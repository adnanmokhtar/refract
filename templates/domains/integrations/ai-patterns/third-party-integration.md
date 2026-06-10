---
name: third-party-integration
description: "Pattern: Third-party integration (token-vaulted, rate-aware, retried, drift-reconciled)"
kind: ai-pattern
---

# Pattern: Third-party integration (token-vaulted, rate-aware, retried, drift-reconciled)

> **Hard rule** — Vendor credentials are stored ENCRYPTED-AT-REST and scoped PER TENANT, refreshed proactively + atomically; every outbound call goes through a client wrapper that retries idempotent failures with EXPONENTIAL BACKOFF + JITTER, honors `429`/`Retry-After`, and sits behind a CIRCUIT BREAKER; sync writes are IDEMPOTENT (upsert on the vendor's external id); the incremental path is backstopped by periodic DRIFT RECONCILIATION; inbound vendor payloads are VALIDATED at the boundary and webhooks are SIGNATURE-VERIFIED; vendor I/O runs ASYNC off the request path; secrets NEVER reach logs.

**When to apply**
- Any OAuth-to-vendor or API-key connector (CRM, payments, calendar, email, accounting, storage, shipping) where you hold a tenant's credential and call out on their behalf.
- Any sync that mirrors a vendor's data into your store (contacts, orders, invoices, events) via webhooks and/or polling.
- Multi-tenant products where each tenant connects their OWN vendor account and one tenant's data must never cross to another.

**When NOT to apply**
- A single static, server-owned API key for a stateless utility call (a geocoder, a one-shot enrichment) with no per-tenant credential and no mirrored state — the vault + reconciliation machinery is overhead; you still want the retry/backoff wrapper.
- A pure pass-through where you never persist vendor data (no sync, no reconciliation needed) — keep the client wrapper + breaker, drop the upsert/reconcile layers.
- An inbound-only webhook with no outbound calls — you still need signature verification + idempotent processing, but not the token store.

**Halt conditions / mandatory cites**
- Cite the encrypted credential store + the encrypt/decrypt-at-use + the per-tenant key at `<path:line>`. A plaintext token column = halt.
- Cite the token refresh path — proactive, single-flighted, persisted atomically — at `<path:line>`. No refresh / a non-atomic refresh = halt.
- Cite the outbound client wrapper: timeout + retry/backoff/jitter + `Retry-After` respect + circuit breaker at `<path:line>`. A bare `fetch(vendor)` in feature code = halt.
- Cite the idempotent sync write (upsert on the external id) + the event dedupe at `<path:line>`. An `INSERT` on a surrogate id = halt.
- Cite the reconciliation / drift job at `<path:line>`. A webhook-only pipeline with no reconciliation = halt.
- Cite the inbound payload validation + the webhook signature verification at `<path:line>` each.
- Cite the enqueue that moves the vendor round-trip off the request path at `<path:line>`.
- Grep ban: "the integration is secure/resilient/idempotent" without file:line for the encrypted store, the refresh, the breaker, the upsert, the reconciliation, and the signature check.

## Why

A third-party integration is the place where four hard problems converge at once: you hold someone else's secret, you depend on a system you don't control, you mirror state that can drift, and you accept input you didn't author. The recurring failure modes:

1. **The credential leaks or crosses tenants** — a plaintext token column, a token in a log line, or a connection resolved from client input hands an attacker (or tenant A) live access to a vendor account. The credential is encrypted at rest, decrypted only in memory at use, and resolved strictly from the auth context's tenant.
2. **The vendor takes you down with it** — a bare call with no timeout / retry / breaker means the vendor's hang becomes your thread exhaustion, and its `429` storm becomes your ban. Every call goes through a wrapper that retries with backoff+jitter, honors `Retry-After`, and trips a breaker so a bad dependency fails fast.
3. **Redelivery corrupts your data** — webhooks and retries redeliver, so a non-idempotent `INSERT` duplicates. Sync writes upsert on the vendor's external id; events dedupe on the vendor's event id.
4. **Your mirror silently diverges** — a dropped webhook during a deploy means a record never syncs and no one notices. The incremental path is backstopped by a periodic reconciliation that compares + repairs.
5. **You trust hostile input** — a vendor payload parsed straight into the domain, or a webhook acted on without a signature, lets malformed or forged data into your store. Validate at the boundary; verify the signature first.

The pattern: VAULT the credential, REFRESH it atomically, WRAP every call (retry+breaker), UPSERT idempotently, RECONCILE drift, VALIDATE + VERIFY inbound, and do it all ASYNC.

> The TypeScript below uses NestJS-style DI + a Postgres/`pg` idiom for illustration. Substitute your project's real shapes from `.claude/_extracted-codebase.md`: the HTTP client, the KMS/secrets-manager SDK, the queue, the ORM/upsert syntax, the breaker library. The SHAPE — vault → refresh → wrapped-call → upsert → reconcile → validate → async — is universal, not the helper names.

## Encrypted, per-tenant credential store (vault) with atomic refresh

```ts
// src/modules/integrations/core/credential-store.ts

/** Stored row: the token columns are CIPHERTEXT, never plaintext. Keyed per tenant + provider. */
interface ConnectionRow {
  id: string;
  tenant_id: string;                 // the isolation boundary
  provider: string;                  // 'salesforce' | 'stripe' | 'google_calendar'
  access_token_enc: Buffer;          // envelope-encrypted ciphertext
  refresh_token_enc: Buffer | null;
  expires_at: Date;
  status: 'connected' | 'needs_reauth' | 'revoked';
  external_account_id: string;
}

export class CredentialStore {
  constructor(
    private readonly db: Db,
    private readonly kms: Kms,              // envelope encryption (KMS data key)
    private readonly clock: Clock,
    private readonly oauth: OAuthClient,
  ) {}

  /** Resolve the connection for THIS tenant — from the auth context, never client input. */
  async forTenant(tenantId: string, provider: string): Promise<DecryptedConnection> {
    const row = await this.db.one<ConnectionRow>(
      `SELECT * FROM integration_connections
        WHERE tenant_id = $1 AND provider = $2 AND status = 'connected'`,
      [tenantId, provider],            // tenant_id from ctx — the cross-tenant boundary
    );
    if (!row) throw new ConnectionNotFound(provider);

    const valid = await this.ensureFresh(row);   // refresh-if-near-expiry, single-flighted
    return {
      connectionId: valid.id,
      tenantId: valid.tenant_id,
      provider: valid.provider,
      // Decrypt ONLY here, in memory, at the moment of use. Never logged, never returned wholesale.
      accessToken: await this.kms.decrypt(valid.access_token_enc),
    };
  }

  /** Proactive, single-flighted, atomic refresh. */
  private async ensureFresh(row: ConnectionRow): Promise<ConnectionRow> {
    const skewMs = 60_000;           // refresh a minute before the vendor expires it
    if (row.expires_at.getTime() - this.clock.now() > skewMs) return row;

    // Single-flight per connection: lock the row so 50 concurrent jobs do ONE refresh, not 50.
    return this.db.tx(async (tx) => {
      const locked = await tx.one<ConnectionRow>(
        `SELECT * FROM integration_connections WHERE id = $1 FOR UPDATE`, [row.id],
      );
      if (locked.expires_at.getTime() - this.clock.now() > skewMs) return locked;  // someone refreshed

      const refreshToken = await this.kms.decrypt(locked.refresh_token_enc!);
      let fresh: OAuthTokens;
      try {
        fresh = await this.oauth.refresh(locked.provider, refreshToken);
      } catch (e) {
        if (e instanceof OAuthInvalidGrant) {
          // The refresh token was revoked by the tenant on the vendor side. Surface, don't loop.
          await tx.exec(`UPDATE integration_connections SET status='needs_reauth' WHERE id=$1`, [locked.id]);
          throw new NeedsReauth(locked.provider);
        }
        throw e;
      }

      // Persist new token + new expiry + ROTATED refresh token (if the vendor rotates) in ONE tx.
      const updated = await tx.one<ConnectionRow>(
        `UPDATE integration_connections
            SET access_token_enc  = $2,
                refresh_token_enc = COALESCE($3, refresh_token_enc),
                expires_at        = $4
          WHERE id = $1 RETURNING *`,
        [locked.id,
         await this.kms.encrypt(fresh.accessToken),
         fresh.refreshToken ? await this.kms.encrypt(fresh.refreshToken) : null,
         new Date(this.clock.now() + fresh.expiresInSec * 1000)],
      );
      return updated;
    });
  }
}
```

The token is ciphertext at rest, decrypted only in memory at use, scoped by `tenant_id` from the auth context. The refresh is single-flighted (`FOR UPDATE`) so a stampede does one rotation, and the new token + rotated refresh + expiry land in one transaction. A revoked grant flips to `needs_reauth` instead of 401-looping forever.

## Outbound client wrapper: timeout + retry/backoff/jitter + `Retry-After` + breaker

```ts
// src/modules/integrations/core/vendor-client.ts

export class VendorClient {
  constructor(
    private readonly creds: CredentialStore,
    private readonly breakers: BreakerRegistry,    // one breaker per provider (+ per tenant where vendor caps per-account)
    private readonly limiter: TokenBucket,         // proactive throttle per provider+tenant
    private readonly log: Logger,
  ) {}

  /** Every outbound vendor call goes through here. No feature code calls fetch(vendor) directly. */
  async call<T>(ctx: { tenantId: string; provider: string }, op: VendorOp<T>): Promise<T> {
    const breaker = this.breakers.for(`${ctx.provider}:${ctx.tenantId}`);
    if (breaker.state === 'open') throw new VendorUnavailable(ctx.provider);   // fail fast, don't hang

    await this.limiter.take(`${ctx.provider}:${ctx.tenantId}`);                // honor our own quota first
    const conn = await this.creds.forTenant(ctx.tenantId, ctx.provider);       // fresh token

    const maxAttempts = op.idempotent ? 5 : 1;   // ONLY retry idempotent ops (or POST w/ an idempotency key)
    let attempt = 0;
    while (true) {
      attempt++;
      try {
        const res = await this.withTimeout(op.send(conn.accessToken, op.idempotencyKey), op.timeoutMs ?? 10_000);
        breaker.onSuccess();
        // Secret-safe: log the op + status + breaker state, NEVER the token or full headers.
        this.log.info('vendor.call', {
          provider: ctx.provider, connectionId: conn.connectionId, op: op.name,
          attempt, status: res.status, latencyMs: res.latencyMs,
          breaker: breaker.state, rateLimitRemaining: res.headers['x-ratelimit-remaining'],
        });
        return op.parse(res);          // boundary validation lives in op.parse (see below)
      } catch (e) {
        const retryable = isRetryable(e);     // 429 | 5xx | network/timeout
        breaker.onFailure();                  // counts toward tripping the breaker open
        if (!retryable || attempt >= maxAttempts) throw normalize(e, ctx.provider);

        // Honor Retry-After if present; otherwise exponential backoff with FULL JITTER.
        const retryAfterMs = retryAfter(e);
        const backoff = retryAfterMs ?? Math.min(30_000, 2 ** attempt * 250);
        const jittered = retryAfterMs ?? Math.random() * backoff;   // full jitter avoids synchronized retries
        await sleep(Math.max(retryAfterMs ?? 0, jittered));
      }
    }
  }

  private withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
    return Promise.race([p, sleep(ms).then(() => { throw new VendorTimeout(); })]);
  }
}

function isRetryable(e: unknown): boolean {
  return e instanceof VendorTimeout
    || (e instanceof VendorHttpError && (e.status === 429 || e.status >= 500));
}

function retryAfter(e: unknown): number | undefined {
  if (e instanceof VendorHttpError && e.headers['retry-after']) {
    const v = e.headers['retry-after'];
    const secs = Number(v);                          // delta-seconds or an HTTP-date
    return Number.isFinite(secs) ? secs * 1000 : Math.max(0, Date.parse(v) - Date.now());
  }
  return undefined;
}
```

A vendor blip can't take you down: the call has a timeout, retries only when idempotent, waits at least `Retry-After`, backs off with full jitter (no synchronized retry herd), and trips a breaker that fails fast on a sustained outage. The token is never logged — only the op + status + breaker state.

## Circuit breaker

```ts
// src/modules/integrations/core/circuit-breaker.ts

type BreakerState = 'closed' | 'open' | 'half_open';

export class CircuitBreaker {
  private state: BreakerState = 'closed';
  private failures = 0;
  private openedAt = 0;

  constructor(private readonly threshold = 5, private readonly cooldownMs = 30_000, private readonly clock: Clock) {}

  get current(): BreakerState {
    if (this.state === 'open' && this.clock.now() - this.openedAt >= this.cooldownMs) {
      this.state = 'half_open';        // let ONE probe through after cooldown
    }
    return this.state;
  }

  onSuccess() { this.failures = 0; this.state = 'closed'; }

  onFailure() {
    this.failures++;
    if (this.failures >= this.threshold) { this.state = 'open'; this.openedAt = this.clock.now(); }
  }
}
```

Closed → trips open after N consecutive failures → after a cooldown lets one half-open probe through → success closes it, failure re-opens. While open, callers get `VendorUnavailable` immediately instead of each burning a full timeout and a connection.

## Idempotent sync write: upsert on the vendor's external id

```ts
// src/modules/integrations/sync/upsert-contact.ts

/** Webhooks + retries redeliver. The write MUST be idempotent: upsert on the vendor's stable id. */
async function upsertContact(db: Db, tenantId: string, provider: string, vc: ValidatedVendorContact) {
  await db.exec(
    `INSERT INTO contacts (tenant_id, provider, external_id, email, name, updated_at, source_updated_at)
     VALUES ($1, $2, $3, $4, $5, now(), $6)
     ON CONFLICT (tenant_id, provider, external_id) DO UPDATE
        SET email             = EXCLUDED.email,
            name              = EXCLUDED.name,
            updated_at        = now(),
            source_updated_at = EXCLUDED.source_updated_at
      WHERE contacts.source_updated_at < EXCLUDED.source_updated_at`,  // last-writer-wins by vendor timestamp
    [tenantId, provider, vc.externalId, vc.email, vc.name, vc.updatedAt],
  );
}

/** Process-once: dedupe on the vendor's event id so a redelivered webhook is a no-op. */
async function processOnce(db: Db, tenantId: string, eventId: string, fn: () => Promise<void>): Promise<void> {
  const inserted = await db.one<{ ok: boolean }>(
    `INSERT INTO processed_vendor_events (tenant_id, event_id) VALUES ($1, $2)
     ON CONFLICT (tenant_id, event_id) DO NOTHING RETURNING true AS ok`,
    [tenantId, eventId],
  );
  if (!inserted) return;             // already processed — redelivery is a safe no-op
  await fn();
}
```

`UNIQUE (tenant_id, provider, external_id)` makes redelivery update-in-place, never duplicate; the `source_updated_at` guard drops stale out-of-order updates; the event-id dedupe makes processing exactly-once.

## Drift reconciliation: incremental backstopped by periodic full-sync

```ts
// src/modules/integrations/sync/reconcile.ts

/** Webhooks drift (dropped during deploys, missed events). A periodic reconcile compares + repairs. */
@Cron('17 * * * *')   // hourly, offset to avoid the top-of-hour herd
async function reconcileContacts(deps: SyncDeps, tenantId: string, provider: string): Promise<ReconcileReport> {
  const report = { added: 0, updated: 0, removed: 0, scanned: 0 };

  // Pull the vendor's current truth for a window (or full set), paginated through the wrapped client.
  const since = await deps.cursors.get(tenantId, provider);       // last reconciled high-watermark
  for await (const page of deps.client.paginate({ tenantId, provider }, listContactsSince(since))) {
    for (const raw of page.items) {
      const vc = ValidatedVendorContact.parse(raw);               // boundary validation, always
      const before = await deps.repo.find(tenantId, provider, vc.externalId);
      await upsertContact(deps.db, tenantId, provider, vc);
      before ? report.updated++ : report.added++;
      report.scanned++;
    }
  }

  // Detect deletions: rows we have that the vendor no longer reports in the window are stale.
  const stale = await deps.repo.notSeenSince(tenantId, provider, report.scanStartedAt);
  report.removed = await deps.repo.softDelete(stale);

  await deps.cursors.set(tenantId, provider, report.scanStartedAt);   // advance the watermark
  await deps.repo.markSynced(tenantId, provider, new Date());         // last_synced_at — staleness is visible
  deps.metrics.gauge('integration.reconcile.drift', report.added + report.removed, { provider });
  return report;
}
```

The webhook path is fast but lossy; the reconcile job is the source of truth that heals it — repairing adds/updates and detecting vendor-side deletions, while `last_synced_at` + a drift metric make divergence measurable instead of invisible.

## Inbound boundary: signature-verify, then validate

```ts
// src/modules/integrations/inbound/webhook.controller.ts

@Post('/webhooks/:provider')
async receive(@Param('provider') provider: string, @Req() req: RawRequest): Promise<{ ack: true }> {
  // 1) VERIFY THE SIGNATURE on the raw body BEFORE parsing or acting (see <rules-path>/webhook).
  const secret = await this.creds.webhookSecret(provider);        // per-provider signing secret, from the vault
  if (!verifyHmac(req.rawBody, req.headers['x-vendor-signature'], secret)) {  // constant-time compare
    throw new UnauthorizedWebhook(provider);                      // forged event — reject before any work
  }
  if (this.replay.seen(req.headers['x-vendor-delivery-id'], req.headers['x-vendor-timestamp'])) {
    return { ack: true };                                         // replay guard — idempotent ack
  }

  // 2) VALIDATE the payload into a typed shape at the boundary — vendor data is UNTRUSTED.
  const event = VendorWebhookEvent.parse(JSON.parse(req.rawBody.toString()));  // throws on shape/enum/range violation

  // 3) ACK fast, process ASYNC off the request path (see <rules-path>/background-jobs).
  await this.queue.add('sync-vendor-event', {
    tenantId: event.tenantId, provider, eventId: event.id, payload: event,
  });
  return { ack: true };           // the vendor wants a quick 2xx; the real work happens in a worker
}
```

```ts
// src/modules/integrations/inbound/schema.ts
// The validator IS the boundary. Unknown fields are not blindly persisted; types/enums/ranges are checked.
const ValidatedVendorContact = z.object({
  externalId: z.string().min(1),
  email: z.string().email().nullable(),
  name: z.string().max(500),
  updatedAt: z.coerce.date(),
}).strict();                       // .strict() rejects unexpected fields — no silent passthrough
```

Verify the signature on the raw bytes first (forged events never reach your logic), guard replays, validate the payload into a typed shape, ack fast, and do the actual sync in a worker — the vendor's webhook latency budget is never your domain's.

## Secret-safe logging

```ts
// src/modules/integrations/core/redact.ts
// Tokens, keys, signing secrets, full auth headers, and PII NEVER reach logs/errors/traces.
const SECRET_KEYS = /token|secret|authorization|api[_-]?key|password|refresh/i;

export function redact(o: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(o).map(([k, v]) => [k, SECRET_KEYS.test(k) ? '[redacted]' : v]),
  );
}
// Log { provider, connectionId, op, status, breakerState } — never the credential or the raw payload.
```

## Common mistakes

### Plaintext token column
`access_token VARCHAR` stores the raw token → one DB dump / log line / backup leak hands an attacker live vendor access for every tenant. Encrypt at rest (envelope/KMS); decrypt only in memory at use.

### Connection resolved from client input
`creds.forConnection(req.body.connectionId)` → tenant A passes tenant B's id and reads B's vendor data. Resolve strictly from the auth context's `tenant_id`.

### Never-refreshed / stampeding refresh
The token expires and every call 401-loops; or 50 jobs each fire a refresh and rotate the refresh token 50 times. Refresh proactively before expiry, single-flighted with `FOR UPDATE`.

### Bare vendor fetch
`await fetch(vendorUrl)` with no timeout/retry/breaker → the vendor hangs → request threads pile up → your app falls over. Route every call through the wrapper.

### Retry storm on 429 / double-create on retry
Immediately retrying a `429` bombards a vendor asking you to slow down; retrying a non-idempotent `POST` double-creates. Wait at least `Retry-After`; retry only idempotent ops (or carry the vendor's idempotency key).

### Insert-not-upsert
A redelivered webhook `INSERT`s a row the first delivery already created → duplicate orders/contacts. Upsert on `(tenant_id, provider, external_id)`; dedupe events on the vendor event id.

### Webhook-only, no reconciliation
A dropped webhook during a deploy means a record never syncs and no one notices. Backstop the incremental path with a periodic reconcile that compares + repairs and records `last_synced_at`.

### Unvalidated / unverified inbound
`JSON.parse` straight into the domain, or acting on a webhook with no signature check → corrupted store / forged events. Verify the signature on raw bytes first; validate into a typed shape at the boundary.

### Synchronous vendor call on the request path
`POST /contacts` calls the CRM inline → the CRM's p99 is now yours and its outage is yours. Enqueue; return; sync in a worker.

### Secret in logs
`logger.info('call', { headers })` logs the full `Authorization: Bearer …`. Redact secrets before logging; log the connection id, not the credential.

## Cross-references

- `<rules-path>/integrations-sync-discipline.md` — the hard-rule list this pattern implements (vault, refresh, wrapper, idempotency, reconciliation, validation, async, redaction).
- `<rules-path>/webhook` — inbound vendor events: signature verification, replay guard, fast-ack + async processing.
- `<rules-path>/background-jobs` — async sync semantics (enqueue off the request path, idempotency, resumability, DLQ for poison vendor events).
- `<rules-path>/rate-limit` — token-bucket for outbound vendor calls + throttling your own inbound webhook/sync endpoints per tenant/connection.
- `<rules-path>/audit-log` — credential lifecycle (connect / refresh / reauth / revoke) is an audited event.
- `<patterns-path>/report-generation.md` — the async-job + signed-delivery spine reused for bulk vendor import/export.
- `<commands-path>/audit-integration.md` — per-integration cite-or-halt diagnostic.
- `<agents-path>/integrations-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-integration-credential-store.md` — ADR pinning the credential store + the refresh + reconciliation contract per vendor.
