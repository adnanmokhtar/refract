# Fintech — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `fintech`:

**Entity / model names**: `Account`, `Wallet`, `Balance`, `Ledger`, `LedgerEntry`, `Posting`, `Transaction` (with `debit/credit`), `Transfer`, `Payment`, `Beneficiary`, `Counterparty`, `KYC`, `KYB`, `Verification`, `RiskScore`, `SanctionsHit`, `Limit`, `Hold`, `Authorization`, `FxRate`, `FxConversion`, `Settlement`, `Reconciliation`, `Statement`, `Card`, `Mandate`, `Direct Debit`.

**Folder / route names**: `accounts/`, `wallets/`, `transfers/`, `ledger/`, `kyc/`, `compliance/`, `aml/`, `sanctions/`, `cards/`, `/transfer`, `/account/[id]/statement`, `/admin/aml-queue`.

**Dependencies**: `decimal.js`, `bignumber.js`, `dinero.js`, `currency.js`, `js-money`, `plaid`, `stripe-treasury`, `stripe-issuing`, `unit-co`, `bond-fintech`, `rapyd`, `wise-api`, `dwolla`, `marqeta`, `lithic`, `fireblocks` (crypto), `chainlysis`, `sumsub`, `onfido`, `persona`, `comply-advantage`, `socure`, `alloy`.

**Database schema**: tables for `ledger_entries` with `debit_account_id` + `credit_account_id` is the strongest signal. `accounts` + `transactions` + `kyc_verifications` is highly indicative.

**Distinguishing from generic ecommerce/marketplace**: ecommerce/marketplace touch payments but the operator is not the financial institution. Fintech operates the account itself: holding, lending, transferring funds. The presence of `Account` (with balance) + double-entry ledger + KYC is the line.

**Sub-domains** (each shapes the data model):
- Neobank / digital banking
- Payments processor / PSP
- Money transfer / remittance
- Lending / BNPL / installments
- Investing / brokerage / robo-advisor
- Insurtech (see `insurance/`)
- Wallet / e-money / stored value
- Crypto exchange / custodian (additional rules)
- B2B AP / AR (accounts payable / receivable)

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `User` / `Customer` | the natural person or entity | `id, kind (individual/business), email, phone, primary_country, status, kyc_level` | applied → active → suspended → closed |
| `KYCVerification` | identity proof | `user_id, level (basic/full/enhanced), provider, status, documents[], decision, reviewer_id, completed_at, expires_at` | submitted → in_review → approved / rejected / requires_info |
| `Account` | the funded entity | `id, owner_id, type (checking/savings/wallet/escrow/loan), currency, status, opened_at, balance_minor, available_minor, subtype` | open → frozen → closed |
| `LedgerEntry` / `Posting` | atomic accounting record | `id, account_id, amount_minor, currency, direction (debit/credit), transaction_id, posted_at, balance_after_minor, idempotency_key, metadata` | posted (immutable) — corrections via reversal entries, never edits |
| `Transaction` | logical financial event grouping ledger entries | `id, type (deposit/withdrawal/transfer/fee/fx/refund/interest/chargeback), status, amount, currency, originator_id, counterparty_id, description, posted_at, settled_at` | initiated → pending → posted → settled (or rejected / reversed) |
| `Hold` / `Authorization` | reserved (not yet posted) amount | `id, account_id, amount_minor, currency, reason, expires_at, status` | placed → captured → released (or expired) |
| `Transfer` | money moved between accounts | `id, from_account_id, to_account_id, amount, currency, fee, fx_rate?, status, scheduled_for, executed_at, idempotency_key` | scheduled → in_progress → completed (or failed / returned) |
| `Counterparty` / `Beneficiary` | external entity | `id, name, type (individual/business), country, account_number_token, bank, currency, kyc_status, sanctions_status, added_at` | active → archived |
| `Card` | payment instrument | `id, account_id, kind (debit/credit/prepaid/virtual), pan_token, last4, expiry, network, status, daily_limit_minor` | issued → active → frozen → cancelled |
| `Mandate` / `DirectDebit` | recurring authorization | `id, payer_account_id, payee_id, amount_pattern, max_amount, frequency, status, signed_at, expires_at` | pending → active → cancelled / expired |
| `FxRate` | conversion rate | `id, base_ccy, quote_ccy, rate, source, captured_at, valid_until` | live → expired |
| `FxConversion` | one applied conversion | `id, transaction_id, from_amount_minor, from_ccy, to_amount_minor, to_ccy, rate, fee, executed_at` | logged immutably |
| `Limit` | per-user / per-tx caps | `user_id, kind (daily/monthly/per_transaction), amount_minor, currency, applies_to (transfer/withdrawal/deposit)` | active rule |
| `RiskScore` | live ML score | `user_id, score, model_version, computed_at, signals[]` | recomputed on event |
| `SanctionsHit` | screening result | `user_id, list (OFAC/EU/UN), match_score, matched_record, status (false_positive/escalated/blocked), reviewed_by, reviewed_at` | open → resolved |
| `AMLAlert` | suspicious activity flag | `id, user_id, type (structuring/velocity/high_risk_country/etc), severity, signals, status (open/escalated/closed/sar_filed), assigned_to` | open → resolved |
| `Statement` | periodic account summary | `account_id, period_start, period_end, opening_balance, closing_balance, transactions[], generated_at, pdf_url` | finalized (immutable per period) |
| `Reconciliation` | external sync match | `external_source, external_id, internal_transaction_id, status (matched/unmatched/exception), reconciled_at` | matched → exception |
| `Reversal` | corrective entry | `original_transaction_id, reversal_transaction_id, reason, posted_at` | logged |
| `Chargeback` / `Dispute` | inbound dispute on a card transaction | `id, transaction_id, network_case_id, reason_code, amount, status, deadline_at, evidence[]` | initiated → response_due → won / lost / accepted |
| `Webhook` | provider event log | `provider, event_id, type, payload, received_at, processed_at, status` | received → processed |

## Status state machines

**KYC:**
```
submitted → in_review → approved
                ↓
            rejected → resubmitted → in_review (loop)
                ↓
       requires_more_info → resubmitted
```

**Transaction:**
```
initiated → pending → posted → settled
              ↓          ↓
          rejected   reversed (reversal entries posted)
```

**Transfer:**
```
scheduled → in_progress → completed
                ↓             ↓
            failed         returned (NACHA / SEPA return after settlement)
                              ↓
                          reversed
```

**Hold / Authorization:**
```
placed → captured (becomes posting) → released
   ↓
expired (TTL, returns funds to available)
```

**AML alert:**
```
open → assigned → in_review → closed (false positive)
                       ↓             ↓
                  escalated      sar_filed
```

**Account:**
```
applied → opened → active → frozen → closed
                      ↓                ↓
                  restricted       under_legal_hold
```

## Vocabulary distinctions (don't conflate)

- **Available balance** vs **Posted balance** vs **Pending balance** — Posted = sum of settled postings. Pending = unsettled (in-flight transfers). Available = posted + cleared - holds. Different queries return different numbers; UI must specify.
- **Authorization / Hold** vs **Capture** vs **Settlement** — Card flow: auth (reserve) → capture (commit) → settle (funds move). Each is a distinct event with its own lifecycle.
- **Debit** vs **Credit** in double-entry — Debits and credits are NOT the same as "money out" and "money in." On a customer's deposit account: a customer deposit = credit to customer account (their balance grows) AND debit to operator's cash account. Stop thinking of debit/credit as good/bad.
- **T-account** — visualization: left side = debits, right side = credits. Account balance = sum of credits − sum of debits (for asset accounts) OR debits − credits (for liability/equity).
- **Posting** vs **Entry** vs **Transaction** — A transaction has 2+ postings. Each posting hits one account. Total debits = total credits in every transaction (the invariant).
- **Reversal** vs **Refund** vs **Chargeback** — Reversal: internal correction (we made a mistake). Refund: voluntary repayment. Chargeback: forced reversal via card network or ACH return.
- **NACHA return** (US ACH) — recipient bank rejects the ACH (insufficient funds, account closed, etc.); reversal must be processed within window.
- **SEPA recall / return** (EU) — analogous to ACH return.
- **Settlement** vs **Clearing** — Clearing: agreed-upon transaction. Settlement: actual funds movement.
- **Same-currency transfer** vs **FX transfer** vs **Cross-border** — Each requires different rails, different fees, different KYC triggers.
- **Open Banking / PSD2 AISP / PISP** — AISP (Account Information Service Provider) = read access to user's bank data. PISP (Payment Initiation Service Provider) = move money on user's behalf.
- **Customer due diligence (CDD)** vs **Enhanced due diligence (EDD)** — CDD baseline; EDD for higher risk (PEPs, high-amount, certain countries, certain industries).
- **Beneficial owner / UBO** — natural person ultimately owning ≥25% of a business; KYB requires identifying them.
- **Funds flow on rails** — ACH (US), Fedwire (US), RTP (US realtime), SEPA (EU), Faster Payments (UK), CHAPS (UK), SWIFT (international), card networks (Visa/MC). Each has its own settlement window, fee, dispute, and reversal rules.

## Multi-tenancy variants

- **Bank-as-a-Service (BaaS) provider** (Stripe Treasury, Unit, Bond): operator builds on top of regulated bank's APIs. Tenant boundary at customer level; underlying bank handles regulation.
- **Direct-licensed neobank**: operator IS the regulated entity. No tenant; customer = end-user.
- **Multi-tenant fintech SaaS** (e.g. expense management for SMBs): tenant = company; users = employees of that company.
- **B2B platform**: tenant = each business customer; their counterparties are external.

## Money representation

The single most error-prone area in fintech:

- ALWAYS store amounts as integer minor units in a "smallest unit" field: `amount_minor: 1234` for $12.34.
- ALWAYS store currency code (ISO 4217) alongside: `currency: "USD"`.
- NEVER use floats. `0.1 + 0.2 != 0.3`.
- For arithmetic: use a money library (`dinero`, `js-money`, `currency.js`) OR `BigDecimal` / `Decimal` types.
- For display: format using locale + currency-aware library (`Intl.NumberFormat`).
- For storage size: `bigint` in DB (some currencies have small minor units like JPY = 0; some have large = IQD with 3 decimals).
- For FX: store both amounts (from + to) + the rate + the source, NEVER recompute on display.
- For percentages (rates, fees, interest): store as basis points (`int`) — `250` = 2.50% — to avoid float rounding.
