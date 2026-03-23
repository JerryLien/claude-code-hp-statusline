#!/bin/bash
# Themed status line for Claude Code
# Reads JSON from stdin, displays game-style status bars
# No external dependencies — uses python3 (pre-installed on macOS/most Linux)
#
# Themes: "rpg" (default), "bloom"
# Set theme in ~/.claude/settings.json:  "env": { "STATUSLINE_THEME": "bloom" }

input=$(cat)

# Parse all values in one python3 call (no jq needed)
eval "$(INPUT="$input" python3 -c '
import json, os, sys, time

try:
    d = json.loads(os.environ.get("INPUT", "{}"))
except:
    sys.exit(0)

def g(obj, *keys):
    for k in keys:
        if isinstance(obj, dict):
            obj = obj.get(k)
        else:
            return None
    return obj

def fmt_remaining(reset_ts):
    if reset_ts is None:
        return ""
    remaining = int(reset_ts - time.time())
    if remaining <= 0:
        return ""
    h = remaining // 3600
    m = (remaining % 3600) // 60
    if h >= 24:
        return f"{h // 24}d{h % 24}h"
    elif h > 0:
        return f"{h}h{m:02d}m"
    else:
        return f"{m}m"

model = g(d, "model", "display_name") or "Claude"
ctx = int(float(g(d, "context_window", "used_percentage") or 0))
five_h = g(d, "rate_limits", "five_hour", "used_percentage")
seven_d = g(d, "rate_limits", "seven_day", "used_percentage")
fh_reset = g(d, "rate_limits", "five_hour", "resets_at")
sd_reset = g(d, "rate_limits", "seven_day", "resets_at")
cost = g(d, "cost", "total_cost_usd")
lines_add = g(d, "cost", "total_lines_added") or 0
lines_del = g(d, "cost", "total_lines_removed") or 0

effort = ""
try:
    with open(os.path.expanduser("~/.claude/settings.json")) as f:
        effort = json.load(f).get("effortLevel", "")
except:
    pass

fh = five_h if five_h is not None else ""
sd = seven_d if seven_d is not None else ""
c = f"{cost:.4f}" if isinstance(cost, (int, float)) else ""

print(f"MODEL=\"{model}\"")
print(f"CTX={ctx}")
print(f"FIVE_H=\"{fh}\"")
print(f"SEVEN_D=\"{sd}\"")
print(f"FH_RESET=\"{fmt_remaining(fh_reset)}\"")
print(f"SD_RESET=\"{fmt_remaining(sd_reset)}\"")
print(f"COST=\"{c}\"")
print(f"LINES_ADD={lines_add}")
print(f"LINES_DEL={lines_del}")
print(f"EFFORT=\"{effort}\"")
' 2>/dev/null)"

THEME="${STATUSLINE_THEME:-rpg}"

# ANSI colors
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BRIGHT_GREEN='\033[92m'
BRIGHT_YELLOW='\033[93m'
BRIGHT_RED='\033[91m'
CYAN='\033[36m'
WHITE='\033[97m'
GRAY='\033[90m'
MAGENTA='\033[35m'

# Theme configuration
case "$THEME" in
  bloom)
    # Bloom theme — flowers grow as you use more
    MODEL_ICON="🌱"
    BAR_FILL="🌸"
    BAR_EMPTY="·"
    CTX_ICON="🍄"
    COST_ICON="🌕"
    EFFORT_HIGH="🔴"
    EFFORT_MED="🟡"
    EFFORT_LOW="🔵"
    BAR_INVERTED=1       # flowers = used, dots = remaining
    LABEL_5H="5h"
    LABEL_7D="7d"
    ;;
  *)
    # RPG theme (default)
    MODEL_ICON="⚔"
    BAR_FILL="█"
    BAR_EMPTY="░"
    CTX_ICON="🧠"
    COST_ICON="💰"
    EFFORT_HIGH="↑H"
    EFFORT_MED="~M"
    EFFORT_LOW="↓L"
    LABEL_5H="5h"
    LABEL_7D="7d"
    ;;
esac

# Pick color based on usage
pick_color() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then
    echo "$BRIGHT_RED"
  elif [ "$pct" -ge 50 ]; then
    echo "$BRIGHT_YELLOW"
  else
    echo "$BRIGHT_GREEN"
  fi
}

# Build a status bar
status_bar() {
  local used_pct=${1:-0}
  local width=${2:-20}
  local label=$3
  local reset_time=$4

  local hp=$((100 - used_pct))
  local filled=$(( hp * width / 100 ))
  local empty=$(( width - filled ))

  local color
  color=$(pick_color "$used_pct")

  local bar_fill=""
  local bar_empty=""

  local reset_str=""
  [ -n "$reset_time" ] && reset_str=" ${GRAY}↻${reset_time}${RESET}"

  if [ "${BAR_INVERTED:-0}" = "1" ]; then
    # Inverted: flowers = used portion, dots = remaining
    local used_filled=$(( used_pct * width / 100 ))
    local used_empty=$(( width - used_filled ))
    for ((i=0; i<used_filled; i++)); do bar_fill+="$BAR_FILL"; done
    for ((i=0; i<used_empty; i++)); do bar_empty+="$BAR_EMPTY"; done
    printf "${color}${label} ${bar_fill}${GRAY}${bar_empty} ${color}${used_pct}%%${RESET}${reset_str}"
  else
    # RPG: classic block bar, filled = remaining HP
    for ((i=0; i<filled; i++)); do bar_fill+="$BAR_FILL"; done
    for ((i=0; i<empty; i++)); do bar_empty+="$BAR_EMPTY"; done
    printf "${BOLD}${color}❤ ${WHITE}${label} ${color}[${bar_fill}${GRAY}${bar_empty}${color}]${RESET} ${color}${hp}%%${RESET}${reset_str}"
  fi
}

# Context bar
ctx_bar() {
  local pct=${1:-0}
  local width=10
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))

  local color
  if [ "$pct" -ge 90 ]; then color="$RED"
  elif [ "$pct" -ge 70 ]; then color="$YELLOW"
  else color="$CYAN"; fi

  local bar_fill=""
  local bar_empty=""

  if [ "${BAR_INVERTED:-0}" = "1" ]; then
    for ((i=0; i<filled; i++)); do bar_fill+="🌸"; done
    for ((i=0; i<empty; i++)); do bar_empty+="·"; done
    printf "${CTX_ICON} ${color}${bar_fill}${GRAY}${bar_empty} ${color}${pct}%%${RESET}"
  else
    for ((i=0; i<filled; i++)); do bar_fill+="▮"; done
    for ((i=0; i<empty; i++)); do bar_empty+="▯"; done
    printf "${CYAN}${CTX_ICON} ${color}${bar_fill}${GRAY}${bar_empty} ${color}${pct}%%${RESET}"
  fi
}

# Build output
parts=""

# Model name + effort level
EFFORT_ICON=""
if [[ "$MODEL" != *"Haiku"* ]] && [ -n "$EFFORT" ]; then
  if [ "$EFFORT" = "high" ]; then
    EFFORT_ICON="${BRIGHT_RED}${EFFORT_HIGH}${RESET}"
  elif [ "$EFFORT" = "medium" ]; then
    EFFORT_ICON="${BRIGHT_YELLOW}${EFFORT_MED}${RESET}"
  elif [ "$EFFORT" = "low" ]; then
    EFFORT_ICON="${GRAY}${EFFORT_LOW}${RESET}"
  fi
fi

parts+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ -n "$EFFORT_ICON" ] && parts+=" ${EFFORT_ICON}"

# Usage bars (only if available — API users won't have these)
if [ -n "$FIVE_H" ]; then
  five_int=$(printf "%.0f" "$FIVE_H" 2>/dev/null || echo "0")
  parts+="  $(status_bar "$five_int" 15 "$LABEL_5H" "$FH_RESET")"
fi

if [ -n "$SEVEN_D" ]; then
  seven_int=$(printf "%.0f" "$SEVEN_D" 2>/dev/null || echo "0")
  parts+="  $(status_bar "$seven_int" 15 "$LABEL_7D" "$SD_RESET")"
fi

# Context window
parts+="  $(ctx_bar "$CTX")"

# Cost
if [ -n "$COST" ]; then
  parts+="  ${MAGENTA}${COST_ICON} \$${COST}${RESET}"
fi

# Lines changed
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  if [ "$THEME" = "pikmin" ]; then
    parts+="  ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
  else
    parts+="  ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
  fi
fi

echo -e "$parts"
