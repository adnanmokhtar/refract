---
name: integrations-sync-discipline
description: Third-party integration & external-sync discipline
kind: rule
---

# Third-party integration & external-sync discipline

## Hard rule

Every credential for a third-party vendor (OAuth access/refresh tokens, API keys, signing secrets) MUST be stored ENCRYPTED-AT-REST, scoped per-tenant, and refreshed before expiry — a plaintext token column, a token shared across tenants, or a token that is never refreshed is a BLOCKER. Every outbound call to a vendor MUST go through a client wrapper that retries idempotent failures with EXPONENTIAL BACKOFF + JITTER, HONORS the vendor's `429` / `Retry-After`, and sits behind a CIRCUIT BREAKER — a bare `fetch(vendor)` with no retry, no rate-limit respect, and no breaker is FORBIDDEN, because a vendor blip becomes your cascading outage. Sync WRITES into your store MUST be IDEMPOTENT (upsert on the vendor's external id), because webhooks and retries redeliver. Sync state MUST be reconciled against the vendor periodically (full-sync vs. incremental) — a webhook-only pipeline with no reconciliation silently diverges. Inbound vendor payloads are UNTRUSTED INPUT: validate + parse them at the boundary before they touch your domain, and inbound webhooks MUST be signature-verified. A synchronous vendor call MUST NOT block the user's request path — move it to a background job. Secrets MUST NEVER appear in logs, error messages, or traces.

An integration bug is a leaked credential, a cross-tenant breach, a duplicate-write data corruption, or your whole product going down because one vendor had a bad afternoon — failure modes that are invisible until the vendor misbehaves, which is exactly when you have no slack to fix them.

## Must

- **Encrypt credentials at rest, per tenant**: OAuth tokens / API keys / signing secrets are stored in an encrypted column or a secrets manager (envelope encryption with a KMS data key), keyed by `tenant_id` (+ provider + connection id). A token is decrypted only at the moment of use, in memory, and never logged. The column type is ciphertext, never plaintext.
- **Refresh before expiry, atomically**: access tokens are refreshed proactively (before `expires_at`, with a skew margin) using the refresh token; the refresh is single-flighted per connection (a lock / `SELECT … FOR UPDATE` / mutex) so concurrent callers don't each burn a refresh and race the rotation. The new token + new `expires_at` (+ rotated refresh token, if the vendor rotates) are persisted in one transaction.
- **Per-tenant credential isolation**: the connection used for a request is resolved FROM the auth context's `tenant_id` — never a client-supplied connection id. Tenant A's job can never load tenant B's vendor connection. The lookup predicate is the boundary.
- **All outbound calls through one client wrapper**: no feature code calls `fetch(vendorUrl)` directly. A `<VendorClient>` wraps every call with: a timeout, retry-with-exponential-backoff + full jitter on transient failures (`429`, `5xx`, network), `Retry-After` / rate-limit-header respect, a circuit breaker per vendor (+ per tenant where the vendor rate-limits per account), and structured (secret-safe) logging.
- **Honor the vendor's rate limits**: respect `Retry-After` and the vendor's `X-RateLimit-Remaining` / `-Reset` headers; throttle proactively (token-bucket / leaky-bucket per vendor+tenant) rather than discovering the limit by getting `429`-stormed. Retries on a `429` wait at least `Retry-After`.
- **Retry only idempotent operations**: `GET` / `PUT`-by-id / upserts are retried; a non-idempotent `POST` that creates a resource is retried ONLY with an idempotency key the vendor supports — otherwise a retry double-creates. Reads vs. unsafe writes are classified, not retried blindly.
- **Circuit breaker per dependency**: each vendor has a breaker (closed → open on an error-rate/consecutive-failure threshold → half-open probe). When open, calls fail fast with a typed `VendorUnavailable` and the caller degrades gracefully — a vendor outage MUST NOT exhaust your threads/connections or take your app down with it.
- **Idempotent sync writes**: every write derived from vendor data upserts on the vendor's stable external id (`UNIQUE (tenant_id, provider, external_id)`), so a redelivered webhook or a retried sync updates-in-place instead of duplicating. Process-once semantics for events (dedupe on the vendor's event id).
- **Reconciliation / drift detection**: incremental updates (webhooks / cursors) are backstopped by a periodic full or windowed reconciliation that compares your state to the vendor's and repairs drift; missed/dropped webhooks are detected and healed. A "data as of <ts>" / `last_synced_at` per connection makes staleness visible.
- **Validate inbound vendor data at the boundary**: every inbound payload (webhook body, API response) is parsed + schema-validated into a typed shape at the edge BEFORE it reaches the domain; unknown/extra fields are not blindly persisted; types/enums/ranges are checked. Vendor data is untrusted input.
- **Verify inbound webhook signatures**: every inbound webhook is signature-verified (HMAC / vendor signature header) against the shared secret with a constant-time compare + timestamp/nonce replay guard, BEFORE the body is parsed or acted on (see `<rules-path>/webhook`).
- **Do vendor I/O async, off the request path**: a user request enqueues a job and returns; the synchronous vendor round-trip happens in a worker (see `<rules-path>/background-jobs`). The user never waits on (or fails because of) a vendor's latency.
- **Secret-safe logging**: tokens, API keys, signing secrets, full auth headers, and PII in vendor payloads are redacted from logs / errors / traces. Log the connection id + provider + correlation id, never the credential.

## Must not

- Store an OAuth/access/refresh token or API key in plaintext (a `varchar` token column, a `.env`-committed key, a token in a JWT claim you log).
- Share one credential / connection across tenants, or resolve the connection from a client-supplied id instead of the auth context — cross-tenant access.
- Never refresh a token (let it expire and 401-loop), or refresh it non-atomically so concurrent callers race and one wins a stale rotation.
- Call a vendor with a bare `fetch` / SDK call that has no timeout, no retry/backoff, no `Retry-After` respect, and no circuit breaker.
- Retry a non-idempotent create on `5xx`/timeout with no idempotency key — it double-creates on the vendor side.
- Ignore `429` / `Retry-After` and hammer the vendor (retry-storm) — you get rate-limited harder or banned.
- Write vendor data with an `INSERT` keyed on your own surrogate id instead of an upsert on the vendor's external id — redelivery duplicates rows.
- Run a webhook-only pipeline with no reconciliation — dropped webhooks silently diverge your state from the vendor's forever.
- Trust a vendor payload unvalidated (`JSON.parse` straight into your domain / DB) — malformed or hostile data corrupts your store or injects.
- Act on a webhook before verifying its signature — anyone who guesses the URL can forge events.
- Block the user's request on a synchronous vendor call — the vendor's latency/outage becomes the user's.
- Log a token / key / signing secret / full `Authorization` header / raw vendor payload with PII.

## Should

- Wrap each vendor behind a project-internal `<VendorClient>` / connector interface so token resolution+refresh, retry/backoff, rate-limiting, the breaker, and secret-safe logging are enforced in ONE place — feature code calls `client.getOrders()`, never raw HTTP.
- Model the connection lifecycle explicitly (`pending` → `connected` → `needs_reauth` → `revoked`); surface `needs_reauth` to the tenant instead of silently failing when a refresh token is revoked.
- Make outbound calls observable: structured `{ provider, tenantId, connectionId, op, attempt, status, latencyMs, breakerState, rateLimitRemaining }` per call; alert on breaker-open, rising `429` rate, refresh failures, and reconciliation drift counts.
- Persist a per-connection sync cursor / `last_synced_at` and a reconciliation report (added / updated / removed / repaired counts) so divergence is measurable, not guessed.
- Dead-letter vendor events that fail validation or processing after retries (see `<rules-path>/background-jobs`) instead of dropping or infinite-retrying them.
- Rate-limit your OWN inbound webhook + sync endpoints per tenant/connection (see `<rules-path>/rate-limit`) so one noisy vendor connection can't exhaust your workers.
- Audit credential lifecycle events — connect, refresh, reauth, revoke, and admin views of a connection — to the audit log (see `<rules-path>/audit-log`).

## Review checklist (PRs touching connectors / OAuth-to-vendor / external sync / webhooks)

- [ ] Tokens/keys are encrypted-at-rest (ciphertext column / secrets manager), keyed per tenant — cite the storage + the encrypt/decrypt at `<path:line>`; no plaintext token column.
- [ ] Access token is refreshed before expiry, single-flighted, and persisted atomically (new token + `expires_at` + rotated refresh) — cite the refresh path at `<path:line>`.
- [ ] The vendor connection is resolved from the auth-context `tenant_id`, never a client-supplied id — cite the lookup at `<path:line>`.
- [ ] Every outbound vendor call goes through the client wrapper (timeout + retry/backoff + jitter + `Retry-After` + breaker) — no bare `fetch(vendor)` in feature code.
- [ ] Retries are on `429`/`5xx`/network with exponential backoff + jitter, and wait at least `Retry-After`; non-idempotent creates carry an idempotency key.
- [ ] A circuit breaker exists per vendor; open-state fails fast with a typed error and graceful degradation — cite at `<path:line>`.
- [ ] Sync writes upsert on the vendor's external id (`UNIQUE (tenant_id, provider, external_id)`); events are deduped on the vendor event id — cite the upsert at `<path:line>`.
- [ ] A reconciliation / drift job exists (full or windowed) backstopping the incremental path; `last_synced_at` is recorded — cite at `<path:line>`.
- [ ] Inbound vendor payloads are schema-validated at the boundary before touching the domain — cite the parse/validate at `<path:line>`.
- [ ] Inbound webhooks are signature-verified (constant-time) with a replay guard before processing — cite at `<path:line>`.
- [ ] No vendor call blocks the user request path; the round-trip is in a background job — cite the enqueue at `<path:line>`.
- [ ] No token / key / signing secret / full auth header / raw PII payload reaches logs/errors/traces.

## Anti-patterns

- **Plaintext token column** — `oauth_token VARCHAR` storing the raw access + refresh token -> one DB dump / log line / backup leak hands an attacker live vendor access for every tenant. Encrypt at rest; decrypt only in memory at use.
- **Shared / mis-scoped connection** — the connection is looked up by `req.body.connectionId` -> tenant A passes tenant B's id and reads B's vendor data. Resolve from the auth context's tenant id.
- **Never-refreshed token** — the access token expires, every call `401`s, the integration "just stops working" with no signal. Refresh proactively before `expires_at`; mark `needs_reauth` when the refresh token is revoked.
- **Refresh stampede** — 50 concurrent jobs each see the token expired and each fire a refresh -> the vendor rotates the refresh token 50 times -> 49 now hold a dead refresh token. Single-flight the refresh per connection.
- **Bare vendor fetch** — `await fetch(vendorUrl)` in a service, no timeout, no retry, no breaker -> the vendor hangs for 30s -> every request thread waiting on it piles up -> your app falls over. Route through the client wrapper.
- **Retry storm on 429** — a `429` triggers an immediate retry which triggers another `429` -> you bombard a vendor that's asking you to slow down -> harder throttle / ban. Wait at least `Retry-After`; back off with jitter.
- **Double-create on retry** — a timeout on a non-idempotent `POST /charges` is retried -> two charges. Retry only with the vendor's idempotency key, or don't retry the create.
- **No circuit breaker** — the vendor is down; every call burns its full timeout and a connection; the pool drains; healthy requests starve. A breaker fails fast and isolates the bad dependency.
- **Insert-not-upsert sync** — a redelivered webhook `INSERT`s a row already created by the first delivery -> duplicate orders / contacts / line items. Upsert on `(tenant_id, provider, external_id)`.
- **Webhook-only, no reconciliation** — the vendor drops a webhook during a deploy -> that record never syncs -> your state silently diverges and no one notices until a customer complains. Backstop with a periodic reconciliation.
- **Unvalidated vendor payload** — `const data = await res.json(); await repo.save(data)` -> a renamed field / null / hostile string lands straight in your DB. Parse + validate at the boundary.
- **Unverified webhook** — acting on a `POST /webhooks/vendor` with no signature check -> anyone who learns the URL forges events (fake "payment succeeded"). Signature-verify before parsing (see `<rules-path>/webhook`).
- **Synchronous vendor call on the request path** — `POST /contacts` calls the CRM inline and returns when the CRM returns -> the CRM's p99 latency is now your p99, and its outage is your outage. Enqueue; return; sync in a worker.
- **Secret in logs** — `logger.info('calling vendor', { headers })` logs the full `Authorization: Bearer …` -> the token is now in your log aggregator forever. Redact secrets before logging.

## Enforcement

- `<commands-path>/audit-integration.md` (slash: `/audit-integration`) — per-integration cite-or-halt diagnostic of token storage (encrypted? refreshed? per-tenant?), retry/backoff on `429`/`5xx`, circuit breaker, sync-write idempotency, reconciliation/drift, inbound validation, secrets-in-logs, and blocking-on-vendor on the request path — real code at `<path:line>` or HALT, never an assumed connector shape.
- `<agents-path>/integrations-reviewer.md` — review gate hard-failing on plaintext/unrefreshed/mis-scoped tokens, bare vendor fetches, missing retry/backoff/`Retry-After`, missing circuit breaker, non-idempotent sync writes, no reconciliation, unvalidated/unverified inbound payloads, secrets in logs, and synchronous vendor calls on the request path.
- CI lint MUST reject a direct `fetch(`/SDK call to a known vendor host outside the `<VendorClient>` wrapper (heuristic; flag for review).
- CI lint MUST reject a token/key column whose type is plaintext (not the project's encrypted/ciphertext type) in any connection/credential model (AST/schema heuristic; flag for review).
- CI lint MUST reject a sync write that `INSERT`s vendor data without an `ON CONFLICT` / upsert on the external-id unique key (heuristic; flag for review).
- CI MUST assert every inbound webhook route is wrapped by the signature-verification middleware before its handler.
- TODO: `scripts/validate-integration-discipline.sh` to AST-walk connectors and assert each vendor has a client wrapper (retry+backoff+breaker), each credential model uses the encrypted type keyed per tenant, and each sync write upserts on the external id.

## Cross-references

- `<patterns-path>/third-party-integration.md` — encrypted token store + atomic refresh + retry/backoff/jitter client + circuit breaker + idempotent upsert + drift reconciliation + inbound validation + secret-safe logging code shapes.
- `<rules-path>/webhook` — inbound vendor events: signature verification, replay guard, fast-ack + async processing.
- `<rules-path>/background-jobs` — async sync semantics: enqueue off the request path, idempotency, resumability, DLQ for poison vendor events.
- `<rules-path>/rate-limit` — throttle your own inbound webhook/sync endpoints per tenant/connection, and the token-bucket for outbound vendor calls.
- `<rules-path>/audit-log` — credential lifecycle (connect / refresh / reauth / revoke) is an audited event.
- `<patterns-path>/report-generation.md` — the async-job + signed-delivery spine reused when an integration exports/imports bulk vendor data.
- `<adr-path>/<NNN>-integration-credential-store.md` — ADR pinning the credential store (KMS / secrets manager / encrypted column) + the refresh + reconciliation contract per vendor.
