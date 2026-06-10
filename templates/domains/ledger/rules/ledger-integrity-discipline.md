---
name: ledger-integrity-discipline
description: Ledger & money-movement integrity discipline
kind: rule
---

# Ledger & money-movement integrity discipline

## Hard rule

Every movement of money/credits/balances MUST be recorded as an APPEND-ONLY, double-entry posting where `sum(debits) = sum(credits)` is enforced ATOMICALLY in ONE database transaction, in INTEGER minor units (never float). Ledger entries are IMMUTABLE: no `UPDATE`, no `DELETE` — a correction is a NEW reversing posting that nets to zero, never an edit. Every posting MUST carry an idempotency key so a retry NEVER double-posts. A balance MUST be derived from a CONSISTENT read (a running-balance/snapshot+delta or a locked aggregate), never a racy live `SUM` interpreted as authoritative for a debit. A wallet/balance DEBIT MUST take a row lock / `SELECT ... FOR UPDATE` / `SERIALIZABLE` so two concurrent debits cannot both pass the overspend check. Every entry MUST be scoped to an account + tenant; the ledger MUST be reconciled against its source of truth on a schedule.

A ledger bug is not a failed request — it is money invented, money destroyed, a balance that goes negative, a wallet double-credited on retry, or two accounts whose totals silently disagree with reality. The ledger IS the system of record for money; its integrity is non-negotiable.

## Must

- **Append-only journal**: postings and their entries (legs) are INSERT-only. A correction is a new reversing posting (`reverses_posting_id`) whose legs negate the original; the original stays in the journal forever. Reads of "current state" derive from the full immutable history.
- **Balanced, atomic posting**: every posting writes ≥ 2 legs in ONE transaction such that `Σ debits = Σ credits` (per currency). The balance check and ALL legs commit together or roll back together — a partial posting that debits without the matching credit is FORBIDDEN.
- **Integer minor units**: all amounts are integer minor units (cents/satoshi/…) with an explicit currency tag — the `Money` type from `<patterns-path>/payment-integration § Money`. Floats / `number` arithmetic / `toFixed` on money are FORBIDDEN; they drift fractional cents that never reconcile.
- **Idempotent posting**: every posting carries a caller-supplied idempotency key (`UNIQUE` constraint on `(tenant_id, idempotency_key)`); a retry with the same key returns the existing posting and writes NOTHING new. The unique index — not application logic — is the guarantee.
- **Consistent balance read**: a balance is a running balance maintained transactionally with each posting (snapshot + delta), or computed under the same lock as the debit. A live `SELECT SUM(...)` read OUTSIDE the debit's lock is NEVER treated as the authoritative available balance for an overspend decision.
- **Locked overspend guard**: a debit that must not overdraw locks the account row (`SELECT ... FOR UPDATE`) or runs `SERIALIZABLE`, re-reads the balance under the lock, checks `available >= amount`, then posts — all in one transaction. The check-then-post window MUST be closed against concurrency.
- **Account + tenant scope**: every leg references an `account_id` that belongs to a `tenant_id`; every posting and balance read is scoped to the tenant from the auth context. A posting that can move funds between accounts of DIFFERENT tenants is FORBIDDEN.
- **Recorded conversion on currency mixing**: a posting that crosses currencies records the conversion rate, the rate source, and the rate timestamp on the posting; each leg stays single-currency. Mixing currencies in one balance with no recorded rate is FORBIDDEN.
- **Reconciliation against the source of truth**: a scheduled job re-derives balances from the journal and compares them to the materialized/cached balances AND to the external source of truth (PSP settlement, bank statement, on-chain balance). A drift is an alert, halted and investigated — never auto-squared by editing entries.
- **Negative-balance/overdraft is explicit**: accounts that may not go negative reject the debit under the lock; accounts that MAY (credit lines) have an explicit, bounded overdraft limit checked the same way. Silent negative balances are FORBIDDEN.

## Must not

- `UPDATE` or `DELETE` a ledger entry / posting / leg to fix a mistake — it destroys the audit trail and breaks reconciliation. Reverse with a new posting.
- Write a posting where `Σ debits ≠ Σ credits`, or write the debit leg and credit leg in SEPARATE transactions — a crash between them invents or destroys money.
- Represent money as a float / `number` / `Decimal` formatted via `toFixed` — accumulated fractional-cent error never ties out to the source of truth.
- Post without an idempotency key, or "check if it exists then insert" without a UNIQUE constraint — a retry races and double-credits.
- Decide an overspend from a live `SUM` or a cached balance read outside the debit's lock — two concurrent debits both read the old balance and both pass → overspend / negative balance.
- Debit a wallet/balance without a row lock or `SERIALIZABLE` isolation — classic double-spend race.
- Omit the `tenant_id` / `account_id` scope on a posting or balance read, or move funds between two tenants' accounts.
- Mix currencies in a single account/balance without recording the conversion rate + source + timestamp.
- Skip reconciliation, or "fix" a reconciliation drift by editing entries instead of investigating + posting an adjustment.
- Let a non-credit account go negative silently.

## Should

- Wrap all money movement behind a single project-internal `<Ledger.post()>` / `<PostingService>` interface that takes a balanced set of legs + an idempotency key and enforces atomicity, balance, immutability, and scope in ONE place — feature code never writes ledger rows directly.
- Maintain per-account materialized running balances updated in the SAME transaction as the posting, so reads are O(1) and consistent, with reconciliation re-deriving them from the journal.
- Model accounts with explicit `normal_balance` (debit-normal vs credit-normal) so sign conventions are declared, not implicit per call site.
- Make posting jobs (settlement, payout, dunning) idempotent and replayable — see `<patterns-path>/queue-producer-consumer § idempotency`; a redelivered job re-posts with the same key and is a no-op.
- Record on every posting: `created_at`, `effective_at` (business date, may differ from system time), `reference` (the external event that caused it), and `reverses_posting_id` for corrections.
- Emit structured `{ postingId, tenantId, accountIds, currency, debitTotal, creditTotal, idempotencyKey, reversesPostingId }` per posting; alert on any posting where debit ≠ credit slips through, on negative balances, and on reconciliation drift.

## Review checklist (PRs touching postings / balances / wallets / credits / payouts)

- [ ] Ledger entries are INSERT-only — no `UPDATE`/`DELETE` on entries/postings/legs; corrections are reversing postings. Cite the write path at `<path:line>`.
- [ ] Every posting writes balanced legs (`Σ debits = Σ credits`) in ONE transaction; the balance assertion is at `<path:line>`.
- [ ] All amounts are integer minor units + currency tag (the `Money` type) — no float, no `toFixed` arithmetic.
- [ ] Every posting has an idempotency key backed by a UNIQUE constraint; cite the constraint + the retry path.
- [ ] Balance reads for an overspend decision are consistent (running balance / locked aggregate), not a racy live `SUM` or cached value.
- [ ] Wallet/balance debit takes a row lock (`FOR UPDATE`) or runs `SERIALIZABLE`; the check-then-post window is closed. Cite the lock at `<path:line>`.
- [ ] Every posting + balance read is scoped to `account_id` + `tenant_id` from the auth context; no cross-tenant movement.
- [ ] Currency-crossing postings record rate + source + timestamp; legs stay single-currency.
- [ ] Reconciliation against the source of truth exists and runs on a schedule; drift alerts, it does not auto-edit.
- [ ] Non-credit accounts cannot go negative; credit accounts have an explicit overdraft limit checked under the lock.

## Anti-patterns

- **Editing an entry to fix a balance** — `UPDATE ledger_entries SET amount = ... WHERE id = ...` to "correct" a wrong posting → audit trail destroyed, reconciliation broken. Post a reversing entry; the original stays forever.
- **Unbalanced / split-transaction posting** — debiting account A in one transaction and crediting account B in another → a crash between them leaves the books unbalanced; money is invented or destroyed. Both legs commit atomically or not at all.
- **Float money** — `balance += amount * 0.01` / `parseFloat(price)` / `total.toFixed(2)` → fractional-cent drift accumulates and the ledger never ties out to the bank. Integer minor units only.
- **Non-idempotent credit** — `if (!exists) insert(posting)` with no UNIQUE constraint → two concurrent retries both see "not exists" and both insert → the wallet is double-credited. The unique index is the guarantee.
- **Racy live SUM for overspend** — `const bal = SUM(amount); if (bal >= debit) post()` with the SUM read outside any lock → two concurrent debits both read the old balance, both pass, balance goes negative. Read under the debit's lock.
- **Unlocked wallet debit** — debiting without `SELECT ... FOR UPDATE` / `SERIALIZABLE` → textbook double-spend race. Lock the account row for the whole check-then-post.
- **Cross-tenant posting** — a transfer endpoint that takes `fromAccountId` + `toAccountId` from the request with no tenant check → funds move between tenants. Both accounts must belong to the auth-context tenant.
- **Silent currency mix** — adding USD and EUR amounts into one balance with no recorded rate → the balance is meaningless and irreversible. Record rate + source + timestamp; keep legs single-currency.
- **No reconciliation** — balances are trusted forever and never compared to the bank/PSP → a slow drift goes unnoticed until it's a six-figure discrepancy. Reconcile on a schedule; alert on drift.
- **Auto-squaring a drift** — a reconciliation job that "fixes" a mismatch by writing the difference into an entry with no investigation → it hides the bug that caused the drift. Halt + investigate + post a documented adjustment.

## Enforcement

- `<commands-path>/audit-ledger.md` (slash: `/audit-ledger`) — cite-or-halt diagnostic that locates the posting code at `<path:line>` and proves immutability, the balance invariant, integer money, idempotency, balance-read consistency / overspend race, reconciliation, and tenant/account scope from the real source — never an assumed posting.
- `<agents-path>/ledger-reviewer.md` — review gate hard-failing on mutable/deletable entries, unbalanced or non-atomic postings, float money, non-idempotent postings, racy/unlocked overspend reads, missing reconciliation, missing tenant/account scope, and unrecorded currency conversion.
- CI lint MUST reject `UPDATE` / `DELETE` against ledger entry / posting / leg tables (heuristic on table names; flag for review).
- CI lint MUST reject float/`number` arithmetic or `toFixed` on money-typed columns in posting code (AST heuristic; require the `Money` type).
- CI MUST assert a UNIQUE constraint on `(tenant_id, idempotency_key)` for the postings table exists in the schema.
- TODO: `scripts/validate-ledger-postings.sh` to AST-walk posting code and assert every posting is balanced, atomic, idempotency-keyed, tenant-scoped, and takes a lock on any account it debits with an overspend guard.

## Cross-references

- `<patterns-path>/double-entry-ledger.md` — immutable journal + balanced atomic posting + integer Money + idempotency key + consistent balance read + locked overspend guard + reconciliation code shapes.
- `<patterns-path>/payment-integration.md § Money` — the integer-minor-unit `Money` type every amount uses; `payment` is PSP integration, the ledger is the money-movement system of record it feeds.
- `<rules-path>/audit-log-discipline.md` — the ledger IS an audit trail of money; the append-only/immutability discipline parallels (and reconciliation depends on it).
- `<rules-path>/job-design.md` — idempotent, replayable posting jobs (settlement / payout / dunning) so a redelivered job re-posts as a no-op.
- `<rules-path>/reporting-export-discipline.md` — financial reports READ the ledger at a consistent as-of instant; they must not re-`SUM` mutable state mid-posting.
- `<adr-path>/<NNN>-ledger-model.md` — ADR pinning the account model (debit/credit-normal), the balance-derivation strategy (running balance vs. replay), the isolation level for debits, and the reconciliation source of truth.
