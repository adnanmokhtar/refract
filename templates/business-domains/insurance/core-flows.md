# Insurance — core flows

The flows every insurance product must support. P1 = "without these, you can't bind or pay claims." P2 = retention. P3 = competitive depth.

## P1 — must-have for v1

### 1. Quote → application → underwriting → bind

```
Applicant fills info (often pre-filled from a quote tool)
  → product-specific risk data: vehicle (auto), property (home), health (life)
  → underlying data pulls (with consent): MVR (driving), property reports, prior loss history (LexisNexis CLUE), credit-based insurance score
  → rating engine computes premium for proposed coverage
  → quote presented; applicant accepts or modifies
  → application submitted with disclosures + e-signature
  → underwriting:
       auto-bind if all rules pass (e.g. no prior losses, clean MVR, etc.)
       referred to underwriter if exceptions (high-risk indicators, declined-class, manual review)
       declined if uninsurable
  → on bind:
       Policy created (status=active, effective_date, expiry_date)
       first premium charged (or scheduled per payment plan)
       policy documents (declarations, coverage forms) generated + sent
       confirmation to applicant + producer (if any)
```

Critical invariants:
- **Quote is non-binding** until application + underwriting completed. Disclose this.
- **Effective date** must be ≥ today (or per state-specific rules; some allow back-date with conditions).
- **Coverage doesn't apply before bind + first premium received** (in most products). Document the binding rule.
- **Disclosures collected with timestamp + IP + signed copy** retained for litigation.
- **Risk data pulls require explicit consent** (FCRA in US, GDPR in EU).
- **Rating factors locked at bind time** — same risk, same answers, same rate (premium audit can adjust later if data was wrong).

### 2. Premium billing + collection

```
Policy bound; payment plan selected (annual / semi-annual / monthly)
  → first premium charged immediately
  → schedule subsequent premiums per plan
  → each due date:
       attempt charge (auto-pay) OR send invoice
       on success: posting; status=paid
       on failure: notify; retry per policy; enter grace period
  → grace period (varies by line + state, commonly 10-31 days):
       coverage continues (in most lines)
       ongoing collection attempts
       if still unpaid at grace end: notice of cancellation per state law
       lapse: policy.status = lapsed; coverage ends
  → if reinstated within reinstatement window: policy reactivates with conditions
```

Critical invariants:
- **Grace period required by law in most lines + states**. Hard-fail-on-day-1 = regulatory violation.
- **Cancellation notice by mail (often certified)** — state-specific timing (10, 20, 30 days advance). Email may or may not satisfy.
- **Claims during lapse** generally not covered, BUT some states require "actual notice" before deny. Check.
- **Insurer-initiated cancellation** has more restrictive rules than insured-initiated.

### 3. First Notice of Loss (FNOL)

```
Insured / claimant reports loss:
  → policy validated (active at loss date, coverage applies)
  → claim record created (status=reported)
  → unique claim number generated
  → policyholder + claimant info captured
  → loss details: date, location, description, parties involved, injuries, photos
  → triage:
       severity / complexity scoring
       fraud signals (suspicious indicators)
       assigned to adjuster (auto-routed by line / region / specialty)
  → reserve set (initial estimate of total payout)
  → acknowledgment sent (email + SMS + letter per state requirements)
  → SLA clock starts (each state regulates "fair claims practices" timing)
```

Critical invariants:
- **State-by-state FNOL requirements**: some require acknowledgment within X days, others require status updates every X days.
- **Coverage at loss date** is what governs (NOT today's policy state). Time-travel queries.
- **Reserves are required for solvency reporting** — must be set at FNOL with actuarial discipline.
- **Claim cannot exceed coverage limits** (subject to interpretation in policy language; ambiguity = bad faith risk).

### 4. Claim investigation + decision

```
Claim assigned to adjuster:
  → contact insured / claimant within state-specific deadline
  → request documents (photos, police report, medical, repair estimates, etc.)
  → site inspection (P&C); medical records review (life/health); recorded statements as needed
  → fraud check (rules + analytics)
  → estimate damage / loss
  → coverage analysis: is this covered? Limits? Deductible? Exclusions?
  → decision:
       approved (in full or part)
       denied (with specific reason + policy citation)
       referred to litigation
  → notification with appeal rights
```

Critical invariants:
- **Decision rationale documented** with specific policy citation. Bad-faith litigation in US is real and expensive.
- **Decision audit trail** — who decided, when, based on what.
- **Appeal / reopen flow** required.
- **Denial letter content** governed by state law (specific language, cites, appeal rights).

### 5. Settlement + payout

```
Approved claim:
  → settlement amount computed (loss - deductible, capped by limits, less salvage)
  → release / agreement signed by insured / claimant
  → payment issued (check, ACH, virtual card)
  → posting:
       reserve reduced
       paid losses booked
       loss ratio metrics update
  → claim status = paid
  → close after final payment + post-claim follow-up window
  → subrogation initiated if at-fault third party identified
```

Invariants:
- **Settlement amount frozen at agreement**. Re-opening is exceptional.
- **Lien/garnishment honored** (some claims subject to medical liens, court orders).
- **Tax reporting**: 1099-MISC for some payouts; 1099-LTC for long-term care; etc.

### 6. Policy renewal

```
Renewal trigger (e.g. 60 days before expiry):
  → re-rate based on current data (loss history, updated info)
  → renewal offer generated (may include premium change + term change)
  → notice sent per state law (timing + content regulated)
  → insured accepts → new policy bound, effective at expiry of old
  → insured declines OR doesn't respond → policy lapses at expiry
  → insurer non-renews → required notice with reason
```

Invariants:
- **Non-renewal notice timing** state-regulated (typically 30-60 days advance).
- **Reasons for non-renewal** sometimes restricted (cannot non-renew solely for filing a claim in some states).
- **Renewal premium changes >X%** often require additional disclosure.
- **Continuous coverage** — old policy expires the same instant new one starts (no gap).

### 7. Policy endorsement (mid-term change)

```
Insured requests change (add vehicle, add driver, change limits, change address):
  → impact analysis: premium change, eligibility change
  → endorsement quoted
  → if change material (vehicle add, etc.): underwriting may re-check
  → endorsement signed + bound; effective date set
  → premium adjustment: pro-rated charge or refund
  → endorsement document generated + sent
  → policy version incremented
```

Invariants:
- **Effective date can be back-dated** in some cases (within rules); requires audit + confirmation.
- **Pro-rata calculations** must use the right basis (calendar days vs effective period).
- **Old endorsements + policy version preserved** — claim from before this endorsement uses old policy.

## P2 — retention + completeness

### 8. Self-service policy management
- View declarations + coverage forms.
- Download ID card / pink slip / certificate of insurance.
- Update contact / payment info.
- Add / remove vehicles, drivers, properties.
- Change deductibles + limits (with re-rating).
- View bills + pay.
- Set up auto-pay.

### 9. Claim self-service
- File FNOL with photos / video.
- Track claim status with milestones.
- Upload requested documents.
- View payment history.
- Communicate with adjuster.

### 10. Telematics / IoT (auto, home)
- Device installation + data ingestion.
- Driving / occupancy data → rating adjustments.
- Real-time alerts (theft, breakdown, leak).
- Privacy disclosure + opt-out.

### 11. Cancellation / non-renewal flow
- Insured-initiated: confirm, calculate refund, process.
- Insurer-initiated: notice generation per state.
- Refund: pro-rata or short-rate (with cancellation fee).
- Final accounting + receipt.

### 12. Producer / agent portal
- Quote / bind on behalf of clients.
- Commission tracking.
- Book of business.
- Renewal alerts.
- Production reports.

### 13. Reporting + analytics
- Loss ratio by line / region / class.
- Combined ratio.
- New business vs renewals.
- Claim severity distribution.
- Reserve adequacy.
- Reinsurance recoveries.

## P3 — sophistication + scale

### 14. Multi-line bundling
- Auto + home + umbrella = bundle discount.
- Single billing with split coverage.
- Cross-line endorsements.

### 15. Advanced fraud detection
- Rules-based (keyword, claim pattern).
- ML/scoring (claim graph, prior claims, providers).
- Photo/document forensics.
- SIU (Special Investigations Unit) workflow.
- State fraud bureau reporting (mandatory in many states).

### 16. Reinsurance integration
- Treaty assumption / cession.
- Facultative placement.
- Loss reporting to reinsurer.
- Recovery accounting.

### 17. Catastrophe management
- Pre-event: exposure aggregation, modeling.
- Event: surge handling (claim volume), mass-comm to insureds.
- Post-event: ALAE / ULAE allocation, reinsurance triggers.

### 18. AI-assisted claims
- Photo damage assessment (auto, property).
- Document extraction (medical bills, repair estimates).
- Predictive severity scoring.
- Automated routing.

### 19. Embedded insurance
- Insurance offered at point of related purchase (rental car, ticket, mortgage).
- API + iframe + co-branded.
- Real-time underwriting + bind.

### 20. Parametric products
- Trigger-based payouts (weather, flight delay, earthquake magnitude).
- Oracle data integration.
- Automated payment without claim adjustment.

### 21. Group / employer-sponsored
- Master policy with employee enrollment.
- Open enrollment periods.
- Payroll deduction integration.
- Beneficiary designation tracking.

## Idempotency-critical endpoints

- `POST /policies/bind` — Idempotency-Key required; double-binding = double premiums.
- `POST /claims` — FNOL retried; same claim returned, not duplicate.
- `POST /payments` — premium retries.
- `POST /payouts` — claim payment retries.
- `POST /endorsements` — re-submission returns existing endorsement.

## Webhooks to produce

- `quote.generated`, `quote.expired`.
- `application.submitted`, `application.declined`.
- `policy.bound`, `policy.cancelled`, `policy.lapsed`, `policy.renewed`.
- `endorsement.applied`.
- `claim.fnol`, `claim.assigned`, `claim.documents_received`, `claim.approved`, `claim.denied`, `claim.paid`, `claim.closed`.
- `premium.paid`, `premium.failed`.
- `fraud.flagged`.

## Webhooks to consume

- Payment provider: charge / refund.
- Data providers (LexisNexis, Verisk, MVR): risk reports.
- Telematics: trip / sensor data.
- Document providers (DocuSign): signature events.
- AI providers: damage assessments, fraud signals.
- Bank/ACH: payment results.

## Time invariants

- **Policy effective period**: half-open `[effective_date, expiry_date)` — coverage applies on effective_date through expiry_date - 1 instant.
- **Coverage at loss time** uses the policy version IN FORCE at that time, NOT current.
- **Premium accrual**: earned over policy period; unearned = days remaining / total days.
- **Retroactive endorsements**: allowed in some lines (back to policy effective date for missed-info corrections); strictly logged.
- **Statute of limitations on claims**: state-by-state for various types (typically 1-6 years from loss date).
