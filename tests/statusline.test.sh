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
  output=$(printf '%s\n' "$json" | STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  if printf '%s\n' "$output" | grep -qF "$pattern"; then
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
  output=$(printf '%s\n' "$json" | STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  if printf '%s\n' "$output" | grep -qF "$pattern"; then
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

# Helper: run statusline with custom effort via temp HOME
run_with_effort() {
  local effort=$1 theme=$2 json=$3
  local tmp output status
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/statusline.XXXXXX") || return 1
  mkdir -p "$tmp/.claude"
  printf '{"effortLevel":"%s"}\n' "$effort" > "$tmp/.claude/settings.json"
  output=$(printf '%s\n' "$json" | HOME="$tmp" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  status=$?
  rm -rf "$tmp"
  printf '%s' "$output"
  return $status
}

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

# Helper: run statusline with a specific COLUMNS value
run_with_cols() {
  local cols=$1 theme=$2 json=$3
  printf '%s\n' "$json" | COLUMNS="$cols" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1
}

# assert_multiline <name> <cols> <theme> <json>
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

# --- Tests go below ---

# Baseline: minimal JSON works (regression)
assert_contains "baseline-rpg" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "Opus"

assert_contains "baseline-bloom" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "Opus"

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

# A3 session_name
assert_contains "a3-session-name" "rpg" \
  '{"model":{"display_name":"Opus"},"session_name":"my-feature"}' \
  "#my-feature"

assert_not_contains "a3-no-session-name" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "#"

# A4 worktree
assert_contains "a4-git-worktree" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"git_worktree":"feature-xyz"}}' \
  "🌳feature-xyz"

assert_contains "a4-worktree-name" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"}}' \
  "🌳wt-x"

assert_contains "a4-priority" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"},"workspace":{"git_worktree":"wt-a"}}' \
  "🌳wt-x"

assert_not_contains "a4-priority-loser-absent" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt-x"},"workspace":{"git_worktree":"wt-a"}}' \
  "wt-a"

assert_not_contains "a4-no-worktree" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "🌳"

# A2 wall time
# API=2m14s=134000ms, Wall=45m=2700000ms
assert_contains "a2-wall-time-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "2m14s/45m"

assert_contains "a2-wall-time-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "2m14s/45m"

assert_not_contains "a2-no-wall" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "/45m"

assert_contains "a2-api-still-shown" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "🔮 2m14s"

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

assert_not_contains "b1-99-percent-no-cooldown" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":99.99,"resets_at":9999999999}}}' \
  "⏳"

assert_contains "b1-7d-normal-rotate" "rpg" \
  '{"model":{"display_name":"Opus"},"rate_limits":{"seven_day":{"used_percentage":50.0,"resets_at":9999999999}}}' \
  "↻"

# B2 effort gradient
assert_contains_effort "b2-rpg-max-reverse" "max" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

assert_contains_effort "b2-rpg-xhigh-bold" "xhigh" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[1m'

assert_not_contains_effort "b2-rpg-xhigh-no-reverse" "xhigh" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

assert_not_contains_effort "b2-rpg-high-no-reverse" "high" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

assert_contains_effort "b2-bloom-max-reverse" "max" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

assert_not_contains_effort "b2-bloom-xhigh-no-reverse" "xhigh" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  $'\033[7m'

# Integration: all features together
FULL_JSON='{"model":{"display_name":"Opus"},"session_name":"my-feature","output_style":{"name":"explanatory"},"workspace":{"git_worktree":"wt-abc"},"cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12},"rate_limits":{"five_hour":{"used_percentage":65.0,"resets_at":9999999999},"seven_day":{"used_percentage":100.0,"resets_at":9999999999}}}'

assert_contains "integration-session" "rpg" "$FULL_JSON" "#my-feature"
assert_contains "integration-worktree" "rpg" "$FULL_JSON" "🌳wt-abc"
assert_contains "integration-style" "rpg" "$FULL_JSON" "📖explanatory"
assert_contains "integration-wall" "rpg" "$FULL_JSON" "/45m"
assert_contains "integration-cooldown-7d" "rpg" "$FULL_JSON" "⏳"
assert_contains "integration-rotate-5h" "rpg" "$FULL_JSON" "↻"
assert_contains "integration-bloom-style" "bloom" "$FULL_JSON" "🌻explanatory"
assert_contains "integration-bloom-cooldown" "bloom" "$FULL_JSON" "💤"

# A2 wall-time icons removed
assert_not_contains "a2-no-stopwatch-icon" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "⏱"

assert_not_contains "a2-no-pendulum-icon" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "🕰"

# Responsive multi-line behavior
FULL_JSON_MR='{"model":{"display_name":"Opus"},"session_name":"demo","output_style":{"name":"explanatory"},"workspace":{"git_worktree":"wt-abc"},"cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":65.0,"resets_at":9999999999},"seven_day":{"used_percentage":100.0,"resets_at":9999999999}},"version":"2.1.105"}'

assert_multiline "mr-narrow-wraps-rpg" "80" "rpg" "$FULL_JSON_MR"
assert_multiline "mr-narrow-wraps-bloom" "80" "bloom" "$FULL_JSON_MR"
assert_single_line "mr-wide-single-line-rpg" "250" "rpg" "$FULL_JSON_MR"
assert_single_line "mr-wide-single-line-bloom" "250" "bloom" "$FULL_JSON_MR"
assert_single_line "mr-minimal-narrow" "80" "rpg" \
  '{"model":{"display_name":"Opus"}}'

# Workspace dir display
assert_contains "workspace-dir-basename" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/my-project"}}' \
  "📁 my-project"

assert_contains "workspace-dir-cwd-fallback" "rpg" \
  '{"model":{"display_name":"Opus"},"cwd":"/var/tmp/foo"}' \
  "📁 foo"

assert_not_contains "workspace-dir-no-field" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "📁"

# Effort label spelled out (RPG)
assert_contains_effort "effort-word-max-rpg" "max" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "★max"

assert_contains_effort "effort-word-high-rpg" "high" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "↑high"

# Effort label spelled out (Bloom)
assert_contains_effort "effort-word-max-bloom" "max" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "⚫ max"

assert_contains_effort "effort-word-high-bloom" "high" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "🔴 high"

# --- Summary ---
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failed tests: ${FAILED_NAMES[*]}"
  exit 1
fi
