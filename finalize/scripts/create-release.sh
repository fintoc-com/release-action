#!/usr/bin/env bash
# Create the GitHub Release for $TAG with $RELEASE_NOTES as body (empty allowed).
# Writes `url` to $GITHUB_OUTPUT.
#
# Required env: GH_TOKEN, TAG, RELEASE_NOTES, GITHUB_OUTPUT
set -euo pipefail

URL=$(gh release create "$TAG" --title "$TAG" --notes "$RELEASE_NOTES")
echo "url=$URL" >> "$GITHUB_OUTPUT"
echo "Release created: $URL"
