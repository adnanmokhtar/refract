---
description: Locate a module, feature, or concept across the codebase quickly.
---

# /find-module <name|concept>

Parallel search across directory names, filenames, identifiers, and string usage. Reports primary location plus related files and registration status.

## Phases applied

DIAGNOSTIC type — 1, 2, 3 dominate. No Generate/Update/Validate/Improve unless the search reveals stale `ai/modules.md` (then a one-line update).

## When to use / NOT to use
- USE: onboarding to an unfamiliar repo; pre-flight before editing — find every place a concept lives; searching for the right module to extend instead of creating a new one.
- NOT: name is a common noun without qualifier (`/find-module user`) — too many false matches.

## Phase 1 — Understand

- Parse `<name|concept>`.
- If common noun (`user`, `order`, `item`), suggest qualifier and ask.
- Success: primary location named OR "not found" with conventions-based suggestion of where it would live.

## Phase 2 — Organize

- Plan 4 parallel searches (Phase 3).
- Decide scoring shape (path match > identifier match > string match).

## Phase 3 — Retrieve (the searches)

Parallel:
- **Directory match** — `find . -type d -iname "*<name>*"` excluding `node_modules`, `dist`, `.git`, `build`.
- **Filename match** — `find . -type f -iname "*<name>*"` with same exclusions.
- **Identifier match** — `rg -n "(class|interface|type|function|const|enum)\s+<Name>"`.
- **String reference** — `rg -nF "<name>"` (literal) for i18n keys / config / comments.

Read `ai/modules.md` (if present) for registration status + canonical owner.

Score:
- Exact name match in path = 100.
- Substring in path + same casing = 80.
- Identifier defined = 70.
- String reference only = 30.

Cluster results: primary module / related modules / DB layer / tests.

If primary not found, read 1-2 sibling modules to infer convention, suggest where it WOULD live (`src/modules/<noun>/` or `apps/<app>/src/<noun>/`).

## Phase 4 — Generate (the report)

Format the clustered results (see Output).

## Phase 5 — Update (only if drift detected)

- If `ai/modules.md` claims registration but directory absent (or vice versa), queue a one-line correction to `ai/dynamic/drift-log.md`. No auto-edit.

## Phase 6 — Validate

- Cross-check: `ai/modules.md` says registered — does the directory exist?
- For "not found" verdict: ask user for synonyms (concept aliases — "subscription" might be "membership" or "plan") before declaring final.

## Phase 7 — N/A

Pure read; no learning hook. (If repeated "not found" on same query reveals a missing alias glossary, that's a `/refresh-knowledge` job.)

## Output (found)

```
Query: subscription

Primary:
  src/modules/subscriptions/         14 files
  Registered in ai/modules.md: yes

Related:
  src/shared/guards/subscription-active.guard.ts
  src/modules/billing/                references subscription tier in 4 files

Database:
  prisma/migrations/20250310-subscriptions/migration.sql
  src/modules/subscriptions/infrastructure/persistence/subscription.orm-entity.ts

Tests:
  src/modules/subscriptions/**/*.spec.ts   18 files
  e2e/subscriptions.e2e-spec.ts            1 file

Sibling modules (similar shape, useful for new code):
  src/modules/orders/        — same module structure
  src/modules/invoices/      — same module structure
```

## Output (not found)

```
Query: refunds

No matching module.

Suggested location based on conventions:
  src/modules/refunds/
    core/
    application/
    infrastructure/
    refunds.module.ts

Related concepts already in repo:
  src/modules/orders/  (refund logic might attach here — confirm domain ownership before deciding)
```

## Failure modes

- Common noun matches dominate (`user`, `order`, `item`) — require a qualifier.
- `node_modules` / `vendor` matches dominate raw greps — always exclude.
- `ai/modules.md` lies (file moved without doc update) — cross-check directory existence.
- Concept aliases ("subscription" → "membership") — ask for synonyms before declaring not-found.
- Tests in monorepos can live far from source (`tests/` at repo root) — don't conclude "no tests" without checking.
- Speed budget < 10s — fall back to `grep -r` if `rg` absent, but flag the slowness.

## Related

### Sibling commands in code-quality pack
- `/check-health` — sibling command in code-quality pack
- `/pre-commit` — sibling command in code-quality pack
- `/review-changes` — sibling command in code-quality pack
- `/simplify` — sibling command in code-quality pack

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
