# Fast Mode Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface Claude Code's top-level `fast_mode` boolean (Opus `/fast`) as a themed row1 badge, shown only when on.

**Architecture:** Parse `fast_mode` in the existing single `python3` block → emit `FAST_MODE=1/0`; define per-theme `FAST_TEXT`/`FAST_STYLE` in the `case "$THEME"` block; append a one-line conditional badge to `parts_row1` immediately after the effort indicator and before `output_style`. No new dependencies; mirrors the existing `exceeds_200k` / effort patterns.

**Tech Stack:** Bash + embedded `python3` (statusline-hp.sh); bash test harness (tests/statusline.test.sh).

## Global Constraints

- VERSION file and `STATUSLINE_HP_VERSION` in the script MUST be bumped together to `0.6.0` (drift misfires the `📦 sl→X.Y.Z` self-update badge and fails the `version-consistency` test). Copy value verbatim: `0.6.0`.
- Badge is **additive only**: do not reorder or restyle existing fields.
- Leading-space rule: badge prefixed with a single space; fully omitted (incl. the space) when off — no double-space hole.
- No model guard needed: `fast_mode` is only truthy on Opus, so "show only when truthy" is sufficient.
- RPG badge: `⏩fast` in `${BOLD}${BRIGHT_GREEN}`. Bloom badge: `🐝 fast` flat (empty style).
- Glyph widths are verified: `⏩` (U+23E9) and `🐝` (U+1F41D) both report `east_asian_width=W` → `dw()` already counts each as 2 cells on any Python ≥ 3.6. **Do not modify `dw()`.**
- Commits: NO `Co-Authored-By` line (user global instruction).
- Project ships one feature per PR off a feature branch (current branch: `feat/fast-mode-indicator`).

---

## File Structure

- `statusline-hp.sh` — parse `fast_mode`, theme vars, badge assembly, version bump (one responsibility: render).
- `tests/statusline.test.sh` — append a `fast_mode` test section (behaviour, position, colour, width).
- `README.md` — document the badge (features list + conditional-extras entry).
- `CHANGELOG.md` — add `[0.6.0]` section.
- `VERSION` — bump to `0.6.0`.

---

### Task 1: Parse `fast_mode` and render the dual-theme badge

**Files:**
- Modify: `statusline-hp.sh` (parse ~line 122, print ~line 203, theme vars ~lines 263 & 286, assembly ~line 431)
- Test: `tests/statusline.test.sh` (append new section near the end, before `=== Version consistency ===`)

**Interfaces:**
- Produces: shell var `FAST_MODE` (`1` show / `0` hide) from the python block; theme vars `FAST_TEXT`, `FAST_STYLE`; appends `" ${FAST_STYLE}${FAST_TEXT}${RESET}"` to `parts_row1` when `FAST_MODE=1`.

- [ ] **Step 1: Write the failing render tests (both themes + hidden + safe-degrade)**

Append to `tests/statusline.test.sh` immediately before the `# === Version consistency ===` block:

```bash
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
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `./tests/statusline.test.sh 2>&1 | grep -E 'FAIL: fast-'`
Expected: `fast-on-rpg`, `fast-on-bloom`, `fast-truthy-string-rpg` FAIL (badge not rendered yet). The `fast-false-*`, `fast-absent-*`, `fast-falsy-zero-rpg` will already PASS (nothing renders), which is fine — the three positive cases failing proves red.

- [ ] **Step 3: Parse `fast_mode` in the python block**

In `statusline-hp.sh`, after the line:
```python
exceeds_200k = 1 if g(d, "exceeds_200k_tokens") else 0
```
add:
```python
fast_mode = 1 if g(d, "fast_mode") else 0
```

- [ ] **Step 4: Emit `FAST_MODE`**

After the line:
```python
print(f"EXCEEDS_200K={exceeds_200k}")
```
add:
```python
print(f"FAST_MODE={fast_mode}")
```

- [ ] **Step 5: Add Bloom theme vars**

In the `bloom)` case, after `EFFORT_LOW_STYLE=""`, add:
```bash
    FAST_TEXT="🐝 fast"
    FAST_STYLE=""
```

- [ ] **Step 6: Add RPG theme vars**

In the `*)` (RPG default) case, after `EFFORT_LOW_STYLE="${GRAY}"`, add:
```bash
    FAST_TEXT="⏩fast"
    FAST_STYLE="${BOLD}${BRIGHT_GREEN}"
```

- [ ] **Step 7: Assemble the badge (after effort, before output_style)**

After the line:
```bash
[ -n "$EFFORT_ICON" ] && parts_row1+=" ${EFFORT_ICON}"
```
add:
```bash
[ "${FAST_MODE:-0}" = "1" ] && parts_row1+=" ${FAST_STYLE}${FAST_TEXT}${RESET}"
```

- [ ] **Step 8: Run the fast tests to verify they pass**

Run: `./tests/statusline.test.sh 2>&1 | grep -E 'fast-'`
Expected: all `fast-*` lines show `PASS`.

- [ ] **Step 9: Run the full suite (no regressions)**

Run: `./tests/statusline.test.sh`
Expected: `Failed: 0` (count rises from 113 to 121).

- [ ] **Step 10: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "feat: fast_mode badge in row1 (⏩fast / 🐝 fast)"
```

---

### Task 2: Pin the ordering, colour, and width contracts

These are contract/regression tests; the Task 1 implementation already satisfies them, so they pass on first run (characterization tests). No production code changes.

**Files:**
- Test: `tests/statusline.test.sh` (extend the `fast_mode` section)

**Interfaces:**
- Consumes: the rendered `parts_row1` byte sequence and the responsive wrap decision from Task 1.

- [ ] **Step 1: Add position contract tests (after effort, before output_style)**

Append to the `fast_mode` test section:

```bash
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
```

- [ ] **Step 2: Add colour contract tests**

```bash
# RPG badge carries BOLD + BRIGHT_GREEN
assert_contains "fast-colour-rpg" "rpg" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  $'\033[1m\033[92m⏩fast'

# Bloom badge is flat — must NOT inherit the RPG bright-green
assert_not_contains "fast-bloom-flat-no-green" "bloom" \
  '{"model":{"display_name":"Opus"},"fast_mode":true}' \
  $'\033[92m🐝'
```

- [ ] **Step 3: Add width / wrap differential tests**

The badge ( ` ⏩fast` = 7 cells, ` 🐝 fast` = 8 cells) must count toward row width. At a `COLUMNS` inside the measured gap, the SAME JSON is single-line WITHOUT the badge but wraps WITH it — proving the width is counted (and that `⏩`/`🐝` are not undercounted). Measured boundaries (this script, current glyphs): rpg single-line at ≥52 without badge → ≥59 with; bloom ≥58 → ≥66. Chosen test columns sit mid-gap: 55 (rpg), 62 (bloom).

```bash
# === fast_mode width / wrap ===
FAST_W_OFF='{"model":{"display_name":"Opus"},"effort":{"level":"high"},"output_style":{"name":"explanatory"},"context_window":{"used_percentage":42}}'
FAST_W_ON='{"model":{"display_name":"Opus"},"effort":{"level":"high"},"output_style":{"name":"explanatory"},"context_window":{"used_percentage":42},"fast_mode":true}'

assert_single_line "fast-width-control-rpg"     "55" "rpg"   "$FAST_W_OFF"
assert_multiline   "fast-width-badge-wraps-rpg" "55" "rpg"   "$FAST_W_ON"
assert_single_line "fast-width-control-bloom"   "62" "bloom" "$FAST_W_OFF"
assert_multiline   "fast-width-badge-wraps-bloom" "62" "bloom" "$FAST_W_ON"
```

- [ ] **Step 4: Run the suite and verify all new tests pass**

Run: `./tests/statusline.test.sh`
Expected: `Failed: 0` (count rises to 130). If a width test misfires, the local single→multi gap differs from the measured one: confirm with `for c in $(seq 48 70); do printf '%s\n' "$FAST_W_OFF" | COLUMNS=$c STATUSLINE_THEME=rpg ./statusline-hp.sh | awk "END{print $c\"=\"NR}"; done` and pick a `COLUMNS` that is single-line for `_OFF` and would gain 7/8 cells for `_ON`; update the two literals. Do not touch `dw()`.

- [ ] **Step 5: Commit**

```bash
git add tests/statusline.test.sh
git commit -m "test: pin fast_mode position, colour, and width contracts"
```

---

### Task 3: Version bump + documentation + release

**Files:**
- Modify: `VERSION`, `statusline-hp.sh:11`, `CHANGELOG.md`, `README.md`

**Interfaces:**
- Consumes: the `version-consistency` test (asserts `VERSION` == `STATUSLINE_HP_VERSION`, both `x.y.z`).

- [ ] **Step 1: Bump the embedded version**

In `statusline-hp.sh`, change:
```bash
STATUSLINE_HP_VERSION="0.5.0"
```
to:
```bash
STATUSLINE_HP_VERSION="0.6.0"
```

- [ ] **Step 2: Bump the VERSION file**

```bash
printf '0.6.0' > VERSION
```

- [ ] **Step 3: Run the version-consistency test**

Run: `./tests/statusline.test.sh 2>&1 | grep version-consistency`
Expected: `PASS: version-consistency`

- [ ] **Step 4: Add the CHANGELOG entry**

In `CHANGELOG.md`, replace the `## [Unreleased]` block's content (keep the Fable 5 test note under Unreleased OR fold it into 0.6.0 since the script now changes) by inserting a new section directly under the `## [Unreleased]` heading:

```markdown
## [0.6.0] — 2026-06-19

- `⏩fast` (rpg, bold bright-green) / `🐝 fast` (bloom, flat) badge in row1 when Opus fast mode (`/fast`) is on, parsed from the top-level `fast_mode` boolean
- Placed immediately after the effort indicator and before `output_style`, forming a "how the model runs" group (effort + output speed); shown only when `fast_mode` is truthy (no model guard needed — Claude Code only reports it truthy for Opus)
- Neutral styling by design: fast mode is a deliberate user choice, so the badge does not imply a cost warning
- Width: `⏩` (U+23E9) and `🐝` (U+1F41D) both measure 2 cells via `east_asian_width=W`, so the responsive wrap calculation is correct with no change to `dw()`
- +12 tests covering render (both themes), hidden-when-off, non-bool safe-degrade, position (after effort / before output_style), colour (rpg bold+green, bloom flat), and width/wrap differential (113 → 130)
```

- [ ] **Step 5: Add README features-list entry**

In `README.md`, after the `💭 / **[1M]** **Model state indicators**` bullet in the `## Features` list, add:
```markdown
- ⏩ / 🐝 **Fast mode** — Badge appears next to the effort level when Opus fast mode (`/fast`) is on
```

- [ ] **Step 6: Add README conditional-extras entry**

In `README.md`, under `### Conditional extras`, after the `·agent` bullet, add:
```markdown
- **⏩fast / 🐝 fast — Fast mode** — Appears right after the effort level when Opus fast mode is enabled (`/fast`, the `fast_mode` field). RPG renders `⏩fast` in bold bright-green; Bloom renders `🐝 fast` flat. Hidden when fast mode is off — and naturally absent on models that don't report it (Claude Code only sends it truthy for Opus)
```

- [ ] **Step 7: Run the full suite one last time**

Run: `./tests/statusline.test.sh`
Expected: `Failed: 0`, `Passed: 130`.

- [ ] **Step 8: Commit**

```bash
git add VERSION statusline-hp.sh CHANGELOG.md README.md
git commit -m "docs: fast_mode indicator + bump to 0.6.0"
```

- [ ] **Step 9: Push and open the PR**

```bash
git push -u origin feat/fast-mode-indicator
gh pr create --title "feat: fast_mode indicator (0.6.0)" --body "$(cat <<'EOF'
## Summary
- Adds a row1 `fast_mode` badge: `⏩fast` (rpg, bold bright-green) / `🐝 fast` (bloom, flat), shown only when Opus fast mode (`/fast`) is on
- Placed after the effort indicator, before `output_style`
- Bumps to 0.6.0; +12 tests (113 → 130)

## Test plan
- `./tests/statusline.test.sh` → Passed: 130, Failed: 0

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**1. Spec coverage:** P1 parse `fast_mode`→`FAST_MODE` (T1 S3–S4 ✓); P2 row1 badge after effort/before output_style, only when on (T1 S5–S7, T2 S1 ✓); P3 per-theme glyph+style (T1 S5–S6, T2 S2 ✓); P4 width test, no mis-wrap (T2 S3 ✓); P5 README (T3 S5–S6 ✓); version+CHANGELOG (T3 ✓). Edge cases §5: absent/false/true/non-bool/Haiku all covered by T1 tests. ✓

**2. Placeholder scan:** All steps contain concrete code/commands and expected output. Width-boundary fallback in T2 S4 is a TDD verification instruction with concrete fallback command, not a placeholder. ✓

**3. Type consistency:** `FAST_MODE`, `FAST_TEXT`, `FAST_STYLE` named identically across parse/print, theme vars, and assembly. Assembly guard `"${FAST_MODE:-0}" = "1"` matches the `print(f"FAST_MODE={fast_mode}")` 0/1 output. ✓
