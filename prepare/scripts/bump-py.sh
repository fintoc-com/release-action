#!/usr/bin/env bash
# Bump the version in ./pyproject.toml using `poetry version`. Stage the
# file. Writes outputs `version` and `tag` to $GITHUB_OUTPUT.
#
# Required env: BUMP, TAG_PREFIX, GITHUB_OUTPUT
# Requires `poetry` on PATH.
set -euo pipefail

if [[ ! -f pyproject.toml ]]; then
  echo "::error::pyproject.toml not found at repo root"
  exit 1
fi

poetry version "$BUMP" >/dev/null
VERSION=$(poetry version -s)

if [[ -z "$VERSION" ]]; then
  echo "::error::Could not read version from pyproject.toml after bump"
  exit 1
fi

git add pyproject.toml

TAG="${TAG_PREFIX}${VERSION}"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
echo "Bumped pyproject.toml to $VERSION (tag $TAG)"
