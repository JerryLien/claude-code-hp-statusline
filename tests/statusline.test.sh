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

# B2 effort gradient — effort comes from the payload's effort.level (the only
# source since 0.6.2; the settings.json fallback displayed the baseline default
# for models that don't run effort at all)
assert_contains "b2-rpg-max-reverse" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  $'\033[7m'

assert_contains "b2-rpg-xhigh-bold" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"xhigh"}}' \
  $'\033[1m'

assert_not_contains "b2-rpg-xhigh-no-reverse" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"xhigh"}}' \
  $'\033[7m'

assert_not_contains "b2-rpg-high-no-reverse" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"high"}}' \
  $'\033[7m'

assert_contains "b2-bloom-max-reverse" "bloom" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  $'\033[7m'

assert_not_contains "b2-bloom-xhigh-no-reverse" "bloom" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"xhigh"}}' \
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
assert_contains "effort-word-max-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  "★max"

assert_contains "effort-word-high-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"high"}}' \
  "↑high"

# Effort label spelled out (Bloom)
assert_contains "effort-word-max-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  "⚫ max"

assert_contains "effort-word-high-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"high"}}' \
  "🔴 high"

# C1 effort.level (spec field) — payload wins even with a settings effortLevel present
assert_contains_effort "c1-runtime-overrides-settings-rpg" "low" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  "★max"

assert_not_contains_effort "c1-runtime-overrides-settings-not-low" "low" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"max"}}' \
  "↓low"

# C1 case-insensitive (spec returns lower-case but be defensive)
assert_contains "c1-effort-uppercase" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"HIGH"}}' \
  "↑high"

# C6 effort.level absence means the model is not running effort (Claude Code
# only emits the field for effort-capable models). settings.json effortLevel is
# the *default for new sessions*, not live session state — it must never be
# displayed. Regression: Sonnet 4.5 (on Claude Code's effort denylist) used to
# show the settings baseline ⇈xhigh via the fallback.
assert_not_contains_effort "c6-no-effort-no-badge-sonnet45" "xhigh" "rpg" \
  '{"model":{"display_name":"Sonnet 4.5"}}' \
  "xhigh"

assert_not_contains_effort "c6-no-effort-no-badge-opus" "high" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "↑high"

assert_not_contains_effort "c6-no-effort-no-badge-bloom" "max" "bloom" \
  '{"model":{"display_name":"Sonnet 4.5"}}' \
  "⚫ max"

# C6 pure data-driven: no model-name mask. If Claude Code ever emits
# effort.level for a Haiku-family model, trust the payload and render it.
assert_contains "c6-haiku-with-effort-renders" "rpg" \
  '{"model":{"display_name":"Haiku 4.5"},"effort":{"level":"high"}}' \
  "↑high"

assert_not_contains_effort "c6-haiku-without-effort-hidden" "xhigh" "rpg" \
  '{"model":{"display_name":"Haiku 4.5"}}' \
  "xhigh"

# C7 pr.kind — "cr" (remote code-review session, undocumented field verified
# emitted by 2.1.201) swaps the PR icon to 🔍 in both themes
assert_contains "c7-pr-kind-cr-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":42,"kind":"cr"}}' \
  "🔍#42"

assert_contains "c7-pr-kind-cr-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"pr":{"number":42,"kind":"cr"}}' \
  "🔍#42"

assert_contains "c7-pr-kind-absent-keeps-theme-icon" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":42}}' \
  "🔀#42"

assert_contains "c7-pr-kind-other-keeps-theme-icon" "bloom" \
  '{"model":{"display_name":"Opus"},"pr":{"number":42,"kind":"pr"}}' \
  "🌷#42"

# C7 workspace.repo — owner+name upgrade the dir badge to owner/name
assert_contains "c7-repo-badge" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/checkout","repo":{"host":"github.com","owner":"jerry","name":"my-project"}}}' \
  "📁 jerry/my-project"

assert_not_contains "c7-repo-badge-replaces-basename" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/checkout","repo":{"owner":"jerry","name":"my-project"}}}' \
  "checkout"

assert_contains "c7-repo-partial-falls-back" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/checkout","repo":{"owner":"jerry"}}}' \
  "📁 checkout"

# C2 thinking.enabled
assert_contains "c2-thinking-on-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"thinking":{"enabled":true}}' \
  "💭"

assert_contains "c2-thinking-on-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"thinking":{"enabled":true}}' \
  "💭"

assert_not_contains "c2-thinking-off" "rpg" \
  '{"model":{"display_name":"Opus"},"thinking":{"enabled":false}}' \
  "💭"

assert_not_contains "c2-thinking-absent" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "💭"

# C3 1M context window badge
assert_contains "c3-1m-badge" "rpg" \
  '{"model":{"display_name":"Opus"},"context_window":{"context_window_size":1000000}}' \
  "[1M]"

assert_not_contains "c3-200k-no-badge" "rpg" \
  '{"model":{"display_name":"Opus"},"context_window":{"context_window_size":200000}}' \
  "[1M]"

assert_not_contains "c3-no-size-no-badge" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "[1M]"

# C4 Fable 5 (new top-tier model) — script is model-agnostic, so a brand-new
# model must render correctly with no code changes: name passes through, the
# 1M-context badge keys off context_window_size (not a model allow-list), and
# effort shows because "Fable 5" doesn't match the Haiku effort-hide guard.
FABLE_JSON='{"model":{"display_name":"Fable 5"},"context_window":{"context_window_size":1000000},"effort":{"level":"max"}}'

assert_contains "c4-fable-name" "rpg" \
  "$FABLE_JSON" \
  "Fable 5"

assert_contains "c4-fable-1m-badge" "rpg" \
  "$FABLE_JSON" \
  "[1M]"

assert_contains "c4-fable-effort-shows" "rpg" \
  "$FABLE_JSON" \
  "★max"

# Bloom theme: name + [1M] badge are theme-independent; effort glyph differs
# (RPG ★max → Bloom ⚫ max), so it's the one assertion that genuinely re-exercises
# theme-specific rendering for the new model.
assert_contains "c4-fable-name-bloom" "bloom" \
  "$FABLE_JSON" \
  "Fable 5"

assert_contains "c4-fable-1m-badge-bloom" "bloom" \
  "$FABLE_JSON" \
  "[1M]"

assert_contains "c4-fable-effort-shows-bloom" "bloom" \
  "$FABLE_JSON" \
  "⚫ max"

# C5 exceeds_200k_tokens: same flag, two meanings. In a 200k window it is a
# capacity alarm (red ⚠200k); in a 1M window it marks the >200k long-context
# pricing tier (yellow 💰200k+), so the red alarm must NOT appear there.
assert_contains "c5-200k-warn-small-window" "rpg" \
  '{"model":{"display_name":"Opus"},"exceeds_200k_tokens":true,"context_window":{"context_window_size":200000}}' \
  "⚠200k"

assert_contains "c5-200k-warn-no-size" "rpg" \
  '{"model":{"display_name":"Opus"},"exceeds_200k_tokens":true}' \
  "⚠200k"

assert_contains "c5-200k-pricing-1m" "rpg" \
  '{"model":{"display_name":"Fable 5"},"exceeds_200k_tokens":true,"context_window":{"context_window_size":1000000}}' \
  "💰200k+"

assert_not_contains "c5-200k-no-red-warn-1m" "rpg" \
  '{"model":{"display_name":"Fable 5"},"exceeds_200k_tokens":true,"context_window":{"context_window_size":1000000}}' \
  "⚠200k"

assert_contains "c5-200k-pricing-1m-bloom" "bloom" \
  '{"model":{"display_name":"Fable 5"},"exceeds_200k_tokens":true,"context_window":{"context_window_size":1000000}}' \
  "💰200k+"

assert_not_contains "c5-200k-no-hint-under-200k-1m" "rpg" \
  '{"model":{"display_name":"Fable 5"},"exceeds_200k_tokens":false,"context_window":{"context_window_size":1000000}}' \
  "200k"

# C8 update-command downgrade guard — extract the bash snippet from
# commands/statusline-update.md and run it with a mocked curl + isolated HOME.
# run_update_snippet <remote VERSION> <version inside remote script> <installed version>
# Sets: UPD_STATUS (exit code), UPD_OUT (output), UPD_INSTALLED (version now on disk)
run_update_snippet() {
  local remote=$1 remote_script=$2 installed=$3
  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/slupdate.XXXXXX") || return 1
  mkdir -p "$tmp/bin" "$tmp/home/.claude"
  cat > "$tmp/bin/curl" <<'FAKE'
#!/bin/bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -*) shift ;;
    *)  url="$1"; shift ;;
  esac
done
case "$url" in
  */VERSION)          content="$FAKE_REMOTE_VERSION" ;;
  */statusline-hp.sh) content="$FAKE_REMOTE_SCRIPT" ;;
  *) exit 22 ;;
esac
if [ -n "$out" ]; then printf '%s\n' "$content" > "$out"; else printf '%s\n' "$content"; fi
FAKE
  chmod +x "$tmp/bin/curl"
  printf '#!/bin/bash\nSTATUSLINE_HP_VERSION="%s"\n' "$installed" > "$tmp/home/.claude/statusline-hp.sh"
  sed -n '/^```bash$/,/^```$/p' "$SCRIPT_DIR/commands/statusline-update.md" | sed '1d;$d' > "$tmp/snippet.sh"
  local script_body
  printf -v script_body '#!/bin/bash\nSTATUSLINE_HP_VERSION="%s"\necho ok\n' "$remote_script"
  UPD_OUT=$(HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
    FAKE_REMOTE_VERSION="$remote" FAKE_REMOTE_SCRIPT="$script_body" \
    bash "$tmp/snippet.sh" 2>&1)
  UPD_STATUS=$?
  UPD_INSTALLED=$(grep -m1 -oE '[0-9.]+' "$tmp/home/.claude/statusline-hp.sh" || echo "?")
  rm -rf "$tmp"
}

assert_update() {
  local name=$1 remote=$2 remote_script=$3 installed=$4 want_status=$5 want_installed=$6
  run_update_snippet "$remote" "$remote_script" "$installed"
  if [ "$UPD_STATUS" = "$want_status" ] && [ "$UPD_INSTALLED" = "$want_installed" ]; then
    PASS=$((PASS + 1)); echo "PASS: $name"
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$name")
    echo "FAIL: $name"
    echo "  want status=$want_status installed=$want_installed"
    echo "  got  status=$UPD_STATUS installed=$UPD_INSTALLED"
    echo "  output: $UPD_OUT"
  fi
}

#              name                          remote  in-script  installed  status  installed-after
assert_update "c8-upgrade-installs"          "0.7.0" "0.7.0"    "0.6.0"    0       "0.7.0"
assert_update "c8-downgrade-aborts"          "0.5.0" "0.5.0"    "0.6.0"    1       "0.6.0"
assert_update "c8-same-version-noop"         "0.6.0" "0.6.0"    "0.6.0"    0       "0.6.0"
assert_update "c8-script-version-mismatch"   "0.7.0" "0.6.9"    "0.6.0"    1       "0.6.0"

# C9 subagentStatusLine mode — tasks[] payload emits {"id","content"} JSON lines
# Helper: every non-empty output line must parse as JSON with id + content
assert_subagent_json() {
  local name=$1 theme=$2 json=$3
  local output
  output=$(printf '%s\n' "$json" | STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  if printf '%s\n' "$output" | python3 -c '
import json, sys
ok = True
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        o = json.loads(line)
        if not (isinstance(o.get("id"), str) and isinstance(o.get("content"), str)):
            ok = False
    except Exception:
        ok = False
sys.exit(0 if ok else 1)
'; then
    PASS=$((PASS + 1)); echo "PASS: $name"
  else
    FAIL=$((FAIL + 1)); FAILED_NAMES+=("$name")
    echo "FAIL: $name"; echo "  Output:  $output"
  fi
}

SUB_START=$(( ( $(date +%s) - 3723 ) * 1000 ))  # 1h02m ago (minute-stable vs race)
SUB_JSON='{"session_id":"s","cwd":"/tmp","columns":80,"tasks":[{"id":"t1","name":"explore-agent","type":"local_agent","status":"running","description":"d","label":"l","startTime":'$SUB_START',"tokenCount":38200,"tokenSamples":[100,200,400,800]},{"id":"t2","status":"completed","label":"verify:bugs","tokenCount":45100,"tokenSamples":[45100]}]}'

assert_subagent_json "c9-json-lines-valid-rpg" "rpg" "$SUB_JSON"
assert_subagent_json "c9-json-lines-valid-bloom" "bloom" "$SUB_JSON"

assert_contains "c9-running-glyph-rpg" "rpg" "$SUB_JSON" "⚔ "
assert_contains "c9-completed-glyph-rpg" "rpg" "$SUB_JSON" "💀"
assert_contains "c9-running-glyph-bloom" "bloom" "$SUB_JSON" "🌱"
assert_contains "c9-completed-glyph-bloom" "bloom" "$SUB_JSON" "🌸"

assert_contains "c9-token-compact" "rpg" "$SUB_JSON" "38.2k"
assert_contains "c9-elapsed-hours" "rpg" "$SUB_JSON" "♔1h02m"

# sparkline: deltas 100,200,400 normalize to ▃▅█ (rpg) / 🌿🌸🌼 (bloom)
assert_contains "c9-spark-rpg" "rpg" "$SUB_JSON" "▃▅█"
assert_contains "c9-spark-bloom" "bloom" "$SUB_JSON" "🌿🌸🌼"

# name fallback chain: no name → label; no name/label → description; → type
assert_contains "c9-name-fallback-label" "rpg" "$SUB_JSON" "verify:bugs"
assert_contains "c9-name-fallback-description" "rpg" \
  '{"tasks":[{"id":"a","status":"running","description":"only-desc","tokenCount":5}]}' \
  "only-desc"
assert_contains "c9-name-fallback-type" "rpg" \
  '{"tasks":[{"id":"a","status":"running","type":"local_bash","tokenCount":5}]}' \
  "local_bash"

# single-sample task renders no sparkline; missing startTime renders no clock
assert_not_contains "c9-single-sample-no-spark" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":5,"tokenSamples":[5]}]}' \
  "▁"
assert_not_contains "c9-no-starttime-no-clock" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":5}]}' \
  "♔"

# unknown status falls back to the running glyph
assert_contains "c9-unknown-status-runs" "rpg" \
  '{"tasks":[{"id":"a","status":"someday-new","label":"x","tokenCount":5}]}' \
  "⚔ "

# empty tasks list is still subagent mode: no main-statusline leakage
assert_not_contains "c9-empty-tasks-no-main-render" "rpg" \
  '{"tasks":[]}' \
  "🧠"

# main mode must not be hijacked: "tasks" as a non-list value falls through
assert_contains "c9-tasks-not-list-main-mode" "rpg" \
  '{"model":{"display_name":"Opus"},"tasks":"nope"}' \
  "⚔ Opus"
assert_contains "c9-tasks-substring-main-mode" "rpg" \
  '{"model":{"display_name":"Opus"},"session_name":"my-tasks-list"}' \
  "#my-tasks-list"


# --- 0.8.0: model 縮寫 ---
assert_contains "c9-model-full-id-shortens" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"claude-haiku-4-5-20251001","tokenCount":5}]}' \
  '\u001b[90m·haiku'
assert_contains "c9-model-alias-passthrough" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"sonnet","tokenCount":5}]}' \
  '\u001b[90m·sonnet'
assert_contains "c9-model-fable" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"claude-fable-5","tokenCount":5}]}' \
  '\u001b[90m·fable'
assert_contains "c9-model-opus" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"claude-opus-5","tokenCount":5}]}' \
  '\u001b[90m·opus'
# 未知 model：原樣小寫、截 12 字元
assert_contains "c9-model-unknown-truncated" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"Claude-Zeta-1-Preview-2027","tokenCount":5}]}' \
  '\u001b[90m·claude-zeta-'
# 缺席／空字串／inherit 都不顯示分隔符
assert_not_contains "c9-model-absent-no-dot" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":5}]}' \
  "·"
assert_not_contains "c9-model-inherit-no-dot" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"inherit","tokenCount":5}]}' \
  "·"
assert_not_contains "c9-model-empty-no-dot" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"","tokenCount":5}]}' \
  "·"
# 型別怪異不得炸掉該列
assert_contains "c9-model-non-string-survives" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"survivor","model":123,"tokenCount":5}]}' \
  "survivor"

# Helper: run statusline with a latest-version cache file present
run_with_sl_latest() {
  local latest=$1 theme=$2 json=$3
  local tmp output status
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/statusline.XXXXXX") || return 1
  mkdir -p "$tmp/.claude/cache"
  printf '%s\n' "$latest" > "$tmp/.claude/cache/statusline-hp.latest-version"
  output=$(printf '%s\n' "$json" | HOME="$tmp" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1)
  status=$?
  rm -rf "$tmp"
  printf '%s' "$output"
  return $status
}

assert_sl_contains() {
  local name=$1 latest=$2 theme=$3 json=$4 pattern=$5
  local output
  output=$(run_with_sl_latest "$latest" "$theme" "$json")
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

assert_sl_not_contains() {
  local name=$1 latest=$2 theme=$3 json=$4 pattern=$5
  local output
  output=$(run_with_sl_latest "$latest" "$theme" "$json")
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

# C4 statusline self-update badge
assert_sl_contains "c4-newer-shows-badge" "9.9.9" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "📦 sl→9.9.9"

assert_sl_not_contains "c4-equal-no-badge" "0.4.0" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "📦"

assert_sl_not_contains "c4-older-no-badge" "0.0.1" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "📦"

# Cache absent should not break or show badge
assert_not_contains "c4-no-cache-no-badge" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "📦"

# D1 workspace.added_dirs — count badge after workspace dir
assert_contains "d1-added-dirs-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/proj","added_dirs":["/tmp/a","/tmp/b"]}}' \
  "📁 proj+2"

assert_contains "d1-added-dirs-single" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/proj","added_dirs":["/tmp/a"]}}' \
  "📁 proj+1"

assert_not_contains "d1-added-dirs-empty" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/proj","added_dirs":[]}}' \
  "+0"

assert_not_contains "d1-added-dirs-missing" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/home/user/proj"}}' \
  "proj+"

# D2 worktree.branch — dim suffix after worktree name
assert_contains "d2-worktree-branch" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"my-feature","branch":"worktree-my-feature"}}' \
  "🌳my-feature"

assert_contains "d2-worktree-branch-shows" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"my-feature","branch":"worktree-my-feature"}}' \
  "⎇worktree-my-feature"

assert_not_contains "d2-worktree-no-branch" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"my-feature"}}' \
  "⎇"

# D2 branch absent for workspace.git_worktree fallback (no branch field there)
assert_not_contains "d2-git-worktree-no-branch" "rpg" \
  '{"model":{"display_name":"Opus"},"workspace":{"git_worktree":"feature-xyz"}}' \
  "⎇"

# === PR badge (pr.*) ===

# Core render: approved -> icon + number + check, per theme
assert_contains "pr-approved-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved"}}' \
  "🔀#1234✓"

assert_contains "pr-approved-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved"}}' \
  "🌷#1234✓"

# State glyphs (theme-agnostic), rpg icon
assert_contains "pr-pending-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"pending"}}' \
  "🔀#7…"

assert_contains "pr-changes-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"changes_requested"}}' \
  "🔀#7✗"

assert_contains "pr-draft-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"draft"}}' \
  "🔀#7✎"

# Colour assertions pin the full colour+icon+number+glyph run rather than the
# bare escape code, so they identify the badge unambiguously and stay conclusive
# even if rate-limit fields (which reuse the same bright colours) are later added
# to a test JSON.
# changes_requested -> BRIGHT_RED
assert_contains "pr-changes-colour-red" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"changes_requested"}}' \
  $'\033[91m🔀#7✗'

# approved -> BRIGHT_GREEN
assert_contains "pr-approved-colour-green" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"approved"}}' \
  $'\033[92m🔀#7✓'

# pending -> BRIGHT_YELLOW
assert_contains "pr-pending-colour-yellow" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"pending"}}' \
  $'\033[93m🔀#7…'

# draft -> GRAY (bare \033[90m is not conclusive: GRAY appears more than once)
assert_contains "pr-draft-colour-gray" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"draft"}}' \
  $'\033[90m🔀#7✎'

# Bloom theme shares the same colour codes; pin one to guard the bloom render path.
assert_contains "pr-approved-colour-green-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"pr":{"number":7,"review_state":"approved"}}' \
  $'\033[92m🌷#7✓'

# Review state absent -> number shows, neutral, NO glyph
assert_contains "pr-no-review-number" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234}}' \
  "🔀#1234"

assert_not_contains "pr-no-review-no-checkglyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234}}' \
  "✓"

assert_not_contains "pr-no-review-no-xglyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234}}' \
  "✗"

# Absent review_state must show NONE of the four state glyphs, not just the
# check/x pair: guard the pending (…) and draft (✎) glyphs too.
assert_not_contains "pr-no-review-no-ellipsis-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234}}' \
  "…"

assert_not_contains "pr-no-review-no-draft-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234}}' \
  "✎"

# Unknown review state -> safe degrade (no glyph), still shows number
assert_contains "pr-unknown-review-number" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"weird"}}' \
  "🔀#1234"

assert_not_contains "pr-unknown-review-no-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"weird"}}' \
  "✓"

# An unrecognised state must not leak ANY of the other three glyphs either.
assert_not_contains "pr-unknown-review-no-xglyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"weird"}}' \
  "✗"

assert_not_contains "pr-unknown-review-no-ellipsis-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"weird"}}' \
  "…"

assert_not_contains "pr-unknown-review-no-draft-glyph" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"weird"}}' \
  "✎"

# No pr -> no badge (baseline regression)
assert_not_contains "pr-absent-rpg" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "🔀"

assert_not_contains "pr-absent-bloom" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "🌷"

# pr present but number missing -> no badge
assert_not_contains "pr-no-number-no-badge" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"review_state":"approved"}}' \
  "🔀"

# Position: PR badge sits after 🌳worktree and before ·agent (full ordering contract)
# Pattern spans wt→RESET→space→GREEN→badge as a contiguous byte sequence, proving
# the badge immediately follows the worktree segment (no reordering possible).
assert_contains "pr-position-order" "rpg" \
  '{"model":{"display_name":"Opus"},"worktree":{"name":"wt"},"pr":{"number":9,"review_state":"approved"},"agent":{"name":"sec"}}' \
  $'wt\033[0m \033[92m🔀#9✓'

# Other half of the contract: badge sits BEFORE ·agent even with no worktree.
# Pattern spans badge→RESET→GRAY→·agent contiguously, proving the order.
assert_contains "pr-position-before-agent" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":9,"review_state":"approved"},"agent":{"name":"sec"}}' \
  $'\033[92m🔀#9✓\033[0m\033[90m·sec'

# === PR badge OSC 8 clickable link (pr.url) ===

# OSC 8 link present when pr.url is set
assert_contains "pr-osc8-link" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved","url":"https://github.com/o/r/pull/1234"}}' \
  "]8;;https://github.com/o/r/pull/1234"

# Still shows the visible badge text alongside the link
assert_contains "pr-osc8-text-still-shown" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved","url":"https://github.com/o/r/pull/1234"}}' \
  "🔀#1234✓"

# Colour must survive next to the link: the OSC 8 open + ST must be immediately
# followed by the real GREEN escape (ESC[92m), NOT a literal "033[92m". This
# catches the echo -e backslash-merge where the ST eats the colour escape lead.
assert_contains "pr-osc8-colour-intact" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved","url":"https://github.com/o/r/pull/1234"}}' \
  $'\033]8;;https://github.com/o/r/pull/1234\033\\\033[92m'

# Close ST must not swallow the following agent colour either (agent abuts badge
# with no leading space): link-close ST then GRAY then ·agent, contiguous.
assert_contains "pr-osc8-close-keeps-agent-colour" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved","url":"https://github.com/o/r/pull/1234"},"agent":{"name":"sec"}}' \
  $'\033]8;;\033\\\033[90m·sec'

# No url -> no OSC 8 sequence, but badge still renders
assert_not_contains "pr-no-url-no-osc8" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved"}}' \
  "]8;;"

assert_contains "pr-no-url-badge-shown" "rpg" \
  '{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved"}}' \
  "🔀#1234✓"

# === PR badge OSC 8 width measurement ===
# The hidden URL inside the OSC 8 link must NOT count toward row width. A ~150-char
# URL would blow past COLUMNS=80 if counted, forcing a 2-row wrap. With correct
# stripping, visible row1 (⚔ Opus 🔀#1234✓) + row2 (ctx bar) fits on one line.
PR_LONGURL='{"model":{"display_name":"Opus"},"pr":{"number":1234,"review_state":"approved","url":"https://github.com/an-extremely-long-organisation-name-here/an-extremely-long-repository-name-goes-right-here/pull/1234567890123456"}}'

assert_single_line "pr-osc8-width-stripped" "80" "rpg" "$PR_LONGURL"
assert_single_line "pr-osc8-width-stripped-bloom" "80" "bloom" "$PR_LONGURL"

# === fast_mode indicator (fast_mode) ===

# Core render per theme
assert_contains "fast-on-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  "⏩fast"

assert_contains "fast-on-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  "🐝 fast"

# Hidden when false / absent (guard each theme glyph)
assert_not_contains "fast-false-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":false}' \
  "⏩"

assert_not_contains "fast-false-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"fast_mode":false}' \
  "🐝"

assert_not_contains "fast-absent-rpg" "rpg" \
  '{"model":{"display_name":"Opus"}}' \
  "⏩"

assert_not_contains "fast-absent-bloom" "bloom" \
  '{"model":{"display_name":"Opus"}}' \
  "🐝"

# Safe degrade: non-bool truthy shows; non-bool falsy (0) hides
assert_contains "fast-truthy-string-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":"yes"}' \
  "⏩fast"

assert_not_contains "fast-falsy-zero-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":0}' \
  "⏩"

# Position: fast sits immediately AFTER the effort indicator …
assert_contains "fast-after-effort-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"high"},"fast_mode":true}' \
  $'↑high\033[0m \033[1m\033[92m⏩fast'

# … and immediately BEFORE output_style
assert_contains "fast-before-style-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":true,"output_style":{"name":"explanatory"}}' \
  $'⏩fast\033[0m \033[36m📖explanatory'

# Bloom ordering (after effort): flat badge, no bright-green
assert_contains "fast-after-effort-bloom" "bloom" \
  '{"model":{"display_name":"Opus"},"effort":{"level":"high"},"fast_mode":true}' \
  $'🔴 high\033[0m 🐝 fast'

# RPG badge carries BOLD + BRIGHT_GREEN
assert_contains "fast-colour-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  $'\033[1m\033[92m⏩fast'

# Bloom badge is flat — must NOT inherit the RPG bright-green
assert_not_contains "fast-bloom-flat-no-green" "bloom" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  $'\033[92m🐝'

# === fast_mode width / wrap ===
FAST_W_OFF='{"model":{"display_name":"Opus"},"effort":{"level":"high"},"output_style":{"name":"explanatory"},"context_window":{"used_percentage":42}}'
FAST_W_ON='{"model":{"display_name":"Opus"},"effort":{"level":"high"},"output_style":{"name":"explanatory"},"context_window":{"used_percentage":42},"fast_mode":true}'

assert_single_line "fast-width-control-rpg"     "55" "rpg"   "$FAST_W_OFF"
assert_multiline   "fast-width-badge-wraps-rpg" "55" "rpg"   "$FAST_W_ON"
assert_single_line "fast-width-control-bloom"   "62" "bloom" "$FAST_W_OFF"
assert_multiline   "fast-width-badge-wraps-bloom" "62" "bloom" "$FAST_W_ON"

# === Version consistency ===
# VERSION file and STATUSLINE_HP_VERSION in the script must stay in sync. Checks
# the invariant (they are equal and look like x.y.z) WITHOUT hardcoding a version,
# so the suite stays green across future bumps and only fails on real drift.
VERSION_FILE="$(cat "$SCRIPT_DIR/VERSION")"
SCRIPT_VERSION="$(grep -E '^STATUSLINE_HP_VERSION=' "$STATUSLINE" | sed -E 's/.*"([^"]+)".*/\1/')"
if [ "$VERSION_FILE" = "$SCRIPT_VERSION" ] && echo "$VERSION_FILE" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  PASS=$((PASS + 1)); echo "PASS: version-consistency"
else
  FAIL=$((FAIL + 1)); FAILED_NAMES+=("version-consistency")
  echo "FAIL: version-consistency (VERSION=$VERSION_FILE SCRIPT=$SCRIPT_VERSION)"
fi

# --- Summary ---
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failed tests: ${FAILED_NAMES[*]}"
  exit 1
fi
