# Booking — compliance + legal

Bookings touch consent, fees, refunds, sometimes health data. Vertical matters: a salon's regulatory load is light; a clinic's is heavy.

## Consumer protection

### Cancellation + no-show fees
- Disclosure required at booking (most jurisdictions): the fee, the window, the policy must be visible BEFORE the customer commits.
- Surprise fees ("we charged you $50 because you didn't show") trigger consumer-protection complaints + chargebacks.
- EU: Consumer Rights Directive — if the fee isn't transparently disclosed pre-contract, it's unenforceable.
- US: FTC + state AGs target deceptive cancellation practices.
- UK: CRA "unfair terms" — penalty fees disproportionate to operator's actual loss = unenforceable.

### Late-cancellation fee math
- Most defensible: fee = lost revenue * P(can't fill slot) — not punitive.
- Arbitrary "100% no-show fee" can be void as a penalty clause in EU/UK.
- Healthcare: many jurisdictions require itemized billing for missed-appointment fees.

### Deposit handling
- Deposits typically refundable until cancellation cutoff.
- Forfeit policy must be disclosed.
- EU: 14-day cooling-off for distance-sale services in some categories — but services already performed are excluded; tricky for booking systems where the "service" is the slot reservation itself.

### EU Distance Sales Directive
- "Performance during cooling-off period" requires explicit consumer consent + acknowledgment that withdrawal right is lost.

### "No refund if no-show" policy
- Must be explicit + acknowledged.
- Cannot apply if business itself was at fault (provider sick, business closed unannounced).

## Privacy

### GDPR
- Customer name + contact + booking history = personal data.
- Lawful basis: contract (for the booking itself), legitimate interest (no-show prevention reminders), consent (marketing).
- Right of erasure: usually granted, but bookings within retention period (financial / legal) can be anonymized.
- Sensitive data (health-related notes, allergies) = special category; needs explicit consent OR vital interests basis.
- DPA with calendar/email/SMS providers.

### CCPA / CPRA (California)
- Same shape; standard ecommerce playbook.

### HIPAA (US healthcare bookings)
- PHI (Protected Health Information): name + appointment with healthcare provider IS PHI.
- Encrypted at rest + in transit.
- BAA (Business Associate Agreement) with every vendor that touches PHI: hosting, email, SMS, analytics.
- Audit log of every PHI access — 6 years retention.
- Breach notification: 60 days for breaches affecting 500+ individuals (HHS + media + state AG).
- Texts containing PHI: most consumer SMS providers (Twilio, MessageBird) offer HIPAA mode + BAA — DEFAULT mode does not. Configure correctly.
- Voicemails with PHI: leave only "this is a reminder, please call" — no diagnosis details.

### PHIPA (Ontario), other provincial healthcare privacy
- Similar to HIPAA in shape; provincial data residency requirements (data may need to stay in Canada).

### Cookie consent
- Same as ecommerce: block analytics + marketing until consent.

## Communications consent

### TCPA (US — Telephone Consumer Protection Act)
- Marketing SMS / robocalls require prior express WRITTEN consent.
- Transactional SMS (booking reminders) generally allowed without explicit "marketing" consent BUT customer must have provided phone in context where reminders are reasonable.
- Per-violation fine $500-$1500 (statutory).
- Class actions are real; massive damages possible.

### CAN-SPAM (US email)
- Unsubscribe in every marketing email.
- Honest "From" + "Subject."
- Physical postal address.

### CASL (Canada Anti-Spam Legislation)
- Express consent required for commercial messages.
- Strict; fines real.

### GDPR ePrivacy
- Marketing email/SMS requires opt-in (not pre-checked).
- Transactional reminders OK under "necessary for performance of contract."

### India DPDPA + TRAI
- Commercial SMS requires DLT registration in India.

## Tax

### VAT on services (EU)
- Most personal services are taxable at standard rate.
- Healthcare services often exempt (varies country).
- B2C: VAT at customer's destination (varies by service category).

### US sales tax on services
- Most states do NOT tax personal services (haircut, massage).
- Some do (Hawaii, New Mexico, South Dakota, West Virginia, others varying).
- Memberships + retail product sales bundled in: usually taxable.
- Use a tax service.

### GCC (KSA / UAE)
- VAT applies (5% UAE, 15% KSA).
- E-invoicing requirements (KSA ZATCA).

## Industry-specific

### Healthcare
- HIPAA (US) — see above.
- State medical board rules — provider licensure verification at booking.
- Telehealth: different rules per state for cross-state video visits.
- Controlled-substance prescribing requires in-person OR DEA-registered telehealth.
- No-show notification regulations (some states regulate medical no-show fees).
- Mental health: stricter consent + privacy.

### Personal services / beauty (salon, spa)
- State licensure of operators (cosmetology license).
- Sanitation reporting (post-COVID, often required).
- Allergy / patch-test records (waxing, hair color) — keep for liability defense.
- Minor consent (under-18 service in some states requires parental consent).

### Fitness
- Waiver / liability release at signup.
- Trainer certification verification.
- Membership cancellation laws (most states have specific rules: written notice, refund of pre-paid).
- "Health Spa Act" in some states (Texas, Florida) regulates fitness contracts.

### Restaurants
- ADA accessibility for booking site.
- Allergen info disclosure on menu.
- Reservation deposit law (varies).

### Legal services
- ABA Model Rules — confidentiality.
- Ethics around "intake" vs. "engagement" — intake info from prospective clients is confidential even if no engagement formed.

### Childcare / education
- Mandatory reporter laws — operator may be required to report suspected abuse.
- Vaccination records (some states).

### Cannabis / restricted services (where legal)
- State-specific regulation — age verification at booking.
- ID check at appointment.

### Adult services
- Many platforms ban; if allowed locally, KYC + age + payment-processor restrictions are intense.

## Accessibility

- WCAG 2.2 AA — booking form keyboard accessible, screen-reader friendly.
- Color-only state indicators forbidden.
- Date pickers a notorious accessibility hole — test with NVDA/VoiceOver/JAWS.
- ADA Title III applies to booking websites in US.
- EAA (EU, June 2025): public-facing booking apps in scope.

## Data retention

| Record | Retention | Reason |
|---|---|---|
| Bookings (financial) | 7-10 years | Tax + audit |
| Cancelled / no-show records | 1-3 years | Pattern detection, customer service |
| Customer notes (non-medical) | Until account deletion + 1 year | GDPR + customer service |
| Medical / health notes | Per local healthcare law (often 5-15 years) | Healthcare retention |
| Audit logs (PHI access) | 6 years (HIPAA) | Regulatory |
| Audit logs (general) | 1-3 years | Operational |
| Recordings (if any) | Per local consent law | Wiretap / two-party consent states |
| Payment data | NEVER store PANs; retention of tokens per provider | PCI |

## Insurance

- General liability — slip-and-fall in physical location.
- Professional liability / E&O — service errors.
- Cyber — PII / health data breach.
- Workers' comp — staff injuries.

## Common compliance gaps in v1

- Cancellation fee policy buried in T&Cs only — not displayed at booking → unenforceable + chargebacks.
- SMS reminders without opt-in flow → TCPA class action.
- Healthcare bookings without HIPAA hosting / BAA → HHS investigation + fines.
- Booking confirmations to customer's email + name in subject → some workplaces flag as PHI exposure.
- Waiver / consent missing in fitness / beauty / spa → liability exposure.
- Voicemail reminders revealing diagnosis ("This is reminding you of your colonoscopy tomorrow") → HIPAA breach.
- Automated reminders skipping consent on dynamic content → TCPA penalty class.
- Calendar sync sending PHI to providers without BAA → HIPAA breach by act of integration.
- Minor consent absent → state law violations.
- Membership auto-renewal without ROSCA-compliant disclosure → state subscription law.
- "Up-front payment, refund less fee" without clear refund timing → consumer-protection complaints.
- Stored payment for "convenience" without explicit opt-in → state privacy + EU dark-pattern fines.
- TZ display bug serving customer in operator TZ → no-shows blamed on the customer (real cause: bad UX).
