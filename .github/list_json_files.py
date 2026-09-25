#!/usr/bin/env python3
"""Print every *.json that CI may reformat, NUL-separated, for the Prettier step."""

import json
import sys
import tempfile
from pathlib import Path

from mod_metadata_common import iter_formattable_json


def self_test():
	"""Weblate-owned directories are skipped, the rest of the mod tree is formatted."""
	with tempfile.TemporaryDirectory() as tmp:
		root = Path(tmp)
		(root / "Content/config/vcmi-czech").mkdir(parents=True)
		(root / "Content/config/creatures").mkdir(parents=True)
		(root / "Mods/ai/Content/config/vcmi-czech-ai").mkdir(parents=True)
		(root / "mod.json").write_text(json.dumps(
			{"translations": ["config/vcmi-czech/game.json"]}))
		(root / "Mods/ai/mod.json").write_text(json.dumps(
			{"czech": {"translations": ["config/vcmi-czech-ai/chronicles.json"]}}))
		for rel in ("Content/config/vcmi-czech/game.json",
					# sibling of a declared file: Weblate-owned as well
					"Content/config/vcmi-czech/chronicles.json",
					"Mods/ai/Content/config/vcmi-czech-ai/chronicles.json",
					"Content/config/creatures/dragon.json"):
			(root / rel).write_text("{}")

		formatted = {p.relative_to(root).as_posix() for p in iter_formattable_json(root)}
		assert formatted == {"mod.json", "Mods/ai/mod.json", "Content/config/creatures/dragon.json"}, formatted
	print("self-test OK")


if __name__ == "__main__":
	if "--self-test" in sys.argv:
		self_test()
	else:
		for path in iter_formattable_json(Path(".")):
			sys.stdout.write(f"{path}\0")
