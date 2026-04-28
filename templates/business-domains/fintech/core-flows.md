# Fintech — core flows

The flows every money-movement product must support. P1 = "without these, you can't legally + safely move money." P2 = retention. P3 = scale + sophistication.

## P1 — must-have for v1

### 1. Account opening + KYC

```
Customer applies (email, phone, name, country, dob, SSN/govt ID#)
  → email/phone verified (OTP)
  → KYC submission:
       individual: passport / driver's license + selfie + liveness
       business: registration cert, articles, UBO list, proof of address
  → KYC provider verifies (Onfido / Persona / SumSub / Veriff)
  → sanctions + PEP screening (Comply Advantage / WorldCheck / OFAC SDN)
  → AML risk score computed
  → outcome:
       approved → account opened (status = active)
       rejected → reasoned email + appeal path
       requires_info → resubmission flow
```

Critical invariants:
- Account NOT created in usable state until KYC + sanctions clear. Pre-KYC "limited" mode is OK (read-only) but funds-handling is blocked.
- Sanctions hit = automatic block + manual review by compliance. Never auto-clear.
- Re-screening on profile changes (name, address, country) AND on schedule (daily delta scan against updated lists).
- KYC level tied to account capabilities: basic = $X daily limit; full = $Y; EDD = $Z. Don't let users transact above their KYC level.

### 2. Deposit (funding the account)

```
Customer initiates deposit:
  via card: Stripe / Adyen authorization → capture
  via ACH/SEPA: bank-to-bank pull (with mandate) OR push from external bank
  via wire: customer pushes; we credit on receipt
  → on funds confirmed (NOT same as "initiated"):
       transaction created
       ledger postings:
            debit operator's external bank account
            credit customer's internal account
       balance updated atomically
  → notification to customer
  → reconciliation against bank statement (daily)
```

Critical invariants:
- Posting fires on funds CONFIRMED, not initiated. ACH "submitted" ≠ "funds available" — there's a 1-3 day return window where funds can be clawed back.
- Pending balance shown until settled.
- Idempotency key on every initiation — provider retries must not double-post.
- Daily reconciliation: sum(deposits posted) == sum(bank credits we received). Mismatches = stop-the-world.

### 3. Withdrawal (off-rampng to external bank)

```
Customer requests withdrawal:
  → validate available balance >= amount + fee
  → validate counterparty (saved beneficiary or new)
  → validate against limits (daily, monthly, per-tx)
  → AML check (high-amount, suspicious pattern, country risk)
  → place hold on customer's account (internal)
  → submit payment instruction to provider (ACH / SEPA / wire / card payout)
  → on provider ack:
       hold → posted (debit customer; credit operator's external account)
  → on provider settle:
       transaction.status = settled
  → on provider failure / return:
       reversal posted; alert customer + ops
```

Invariants:
- Hold placed BEFORE submitting external payment, so customer can't double-spend.
- Idempotency key on provider call.
- ACH return window (US): 60 calendar days for unauth; 2 days for admin returns. Until past window, treat as "settling, not final."
- SEPA return: 8 weeks for SDD (consumer); 5 days for SCT.
- Limit checks use TODAY in customer's TZ; midnight rollover semantics matter.

### 4. P2P / internal transfer

```
User A sends $X to User B (both on platform):
  → validate User A's balance >= X
  → AML + limit checks
  → create Transfer (status=pending)
  → atomic transaction:
       debit A's account
       credit B's account
       (operator's accounts unchanged — internal)
  → notify both
  → status = completed
```

Invariants:
- ATOMIC. Either both postings happen or neither. Database transaction with serializable isolation OR write-ahead-log + replay.
- If A and B same currency: no FX. Different currency: explicit FX leg with locked rate.
- Idempotency on the Transfer ID — re-submit returns same Transfer.
- Recipient existence check happens BEFORE debit (so failed sends don't deduct).

### 5. Double-entry ledger invariants

```
Every transaction:
  sum(debits) == sum(credits)  (for that transaction, in unified currency)
  
Postings are immutable; corrections via reversal postings.

Daily reconciliation:
  sum(all_credits) - sum(all_debits) over all internal accounts == 0
  per-account_balance == sum(postings on that account)
  per-currency total == external bank balance + outstanding holds
```

Critical rules:
- NEVER edit a posted ledger entry. Reverse + repost.
- Posting requires `idempotency_key` to prevent double-posts on retry.
- Balance is a derived (or memoized) value; source of truth is the ledger.
- Cross-currency transactions: each currency balanced separately (FX leg has 2 postings: debit currency A, credit currency B, with FX rate metadata).

### 6. Hold / authorization (cards + pending transactions)

```
Card swipe (or transfer initiation):
  authorization request: $X for Y reason
  → place Hold on account (decreases available, NOT posted balance)
  → return auth approved
  
Settlement:
  capture for $X' (often = $X but can differ — restaurant tips!)
  → convert hold to posting (debit customer, credit operator)
  → release hold (balance updates)
  
Or expiry:
  hold TTL (typically 1-7 days for cards)
  → release hold (auto)
  → no posting; available restored
```

Invariants:
- Available = posted balance - sum(active holds).
- Hold + capture must reference each other (capture quotes the hold ID).
- Capture amount can differ from hold (tips, partial). Capture > hold = re-auth required.
- Expired holds release without posting — funds unblocked.

### 7. AML monitoring + alerting

```
Every transaction:
  → run rules engine:
       velocity check (N tx in M minutes)
       structuring (multiple sub-CTR threshold tx)
       geographic risk (high-risk country, IP/billing mismatch)
       industry / counterparty risk
       behavioral (deviation from user's pattern)
  → if any rule trips:
       AMLAlert created
       transaction may be auto-frozen pending review
       compliance team notified
  → review:
       false positive → close
       confirmed → escalate → SAR filing in regulatory window
       account action: warning / restriction / closure
```

Invariants:
- Logged + auditable; every decision has a paper trail.
- SAR filing happens in window (US: 30 days from detection; varies).
- Customer typically NOT informed of SAR (tipping off = federal crime in US).

## P2 — retention + completeness

### 8. Statement generation
- Monthly statement: opening + closing balance, transaction list, fees, interest.
- PDF + CSV.
- Tax-document generation (1099-INT for interest, 1099-K, 1099-B for investing).
- Year-end summary.

### 9. Card issuance + management
- Order physical or virtual card.
- View PAN/CVV (PCI scope — provider-tokenized; never your servers).
- Freeze/unfreeze.
- Set spending limits (per-tx, daily, category MCCs).
- Replace lost / stolen.
- Travel notice (legacy; less relevant with risk scoring).

### 10. Recurring transfers / scheduled payments
- Create schedule (date + amount + recurrence rule).
- Cron picks up due transfers.
- Idempotency per (schedule_id, due_date).
- Failure handling (retry; notify; pause).

### 11. Bill pay / merchant payment
- Pay a registered biller (utility, credit card).
- Push payment via ACH / RTP / wire.
- Confirmation / receipt.

### 12. FX / currency conversion
- Get quote (live rate + fee + valid TTL).
- Lock quote (e.g. 30 sec).
- Execute: debit source currency, credit target currency, both postings reference FxRate snapshot.
- Settlement may take time depending on rails.

### 13. Beneficiary management
- Add beneficiary (account #, routing, IBAN, name).
- Verification (micro-deposit / instant verify like Plaid).
- Sanctions screen on add.
- Soft-edit (some providers require new addition + reverify on change).

### 14. Disputes + chargebacks
- Customer files dispute (card or ACH return).
- Provisional credit while investigating (Reg E mandate in US for cards).
- Evidence collection.
- Network case (Visa CE 3.0, MC Smart Data, etc.).
- Outcome: credit retained or reversed.

### 15. Customer support
- View user / account / transactions.
- Place hold / freeze / unfreeze.
- Initiate refund (within authority).
- Note + flag user.

## P3 — scale + product depth

### 16. Multi-currency accounts
- Customer holds balances in multiple currencies in one account (sub-balances).
- Send / receive in any held currency without forced conversion.

### 17. Lending / credit
- Underwriting flow.
- Loan account with amortization schedule.
- Auto-debit installments.
- Default / collections flow (separate from main fintech model).

### 18. Investing / brokerage
- Custodial vs non-custodial.
- Order routing (RegNMS in US).
- Trade settlement (T+2 → T+1 in US as of May 2024).
- Tax-lot tracking, wash-sale flags.

### 19. Subscription savings / round-ups / pots
- "Round each transaction up to $1, save the difference."
- Goal-based savings.
- Yield/interest computation + accrual postings.

### 20. Fraud detection (ML-driven)
- Real-time risk scoring on every transaction.
- Step-up auth on suspicious (3DS, OTP, biometric).
- Account takeover detection (device fingerprint, geo, behavior).
- Mule account detection.

### 21. Open Banking / Aggregation (PSD2 AISP/PISP)
- Pull external account data (Plaid, Tink).
- Initiate payments from external account.
- OAuth + consent flows + 90-day re-consent under PSD2.

### 22. Reconciliation + back-office
- Daily reconciliation of internal ledger vs partner bank vs card network.
- Exception management.
- Suspense account handling.
- Manual journal entries with approval.

### 23. Reporting (regulator + tax)
- CTR (Currency Transaction Report) > $10k US.
- SAR (Suspicious Activity Report).
- 1099 series (interest, B for brokerage, K for marketplace, MISC).
- BSA/AML reports.
- DAC8 / CRS for crypto and cross-border data.

## Idempotency-critical endpoints

- `POST /transfers` — Idempotency-Key MANDATORY.
- `POST /payouts/withdrawals` — same.
- `POST /deposits/initiate` — same.
- Provider webhook handler for charge / payout / return — every webhook event has unique ID; dedupe.
- KYC re-submission — same submission ID returns existing result.

## Webhooks to produce

- `account.opened`, `account.frozen`, `account.closed`.
- `kyc.approved`, `kyc.rejected`, `kyc.requires_info`.
- `transaction.posted`, `transaction.settled`, `transaction.reversed`.
- `transfer.completed`, `transfer.failed`, `transfer.returned`.
- `aml.alert_opened`, `aml.alert_closed`.
- `card.issued`, `card.frozen`, `card.declined`.
- `dispute.opened`, `dispute.resolved`.

## Webhooks to consume

- BaaS provider: account events, ledger events.
- KYC provider: verification.completed, verification.required_action, sanctions.hit.
- Payment rails: ACH return, wire received, SEPA settlement.
- Card networks: authorization, capture, dispute.
- FX provider: rate updates.

## Performance + concurrency

- Posting on hot accounts (treasury, fees) needs serialization. Per-account row-lock or queue.
- Balance computation cached; reconciled against ledger sum (reconciliation job).
- Read replicas OK for statements; write to primary.
- Posting rate budget: design for peak hours (paydays, market open, salary deposits).
