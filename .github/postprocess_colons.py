#!/usr/bin/env python3

import re
import sys
from pathlib import Path

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
			line = re.sub(r'(".*?")\s*:\s*', r'\1 : ', line)
			f.write(line)

def process_all_json_files():
	for path in Path(".").rglob("*.json"):
		if str(path).startswith("./.git") or not path.is_file():
			continue
		print(f"Postprocessing: {path}")
		fix_colon_spacing(path)

if __name__ == "__main__":
	process_all_json_files()
