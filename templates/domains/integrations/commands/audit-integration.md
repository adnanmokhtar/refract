---
description: Audit a specific third-party integration — token storage, refresh, per-tenant isolation, retry/backoff, circuit breaker, sync idempotency, drift reconciliation, inbound validation, secrets-in-logs, and request-path blocking — against the REAL connector code, never an assumed shape.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-integration

Diagnose whether one integration (a vendor connector / external sync) is safe + resilient: where the credential lives, whether it's encrypted + refreshed + tenant-scoped, whether outbound calls are retried + rate-aware + breaker-protected, whether sync writes are idempotent + reconciled, and whether inbound vendor data is validated + verified — from the ACTUAL code, not a guess.

## Premise

Real signals only. Cite the credential storage + the encrypt/decrypt at `<path:line>`, the refresh path at `<path:line>`, the tenant-scoped connection lookup at `<path:line>`, the outbound client wrapper at `<path:line>`, the sync upsert at `<path:line>`, the reconciliation job at `<path:line>`, the inbound validation + signature check at `<path:line>`, and the enqueue that moves vendor I/O off the request path at `<path:line>` — never narrate a connector you didn't read. Read before auditing: locate the connector in source and confirm which vendor, which credential model, and which sync direction(s) it has BEFORE judging anything.

## Mechanical halt

Cite-or-halt: every run MUST print, for the named integration, (1) where the token/key is stored + whether the column is ciphertext or plaintext at `<path:line>`; (2) the refresh path + whether it's proactive, single-flighted, and atomic at `<path:line>` (or "MISSING"); (3) the connection-lookup predicate + whether the tenant id comes from the auth context or client input at `<path:line>`; (4) the outbound wrapper + whether it has timeout + retry/backoff/jitter + `Retry-After` respect + a circuit breaker at `<path:line>` (or "BARE FETCH"); (5) the sync write + whether it upserts on the external id at `<path:line>` (or "INSERT — duplicates on redelivery"); (6) the reconciliation job at `<path:line>` (or "NONE — webhook-only, silent drift"); (7) the inbound validation + webhook signature verification at `<path:line>` each (or "UNVALIDATED" / "UNVERIFIED"); (8) whether any vendor call runs on the user request path at `<path:line>`; (9) any secret reaching a log/error/trace at `<path:line>`. If any of these cannot be produced from real code, HALT and say which — never an assumed connector shape, never an assumed "it's probably encrypted."

This command READS code; it does not call the vendor, does not decrypt a real token, and does not trigger a sync. If a check needs a live credential to confirm, report what the code does and flag the credential check as "needs runtime confirmation" — never exfiltrate or print a real secret.

## What it does

1. **Locate** the connector — cite `<path:line>` for the client, the credential model, the sync writer(s), and the inbound webhook handler. Name the vendor + the sync direction (outbound / inbound / bidirectional).
2. **Token storage** — find the credential model. Is the token/key column ciphertext (encrypted column / secrets-manager ref) or plaintext? Is it keyed per tenant? Cite `<path:line>`. Plaintext or shared = BLOCKER.
3. **Refresh** — find the refresh path. Is it proactive (before `expires_at`), single-flighted (lock/mutex), and atomic (new token + expiry + rotated refresh in one tx)? Cite `<path:line>`. No refresh / non-atomic = finding.
4. **Per-tenant isolation** — find the connection lookup. Is the connection resolved from the auth-context `tenant_id`, or from a client-supplied id? Cite `<path:line>`. Client-supplied = BLOCKER (cross-tenant).
5. **Outbound resilience** — find every vendor call. Do they go through one wrapper with a timeout + retry/backoff + jitter + `Retry-After` respect + a circuit breaker? Or is there a bare `fetch(vendor)` / raw SDK call in feature code? Cite `<path:line>`. Bare call = BLOCKER.
6. **Rate-limit respect** — does a `429` wait at least `Retry-After`? Is there proactive throttling? Cite `<path:line>`. Retry-storm on `429` = finding.
7. **Sync idempotency** — find the sync write. Does it upsert on the vendor's external id (`UNIQUE (tenant_id, provider, external_id)`) and dedupe events on the vendor event id? Or `INSERT` on a surrogate id? Cite `<path:line>`. Non-idempotent = BLOCKER (duplicates).
8. **Reconciliation / drift** — is there a periodic full/windowed reconcile backstopping the incremental path, with `last_synced_at`? Cite `<path:line>`. Webhook-only with no reconcile = finding (silent divergence).
9. **Inbound validation + signature** — is the vendor payload schema-validated at the boundary before touching the domain? Is the inbound webhook signature-verified (constant-time + replay guard) before processing? Cite `<path:line>` each. Unvalidated = BLOCKER; unverified = BLOCKER.
10. **Request-path blocking** — does any vendor round-trip happen inline on a user request instead of in a background job? Cite `<path:line>`. Synchronous vendor call on the request path = finding.
11. **Secrets in logs** — grep the connector for tokens/keys/secrets/full auth headers/raw PII payloads reaching logs/errors/traces. Cite `<path:line>`. Any = BLOCKER.
12. **Report** — per-check verdict table + the top fix.

## Flow

```text
locate connector (<path:line>)  -> name vendor + sync direction
  -> token storage: ciphertext? per-tenant?              [BLOCKER if plaintext / shared]
  -> refresh: proactive? single-flight? atomic?          [finding if missing / non-atomic]
  -> connection lookup: tenant from auth ctx?             [BLOCKER if client-supplied]
  -> outbound: wrapper w/ timeout+backoff+jitter+breaker? [BLOCKER if bare fetch]
  -> rate limit: honors 429 / Retry-After?               [finding if retry-storm]
  -> sync write: upsert on external id?                   [BLOCKER if INSERT]
  -> reconciliation: periodic drift repair + last_synced? [finding if webhook-only]
  -> inbound: validated at boundary? signature-verified?  [BLOCKER each if missing]
  -> request path: any inline vendor call?                [finding if synchronous]
  -> logs: any secret / raw payload logged?               [BLOCKER if any]
  -> report: per-check verdict table + top fix
```

## Output

```
/audit-integration — <vendor> connector @ <path:line>   (direction: <outbound|inbound|bidirectional>)

Token storage:     encrypted col `access_token_enc` (KMS), keyed (tenant_id, provider) @ credential-store.ts:14
                                                            [or: PLAINTEXT `access_token VARCHAR` — BLOCKER]
Refresh:           proactive(60s skew) + FOR UPDATE single-flight + atomic tx @ credential-store.ts:48
                                                            [or: MISSING — token 401-loops on expiry — finding]
Per-tenant:        connection resolved from ctx.tenantId @ credential-store.ts:27
                                                            [or: req.body.connectionId — cross-tenant — BLOCKER]
Outbound wrapper:  timeout + backoff+jitter + Retry-After + breaker @ vendor-client.ts:22
                                                            [or: bare fetch(vendor) @ svc.ts:31 — BLOCKER]
Rate limit:        retry waits >= Retry-After @ vendor-client.ts:55      [or: immediate retry — finding]
Circuit breaker:   per provider+tenant, fail-fast when open @ circuit-breaker.ts:9   [or: NONE — finding]
Sync idempotency:  upsert ON CONFLICT (tenant_id,provider,external_id) @ upsert-contact.ts:6
                                                            [or: INSERT on surrogate id — duplicates — BLOCKER]
Reconciliation:    hourly windowed reconcile + last_synced_at @ reconcile.ts:8
                                                            [or: webhook-only, no reconcile — drift — finding]
Inbound validate:  z.object().strict() at boundary @ schema.ts:4        [or: JSON.parse -> repo.save — BLOCKER]
Webhook signature: HMAC constant-time + replay guard @ webhook.controller.ts:6  [or: UNVERIFIED — BLOCKER]
Request path:      enqueued, synced in worker @ webhook.controller.ts:18 [or: inline CRM call @ ctrl.ts:9 — finding]
Secrets in logs:   redact() applied; none logged @ redact.ts:5          [or: logs Authorization header @ svc.ts:40 — BLOCKER]

Verdict: OK | NEEDS-WORK | BLOCKER(<which>)

Top recommendation:
  - <e.g. move the token to the encrypted column; wrap the bare fetch; upsert on external_id; add a reconcile job>
```

## Rules

- READ-ONLY audit. Never call the vendor, never decrypt or print a real token/key, never trigger a sync.
- Cite-or-halt: real credential model, real refresh path, real wrapper, real upsert, real reconcile, real inbound validation + signature check — or halt naming what's missing.
- Plaintext credential, client-supplied connection, bare vendor fetch, non-idempotent sync write, unvalidated/unverified inbound payload, and any secret in logs are each reported FIRST as BLOCKERs.
- A webhook-only pipeline with no reconciliation is a silent-divergence finding, never an "ok because webhooks usually fire."
- Never report "it's probably encrypted / scoped / retried" — show the line or halt.
- If confirming a check needs a live credential or a runtime call, say "needs runtime confirmation" — do not fabricate the result.

## Cross-references

- `.claude/rules/integrations-sync-discipline.md` — the hard-rule list this command enforces (vault, refresh, isolation, wrapper, idempotency, reconciliation, validation, async, redaction).
- `ai/patterns/third-party-integration.md` — the encrypted store + atomic refresh + retry/backoff client + breaker + idempotent upsert + reconciliation + inbound validation code shapes.
- `<rules-path>/webhook` — inbound vendor event signature verification + replay guard this command checks for.
- `<rules-path>/background-jobs` — the async sync path a synchronous vendor call should move to.
- `<agents-path>/integrations-reviewer.md` — the review gate that consumes these findings.
