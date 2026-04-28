# Fintech — compliance + legal

Fintech compliance is THE product surface as much as the UI. Underinvesting here = enforcement actions + license revocations + criminal liability.

## Licensing + regulatory shape

### US — money transmission
- State-by-state Money Transmitter License (MTL): 49 states + DC + PR.
- Bond requirements ($25k - $7M depending on state).
- Net worth requirements.
- Bank-as-a-Service (BaaS) partnership often used to avoid direct licensing — operator builds on Stripe Treasury / Unit / Bond / Synapse, the partner bank holds the license.
- Federal: FinCEN MSB registration (Money Service Business).
- 50-state coverage typically takes 12-24 months + ~$1M+ in legal/bond.

### US — banking
- OCC charter (national bank).
- State bank charter (state-chartered).
- ILC (Industrial Loan Charter — Utah, etc.).
- FDIC insurance for deposits.
- NCUA for credit unions.
- Most "neobanks" are NOT banks — they're tech overlay on a partner bank.

### EU — Payment Services Directive (PSD2)
- Payment Institution (PI) license OR Electronic Money Institution (EMI) license.
- Single passport: license in one EU country = operate across EU.
- Strong Customer Authentication (SCA) for online payments (multi-factor).
- AISP / PISP licenses for Open Banking.
- 2-factor for transaction monitoring access.
- PSD3 + Payment Services Regulation (PSR) finalized 2024-2025; expanding scope.

### UK — FCA
- FCA authorization required.
- E-Money Institution (EMI) or Authorized Payment Institution (API).
- Safeguarding rules for client money.

### Singapore — MAS
- Payment Services Act licenses (Major Payment Institution, Standard Payment Institution).

### India — RBI
- Prepaid Payment Instrument (PPI) license.
- UPI integration through partner bank.
- Account Aggregator framework.

### KSA / UAE
- SAMA (KSA) licenses for fintech sandbox + payments.
- CBUAE for UAE.
- Open Banking framework emerging.

### Mexico — CNBV
- IFPE (Institución de Fondos de Pago Electrónico) for e-money.

## KYC / AML / CFT

### US BSA (Bank Secrecy Act)
- Customer Identification Program (CIP) — verify identity at onboarding.
- Customer Due Diligence (CDD) Rule — beneficial ownership for legal entities (≥25%).
- AML program: written policies, designated officer, training, independent audit.
- Suspicious Activity Report (SAR): 30 days from detection to file (60 if continuous monitoring).
- Currency Transaction Report (CTR): cash transactions > $10,000.
- Recordkeeping: 5 years post account closure for KYC; 5 years for transactions.

### USA PATRIOT Act
- 314(a) requests: FinCEN can request info; respond within 14 days.
- 314(b): info sharing among FIs for AML purposes.
- Section 326: CIP rule.
- Special Measures: country / institution-specific restrictions.

### Sanctions (US)
- OFAC SDN (Specially Designated Nationals) list — primary.
- Sectoral Sanctions (Russia, etc.) — partial restrictions.
- Country embargoes (Cuba, Iran, North Korea, Syria, Crimea).
- Re-screen on every profile change + daily delta on customer base.
- Penalties: $328k+ per violation OR up to 2x the value of the transaction.
- "Strict liability" — knowledge not required.

### Sanctions (EU)
- EU consolidated list.
- Member state extensions.

### Sanctions (UK)
- HMT Consolidated List post-Brexit.

### Sanctions (UN)
- UN Security Council sanctions (binding on member states).

### EU AMLD (Anti-Money Laundering Directives)
- 6th AMLD (2021): broader predicate offenses, criminal liability for legal entities, harsher sentences.
- AMLA (Anti-Money Laundering Authority) — EU-level supervisor effective 2025-2027.
- Enhanced due diligence for high-risk third countries (per EU Commission's list).
- UBO registers (made public, then reverted post-CJEU Nov 2022 ruling).

### FATF Recommendations
- 40 recommendations setting global AML/CFT baseline.
- Country compliance evaluated periodically; non-compliant countries land on grey/black lists.
- Travel Rule: originator + beneficiary info required for transfers ≥ $1k (US) / €1k (EU); also applies to virtual asset transfers.

### EDD triggers
- High-net-worth.
- PEP (Politically Exposed Persons) — current or close associates.
- High-risk geography.
- High-risk industry (gambling, crypto, cannabis where legal, MSBs).
- Large/unusual transactions.

## Privacy

### GDPR
- Standard rights, modulated by AML/regulatory carve-outs.
- Right to erasure: financial records retained per regulatory floor; PII anonymized post-retention.
- Profiling + automated decisions: KYC + risk scoring may qualify; Art 22 right to human review.
- Lawful basis: legal obligation (AML), contract (account services), legitimate interest (fraud prevention), consent (marketing).

### GLBA (US — Gramm-Leach-Bliley Act)
- Privacy Notice annually + at account opening.
- Safeguards Rule: information security program.
- Pretexting protections.
- Opt-out for sharing with non-affiliates.

### CCPA / CPRA (California)
- Financial institutions partially exempt (when subject to GLBA) — but employee + B2B data still covered.

### State-level (US)
- New York DFS Part 500 (cybersecurity).
- Massachusetts 201 CMR 17.
- Various breach notification laws (50 states + DC + territories).

### PIPEDA (Canada), POPIA (SA), LGPD (Brazil), DPDPA (India)
- GDPR-shaped variants.

## Payments security

### PCI-DSS
- Card data NEVER on your servers — provider-hosted fields, tokens only.
- SAQ-A (lightest) if hosted-fields-only.
- SAQ-D required if you touch PANs anywhere (most fintechs avoid).
- Annual SAQ + quarterly external scans + penetration test.
- PCI-DSS 4.0 (effective 2025) — multi-factor for all access.

### PSD2 SCA (Strong Customer Authentication)
- Mandatory in EU/UK for in-scope transactions ≥ €30 (€50 cumulative for low-risk).
- 2 of 3 factors: knowledge (password), possession (device), inherence (biometric).
- Exemptions: low-risk (TRA), low-value, recurring, MIT (merchant-initiated).
- Penalties: per-transaction violations + license revocation risk.

### 3DS (3D Secure)
- 3DS2 = friction-reduced; passes data to issuer for risk decisioning.
- Implement via your provider (Stripe payment_intents, Adyen, etc.).

### Open Banking security
- OAuth 2.0 + FAPI (Financial-grade API) profiles.
- 90-day re-consent (PSD2).
- TLS mutual auth.

## Information security frameworks

- SOC 2 Type II (most common enterprise expectation).
- ISO 27001.
- NIST Cybersecurity Framework.
- NYDFS Part 500 (NY-licensed entities).
- HITRUST (less common for fintech; healthcare overlap).

## Consumer protection

### US Reg E — Electronic Fund Transfer Act
- Error resolution: customer reports unauthorized transaction; FI must investigate within 10 business days.
- Provisional credit during investigation if not resolved within 10 BD.
- Liability caps on lost cards / unauthorized use.
- Disclosures at account opening + change of terms.

### US Reg Z — Truth in Lending Act
- Credit / lending disclosures (APR, fees).
- Right of rescission for certain credit.

### US Reg DD — Truth in Savings Act
- Account terms, APY, fees disclosure.

### US Reg CC — Funds Availability
- Funds availability schedule (next-day, 2-day, etc., depending on deposit type + amount).

### US CFPB enforcement
- UDAAP (Unfair, Deceptive, Abusive Acts or Practices) — broad authority.
- Per-violation civil penalties.

### EU Distance Marketing Directive
- Pre-contract disclosures.
- 14-day withdrawal right (some financial services exempt; check).

### EU Mortgage Credit Directive (MCD)
- Specific rules for consumer mortgages.

### UK FCA Consumer Duty (effective 2023)
- Higher and clearer standard of care for retail customers.
- "Fair value" assessment of products.

## Tax + reporting

### US 1099 series
- 1099-INT (interest > $10).
- 1099-K (third-party network transactions; threshold dropping to $600 by 2026).
- 1099-MISC (general).
- 1099-B (brokerage).
- 1099-DIV (dividends).
- Issuance: Jan 31 to recipient; varying dates to IRS.

### FATCA (US)
- Reporting on US persons with foreign accounts.
- W-8 / W-9 forms collection.

### CRS (Common Reporting Standard, OECD)
- 100+ jurisdictions; cross-border financial-account info exchange.
- Self-certification of tax residence at onboarding.

### DAC8 (EU)
- Crypto-asset reporting (effective 2026).

### State / local
- Withholding tax on interest in some states.
- Escheat / unclaimed property laws (dormant accounts) — varying state thresholds (1-7 years).

## Insurance

- FDIC / NCUA (US deposit insurance) — passed through via partner bank for BaaS fintechs ($250k per depositor per insured bank).
- FSCS (UK) — £85k.
- EU deposit insurance scheme — €100k.
- Cyber liability — minimum $5-25M depending on size.
- E&O / professional liability.
- Crime / fidelity bond — required by partner banks.

## Audit + retention

| Record | Retention | Reason |
|---|---|---|
| Transaction records | 5 years (US BSA), 5-7 years (EU AMLD) | AML |
| KYC docs | 5 years post account closure (US), 5-7 (EU) | AML |
| SAR / CTR | 5 years | BSA |
| Sanctions screening logs | 5 years | OFAC |
| Customer comms | 3-7 years | Disputes + regulatory |
| Audit logs (privileged actions) | 5 years | SOX-adjacent |
| Statements | 7 years (US tax) | IRS |
| Backups | Per policy + business need | DR |

## Common compliance gaps in v1

- Sanctions screening at onboarding only — no daily delta scan.
- KYC documents stored in S3 unencrypted or under generic key.
- Audit log not immutable — engineering can edit; defeats purpose. Use append-only store + periodic Merkle tree.
- "We're under our partner bank's license" — but partner banks expect YOU to do KYC + AML; this is the BaaS dirty secret. Synapse collapse in 2024 showed the consequences.
- 1099 issuance ad-hoc — manual exports = errors + late filings.
- AML rules tuned only at launch — never recalibrated; false-positive rate explodes; real fraud missed.
- SAR not filed in window — federal penalty per filing.
- Reg E timing missed (provisional credit not issued in 10 business days) — class actions.
- KYC stored client-side / sent client-side without TLS — exposed.
- Customer "tipped off" about SAR — federal crime.
- PEP screening shallow (current PEPs only, not associates) — laundering vector.
- CTR aggregation rules wrong — multiple sub-$10k transactions ("structuring") not aggregated.
- Fraud rules don't consider counterparty concentration — mule networks slip through.
- Reverse-engineering production data from logs (PAN, full account #) — PCI / GDPR violation.
- API rate limit absent on KYC submission endpoint — bot creates 10k accounts; sanctions screening overwhelmed.
- Account closure flow leaves PII intact — GDPR right of erasure violated past retention period.
- Subpoena response procedure missing — first legal request, scrambling.
- Cross-border data flow restrictions ignored — Schrems II concerns for EU data to US.
- Regulator exam exports take engineering days to produce — "we'll just pull the data" doesn't survive an actual exam.
