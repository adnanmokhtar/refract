---
name: read-codebase-deeply
description: Foundational rule — tiered reading playbook for non-trivial work. One of the four load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# Rule: Read the codebase deeply before writing

> **Hard rule (TL;DR):** Behave like a senior engineer 6 months in. Tier-1 (digest) loads every session; Tier-2 (task-specific) loads before substantive work; Tier-3 (deep) loads only when relevant. `_extracted-codebase.md` and `_extracted-idioms.md` are ground truth — they win against memory and older docs.

**This rule is imported via the project `CLAUDE.md` (`@.claude/rules/read-codebase-deeply.md`), so it loads every session and applies to every agent + command + generated artifact in this project.**

## Must

- Behave like a senior engineer on the project for 6 months: read what exists, mirror shape, cite real files (`path:line`), invent only when nothing analogous exists.
- **Tier 1 — every session:** read `ai/_session-digest.md`.
- **Tier 2 — load before substantive work when the task type matches the trigger:**

  | ai file | Load when (trigger) |
  |---|---|
  | `ai/_convention-cheatsheet.md` | Code edit / new code (read with the file being modified + 1–2 siblings in the same layer). |
  | `ai/conventions.md` | Audit / review, or when the cheatsheet is insufficient (read with `.claude/rules/`). |
  | `ai/_decision-index.md` | Architectural decision (then specific ADRs under `ai/decisions/` if needed). |
  | `ai/architecture.md` | System-shape / boundary work, cross-module change. |
  | `ai/modules.md` | Locating where a feature lives, or adding a new module. |
  | `ai/business-domain.md` | New feature, domain-glossary lookup. |
  | `ai/business-flows.md` | New feature touching an operational flow. |
  | `ai/users-and-personas.md` | New feature, UX / role-scoped behaviour. |
  | `ai/business-model.md` | Pricing / entitlement / billing / plan-gating work. |
  | `ai/project-goals.md` | Scoping / prioritisation, "should we build this" calls. |
  | `ai/roadmap.md` | Planning, sequencing, "what's next" work. |
  | `ai/competitive-context.md` | Product-positioning / feature-parity reference (reference-only — grep-match). |
  | `ai/stack.md` | Version / dependency / tooling questions. |
  | `ai/status.md` | Session bootstrap cross-reference; current state + recent changes. |
  | `ai/core/invariants.md` | Bug fix or feature touching a guarded invariant. |
  | `ai/core/glossary.md` | Term disambiguation (reference-only — grep-match). |
  | `ai/core/stakeholders.md` | Ownership / sign-off questions (reference-only — grep-match). |
  | `ai/runtime/context.md` | Bug fix — runtime / operational context. |
  | `ai/runtime/environment-quirks.md` | Bug fix — env-specific behaviour, "works locally not in prod". |
  | `ai/runtime/dependencies-with-traps.md` | Bug fix touching a known-trappy dependency. |
  | `ai/runtime/domain-anti-patterns.md` | Bug fix / review — avoid a known domain anti-pattern. |
  | `ai/patterns/<name>.md` | Pattern / refactor work matching the named pattern; `.claude/_extracted-idioms.md` when present. |

- **Tier 3 — on demand, only when directly relevant:** `.claude/_extracted-codebase.md`; specific `ai/decisions/` ADRs, `ai/runbooks/`, `ai/audits/`, `ai/failures/`, `ai/references/`, and `ai/dynamic/` working files (drift-log, learned-patterns, decisions-pending). Everything not enumerated above is reference-only — grep-match into it when a keyword hits, don't read whole.
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

- Imported via the project `CLAUDE.md` (`@.claude/rules/read-codebase-deeply.md`), so it loads every session and applies to every agent + command. (`.claude/rules/` files are not auto-loaded on their own — the `CLAUDE.md` import is what wires them in.)
- `read-before-write.md` gives the strict edit checklist; PR review traces Read-before-Edit (convention — there is no read-before-edit hook).

## Cross-references

- `read-before-write.md` — the strict edit-time checklist that operationalises this rule.
- `think-simplify-surgical.md` — once you've read deeply, this rule covers how to *act* on what you read: explicit assumptions, minimum-viable change, surgical scope, verifiable success criteria.
