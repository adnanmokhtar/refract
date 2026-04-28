# Marketplace — compliance + legal

Marketplaces sit at the intersection of payments, taxes, KYC, and consumer protection. The operator is legally responsible for things sellers do — under-investing in compliance is existential.

## Tax — marketplace facilitator laws

### US (state-by-state, post-Wayfair)
- 45+ states have marketplace facilitator laws (effective dates 2018-2021): the marketplace MUST collect + remit sales tax on behalf of sellers.
- Operator is the tax collector even if seller has no nexus in the state.
- Economic nexus thresholds: typically $100k OR 200 transactions per state per year.
- Streamlined Sales Tax (SST) member states have unified registration for ~24 states.
- Use Avalara / TaxJar / Stripe Tax — DIY is regulatory suicide.
- Form 1099-K to sellers + IRS: $5,000 threshold for 2024 (was $20k+200tx, dropped via American Rescue Plan; revised 2024-2026 thresholds: $5k 2024, $2.5k 2025, $600 2026).

### EU
- VAT One-Stop-Shop (OSS): single VAT registration for B2C cross-border (EU customer in non-seller country).
- Import One-Stop-Shop (IOSS): low-value imports ≤ €150 — marketplace can collect VAT at sale.
- Deemed-supplier rules (DAC7): for goods imported ≤€150 OR sold by non-EU sellers to EU buyers, the marketplace is deemed the seller for VAT purposes.
- DAC7 reporting (effective Jan 2023): platforms must report seller info + earnings annually to EU tax authorities; thresholds 30+ transactions OR €2,000 in income.
- VAT rate = buyer's country rate. Display VAT-inclusive prices in B2C.

### UK
- Post-Brexit: VAT on goods ≤£135 sold to UK consumers — marketplace collects.
- HMRC Online Marketplace VAT regulations.

### GCC
- KSA: ZATCA Phase 2 e-invoicing — applies to sellers; marketplace must support seller compliance.
- UAE: 5% VAT, marketplace can act as agent.

## KYC / KYB / AML

### Customer Due Diligence
- Basic KYC for low-volume individual sellers: ID + selfie + address.
- Enhanced Due Diligence (EDD) above thresholds (e.g. $10k cumulative, varies by jurisdiction):
  - Source of funds.
  - PEP screening (politically exposed persons).
  - Adverse media screening.
- KYB for businesses: company registration cert, articles, UBO (ultimate beneficial owners ≥25%), proof of address.

### Screening
- Sanctions: OFAC (US), EU consolidated, UN, UK HMT, local lists.
- Re-screen on ANY profile change (name, address, country) and on schedule (daily delta scan).
- Block payouts to sanctioned individuals/entities — automatic, not manual review.

### AML
- Transaction monitoring: structuring (multiple sub-threshold transactions), velocity, geographic risk, mismatched IP/billing.
- SAR (Suspicious Activity Report) filing within statutory window (US: 30 days from detection; varies by country).
- Recordkeeping: 5-7 years retention of customer records + transaction history.
- Money Laundering Reporting Officer (MLRO) — required role in regulated jurisdictions.

### Money Service Business (MSB) registration
- US: FinCEN registration if you "transmit money" (debate: marketplace facilitator vs MSB).
- EU: PSD2 / EMI license if holding funds longer than settlement window.
- Many marketplaces partner with a regulated PSP (Stripe Connect, Adyen MarketPay, Mangopay) to AVOID being a regulated entity themselves.

## Payments

### PCI-DSS
- Provider-hosted fields only. Marketplace never sees card data.
- SAQ-A questionnaire annually if hosted-fields-only.

### Funds flow models
- **Aggregate model**: marketplace holds funds in operator account, splits internally. Heavier regulation (e-money license risk).
- **Split-on-charge** (Stripe Connect / Adyen MarketPay): provider routes seller share directly; reduces operator's regulatory burden.
- **Escrow model**: explicit escrow account, regulated by state-level escrow laws (US) or licensed escrow agent (EU).

Pick early; switching is brutal.

### Hold / reserve
- Industry norm: 7-14 day hold post-delivery (chargeback exposure).
- Rolling reserve for high-risk sellers (5-15% of gross, released 90-180 days).
- Disclose holds + reserves in seller agreement; surprise holds = lawsuits.

### Chargebacks
- Visa CE 3.0 (Compelling Evidence) framework: marketplace must provide tracking + delivery proof + buyer comms within window.
- Re-presentment: respond to chargeback within 7-21 days.
- Cardholder dispute window: ~120 days.
- Chargeback ratio threshold: Visa 0.9%, Mastercard 1.0% — exceeding triggers monitoring programs (VFMP, EMP) → fines + termination risk.

## Privacy

### GDPR (EU buyers AND sellers)
- Operator is data controller for buyer data + operator-collected seller data.
- Operator MAY be data processor for seller's customer data (depends on flow).
- Standard GDPR rights apply: access, erasure, portability, rectification, objection.
- Sub-processor list: every third party that touches data must be listed in privacy policy.
- DPA with each seller IF seller is also a controller.

### CCPA / CPRA (California)
- Same shape as GDPR.
- Sellers above thresholds may need their own CCPA compliance — marketplace acts as service provider.

### Seller PII
- Seller is a data subject too. KYC docs + bank info are highly sensitive.
- Encrypt at rest with separate keys from buyer data (separation of risk).
- Retention: KYC records 5-7 years post account closure (AML), then purge.

## Consumer protection

### EU Platform-to-Business Regulation (P2B, 2019/1150)
- Mandatory T&Cs disclosure to sellers.
- 15-day notice for T&C changes.
- 30-day notice for account suspension/termination (with reason).
- Internal complaint-handling system required.
- Mandatory mediation pathway.

### EU Digital Services Act (DSA, 2024)
- Notice + action mechanism for illegal content/listings.
- Trader traceability — collect + verify seller identity (KYB lite).
- Transparency reports on moderation.
- Recommender system transparency (algo disclosure).
- Very Large Online Platforms (VLOPs, 45M+ EU users): risk assessments, auditing.

### EU Consumer Rights Directive
- 14-day cooling-off period for B2C distance sales — operator must facilitate even if seller fulfills.
- Pre-contract info disclosure.

### US FTC Mail Order Rule
- Ship within 30 days OR notify buyer + offer refund.

### Restricted goods
- Alcohol/tobacco/firearms: state-by-state in US, country-by-country in EU. Many marketplaces ban outright.
- CITES (endangered species): ivory, certain woods, exotic leather.
- Counterfeit: takedown obligations under DMCA (US) / DSA (EU).

## Seller-of-record vs marketplace-of-record

This determines who's liable for product safety, returns, taxes:

- **Seller-of-record**: seller is on the receipt; operator is just the platform. Lower liability for operator BUT seller must be tax-registered everywhere.
- **Marketplace-of-record**: operator is on the receipt. Higher liability BUT simpler for sellers; operator handles taxes, returns.
- **Hybrid**: depends on jurisdiction. Many marketplaces are MoR in the US (per facilitator laws) and SoR in some EU countries.

Document the choice per jurisdiction in legal review BEFORE launching there.

## 1099-K / equivalent reporting

| Jurisdiction | Threshold | Form | Frequency |
|---|---|---|---|
| US (IRS) | $5k 2024 / $2.5k 2025 / $600 2026 | 1099-K | Annual (Jan 31 to seller, Feb 28 to IRS) |
| EU (DAC7) | 30 transactions OR €2,000 | DAC7 report | Annual |
| UK (HMRC) | Equivalent of DAC7 (post-Brexit, 2024) | OECD platform reporting | Annual |
| Canada | 200 transactions / equivalent | T2125 reporting from sellers | Annual |
| Australia | $75k AUD GST threshold | BAS / GST reporting | Quarterly |

## Audit + retention

- Order + payout records: 7-10 years.
- KYC docs: 5-7 years post account closure (AML).
- Chargeback evidence: 2 years post-dispute window close.
- Tax records: per jurisdiction (typically 7-10 years).
- Audit logs of operator actions on seller accounts: 3-5 years.

## Insurance

- Cyber liability — buyer + seller PII + bank data exposure.
- E&O — failure of marketplace operations causing seller losses.
- Crime — internal fraud (employee misappropriating funds in transit).
- D&O — director/officer liability.

## Common compliance gaps in v1

- KYC checked at signup, never re-verified — passport expires, account stays active.
- Tax remittance "we'll figure it out at scale" — fines for prior years can sink the business.
- 1099-K issuance "we'll do it manually" — required at $600 threshold from 2026; manual = audit hell.
- T&C version management absent — when sued, can't prove which version seller accepted.
- Sanctions screening at onboarding only — sellers added to lists later, payouts continue.
- Reserve policy undocumented — sellers sue for unpaid balances.
- DAC7 reporting absent — EU platforms launching 2023+ caught off-guard.
- Marketplace facilitator state coverage incomplete — collect in 5 states, ignore the other 40 → state attorney general action.
- Restricted-goods enforcement keyword-only — sellers easily circumvent ("vape" → "vp", "wpe").
- Counterfeit takedown SLA absent — brand-owner lawsuits + DSA fines.
