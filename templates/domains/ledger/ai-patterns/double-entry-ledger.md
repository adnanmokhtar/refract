---
name: double-entry-ledger
description: "Pattern: Double-entry ledger (immutable entries, balanced, idempotent, reconciled)"
kind: ai-pattern
---

# Pattern: Double-entry ledger (immutable entries, balanced, idempotent, reconciled)

> **Hard rule** — Money moves only as an APPEND-ONLY, double-entry posting where `Σ debits = Σ credits` commits ATOMICALLY in ONE transaction, in INTEGER minor units (never float); entries are IMMUTABLE (corrections are reversing postings, never `UPDATE`/`DELETE`); every posting carries an idempotency key backed by a UNIQUE constraint so a retry never double-posts; a debit that must not overdraw reads the balance UNDER a row lock / `SERIALIZABLE` and posts in the same transaction; every entry is account- + tenant-scoped; balances are reconciled against the source of truth on a schedule.

**When to apply**
- Any wallet / credits / balance / store-value feature where users hold and spend a quantity that must never be invented, destroyed, double-spent, or driven negative.
- Internal money movement that must reconcile to an external source of truth (PSP settlement, bank, on-chain) — payouts, refunds, transfers, fees, dunning.
- Any product where "what is this account's balance, exactly, and how did it get there" must be answerable from an immutable history.

**When NOT to apply**
- A pure pass-through to a PSP where you never hold a balance and never need a second account to balance against — that's `payment` (PSP integration), not a ledger.
- A non-monetary counter with no integrity requirement (page views, feature-usage tallies) — a counter store is enough; double-entry is overhead.
- Reporting/aggregation over an existing ledger — that READS the ledger (see `<patterns-path>/report-generation.md`); it does not post.

**Halt conditions / mandatory cites**
- Cite the posting write path at `<path:line>`. If it `UPDATE`s or `DELETE`s a ledger entry/posting/leg to "fix" anything = halt (corrections must be reversing entries).
- Cite the balanced-posting assertion + the single transaction boundary at `<path:line>`. Legs written across two transactions, or no `Σdebit = Σcredit` check = halt (money invented/destroyed).
- Cite the money type at `<path:line>`. A float / `number` arithmetic / `toFixed` on an amount = halt (use the integer-minor-unit `Money` type).
- Cite the idempotency key + its UNIQUE constraint at `<path:line>`. A posting with no key, or "check-then-insert" with no unique index = halt (retry double-posts).
- Cite the balance read used for an overspend decision at `<path:line>`, and the lock (`FOR UPDATE` / `SERIALIZABLE`) that wraps the check-then-post. A racy live `SUM` / cached read / unlocked debit = halt (double-spend / negative balance).
- Cite the tenant + account scope on every posting + balance read, and the reconciliation job, at `<path:line>` each.
- Grep ban: "the ledger is balanced / safe / can't double-spend" without file:line for the atomic balance assertion, the idempotency constraint, and the locked overspend read.

## Why

A ledger is the one workload where a "small bug" is literally money invented or destroyed, and where the failure is silent — nothing 500s, the books just stop tying out. Five failure modes recur:

1. **Mutable history** — someone `UPDATE`s an entry to "fix" a balance. The audit trail is now a lie, reconciliation can't find the cause, and the fix itself is unauditable. Entries are append-only; a correction is a reversing posting.
2. **Unbalanced / non-atomic posting** — the debit commits but the credit doesn't (separate transactions, a crash in between). Money is invented on one side or destroyed on the other. Both legs commit atomically with a `Σdebit = Σcredit` assertion or not at all.
3. **Double-post on retry** — a network retry re-runs a credit with no idempotency key → the wallet is credited twice. The guarantee MUST be a UNIQUE constraint, not application logic that races.
4. **Double-spend race** — two concurrent debits both read the old balance via a live `SUM`, both pass the overspend check, both post → negative balance. The balance read for a debit decision MUST happen under the same lock as the post.
5. **Float drift** — money in floats accumulates fractional-cent error that never reconciles to the bank. Integer minor units only.

The pattern: an immutable journal of postings, each a set of balanced legs committed atomically with an idempotency key; debits that read the balance under a row lock; and a reconciliation job that re-derives balances from the journal and compares them to the source of truth.

## Schema: append-only journal (no UPDATE, no DELETE)

```sql
-- A posting is one balanced business event. Its legs net to zero per currency.
CREATE TABLE postings (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id          UUID    NOT NULL,
  idempotency_key    TEXT    NOT NULL,
  reference          TEXT    NOT NULL,              -- the external event that caused this
  reverses_posting_id BIGINT REFERENCES postings(id),  -- set ONLY on a correction
  effective_at       TIMESTAMPTZ NOT NULL,          -- business date (may differ from created_at)
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- A retry with the same key is a no-op: the unique index IS the idempotency guarantee.
  CONSTRAINT uq_posting_idem UNIQUE (tenant_id, idempotency_key)
);

CREATE TABLE ledger_entries (              -- the legs; INSERT-only, NEVER updated/deleted
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  posting_id    BIGINT NOT NULL REFERENCES postings(id),
  tenant_id     UUID   NOT NULL,
  account_id    UUID   NOT NULL,                    -- belongs to tenant_id
  direction     SMALLINT NOT NULL CHECK (direction IN (1, -1)),  -- +1 debit, -1 credit
  amount_minor  BIGINT NOT NULL CHECK (amount_minor > 0),        -- INTEGER minor units, never float
  currency      TEXT   NOT NULL,                    -- single currency per leg
  -- conversion is recorded on the posting when a transfer crosses currencies:
  fx_rate       NUMERIC,        -- rate applied (NULL when same-currency)
  fx_source     TEXT,           -- where the rate came from
  fx_quoted_at  TIMESTAMPTZ     -- when the rate was quoted
);

-- DB-level guard: forbid mutation of the immutable history (corrections are new rows).
CREATE RULE no_update_entries AS ON UPDATE TO ledger_entries DO INSTEAD NOTHING;
CREATE RULE no_delete_entries AS ON DELETE TO ledger_entries DO INSTEAD NOTHING;

-- Materialized running balance, updated in the SAME transaction as the posting (see post()).
CREATE TABLE account_balances (
  account_id    UUID   NOT NULL,
  tenant_id     UUID   NOT NULL,
  currency      TEXT   NOT NULL,
  balance_minor BIGINT NOT NULL DEFAULT 0,          -- signed running balance, integer
  version       BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (account_id, currency)
);
```

There is no path to mutate a posted entry. A correction inserts a NEW posting whose legs negate the original and whose `reverses_posting_id` points at it. The whole history is replayable.

## The Money type (integer minor units, never float)

```ts
// All amounts are integer minor units + a currency tag. Reuse the project's Money type —
// see <patterns-path>/payment-integration.md § Money. Sketch for this pattern:

export class Money {
  private constructor(readonly minor: bigint, readonly currency: string) {}   // bigint, never number/float

  static of(minor: bigint | number, currency: string): Money {
    if (typeof minor === 'number' && !Number.isInteger(minor)) {
      throw new Error('Money must be integer minor units — never a float');   // hard fail on float
    }
    return new Money(BigInt(minor), currency);
  }
  plus(o: Money) { this.assertSameCurrency(o); return new Money(this.minor + o.minor, this.currency); }
  negate()       { return new Money(-this.minor, this.currency); }
  gte(o: Money)  { this.assertSameCurrency(o); return this.minor >= o.minor; }
  private assertSameCurrency(o: Money) {
    if (o.currency !== this.currency) throw new Error('currency mismatch — record an fx rate first');
  }
}
```

`SUM`/`+`/`*` happen on integers; formatting (`toFixed`, locale) happens only at the serialization edge. A money float NEVER reconciles.

## Posting: balanced, atomic, idempotent — in ONE transaction

> The TypeScript below uses a generic `db.tx` / `tx.query` shape for illustration. Substitute your project's idiom from `.claude/_extracted-codebase.md` — the ORM/transaction helper, the DI mechanism, the lock primitive. The SHAPE is universal: one transaction, idempotency short-circuit, `Σdebit = Σcredit` assertion, all legs + balance updates committed together.

```ts
// src/modules/ledger/posting.service.ts

export interface Leg { accountId: string; direction: 1 | -1; amount: Money; }  // +1 debit, -1 credit

export class PostingService {
  constructor(private db: Db) {}

  /** Single entry point for ALL money movement. Balanced, atomic, idempotent, scoped. */
  async post(input: {
    tenantId: string;
    idempotencyKey: string;
    reference: string;
    effectiveAt: Date;
    legs: Leg[];
    reversesPostingId?: bigint;
  }): Promise<{ postingId: bigint; replayed: boolean }> {
    this.assertBalanced(input.legs);   // Σ debits = Σ credits, per currency, BEFORE we touch the DB

    return this.db.tx(async (tx) => {
      // Idempotency: the UNIQUE (tenant_id, idempotency_key) makes a retry a no-op.
      const existing = await tx.query(
        `SELECT id FROM postings WHERE tenant_id = $1 AND idempotency_key = $2`,
        [input.tenantId, input.idempotencyKey],
      );
      if (existing.rows[0]) return { postingId: existing.rows[0].id, replayed: true };  // never double-post

      const { rows: [posting] } = await tx.query(
        `INSERT INTO postings (tenant_id, idempotency_key, reference, reverses_posting_id, effective_at)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [input.tenantId, input.idempotencyKey, input.reference, input.reversesPostingId ?? null, input.effectiveAt],
      );

      for (const leg of input.legs) {
        // Every leg is tenant + account scoped; account must belong to this tenant.
        const owns = await tx.query(
          `SELECT 1 FROM accounts WHERE id = $1 AND tenant_id = $2`, [leg.accountId, input.tenantId]);
        if (!owns.rows[0]) throw new CrossTenantPostingError(leg.accountId);   // no cross-tenant movement

        await tx.query(
          `INSERT INTO ledger_entries (posting_id, tenant_id, account_id, direction, amount_minor, currency)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [posting.id, input.tenantId, leg.accountId, leg.direction, leg.amount.minor, leg.amount.currency],
        );
        // Maintain the running balance in the SAME transaction — consistent O(1) reads later.
        await tx.query(
          `INSERT INTO account_balances (account_id, tenant_id, currency, balance_minor, version)
           VALUES ($1, $2, $3, $4, 1)
           ON CONFLICT (account_id, currency)
           DO UPDATE SET balance_minor = account_balances.balance_minor + EXCLUDED.balance_minor,
                         version = account_balances.version + 1`,
          [leg.accountId, input.tenantId, leg.amount.currency, leg.direction * leg.amount.minor],
        );
      }
      return { postingId: posting.id, replayed: false };   // all legs + balances committed atomically
    });
  }

  /** Σ debits = Σ credits, per currency. An unbalanced posting invents or destroys money. */
  private assertBalanced(legs: Leg[]): void {
    if (legs.length < 2) throw new UnbalancedPostingError('a posting needs ≥ 2 legs');
    const net = new Map<string, bigint>();
    for (const l of legs) {
      net.set(l.amount.currency, (net.get(l.amount.currency) ?? 0n) + BigInt(l.direction) * l.amount.minor);
    }
    for (const [currency, sum] of net) {
      if (sum !== 0n) throw new UnbalancedPostingError(`legs do not balance for ${currency}: net=${sum}`);
    }
  }

  /** A correction is a NEW reversing posting — never an UPDATE/DELETE of the original. */
  async reverse(tenantId: string, original: bigint, idempotencyKey: string): Promise<{ postingId: bigint }> {
    const legs = await this.legsOf(tenantId, original);
    return this.post({
      tenantId, idempotencyKey, reference: `reversal:${original}`, effectiveAt: new Date(),
      reversesPostingId: original,
      legs: legs.map((l) => ({ ...l, direction: (l.direction * -1) as 1 | -1 })),  // negate each leg
    });
  }
}
```

Both legs (and the balance updates) commit in ONE transaction; an unbalanced posting throws before any write; a retry with the same key returns the existing posting and writes nothing.

## Wallet debit: locked overspend guard (no double-spend)

```ts
// src/modules/ledger/wallet.service.ts

export class WalletService {
  constructor(private db: Db, private posting: PostingService) {}

  /** Debit a wallet without ever overdrawing it, even under concurrency. */
  async debit(input: {
    tenantId: string; walletAccountId: string; sinkAccountId: string;
    amount: Money; idempotencyKey: string; reference: string;
  }): Promise<{ postingId: bigint }> {
    return this.db.tx(async (tx) => {
      // Lock the wallet row for the WHOLE check-then-post window. Two concurrent debits serialize here.
      const { rows: [bal] } = await tx.query(
        `SELECT balance_minor FROM account_balances
          WHERE account_id = $1 AND tenant_id = $2 AND currency = $3
          FOR UPDATE`,                                   // <- row lock; or run the tx SERIALIZABLE
        [input.walletAccountId, input.tenantId, input.amount.currency],
      );

      const available = Money.of(bal?.balance_minor ?? 0n, input.amount.currency);
      if (!available.gte(input.amount)) {               // re-read UNDER the lock, not a racy live SUM
        throw new InsufficientFundsError(input.walletAccountId, available, input.amount);  // no negative balance
      }

      // Post inside the same transaction, under the same lock: wallet credited-out, sink debited-in.
      return this.posting.postWithin(tx, {
        tenantId: input.tenantId, idempotencyKey: input.idempotencyKey, reference: input.reference,
        effectiveAt: new Date(),
        legs: [
          { accountId: input.walletAccountId, direction: -1, amount: input.amount },  // credit (reduce wallet)
          { accountId: input.sinkAccountId,   direction: +1, amount: input.amount },  // debit  (the sink)
        ],
      });
    });
  }
}
```

The balance is read with `FOR UPDATE` and the post happens in the same transaction, so two concurrent debits cannot both pass the check — the second blocks until the first commits, then sees the reduced balance.

## Reconciliation against the source of truth

```ts
// src/modules/ledger/reconcile.service.ts — scheduled; alerts on drift, NEVER edits entries.

export class ReconcileService {
  async reconcile(tenantId: string, accountId: string, currency: string): Promise<ReconResult> {
    // 1. Re-derive the balance from the immutable journal (the truth of record).
    const { rows: [derived] } = await this.replica.query(
      `SELECT COALESCE(SUM(direction * amount_minor), 0) AS minor
         FROM ledger_entries
        WHERE tenant_id = $1 AND account_id = $2 AND currency = $3`,
      [tenantId, accountId, currency],
    );

    // 2. The materialized running balance we serve reads from.
    const { rows: [cached] } = await this.replica.query(
      `SELECT balance_minor FROM account_balances
        WHERE tenant_id = $1 AND account_id = $2 AND currency = $3`,
      [tenantId, accountId, currency],
    );

    // 3. The EXTERNAL source of truth (PSP settlement / bank statement / on-chain).
    const external = await this.sourceOfTruth.balance(tenantId, accountId, currency);

    const internalDrift = BigInt(derived.minor) - BigInt(cached?.balance_minor ?? 0n);
    const externalDrift = BigInt(derived.minor) - external.minor;

    if (internalDrift !== 0n || externalDrift !== 0n) {
      // HALT + alert + investigate. Do NOT auto-square by editing entries — that hides the cause.
      await this.alerts.ledgerDrift({ tenantId, accountId, currency, internalDrift, externalDrift });
      return { ok: false, internalDrift, externalDrift };
    }
    return { ok: true, internalDrift: 0n, externalDrift: 0n };
  }
}
```

Reconciliation re-derives from the journal, compares to the served balance AND the external source of truth, and ALERTS on any drift — it never "fixes" a drift by editing the immutable history.

## Common mistakes

### Editing an entry to fix a balance
`UPDATE ledger_entries SET amount_minor = ... WHERE id = ...` → the audit trail is now wrong and reconciliation can't explain it. Post a reversing entry; the original stays forever.

### Split-transaction posting
Debiting account A in one transaction and crediting account B in another → a crash between them leaves the books unbalanced. Both legs (and balances) commit in ONE transaction with a `Σdebit = Σcredit` assertion.

### Float money
`balance += amount * 0.01` / `parseFloat` / `toFixed(2)` arithmetic → fractional-cent drift that never ties out to the bank. Integer minor units (`bigint`) only; format at the edge.

### Non-idempotent credit
`if (!exists) insert(posting)` with no UNIQUE constraint → two concurrent retries both insert → double-credit. The `UNIQUE (tenant_id, idempotency_key)` index is the guarantee, not the `if`.

### Racy live SUM for overspend
`const bal = SELECT SUM(...); if (bal >= amount) post()` with the SUM read outside any lock → two concurrent debits both read the old balance and both pass → negative balance. Read under `FOR UPDATE` in the same transaction as the post.

### Unlocked wallet debit
Debiting without `SELECT ... FOR UPDATE` / `SERIALIZABLE` → classic double-spend race. Lock the account row for the whole check-then-post.

### Cross-tenant posting
A transfer that takes `fromAccountId`/`toAccountId` from the request and never checks ownership → funds move between tenants. Every leg's account must belong to the auth-context tenant.

### Silent currency mix
Adding USD + EUR into one balance with no recorded rate → an irreversible, meaningless balance. Record `fx_rate` + `fx_source` + `fx_quoted_at`; keep each leg single-currency.

### No reconciliation
Trusting the served balance forever → a slow drift goes unnoticed until it's a large discrepancy. Reconcile against the journal AND the external source of truth on a schedule; alert on drift.

### Auto-squaring a drift
A reconciliation job that writes the difference into an entry to "balance the books" → it hides the bug that caused the drift. Halt, investigate, and post a documented adjustment.

## Cross-references

- `<rules-path>/ledger-integrity-discipline.md` — the hard-rule list (append-only, balanced + atomic, integer money, idempotent, locked overspend, tenant scope, reconciliation).
- `<patterns-path>/payment-integration.md § Money` — the integer-minor-unit `Money` type every amount uses; `payment` is PSP integration that FEEDS the ledger, the ledger is the money-movement system of record.
- `<rules-path>/audit-log-discipline.md` — the ledger IS an audit trail of money; the append-only / immutability discipline parallels it and reconciliation depends on it.
- `<rules-path>/job-design.md` — idempotent, replayable posting jobs (settlement / payout / dunning); a redelivered job re-posts with the same key as a no-op.
- `<patterns-path>/queue-producer-consumer.md` — async worker semantics for posting jobs (idempotency, resumability, DLQ).
- `<patterns-path>/report-generation.md` — financial reports READ the ledger at a consistent as-of instant; they must not re-`SUM` mutable state mid-posting.
- `<commands-path>/audit-ledger.md` — cite-or-halt diagnostic for a specific posting/wallet path.
- `<agents-path>/ledger-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-ledger-model.md` — ADR pinning the account model, balance-derivation strategy, debit isolation level, and reconciliation source of truth.
