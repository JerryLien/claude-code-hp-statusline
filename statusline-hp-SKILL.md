---
name: statustheme
description: Switch status line theme (rpg or bloom)
user_invocable: true
---

# Switch Status Line Theme

The user wants to switch their status line theme.

Available themes:
- `rpg` — Classic RPG health bar style (⚔❤█░)
- `bloom` — Flower garden style (🌱🌸🍄🌕)

## Instructions

1. Read `~/.claude/settings.json`
2. If the user provided an argument (e.g. `/statustheme bloom`), use that as the theme name
3. If no argument, check the current theme and toggle to the other one:
   - If currently `bloom` → switch to `rpg`
   - If currently `rpg` (or unset) → switch to `bloom`
4. Update the `env.STATUSLINE_THEME` value in `~/.claude/settings.json` using the Edit tool
5. Tell the user which theme is now active
