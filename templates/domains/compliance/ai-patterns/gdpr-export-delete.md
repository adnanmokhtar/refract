---
name: gdpr-export-delete
description: "Pattern: GDPR export + delete (Article 15 + Article 17)"
kind: ai-pattern
---

# Pattern: GDPR export + delete (Article 15 + Article 17)

> **Hard rule** — The PII inventory is the contract; every entity it lists has a wired exporter + deleter, plus a coverage test that fails CI when a flagged entity is unwired. No PII field ships without a row in the inventory.

**When to apply**
- Any system processing EU personal data (or CCPA / equivalent jurisdictional rights).
- Self-serve account deletion / data-export endpoints exist or are planned.
- Sub-processors (Stripe, ESP, analytics) hold copies of the same data.

**When NOT to apply**
- Anonymous / pseudonymous-only datasets with no link to a natural person.
- B2B contracts where erasure obligations sit with the customer's controller, not us — document the carve-out in an ADR.
- Pre-launch internal tooling with no real-user data.

**Halt conditions / mandatory cites**
- Cite `ai/compliance/pii-inventory.yaml` and at least one `Exporter` + `Deleter` implementation at `<path:line>`. Inventory absent = halt.
- Cite the coverage test that walks the inventory and asserts wired exporters/deleters at `<path:line>`. Manual review only = halt.
- Cite the sub-processor notification path at `<path:line>` (Stripe, ESP, analytics deletion calls). "We'll email them" = halt.
- Cite retention sweep / hard-delete cron at `<path:line>`. Soft-delete with no purge job = halt.
- Grep ban: "GDPR is handled" without `<path:line>` references for inventory + exporter + deleter + sub-processor + retention.

## Why

Right of access (Art 15) and right to erasure (Art 17) are not optional. Implement them once, properly, in a way that survives schema growth — not as a one-off endpoint someone forgets to update.

The architecture: per-entity exporter + deleter, an orchestrator endpoint, a PII inventory that drives both. New PII field added → inventory updated → exporter + deleter updated → tests assert coverage. The PII inventory is the contract.

## PII inventory

```yaml
# ai/compliance/pii-inventory.yaml
- entity: users
  fields:
    - { name: email,        class: identifier, retention: 30d_post_deletion, basis: contract,    export: UserExporter, delete: UserDeleter }
    - { name: phone,        class: identifier, retention: 30d_post_deletion, basis: contract,    export: UserExporter, delete: UserDeleter }
    - { name: name,         class: profile,    retention: 30d_post_deletion, basis: contract,    export: UserExporter, delete: UserDeleter }
    - { name: date_of_birth,class: profile,    retention: 30d_post_deletion, basis: legitimate,  export: UserExporter, delete: UserDeleter }

- entity: addresses
  fields:
    - { name: street,       class: identifier, retention: 30d_post_deletion, basis: contract,    export: AddressExporter, delete: AddressDeleter }
    # ...

- entity: orders
  fields:
    - { name: shipping_address, class: identifier, retention: 7y, basis: legal_obligation, export: OrderExporter, delete: NONE_LEGAL_HOLD }
    - { name: total_cents,      class: financial,  retention: 7y, basis: legal_obligation, export: OrderExporter, delete: NONE_LEGAL_HOLD }

- entity: support_tickets
  fields:
    - { name: body_text,    class: free_text_pii, retention: 2y, basis: legitimate, export: TicketExporter, delete: TicketDeleter }
```

`/compliance-audit` reads this file and verifies every entry has an exporter + deleter wired.

## Exporter interface

Each entity owns its exporter. They compose into the orchestrator.

```ts
// src/modules/compliance/core/interfaces/exporter.interface.ts
export interface Exporter<TKey = string> {
  readonly entity: string;
  export(subjectId: TKey): Promise<unknown>;       // typed per implementation
}
```

```ts
// src/modules/users/compliance/user.exporter.ts
@Injectable()
export class UserExporter implements Exporter {
  readonly entity = 'users';
  constructor(@Inject(USER_REPO) private users: UserRepo) {}

  async export(userId: string): Promise<unknown> {
    const u = await this.users.findOne(userId);
    if (!u) return null;
    return {
      id:           u.id,
      email:        u.email,
      phone:        u.phone,
      name:         u.name,
      date_of_birth:u.dateOfBirth,
      created_at:   u.createdAt,
      // Excluded: passwordHash (not PII per se but never exposed), internal flags
    };
  }
}
```

```ts
// src/modules/orders/compliance/order.exporter.ts
@Injectable()
export class OrderExporter implements Exporter {
  readonly entity = 'orders';
  constructor(@Inject(ORDER_REPO) private orders: OrderRepo) {}

  async export(userId: string): Promise<unknown[]> {
    const orders = await this.orders.findByUser(userId);
    return orders.map(o => ({
      id:                 o.id,
      placed_at:          o.placedAt,
      total_cents:        o.totalCents,
      currency:           o.currency,
      status:             o.status,
      shipping_address:   o.shippingAddress,
      items:              o.items.map(i => ({ name: i.productName, qty: i.qty, price_cents: i.priceCents })),
    }));
  }
}
```

## Orchestrator (export endpoint)

```ts
// src/modules/compliance/infrastructure/export.controller.ts
@Controller('/accounts/me')
export class DataExportController {
  constructor(
    @Inject(EXPORTERS) private exporters: Exporter[],   // multi-provider, all @Injectable() exporters bound
    @Inject(EXPORT_QUEUE) private queue: Queue,
    @Inject(AUDIT_LOG) private audit: AuditLog,
  ) {}

  @Post('/data-export')
  @UseGuards(JwtAuthGuard)
  async request(@CurrentUser() user: User): Promise<{ requestId: string }> {
    await this.audit.record({
      actor: user.id, subject: user.id, action: 'data_export_requested',
      purpose: 'gdpr_art_15', timestamp: new Date(),
    });
    const job = await this.queue.add('data-export', { userId: user.id, email: user.email });
    return { requestId: job.id };
  }
}

// Worker
@Processor('data-export')
export class DataExportWorker {
  constructor(
    @Inject(EXPORTERS) private exporters: Exporter[],
    @Inject(STORAGE) private storage: Storage,
    @Inject(EMAIL) private email: Email,
  ) {}

  @Process()
  async run(job: Job<{ userId: string; email: string }>): Promise<void> {
    const data: Record<string, unknown> = {};
    for (const exporter of this.exporters) {
      data[exporter.entity] = await exporter.export(job.data.userId);
    }
    const json = JSON.stringify(data, null, 2);
    const key = `exports/${job.data.userId}/${Date.now()}.json`;
    await this.storage.put(key, Buffer.from(json), { contentType: 'application/json' });
    const url = await this.storage.signedUrl(key, { expiresIn: '7d' });
    await this.email.send(job.data.email, 'data_export_ready', { url });
  }
}
```

Async pattern — large exports don't block the request. Signed URL expires; user re-requests if needed.

## Deleter interface

```ts
export interface Deleter<TKey = string> {
  readonly entity: string;
  delete(subjectId: TKey, options: { hardDelete: boolean }): Promise<DeleteResult>;
}

export type DeleteResult = {
  entity: string;
  deletedCount: number;
  cryptoShreddedCount: number;
  retainedForLegalCount: number;
  exemptions: Array<{ recordId: string; reason: string; reviewableUntil: Date }>;
};
```

```ts
// src/modules/users/compliance/user.deleter.ts
@Injectable()
export class UserDeleter implements Deleter {
  readonly entity = 'users';
  constructor(@Inject(USER_REPO) private users: UserRepo) {}

  async delete(userId: string, { hardDelete }: { hardDelete: boolean }): Promise<DeleteResult> {
    if (hardDelete) {
      const r = await this.users.hardDelete(userId);
      return { entity: 'users', deletedCount: r.affected ?? 0, cryptoShreddedCount: 0, retainedForLegalCount: 0, exemptions: [] };
    }
    // Soft delete now: NULL out PII immediately, hard-delete in 30d via retention job.
    await this.users.update(userId, {
      email:       null,
      phone:       null,
      name:        '[DELETED]',
      dateOfBirth: null,
      deletedAt:   new Date(),
    });
    return { entity: 'users', deletedCount: 0, cryptoShreddedCount: 1, retainedForLegalCount: 0, exemptions: [] };
  }
}
```

```ts
// src/modules/orders/compliance/order.deleter.ts
@Injectable()
export class OrderDeleter implements Deleter {
  readonly entity = 'orders';
  constructor(@Inject(ORDER_REPO) private orders: OrderRepo) {}

  async delete(userId: string, _: { hardDelete: boolean }): Promise<DeleteResult> {
    // Orders retained 7y for tax / dispute. PII inside order replaced.
    const orders = await this.orders.findByUser(userId);
    for (const o of orders) {
      await this.orders.update(o.id, {
        // PII replaced; transaction record preserved.
        shippingAddress: { line1: '[DELETED]', city: '[DELETED]', country: o.shippingAddress.country },
        billingEmail:    null,
        billingPhone:    null,
        // userId nulled to break the link, but order stays for accounting.
        userId:          null,
      });
    }
    return {
      entity: 'orders',
      deletedCount: 0,
      cryptoShreddedCount: orders.length,
      retainedForLegalCount: orders.length,
      exemptions: orders.map(o => ({
        recordId: o.id,
        reason: 'tax_record_retention_7y',
        reviewableUntil: addYears(o.placedAt, 7),
      })),
    };
  }
}
```

## Orchestrator (delete endpoint)

```ts
@Controller('/accounts/me')
export class DataDeleteController {
  constructor(
    @Inject(DELETERS) private deleters: Deleter[],
    @Inject(USER_REPO) private users: UserRepo,
    @Inject(SUB_PROCESSORS) private subProcessors: SubProcessorNotifier,
    @Inject(AUDIT_LOG) private audit: AuditLog,
  ) {}

  @Post('/deletion-request')
  @UseGuards(JwtAuthGuard)
  async request(@CurrentUser() user: User): Promise<{ acknowledged: true; results: DeleteResult[] }> {
    const results: DeleteResult[] = [];
    for (const deleter of this.deleters) {
      results.push(await deleter.delete(user.id, { hardDelete: false }));
    }

    // Notify sub-processors within 30d (here: kick off async)
    await this.subProcessors.notifyDeletion(user.id, user.email);

    await this.audit.record({
      actor:   user.id,
      subject: user.id,
      action:  'data_deletion_executed',
      purpose: 'gdpr_art_17',
      results,
      timestamp: new Date(),
    });

    return { acknowledged: true, results };
  }
}
```

## Crypto-shredding for legal-hold data

When PII must be retained (tax, dispute window) but the user requests erasure, encrypt the PII columns per-subject and shred the key:

```ts
// At write time
const subjectKey = await this.kms.generateDataKey({ subjectId: userId });
order.shippingAddressEncrypted = encrypt(order.shippingAddress, subjectKey);
order.shippingAddress = null;

// On erasure request (preserves transactional integrity, removes PII access)
await this.kms.deleteDataKey(userId);
// All ciphertext referencing this key is now unreadable. Row stays for accounting.
```

This is recognized by GDPR as effective erasure when hard delete conflicts with retention obligations. Document the approach in `ai/decisions/crypto-shredding.md`.

## Sub-processor notification

```ts
@Injectable()
export class SubProcessorNotifier {
  async notifyDeletion(userId: string, email: string): Promise<void> {
    // 30-day window per GDPR. Run async; queue retries.
    await Promise.allSettled([
      this.stripe.customers.del(await this.findStripeCustomerId(userId)),  // by metadata
      this.sendgrid.suppressions.add(email),                                // suppress + erase per Sendgrid API
      this.algolia.deleteObject(`user_${userId}`),
      this.mixpanel.deleteUser(userId),
    ]);
  }
}
```

Audit each call. Failures retried with backoff. After N failures → escalate to ops (vendor integration broken).

## Retention job (hard-delete sweep)

```ts
@Injectable()
export class RetentionJob {
  @Cron('0 2 * * *')
  async run(): Promise<void> {
    const users = await this.users.findSoftDeletedBefore(subDays(new Date(), 30));
    for (const u of users) {
      await this.userDeleter.delete(u.id, { hardDelete: true });
    }
    logger.info({ count: users.length }, 'retention_purge_users');

    const sessions = await this.sessions.findExpiredBefore(subDays(new Date(), 90));
    await this.sessions.hardDelete(sessions.map(s => s.id));
    logger.info({ count: sessions.length }, 'retention_purge_sessions');
    // ... per-class purges
  }
}
```

## Tests

```ts
describe('compliance: export coverage', () => {
  it('exports every PII-flagged entity', async () => {
    const inventory = parseInventory('ai/compliance/pii-inventory.yaml');
    const flagged = inventory.entities.filter(e => e.fields.some(f => f.export !== 'NONE_LEGAL_HOLD'));
    const wired   = container.getAll<Exporter>(EXPORTERS).map(e => e.entity);
    for (const entity of flagged) {
      expect(wired).toContain(entity.name);
    }
  });
});

describe('compliance: deletion cascade', () => {
  it('hard-deletes a user with no orphan rows in PII tables', async () => {
    const user = await seedUserWithFullDataset();
    await dataDelete.request(user);
    // simulate retention-grace
    await timeWarp(31, 'days');
    await retentionJob.run();
    for (const table of PII_TABLES) {
      const remaining = await db.query(`SELECT COUNT(*) FROM ${table} WHERE user_id = $1`, [user.id]);
      expect(remaining.rows[0].count).toBe('0');
    }
  });
});
```

## Common mistakes

### Forgotten foreign keys
`referral_codes.source_user_id` references `users.id` but missing `ON DELETE CASCADE` and missing from any deleter. User deleted → row orphaned → next user with same email + lookup → leak.

### Soft-deleted PII still queryable
`SELECT * FROM users WHERE email = ?` still finds soft-deleted rows. Either NULL the PII columns on soft-delete OR add `WHERE deleted_at IS NULL` to every query path (audit error-prone). Prefer NULL-on-soft-delete.

### Export missing relations
`/data-export` returns `users` row only. User has 50 orders, 200 messages, 30 reviews — none included. SAR (Subject Access Request) incomplete. Always wire the orchestrator.

### Deletion broke FKs
Hard-deleting `users` cascades to `orders` because of `ON DELETE CASCADE`. Now the financial record is gone — tax violation. Crypto-shred PII inside `orders`, keep the row.

### Backups outlive retention
PII purged from prod DB; backup from 6 months ago still has it. Backup retention policy MUST be ≤ data retention OR have a documented carve-out.

### Audit log itself contains PII
"User X requested deletion. Email was foo@bar." → audit log retained 2y, contains email. Exclude PII from audit log payload (use IDs only).

### Sub-processor ignored
Stripe customer object retained after user deletion. Vendor still has the data. Each sub-processor needs its own deletion call within 30d.

### Free-text fields unmonitored
`support_tickets.body` → users paste credit card numbers, NIDs, phone numbers in support requests. Flag the field; review redaction strategy.

### Export format unstable
Today's export is JSON; next quarter's is YAML; user can't compare. Pin format in a versioned schema; bump version explicitly.

### Self-serve missing
Export only via "email support" → support team manually exports → consistency suffers, GDPR self-serve right impaired. Provide an authenticated endpoint.

### Operator deletion vs. user deletion
"Operator deletes user from admin panel" must go through the SAME deletion endpoint as the user-initiated path. Otherwise: admin shortcut skips audit log, skips sub-processor notification, skips legal-hold review.
