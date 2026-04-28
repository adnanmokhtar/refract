# SaaS B2B — compliance + legal

B2B sales cycles stall on compliance questionnaires. Enterprise deals have CISO review. Build with compliance as architecture constraint from day one.

## SOC 2

The de facto US enterprise trust standard.

### Type I vs Type II
- **Type I** — point-in-time assessment; "do you have controls?"
- **Type II** — 3-12 month observation period; "do controls operate effectively?"
- Enterprise buyers want Type II. Type I is a stepping stone.

### Trust Services Criteria
- **Security** — baseline; required for all SOC 2 reports.
- **Availability** — uptime commitments.
- **Processing Integrity** — data accuracy.
- **Confidentiality** — data protection during processing.
- **Privacy** — personal info handling.

Most startups: Security + Availability + Confidentiality.

### Common control requirements
- Access control (RBAC, MFA, SSO).
- Change management (code review, deployment approvals).
- Vendor management (sub-processor inventory, SOC 2 of critical vendors).
- Logical + physical access.
- Backups + disaster recovery (documented + tested).
- Incident response plan.
- Risk assessment + remediation tracking.
- Employee onboarding + offboarding.
- Background checks.
- Security awareness training.
- Vulnerability management + pen test.
- Encryption at rest + in transit.
- Audit logging + monitoring.

### Auditors + cost
- Big 4 ($50k-$200k), boutique ($15k-$50k), or automation-led (Vanta, Drata, Secureframe — $7k-$30k).
- Ongoing cost + engineering time.
- Plan: Type I at ~12 months, Type II report available at ~18-24 months post-launch.

## ISO 27001

International equivalent / complementary to SOC 2.
- Required for EU + international enterprise.
- ISMS (Information Security Management System) documentation-heavy.
- Annex A controls (114 in ISO 27001:2022).
- Certification by accredited body; 3-year cycle with annual surveillance.
- Some customers require ISO 27017 (cloud), ISO 27018 (cloud PII), ISO 27701 (privacy).

## GDPR (EU)

Applies to any SaaS processing EU personal data, regardless of where based.

### Controller vs Processor
- **Controller**: customer (determines purpose + means of processing).
- **Processor**: you, the SaaS (processes on controller's instructions).
- Different obligations; DPA governs the relationship.

### DPA (Data Processing Agreement)
- Required Article 28 contract.
- Template DPA on your site; enterprise customers negotiate.
- Key sections: nature + purpose of processing, data subject categories, data categories, sub-processor provisions, SCCs for international transfer, deletion on termination.

### Sub-processors
- All vendors touching customer data = sub-processors.
- Public list required + obligation to notify on additions.
- 14-30 day objection window for customers.
- Examples: AWS, Stripe, Datadog, Zendesk, Intercom.

### Standard Contractual Clauses (SCCs)
- Required for EU → US transfer post-Schrems II.
- 2021 updated SCCs (Commission Decision 2021/914).
- TIA (Transfer Impact Assessment) required; document why destination country protections are adequate.
- Data Privacy Framework (DPF) — US self-certification post-July 2023; alternative mechanism.

### Data subject rights
- Access, rectification, erasure, portability, restriction, objection.
- 30-day response; extend to 60 with notice.
- Through customer (controller) usually; you support by enabling customer tooling.
- Self-service data export + deletion tools reduce ad-hoc burden.

### Breach notification
- 72 hours to notify customer (controller) of confirmed breach.
- Customer notifies authority + data subjects.

### Data residency
- Not strictly GDPR-required but customer-requested.
- EU customers often require EU-only hosting.
- Architecture: region per-tenant OR per-deployment.

## US privacy

### CCPA / CPRA (California)
- B2B data was partially exempt until Jan 2023; now fully covered.
- Right to know, delete, opt-out of sale/sharing, limit use of sensitive PI.
- "Sharing" with service providers that use data beyond service = sale.
- Sensitive PI (precise geo, race, biometric, etc.) — additional rights.

### Other states
- Virginia (VCDPA), Colorado (CPA), Connecticut (CTDPA), Utah (UCPA), Texas (TDPSA), Oregon, Montana, Washington (My Health My Data) — 2023-2024 enacted.
- Shape similar to GDPR-lite.
- Most exempt B2B data; read carefully.

### HIPAA
- If your SaaS touches PHI, BAA with each customer required.
- Security Rule + Privacy Rule apply.
- Audit logs + encryption + access controls table-stakes.

### GLBA
- Financial institution customer data — if you serve banks/insurance.
- Safeguards Rule (FTC).

### FERPA
- Student records — if you serve education.

## International privacy

- **UK GDPR** — post-Brexit; similar to EU.
- **LGPD (Brazil)** — 2020; GDPR-like.
- **PIPEDA (Canada)** — federal; provincial variants (Quebec Law 25 strict).
- **POPIA (South Africa)** — 2021.
- **PDPA (Singapore)** — strong enforcement.
- **APPI (Japan)** — amended 2022.
- **DPDP (India)** — 2023 passed; rules emerging.
- **PIPL (China)** — strict cross-border; explicit consent for data export.
- **Australia Privacy Act** — amended 2024; more penalties; notifiable breach.

## Security standards + frameworks

- **CIS Critical Security Controls** — v8; practical control set.
- **NIST Cybersecurity Framework** — Identify/Protect/Detect/Respond/Recover.
- **NIST SP 800-53** — federal control baseline.
- **PCI DSS** — if you touch cardholder data.
- **FedRAMP** — if selling to US federal; costly + long.
- **HITRUST CSF** — healthcare + financial; rolls up HIPAA, NIST, etc.
- **IRAP** — Australian Government.
- **C5** — German federal.

## Sales enablement — security questionnaires

Enterprise prospects send 50-300 question questionnaires. Common:
- **SIG (Standardized Information Gathering)** — Shared Assessments Program.
- **CAIQ (Consensus Assessments Initiative Questionnaire)** — Cloud Security Alliance.
- **VSA (Vendor Security Assessment)** — Shared Assessments.
- **Custom** — Microsoft, Apple, Google, etc. have their own.

Tooling to handle: SafeBase, Whistic, Vanta Trust, OneTrust, Conveyor.

## Accessibility

- **WCAG 2.1 AA** — baseline for public-facing surfaces.
- **WCAG 2.2** — current.
- **ADA** (US) — case law applies to commercial websites.
- **Section 508** — US federal customers.
- **EN 301 549** — EU public sector.
- **EAA (EU Accessibility Act)** — June 2025 enforcement.

## Data retention + deletion

- Customer data retained per subscription + grace period (30-90 days typical).
- Hard delete on request (GDPR erasure).
- Backup retention: documented; encrypted; tested restore.
- Log retention: business need + compliance (SOC 2: 1 year+; HIPAA: 6 years).
- Export format on deletion: customer choice (JSON minimum, CSV for tabular).

## Sub-processor obligations

- Public list at `/trust/sub-processors` or similar.
- Email notification to customers on addition (14-30 day notice).
- DPA flow-down (each sub-processor contractually bound).
- SOC 2 / ISO 27001 of critical sub-processors on file.

## Insurance

- **Cyber liability** — breach response, extortion, legal.
- **Tech E&O** — professional services errors.
- **D&O** — director/officer protection.
- Enterprise customers request certificates of insurance (COI) with specific limits.

## Contract terms to watch

- **Indemnification caps** — customer wants unlimited for data breach; standard is 12-month fees or $1-5M.
- **Liability caps** — 1x annual fees typical; customer negotiates up.
- **SLAs** — uptime commitments with service credits.
- **Termination for convenience** — customer wants easy out; balance with contract term.
- **Auto-renewal** — customer wants termination notice requirements clear.
- **MSA + order forms** — master terms + per-engagement.
- **BAA** — HIPAA-triggered side agreement.

## AI-specific emerging regulation

- **EU AI Act** — applies to AI providers + deployers; 2024 phased enforcement; high-risk categorization.
- **CPPA CCPA automated decision-making** — 2024 regulations.
- **Colorado AI Act** — 2026 effective.
- **NYC AEDT** — hiring decision systems.
- **SOC 2 for AI** — evolving.
- Customer questions about training data, data isolation, retention, model privacy increasingly in questionnaires.

## Common compliance gaps in v1

- No DPA template; enterprise deals stall on legal.
- Sub-processor list absent or stale.
- No data-export self-service; every GDPR request is engineering ticket.
- Audit log coverage incomplete (no PII access logged).
- Encryption at rest on DB but backups unencrypted (or keys co-located).
- MFA optional; SOC 2 finding or customer-facing risk.
- No incident response plan documented.
- Vendor/sub-processor inventory in Google Sheet, unverified.
- Security awareness training not tracked; SOC 2 auditor flags.
- Pen test annual requirement skipped.
- No password policy enforcement.
- SSO available but not enforced by customers; they ask for enforcement feature.
- Session timeout never; long-lived sessions in unattended computers.
- Customer data in lower environments (staging, dev) for "debugging".
- No BAA template despite potential healthcare customers.
- Single region; EU customers turn away.
- No data residency controls.
- Pen test scope excludes tenant isolation.
- No tenant-leak regression tests.
- Cookie banner bypasses (not blocking non-essential cookies pre-consent).
- EU customer onboarding without TIA review.
- Compliance certifications claimed in marketing without SOC 2 report existing.
- No sub-processor notification workflow (14-day customer rights).
- AI features shipped without data-use disclosure + model retention statement.
