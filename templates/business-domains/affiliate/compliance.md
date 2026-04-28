# Affiliate — compliance + legal

Affiliate marketing intersects advertising law, tax, financial regulation, and privacy. The traps are mostly invisible until a regulator or auditor arrives.

## Advertising disclosure

### FTC Endorsement Guides (US, updated 2023)
- "Material connections" between advertiser and endorser must be clearly + conspicuously disclosed.
- Affiliate relationship = material connection.
- Acceptable disclosure formats: "#ad", "#sponsored", "Paid partnership with [brand]", "As an affiliate I earn from qualifying purchases."
- Disclosure must be: in same medium, before any link/recommendation, not buried.
- "Disclosure in profile bio" insufficient if endorsement is a separate post.
- Penalties: civil penalties up to $50,120 per violation (2024 figure, indexed annually).
- 2023 amendment: explicit liability for advertisers (not just endorsers) for failure to enforce.

### Endorsement requirements specifics
- Reviews of free products = disclosure required.
- Sweepstakes / giveaways = disclosure of how participants are selected.
- Compensated reviews can't claim "honest" without disclosing payment.
- Children's content: COPPA + CARU additionally apply.

### ASA (UK Advertising Standards Authority)
- "#ad" required for paid partnerships.
- CAP Code applies to affiliate content.
- Influencers + affiliates equally responsible.
- Sanctions: ad takedown + named-and-shamed list + Trading Standards referral.

### European country-specific
- Germany: clear "Werbung" or "Anzeige" labeling.
- France: ARPP guidelines + clear identification.
- Spain, Italy, Netherlands: similar transparency mandates.

### Influencer-platform standards
- Instagram Branded Content tag.
- TikTok Branded Content disclosure toggle.
- YouTube paid promotion disclosure flag.
- Compliance increasingly enforced by platforms themselves.

## Privacy + tracking

### GDPR (EU users)
- Click tracking with cookies = personal data processing.
- Lawful basis: consent (most defensible) or legitimate interest (contestable).
- ePrivacy Directive: cookie consent for ALL non-essential cookies, including affiliate tracking.
- "Strictly necessary" exemption does NOT cover affiliate cookies.
- IP addresses are personal data; storage requires basis.
- Right to erasure: affiliate networks must support deletion of clicker's data on request, even though click is anonymous.
- Cross-border data transfers (EU → US): SCCs + Transfer Impact Assessment post-Schrems II.

### ePrivacy Directive (EU)
- Updated regulation in trilogue; rules in Directive remain enforceable.
- Storage of / access to information on user device requires consent.
- Server-side tracking still requires consent for setting first-party cookie.

### CCPA / CPRA (California)
- Affiliate sharing = "sharing for cross-context behavioral advertising" → opt-out required.
- "Do Not Sell or Share" signal honor (Global Privacy Control).
- Right to know which affiliates received your data.

### Anti-Spam (CAN-SPAM US, CASL Canada, GDPR EU)
- Affiliate emails count as commercial; same rules as any marketing email.
- Unsubscribe + sender ID required.
- CASL (Canada): explicit consent required for any commercial email; statutory damages.
- GDPR + ePrivacy: opt-in default in most EU jurisdictions.

### LGPD (Brazil), POPIA (South Africa), PDPA (Singapore)
- Treat as GDPR-shape minimum.

## Tax

### US tax obligations
- 1099-NEC required for any US affiliate paid $600+ in calendar year.
- Backup withholding (24%) if affiliate fails to provide W-9 or has IRS-flagged TIN.
- Filing: 1099 to IRS + copy to affiliate by Jan 31.
- 1099-K (third-party payment networks): different threshold ($600 from 2024 — though delays); applies to PayPal/Venmo payouts.
- State 1099 filings vary.

### Non-US affiliate payments
- W-8BEN required for non-US individuals.
- W-8BEN-E for non-US entities.
- Treaty-rate withholding may apply (typically 30% default; reduced by treaty).
- 1042-S filing for foreign-paid amounts.

### VAT on affiliate commissions
- EU: B2B affiliate commissions typically reverse-charge (affiliate self-assesses VAT).
- VAT-registered affiliate provides VAT number to merchant.
- Non-VAT-registered EU affiliate: complications; some merchants charge VAT.
- UK post-Brexit: similar rules; UK VAT separate from EU.

### Self-employment + classification
- Affiliates are independent contractors, NOT employees.
- Misclassification risk if you exert too much control (mandatory hours, exclusive arrangement, employee-like benefits).
- IR35 (UK): if affiliate works like an employee, treat as employee for tax.
- AB5 (California): contractor classification three-prong test.

## Financial regulation

### Money transmitter / payment licensing
- High-volume payouts may trigger money-transmitter licensing (varies by US state).
- Cross-border payouts: AML compliance.
- PayPal/Wise/Stripe used as money-transmitter intermediaries to avoid direct license requirement (most platforms).

### AML / KYC
- Sanctions screening (OFAC list) before payout.
- KYC threshold-driven (often $10K+ payouts trigger enhanced KYC).
- Suspicious activity reporting (SAR) for unusual patterns.
- Beneficial ownership for entity affiliates.

### Crypto payouts
- FinCEN registration if you transmit crypto on behalf of others.
- Reporting (Form 8300 for $10K+ cash equivalents).
- Taxable event for affiliate at FMV at time of payout.
- 1099-MISC / 1099-K still applies for crypto compensation.

### Chargebacks + reversals
- Card-network rules require merchants honor chargebacks; affiliates don't get paid for charged-back orders.
- Holdback periods exist primarily for chargeback window (typically 120 days for cards).
- Network may impose monthly chargeback rate ceilings on affiliates.

## Cookie + tracking technical compliance

### Browser-level changes
- Safari ITP (Intelligent Tracking Prevention): 7-day cap on first-party cookies set by tracking domains; 24-hour for cookies set via JS document.cookie.
- Firefox ETP (Enhanced Tracking Protection): blocks known trackers.
- Chrome (rolling out): Privacy Sandbox + 3rd-party cookie deprecation.
- Adapt to server-side tracking + 1st-party setup + non-cookie identifiers (postback URLs).

### App tracking
- iOS ATT (App Tracking Transparency): explicit opt-in for IDFA usage.
- Android Privacy Sandbox: similar trajectory.
- MMP attribution must comply with SKAdNetwork on iOS; AdsPostback API on Android.
- IDFA / GAID-based attribution increasingly limited.

## Industry-specific affiliate restrictions

### Regulated verticals
- Gambling: license per jurisdiction; affiliates must comply with operator's license; UKGC affiliate code.
- Crypto: increasing licensing requirements; prohibited in several jurisdictions.
- Pharmaceuticals: prescription advertising restrictions per country.
- Financial services (loans, credit cards): TCPA/TILA/Reg Z + CFPB enforcement; disclosure requirements; UDAAP.
- Cannabis: state-by-state in US; federal vs state conflict; affiliate may be liable in shipping states.
- Nutraceuticals: FTC + FDA on health claims.
- Adult content: age verification + 2257 records (US).

### CBD / hemp
- Federal legality varies; state restrictions; advertising restrictions on platforms.

### Forex / CFD
- ESMA restrictions in EU; ASIC in Australia; FCA in UK.
- Promotion to retail clients restricted.

## Network-specific compliance

### IAB / Performance Marketing Association codes
- Voluntary industry standards for transparency, consent, clean clicks.
- Affiliate network certifications (TUNE, Impact, etc.) advertise these standards.

### Cookie stuffing / forced clicks (illegal)
- Setting cookies without user click action = wire fraud (US).
- Several historical convictions; reputational damage.

### Trademark bidding rules
- Programs commonly prohibit affiliates from bidding on trademark keywords in paid search.
- Brand violation evidence: SERP screenshots; tools like BrandVerity / Trademark Watcher.
- Sanctions: clawback + termination.

### Coupon affiliate restrictions
- Some programs exclude / cap commission on coupon-site traffic (passes value, not source).
- Define + enforce.

## Audit + retention

- Tax records: 7 years minimum (US); 6 years (UK); 10 years (Germany).
- Click + conversion data: 25 months minimum for chargeback windows + tax audit.
- W-9 / W-8: through filing year + retention period (4 years past due date).
- Communications + dispute records: 5 years typical.
- KYC records: 5 years past account closure.

## Common compliance gaps in v1

- No FTC disclosure enforcement (affiliates omit "#ad"; merchant equally liable post-2023 amendment).
- Cookie consent banner missing or non-compliant (sets affiliate cookie without consent).
- 1099 generation manual or absent (IRS letters).
- No backup withholding when W-9 missing.
- Non-US affiliates paid without W-8BEN (30% withholding obligation missed).
- VAT not handled on EU B2B commissions.
- Sanctions screening absent (OFAC violation).
- Cross-network fraud blocklist not subscribed (repeat fraudsters whitelisted by ignorance).
- Audit log absent (regulator inquiry → silence).
- "Strictly necessary" cookie classification mis-applied to tracking cookies.
- Right-to-erasure not propagated to click logs.
- Holdback period changed mid-program → lawsuits.
- Affiliate terminated without appeal process → reputational damage + Trading Standards referral (UK).
- Cross-border data transfer without SCCs (post-Schrems II).
- AML / SAR threshold tracking absent (FinCEN exposure).
