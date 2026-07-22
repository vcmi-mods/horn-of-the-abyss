#!/usr/bin/env python3
"""
TEMPORARY migration step.

Splits a legacy sectioned `description.md` (one "# <language>" section per language,
the format consumed by ModDescription::mergeModDescriptions) into per-language files
`description/<lang>.md`, so each becomes its own Weblate component, then removes the
legacy file.

Rules (per maintainer, validated against real description.md files):
  - language ids in headings are guaranteed lower-case
  - english is guaranteed present (but not necessarily first)
  - if the file has no "# <language>" headings at all, the whole file is english

Idempotent: skips any mod that has no description.md, or that already has a
description/ directory. Once every mod has migrated, delete this script and its
workflow step.

Usage: migrate_description.py [--root .]
       migrate_description.py --self-test
"""

import argparse
import re
import sys
from pathlib import Path

from mod_metadata_common import LANGUAGES, child_ci, detect_language, find_mods

HEADING_RE = re.compile(r"(?m)^#[ \t]+(.*)$")


def split_description(text: str) -> dict:
    """Return {language: body} parsed from a sectioned description.md."""
    headings = list(HEADING_RE.finditer(text))
    if not headings:
        # No headings -> the whole file is the english description.
        return {"english": text.strip() + "\n"}

    result = {}
    for index, match in enumerate(headings):
        language = detect_language(match.group(1))
        if language is None:
            continue  # heading without a recognised language: skip (matches loader)
        start = match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        body = text[start:end].strip("\n").rstrip() + "\n"
        result[language] = body
    return result


def migrate_mod(mod_dir: Path) -> bool:
    """Migrate a single mod's description.md. Returns True if it did anything."""
    legacy = child_ci(mod_dir, "description.md")
    if legacy is None:
        return False
    if child_ci(mod_dir, "description") is not None:
        print(f"skip (description/ already present): {mod_dir}")
        return False

    sections = split_description(legacy.read_text(encoding="utf-8"))
    if "english" not in sections:
        # english is guaranteed present; if missing the file is malformed - leave it.
        print(f"WARNING: no english section in {legacy}, leaving as-is")
        return False

    out_dir = mod_dir / "description"
    out_dir.mkdir()
    for language, body in sections.items():
        (out_dir / f"{language}.md").write_text(body, encoding="utf-8")
        print(f"wrote {out_dir.name}/{language}.md")
    legacy.unlink()
    print(f"removed {legacy.name}")
    return True


def run(root: Path) -> None:
    for mod_dir, _segments in find_mods(root):
        migrate_mod(mod_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    run(Path(args.root))
