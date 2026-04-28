# Ecommerce — compliance + legal

Knowing the regulations early is cheap; retrofitting is not. This list is the floor for any global ecommerce; layer on country-specific rules as you launch markets.

## Payment + financial

### PCI-DSS
- Never store / log / transmit card numbers (PAN), CVV, full magnetic stripe.
- Use provider-hosted fields (Stripe Elements, Adyen Web Components, etc.) — your servers never touch the PAN.
- Network access from your card-handling tier limited (segmentation).
- Annual SAQ-A questionnaire if you use hosted fields end-to-end.
- Quarterly external scan (provider's compliance portal usually handles).
- Token-only storage for "save card for later" — never PANs even encrypted.

### 3DS / SCA (EU + UK)
- Strong Customer Authentication required for transactions ≥€30 in EU.
- Implement via your provider (Stripe `payment_intents` with `automatic_payment_methods`).
- Frictionless flow for low-risk transactions; challenge for high-risk.
- Test in sandbox with provider-supplied test cards forcing each path.

### Fraud
- Velocity checks (N orders / N hours / per IP).
- Address Verification Service (AVS) results from provider.
- CVV match check.
- Geolocation mismatch flag (card billing vs IP country).
- Optional: third-party scoring (Sift, Riskified, Signifyd) for high-AOV products.

### Refunds + chargebacks
- Refund → original payment method, NEVER store credit (unless customer agrees).
- Chargeback response — provider will request evidence; have it ready (tracking, delivery proof, customer comms).
- Dispute window: card networks allow ~120 days post-transaction. Don't delete shipping evidence.

## Privacy

### GDPR (EU customers, regardless of where you're based)
- Explicit cookie consent — non-essential cookies blocked until accepted.
- Privacy policy: legal basis for each processing purpose (contract, consent, legitimate interest).
- Data Processing Agreement (DPA) with all third-party processors (ESP, analytics, payment).
- Right to access — customer can download their data.
- Right to erasure — customer can request deletion (with carve-outs for legal/financial records: order history must be retained 7-10 years for tax in most jurisdictions; anonymize PII but keep transactional records).
- Right to rectification — customer can correct address, name, etc.
- Data portability — export in machine-readable format (JSON / CSV).
- Breach notification — 72 hours to supervisory authority.
- DPO (Data Protection Officer) if processing at scale.

### CCPA / CPRA (California)
- "Do Not Sell My Personal Information" link in footer.
- Privacy policy must list categories of personal info collected + purposes.
- Right to know + delete + opt-out of sale.
- Opt-out cannot be conditional on service degradation.

### LGPD (Brazil), POPIA (South Africa), PDPA (Singapore)
- Similar shape to GDPR. If you serve those markets, treat them as GDPR-compliant minimum.

### Cookies
- Distinguish strictly necessary (cart, session) from analytics from marketing.
- Block analytics + marketing until consent.
- Track consent state per visitor (timestamp + version of policy).
- Respect "Do Not Track" header where applicable.

## Tax

### VAT (EU + UK)
- Charge VAT at customer's destination rate (B2C).
- VAT-registered B2B customers can use reverse-charge — provide their VAT number, they self-assess.
- One-Stop-Shop (OSS) for EU — single registration, allocate per country.
- Display prices INCLUSIVE of VAT to consumers.
- Receipt must show VAT amount + rate per line.

### US sales tax
- Nexus rules — physical presence OR economic nexus (most states use $100k or 200 transactions threshold).
- Marketplace facilitator laws — if you sell on Amazon, Amazon collects; if you sell direct, you collect.
- Use a tax service (Avalara, TaxJar) — DIY is a regulatory rabbit hole.

### GCC (Saudi Arabia, UAE, Bahrain, Oman, Qatar, Kuwait)
- VAT rates vary (5% UAE, 15% KSA).
- E-invoicing mandatory in some (KSA: ZATCA Phase 2 enforced).

### Customs + duties (cross-border)
- DDP (Delivered Duty Paid) — you collect duties at checkout, ship clear.
- DDU (Delivered Duty Unpaid) — customer pays at delivery (poor UX).
- Display estimate at checkout; provider services (Zonos, Easyship) calculate.

## Consumer protection

### Right of withdrawal (EU)
- 14-day cooling-off period for distance-selling B2C.
- Must inform customer at order time.
- Refund within 14 days of return.
- Exclusions: perishables, customized, sealed software opened, etc.

### UK CRA (Consumer Rights Act)
- Goods must be of "satisfactory quality" — refund if not.
- Digital content — separate rules for downloadable / streaming.

### Canada (Competition Act, CPA)
- "Drip pricing" prohibited — total price upfront.
- No misleading advertising.

### Saudi Arabia (Consumer Protection Law)
- 7-day return for online purchases.
- Bilingual product info (Arabic + English).

## Accessibility

- WCAG 2.2 AA — non-negotiable in many jurisdictions for businesses serving the public.
- ADA (US) — case law applies websites despite no explicit law; budget for compliance.
- EAA (EU European Accessibility Act) — June 2025 enforcement for ecommerce.
- Provide accessibility statement on the site.

## Industry-specific

### Age-restricted (alcohol, tobacco, vape, supplements)
- Age gate at PDP.
- ID verification at delivery (provider-dependent).
- Geo-restrictions on shipping.

### Regulated goods (pharma, weapons, agriculture)
- Out of scope for general ecommerce — needs domain-specific compliance.

### Food + perishables
- Allergen labeling.
- Cold-chain shipping.
- Country-specific food labeling regulations.

## Audit + retention

- Order records: 7-10 years (tax authorities).
- Customer PII: minimize what you retain post-relationship.
- Financial records: 7-10 years.
- Audit logs: 1-3 years operational; longer for security-relevant events.
- Backups: encrypted at rest, retained per policy.

## Insurance

- Cyber liability — when (not if) a breach happens.
- Product liability — defective goods cause harm.
- Business interruption — site outage at peak.

## Common compliance gaps in v1

- Cookie consent banner that doesn't actually block trackers (fake compliance).
- "Privacy policy" copy-pasted from a template, not reflecting actual practice.
- No data deletion endpoint — manual via support, with no SLA.
- VAT shown excluding instead of including (illegal in EU B2C).
- No tax invoice (B2B customers can't reclaim VAT).
- Auto-stored card details "for convenience" without explicit opt-in.
- No 3DS step → high decline rate from EU issuers.
- Marketing emails without unsubscribe → CAN-SPAM / GDPR violation.
- No accessibility statement → instant lawsuit fodder in US.
