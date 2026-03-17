---
description: 執行 make build 建置專案，若失敗則自動分析錯誤原因
allowed-tools:
  - Bash(make:build)
---

執行 `make build` 來建置 issue2md 專案的所有二進位檔（`issue2md` CLI 與 `issue2mdweb` Web 服務）。

若建置成功，回報建置完成。

若建置失敗，請分析編譯器輸出的錯誤訊息，找出根本原因（例如：語法錯誤、型別不符、缺少依賴、模組路徑錯誤等），並提供具體的修正建議。
