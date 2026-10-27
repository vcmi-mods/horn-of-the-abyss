#!/bin/bash 

set -euo pipefail

mkdir -p dist

REPO_NAME="${GITHUB_REPOSITORY##*/}"
WRAP="${REPO_NAME}-${GITHUB_REF_NAME}"
OUT="dist/${WRAP}.zip"

rm -rf ".pack"
mkdir -p ".pack/${WRAP}"

# Whitelist: what VCMI loads plus screenshots for offline browsing. content/ is
# already packed into content.zip by create_content_zip.sh. find -iname because
# mods use any case (Mods/, Content.zip, Screenshots/).
mapfile -d '' KEEP < <(find . -mindepth 1 -maxdepth 1 \
	\( -iname mod.json -o -iname content.zip -o -iname mods -o -iname screenshots \) -print0)
cp -a "${KEEP[@]}" ".pack/${WRAP}/"

# Drop every description/ dir in submods (any case, any depth): its per-language .md
# is folded into mod.json at release time.
find ".pack/${WRAP}" -type d -iname description -prune -exec rm -rf {} +

# Create zip so that it contains the wrapper folder at top level
(cd ".pack" && zip -9 -r -q "../${OUT}" "${WRAP}" )

echo "Created: ${OUT}"
