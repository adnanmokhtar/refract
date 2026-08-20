# database pack — changelog

Release history for `templates/packs/database/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
