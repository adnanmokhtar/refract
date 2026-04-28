# Insurance — stakeholders

Insurance has more layered stakeholders than most domains: policyholders, claimants (often different), agents/brokers, adjusters, underwriters, reinsurers, regulators, plus medical/legal/repair networks. Each has hard veto power over claim decisions.

## Policyholder

The buyer + premium-payer.

**Workflows:**
- Shop / quote.
- Apply + bind.
- Pay premium.
- Manage policy (changes, renewals).
- File claim (when needed).
- Renew or shop competitor.

**Pain points the system must solve:**
- "What does this policy actually cover?" — coverage + exclusion clarity in plain language.
- "Why did my premium go up?" — explanation of rate factors.
- "Will this be covered?" — pre-loss eligibility check (some products offer this).
- "Why did you deny my claim?" — specific reason citing policy section.
- "When will I be paid?" — claim status visibility with milestones.
- "Is my agent on my side or yours?" — independent vs captive distinction.

**Sub-types:**

### Personal lines (auto, home, renters, life)
- Cares about: low premium, quick claim, mobile access.
- Pain: confusing policy language, slow claims, surprise renewal increases.

### Small business
- Cares about: certificate of insurance for contracts, multi-line bundling, BOP (Business Owner's Policy).
- Pain: producer disengagement, claim-handling delays affecting operations.

### Mid-market commercial
- Cares about: dedicated risk control, loss-prevention services, broker relationship.
- Pain: claim handling for complex losses, reinsurance disclosures.

### Specialty / high-net-worth
- Cares about: white-glove service, valuables coverage, concierge claims.
- Pain: ordinary claim friction.

**KPIs:**
- Quote-to-bind rate.
- Retention / renewal rate.
- Claims satisfaction.
- NPS.
- Time to first decision.
- Time to payout.

## Claimant

The party requesting claim payment. Often the policyholder; sometimes a third party (liability) or a beneficiary (life).

**Distinct workflow needs:**
- Third-party liability claimant: NOT the policyholder; has limited information about coverage; may be adversarial.
- Beneficiary: receiving life-insurance payout after policyholder's death; emotional + bureaucratic moment; needs sensitivity.

**Pain points:**
- "I don't know what to do" — guidance, not just forms.
- "You're representing the other driver, not me" — third-party claimants distrust insurer.
- "I provided what you asked; why do you need more?" — document checklist + status.

## Producer / Agent / Broker

The distribution channel. Independent agents represent multiple carriers; captive agents represent one. Brokers represent the client.

### Captive agent (State Farm, Allstate model)
- Cares about: company tooling, leads, commission, benefits.
- Pain: limited carrier options for clients who don't fit underwriting.

### Independent agent
- Cares about: multi-carrier comparison rater, commission, easy book transfer.
- Pain: carrier-by-carrier portals, integration friction.

### Broker (commercial, larger accounts)
- Cares about: market access, knowledge depth, relationship management.
- Pain: time spent on data entry; carrier portal fragmentation.

### MGA (Managing General Agent)
- Cares about: bind authority, carrier support, profitability.
- Pain: carrier authority changes, technology gaps.

**Operator dashboards:**
- Book of business.
- Lapsed / non-renewed.
- Production this month / quarter.
- Commission accruals.
- Renewals upcoming.
- Loss ratio (visibility into book quality).

**KPIs:**
- Quote conversion.
- Bind rate.
- Retention.
- Loss ratio of book.
- Average premium.
- Cross-sell ratio.

## Underwriter

Decides whether to accept the risk + at what price.

### Personal lines (auto, home)
- Mostly automated rules; underwriter handles exceptions.
- Pain: noisy data (LexisNexis, MVR), false-positive declines.

### Commercial lines
- Heavy judgment + manual review.
- Pain: data fragmentation, slow turnaround time on submissions.

**Permissions:**
- Read application + risk data.
- Bind / decline within authority.
- Refer up for higher authority.

## Adjuster

Handles claims. Often the most-numerous internal role.

### Field adjuster (P&C)
- Visits site, inspects damage.
- Pain: scheduling, mileage, weather (catastrophe response).
- Tooling: mobile app, photo upload, estimating software, virtual inspection.

### Desk adjuster
- Office-based; documents, phone calls, decisions.
- Pain: case load, deadline pressure, training on state-specific rules.

### Independent adjuster (IA)
- Contracted; deployed at catastrophe events.
- Pain: working across multiple insurers' systems.

### SIU adjuster (Special Investigations)
- Suspected fraud cases.
- Pain: data correlation, link analysis, court-admissible evidence.

### Catastrophe adjuster
- Surge response (hurricane, wildfire).
- Pain: 50x normal claim volume; overwhelmed system.

**Pain points (universal):**
- Conflicting information from different sources.
- Pressure to settle quickly conflicting with proper investigation.
- Bad-faith litigation risk on every decision.
- Documentation fatigue.

**KPIs:**
- Cycle time (FNOL to close).
- Severity (average paid).
- Reopen rate.
- Cost containment.
- Customer satisfaction post-claim.

## Operator (carrier executive layer)

### CEO / business unit head
- Wants: combined ratio, market share, growth, retention.

### Chief Underwriting Officer
- Wants: portfolio health, rate adequacy, loss trends.

### Chief Claims Officer
- Wants: cycle times, severity, leakage (overpaid claims), customer satisfaction.

### Chief Actuary
- Wants: reserve adequacy, rate adequacy, profitability projections.

### Chief Compliance Officer
- Wants: state-by-state filing status, exam findings, regulatory complaints.

### Chief Risk Officer
- Wants: catastrophe exposure, ORSA results, capital adequacy.

### Customer service / call center
- Wants: 360-degree customer view, scripts, escalation paths.

### Marketing / distribution
- Wants: agent recruitment, advertising effectiveness, brand metrics.

## Reinsurance partners

- Treaty: ongoing relationship; share in policies above retention.
- Facultative: case-by-case.
- Pain: timely loss reporting, large-loss notification, treaty-year accounting.

## Regulators

### State DOI
- Form filings approval.
- Rate filings approval.
- Market conduct exams.
- Solvency monitoring.
- Complaint handling.
- Enforcement actions.

### NAIC
- Coordinates among states.
- Model laws.
- Database (SERFF).

### Federal
- ACA (CMS) for health.
- FEMA for flood (NFIP).
- Treasury / FIO (Federal Insurance Office) advisory.

### EU / international
- EIOPA (EU).
- FCA / PRA (UK).
- Per-country supervisors.

**Common interactions:**
- Annual statement filings.
- Rate / form filings (SERFF in US).
- Complaint resolution (DOI mediates between consumer + insurer).
- Market conduct exams (every 5 years typical).
- Financial exams (every 3-5 years).
- Targeted exams on specific concerns.

## Networks (P&C + health)

### Repair shops (auto)
- Direct repair programs (DRP) — preferred network.
- Cycle time + cost negotiation.

### Medical providers (auto + health + workers' comp)
- PPO networks.
- Fee schedules.
- Pre-authorization.
- Bill review.

### Restoration contractors (property)
- Catastrophe response.
- Mitigation crews.

### Salvage / total-loss vendors
- Title transfer.
- Auction.

### Legal / claims defense counsel
- Litigated claims.
- Cycle time + cost containment.

### Independent medical examiners (workers' comp, disability, etc.)
- Independent assessment.

## Investors / Reinsurance market

- Quarterly + annual reports drive stock price.
- Catastrophe events drive rating-agency reviews (AM Best, S&P).
- Capital raises after large losses.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Policyholders surprised at renewal | Premium-change explanations + advance notice |
| Claimants confused about status | Status timeline + milestone notifications + estimate |
| Adjusters drowning in paperwork | Workflow automation + estimating tools + voice notes |
| Underwriters overwhelmed | Auto-bind rules + better triage + data integrations |
| Producers calling for help | Portal improvements + commission transparency |
| Regulators flagging slow claims | Cycle-time tracking + workflow automation |
| Auditors finding doc gaps | Mandatory data fields + audit-log enrichment |
| Catastrophe overload | Surge plans + pre-event playbooks |
| Bad-faith threats from plaintiff attorneys | Decision audit trail + state-compliant denial letters |

## Anti-pattern: "tech-first, regulation-later"

Build the slick UX first; bolt compliance on. Result: state DOI rejection of forms, market conduct findings, enforcement orders, business stop. Compliance drives data model + UX from day one.

## Anti-pattern: "claims is a cost center"

Treating claims as friction-to-minimize generates: bad-faith lawsuits, regulatory complaints, retention collapse. Claims is the moment of truth; investing in tooling is investing in trust.

## Anti-pattern: "the agent will explain"

Self-service insurance with no agent assumes the policyholder understands coverage, exclusions, claim process. They don't. Either invest in plain-language disclosure + decision-support, OR maintain agent presence.
