---
name: project_overview
description: issue2md project architecture — CLI + HTTP web handler converting GitHub issues/PRs/discussions to Markdown
type: project
---

issue2md converts GitHub issues, pull requests, and discussions into Markdown files.

**Why:** The project fetches data from the GitHub REST API and formats it as Markdown, either writing to stdout/file (CLI) or returning it as an HTTP download (web handler).

**How to apply:** Security review must consider both the CLI path (cmd/issue2md/main.go) and the web handler path (web/handlers/handlers.go). Data flows: user-supplied URL -> github.ParseURL -> GitHub API fetch -> converter.*ToMarkdown -> output. The converter layer is the last point before output and is where injection risks materialise.

Key files:
- internal/converter/converter.go — Markdown assembly (reviewed 2026-03-16)
- internal/github/github.go — GitHub API client + URL parser
- web/handlers/handlers.go — HTTP handler; sets Content-Disposition header using owner/repo from parsed URL
- cmd/issue2md/main.go — CLI entry point
