---
name: audit-logging
description: 'Pattern: Audit Logging (tamper-evident, retained, un-redacted)'
kind: ai-pattern
pack: observability
---

# Pattern: Audit Logging (tamper-evident, retained, un-redacted)

> **Hard rule:** Security-relevant actions (authn, authz changes, role/permission changes, payment + billing changes, data exports, admin overrides, PII access) are written to a **separate, append-only / WORM audit sink** — never the mutable debug-log store. Every audit event carries `actor`, `subject`, `action`, `before`/`after`, `source_ip`, and a trusted `timestamp`. Audit logs are **NOT redacted** the way debug logs are: they *are* the legal record. Retention is set by the governing regime, not by disk pressure.

**When to apply**
- The system takes privileged actions someone may later have to answer for: who changed this role, who exported this data, who approved this refund, who read this patient record.
- A compliance regime is in scope — SOC 2, PCI-DSS, HIPAA, GDPR, SOX — and an auditor will ask "prove who did what, when, and that the record wasn't altered".
- An incident retro needed to reconstruct an attacker's or insider's actions and the debug logs had already rotated away or been redacted into uselessness.

**When NOT to apply**
- Ordinary operational events (a request served, a cache miss) — those are metrics/traces/debug logs, not audit events. Auditing everything drowns the real security signal and inflates WORM storage cost.
- A single-user local tool with no privileged multi-actor actions to attribute.

**Halt conditions / mandatory cites**
- Each audit event MUST cite its emit site at `<path:line>` AND the **immutable sink** it lands in (append-only table with revoked UPDATE/DELETE, object-lock/WORM bucket, or managed audit service) — a write to the normal log store is a bug, reject.
- Each event MUST cite a non-empty `actor` AND `subject` — an audit row that can't answer "who acted on whom" is worthless; reject.
- A doc that redacts audit events with the debug-log redaction config is a bug — reject; audit records keep the real values (with access-controlled reads), they are not debug logs.
- Each retention setting MUST cite the regime that requires it (SOC 2 / PCI / HIPAA / contractual) — "keep for a while" is not a policy.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this action is audited".
- If the audit sink + its immutability guarantee + its retention policy aren't extracted, halt.

An audit log answers a fundamentally different question from a debug log. Debug logs answer *"why is the system behaving this way?"* — they are high-volume, PII-redacted, short-retention, and mutable/rotating. Audit logs answer *"who did this privileged thing, and can we prove the record is intact?"* — they are low-volume, deliberately un-redacted, long-retention, and tamper-evident. Storing the second in the pipeline built for the first is the most common audit failure.

## Boundary — security owns WHAT, observability owns the PIPELINE

Two packs meet here; keep the seam clean:

- **security** owns **which events must be audited** and the **write-shape requirement** — `rules/security-principles.md` mandates "write an audit log on every privileged action: role changes, payment changes, data exports; include actor, target, before/after, IP, timestamp". That's the security control: the list of auditable actions and the obligation to record them.
- **observability** (this pattern) owns the **pipeline**: the immutable/append-only sink, tamper-evidence (hash-chaining), retention by regime, and the PII handling that distinguishes an audit record (keep the values, access-control the reads) from a debug log (redact at write time). Security says *"a role change must be audited with before/after"*; observability says *"here's the WORM sink, the hash-chain, the 1-year retention, and why this record is not redacted like your debug logs".*

If both packs are installed, the security rule is the source of truth for the *what*; do not restate the auditable-action list here — link it.

## Event schema

Every audit event is a structured record (JSON or an append-only row) with at least:

| Field | Meaning | Example |
|---|---|---|
| `timestamp` | Trusted, server-side, UTC, ISO-8601 | `2026-07-09T14:03:11.812Z` |
| `actor` | **Who** performed the action (user id + auth method; `system`/`service:<name>` for automated) | `usr-99 (mfa)` |
| `subject` | **Whom / what** it was done to | `usr-42`, `payment:pay-77`, `dataset:pii-export-12` |
| `action` | The privileged verb, from a closed vocabulary | `role.grant`, `payment.refund`, `data.export`, `record.read` |
| `before` / `after` | State delta for changes (the whole point of "before/after") | `{role:"member"}` → `{role:"admin"}` |
| `source_ip` | Origin IP (and `user_agent` where useful) | `203.0.113.7` |
| `outcome` | `success` / `denied` / `error` — a *denied* privileged attempt is itself auditable | `denied` |
| `request_id` / `trace_id` | Correlation back to the debug/trace pipeline | `abc-123` |

`actor` and `subject` are non-negotiable — an event without both cannot answer the only question audit exists to answer.

## Tamper-evidence

Anyone with write access to a mutable store can rewrite history; an auditor won't trust it. Make alteration detectable or impossible:

- **Append-only / WORM sink.** A dedicated audit table with `UPDATE`/`DELETE` revoked from the app role; or an object-store bucket with object-lock / retention-lock (S3 Object Lock, GCS retention policy); or a managed audit trail (Cloud Audit Logs, CloudTrail, a SIEM's immutable index).
- **Hash-chain (tamper-evidence).** Each record stores `hash = H(prev_hash || record)`. Altering or deleting any row breaks the chain from that point forward, so tampering is *detectable* even if a store technically allows writes. Periodically anchor the latest hash somewhere out-of-band (a signed daily digest, a separate account) so an attacker who owns the store still can't rewrite undetected.
- **Separation of duties.** The identities that can *administer* the audit sink are not the identities the application writes with, and ideally not the ones being audited.

## Un-redacted — audit logs are the record

Debug logs redact PII at write time (see `structured-logging.md`) because they're high-volume and don't need the real values. Audit logs are the opposite: the real actor, the real subject, the real before/after values **are the evidence** — redacting them destroys the record. So:

- Do **not** run audit events through the debug-log redaction config.
- Protect the data at **read** time instead: strict RBAC on who can query the audit sink, access to the audit log is *itself* an audited action, and encrypt at rest.
- This is exactly why audit must be a *separate* sink — you cannot have one redaction policy that both scrubs debug logs and preserves audit evidence.

## Retention by regime

Retention is a legal/contractual input, not an ops preference. Set it per the strictest regime in scope and cite it:

| Regime | Typical audit-log retention |
|---|---|
| SOC 2 | ≥ 1 year (commonly 1y hot + archive) |
| PCI-DSS | ≥ 1 year, with ≥ 3 months immediately available |
| HIPAA | 6 years |
| SOX | 7 years (financial-reporting relevant) |
| GDPR | *as long as necessary* — audit of processing, balanced against data-minimization |

Enforce it with the sink's lifecycle/retention-lock so records can't be aged out early, and so they *are* purged when the regime's clock expires (over-retention of PII is its own liability).

## Detectors (what a reviewer flags)

- **Security events in the debug-log store** — role changes / exports written via the normal `logger.info(...)` into the mutable, rotating, redacted pipeline. Move them to the audit sink.
- **Audit events redacted like debug logs** — the audit record shows `[REDACTED]` where the before/after value should be. The evidence has been destroyed; un-redact and access-control the reads instead.
- **No retention or no immutability** — audit rows in a table the app can `UPDATE`/`DELETE`, or with default log rotation, or with no retention policy tied to a regime.
- **Audit events with no actor or no subject** — `action: "role.grant"` with an empty actor answers nothing.
- **Auditing everything** — ordinary request logs dumped into the audit sink, drowning the security signal and blowing WORM cost. Audit the privileged closed-vocabulary actions only.

## Related

- `security/rules/security-principles.md` — owns the auditable-action list + the write-shape requirement (actor/target/before/after/IP/timestamp); source of truth for the *what*.
- `structured-logging.md` — the debug-log pipeline this is deliberately *separate* from; its redaction policy is exactly what audit logs must NOT inherit.
- `tracing.md` — `trace_id` correlates an audit event back to the request that caused it, without putting PII in spans.
- `security/ai-patterns/auth-flow.md`, `security/ai-patterns/tenant-isolation.md` — the authn/authz + tenant-scoping events that are prime audit subjects.
