# Restaurant POS — compliance + legal

Restaurants are one of the most-regulated consumer sectors: payment + tax + labor + food safety + alcohol + accessibility + fiscal. The rules are aggressively local. Ship a generic POS and you'll be blocked from entire countries.

## Payment

### PCI-DSS
- Never store / log / transmit PAN. Use certified terminals (Stripe Terminal, Square Terminal, Clover, Verifone, Ingenico) that handle card data outside your application scope.
- SAQ-B-IP or SAQ-B depending on terminal type; SAQ-C for integrated-payment-apps (heavier). Terminals in P2PE mode keep you at SAQ-B-IP.
- Tip adjust: card authorized for base + tax at swipe, captured later with tip added at day-close. Capture must complete within provider window (Stripe: 7 days; Square: 6 days).
- Save-on-file (bar tabs, loyalty): provider token only, NEVER raw PAN even encrypted.
- Quarterly ASV scans (provider handles for hosted terminals).

### EMV liability shift (US, 2015; worldwide earlier)
- Chip transactions accepted via chip reader = liability on issuer.
- Swipe on chip card where chip reader available = liability on merchant. All terminals must support chip.
- Contactless (NFC) effectively required post-pandemic.

### 3DS / SCA (EU + UK)
- Most card-present transactions exempt (PIN serves as authentication).
- Stored-card online payments: SCA applies (tokenized terminal tap does not, it's card-present).

### Cash handling
- Drawer accountability per shift, sealed count at clock-in/clock-out.
- Over/short logged. Threshold triggers investigation.
- Jurisdiction-specific rounding rules (Switzerland, Sweden, Canada have no 1-cent coins → round to 5¢/5öre).

## Fiscal / e-receipt compliance

This is where a generic POS dies. Every country has its flavor; selling in each requires local certification.

### Italy — SDI (Sistema di Interscambio)
- Every B2B invoice via XML through SDI platform.
- B2C receipts via fiscal printer (RT — Registratore Telematico) or e-receipt Lotteria degli Scontrini.
- Daily fiscal Z-report transmission.
- POS integration certified by Agenzia delle Entrate; generic POS cannot transact.

### Brazil — NFC-e (Nota Fiscal de Consumidor Eletrônica)
- Every consumer transaction → XML invoice with state tax authority signature.
- SEFAZ per state; different cert per state.
- QR code on receipt links to gov portal for customer verification.

### Saudi Arabia — ZATCA Phase 2 (Fatoorah)
- E-invoicing mandatory. Each receipt signed via cryptographic stamp, reported to ZATCA.
- QR code with TLV-encoded data per invoice.
- Integration with ZATCA Fatoora platform.
- Bilingual (Arabic + English) required.

### Mexico — CFDI (Comprobante Fiscal Digital por Internet)
- Every transaction produces CFDI XML, signed by PAC (authorized certification provider).
- RFC tax ID per customer (B2B) or generic "Público en general" for B2C.

### Spain — Veri*factu (effective Jan 2026)
- Real-time invoice reporting via anti-fraud software.
- Certified software required; receipts chained by hash for audit.

### Greece, Hungary, Portugal, Poland, Romania, Czech Republic, Slovakia
- Each has fiscal printer or real-time reporting regime. EU Directive 2022/542 aligning some but rollout is uneven.

### Germany — KassenSichV / TSE (Technische Sicherheitseinrichtung)
- Tamper-proof fiscal module signing every transaction.
- Signed receipt with QR code.
- Cloud TSE allowed since 2020 (Fiskaly, Epson, D-Trust).

### France — NF525 certification
- POS software certified; prints receipts with secure sequence number.
- Archive 6 years, closed per period with locked totals.

### UK + US
- No mandatory e-fiscal at federal level (US sales tax is state-by-state; UK HMRC Making Tax Digital affects VAT reporting but not receipt format).
- Receipt requirements light; accurate VAT totals on UK receipts.

### Gulf (UAE, Bahrain, Kuwait, Qatar, Oman)
- VAT + fiscal receipt requirements evolving. Track local tax authority updates.

## Food safety + allergen disclosure

### EU Food Information Regulation (FIR) 1169/2011
- 14 major allergens must be declared on menus: gluten, crustaceans, eggs, fish, peanuts, soy, milk, nuts (tree), celery, mustard, sesame, sulphites, lupin, molluscs.
- Written form or verbal on request with signage.
- Cross-contamination warnings expected.

### Natasha's Law (UK, Oct 2021)
- Pre-packed-for-direct-sale food must list full ingredients + allergens on label.
- Applies to delis, sandwich counters, bakery pre-pack.

### FDA Menu Labeling (US)
- Chains with 20+ locations must display calorie counts on menus.
- NYC Local Law 50: salt warning icon for dishes >2300mg sodium.

### California Prop 65
- Warning labels for known carcinogens (acrylamide in fried foods, coffee carve-out).

### HACCP + local food safety codes
- Not POS concern directly, but allergen flag data lives in menu → POS must handle.

## Alcohol service

### US — state-specific regs + local (county/city)
- Age of purchase: 21 federal.
- ID check at purchase; many states require scan + retention.
- Last call + cutoff times vary by state.
- Happy hour restrictions (IL, MA, UT have limits).
- Dram shop liability (serving visibly intoxicated guest → restaurant liable for harm).

### EU — varies
- Most countries 18 (Germany 16 for beer/wine).
- Last-drink time sometimes capped (France 22:00 in some municipalities).
- Advertising restrictions (Loi Évin in France).

### Saudi Arabia + most Gulf + some Asia
- Alcohol prohibited for consumer sale → feature-flag menu entirely.

### ID verification at POS
- Age prompt on alcohol item.
- ID-scanner integration (ID scanner + DOB extraction).
- Minor: manual age entry OK in some jurisdictions, scan-required in others (FL, UT).

## Tips + tip pooling

### US — FLSA (Fair Labor Standards Act)
- Tip credit allowed: employer pays $2.13/hr + tips must bring to $7.25 min wage. Shortfall: employer makes up.
- Tip pooling: among traditionally-tipped employees (servers, bartenders, bussers, food runners). Back-of-house (cooks, dishwashers) INCLUDED only if no tip credit taken (post-2018 CAA amendment).
- Mandatory service charges are NOT tips in FLSA — goes to employer who may redistribute.
- Employee must declare tips (Form 4070 monthly + W-2).
- IRS 8027 Tip Allocation for large food/beverage establishments.

### California + Washington State + Oregon + Nevada
- No tip credit allowed — tipped employees must receive full minimum wage plus tips.

### UK — Tipping Act 2023 (Allocation of Tips Act, effective Oct 2024)
- 100% of tips to workers (no employer deduction allowed).
- Fair written policy on allocation.
- Tronc schemes must pass allocation test.

### EU — varies
- Germany: tips are employee income, but mandatory service fee goes to employer.
- France: "service compris" (service included) by law since 1985; tips discretionary on top.

### Italy, Greece, Spain
- Tipping is discretionary, low percentage. Mandatory service fee common; declared as operator income.

### ID of mandatory vs voluntary on receipt
- Mandatory service charges must be clearly labeled as such (not "tip"). US IRS ruling 2012-18: must be separately stated or it's a tip.
- Misclassification = payroll tax underpayment penalties.

## Labor law (front-of-house + kitchen)

### Minor employment (US)
- <16: max 3 hr school days, 18 hr school week, 40 hr non-school week (FLSA). States stricter.
- No hazardous equipment (slicers, fryers) for under-18.

### Break laws
- California: 30-min meal break for shift > 5 hr, 10-min rest every 4 hr.
- Most states + federal: no mandated break (industry convention).

### Predictive scheduling (Fair Workweek laws)
- NYC, San Francisco, Philadelphia, Seattle, Oregon, Chicago, Emeryville CA.
- Schedule 7-14 days in advance; premium pay for late changes.
- POS should capture scheduled vs actual clock times.

### Tip declaration + payroll integration
- Federal: IRS Form 4137 for under-declared tips.
- Must have documented declaration mechanism.

## Accessibility

### ADA (US)
- Public-facing POS (kiosk, customer display, QR pay) subject to accessibility case law.
- Kiosk height + reach: 48 in max reach; screen readable by users with vision impairment.
- Menu printed with sufficient size + contrast (14pt+ recommended).

### EAA (EU European Accessibility Act, June 2025)
- Self-service terminals (kiosks) included; required screen reader + large-text mode + physical accessibility.

### WCAG 2.2 AA
- Customer-facing apps (QR pay, online order) must meet; complaints + lawsuits common in US.

## Privacy

### GDPR (EU)
- Reservation + loyalty data: lawful basis (contract for booking; consent for marketing).
- Reservation emails must have unsubscribe for marketing uses.
- Right to erasure on request; reservation records may be held longer under legitimate interest for chargeback window.

### CCPA (California)
- Customer data from online orders / loyalty subject to "Do Not Sell" opt-out.

### GCC (KSA PDPL, UAE DPL)
- Similar shape to GDPR; local data storage sometimes required.

### Card data + loyalty linking
- If linking card tokens to loyalty profile: explicit consent at enrollment.
- Loyalty profile deletion cascades to token deletion.

## Delivery platform tax (US state-by-state expanding)
- Marketplace facilitator laws: Uber/Doordash/Grubhub collect sales tax in many states.
- Restaurant must identify which orders were platform-collected vs self-collected to avoid double-remit.

## Retention

- Transaction records: 7 years (US IRS), 10 years (most EU).
- Tip declaration records: 7 years.
- Fiscal receipts (Italy, Brazil, KSA): as per local law, usually 5-10 years.
- Video surveillance: 7-30 days typical (some jurisdictions cap).
- Employee scheduling + clock records: 3 years (US FLSA), 2 years (most EU).

## Insurance

- General liability (slip + fall).
- Liquor liability (dram shop).
- Cyber liability (card data + loyalty breach).
- Employment practices liability (tip disputes, minor employment violations).
- Commercial property (kitchen fire).

## Common compliance gaps in v1

- No REPRINT mark on receipt copies — fiscal jurisdictions flag this as evasion.
- Tip on subtotal vs total inconsistent on receipt vs card reader screen.
- Service charge line labeled "tip" (FLSA/IRS violation; tax + payroll impact).
- Tip pool algorithm undocumented + unauditable — lawsuit bait.
- Alcohol age prompt missing or trivially bypassable ("Yes, I'm 21" click-through).
- Allergen flags present in POS data but absent on customer menu (EU FIR violation).
- Fiscal printer integration only as "roadmap" — blocks launch in Italy/Brazil/KSA/Greece.
- Over-18 hours worked by minor employees without tracking.
- Break enforcement absent in CA (shift > 5 hr without meal break logged).
- Cash over-short not logged nightly → fraud window.
- Customer loyalty + reservation data without GDPR deletion path.
- Dram-shop overservice detection absent (many-drinks-same-guest within window).
- Calorie counts missing on menus for chains 20+ in US.
- No audit log on price overrides / voids / comps; inventory shrinkage invisible.
