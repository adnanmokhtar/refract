---
name: audit-log-discipline
description: Audit-log discipline
kind: rule
---

# Audit-log discipline

## Hard rule

The audit log is the tamper-evident, append-only, retained record of WHO did WHAT to WHICH thing, WHEN, from WHERE, and with what OUTCOME. Audit rows MUST be append-only and immutable — `UPDATE` / `DELETE` on audit rows is FORBIDDEN and MUST be revoked at the database grant level (or enforced by trigger / WORM store). Every audit entry MUST carry actor, action, target, timestamp (UTC + monotonic sequence), correlation/request id, source IP + user agent, tenant id, and outcome. Every critical security action (login, permission change, data export, admin override, deletion) MUST be audited. The audit write MUST be atomic with — or guaranteed-after — the business change it records; fire-and-forget that can silently drop is FORBIDDEN. Raw secrets, full PANs, passwords, and tokens MUST NEVER be written to an audit row. The chain MUST be integrity-verifiable (hash chain or sequence + anchoring) so gaps and reordering are detectable. Read access to the audit store is itself access-controlled AND audited.

The audit log is the one record you reach for after a breach, a dispute, or a compliance request — when every other source is suspect. If it can be silently mutated, silently dropped, or silently gapped, it is worthless exactly when it matters.

## Must

- **Append-only at the storage layer.** Audit rows are inserted, never modified. `UPDATE` / `DELETE` grants on the audit table are REVOKED from the application role (`REVOKE UPDATE, DELETE ON audit_log FROM app_role`), or blocked by a `BEFORE UPDATE OR DELETE` trigger that raises, or the store is a true WORM / object-lock bucket. Business logic must NEVER depend on mutating an audit row — corrections are NEW rows that reference the prior one.
- **Required fields, enforced.** Every entry carries: `actor` (user id + `impersonator_id` if acting-as), `action` (a stable verb — `user.role.granted`, `order.deleted`, `data.exported`), `target` (`target_type` + `target_id`), `before` / `after` (or a structured diff) for mutations, `occurred_at` (UTC) + monotonic `seq`, `correlation_id` / `request_id`, `source_ip`, `user_agent`, `tenant_id`, and `outcome` (`success` / `denied` / `error`). Missing a required field → the write fails loudly, not silently.
- **Tamper-evidence.** Each row stores `prev_hash` and `row_hash = H(prev_hash ‖ canonical(row))` over a CANONICAL serialization (sorted keys, fixed encoding) — OR a strictly monotonic gap-free `seq` with periodic anchoring (sign/notarize the head hash on a schedule). Either way the chain is verifiable end-to-end and detects insertion, deletion, reordering, and mutation.
- **Reliable capture.** The audit write commits in the SAME transaction as the business change, OR is emitted via a transactional outbox / change-data-capture so it is guaranteed-after and cannot be lost. Capture lives in an interceptor / middleware / repository hook — not sprinkled by hand at each call site where it can be forgotten.
- **Critical actions always audited.** Authentication (login success/failure, logout, MFA change), authorization changes (role/permission grant + revoke), data export / bulk read, admin overrides + impersonation start/stop, and every destructive operation (delete, purge, anonymize) emit an audit entry. No code path performs one of these without an entry.
- **PII / secret minimization with field-level redaction.** Audit enough to be forensically useful, but redact secrets and minimize PII: store identifiers and hashes, not raw values. A redaction allow/deny list runs on the event payload before persistence.
- **Separate, access-controlled store.** Audit data lives in its own table / schema / store with its own restricted role. Read access requires a privilege AND reading the audit log is itself audited (a `audit.read` / `audit.export` entry). Retention follows the governing regulation (often years); destructive "cleanup" of in-retention records is FORBIDDEN.
- **Query / export for investigation + compliance.** Indexed and time-partitioned for investigations and compliance reports — partition by time, index `(tenant_id, target_type, target_id)` and `(actor_id, occurred_at)` — WITHOUT exposing any mutation path. Exports themselves are audited.

## Must not

- `UPDATE` or `DELETE` an audit row — at all, by anyone, including "fix a typo in the reason" or a GDPR-erasure cron. Corrections and erasures are append-only events (crypto-shred referenced PII; keep the audit row).
- Fire-and-forget the audit write (`void auditLog.emit(...)` with no awaited durability) on a path that can silently drop the entry — a queue with no delivery guarantee, an async call whose rejection is swallowed.
- Write the audit entry in a transaction that may roll back the business change while the audit row commits separately (or vice-versa) — leaving either a phantom audit of a change that never happened, or a real change with no trace.
- Store raw secrets, passwords, full PANs, API tokens, session tokens, or unredacted sensitive PII in an audit row.
- Couple the audit log to debug / application logging — routing `logger.info(...)` to the audit store, or treating an ephemeral, sampled, rotated app-log line as the audit record. Debug logs are for engineers and disappear; audit logs are for investigators and regulators and are retained.
- Skip the entry on critical actions "because it's an internal job" / "because it's an admin" — privileged and automated actions are the ones investigators care about MOST.
- Leave the chain unverifiable — no `prev_hash`, no monotonic sequence, no anchoring — so a deleted or reordered row is undetectable.
- Grant unrestricted read on the audit store, or read it without leaving an `audit.read` entry.

## Should

- Wrap emission behind a project-internal `<AuditLog>` interface (`record(event)`) so the store, hashing, and redaction are one swappable implementation — never scattered raw inserts.
- Derive the `action` verb vocabulary from a closed enum / registry so reports can group reliably and a new sensitive action is a deliberate addition, not an ad-hoc string.
- Capture `before` / `after` as a structured diff (changed fields only) rather than full-row snapshots when rows are large — enough to reconstruct what changed without bloating the store.
- Persist the canonical-serialization function used for hashing alongside the schema version (`hash_version`) so the verifier reproduces historical hashes exactly across format changes.
- Run an integrity-verification job on a schedule (recompute the chain over a window, compare against anchored heads) and alert on ANY mismatch or gap.
- Make impersonation/admin-override entries first-class and highlighted in compliance reports — they are the highest-signal rows.
- Reconcile coverage: a periodic check that asserts every sensitive action type has a corresponding emit site (see the verify command). Drift here is a coverage hole, not noise.

## Review checklist (PRs touching audit emission / audit schema / sensitive actions)

- [ ] No `UPDATE` / `DELETE` against the audit table anywhere; grants revoked or trigger present (cite the migration).
- [ ] New sensitive action (login / permission / export / override / delete) emits an audit entry on every path, including failure (`outcome: denied`).
- [ ] Audit write is atomic-with or guaranteed-after the business change (same txn, or outbox) — not fire-and-forget that can drop.
- [ ] Entry carries actor (+ impersonator), action verb, target type+id, before/after or diff, UTC timestamp + seq, correlation id, source IP, user agent, tenant id, outcome.
- [ ] Payload passes redaction — no secrets / tokens / full PAN / password / unredacted PII.
- [ ] `prev_hash` + `row_hash` (or monotonic seq + anchoring) populated; `hash_version` stored.
- [ ] Audit store is the separate restricted store; read path emits an `audit.read` entry.
- [ ] No retention-cleanup deletes in-retention rows; erasure is append-only crypto-shred, not row delete.
- [ ] Indexes / partitioning support investigation queries without introducing a mutation path.
- [ ] Audit emission is NOT routed through the debug/application logger.

## Anti-patterns

- **Mutable audit row** — `UPDATE audit_log SET reason = ? WHERE id = ?` to "correct" an entry. Now the record is editable, so it proves nothing. Append a correction row referencing the original.
- **Fire-and-forget drop** — `auditQueue.publish(event)` with no awaited ack, no outbox, errors swallowed. Under load or a broker blip the entry silently vanishes — exactly the period an investigator will ask about.
- **Split-transaction trace** — business change commits, audit write throws and is caught-and-ignored → a real deletion with no record. Or audit commits, business txn rolls back → an audit of a change that never happened. Bind them: same txn, or outbox.
- **Debug-log-as-audit** — `logger.info({ userId, action })` to stdout, rotated after 7 days, sampled under load. When legal asks for who exported the customer list 8 months ago, the line is gone. Audit is a durable, append-only, queryable store.
- **Secret in the trail** — auditing a password reset and storing the new password hash, or auditing an integration and dumping the API token into `after`. The audit log becomes a credential store to breach.
- **Coverage gap on deletion** — every read is audited but `DELETE /users/:id` is not, because deletion went through a different service. The one action investigators care about most is invisible.
- **No integrity chain** — rows have no `prev_hash` and a reused / non-monotonic id. An insider deletes the three rows covering their action and the table looks pristine. Hash-chain or anchored sequence makes the gap detectable.
- **Unaudited audit read** — anyone with DB read can browse the audit log and no one knows who looked. Reading the trail is itself a sensitive action; emit `audit.read`.
- **Retention cleanup deletes evidence** — a "tidy old data" cron deletes rows still inside the regulatory retention window, or a GDPR-erasure job hard-deletes audit rows referencing the subject. Exclude in-retention audit rows from cleanup; erase referenced PII by crypto-shredding, keep the row.
- **Client-supplied actor/timestamp** — trusting `actor_id` or `occurred_at` from the request body. The actor is the authenticated principal; the timestamp is server-assigned. A forged actor field rewrites history.

## Enforcement

- `<commands-path>/audit-trail-verify.md` (slash: `/audit-trail-verify`) — recomputes the hash chain / sequence end-to-end (actual computed-vs-stored result, not an assumed pass) AND checks coverage of a checklist of sensitive actions, citing each emit site at `<path:line>` or FAILing.
- `<agents-path>/audit-log-reviewer.md` — review gate hard-failing on mutable audit rows, missing actor/target/correlation, secrets/PII in the trail, unaudited critical actions, split-transaction or fire-and-forget capture, missing integrity chain, unrestricted read, and audit/debug-log coupling.
- CI grant check MUST assert the application DB role has NO `UPDATE` / `DELETE` privilege on the audit table(s).
- CI lint MUST reject `UPDATE`/`DELETE` statements (raw SQL or ORM `.update()`/`.delete()`/`.destroy()`) targeting the audit model.
- CI lint MUST reject any audit-event field name or payload assignment matching `password` / `secret` / `token` / `pan` / `cvv` / `card_number` before redaction.
- Integrity-verification job MUST run on a schedule; ANY chain mismatch or sequence gap pages on-call.
- TODO: `scripts/validate-audit-coverage.sh` to AST-walk controllers/services and assert every sensitive-action handler reaches an `<AuditLog>.record(...)` call site, and that the call is on the committed (atomic / outbox) path — not a swallowed async.

## Cross-references

- `<patterns-path>/audit-trail.md` — append-only schema, hash-chain construction + verification, the `<AuditLog>` interface, transactional-outbox capture, redaction, query/export shapes.
- `<rules-path>/payment-idempotency.md` — payment operator overrides ("manual mark as paid") MUST produce an audit entry tied to a user id; this rule defines what that entry must contain.
- `<rules-path>/webhook-signature-verification.md` — inbound side-effects (account changes, exports triggered by webhook) feed the same audit trail; the actor is the verified provider/installation, not an unverified payload field.
- `<commands-path>/audit-trail-verify.md` — integrity + coverage verification tool.
- `<agents-path>/audit-log-reviewer.md` — review gate.
- `<adr-path>/<NNN>-audit-retention-and-tamper-evidence.md` — ADR pinning the store, retention windows per regulation, hashing/anchoring scheme, and access-control policy.
