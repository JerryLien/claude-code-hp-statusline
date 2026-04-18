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

def fmt_ms(ms):
    if not isinstance(ms, (int, float)) or ms <= 0:
        return ""
    s = int(ms / 1000)
    h, rem = s // 3600, s % 3600
    m, ss = rem // 60, rem % 60
    if h > 0:
        return f"{h}h{m:02d}m"
    if m > 0:
        return f"{m}m{ss:02d}s"
    return f"{ss}s"

def sh(v):
    return str(v).translate({ord(c): None for c in "\"\\$`\n"})

model = g(d, "model", "display_name") or "Claude"
ctx = int(float(g(d, "context_window", "used_percentage") or 0))
five_h = g(d, "rate_limits", "five_hour", "used_percentage")
seven_d = g(d, "rate_limits", "seven_day", "used_percentage")
fh_reset = g(d, "rate_limits", "five_hour", "resets_at")
sd_reset = g(d, "rate_limits", "seven_day", "resets_at")
cost = g(d, "cost", "total_cost_usd")
lines_add = g(d, "cost", "total_lines_added") or 0
lines_del = g(d, "cost", "total_lines_removed") or 0
version = g(d, "version") or ""
vim_mode = g(d, "vim", "mode") or ""
agent_name = g(d, "agent", "name") or ""
api_dur = fmt_ms(g(d, "cost", "total_api_duration_ms"))
exceeds_200k = 1 if g(d, "exceeds_200k_tokens") else 0

cu = g(d, "context_window", "current_usage") or {}
cr = cu.get("cache_read_input_tokens") or 0
cc = cu.get("cache_creation_input_tokens") or 0
it = cu.get("input_tokens") or 0
_cache_total = cr + cc + it
cache_pct = int(cr * 100 / _cache_total) if _cache_total > 0 else -1

effort = ""
theme_file = ""
try:
    with open(os.path.expanduser("~/.claude/settings.json")) as f:
        s = json.load(f)
        effort = s.get("effortLevel", "")
        theme_file = (s.get("env") or {}).get("STATUSLINE_THEME", "")
except:
    pass

# Latest version from the Claude Code changelog cache
latest_version = ""
try:
    with open(os.path.expanduser("~/.claude/cache/changelog.md")) as f:
        for line in f:
            if line.startswith("## "):
                latest_version = line[3:].strip()
                break
except:
    pass

def parse_v(v):
    try:
        return tuple(int(x) for x in v.split("."))
    except:
        return ()

needs_update = 1 if (version and latest_version and parse_v(version) < parse_v(latest_version)) else 0

fh = five_h if five_h is not None else ""
sd = seven_d if seven_d is not None else ""
c = f"{cost:.4f}" if isinstance(cost, (int, float)) else ""

print(f"MODEL=\"{sh(model)}\"")
print(f"CTX={ctx}")
print(f"FIVE_H=\"{fh}\"")
print(f"SEVEN_D=\"{sd}\"")
print(f"FH_RESET=\"{fmt_remaining(fh_reset)}\"")
print(f"SD_RESET=\"{fmt_remaining(sd_reset)}\"")
print(f"COST=\"{c}\"")
print(f"LINES_ADD={lines_add}")
print(f"LINES_DEL={lines_del}")
print(f"EFFORT=\"{effort}\"")
print(f"VERSION=\"{sh(version)}\"")
print(f"LATEST_VERSION=\"{sh(latest_version)}\"")
print(f"NEEDS_UPDATE={needs_update}")
print(f"VIM_MODE=\"{sh(vim_mode)}\"")
print(f"AGENT_NAME=\"{sh(agent_name)}\"")
print(f"API_DURATION=\"{api_dur}\"")
print(f"EXCEEDS_200K={exceeds_200k}")
print(f"CACHE_PCT={cache_pct}")
print(f"THEME_FILE=\"{sh(theme_file)}\"")
' 2>/dev/null)"

THEME="${STATUSLINE_THEME:-${THEME_FILE:-rpg}}"

# ANSI colors
BOLD='\033[1m'
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

# Labels shared across themes
LABEL_5H="5h"
LABEL_7D="7d"

# Theme configuration
case "$THEME" in
  bloom)
    # Bloom theme — flowers grow as you use more
    MODEL_ICON="🌱"
    BAR_FILL="🌸"
    BAR_EMPTY="·"
    CTX_ICON="🍄"
    COST_ICON="🌕"
    EFFORT_MAX="⚫"
    EFFORT_XHIGH="🟣"
    EFFORT_HIGH="🔴"
    EFFORT_MED="🟡"
    EFFORT_LOW="🔵"
    CAST_ICON="🌿"
    BAR_INVERTED=1       # flowers = used, dots = remaining
    ;;
  *)
    # RPG theme (default)
    MODEL_ICON="⚔"
    BAR_FILL="█"
    BAR_EMPTY="░"
    CTX_ICON="🧠"
    COST_ICON="💰"
    EFFORT_MAX="★M"
    EFFORT_XHIGH="⇈X"
    EFFORT_HIGH="↑H"
    EFFORT_MED="~M"
    EFFORT_LOW="↓L"
    CAST_ICON="🔮"
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

  # Clamp to [0, 100]
  [ "$used_pct" -lt 0 ] && used_pct=0
  [ "$used_pct" -gt 100 ] && used_pct=100

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

  # Clamp to [0, 100]
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100

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
  # Case-insensitive match so "Max"/"max"/"MAX" all work
  case "${EFFORT,,}" in
    max)    EFFORT_ICON="${BOLD}${MAGENTA}${EFFORT_MAX}${RESET}" ;;
    xhigh)  EFFORT_ICON="${MAGENTA}${EFFORT_XHIGH}${RESET}" ;;
    high)   EFFORT_ICON="${BRIGHT_RED}${EFFORT_HIGH}${RESET}" ;;
    medium) EFFORT_ICON="${BRIGHT_YELLOW}${EFFORT_MED}${RESET}" ;;
    low)    EFFORT_ICON="${GRAY}${EFFORT_LOW}${RESET}" ;;
  esac
fi

parts+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ -n "$AGENT_NAME" ] && parts+="${GRAY}·${AGENT_NAME}${RESET}"
[ -n "$EFFORT_ICON" ] && parts+=" ${EFFORT_ICON}"

# Vim mode
if [ -n "$VIM_MODE" ]; then
  parts+="  ${GRAY}⌨${VIM_MODE:0:1}${RESET}"
fi

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

# Cache hit ratio
if [ "${CACHE_PCT:-"-1"}" -ge 0 ] 2>/dev/null; then
  if [ "$CACHE_PCT" -ge 70 ]; then cache_color="$BRIGHT_GREEN"
  elif [ "$CACHE_PCT" -ge 30 ]; then cache_color="$BRIGHT_YELLOW"
  else cache_color="$BRIGHT_RED"; fi
  parts+=" ${cache_color}⚡${CACHE_PCT}%${RESET}"
fi

# 200k threshold warning
if [ "${EXCEEDS_200K:-0}" = "1" ]; then
  parts+=" ${BRIGHT_RED}⚠200k${RESET}"
fi

# API casting time
if [ -n "$API_DURATION" ]; then
  parts+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}${RESET}"
fi

# Cost
if [ -n "$COST" ]; then
  parts+="  ${MAGENTA}${COST_ICON} \$${COST}${RESET}"
fi

# Lines changed
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  parts+="  ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
fi

# Version (highlight if newer release available)
if [ -n "$VERSION" ]; then
  if [ "${NEEDS_UPDATE:-0}" = "1" ]; then
    # Yellow background, black text — eye-catching but not alarming
    parts+="  \033[43m\033[30m v${VERSION}→${LATEST_VERSION} \033[0m"
  else
    parts+="  ${GRAY}v${VERSION}${RESET}"
  fi
fi

echo -e "$parts"
