# API Sketch: 核心套件公開介面

**版本:** 1.0
**日期:** 2026-03-16
**對應 Spec:** `spec.md`

本文件描述 `internal/` 下各套件對外暴露的主要資料結構與函式簽章。
這是設計草稿，用於在實作前對齊架構意圖。

---

## `internal/parser`

**職責：** 解析 GitHub URL，識別資源類型並提取結構化資訊。無 I/O、無網路呼叫。

```go
package parser

// ResourceType 表示 GitHub 資源類型
type ResourceType string

const (
    ResourceTypeIssue      ResourceType = "issue"
    ResourceTypePullRequest ResourceType = "pull_request"
    ResourceTypeDiscussion  ResourceType = "discussion"
)

// Resource 代表一個已解析的 GitHub 資源
type Resource struct {
    Owner  string
    Repo   string
    Number int
    Type   ResourceType
}

// Parse 解析 GitHub URL，回傳 Resource。
// 若 URL 格式無效或不被支援，回傳 error。
//
// 範例：
//   Parse("https://github.com/golang/go/issues/1")
//   => Resource{Owner:"golang", Repo:"go", Number:1, Type:ResourceTypeIssue}, nil
func Parse(rawURL string) (Resource, error)
```

---

## `internal/github`

**職責：** 與 GitHub API 互動，取得原始資料並映射為領域模型。
封裝 REST API（Issue/PR）與 GraphQL API（Discussion）的差異。

```go
package github

import "time"

// ---- 領域模型 ----

// Author 代表一個 GitHub 使用者
type Author struct {
    Login   string
    HTMLURL string // https://github.com/{login}
}

// Reaction 代表一種 Reaction 的統計
type Reaction struct {
    Content string // "+1", "-1", "laugh", "confused", "heart", "hooray", "rocket", "eyes"
    Count   int
}

// Comment 代表一則留言（適用於 Issue、PR、Discussion）
type Comment struct {
    ID         int64
    Author     Author
    Body       string
    CreatedAt  time.Time
    Reactions  []Reaction // 僅在呼叫時帶入 WithReactions option 才填充
    IsAnswer   bool       // Discussion 專用：是否為被接受的解答
}

// Label 代表一個標籤
type Label struct {
    Name string
}

// Issue 代表一個 GitHub Issue 的完整資料
type Issue struct {
    Number    int
    Title     string
    Author    Author
    State     string // "open" | "closed"
    Body      string
    Labels    []Label
    Milestone string // 若無則為空字串
    CreatedAt time.Time
    Reactions []Reaction
    Comments  []Comment
}

// PullRequest 代表一個 GitHub PR 的完整資料
// Comments 包含一般留言與 review comments，已按時間正序合併
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
    Comments  []Comment
}

// Discussion 代表一個 GitHub Discussion 的完整資料
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
    Answered  bool // 是否有被接受的解答
}

// ---- 選項 ----

// FetchOptions 控制資料擷取行為
type FetchOptions struct {
    IncludeReactions bool
}

// ---- Client ----

// Client 封裝對 GitHub API 的所有呼叫
type Client struct {
    // 內部欄位：http.Client、token、base URL（便於測試時替換）
}

// NewClient 建立一個新的 Client。
// token 為空字串時，以未認證模式呼叫 API。
func NewClient(token string) *Client

// GetIssue 取得指定 Issue 的完整資料（含所有留言）。
func (c *Client) GetIssue(owner, repo string, number int, opts FetchOptions) (*Issue, error)

// GetPullRequest 取得指定 PR 的完整資料（含所有留言，一般 + review 已合併排序）。
func (c *Client) GetPullRequest(owner, repo string, number int, opts FetchOptions) (*PullRequest, error)

// GetDiscussion 取得指定 Discussion 的完整資料（含所有留言）。
// 內部使用 GitHub GraphQL API v4。
func (c *Client) GetDiscussion(owner, repo string, number int, opts FetchOptions) (*Discussion, error)
```

---

## `internal/converter`

**職責：** 將 `internal/github` 的領域模型轉換為 Markdown 字串。
純函式，無 I/O、無網路呼叫。輸入領域模型，輸出 `string`。

```go
package converter

import (
    "github.com/Jinxuan-Oolong/my-issue2md-project/internal/github"
)

// Options 控制 Markdown 輸出的渲染行為
type Options struct {
    EnableUserLinks bool
    // 注意：Reactions 的開關在 github.FetchOptions 控制擷取，
    // converter 只要「資料存在就渲染」，無需重複設定此 flag。
}

// IssueToMarkdown 將 Issue 轉換為完整的 Markdown 字串（含 Frontmatter）。
func IssueToMarkdown(issue *github.Issue, opts Options) string

// PullRequestToMarkdown 將 PullRequest 轉換為完整的 Markdown 字串（含 Frontmatter）。
func PullRequestToMarkdown(pr *github.PullRequest, opts Options) string

// DiscussionToMarkdown 將 Discussion 轉換為完整的 Markdown 字串（含 Frontmatter）。
func DiscussionToMarkdown(disc *github.Discussion, opts Options) string
```

---

## `internal/config`

**職責：** 讀取並驗證環境變數與 CLI 參數，組裝成統一的設定結構。

```go
package config

// Config 代表工具執行所需的所有設定
type Config struct {
    Token           string // 來自 GITHUB_TOKEN 環境變數，可為空
    EnableReactions bool   // 來自 -enable-reactions flag
    EnableUserLinks bool   // 來自 -enable-user-links flag
    InputURL        string // 來自位置參數 <url>
    OutputFile      string // 來自位置參數 [output_file]，空字串代表 stdout
}

// Load 從環境變數與已解析的 flag 值建立 Config。
// 若必填欄位（如 InputURL）缺失，回傳 error。
func Load(args []string) (Config, error)
```

---

## `internal/cli`

**職責：** 串接所有 `internal/` 套件，執行完整的轉換流程，並處理輸出。
這是應用程式的業務編排層（orchestration layer）。

```go
package cli

import (
    "io"
    "github.com/Jinxuan-Oolong/my-issue2md-project/internal/config"
)

// Run 執行完整的 issue2md 轉換流程。
// out 為 Markdown 輸出的目標 Writer（通常為 os.Stdout 或已開啟的檔案）。
// errOut 為錯誤訊息的目標 Writer（通常為 os.Stderr）。
// 回傳 exit code：0 代表成功，1 代表失敗。
func Run(cfg config.Config, out io.Writer, errOut io.Writer) int
```

---

## 資料流總覽

```
[使用者輸入]
    │
    ▼
config.Load(os.Args)        ← internal/config
    │  cfg.InputURL, flags
    ▼
parser.Parse(cfg.InputURL)  ← internal/parser
    │  Resource{Owner, Repo, Number, Type}
    ▼
github.Client.Get{Issue|PullRequest|Discussion}(...)  ← internal/github
    │  *github.Issue / *github.PullRequest / *github.Discussion
    ▼
converter.{Issue|PullRequest|Discussion}ToMarkdown(...)  ← internal/converter
    │  string（完整 Markdown）
    ▼
io.Writer（stdout 或檔案）  ← internal/cli 負責編排以上所有步驟
```

---

## 設計說明

1. **`converter` 不依賴 `cli`，`github` 不依賴 `converter`。** 依賴方向單向向下，便於獨立測試。
2. **`converter` 的 Reactions 渲染邏輯：** 只要 `Comment.Reactions` 切片非空，就渲染。擷取開關在 `FetchOptions` 控制，converter 無需知道此 flag 的存在。
3. **`github.Client` 的 base URL 應可由外部注入**（隱藏欄位），以便在整合測試中替換為本機測試伺服器，符合憲法第二條（拒絕 Mocks）的精神。
