---
description: Update statusline-hp.sh to the latest published release
---

Run the following bash commands to update the statusline script in place,
then refresh the cached latest-version file so the update badge clears:

```bash
set -euo pipefail
REPO="https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main"
DEST="${HOME}/.claude/statusline-hp.sh"
CACHE="${HOME}/.claude/cache/statusline-hp.latest-version"

# Backup current script before overwriting
[ -f "$DEST" ] && cp "$DEST" "${DEST}.bak"

# Download new script + refresh version cache
curl -fsSL -o "$DEST" "${REPO}/statusline-hp.sh"
chmod +x "$DEST"
mkdir -p "$(dirname "$CACHE")"
curl -fsSL -o "$CACHE" "${REPO}/VERSION"

# Show installed + latest version for confirmation
grep -E '^STATUSLINE_HP_VERSION=' "$DEST" | head -1
echo "latest: $(cat "$CACHE")"
```

After it finishes, the next time the statusline redraws (send any new prompt)
the `📦 sl→X.Y.Z` badge will disappear, confirming the upgrade succeeded.

If anything looks wrong, the previous version is preserved at
`~/.claude/statusline-hp.sh.bak`.
