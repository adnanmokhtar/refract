---
name: audit-trail
description: "Pattern: Audit trail (append-only, tamper-evident activity log)"
kind: ai-pattern
---

# Pattern: Audit trail (append-only, tamper-evident activity log)

> **Hard rule** — Audit rows are append-only and immutable (no `UPDATE`/`DELETE`, enforced at the DB grant level); every entry carries actor + action + target + UTC timestamp + monotonic seq + correlation id + source IP/UA + tenant + outcome; the entry is hash-chained (`row_hash = H(prev_hash ‖ canonical(row))`) so gaps/reordering are detectable; the write is atomic-with or guaranteed-after the business change (same txn or outbox) — NEVER fire-and-forget that can drop; secrets / full PANs / passwords / tokens are NEVER written; read access is itself audited.

**When to apply**
- Any system with security/compliance obligations: who-did-what-to-what must be reconstructable after a breach, dispute, or regulator request.
- Sensitive actions exist: authentication, permission changes, data export, admin override / impersonation, deletion.
- Multi-tenant or regulated (SOC2 / HIPAA / GDPR / PCI) products where retention + tamper-evidence + restricted access are required.

**When NOT to apply**
- Debugging / operational logging — use the application logger (ephemeral, sampled, rotated). The audit log is NOT a debug log and the debug log is NOT an audit log.
- Domain events for read-model projection / integration (CQRS event store) — overlapping shape, different purpose; the audit log is a security record, not a rebuild source. They MAY share a transactional-outbox mechanism but are distinct streams.
- Pure analytics / product telemetry — different retention, different access model, mutable by design.

**Halt conditions / mandatory cites**
- Cite the audit table migration showing `UPDATE`/`DELETE` grants REVOKED (or a blocking trigger / WORM store) at `<path:line>`. A mutable audit table = halt.
- Cite the `<AuditLog>` interface + its single `record(event)` implementation at `<path:line>`. Raw `INSERT INTO audit_log` scattered across feature code = halt.
- Cite the hash-chain construction (`prev_hash` read + `row_hash` compute over canonical serialization) at `<path:line>`. No integrity primitive = halt.
- Cite the capture path proving atomicity — same transaction as the business change, OR a transactional-outbox insert — at `<path:line>`. Fire-and-forget emit = halt.
- Cite the redaction step at `<path:line>`. Unredacted payload reaching persistence = halt.
- Grep ban: "it's audited" / "we log everything" without file:line for the append-only constraint, the integrity chain, the atomic capture, and the redaction step.

## Why

The audit log is the record of last resort. Every other source — app logs, metrics, the row itself — is mutable, sampled, or already overwritten by the time you need it. So the audit log earns its trust through four properties the others lack:

1. **Append-only + immutable** — if a row can be edited or deleted, the log proves nothing; an insider erases their own tracks.
2. **Tamper-evident** — even with append-only grants, you must DETECT deletion/reordering. A hash chain (or anchored sequence) makes any gap visible.
3. **Reliably captured** — an entry that can be silently dropped is missing exactly when load spikes or a broker blips. The write must be bound to the business change.
4. **Forensically sufficient but minimized** — enough fields to reconstruct the event; no secrets/PII that turn the log into a breach target.

Keep this distinct from three neighbors: **application logging** (debugging, ephemeral, for engineers), **domain events** (state-change stream for projections/integration), and **this** — the security/compliance trail, retained for years, read by investigators and regulators.

## The `<AuditLog>` interface

```ts
// src/modules/audit/core/interfaces/audit-log.interface.ts

export interface AuditLog {
  /** Persist one audit event. Append-only, hash-chained, redacted. Resolves only on durable commit. */
  record(event: AuditEvent): Promise<void>;

  /** Query for investigation / compliance. Read-only; emits an `audit.read` entry as a side effect. */
  query(filter: AuditQuery, by: Actor): Promise<AuditEntry[]>;
}

export type Actor = {
  userId: string;
  impersonatorId?: string;   // set when an admin is acting-as another user
  tenantId: string;
};

export type AuditEvent = {
  actor: Actor;
  action: AuditAction;                 // closed enum — see vocabulary below
  target: { type: string; id: string };
  diff?: { before?: Json; after?: Json };  // changed fields only, for mutations
  outcome: 'success' | 'denied' | 'error';
  context: {
    correlationId: string;             // request / trace id
    sourceIp: string;
    userAgent: string;
  };
  // occurred_at, seq, prev_hash, row_hash are assigned SERVER-SIDE at persistence — never from input.
};
```

Feature code calls `auditLog.record(...)` with intent. Timestamp, sequence, and hash are assigned by the implementation — never accepted from the caller, never from the request body.

## Action vocabulary (closed enum)

```ts
// src/modules/audit/core/audit-action.enum.ts

export enum AuditAction {
  // authentication
  AUTH_LOGIN          = 'auth.login',
  AUTH_LOGIN_FAILED   = 'auth.login.failed',
  AUTH_LOGOUT         = 'auth.logout',
  AUTH_MFA_CHANGED    = 'auth.mfa.changed',
  // authorization
  ROLE_GRANTED        = 'authz.role.granted',
  ROLE_REVOKED        = 'authz.role.revoked',
  PERMISSION_CHANGED  = 'authz.permission.changed',
  // privileged
  IMPERSONATION_START = 'admin.impersonation.start',
  IMPERSONATION_STOP  = 'admin.impersonation.stop',
  ADMIN_OVERRIDE      = 'admin.override',
  // data
  DATA_EXPORTED       = 'data.exported',
  RECORD_DELETED      = 'record.deleted',
  RECORD_ANONYMIZED   = 'record.anonymized',
  // the audit log auditing itself
  AUDIT_READ          = 'audit.read',
  AUDIT_EXPORTED      = 'audit.exported',
}
```

A closed enum means reports group reliably and a NEW sensitive action is a deliberate addition reviewed in a PR — not an ad-hoc string that slips coverage.

## Append-only schema + revoked grants

```sql
-- migrations/0001_audit_log.sql

CREATE TABLE audit_log (
  seq           BIGSERIAL PRIMARY KEY,        -- strictly monotonic, gap-free
  occurred_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  tenant_id     UUID         NOT NULL,
  actor_id      UUID         NOT NULL,
  impersonator_id UUID,
  action        TEXT         NOT NULL,        -- from the closed enum
  target_type   TEXT         NOT NULL,
  target_id     TEXT         NOT NULL,
  diff          JSONB,                        -- redacted, changed fields only
  outcome       TEXT         NOT NULL CHECK (outcome IN ('success','denied','error')),
  correlation_id TEXT        NOT NULL,
  source_ip     INET         NOT NULL,
  user_agent    TEXT         NOT NULL,
  hash_version  INT          NOT NULL,        -- which canonical-serialization the hash used
  prev_hash     BYTEA        NOT NULL,        -- row_hash of seq-1 (genesis = zero hash)
  row_hash      BYTEA        NOT NULL         -- H(prev_hash || canonical(this row))
);

-- investigation indexes — NO mutation path is created here
CREATE INDEX audit_by_target ON audit_log (tenant_id, target_type, target_id, occurred_at);
CREATE INDEX audit_by_actor  ON audit_log (actor_id, occurred_at);
-- partition by time in production (monthly), e.g. PARTITION BY RANGE (occurred_at)

-- IMMUTABILITY: the application role may only INSERT and SELECT.
REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM app_role;
GRANT  INSERT, SELECT            ON audit_log TO   app_role;

-- defense in depth: even a privileged role cannot mutate without lifting this trigger.
CREATE FUNCTION audit_no_mutate() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'audit_log is append-only (seq=%, action=%)', OLD.seq, OLD.action; END $$;
CREATE TRIGGER audit_immutable BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION audit_no_mutate();
```

Append-only is enforced at the GRANT level (the durable guarantee) AND a trigger (defense in depth). Business logic never depends on mutating a row — corrections are new rows referencing the prior `seq`.

## Hash-chain construction + canonical serialization

```ts
// src/modules/audit/infrastructure/hash-chain.ts

const HASH_VERSION = 1;

/** Stable, sorted, fixed-encoding serialization. The hash is only reproducible if this is deterministic. */
export function canonical(row: HashableRow): Buffer {
  // sort keys, fixed number formatting, UTC ISO timestamps, explicit nulls — NEVER JSON.stringify of an object
  // whose key order or number formatting can drift between runtimes.
  return Buffer.from(stableStringify(row), 'utf8');
}

export function rowHash(prevHash: Buffer, row: HashableRow): Buffer {
  return createHash('sha256').update(prevHash).update(canonical(row)).digest();
}

export const GENESIS = Buffer.alloc(32, 0);
```

Persisting `hash_version` alongside each row lets the verifier reproduce historical hashes EXACTLY even after the serialization format evolves — otherwise a format change silently breaks verification of old rows.

## Reliable capture (atomic with the business change)

> The TypeScript example below uses NestJS-style DI + a `runInTransaction` helper for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the transaction wrapper your ORM exposes (`prisma.$transaction`, `db.transaction`, `@Transactional`, a UoW), the DI mechanism, the repository names. The SHAPE — business write and audit write in ONE transaction, hash chained off the previous row, resolves only on commit — is what's universal, not the helper names.

```ts
// src/modules/audit/core/services/audit-log.service.ts

@Injectable()
export class AuditLogService implements AuditLog {
  constructor(
    @Inject(AUDIT_REPO) private repo: AuditRepository,
    private redactor: Redactor,
    private logger: Logger,
  ) {}

  /** Records WITHIN the caller's transaction so it commits/rolls back atomically with the business change. */
  async record(event: AuditEvent): Promise<void> {
    const safeDiff = event.diff ? this.redactor.scrub(event.diff) : undefined;   // strip secrets/PII first

    await this.repo.runInTransaction(async (tx) => {
      // SELECT ... FOR UPDATE on the chain head serializes appenders → gap-free seq + correct prev_hash.
      const head = await this.repo.lockChainHead(tx, event.actor.tenantId);
      const prevHash = head?.rowHash ?? GENESIS;

      const row = {
        tenantId: event.actor.tenantId,
        actorId: event.actor.userId,
        impersonatorId: event.actor.impersonatorId ?? null,
        action: event.action,
        targetType: event.target.type,
        targetId: event.target.id,
        diff: safeDiff ?? null,
        outcome: event.outcome,
        correlationId: event.context.correlationId,
        sourceIp: event.context.sourceIp,
        userAgent: event.context.userAgent,
        hashVersion: HASH_VERSION,
        occurredAt: new Date(),     // server-assigned, UTC
      };
      await this.repo.insert(tx, { ...row, prevHash, rowHash: rowHash(prevHash, row) });
    });
    // resolves ONLY after commit — never fire-and-forget.
  }
}
```

The audit `INSERT` joins the SAME transaction as the business mutation. If the business change rolls back, so does the audit row (no phantom). If the audit insert throws, the business change rolls back (no untraced change). Where the business change spans services and a shared transaction is impossible, use the outbox shape below.

## Transactional outbox (when a shared transaction is impossible)

```ts
// Business change + outbox row commit together; a relay drains the outbox into the audit store guaranteed-after.

await db.transaction(async (tx) => {
  await orders.delete(tx, orderId);                          // the business change
  await outbox.enqueue(tx, {                                 // SAME transaction
    kind: 'audit',
    event: { actor, action: AuditAction.RECORD_DELETED, target: { type: 'order', id: orderId },
             diff: { before: snapshot }, outcome: 'success', context },
  });
});
// A separate relay polls `outbox` and calls auditLog.record(...); the row is marked sent only on durable audit commit.
// Guaranteed-AFTER, never dropped. Contrast with `void queue.publish(event)` whose rejection vanishes.
```

The outbox row and the business change share a transaction, so the intent to audit cannot be lost. A relay delivers it with at-least-once semantics; the audit `record` is idempotent on `(correlation_id, action, target_id)` to absorb redelivery.

## Capturing critical actions via interceptor

```ts
// src/modules/audit/audit.interceptor.ts  — central capture so call sites can't forget

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler) {
    const meta = this.reflector.get<AuditMeta>(AUDIT_META, ctx.getHandler());
    if (!meta) return next.handle();                         // not a sensitive action

    const req = ctx.switchToHttp().getRequest();
    const base = {
      actor: { userId: req.user.id, impersonatorId: req.user.impersonatorId, tenantId: req.user.tenantId },
      context: { correlationId: req.correlationId, sourceIp: req.ip, userAgent: req.headers['user-agent'] },
    };
    return next.handle().pipe(
      // success AND denial/error both audited — a denied permission change is high-signal.
      tap({
        next:  (res) => this.audit.record({ ...base, action: meta.action, target: meta.target(req, res), outcome: 'success' }),
        error: (err) => this.audit.record({ ...base, action: meta.action, target: meta.target(req), outcome: err instanceof ForbiddenError ? 'denied' : 'error' }),
      }),
    );
  }
}

// usage:  @Audit(AuditAction.RECORD_DELETED, r => ({ type: 'user', id: r.params.id }))
//         @Delete('/users/:id')  deleteUser() { ... }
```

A decorator + interceptor makes "audited" the default for marked handlers and surfaces coverage to the verify command. Failure paths (`denied` / `error`) are audited too — investigators care about attempts, not just successes.

## Redaction

```ts
// src/modules/audit/infrastructure/redactor.ts

const DENY = /pass(word)?|secret|token|api[_-]?key|authorization|card[_-]?number|\bpan\b|cvv|cvc|ssn/i;

export class Redactor {
  scrub(value: Json): Json {
    return mapDeep(value, (key, v) => {
      if (DENY.test(key)) return '[REDACTED]';               // never the raw secret
      if (key === 'email') return hashPseudonym(v);          // minimize PII — store a stable pseudonym
      return v;                                              // keep enough to be forensically useful
    });
  }
}
```

Store identifiers and hashes, not raw secrets/PII. Forensically useful (you can correlate the same hashed email across events) without turning the audit log into a credential dump.

## Query / export for investigations + compliance

```ts
async query(filter: AuditQuery, by: Actor): Promise<AuditEntry[]> {
  this.authz.require(by, 'audit:read');                       // read is privileged
  await this.record({                                         // reading the trail is itself audited
    actor: by, action: AuditAction.AUDIT_READ,
    target: { type: 'audit_query', id: hashFilter(filter) },
    outcome: 'success', context: by.context,
  });
  return this.repo.find(filter);   // SELECT only — query path exposes no UPDATE/DELETE
}
```

Reading the audit log is itself a sensitive action; every query/export emits its own entry. The query path is read-only by construction — there is no code route that mutates a row.

## Common mistakes

### Mutable audit rows
"We just need to fix one wrong `reason`." → `UPDATE audit_log SET ... ` → the table is now editable, so it proves nothing. Append a correction row referencing the original `seq`. Revoke `UPDATE`/`DELETE` so this can't happen.

### Fire-and-forget that drops
`void auditQueue.publish(event)` — no await, no outbox, rejection swallowed. Under load or a broker blip the entry vanishes silently. Bind the write to the business change (same txn) or use a transactional outbox with at-least-once delivery.

### Split transaction
Business change commits, audit write throws and is caught-and-ignored → a real deletion with no trace. Or audit commits, business txn rolls back → an audit of a change that never happened. Put both in ONE transaction (or both behind the outbox).

### Secret / PII in the trail
Auditing a token rotation and dumping the new token into `after`; auditing a password change and storing the hash. The audit log becomes a breach target. Redact secrets; pseudonymize PII; store enough to investigate, not enough to compromise.

### Coverage gap on the action that matters
Every read is audited but `DELETE /users/:id` isn't because deletion runs in a different service. The single most investigation-relevant action is invisible. Mark every sensitive handler; let the verify command prove coverage.

### Debug-log-as-audit
`logger.info({ userId, action })` to stdout — sampled, rotated after 7 days. Eight months later legal asks who exported the customer list; the line is gone. Audit is a durable, append-only, queryable, retained store — not a log line.

### No integrity chain
Rows have no `prev_hash` and a reusable id. An insider with DB access deletes the three rows covering their action; nothing detects the gap. Hash-chain (or anchored monotonic seq) so deletion/reordering is provable.

### Unaudited audit read
Anyone with DB read browses the trail and no one knows who looked or what they exported. Reading the trail is sensitive — emit `audit.read` / `audit.exported`.

### Retention cleanup deletes evidence
A "tidy old data" cron deletes rows still inside the regulatory retention window; or a GDPR-erasure job hard-deletes audit rows referencing the subject. Exclude in-retention audit rows from cleanup; satisfy erasure by crypto-shredding referenced PII while KEEPING the audit row.

### Client-supplied actor or timestamp
Trusting `actor_id` / `occurred_at` from the request body. The actor is the authenticated principal; the timestamp + sequence are server-assigned. A forged actor field lets the attacker write history in someone else's name.

### Non-canonical hash input
`JSON.stringify(row)` whose key order or number formatting differs between runtimes → the verifier recomputes a different hash and reports false tampering. Use a deterministic canonical serialization and store `hash_version`.

## Cross-references

- `<rules-path>/audit-log-discipline.md` — the hard-rule list (append-only, required fields, tamper-evidence, atomic capture, redaction, restricted+audited reads, retention).
- `<commands-path>/audit-trail-verify.md` — recomputes the chain (computed-vs-stored) and proves coverage of sensitive actions cite-or-FAIL.
- `<agents-path>/audit-log-reviewer.md` — review gate enforcing this pattern.
- `<rules-path>/payment-idempotency.md` — operator "manual mark as paid" overrides MUST emit an audit entry; this pattern defines its shape.
- `<patterns-path>/webhook-flow.md` — webhook-triggered side effects (exports, account changes) feed the same trail; the actor is the verified provider/installation, never an unverified payload field.
- `<adr-path>/<NNN>-audit-retention-and-tamper-evidence.md` — ADR pinning store, retention per regulation, hashing/anchoring scheme, and access policy.
