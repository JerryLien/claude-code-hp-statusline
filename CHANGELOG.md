# Changelog

All notable changes to `statusline-hp.sh`. Format loosely follows [Keep a Changelog](https://keepachangelog.com).
Versions are tagged in the `VERSION` file and embedded in the script as `STATUSLINE_HP_VERSION`.

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
