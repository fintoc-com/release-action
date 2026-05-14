#!/usr/bin/env bash
# Push the commit and tag prepared by release/prepare. Swaps the origin
# remote URL to use the App token first.
#
# Required env: TOKEN, TAG, GITHUB_REPOSITORY
set -euo pipefail

if ! git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "::error::Tag $TAG does not exist locally — was release/prepare run earlier in this job?"
  exit 1
fi

# Replace the default checkout's GITHUB_TOKEN extraheader with the App token
git config --unset-all "http.https://github.com/.extraheader" 2>/dev/null || true
git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

git push origin HEAD --follow-tags
