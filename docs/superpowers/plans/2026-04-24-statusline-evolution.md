# Statusline Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 new JSON fields (A1-A4) to the statusline display and polish 2 existing display behaviors (B1-B2), per `docs/superpowers/specs/2026-04-24-statusline-evolution.md`.

**Architecture:** All changes land in `statusline-hp.sh`. The script is a single-file Bash + embedded Python3 parser. New fields are extracted in the Python block as shell-safe variables, then rendered in the Bash section with per-theme icons and conditional visibility. The `status_bar()` function gains an optional reset-icon parameter for cooldown state. Effort styling moves from hard-coded colors to per-theme style variables so RPG and Bloom can diverge.

**Tech Stack:** Bash 4+, Python 3, ANSI escape codes.

**Spec deviation flagged for review:**
Spec §2 states Bloom `max` = bold. Emoji (`⚫`) ignore `\033[1m`, so bold produces no visible change. This plan uses **reverse video** (`\033[7m`) for Bloom `max` to honor the "max is most dramatic" design intent. Reverse video creates a highlighted background block behind the emoji in most terminals. If you prefer to keep strict bold (invisible but spec-accurate), swap the `\033[7m` for `\033[1m` in Task 7.

---

## File Structure

The primary implementation changes land in `/home/jerrylien/src/claude-code-hp-statusline/statusline-hp.sh`. Tests live in `tests/statusline.test.sh` (new file) and documentation in `README.md` is updated in Task 9.

A lightweight test harness is added: `/home/jerrylien/src/claude-code-hp-statusline/tests/statusline.test.sh`. This is a plain Bash script that pipes mock JSON into the statusline and greps the output for expected tokens. No test framework, no dependencies.

---

## Task 1: Test harness scaffolding

**Files:**
- Create: `tests/statusline.test.sh`
- Modify: `.gitignore` (if needed — N/A, new dir)

- [ ] **Step 1: Create the test harness**

Create `tests/statusline.test.sh` with the following contents:

```bash
#!/bin/bash
# Lightweight test harness for statusline-hp.sh
# Usage: ./tests/statusline.test.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline-hp.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

# assert_contains <name> <theme> <json> <pattern>
# Runs statusline with given theme + JSON, checks output contains pattern.
assert_contains() {
  local name=$1 theme=$2 json=$3 pattern=$4
  local output
  output=$(echo "$json" | STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  if echo "$output" | grep -qF "$pattern"; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name"
    echo "  Theme:   $theme"
    echo "  Pattern: $pattern"
    echo "  Output:  $output"
  fi
}

# assert_not_contains <name> <theme> <json> <pattern>
assert_not_contains() {
  local name=$1 theme=$2 json=$3 pattern=$4
  local output
  output=$(echo "$json" | STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  if echo "$output" | grep -qF "$pattern"; then
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name (unexpected match)"
    echo "  Theme:   $theme"
    echo "  Pattern: $pattern"
    echo "  Output:  $output"
  else
    PASS=$((PASS + 1))
    echo "PASS: $name"
  fi
}

# --- Tests go below ---

# Baseline: minimal JSON works (regression)
assert_contains "baseline-rpg" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "Opus"

assert_contains "baseline-bloom" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "Opus"

# --- Summary ---
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failed tests: ${FAILED_NAMES[*]}"
  exit 1
fi
```

- [ ] **Step 2: Make executable and run**

Run:
```bash
chmod +x tests/statusline.test.sh
./tests/statusline.test.sh
```

Expected: Both baseline tests PASS. Exit code 0.

- [ ] **Step 3: Commit**

```bash
git add tests/statusline.test.sh
git commit -m "add lightweight statusline test harness"
```

---

## Task 2: A1 — output_style display

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal: Parse `output_style.name`. Show `📖<name>` (RPG) or `🌻<name>` (Bloom) after effort icon. Skip if value is `"default"` or empty.

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh` before the Summary section:

```bash
# A1 output_style
assert_contains "a1-explanatory-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"output_style":{"name":"explanatory"}}' \
  "📖explanatory"

assert_contains "a1-explanatory-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"output_style":{"name":"explanatory"}}' \
  "🌻explanatory"

assert_not_contains "a1-default-hidden-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"output_style":{"name":"default"}}' \
  "📖"

assert_not_contains "a1-default-hidden-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"output_style":{"name":"default"}}' \
  "🌻"
```

- [ ] **Step 2: Run tests, verify the 4 new tests FAIL**

Run: `./tests/statusline.test.sh`
Expected: 4 new tests (`a1-*`) FAIL. Baselines still PASS.

- [ ] **Step 3: Parse the field in Python**

In `statusline-hp.sh`, locate the block around line 69 (where `agent_name` is extracted) and add after it:

```python
output_style = g(d, "output_style", "name") or ""
```

Then at the print section near the bottom of the Python block (after `print(f"EFFORT_WARNING={effort_warning}")` on line 162), add:

```python
print(f"OUTPUT_STYLE=\"{sh(output_style)}\"")
```

- [ ] **Step 4: Add theme icon variable**

In the `case "$THEME"` block, add to the `bloom)` branch after `CAST_ICON="🌿"`:

```bash
STYLE_ICON="🌻"
```

Add to the `*)` (RPG) branch after `CAST_ICON="🔮"`:

```bash
STYLE_ICON="📖"
```

- [ ] **Step 5: Render the field**

In the model block (around lines 316-320), after the `⚠effort` line:

```bash
[ "${EFFORT_WARNING:-0}" = "1" ] && parts+=" ${BRIGHT_RED}⚠effort${RESET}"
```

Add:

```bash
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  parts+=" ${CYAN}${STYLE_ICON}${OUTPUT_STYLE}${RESET}"
fi
```

- [ ] **Step 6: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All 4 `a1-*` tests PASS. Baselines still PASS.

- [ ] **Step 7: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "add output_style display (A1)"
```

---

## Task 3: A3 — session_name display

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal: Parse `session_name`. Show `#<name>` after the model name, before agent. Hide if absent.

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh`:

```bash
# A3 session_name
assert_contains "a3-session-name" "rpg" \
  '{"model":{"display_name":"Opus"},"session_name":"my-feature"}' \
  "#my-feature"

assert_not_contains "a3-no-session-name" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "#"
```

Note: the second test asserts no `#` appears in baseline. This is safe because baseline output doesn't contain `#`.

- [ ] **Step 2: Run tests, verify `a3-session-name` FAILs**

Run: `./tests/statusline.test.sh`
Expected: `a3-session-name` FAILs, `a3-no-session-name` PASSes (no `#` in current output).

- [ ] **Step 3: Parse the field in Python**

After `output_style = ...` add:

```python
session_name = g(d, "session_name") or ""
```

In the print section add:

```python
print(f"SESSION_NAME=\"{sh(session_name)}\"")
```

- [ ] **Step 4: Render the field**

In the model block, insert after the MODEL line (around line 316) and before the `·AGENT` line:

Current:
```bash
parts+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ -n "$AGENT_NAME" ] && parts+="${GRAY}·${AGENT_NAME}${RESET}"
```

Becomes:
```bash
parts+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ -n "$SESSION_NAME" ] && parts+=" ${GRAY}#${SESSION_NAME}${RESET}"
[ -n "$AGENT_NAME" ] && parts+="${GRAY}·${AGENT_NAME}${RESET}"
```

- [ ] **Step 5: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All `a3-*` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "add session_name display (A3)"
```

---

## Task 4: A4 — worktree display

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal: Parse `worktree.name` with fallback to `workspace.git_worktree`. Show `🌳<name>` after session_name.

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh`:

```bash
# A4 worktree
assert_contains "a4-git-worktree" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"git_worktree":"feature-xyz"}}' \
  "🌳feature-xyz"

assert_contains "a4-worktree-name" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"}}' \
  "🌳wt-x"

# Priority: worktree.name wins over workspace.git_worktree
assert_contains "a4-priority" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"},"workspace":{"git_worktree":"wt-a"}}' \
  "🌳wt-x"

assert_not_contains "a4-priority-loser-absent" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"},"workspace":{"git_worktree":"wt-a"}}' \
  "wt-a"

assert_not_contains "a4-no-worktree" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "🌳"
```

- [ ] **Step 2: Run tests, verify 4 new tests FAIL (the no-worktree one PASSes)**

Run: `./tests/statusline.test.sh`
Expected: `a4-git-worktree`, `a4-worktree-name`, `a4-priority`, `a4-priority-loser-absent` FAIL. `a4-no-worktree` PASSes.

- [ ] **Step 3: Parse the field in Python**

After `session_name = ...` add:

```python
wt_name = g(d, "worktree", "name") or g(d, "workspace", "git_worktree") or ""
```

In the print section add:

```python
print(f"WORKTREE_NAME=\"{sh(wt_name)}\"")
```

- [ ] **Step 4: Render the field**

In the model block, insert after the SESSION_NAME line from Task 3:

```bash
[ -n "$SESSION_NAME" ] && parts+=" ${GRAY}#${SESSION_NAME}${RESET}"
[ -n "$WORKTREE_NAME" ] && parts+=" ${GREEN}🌳${WORKTREE_NAME}${RESET}"
[ -n "$AGENT_NAME" ] && parts+="${GRAY}·${AGENT_NAME}${RESET}"
```

- [ ] **Step 5: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All `a4-*` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "add worktree display (A4)"
```

---

## Task 5: A2 — total_duration_ms (wall time)

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal: Parse `cost.total_duration_ms`. Append `/⏱<time>` (RPG) or `/🕰<time>` (Bloom) to the existing API duration display when wall time > 0.

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh`:

```bash
# A2 wall time
# API=2m14s=134000ms, Wall=45m=2700000ms
assert_contains "a2-wall-time-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "/⏱45m"

assert_contains "a2-wall-time-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "/🕰45m"

# No wall time → no /⏱ suffix
assert_not_contains "a2-no-wall" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "/⏱"

# API time still shown without wall
assert_contains "a2-api-still-shown" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "🔮 2m14s"
```

- [ ] **Step 2: Run tests, verify the 2 `/⏱` and `/🕰` tests FAIL**

Run: `./tests/statusline.test.sh`
Expected: `a2-wall-time-rpg` and `a2-wall-time-bloom` FAIL. Others PASS.

- [ ] **Step 3: Parse the field in Python**

Near where `api_dur = fmt_ms(g(d, "cost", "total_api_duration_ms"))` is set (around line 70), add after it:

```python
wall_dur = fmt_ms(g(d, "cost", "total_duration_ms"))
```

In the print section, add:

```python
print(f"WALL_TIME=\"{wall_dur}\"")
```

- [ ] **Step 4: Add theme icon**

In the `bloom)` branch add after `STYLE_ICON="🌻"`:

```bash
WALL_ICON="🕰"
```

In the `*)` (RPG) branch add after `STYLE_ICON="📖"`:

```bash
WALL_ICON="⏱"
```

- [ ] **Step 5: Modify API duration render**

Locate the existing line (around line 356):

```bash
if [ -n "$API_DURATION" ]; then
  parts+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}${RESET}"
fi
```

Replace with:

```bash
if [ -n "$API_DURATION" ]; then
  parts+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}"
  [ -n "$WALL_TIME" ] && parts+="/${WALL_ICON}${WALL_TIME}"
  parts+="${RESET}"
fi
```

- [ ] **Step 6: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All `a2-*` tests PASS.

- [ ] **Step 7: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "add wall clock time alongside API duration (A2)"
```

---

## Task 6: B1 — cooldown icon at 100%

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal: When `used_percentage >= 100.0` (strict float compare), replace `↻` with `⏳` (RPG) or `💤` (Bloom) in the reset-time suffix. Apply to both 5h and 7d bars.

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh`:

```bash
# B1 cooldown icon at 100%
assert_contains "b1-7d-cooldown-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":100.0,"resets_at":9999999999}}}' \
  "⏳"

assert_contains "b1-7d-cooldown-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":100.0,"resets_at":9999999999}}}' \
  "💤"

assert_contains "b1-5h-cooldown-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":100.0,"resets_at":9999999999}}}' \
  "⏳"

# 99.99% should NOT trigger cooldown
assert_not_contains "b1-99-percent-no-cooldown" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":99.99,"resets_at":9999999999}}}' \
  "⏳"

# Normal 7d bar still shows ↻
assert_contains "b1-7d-normal-rotate" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":50.0,"resets_at":9999999999}}}' \
  "↻"
```

- [ ] **Step 2: Run tests, verify 3 new tests FAIL**

Run: `./tests/statusline.test.sh`
Expected: `b1-7d-cooldown-rpg`, `b1-7d-cooldown-bloom`, `b1-5h-cooldown-rpg` FAIL. Others PASS.

- [ ] **Step 3: Compute cooldown flags in Python**

Near the rate-limit parsing (around line 61), after `sd_reset = g(d, "rate_limits", "seven_day", "resets_at")`, add:

```python
def is_cooldown(v):
    if v is None: return 0
    try:
        return 1 if float(v) >= 100.0 else 0
    except (TypeError, ValueError):
        return 0

is_5h_cooldown = is_cooldown(five_h)
is_7d_cooldown = is_cooldown(seven_d)
```

In the print section, add:

```python
print(f"IS_5H_COOLDOWN={is_5h_cooldown}")
print(f"IS_7D_COOLDOWN={is_7d_cooldown}")
```

- [ ] **Step 4: Add theme icon**

In the `bloom)` branch after `WALL_ICON="🕰"`:

```bash
COOLDOWN_ICON="💤"
```

In the `*)` (RPG) branch after `WALL_ICON="⏱"`:

```bash
COOLDOWN_ICON="⏳"
```

- [ ] **Step 5: Extend status_bar() to accept a custom reset icon**

Locate the `status_bar()` function (around line 231). Change the parameter parsing:

Current:
```bash
status_bar() {
  local used_pct=${1:-0}
  local width=${2:-20}
  local label=$3
  local reset_time=$4
```

Replace with:
```bash
status_bar() {
  local used_pct=${1:-0}
  local width=${2:-20}
  local label=$3
  local reset_time=$4
  local reset_icon=${5:-↻}
```

Then change the `reset_str` line:

Current:
```bash
  [ -n "$reset_time" ] && reset_str=" ${GRAY}↻${reset_time}${RESET}"
```

Replace with:
```bash
  [ -n "$reset_time" ] && reset_str=" ${GRAY}${reset_icon}${reset_time}${RESET}"
```

- [ ] **Step 6: Pass cooldown icon to each bar**

Locate the 5h and 7d rendering (around lines 328-336):

Current:
```bash
if [ -n "$FIVE_H" ]; then
  five_int=$(printf "%.0f" "$FIVE_H" 2>/dev/null || echo "0")
  parts+="  $(status_bar "$five_int" 15 "$LABEL_5H" "$FH_RESET")"
fi

if [ -n "$SEVEN_D" ]; then
  seven_int=$(printf "%.0f" "$SEVEN_D" 2>/dev/null || echo "0")
  parts+="  $(status_bar "$seven_int" 15 "$LABEL_7D" "$SD_RESET")"
fi
```

Replace with:
```bash
if [ -n "$FIVE_H" ]; then
  five_int=$(printf "%.0f" "$FIVE_H" 2>/dev/null || echo "0")
  fh_icon="↻"; [ "${IS_5H_COOLDOWN:-0}" = "1" ] && fh_icon="$COOLDOWN_ICON"
  parts+="  $(status_bar "$five_int" 15 "$LABEL_5H" "$FH_RESET" "$fh_icon")"
fi

if [ -n "$SEVEN_D" ]; then
  seven_int=$(printf "%.0f" "$SEVEN_D" 2>/dev/null || echo "0")
  sd_icon="↻"; [ "${IS_7D_COOLDOWN:-0}" = "1" ] && sd_icon="$COOLDOWN_ICON"
  parts+="  $(status_bar "$seven_int" 15 "$LABEL_7D" "$SD_RESET" "$sd_icon")"
fi
```

- [ ] **Step 7: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All `b1-*` tests PASS.

- [ ] **Step 8: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "show cooldown icon when rate limit hits 100% (B1)"
```

---

## Task 7: B2 — effort xhigh/max gradient

**Files:**
- Modify: `statusline-hp.sh`
- Modify: `tests/statusline.test.sh`

Goal:
- RPG: `high` unchanged · `xhigh` = bold + magenta · `max` = reverse + bold + magenta
- Bloom: `high` unchanged · `xhigh` unchanged · `max` = reverse video (spec deviation: bold is invisible on emoji; see plan header)

- [ ] **Step 1: Add failing tests**

Add to `tests/statusline.test.sh`:

```bash
# B2 effort gradient
# RPG max: expect \033[7m (reverse) AND \033[1m (bold) AND ★M in sequence
assert_contains "b2-rpg-max-reverse" "rpg" \
  '{"model":{"display_name":"Opus"},"transcript_path":"/nonexistent"}' \
  ""
# The above is a placeholder; real max test needs effort context. See Step 2.
```

This is tricky because effort comes from `settings.json` or transcript, not direct JSON input. Use an alternative approach: set the effort via a temp settings.json override.

Replace the placeholder test with these (uses `CLAUDE_CONFIG_DIR` is NOT supported; the script reads `~/.claude/settings.json` directly). Instead, inject via transcript path is also complex. **Use inline environment override:** the script reads `settings_effort` from `settings.json`. For tests, we'll prefer transcript-based effort which requires a mock transcript file.

Simpler: create a temp dir with a settings.json, then override HOME for the test.

Add these helpers ABOVE the `# --- Tests go below ---` line (so they're defined before use):

```bash
# Helper: run statusline with custom effort via temp HOME
run_with_effort() {
  local effort=$1 theme=$2 json=$3
  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.claude"
  echo "{\"effortLevel\":\"$effort\"}" > "$tmp/.claude/settings.json"
  echo "$json" | HOME="$tmp" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1
  rm -rf "$tmp"
}

# assert_contains_effort <name> <effort> <theme> <json> <pattern>
assert_contains_effort() {
  local name=$1 effort=$2 theme=$3 json=$4 pattern=$5
  local output
  output=$(run_with_effort "$effort" "$theme" "$json")
  if echo "$output" | grep -qF "$pattern"; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name"
    echo "  Output:  $output"
  fi
}

# assert_not_contains_effort <name> <effort> <theme> <json> <pattern>
assert_not_contains_effort() {
  local name=$1 effort=$2 theme=$3 json=$4 pattern=$5
  local output
  output=$(run_with_effort "$effort" "$theme" "$json")
  if echo "$output" | grep -qF "$pattern"; then
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name (unexpected match)"
    echo "  Output:  $output"
  else
    PASS=$((PASS + 1))
    echo "PASS: $name"
  fi
}
```

Add these tests to the bottom of the test section:

```bash
# RPG max: reverse video \033[7m should appear
assert_contains_effort "b2-rpg-max-reverse" "max" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

# RPG xhigh: bold \033[1m appears, but NOT reverse \033[7m
assert_contains_effort "b2-rpg-xhigh-bold" "xhigh" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[1m'

assert_not_contains_effort "b2-rpg-xhigh-no-reverse" "xhigh" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

# RPG high: no bold and no reverse (regression — high should look as before)
assert_not_contains_effort "b2-rpg-high-no-bold" "high" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[1m'

# Bloom max: reverse video
assert_contains_effort "b2-bloom-max-reverse" "max" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

# Bloom xhigh: NO reverse (so we can see the gradient with max)
assert_not_contains_effort "b2-bloom-xhigh-no-reverse" "xhigh" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'
```

- [ ] **Step 2: Run tests, verify relevant tests FAIL**

Run: `./tests/statusline.test.sh`
Expected to FAIL initially (3): `b2-rpg-max-reverse`, `b2-rpg-xhigh-bold`, `b2-bloom-max-reverse` — none of `\033[7m` for max or `\033[1m` for xhigh exist in current code.
Expected to PASS initially (3): `b2-rpg-xhigh-no-reverse`, `b2-rpg-high-no-bold`, `b2-bloom-xhigh-no-reverse` — negative assertions are satisfied by the current "nothing fancy" state.

- [ ] **Step 3: Introduce per-theme effort style variables**

In the `bloom)` branch of the theme `case`, add these new variables (after `EFFORT_LOW="🔵"`):

```bash
EFFORT_MAX_STYLE="\033[7m"
EFFORT_XHIGH_STYLE=""
EFFORT_HIGH_STYLE=""
EFFORT_MED_STYLE=""
EFFORT_LOW_STYLE=""
```

In the `*)` (RPG) branch, add (after `EFFORT_LOW="↓L"`):

```bash
EFFORT_MAX_STYLE="\033[7m${BOLD}${MAGENTA}"
EFFORT_XHIGH_STYLE="${BOLD}${MAGENTA}"
EFFORT_HIGH_STYLE="${BRIGHT_RED}"
EFFORT_MED_STYLE="${BRIGHT_YELLOW}"
EFFORT_LOW_STYLE="${GRAY}"
```

- [ ] **Step 4: Refactor the effort case statement**

Locate the effort case (around lines 307-313):

Current:
```bash
  case "${EFFORT,,}" in
    max)    EFFORT_ICON="${BOLD}${MAGENTA}${EFFORT_MAX}${RESET}" ;;
    xhigh)  EFFORT_ICON="${MAGENTA}${EFFORT_XHIGH}${RESET}" ;;
    high)   EFFORT_ICON="${BRIGHT_RED}${EFFORT_HIGH}${RESET}" ;;
    medium) EFFORT_ICON="${BRIGHT_YELLOW}${EFFORT_MED}${RESET}" ;;
    low)    EFFORT_ICON="${GRAY}${EFFORT_LOW}${RESET}" ;;
  esac
```

Replace with:
```bash
  case "${EFFORT,,}" in
    max)    EFFORT_ICON="${EFFORT_MAX_STYLE}${EFFORT_MAX}${RESET}" ;;
    xhigh)  EFFORT_ICON="${EFFORT_XHIGH_STYLE}${EFFORT_XHIGH}${RESET}" ;;
    high)   EFFORT_ICON="${EFFORT_HIGH_STYLE}${EFFORT_HIGH}${RESET}" ;;
    medium) EFFORT_ICON="${EFFORT_MED_STYLE}${EFFORT_MED}${RESET}" ;;
    low)    EFFORT_ICON="${EFFORT_LOW_STYLE}${EFFORT_LOW}${RESET}" ;;
  esac
```

- [ ] **Step 5: Run tests, verify they PASS**

Run: `./tests/statusline.test.sh`
Expected: All `b2-*` tests PASS.

- [ ] **Step 6: Visual spot check**

Run manually to see the actual terminal rendering:

```bash
tmp=$(mktemp -d) && mkdir -p "$tmp/.claude" \
  && echo '{"effortLevel":"max"}' > "$tmp/.claude/settings.json" \
  && echo '{"model":{"display_name":"Opus"}}' \
     | HOME="$tmp" ./statusline-hp.sh \
  && rm -rf "$tmp"
```

Expected: `★M` appears with a reversed background block in RPG theme.

- [ ] **Step 7: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "strengthen effort xhigh/max visual gradient (B2)"
```

---

## Task 8: Final integration test

**Files:**
- Modify: `tests/statusline.test.sh`

Goal: One end-to-end test with a JSON that exercises **all** new features together, so regressions show up after any future change.

- [ ] **Step 1: Add combined test**

Add to `tests/statusline.test.sh`:

```bash
# Integration: all features together
FULL_JSON='{"model":{"display_name":"Opus"},"session_name":"my-feature","output_style":{"name":"explanatory"},"workspace":{"git_worktree":"wt-abc"},"cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12},"rate_limits":{"five_hour":{"used_percentage":65.0,"resets_at":9999999999},"seven_day":{"used_percentage":100.0,"resets_at":9999999999}}}'

assert_contains "integration-session" "rpg" "$FULL_JSON" "#my-feature"
assert_contains "integration-worktree" "rpg" "$FULL_JSON" "🌳wt-abc"
assert_contains "integration-style" "rpg" "$FULL_JSON" "📖explanatory"
assert_contains "integration-wall" "rpg" "$FULL_JSON" "/⏱45m"
assert_contains "integration-cooldown-7d" "rpg" "$FULL_JSON" "⏳"
assert_contains "integration-rotate-5h" "rpg" "$FULL_JSON" "↻"
assert_contains "integration-bloom-style" "bloom" "$FULL_JSON" "🌻explanatory"
assert_contains "integration-bloom-cooldown" "bloom" "$FULL_JSON" "💤"
```

- [ ] **Step 2: Run tests, verify all PASS**

Run: `./tests/statusline.test.sh`
Expected: All integration tests PASS. Total pass count ≥ all previous counts.

- [ ] **Step 3: Commit**

```bash
git add tests/statusline.test.sh
git commit -m "add integration tests for combined new features"
```

---

## Task 9 (optional): Update README

**Files:**
- Modify: `README.md`

Goal: Document the new features in the existing "What it shows" section. Only do this if the user wants it; otherwise skip.

- [ ] **Step 1: Ask the user whether to update README**

If yes, proceed. If no, skip all remaining steps in this task.

- [ ] **Step 2: Add new features to README**

In the "What it shows" → "Always visible" section, add after Model + Effort:

```markdown
- **Output style** — Current output style when non-default (📖 RPG / 🌻 Bloom)
- **Session name** — `#<name>` when session is named via `--name` or `/rename`
- **Worktree** — `🌳<name>` when working inside a git worktree
- **Wall clock time** — total session time appended after API time (`🔮 2m14s/⏱45m`)
```

In the "Smart alerts" section, add:

```markdown
- **⏳/💤 Cooldown** — Rate limit reset icon changes when at 100% (⏳ RPG / 💤 Bloom), signaling the countdown is to cooldown lift, not a full window reset
- **Effort gradient** — Extreme effort levels stand out more strongly: `high` (default), `xhigh` (bold), `max` (reverse video highlight)
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "document new statusline features in README"
```

---

## Self-Review (completed by plan author)

**Spec coverage:**
- A1 output_style → Task 2 ✓
- A2 total_duration_ms → Task 5 ✓
- A3 session_name → Task 3 ✓
- A4 worktree → Task 4 ✓
- B1 cooldown → Task 6 ✓
- B2 effort gradient → Task 7 ✓
- Testing plan (§4 testing matrix) → tests added incrementally in each task + integration test in Task 8 ✓

**Placeholder scan:** None.

**Type consistency:**
- `STYLE_ICON`, `WALL_ICON`, `COOLDOWN_ICON` defined in theme block, used in render block ✓
- `OUTPUT_STYLE`, `SESSION_NAME`, `WORKTREE_NAME`, `WALL_TIME`, `IS_5H_COOLDOWN`, `IS_7D_COOLDOWN` defined via Python `print`, used in Bash ✓
- `EFFORT_*_STYLE` variables defined in both theme branches with consistent naming ✓
- `status_bar()` new 5th param `reset_icon` consistent between definition and call sites ✓

**Spec deviation note:** Bloom `max` uses reverse video instead of spec's bold — documented in plan header for user review.
