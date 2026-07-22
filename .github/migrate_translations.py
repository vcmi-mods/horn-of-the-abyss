#!/usr/bin/env python3
"""
TEMPORARY migration step.

Seeds the Weblate translation sources from metadata that already lives in mod.json:
for every non-english "<lang>": {"name"/"description"} block present in a mod (or
submod) mod.json, copy those values into the top-level content/translation/<lang>.json
as mod.<seg>.name / mod.<seg>.description - the same keys export/inject use.

Creates <lang>.json when it does not exist; never overwrites a key that is already
there (Weblate/translator content wins). Translation-type mods are skipped, matching
export/wire.

Once every mod's manual per-language metadata has been folded into the translation
JSONs, delete this script and its workflow step.

Usage: migrate_translations.py [--root .]
       migrate_translations.py --self-test
"""

import argparse
import json
from pathlib import Path

from mod_metadata_common import (
    LANGUAGES,
    child_ci,
    find_mods,
    load_jsonc,
    metadata_key,
    mod_json_path,
    translation_dir,
)


def write_weblate_json(path: Path, data) -> None:
    """Write a translation file in Weblate's native format (tab indent, standard ": ").

    Not mod_metadata_common.write_json: these files are Weblate-managed and excluded
    from Prettier/postprocess_colons, so the house " : " separator would reformat every
    existing line (and churn against Weblate) instead of just adding the seeded keys.
    """
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def translation_json_path(root: Path, language: str) -> Path:
    """Top-level content/translation/<language>.json, resolving existing case."""
    tdir = translation_dir(root)
    if tdir is not None:
        existing = child_ci(tdir, language + ".json")
        return existing if existing is not None else tdir / f"{language}.json"
    return root / "content" / "translation" / f"{language}.json"


def collect_updates(root: Path) -> dict:
    """Return {language: {metadata_key: value}} gathered from per-language mod.json blocks."""
    updates: dict = {}
    for mod_dir, segments in find_mods(root):
        config = load_jsonc(mod_json_path(mod_dir))
        if config.get("modType") == "Translation":
            continue
        for language in LANGUAGES:
            if language == "english":
                continue
            block = config.get(language)
            if not isinstance(block, dict):
                continue
            for field in ("name", "description"):
                value = block.get(field)
                if isinstance(value, str) and value:
                    updates.setdefault(language, {})[metadata_key(segments, field)] = value
    return updates


def migrate(root: Path) -> None:
    for language, keys in sorted(collect_updates(root).items()):
        path = translation_json_path(root, language)
        data = load_jsonc(path) if path.exists() else {}
        added = [key for key in keys if key not in data]  # never overwrite existing
        if not added:
            continue
        for key in added:
            data[key] = keys[key]
        path.parent.mkdir(parents=True, exist_ok=True)
        write_weblate_json(path, data)
        print(f"seeded {len(added)} key(s) into {path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    migrate(Path(args.root))
