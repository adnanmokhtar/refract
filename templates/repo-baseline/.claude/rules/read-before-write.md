---
name: read-before-write
description: Foundational rule — read existing code before writing. One of the four load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# #1 Rule: Read Before You Write

> **Hard rule (TL;DR):** Read the file you're about to edit AND ≥1 sibling in the same layer. Read `codebase-profile.md` if it exists. Cite real classes/paths — never invent. PR review should fail any edit without prior Read of the touched file (convention; no CI gate ships).

## Must

- Read the existing code around any change **before** writing — open a similar file in the target module or sibling module first.
- Read `.claude/codebase-profile.md` first when it exists — treat it as the curated fact sheet (architecture, base classes, naming, errors, tests, auth, i18n, glossary).
- Match **classes, folders, suffixes, error handling, logging, validation, imports, and tests** to existing sibling code.
- Cite **concrete classes and paths** from the profile or files you read — not hypothetical names.
- Run `/setup-project --enhance` when the profile is missing or stale so detection can refresh it.

## Must not

- Invent file paths or class names you have not read in this session or seen in extraction/profile.
- Silently "fix" a pattern that looks wrong — flag it and ask; patterns often exist for undocumented reasons.

## Should

- Prefer the smallest read set that still proves shape: target file + 1–2 siblings in the same layer.

## Review checklist

- [ ] Read `codebase-profile.md` or confirmed why it's absent.
- [ ] Read target file + at least one sibling before editing.
- [ ] Named real paths when justifying non-obvious choices.

## Enforcement

- There is currently **no read-before-edit hook** — this rule is enforced by convention + review, not automatically. (The shipped `pre-edit-guard` hook only blocks writes to sensitive paths like `.env` / lock files / build output; it does not check whether the target file was read first.)
- PR review: edits without prior Read of the touched file should fail review.

**Consistency with existing code is more important than personal preference.**

## Cross-references

- `read-codebase-deeply.md` — tiered reading playbook for non-trivial work.
- `think-simplify-surgical.md` — the task-discipline layer (assumptions, simplicity, surgical scope, verifiable goals) that *uses* the reads this rule mandates.
