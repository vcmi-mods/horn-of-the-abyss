#!/usr/bin/env python3
"""
Find every directory containing english.json, add empty JSON files for a specified language,
and update mod.json two directories above each english.json with a top-level entry:

  "<lang>": { ... , "translations": ["translation/<lang>.json"] }
"""

import argparse
import json
import jstyleson
from pathlib import Path
from typing import List, Optional

def load_json_with_comments(path: Path) -> Optional[dict]:
    txt = path.read_text(encoding="utf-8")
    data = jstyleson.loads(txt)
    if not isinstance(data, dict):
        return None
    return data

def find_english_dirs(root: Path) -> List[Path]:
    return [p.parent for p in root.rglob("english.json")]

def ensure_lang_files(dirs: List[Path], lang: str) -> None:
    for d in dirs:
        target = d / f"{lang}.json"
        if not target.exists():
            target.write_text("{}", encoding="utf-8")
            print(f"Created {target}")


def update_mod_json_for_lang(dirs: List[Path], lang: str) -> None:
    for d in dirs:
        mod_path = (d / ".." / ".." / "mod.json").resolve()
        if not mod_path.exists():
            print(f"mod.json not found at {mod_path}; skipping.")
            continue

        mod_data = load_json_with_comments(mod_path)
        if mod_data is None:
            print(f"Skipping {mod_path} due to parse failure.")
            continue

        existing = mod_data.get(lang)
        if isinstance(existing, dict):
            existing["translations"] = [f"translation/{lang}.json"]
            mod_data[lang] = existing
        else:
            # if missing or not an object, replace with a proper object
            mod_data[lang] = {"translations": [f"translation/{lang}.json"]}

        mod_path.write_text(
            json.dumps(mod_data, indent='\t', separators=(',', ' : '), ensure_ascii=False),
            encoding="utf-8",
        )

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", "-r", type=Path, default=Path.cwd(), help="Root directory to search")
    p.add_argument("--lang", "-l", required=True, help="Language name to add (e.g., 'es' or 'french')")
    args = p.parse_args()

    root: Path = args.root
    lang: str = args.lang
    
    if not (lang.isascii() and lang.islower() and lang.isalpha()):
        print("Language name must only contain lower-case latin characters")
        return

    english_dirs = find_english_dirs(root)
    if not english_dirs:
        print("No english.json files found.")
        return

    ensure_lang_files(english_dirs, lang)
    update_mod_json_for_lang(english_dirs, lang)
    print(f"Processed {len(english_dirs)} directories; ensured {lang}.json where missing.")

if __name__ == "__main__":
    main()
