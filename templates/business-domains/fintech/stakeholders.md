# Fintech — stakeholders

Fintech has unusually many stakeholders because money attracts oversight: customers, internal compliance, banking partners, regulators, networks, auditors, law enforcement. Each has a hard-no veto.

## End customer

The user holding the account.

**Workflows:**
- Open account.
- Verify identity.
- Fund (deposit).
- Move money (transfer, pay, withdraw).
- Track (statements, alerts, limits).
- Resolve issues (lost card, fraud, dispute).
- Close.

**Pain points the system must solve:**
- "Why is my account frozen?" — compliance freezes need clear (compliant) communication.
- "When is my money available?" — funds availability schedules are confusing; surface clearly.
- "Did the transfer go through?" — status visibility, real-time updates.
- "I didn't authorize that charge" — easy dispute path, provisional credit.
- "How do I prove I paid?" — receipts, statements, transaction details.
- "Where did my money go?" — readable transaction descriptions, not raw provider codes.

**Sub-types:**

### Consumer / retail
- Cares about: speed, low fees, good UX, security.
- Pain: KYC friction, slow withdrawals, opaque fees.

### Small business
- Cares about: bookkeeping integration, cash-flow visibility, payroll connectivity.
- Pain: KYB for sole-prop ambiguous, transaction limits choke business operations.

### Enterprise
- Cares about: APIs, payment file ingestion (NACHA, ISO 20022), reporting depth, dedicated support.
- Pain: limit ceilings, support response time, custom integration work.

### Cross-border / immigrant
- Cares about: international transfers, FX rates, family remittance.
- Pain: KYC for foreign IDs, country-specific compliance restrictions.

**KPIs:**
- KYC pass rate.
- Time to first transaction (activation).
- Account funding rate.
- Active monthly users.
- Transaction frequency.
- NPS / CSAT.
- Support tickets per active user.
- Account closure / churn.

## Compliance / Risk team (the gatekeeper, internal)

The team most ignored in v1, most regretted thereafter.

### Chief Compliance Officer (CCO) / MLRO
- Wants: AML program documentation, regulator-ready reporting, defensible decisions.
- Pain: tooling that doesn't generate audit trails, ad-hoc data pulls for regulators.
- Permissions: full read; write on policy + alert disposition.

### KYC analysts
- Wants: queue with prioritization, document-review interface with side-by-side comparison, fast SLA.
- Pain: manual document inspection, low-quality images, false sanctions hits.

### AML / fraud analysts
- Wants: alert dashboard with explainability ("why did this rule fire?"), case management with tags + notes, pattern visualization.
- Pain: alert fatigue, manual SAR drafting, no graph tools to spot networks.

### Disputes team
- Wants: dispute queue with countdown clocks, evidence collection workflow, network case file generation.
- Pain: manual evidence gathering, deadline pressure.

### Treasury / reconciliation
- Wants: daily recon reports, exception clearing workflow, manual journal entry with approval.
- Pain: messy bank statements, mismatches that take hours to investigate.

**Core operator dashboards:**
- Open AML alerts by severity + age.
- KYC backlog + average review time.
- Sanctions hits awaiting review.
- Disputes by deadline.
- Reconciliation exceptions.
- High-risk customer list.

## Engineering / Security

### Backend engineers
- Care about: ledger correctness, idempotency at API + DB, audit trail preservation.
- Pain points: feature pressure conflicting with compliance overhead.

### SRE / Platform
- Cares about: uptime, RTO/RPO, regulator-acceptable DR, monitoring.
- Pain: financial systems have lower error tolerance than typical SaaS.

### Security / InfoSec
- Cares about: SOC 2, ISO 27001, breach prevention, employee access controls.
- Pain: privileged access management, vendor risk, third-party assessments.

### Data / Analytics
- Cares about: regulatory reports, customer behavior, model performance.
- Pain: PII access controls vs analytical needs.

## Banking / BaaS partner

For non-bank fintechs:

- They hold the actual license + bank charter.
- They expect: solid KYC + AML program, prompt SAR filing, monthly reporting, audit access.
- Pain: their compliance team second-guesses your decisions; their operational rules constrain product.
- Failure mode: partner bank changes terms, raises fees, or terminates; massive disruption.
- The 2023-2024 BaaS crisis (Synapse, Evolve issues) exposed how fragile these relationships are.

## Card networks (Visa / Mastercard / Amex / Discover / etc.)

- Set rules (Visa Operating Regulations, MC Rules) — must follow or fines.
- Compliance programs (VAMP, EMP) for high-chargeback merchants/issuers.
- Disputes via their case management.
- BIN sponsorship through issuer; BIN owner gets liabilities.

## Regulators

### US — Federal
- FinCEN (BSA / AML).
- OCC, FDIC, NCUA, FRB (banking).
- SEC, FINRA, CFTC (securities, commodities).
- CFPB (consumer financial protection).
- IRS (tax).
- OFAC (sanctions).
- DOJ (criminal).

### US — State
- State banking departments (NYDFS, CDFPI, etc.).
- State AGs.
- State tax authorities.

### EU
- EBA (European Banking Authority).
- EU supervisors per country (BaFin, ACPR, FCA pre-Brexit, CSSF).
- AMLA (forming).

### UK
- FCA.
- PRA (prudential).
- Information Commissioner's Office (data).

### Asia-Pac
- MAS (Singapore).
- HKMA (Hong Kong).
- RBI (India).
- ASIC (Australia).
- FSA (Japan).

### Common regulator interactions:
- Routine exams (every 12-36 months).
- Targeted exams on specific concerns.
- Ad-hoc data requests.
- Consent orders / matters requiring attention (MRA).
- Enforcement actions.
- SAR / CTR submission.

**Permissions:** read-only into specific datasets, with audit; signed agreements for data sharing.

## Auditors

### Internal audit
- Tests controls.
- Reports to board.

### External audit (financial)
- Annual audit.
- Per-jurisdiction firm requirements (Big Four common).

### External audit (compliance)
- BSA/AML audit (often annual or 18-month).

### IT auditors (SOC 2, ISO)
- Type II requires 6+ month observation period.
- Continuous monitoring expectation.

## Law enforcement

- Subpoenas (with proper service).
- Search warrants (in-scope data).
- 314(a) requests (FinCEN — info on persons of interest).
- Garnishment orders.

**Permissions:** narrow access for specific subjects + transactions; data preservation orders.

## KYC / Identity providers (Onfido, Persona, SumSub, Veriff, Alloy)

- Their pass rates = your conversion.
- Their false positives = your false rejections.
- Tradeoff: stricter checks reduce fraud but reject legitimate users.
- Multi-provider strategy at scale.

## AML / Sanctions providers (ComplyAdvantage, WorldCheck, Refinitiv, NameScan)

- Their lists = your protection.
- False match rate = your alert volume.
- Subscription costs scale with customer base.

## Payment rails

### ACH (US, NACHA-governed)
- Slow (next-day, 2-day).
- Returns within 60 days unauthorized; 2 days admin.
- NSF, account closed, etc.

### RTP (US, instant)
- Limited adoption.
- $1M cap.

### Fedwire (US)
- Same-day, irrevocable.

### SEPA (EU)
- SCT (Credit), SDD (Direct Debit), SCT Inst (instant).
- Returns: 5 days SCT, 8 weeks SDD.

### Faster Payments / CHAPS (UK)
- FPS instant; CHAPS same-day.

### SWIFT
- International correspondent banking.
- 1-5 business days.
- Fees + intermediary haircuts.

## Investors / Board

- Want: GMV, revenue, regulatory wins, capital efficiency.
- Pain: capital regulations, regulatory uncertainty, exit valuation.
- High involvement during regulator escalations.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Customers waiting for KYC | KYC tooling, SLA, automation |
| Compliance officer drowning | Alert quality + case management + reporting automation |
| Disputes team missing deadlines | Dispute workflow + evidence collection automation |
| Regulator finding | Audit trail + reporting + control testing |
| BaaS partner threatening termination | Compliance maturity + reporting cadence |
| Customers locked out of funds | Hold management + clear messaging + appeal process |
| Engineering paged at 3am for ledger drift | Reconciliation + alerting + idempotency hardening |
| Auditor citing manual processes | Workflow automation + immutable audit log |

## Anti-pattern: "compliance is a cost center"

Treating compliance as a tax means under-investing in tooling. Then regulator findings = enforcement actions = fines + business stop. Compliance is the product surface in fintech; under-tooling it is existential.

## Anti-pattern: "we'll fix it before the audit"

Auditors look at production state, not your roadmap. Manual processes + missing audit trails + ad-hoc decisions = audit findings = consent orders. Build for audit-readiness from day one.

## Anti-pattern: "the partner bank handles compliance"

False. Partner banks rely on you for KYC + AML + monitoring. They audit YOU. They terminate when your program is weak. The 2023-2024 BaaS disruptions made this brutally clear.

## Anti-pattern: "users want speed, screw the limits"

Customer-pleasing limit override → AML signal lost → SAR deficiency → regulator finds → license risk. Limits are not UX friction; they're a control.
