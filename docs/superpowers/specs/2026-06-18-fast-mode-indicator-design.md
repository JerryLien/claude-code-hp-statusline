# Statusline fast_mode 指示器：顯示 Opus 快速模式

**日期**：2026-06-18
**範圍**：`statusline-hp.sh`、`tests/statusline.test.sh`、`README.md`、`CHANGELOG.md`、`VERSION`

## 背景

Claude Code 的 statusline JSON 輸入有一個頂層布林欄位 `fast_mode`，對應 Opus 的快速模式（`/fast` 切換，目前可用於 Opus 4.8 / 4.7 / 4.6，以較高費率換取較快輸出）。目前腳本（0.5.0）尚未消費此欄位，使用者切換 `/fast` 後 statusline 完全無感。

比對 Claude Code `2.1.181` 實際二進位送出的 statusline 物件，欄位位置與形狀為：

```
…,context_window:…,exceeds_200k_tokens:t,fast_mode:n,…effort:{level:…},thinking:{enabled:…},…
```

- `fast_mode` 是**頂層布林**，與 `exceeds_200k_tokens` 同層、同模式。
- 來源是 session 的 `fastMode ?? false`；只有 Opus 系列才會出現 truthy 值，CC 不會對 Haiku / Sonnet 送出 `true`。

同時也確認：0.5.0 既有消費的欄位在 2.1.181 全部仍在、形狀一致、無破壞性變更（直接 grep 二進位驗證）。本 spec 只做 `fast_mode` 一個欄位的加法。

## 目標

- P1 解析頂層布林 `fast_mode`，輸出 `FAST_MODE=1/0`
- P2 在 row1 緊接 effort 之後、`output_style` 之前，顯示「圖示 + `fast` 標籤」徽章，且**只在開啟時**出現
- P3 徽章依主題（RPG / Bloom）有各自的圖示與樣式
- P4 擴充寬度量測測試，確保含 fast 徽章的 row1 不誤折行
- P5 補文件：README 新增 fast_mode 指示器說明

## 非目標

- 顯示 `fast_mode` 以外的新欄位（`workspace.repo`、`workspace.project_dir`、`context_window.remaining_percentage`、`remote.session_id`、`pr.kind`、`worktree.{path,original_cwd,original_branch}` 等）——維持單一聚焦的 spec
- 改動既有欄位的順序或樣式（fast 徽章只做加法，插在 effort 之後）
- 新增主題
- 編碼費率/成本提醒語意：fast mode 是使用者刻意的選擇，徽章保持中性，不暗示「正在多花錢」

## 設計

### §1 Layout 與顯示規則

fast 徽章插在 row1，**緊接 effort 指示器之後、`📖/🌻 output_style` 之前**，與 effort 聚成「模型怎麼跑」（用力程度 + 出字速度）的群組。

**RPG 目標外觀**（`▸` 標示新增項，實際輸出不含）：
```
⚔ Opus 📁 statusline 🌳feat⎇main ↑high ▸⏩fast 📖explanatory
```

**Bloom 目標外觀**：
```
🌱 Opus 📁 statusline 🌳feat⎇main 🔴 high ▸🐝 fast 🌻explanatory
```

**顯示條件**：

| 元素 | 條件 |
|---|---|
| 整個 fast 徽章 | `fast_mode` 為 truthy（`true`） |

**空白規則**：徽章前用單空白；`fast_mode` 非 truthy 時連同前導空白一併省略，避免雙空白洞（比照既有欄位）。

**模型守衛**：不需要。effort 之所以加 `[[ "$MODEL" != *"Haiku"* ]]` 守衛，是因為 CC 對所有模型都會送 `effort.level`；但 `fast_mode` 只在 Opus 為 truthy，「只在欄位為真時顯示」已自然涵蓋，毋須額外守衛。

### §2 主題對照

沿用 effort 的「把整串 icon+label 烤進主題變數」寫法（`EFFORT_HIGH="↑high"` vs `"🔴 high"`），fast 徽章同樣把完整字串依主題定義：

| 元素 | RPG | Bloom |
|---|---|---|
| `FAST_TEXT` | `⏩fast`（無空格，比照 `↑high`） | `🐝 fast`（圖示後有空格，比照 `🔴 high`） |
| `FAST_STYLE` | `${BOLD}${BRIGHT_GREEN}` | 空字串（不上色，比照 Bloom effort 的扁平標籤，靠 🐝 emoji 表色） |

**配色理由**：左鄰 effort 用了紅/黃/洋紅/灰，右鄰 `output_style` 是青色；避開這些才不會與鄰居糊在一起。亮綠語意上呼應「go / 快」，且 RPG row1 未在相鄰處使用亮綠（🌳worktree 的綠在最左、非相鄰）。洋紅（thinking / cost / cast 使用中）與青（style 鄰居）刻意排除。

### §3 解析與顯示邏輯

**Python 端新增**（現有 `eval "$(INPUT=... python3 -c '...')"` 區塊內，比照 `exceeds_200k` 寫法）：
```python
fast_mode = 1 if g(d, "fast_mode") else 0
```

**輸出新變數**：`FAST_MODE`（1 表示顯示）：
```python
print(f"FAST_MODE={fast_mode}")
```

**Bash 端主題設定**（`case "$THEME"` 內，比照其他主題變數）：
```bash
# bloom
FAST_TEXT="🐝 fast"
FAST_STYLE=""
# rpg（預設）
FAST_TEXT="⏩fast"
FAST_STYLE="${BOLD}${BRIGHT_GREEN}"
```

**Bash 端徽章組裝**（row1，effort 區塊之後、output_style 之前——即現有 `[ -n "$EFFORT_ICON" ] && parts_row1+=" ${EFFORT_ICON}"` 那一行的緊接下方）：
```bash
[ "${FAST_MODE:-0}" = "1" ] && parts_row1+=" ${FAST_STYLE}${FAST_TEXT}${RESET}"
```

### §4 寬度量測

既有 `dw()`（row 寬度量測的 python）以「`east_asian_width ∈ {W,F}` 或 `ord(ch) ≥ 0x2600`」判定 2 格寬。

- `🐝`（U+1F41D）遠大於 `0x2600`，穩定判 2 格。
- `⏩`（U+23E9）在 `0x2600` 門檻**之下**，需仰賴 `east_asian_width` 回傳 `W`。多數 Python 版本對 U+23E9 回傳 `W`，但有版本差異風險。

**做法（由測試釘死，spec 不預先改 `dw()`）**：加一條寬度等值測試——含 fast 徽章的 row1 經 `dw()` 後，寬度須等同把徽章替換為等寬純文字的版本。若實測 `⏩` 被算成 1 格（折行誤判），再二擇一修正：
1. 在 `dw()` 的 emoji 判定補上涵蓋 U+23E9 的範圍（例如把門檻下修或顯式列入該 misc-technical emoji 區段），或
2. 改用一個 `ord ≥ 0x2600` 或 `east_asian_width=W` 穩定的 RPG glyph。

優先採 (1)，保留 `⏩fast` 的清楚語意。

### §5 邊界條件

| 情況 | 處理 |
|---|---|
| 無 `fast_mode` 欄位 | `FAST_MODE=0` → 徽章整段隱藏（含前導空白） |
| `fast_mode: false` | `FAST_MODE=0` → 隱藏 |
| `fast_mode: true` | 顯示主題徽章 |
| `fast_mode` 為非布林 truthy（schema 演進） | `FAST_MODE=1` → 顯示（安全降級） |
| Haiku / Sonnet | CC 不送 truthy → 自然不顯示，無需守衛 |

## 測試計畫

沿用 `tests/statusline.test.sh` 既有 harness（mock JSON 灌 stdin、grep 斷言），兩主題各驗，比照 0.4.0 / 0.5.0 走正負案例。

**驗證矩陣**：

| 情境 | 預期 |
|---|---|
| 無 `fast_mode`（基線回歸） | 不出現 `fast` / `⏩` / `🐝` |
| `fast_mode=true`（RPG） | 出現 `⏩fast` |
| `fast_mode=true`（Bloom） | 出現 `🐝 fast` |
| `fast_mode=false` | 不顯示徽章 |
| 位置 | fast 徽章出現在 effort（`↑high` / `🔴 high`）之後、`output_style`（`📖` / `🌻`）之前 |
| 寬度量測 | 含 fast 徽章的 row1 `dw()` 回傳值等同等寬純文字版本（URL 不適用；確認 `⏩`/`🐝` 各計 2 格），不誤折行 |

## 版本與文件

- `VERSION` 與腳本內 `STATUSLINE_HP_VERSION` 同步 bump 到 `0.6.0`（兩者必須一起改，否則自更新徽章判斷會錯）
- `CHANGELOG.md` 新增 `[0.6.0]` 段落
- `README.md` 新增 fast_mode 指示器說明（兩主題圖示、只在開啟時顯示、位置緊鄰 effort）

## 開放問題

無。所有設計決策已於 brainstorming 階段確認（位置=緊鄰 effort、外觀=圖示+`fast` 標籤、RPG=`⏩fast` 亮綠粗體、Bloom=`🐝 fast` 扁平、版本=0.6.0）。
