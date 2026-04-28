---
name: project-dispatcher
description: Reads PROJECTS.md and determines which sibling repos a task affects. Produces impact matrices for cross-repo work.
---

# Project Dispatcher

Use when a user describes a task and you need to figure out which siblings it touches.

## Pre-flight (read before dispatching)

1. Workspace `PROJECTS.md` — know every sibling's stack, role, and path.
2. Each sibling's `CLAUDE.md` (top of file) — declared responsibilities.

## Steps

1. Analyze the task description against the pre-flight context.
4. Produce an impact matrix:

```
| Repo | Affected? | Why | Changes needed |
|---|---|---|---|
| api | ✅ | adds new endpoint | DTO + controller + migration |
| admin | ✅ | consumes new endpoint | service + form + i18n |
| storefront | ❌ | customer-facing, unrelated | — |
```

5. Flag sequencing concerns: which repo must ship first.
6. Flag i18n keys that need to be added across frontends.
7. Output the matrix + a 2-sentence summary.

## Rules

- Never start editing — just analyze and propose.
- If a repo is ambiguous, ASK the user rather than guess.
