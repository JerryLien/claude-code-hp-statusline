# Responsive Multi-line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `statusline-hp.sh` auto-wrap into 2 rows when terminal is narrow, using precise display-width calculation; also drop ⏱/🕰 wall-time icons that cause East Asian Width overlap.

**Architecture:** All changes land in `statusline-hp.sh` + `tests/statusline.test.sh`. Three tasks, each TDD:
1. Drop wall-time icons (smallest, independent change)
2. Refactor single `parts` variable into `parts_row1` (identity) + `parts_row2` (metrics), preserving current single-line output
3. Add Python `display_width()` helper, read `COLUMNS`/`tput cols`, decide single vs multi-line

**Tech Stack:** Bash 4+, Python 3 (`re`, `unicodedata` stdlib only).

---

## File Structure

Only two files change:
- `/home/jerrylien/src/claude-code-hp-statusline/statusline-hp.sh`
- `/home/jerrylien/src/claude-code-hp-statusline/tests/statusline.test.sh`

README update is bundled into Task 3.

---

## Task 1: Drop wall-time icons

**Files:**
- Modify: `statusline-hp.sh` (wall time render block + theme WALL_ICON removal)
- Modify: `tests/statusline.test.sh` (update a2 tests)

Goal: Remove `⏱` (RPG) and `🕰` (Bloom) from the wall-time segment; keep `/` as separator. `🔮 2m14s/⏱45m` → `🔮 2m14s/45m`.

- [ ] **Step 1: Update failing tests to new expected format**

In `tests/statusline.test.sh`, locate the existing A2 tests:

```bash
assert_contains "a2-wall-time-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "/⏱45m"

assert_contains "a2-wall-time-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "/🕰45m"

assert_not_contains "a2-no-wall" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "/⏱"
```

Replace with:

```bash
assert_contains "a2-wall-time-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "2m14s/45m"

assert_contains "a2-wall-time-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "2m14s/45m"

assert_not_contains "a2-no-wall" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "/45m"

# New negative tests: ensure old icons removed
assert_not_contains "a2-no-stopwatch-icon" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "⏱"

assert_not_contains "a2-no-pendulum-icon" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "🕰"
```

Also update the integration test's expected pattern. Locate:

```bash
assert_contains "integration-wall" "rpg" "$FULL_JSON" "/⏱45m"
```

Replace with:

```bash
assert_contains "integration-wall" "rpg" "$FULL_JSON" "/45m"
```

- [ ] **Step 2: Run tests — some should FAIL**

Run:
```bash
cd /home/jerrylien/src/claude-code-hp-statusline && ./tests/statusline.test.sh
```

Expected FAILs (old icons still in output): `a2-no-stopwatch-icon`, `a2-no-pendulum-icon`.
The two positive tests (`a2-wall-time-rpg/bloom`) may also FAIL because current output is `/⏱45m` which doesn't contain `2m14s/45m` as substring.

- [ ] **Step 3: Update statusline-hp.sh render**

Find the render block (search for `CAST_ICON`):

```bash
if [ -n "$API_DURATION" ]; then
  parts+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}"
  [ -n "$WALL_TIME" ] && parts+="/${WALL_ICON}${WALL_TIME}"
  parts+="${RESET}"
fi
```

Replace with:

```bash
if [ -n "$API_DURATION" ]; then
  parts+="  ${MAGENTA}${CAST_ICON} ${API_DURATION}"
  [ -n "$WALL_TIME" ] && parts+="/${WALL_TIME}"
  parts+="${RESET}"
fi
```

- [ ] **Step 4: Remove the now-unused WALL_ICON variables**

In the theme `case "$THEME"` block, remove both lines:

```bash
# bloom)
WALL_ICON="🕰"

# *)
WALL_ICON="⏱"
```

Delete them entirely (they're no longer referenced).

- [ ] **Step 5: Run tests — all should PASS**

```bash
./tests/statusline.test.sh
```

Expected: all 37 tests pass (36 existing − 2 updated a2 + 2 new no-icon tests + integration-wall updated).

- [ ] **Step 6: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "drop wall-time icons to fix east asian width overlap"
```

---

## Task 2: Split `parts` into `parts_row1` + `parts_row2`

**Files:**
- Modify: `statusline-hp.sh`

Goal: Refactor the render block to use two separate part variables (identity vs metrics) while preserving current single-line output. Lays groundwork for Task 3. **No behavior change.** All 37 tests must continue to pass.

The split follows §1 of the spec:
- **Row 1 (identity):** model + session_name + worktree + agent + effort + ⚠effort + style + vim
- **Row 2 (metrics):** 5h + 7d + context + cache + ⚠200k + API/wall time + cost + lines + version

- [ ] **Step 1: Verify all 37 tests pass before starting**

```bash
cd /home/jerrylien/src/claude-code-hp-statusline && ./tests/statusline.test.sh
```

Expected: 37 pass, 0 fail.

- [ ] **Step 2: Rename `parts=""` and split into two variables**

Locate:
```bash
# Build output
parts=""
```

Replace with:
```bash
# Build output — split into two rows for responsive multi-line
parts_row1=""
parts_row2=""
```

- [ ] **Step 3: Reassign all `parts+=...` lines to the correct row**

Systematically replace each `parts+=` with `parts_row1+=` or `parts_row2+=` based on the logical grouping.

**Row 1 block** (starts after `EFFORT_ICON=""` setup; these all operate on model/identity info):

Current:
```bash
parts+="${BOLD}${WHITE}${MODEL_ICON} ${MODEL}${RESET}"
[ -n "$SESSION_NAME" ] && parts+=" ${GRAY}#${SESSION_NAME}${RESET}"
[ -n "$WORKTREE_NAME" ] && parts+=" ${GREEN}🌳${WORKTREE_NAME}${RESET}"
[ -n "$AGENT_NAME" ] && parts+="${GRAY}·${AGENT_NAME}${RESET}"
[ -n "$EFFORT_ICON" ] && parts+=" ${EFFORT_ICON}"
# Loud warning: /model output in transcript didn't match expected format
[ "${EFFORT_WARNING:-0}" = "1" ] && parts+=" ${BRIGHT_RED}⚠effort${RESET}"
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  parts+=" ${CYAN}${STYLE_ICON}${OUTPUT_STYLE}${RESET}"
fi

# Vim mode
if [ -n "$VIM_MODE" ]; then
  parts+="  ${GRAY}⌨${VIM_MODE:0:1}${RESET}"
fi
```

Replace `parts+=` with `parts_row1+=` on every line in this block (9 occurrences).

**Row 2 block** (5h, 7d, context, cache, 200k, API/wall, cost, lines, version):

Everything from `if [ -n "$FIVE_H" ]; then` down to the version block — replace all `parts+=` with `parts_row2+=`.

- [ ] **Step 4: Replace final `echo -e "$parts"` with combined row output**

Locate the very last line:
```bash
echo -e "$parts"
```

Replace with:
```bash
# Output: single line for now (multi-line decision added in next task)
if [ -z "$parts_row1" ]; then
  echo -e "$parts_row2"
elif [ -z "$parts_row2" ]; then
  echo -e "$parts_row1"
else
  echo -e "${parts_row1}  ${parts_row2}"
fi
```

- [ ] **Step 5: Run tests — all 37 should still pass (no behavior change)**

```bash
./tests/statusline.test.sh
```

Expected: 37 pass, 0 fail.

- [ ] **Step 6: Manual sanity check**

Run with a full JSON mock and visually compare:

```bash
echo '{"model":{"display_name":"Opus"},"session_name":"demo","cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_cost_usd":1.5},"context_window":{"used_percentage":42}}' | ./statusline-hp.sh
```

Expected: a single line of output identical to pre-refactor behavior (you may need to eyeball it).

- [ ] **Step 7: Commit**

```bash
git add statusline-hp.sh
git commit -m "refactor: split parts into row1 (identity) and row2 (metrics)"
```

---

## Task 3: Multi-line decision + width calculation + tests

**Files:**
- Modify: `statusline-hp.sh` (add width calc + branching)
- Modify: `tests/statusline.test.sh` (add width-aware tests)
- Modify: `README.md` (document responsive behavior)

Goal: Detect terminal width; if rendered single-line would exceed width, output 2 rows instead.

- [ ] **Step 1: Add test harness helpers**

In `tests/statusline.test.sh`, insert these helpers ABOVE `# --- Tests go below ---`:

```bash
# Helper: run statusline with a specific COLUMNS value
run_with_cols() {
  local cols=$1 theme=$2 json=$3
  echo "$json" | COLUMNS="$cols" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1
}

# assert_multiline <name> <cols> <theme> <json>
# Asserts that output contains a newline (i.e., 2+ rows)
assert_multiline() {
  local name=$1 cols=$2 theme=$3 json=$4
  local output
  output=$(run_with_cols "$cols" "$theme" "$json")
  local line_count
  line_count=$(printf '%s' "$output" | awk 'END{print NR}')
  if [ "$line_count" -gt 1 ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name (expected multi-line, got $line_count line(s))"
    echo "  Output: $output"
  fi
}

# assert_single_line <name> <cols> <theme> <json>
assert_single_line() {
  local name=$1 cols=$2 theme=$3 json=$4
  local output
  output=$(run_with_cols "$cols" "$theme" "$json")
  local line_count
  line_count=$(printf '%s' "$output" | awk 'END{print NR}')
  if [ "$line_count" -eq 1 ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    echo "FAIL: $name (expected single line, got $line_count line(s))"
    echo "  Output: $output"
  fi
}
```

- [ ] **Step 2: Add failing tests BEFORE `# --- Summary ---`**

```bash
# Multi-line responsive behavior
FULL_JSON_MR='{"model":{"display_name":"Opus"},"session_name":"demo","output_style":{"name":"explanatory"},"workspace":{"git_worktree":"wt-abc"},"cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":65.0,"resets_at":9999999999},"seven_day":{"used_percentage":100.0,"resets_at":9999999999}},"version":"2.1.105"}'

assert_multiline "mr-narrow-wraps-rpg" "80" "rpg" "$FULL_JSON_MR"
assert_multiline "mr-narrow-wraps-bloom" "80" "bloom" "$FULL_JSON_MR"
assert_single_line "mr-wide-single-line-rpg" "250" "rpg" "$FULL_JSON_MR"
assert_single_line "mr-wide-single-line-bloom" "250" "bloom" "$FULL_JSON_MR"

# Minimal JSON: single line regardless of cols
assert_single_line "mr-minimal-narrow" "80" "rpg" \
  '{"model":{"display_name":"Opus"}}'
```

- [ ] **Step 3: Run tests — the multi-line / single-line assertions should FAIL**

```bash
cd /home/jerrylien/src/claude-code-hp-statusline && ./tests/statusline.test.sh
```

Expected: all `mr-narrow-wraps-*` FAIL (currently always single-line). `mr-wide-single-line-*` PASS (coincidentally, already single-line). `mr-minimal-narrow` PASS.

- [ ] **Step 4: Add width measurement + multi-line branching in bash**

Replace the final output block (added in Task 2 Step 4):

```bash
# Output: single line for now (multi-line decision added in next task)
if [ -z "$parts_row1" ]; then
  echo -e "$parts_row2"
elif [ -z "$parts_row2" ]; then
  echo -e "$parts_row1"
else
  echo -e "${parts_row1}  ${parts_row2}"
fi
```

with:

```bash
# Responsive output: single line if it fits, else 2 rows
if [ -z "$parts_row1" ]; then
  echo -e "$parts_row2"
elif [ -z "$parts_row2" ]; then
  echo -e "$parts_row1"
else
  cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 999)}
  # Measure display width of each row via python3 (same stdlib used earlier)
  widths=$(printf '%s\n%s' "$parts_row1" "$parts_row2" | python3 -c '
import sys, re, unicodedata
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
def dw(s):
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
```

- [ ] **Step 5: Run tests — all should PASS**

```bash
./tests/statusline.test.sh
```

Expected: all tests pass (37 previous + 5 new = 42 total). In particular, `mr-narrow-wraps-*` now PASS because COLUMNS=80 triggers multi-line.

- [ ] **Step 6: Update README.md**

In the existing "Features" section, after the "🎨 **Two themes**" bullet, add a new bullet:

```markdown
- 📏 **Responsive layout** — auto-wraps into 2 rows (identity / metrics) when the terminal is too narrow, stays single-line on wide screens
```

- [ ] **Step 7: Manual verification**

Run at COLUMNS=80 and COLUMNS=200:

```bash
FULL='{"model":{"display_name":"Opus"},"session_name":"demo","output_style":{"name":"explanatory"},"workspace":{"git_worktree":"wt-abc"},"cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12},"context_window":{"used_percentage":42},"rate_limits":{"seven_day":{"used_percentage":100.0,"resets_at":9999999999}},"version":"2.1.105"}'

echo "--- COLUMNS=80 (expect 2 rows) ---"
echo "$FULL" | COLUMNS=80 ./statusline-hp.sh

echo "--- COLUMNS=250 (expect 1 row) ---"
echo "$FULL" | COLUMNS=250 ./statusline-hp.sh
```

Visually confirm: narrow case wraps to 2 rows, wide case stays single-line.

- [ ] **Step 8: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh README.md
git commit -m "add responsive multi-line layout for narrow terminals"
```

---

## Self-Review (completed by plan author)

**Spec coverage:**
- §1 Row 1 / Row 2 split → Task 2 ✓
- §2 Wall time icon removal → Task 1 ✓
- §3 Python `display_width()` → Task 3 Step 4-5 ✓
- §4 Bash flow (parts_row1/row2, cols detection, branching) → Task 3 Step 5 ✓
- §5 Edge cases (empty row, defaults) → Task 2 Step 4 + Task 3 Step 5 ✓
- §6 Tests (assert_multiline, assert_single_line, per-feature coverage) → Task 3 Steps 1-3 ✓

**Placeholder scan:** None.

**Type consistency:**
- `parts_row1` / `parts_row2` used consistently across Task 2 and Task 3 ✓
- `dw()` helper is self-contained in the bash-invoked Python block (Task 3 Step 4); no redundant definition elsewhere ✓
- `COLUMNS` env var respected in both harness helper and main script ✓
