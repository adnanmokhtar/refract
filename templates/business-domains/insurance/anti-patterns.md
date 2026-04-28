# Insurance — domain-specific anti-patterns

Errors here are not bugs but bad-faith claims, regulatory findings, license revocations, or lawsuits. Insurance amplifies the cost of mistakes.

## Policy lifecycle + versioning

- **Single mutable policy row.** Endorsement updates the row; claim from before endorsement now references wrong coverage. Use versioned policy snapshots; claim references version-at-loss-time.
- **Effective date stored as date only.** Coverage at "12:01am" vs "11:59pm" of effective date is ambiguous. Store full datetime + TZ; pick + document the convention (typically 12:01am local of insured's address).
- **Policy expires at "end of effective_date" with off-by-one.** Coverage gap of 1 day at renewal — claim falls through. Half-open intervals (`[effective, expiry)`).
- **Endorsement applied "now"; effective date set to today by default.** User intent often was "yesterday I bought a car" — back-date needed; auto-default mis-prices. Always require explicit effective date.
- **Cancellation effective at midnight; claim filed for 11:59pm same day.** Did claim happen during coverage? Ambiguity = bad-faith risk. Document policy + enforce.
- **Coverage at loss time computed from current state.** Endorsement removed Vehicle X yesterday; claim from last week on Vehicle X denied; insured wins lawsuit. Time-travel queries: `WHERE effective_at <= loss_at AND (expiry_at IS NULL OR expiry_at > loss_at)`.

## Premium + billing

- **Auto-pay failure → instant cancellation.** Most states require grace + notice. Regulatory violation + claim continuation lawsuits. Implement grace period per state.
- **Pro-rata refund computed on calendar days, not earned premium.** Mid-policy cancellation refund off by 5%. Document the formula; compute consistently with rate filing.
- **Short-rate refund (penalty refund) used by default.** Some states require pro-rata. Apply correctly per jurisdiction.
- **Premium recognized at billing, not earned.** Accounting wrong; loss ratio distorted. Earn over policy period.
- **Reinstatement after lapse without conditions.** Insureds let policy lapse pre-claim; reinstate; file claim from lapse period; reinstatement should typically have a "no claims during lapse" provision + sometimes a waiting period.
- **Late fee charged after grace ended.** Some states regulate late fees; charging during grace = consumer-protection violation.
- **Grace period continues coverage but isn't communicated.** Insured assumes lapse → drives without "insurance" → second policy bought → rate spike. Communicate clearly.
- **Multiple unpaid premiums; only one cancellation notice.** Each missed payment generally requires its own notice. State-specific procedures.

## Underwriting

- **Decline based on credit/insurance score without adverse action notice.** FCRA violation; class action. Always issue notice with reason + reporting agency contact.
- **Auto-decline rules without manual override path.** Edge cases drive customers to competitors; complaints about "no human."
- **Underwriting authority enforced in code only at request time.** Underwriter approves $5M risk despite $1M authority; bound; bind valid contractually + carrier on the hook. Authority enforced at bind time.
- **Risk data pulled without disclosed consent.** FCRA / GDPR violation. Explicit consent at application; honor opt-out.
- **Pre-existing condition exclusion in ACA-covered health.** Federal violation post-ACA.
- **Underwriting decision unauditable.** "Why declined?" → "engineer queried it once" → no answer in litigation. Persisted decision record with inputs + rules-fired + reasoning.
- **Application data overwritten by renewal data.** Original disclosure + signature lost. Versioned applications.

## Claims handling

- **Claim status visible only to adjuster, not customer.** Black-box experience; complaints to DOI; bad-faith risk. Self-service status timeline.
- **FNOL accepted but not assigned for days.** State acknowledgment timing missed. Auto-assign + alert.
- **Adjuster note containing customer-disparaging language.** Discoverable in litigation; reputation + bad-faith damage. Train + audit.
- **Reserve set at FNOL but never updated.** Loss-development unrealistic; reserves inadequate; surprise hit at close. Required reserve reviews at intervals.
- **Reserve mass-adjusted via SQL update.** Audit trail destroyed. Always go through workflow.
- **Coverage analysis decision not policy-cited.** Denial vague ("not covered") → bad-faith claim. Cite specific policy section + form version.
- **Denial letter using generic boilerplate.** State-specific required language missing → letter invalid, claim must reopen.
- **Claim approved verbally without documentation.** Customer disputes amount; no record; insurer pays max.
- **Document checklist not given.** Customer makes 3 partial submissions; cycle time blows out; complaints.
- **Documents accepted via unsecure email.** PHI / PII exposed; HIPAA / breach notification.
- **Claim payments via check sent to old address.** Returned mail; days lost; claimant calls DOI. Verify address + offer e-payment.
- **Subrogation never pursued.** Recovery left on table; loss ratio worse than necessary.
- **Subrogation pursued without lien holder notification.** Court order needed; case stalled.
- **Salvage value not booked.** Total loss inventory accumulates; storage fees; lost recovery.

## Coverage interpretation

- **Coverage A vs Coverage B confusion.** Auto policies: liability vs collision vs comprehensive. Mistake = wrong section paid; insureds furious.
- **Sub-limit applied as deductible.** Different math; wrong settlement.
- **Per-claim limit treated as aggregate.** Multiple claims breach aggregate but treated as fresh per-claim; overpaid.
- **Exclusion buried; not surfaced at FNOL.** Customer told claim being processed; weeks later denied for clear exclusion. Surface at intake.
- **Ambiguous policy language interpreted in carrier's favor.** Most jurisdictions: ambiguity construed against drafter (the insurer). Train; use standardized forms.

## Beneficiary changes (life)

- **Beneficiary change accepted online with no verification.** Fraud + family disputes + lawsuits. Require identity verification + sometimes notarization.
- **Most-recent beneficiary not preserved with timestamp.** Litigation: "did the deceased really change to my sibling 2 days before dying?". Versioned + signed + IP-logged.
- **Multiple primary beneficiaries with shares not summing to 100%.** Distribution unclear at claim. Validate at change time.
- **Contingent beneficiary not handled.** Primary deceased before insured; contingent should receive; system ignores.
- **Beneficiary on policy but not validated against state community property rules.** Spouse may have rights despite designation in some states; surprise lawsuit.

## Endorsements

- **Endorsement effective date back-dated to before original policy effective date.** Coverage where there was no policy. Validate.
- **Endorsement back-dated to cover a known loss.** Fraud — must be detected + denied.
- **Endorsement creating coverage gap.** Vehicle removed effective today; reinsured tomorrow; loss today not covered; insured assumed continuous.
- **Premium adjustment from endorsement double-billed.** Customer charged for vehicle add + full new premium.
- **Endorsement document not generated.** Customer requests proof of coverage change; nothing in file.

## Forms + state compliance

- **Same form for all states.** State-specific provisions missing; rate / form filing violation.
- **Form version not tracked on policy.** Carrier amends form; old policies mistakenly served new form. Lock version at bind.
- **Custom claim language not pre-filed with DOI.** Use of unfiled form = violation.
- **Cancellation sent by email when state requires certified mail.** Cancellation invalid; claim must be honored.
- **State-specific anti-fraud warning missing on claim form.** Form invalid; fraud prosecution weakened.

## Renewal

- **Auto-renewal without notice required by state.** Some states require explicit renewal notification; without it, no renewal occurred.
- **Renewal premium increase without explanation.** Some states require disclosure of rate factors causing increase >X%.
- **Non-renewal without reason where required.** State law often requires specific reason. Generic non-renewal letter = renewal continues by default.
- **Non-renewal because of one claim filed.** Some states prohibit (e.g. one not-at-fault claim). Restricted reasons need state-specific check.

## Catastrophe response

- **Surge swamps system.** Hurricane → 50x FNOL volume → app crashes. Pre-event load testing + auto-scale + staging area.
- **Adjuster auto-assignment can't keep up.** Manual override + IA-network deployment.
- **Communication channel saturated.** SMS + email + push concurrent; budget exhausted; insureds get nothing. Pre-purchased capacity from providers.
- **Coverage exhaustion not flagged.** Limits hit on aggregate; subsequent claims paid in error.

## Privacy + security

- **PHI in claim notes visible to all adjusters.** HIPAA violation. RBAC.
- **Claim file emailed to insured via plaintext.** PII exposure.
- **Adjuster downloads entire claim file to laptop.** Lost laptop = breach. DLP + thin-client + audit.
- **Customer's address visible to all internal users via search.** Domestic violence victim safety. Need-to-know access.
- **Recorded statements stored unencrypted.** Sensitive personal info; breach material.
- **Recorded statements without two-party consent in two-party-consent states.** Wiretap violation.

## Anti-fraud

- **SIU referral process undocumented.** State DOI fines for not having a program.
- **Fraud signal scoring used without explainability.** Insureds challenge denial; carrier can't show rationale; bad-faith.
- **Fraud disposition silent acceptance.** "False positive" closed with no rationale; pattern recurs; SIU misses real fraud.
- **Fraud bureau report not filed.** Mandatory in many states. Penalties.

## Producer / commission

- **Commission calculated from gross, paid on net (or vice versa) inconsistently.** Producer disputes pile up.
- **Commission paid before producer license verified.** Unauthorized practice issue.
- **Commission clawback on policy cancellation not consistent.** Producer disputes.
- **Producer book transferred without disclosure to insureds.** Customer service disruption + complaints.

## Reinsurance

- **Cession not reported timely.** Recovery delayed.
- **Catastrophe trigger met but recovery not pursued.** Money on table.
- **Treaty interpretation disagreement.** Reinsurance disputes lengthy + expensive.

## Audit + reporting

- **Statutory accounting not separated from GAAP.** Different rules; mistake = restatement.
- **Reserve sum not matching individual reserves.** Reconciliation mismatch.
- **Premium tax not allocated correctly per state.** Underpayment in one state, overpayment in another; both fines.
- **Annual statement late.** State DOI penalty; rating agency concern.
- **Schedule P (loss reserves) reconstruction from operational data.** Drift; cleanup-of-mess at year-end.

## Operational

- **Adjuster decisions delayed beyond state-acknowledgment / state-decision timing.** Bad-faith + DOI complaint.
- **Claim queue without prioritization.** High-severity claims sit; low-severity favored; unhappy claimants on big losses.
- **Adjuster authority enforced only at request submission.** Self-approval workaround possible. Server-side authority check.
- **Document retention purged at company-set 1 year.** Statute of limitations may extend 5+ years; lost evidence.
- **Cron jobs running on every node.** Duplicate notices, duplicate cancellations.
- **Test environment accessing production rate-filing service.** Quote pollution; reporting wrong.
- **Policy migration between systems loses data.** Drift; reconciliation impossible.

## Trust + UX

- **"Sorry, your claim is being processed" with no status.** Black box → frustration → DOI complaint.
- **Premium increase shown without explanation.** Lost retention.
- **Coverage explanation in legalese.** Customer doesn't understand; doesn't claim things; or files things not covered. Plain-language summary.
- **Policy document a 47-page PDF.** Customers don't read; surprised at exclusions later. Highlight key items in summary.
- **Quote process asks 100 questions before showing price.** Drop-off cliff. Progressive disclosure; show price early.
- **Mobile FNOL only available 9-5.** Accidents happen at night. 24/7.
- **Photo upload requires specific resolution.** Insureds at scene have phone-quality; reject = frustration.
- **Settlement check by mail in 2024.** Slow + lost-in-mail. ACH default; e-check; check on request.
