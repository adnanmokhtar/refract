---
description: Review a migration for safety, lock impact, reversibility, and deploy compatibility.
---
<!-- generated-from: templates/packs/database/commands/migration-review.md
     Faithful seed copy of the database /migration-review command (literal-copy fallback for
     /setup-project Phase 4.2-AUTHOR when extraction has no signal). The abridged form of this
     file used to drop the safety gate and the engine-specific operation-class table — the two
     sections a greenfield project most needs — so it now carries the source verbatim and check
     8b holds the two in lockstep (COPY-DRIFT). REGENERATE whenever the command changes —
     do not hand-edit; edit the command and re-copy. -->


# /migration-review [file|recent]

Migrations are the highest-risk code in the repo. Review every one against prod table sizes, not dev's empty tables.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every claim cites `<file:line>` or `<table.column>`.**

A migration review without locations is theatre. "Consider expand-contract" is not a finding; `BLOCKER  migrations/042-add-status.ts:14 — ALTER TABLE orders SET NOT NULL on <table> is class-3 (rebuild) on <engine> <version> per <DDL-table citation>, shipped in the same deploy as the app change` is a finding. Every BLOCKER / REQUEST / NIT points at the SQL line, the **operation class with the engine-doc citation** that makes it dangerous, and the row-count assumption that scales it.

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
| **BLOCKER** — `synchronize: true`; a **class-3 (rebuild / copy)** statement on a populated table with no expand-contract; a class-1/2 claim the engine's own DDL table contradicts; missing `CONCURRENTLY` on a populated Postgres index build; empty `down()` without an irreversible-by-design note | `request-change` (with fix sequence) | forces BLOCK | NO — emit with anchor |
| **REQUEST** — **no lock timeout set in a DDL migration** (whatever the op class); empty `down()` on a reversible op; `UPDATE` without batching on a large table; schema + data mixed in one file | `request-change` (with corrected pattern) | forces REQUEST_CHANGES | NO — emit with anchor |
| **NIT** — type choice (VARCHAR vs enum), comment-header style, naming style | `suggest` (one-liner) | no verdict impact | NO — emit batched |
| Prod row count unknown AND no sibling inference | `escalate` | halts review | YES — ask, then resume |
| Finding contradicts accepted ADR | `escalate` | halts review | YES — surface ADR + finding |

**Forbidden:** emitting a BLOCKER or REQUEST without `<migration-file:line>` + `<table>` + row-count assumption. Hand-wave findings ("this looks risky") are ejected at validation.

## Mechanical halt — hand-wave grep

See [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). **Migration-review supplements:** also grep the draft for migration-specific vague tokens: `looks risky`, `might lock`, `may rewrite`, `consider expand-contract`, `could be slow`, `seems unsafe`, `appears to`, `possibly`, `unclear`. Anchors require `<migration-file:line>` + `<table>` + row-count assumption.

If row count is missing on any BLOCKER/REQUEST → HALT and ask user before issuing verdict. A verdict without row-count grounding is unreliable per Phase 6 self-audit.

## Lightweight default

**Default closure is anchored-finding emission with mechanical verdict, no chatter.** The agent does NOT pause to ask "should I block this?" — the closure-verb table decides. Verdict is mechanical: any BLOCKER → BLOCK; any REQUEST without BLOCKER → REQUEST_CHANGES; only NITs or none → APPROVE.

```
Auto-emitted (no prompt): <N> BLOCKER + <M> REQUEST + <K> NIT with anchors
  - BLOCKER  migrations/042:14  orders (~<rows>)  SET NOT NULL — class 3 on <engine>, no expand-contract
  - REQUEST  migrations/042:12  orders            no lock_timeout / lock_wait_timeout set
  - REQUEST  migrations/042:31  orders            empty down() — add DROP COLUMN
  - NIT      migrations/042:14  orders            VARCHAR(32) for enum — consider native enum
Verdict: REQUEST_CHANGES (mechanical: 1 BLOCKER + 1 REQUEST)
Escalated to user: <K> (e.g., row count unknown on table X; ADR contradiction on table Y)
```

## Phases applied

All 7. Phase 6 = the verdict; Phase 4 = the per-pattern findings.

## Honesty clause

No verdict without the grounding behind it: every BLOCKER/REQUEST cites a real `<migration-file:line>` + `<table>` + the prod row-count assumption that made it dangerous — no remembered or inferred locations. An operation **class** is a fact read off the engine's own DDL support table — cite the table, do not infer it from a row count and do not carry it over from another engine. A lock *duration* is an estimate derived from the class plus the size, never a measured number unless `migration-rehearsal` actually ran (per its "no number without a real timed run" discipline); say "estimated" when it is estimated. If prod row count is unknown and no sibling inference exists, the verdict is reported as `unreliable — row count ungrounded`, never as a confident APPROVE.

## When to use / NOT to use
- USE: any uncommitted migration file; right before merging a PR with migrations; before promoting staging → prod.
- NOT: never skip — every migration gets reviewed.

## Phase 1 — Understand

- Parse `[file|recent]`:
  - File path → review that file.
  - `recent` or no arg → all migrations in current branch vs `origin/main`.
- For each migration, capture the **engine + version** and the target tables + estimated row count. The engine and version decide the operation class; the row count only scales a class-2/3 duration. Ask the user if either is unknown; default-pessimistic (assume populated).
- Success: per-migration verdict (APPROVE / REQUEST_CHANGES / BLOCK) with findings tagged BLOCKER / REQUEST / NIT.

## Phase 2 — Organize

- For each migration: dispatch `schema-reviewer` with file content + table sizes.
- Plan checks across 4 dimensions: safety on populated tables, lock impact, reversibility, deploy compatibility, data correctness.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `.claude/codebase-profile.md` — DB engine + ORM (Postgres / MySQL; TypeORM / Prisma) — the canonical engine/ORM source for every Retrieve phase in this pack.
- `ai/patterns/migrations.md` — expand-contract pattern.
- `ai/patterns/indexing-strategy.md` — whether the index is worth its write cost, and the FK-index asymmetry between engines.
- The engine's own online-DDL / `ALTER TABLE` documentation for the project's **version**. A class asserted without it is a hand-wave.
- `ai/runbooks/deployment.md` — does code or migration ship first?

CONTEXT:
- Production row counts (ask if unknown — default pessimistic).
- Recent migrations on the same table (for serialization order).

## Phase 4 — Generate (per-pattern checks)

Reviewer checks each pattern:

### Safety on populated tables — classify the operation, then judge it

The first question is not "how many rows" but **which class** the statement falls into on this engine and version (see `ai/patterns/migrations.md`): metadata-only, in-place build/scan, or rebuild/copy. Read the class off the engine's DDL table and cite it in the finding; a finding that asserts a rewrite the engine does not perform is as wrong as one that misses a rewrite it does.

- `ADD COLUMN ... NOT NULL DEFAULT <value>` — **Postgres 11+**: no rewrite when the default is non-volatile; a rewrite when it is volatile (`now()`, random/uuid). **MySQL/InnoDB 8.0.12+**: `ALGORITHM=INSTANT`, metadata-only — *unless* the table is `ROW_FORMAT=COMPRESSED`, carries a `FULLTEXT` index, or has hit the 64-row-version ceiling (`ERROR 4092`). The BLOCKER here is not the add; it is the **`NOT NULL` enforcement over existing rows** (a scan on Postgres, a table rebuild on MySQL) shipped in the same deploy as the app change. Fix: 3-step expand-contract — add nullable → batched backfill → set NOT NULL.
- `ADD CONSTRAINT FOREIGN KEY` on an existing table — **Postgres**: `ADD CONSTRAINT … NOT VALID` commits without a scan; `VALIDATE CONSTRAINT` then takes only `SHARE UPDATE EXCLUSIVE`. **MySQL has no `NOT VALID`**: this is `ALGORITHM=COPY` unless `foreign_key_checks` is disabled, and disabling it means existing rows are never verified — require the anti-join proof in the migration. If the constraint carries `ON DELETE CASCADE`/`SET NULL`, note that `LOCK=NONE` is refused on that table from then on.
- `ALTER COLUMN TYPE` (incompatible) — class 3 on Postgres and on MySQL; on MySQL, "Changing the column data type is only supported with `ALGORITHM=COPY`" and it does **not** permit concurrent DML. Expand-contract.
- Rename column → expand-contract (add new → dual-write → backfill → switch reads → drop old). A hard rename breaks the rolling deploy regardless of how cheap the DDL is.
- Drop column → ensure no code references it AND back up. Multi-step: stop writing → wait a deploy → drop. On MySQL this also burns a row version.

### Lock impact
- **Every DDL migration must set a lock timeout.** `SET lock_timeout` (Postgres) / `SET SESSION lock_wait_timeout` (MySQL — the default is `31536000`, one year). Absent = REQUEST, whatever the op class. Rationale below.
- **The definition-lock queue is the real hazard, and it is class-independent.** An online DDL "always requires [an exclusive metadata lock] in the final phase of the operation when updating the table definition… A long running or inactive transaction that holds a metadata lock on the table can cause an online DDL operation to timeout" ([MySQL § Online DDL Limitations](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-limitations.html)); Postgres takes `ACCESS EXCLUSIVE` on most `ALTER TABLE` forms, which conflicts with plain `SELECT`. Everything arriving after the waiting DDL queues behind it. Ask: does this migration run at a time when a long transaction could be open, and is the wait bounded?
- Postgres: `CREATE INDEX CONCURRENTLY` MUST be outside a transaction; a plain `CREATE INDEX` blocks writes for the whole build.
- **MySQL (InnoDB): a secondary index build is In Place, does not rebuild the table, and permits concurrent DML** — "the table remains available for read and write operations while the index is being created". Flagging `ALTER TABLE … ADD INDEX` as blocking is a false positive. What *is* worth a finding: the algorithm clause omitted (so a downgrade is silent), `LOCK=NONE` used on a table with cascading FKs (refused), or a `FULLTEXT`/`SPATIAL` index build (these do **not** permit concurrent DML).
- `pt-online-schema-change` / `gh-ost` are the right call for **throttling, pausability, or replica-lag control** — native online DDL offers none of the three — or when the op is class-3 anyway. "Native ALTER locks" is not a valid reason and should be corrected where a migration's comment claims it.

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
- For "expand-contract proposed": **planned, not promised — verify mechanically.** When a BLOCKER's fix is an N-step expand-contract sequence, grep the branch / PR for the follow-up migration files (the M2 backfill, M3 `SET NOT NULL`, etc.) by their expected slugs:
  ```bash
  git diff --name-only origin/main...HEAD -- '*migrations*' '*migration*'
  # cross-check the expand-contract step slugs against this list
  ```
  - If every follow-up step has a matching migration file on the branch → the sequence is **planned**; note it as satisfied.
  - If one or more follow-up files are absent → do NOT silently pass. Downgrade to a `REQUEST` on the reviewed migration: "expand-contract step(s) `<slug>` not present on branch — note as REQUEST until the follow-up migrations land." A promise in prose is not a planned migration.
- Self-audit: did the reviewer ask for prod row count? If not, the verdict is unreliable.

## Phase 7 — Improve

- If a BLOCKER pattern recurs (e.g. NOT NULL DEFAULT on populated tables) across 3+ PRs, queue rule sharpening to `ai/dynamic/learned-patterns.md`.
- If `synchronize: true` slips into a prod config, queue urgent ADR + CI check.

## Output

```
Migration: 042-add-order-status.ts
Engine: <engine> <version>
Target table: orders (~<rows> rows, prod estimate)

Verdict: REQUEST_CHANGES

Findings:

BLOCKER  NOT NULL enforced in the same statement that adds the column
  migrations/042-add-order-status.ts:14  orders (~<rows> rows, <engine> <version>)
  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'pending'
  Op class: the ADD is class-1 on this engine (<cite the DDL table>). The blocker is the
  NOT NULL: enforcing it over existing rows is class-<n> here, and the app cannot start
  requiring the column in the same deploy that creates it.
  Fix: split into 3 migrations:
    1. ALTER TABLE orders ADD COLUMN status VARCHAR(32) NULL   (class 1; state the algorithm)
    2. UPDATE orders SET status = 'pending' WHERE status IS NULL   (batched)
    3. ALTER TABLE orders ALTER COLUMN status SET NOT NULL, SET DEFAULT 'pending'

REQUEST  No lock timeout
  migrations/042-add-order-status.ts:12 — no SET lock_timeout / lock_wait_timeout.
  An unbounded DDL that queues behind an open transaction takes the table down with it.

REQUEST  Empty down()
  Add: ALTER TABLE orders DROP COLUMN status;

REQUEST  Backward compat
  Old app code uses { status: undefined } in inserts. After step 1 it works (NULL allowed). After step 3 it breaks.
  Plan: deploy new code referencing status BEFORE step 3; run step 3 in a follow-up release.

NIT  Type choice
  VARCHAR(32) for an enum — consider native enum or CHECK constraint.
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (data-loss, irreversibility, table-locking / blocking DDL on a hot table) → **SHOULD FIX** (missing index for the new access path, naming/convention drift) → **OPTIONAL** (cosmetic) — each step carrying the migration step / `<file:line>` + **Fix** (concrete; the safe rewrite — e.g. expand-contract, `CONCURRENTLY`, batched backfill) + **Verify** (lock check / dry-run / rollback test), then the closing steps (re-run `/migration-review` to confirm it comes back clean, `/learn-from-task`, then ship). A clean run collapses to a single line ("Safe — clear to apply"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Reviewing against dev's empty table — meaningless; always assess vs prod row count.
- `synchronize: true` (TypeORM) / `prisma db push` in prod — blocker, no exceptions.
- FK on huge tables — index the referencing column BEFORE adding the constraint (Postgres does not create it for you; InnoDB does, so the finding does not simply mirror — see `indexing-strategy.md` § Foreign keys).
- Flagging an InnoDB secondary-index build as blocking — it is not, and the false positive trains reviewers to ignore the check.
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
