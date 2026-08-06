# Changelog

All notable changes to `statusline-hp.sh`. Format loosely follows [Keep a Changelog](https://keepachangelog.com).
Versions are tagged in the `VERSION` file and embedded in the script as `STATUSLINE_HP_VERSION`.

## [Unreleased]

## [0.8.0] — 2026-08-06

- Subagent rows now show the per-task model as a short name (`·haiku`, `·sonnet`, `·opus`, `·fable`); unknown model ids fall back to the value lower-cased and truncated to 12 characters, and the segment is omitted when the field is absent or `inherit`
- Subagent rows now show the per-task reasoning effort as a themed symbol (RPG `★⇈↑~↓`, Bloom `⚫🟣🔴🟡🔵`) matching the main row colours; a numeric token budget renders compact in grey, and an absent field (subagent inherits the session level) renders nothing. Requires Claude Code 2.1.214 or later
- Subagent token counts are now coloured by context usage (`tokenCount / contextWindowSize`) using the same thresholds as the main row context bar: cyan below 70%, yellow from 70%, red from 90%. Rows without `contextWindowSize` stay uncoloured
- Tests: +34 subagent model/effort/token-colour cases (170 → 204)

## [0.7.0] — 2026-07-06

- **Subagent status line**: point the `subagentStatusLine` setting at the same script — it auto-detects the `tasks[]` payload (structural check, not just the substring probe) and emits one `{"id","content"}` JSON line per task. Rows show a themed status glyph (RPG `⚔`/`💀`/`☠`/`⏳`, Bloom `🌱`/`🌸`/`🥀`/`💤`), the agent name (fallback chain `name → label → description → type`), a token-burn sparkline from `tokenSamples` deltas (`▁▂▃▄▅▆▇█` in RPG, 4 flower stages in Bloom), the compact token total, and elapsed time (`♔1m24s` / `⏱1m24s`). Per-task render errors skip that line so Claude Code falls back to its default row. Contract verified against the v2.1.201 payload builder (5s cadence, 5s timeout, ANSI + OSC 8 supported, partial output allowed)
- `/statusline-update` now refuses to downgrade: it compares the remote `VERSION` against the installed `STATUSLINE_HP_VERSION` (`sort -V`) and aborts when remote ≤ installed (the 2026-07-06 incident: a local repo ahead of GitHub caused the old unconditional download to downgrade 0.6.0 → 0.5.0); downloads are also validated (`bash -n` + embedded version must match the fetched `VERSION`) before touching the installed copy
- `pr.kind: "cr"` (remote code-review session) swaps the PR badge icon to `🔍` in both themes
- `workspace.repo.owner` + `.name` upgrade the directory badge to `📁 owner/name` (repo identity beats checkout-dir basename)
- README: documented the subagent status line setting and a new field-compatibility section for undocumented-but-emitted fields (`fast_mode`, `pr.kind`)
- Tests: +4 update-guard cases (mocked `curl` + isolated `HOME` running the real snippet from the command doc), +19 subagent-mode cases, +7 kind/repo badge cases (140 → 170)

## [0.6.2] — 2026-07-06

- Fixed phantom effort badge on effort-less models (e.g. `⇈xhigh` shown on Sonnet 4.5): Claude Code emits `effort.level` only for effort-capable models (reverse-engineered v2.1.201 — hardcoded denylist covers `claude-3-*`, `opus-4-0/4-1`, `sonnet-4-0`, `sonnet-4-5`, `haiku-4-5`), so field absence means "not running effort". The settings.json `effortLevel` fallback displayed the *new-session default* as if it were live session state, and only ever became visible exactly when it was wrong — removed; effort is now purely payload-driven
- Removed the `*Haiku*` model-name mask that was papering over the same bug for Haiku — no model allow-lists; if Claude Code ever emits `effort.level` for a future Haiku, it renders
- Tests: 11 render cases converted from the settings-fallback helper to payload-driven `effort.level` (matches the real data flow), +5 new `c6-*` cases covering absence-means-hidden (Sonnet 4.5/Opus/bloom), Haiku-with-payload renders, Haiku-without stays hidden (136 → 140)

## [0.6.1] — 2026-07-06

- `⚠200k` no longer stays permanently red in 1M-context sessions: `exceeds_200k_tokens` is a fixed 200k flag regardless of window size (verified against the Claude Code v2.1.201 payload builder), so in a 1M window it now renders as a yellow `💰200k+` pricing-tier hint (>200k input = 2x token rate) instead of a capacity alarm; the red `⚠200k` is unchanged for 200k windows (and when `context_window_size` is absent)
- Compat audit vs Claude Code v2.1.201: all 34 consumed JSON paths still emitted, `COLUMNS`-first width detection matches the 2.1.153+ contract, and `pr.*` (`pr.number`/`pr.url`/`pr.review_state`) is now officially documented — the 0.5.0 badge's field assumption is confirmed end-to-end; `fast_mode` is emitted unconditionally but remains undocumented
- +6 tests: red alarm in 200k/absent-size windows, yellow hint in 1M (both themes), no red alarm in 1M, no hint below the threshold (130 → 136)

## [0.6.0] — 2026-06-19

- `⏩fast` (rpg, bold bright-green) / `🐝 fast` (bloom, flat) badge in row1 when Opus fast mode (`/fast`) is on, parsed from the top-level `fast_mode` boolean
- Placed immediately after the effort indicator and before `output_style`, forming a "how the model runs" group (effort + output speed); shown only when `fast_mode` is truthy (no model guard needed — Claude Code only reports it truthy for Opus)
- Neutral styling by design: fast mode is a deliberate user choice, so the badge does not imply a cost warning
- Width: `⏩` (U+23E9) and `🐝` (U+1F41D) both measure 2 cells via `east_asian_width=W`, so the responsive wrap calculation is correct with no change to `dw()`
- +12 tests covering render (both themes), hidden-when-off, non-bool safe-degrade, position (after effort / before output_style), colour (rpg bold+green, bloom flat), and width/wrap differential (113 → 130)
- +6 Fable 5 regression tests (rpg + bloom) asserting the script stays model-agnostic: `model.display_name` pass-through, `[1M]` badge driven by `context_window_size` (not a model allow-list), and effort shown because `Fable 5` doesn't match the `*Haiku*` effort-hide guard

## [0.5.0] — 2026-06-03

- `🔀#1234✓` (rpg) / `🌷#1234✓` (bloom) PR badge in row1 when an open PR exists for the current branch (`pr.number` / `pr.review_state`)
- Review state shown as glyph + colour: `✓` approved (green), `…` pending (yellow), `✗` changes_requested (red), `✎` draft (grey); neutral cyan with no glyph when `review_state` is absent or unknown
- Badge is a clickable OSC 8 hyperlink to `pr.url` (degrades to plain text on terminals without OSC 8 support); the string-terminator escaping is colour-safe so the badge colour survives next to the link
- Width measurement now strips OSC 8 sequences so the hidden URL does not skew the responsive single-line / 2-row wrap decision
- README: documented the PR badge plus `hideVimModeIndicator` and `refreshInterval` settings tips
- +34 new tests covering the four review states, absent/unknown state (all glyphs guarded), position ordering, no-url fallback, OSC 8 colour-safety, OSC 8 width equivalence, theme colour rendering, and version consistency (73 → 107)

## [0.4.0] — 2026-05-20

- `📁 dir+N` count badge when `/add-dir` mounted extra directories (`workspace.added_dirs`)
- `🌳name⎇branch` dim suffix in `--worktree` sessions when `worktree.branch` is populated
- Both indicators are theme-agnostic; bloom and rpg render the same text decoration
- +8 new tests covering D1/D2 positive and negative cases (65 → 73)

## [0.3.0] — 2026-04-30

**Statusline self-update notification** (`71697ad`)

- New `hooks/check-update.sh` SessionStart hook background-fetches `VERSION` from GitHub (2s timeout, 6h cache)
- `📦 sl→X.Y.Z` cyan badge appears when installed `STATUSLINE_HP_VERSION` is older than the cached latest
- New `/statusline-update` slash command performs the in-place upgrade with a `.bak` backup

**Spec-driven evolution** (`481d3df`) — implements `docs/superpowers/specs/2026-04-24-statusline-evolution.md` and `responsive-multiline.md`:

- `output_style.name` → `📖<style>` (rpg) / `🌻<style>` (bloom), hidden when `default`
- `cost.total_duration_ms` → wall clock time appended after API time (`🔮 2m14s/45m00s`)
- `session_name` → `#<name>` after model
- `worktree.name` / `workspace.git_worktree` → `🌳<name>` indicator
- `workspace.current_dir` → `📁 <basename>` (or `~` for home)
- Rate limit 100% → cooldown icon (`⏳` rpg / `💤` bloom) replaces the `↻` reset arrow
- `xhigh` / `max` effort levels get stronger visual treatment (rpg: bold magenta / reverse video; bloom: reverse video on `⚫`)
- Responsive 2-row layout: measures display width (handles East Asian Width + emoji), wraps at narrow terminals, single-line at ≥200 cols fast path
- Removes `⏱` / `🕰` icons (East Asian Width ambiguity caused visual overlap)
- Lightweight test harness (`tests/statusline.test.sh`) with 65 tests across both themes

## Pre-0.3.0

No `VERSION` file existed before 0.3.0. Highlights from earlier commits:

- `348ece8` Document `/model` auto-sync and `⚠effort` drift warning
- `68b18b5` Transcript fallback so mid-session `/model` effort changes reflect in statusline
- `0b78bd5` Add `xhigh` and `max` effort levels for Opus 4.7
- `3a56825` Cache hit ratio (⚡), API duration (🔮 / 🌿), version update alert, vim mode, agent name indicators
- `fa091e4` Rate limit reset countdown
- `4310d2d` Initial statusline script with rpg + bloom themes

For exact history see `git log`.
