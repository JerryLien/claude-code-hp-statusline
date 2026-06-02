# Statusline PR 徽章：顯示分支的開啟中 PR

**日期**：2026-06-02
**範圍**：`statusline-hp.sh`、`tests/statusline.test.sh`、`README.md`、`CHANGELOG.md`、`VERSION`

## 背景

Claude Code 的 statusline JSON 輸入新增了 `pr.*` 欄位（對應底部狀態列的 PR 徽章），目前腳本（0.4.0）尚未消費：

- `pr.number` — 目前分支對應的開啟中 PR 編號
- `pr.url` — 該 PR 的網址
- `pr.review_state` — 審查狀態，值為 `approved` / `pending` / `changes_requested` / `draft`，可能獨立缺漏

`pr` 物件只有在找到開啟中的 PR 時才出現，PR 合併或關閉後就移除。比對 Claude Code `2.1.159` 的 schema，現有腳本消費的欄位全部仍在、無破壞性變更；`pr.*` 是少數既新增又契合「一眼掌握狀態」定位的欄位，因此新增顯示。

## 目標

- P1 解析 `pr.number` / `pr.url` / `pr.review_state`，在 row1 顯示 PR 徽章
- P2 徽章依審查狀態以「字形 + 顏色」雙重編碼（色盲與黑白終端也能辨識）
- P3 把徽章包成 OSC 8 可點超連結，連到 `pr.url`
- P4 同步擴充 row 寬度量測，使其能 strip OSC 8 序列，避免折行誤判
- P5 補文件：README 新增 PR 徽章說明，並補 `hideVimModeIndicator` / `refreshInterval` 兩個設定建議

## 非目標

- 顯示 `pr.*` 以外的新欄位（`workspace.repo.*`、`workspace.project_dir`、`context_window.remaining_percentage` 等）
- 改動既有欄位的順序或樣式（PR 徽章只做加法，插在 worktree/branch 之後）
- 新增主題
- **不處理 ultracode 顯示**：ultracode 是 session 設定（送模型 `xhigh` + 自動編排 dynamic workflows），官方 schema 明寫「ultracode 不是獨立的 effort 等級，回報為 `xhigh`」。statusline 收到的 `effort.level` 在 ultracode 與一般 xhigh 下同為 `xhigh`，本機 env 也只有 `CLAUDE_EFFORT=xhigh`、無專屬變數，資料層無法區分。現有 xhigh 樣式（RPG 粗體洋紅 `⇈xhigh` / Bloom `🟣 xhigh`）在 ultracode session 已會亮起。待官方暴露「ultracode on」或「active workflow」訊號再議。

## 設計

### §1 Layout 與顯示規則

PR 徽章插在 row1 的 git 脈絡區，緊接 `🌳worktree⎇branch` 之後、`·agent` 之前，讓「目錄 → worktree → branch → PR」聚成一組。

**RPG 目標外觀**（`▸` 標示新增項，實際輸出不含）：
```
⚔ Opus 📁 repo 🌳feature⎇branch ▸🔀#1234✓ ·agent ↑high 📖explanatory
```

**Bloom 目標外觀**：
```
🌱 Opus 📁 repo 🌳feature⎇branch ▸🌷#1234✓ ·agent 🔴 high 🌻explanatory
```

**徽章格式**：`{ICON}#{NUMBER}{GLYPH}`，整段（含 ICON、編號、字形）以同一個審查狀態顏色著色，再整段包進 OSC 8 超連結。

**字形 + 顏色對照**：

| review_state | 字形 | 顏色 |
|---|---|---|
| `approved` | `✓` | `BRIGHT_GREEN` |
| `pending` | `…` | `BRIGHT_YELLOW` |
| `changes_requested` | `✗` | `BRIGHT_RED` |
| `draft` | `✎` | `GRAY` |
| 缺漏（`pr` 在但 `review_state` 不在） | 無字形 | `CYAN`（中性） |

**顯示條件**：

| 欄位 | 條件 |
|---|---|
| 整個 PR 徽章 | `pr.number` 存在且為正整數 |
| 字形 + 狀態顏色 | `pr.review_state` 為上表四值之一；否則走「缺漏」列（中性青、無字形） |
| OSC 8 超連結 | `pr.url` 存在且非空；否則徽章退化為純文字（仍正常顯示） |

**空白規則**：徽章前用單空白；`pr.number` 不存在時連同前導空白一併省略，避免雙空白洞（比照既有欄位）。

### §2 主題對照

| 元素 | RPG | Bloom |
|---|---|---|
| 前導 PR 圖示 | `🔀` | `🌷` |
| 狀態字形 | `✓ … ✗ ✎`（兩主題共用，theme-agnostic） | 同左 |
| 狀態顏色 | 綠/黃/紅/灰/青 | 同左 |

狀態字形與顏色刻意做成 theme-agnostic，比照 0.4.0 的 worktree / added_dirs 指示；只有前導圖示跟著主題走。

### §3 解析與顯示邏輯

**Python 端新增**（現有 `eval "$(INPUT=... python3 -c '...')"` 區塊內）：
```python
pr_number = g(d, "pr", "number")
pr_url = g(d, "pr", "url") or ""
pr_review = (g(d, "pr", "review_state") or "").lower()

def pos_int(v):
    try:
        return int(v) if int(v) > 0 else 0
    except (TypeError, ValueError):
        return 0
pr_num_int = pos_int(pr_number)
```

**輸出新變數**：`PR_NUMBER`（整數，0 表示不顯示）、`PR_URL`（經 `sh()` 消毒）、`PR_REVIEW`（小寫狀態字串）。

```python
print(f"PR_NUMBER={pr_num_int}")
print(f"PR_URL=\"{sh(pr_url)}\"")
print(f"PR_REVIEW=\"{sh(pr_review)}\"")
```

**Bash 端主題設定**（`case "$THEME"` 內，比照其他主題變數）：
```bash
# bloom
PR_ICON="🌷"
# rpg（預設）
PR_ICON="🔀"
```

**Bash 端徽章組裝**（row1，worktree 區塊之後、agent 之前）：
```bash
if [ "${PR_NUMBER:-0}" -gt 0 ] 2>/dev/null; then
  case "$PR_REVIEW" in
    approved)          pr_glyph="✓"; pr_color="$BRIGHT_GREEN" ;;
    pending)           pr_glyph="…"; pr_color="$BRIGHT_YELLOW" ;;
    changes_requested) pr_glyph="✗"; pr_color="$BRIGHT_RED" ;;
    draft)             pr_glyph="✎"; pr_color="$GRAY" ;;
    *)                 pr_glyph="";  pr_color="$CYAN" ;;
  esac
  pr_text="${PR_ICON}#${PR_NUMBER}${pr_glyph}"
  if [ -n "$PR_URL" ]; then
    # OSC 8 超連結：ESC]8;;URL ST  text  ESC]8;; ST
    pr_badge="\033]8;;${PR_URL}\033\\${pr_color}${pr_text}${RESET}\033]8;;\033\\"
  else
    pr_badge="${pr_color}${pr_text}${RESET}"
  fi
  parts_row1+=" ${pr_badge}"
fi
```

**P4 寬度量測擴充**：row 寬度量測的 python（`dw()`）目前只 strip SGR 色碼：
```python
ANSI_RE = re.compile(r"(?:\x1b|\\033)\[[0-9;]*m")
```
需再 strip OSC 8 序列（含其中的 URL 字元），在 SGR strip **之前**先套用一條 `OSC8_RE`。

> **實作注意（細節由測試釘死，spec 不釘死 regex 字面）**：寬度量測拿到的 parts 字串是**未經 `echo -e`** 的字面形式，escape 是 4 個字元的 `\033`（不是真 ESC byte），OSC 8 的 ST 終止符在變數裡是 `\033\`（字面 `\033` + **單一**反斜線）。因此 regex 必須同時處理「真 ESC byte（`\x1b`）」與「字面 `\033`」兩種形式，且 ST 尾端是單一反斜線。正確性以下方測試矩陣的「寬度等值」案例為準：含 OSC 8 的 row1 經 `dw()` 後，寬度必須等同把徽章換成純文字 `🔀#1234✓` 的寬度。實作時用該測試驅動 regex（TDD），不在 spec 預先固定可能出錯的字面。

這樣只有可見的 `🔀#1234✓` 進入寬度計算，URL 與 OSC 8 控制序列不計入。

### §4 邊界條件

| 情況 | 處理 |
|---|---|
| 無 `pr` 物件 | `PR_NUMBER=0` → 徽章整段隱藏（含前導空白） |
| `pr` 在但 `pr.number` 缺/非正整數 | 視為無 PR，不顯示 |
| `pr` 在、`review_state` 缺 | 顯示中性青徽章、無字形（仍可點，若有 url） |
| `pr.review_state` 為未知值（schema 演進） | 落到 `*)` → 中性青、無字形（安全降級） |
| `pr.url` 缺/空 | 徽章退化為純文字，不包 OSC 8 |
| `pr.url` 含 `"\$\`\n` | 經 `sh()` 消毒去除（URL 正常情況不含這些） |
| 終端不支援 OSC 8 | 多數會忽略控制序列、顯示純文字（可接受降級） |

## 測試計畫

沿用 `tests/statusline.test.sh` 既有 harness（mock JSON 灌 stdin、grep 斷言），兩主題各驗。比照 0.4.0 走正負案例。

**驗證矩陣**：

| 情境 | 預期 |
|---|---|
| 無 `pr`（基線回歸） | 不出現任何 `🔀` / `🌷` / `#` PR 徽章 |
| `pr.number=1234` + `review_state=approved` | 出現 `🔀#1234✓`（RPG）/ `🌷#1234✓`（Bloom），綠色 |
| `review_state=pending` | 字形 `…`、黃色 |
| `review_state=changes_requested` | 字形 `✗`、紅色 |
| `review_state=draft` | 字形 `✎`、灰色 |
| `pr.number=1234`、無 `review_state` | `🔀#1234`（無字形）、青色 |
| `pr.number=1234`、`review_state=weird` | 落到中性青、無字形（未知值安全降級） |
| `pr` 在但 `number` 缺 | 不顯示徽章 |
| `pr.url` 存在 | 輸出含 OSC 8 序列（`grep` `]8;;` + url） |
| `pr.url` 缺 | 輸出不含 OSC 8 序列，仍顯示 `🔀#1234` |
| 寬度量測：含 OSC 8 的 row1 | `dw()` 回傳值等同純文字徽章的寬度（URL 不計入），不誤折行 |
| 位置 | PR 徽章出現在 `🌳worktree` 之後、`·agent` 之前 |

## 版本與文件

- `VERSION` 與腳本內 `STATUSLINE_HP_VERSION` 同步 bump 到 `0.5.0`（兩者必須一起改，否則自更新徽章判斷會錯）
- `CHANGELOG.md` 新增 `[0.5.0]` 段落
- `README.md` 新增 PR 徽章說明；另補兩個設定建議：
  - `hideVimModeIndicator: true` — 腳本自繪 `⌨N` vim 指示，開此設定避免內建 `-- INSERT --` 重複
  - `refreshInterval` — 腳本有 reset 倒數，設此值可讓倒數在 session 閒置時仍持續更新

## 開放問題

無。所有設計決策已於 brainstorming 階段確認（內容=編號+字形+顏色、圖示=rpg🔀/bloom🌷、可點連結=是、位置=row1、版本=0.5.0）。
