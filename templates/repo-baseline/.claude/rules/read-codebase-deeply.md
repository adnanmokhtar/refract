---
name: read-codebase-deeply
description: Foundational rule — tiered reading playbook for non-trivial work. One of the four load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# Rule: Read the codebase deeply before writing

> **Hard rule (TL;DR):** Behave like a senior engineer 6 months in. Tier-1 (digest) loads every session; Tier-2 (task-specific) loads before substantive work; Tier-3 (deep) loads only when relevant. `_extracted-codebase.md` and `_extracted-idioms.md` are ground truth — they win against memory and older docs.

**This rule auto-applies to every agent + every command + every generated artifact in this project.**

## Must

- Behave like a senior engineer on the project for 6 months: read what exists, mirror shape, cite real files (`path:line`), invent only when nothing analogous exists.
- **Tier 1 — every session:** read `ai/_session-digest.md`.
- **Tier 2 — by task:**
  - Code edit / new code → `ai/_convention-cheatsheet.md`, the file being modified, 1–2 siblings in the same layer.
  - Architectural decision → `ai/_decision-index.md`, then specific ADRs if needed.
  - New feature → `ai/business-domain.md`, `ai/business-flows.md`, `ai/users-and-personas.md`.
  - Bug fix → `ai/runtime/context.md`, relevant `ai/patterns/<name>.md`.
  - Pattern / refactor work → `.claude/_extracted-idioms.md` when present.
  - Audit / review → full `ai/conventions.md` + `.claude/rules/`.
- **Tier 3 — on demand:** `.claude/_extracted-codebase.md`, specific patterns/ADRs/runbooks/audits/dynamic files only when directly relevant.
- Treat `.claude/_extracted-codebase.md` and `_extracted-idioms.md` as **ground truth** when they conflict with memory or older docs.

## Must not

- Skip reading the file you are about to edit.
- Proceed when your task contradicts what you read — STOP and ask.
- Propose generic best-practice alone when this codebase's extraction shows a concrete idiom — the answer must cite that idiom.

## Should

- Append drift findings to `ai/dynamic/drift-log.md` when code violates documented rules instead of silently fixing (unless explicitly in scope).

## Review checklist

- [ ] `_session-digest.md` loaded for session bootstrap.
- [ ] Task-appropriate Tier 2 list loaded before substantive work.
- [ ] Contradictions escalated, not overridden.

## Enforcement

- Injected agent pre-flight blocks reference this rule.
- `read-before-write.md` gives the strict edit checklist; PR review traces Read-before-Edit.

## Cross-references

- `read-before-write.md` — the strict edit-time checklist that operationalises this rule.
- `think-simplify-surgical.md` — once you've read deeply, this rule covers how to *act* on what you read: explicit assumptions, minimum-viable change, surgical scope, verifiable success criteria.
