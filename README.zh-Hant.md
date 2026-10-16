# handoff

[![License](https://img.shields.io/github/license/howar31/handoff?style=flat-square)](LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D77655?style=flat-square)](https://claude.com/claude-code)
[![Conventional Commits](https://img.shields.io/badge/conventional%20commits-1.0.0-yellow?style=flat-square)](https://www.conventionalcommits.org)
[![Last Commit](https://img.shields.io/github/last-commit/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/commits/main)
[![Stars](https://img.shields.io/github/stars/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/stargazers)
[![Open Issues](https://img.shields.io/github/issues/howar31/handoff?style=flat-square)](https://github.com/howar31/handoff/issues)
[![Sponsor](https://img.shields.io/badge/%E8%B4%8A%E5%8A%A9-donate.howar31.com-b4532c?style=flat-square&logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTIwLjg0IDQuNjFhNS41IDUuNSAwIDAgMC03Ljc4IDBMMTIgNS42N2wtMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAtNy43OCA3Ljc4bDEuMDYgMS4wNkwxMiAyMS4yM2w3Ljc4LTcuNzggMS4wNi0xLjA2YTUuNSA1LjUgMCAwIDAgMC03Ljc4eiIvPjwvc3ZnPg==)](https://donate.howar31.com/)

[English](README.md) | 正體中文

給 [Claude Code](https://claude.com/claude-code) 用的 skill：把 session **存成交接文件**，之後再**讀回來**，讓新的 agent 從上一個 agent 停下的地方接續工作，即使換了模型、從空白的 context 開始也一樣。交接文件是一份寫給 LLM 讀的 Markdown 檔案。不需要 hook、MCP server 或任何外部服務。

## 功能

### 存檔：`/handoff`

整理 session 的任務目標、目前狀態、決策（含理由與被否決的方案）、走不通的路、硬性限制、未解問題與依序的下一步，執行隱私掃描後寫入 `~/.claude/cache/handoff/<project>-<topic>-<timestamp>.md`。

```text
/handoff                    → 從 session 推斷主題與重點
/handoff <重點>             → 文件內容偏重指定的重點
/handoff topic: <slug>      → 明確指定主題 slug
```

### 讀檔：`/handoff load`

找出目前專案的交接文件（依專案名稱，以及每份文件記錄的目錄），列出後詢問要載入哪一份。即使只有一份也不會自行選定。讀完檔案後，接手的 agent 依照文件本身 §0 內嵌的流程進行。

```text
/handoff load               → 從這個專案的交接文件中挑選
/handoff load <filter>      → 以檔名子字串篩選候選
```

兩種模式都可由模型自動呼叫：像「做交接」/ "create a handoff" 或「接續交接」/ "load handoff" 這類自然語言也會觸發。

### 交接文件的內容

一份 15 個章節、供機器擷取而非給人閱讀的文件：`§0 PROTOCOL`（給接手 agent 的先讀指示）、`§1 METADATA`、`§2 ORIENTATION`、`§3 MISSION`、`§4 STATE`、`§5 PRIORITIES`、`§6 DECISIONS`、`§7 CONSTRAINTS`、`§8 DEAD ENDS`、`§9 OPEN QUESTIONS`、`§10 VERIFICATION`、`§11 LOCATIONS`、`§12 QUICK COMMANDS`、`§13 POINTERS`、`§14 NEXT ACTIONS`。沒有內容的章節保留標題並寫 `(none)`，讓下一個 agent 知道這個主題有考慮過，不是遺漏。

### 來源 session 與接手檢查

交接文件記錄寫出它的 session ID 與對話紀錄路徑。文件有不清楚的地方時，接手的 agent 會去查那份對話紀錄，或用 `claude --resume <id>` 重新開啟那個 session；對話紀錄超過 Claude Code 的保留期限後就無法使用。如果 session 在存檔前被 compact 過，存檔時會先從對話紀錄讀回較早的訊息。

讀檔時，接手的 agent 在第一則訊息之前，會比對目前的 git branch、HEAD、upstream 與工作目錄跟文件記錄的狀態，並回報差異。只存在於該 session 暫存空間的檔案會複製到交接文件旁邊；隨 session 結束的背景工作會列出來，方便重新啟動。

### 隱私

交接文件常常需要敏感的 context（專案名稱、主機名稱）才有用，所以存檔時只警告、不阻擋：列出偵測到的敏感字串，讓你選擇保留、遮蔽或取消，並記錄保留了哪些。讀檔後，你確認接手完成時，接手的 agent 會詢問是否刪除這份檔案；有保留敏感項目時會建議刪除。交接文件存放在你的 `~/.claude/cache/`，不屬於這個 repo。

### 與專案記憶搭配

每項資訊只放一個地方：長期有效的專案知識留在 Claude Code 自動載入的專案記憶，暫時性的接續狀態放進交接文件。專案已有記憶時，存檔以 **lean** 模式進行：把 session 中長期有效的資訊寫進記憶，交接文件只記錄暫時狀態，以及指向記憶條目的連結。沒有記憶時，交接文件把所有內容寫完整（**self-contained** 模式）。

### 選用的使用者資料

如果有你的使用者資料，不論是在 Claude Code 的 context 裡（例如由你的 `CLAUDE.md` 匯入），或是 `~/.claude/USER.md` 檔案，存檔時會使用其中寫明的內容：常用的專案根目錄與容器目錄用於判斷專案名稱，時區用於時間戳，組織名稱用於隱私掃描。沒有使用者資料時，改用 git remote 名稱、系統時區，以及 session 中出現的內容。

## 架構

```
/handoff        -->  整理 session 狀態；區分長期與暫時資訊
                     （lean 模式把長期資訊寫進記憶）；
                     隱私掃描；寫入文件

/handoff load   -->  找出這個專案的交接文件；確認選擇；
                     讀取；依照其 §0 流程進行（狀態比對、
                     來源 session 查詢、刪除詢問）
```

相關檔案：

```
~/.claude/skills/handoff/                       skill（symlink → repo）
~/.claude/cache/handoff/<name>.md               交接文件
~/.claude/cache/handoff/<name>.assets/          複製過來的 session 檔案（需要時才建立）
```

不會安裝 hook，也不會修改 `settings.json`。

## 快速開始

### 1. Clone repo

```bash
git clone https://github.com/howar31/handoff
```

位置不限；安裝程式會自行解析所在路徑，從哪裡執行都可以。

### 2. 安裝

```bash
cd handoff && ./setup.sh
```

安裝程式把 `skills/handoff` symlink 到 `~/.claude/skills/`，因此 skill 以 **`/handoff`**（沒有命名空間前綴）呼叫，repo 維持唯一的來源。可重複執行，結果相同。如果 skill 路徑已經有實體目錄，它會停下並顯示訊息；加上 `--force` 會先把該目錄備份到 `~/.claude/skills/.bak/<timestamp>/` 再取代。

### 3. 驗證

```bash
./setup.sh             # 隨時可重跑；回報所有檢查結果或哪裡有問題
./setup.sh --dry-run   # 只預覽，不實際套用
./setup.sh --force     # 取代 skill 路徑上既有的實體目錄（先備份）
```

更新時在 clone 目錄執行 `git pull` 即可：已安裝的 skill 是 symlink，Claude Code 會直接讀到新檔案。只有 symlink 不見或指向別處時，才需要重跑 `setup.sh`。

### 4. 開始使用

Skill 會動態載入；如果 `/handoff` 沒有立即出現，在進行中的 session 執行 `/reload-plugins`。不需要重新啟動。

## 其他安裝方式

### Plugin manager

透過 Claude Code 的 plugin manager 安裝同一個 skill。由 plugin 管理的 skill 有**命名空間**，因此名稱為 **`/handoff:handoff`**。兩種註冊方式安裝的是同一個 plugin，擇一即可。

**自架 marketplace**（這個 repo 本身就是 marketplace）：

```bash
claude plugin marketplace add howar31/handoff
claude plugin install handoff@handoff
```

**中央 marketplace**（howar31 的所有 plugin；註冊一次，之後就能直接用名稱安裝其中任何一個）：

```bash
claude plugin marketplace add howar31/howar31-marketplace
claude plugin install handoff@howar31
```

### npx skills

用跨 agent 的 [`npx skills`](https://github.com/vercel-labs/skills) CLI 安裝，以 **`/handoff`** 呼叫：

```bash
npx skills add howar31/handoff -g -a claude-code
npx skills update handoff -g          # 之後更新
```

請加上 `-a claude-code`：不加的話，CLI 會列出它偵測到的所有 agent，而這個 skill 無法限制安裝到哪裡。它是為 Claude Code 撰寫的。在其他 agent 上，預期只有 self-contained 模式的存檔與讀檔可用：專案記憶（lean 模式）與來源 session 查詢依賴 Claude Code，而且尚未在其他 agent 上測試。

### 選哪種安裝方式？

| | `setup.sh`（symlink） | npx skills | plugin manager |
|---|---|---|---|
| Slash 名稱 | `/handoff`（最短） | `/handoff` | `/handoff:handoff` |
| 安裝 / 更新 | clone + 執行 `setup.sh`；更新用 `git pull` | `npx skills add` / `update` | `claude plugin install` / `update` |
| 可被搜尋到 | 否 | 否 | 是（透過 marketplace） |

只用一種方式安裝：`setup.sh` 與 `npx skills` 都寫入 `~/.claude/skills/handoff`，plugin manager 則會讓同一個 skill 多一個名稱。

## 使用時會看到什麼

執行 `/handoff` 後，Claude 回報寫入的檔案路徑、assets 目錄（或 `none`）、主題、專案、來源 session ID，以及填寫了幾個章節。不會把文件內容再印一次。

執行 `/handoff load` 並選好檔案後，接手的 agent 讀取該檔案與它在 §13 列出的檔案，第一則訊息是 `Handoff consumed. Current top priority: …`、自交接以來的狀態差異，以及請你確認。在你確認之前不會做任何寫入動作，確認後會詢問是否刪除這份交接文件。

## 備份

`~/.claude/skills/` 裡的 skill 目錄是指回 repo 的 symlink，repo 是唯一的來源，任何包含這份 clone 的備份都涵蓋它。`~/.claude/cache/handoff/` 裡的交接文件本來就是短期使用，接手後經你同意就會刪除，不要把它當成紀錄保存。

## 解除安裝

```bash
# setup.sh 安裝（被取代的實體目錄如果有，在 ~/.claude/skills/.bak/<timestamp>/）
rm ~/.claude/skills/handoff

# npx skills 安裝
npx skills remove handoff -g

# Plugin 安裝
claude plugin uninstall handoff@handoff   # 或 handoff@howar31
```

`settings.json` 沒有需要還原的地方。既有的交接文件會留在 `~/.claude/cache/handoff/`，直到你刪除。

## 參考

- [SPEC.md](SPEC.md)：架構、資料模型、慣例、驗證方式、設計決策
- [CLAUDE.md](CLAUDE.md)：在這個 repo 工作的 agent 索引

## 授權

MIT。見 [LICENSE](LICENSE)。
