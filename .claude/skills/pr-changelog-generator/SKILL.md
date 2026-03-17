---
name: pr-changelog-generator
description: 自動分析 Git 提交歷史，生成規範的 PR Changelog。當使用者準備提 PR、請求總結程式碼變更，或是要求「寫一下更新日誌」時，請務必優先觸發本技能。
allowed-tools: Bash Read
metadata:
  author: tonybai
---

# PR Changelog Generator 技能指南

這個技能旨在幫助我們的開發者減輕提交 PR 時的負擔。我們團隊非常重視 Review 的效率，一份結構清晰、重點突出的 Changelog 能大幅節省 Reviewer 的時間，減少溝通摩擦。

## 執行步驟

當決定使用本技能時，請遵循以下流程：

### 1. 收集資料（確定性執行）

請不要自行猜測 Git 指令。請直接呼叫我們準備好的安全腳本來取得原始提交資料：

執行 `Bash(sh scripts/extract_commits.sh)`

### 2. 意圖理解與提煉（你的強項）

仔細閱讀腳本回傳的 commits。你需要發揮你的理解能力：

- 剔除那些無意義的提交（例如 "fix typo"、"update"）。
- 將連續相關的提交合併為一個功能點。
- **重點：** 請站在 Reviewer 的角度，思考他們最關心哪些變更？把高風險、大範圍的改動排在最前面。

### 3. 結構化輸出

請使用以下模板輸出。**為什麼要中英雙語？因為我們是一個跨國協作團隊，這能確保不同母語的同事都能快速理解。**

    ## 🚀 Changes（變更內容）
    * **[Feature/Fix]**: (English description) / (中文描述)
    * ...