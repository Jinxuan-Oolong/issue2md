---
description: 根據目前程式碼變更，自動生成一條符合 Conventional Commits 規範的 Commit Message。
allowed-tools: Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git status:*), Bash(git add:*)
---

你是一位資深 Git 與軟體工程專家。請根據以下專案資訊與程式碼變更，生成一條**高品質且簡潔**的 Conventional Commits 格式 `git commit` 訊息。

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
- 使用 **現在式**
- 不超過 **72 字**
- 不加句號
- 簡潔描述變更目的

5. 如果變更較大，可加入一段 **簡短 body**

6. **不要輸出任何解釋，只輸出 commit message**

---

## Current Branch

!`git branch --show-current`

---

## Git Status

!`git status --short`

---

## Changed Files (staged)

!`git diff --staged --name-status`

---

## Diff (staged changes)

!`git diff --staged`

---

## Diff (unstaged fallback)

如果 staged diff 為空，請改參考以下 diff：

!`git diff`

---

## Recent Commit Style (for reference)

!`git log -5 --pretty=format:"%s"`

---

請根據以上資訊生成 **最佳 commit message**。

只輸出 commit message 本身，不要包含任何說明。
