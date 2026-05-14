#!/usr/bin/env bash
# Fail if $TAG already exists on origin.
#
# Required env: TAG
set -euo pipefail

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "::error::Tag $TAG already exists on origin"
  exit 1
fi
