#!/bin/bash 

set -euo pipefail

ROOT="$(pwd)"
mapfile -d '' CONTENT_DIRS < <(find . -type d -name content -print0)
echo "Found ${#CONTENT_DIRS[@]} content directories"

for d in "${CONTENT_DIRS[@]}"; do
	parent="$(dirname "$d")"
	out="$ROOT/${parent#./}/content.zip"

	echo "Packaging CONTENT of: $d -> $out"

	# ensure no leftover
	rm -f "$out"

	# Zip CONTENTS (not the folder), store-only
	(
		cd "$d"
		zip -0 -r -q "$out" .
	)

	rm -rf "$d"
done
