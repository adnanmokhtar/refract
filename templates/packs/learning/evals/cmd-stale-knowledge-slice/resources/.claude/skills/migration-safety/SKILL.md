---
name: migration-safety
description: Reviews a migration for locks, rewrites and unsafe defaults before it merges.
kind: skill
allowed-tools: [Read, Grep, Glob, Bash]
pack: database
---

<!-- project-specific:start -->
## Project-specific (Orderly)

> Round-one anchor (Phase 4.6 / 2026-07-08); deepened by `/setup-project --refine` on 2026-07-10.
> Refresh source: `.claude/_codebase-scan.md` (re-run the scan before the next refine).
> REFINE rewrites between these markers; user-authored content outside is preserved verbatim.

**Where this applies in Orderly**:
- Migrations live in `apps/api/src/migrations/` and run with `pnpm --filter @orderly/api migration:up`.
- The order table is the largest; index changes on it go through review.

**Flows that exercise this rule**:
- e2e: every suite boots a testcontainers MySQL 8 instance and runs the migrations first.

**Failure themes to avoid**:
- Long locks on the order table: see `ai/failures/_index.md`.
<!-- project-specific:end -->

# Skill: migration-safety

Read one migration and answer: does it lock a hot table, rewrite it, or add a default that blocks writes?

## Checks

1. Every `ALTER TABLE` on a large table sets a lock timeout first.
2. New indexes on large tables are built without blocking writes.
3. A new non-null column has a default the database can add without a rewrite.
