# Insurance — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `insurance`:

**Entity / model names**: `Policy`, `Policyholder`, `Insured`, `Beneficiary`, `Premium`, `Claim`, `ClaimDocument`, `ClaimEvent`, `Adjuster`, `Underwriter`, `Quote`, `Application`, `RiskAssessment`, `Coverage`, `Endorsement`, `Rider`, `Deductible`, `CoverageLimit`, `Renewal`, `Cancellation`, `Reinstatement`, `Lapse`, `LossEvent`, `Subrogation`, `Reserve`.

**Folder / route names**: `policies/`, `claims/`, `quotes/`, `underwriting/`, `applications/`, `adjusters/`, `policyholders/`, `/quote`, `/claim/file`, `/policy/[id]`, `/admin/underwriting-queue`.

**Dependencies**: `salesforce-financial-services`, `guidewire-bridge`, `duck-creek`, `socotra`, `lemonade-api`, `shift-technology`, `tractable` (claim images), `verisk`, `lexisnexis`, `mitchell` (auto), `xactimate` (property), `claros`, `applied-systems-tam`, `actuarial-modeling-libraries` (loss-distribution).

**Database schema**: tables for `policies` + `claims` + `premiums` + `coverages` is the strongest signal. Presence of `effective_date` + `expiry_date` on policies + claim severity / status state machines is highly indicative.

**Distinguishing from healthcare**: healthcare = clinical care delivery. Health insurance = financial coverage for healthcare. Distinguish by entity names (Policy + Premium = insurance; Encounter + Provider + Procedure = healthcare).

**Distinguishing from fintech-loans**: lending originates a debt; insurance assumes a risk. Different actuarial math, different regulators (insurance commissioners vs banking).

**Sub-domains** (each has very different requirements):
- P&C (Property & Casualty): auto, home, renters, business
- Life: term, whole, universal
- Health: ACA, Medicare, Medigap, group
- Specialty: cyber, pet, travel, event, parametric
- Reinsurance (B2B between insurers)
- Distribution / Brokerage / MGA (intermediaries)

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Quote` | preliminary offer | `id, applicant_id, product, coverage[], premium_estimate, valid_until, source (web/agent), risk_data, status` | created → bound (becomes policy) → expired |
| `Application` | formal request to bind | `id, quote_id, applicant_data, disclosures, signatures, status` | submitted → in_underwriting → approved → bound (or declined) |
| `Policy` | the contract | `id, policy_number, product, policyholder_id, insured[], beneficiary[], effective_date, expiry_date, premium_total, payment_schedule, status, document_url, version` | bound → active → renewed (new policy) / cancelled / lapsed / expired |
| `Coverage` | what's covered + limits | `id, policy_id, type (liability/collision/medical/etc), limit_amount, deductible, sub_limits, exclusions[]` | tied to policy |
| `Endorsement` / `Rider` | mid-term policy change | `id, policy_id, type, effective_date, premium_delta, change_summary, document_url` | requested → signed → effective → expired with policy |
| `Policyholder` | owns the policy | `id, name, dob, address, contact, identifiers (SSN/govt-ID)` | active |
| `Insured` | the covered party (may differ from policyholder) | `id, policy_id, name, relation_to_policyholder, dob, info_for_rating` | tied to policy |
| `Beneficiary` | who receives payout (life insurance, etc.) | `id, policy_id, name, dob, relation, share_percent, primary_or_contingent, designated_at, last_changed_at, signed_doc_url` | versioned (changes require verification) |
| `Premium` | scheduled payment | `id, policy_id, amount, currency, due_date, status, paid_at, payment_method, invoice_id` | scheduled → due → paid (or overdue → grace → lapsed) |
| `Claim` | reported loss event | `id, policy_id, claimant_id, loss_event_id, type, status, reported_at, loss_date, assigned_adjuster, reserve_amount, paid_amount, denied_reason` | reported → triaged → investigating → estimating → approved (or denied) → paid → closed |
| `LossEvent` | the incident | `id, date, location, description, witnesses, police_report_id?` | logged |
| `ClaimDocument` | evidence | `id, claim_id, type (photo/police/medical/quote/etc), uploaded_by, uploaded_at, hash, ai_analysis_result?` | submitted → reviewed → accepted / rejected |
| `ClaimEvent` / `ClaimNote` | claim audit trail | `claim_id, actor, action, before_state, after_state, note, occurred_at` | append-only |
| `Adjuster` | claim handler | `id, name, license_number, license_state, type (staff/independent), specialties[]` | active → terminated |
| `Underwriter` | risk reviewer | `id, name, authority_level, approved_lines[]` | active |
| `RiskAssessment` | pre-bind eval | `id, application_id, score, factors[], decision, notes, decided_by, decided_at` | logged |
| `Reserve` | actuarial set-aside | `id, claim_id, amount, currency, set_at, last_updated_at, reason` | open → adjusted → closed |
| `Renewal` | annual / term renewal | `original_policy_id, new_policy_id, terms_changed[], offered_at, accepted_at, lapsed_at` | offered → accepted (new policy bound) / declined / lapsed |
| `Cancellation` | early termination | `policy_id, requested_by, requested_at, effective_at, reason, refund_amount, fee_charged` | requested → effective |
| `Lapse` | non-payment termination | `policy_id, lapsed_at, grace_ended_at, reinstatement_window_ends_at` | flag on policy |
| `Reinstatement` | restoring lapsed policy | `policy_id, requested_at, granted_at, conditions, additional_premium` | requested → granted (or denied) |
| `Subrogation` | recovery from third party | `claim_id, defendant, status, recovery_amount, recovered_at` | open → recovered / closed |
| `FraudFlag` | anti-fraud signal | `claim_id, signal_type, score, details, reviewer_decision, decided_at` | open → cleared / confirmed |
| `Payout` | settlement payment | `id, claim_id, payee, amount, method, status, paid_at` | scheduled → paid (or returned) |
| `Producer` / `Agent` / `Broker` | distribution party | `id, license_number, appointed_by, commission_rate, principal_or_independent` | active → terminated |

## Status state machines

**Policy:**
```
quoted → applied → in_underwriting → bound → active → expiring → renewed
                          ↓                       ↓
                      declined                cancelled / lapsed
                                                    ↓
                                              reinstated (window)
```

**Claim:**
```
reported (FNOL) → triaged → investigating → estimating → approved → paid → closed
                                ↓                            ↓
                          requires_more_info             denied → appealed → reopened
                                ↓                            ↓
                            withdrawn                   litigated
```

**Premium:**
```
scheduled → due → paid
              ↓
          overdue → grace_period → lapsed → reinstated (or terminated)
```

**Application:**
```
draft → submitted → in_underwriting → approved → bound
                          ↓
                  requires_info → resubmitted → in_underwriting (loop)
                          ↓
                     declined / withdrawn
```

**Endorsement:**
```
requested → quoted → signed → in_force → expired (with policy)
                  ↓
              declined / withdrawn
```

## Vocabulary distinctions (don't conflate)

- **Policyholder** vs **Insured** vs **Beneficiary** — Policyholder owns the contract + pays premiums. Insured is the covered party (may differ; e.g. parent owns life policy on child). Beneficiary receives payout on death/loss. All three may differ.
- **Claimant** — whoever files the claim. May or may not be the policyholder (third-party liability claimant).
- **Coverage limit** vs **Deductible** vs **Sub-limit** vs **Out-of-pocket maximum** — Limit is the max insurer pays. Deductible is what insured pays first. Sub-limit caps a category within a coverage. OOP max applies to certain health insurance models.
- **Premium** vs **Policy fee** vs **Surcharge** — Premium is the actuarial price for risk. Fees + surcharges are non-actuarial line items (often regulated separately).
- **Loss** vs **Claim** vs **Loss event** — Loss event is the incident (e.g. car accident). Claim is the formal request for payment. A single loss event can produce multiple claims (claimant, third party).
- **Reserves** vs **Paid losses** — Reserves are estimated future payouts on open claims (set by adjuster). Paid is what's been disbursed.
- **Actual cash value (ACV)** vs **Replacement cost** — ACV: depreciated value at time of loss. Replacement: cost to replace with new. Matters in P&C settlement.
- **Subrogation** vs **Salvage** — Subrogation: insurer recovers from at-fault third party after paying insured. Salvage: insurer takes title to damaged property after total loss + sells.
- **Lapse** vs **Cancellation** vs **Non-renewal** — Lapse: silent expiry due to non-payment. Cancellation: termination (by insured or insurer). Non-renewal: insurer doesn't offer to renew at expiry. Each has different regulatory treatment + customer notification rules.
- **First Notice of Loss (FNOL)** — initial claim report. Often the first interaction; UX critical.
- **Underwriting** vs **Rating** — Rating computes the price for a known risk (formulas). Underwriting decides whether to accept the risk at all (judgment + rules).
- **Endorsement** vs **Renewal** — Endorsement is a mid-term change (add a driver, increase limit). Renewal is a new term.
- **Term life** vs **Whole life** vs **Universal life** — Term: temporary, no cash value. Whole: permanent + cash value + fixed premium. Universal: permanent + flexible + investment component.
- **Auto-pay** vs **Premium audit** vs **Mid-term audit** — Insurance has sophisticated billing models; "auto-pay" alone is a simplification.

## Multi-tenancy variants

- **Direct carrier**: insurer underwrites + holds risk + handles claims. Tenant boundary at customer + maybe agency.
- **MGA / MGU** (Managing General Agent / Underwriter): handles underwriting + sometimes claims on behalf of carrier. Tenant per principal carrier.
- **Brokerage / Agency**: distribution channel. Tenant per client.
- **Reinsurance**: B2B between insurers; very different model (treaty + facultative).
- **InsurTech platform / API**: powers multiple downstream insurance products. Tenant per product or carrier.

## Money + actuarial

- Premium = risk_factor * coverage_amount * exposure_period + fees + taxes.
- Loss ratio = paid_losses / earned_premiums (key insurer KPI).
- Combined ratio = loss ratio + expense ratio (under 100% = profitable underwriting).
- Reserves are recorded as liabilities; paid claims debit reserves.
- Premium recognition: earned over policy period (not at receipt). Unearned premium = liability.
- Catastrophic / aggregate reinsurance affects reported losses.

## Multi-state / multi-country complexity

- US insurance regulated state-by-state (50 different sets of rules + filings).
- Form filings + rate filings: insurers must file forms with state DOI; some prior-approval, some file-and-use, some use-and-file.
- Surplus lines: non-admitted carrier; different rules + tax.
- EU: cross-border via passporting (if licensed in one EU state).
- License required to bind in each jurisdiction.
