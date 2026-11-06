#!/usr/bin/env bash
# Push the release commit and tag prepared by release/prepare in a single
# atomic push: either the current branch fast-forwards to HEAD and the tag
# is created, or neither ref changes. No force: if the branch moved since
# checkout, the push is rejected.
#
# If the tag is already on the remote pointing at the same object (pushed
# earlier by prepare with `push: true`), there is nothing to do.
#
# Authenticated as the App via a one-shot Authorization header. The token is
# never written to .git/config, so subsequent steps in the same job cannot
# read it back.
#
# Required env: TOKEN, TAG, GITHUB_REPOSITORY
set -euo pipefail

if ! LOCAL_TAG=$(git rev-parse --verify --quiet "refs/tags/$TAG"); then
  echo "::error::Tag $TAG does not exist locally — was release/prepare run earlier in this job?"
  exit 1
fi

if ! BRANCH=$(git symbolic-ref --quiet --short HEAD); then
  echo "::error::HEAD is detached. Check out the release branch by name (actions/checkout with ref: <branch>)."
  exit 1
fi

REMOTE="https://github.com/${GITHUB_REPOSITORY}.git"
AUTH_HEADER="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"

# Drop the default checkout's GITHUB_TOKEN extraheader so it doesn't race
# with the App credential, then authenticate with the App token injected via
# GIT_CONFIG_KEY_*/VALUE_* — env-only, so the header never appears in argv
# (no `ps` exposure) and never lands in .git/config.
git config --unset-all "http.https://github.com/.extraheader" 2>/dev/null || true

git_as_app() {
  GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
  GIT_CONFIG_VALUE_0="$AUTH_HEADER" \
    git "$@"
}

REMOTE_TAG=$(git_as_app ls-remote "$REMOTE" "refs/tags/$TAG" | cut -f1)
if [[ "$REMOTE_TAG" == "$LOCAL_TAG" ]]; then
  echo "Tag $TAG is already on the remote, nothing to push"
  exit 0
fi
if [[ -n "$REMOTE_TAG" ]]; then
  echo "::error::Tag $TAG already exists on the remote and points to a different object"
  exit 1
fi

git_as_app push --atomic "$REMOTE" "HEAD:refs/heads/$BRANCH" "refs/tags/$TAG:refs/tags/$TAG"
