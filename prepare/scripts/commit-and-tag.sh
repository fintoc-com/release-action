#!/usr/bin/env bash
# Configure git as the fin-releases bot, commit what the bump step
# already staged, and create an annotated tag. Does NOT push.
#
# Required env: TOKEN, APP_SLUG, TAG
set -euo pipefail

BOT_NAME="${APP_SLUG}[bot]"
BOT_ID=$(GH_TOKEN="$TOKEN" gh api "/users/${BOT_NAME}" --jq .id)
git config user.name  "$BOT_NAME"
git config user.email "${BOT_ID}+${BOT_NAME}@users.noreply.github.com"

if git diff --cached --quiet; then
  echo "::error::Nothing staged after bump"
  exit 1
fi

git commit -m "release: $TAG"
# Annotated tag: `git push --follow-tags` only pushes annotated tags.
git tag -a "$TAG" -m "$TAG"
