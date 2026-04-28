# LMS — compliance + legal

Education has its own regulatory stack on top of generic SaaS rules. Underage learners, accessibility lawsuits, and accreditation revocations are all common failure modes.

## Student data privacy

### FERPA (US — Family Educational Rights and Privacy Act, 1974)
- Applies to schools + universities receiving federal funds AND THEIR vendors via DPA.
- Educational records (grades, attendance, work) treated as confidential.
- Disclosure requires parental/student consent (student takes over consent at 18 OR enrollment in postsecondary).
- "Directory information" exception (name, email, dates) — student can opt out.
- Vendors process data only for the schooling purpose, not for marketing.
- DPAs (Data Processing Agreements) mandatory with each institutional customer.
- Right of access: students can review their records; correction requests honored.
- No commercial use of student data — GENERATIVE-AI training on student data is FERPA violation by default.

### COPPA (US — Children's Online Privacy Protection Act, 1998)
- Applies if you knowingly collect data from under-13 children.
- Verifiable parental consent BEFORE collecting personal info: credit card, signed form, video call, government ID.
- "School authorization" exception: if a school enrolls the child for educational use, school can consent on parent's behalf (with caveats).
- Data minimization: collect only what's needed for the activity.
- No behavioral advertising to under-13.
- Penalties: $51,744 per violation (2024 inflation-adjusted, FTC).

### GDPR + GDPR-K (EU children's data — under 16, varies 13-16 by country)
- Same shape as GDPR with stricter consent for children.
- "Children deserve specific protection" — clear, age-appropriate language.
- Higher bar for legitimate-interest basis when processing children's data.

### State student privacy laws (US)
- California SOPIPA (Student Online Personal Information Protection Act): bans targeted ads + selling student data + creating profiles for non-edu purposes; applies to K-12 vendors.
- Connecticut, Colorado, similar laws follow SOPIPA pattern.
- 30+ states have student privacy laws — track per-state.

### PIPEDA (Canada), POPIA (South Africa), LGPD (Brazil)
- GDPR-shaped, same student-protection logic.

### India DPDPA (Digital Personal Data Protection Act, 2023)
- Stronger restrictions on children's data; verifiable parental consent required.

## Accessibility (often the biggest legal exposure)

### WCAG 2.2 AA (the global baseline)
- Captions on ALL prerecorded video (Success Criterion 1.2.2).
- Audio description or alternative for video without dialogue (1.2.5).
- Transcripts available.
- Keyboard-operable throughout.
- Sufficient color contrast (4.5:1 for normal text).
- Resizable text to 200%.
- Focus visible.
- Skip-to-main link.

### ADA Title III (US)
- Public-accommodation websites — case law applies (Robles v. Domino's, 2019).
- Education services explicitly covered.
- DOJ rulemaking expected; assume WCAG 2.2 AA enforcement.

### Section 508 (US Federal)
- Required for federal agencies + recipients of federal funding.
- Most universities qualify.

### EAA (EU European Accessibility Act, June 28 2025)
- Mandatory for digital services in B2C.
- WCAG 2.2 AA minimum.
- Accessibility statement required.

### AODA (Ontario, Canada — full enforcement 2021)
- WCAG 2.0 AA minimum; some 2.1.

### Common educational accessibility requirements
- Math content: MathML or LaTeX rendered with screen-reader support (MathJax/KaTeX).
- Code samples: semantic markup, syntax highlight without color-only meaning.
- Quiz question types compatible with assistive tech (drag-drop a notorious problem).
- Live sessions: real-time captions (CART) for institutional customers.

## Accreditation

### US regional accreditors (Middle States, NEASC, etc.)
- Distance-learning programs need separate accreditation review.
- Identity verification of test-takers (proctoring).
- Substantive academic integrity policies.
- Records retention 5+ years post-graduation.

### CHEA (Council for Higher Education Accreditation)
- US umbrella; many institutional accrediting bodies under it.

### State authorization (US)
- Each state regulates degrees offered to its residents.
- SARA (State Authorization Reciprocity Agreement) covers most; California is famously a holdout.
- Failure to authorize = degrees illegal in that state.

### EU accreditation
- Bologna Process (3-cycle bachelor/master/doctorate).
- ECTS credit transferability.
- National-level recognition; national qualification frameworks.

### Quality certifications
- Quality Matters (QM) — course design rubric.
- IACBE / AACSB — business education.
- ABET — engineering / computing.

These don't directly bind your code, but consume requirements (e.g. "every learning objective must be assessed and reportable").

## Tax on digital education

### US sales tax
- Most states do NOT tax pure digital education service.
- BUT: bundled access to software + downloadable materials may be taxable in some states.
- Live instruction often clearly exempt; self-paced often less clear.
- Use a tax service.

### EU VAT on digital services
- Charge VAT at consumer's destination rate (B2C).
- B2B reverse charge if VAT-registered.
- OSS for EU-wide single registration.
- "Electronically supplied services" classification — automated delivery (self-paced video) is taxable; live instruction with substantial human involvement may be exempt.

### UK VAT
- Same shape as EU post-Brexit.

### Education-specific exemptions
- Some jurisdictions exempt accredited education entirely.
- "Tuition" by a recognized educational provider often exempt.
- Marketplace + bootcamp + non-accredited usually NOT exempt.

## Refunds + consumer protection

### EU 14-day cooling-off
- Distance-selling B2C: 14 days post-purchase to cancel.
- Exception: digital content access begun with consumer's express consent — can waive cooling-off.
- Confirm consent + waiver explicitly at checkout.

### US state refund laws
- California education code: refunds prorated to date of withdrawal for many programs.
- Bootcamp regulations (BPPE in California): mandatory refund policy + tuition recovery fund.

### Industry standard
- 30-day money-back is common (Udemy, Coursera).
- Specify exclusions (certificate already issued, % completion threshold).

## Payments

- PCI-DSS via provider-hosted fields (same as ecommerce).
- Subscription billing: clear renewal disclosure, easy cancel (FTC ROSCA + state subscription laws).
- B2B invoicing for institutional customers (NET-30, NET-60 typical).

## Content + copyright

### DMCA / DSA takedowns
- Counter-notice procedure required (US).
- DSA notice + action mechanism (EU).
- Repeat infringer policy (terminate accounts after N strikes).

### Instructor copyright
- Instructor retains content copyright by default; platform gets a license.
- Document scope of license: marketing use? Re-edit? Sublicense?
- Platform-created content: assignment of rights or work-for-hire.

### Open licenses
- Creative Commons (CC BY, CC BY-SA, etc.) for OER (Open Educational Resources).
- Attribution requirements MUST be honored.

### Plagiarism + academic integrity
- Plagiarism detection (Turnitin, Copyleaks) standard for written assignments.
- Honor code disclosure required for accredited courses.
- Proctoring for high-stakes exams.

### Stock content licensing
- Image, music, font licenses — track per-course.
- Royalty-free stock platforms (Envato, Adobe Stock) — verify license tier.

## Anti-fraud

### Certificate fraud
- Verification URL public + signed.
- Serial number unguessable.
- Revocation list checked at verification.
- Some platforms use blockchain certificates (overkill but PR-friendly).

### Watch-time fraud
- Bots auto-play videos to claim refund AND keep certificate.
- Detection: interaction signals, mouse movement, focus events, anti-tampering on player.
- Rate-limit watch-time growth to real-time.

### Account sharing
- One paid account, 50 students using credentials.
- Detection: concurrent sessions, IP variance, device fingerprints.
- Tradeoff: too aggressive = false positives; calibrate.

## Health + safety (for content)

### Mental health content
- Content disclaimers ("not a substitute for medical advice").
- Crisis-resource pop-ups in some content categories.

### Restricted topics
- Some jurisdictions restrict politicized education content.
- Some platforms ban gambling / weapons / certain financial advice.

## Data retention

| Record | Retention | Reason |
|---|---|---|
| Student enrollment + grades | 5-10 years post-graduation | Accreditation, transcripts |
| Quiz/assignment submissions | 3-7 years | Disputes + appeals |
| Tax invoices | 7-10 years | Tax audit |
| Certificate records | Permanent | Verification requests |
| FERPA-protected records | Per institution's policy | Often 5 years post-completion |
| Audit logs (instructor edits, admin actions) | 3-5 years | Compliance reviews |
| Video raw uploads | Per platform policy | Storage cost vs re-encode capability |

## Common compliance gaps in v1

- Captions absent — instant ADA/EAA exposure; institutional customers won't sign.
- Quiz answers shipped to client — security audit fails.
- COPPA flow absent on platform that ANYONE under 13 might use → FTC fines.
- FERPA DPA not offered to institutional customers — they can't legally sign.
- Refund policy ambiguous → consumer-protection complaints.
- Certificate verification URL absent → recruiters reject; brand damage.
- "Course updated mid-enrollment" with no notification → lawsuits in some jurisdictions.
- Watch-time fraud detection absent → revenue inflation + refund-fraud cycle.
- Subscription auto-renew without ROSCA disclosure → state AG action.
- Non-EU instructor selling to EU buyers → VAT not collected → fines on operator (DAC7-style).
- Student data used to train ML / LLM without explicit opt-in → GDPR + FERPA violation.
- Plagiarism reports stored unsanitized (showing source URLs from other students) → cross-student data leak.
