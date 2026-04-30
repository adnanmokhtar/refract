---
description: Scan the codebase for prompt bloat, unbounded contexts, and missing cost accounting.
---

# /token-audit

Purpose: catch AI cost leaks before they hit the bill.

## Premise

Find real issues, no hand-waves. Every finding cites `<file:line>` or `<resource>` — never "review the prompt builder" or "consider capping tokens." If you can't point to the offending line, the finding doesn't exist.

## Mechanical halt

Hand-wave grep — refuse to report any finding without a `file:line` anchor in the table. Generic suggestions ("look into prompt size") are dropped before printing. A run with zero findings is a valid result; a run with vague findings is a bug.

## What it checks

Run grep-based checks across `src/` and report:

1. **Unbounded product lists in prompts.** Every call path into `PromptBuilder` must pass a products array capped at 40 (see `rules/ai-cost-tracking.md`).
   - Flag: any `PromptBuilder.build({ products })` call where `products` is not demonstrably capped.
2. **Missing `max_tokens`.** Every `anthropic.messages.create({…})` call must set `max_tokens`. Flag any without.
3. **Cost-on-read leaks.** Any `computeCostUsd(` outside `infrastructure/claude/`. Cost is computed at write time only.
4. **Pricing table hardcoded elsewhere.** Any numeric literal matching Anthropic's pricing multiplied by token vars outside `infrastructure/claude/pricing.ts`.
5. **Prompt string concatenation outside PromptBuilder.** Any `` `...${userMessage}...` `` pattern inside a non-test file in `application/` or `infrastructure/claude/` that's not inside the PromptBuilder itself.
6. **Full-prompt logging.** Any `logger.info(` call passing a variable named `prompt` / `messages` / `system`. These must be `debug` only, PII-redacted.
7. **Conversation history not capped.** Every `MessageRepo.recent(…)` call must pass a `limit`. Flag missing or `limit > 10`.

## How to run

```bash
.claude/skills/token-audit-scan.sh    # or equivalent — grep-based, fast
```

Or invoke as a slash command; Claude runs the grep checks and produces a table:

| File:Line | Check | Severity | Suggested fix |

## When to run

- Pre-commit on any PR touching `application/services/prompt-builder/`, `infrastructure/claude/`, or `application/handle-incoming-message/`.
- Before each release.
- Weekly, as a background sweep.

## Follow-up

Each finding gets either a fix or an explicit `// token-audit:ignore <reason>` with a tracked justification. No silent ignores.
