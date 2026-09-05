---
description: Audit a specific money-movement path — immutability, the balance invariant, money type, idempotency, balance-read consistency / overspend race, reconciliation, and tenant/account scope — from the REAL posting code, never an assumed posting.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-ledger

Diagnose whether a specific posting / wallet / balance path is integrity-safe: whether entries are immutable, whether `Σ debits = Σ credits` atomically, whether money is integer, whether the posting is idempotent, whether an overspend can race, whether it reconciles, and whether it is tenant/account-scoped — from the REAL code, not a guess.

## Premise

Real signals only. Cite the actual posting/write code at `<path:line>`, the transaction boundary, the `Σdebit = Σcredit` assertion, the money type, the idempotency key + its UNIQUE constraint, the balance read used for any overspend decision + the lock around it, the reconciliation job, and the tenant + account scope — each at `<path:line>`. Never narrate an invariant you didn't read in the source. Read before judging: locate the posting in source and confirm the table the entries land in (and whether it is mutated anywhere) BEFORE issuing a verdict.

## Mechanical halt

Cite-or-halt: every run MUST print, for the path under audit — (1) the posting write at `<path:line>`; (2) the immutability verdict (any `UPDATE`/`DELETE` on the entries/postings/legs tables? cite each, or "INSERT-only"); (3) the balance invariant (the `Σdebit = Σcredit` assertion at `<path:line>` AND whether all legs commit in ONE transaction); (4) the money type at `<path:line>` (integer minor units, or "FLOAT — drift"); (5) the idempotency key + its UNIQUE constraint at `<path:line>` (or "MISSING — retry double-posts"); (6) the balance read used for overspend + the lock around the check-then-post at `<path:line>` (or "RACY / UNLOCKED — double-spend"); (7) the reconciliation job at `<path:line>` (or "MISSING"); (8) the tenant + account scope at `<path:line>` (or "MISSING — cross-account/tenant movement"). If any of these cannot be produced from real source, HALT and say which — never an assumed posting, never an assumed invariant.

This audit READS source and schema only. It does NOT run postings, does NOT execute money movement, and does NOT mutate the ledger. If verifying the overspend race needs a live test, propose an isolated, non-prod concurrency test — never fire concurrent debits at a real account.

## What it does

1. **Locate the posting** — find where money movement is written; cite `<path:line>` and the exact INSERT/posting-service call and the entries/postings/legs table(s) it writes.
2. **Immutability** — grep the entries/postings/legs tables for any `UPDATE` / `DELETE` / "edit to fix" path. Cite each at `<path:line>`. A correction MUST be a reversing posting; a mutation of history is a BLOCKER.
3. **Balance invariant + atomicity** — find the `Σ debits = Σ credits` assertion and confirm ALL legs (and any balance update) commit in ONE transaction. Cite the assertion + the transaction boundary. An unbalanced or split-transaction posting is a BLOCKER.
4. **Money type** — confirm amounts are integer minor units + currency tag (the `Money` type). Any float / `number` arithmetic / `toFixed` on an amount is a BLOCKER. Cite `<path:line>`.
5. **Idempotency** — confirm every posting carries an idempotency key AND a UNIQUE constraint backs it (check the schema, not just the code). "Check-then-insert" with no unique index is a BLOCKER. Cite the key + the constraint.
6. **Balance-read consistency / overspend race** — find the balance read used to decide a debit. Is it a running balance / locked aggregate, or a racy live `SUM` / cached value? Is the debit wrapped in `SELECT ... FOR UPDATE` / `SERIALIZABLE` so check-then-post can't race? A racy read or an unlocked debit is a BLOCKER. Cite `<path:line>`.
7. **Reconciliation** — find the scheduled job that re-derives balances from the journal and compares to the source of truth. Missing reconciliation, or a job that auto-edits entries to square a drift, is a finding. Cite `<path:line>`.
8. **Tenant + account scope** — confirm every posting + balance read is scoped to `account_id` + `tenant_id` from the auth context, and no path moves funds between tenants. A missing scope is a BLOCKER. Cite `<path:line>`.
9. **Currency** — if a posting can cross currencies, confirm the rate + source + timestamp are recorded and legs stay single-currency.
10. **Report** — immutability verdict, balance/atomicity verdict, money verdict, idempotency verdict, overspend verdict, reconciliation verdict, scope verdict, and the top fix.

## Flow

```text
locate posting (<path:line>)
  -> immutability: any UPDATE/DELETE on entries?            [BLOCKER if mutated history]
  -> balance: Σdebit = Σcredit + ONE transaction           [BLOCKER if unbalanced / split tx]
  -> money: integer minor units (Money type)               [BLOCKER if float]
  -> idempotency: key + UNIQUE constraint                   [BLOCKER if missing / no unique index]
  -> overspend: locked balance read + check-then-post       [BLOCKER if racy SUM / unlocked debit]
  -> reconciliation: re-derive vs source of truth           [finding if missing / auto-squares drift]
  -> scope: account_id + tenant_id from auth context        [BLOCKER if missing / cross-tenant]
  -> currency: recorded rate + source + ts on FX postings   [finding if mixed with no rate]
  -> report: verdicts + top fix
```

## Output

```
/audit-ledger — <wallet/posting path> @ <path:line>

Posting write (<path:line>):
  posting.post({ legs: [{wallet, -1, amt}, {sink, +1, amt}], idempotencyKey, ... })  -> ledger_entries

Immutability:      INSERT-only; corrections = reversing postings   [or: UPDATE ledger_entries @ x.ts:n — BLOCKER]
Balance invariant: Σdebit = Σcredit asserted @ posting.ts:48; all legs in ONE tx   [or: split tx — BLOCKER]
Money type:        integer minor units (Money, bigint) @ money.ts:12   [or: float / toFixed @ x.ts:n — BLOCKER]
Idempotency:       key + UNIQUE(tenant_id, idempotency_key) @ schema.sql:9   [or: MISSING — retry double-posts]
Overspend guard:   balance read FOR UPDATE @ wallet.ts:22; check-then-post in one tx
                                                                   [or: racy SUM / unlocked — double-spend BLOCKER]
Reconciliation:    re-derive vs PSP settlement @ reconcile.ts:14; alerts on drift   [or: MISSING — finding]
Tenant/account:    account_id + tenant_id from ctx @ posting.ts:60   [or: MISSING — cross-tenant BLOCKER]
Currency:          single-currency legs; fx rate+source+ts recorded   [or: mixed, no rate — finding]

Verdict: OK | BLOCKER(immutability) | BLOCKER(balance) | BLOCKER(float) | BLOCKER(idempotency)
         | BLOCKER(overspend) | BLOCKER(scope) | NEEDS-RECONCILIATION

Top recommendation:
  - <e.g. add UNIQUE(tenant_id, idempotency_key); wrap debit in FOR UPDATE; replace float with Money;
     convert the "fix" UPDATE into a reversing posting>
```

## Rules

- READ-ONLY audit. Never run a posting, never move money, never mutate the ledger. A concurrency check, if needed, runs isolated in non-prod — never concurrent debits against a real account.
- Cite-or-halt: real posting, real transaction boundary, real `Σdebit = Σcredit` assertion, real money type, real UNIQUE constraint (from the schema), real lock, real reconciliation, real scope — or halt naming what's missing.
- Always print the immutability verdict first; an `UPDATE`/`DELETE` on the immutable history is reported before anything else.
- Idempotency is judged from the SCHEMA (a UNIQUE constraint), not from an `if (!exists)` in application code — say so explicitly.
- The overspend verdict requires BOTH a consistent balance read AND a lock; a consistent read with no lock (or a lock with a racy read) is still a BLOCKER.
- Never report an invariant you didn't read in the source.

## Cross-references

- `.claude/rules/ledger-integrity-discipline.md` — the hard-rule list this command enforces (append-only, balanced + atomic, integer money, idempotent, locked overspend, scope, reconciliation).
- `ai/patterns/double-entry-ledger.md` — the immutable journal + balanced atomic posting + locked overspend + reconciliation code shapes.
- `<patterns-path>/payment-integration.md § Money` — the integer-minor-unit money type amounts must use.
- `<agents-path>/ledger-reviewer.md` — review gate that consumes these findings.
