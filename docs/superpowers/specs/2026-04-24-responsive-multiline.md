# Statusline 自動換行：Responsive Multi-line

**日期**：2026-04-24
**範圍**：`statusline-hp.sh`

## 背景

8 個新欄位加入後，statusline 單行寬度膨脹到 ~200 cols。80 cols 終端機上：
1. 右側 `版本` 等資訊被截斷看不到
2. `⏱` (U+23F1, East Asian Width = Ambiguous) 和 `🕰` (U+1F570) 的寬度歧義導致終端游標位置錯位，後續字元與 emoji 重疊

單行設計已不適合所有終端寬度。

## 目標

- 窄螢幕自動換成 2 行顯示，資訊不截斷
- 寬螢幕維持單行（不浪費空間）
- 切線條件用**精確的顯示寬度計算**（非固定閾值）
- 消除 `⏱` / `🕰` 造成的視覺重疊

## 非目標

- 3 行以上的版面
- 依終端能力偵測 emoji 支援度（假設使用者終端支援 UTF-8）
- 按資訊優先序丟棄欄位（不做 option C）

## 設計

### §1 分行位置

**Row 1 — 身分／狀態**：
```
MODEL_ICON MODEL #SESSION 🌳WT ·AGENT EFFORT ⚠effort STYLE VIM
```

**Row 2 — 用量／指標**：
```
5h  7d  🧠 CTX  ⚡CACHE  ⚠200k  🔮 API/WALL  💰 COST  +/-  VERSION
```

### §2 Wall time 重疊修復

拿掉 wall time 的 icon，改用 `/` 分隔：

| | 目前 | 改後 |
|---|---|---|
| RPG | `🔮 2m14s/⏱45m00s` | `🔮 2m14s/45m00s` |
| Bloom | `🌿 2m14s/🕰45m00s` | `🌿 2m14s/45m00s` |

`🔮` 與 `🌿` 是已知可靠寬度的 emoji，保留。

### §3 顯示寬度精算

在 Python 端新增 helper（跟既有 `fmt_ms`、`sh` 等放在一起）：

```python
import re, unicodedata

ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')

def display_width(s):
    """大致計算字串在終端的顯示寬度（cell 數）。"""
    s = ANSI_RE.sub('', s)
    w = 0
    for ch in s:
        # 跳過 combining marks
        if unicodedata.category(ch).startswith('M'):
            continue
        # East Asian Wide/Fullwidth：2 cells
        eaw = unicodedata.east_asian_width(ch)
        if eaw in ('W', 'F'):
            w += 2
            continue
        # Emoji / Misc Symbols (U+2600+)：大部分終端視為 2 cells
        if ord(ch) >= 0x2600:
            w += 2
            continue
        w += 1
    return w
```

此 helper 不在 Python 第一次被呼叫時使用（parts 還沒組好），而是**在 bash 組完 parts_row1 / parts_row2 後，用 `python3 -c` 再呼叫一次**測量寬度。這會多一次 python 啟動（~30-60ms），可接受。

### §4 Bash 端流程

1. **組裝兩段 parts 變數**：
   ```bash
   parts_row1=""   # 身分／狀態
   parts_row2=""   # 用量／指標
   ```
   現有的 `parts+=...` 呼叫依所屬區塊分配到 row1 或 row2。

2. **取得終端寬度**：
   ```bash
   cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
   ```
   優先用環境變數 `COLUMNS`（方便測試注入），退 `tput cols`，都失敗就保守用 120（偏向單行）。

3. **量測兩段寬度**：
   ```bash
   widths=$(printf '%s\n%s' "$parts_row1" "$parts_row2" | python3 -c '
   import sys, re, unicodedata
   # ... display_width(s) 同 §3 ...
   for line in sys.stdin.read().split("\n"):
       print(display_width(line))
   ')
   row1_w=$(echo "$widths" | sed -n "1p")
   row2_w=$(echo "$widths" | sed -n "2p")
   ```

4. **決定換行**：
   ```bash
   # 單行總長 = row1 + "  " + row2 = row1_w + 2 + row2_w
   # 加 4 cells 保險邊距（避免邊界誤判）
   total_w=$((row1_w + row2_w + 2 + 4))

   # 空行處理：某一行為空時只輸出有內容的那行
   if [ -z "$parts_row1" ]; then
     echo -e "$parts_row2"
   elif [ -z "$parts_row2" ]; then
     echo -e "$parts_row1"
   elif [ "$total_w" -gt "$cols" ]; then
     echo -e "$parts_row1"
     echo -e "$parts_row2"
   else
     echo -e "${parts_row1}  ${parts_row2}"
   fi
   ```

### §5 邊界條件

| 情況 | 處理 |
|---|---|
| `COLUMNS` 未設、`tput cols` 失敗 | 退 120，偏向單行顯示 |
| `parts_row2` 為空字串（Pro 使用者在 API 回應前） | 照算；單行顯示會變 `parts_row1` 加 "  "（尾端 trim？） |
| 使用者終端 < 40 cols（極窄） | 仍走 2 行，可能 row1 內部再折行（作業系統終端自己處理，我們不處理） |
| Row 1 / Row 2 本身就比終端寬 | 接受，終端自己折行（此設計只解決單行→雙行門檻問題） |
| `parts_row1` 尾端無內容、`parts_row2` 有內容（反之亦然） | 若某行為空則只 echo 有內容的那行（避免空白行） |

### §6 測試

Mock JSON + 環境變數 `COLUMNS=N` 操控寬度：

| 測試 | 設定 | 預期 |
|---|---|---|
| `mr-narrow-wraps` | `COLUMNS=80`，滿載 JSON（所有 feature 開啟） | 輸出含 `\n`（多行） |
| `mr-wide-single-line` | `COLUMNS=200`，滿載 JSON | 輸出**不含** `\n`（單行） |
| `mr-minimal-narrow` | `COLUMNS=80`，最小 JSON（只有 model） | 單行（row2 空） |
| `mr-no-wall-icon-rpg` | 有 wall time | 輸出含 `/45m`，**不含** `⏱` |
| `mr-no-wall-icon-bloom` | 有 wall time | 輸出含 `/45m`，**不含** `🕰` |
| `mr-default-120` | 無 `COLUMNS`、無 `tput`（模擬） | 保守單行 |
| `mr-row1-empty` | 只有 row2 欄位 | 只 echo row2，無空白行 |
| `mr-row2-empty` | 只有 row1 欄位 | 只 echo row1，無空白行 |

整合測試保留現有的 36 個，加入上述新情境。

Bash 測試輔助函式需新增：
```bash
run_with_cols() {
  local cols=$1 theme=$2 json=$3
  echo "$json" | COLUMNS="$cols" STATUSLINE_THEME="$theme" "$STATUSLINE" 2>&1
}
```

以及檢查「輸出是否含換行」的 assertion：
```bash
assert_multiline() { ... }
assert_single_line() { ... }
```

## 開放問題

無。所有決策已於 brainstorming 階段確認。

## 風險 / 已知限制

1. **`display_width` 的 emoji 啟發式不完美** — U+2600 以上皆算 2 cells 會把某些 1-cell 的符號（例如 `★` U+2605）也算成 2。但對 statusline 場景裡常用字元組合誤差小，實測 80 cols 可區分，足以決定換行門檻。
2. **多一次 python3 啟動開銷** — 實測 ~30-60ms，在 statusline 300ms debounce 內安全。
3. **`echo -e` 對控制字元的解讀** — 已有在用，不變。
