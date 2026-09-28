#!/usr/bin/env python3
"""
Write the VCMI preset that activates the mod under test, its submods and its dependencies.

vcmiserver loads only what the preset lists, and a mod whose dependency is missing from it
is dropped without a word on stderr - so a preset holding just the mod itself makes the
dummy-run pass while validating nothing.

Usage: write_mod_preset.py <mod-id> [preset-path] [--root .]
"""

import argparse
import json
from pathlib import Path

from install_mod_dependencies import iter_depends_values
from mod_metadata_common import find_mods, load_jsonc, mod_json_path

DEFAULT_PRESET = Path.home() / ".config/vcmi/modSettings.json"


def dependency_ids(root: Path) -> set:
    """Every id referenced by a `depends` anywhere in the mod tree, submod ids included."""
    ids = set()
    for mod_dir, _ in find_mods(root):
        for value in iter_depends_values(load_jsonc(mod_json_path(mod_dir))):
            if isinstance(value, str):
                ids.add(value)
            elif isinstance(value, (list, dict)):
                ids.update(dep for dep in value if isinstance(dep, str))
    return ids


def build_preset(root: Path, mod_id: str) -> dict:
    submods = {".".join(segments): True for _, segments in find_mods(root) if segments}
    settings = {mod_id: submods} if submods else {}

    roots = set()
    for dep in dependency_ids(root):
        dep_root, _, submod = dep.lower().partition(".")
        if dep_root == mod_id:  # self-dependency of a submod
            continue
        roots.add(dep_root)
        if submod:
            settings.setdefault(dep_root, {})[submod] = True

    mods = ["vcmi", "core", mod_id] + sorted(roots)
    return {"activePreset": "default", "presets": {"default": {"mods": mods, "settings": settings}}}


def main() -> None:
    parser = argparse.ArgumentParser(description="Write a VCMI mod preset for CI.")
    parser.add_argument("mod_id")
    parser.add_argument("preset", nargs="?", type=Path, default=DEFAULT_PRESET)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    preset = build_preset(args.root, args.mod_id.lower())
    args.preset.parent.mkdir(parents=True, exist_ok=True)
    args.preset.write_text(json.dumps(preset, indent="\t") + "\n", encoding="utf-8")
    print(f"wrote {args.preset}: {', '.join(preset['presets']['default']['mods'])}")


if __name__ == "__main__":
    main()
