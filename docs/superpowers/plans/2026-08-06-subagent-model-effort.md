# Subagent 列 model／effort／context 變色 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 `subagentStatusLine` 的每一列顯示該 subagent 的 model 縮寫、effort 短符號，並讓 token 數依 context 使用率變色。

**Architecture:** 所有改動集中在 `statusline-hp.sh` 開頭那段 subagent 專用的 Python 區塊（第 23-131 行，`if [[ "$input" == *'"tasks"'* ]]` 之內）。該區塊已經逐一走訪 `tasks[]` 並組出 `parts` 陣列；本次新增三個純函式（`short_model`、`effort_badge`、`token_color`）與對應的 `parts` 組裝邏輯，主列（第 133 行以後）完全不動。

**Tech Stack:** Bash 4+、Python 3（標準庫，無外部相依）、既有的 `tests/statusline.test.sh` 測試框架。

## Global Constraints

- **單引號 heredoc 禁用單引號字元**：subagent 區塊是 `python3 -c '…'` 單引號包起來的，區塊內的**程式碼與註解一律不得出現 `'` 字元**（含英文所有格與縮寫，如 `don't`、`agent's`）。違反會直接讓 shell 解析失敗。
- **測試指令**：`./tests/statusline.test.sh`，必須 100% PASS 才算完成。
- **ANSI 顏色常數**（與主列 `statusline-hp.sh:350-361` 一致，subagent 區塊需自行定義）：
  - `RESET="\033[0m"`、`BOLD="\033[1m"`、`WHITE="\033[97m"`、`CYAN="\033[36m"`、`GRAY="\033[90m"`（區塊內已有）
  - 本次新增：`MAGENTA="\033[35m"`、`BRIGHT_RED="\033[91m"`、`BRIGHT_YELLOW="\033[93m"`、`RED="\033[31m"`、`YELLOW="\033[33m"`、`REVERSE="\033[7m"`
- **變色門檻**（與主列 `ctx_bar` 一致）：`pct >= 90` → RED；`pct >= 70` → YELLOW；其餘 → CYAN
- **測試 pattern 要用 JSON 編碼後的形式**：subagent 區塊的輸出是 `json.dumps()` 產生的 JSON 行，ESC（0x1b）依 JSON 規格一律被編碼成**字面的六個字元** `\u001b`（`ensure_ascii=False` 只影響非 ASCII 字元，控制字元照 escape）。因此 subagent 測試的顏色 pattern 必須寫成單引號字串 `'\u001b[90m…'`，**不能**用主列測試那種 `$'\033[90m…'`（真實 escape 位元組）——後者永遠不會命中。實測輸出：`{"id": "a", "content": "⚔ \u001b[1m…"}`
- **既有 per-task `try/except` 不可移除**：新解析全部放在其內，單一 task 出錯不得影響其他列
- **版本號**：完成後 `VERSION` 檔與 `statusline-hp.sh:11` 的 `STATUSLINE_HP_VERSION` 必須同為 `0.8.0`
- **Commit message 一律英文**，conventional commits 風格，**不得含 Linear 單號**

---

### Task 1: model 縮寫

**Files:**
- Modify: `statusline-hp.sh`（subagent Python 區塊，於 `def elapsed` 之後新增函式；於 `parts = [glyph, …]` 之後組裝）
- Test: `tests/statusline.test.sh`（C9 區段末尾，`c9-tasks-substring-main-mode` 之後）

**Interfaces:**
- Produces: `short_model(v) -> str`，接受任意型別，回傳可直接顯示的短名或空字串。Task 2 會在它回傳空字串時決定 `·` 分隔符是否出現。

- [ ] **Step 1: Write the failing test**

在 `tests/statusline.test.sh` 的 `assert_contains "c9-tasks-substring-main-mode" …` 那一組之後插入：

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/statusline.test.sh 2>&1 | grep -E "c9-model|FAIL|PASS:.*c9-model"`
Expected: `c9-model-full-id-shortens` 等 FAIL（輸出不含 `·haiku`）；`c9-model-absent-no-dot` 這類 `assert_not_contains` 會 PASS（因為功能還沒做，本來就沒有 `·`）。

- [ ] **Step 3: Write minimal implementation**

在 `statusline-hp.sh` 的 subagent Python 區塊，找到 `def elapsed(start_ms):` 整個函式結束之後（緊接 `for t in tasks:` 之前），插入：

```python
MODEL_SHORTS = ("fable", "opus", "sonnet", "haiku")

def short_model(v):
    # Normalise a model id or alias to a short display name.
    # Values arrive as either a full id (claude-haiku-4-5-20251001) or an alias (haiku).
    if not isinstance(v, str):
        return ""
    s = v.strip().lower()
    if not s or s == "inherit":
        return ""
    for name in MODEL_SHORTS:
        if name in s:
            return name
    return s[:12]
```

接著在 `for t in tasks:` 迴圈內，找到這一行：

```python
        parts = [glyph, f"{BOLD}{WHITE}{str(name)}{RESET}"]
```

在其**正下方**插入：

```python
        sm = short_model(t.get("model"))
        if sm:
            parts[-1] += f"{GRAY}·{sm}{RESET}"
```

> 註：分隔符是 U+00B7 middle dot（`·`），與 row1 既有的 `·agent` 分隔符同一個字元。

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/statusline.test.sh`
Expected: 全數 PASS（含既有案例；`c9-model-*` 全綠）

- [ ] **Step 5: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "feat(subagent): show shortened model name per task row"
```

---

### Task 2: effort 短符號

**Files:**
- Modify: `statusline-hp.sh`（subagent Python 區塊：主題常數區、`short_model` 之後新增函式、`parts` 組裝）
- Test: `tests/statusline.test.sh`（接在 Task 1 的案例之後）

**Interfaces:**
- Consumes: Task 1 的 `short_model()`（effort 徽章緊接在 model 縮寫之後，兩者共用同一個 `parts[-1]`）
- Produces: `effort_badge(v) -> str`，回傳已上色、可直接串接的字串或空字串

- [ ] **Step 1: Write the failing test**

在 Task 1 的測試之後插入：

```bash
# --- 0.8.0: effort 短符號 ---
# rpg：符號 + 主列同款 ANSI
assert_contains "c9-effort-max-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"max","tokenCount":5}]}' \
  '\u001b[7m\u001b[1m\u001b[35m★'
assert_contains "c9-effort-xhigh-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"xhigh","tokenCount":5}]}' \
  '\u001b[1m\u001b[35m⇈'
assert_contains "c9-effort-high-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"high","tokenCount":5}]}' \
  '\u001b[91m↑'
assert_contains "c9-effort-medium-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"medium","tokenCount":5}]}' \
  '\u001b[93m~'
assert_contains "c9-effort-low-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"low","tokenCount":5}]}' \
  '\u001b[90m↓'
# 大小寫不敏感
assert_contains "c9-effort-case-insensitive" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"HIGH","tokenCount":5}]}' \
  '\u001b[91m↑'
# bloom：emoji 自帶顏色，不加 ANSI（max 也不反白）
assert_contains "c9-effort-max-bloom" "bloom" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"max","tokenCount":5}]}' \
  "⚫"
assert_contains "c9-effort-high-bloom" "bloom" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"high","tokenCount":5}]}' \
  "🔴"
assert_not_contains "c9-effort-max-bloom-no-reverse" "bloom" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"max","tokenCount":5}]}' \
  '\u001b[7m'
# 數字 token budget → compact 灰字，不配符號
assert_contains "c9-effort-numeric-budget" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":30000,"tokenCount":5}]}' \
  '\u001b[90m30.0k'
assert_contains "c9-effort-numeric-string-budget" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"30000","tokenCount":5}]}' \
  '\u001b[90m30.0k'
# 缺席（繼承 session effort）不顯示
assert_not_contains "c9-effort-absent-rpg" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":5}]}' \
  "↑"
# 未知等級字串不顯示
assert_not_contains "c9-effort-unknown-level" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"ludicrous","tokenCount":5}]}' \
  "★"
# model + effort 並存的完整組合
assert_contains "c9-model-and-effort-together" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","model":"haiku","effort":"high","tokenCount":5}]}' \
  '\u001b[90m·haiku\u001b[0m\u001b[91m↑'
# model 缺席但 effort 存在：符號直接接名稱，不出現分隔符
assert_not_contains "c9-effort-without-model-no-dot" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","effort":"high","tokenCount":5}]}' \
  "·"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/statusline.test.sh 2>&1 | grep -E "c9-effort|c9-model-and-effort"`
Expected: `c9-effort-max-rpg` 等 `assert_contains` 案例 FAIL

- [ ] **Step 3: Write minimal implementation**

**3a.** 在 subagent Python 區塊找到既有的顏色常數行：

```python
RESET = "\033[0m"; BOLD = "\033[1m"; WHITE = "\033[97m"
CYAN = "\033[36m"; GRAY = "\033[90m"
```

在其下方插入：

```python
MAGENTA = "\033[35m"; BRIGHT_RED = "\033[91m"; BRIGHT_YELLOW = "\033[93m"
RED = "\033[31m"; YELLOW = "\033[33m"; REVERSE = "\033[7m"
```

**3b.** 在既有的 `if bloom:` / `else:` 主題分支中，各自加入 effort 對照表。找到 bloom 分支：

```python
if bloom:
    DONE = {"completed": "\U0001F338", "failed": "\U0001F940", "killed": "\U0001F940"}
    RUN = "\U0001F331"; WAIT = "\U0001F4A4"; CLOCK = "⏱"
    SPARK = ["\U0001F331", "\U0001F33F", "\U0001F338", "\U0001F33C"]; SPARK_N = 4
```

在 `SPARK_N = 4` 那行下方插入（縮排對齊）：

```python
    EFFORTS = {
        "max": "⚫", "xhigh": "\U0001F7E3", "high": "\U0001F534",
        "medium": "\U0001F7E1", "low": "\U0001F535",
    }
    EFFORT_STYLES = {"max": "", "xhigh": "", "high": "", "medium": "", "low": ""}
```

找到 else 分支：

```python
else:
    DONE = {"completed": "\U0001F480", "failed": "☠", "killed": "☠"}
    RUN = "⚔"; WAIT = "⏳"; CLOCK = "♔"
    SPARK = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]; SPARK_N = 8
```

在 `SPARK_N = 8` 那行下方插入（縮排對齊）：

```python
    EFFORTS = {
        "max": "★", "xhigh": "⇈", "high": "↑", "medium": "~", "low": "↓",
    }
    EFFORT_STYLES = {
        "max": REVERSE + BOLD + MAGENTA, "xhigh": BOLD + MAGENTA,
        "high": BRIGHT_RED, "medium": BRIGHT_YELLOW, "low": GRAY,
    }
```

**3c.** 在 Task 1 的 `short_model` 函式之後插入：

```python
def effort_badge(v):
    # Per-task reasoning effort: either a level string or a numeric token budget.
    # Absent means the subagent inherits the session level, so render nothing.
    if isinstance(v, bool) or v is None:
        return ""
    if isinstance(v, (int, float)):
        return f"{GRAY}{compact(v)}{RESET}"
    if not isinstance(v, str):
        return ""
    s = v.strip()
    if not s:
        return ""
    lvl = s.lower()
    if lvl in EFFORTS:
        return f"{EFFORT_STYLES[lvl]}{EFFORTS[lvl]}{RESET}"
    try:
        return f"{GRAY}{compact(float(s))}{RESET}"
    except (TypeError, ValueError):
        return ""
```

**3d.** 在 Task 1 插入的 model 組裝之後（`parts[-1] += f"{GRAY}·{sm}{RESET}"` 那個 `if` 區塊的正下方）插入：

```python
        eb = effort_badge(t.get("effort"))
        if eb:
            parts[-1] += eb
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/statusline.test.sh`
Expected: 全數 PASS

- [ ] **Step 5: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "feat(subagent): show per-task reasoning effort badge"
```

---

### Task 3: token 數依 context 使用率變色

**Files:**
- Modify: `statusline-hp.sh`（subagent Python 區塊：`effort_badge` 之後新增函式、token 組裝那行）
- Test: `tests/statusline.test.sh`（接在 Task 2 的案例之後）

**Interfaces:**
- Consumes: Task 2 定義的 `RED` / `YELLOW` / `CYAN` 常數
- Produces: `token_color(count, size) -> str`，回傳顏色 ANSI 或空字串（空＝不變色）

- [ ] **Step 1: Write the failing test**

在 Task 2 的測試之後插入：

```bash
# --- 0.8.0: token 數 HP 變色（門檻同主列 ctx_bar：>=90 紅、>=70 黃、其餘青）---
# 69% → CYAN（邊界下緣）
assert_contains "c9-token-color-cyan-69" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":69000,"contextWindowSize":100000}]}' \
  '\u001b[36m69.0k'
# 70% → YELLOW（邊界）
assert_contains "c9-token-color-yellow-70" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":70000,"contextWindowSize":100000}]}' \
  '\u001b[33m70.0k'
# 89% → YELLOW（邊界上緣）
assert_contains "c9-token-color-yellow-89" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":89000,"contextWindowSize":100000}]}' \
  '\u001b[33m89.0k'
# 90% → RED（邊界）
assert_contains "c9-token-color-red-90" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":90000,"contextWindowSize":100000}]}' \
  '\u001b[31m90.0k'
# 超過 100% 仍是紅、數字照實顯示
assert_contains "c9-token-color-red-over-100" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":150000,"contextWindowSize":100000}]}' \
  '\u001b[31m150.0k'
# contextWindowSize 缺席 → 不變色（維持現行白字，輸出僅有裸 token 數）
assert_not_contains "c9-token-no-ctxsize-no-color" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":38200}]}' \
  '\u001b[36m38.2k'
assert_contains "c9-token-no-ctxsize-plain" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":38200}]}' \
  "38.2k"
# contextWindowSize 為 0 → 不變色（不得除以零）
assert_contains "c9-token-zero-ctxsize-plain" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":38200,"contextWindowSize":0}]}' \
  "38.2k"
# tokenCount 缺席視為 0 → CYAN
assert_contains "c9-token-absent-count-cyan" "rpg" \
  '{"tasks":[{"id":"a","status":"running","label":"x","contextWindowSize":100000}]}' \
  '\u001b[36m0'
# bloom 主題共用同一套門檻
assert_contains "c9-token-color-red-bloom" "bloom" \
  '{"tasks":[{"id":"a","status":"running","label":"x","tokenCount":95000,"contextWindowSize":100000}]}' \
  '\u001b[31m95.0k'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/statusline.test.sh 2>&1 | grep -E "c9-token-color|c9-token-absent"`
Expected: 帶顏色的 `assert_contains` 案例 FAIL

- [ ] **Step 3: Write minimal implementation**

在 Task 2 的 `effort_badge` 函式之後插入：

```python
def token_color(count, size):
    # Colour the token count by context usage, using the same thresholds as the
    # main row context bar. Missing or non-positive window size means no colour.
    try:
        size = float(size)
        count = float(count)
    except (TypeError, ValueError):
        return ""
    if size <= 0:
        return ""
    pct = int(count * 100 / size)
    if pct >= 90:
        return RED
    if pct >= 70:
        return YELLOW
    return CYAN
```

接著在 `for t in tasks:` 迴圈內找到這一行：

```python
        parts.append(compact(t.get("tokenCount") or 0))
```

**整行替換為**：

```python
        tc = t.get("tokenCount") or 0
        tcol = token_color(tc, t.get("contextWindowSize"))
        parts.append(f"{tcol}{compact(tc)}{RESET}" if tcol else compact(tc))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/statusline.test.sh`
Expected: 全數 PASS

- [ ] **Step 5: Commit**

```bash
git add statusline-hp.sh tests/statusline.test.sh
git commit -m "feat(subagent): colour token count by context usage"
```

---

### Task 4: 版本 bump 與文件

**Files:**
- Modify: `VERSION`
- Modify: `statusline-hp.sh:11`（`STATUSLINE_HP_VERSION`）
- Modify: `CHANGELOG.md`
- Modify: `README.md`（subagent statusline 段落）

**Interfaces:**
- Consumes: Task 1-3 的完成狀態（文件描述必須與實際行為一致）

- [ ] **Step 1: 確認前置任務全綠**

Run: `./tests/statusline.test.sh | tail -5`
Expected: `FAIL: 0`（或等效的全數通過訊息）

- [ ] **Step 2: 同步 bump 兩處版本號**

`VERSION` 檔內容整個替換為：

```
0.8.0
```

`statusline-hp.sh` 第 11 行：

```bash
STATUSLINE_HP_VERSION="0.8.0"
```

- [ ] **Step 3: 驗證版本一致**

Run: `grep -n 'STATUSLINE_HP_VERSION="' statusline-hp.sh && cat VERSION`
Expected: 兩者都顯示 `0.8.0`

- [ ] **Step 4: 補 CHANGELOG**

在 `CHANGELOG.md` 最上方的版本段落**之前**插入（沿用檔案既有的標題與條列格式）：

```markdown
## 0.8.0

- Subagent rows now show the per-task model as a short name (`·haiku`, `·sonnet`, `·opus`, `·fable`); unknown model ids fall back to the raw value truncated to 12 characters, and the segment is omitted when the field is absent or `inherit`
- Subagent rows now show the per-task reasoning effort as a themed symbol (RPG `★⇈↑~↓`, Bloom `⚫🟣🔴🟡🔵`) matching the main row colours; a numeric token budget renders compact in grey, and an absent field (subagent inherits the session level) renders nothing. Requires Claude Code 2.1.214 or later
- Subagent token counts are now coloured by context usage (`tokenCount / contextWindowSize`) using the same thresholds as the main row context bar: cyan below 70%, yellow from 70%, red from 90%. Rows without `contextWindowSize` stay uncoloured
```

- [ ] **Step 5: 補 README**

`README.md` 第 88-92 行的整段（`Each running subagent gets a themed row:` 開頭那段）**整段替換為**：

```markdown
Each running subagent gets a themed row: status glyph (RPG `⚔` running / `💀`
completed / `☠` failed; Bloom `🌱` / `🌸` / `🥀`), agent name, the model short
name and reasoning effort, a token-burn sparkline built from the recent
`tokenSamples` history (`▂▃▅█` in RPG, flower stages in Bloom), the compact
token total, and elapsed time. Rows the script cannot render fall back to
Claude Code's default rendering automatically.

Since 0.8.0 each row also carries three per-task details:

- **`·model`** — the task model as a short name (`·haiku`, `·sonnet`, `·opus`,
  `·fable`). An unrecognised model id shows the raw value truncated to 12
  characters; the segment is omitted when the field is absent or `inherit`.
- **Effort symbol** — the task reasoning effort as `★` max, `⇈` xhigh, `↑` high,
  `~` medium, `↓` low in RPG (`⚫🟣🔴🟡🔵` in Bloom), coloured to match the main
  row. A numeric token budget renders compact in grey. Nothing renders when the
  subagent inherits the session effort. Requires Claude Code 2.1.214 or later.
- **Token colour** — the token total is coloured by context usage
  (`tokenCount / contextWindowSize`) on the same thresholds as the main row
  context bar: cyan below 70%, yellow from 70%, red from 90%. Rows without
  `contextWindowSize` stay uncoloured.
```

- [ ] **Step 6: 最終驗證**

Run: `./tests/statusline.test.sh | tail -5 && bash -n statusline-hp.sh && echo "syntax OK"`
Expected: 測試全綠且 `syntax OK`

- [ ] **Step 7: Commit**

```bash
git add VERSION statusline-hp.sh CHANGELOG.md README.md
git commit -m "chore: bump to 0.8.0 with subagent model/effort/context docs"
```

---

### Task 5: 本機補上 refreshInterval 設定

> 這一項不進 repo，是使用者本機 `~/.claude/settings.json` 的設定缺口（README 早有建議值，但本機一直沒設，導致 rate-limit 倒數在 session 閒置時凍住）。

**Files:**
- Modify: `~/.claude/settings.json`（僅 `statusLine` 物件）

- [ ] **Step 1: 先備份並確認現況**

Run:
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak-0.8.0
python3 -c "import json;print(json.dumps(json.load(open('/home/jerrylien/.claude/settings.json'))['statusLine'],indent=2))"
```
Expected: 顯示現有 `statusLine` 物件，其中**沒有** `refreshInterval`

- [ ] **Step 2: 加入 refreshInterval**

用 Edit 工具在 `~/.claude/settings.json` 的 `statusLine` 物件中，於 `"command"` 那一行之後加入 `"refreshInterval": 10`（注意前一行需補逗號）。結果應為：

```json
  "statusLine": {
    "type": "command",
    "command": "/home/jerrylien/.claude/statusline-hp.sh",
    "refreshInterval": 10
  },
```

**不要**改動 `subagentStatusLine`：官方文件說它每個 refresh tick 就會跑一次，本來就有自己的更新節奏，且未記載支援此欄位。

- [ ] **Step 3: 驗證 JSON 合法且值正確**

Run:
```bash
python3 -c "
import json
s = json.load(open('/home/jerrylien/.claude/settings.json'))
assert s['statusLine']['refreshInterval'] == 10, s['statusLine']
assert 'refreshInterval' not in s.get('subagentStatusLine', {}), s['subagentStatusLine']
print('settings OK:', json.dumps(s['statusLine']))
"
```
Expected: 印出 `settings OK: …` 且不拋例外。若 JSON 解析失敗，立刻用備份還原：`cp ~/.claude/settings.json.bak-0.8.0 ~/.claude/settings.json`

- [ ] **Step 4: 清掉備份**

Run: `rm ~/.claude/settings.json.bak-0.8.0`

---

## 完成後

四個 repo 任務完成後分支上會有四個 commit。建議推分支開 PR（`gh pr create`），標題沿用 repo 慣例：`feat: subagent model/effort badges and context-coloured token count (0.8.0)`。

依 memory 記載的 release flow：`VERSION` 與 `STATUSLINE_HP_VERSION` 同步 bump 後推上 main，已安裝的使用者會在 6 小時內看到 `📦 sl→0.8.0` 徽章。本機開發仍應從 local repo 複製安裝，不要走 `/statusline-update`。
