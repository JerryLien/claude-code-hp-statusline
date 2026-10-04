---
description: Update statusline-hp.sh and its installed companion files to the latest published release
---

Run the following bash commands to update the statusline script in place.
The snippet refuses to downgrade: if the installed script is newer than what
GitHub serves, nothing is overwritten — the usual cause is a local repo that is
ahead of GitHub (push first, then update, or install by copying from the local
repo instead).

It then refreshes the companion files you already installed — the update-check
hook, the usage hook, the `/statustheme` skill, and this command — and never
installs ones you skipped. Each download is validated before it replaces the
old copy; a companion that fails to download or validate is reported and left
as it was.

```bash
set -euo pipefail
REPO="https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main"
DEST="${HOME}/.claude/statusline-hp.sh"
CACHE="${HOME}/.claude/cache/statusline-hp.latest-version"

remote=$(curl -fsSL "${REPO}/VERSION" | tr -d '[:space:]')
[ -n "$remote" ] || { echo "abort: could not fetch remote VERSION"; exit 1; }
installed=$(grep -m1 -oE 'STATUSLINE_HP_VERSION="[0-9.]+"' "$DEST" 2>/dev/null | grep -oE '[0-9.]+' || echo "0")

if [ "$remote" = "$installed" ]; then
  echo "statusline-hp.sh already up to date ($installed)"
else
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
  echo "updated statusline-hp.sh $installed -> $remote"
fi
mkdir -p "$(dirname "$CACHE")"
printf '%s\n' "$remote" > "$CACHE"

# Refresh companion files that are already installed; never install new ones.
# refresh <path in repo> <installed path> <sh|md>
refresh() {
  local src=$1 dest=$2 kind=$3 tmp
  [ -f "$dest" ] || return 0
  tmp=$(mktemp)
  if ! curl -fsSL -o "$tmp" "${REPO}/${src}"; then
    echo "skipped ${dest}: download failed"; rm -f "$tmp"; return 0
  fi
  if [ "$kind" = sh ] && ! bash -n "$tmp" 2>/dev/null; then
    echo "skipped ${dest}: download fails bash -n"; rm -f "$tmp"; return 0
  fi
  if [ "$kind" = md ] && [ "$(head -n 1 "$tmp")" != "---" ]; then
    echo "skipped ${dest}: download has no frontmatter"; rm -f "$tmp"; return 0
  fi
  if cmp -s "$tmp" "$dest"; then
    echo "unchanged ${dest}"; rm -f "$tmp"; return 0
  fi
  if [ "$kind" = sh ]; then chmod 755 "$tmp"; else chmod 644 "$tmp"; fi
  mv "$tmp" "$dest"
  echo "updated ${dest}"
}
refresh hooks/check-update.sh         "${HOME}/.claude/hooks/check-statusline-update.sh" sh
refresh hooks/fetch-usage.sh          "${HOME}/.claude/hooks/fetch-usage.sh"             sh
refresh statusline-hp-SKILL.md        "${HOME}/.claude/skills/statustheme/SKILL.md"      md
refresh commands/statusline-update.md "${HOME}/.claude/commands/statusline-update.md"    md
```

After it finishes, the next time the statusline redraws (send any new prompt)
the `📦 sl→X.Y.Z` badge will disappear, confirming the upgrade succeeded.

If anything looks wrong, the previous script is preserved at
`~/.claude/statusline-hp.sh.bak`. Companion files are not backed up; re-run the
install commands in the README to restore one.
