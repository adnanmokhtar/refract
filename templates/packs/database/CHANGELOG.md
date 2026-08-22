# database pack — changelog

Release history for `templates/packs/database/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.6.0 — 2026-08-22

- **Every pointer out of the rule resolves in the installed layout.** `database-principles.md`
  carried ten `ai-patterns/<x>.md` references and two `references/<engine>.md` ones, written
  pack-relative. The installer copies `ai-patterns/` into `ai/patterns/` and `references/` into
  `.claude/references/`, while rules land in `.claude/rules/` — so from the installed rule those
  paths resolved to `.claude/rules/ai-patterns/` and `.claude/rules/references/`, neither of which
  any install has. Both forms corrected. This is load-bearing rather than cosmetic: the pointer *is*
  the shrink strategy for this file, so a dangling one costs the whole lift.
- **The rule says which file carries the citation.** Its three MySQL source links were dropped as
  part of the shrink, leaving engine-specific claims — InnoDB auto-creating the FK index, the
  `LOCK=NONE` cascade restriction, INSTANT `ALTER` queueing behind an open transaction — sitting
  uncited in an always-loaded file. The links live in `ai/patterns/migrations.md` and
  `ai/patterns/indexing-strategy.md`, which the bullets already point at, so the fix is to say so:
  the header now states that the linked pattern carries the vendor citation for every engine claim
  below, and that none of them may be asserted without following the pointer to the doc that
  sources it.
- **`database-principles`: 8,000 → ~6,560 characters (~2,000 → ~1,639 always-loaded tokens)**,
  clearing the shrink debt carried over from the release that was asked for it and did not deliver.

## 1.5.0 — 2026-08-22

Pack-wide quality pass. The engine claims are engine-named and sourced throughout; the agents state
what is NOT their job; the commands, skills and patterns classify operations by what the engine
actually does rather than by row count, and decide whether an index is worth its write cost.

### Commands, skills and ai-patterns

- **`/add-migration` classifies by operation class, not row count.** Phase 2 replaces the
  size-tiered op table with three classes — metadata-only / in-place build-or-scan / rebuild-copy —
  read off each engine's own DDL support table and cited, plus a **MySQL fast-path probe**
  (`SHOW CREATE TABLE` for `ROW_FORMAT=COMPRESSED` and `FULLTEXT`,
  `INNODB_TABLES.TOTAL_ROW_VERSIONS` against the 64-version ceiling / `ERROR 4092`) that must run
  before any `ALGORITHM=INSTANT` claim. The closure-verb tiers key on the class; a class-1 op whose
  probe fails is a P0, not a P2.
- **The definition-lock queue is named as a first-class hazard** in `/add-migration`,
  `/migration-review`, `migrations.md` and `migration-rehearsal`. An online DDL "always requires
  [an exclusive metadata lock] in the final phase… when updating the table definition", and every
  statement arriving after the waiting DDL queues behind it — so the table is down for as long as
  the *oldest transaction* runs. Every DDL migration must now carry a blocker pre-flight
  (`performance_schema.metadata_locks` + `INNODB_TRX` / `pg_locks` + `pg_stat_activity`) and a
  bounded wait; MySQL's `lock_wait_timeout` default is one year, so unbounded is the shipped
  default. Absent lock timeout is a REQUEST-level finding whatever the op class.
- **The MySQL online-DDL falsehood is gone from every command, skill and pattern.** A secondary
  index build on InnoDB is In Place, does not rebuild the table, and permits concurrent DML.
  `pt-online-schema-change` / `gh-ost` are now justified by the three things native online DDL
  cannot do — no pause, no I/O throttle, replication lag — and any recommendation must name which
  applies. Added alongside: `LOCK=NONE` is refused on tables with `ON…CASCADE`/`ON…SET NULL`;
  `ADD FULLTEXT`/`ADD SPATIAL` do not permit concurrent DML; `ADD FOREIGN KEY` is `COPY` unless
  `foreign_key_checks` is disabled, and MySQL has no `NOT VALID`.
- **`indexing-strategy` can now decide whether an index is worth adding.** The 60-line index-type
  catalogue is deleted; in its place a three-input verdict — the query's measured share of total
  execution time (`pg_stat_statements` / `events_statements_summary_by_digest`), the recoverable
  fraction (rows read vs rows returned), and the write cost including the **Postgres HOT loss**
  (indexing a column the update path writes disqualifies heap-only tuples, so *every* index on the
  table pays per update). `WORTH IT` / `NOT WORTH IT` / `UNJUSTIFIED` are the three outcomes; a
  proposal with a blank in the block is invalid. The invented "indexes > 3× table size" budget and
  the "< 1000 rows" folklore are replaced by their determinants. Net 188 → 161 lines.
  `/optimize-query` gates every index proposal on that verdict.
- **The FK-index advice inverts per engine.** InnoDB creates the referencing-table index
  automatically, so the MySQL finding is the *redundant* leftover (`sys.schema_redundant_indexes`),
  not a missing index; Postgres still needs it added explicitly.
- **`sharding-partitioning` is a decision artifact.** Deleted: the shard-routing/rebalancing
  encyclopedia, the managed-service catalogue, and the "Read replicas (before sharding)" stub that
  `read-replicas.md` superseded in 1.3.0. Added the check that actually ends most partitioning
  proposals — **every unique key, primary key included, must contain all the partition-key
  columns** — plus the two benefits partitioning buys and the fact that hash partitioning buys
  neither. The scale-signal table now keys on write IOPS rather than storage size. 164 → 90 lines.
- **`migration-rehearsal` gained a MySQL lane**, so the gate it feeds is reachable on both engines.
  Restore, baseline, an MDL-aware lock observer, an algorithm probe that states `ALGORITHM=` so the
  engine errors instead of silently downgrading, and the `pt-osc --dry-run` fallback reported as
  `PARTIAL`. Documented gotchas: a logical restore resets `TOTAL_ROW_VERSIONS` and so hides the
  ceiling; a rehearsal on an idle copy cannot reproduce the definition-lock queue at all.
- **`/db-audit` has a real MySQL path for every check** (`sys.schema_unused_indexes`,
  `sys.schema_redundant_indexes`, `sys.schema_tables_with_full_table_scans`,
  `events_statements_summary_by_digest`, `information_schema.TABLES.DATA_FREE`), and dispatches
  `database-optimizer` scoped to surfaces the engine has — **InnoDB has no vacuum and no dead-tuple
  bloat**, so a bloat finding there is a fabrication, not a false positive. Slow-query findings now
  report share of total execution time, the input the index decision needs.
- **`schema-consistency-audit`: 12 detectors → 11**, and findings rank by data-integrity risk
  instead of detector index. Index-naming and fk-naming merged into one low-risk `object-naming`
  detector whose strategy is the engine's in-place rename — the old `simple` strategy ordered a
  drop-and-recreate index build for a cosmetic gain. New `integrity_class` field
  (corrupts-data / loses-precision / breaks-queries / cosmetic) does the ranking.
- **`schema-diff`** emits the fix command in the project's detected migration tool instead of
  hard-coding Prisma, and states plainly that autogenerate cannot tell a rename from a drop+add.
- Fixed: the MySQL FULLTEXT "ignores words in > 50% of rows" claim is **MyISAM-only** and was
  asserted under an InnoDB heading (the neighbouring `innodb_ft_min_token_size` default of 3 was
  and is correct); `data-retention-pii`'s boundary line no longer says the security-pack reviewer
  "is being authored" — it shipped; `connection-pooling`'s fleet-ceiling halt now names where each
  reserve term is read from, so the arithmetic it demands can actually be closed;
  `transaction-isolation`'s Adapt table labels its isolation levels as syntax examples rather than
  implied recommendations, and gives the one reason (InnoDB gap-lock contention) that does justify
  a default change.
- **Fabricated measurements removed from every template** that taught them: `/add-migration`'s
  "measured ~2-5m" inside the gate that exists to stop exactly that, its "rehearsal passed
  (forward 4.2min…)" output line, and `/optimize-query`'s "820ms → 8ms". All are now
  `<measured-forward>` / `<p95-before> → <p95-after>` slots.
- **Command fallbacks are declared literal copies.** `_examples/{add-migration, migration-review,
  db-audit, optimize-query}.md` carry `generated-from:`, so check 8b holds them line-for-line
  against their sources (COPY-DRIFT). The abridged forms had been dropping the Migration-Safety
  Gate, the honesty clause, `--plan`, the per-engine check paths and the `## Related`
  sibling-boundary section — on a greenfield project the fallback *is* the artifact, so those were
  the sections most needed and least present. `_examples/{transaction-isolation,
  data-retention-pii}.md` regained their `## Related` boundary sections.

### Agents and rule

- **Online-DDL truth, agents + rule.** `CREATE INDEX` on InnoDB is in-place with concurrent DML
  permitted; `pt-online-schema-change` / `gh-ost` are for `COPY`-class operations
  (column type change, FK add with `foreign_key_checks` on), replication-lag throttling, or a
  pausable build — not a blanket substitute for native `ALTER`. Corrected in
  `agents/{schema-reviewer,schema-architect,query-optimizer}.md` and
  `rules/database-principles.md`. Sources cited inline.
- **Operation class replaces row count.** `schema-reviewer`'s concurrent-write-safety table is now
  per-engine and keyed on the algorithm the engine picks (metadata-only / INSTANT / in-place
  rebuild / COPY), with the InnoDB INSTANT exclusions (`ROW_FORMAT=COMPRESSED`, `FULLTEXT`, the
  row-version ceiling) as a check the reviewer must run. Its halt and D2 changed with it.
- **Metadata locks** are named as a first-class hazard for the first time: an INSTANT `ALTER`
  still queues behind a long transaction, and every later query queues behind the `ALTER`. D2 now
  requires a pre-flight blocker check plus a bounded wait. `LOCK=NONE` is also documented as
  unavailable on tables carrying `ON…CASCADE` / `ON…SET NULL` — which collides with the rule's own
  explicit-`ON DELETE` MUST.
- **FK indexing is engine-split.** InnoDB auto-creates the referencing-table index; Postgres does
  not. The MySQL finding is the redundant leftover, not the missing index.
- **`database-optimizer` rewritten.** Deleted the three sections duplicating `connection-pooling`,
  `read-replicas` and `sharding-partitioning`, and the cloud-DB catalogue. It now owns memory/cache
  sizing (vendor rules cited, not invented percentages), the reclaim path as an explicit
  Postgres-VACUUM-vs-InnoDB-purge split, and storage tier — with a Boundary table naming every
  surface it delegates.
- **`query-optimizer`** gained the MySQL EXPLAIN lane and the write-cost half of the index verdict
  (share of total execution time vs write amplification, with the counters to read for each);
  invented latencies in its output template replaced with measured-value slots.
- **`schema-architect`** no longer invents retention periods or the compliance regimes behind them
  (halt + `<TBD>`), points at `data-retention-pii.md` (the old link was to a file that never
  existed), and carries MySQL rows in its column-type table.
- **Rule shrunk and re-aimed.** `rules/database-principles.md`: the duplicated Review checklist and
  the five paragraph-length pattern summaries are gone (~2.2k chars of always-loaded duplication);
  the bare `(cores*2 + spindles)` pool bullet is deleted in favour of the fleet-ceiling invariant
  the same file already stated correctly; thresholds with no determinant replaced by the
  determinant. Net 8045 → 7754 bytes while adding four sourced engine mechanisms.
- **Fallbacks repaired.** All four agent `_examples/` gained the `## Related` sibling-boundary
  section they had been dropping, so a greenfield project no longer receives agents with no idea
  what is not their job. `_examples/schema-reviewer.md` regained the entire APPROVE gate (D1–D5,
  the unmeasured-lock halt, the D-line output block) that shipped in 1.4.0 and never reached the
  fallback.
- `_topics.md`: the rule topic is named `database-principles` (it was `- name: database`, copied
  from the backend pack's unrelated data-access rule, and its `sections:` list described that file
  rather than this one).


CORRECTED IN AUDIT (defects found in this release before it shipped — each re-fetched)
- **`EXPLAIN ANALYZE FORMAT=JSON` errors on every MySQL version.** It was input 2 of the indexing
  worth-it verdict, so that input was unobtainable on MySQL. `EXPLAIN ANALYZE` "always uses the
  `TREE` output format" and `FORMAT=JSON`/`TRADITIONAL` with it "always raises an error"
  (`ERROR 1235`) — dev.mysql.com/doc/refman/8.4/en/explain.html. `rows_examined_per_scan` /
  `rows_produced_per_join` belong to plain `EXPLAIN FORMAT=JSON`, which is an estimate with no
  execution. The pattern now reads rows off the TREE iterators and says the counter totals all
  `loops`. `query-optimizer:32` and `database-principles:49` had it right all along.
- **The FK-redundancy rule was inverted**, in the always-loaded rule and in the APPROVE-gate
  reviewer. MySQL: the auto-created FK index "might be silently dropped later if you create another
  index that can be used to enforce the foreign key constraint" — so the leading-column case is the
  one that self-resolves, and when the composite does *not* lead with the FK column the
  single-column index is **required**, not redundant. "Redundant" was the wrong label on both sides
  of the split. All nine sites now state both branches and say a drop is safe only in the first.
  `schema-architect`'s example was self-refuting (`(tenant_id, customer_id)` does not lead with the
  FK column, so the auto index survives and is required).
- **`SET NOT NULL` was classed 3 against the row it quotes.** MySQL 8.4 Online DDL Operations gives
  "Making a column NOT NULL": In Place Yes, Rebuilds Table Yes, **Permits Concurrent DML Yes** — an
  in-place rebuild that stays online. The three-class taxonomy had no slot for it because it
  conflated "rebuild" with "blocks writes", so the op drew a P0 and a maintenance window. Class 3 is
  now explicitly a statement about cost, not blocking; the tier table keys P0 off the engine's
  `Permits Concurrent DML` column instead.
- **`information_schema.STATISTICS.CARDINALITY` cannot answer the selectivity question.** STATISTICS
  covers *indexed* columns only and CARDINALITY estimates unique values "in the index" — but the
  input is offered to decide whether to index a column that has no index, so on MySQL it returns
  nothing. Postgres `pg_stats.n_distinct` genuinely works there; the MySQL twin was not equivalent.
  The executable answer (`SELECT COUNT(DISTINCT col)/COUNT(*)`) is now given.
- **The online-FK recipe's safety step was not a barrier.** With `LOCK=NONE` + `foreign_key_checks=0`
  writes proceed unchecked, so any row arriving between the step-1 anti-join and the ALTER's
  completion is never verified — and MySQL has no `VALIDATE CONSTRAINT` to close the window. Both
  honest resolutions are now offered and one must be chosen: `LOCK=SHARED` (no row can arrive, so
  the proof holds) or `LOCK=NONE` plus a re-run of the anti-join after commit, which covers exactly
  the window because post-commit writes are constraint-checked.
- **Fallbacks kept vendor quotes and dropped their URLs.** `_examples/database-optimizer.md` carried
  the `shared_buffers` 25%/40% and `innodb_dedicated_server` 128MB/×0.5/×0.75 numbers with zero
  sources, inside a file that says "cite the rule, never invent a percentage" — and on greenfield the
  fallback is the only artifact delivered. Sources restored across the database fallbacks
  (optimizer, query-optimizer, indexing-strategy, sharding-partitioning, schema-architect).

## 1.4.0 — 2026-07-10

- add-migration Migration-Safety Gate (D1 reversible · D2 online-safe with a MEASURED lock/backfill
  profile ≤ SLO · D3 index coverage by EXPLAIN · D4 rename/type-change backfill+dual-write plan · D5
  no data loss); any unmet/unverified dim → INCOMPLETE, grounded in the migration-rehearsal report.
- schema-reviewer: APPROVE is now a positive evidenced claim; halt forbids APPROVE on an
  unmeasured-lock populated-table migration (downgrade to BLOCK).

## 1.3.0 — 2026-07-10

- ai-patterns +3: full-text-search (engine text primitive + ranking vs LIKE-scan),
  connection-pooling (bounded pool sizing/mode, pgbouncer txn-mode, serverless proxy), read-replicas
  (lag-tolerant read routing / read-your-writes).

## 1.2.0 — 2026-07-09

- ai-patterns +2: transaction-isolation (DB-engine locking/isolation/deadlock-avoidance/MVCC — the
  engine-semantics counterpart to backend's service-scope transaction-boundary) and
  data-retention-pii (PII classification, retention/purge mechanism, erasure-vs-FK, at-rest
  encryption — the storage-mechanics counterpart to security's data-privacy-reviewer). Backing
  MUST/SHOULDs + checklist in database-principles.

## 1.1.1 — 2026-06-14

- schema-consistency-audit skill: added `name:` frontmatter field (was missing).
