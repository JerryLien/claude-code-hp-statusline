# Claude Code HP Status Line ⚔❤

A gaming-inspired status line for [Claude Code](https://claude.com/claude-code) that displays your usage limits as game-style health bars.

## Themes

### RPG (default)
```
⚔ Opus ↑H  ❤ 5h [█████████░░░░░░] 65% ↻2h29m  ❤ 7d [████░░░░░░░░░░░] 28% ↻1d4h  🧠 ▮▮▮▮▯▯▯▯▯▯ 42% ⚡87%  🔮 2m14s  💰 $2.80  +87/-12  v2.1.105
```

### Bloom
```
🌱 Opus 🔴  5h 🌸🌸🌸🌸🌸·········· 35% ↻2h29m  7d 🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸····· 72% ↻1d4h  🍄 🌸🌸🌸🌸······ 42% ⚡87%  🌿 2m14s  🌕 $2.80  +87/-12  v2.1.105
```

## What it shows

- **Model + Effort** — Current model and effort level
  - RPG: ↑H / ~M / ↓L
  - Bloom: 🔴 / 🟡 / 🔵
- **5h / 7d** — Usage bars for 5-hour and 7-day rolling windows (Pro/Max only)
  - 🟢 Green: safe
  - 🟡 Yellow: moderate
  - 🔴 Red: slow down!
  - ↻ Countdown to rate limit reset (e.g. `↻2h29m`, `↻1d4h`)
- **Context** — Context window usage (🧠 or 🍄)
- **⚡ Cache hit ratio** — How much of the recent prompt came from the Claude prompt cache. Green ≥70%, yellow ≥30%, red <30% — a great real-time check that caching is actually working
- **⚠200k** — Red warning badge when the session crosses the 200k-token threshold (where per-token pricing goes up)
- **🔮 / 🌿 Casting time** — Total time spent waiting on Claude API responses this session (RPG: 🔮 crystal ball, Bloom: 🌿 growing plant)
- **Cost** — Session cost in USD. For Pro/Max subscribers, this shows the **equivalent API cost** of your session — a fun way to see how much value you're getting from your subscription
- **+N/-N** — Lines of code added/removed this session
- **Version** — Claude Code version. Shows dim gray when up to date, **yellow highlight with `→X.Y.Z`** when a newer release is detected in Claude Code's local changelog cache

### Conditional extras

These only appear when the relevant data is present:

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

Or just paste the gist URL into Claude Code and ask it to set up the status line for you.
