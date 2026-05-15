#!/usr/bin/env bash
# Bump the version in lib/<gem>/version.rb. Refresh Gemfile.lock if the
# project bundles itself via `gemspec`. Stage the touched files. Writes
# outputs `version` and `tag` to $GITHUB_OUTPUT.
#
# Required env: BUMP, TAG_PREFIX, GITHUB_OUTPUT
# Requires `bundle` on PATH (provided by ruby/setup-ruby in the consumer).
set -euo pipefail

# Locate the version.rb file. Standard Ruby gem layout: lib/<gem>/version.rb.
shopt -s nullglob
VERSION_FILES=(lib/*/version.rb)
shopt -u nullglob

if [[ ${#VERSION_FILES[@]} -eq 0 ]]; then
  echo "::error::No lib/<gem>/version.rb found"
  exit 1
fi
if [[ ${#VERSION_FILES[@]} -gt 1 ]]; then
  echo "::error::Expected exactly one lib/<gem>/version.rb, found ${#VERSION_FILES[@]}: ${VERSION_FILES[*]}"
  exit 1
fi
VERSION_FILE="${VERSION_FILES[0]}"

# Parse current version. Accept single or double quotes.
CURRENT=$(grep -oE 'VERSION[[:space:]]*=[[:space:]]*['\''"][0-9]+\.[0-9]+\.[0-9]+['\''"]' "$VERSION_FILE" \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -z "$CURRENT" ]]; then
  echo "::error::Could not find VERSION = \"x.y.z\" in $VERSION_FILE"
  exit 1
fi

IFS=. read -r MAJOR MINOR PATCH <<< "$CURRENT"
case "$BUMP" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac
VERSION="${MAJOR}.${MINOR}.${PATCH}"

# Replace the version. Preserves the original quote style.
sed -i.bak -E "s/(VERSION[[:space:]]*=[[:space:]]*['\"])[0-9]+\.[0-9]+\.[0-9]+(['\"])/\1${VERSION}\2/" "$VERSION_FILE"
rm -f "${VERSION_FILE}.bak"
git add "$VERSION_FILE"

# If the project bundles itself (gemspec directive in Gemfile), Gemfile.lock
# has the local gem version pinned and now mismatches. Refresh it.
if [[ -f Gemfile.lock ]] && [[ -f Gemfile ]] && grep -qE '^[[:space:]]*gemspec' Gemfile; then
  bundle install --quiet
  git add Gemfile.lock
fi

TAG="${TAG_PREFIX}${VERSION}"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
echo "Bumped $VERSION_FILE to $VERSION (tag $TAG)"
