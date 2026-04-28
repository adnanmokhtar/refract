# Social — compliance + legal

Social platforms operate under intermediary-liability regimes that are jurisdiction-specific and rapidly evolving. Get this wrong = platform-level enforcement actions, not just fines.

## Intermediary liability

### Section 230 (US Communications Decency Act, 1996)
- Provides immunity for user-generated content with caveats.
- Does NOT immunize federal criminal law violations, IP infringement (DMCA), or — post-FOSTA-SESTA (2018) — sex trafficking content.
- Moderation in good faith does NOT waive immunity ("Good Samaritan" 230(c)(2)).
- Active congressional debate on reform — track changes; carve-outs likely to expand.

### Digital Services Act (DSA, EU, fully effective Feb 2024)
- Applies to all online platforms serving EU users; tiered obligations by size.
- "Very Large Online Platforms" (VLOPs, >45M EU monthly users): designated by Commission; extra transparency + risk-assessment obligations.
- Required: notice-and-action mechanism for illegal content, statement of reasons for moderation actions, internal complaint handling, transparency reports, terms enforcement consistency.
- Algorithmic transparency: "why am I seeing this" affordance + opt out of profiling-based ranking.
- Trusted Flaggers: reports from designated flaggers prioritized.
- Penalties: up to 6% of global annual turnover.

### NetzDG (Germany, 2017) → integrated into DSA
- 24-hour removal for "manifestly illegal" content; 7 days for ambiguous.
- Reporting officer in jurisdiction.

### Online Safety Act (UK, 2023, phased rollout 2024-2025)
- Duty of care to users, especially children.
- Risk assessments + age assurance for adult content.
- Ofcom enforcement; fines up to £18M or 10% of global revenue.

### India IT Rules (2021, amended 2023)
- "Significant social media intermediaries" (>5M users): grievance officer, traceability of message originators (encrypted-messaging compliance fight).
- 24-hour removal for unlawful content; 36-hour for non-consensual content.
- Local data storage + grievance officer requirements.

## Content moderation transparency

### DSA transparency reports
- Number of orders received from authorities, by category.
- Notices received, breakdown by reason + content type.
- Action taken: time-to-action, reversed-on-appeal rates.
- Automated detection accuracy disclosure.
- Required at least every 6 months for VLOPs; annually for others.

### Statement of reasons
- Per-action notice to affected user explaining: type of action, factual basis, legal/policy basis, redress options.
- Submitted to Commission's transparency database for VLOPs.

### Trusted Flagger programs
- Designated organizations whose reports are prioritized.
- Maintain workflow + SLA.

## Privacy

### GDPR (EU users worldwide)
- Lawful basis for processing each data type (consent, contract, legitimate interest).
- Privacy policy mapping each processing purpose.
- Right to access, rectification, erasure, portability, objection.
- Right to erasure complications: deleted user's content quoted/replied-to by others — anonymize OR strip OR cascade delete? Document the choice; defensibly justify.
- DPO required (mandatory for monitoring at scale).
- DPIA before high-risk processing (profiling for content ranking).
- 72-hour breach notification to supervisory authority.
- Special category data (health, sexual orientation, political opinion): explicit consent + heightened protection.

### CCPA / CPRA (California)
- "Do Not Sell or Share My Personal Information" — applies to behavioral ad targeting on social.
- Opt-out signal compliance (Global Privacy Control header).

### COPPA (US, 1998 — children online)
- Under-13 users prohibited from data collection without verifiable parental consent.
- Many platforms simply ban under-13 (TOS) — but enforcement requires actual age detection, not just self-declaration.
- FTC fines: TikTok $5.7M (2019), YouTube $170M (2019).

### Age Appropriate Design Code (UK ICO, similar in CA + other states)
- High-privacy defaults for children.
- Profile only with strict justification.
- No nudges to lower privacy or share more.

### Biometrics (BIPA Illinois, similar in TX, WA)
- Face recognition / facial templates require informed consent + retention schedule.
- Statutory damages per violation — Facebook settled for $650M (2021) over photo tagging.
- Avoid biometric features unless you can prove consent.

## Child safety + CSAM

### CSAM mandatory reporting
- All US-based platforms must report CSAM to NCMEC's CyberTipline (18 U.S.C. § 2258A).
- EU CSAM regulation (proposed/in trilogue): scanning obligations under debate; track outcome.
- PhotoDNA / NeuralHash matching against known-CSAM databases — table stakes.
- Once CSAM is detected: preserve evidence (don't delete), file report, terminate user, log.

### Grooming + child exploitation
- Detection signals: age mismatch in DMs, pattern of contact with multiple minors, location requests.
- Routes to specialized review queue, not regular moderation.

### KOSA (US, proposed) + state-level child-safety laws
- Duty of care toward minors.
- Default-private accounts for minors.
- Limit feature exposure (DMs, ads, addictive design patterns) for minors.

## Copyright + IP

### DMCA (US, 1998)
- Notice-and-takedown safe harbor.
- DMCA agent registered with US Copyright Office (renewed every 3 years).
- Counter-notice procedure: 10-14 day window before reposting.
- Repeat infringer policy required for safe harbor.

### DMCA abuse
- False takedowns weaponized for harassment/competition.
- Document review process; counter-notice support.
- Lenz v. Universal: rightsholders must consider fair use before filing.

### Trademark / impersonation
- Verified-account systems serve trademark protection function.
- Brand protection requests from rights holders — separate workflow.

### EU Copyright Directive (Article 17, 2019)
- Platforms liable for copyrighted content unless best-effort licensing + content recognition.
- ContentID-style filtering effectively required at scale.

### User-generated content licensing
- TOS must grant platform a license to host/display/distribute user content.
- License must terminate on user content deletion (privacy expectation).
- Sub-licensing (to advertisers, partners) controversial — explicit consent for that scope.

## Defamation + harmful speech

### Country-specific defamation
- US: Section 230 protects platform; user can be sued by victim.
- UK: stricter — platform may be co-liable if on notice.
- France: hate-speech laws (Loi Avia struck down but DSA fills role).
- Germany: holocaust denial illegal.
- Specific legal-removal queues per jurisdiction.

### NCII (non-consensual intimate imagery / "revenge porn")
- US: state laws + EARN IT debates.
- UK: Voyeurism Act, Online Safety Act explicit.
- 24-48 hour removal SLA expectations.
- Hash-and-block (StopNCII.org) integration table stakes.

## Accessibility

- WCAG 2.2 AA — non-negotiable.
- Alt text for images (encourage + auto-generate).
- Captions on video.
- Screen-reader compatibility through whole flow including modals + media viewer.
- ADA US case law applies; settlements run $50K+.
- EAA (EU) effective June 2025.

## Content monetization compliance

### Creator payouts
- 1099-NEC for US creators >$600/year.
- VAT on platform service fee (depending on creator country + platform country).
- Anti-money-laundering (AML) on payout flows.

### Advertising disclosure
- FTC: "ad" / "paid partnership" labels for sponsored content.
- ASA (UK): #ad required.
- Platform-supplied disclosure tooling (Instagram Branded Content tag, etc.).

## Content retention + audit

- Posts: as long as visible + per user contract.
- Deleted posts: hold for legal hold periods (criminal investigations) — typically 90 days.
- DM / private content: per privacy policy (typically retained until user deletes; backup retention disclosed).
- IP logs: 30-180 days for fraud / abuse investigations.
- Moderation action logs: minimum 6 months (DSA), often 2 years for legal defense.
- Identity verification documents: minimum required + delete promptly (GDPR data minimization).

## Common compliance gaps in v1

- No DSA transparency mechanism (silent moderation; users don't know what was actioned).
- No DMCA agent registered (loses safe harbor).
- Privacy policy says "we won't share your data" but ESP / analytics integration sends PII (contradicts; lawsuit-bait).
- Right-to-erasure handled manually with no SLA (GDPR-mandates without delay).
- Under-13 users not detected (COPPA fines).
- Identity verification documents kept indefinitely (GDPR data minimization).
- Block leak → harassment continues → user sues platform for inaction.
- CSAM detection absent or only on reported content (US legal exposure if hosting at all).
- "Why am I seeing this" affordance missing (DSA risk).
- No appeal process for permanent bans (DSA + UK Online Safety + general consumer-rights risk).
- Self-harm reporting routed to spam queue (PR + safety nightmare when user dies).
- Age gate as text input (not effective; trivially bypassable; doesn't satisfy COPPA).
