# Claude Code HP Status Line ⚔❤

> Turn your [Claude Code](https://claude.com/claude-code) status line into a game HUD. See usage limits as health bars, catch cache-miss regressions instantly, and get a loud heads-up the moment a new release drops.

```
⚔ Opus ↑H  ❤ 5h [█████████░░░░░░] 65% ↻2h29m  ❤ 7d [████░░░░░░░░░░░] 28% ↻1d4h  🧠 ▮▮▮▮▯▯▯▯▯▯ 42% ⚡87%  🔮 2m14s  💰 $2.80  +87/-12  v2.1.105
```

```
🌱 Opus 🔴  5h 🌸🌸🌸🌸🌸·········· 35% ↻2h29m  7d 🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸····· 72% ↻1d4h  🍄 🌸🌸🌸🌸······ 42% ⚡87%  🌿 2m14s  🌕 $2.80  +87/-12  v2.1.105
```

## Why?

The default status line tells you very little. This one turns everything that matters into **at-a-glance HUD elements** so you can stay in flow instead of running `/status`, `/cost`, or `/doctor`. Two themes, zero dependencies beyond `python3`.

## Features

- ❤ **Health-bar rate limits** — 5-hour and 7-day windows with countdown to reset
- 🧠 **Context window meter** — know exactly how much headroom you have
- ⚡ **Cache hit ratio** — realtime feedback that your prompt caching is actually working
- ⚠ **200k threshold alert** — loud warning the moment per-token pricing jumps
- 🔮 **Total casting time** — how long you've been waiting on Claude this session
- 💰 **Session cost** — equivalent API cost, even on Pro/Max subscriptions
- 📈 **Lines changed** — `+/-` counter for edits made in this session
- 🆕 **Update alert** — version number flips to a yellow badge the instant a newer release hits your local changelog cache
- 🎨 **Two themes** — classic RPG (`⚔❤█░`) or peaceful Bloom garden (`🌱🌸🍄🌕`)
- 📏 **Responsive layout** — auto-wraps into 2 rows (identity / metrics) when the terminal is too narrow, stays single-line on wide screens

## What it shows

### Always visible

- **Model + Effort** — Current model and effort level (low / medium / high / xhigh / max). RPG: ↓low / ~medium / ↑high / ⇈xhigh / ★max · Bloom: 🔵 low / 🟡 medium / 🔴 high / 🟣 xhigh / ⚫ max. Reads the live `effort.level` from Claude Code, so mid-session `/effort` changes show up immediately. Falls back to `effortLevel` in `settings.json` for models that don't expose effort
- **[1M] badge** — Cyan `[1M]` next to the model name when the session is running with a 1M-token context window (`context_window.context_window_size >= 1000000`). Hidden for the 200k default
- **💭 Thinking** — Magenta thought-bubble next to the model name when extended thinking is enabled for the session
- **Output style** — Current output style name when set to a non-default value (📖 RPG · 🌻 Bloom)
- **Session name** — `#<name>` when the session was named via `--name` or `/rename`, helpful for juggling multiple sessions
- **Worktree** — `🌳<name>` when working inside a linked git worktree (prefers `worktree.name` from `--worktree` sessions, falls back to `workspace.git_worktree`)
- **Context** — Context window usage (🧠 or 🍄)
- **Cost** — Session cost in USD. For Pro/Max subscribers, this shows the **equivalent API cost** — a fun way to see how much value you're getting from your subscription
- **+N/-N** — Lines of code added/removed this session
- **Version** — Claude Code version, dim gray when up to date

### Pro/Max only

- **5h / 7d** — Rate-limit health bars for the 5-hour and 7-day rolling windows
  - 🟢 Green: safe · 🟡 Yellow: moderate · 🔴 Red: slow down!
  - ↻ Countdown to reset (e.g. `↻2h29m`, `↻1d4h`)

### Smart alerts

- **⚡ Cache hit ratio** — Green ≥70%, yellow ≥30%, red <30%. A great real-time check that prompt caching is actually working
- **⚠ 200k** — Red warning badge when the session crosses the 200k-token threshold (where per-token pricing jumps)
- **🔮 / 🌿 Casting time + wall time** — Total time spent waiting on Claude API responses, followed by total session wall time (e.g. `🔮 2m14s/45m`). RPG: 🔮 crystal ball · Bloom: 🌿 growing plant
- **v2.1.100→2.1.105** — Version badge goes yellow-highlighted with the target version when a newer release is detected in Claude Code's local changelog cache
- **⏳ / 💤 Cooldown** — When a rate limit hits 100%, the reset countdown icon changes (⏳ RPG · 💤 Bloom) to signal the countdown is to cooldown lift, not a full window reset
- **Effort gradient** — Extreme effort levels get progressively stronger visual treatment. RPG: `xhigh` = bold magenta · `max` = reverse-video highlight. Bloom: `max` = reverse-video highlight on the circle (emoji don't respond to bold)

### Conditional extras

Only appear when the relevant data is present:

- **⌨N / ⌨I** — Current vim mode (NORMAL / INSERT), when vim mode is enabled
- **·agent** — Agent name when launched via `--agent`

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
