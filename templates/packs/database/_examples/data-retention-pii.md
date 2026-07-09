---
name: data-retention-pii
kind: example
pack: database
---

# Pattern: Data Retention + PII

Every table classified for PII, every PII column with a retention window enforced by a real mechanism, and erasure implementable without orphaning rows. Owns the **schema/storage mechanics**; regulatory data-flow + compliance mapping belong to the security pack's `data-privacy-reviewer`. Extract the engine first — purge + encryption primitives are engine-specific.

## PII classification

You cannot retain or erase what you have not inventoried. Pick ONE mechanism per repo, apply uniformly:
- **Column comment** — `COMMENT ON COLUMN users.email IS 'pii:email; retention:account+30d'`.
- **Data-catalog table** — `data_classification(table, column, category, retention_days, purge_mechanism)`.
- **ORM annotation** — Prisma `/// @pii(email)`, TypeORM column `comment`.

Categories: `name`, `email`, `phone`, `gov_id`, `location`, `financial`, `health` (last three high-sensitivity).

## Retention enforcement

A window is theatre unless a mechanism enforces it:
- **Time-partition + `DROP PARTITION`** — O(1), no scan, no bloat. Right default for append-heavy PII. See `sharding-partitioning.md`.
- **TTL column + scheduled batched delete** — `retain_until` + `pg_cron` / MySQL event scheduler, `LIMIT`ed to avoid long locks.
- **MongoDB TTL index** — best-effort, ~minute granularity.

## Erasure vs anonymization

- **Hard-delete** — the row leaves; correct when nothing downstream needs it.
- **Tombstone-and-scrub** — null/hash PII, set `anonymized_at`; correct when the row MUST survive (audit/ledger/tax).

## Erasure ↔ FK cascade (implementability probe)

Trace the FK graph outward from the PII root; every edge must resolve **CASCADE / anonymize / SET NULL**. An unresolved `ON DELETE RESTRICT` means erasure throws at runtime — the path is not implementable. The most common silent failure.

## Encryption-at-rest

- **TDE** — full-volume; baseline against stolen disks/backups, transparent to queries.
- **Column/app-level** — high-sensitivity fields (`gov_id`, card, health) via `pgcrypto` / KMS envelope; store `key_version` for rotation. TDE alone does not hide a field from a DB user with SELECT.

## Backups / replicas / soft-delete

A hard-delete does NOT remove PII from yesterday's snapshot — retention must cover backups (flagged here, not fixed). A soft-deleted row STILL holds its PII: the purge job MUST include `deleted_at < now() - retention`.

## Forbidden

- PII column with no classification/tag.
- PII table with no retention policy / purge mechanism.
- Erasure path blocked by a non-cascading FK.
- Soft-delete with no hard-purge job.
- High-sensitivity field stored plaintext.
