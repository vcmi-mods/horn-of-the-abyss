#!/usr/bin/env python3
"""
Mod metadata operations over a mod tree (top-level mod + nested submods).

Subcommands:
  export          Write mod name/description into the Weblate source english.json.
  wire            Wire translation/<lang>.json references into mod.json (committed).
  inject-names    Fold translated name/description into the published mod.json (release).
  measure-progress  Record per-language translation progress for inject-release (release).
  inject-release  Write release/repository fields into the published mod.json (release).

Every operation takes --root (default '.'). Shared tree-walking / JSON helpers live
in mod_metadata_common.

  export         runs after the in-game english.json is regenerated, before it is
                 committed as the Weblate source. Metadata keys written:
                   mod.<id>.name         always (from that mod's mod.json "name")
                   mod.<id>.description  only if the mod has no description/english.md
                                         (the .md, when present, is the authoritative
                                          source translated as its own component)
  wire           for every non-Translation mod/submod, ensures each non-english
                 <lang>.json is referenced via "<lang>": {"translations": [...]} so
                 the game loads it. Existing blocks/references are left untouched.
  inject-names   at release time (fresh checkout, never committed) writes per-language
                   <lang>.name         <- translated mod.<id>.name
                   <lang>.description  <- description/<lang>.md, else translated
                                          mod.<id>.description
                 English keeps its root name/short description; only description/
                 english.md (when present) is injected.
  inject-release runs after the release ZIP is built (needs its size), before mod.json
                 is uploaded. Fields: download, downloadSize, screenshots, githubStars,
                 updateDate (1.8+ only), validated (only when the dummy-run ran),
                 <lang>.progress (from measure-progress). updateDate is UTC ISO 8601
                 so std::get_time + timegm parse it and comparison against std::time
                 needs no timezone.
"""

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from mod_metadata_common import (
    LANGUAGES,
    child_ci,
    description_md,
    find_mods,
    iter_language_files,
    load_jsonc,
    metadata_key,
    mod_json_path,
    translation_dir,
    write_json,
)


# --- export -----------------------------------------------------------------

def english_json_path(root: Path) -> Path:
    """Path to the top-level mod's english.json, resolving existing dirs case-insensitively."""
    tdir = translation_dir(root)
    if tdir is not None:
        existing = next((p for p in tdir.iterdir() if p.name.lower() == "english.json"), None)
        if existing is not None:
            return existing
        return tdir / "english.json"
    return root / "content" / "translation" / "english.json"


def export(root: Path) -> None:
    target = english_json_path(root)
    strings = load_jsonc(target) if target.exists() else {}

    for mod_dir, segments in find_mods(root):
        config = load_jsonc(mod_json_path(mod_dir))

        # Translation mods are single-language and hand-edited; they have no english
        # Weblate source, so don't export (nor conjure an english.json for) them.
        if config.get("modType") == "Translation":
            continue

        name = config.get("name")
        if isinstance(name, str) and name:
            strings[metadata_key(segments, "name")] = name

        # description.md (now description/english.md) is authoritative when present
        if description_md(mod_dir, "english") is None:
            description = config.get("description")
            if isinstance(description, str) and description:
                strings[metadata_key(segments, "description")] = description

    # Nothing to export (e.g. a Translation-only repo) - don't create an empty source.
    if not strings and not target.exists():
        print("no metadata to export")
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    write_json(target, strings)
    print(f"wrote {len(strings)} entries to {target}")


# --- wire -------------------------------------------------------------------

def wire_mod(mod_dir: Path) -> None:
    path = mod_json_path(mod_dir)
    config = load_jsonc(path)

    if config.get("modType") == "Translation":
        return

    changed = False
    for language, _entry in iter_language_files(mod_dir):
        if not language_supported(language):
            continue
        block = config.get(language)
        if not isinstance(block, dict):
            block = {}
        if "translations" not in block:
            block["translations"] = [f"translation/{language}.json"]
            changed = True
        config[language] = block

    if changed:
        # Committed via the add-language PR without Prettier, so keep the house style
        # (tabs + " : ") here; the CI path re-runs Prettier over it anyway.
        path.write_text(
            json.dumps(config, ensure_ascii=False, indent="\t", separators=(",", " : "))
            + "\n",
            encoding="utf-8",
        )
        print(f"wired translations into {path}")


def wire(root: Path) -> None:
    for mod_dir, _segments in find_mods(root):
        wire_mod(mod_dir)


# --- inject-names -----------------------------------------------------------

def read_md(path: Path) -> str:
    return path.read_text(encoding="utf-8").rstrip("\n") + "\n"


def load_translations(root: Path) -> dict:
    """Load every top-level content/translation/<lang>.json keyed by language."""
    return {lang: load_jsonc(path) for lang, path in iter_language_files(root, include_english=True)}


def inject_mod(mod_dir: Path, segments, translations: dict) -> None:
    config = load_jsonc(mod_json_path(mod_dir))
    name_key = metadata_key(segments, "name")
    desc_key = metadata_key(segments, "description")

    languages = set(translations)
    languages.update(lang for lang in LANGUAGES if description_md(mod_dir, lang) is not None)

    changed = False
    for language in sorted(filter(language_supported, languages)):
        block = config.get(language)
        if not isinstance(block, dict):
            block = {}

        if language != "english":
            name = translations.get(language, {}).get(name_key)
            if isinstance(name, str) and name:
                block["name"] = name
                changed = True

        md = description_md(mod_dir, language)
        if md is not None:
            block["description"] = read_md(md)
            changed = True
        elif language != "english":
            description = translations.get(language, {}).get(desc_key)
            if isinstance(description, str) and description:
                block["description"] = description
                changed = True

        if block:
            config[language] = block

    if changed:
        write_json(mod_json_path(mod_dir), config)
        print(f"injected metadata into {mod_json_path(mod_dir)}")


def inject_names(root: Path) -> None:
    translations = load_translations(root)
    for mod_dir, segments in find_mods(root):
        inject_mod(mod_dir, segments, translations)


# --- measure-progress -------------------------------------------------------

# Outside the release ZIP (create_release_package.sh excludes dist/). Measured before
# content/ is zipped away; injected only into the published mod.json, because the
# game's mod.json schema rejects unknown keys in language blocks.
PROGRESS_FILE = Path("dist") / "progress.json"


def translation_progress(root: Path) -> dict:
    """Percent (0-100, rounded down) of english strings translated per language, over all mods and submods."""
    total = 0
    translated = {}
    for mod_dir, _ in find_mods(root):
        files = dict(iter_language_files(mod_dir, include_english=True))
        english = files.pop("english", None)
        if english is None:
            continue
        keys = list(load_jsonc(english))
        total += len(keys)
        for language, path in files.items():
            strings = load_jsonc(path)
            # Only keys still present in english.json: removed strings may linger in translations
            count = sum(1 for key in keys if isinstance(strings.get(key), str) and strings[key])
            translated[language] = translated.get(language, 0) + count
    if total == 0:
        return {}
    return {language: count * 100 // total for language, count in translated.items()}


def self_test() -> None:
    """Check translation_progress on a mod with a submod, a stale key and an empty string."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        files = {
            "mod.json": {"name": "Root"},
            "content/translation/english.json": {"a": "A", "b": "B", "c": "C"},
            "content/translation/german.json": {"a": "a", "b": "", "stale": "x"},
            "Mods/sub/mod.json": {"name": "Sub"},
            "Mods/sub/content/translation/english.json": {"d": "D"},
            "Mods/sub/content/translation/german.json": {"d": "d"},
            "Mods/sub/content/translation/polish.json": {"d": "d"},
        }
        for name, data in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            write_json(root / name, data)
        # german: a + d of 4; polish: d of 4; empty and stale keys don't count
        assert translation_progress(root) == {"german": 50, "polish": 25}, translation_progress(root)
    print("self-test OK")


def measure_progress(root: Path) -> None:
    path = root / PROGRESS_FILE
    path.parent.mkdir(exist_ok=True)
    write_json(path, translation_progress(root))


# --- inject-release ---------------------------------------------------------

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"}


def megabytes(num_bytes: int) -> float:
    return round(num_bytes / (1024 * 1024), 2)


def download_url(repository: str, tag: str, asset: str) -> str:
    return f"https://github.com/{repository}/releases/download/{tag}/{asset}"


def screenshot_urls(root: Path, repository: str, sha: str) -> list:
    directory = child_ci(root, "screenshots")
    if directory is None:
        return []
    files = [e for e in directory.iterdir() if e.is_file() and e.suffix.lower() in IMAGE_SUFFIXES]
    return [
        f"https://raw.githubusercontent.com/{repository}/{sha}/{directory.name}/{e.name}"
        for e in sorted(files, key=lambda p: p.name.lower())
    ]


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def version_at_least(ref_name: str, major: int, minor: int) -> bool:
    """True if ref_name is vcmi-<major>.<minor> or newer (numeric compare, so 1.10 > 1.8)."""
    match = re.match(r"vcmi-(\d+)\.(\d+)", ref_name)
    if match is None:
        return False
    return (int(match.group(1)), int(match.group(2))) >= (major, minor)


# Languages added in VCMI 1.8; older versions reject them in mod.json.
LANGUAGES_SINCE_1_8 = {"tchinese", "norwegian", "lithuanian"}


def language_supported(language: str) -> bool:
    """False for 1.8-only languages when running on a vcmi-* branch older than 1.8."""
    # Set by the detect step from the base branch, since GITHUB_REF_NAME is "<n>/merge" on PRs.
    ref_name = os.environ.get("VCMI_VERSION", "")
    if language not in LANGUAGES_SINCE_1_8 or not ref_name.startswith("vcmi-"):
        return True
    return version_at_least(ref_name, 1, 8)


def inject_release(root: Path) -> None:
    repository = os.environ["GITHUB_REPOSITORY"]          # owner/repo
    ref_name = os.environ["GITHUB_REF_NAME"]              # vcmi-1.8
    sha = os.environ["GITHUB_SHA"]
    repo = repository.split("/")[-1]
    tag = ref_name.removeprefix("vcmi-")                  # 1.8 - matches release tag
    asset = f"{repo}-{ref_name}.zip"

    zip_path = root / "dist" / asset
    config = load_jsonc(mod_json_path(root))

    config["download"] = download_url(repository, tag, asset)
    config["downloadSize"] = megabytes(zip_path.stat().st_size)

    # updateDate is a 1.8+ feature; 1.7 and older releases omit it.
    if version_at_least(ref_name, 1, 8):
        config["updateDate"] = utc_now()
    else:
        config.pop("updateDate", None)

    screenshots = screenshot_urls(root, repository, sha)
    if screenshots:
        config["screenshots"] = screenshots

    # Unset when the VCMI version was not detected and the dummy-run never ran
    validation = os.environ.get("VALIDATION_RESULT", "")
    if validation:
        config["validated"] = validation == "success"

    progress_path = root / PROGRESS_FILE
    progress = load_jsonc(progress_path) if progress_path.exists() else {}
    if progress:
        for language in filter(language_supported, LANGUAGES):
            block = config.get(language)
            if language != "english" and isinstance(block, dict):
                block["progress"] = progress.get(language, 0)

    stars = os.environ.get("GITHUB_STARS", "").strip()
    if stars.isdigit():
        config["githubStars"] = int(stars)

    write_json(mod_json_path(root), config)
    print(f"wrote release metadata into {mod_json_path(root)}")


# --- CLI --------------------------------------------------------------------

OPERATIONS = {
    "export": export,
    "wire": wire,
    "inject-names": inject_names,
    "measure-progress": measure_progress,
    "inject-release": inject_release,
}


def main() -> None:
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return

    parser = argparse.ArgumentParser(description="Mod metadata operations over a mod tree.")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in OPERATIONS:
        sub.add_parser(name).add_argument("--root", default=".")

    args = parser.parse_args()
    OPERATIONS[args.command](Path(args.root))


if __name__ == "__main__":
    main()
