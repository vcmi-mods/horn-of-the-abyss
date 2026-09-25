#!/usr/bin/env python3

import re
import sys
from pathlib import Path

from mod_metadata_common import iter_formattable_json

# Anchored at the start of the line so only the key is matched. An unanchored
# pattern also matches a quoted phrase inside a value and corrupts translated
# text like: from "the Angelic Alliance": "the Sword of Judgement".
# Safe because Prettier runs with --print-width 1, putting one key per line.
KEY_COLON = re.compile(r'^(\s*)(".*?")\s*:\s*')

def fix_colon_spacing(file_path: Path):
	with file_path.open("r", encoding="utf-8") as f:
		lines = f.readlines()

	with file_path.open("w", encoding="utf-8") as f:
		for line in lines:
			# Skip comments (lines starting with // or /*)
			if line.strip().startswith("//") or line.strip().startswith("/*"):
				f.write(line)
				continue

			# Replace "key": value with "key" : value
			# Only for JSON key-value pairs, not strings or comments
			line = KEY_COLON.sub(r'\1\2 : ', line)
			f.write(line)

def process_all_json_files():
	for path in iter_formattable_json(Path(".")):
		print(f"Postprocessing: {path}")
		fix_colon_spacing(path)

def self_test():
	cases = [
		('\t"name": "Highlands Town"\n',      '\t"name" : "Highlands Town"\n'),
		('\t"name"   :   "x"\n',              '\t"name" : "x"\n'),
		# a quoted phrase inside a value keeps its own spacing
		('\t"text" : "from "Alliance": the Sword"\n',
		 '\t"text" : "from "Alliance": the Sword"\n'),
		('\t\t"config/vcmi-dutch/game.json",\n', '\t\t"config/vcmi-dutch/game.json",\n'),
		('\t// "commented": value\n',         '\t// "commented": value\n'),
	]
	for source, expected in cases:
		actual = source if source.strip().startswith("//") else KEY_COLON.sub(r'\1\2 : ', source)
		assert actual == expected, f"{source!r} -> {actual!r}, expected {expected!r}"
	print("self-test OK")

if __name__ == "__main__":
	if "--self-test" in sys.argv:
		self_test()
	else:
		process_all_json_files()
