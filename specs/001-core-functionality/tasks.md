# Tasks 001: issue2md 核心功能實作任務列表

**版本:** 1.0
**狀態:** 待執行
**日期:** 2026-03-16
**對應 Plan:** `plan.md`
**對應 Spec:** `spec.md`

---

## 說明

- **[P]** 標記表示該任務與前一個任務無直接依賴，可與其他 [P] 任務並行執行。
- **依賴欄位** 列出所有前置任務編號；空白表示無前置依賴。
- 每個任務僅涉及一個主要檔案的建立或修改。
- 所有實作任務都必須在對應的測試任務（Red 階段）完成後才能開始（TDD 鐵律）。

---

## Phase 1: Foundation（資料結構定義）

> 目標：建立整個專案的核心領域模型與型別定義。此階段為純型別宣告，不含函式邏輯，因此無需先寫測試。

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T01 | **[P]** 建立 `internal/github/models.go`：定義所有領域模型，包含 `Author`、`Reaction`、`Label`、`Comment`（含 `IsAnswer bool`）、`Issue`、`PullRequest`、`Discussion`、`FetchOptions` 結構體 | `internal/github/models.go` | — |
| T02 | **[P]** 建立 `internal/parser/parser.go`（型別宣告部分）：定義 `ResourceType` 字串型別、三個常數（`ResourceTypeIssue`、`ResourceTypePullRequest`、`ResourceTypeDiscussion`）、`Resource` 結構體（Owner, Repo, Number, Type）。**不包含** `Parse()` 函式實作 | `internal/parser/parser.go` | — |

---

## Phase 2: GitHub Fetcher（API 互動邏輯，TDD）

> 目標：以 TDD 實作 URL 解析器與 GitHub API 客戶端。所有測試使用 httptest.NewServer，不使用 Mock。

### 2-A：URL 解析器（parser）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T03 | **[Red]** 編寫 `internal/parser/parser_test.go`：表格驅動測試，涵蓋 AC-01 全部 URL 識別案例（有效 Issue/PR/Discussion URL、非 GitHub URL、GitHub 但路徑無效、數字解析）。此時 `Parse()` 不存在，測試必須**無法編譯或失敗** | `internal/parser/parser_test.go` | T02 |
| T04 | **[Green]** 在 `internal/parser/parser.go` 中實作 `Parse(rawURL string) (Resource, error)` 函式，使 T03 所有測試通過 | `internal/parser/parser.go` | T03 |

### 2-B：GitHub Client 基礎與測試資料

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T05 | **[P]** 建立 `internal/github/testdata/` 目錄，新增以下 JSON fixture 檔案（用於 httptest 伺服器回應）：`issue.json`（單一 Issue 回應）、`issue_comments.json`（留言陣列）、`issue_reactions.json`、`pr.json`（PR 回應，含 merged 狀態）、`pr_issue_comments.json`、`pr_review_comments.json`、`discussion_graphql.json`（GraphQL 回應結構）、`error_404.json`、`error_401.json`、`error_rate_limit.json` | `internal/github/testdata/*.json` | T01 |
| T06 | **[Red]** 編寫 `internal/github/client_test.go`（基礎部分）：測試 `NewClient` 建立、HTTP header 設定（Authorization、Accept、X-GitHub-Api-Version）、錯誤回應解析（404→特定錯誤訊息、401→特定錯誤訊息、429/Rate Limit→特定錯誤訊息），全部使用 `httptest.NewServer` | `internal/github/client_test.go` | T05 |
| T07 | **[Green]** 實作 `internal/github/client.go`：`Client` 結構體（含 `httpClient`、`token`、`baseURL` 欄位）、`NewClient(token string) *Client`、`newClientWithBaseURL(token, baseURL string) *Client`（供測試注入）、共用 HTTP 請求輔助函式（`doRequest`）、`Link` header 分頁解析邏輯、HTTP 錯誤狀態碼→錯誤訊息映射 | `internal/github/client.go` | T06 |

### 2-C：GetIssue（TDD）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T08 | **[Red]** 在 `internal/github/client_test.go` 中新增 `GetIssue` 測試區段：正常回應（基本欄位映射）、含分頁留言（多頁 `Link` header）、含 Reactions（`FetchOptions.IncludeReactions=true`）、404 錯誤路徑 | `internal/github/client_test.go` | T07 |
| T09 | **[Green]** 實作 `internal/github/issue.go`：`GetIssue(owner, repo string, number int, opts FetchOptions) (*Issue, error)`，依序調用 Issues 基本資訊、Comments（含分頁）、Reactions（依 opts）端點 | `internal/github/issue.go` | T08 |

### 2-D：GetPullRequest（TDD，可與 2-C 並行）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T10 | **[P][Red]** 在 `internal/github/client_test.go` 中新增 `GetPullRequest` 測試區段：正常回應、一般留言與 review comments 依 `created_at` 合併正序排列、`merged` 狀態映射 | `internal/github/client_test.go` | T07 |
| T11 | **[Green]** 實作 `internal/github/pullrequest.go`：`GetPullRequest(owner, repo string, number int, opts FetchOptions) (*PullRequest, error)`，分別取得一般 comments 與 review comments 後合併並依 `CreatedAt` 正序排序 | `internal/github/pullrequest.go` | T10 |

### 2-E：GetDiscussion（TDD，可與 2-C 並行）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T12 | **[P][Red]** 在 `internal/github/client_test.go` 中新增 `GetDiscussion` 測試區段：GraphQL POST 請求結構正確、回應映射（title、author、category、isAnswer 標記）、cursor 分頁（`hasNextPage`）、`answered` 欄位設定 | `internal/github/client_test.go` | T07 |
| T13 | **[Green]** 實作 `internal/github/discussion.go`：`GetDiscussion(owner, repo string, number int, opts FetchOptions) (*Discussion, error)`，手動組裝 GraphQL query（使用 `net/http` POST），實作 cursor 分頁迴圈，映射 `isAnswer` 並設定 `Discussion.Answered` | `internal/github/discussion.go` | T12 |

---

## Phase 3: Markdown Converter（轉換邏輯，TDD）

> 目標：以 TDD 實作純函式 Markdown 轉換器。僅依賴 Phase 1 的領域模型，可與 Phase 2 並行開始測試編寫。

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T14 | **[P][Red]** 編寫 `internal/converter/converter_test.go`：表格驅動測試，涵蓋 AC-03 至 AC-08 所有場景——YAML Frontmatter 欄位正確性（milestone 省略、labels 空陣列、created_at RFC3339）、留言正序排列、Reactions 渲染（順序、僅顯示 Count > 0、emoji 映射）、`-enable-user-links` 開關、Discussion `✅ Accepted Answer` 標記、PR `state: merged`、無 Reactions 時輸出無任何 Reactions 內容 | `internal/converter/converter_test.go` | T01 |
| T15 | **[Green]** 實作 `internal/converter/converter.go`：`Options` 結構體；`IssueToMarkdown`、`PullRequestToMarkdown`、`DiscussionToMarkdown` 三個公開函式；共用私有輔助函式（`renderFrontmatter`、`renderMetaBlock`、`renderComments`、`renderReactions`、`formatAuthor`） | `internal/converter/converter.go` | T14 |

---

## Phase 4: CLI Assembly（命令列入口整合）

> 目標：整合所有套件，組裝命令列工具的完整入口。Config 測試無代碼依賴，可提前並行撰寫。

### 4-A：Config（TDD）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T16 | **[P][Red]** 編寫 `internal/config/config_test.go`：表格驅動測試，涵蓋——URL 必填驗證（缺少 URL 回傳 error）、`[output_file]` 可選（省略時 OutputFile 為空字串）、`-enable-reactions` / `-enable-user-links` flag 解析、`GITHUB_TOKEN` 環境變數讀取（設定/未設定兩種情境）、多次呼叫 `Load` 不互相干擾（flag.FlagSet 隔離） | `internal/config/config_test.go` | — |
| T17 | **[Green]** 實作 `internal/config/config.go`：`Config` 結構體、`Load(args []string) (Config, error)` 函式（使用 `flag.FlagSet` 非全域 `flag.Parse`，從 `os.Getenv("GITHUB_TOKEN")` 讀取 token） | `internal/config/config.go` | T16 |

### 4-B：CLI 編排層（TDD）

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T18 | **[Red]** 編寫 `internal/cli/cli_test.go`：端對端測試，使用 `bytes.Buffer` 作為 `out`/`errOut`；使用 `httptest.NewServer` 提供 fake GitHub API（需透過 `newClientWithBaseURL` 注入）；測試案例涵蓋——Issue/PR/Discussion 完整輸出驗證（stdout）、輸出至檔案（AC-02）、無效 URL 錯誤至 stderr（exit code 1）、404 錯誤至 stderr | `internal/cli/cli_test.go` | T04, T09, T11, T13, T15, T17 |
| T19 | **[Green]** 實作 `internal/cli/cli.go`：`Run(cfg config.Config, out io.Writer, errOut io.Writer) int` 函式，按順序呼叫 `parser.Parse` → `github.NewClient` → `client.Get*` → `converter.*ToMarkdown`，將 Markdown 寫入 `out` 或指定檔案，將所有錯誤格式化後寫入 `errOut` 並回傳 exit code | `internal/cli/cli.go` | T18 |

### 4-C：程式入口與建置

| ID | 任務描述 | 主要檔案 | 依賴 |
|----|----------|----------|------|
| T20 | 建立 `cmd/issue2md/main.go`：極薄入口，僅含 `config.Load(os.Args[1:])` → `cli.Run(cfg, os.Stdout, os.Stderr)` → `os.Exit(exitCode)` 三行核心邏輯 | `cmd/issue2md/main.go` | T17, T19 |
| T21 | 更新 `Makefile`：確認包含 `build`（`go build -o bin/issue2md ./cmd/issue2md`）、`test`（`go test ./...`）、`lint`（`go vet ./...`）三個目標，全部標記 `.PHONY` | `Makefile` | T20 |

---

## 任務依賴關係圖

```
T01 ─────────────────────────────────────────┬→ T05 → T06 → T07 → T08 → T09
                                              │                   ↘ T10 → T11
                                              │                   ↘ T12 → T13
                                              └→ T14 → T15

T02 → T03 → T04 ─────────────────────────────────────────────────────────────┐
                                                                              ↓
T16 → T17 ────────────────────────────────────────────────────────────────→ T18 → T19 → T20 → T21
                                                                              ↑
T01, T04, T09, T11, T13, T15, T17 ──────────────────────────────────────────┘
```

---

## 並行執行建議

| 批次 | 可並行執行的任務 |
|------|-----------------|
| Batch 1 | T01、T02（Phase 1 全部） |
| Batch 2 | T03（依賴 T02）、T05（依賴 T01）、T14（依賴 T01）、T16（無依賴） |
| Batch 3 | T04（依賴 T03）、T06（依賴 T05） |
| Batch 4 | T07（依賴 T06）、T15（依賴 T14）、T17（依賴 T16） |
| Batch 5 | T08、T10、T12（全部依賴 T07，互相無依賴） |
| Batch 6 | T09（依賴 T08）、T11（依賴 T10）、T13（依賴 T12） |
| Batch 7 | T18（依賴 T04, T09, T11, T13, T15, T17 全部完成） |
| Batch 8 | T19（依賴 T18） |
| Batch 9 | T20（依賴 T17, T19）→ T21（依賴 T20） |

---

## 驗收確認清單

每個任務完成後，執行 `make test` 確認所有現有測試仍通過（Regression Check）。

| 里程碑 | 完成條件 |
|--------|----------|
| Phase 1 完成 | T01、T02 完成，`go build ./...` 無錯誤 |
| Phase 2 完成 | T04、T09、T11、T13 完成，`make test` 全通過 |
| Phase 3 完成 | T15 完成，`make test` 全通過，converter 測試涵蓋 AC-03 至 AC-08 |
| Phase 4 完成 | T21 完成，`make build` 產出 `bin/issue2md`，`make test` 全通過 |
