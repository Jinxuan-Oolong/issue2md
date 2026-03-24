---
description: 根據目前程式碼變更，自動生成一條符合 Conventional Commits 規範的 Commit Message 並執行 commit。
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*)
---

你是一位資深 Git 與軟體工程專家。請根據以下專案資訊與程式碼變更，生成一條**高品質且簡潔**的 Conventional Commits 格式 commit message，並直接執行 commit。

請遵守以下規則：

1. 使用 **Conventional Commits** 規範
2. 格式：
```
   type(scope): short summary

   optional longer description
```

3. `type` 只能是以下之一：
   - feat
   - fix
   - refactor
   - perf
   - docs
   - style
   - test
   - build
   - ci
   - chore

4. summary：
   - 使用**現在式**
   - 不超過 **72 字**
   - 不加句號
   - 簡潔描述變更目的

5. 如果變更較大，可加入一段**簡短 body**

---

## Current Branch

!`git branch --show-current`

---

## Git Status

!`git status --short`

---

## Staged Changes

!`git diff --staged --name-status`

---

## Diff (staged)

!`git diff --staged`

---

## Recent Commit Style (for reference)

!`git log -5 --pretty=format:"%s"`

---

## 執行步驟

請依照以下步驟執行：

1. 檢查是否有 staged changes（`git diff --staged` 是否為空）

2. **若沒有 staged changes**：
   - 執行 `git add -A`
   - 再執行 `git diff --staged` 取得完整 diff 作為生成依據

3. **生成 commit message**：根據 diff 內容決定最佳 type、scope 與 summary

4. **執行 commit**：
```
   git commit -m "<subject>" -m "<body（如有）>"
```

5. 輸出最終執行的 commit message，不需要其他說明

6. 處理額外需求

   如果使用者有額外要求（例如 push、PR）：

   常見情境：
   - push → git push
   - push + PR → push 後建立 PR
   - tag → 建立 tag

   ⚠️ 只執行使用者明確要求的操作