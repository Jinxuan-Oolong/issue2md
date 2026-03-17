---
description: 掃描整個專案，並更新或重新產生 README.md 文件。
model: opus
---

你是一位優秀的技術文件工程師。請全面掃描目前目錄（`@.`）下的所有檔案，特別是 `go.mod`、`Makefile` 以及 `cmd/` 目錄下的 `main.go`，以理解專案的最新狀態。

然後，請為 `issue2md` 專案，重新產生一份完整、清晰、且與目前程式碼完全同步的 `README.md` 檔案內容。

這份 README 必須包含以下部分：
1. **專案簡介（Overview）**
2. **核心特性（Features）**
3. **安裝指南（Installation）**
4. **使用方法（Usage）：** 必須包含所有命令列參數的詳細說明與範例。
5. **建置方法（Building from Source）：** 必須引用 `Makefile` 中的命令。