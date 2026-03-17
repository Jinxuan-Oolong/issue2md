# Spec 001: issue2md 核心功能

**版本:** 1.0
**狀態:** 已定稿
**日期:** 2026-03-16

---

## 1. 概覽

`issue2md` 是一個命令列工具。使用者輸入一個 GitHub Issue、Pull Request 或 Discussion 的 URL，工具自動將其討論內容轉換為標準的 GitHub Flavored Markdown 檔案，並附帶 YAML Frontmatter。

---

## 2. 使用者故事

### 2.1 MVP（本次實作）

| ID | 身份 | 我想要 | 以便於 |
|----|------|--------|--------|
| US-01 | 開發者 | 輸入一個 GitHub Issue URL，取得完整的 Markdown 檔案 | 離線存檔或匯入筆記工具 |
| US-02 | 開發者 | 輸入一個 GitHub PR URL，取得 PR 描述與所有討論留言的 Markdown | 歸檔程式碼審查中的決策過程 |
| US-03 | 開發者 | 輸入一個 GitHub Discussion URL，取得完整 Markdown | 保存社群討論紀錄 |
| US-04 | 開發者 | 將輸出導向 stdout | 搭配 shell pipeline 使用（例如 `issue2md <url> | pbcopy`） |
| US-05 | 開發者 | 指定輸出檔案路徑 | 直接存成本機檔案 |
| US-06 | 開發者 | 透過 `GITHUB_TOKEN` 環境變數提供認證 | 存取需要認證的公開資源，避免 API rate limit |
| US-07 | 開發者 | 選擇性地顯示 Reactions 統計 | 了解社群對各留言的態度 |
| US-08 | 開發者 | 選擇性地將使用者名稱渲染為 GitHub 首頁連結 | 在 Markdown 中保留可點擊的人員索引 |

### 2.2 未來使用者故事（不在本次範圍）

| ID | 身份 | 我想要 | 備註 |
|----|------|--------|------|
| US-F01 | 一般使用者 | 透過 Web 介面貼入 URL 並下載 Markdown | 降低 CLI 使用門檻 |
| US-F02 | 開發者 | 支援自訂 Markdown 模板 | 客製化輸出格式 |
| US-F03 | 開發者 | 批次轉換多個 URL | 提升效率 |

---

## 3. 功能性需求

### 3.1 命令列介面

**語法：**

```
issue2md [flags] <url> [output_file]
```

**參數：**

| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `<url>` | 位置參數 | 是 | GitHub Issue / PR / Discussion 的完整 URL |
| `[output_file]` | 位置參數 | 否 | 輸出檔案路徑。若省略，輸出至 stdout |

**Flags：**

| Flag | 類型 | 預設值 | 說明 |
|------|------|--------|------|
| `-enable-reactions` | bool | false | 在主樓與每則留言下方顯示 Reactions 統計 |
| `-enable-user-links` | bool | false | 將所有使用者名稱渲染為指向其 GitHub 首頁的 Markdown 連結 |

**注意：** 不提供 `--token` flag。認證金鑰**僅**透過 `GITHUB_TOKEN` 環境變數讀取。

### 3.2 URL 自動識別

工具必須解析 URL 路徑，自動判斷資源類型。無需使用者手動指定。

| URL 模式 | 識別類型 |
|----------|----------|
| `https://github.com/{owner}/{repo}/issues/{number}` | Issue |
| `https://github.com/{owner}/{repo}/pull/{number}` | Pull Request |
| `https://github.com/{owner}/{repo}/discussions/{number}` | Discussion |

其他任何 URL 格式均視為無效輸入。

### 3.3 資料擷取範圍

#### Issue

| 欄位 | 必含 |
|------|------|
| 標題 (title) | 是 |
| 作者 (author) | 是 |
| 建立時間 (created_at) | 是 |
| 狀態 (state: open/closed) | 是 |
| Labels | 是 |
| Milestone | 是（若有） |
| 主樓內容 (body) | 是 |
| Reactions | 選用（`-enable-reactions`） |
| 所有留言 (comments)，按時間正序 | 是 |

#### Pull Request

| 欄位 | 必含 |
|------|------|
| 標題 (title) | 是 |
| 作者 (author) | 是 |
| 建立時間 (created_at) | 是 |
| 狀態 (state: open/closed/merged) | 是 |
| Labels | 是 |
| Milestone | 是（若有） |
| 主樓描述 (body) | 是 |
| Reactions | 選用（`-enable-reactions`） |
| 所有留言（一般 comments + review comments），按時間線正序平鋪 | 是 |
| **不含：** Diff、Commits 歷史、Files changed | — |

#### Discussion

| 欄位 | 必含 |
|------|------|
| 標題 (title) | 是 |
| 作者 (author) | 是 |
| 建立時間 (created_at) | 是 |
| 分類 (category) | 是 |
| 主樓內容 (body) | 是 |
| Reactions | 選用（`-enable-reactions`） |
| 所有留言，按時間正序 | 是 |
| Answered 標記（若某則留言被標記為正解） | 是 |

### 3.4 認證

- 工具讀取環境變數 `GITHUB_TOKEN` 作為 Personal Access Token。
- 若該環境變數未設定，工具以**未認證**模式呼叫 GitHub API（適用於公開倉庫，但有較低的 rate limit）。
- 僅支援公開倉庫。存取私有倉庫需提供有效 token，否則視為授權失敗。

---

## 4. 非功能性需求

### 4.1 架構

- **依賴方向：** 核心邏輯（資料擷取、Markdown 渲染）必須與 I/O 層（CLI、檔案輸出）解耦，以利測試。
- **外部依賴：** 遵循憲法第一條，僅使用 Go 標準庫。GitHub API 呼叫使用 `net/http`。
- **GitHub API：** 使用 GitHub REST API v3（`https://api.github.com`）。Discussion 使用 GitHub GraphQL API v4（`https://api.github.com/graphql`），因 REST API 不支援 Discussion。

### 4.2 錯誤處理

- 所有錯誤訊息輸出至 **stderr**。
- 程式正常輸出至 **stdout**（或指定檔案）。
- 遇到錯誤時，以非零 exit code 退出（`os.Exit(1)`）。
- 不實作重試機制。API rate limit 錯誤直接透傳 GitHub 的錯誤訊息給使用者。
- 錯誤訊息格式範例：
  - `error: invalid GitHub URL: "https://github.com/foo"`
  - `error: resource not found (404): check if the URL is correct and the repository is public`
  - `error: GitHub API rate limit exceeded. Set GITHUB_TOKEN to increase your limit.`

### 4.3 效能

- 無特別效能要求。對於一般 Issue/PR（留言數 < 500），工具應在合理時間內完成（< 30 秒）。

---

## 5. 輸出格式規格

### 5.1 整體結構

```
[YAML Frontmatter]
[H1 標題]
[元資料區塊]
[主樓內容]
[Reactions（選用）]
---
[留言 1]
[Reactions（選用）]
---
[留言 2]
...
```

### 5.2 YAML Frontmatter

```yaml
---
title: "Issue 或 PR 的標題"
url: "https://github.com/owner/repo/issues/123"
type: issue  # issue | pull_request | discussion
author: "github-username"
created_at: "2024-01-15T10:30:00Z"
state: open  # open | closed | merged（PR 專用）
labels:
  - "bug"
  - "enhancement"
milestone: "v2.0"  # 若無則省略此欄位
---
```

Discussion 額外包含：

```yaml
category: "Q&A"
answered: true  # 若有被標記的正解
```

### 5.3 主體內容

```markdown
# Issue 標題

**Author:** github-username（開啟 -enable-user-links 時：**Author:** [github-username](https://github.com/github-username)）
**Created:** 2024-01-15T10:30:00Z
**State:** Open
**Labels:** `bug`, `enhancement`
**Milestone:** v2.0

---

主樓的內容原文（保留原始 Markdown，包含圖片連結）

<!-- 若開啟 -enable-reactions -->
**Reactions:** 👍 12 · 🎉 3 · ❤️ 2

---

## Comments

### Comment #1

**Author:** another-user
**Created:** 2024-01-16T08:00:00Z

留言的內容原文

<!-- 若開啟 -enable-reactions -->
**Reactions:** 👍 5

---

### Comment #2

...
```

### 5.4 Discussion Answer 標記

若某則留言被標記為「Answered」，在該留言的標題後加入標記：

```markdown
### Comment #3 ✅ Accepted Answer

**Author:** expert-user
**Created:** 2024-01-17T09:00:00Z

這是被接受的解答內容。
```

### 5.5 Reactions 格式

僅顯示數量大於 0 的 Reaction，以 ` · ` 分隔：

```
**Reactions:** 👍 12 · 👎 1 · 😄 3 · 🎉 5 · 😕 2 · ❤️ 8 · 🚀 4 · 👀 6
```

Emoji 對應 GitHub API 的 content 欄位：

| API content | Emoji |
|-------------|-------|
| `+1` | 👍 |
| `-1` | 👎 |
| `laugh` | 😄 |
| `confused` | 😕 |
| `heart` | ❤️ |
| `hooray` | 🎉 |
| `rocket` | 🚀 |
| `eyes` | 👀 |

---

## 6. 驗收標準

### AC-01：URL 識別

| 測試案例 | 輸入 | 預期結果 |
|----------|------|----------|
| 有效 Issue URL | `https://github.com/golang/go/issues/1` | 識別為 Issue，成功擷取 |
| 有效 PR URL | `https://github.com/golang/go/pull/1` | 識別為 Pull Request，成功擷取 |
| 有效 Discussion URL | `https://github.com/golang/go/discussions/1` | 識別為 Discussion，成功擷取 |
| 無效 URL（非 GitHub） | `https://example.com/foo` | stderr 報錯，exit 1 |
| 無效 URL（GitHub 但非 Issue/PR/Discussion） | `https://github.com/golang/go` | stderr 報錯，exit 1 |
| 404 資源 | `https://github.com/golang/go/issues/9999999` | stderr 報 404 錯誤，exit 1 |

### AC-02：輸出目標

| 測試案例 | 指令 | 預期結果 |
|----------|------|----------|
| 輸出至 stdout | `issue2md <url>` | Markdown 內容印至 stdout |
| 輸出至指定檔案 | `issue2md <url> output.md` | 建立 `output.md` 並寫入內容；stdout 無輸出 |

### AC-03：Frontmatter 正確性

- 所有必填欄位均存在
- `created_at` 為 RFC 3339 / ISO 8601 格式（UTC）
- `type` 值正確對應（`issue` / `pull_request` / `discussion`）
- `state` 值正確（Issue/Discussion: `open`/`closed`；PR: `open`/`closed`/`merged`）
- 無 Labels 時，`labels` 為空陣列 `[]`
- 無 Milestone 時，`milestone` 欄位省略

### AC-04：留言排序

- 所有留言按 `created_at` 時間**正序**排列

### AC-05：Discussion Answer 標記

- 被標記為 Answered 的留言，標題包含 `✅ Accepted Answer`
- Frontmatter 中 `answered: true`

### AC-06：Flags 行為

| Flag | 行為 |
|------|------|
| 不加 `-enable-reactions` | 輸出中無任何 Reactions 相關內容 |
| 加 `-enable-reactions` | 主樓與每則留言下方均顯示 Reactions（僅顯示數量 > 0 的） |
| 不加 `-enable-user-links` | 使用者名稱以純文字顯示 |
| 加 `-enable-user-links` | 使用者名稱以 `[username](https://github.com/username)` 格式顯示 |

### AC-07：認證行為

| 情境 | 預期行為 |
|------|----------|
| 未設定 `GITHUB_TOKEN`，存取公開倉庫 | 成功（使用未認證請求） |
| 設定有效 `GITHUB_TOKEN`，存取公開倉庫 | 成功（較高 rate limit） |
| 未設定 `GITHUB_TOKEN`，存取私有倉庫 | stderr 報 401/404 錯誤，exit 1 |
| API Rate Limit 超限 | stderr 直接輸出 GitHub 錯誤訊息，exit 1 |

### AC-08：PR 特定行為

- 輸出中**不含** diff、commits、files changed 等資訊
- Review comments 與一般 comments 按時間線平鋪，不分組

---

## 7. 超出範圍（Out of Scope）

以下內容**明確排除**在本次實作之外：

- Web 介面（見 US-F01）
- 私有倉庫完整支援（進階 token scope 管理）
- 下載圖片或附件至本機
- 批次轉換
- 自訂 Markdown 模板
- PR 的 Diff / Commits / Files changed
- 重試機制
- `--token` CLI flag
