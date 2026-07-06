---
description: Update statusline-hp.sh to the latest published release
---

Run the following bash commands to update the statusline script in place.
The snippet refuses to downgrade: if the installed script is newer than (or
equal to) what GitHub serves, nothing is overwritten — the usual cause is a
local repo that is ahead of GitHub (push first, then update, or install by
copying from the local repo instead).

```bash
set -euo pipefail
REPO="https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main"
DEST="${HOME}/.claude/statusline-hp.sh"
CACHE="${HOME}/.claude/cache/statusline-hp.latest-version"

remote=$(curl -fsSL "${REPO}/VERSION" | tr -d '[:space:]')
[ -n "$remote" ] || { echo "abort: could not fetch remote VERSION"; exit 1; }
installed=$(grep -m1 -oE 'STATUSLINE_HP_VERSION="[0-9.]+"' "$DEST" 2>/dev/null | grep -oE '[0-9.]+' || echo "0")

if [ "$remote" = "$installed" ]; then
  mkdir -p "$(dirname "$CACHE")"
  printf '%s\n' "$remote" > "$CACHE"
  echo "already up to date ($installed)"
  exit 0
fi

# Downgrade guard: proceed only when remote is strictly newer than installed.
newest=$(printf '%s\n%s\n' "$remote" "$installed" | sort -V | tail -1)
if [ "$newest" != "$remote" ]; then
  echo "abort: remote $remote is older than installed $installed — refusing to downgrade"
  echo "(likely cause: local repo is ahead of GitHub; push first or install from the local repo)"
  exit 1
fi

# Download to a temp path and validate before touching the installed copy.
TMP=$(mktemp)
curl -fsSL -o "$TMP" "${REPO}/statusline-hp.sh"
bash -n "$TMP" || { echo "abort: downloaded script fails bash -n"; rm -f "$TMP"; exit 1; }
grep -q "STATUSLINE_HP_VERSION=\"${remote}\"" "$TMP" || { echo "abort: downloaded script version does not match VERSION ($remote)"; rm -f "$TMP"; exit 1; }

[ -f "$DEST" ] && cp "$DEST" "${DEST}.bak"
mv "$TMP" "$DEST"
chmod +x "$DEST"
mkdir -p "$(dirname "$CACHE")"
printf '%s\n' "$remote" > "$CACHE"
echo "updated $installed -> $remote"
```

After it finishes, the next time the statusline redraws (send any new prompt)
the `📦 sl→X.Y.Z` badge will disappear, confirming the upgrade succeeded.

If anything looks wrong, the previous version is preserved at
`~/.claude/statusline-hp.sh.bak`.
