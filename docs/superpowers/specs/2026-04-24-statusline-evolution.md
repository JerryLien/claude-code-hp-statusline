# Statusline 進化：新欄位 + 顯示優化

**日期**：2026-04-24
**範圍**：`statusline-hp.sh`

## 背景

Claude Code 的 statusline JSON 輸入自上次實作以來，官方新增了多個欄位（`output_style.name`、`cost.total_duration_ms`、`session_name`、`workspace.git_worktree`、`worktree.*`），現有腳本沒有顯示這些資訊。

另外兩個既有顯示在特定情況下語意不夠精準：
- rate limit 100% 時的 `↻` 倒數實際是「冷卻解除時間」而非完整視窗重置，視覺上沒區分
- `xhigh` / `max` effort 在 RPG 主題的視覺強度跟 `high` 差不多，極端等級辨識度不足

## 目標

**A. 加新資訊欄位**
- A1 `output_style.name` — 顯示當前 output style（非 default 才顯示）
- A2 `cost.total_duration_ms` — 顯示 session 總牆上時間
- A3 `session_name` — 顯示 `--name` / `/rename` 設的名稱
- A4 worktree — 顯示 worktree 指示器

**B. 改善現有顯示**
- B1 rate limit 100% 時冷卻狀態視覺差異
- B2 effort `xhigh` / `max` 視覺強化（明確強度梯度）

## 非目標

- 改變既有欄位的順序或樣式（只做加法）
- 新增主題
- 多行 statusline
- 處理 `output_style`、`session_name`、worktree **以外**的新欄位

## 設計

### §1 Layout 與顯示規則

**RPG 目標外觀**（`▸` 標示新增項，實際輸出不含）：
```
⚔ Opus ▸#my-feature ▸🌳feature-xyz ·agent ↑H ▸📖explanatory ⌨N  ❤ 5h [...] 65% ↻2h29m  ❤ 7d [████████████████] 100% ▸⏳11h55m  🧠 ▮▮▮▮ 42% ⚡87%  🔮 2m14s▸/⏱45m  💰 $2.80  +87/-12  v2.1.105
```

**Bloom 目標外觀**：
```
🌱 Opus ▸#my-feature ▸🌳feature-xyz ·agent 🔴 ▸🌻explanatory ⌨N  5h 🌸🌸🌸········ 35% ↻2h29m  7d 🌸🌸🌸🌸🌸🌸🌸🌸🌸🌸 100% ▸💤11h55m  🍄 🌸🌸🌸🌸······ 42% ⚡87%  🌿 2m14s▸/🕰45m  🌕 $2.80  +87/-12  v2.1.105
```

**欄位順序（從左到右）**：
1. 模型區：`MODEL_ICON MODEL ·#SESSION ·🌳WT ·AGENT EFFORT STYLE VIM`
2. 用量區：`5h / 7d / 🧠 / ⚡ / ⚠200k`（不動）
3. 時間成本區：`🔮 API/⏱WALL / 💰 / +/- / v`

**顯示條件**：

| 欄位 | 條件 |
|---|---|
| A1 `📖<style>` / `🌻<style>` | `output_style.name` 存在且 **≠ `"default"`** 且 **≠ `""`** |
| A2 `/⏱<wall>` / `/🕰<wall>` | `cost.total_duration_ms > 0` 且 API duration 已顯示 |
| A3 `#<session_name>` | `session_name` 欄位存在且非空 |
| A4 `🌳<name>` | 優先序：`worktree.name` → `workspace.git_worktree` → 不顯示 |
| B1 冷卻符號取代 `↻` | 5h 或 7d 的 `used_percentage` **浮點值 ≥ 100.0**（不是取整後） |
| B2 effort 強化 | `xhigh` → bold · `max` → reverse video（僅 RPG）；Bloom 的 `max` → 加粗 |

**空白規則**：新增欄位間用單空白；條件為假時連同前導空白一併省略，避免雙空白洞。

### §2 主題對照

| 欄位 | RPG | Bloom |
|---|---|---|
| A1 output_style | `📖<name>` | `🌻<name>` |
| A2 wall time | `/⏱<time>` | `/🕰<time>` |
| A3 session_name | `#<name>` | `#<name>` |
| A4 worktree | `🌳<name>` | `🌳<name>` |
| B1 cooldown icon | `⏳` | `💤` |
| B2 effort gradient | high=normal / xhigh=bold / max=reverse | high=normal / xhigh=同現狀 / max=bold |

### §3 解析與顯示邏輯

**Python 端新增**（現有 `eval "$(INPUT=... python3 -c '...')"` 區塊內）：
```python
output_style = g(d, "output_style", "name") or ""
session_name = g(d, "session_name") or ""
wall_ms = g(d, "cost", "total_duration_ms")
wt_name = g(d, "worktree", "name") or g(d, "workspace", "git_worktree") or ""
```

**輸出新變數**：`OUTPUT_STYLE`、`SESSION_NAME`、`WALL_TIME`、`WORKTREE_NAME`、`IS_5H_COOLDOWN`、`IS_7D_COOLDOWN`。

**冷卻偵測**（用原始浮點值）：
```python
is_5h_cooldown = 1 if (five_h is not None and float(five_h) >= 100.0) else 0
is_7d_cooldown = 1 if (seven_d is not None and float(seven_d) >= 100.0) else 0
```

**Bash 端**：
- `OUTPUT_STYLE` 若為 `"default"` 或空 → 不顯示該段
- `SESSION_NAME` / `WORKTREE_NAME` → 已經過 Python `sh()` 做 sanitize（去除 `"\$\`\n`）
- `WALL_TIME` 走現有 `fmt_ms()` 格式化（若 `wall_ms` 為 0 或 null 則為空字串）
- `status_bar()` 內 reset_str 組裝改用對應主題的冷卻 icon，由 `IS_*_COOLDOWN` 決定

**B2 effort 著色改寫**（RPG 分支）：
```bash
max)    EFFORT_ICON="${BOLD}\033[7m${MAGENTA}${EFFORT_MAX}${RESET}" ;;   # reverse + magenta bold
xhigh)  EFFORT_ICON="${BOLD}${MAGENTA}${EFFORT_XHIGH}${RESET}" ;;         # magenta bold
high)   EFFORT_ICON="${BRIGHT_RED}${EFFORT_HIGH}${RESET}" ;;              # 現狀不變
```

Bloom 分支只改 `max`：`${BOLD}${EFFORT_MAX}${RESET}`。

### §4 邊界條件

| 情況 | 處理 |
|---|---|
| `cost.total_duration_ms < cost.total_api_duration_ms` | 照原值顯示，不做修正（極罕見） |
| `wall_ms` 為 0 或 null | 不顯示 `/⏱` 尾巴 |
| `output_style.name` 為 `"default"` 或空 | 視為未設定，不顯示 |
| `session_name` / `worktree name` 含非 ASCII | 照字面輸出（terminal 編碼處理） |
| `worktree.name` 與 `workspace.git_worktree` 同時有值 | 優先 `worktree.name` |
| `used_percentage = 99.99` | **不**觸發冷卻符號（浮點比較，非取整） |
| `used_percentage = 100.0000001` | 觸發冷卻符號 |

## 測試計畫

Bash + Python3 腳本無 test framework，使用 mock JSON 灌 stdin 驗證：

```bash
# 基礎回歸（新欄位都該不顯示）
echo '{"model":{"display_name":"Opus"}}' | ./statusline-hp.sh

# 完整情境（所有新欄位皆顯示）
echo '{"model":{"display_name":"Opus"}, "output_style":{"name":"explanatory"}, "session_name":"my-feature", "workspace":{"git_worktree":"feature-xyz"}, "cost":{"total_cost_usd":2.8,"total_api_duration_ms":134000,"total_duration_ms":2700000,"total_lines_added":87,"total_lines_removed":12}, "rate_limits":{"seven_day":{"used_percentage":100.0,"resets_at":1000000000}}}' | ./statusline-hp.sh
```

**驗證矩陣**（兩個主題各跑一次）：

| 情境 | 預期 |
|---|---|
| 基線（無 A/B 欄位） | 輸出與現狀完全一致（回歸） |
| `output_style=explanatory` | 出現 `📖explanatory`（RPG）/ `🌻explanatory`（Bloom） |
| `output_style=default` | 不顯示（避免噪音） |
| `session_name=my-feature` | 出現 `#my-feature` |
| `workspace.git_worktree=wt-a` | 出現 `🌳wt-a` |
| `worktree.name=wt-x` + `workspace.git_worktree=wt-a` | 出現 `🌳wt-x`（優先序正確） |
| `total_duration_ms=2700000` + `api_duration_ms=134000` | `🔮 2m14s/⏱45m` |
| `total_duration_ms=0` | `🔮 2m14s`（無 `/⏱` 尾巴） |
| 7d `used_percentage=100.0` | `↻` → `⏳`（RPG）/ `💤`（Bloom） |
| 7d `used_percentage=99.99` | 仍顯示 `↻`（浮點嚴格比較） |
| 5h `used_percentage=100.0` | 冷卻符號觸發（與 7d 對稱） |
| effort=`max`（Opus 非 Haiku） | RPG 背景反白；Bloom 加粗 |
| effort=`xhigh` | RPG 加粗；Bloom 不變 |
| effort=`high` | 現狀不變（回歸） |

## 開放問題

無。所有設計決策已於 brainstorming 階段確認。
