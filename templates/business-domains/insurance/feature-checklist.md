# Insurance — feature checklist

What every insurance system needs. v1s usually under-build the claims workflow + over-build the front-of-funnel quote tool — losing money on the back-end.

## Policyholder-facing

### Quote + apply
- [ ] Quote tool with progressive disclosure (don't ask everything upfront).
- [ ] Save partial quote (resume later).
- [ ] Multiple coverage option comparison (good/better/best).
- [ ] Add-on coverage (riders, endorsements).
- [ ] Real-time premium calculation as inputs change.
- [ ] Bundle pricing (multi-line discount).
- [ ] Pre-fill from prior policy / data sources (with consent).
- [ ] Application with required disclosures clearly displayed.
- [ ] E-signature with witnessed timestamp + IP.
- [ ] Identity verification (KYC).
- [ ] Decline handling with referral path (declined for one product → suggest others).

### Policy management
- [ ] Policy dashboard with declarations, coverage, premium, payment plan.
- [ ] Document library (declarations, endorsements, claims documents, ID cards).
- [ ] Download / print declarations + ID card.
- [ ] Mid-term change requests (add/remove vehicle, change limits, address change).
- [ ] Endorsement quote + accept flow.
- [ ] Beneficiary update (life insurance) with verification step.

### Billing
- [ ] Auto-pay setup (card / ACH / EFT).
- [ ] Payment plan options (annual / semi-annual / quarterly / monthly).
- [ ] View invoices / past payments.
- [ ] Make a payment.
- [ ] Pay in full discount (typical 3-8%).
- [ ] Late notice + grace status visibility.
- [ ] Payment history.

### Claims (the moment of truth)
- [ ] Easy FNOL: photos, video, voice description.
- [ ] Mobile-first (most reports happen at the scene).
- [ ] Estimate provided quickly (instant if photo-driven).
- [ ] Claim status timeline (no "we'll call you" black box).
- [ ] Document upload requests with checklist.
- [ ] Adjuster contact info + scheduled appointments.
- [ ] Repair shop network selection (auto).
- [ ] Direct deposit setup for payouts.
- [ ] Track payout.

### Communication
- [ ] Notification preferences (email, SMS, app push).
- [ ] Status update cadence per claim.
- [ ] Renewal reminder (60+ days advance).
- [ ] Policy expiration warnings.

### Account
- [ ] Sign in / forgot password / 2FA.
- [ ] Profile + contact info.
- [ ] Multiple policies under one account (auto + home + life).
- [ ] Household members (drivers, dependents, named insureds).
- [ ] Payment methods.
- [ ] Communication preferences.

## Producer / Agent-facing (if distribution channel)

- [ ] Book of business.
- [ ] Quote / bind on behalf of clients.
- [ ] Commission tracking.
- [ ] Renewal book + alerts.
- [ ] Lead pipeline.
- [ ] Production reports (NWP, NB, retention).
- [ ] License + appointment status.

## Underwriter / Operator-facing

### Underwriting
- [ ] Application queue with priority.
- [ ] Risk analysis dashboard.
- [ ] Data pull viewer (MVR, CLUE, credit, property).
- [ ] Decision interface with policy citation.
- [ ] Authority limits + escalation.
- [ ] Decline with documented reason.
- [ ] Bound policy verification.

### Claims (the operator workhorse)
- [ ] FNOL queue with triage.
- [ ] Auto-routing by line / region / specialty.
- [ ] Adjuster workbench: claim, documents, communications, notes, financial.
- [ ] Document request workflow.
- [ ] Estimating tools integration (Mitchell, CCC, Xactimate).
- [ ] Coverage analysis with policy citation.
- [ ] Reserve management.
- [ ] Approval workflow + authority limits.
- [ ] Denial letter generation with state-specific compliance.
- [ ] Payment authorization.
- [ ] Subrogation tracking.
- [ ] Salvage tracking.
- [ ] SIU (Special Investigations Unit) referral.
- [ ] Litigation management.

### Policy administration
- [ ] Policy lookup with full version history.
- [ ] Endorsement processing.
- [ ] Cancellation with proper notice generation.
- [ ] Reinstatement workflow.
- [ ] Renewal management.
- [ ] Form / document version control (rate filings tied).

### Finance + actuarial
- [ ] Loss ratio reports.
- [ ] Reserve adequacy.
- [ ] Reinsurance cession + recovery.
- [ ] Premium accruals.
- [ ] Statutory reporting (Schedule P, etc.).
- [ ] Tax filings.

### Compliance
- [ ] State filing tracker (rates + forms).
- [ ] Regulatory complaint handling.
- [ ] Annual statement / quarterly statement preparation.
- [ ] Fraud bureau reporting.
- [ ] Producer licensing tracking.

### Reports
- [ ] Loss ratio by line / state / class.
- [ ] Combined ratio.
- [ ] Retention rate.
- [ ] New business mix.
- [ ] Reserve trends.
- [ ] Claim cycle time.
- [ ] Litigation rate.
- [ ] Producer production.

## Trust + compliance

- [ ] HTTPS site-wide.
- [ ] Privacy + terms + state-required disclosures.
- [ ] State-specific consumer notices (right to access info, opt-out, etc.).
- [ ] Cookie banner.
- [ ] FCRA-compliant adverse action notice (when declining for credit/data reasons).
- [ ] HIPAA mode for health/life insurance touching PHI.
- [ ] GDPR / CCPA data subject rights.
- [ ] Audit log of every decision (claim, underwriting, cancellation).
- [ ] Document retention per state schedule.
- [ ] Cybersecurity per NYDFS Part 500 / state requirements.
- [ ] PCI for card payments.
- [ ] Anti-fraud disclosures + fraud-bureau-required language.

## Operational

- [ ] State-specific form templates (declarations, denials, cancellations).
- [ ] Rate-engine versioning aligned with rate filings.
- [ ] DR/BCP for catastrophic events (carrier must keep paying claims during a hurricane).
- [ ] Surge capacity for catastrophe FNOL (Hurricane → 50x normal claim volume).
- [ ] Reinsurance API integration.
- [ ] Carrier-of-record transitions (when policies move).
- [ ] Audit-trail-ready exports.

## Things v1s commonly miss

- State-by-state form variations — generic forms don't pass DOI.
- Grace period handling — premium failure → instant cancellation = regulatory violation.
- Adverse action notices when declining — FCRA / state law requirement.
- Specific decline reasons in policy citations — bad-faith litigation magnet without them.
- Coverage at loss time vs current — claim from 6 months ago needs the policy state at that time.
- Proper notice generation for cancellation/non-renewal (timing + content state-specific).
- Beneficiary changes without verification — fraud vector + family disputes.
- Policy version preservation — endorsement history lost after upgrade.
- Premium recognition (earned vs unearned) — accounting wrong.
- Reserve accounting — claims booked as paid + reserves missing → loss ratio distorted.
- Document version control — policy form referenced in claim is the wrong version.
- Subrogation tracking — recoveries leaked.
- Claim status transparency — "your claim is being processed" → angry customers + complaints.
- FNOL outside business hours — peak times for accidents are evenings/weekends; bot/portal must work 24/7.
- Mobile FNOL with photo upload — biggest UX gap; insureds at the scene of an accident need this.
- Catastrophe handling — hurricane hits, FNOL volume 50x; system collapses.
- Producer commission accounting — incorrect = agent disputes + churn.
- Renewal pricing transparency — "your premium went up because [actuarial reason]" required in some states.

## Things often over-built in v1

- AI fraud scoring (start with rules + manual review).
- Complex bundle pricing (start single-product).
- Telematics integration (third-party data + opt-in is sufficient).
- Full agent CRM (light agent portal first).
- Reinsurance system integration (manual quarterly reporting works initially).
- Multiple billing currencies (most insurance is country-specific).
- Real-time catastrophe modeling (annual exposure aggregation works for v1).
- Custom rating engine (start with vendor like Earnix / Verisk ISO).
