---
name: data-retention-pii
description: "Pattern: Data Retention + PII — schema/storage mechanics of the PII lifecycle: classification, retention windows, erasure vs anonymization, column encryption, and how these survive soft-delete, FKs, and backups."
kind: ai-pattern
pack: database
---

# Pattern: Data Retention + PII

> **Hard rule:** Every table is classified for PII, every PII column has a declared retention window enforced by a real mechanism (partition-drop / TTL job / scheduled purge), and erasure is implementable without orphaning rows or breaking referential integrity. PII stored with no retention policy, or an erasure path that a foreign key silently blocks, is forbidden. Cite the classification, the purge mechanism, and the erasure-vs-FK resolution at `<path:line>` — or halt.

**Ownership boundary (read first).** This pattern owns the **schema/storage mechanics**: which columns are PII, the retention TTL / partition-purge, erasure-vs-FK-cascade resolution, and column-level encryption. It does **not** own regulatory compliance mapping. The security pack's **`data-privacy-reviewer` agent** (being authored separately) owns the **code-level data-flow + compliance side**: collection → sink → third-party egress, DSAR fulfilment, cross-border transfer, and GDPR/PDPL/CCPA article mapping. When a finding is about *where PII flows in code* or *which regulation applies*, stop and point there — do not re-derive it here.

**When to apply**
- A schema stores anything that identifies a person: name, email, phone, government ID, precise location, financial, or health data.
- A "delete my account" / erasure request must be satisfiable and you need to prove the DB can actually do it.
- A table grows unbounded with personal records and no purge exists.

**When NOT to apply**
- The data is genuinely non-personal (aggregate counters, opaque system IDs with no join back to a person).
- The question is *regulatory* ("does GDPR Art. 17 apply", "is this a lawful basis") — that is `data-privacy-reviewer`, not this pattern.

**Halt conditions / mandatory cites**
- Each PII column MUST cite its classification tag AND its retention window at `<path:line>` (comment, catalog row, or naming convention).
- Each PII table MUST cite the purge mechanism (partition drop / TTL / scheduled job) at `<path:line>`.
- An erasure path MUST cite how each dependent FK is resolved (cascade / anonymize / SET NULL) — an unresolved `ON DELETE RESTRICT` blocking erasure is a bug, reject.
- Hand-wave grep on `etc.`, `...`, `probably fine`, `handled elsewhere` is forbidden when claiming "PII is covered".
- If the DB engine + version aren't extracted, halt — purge and encryption primitives are engine-specific.

## PII classification / tagging

You cannot retain or erase what you have not inventoried. Every PII column carries a machine-readable classification. Pick ONE mechanism per repo and apply it uniformly:

- **Column comment** — `COMMENT ON COLUMN users.email IS 'pii:email; retention:account+30d'`. Greppable, lives with the schema.
- **Data-catalog table** — a `data_classification(table_name, column_name, category, retention_days, purge_mechanism)` row per PII column. Queryable, auditable, drives automation.
- **Naming / ORM annotation** — Prisma `/// @pii(email)`, TypeORM `@Column({ comment: 'pii:email' })`. Tags travel with the model.

Categories to inventory: `name`, `email`, `phone`, `gov_id`, `location`, `financial`, `health`. The last three are **high-sensitivity** (see encryption).

## Retention-window enforcement

A retention window is theatre unless a mechanism enforces it. Cheapest to most manual:

- **Time-partitioned table + `DROP PARTITION`** — partition by `created_at`; purge = drop the expired partition. O(1), no row scan, no bloat. The right default for append-heavy PII (events, logs, sessions). See `sharding-partitioning.md`.
- **TTL column + scheduled delete** — `expires_at` / `retain_until` column + a cron job (`DELETE ... WHERE retain_until < now() LIMIT <batch>`), batched to avoid long locks. Postgres `pg_cron`, MySQL event scheduler.
- **MongoDB TTL index** — `db.sessions.createIndex({ createdAt: 1 }, { expireAfterSeconds: N })`. The engine purges. Note: TTL granularity is ~minutes, best-effort, not exact.

Retention window = a stated duration tied to a lifecycle anchor (`account_closed + 30d`, `created + 90d`), not "forever" and not undocumented.

## Right-to-erasure vs anonymization

Two distinct operations — choose per row, not per table:

- **Hard-delete (erasure)** — the row leaves. Correct when nothing downstream needs it.
- **Tombstone-and-scrub (anonymization)** — keep the row's shape, null/hash the PII columns, set an `anonymized_at` marker. Correct when the row **must** survive: a financial/audit record referenced by immutable ledgers, an order kept for tax law, an FK dependent that cannot be orphaned. Scrub replaces PII with an irreversible placeholder (`'redacted'`, a one-way hash, or NULL) so the record's *structure* remains but the *person* is unrecoverable.

Anonymized data is out of scope for erasure only if it is genuinely non-re-identifiable — a hashed email joined against a rainbow of known emails is still PII.

## Erasure ↔ FK cascade (the implementability probe)

Erasing a `user` row must not orphan its dependents (`orders`, `comments`, `audit_log`) or silently fail on an `ON DELETE RESTRICT` FK. For every FK pointing at a PII parent, the erasure design must state one resolution:

- **CASCADE** — dependents are personal too and go with the parent.
- **Anonymize** — dependents must survive (financial/audit): scrub their PII columns, keep the row, break the identifying link.
- **SET NULL** — the dependent survives de-personalized, FK becomes NULL.

The probe: *trace the FK graph outward from the PII root and confirm every edge has a chosen resolution.* An unresolved `RESTRICT` edge means erasure will throw at runtime — the erasure path is not implementable. This is the FK analog of the retention rule and the most common silent failure.

## Encryption-at-rest

- **TDE (transparent data encryption)** — full-volume / tablespace encryption (RDS/Aurora storage encryption, MySQL InnoDB TDE). Protects against stolen disks/backups. Transparent to queries. Baseline for any PII store.
- **Column-level / app-level** — high-sensitivity fields (`gov_id`, card data, health) get an additional layer: Postgres `pgcrypto`, or app-side envelope encryption via a KMS. TDE alone does *not* protect a field from a DB user with SELECT rights; column encryption does.
- **Key-rotation implication** — column/app-level encryption means keys must rotate, and rotation implies re-encrypting or key-versioning existing rows. Store a `key_version` alongside the ciphertext so old rows stay decryptable across rotations. Design rotation before you encrypt, not after a key leaks.

## PII in backups, replicas, and derived stores

- **Backups** — a hard-delete removes PII from the live table but NOT from yesterday's snapshot. Retention must cover backups: a backup rotation window shorter than or aligned to the retention policy, or documented that erasure is eventually-consistent to backup-expiry. Flag this — this pattern does not fix backup rotation, it requires it be stated.
- **Replicas** — purge propagates via replication; a logical/decoupled replica or a warehouse copy may not. Flag, defer the flow-tracing to `data-privacy-reviewer`.
- **Soft-delete ↔ retention** — a soft-deleted row (`deleted_at IS NOT NULL`) STILL holds its PII. Soft-delete is a UX/consistency tool, not erasure. The purge job MUST include soft-deleted rows once past the window: `DELETE WHERE deleted_at < now() - retention`. A soft-delete with no hard-purge job means PII lingers indefinitely. See `indexing-strategy.md` for the partial-index that keeps the soft-delete filter cheap.
- **Logs / derived stores** — PII copied into application logs, analytics events, or search indexes lives outside this schema. That is a **code-level data-flow** concern → `data-privacy-reviewer`. This pattern only flags that the pointer exists.

## Adapt to the codebase

Detect the engine and choose primitives to match. Never assume Postgres.

| Engine | Retention purge | Encryption |
|---|---|---|
| **Postgres** | RANGE partition + `DROP PARTITION`; or `pg_cron` batched delete on a `retain_until` column | TDE via cloud volume; `pgcrypto` for high-sensitivity columns |
| **MySQL** | Partitions + `DROP PARTITION`; or event scheduler batched delete | InnoDB TDE; app-level envelope encryption for columns |
| **MongoDB** | TTL index (`expireAfterSeconds`) | Encrypted storage engine; client-side field-level encryption (CSFLE) for high-sensitivity fields |
| **ORM tagging** | Prisma `/// @pii`; TypeORM column `comment`; carried into the catalog | — |
| **Cloud** | Snapshot retention aligned to policy | RDS/Aurora storage encryption + **KMS** key per data class |

## Detectors (cite-or-halt)

1. **PII column with no classification/tag.** BAD: `email varchar` with no comment/catalog row. GOOD: `email varchar` + `COMMENT ... 'pii:email; retention:account+30d'`. Grep: columns named `email|phone|ssn|tax_id|dob|address|card|health` — cross-check against catalog/comments.
2. **PII table with no retention policy / purge mechanism.** BAD: a personal-data table with no partition scheme, no TTL column, no purge job. GOOD: partitioned + drop schedule, or `retain_until` + cron. Grep: `pg_cron|event scheduler|expireAfterSeconds|DROP PARTITION|retain_until|expires_at` near the table.
3. **Erasure path blocked by a non-cascading FK.** BAD: FK to `users` with `ON DELETE RESTRICT` and no anonymize step — erasure throws or is skipped. GOOD: every FK edge resolved CASCADE / anonymize / SET NULL. Grep: `ON DELETE RESTRICT|NO ACTION` on FKs referencing a PII parent.
4. **Soft-delete with no hard-purge job.** BAD: `deleted_at` set, row keeps PII forever. GOOD: purge job deletes soft-deleted rows past the window. Grep: `deleted_at` columns with no matching `DELETE ... deleted_at <` job.
5. **High-sensitivity field stored plaintext.** BAD: `gov_id`, card number, or health field as plain `varchar` with no column/at-rest encryption. GOOD: `pgcrypto` / CSFLE / envelope-encrypted + `key_version`. Grep: `gov_id|ssn|tax_id|card_number|pan|diagnosis|health` not wrapped in an encryption path.
6. **Purge job that ignores backups/replicas.** BAD: live delete only, backup snapshots outlive the retention window with no stated alignment. Flag as a gap — noted here, **not fixed here** (backup rotation is ops).
7. **`SELECT *` / broad export raking PII with no field-level control.** BAD: bulk export or `SELECT *` over a PII table into a report/sink. GOOD: explicit non-PII projection. Flag and **hand the data-flow to `data-privacy-reviewer`** — the sink/egress side is theirs.

## Closure verbs

Classify every column, declare a retention window, wire a purge mechanism, resolve every FK edge on the erasure path, encrypt high-sensitivity fields, align backup retention, purge soft-deleted rows, and point log/egress findings to `data-privacy-reviewer`.

## Related

- `sharding-partitioning.md` — partition-drop as the cheapest retention purge.
- `indexing-strategy.md` — partial index for the soft-delete filter that purge relies on.
- `migrations.md` — adding retention/classification columns and encryption safely under concurrent writes.
- cross-pack `security` `data-privacy-reviewer` — **owns the code-level data-flow (collection→sink→egress, DSAR, cross-border) and regulatory compliance mapping**; this pattern owns schema/storage mechanics. State the boundary in any joint finding. (Being added to the security pack.)
- cross-pack `security` `security-principles` — encryption + secrets baseline this pattern's at-rest rules build on.
- `@schema-reviewer` — enforces classification + retention + FK-erasure resolution at review time.
