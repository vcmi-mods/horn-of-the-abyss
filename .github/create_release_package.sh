#!/bin/bash 

set -euo pipefail

mkdir -p dist

REPO_NAME="${GITHUB_REPOSITORY##*/}"
WRAP="${REPO_NAME}-${GITHUB_REF_NAME}"
OUT="dist/${WRAP}.zip"

rm -rf ".pack"
mkdir -p ".pack/${WRAP}"

# Copy repo content into wrapper folder, excluding .git and dist and the staging itself
rsync -a \
	--exclude ".git/" \
	--exclude "dist/" \
	--exclude ".pack/" \
	"./" ".pack/${WRAP}/"

# Create zip so that it contains the wrapper folder at top level
(cd ".pack" && zip -9 -r -q "../${OUT}" "${WRAP}" )

echo "Created: ${OUT}"
