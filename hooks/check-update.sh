#!/bin/bash
# SessionStart hook: background-fetch the latest statusline-hp.sh VERSION
# from GitHub and cache it for the statusline to compare against.
#
# Designed to never block session startup:
#   - Runs entirely in a detached subshell
#   - Caps fetch at 2 seconds
#   - Skips if the cache was refreshed within the last 6 hours
#   - Always exits 0 (failure here must not block Claude Code)

set -u

CACHE="${HOME}/.claude/cache/statusline-hp.latest-version"
URL="https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/VERSION"

mkdir -p "$(dirname "$CACHE")" 2>/dev/null

# Skip if cache fresh (modified within last 6 hours = 360 minutes).
# `find -mmin +360` returns the file only if older than 360 minutes; empty
# result means it is fresh and we should not re-fetch.
if [ -f "$CACHE" ] && [ -z "$(find "$CACHE" -mmin +360 2>/dev/null)" ]; then
  exit 0
fi

# Detached background fetch so SessionStart never waits on the network.
(
  TMP="${CACHE}.tmp.$$"
  if curl -fsS --max-time 2 "$URL" -o "$TMP" 2>/dev/null; then
    # Strip whitespace and validate it looks like a version (digits.dots).
    v=$(tr -d '[:space:]' < "$TMP")
    if echo "$v" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
      printf '%s\n' "$v" > "$CACHE"
    fi
  fi
  rm -f "$TMP"
) >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
