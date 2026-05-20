#!/usr/bin/env bash
# Push the commit and tag prepared by release/prepare, authenticated as
# the App via a one-shot Authorization header. The token is never written
# to .git/config, so subsequent steps in the same job cannot read it back.
#
# Required env: TOKEN, TAG, GITHUB_REPOSITORY
set -euo pipefail

if ! git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "::error::Tag $TAG does not exist locally — was release/prepare run earlier in this job?"
  exit 1
fi

# Drop the default checkout's GITHUB_TOKEN extraheader so it doesn't race
# with the App credential, then push with the App token injected via
# GIT_CONFIG_KEY_*/VALUE_* — env-only, so the header never appears in argv
# (no `ps` exposure) and never lands in .git/config.
git config --unset-all "http.https://github.com/.extraheader" 2>/dev/null || true

GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
GIT_CONFIG_VALUE_0="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')" \
  git push "https://github.com/${GITHUB_REPOSITORY}.git" HEAD --follow-tags
