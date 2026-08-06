# Subagent 列：model 縮寫、effort 短符號、token 數 HP 變色（0.8.0）

**日期**：2026-08-06
**範圍**：`statusline-hp.sh`、`tests/statusline.test.sh`、`README.md`、`CHANGELOG.md`、`VERSION`

## 背景

Claude Code 2.1.214 在 `subagentStatusLine` 的 payload 加入了 `effort` 欄位。官方文件列出每個 task 的完整欄位為：`id`、`name`、`type`、`status`、`description`、`label`、`startTime`、`model`、`effort`、`contextWindowSize`、`tokenCount`、`tokenSamples`、`cwd`。其中 `model`、`effort`、`contextWindowSize`、`cwd` 是 0.7.0 subagent 列（PR #10）尚未消費的欄位。

從 2.1.223 的 CLI binary 直接驗證過 payload 組裝程式碼：

```js
model: h.model,                                        // 原樣傳遞，可能是完整 model ID 或別名
effort: h.effort,                                      // 定義 frontmatter 或單次呼叫設定的值
contextWindowSize: h.model ? wA(h.model, mT()) : void 0,  // 只有 model 存在時才有值
```

官方文件對 `effort` 的語意：值是 effort 等級字串（`low`/`medium`/`high`/`xhigh`/`max`）**或數字 token budget**；subagent 繼承 session effort 時**欄位缺席**；回報的是「設定寫什麼就是什麼」，模型不支援該等級時實際套用值可能不同。

## 目標

- P1 subagent 列在名稱後顯示 model 縮寫（灰字 `·model`）
- P2 model 後接 effort 短符號（主題化、只取符號不帶字，顏色同主列）
- P3 token 數依 `tokenCount ÷ contextWindowSize` 使用率變色（青→黃→紅，門檻同主列 ctx bar）
- P4 補測試：新欄位各種值域與缺席情境、變色門檻邊界
- P5 版本 bump 0.8.0、CHANGELOG、README subagent 段落更新

## 非目標

- **不使用 `columns` 做寬度截斷**：Claude Code 會自行截列，等實際遇到截斷問題再議
- **不使用 `cwd` 欄位**：目前想不到夠有價值的顯示方式
- 不改動 subagent 列既有元素（狀態圖示、名稱、火花圖、經過時間）的順序與樣式
- 不動主列

## 附帶動作（不入 repo）

本機 `~/.claude/settings.json` 的 `statusLine` 區塊補 `"refreshInterval": 10`（README 既有建議，使用者本機一直沒設，導致 rate-limit 倒數在 session 閒置時凍住）。`subagentStatusLine` 不加：官方文件說它每個 refresh tick 跑一次，本來就有自己的更新節奏，且未記載支援 `refreshInterval`。

## 設計

### §1 Layout

新元素全部聚在名稱區，其餘不動（`▸` 標示新增，實際輸出不含）：

```
rpg:   ⚔ code-reviewer▸·haiku⇈ ▃▅▇ 34.5k ♔2m10s
bloom: 🌱 code-reviewer▸·haiku🟣 🌱🌿🌸 34.5k ⏱2m10s
                                  └ 34.5k 依使用率變色
```

### §2 model 縮寫

`model` 值可能是完整 ID（`claude-haiku-4-5-20251001`）或別名（`haiku`），統一正規化：

1. 轉小寫後子字串比對，命中即顯示短名：含 `fable`→`fable`、`opus`→`opus`、`sonnet`→`sonnet`、`haiku`→`haiku`（依此順序）
2. 比不中：原樣小寫顯示，截 12 字元（未知的新 model 系列仍可辨識）
3. 欄位缺席、空字串、或值為 `inherit`：整段不顯示（`·` 分隔符也不出現）——`inherit` 對使用者是雜訊，不如不顯示

樣式：灰色（`GRAY`），以 `·` 接在名稱後，如 `code-reviewer·haiku`。

### §3 effort 短符號

只取主列 effort 符號、不帶等級文字，接在 model 縮寫後（無空格）：

| 等級 | rpg | rpg 樣式（同主列 `EFFORT_*_STYLE`） | bloom |
|---|---|---|---|
| max | `★` | 反白＋粗體＋洋紅 `\033[7m\033[1m\033[35m` | `⚫` |
| xhigh | `⇈` | 粗體＋洋紅 `\033[1m\033[35m` | `🟣` |
| high | `↑` | 亮紅 `\033[91m` | `🔴` |
| medium | `~` | 亮黃 `\033[93m` | `🟡` |
| low | `↓` | 灰 `\033[90m` | `🔵` |

- rpg 的顏色逐一對齊主列 `EFFORT_*_STYLE` 實際值（上表已從 `statusline-hp.sh:381-385, 406-410` 查證）；bloom 主列的 `EFFORT_*_STYLE` 除 max 為反白外皆為空字串，subagent 列比照辦理：emoji 自帶顏色，不加 ANSI，max 也不加反白（單一 emoji 反白顯示怪異）
- 比對不分大小寫（同主列 `${EFFORT,,}` 慣例）
- **數字 token budget**：以既有 `compact()` 格式灰字顯示（30000 → `30.0k`），不配符號；數字與全數字字串（`30000` / `"30000"`）皆走此路徑
- 欄位缺席（繼承 session effort）或空字串：不顯示
- model 缺席但 effort 存在：effort 符號直接接在名稱後（`·` 不出現）

### §4 token 數 HP 變色

```
pct = tokenCount * 100 / contextWindowSize   （整數截斷）
pct >= 90 → RED；pct >= 70 → YELLOW；其餘 → CYAN
```

- 門檻與顏色跟主列 `ctx_bar` 完全同套，看色即知同一語意
- 選項預覽階段曾寫「綠→黃→紅」，定案改「青→黃→紅」與主列一致（綠在本腳本是 worktree 色）——已於設計提案揭露並經使用者核可
- `contextWindowSize` 缺席、0、或非正數：**不變色**（維持現行無色樣式），不猜預設視窗大小
- `tokenCount` 缺席視為 0（現行行為），pct 為 0、顯示青色
- pct 超過 100 不 clamp 顯示顏色（仍是紅），token 數照實顯示

### §5 錯誤處理

全部新解析都在既有的 per-task `try/except` 之內：任一 task 的新欄位型別怪異（如 `model` 是數字、`effort` 是物件）時，該 task 落回最小可用顯示或被跳過，不影響其他列；整體 payload 解析失敗的行為不變（exit 1 落回主流程）。數值轉換（`effort` 數字判斷、pct 計算）各自 try/except，失敗即當作「缺席」處理。

### §6 測試

`tests/statusline.test.sh` 新增 subagent 案例（rpg 與 bloom 各驗核心組合）：

1. model 完整 ID（`claude-haiku-4-5-20251001`）→ 顯示 `·haiku`
2. model 別名（`sonnet`）→ 顯示 `·sonnet`
3. model 未知值（`claude-zeta-1`）→ 原樣截 12 字元
4. model 缺席／`inherit` → 無 `·` 段
5. effort 五等級各自的符號與顏色（rpg）／emoji（bloom）
6. effort 數字（`30000`）→ `30.0k` 灰字（字串 `"30000"` 同）
7. effort 缺席 → 無符號
8. 變色門檻邊界：pct 69→青、70→黃、89→黃、90→紅
9. `contextWindowSize` 缺席 → token 數無色
10. 既有案例全數不變（回歸）

### §7 版本

- `VERSION` 與 `statusline-hp.sh` 內嵌 `STATUSLINE_HP_VERSION` 同步 bump `0.8.0`
- `CHANGELOG.md` 新增 0.8.0 段落
- `README.md` subagent statusline 段落補新欄位說明與版本需求（effort 需 Claude Code ≥ 2.1.214）
