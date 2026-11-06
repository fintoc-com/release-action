#!/usr/bin/env bash
# Validate inputs before running the rest of prepare. Fails fast with a
# clear message if anything is off.
#
# Required env: BUMP, VERSION_FORMAT, ACTION_PATH, TAG_PREFIX, PUSH
set -euo pipefail

case "$BUMP" in
  patch|minor|major) ;;
  *) echo "::error::Invalid bump '$BUMP' (must be patch, minor or major)"; exit 1 ;;
esac

case "$PUSH" in
  true|false) ;;
  *) echo "::error::Invalid push '$PUSH' (must be true or false)"; exit 1 ;;
esac

# version-format selects a filename under scripts/; constrain it to a
# safe character set so it can never be anything but a plain identifier.
if [[ ! "$VERSION_FORMAT" =~ ^[a-z0-9-]+$ ]]; then
  echo "::error::Invalid version-format '$VERSION_FORMAT' (must match [a-z0-9-]+)"
  exit 1
fi

BUMP_SCRIPT="$ACTION_PATH/scripts/bump-$VERSION_FORMAT.sh"
if [[ ! -f "$BUMP_SCRIPT" ]]; then
  AVAILABLE=$(find "$ACTION_PATH/scripts" -name 'bump-*.sh' -exec basename {} \; \
    | sed 's/^bump-//; s/\.sh$//' | sort | paste -sd, -)
  echo "::error::Unsupported version-format '$VERSION_FORMAT'. Available: $AVAILABLE"
  exit 1
fi

# tag-prefix is concatenated into $GITHUB_OUTPUT — a literal newline would
# let a caller forge extra step outputs.
if [[ "${TAG_PREFIX-}" == *$'\n'* || "${TAG_PREFIX-}" == *$'\r'* ]]; then
  echo "::error::tag-prefix must not contain newlines"
  exit 1
fi
