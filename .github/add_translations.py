#!/usr/bin/env python3
"""
Scaffold a new translation language: create an empty <lang>.json next to every
english.json, then wire the language into each mod.json via mod_metadata.wire.
"""

import argparse
import sys
from pathlib import Path
from typing import List

import mod_metadata
from mod_metadata_common import LANGUAGES, find_files_ci


def find_english_dirs(root: Path) -> List[Path]:
    return [p.parent for p in find_files_ci(root, "english.json")]


def ensure_lang_files(dirs: List[Path], lang: str) -> None:
    for d in dirs:
        target = d / f"{lang}.json"
        if not target.exists():
            target.write_text("{}", encoding="utf-8")
            print(f"Created {target}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", "-r", type=Path, default=Path.cwd(), help="Root directory to search")
    p.add_argument("--lang", "-l", required=True, help="Language name to add (e.g. 'french')")
    args = p.parse_args()

    root: Path = args.root
    lang: str = args.lang

    if lang not in LANGUAGES:
        print(f"Unknown language '{lang}'. Must be one of: {', '.join(sorted(LANGUAGES))}")
        sys.exit(1)

    english_dirs = find_english_dirs(root)
    if not english_dirs:
        print("No english.json files found.")
        return

    ensure_lang_files(english_dirs, lang)
    # Reuse the canonical wiring so mod.json entries match the CI exactly.
    mod_metadata.wire(root)
    print(f"Processed {len(english_dirs)} directories; ensured {lang}.json where missing.")


if __name__ == "__main__":
    main()
