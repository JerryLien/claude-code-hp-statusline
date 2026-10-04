# Claude Code HP Status Line ⚔❤

> Turn your [Claude Code](https://claude.com/claude-code) status line into a game HUD. See usage limits as health bars, catch cache-miss regressions instantly, and get a loud heads-up the moment a new release drops.

```
⚔ Opus[1M] 📁 my-project ↑high  ❤ 5h [█████████░░░░░░] 65% ↻2h29m  ❤ 7d [████░░░░░░░░░░░] 28% ↻1d4h  🧠 ▮▮▮▮▯▯▯▯▯▯ 42% ⚡87% 3m  🔮 2m14s/45m  💰 $2.80  +87/-12  v2.1.105
```

```
🌱 Opus[1M] 📁 my-project 🔴 high  5h 🌸🌸🌸🌸🌸·········· 35% ↻2h29m  7d 🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸····· 72% ↻1d4h  🍄 🌸🌸🌸🌸······ 42% ⚡87% 3m  🌿 2m14s/45m  🌕 $2.80  +87/-12  v2.1.105
```

## Why?

The default status line tells you very little. This one turns everything that matters into **at-a-glance HUD elements** so you can stay in flow instead of running `/status`, `/cost`, or `/doctor`. Two themes, zero dependencies beyond `python3`.

## Features

- ❤ **Health-bar rate limits** — 5-hour and 7-day windows with countdown to reset
- ❤ **Per-model weekly caps** — a third bar for model-scoped limits such as the Fable weekly cap (needs the optional usage hook, see below)
- 🧠 **Context window meter** — know exactly how much headroom you have
- ⚡ **Cache hit ratio** — realtime feedback that your prompt caching is actually working, plus how long a warm cache has left and a grey `⚡cold` once it expires
- ⚠ **200k threshold alert** — loud warning the moment per-token pricing jumps
- 🔮 **Total casting time** — how long you've been waiting on Claude this session
- 💰 **Session cost** — equivalent API cost, even on Pro/Max subscriptions
- 📈 **Lines changed** — `+/-` counter for edits made in this session
- 🆕 **Update alert** — version number flips to a yellow badge the instant a newer release hits your local changelog cache
- 📁 **Workspace + worktree** — Current dir basename and `--worktree` name always visible
- 🔀 **PR badge** — Open PR for the current branch with review-state glyph + colour, click-to-open via OSC 8 link
- 💭 / **[1M]** **Model state indicators** — Shows `💭off` when extended thinking is turned off, and `[1M]` when running with a 1M-token context window
- ⏩ / 🐝 **Fast mode** — Badge appears next to the effort level when Opus fast mode (`/fast`) is on
- 🎨 **Two themes** — classic RPG (`⚔❤█░`) or peaceful Bloom garden (`🌱🌸🍄🌕`)
- 📏 **Responsive layout** — auto-wraps into 2 rows (identity / metrics) when the terminal is too narrow, stays single-line on wide screens

## What it shows

### Always visible

- **Model + Effort** — Current model and effort level (low / medium / high / xhigh / max). RPG: ↓low / ~medium / ↑high / ⇈xhigh / ★max · Bloom: 🔵 low / 🟡 medium / 🔴 high / 🟣 xhigh / ⚫ max. Reads the live `effort.level` from Claude Code, so mid-session `/effort` changes show up immediately
- **[1M] badge** — Cyan `[1M]` next to the model name when the session is running with a 1M-token context window (`context_window.context_window_size >= 1000000`). Hidden for the 200k default
- **💭off Thinking off** — Grey `💭off` next to the model name when extended thinking is turned off. Nothing is shown while it is on: Claude Code reports thinking as on for every model that cannot turn it off (Fable 5.1, Opus 5.5), so an "on" badge would never go out
- **Output style** — Current output style name when set to a non-default value (📖 RPG · 🌻 Bloom)
- **Session name** — `#<name>` when the session was named via `--name` or `/rename`, helpful for juggling multiple sessions
- **Worktree** — `🌳<name>` when working inside a linked git worktree (prefers `worktree.name` from `--worktree` sessions, falls back to `workspace.git_worktree`). Appends `⎇<branch>` in dim gray when the worktree's git branch is known
- **Added dirs** — `+N` after the workspace dir name when extra directories are mounted via `/add-dir` (e.g., `📁 myproj+2` = working in `myproj` with 2 extra dirs in scope)
- **Context** — Context window usage (🧠 or 🍄)
- **Cost** — Session cost in USD. For Pro/Max subscribers, this shows the **equivalent API cost** — a fun way to see how much value you're getting from your subscription
- **+N/-N** — Lines of code added/removed this session
- **Version** — Claude Code version, dim gray when up to date

### Pro/Max only

- **5h / 7d** — Rate-limit health bars for the 5-hour and 7-day rolling windows
  - 🟢 Green: safe · 🟡 Yellow: moderate · 🔴 Red: slow down!
  - ↻ Countdown to reset (e.g. `↻2h29m`, `↻1d4h`)
- **Fable / per-model bars** — One more bar per model-scoped weekly cap, labelled with the model name, same colours and cooldown icon as 7d. Needs the optional usage hook (see [Per-model weekly caps](#per-model-weekly-caps-optional))

### Smart alerts

- **⚡ Cache hit ratio** — Green ≥70%, yellow ≥30%, red <30%. A great real-time check that prompt caching is actually working. With Claude Code 2.1.251+ (`prompt_cache`), a warm cache adds its time to expiry in grey (`⚡87% 3m`, `<1m` in the last minute), and once it has gone cold the ratio is replaced by a grey `⚡cold`: the next request writes the whole context to the cache again. Claude Code re-runs the statusline the moment the cache expires; set `refreshInterval` so the countdown keeps moving while idle
- **⚠ 200k** — Red warning badge when the session crosses the 200k-token threshold (where per-token pricing jumps)
- **🔮 / 🌿 Casting time + wall time** — Total time spent waiting on Claude API responses, followed by total session wall time (e.g. `🔮 2m14s/45m`). RPG: 🔮 crystal ball · Bloom: 🌿 growing plant
- **v2.1.100→2.1.105** — Version badge goes yellow-highlighted with the target version when a newer release is detected in Claude Code's local changelog cache
- **⏳ / 💤 Cooldown** — When a rate limit hits 100%, the reset countdown icon changes (⏳ RPG · 💤 Bloom) to signal the countdown is to cooldown lift, not a full window reset
- **Effort gradient** — Extreme effort levels get progressively stronger visual treatment. RPG: `xhigh` = bold magenta · `max` = reverse-video highlight. Bloom: `max` = reverse-video highlight on the circle (emoji don't respond to bold)

### Conditional extras

Only appear when the relevant data is present:

- **⌨N / ⌨I** — Current vim mode (NORMAL / INSERT), when vim mode is enabled
- **·agent** — Agent name when launched via `--agent`
- **⏩fast / 🐝 fast — Fast mode** — Appears right after the effort level when Opus fast mode is enabled (`/fast`, the `fast_mode` field). RPG renders `⏩fast` in bold bright-green; Bloom renders `🐝 fast` flat. Hidden when fast mode is off — and naturally absent on models that don't report it (Claude Code only sends it truthy for Opus)
- **🔀#1234✓ / 🌷#1234✓ PR badge** — Open PR for the current branch (`pr.number`), placed right after the worktree block. Glyph + colour encode `pr.review_state`: `✓` approved (green), `…` pending (yellow), `✗` changes_requested (red), `✎` draft (grey); neutral cyan with no glyph when the review state is absent or unrecognised. When `pr.url` is set the badge is a clickable OSC 8 hyperlink (and the hidden URL is excluded from the responsive width calculation). Remote code-review sessions (`pr.kind: "cr"`) swap the icon to `🔍` in both themes. GitLab merge requests (`pr.kind: "mr"`, Claude Code 2.1.234+, needs an authenticated `glab`) render as `🔀!42`, matching GitLab numbering
- **📁 owner/repo** — When Claude Code reports the repository identity (`workspace.repo.owner` + `.name`), the directory badge shows `owner/name` instead of the checkout directory basename

## Subagent status line

Since 0.7.0 the same script also renders the per-subagent rows in the agent
panel. Point the `subagentStatusLine` setting at it — the script auto-detects
the `tasks[]` payload and switches modes:

```json
{
  "statusLine":        { "type": "command", "command": "~/.claude/statusline-hp.sh" },
  "subagentStatusLine": { "type": "command", "command": "~/.claude/statusline-hp.sh" }
}
```

Each running subagent gets a themed row: status glyph (RPG `⚔` running / `💀`
completed / `☠` failed; Bloom `🌱` / `🌸` / `🥀`), agent name, the model short
name and reasoning effort, a token-burn sparkline built from the recent
`tokenSamples` history (`▂▃▅█` in RPG, flower stages in Bloom), the compact
token total, and elapsed time. Rows the script cannot render fall back to
Claude Code's default rendering automatically.

Since 0.8.0 each row also carries three per-task details:

- **`·model`** — the task model as a short name (`·haiku`, `·sonnet`, `·opus`,
  `·fable`). An unrecognised model id shows the value lower-cased and
  truncated to 12 characters; the segment is omitted when the field is
  absent or `inherit`.
- **Effort symbol** — the task reasoning effort as `★` max, `⇈` xhigh, `↑` high,
  `~` medium, `↓` low in RPG (`⚫🟣🔴🟡🔵` in Bloom), coloured to match the main
  row. A numeric token budget renders compact in grey. Nothing renders when the
  subagent inherits the session effort. Requires Claude Code 2.1.214 or later.
- **Token colour** — the token total is coloured by context usage
  (`tokenCount / contextWindowSize`) on the same thresholds as the main row
  context bar: cyan below 70%, yellow from 70%, red from 90%. Rows without
  `contextWindowSize` stay uncoloured.

## Field compatibility notes

Every field this script consumes is in the official statusline schema docs
(checked against the docs and Claude Code v2.1.289), with one exception:

- **`pr.kind: "cr"`** — drives the `🔍` code-review PR icon. The docs only list
  `"mr"` (GitLab merge request); `"cr"` was seen by inspecting v2.1.201 and may
  change without notice

If the `🔍` icon silently disappears after a Claude Code upgrade, this value is
the first thing to re-verify.

A third thing worth tracking is a payload-shape divergence rather than a
missing field (verified against Claude Code 2.1.223):

- **Reasoning effort** — the main status-line payload nests it as an object
  (`effort.level`), while the subagent `tasks[]` payload carries the same
  concept flat (`tasks[].effort`). Both shapes are handled today. If a future
  release normalises the task field to the object form, the per-task effort
  badge would silently stop rendering rather than error — worth re-checking
  alongside the two fields above after any Claude Code upgrade.

## Requirements

- `python3` (pre-installed on macOS and most Linux distros)
- No other dependencies needed

## Install

```bash
# Download status line script
curl -o ~/.claude/statusline-hp.sh \
  https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/statusline-hp.sh \
  && chmod +x ~/.claude/statusline-hp.sh

# Download theme switcher skill (optional)
mkdir -p ~/.claude/skills/statustheme
curl -o ~/.claude/skills/statustheme/SKILL.md \
  https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/statusline-hp-SKILL.md
```

Add to `~/.claude/settings.json`:

> **Note:** `~` is not expanded in settings.json. Use `$HOME` or the full absolute path.

```json
{
  "statusLine": {
    "type": "command",
    "command": "$HOME/.claude/statusline-hp.sh"
  }
}
```

## Recommended settings

Two `~/.claude/settings.json` tweaks make this status line behave better:

```json
{
  "hideVimModeIndicator": true,
  "refreshInterval": 10
}
```

- **`hideVimModeIndicator`** — This script renders its own `⌨N` / `⌨I` vim
  indicator, so hide Claude Code's built-in `-- INSERT --` line to avoid showing
  the mode twice.
- **`refreshInterval`** — This script shows live rate-limit reset countdowns
  (`↻2h29m`). Setting a refresh interval (seconds) keeps them ticking while the
  session is idle instead of freezing until your next action.

## Stay up to date (optional)

Opt in to a non-intrusive update notification: a cyan `📦 sl→X.Y.Z` badge appears
on the statusline when a newer release is published, and `/statusline-update`
upgrades in place.

**1.** Drop the update-check hook + `/statusline-update` slash command into your config:

```bash
# Hook that background-fetches the latest VERSION on session start
mkdir -p ~/.claude/hooks
curl -fsSL -o ~/.claude/hooks/check-statusline-update.sh \
  https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/hooks/check-update.sh
chmod +x ~/.claude/hooks/check-statusline-update.sh

# Slash command that performs the upgrade in place
mkdir -p ~/.claude/commands
curl -fsSL -o ~/.claude/commands/statusline-update.md \
  https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/commands/statusline-update.md
```

**2.** Wire the hook in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/check-statusline-update.sh" }
        ]
      }
    ]
  }
}
```

The hook caps the network call at 2 seconds, runs detached so session start is
never blocked, and skips entirely if the cache was refreshed within the last
6 hours. If GitHub is unreachable it silently no-ops — the statusline keeps
working as if the feature was off.

**3.** When the badge appears, type `/statusline-update` and Claude will run the
upgrade for you. The previous version is kept at `~/.claude/statusline-hp.sh.bak`.

The same run refreshes the companion files you already installed: both hooks,
the `/statustheme` skill, and the `/statusline-update` command itself. Files you
never installed stay uninstalled, and each download must pass `bash -n` (hooks)
or start with frontmatter (skill, command) before it replaces the old copy.

> **Upgrading from 0.9.1 or earlier:** the old command only updates the script.
> Re-run the `curl` for `commands/statusline-update.md` from step 1 once, then
> run `/statusline-update`; later releases refresh everything on their own.

## Per-model weekly caps (optional)

Claude.ai plans carry model-scoped weekly limits on top of the 5h / 7d windows —
today that is the Fable weekly cap, shown by `/usage` as its own row. The
statusline payload does not include it, so a small hook fetches it from the same
OAuth usage endpoint `/usage` reads and caches just the numbers. When present the
statusline draws one more health bar after `7d`, labelled with the model name:

```
❤ 5h [█████████████░░] 96% ↻1h56m  ❤ 7d [█████████████░░] 88% ↻3d22h  ❤ Fable [███████████░░░░] 78% ↻3d22h
```

**1.** Install the hook:

```bash
mkdir -p ~/.claude/hooks
curl -fsSL -o ~/.claude/hooks/fetch-usage.sh \
  https://raw.githubusercontent.com/JerryLien/claude-code-hp-statusline/main/hooks/fetch-usage.sh
chmod +x ~/.claude/hooks/fetch-usage.sh
```

**2.** Wire it to `Stop` (refresh after every turn) and `SessionStart` in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/fetch-usage.sh", "async": true } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$HOME/.claude/hooks/fetch-usage.sh", "async": true } ] }
    ]
  }
}
```

The hook reads the OAuth token from `~/.claude/.credentials.json`, sends it only
to `api.anthropic.com`, and writes a token-free cache
(`~/.claude/cache/usage-limits.json`: `label`, `percent`, `resets_at`). It runs
detached, caps the request at 5 seconds, makes at most one request a minute and
none for 5 minutes after a failed one (the endpoint rate-limits logins, and
Claude Code's own `/usage` reads it too), and silently no-ops for API-key users
or when the network is down — the bar
simply stays hidden. The percentage updates when a turn ends; the reset countdown
is live. Any future per-model cap Anthropic adds shows up as another bar with no
script change.

## Switch theme

Use the `/statustheme` slash command to toggle between themes:

```
/statustheme          # toggle between rpg and bloom
/statustheme bloom    # switch to bloom
/statustheme rpg      # switch to rpg
```

Or manually set `STATUSLINE_THEME` in `~/.claude/settings.json`:

```json
{
  "env": {
    "STATUSLINE_THEME": "bloom"
  }
}
```

Available themes: `rpg` (default), `bloom`

## Bonus: Bloom spinner verbs

Add to `~/.claude/settings.json` for a full bloom experience:

```json
{
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": [
      "Plucking seedlings",
      "Growing sprouts",
      "Planting flowers",
      "Battling mushroom",
      "Collecting nectar",
      "Tossing squad",
      "Blooming petals",
      "Gathering pellets",
      "Sprouting buds",
      "Marching forward"
    ]
  }
}
```

Or just paste this repo URL into Claude Code and ask it to set up the status line for you.
