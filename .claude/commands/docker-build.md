---
description: 執行 make docker-build 建構容器映像，可指定 Tag（預設 latest）
allowed-tools:
  - Bash(docker:*)
  - Bash(make:docker-build)
---

使用者提供的映像 Tag 參數為：`$1`

執行步驟：

1. 判斷 Tag：若 `$1` 為空，則使用 `latest`；否則使用 `$1` 的值。
2. 執行 `make docker-build`，但在呼叫前先將 Makefile 中的 `IMAGE_TAG` 覆蓋為上一步決定的 Tag：
   ```
   make docker-build IMAGE_TAG=issue2md:<tag>
   ```
3. 若建構成功，回報最終的完整映像名稱（含 Tag）。
4. 若建構失敗，分析 Docker build 輸出中的錯誤訊息（例如：Dockerfile 語法錯誤、COPY 來源不存在、基礎映像拉取失敗等），並提供具體的修正建議。
