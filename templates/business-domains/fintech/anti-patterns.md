# Fintech — domain-specific anti-patterns

Specific to money-movement systems. Errors here are not bugs; they are losses, regulatory findings, or insolvency events.

## Money representation

- **Floats / doubles for amounts.** `0.1 + 0.2 = 0.30000000000000004`. Inevitable drift; reconciliation breaks. Always integer minor units in `bigint` OR `Decimal` library. Test with `0.1 + 0.2` cases explicitly.
- **Currency type missing on amount.** Adding USD to EUR silently. Use a Money type: `{ amount: bigint, currency: 'USD' }`. Math operations enforce same-currency or trigger explicit FX.
- **Minor-unit assumption (always 100).** USD/EUR/GBP have 100; JPY has 1; BHD/IQD/JOD have 1000. Hardcoding `* 100` everywhere = 10x errors on those currencies. Lookup from currency metadata.
- **Rate stored as float.** `0.025` for 2.5% — drifts. Store as basis points (`int 250`).
- **Rounding inconsistent.** App rounds half-up, ledger rounds banker's; over time, sub-cent drift compounds. Define rounding policy; enforce in single utility; test edges.
- **Display formatted via custom code.** Forgets locale (1,234.56 vs 1.234,56), positions of currency symbol, RTL formatting. Use `Intl.NumberFormat` (or equivalent).

## Ledger correctness

- **Single-entry ledger.** Just `account.balance` updated per tx. Cannot answer "what was the balance on date X?", cannot reconcile. ALWAYS double-entry: every transaction = 2+ postings; sum(debits) = sum(credits).
- **Direct UPDATE on balance instead of inserting postings.** Race conditions, lost history, no audit. Postings are the source of truth; balance is derived (or memoized + reconciled).
- **Balance recomputed by SUM on every read.** Slow at scale. Memoized balance + reconciliation job that asserts balance = sum(postings).
- **Balance memo updated outside the same transaction as the postings.** Postings written, balance update fails → drift. Atomic update, or rebuild from postings.
- **Negative balance on asset accounts allowed.** Customer's checking account goes -$50 silently due to a race; no overdraft policy applied. CHECK constraint + explicit overdraft logic.
- **Postings mutable.** Edits silently corrupt history. Append-only; corrections via reversal postings.
- **No idempotency key on posting insert.** Retry → double-post. UNIQUE constraint on idempotency_key per account.
- **Currency mismatched in single transaction.** Debit USD, credit EUR — silently misposting. Each transaction = 1 currency, OR explicit FX with two atomic legs (one per currency, with FX-rate metadata).
- **Reconciliation job absent.** Drift goes undetected for months; six-figure crater discovered during audit. Daily recon: balance == sum(postings) per account; sum(internal credits) == sum(internal debits) per currency.

## Concurrency

- **Two transfers from the same account, no row lock.** Both check balance simultaneously; both pass; both posted; account negative. `SELECT ... FOR UPDATE` on the account row OR conditional UPDATE OR per-account serialized queue.
- **Distributed transfers without 2PC.** A debited, B not credited (network partition). Use saga pattern: post both legs in same DB transaction; if external call needed, split into recoverable steps with compensation.
- **Long-held locks.** Account locked for 5 seconds during external call; throughput collapses. Lock briefly; do external work outside lock with idempotent commit.
- **Cluster cron without leader election.** Each node runs the daily-interest cron → 3x interest credits.
- **Webhook handler not idempotent.** Provider retries on timeout → second post → double-credit. Always check + dedupe by webhook event ID.
- **Read after write on replica.** Just-posted transfer not visible; UI looks broken. Read-your-writes: after writes, read primary OR include version token.

## KYC / AML

- **KYC verified once, never re-verified.** ID expires; sanctions list updates; account stays clean. Re-verify on schedule + on triggers.
- **Sanctions screening at onboarding only.** Customer added to OFAC list 6 months later; transactions continue. Daily delta scan against current customer base.
- **Sanctions provider returns false positive; auto-pass.** True hit slips through. ALL hits → manual review queue; never auto-pass.
- **PEP screening shallow.** Only current PEPs; misses recent (6-12 months out of office). Use comprehensive provider data.
- **AML rules thresholds copy-pasted from a vendor template.** Wildly miscalibrated for actual customer base; alert fatigue OR misses real fraud. Tune over 3-6 months.
- **Auto-close AML alerts after 30 days "expired."** Regulator audit finds unreviewed alerts → enforcement.
- **AML decisions recorded as "confirmed false positive" with no rationale.** Cannot defend in audit. Mandatory reasoning + supporting evidence per disposition.
- **Customer "tipped off" about SAR.** Telling a customer "we filed a SAR" is a federal crime in US. Communications must be carefully scripted.
- **KYC documents stored unencrypted in S3.** First audit fails. Encryption + KMS + access logs.
- **KYC reverification not blocking.** Customer's docs expired; transactions continue; AML violation. Block at level enforcement.
- **Structuring detection misses sub-threshold pattern.** $9,500 deposits twice daily over 3 days; rules check single-day; pattern missed. Multi-day windows.
- **Country-of-residence vs nationality conflated.** US citizen living in Iran = sanctions hit; system checks only nationality. Both must be screened.
- **Beneficiary screening absent.** Sender clean, receiver on OFAC; transfer goes through. Screen counterparties on every transfer.

## Holds + authorizations

- **Hold not released on cancel.** Customer cancels withdrawal; available balance still deducted. Atomic release on cancel.
- **Hold expires server-side; not reflected in available.** Available shows lower than reality until customer-induced refresh. Recompute on read.
- **Hold + posting not linked.** Manual reconciliation impossible. Posting references the hold ID it captures.
- **Capture amount > authorized hold.** "Restaurant tip" — 20% over auth allowed by card networks; system rejects valid capture.
- **Hold currency != account currency without FX leg.** Reservation drift on multi-currency cards.

## Transfers + payments

- **No idempotency on POST /transfers.** Customer double-clicks → two transfers. Mandate Idempotency-Key header.
- **Idempotency-Key key not tied to user.** Two users picking same key collide. Scope key to user.
- **Same idempotency key for different intents.** Customer reuses key for different recipient/amount → first response returned (wrong). Hash request body + key.
- **Transfer to closed account silently fails.** Funds go nowhere; balance not restored. Pre-flight check + on failure return.
- **Transfer return (NACHA / SEPA) not handled.** Funds returned by recipient bank; customer balance not restored. Return webhook handler updates ledger.
- **Returned transfer reverses without preserving original.** Audit cannot trace. Reversal posting references original; both retained.
- **Transfer scheduled for date, but cron uses UTC; customer expected local TZ.** Settled day after expected. Customer TZ-aware scheduling.
- **Transfer status display ahead of reality.** "Sent" shown when actually still in queue; customer assumes settled, complains.

## FX

- **FX rate fetched per transaction without locking.** Customer accepts quote; system fetches new rate at settlement; different rate. Lock quote with TTL (15-60 sec).
- **FX rate stale by hours.** Cached aggressively; arbitrage possible (customer's favor); operator loses. Live source + short TTL.
- **FX rate from one provider; trade executed via another.** Spread mismatch; loss on every trade. Single-provider quote → execute.
- **Mid-market rate displayed as "your rate"; spread invisible.** Customer expects mid; gets mid + 2% spread; complaint. Show your rate clearly with separate fee breakdown.
- **FX done at posting time, not at trade time.** Posting delayed; rate moved 0.5%; reconciliation breaks.
- **Cross-currency transfer with single posting per side.** No FX leg recorded. Three accounts touched: source account (debit currency A), FX clearing (credit A + debit B), target (credit B). All postings reference FxConversion.

## Statements + reporting

- **Statements generated each request, not snapshotted.** Last month's statement changes if a back-dated correction posts. Snapshot at generation; future corrections add new lines or are out-of-band.
- **Transaction descriptions raw provider strings.** "ACH-CR-12345-CUST" is unreadable. Map to human-readable + preserve raw for audit.
- **Statement period in operator TZ; customer in different TZ.** Tax-period misclassification. Customer-TZ-aware boundaries.
- **Year-end 1099 generated from operational data, not accounting data.** Drift. Use the ledger.
- **Statement download bypasses authentication.** Statement URLs guessable. Signed URLs + auth check + audit log.

## Disputes + chargebacks

- **No provisional credit (Reg E).** US debit card customer reports unauthorized → must get provisional credit within 10 BD if investigation incomplete; v1 skips → class action.
- **Dispute filed; transaction not flagged.** Customer can move funds before resolution; mule pattern. Auto-hold disputed amount.
- **Evidence not collected systematically.** Manual chase; deadlines missed; chargebacks lost. Workflow that prompts evidence at filing.
- **Card network deadlines hardcoded.** Visa CE 3.0 timelines change; v1 expires defenses early. Configurable + monitored.
- **Won chargebacks not credited back to customer's account.** Customer's funds stuck. Reverse the provisional reversal.

## Cards

- **PAN stored anywhere.** PCI scope nightmare. Provider tokens only.
- **CVV stored.** Forbidden by PCI; even briefly, even in memory.
- **Card image with last 4 + expiry shown to anyone authenticated as the user.** Acceptable; full PAN reveal requires step-up auth.
- **Card freeze not real-time.** User freezes card; auth still approves; angry user.
- **Card PIN reset over insecure channel.** SMS + email step-up at minimum; biometric preferred.
- **Failed PIN tries don't lock.** Brute force trivial.
- **Push provisioning to wallet without device verification.** Stolen device → adds card to attacker's wallet.

## Open Banking / aggregation

- **Plaid-like consent without re-consent at 90 days (PSD2).** Connection silently breaks; users unable to fund.
- **Stored credentials at all.** Never. OAuth tokens only.
- **Aggregator data treated as authoritative.** Connectivity glitches; balance shown wrong. Mark "as of timestamp" on aggregated data.

## Limits

- **Daily limit enforced; per-tx not.** $50,000 single-shot withdrawal slips under "5 transactions today."
- **Limits in operator TZ; customer in different TZ.** Customer hits "midnight" at unexpected moment.
- **Limits stored as int but transaction is bigint.** Overflow on >$21M (32-bit int max in cents). Match types.
- **Limit increase via support not audited.** Compliance can't review; AML weak point.
- **Limits don't degrade gracefully when KYC level downgrades.** Account flagged for review; user can still transact above lower-tier limit.

## Multi-currency accounts

- **Single account, multi-currency posted to one balance.** `balance: 1234, currency: 'USD'` but a EUR transaction came in; nonsense. Sub-balances per currency.
- **Settlement currency conversion at withdrawal-only.** User holds 1000 currencies "freely" until withdrawal; rebalancing chaos. Lock sub-balances; explicit FX moves.

## Audit + observability

- **Audit log mutable.** Engineer edits to remove a record; defeats purpose. Append-only store; periodic Merkle root.
- **PII in logs.** Card last 4 OK; PAN forbidden; SSN forbidden; full names questionable. Log redaction layer.
- **Production data in dev.** Engineers see PAN / SSN / balance; insider risk + compliance fail. Anonymized fixtures.
- **No correlation ID across services.** Trace a transaction across 5 services impossible during incident. Correlation ID propagation mandatory.

## Disaster recovery + reliability

- **Backups never restored.** RTO claim of 4 hours is actually 18; quarterly drill required.
- **DR site stale by hours.** Data loss on failover. Replication lag monitored + alerted.
- **Cron jobs with hardcoded "today is X" assumptions.** DST-induced outages.
- **Dependent on a single payment rail.** Rail outage = product outage. Multi-rail with failover.
- **Capacity planning for "average day."** Payday + market open + tax day = 5x normal load; system collapses. Plan for peak + headroom.

## Trust + UX

- **Account frozen with no message.** "Your account has been frozen due to a violation of our terms" — meaningless. Context (compliance-cleared) + appeal path.
- **Withdrawal hold reasons opaque.** "Your withdrawal is under review" with no ETA; customer files complaint with regulator. Explain (when allowed).
- **2FA SMS-only.** SIM swap attacks. Offer authenticator app + biometric.
- **Notification spam.** Every authorization, every settlement, every check-in → user disables all → real fraud notifications missed. Smart bundling.
- **Step-up auth on every login.** Friction kills usage. Risk-based step-up.
- **PIN / passcode shared between accounts of multiple co-owned business cards.** Insider fraud risk; regulator finding.

## Operational

- **No multi-eyes approval on manual journal entries.** One engineer credits operator account $1M; nobody noticed for a week. Two-person rule on adjustments.
- **Privileged actions only logged in app DB.** App DB compromised → log tampered. Centralized + tamper-evident audit log.
- **Test mode + prod mode in same DB without strict separation.** Test transactions count toward limits, KYC, sanctions screening — pollutes everything. Separate environments completely; test mode flag at the topmost level.
- **Regulator data request takes 5 engineers + 3 days.** Build the export from day one.
- **Customer support staff have full read on every account.** Insider risk. Just-in-time access + audit log + role-based.
