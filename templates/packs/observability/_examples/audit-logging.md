---
name: audit-logging
kind: example
pack: observability
---

# Pattern: Audit Logging (tamper-evident, retained, un-redacted)

Audit logs answer "who did this privileged thing, and can we prove the record is intact?" — the opposite question from debug logs ("why is the system behaving this way?"). They go to a separate, append-only sink; carry actor/subject/action/before-after/IP/timestamp; are NOT redacted (they *are* the evidence); and are retained by regime.

**Boundary:** the security pack owns WHICH events must be audited + the write-shape (`security-principles.md`). This pattern owns the PIPELINE — immutable sink, hash-chain, retention, and why audit records aren't redacted like debug logs.

## Event schema (actor + subject are non-negotiable)

```json
{
  "timestamp": "2026-07-09T14:03:11.812Z",
  "actor":     "usr-99 (mfa)",
  "subject":   "usr-42",
  "action":    "role.grant",
  "before":    { "role": "member" },
  "after":     { "role": "admin" },
  "source_ip": "203.0.113.7",
  "outcome":   "success",
  "trace_id":  "abc-123"
}
```

An event with an empty `actor` or `subject` answers nothing — reject it. A *denied* privileged attempt (`outcome: "denied"`) is itself auditable.

## Separate, append-only sink (never the debug-log store)

```sql
-- dedicated table; app role has INSERT only
CREATE TABLE audit_log (
  id         BIGSERIAL PRIMARY KEY,
  ts         TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor      TEXT NOT NULL,
  subject    TEXT NOT NULL,
  action     TEXT NOT NULL,
  before     JSONB,
  after      JSONB,
  source_ip  INET,
  outcome    TEXT NOT NULL,
  prev_hash  BYTEA,
  hash       BYTEA NOT NULL
);
REVOKE UPDATE, DELETE ON audit_log FROM app_role;   -- append-only
GRANT  INSERT, SELECT ON audit_log TO app_role;
```

Equivalent immutable sinks: an S3/GCS bucket with Object-Lock / retention-lock, or a managed trail (CloudTrail, Cloud Audit Logs, SIEM immutable index).

## Hash-chain (tamper-evidence)

```ts
// each record chains to the previous; altering any row breaks the chain forward
function chain(prevHash: Buffer, record: object): Buffer {
  return createHash('sha256')
    .update(prevHash)
    .update(canonicalJSON(record))   // stable key order
    .digest();
}
// anchor the latest hash out-of-band daily (signed digest in a separate account)
```

## Un-redacted — do NOT reuse the debug-log redaction config

```ts
// WRONG — destroys the evidence
auditLogger.info({ actor, subject, before, after });  // pino redact scrubs before/after → [REDACTED]

// RIGHT — keep real values, protect at READ time
await auditSink.append({ actor, subject, before, after, source_ip, outcome });
// RBAC on who can query auditSink; reading it is itself an audited action; encrypted at rest
```

## Retention by regime (cite the regime)

| Regime | Retention |
|---|---|
| SOC 2 | ≥ 1 year |
| PCI-DSS | ≥ 1 year (≥ 3 months hot) |
| HIPAA | 6 years |
| SOX | 7 years |

Enforce with the sink's retention-lock — so records can't be aged out early, and *are* purged when the clock expires (over-retaining PII is its own liability).

## Detectors

- Security events written via `logger.info(...)` into the mutable/rotating/redacted debug store.
- Audit record showing `[REDACTED]` where before/after should be — evidence destroyed.
- Audit rows the app can `UPDATE`/`DELETE`, or with default log rotation / no retention tied to a regime.
- Events with no actor or no subject.
- Everything dumped into the audit sink (ordinary request logs) — drowns the signal, blows WORM cost.
