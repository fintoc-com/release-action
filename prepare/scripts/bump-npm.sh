#!/usr/bin/env bash
# Bump the version in ./package.json using `npm version`. Stage the
# files touched by the bump (package.json, and package-lock.json if present).
# Write outputs `version` and `tag` to $GITHUB_OUTPUT.
#
# Required env: BUMP, TAG_PREFIX, GITHUB_OUTPUT
# Requires `npm` and `jq` on PATH.
set -euo pipefail

if [[ ! -f package.json ]]; then
  echo "::error::package.json not found at repo root"
  exit 1
fi

npm version "$BUMP" --no-git-tag-version >/dev/null
VERSION=$(jq -r .version package.json)

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "::error::Could not read version from package.json after bump"
  exit 1
fi

git add package.json
[[ -f package-lock.json ]] && git add package-lock.json

TAG="${TAG_PREFIX}${VERSION}"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
echo "Bumped package.json to $VERSION (tag $TAG)"
