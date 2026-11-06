#!/usr/bin/env bash
# Exercise shared/push.sh against a temporary bare repo. GitHub URLs are
# redirected to the bare repo with url.<base>.insteadOf in a throwaway
# global gitconfig, so the script runs unmodified.
#
# Usage: tests/push.test.sh
set -euo pipefail

PUSH_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/shared/push.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export GITHUB_REPOSITORY="acme/sdk"
export TOKEN="test-token"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global url."file://$WORK/remote.git".insteadOf "https://github.com/$GITHUB_REPOSITORY.git"
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false

FAILURES=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
remote_ref() { git --git-dir="$WORK/remote.git" rev-parse --verify --quiet "$1" || true; }

setup() {
  rm -rf "$WORK/remote.git" "$WORK/release" "$WORK/other"
  git init --quiet --bare "$WORK/remote.git"
  git clone --quiet "file://$WORK/remote.git" "$WORK/seed" 2>/dev/null
  git -C "$WORK/seed" commit --quiet --allow-empty -m initial
  git -C "$WORK/seed" push --quiet origin main
  rm -rf "$WORK/seed"
  git clone --quiet "file://$WORK/remote.git" "$WORK/release"
  git -C "$WORK/release" commit --quiet --allow-empty -m "release: v1.0.0"
  git -C "$WORK/release" tag -a v1.0.0 -m v1.0.0
}

move_remote_branch() {
  git clone --quiet "file://$WORK/remote.git" "$WORK/other"
  git -C "$WORK/other" commit --quiet --allow-empty -m "merged during release"
  git -C "$WORK/other" push --quiet origin main
}

run_push() { (cd "$WORK/release" && TAG=v1.0.0 "$PUSH_SCRIPT") >"$WORK/out" 2>&1; }

setup
if run_push \
  && [[ "$(remote_ref refs/heads/main)" == "$(git -C "$WORK/release" rev-parse HEAD)" ]] \
  && [[ "$(remote_ref refs/tags/v1.0.0)" == "$(git -C "$WORK/release" rev-parse v1.0.0)" ]]; then
  pass "pushes branch and tag"
else
  fail "pushes branch and tag"; cat "$WORK/out"
fi

if ! grep -q "$TOKEN" "$WORK/release/.git/config" \
  && ! grep -qF "$(printf 'x-access-token:%s' "$TOKEN" | base64)" "$WORK/release/.git/config"; then
  pass "does not write the token to .git/config"
else
  fail "does not write the token to .git/config"
fi

if run_push && grep -q "already on the remote" "$WORK/out"; then
  pass "skips when the tag is already on the remote"
else
  fail "skips when the tag is already on the remote"; cat "$WORK/out"
fi

setup
move_remote_branch
moved=$(remote_ref refs/heads/main)
if ! run_push \
  && [[ "$(remote_ref refs/heads/main)" == "$moved" ]] \
  && [[ -z "$(remote_ref refs/tags/v1.0.0)" ]]; then
  pass "branch moved: rejects both refs"
else
  fail "branch moved: rejects both refs"; cat "$WORK/out"
fi

setup
git -C "$WORK/release" tag -a other -m other HEAD~1
git -C "$WORK/release" push --quiet origin "refs/tags/other:refs/tags/v1.0.0"
if ! run_push && grep -q "points to a different object" "$WORK/out"; then
  pass "fails when the remote tag points elsewhere"
else
  fail "fails when the remote tag points elsewhere"; cat "$WORK/out"
fi

setup
git -C "$WORK/release" checkout --quiet --detach
if ! run_push && grep -q "HEAD is detached" "$WORK/out"; then
  pass "fails on detached HEAD"
else
  fail "fails on detached HEAD"; cat "$WORK/out"
fi

[[ "$FAILURES" -eq 0 ]] || { echo "$FAILURES test(s) failed"; exit 1; }
