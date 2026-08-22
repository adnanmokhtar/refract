---
name: audit-logging
kind: example
pack: observability
---

# Pattern: Audit Logging (tamper-evident, retained, un-redacted)

> **Hard rule:** Security-relevant actions (authn, authz changes, role/permission changes, payment + billing changes, data exports, admin overrides, PII access) are written to a **separate, append-only / WORM audit sink** — never the mutable debug-log store. Every audit event carries `actor`, `subject`, `action`, `before`/`after`, `source_ip`, and a trusted `timestamp`. Audit logs are **NOT redacted** the way debug logs are: they *are* the legal record. Retention is set by the governing regime, not by disk pressure.

**Halt conditions / mandatory cites**
- Each audit event MUST cite its emit site at `<path:line>` AND the **immutable sink** it lands in (append-only table with revoked UPDATE/DELETE, object-lock/WORM bucket, or managed audit service) — a write to the normal log store is a bug, reject.
- Each event MUST cite a non-empty `actor` AND `subject` — an audit row that can't answer "who acted on whom" is worthless; reject.
- A doc that redacts audit events with the debug-log redaction config is a bug — reject; audit records keep the real values (with access-controlled reads), they are not debug logs.
- Each retention setting MUST cite the regime that requires it (SOC 2 / PCI / HIPAA / contractual) — "keep for a while" is not a policy.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this action is audited".
- If the audit sink + its immutability guarantee + its retention policy aren't extracted, halt.

Audit logs answer "who did this privileged thing, and can we prove the record is intact?" — the opposite question from debug logs ("why is the system behaving this way?"). They go to a separate, append-only sink; carry actor/subject/action/before-after/IP/timestamp; are NOT redacted (they *are* the evidence); and are retained by regime.

## Boundary — security owns WHAT, observability owns the PIPELINE

The *security* pack decides **which events are auditable**, the write-shape (`security-principles.md`), and **how long each regime requires them kept** — the compliance obligation is its subject. This pack owns the **pipeline that satisfies it**: the append-only / WORM sink, the hash chain, the schema, the retention lock, and the fact that this stream is *not* the debug-log stream.

The practical consequence, and the reason the split matters: an audit record must **not** be redacted the way a debug log is. The before/after values *are* the evidence — a `[REDACTED]` where a changed field should be has destroyed the record while appearing to comply. Redaction policy is a security decision applied to the debug stream; this stream is governed by access control and retention instead.

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
