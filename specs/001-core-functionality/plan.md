# Plan 001: issue2md 核心功能實作方案

**版本:** 1.0
**狀態:** 草稿
**日期:** 2026-03-16
**對應 Spec:** `spec.md`
**對應 API 草稿:** `api-sketch.md`

---

## 1. 技術上下文總結

| 面向 | 決策 | 理由 |
|------|------|------|
| **語言** | Go 1.24 | 已定義於 `go.mod` |
| **CLI 解析** | `flag` (標準庫) | 僅需兩個 bool flag，無需外部框架 |
| **GitHub REST API** | `net/http` (標準庫) | 憲法第一條：標準庫優先；spec 4.1 明確要求 |
| **GitHub GraphQL API** | `net/http` + 手動 JSON 組裝 | Discussion 唯一路徑；同上，無需 graphql client |
| **Markdown 輸出** | `strings.Builder` / `fmt.Fprintf` (標準庫) | 純字串拼接即可，無模板複雜度 |
| **外部依賴** | **零** | 憲法第一條 1.2，spec 4.1 明確「僅使用 Go 標準庫」 |
| **資料儲存** | 無 | 所有資料透過 API 即時取得 |
| **Web 框架** | `net/http` (標準庫)，未來 Web 介面用 | 超出本次 MVP 範圍（US-F01） |

> **注意：** 使用者提案中提及 `google/go-github`，但 `spec.md` § 4.1 與憲法第一條 §1.2 均明確要求僅使用標準庫。本方案以 Spec 與憲法為最高依據，不引入任何外部依賴。

---

## 2. 合憲性審查

依據 `constitution.md` 逐條審查本方案：

### 第一條：簡單性原則

| 條款 | 審查結論 |
|------|----------|
| **1.1 YAGNI** | ✅ 本方案僅實作 spec.md MVP 範圍（US-01 至 US-08）。US-F01（Web）、US-F02（模板）、US-F03（批次）明確列入 Out of Scope。 |
| **1.2 標準庫優先** | ✅ 零外部依賴。HTTP 呼叫使用 `net/http`，JSON 解析使用 `encoding/json`，CLI 使用 `flag`，輸出使用 `strings.Builder`。 |
| **1.3 反過度工程** | ✅ `converter` 使用純函式，不定義 interface。`github.Client` 是具體型別，不包裝在 interface 後面（只有一個實作）。 |

### 第二條：測試先行鐵律

| 條款 | 審查結論 |
|------|----------|
| **2.1 TDD 循環** | ✅ 每個套件的實作步驟均從「寫失敗測試」開始（見 §6 實作順序）。 |
| **2.2 表格驅動** | ✅ `parser`、`converter` 的所有單元測試採用 `[]struct{ name, input, want }` 的表格驅動形式。 |
| **2.3 拒絕 Mocks** | ✅ `internal/github` 的測試使用 `net/http/httptest.NewServer` 架設本機 HTTP 伺服器，替代 Mock。`github.Client` 的 `baseURL` 欄位可由外部注入（測試時指向 httptest server）。 |

### 第三條：明確性原則

| 條款 | 審查結論 |
|------|----------|
| **3.1 錯誤處理** | ✅ 所有 `error` 均被處理。層層傳遞時使用 `fmt.Errorf("GetIssue: %w", err)`。`cli.Run` 最終將錯誤寫至 `errOut`，以非零 exit code 退出。 |
| **3.2 無全域變數** | ✅ Token 透過 `config.Config` 傳入 `github.NewClient(cfg.Token)`，`FetchOptions` 透過參數傳入，無任何全域狀態。 |

**結論：本技術方案完全符合專案憲法所有條款。**

---

## 3. 專案結構

```
my-issue2md-project/
├── cmd/
│   └── issue2md/
│       └── main.go            # 入口點：解析 os.Args，呼叫 cli.Run，os.Exit
├── internal/
│   ├── config/
│   │   ├── config.go          # Load(args []string) (Config, error)
│   │   └── config_test.go
│   ├── parser/
│   │   ├── parser.go          # Parse(rawURL string) (Resource, error)
│   │   └── parser_test.go
│   ├── github/
│   │   ├── client.go          # Client struct, NewClient
│   │   ├── issue.go           # GetIssue
│   │   ├── pullrequest.go     # GetPullRequest
│   │   ├── discussion.go      # GetDiscussion (GraphQL)
│   │   ├── models.go          # Issue, PullRequest, Discussion, Comment, Author, Reaction, Label, FetchOptions
│   │   └── client_test.go     # httptest-based 整合測試
│   ├── converter/
│   │   ├── converter.go       # IssueToMarkdown, PullRequestToMarkdown, DiscussionToMarkdown
│   │   └── converter_test.go
│   └── cli/
│       ├── cli.go             # Run(cfg, out, errOut) int
│       └── cli_test.go
├── specs/
│   └── 001-core-functionality/
│       ├── spec.md
│       ├── api-sketch.md
│       └── plan.md            # 本文件
├── constitution.md
├── CLAUDE.md
├── go.mod
└── Makefile
```

### 套件職責與依賴關係

```
cmd/issue2md
    └── depends on → internal/cli, internal/config

internal/cli                   (編排層，無業務邏輯)
    └── depends on → internal/config, internal/parser, internal/github, internal/converter

internal/converter             (純函式，無 I/O)
    └── depends on → internal/github (領域模型)

internal/github                (API 呼叫，映射為領域模型)
    └── depends on → 標準庫 (net/http, encoding/json, time)

internal/parser                (純函式，無 I/O，無網路)
    └── depends on → 標準庫 (net/url, strconv)

internal/config                (環境變數 + CLI 參數解析)
    └── depends on → 標準庫 (flag, os)
```

**依賴方向嚴格單向**：`cli → {converter, github, parser, config}`，任何 `internal/` 套件之間無循環依賴。

---

## 4. 核心資料結構

完整定義見 `api-sketch.md`。以下為重點補充說明：

### `internal/github/models.go`

```go
package github

import "time"

type ResourceType string // 重用 parser 定義，或在此獨立定義

type Author struct {
    Login   string
    HTMLURL string // "https://github.com/{login}"
}

type Reaction struct {
    Content string // "+1" | "-1" | "laugh" | "confused" | "heart" | "hooray" | "rocket" | "eyes"
    Count   int
}

type Comment struct {
    ID        int64
    Author    Author
    Body      string
    CreatedAt time.Time
    Reactions []Reaction // 空切片代表未啟用 reactions 擷取
    IsAnswer  bool       // Discussion 專用
}

type Label struct {
    Name string
}

type Issue struct {
    Number    int
    Title     string
    Author    Author
    State     string // "open" | "closed"
    Body      string
    Labels    []Label
    Milestone string    // 空字串代表無 Milestone
    CreatedAt time.Time
    Reactions []Reaction
    Comments  []Comment
}

type PullRequest struct {
    Number    int
    Title     string
    Author    Author
    State     string // "open" | "closed" | "merged"
    Body      string
    Labels    []Label
    Milestone string
    CreatedAt time.Time
    Reactions []Reaction
    Comments  []Comment // 一般 comments + review comments，已按 CreatedAt 正序合併
}

type Discussion struct {
    Number    int
    Title     string
    Author    Author
    State     string // "open" | "closed"
    Category  string
    Body      string
    CreatedAt time.Time
    Reactions []Reaction
    Comments  []Comment
    Answered  bool // 是否存在 IsAnswer=true 的 Comment
}

type FetchOptions struct {
    IncludeReactions bool
}
```

### `internal/config/config.go`

```go
package config

type Config struct {
    Token           string // 來自 GITHUB_TOKEN 環境變數
    EnableReactions bool   // 來自 -enable-reactions flag
    EnableUserLinks bool   // 來自 -enable-user-links flag
    InputURL        string // 位置參數 <url>
    OutputFile      string // 位置參數 [output_file]，空字串 = stdout
}
```

### `internal/parser/parser.go`

```go
package parser

type ResourceType string

const (
    ResourceTypeIssue       ResourceType = "issue"
    ResourceTypePullRequest  ResourceType = "pull_request"
    ResourceTypeDiscussion   ResourceType = "discussion"
)

type Resource struct {
    Owner  string
    Repo   string
    Number int
    Type   ResourceType
}
```

---

## 5. 介面設計

本專案遵循憲法第一條 §1.3「簡單函式和資料結構優於複雜介面」，各套件**不額外定義 interface**，僅在下列必要情境使用：

### `internal/github.Client`（具體型別，非介面）

```go
type Client struct {
    httpClient *http.Client
    token      string
    baseURL    string // 預設 "https://api.github.com"，測試時可注入 httptest server URL
}

func NewClient(token string) *Client
func (c *Client) GetIssue(owner, repo string, number int, opts FetchOptions) (*Issue, error)
func (c *Client) GetPullRequest(owner, repo string, number int, opts FetchOptions) (*PullRequest, error)
func (c *Client) GetDiscussion(owner, repo string, number int, opts FetchOptions) (*Discussion, error)
```

> **測試可注入性設計：** 提供 `newClientWithBaseURL(token, baseURL string) *Client` 供測試包使用，避免 Mock，符合憲法 §2.3。

### `internal/converter`（純函式，無介面）

```go
type Options struct {
    EnableUserLinks bool
}

func IssueToMarkdown(issue *github.Issue, opts Options) string
func PullRequestToMarkdown(pr *github.PullRequest, opts Options) string
func DiscussionToMarkdown(disc *github.Discussion, opts Options) string
```

### `internal/cli.Run`（編排函式，依賴 `io.Writer` 介面）

```go
func Run(cfg config.Config, out io.Writer, errOut io.Writer) int
```

使用 `io.Writer` 讓 `cli_test.go` 可以傳入 `bytes.Buffer` 驗證輸出，無需 Mock。

---

## 6. GitHub API 呼叫策略

### 6.1 REST API（Issue / PR）

**Issue 資料擷取：**
1. `GET /repos/{owner}/{repo}/issues/{number}` → 取得基本資訊 + Labels + Milestone
2. `GET /repos/{owner}/{repo}/issues/{number}/comments?per_page=100` → 取得所有留言（分頁）
3. 若 `IncludeReactions=true`：
   - `GET /repos/{owner}/{repo}/issues/{number}/reactions`
   - `GET /repos/{owner}/{repo}/issues/comments/{comment_id}/reactions`（每則留言）

**PR 資料擷取：**
1. `GET /repos/{owner}/{repo}/pulls/{number}` → 取得基本資訊（含 `merged` 狀態判斷）
2. `GET /repos/{owner}/{repo}/issues/{number}/comments` → 一般討論留言
3. `GET /repos/{owner}/{repo}/pulls/{number}/comments` → Review inline comments（取 `created_at` 最早的留言代表該 review thread）
4. 合併兩類留言，按 `CreatedAt` 正序排序

**分頁處理：** 解析 `Link` header，自動抓取所有頁面（`?per_page=100&page=N`）。

**API Request Header 設定：**
```
Authorization: Bearer {token}    （若 token 非空）
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
```

### 6.2 GraphQL API（Discussion）

單次 GraphQL query，透過 `pageInfo` cursor 分頁，取得所有 comments：

```graphql
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    discussion(number: $number) {
      title
      author { login url }
      createdAt
      body
      closed
      category { name }
      answer { id }
      reactions(content: THUMBS_UP) { totalCount }
      # ... 其他 reactions
      comments(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          author { login url }
          body
          createdAt
          isAnswer
          reactions(content: THUMBS_UP) { totalCount }
          # ...
        }
      }
    }
  }
}
```

---

## 7. 輸出格式實作要點

### 7.1 YAML Frontmatter 產生規則

- 使用 `fmt.Fprintf` 手動輸出，不使用 `gopkg.in/yaml.v3`（無外部依賴）
- `milestone` 欄位：若為空字串，**完全省略**此欄位（不輸出 `milestone: ""`）
- `labels` 欄位：無 labels 時輸出 `labels: []`（空陣列，非省略）
- Discussion 才有 `category` 與 `answered` 欄位
- `created_at` 格式：`time.Time.UTC().Format(time.RFC3339)`

### 7.2 Reactions 渲染順序

固定渲染順序（只輸出 Count > 0 的項目）：
```
👍 · 👎 · 😄 · 😕 · ❤️ · 🎉 · 🚀 · 👀
```
對應 API content：`+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`, `rocket`, `eyes`

---

## 8. 錯誤處理規範

| 情境 | 錯誤訊息格式 | Exit Code |
|------|-------------|-----------|
| 無效 URL | `error: invalid GitHub URL: "{url}"` | 1 |
| 404 資源 | `error: resource not found (404): check if the URL is correct and the repository is public` | 1 |
| Rate Limit | `error: GitHub API rate limit exceeded. Set GITHUB_TOKEN to increase your limit.` | 1 |
| 401 未授權 | `error: unauthorized (401): set a valid GITHUB_TOKEN to access this resource` | 1 |
| 其他 API 錯誤 | `error: GitHub API error ({status_code}): {message}` | 1 |
| 檔案寫入失敗 | `error: failed to write output file: {wrapped_error}` | 1 |

所有錯誤輸出至 `errOut`（`os.Stderr`）。正常 Markdown 輸出至 `out`（`os.Stdout` 或指定檔案）。

---

## 9. Makefile 目標

```makefile
.PHONY: build test lint

# 建置 CLI 工具
build:
	go build -o bin/issue2md ./cmd/issue2md

# 執行所有測試（含整合測試）
test:
	go test ./...

# 靜態分析
lint:
	go vet ./...

# 建置 Web 服務（未來 US-F01）
web:
	go build -o bin/issue2md-web ./cmd/web
```

---

## 10. TDD 實作順序

依據憲法第二條，所有實作從「Red」開始。建議以下由內向外的實作順序：

### Phase 1：`internal/parser`（純函式，無依賴）

1. **Red：** 編寫 `parser_test.go`，涵蓋所有 AC-01 測試案例的表格驅動測試
2. **Green：** 實作 `Parse(rawURL string) (Resource, error)`
3. **Refactor：** 確認無多餘邏輯

### Phase 2：`internal/github`（核心 API 層）

1. **Red：** 編寫 `client_test.go`，使用 `httptest.NewServer` 模擬 GitHub API 回應
   - 準備 JSON fixture 資料（放置於 `testdata/` 子目錄）
   - 測試涵蓋：正常回應、404、401、Rate Limit、分頁
2. **Green：** 依序實作 `client.go` → `issue.go` → `pullrequest.go` → `discussion.go`
3. **Refactor：** 抽取共用的 HTTP request 輔助函式、分頁邏輯

### Phase 3：`internal/converter`（純函式，依賴 github 模型）

1. **Red：** 編寫 `converter_test.go`，以表格驅動方式覆蓋所有輸出格式（AC-03 至 AC-08）
2. **Green：** 實作三個轉換函式
3. **Refactor：** 抽取共用的 Frontmatter、Comments 渲染邏輯

### Phase 4：`internal/config`

1. **Red：** 測試 `Load` 在各種 `os.Args` 組合下的行為（含缺少 URL 的錯誤路徑）
2. **Green：** 實作 `Load`，使用 `flag.FlagSet` 解析（非全域 `flag.Parse`，便於測試）
3. **Refactor**

### Phase 5：`internal/cli`

1. **Red：** 使用 `bytes.Buffer` 作為 `out`/`errOut`，測試完整的 `Run` 端對端流程
2. **Green：** 實作 `cli.go` 編排所有套件
3. **Refactor**

### Phase 6：`cmd/issue2md/main.go`

- 僅負責：`config.Load(os.Args[1:])` → `cli.Run(cfg, os.Stdout, os.Stderr)` → `os.Exit(exitCode)`
- 極薄，無需專屬測試（由 cli 層覆蓋）

---

## 11. 關鍵設計決策記錄

| 決策 | 選項 A（採用） | 選項 B（放棄） | 理由 |
|------|--------------|--------------|------|
| HTTP client | `net/http` 標準庫 | `google/go-github` | 憲法第一條，spec 明確要求 |
| YAML 序列化 | 手動 `fmt.Fprintf` | `gopkg.in/yaml.v3` | 欄位數量少且固定，無需外部依賴 |
| GraphQL client | 手動 `net/http` POST | `github.com/hasura/go-graphql-client` | 憲法第一條，僅一個 query |
| Client 設計 | 具體 `struct` + `baseURL` 注入 | interface + Mock | 憲法 §2.3 拒絕 Mocks；httptest 更真實 |
| converter 設計 | 純函式 | method on struct | 無狀態，YAGNI |
| flag 解析 | `flag.FlagSet`（非全域） | `flag.Parse`（全域） | 便於 `config_test.go` 多次呼叫不衝突 |
