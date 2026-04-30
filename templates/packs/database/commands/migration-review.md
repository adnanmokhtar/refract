---
description: Review a migration for safety, lock impact, reversibility, and deploy compatibility.
---

# /migration-review [file|recent]

Migrations are the highest-risk code in the repo. Review every one against prod table sizes, not dev's empty tables.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every claim cites `<file:line>` or `<table.column>`.**

A migration review without locations is theatre. "Consider expand-contract" is not a finding; `BLOCKER  migrations/042-add-status.ts:14 — ALTER TABLE orders ADD COLUMN status NOT NULL DEFAULT 'pending' on 5M rows rewrites the table` is a finding. Every BLOCKER / REQUEST / NIT must point at the SQL line and the prod-row-count assumption that made it dangerous.

**The agent's job is exactly this:**
1. Read the migration file line-by-line.
2. For each risky pattern detected, anchor it: `<migration-file:line>` + the `<table>` it touches + the prod row count assumption.
3. Severity by mechanical rule (see closure-verb tiers), not vibes.
4. Verdict (APPROVE / REQUEST_CHANGES / BLOCK) is a function of finding count and severity, not a judgment call.

**The agent does NOT:**
- Emit "this might be slow" — either cite the lock pattern at `<file:line>` against a row-count assumption, or drop the finding.
- Surface a BLOCKER without a fix — every BLOCKER must include the expand-contract sequence or the corrected SQL.
- Approve without confirming prod row count — review against dev's empty table is meaningless.
- Draft an ADR to legitimize a `synchronize: true` config — that is always a BLOCKER.

**The agent ONLY asks the user when:**
- Prod row count is unknown AND no sibling migration on the same table exists for inference (default-pessimistic if unsure, but flag it).
- A finding contradicts a prior accepted ADR (e.g., team accepted single-migration risk for a one-off batch table).
- The migration is irreversible by design and the rationale is not in the file's comment header.

## Closure-verb tiers (mandatory dispatch table)

| Severity | Closure | Verdict impact | User prompt? |
|---|---|---|---|
| **BLOCKER** — `synchronize: true`, NOT NULL DEFAULT on > 1M rows, FK validate without NOT VALID, missing CONCURRENTLY on populated index, empty `down()` without irreversible-by-design note | `request-change` (with fix sequence) | forces BLOCK | NO — emit with anchor |
| **REQUEST** — empty `down()` on reversible op, `UPDATE` without batch on > 100k rows, schema + data mixed in one file | `request-change` (with corrected pattern) | forces REQUEST_CHANGES | NO — emit with anchor |
| **NIT** — type choice (VARCHAR vs enum), comment-header style, naming style | `suggest` (one-liner) | no verdict impact | NO — emit batched |
| Prod row count unknown AND no sibling inference | `escalate` | halts review | YES — ask, then resume |
| Finding contradicts accepted ADR | `escalate` | halts review | YES — surface ADR + finding |

**Forbidden:** emitting a BLOCKER or REQUEST without `<migration-file:line>` + `<table>` + row-count assumption. Hand-wave findings ("this looks risky") are ejected at validation.

## Mechanical halt — hand-wave grep

**Before emitting the verdict, the agent MUST run the hand-wave grep:**

1. Grep the draft review for hand-wave tokens: `looks risky`, `might lock`, `may rewrite`, `consider expand-contract`, `could be slow`, `seems unsafe`, `appears to`, `possibly`, `unclear`.
2. For each hit: anchor with `<migration-file:line>` + `<table>` + row-count assumption, OR delete the line.
3. Re-grep. If any hand-wave survives without anchor → HALT.
4. The validator-equivalent check: `findings_emitted = findings_with_anchor_and_rowcount`. If unequal → HALT, do not emit verdict.

If row count is missing on any BLOCKER/REQUEST → HALT and ask user before issuing verdict. A verdict without row-count grounding is unreliable per Phase 6 self-audit.

## Lightweight default

**Default closure is anchored-finding emission with mechanical verdict, no chatter.** The agent does NOT pause to ask "should I block this?" — the closure-verb table decides. Verdict is mechanical: any BLOCKER → BLOCK; any REQUEST without BLOCKER → REQUEST_CHANGES; only NITs or none → APPROVE.

```
Auto-emitted (no prompt): <N> BLOCKER + <M> REQUEST + <K> NIT with anchors
  - BLOCKER  migrations/042:14  orders (~5M rows)  ADD COLUMN NOT NULL DEFAULT — rewrite
  - REQUEST  migrations/042:31  orders             empty down() — add DROP COLUMN
  - NIT      migrations/042:14  orders             VARCHAR(32) for enum — consider native enum
Verdict: REQUEST_CHANGES (mechanical: 1 BLOCKER + 1 REQUEST)
Escalated to user: <K> (e.g., row count unknown on table X; ADR contradiction on table Y)
```

## Phases applied

All 7. Phase 6 = the verdict; Phase 4 = the per-pattern findings.

## When to use / NOT to use
- USE: any uncommitted migration file; right before merging a PR with migrations; before promoting staging → prod.
- NOT: never skip — every migration gets reviewed.

## Phase 1 — Understand

- Parse `[file|recent]`:
  - File path → review that file.
  - `recent` or no arg → all migrations in current branch vs `origin/main`.
- For each migration, capture target tables + estimated row count. Ask user if not known; default-pessimistic (assume populated).
- Success: per-migration verdict (APPROVE / REQUEST_CHANGES / BLOCK) with findings tagged BLOCKER / REQUEST / NIT.

## Phase 2 — Organize

- For each migration: dispatch `schema-reviewer` with file content + table sizes.
- Plan checks across 4 dimensions: safety on populated tables, lock impact, reversibility, deploy compatibility, data correctness.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `ai/stack.md` — DB engine + ORM (Postgres / MySQL; TypeORM / Prisma).
- `ai/patterns/migrations.md` — expand-contract pattern.
- `ai/patterns/indexing-strategy.md` — concurrent index requirement.
- `ai/runbooks/deployment.md` — does code or migration ship first?

CONTEXT:
- Production row counts (ask if unknown — default pessimistic).
- Recent migrations on the same table (for serialization order).

## Phase 4 — Generate (per-pattern checks)

Reviewer checks each pattern:

### Safety on populated tables
- `ADD COLUMN ... NOT NULL DEFAULT <value>` on > 1M rows → MySQL rewrites table; PG < 11 same; PG ≥ 11 fast path only when default is constant. Fix: 3-step expand-contract — add nullable → batched backfill → set NOT NULL.
- `ADD CONSTRAINT FOREIGN KEY` on existing table → validates all rows; long lock. Fix: `ADD CONSTRAINT ... NOT VALID` then `VALIDATE CONSTRAINT` (Postgres) or precheck data + small lock window.
- Rename column → expand-contract (add new → dual-write → backfill → switch reads → drop old). Hard rename = breaks rolling deploy.
- Change column type → expand-contract.
- Drop column → ensure no code references it AND backup. Multi-step: stop writing → wait deploy → drop.

### Lock impact
- Postgres: `CREATE INDEX CONCURRENTLY` MUST be outside a transaction; standard `CREATE INDEX` blocks writes.
- Postgres: `ALTER TABLE` holds `ACCESS EXCLUSIVE` on most operations; some are metadata-only on PG ≥ 11.
- MySQL/MariaDB: most `ALTER TABLE` rewrites the table (InnoDB online DDL covers some). For big tables → `pt-online-schema-change` or `gh-ost`.

### Reversibility
- `down()` actually reverses the change. Empty `down()` = blocker unless irreversible by design + documented.
- Data transformations: provide reverse plan or annotate as one-way with backup step.

### Deploy compatibility
- **Backward compatible** — old code MUST work AFTER migration runs (rolling deploys).
- **Forward compatible** — new code MUST work BEFORE migration runs (post-deploy migrations).
- Choose one explicitly. Most teams: backward-compat + run migrations before deploying app code.

### Data correctness
- `UPDATE` on > 100k rows → batch (`LIMIT 1000` loop) to avoid replication lag and lock storms.
- No `DELETE` without explicit backup step or audit trail.
- `synchronize: true` / auto-migrate in prod settings = ALWAYS a blocker.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-migration-review-<n>.md` — store the report (long migrations).
- `ai/status.md` — Recent Changes entry if BLOCK or REQUEST_CHANGES.
- For BLOCK verdict: comment on the PR with blocker list.

## Phase 6 — Validate

- For each finding: confirm SQL pattern actually present in the file (no false-positive on similar-looking syntax).
- For "expand-contract proposed": confirm the 3 follow-up migrations are planned, not just promised.
- Self-audit: did the reviewer ask for prod row count? If not, the verdict is unreliable.

## Phase 7 — Improve

- If a BLOCKER pattern recurs (e.g. NOT NULL DEFAULT on populated tables) across 3+ PRs, queue rule sharpening to `ai/dynamic/learned-patterns.md`.
- If `synchronize: true` slips into a prod config, queue urgent ADR + CI check.

## Output

```
Migration: 042-add-order-status.ts
Target table: orders (~5M rows, prod estimate)

Verdict: REQUEST_CHANGES

Findings:

BLOCKER  Single ALTER on populated table
  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'pending'
  On 5M rows this rewrites the table and holds ACCESS EXCLUSIVE for ~minutes.
  Fix: split into 3 migrations:
    1. ALTER TABLE orders ADD COLUMN status VARCHAR(32) NULL  (instant; metadata-only on PG ≥ 11)
    2. UPDATE orders SET status = 'pending' WHERE status IS NULL  (batched, 1000 rows at a time)
    3. ALTER TABLE orders ALTER COLUMN status SET NOT NULL, SET DEFAULT 'pending'  (after backfill verified)

REQUEST  Empty down()
  Add: ALTER TABLE orders DROP COLUMN status;

REQUEST  Backward compat
  Old app code uses { status: undefined } in inserts. After step 1 it works (NULL allowed). After step 3 it breaks.
  Plan: deploy new code referencing status BEFORE step 3; run step 3 in a follow-up release.

NIT  Type choice
  VARCHAR(32) for an enum — consider native enum or CHECK constraint.
```

## Failure modes

- Reviewing against dev's empty table — meaningless; always assess vs prod row count.
- `synchronize: true` (TypeORM) / `prisma db push` in prod — blocker, no exceptions.
- FK on huge tables — index BEFORE adding the constraint, or constraint validation full-scans the table.
- Two migrations in one PR locking the same table — serialize them.
- "Pure data" UPDATE migration — still locks rows; use `FOR UPDATE SKIP LOCKED` or batch.
- Down migration claiming to restore dropped data — that's a lie; say so.

## Related

### Sibling commands in database pack
- `/add-migration` — sibling command in database pack
- `/db-audit` — sibling command in database pack
- `/optimize-query` — sibling command in database pack

### Patterns
- `ai/patterns/indexing-strategy.md`
- `ai/patterns/migrations.md`
- `ai/patterns/sharding-partitioning.md`

### Rules
- `.claude/rules/database-principles.md`
