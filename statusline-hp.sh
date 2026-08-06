#!/bin/bash
# Themed status line for Claude Code
# Reads JSON from stdin, displays game-style status bars
# No external dependencies — uses python3 (pre-installed on macOS/most Linux)
#
# Themes: "rpg" (default), "bloom"
# Set theme in ~/.claude/settings.json:  "env": { "STATUSLINE_THEME": "bloom" }

# Bump on each release; the companion update-check hook compares this
# against the latest VERSION file on GitHub.
STATUSLINE_HP_VERSION="0.8.0"
export STATUSLINE_HP_VERSION

input=$(cat)

# Subagent panel mode (point the subagentStatusLine setting at this same
# script). Claude Code pipes a tasks[] payload; we emit one {"id","content"}
# JSON line per task and exit. The substring probe is only a cheap gate —
# Python confirms tasks is a real list, so a literal "tasks" string elsewhere
# in a main payload cannot hijack main mode. Python exit 0 = subagent payload
# handled (output may be empty; undecorated rows fall back to Claude Code
# defaults); exit 1 = not a subagent payload, fall through to the main flow.
if [[ "$input" == *'"tasks"'* ]]; then
  if subagent_out=$(INPUT="$input" python3 -c '
import json, os, sys, time

try:
    d = json.loads(os.environ.get("INPUT", "{}"))
except:
    sys.exit(1)

tasks = d.get("tasks")
if not isinstance(tasks, list):
    sys.exit(1)

theme = os.environ.get("STATUSLINE_THEME", "")
if not theme:
    try:
        with open(os.path.expanduser("~/.claude/settings.json")) as f:
            theme = (json.load(f).get("env") or {}).get("STATUSLINE_THEME", "")
    except:
        pass
bloom = theme == "bloom"

RESET = "\033[0m"; BOLD = "\033[1m"; WHITE = "\033[97m"
CYAN = "\033[36m"; GRAY = "\033[90m"
MAGENTA = "\033[35m"; BRIGHT_RED = "\033[91m"; BRIGHT_YELLOW = "\033[93m"
RED = "\033[31m"; YELLOW = "\033[33m"; REVERSE = "\033[7m"
if bloom:
    DONE = {"completed": "\U0001F338", "failed": "\U0001F940", "killed": "\U0001F940"}
    RUN = "\U0001F331"; WAIT = "\U0001F4A4"; CLOCK = "⏱"
    SPARK = ["\U0001F331", "\U0001F33F", "\U0001F338", "\U0001F33C"]; SPARK_N = 4
    EFFORTS = {
        "max": "⚫", "xhigh": "\U0001F7E3", "high": "\U0001F534",
        "medium": "\U0001F7E1", "low": "\U0001F535",
    }
    EFFORT_STYLES = {"max": "", "xhigh": "", "high": "", "medium": "", "low": ""}
else:
    DONE = {"completed": "\U0001F480", "failed": "☠", "killed": "☠"}
    RUN = "⚔"; WAIT = "⏳"; CLOCK = "♔"
    SPARK = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]; SPARK_N = 8
    EFFORTS = {
        "max": "★", "xhigh": "⇈", "high": "↑", "medium": "~", "low": "↓",
    }
    EFFORT_STYLES = {
        "max": REVERSE + BOLD + MAGENTA, "xhigh": BOLD + MAGENTA,
        "high": BRIGHT_RED, "medium": BRIGHT_YELLOW, "low": GRAY,
    }

WAITING = ("queued", "waiting", "idle", "awaiting_approval", "awaiting approval")

def compact(n):
    try:
        n = float(n)
    except:
        return "0"
    if n >= 1000000:
        return f"{n/1000000:.1f}M"
    if n >= 1000:
        return f"{n/1000:.1f}k"
    return str(int(n))

def spark(samples):
    # tokenSamples = recent token totals (~5s apart); plot the growth deltas
    if not isinstance(samples, list) or len(samples) < 2:
        return ""
    deltas = []
    for a, b in zip(samples, samples[1:]):
        try:
            deltas.append(max(0.0, float(b) - float(a)))
        except:
            deltas.append(0.0)
    deltas = deltas[-SPARK_N:]
    hi = max(deltas)
    if hi <= 0:
        return SPARK[0] * len(deltas)
    return "".join(SPARK[int(x / hi * (len(SPARK) - 1) + 0.5)] for x in deltas)

def elapsed(start_ms):
    try:
        secs = int(time.time() - float(start_ms) / 1000.0)
    except:
        return ""
    if secs < 0:
        return ""
    m, s = divmod(secs, 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}h{m:02d}m"
    if m > 0:
        return f"{m}m{s:02d}s"
    return f"{s}s"

MODEL_SHORTS = ("fable", "opus", "sonnet", "haiku")

def short_model(v):
    # Normalise a model id or alias to a short display name.
    # Values arrive as either a full id (claude-haiku-4-5-20251001) or an alias (haiku).
    if not isinstance(v, str):
        return ""
    s = v.strip().lower()
    if not s or s == "inherit":
        return ""
    for name in MODEL_SHORTS:
        if name in s:
            return name
    return s[:12]

def effort_badge(v):
    # Per-task reasoning effort: either a level string or a numeric token budget.
    # Absent means the subagent inherits the session level, so render nothing.
    if isinstance(v, bool) or v is None:
        return ""
    if isinstance(v, (int, float)):
        return f"{GRAY} {compact(v)}{RESET}"
    if not isinstance(v, str):
        return ""
    s = v.strip()
    if not s:
        return ""
    lvl = s.lower()
    if lvl in EFFORTS:
        return f"{EFFORT_STYLES[lvl]}{EFFORTS[lvl]}{RESET}"
    try:
        return f"{GRAY} {compact(float(s))}{RESET}"
    except (TypeError, ValueError):
        return ""

def token_color(count, size):
    # Colour the token count by context usage, using the same thresholds as the
    # main row context bar. Missing or non-positive window size means no colour.
    try:
        size = float(size)
        count = float(count)
    except (TypeError, ValueError):
        return ""
    if size <= 0:
        return ""
    pct = int(count * 100 / size)
    if pct >= 90:
        return RED
    if pct >= 70:
        return YELLOW
    return CYAN

for t in tasks:
    try:
        tid = t.get("id")
        if not isinstance(tid, str) or not tid:
            continue
        status = str(t.get("status") or "").lower()
        if status in DONE:
            glyph = DONE[status]
        elif status in WAITING:
            glyph = WAIT
        else:
            glyph = RUN
        name = t.get("name") or t.get("label") or t.get("description") or t.get("type") or "agent"
        parts = [glyph, f"{BOLD}{WHITE}{str(name)}{RESET}"]
        sm = short_model(t.get("model"))
        if sm:
            parts[-1] += f"{GRAY}·{sm}{RESET}"
        eb = effort_badge(t.get("effort"))
        if eb:
            parts[-1] += eb
        sp = spark(t.get("tokenSamples"))
        if sp:
            parts.append(sp if bloom else f"{CYAN}{sp}{RESET}")
        tc = t.get("tokenCount") or 0
        tcol = token_color(tc, t.get("contextWindowSize"))
        parts.append(f"{tcol}{compact(tc)}{RESET}" if tcol else compact(tc))
        el = elapsed(t.get("startTime"))
        if el:
            parts.append(f"{GRAY}{CLOCK}{el}{RESET}")
        print(json.dumps({"id": tid, "content": " ".join(parts)}, ensure_ascii=False))
    except:
        continue
'); then
    printf '%s\n' "$subagent_out"
    exit 0
  fi
fi

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

def is_cooldown(v):
    if v is None: return 0
    try:
        return 1 if float(v) >= 100.0 else 0
    except (TypeError, ValueError):
        return 0

is_5h_cooldown = is_cooldown(five_h)
is_7d_cooldown = is_cooldown(seven_d)

def trunc_pct(v):
    if v is None: return ""
    try:
        return str(int(float(v)))  # truncate toward zero
    except (TypeError, ValueError):
        return ""
five_h_int = trunc_pct(five_h)
seven_d_int = trunc_pct(seven_d)

cost = g(d, "cost", "total_cost_usd")
lines_add = g(d, "cost", "total_lines_added") or 0
lines_del = g(d, "cost", "total_lines_removed") or 0
version = g(d, "version") or ""
vim_mode = g(d, "vim", "mode") or ""
agent_name = g(d, "agent", "name") or ""
output_style = g(d, "output_style", "name") or ""
session_name = g(d, "session_name") or ""
wt_name = g(d, "worktree", "name") or g(d, "workspace", "git_worktree") or ""
# Branch only available under worktree.* (not workspace.git_worktree fallback)
wt_branch = g(d, "worktree", "branch") or ""
added_dirs = g(d, "workspace", "added_dirs") or []
added_count = len(added_dirs) if isinstance(added_dirs, list) else 0
pr_number = g(d, "pr", "number")
pr_url = g(d, "pr", "url") or ""
pr_review = (g(d, "pr", "review_state") or "").lower()
# pr.kind is undocumented but emitted (verified 2.1.201); "cr" = remote code review
pr_kind = (g(d, "pr", "kind") or "").lower()
def pos_int(v):
    try:
        n = int(v)
        return n if n > 0 else 0
    except (TypeError, ValueError):
        return 0
pr_num_int = pos_int(pr_number)
cwd = g(d, "workspace", "current_dir") or g(d, "cwd") or ""
home = os.path.expanduser("~")
repo_owner = g(d, "workspace", "repo", "owner") or ""
repo_name = g(d, "workspace", "repo", "name") or ""
if repo_owner and repo_name:
    # Repo identity beats directory basename (checkout dir names can drift)
    workspace_dir = f"{repo_owner}/{repo_name}"
elif cwd == home:
    workspace_dir = "~"
elif cwd:
    workspace_dir = os.path.basename(cwd)
else:
    workspace_dir = ""
api_dur = fmt_ms(g(d, "cost", "total_api_duration_ms"))
wall_dur = fmt_ms(g(d, "cost", "total_duration_ms"))
exceeds_200k = 1 if g(d, "exceeds_200k_tokens") else 0
fast_mode = 1 if g(d, "fast_mode") else 0

cu = g(d, "context_window", "current_usage") or {}
cr = cu.get("cache_read_input_tokens") or 0
cc = cu.get("cache_creation_input_tokens") or 0
it = cu.get("input_tokens") or 0
_cache_total = cr + cc + it
cache_pct = int(cr * 100 / _cache_total) if _cache_total > 0 else -1

ctx_size = g(d, "context_window", "context_window_size") or 0
is_1m_ctx = 1 if ctx_size >= 1_000_000 else 0
thinking_on = 1 if g(d, "thinking", "enabled") else 0

# Live effort from spec (reflects mid-session /effort changes). Claude Code
# emits effort.level only for effort-capable models, so absence means the
# session is not running effort — display nothing. settings.json effortLevel
# is the default for NEW sessions, never live state, so it is not a fallback.
effort = (g(d, "effort", "level") or "").lower()
theme_file = ""
try:
    with open(os.path.expanduser("~/.claude/settings.json")) as f:
        s = json.load(f)
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

# Self-update check for the statusline script itself.
# The companion SessionStart hook (hooks/check-update.sh) periodically writes
# the latest published VERSION to this cache file. We compare to our own
# embedded version and flag if newer.
sl_installed_version = os.environ.get("STATUSLINE_HP_VERSION", "")
sl_latest_version = ""
try:
    with open(os.path.expanduser("~/.claude/cache/statusline-hp.latest-version")) as f:
        sl_latest_version = f.read().strip()
except:
    pass
sl_needs_update = 1 if (sl_installed_version and sl_latest_version and parse_v(sl_installed_version) < parse_v(sl_latest_version)) else 0

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
print(f"WALL_TIME=\"{wall_dur}\"")
print(f"EXCEEDS_200K={exceeds_200k}")
print(f"FAST_MODE={fast_mode}")
print(f"CACHE_PCT={cache_pct}")
print(f"THEME_FILE=\"{sh(theme_file)}\"")
print(f"IS_1M_CTX={is_1m_ctx}")
print(f"THINKING_ON={thinking_on}")
print(f"OUTPUT_STYLE=\"{sh(output_style)}\"")
print(f"SESSION_NAME=\"{sh(session_name)}\"")
print(f"WORKTREE_NAME=\"{sh(wt_name)}\"")
print(f"WORKTREE_BRANCH=\"{sh(wt_branch)}\"")
print(f"ADDED_COUNT={added_count}")
print(f"PR_NUMBER={pr_num_int}")
print(f"PR_URL=\"{sh(pr_url)}\"")
print(f"PR_REVIEW=\"{sh(pr_review)}\"")
print(f"PR_KIND=\"{sh(pr_kind)}\"")
print(f"WORKSPACE_DIR=\"{sh(workspace_dir)}\"")
print(f"SL_LATEST_VERSION=\"{sh(sl_latest_version)}\"")
print(f"SL_NEEDS_UPDATE={sl_needs_update}")
print(f"IS_5H_COOLDOWN={is_5h_cooldown}")
print(f"IS_7D_COOLDOWN={is_7d_cooldown}")
print(f"FIVE_H_INT=\"{five_h_int}\"")
print(f"SEVEN_D_INT=\"{seven_d_int}\"")
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
    EFFORT_MAX="⚫ max"
    EFFORT_XHIGH="🟣 xhigh"
    EFFORT_HIGH="🔴 high"
    EFFORT_MED="🟡 medium"
    EFFORT_LOW="🔵 low"
    EFFORT_MAX_STYLE="\033[7m"
    EFFORT_XHIGH_STYLE=""
    EFFORT_HIGH_STYLE=""
    EFFORT_MED_STYLE=""
    EFFORT_LOW_STYLE=""
    FAST_TEXT="🐝 fast"
    FAST_STYLE=""
    CAST_ICON="🌿"
    STYLE_ICON="🌻"
    COOLDOWN_ICON="💤"
    PR_ICON="🌷"
    BAR_INVERTED=1       # flowers = used, dots = remaining
    ;;
  *)
    # RPG theme (default)
    MODEL_ICON="⚔"
    BAR_FILL="█"
    BAR_EMPTY="░"
    CTX_ICON="🧠"
    COST_ICON="💰"
    EFFORT_MAX="★max"
    EFFORT_XHIGH="⇈xhigh"
    EFFORT_HIGH="↑high"
    EFFORT_MED="~medium"
    EFFORT_LOW="↓low"
    EFFORT_MAX_STYLE="\033[7m${BOLD}${MAGENTA}"
    EFFORT_XHIGH_STYLE="${BOLD}${MAGENTA}"
    EFFORT_HIGH_STYLE="${BRIGHT_RED}"
    EFFORT_MED_STYLE="${BRIGHT_YELLOW}"
    EFFORT_LOW_STYLE="${GRAY}"
    FAST_TEXT="⏩fast"
    FAST_STYLE="${BOLD}${BRIGHT_GREEN}"
    CAST_ICON="🔮"
    STYLE_ICON="📖"
    COOLDOWN_ICON="⏳"
    PR_ICON="🔀"
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
  local reset_icon=${5:-↻}

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
  [ -n "$reset_time" ] && reset_str=" ${GRAY}${reset_icon}${reset_time}${RESET}"

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

# Build output — split into two rows for responsive multi-line
parts_row1=""
parts_row2=""

# Model name + effort level (purely payload-driven — no model-name mask;
# effort-less models like Haiku simply never receive effort.level)
EFFORT_ICON=""
if [ -n "$EFFORT" ]; then
  # Case-insensitive match so "Max"/"max"/"MAX" all work
  case "${EFFORT,,}" in
    max)    EFFORT_ICON="${EFFORT_MAX_STYLE}${EFFORT_MAX}${RESET}" ;;
    xhigh)  EFFORT_ICON="${EFFORT_XHIGH_STYLE}${EFFORT_XHIGH}${RESET}" ;;
    high)   EFFORT_ICON="${EFFORT_HIGH_STYLE}${EFFORT_HIGH}${RESET}" ;;
    medium) EFFORT_ICON="${EFFORT_MED_STYLE}${EFFORT_MED}${RESET}" ;;
    low)    EFFORT_ICON="${EFFORT_LOW_STYLE}${EFFORT_LOW}${RESET}" ;;
  esac
fi

parts_row1+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ "${IS_1M_CTX:-0}" = "1" ] && parts_row1+="${CYAN}[1M]${RESET}"
[ "${THINKING_ON:-0}" = "1" ] && parts_row1+=" ${MAGENTA}💭${RESET}"
if [ -n "$WORKSPACE_DIR" ]; then
  if [ "${ADDED_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    parts_row1+=" ${CYAN}📁 ${WORKSPACE_DIR}+${ADDED_COUNT}${RESET}"
  else
    parts_row1+=" ${CYAN}📁 ${WORKSPACE_DIR}${RESET}"
  fi
fi
[ -n "$SESSION_NAME" ] && parts_row1+=" ${GRAY}#${SESSION_NAME}${RESET}"
if [ -n "$WORKTREE_NAME" ]; then
  parts_row1+=" ${GREEN}🌳${WORKTREE_NAME}${RESET}"
  [ -n "$WORKTREE_BRANCH" ] && parts_row1+="${GRAY}⎇${WORKTREE_BRANCH}${RESET}"
fi
# PR badge — open PR for the current branch (pr.* fields)
if [ "${PR_NUMBER:-0}" -gt 0 ] 2>/dev/null; then
  # Remote code-review sessions get a magnifier regardless of theme
  [ "$PR_KIND" = "cr" ] && PR_ICON="🔍"
  case "$PR_REVIEW" in
    approved)          pr_glyph="✓"; pr_color="$BRIGHT_GREEN" ;;
    pending)           pr_glyph="…"; pr_color="$BRIGHT_YELLOW" ;;
    changes_requested) pr_glyph="✗"; pr_color="$BRIGHT_RED" ;;
    draft)             pr_glyph="✎"; pr_color="$GRAY" ;;
    *)                 pr_glyph="";  pr_color="$CYAN" ;;
  esac
  pr_text="${PR_ICON}#${PR_NUMBER}${pr_glyph}"
  if [ -n "$PR_URL" ]; then
    # OSC 8 hyperlink: ESC ] 8 ;; URL ST  <visible>  ESC ] 8 ;; ST   (ST = ESC backslash)
    # ST is written \033\\\\ (not \033\\): in this double-quoted string that yields
    # the literal bytes \033\\ , so echo -e consumes BOTH backslashes into ESC+\ and
    # leaves the following colour escape (\033[..m) intact. With only \033\\ the ST
    # steals the colour escape lead and the colour prints as literal text.
    parts_row1+=" \033]8;;${PR_URL}\033\\\\${pr_color}${pr_text}${RESET}\033]8;;\033\\\\"
  else
    parts_row1+=" ${pr_color}${pr_text}${RESET}"
  fi
fi
[ -n "$AGENT_NAME" ] && parts_row1+="${GRAY}·${AGENT_NAME}${RESET}"
[ -n "$EFFORT_ICON" ] && parts_row1+=" ${EFFORT_ICON}"
[ "${FAST_MODE:-0}" = "1" ] && parts_row1+=" ${FAST_STYLE}${FAST_TEXT}${RESET}"
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  parts_row1+=" ${CYAN}${STYLE_ICON}${OUTPUT_STYLE}${RESET}"
fi

# Vim mode
if [ -n "$VIM_MODE" ]; then
  parts_row1+="  ${GRAY}⌨${VIM_MODE:0:1}${RESET}"
fi

# Usage bars (only if available — API users won't have these)
if [ -n "$FIVE_H" ]; then
  fh_icon="↻"; [ "${IS_5H_COOLDOWN:-0}" = "1" ] && fh_icon="$COOLDOWN_ICON"
  parts_row2+="  $(status_bar "${FIVE_H_INT:-0}" 15 "$LABEL_5H" "$FH_RESET" "$fh_icon")"
fi

if [ -n "$SEVEN_D" ]; then
  sd_icon="↻"; [ "${IS_7D_COOLDOWN:-0}" = "1" ] && sd_icon="$COOLDOWN_ICON"
  parts_row2+="  $(status_bar "${SEVEN_D_INT:-0}" 15 "$LABEL_7D" "$SD_RESET" "$sd_icon")"
fi

# Context window
parts_row2+="  $(ctx_bar "$CTX")"

# Cache hit ratio
if [ "${CACHE_PCT:-"-1"}" -ge 0 ] 2>/dev/null; then
  if [ "$CACHE_PCT" -ge 70 ]; then cache_color="$BRIGHT_GREEN"
  elif [ "$CACHE_PCT" -ge 30 ]; then cache_color="$BRIGHT_YELLOW"
  else cache_color="$BRIGHT_RED"; fi
  parts_row2+=" ${cache_color}⚡${CACHE_PCT}%${RESET}"
fi

# 200k threshold: exceeds_200k_tokens is a fixed 200k flag regardless of
# window size, so in a 1M window it means the >200k pricing tier (2x rate),
# not "almost full" — show a yellow cost hint there instead of a red alarm.
if [ "${EXCEEDS_200K:-0}" = "1" ]; then
  if [ "${IS_1M_CTX:-0}" = "1" ]; then
    parts_row2+=" ${BRIGHT_YELLOW}💰200k+${RESET}"
  else
    parts_row2+=" ${BRIGHT_RED}⚠200k${RESET}"
  fi
fi

# API casting time
if [ -n "$API_DURATION" ]; then
  parts_row2+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}"
  [ -n "$WALL_TIME" ] && parts_row2+="/${WALL_TIME}"
  parts_row2+="${RESET}"
fi

# Cost
if [ -n "$COST" ]; then
  parts_row2+="  ${MAGENTA}${COST_ICON} \$${COST}${RESET}"
fi

# Lines changed
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  parts_row2+="  ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"
fi

# Version (highlight if newer release available)
if [ -n "$VERSION" ]; then
  if [ "${NEEDS_UPDATE:-0}" = "1" ]; then
    # Yellow background, black text — eye-catching but not alarming
    parts_row2+="  \033[43m\033[30m v${VERSION}→${LATEST_VERSION} \033[0m"
  else
    parts_row2+="  ${GRAY}v${VERSION}${RESET}"
  fi
fi

# Statusline-hp self-update badge (dim cyan box → /statusline-update)
if [ "${SL_NEEDS_UPDATE:-0}" = "1" ]; then
  parts_row2+="  \033[46m\033[30m 📦 sl→${SL_LATEST_VERSION} \033[0m"
fi

# Responsive output: single line if it fits, else 2 rows
if [ -z "$parts_row1" ]; then
  echo -e "$parts_row2"
elif [ -z "$parts_row2" ]; then
  echo -e "$parts_row1"
else
  cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
  # Sanitize: non-numeric values fall back to a safe default (matches spec)
  case "$cols" in
    ''|*[!0-9]*) cols=120 ;;
  esac
  # Fast path: very wide terminal → single line definitely fits, skip measurement
  if [ "$cols" -ge 200 ]; then
    echo -e "${parts_row1}  ${parts_row2}"
  else
    # Measure display width of each row via python3
    widths=$(printf '%s\n%s' "$parts_row1" "$parts_row2" | python3 -c '
import sys, re, unicodedata
# Match both actual ESC byte (\x1b) and literal backslash-0-3-3 (\033)
# Strip OSC 8 hyperlinks first: ESC ]8;; URL ST and ESC ]8;; ST (close). The ST
# carries 1 or 2 trailing backslashes in this pre-echo form, so allow both. The
# bracket is ]8;; (right bracket) so this never touches SGR [..m (left bracket).
# The non-greedy .*? relies on sh() stripping backslashes from PR_URL, so no
# \033 can appear inside the URL and each match stops at the open ST, not the
# close one. If sh() ever stops stripping backslashes, revisit this.
OSC8_RE = re.compile(r"(?:\x1b|\\033)\]8;;.*?(?:\x1b|\\033)\\{1,2}")
ANSI_RE = re.compile(r"(?:\x1b|\\033)\[[0-9;]*m")
def dw(s):
    s = OSC8_RE.sub("", s)
    s = ANSI_RE.sub("", s)
    w = 0
    for ch in s:
        if unicodedata.category(ch).startswith("M"):
            continue
        if unicodedata.east_asian_width(ch) in ("W", "F"):
            w += 2
            continue
        if ord(ch) >= 0x2600:
            w += 2
            continue
        w += 1
    return w
for line in sys.stdin.read().split("\n")[:2]:
    print(dw(line))
' 2>/dev/null)
    row1_w=$(echo "$widths" | sed -n "1p")
    row2_w=$(echo "$widths" | sed -n "2p")
    # Single-line total = row1 + "  " (2 cells) + row2, plus 4 cells safety margin
    total_w=$(( ${row1_w:-0} + ${row2_w:-0} + 2 + 4 ))
    if [ "$total_w" -gt "$cols" ]; then
      echo -e "$parts_row1"
      echo -e "$parts_row2"
    else
      echo -e "${parts_row1}  ${parts_row2}"
    fi
  fi
fi
