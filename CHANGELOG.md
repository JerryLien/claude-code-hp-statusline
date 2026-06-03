# Changelog

All notable changes to `statusline-hp.sh`. Format loosely follows [Keep a Changelog](https://keepachangelog.com).
Versions are tagged in the `VERSION` file and embedded in the script as `STATUSLINE_HP_VERSION`.

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
