---
name: Go Code Reviewer
description: A specialized skill for reviewing Go (Golang) code based on the project's constitution. Use this skill whenever a user asks to review Go code, check for best practices, or analyze code quality in this repository.
allowed-tools: Read, Grep, Glob, Bash(go vet:*)
---

# Go Code Reviewer Skill

## 核心能力
本技能專門用於根據本專案的開發「憲法」（`constitution.md`），對 Go 語言程式碼進行深入且專業的審查。

## 觸發條件
當使用者的請求包含以下關鍵字時，你應優先考慮啟用本技能：
- 「審查 / review Go 程式碼」
- 「檢查程式碼品質」
- 「看看這段 Go 程式碼寫得怎麼樣」
- 「是否符合規範」

## 執行步驟
當你決定使用本技能時，必須嚴格遵循以下步驟：

1. **載入核心準則：**  
   首先，你必須讀取專案根目錄下的 `constitution.md` 檔案。這是你所有審查工作的最高準則。如果找不到該檔案，應向使用者回報。

2. **定位審查目標：**  
   確定使用者要求審查的程式碼範圍。這可能是一個檔案（透過 `@` 指令提供），或是一個目錄。

3. **逐條審查：**  
   根據 `constitution.md` 中定義的 **每一條原則**（例如簡單性、測試先行、明確性、單一職責），對目標程式碼逐一比對並分析。

4. **生成報告：**  
   按照以下 Markdown 格式生成一份結構化的審查報告。報告必須直接回應「憲法」中的條款。

## 輸出格式（必須遵循）

### 總體評價
用一句話總結程式碼的整體品質與合憲性。

### 優點（值得稱讚的地方）
- 列出 1–2 個最符合專案開發哲學的亮點。

### 待改進項（按優先級排序）

#### [高優先級] 違憲問題（Violations of Constitution）
- **原則：** [引用違反的憲法條款，例如：「第三條：明確性原則」]
- **位置：** `[檔案名稱]:[行號]`
- **問題描述：** [清楚描述程式碼如何違反該原則]
- **修改建議：** [提供具體且可執行的修改方案]

#### [中優先級] 建議性改進
- **位置：** `[檔案名稱]:[行號]`
- **問題描述：** [描述可以進一步優化的地方]
- **修改建議：** [提供改進建議]