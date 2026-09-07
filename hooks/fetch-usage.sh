#!/bin/bash
# Stop / SessionStart hook: background-fetch model-scoped weekly limits
# (e.g. the Fable weekly cap) from the same OAuth usage endpoint /usage
# reads, and cache them for the statusline to render.
#
# The statusline payload only carries the 5h / 7d windows, so this hook
# fills the gap. Designed to never block Claude Code:
#   - Runs entirely in a detached subshell
#   - Caps the fetch at 5 seconds
#   - Skips if the cache was refreshed within the last minute
#   - Always exits 0
#
# Cache format (~/.claude/cache/usage-limits.json), token-free:
#   [{"label":"Fable","percent":21,"resets_at":1757595600}]

set -u

CACHE="${HOME}/.claude/cache/usage-limits.json"
CREDS="${HOME}/.claude/.credentials.json"
URL="https://api.anthropic.com/api/oauth/usage"

# API-key users have no OAuth credentials -> nothing to fetch.
[ -f "$CREDS" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

mkdir -p "$(dirname "$CACHE")" 2>/dev/null

# Skip if cache fresh (modified within the last minute).
if [ -f "$CACHE" ] && [ -n "$(find "$CACHE" -mmin -1 2>/dev/null)" ]; then
  exit 0
fi

(
  TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["claudeAiOauth"]["accessToken"])' "$CREDS" 2>/dev/null)
  [ -n "$TOKEN" ] || exit 0

  RAW="${CACHE}.raw.$$"
  TMP="${CACHE}.tmp.$$"
  HDR="${CACHE}.hdr.$$"
  # Headers go through a 600 file so the token never appears in `ps`.
  umask 077
  printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\n' "$TOKEN" > "$HDR"
  umask 022

  if curl -fsS --max-time 5 -H "@$HDR" "$URL" -o "$RAW" 2>/dev/null; then
    if python3 - "$RAW" "$TMP" <<'PY'
import json, sys
from datetime import datetime
raw, out = sys.argv[1], sys.argv[2]
d = json.load(open(raw))
rows = []
for lim in d.get("limits") or []:
    if lim.get("kind") != "weekly_scoped":
        continue
    label = (((lim.get("scope") or {}).get("model") or {}).get("display_name")) or ""
    if not label:
        continue
    try:
        pct = int(float(lim.get("percent")))
    except (TypeError, ValueError):
        continue
    reset = None
    r = lim.get("resets_at")
    if isinstance(r, str) and r:
        try:
            reset = int(datetime.fromisoformat(r).timestamp())
        except ValueError:
            reset = None
    rows.append({"label": label, "percent": pct, "resets_at": reset})
with open(out, "w") as f:
    json.dump(rows, f, separators=(",", ":"))
    f.write("\n")
PY
    then
      mv -f "$TMP" "$CACHE"
    fi
  fi
  rm -f "$RAW" "$TMP" "$HDR"
) >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
