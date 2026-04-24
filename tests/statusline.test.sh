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
  "/⏱45m"

assert_contains "a2-wall-time-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000,"total_duration_ms":2700000}}' \
  "/🕰45m"

assert_not_contains "a2-no-wall" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "/⏱"

assert_contains "a2-api-still-shown" "rpg" \
  '{"model":{"display_name":"Opus"},"cost":{"total_api_duration_ms":134000}}' \
  "🔮 2m14s"

# --- Summary ---
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failed tests: ${FAILED_NAMES[*]}"
  exit 1
fi
