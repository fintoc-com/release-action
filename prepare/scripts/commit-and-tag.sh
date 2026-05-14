#!/usr/bin/env bash
# Configure git as the fin-releases bot, stage any extra-paths on top of
# what the bump step already staged, commit and tag locally. Does NOT push.
#
# Required env: TOKEN, APP_SLUG, EXTRA_PATHS, TAG
set -euo pipefail

BOT_NAME="${APP_SLUG}[bot]"
BOT_ID=$(GH_TOKEN="$TOKEN" gh api "/users/${BOT_NAME}" --jq .id)
git config user.name  "$BOT_NAME"
git config user.email "${BOT_ID}+${BOT_NAME}@users.noreply.github.com"

if [[ -n "${EXTRA_PATHS//[[:space:]]/}" ]]; then
  while IFS= read -r path; do
    [[ -z "${path//[[:space:]]/}" ]] && continue
    if [[ ! -e "$path" ]]; then
      echo "::warning::extra-paths entry '$path' does not exist, skipping"
      continue
    fi
    git add "$path"
  done <<< "$EXTRA_PATHS"
fi

if git diff --cached --quiet; then
  echo "::error::Nothing staged after bump"
  exit 1
fi

git commit -m "release: $TAG"
# Annotated tag: `git push --follow-tags` only pushes annotated tags.
git tag -a "$TAG" -m "$TAG"
