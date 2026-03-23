# Claude Code HP Status Line ⚔❤

A gaming-inspired status line for [Claude Code](https://claude.com/claude-code) that displays your usage limits as game-style health bars.

## Themes

### RPG (default)
```
⚔ Opus ↑H  ❤ 5h [█████████░░░░░░] 65%  ❤ 7d [████░░░░░░░░░░░] 28%  🧠 ▮▮▮▮▯▯▯▯▯▯ 42%  💰 $2.80  +87/-12
```

### Bloom
```
🌱 Opus 🔴  5h 🌸🌸🌸🌸🌸·········· 35%  7d 🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸····· 72%  🍄 🌸🌸🌸🌸······ 42%  🌕 $2.80  +87/-12
```

## What it shows

- **Model + Effort** — Current model and effort level
  - RPG: ↑H / ~M / ↓L
  - Bloom: 🔴 / 🟡 / 🔵
- **5h / 7d** — Usage bars for 5-hour and 7-day rolling windows (Pro/Max only)
  - 🟢 Green: safe
  - 🟡 Yellow: moderate
  - 🔴 Red: slow down!
- **Context** — Context window usage (🧠 or 🍄)
- **Cost** — Session cost in USD. For Pro/Max subscribers, this shows the **equivalent API cost** of your session — a fun way to see how much value you're getting from your subscription
- **+N/-N** — Lines of code added/removed this session

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
