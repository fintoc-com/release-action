#!/usr/bin/env bash
# Validate inputs before running the rest of prepare. Fails fast with a
# clear message if anything is off.
#
# Required env: BUMP, VERSION_FORMAT, ACTION_PATH
set -euo pipefail

case "$BUMP" in
  patch|minor|major) ;;
  *) echo "::error::Invalid bump '$BUMP' (must be patch, minor or major)"; exit 1 ;;
esac

BUMP_SCRIPT="$ACTION_PATH/scripts/bump-$VERSION_FORMAT.sh"
if [[ ! -f "$BUMP_SCRIPT" ]]; then
  AVAILABLE=$(find "$ACTION_PATH/scripts" -name 'bump-*.sh' -exec basename {} \; \
    | sed 's/^bump-//; s/\.sh$//' | sort | paste -sd, -)
  echo "::error::Unsupported version-format '$VERSION_FORMAT'. Available: $AVAILABLE"
  exit 1
fi
