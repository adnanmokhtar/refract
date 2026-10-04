---
name: code-quality
description: Foundational rule — what "clean" means in this project. One of the five load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# Code Quality Principles

> **Hard rule (TL;DR):** Clean, efficient, stable, DRY, secure. No `any` without justification, no debug prints, no orphan TODOs, no `--no-verify`, no mixed commits. Each of these should fail review (convention; no CI gate ships with the baseline).

## Must

- Keep code **clean**: single responsibility, meaningful names, small focused functions, no dead code.
- Keep systems **efficient**: parameterized queries, proper indexes, avoid N+1, paginate list endpoints.
- Keep behavior **stable**: real error handling (project hierarchy), null safety, validate inputs at boundaries.
- Stay **DRY**: use existing base classes and utilities — do not duplicate what they already provide.
- Stay **secure**: validate every input at trust boundaries — re-validate where data crosses one, even when a type says it is valid (precedence A30) — never trust client data, never log secrets.

## Must not

- Add `any` / unchecked `unknown` without justification in the PR or file.
- Commit `console.log` / print-debug — use the project logger.
- Add a `TODO` without an owner and a delete-by date — `TODO(@owner YYYY-MM-DD): why`; a ticket may be added, never instead (`THR-TODO`, precedence A2).
- Use `--no-verify` or skip hooks unless explicitly authorized.
- Mix unrelated changes in one commit.

## Should

- Default to **no comments** unless WHY is non-obvious. Exception: the exported/public surface carries a one-line contract docstring where the project's docs rule asks for one (precedence A4).

## Review checklist

- [ ] No speculative abstractions for hypothetical requirements.
- [ ] No dead code or commented-out blocks left behind.
- [ ] Hooks and lint pass on touched files.

## Enforcement

- `PostToolUse` lint hook where configured; CI on merge if the project sets one up.
- The Stop gate (`verify-gate` → `.claude/scripts/gate-check.py`) blocks on red tests, lint, typecheck and secrets, and records the rest; the `refract-gates` CI job re-runs it in shadow mode. Everything else here is review. The hooks and what each enforces: `.claude/GUIDE.md` § Hooks.

## Anti-patterns (avoid)

- Fallback branches for scenarios that cannot happen.
- One-off "utils" dumps without a home in `ai/modules.md`.

## Cross-references

- `think-simplify-surgical.md` — extends this rule from "what *clean* means" to "how to *write* clean code on a given task" (assumptions, minimum-code, surgical scope, verifiable goal). The "Simplicity First" section there is the task-level analogue of this rule's Review checklist.
