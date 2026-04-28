# Healthcare — compliance + legal

Healthcare regulation is denser than any other vertical. Every architectural decision has a compliance overlay. Retrofitting compliance after launch is functionally a rewrite.

## HIPAA — Privacy Rule (45 CFR §§ 160, 164 Subparts A & E)

Effective since 2003; modernized via HITECH (2009).

- **Covered Entities** (CE): providers, payers, clearinghouses. Responsible directly.
- **Business Associates** (BA): vendors handling PHI on behalf of CE. Responsible since 2013 HITECH Final Rule.
- **BAA** (Business Associate Agreement): mandatory contract; if you process PHI for a CE, you sign one. SaaS without a BAA = HIPAA violation by the CE customer.
- **Minimum Necessary**: access only PHI needed for the job role. Engineers querying full PHI in prod = violation.
- **Permitted disclosures**: Treatment, Payment, Operations (TPO) without authorization. Other purposes need patient authorization.
- **Right of Access**: patient may request copy in form/format requested if readily producible. 30-day response (one extension to 60). $0.10/page if paper; reasonable cost for electronic.
- **Right to Amendment**: patient can request correction; CE can deny but must document.
- **Right to Accounting of Disclosures**: list of non-TPO disclosures over past 6 years.
- **Notice of Privacy Practices** (NPP): given at first encounter; acknowledgment captured.
- **Marketing**: communications about products/services need authorization; refill reminders are NOT marketing.

## HIPAA — Security Rule (45 CFR §§ 160, 164 Subparts A & C)

ePHI specific. Not optional. Audited.

- **Administrative safeguards**: workforce training, sanction policy, risk analysis, contingency plan, BAA tracking.
- **Physical safeguards**: facility access, workstation security, device disposal.
- **Technical safeguards**: access control (unique user IDs, automatic logoff, encryption), audit logs, integrity controls, transmission security (TLS).
- **Required vs Addressable**: every spec is one or the other. "Addressable" ≠ optional — must implement OR document why an alternative is equivalent.
- **Risk Analysis**: annual; document threats, vulnerabilities, controls, residual risk. OCR will ask for this in any breach investigation.

## HITECH (2009) + Breach Notification

- Breach = unauthorized acquisition/access/use/disclosure of unsecured PHI compromising security or privacy.
- 4-factor risk assessment: nature/extent of PHI, who received it, was it actually viewed, mitigation.
- Notify affected individuals: 60 days from discovery.
- Notify HHS: 60 days for ≥500 affected; annual log for <500.
- Notify media: 60 days if ≥500 affected in a state/jurisdiction.
- Encryption is a safe harbor — encrypted PHI breached is NOT a reportable breach (per NIST SP 800-111 / 800-52).

## 42 CFR Part 2 — Substance Use Disorder Records

Stricter than HIPAA. Applies to federally-assisted SUD treatment programs.

- **Re-disclosure prohibited** without specific authorization, even within the same health system.
- **Patient consent required for almost any disclosure** including TPO (this is THE distinction from HIPAA).
- **2024 final rule** aligned with HIPAA more for TPO but added requirement to segregate SUD records and apply special protections.
- **Tag SUD records** in your data model from day one. Retrofitting is brutal.

## 21st Century Cures Act — Information Blocking (effective 2021, penalties 2024)

- CE/developers/HIN must NOT engage in practices that interfere with access/exchange/use of EHI (electronic health information).
- 8 exceptions (preventing harm, privacy, security, infeasibility, content/manner, fees, licensing, health IT performance) — narrow, must document.
- Penalties: developers up to $1M per violation; CMS payment adjustments for providers.
- Practical: lab results released to portal without "review embargo" beyond narrow exceptions; notes shared without delay.

## ONC Certification (45 CFR Part 170)

EHR vendors selling to providers reporting to CMS must be certified.
- 2015 Edition + Cures Update criteria.
- USCDI v3 (current) → v4 transitioning.
- FHIR R4 APIs mandatory for patient + population services.
- Real-world testing + use reporting.
- Surveillance: ONC Enhanced Oversight + ASTB.

## CMS Quality Programs

- **MIPS (Merit-based Incentive Payment System)**: 4 categories (Quality, Cost, Improvement Activities, Promoting Interoperability). Annual scoring affects Medicare Part B payment ±9%.
- **APMs / Advanced APMs**: shared-savings; risk-bearing.
- **Meaningful Use** → Promoting Interoperability — measures around interop, public health reporting, patient engagement.
- **Hospital Readmissions Reduction Program**, Value-Based Purchasing, Hospital-Acquired Condition.
- **HEDIS** (NCQA): commercial-side quality measures; impacts plan ratings.

## DEA / Controlled Substances Act + EPCS

- **Schedule I-V** classification; II is most restricted (no refills, written or EPCS).
- **EPCS** required (or paper) for controlled substances; SUPPORT Act mandates EPCS for Medicare Part D as of 2021.
- DEA-certified application + 2-factor authentication (one factor is hard token or biometric).
- Annual third-party audit + DEA registration verification.
- Two-step authentication for each prescription transmission.
- Logical access control + identity proofing per IAL2.

## State Medical Boards

- Practice acts vary by state.
- **Telehealth**: provider must be licensed in state where PATIENT is located at time of service. Multi-state compacts (IMLC, NLC, PT Compact) ease but don't eliminate.
- **Scope of practice** (NP/PA/RN) varies by state.
- **Corporate practice of medicine** doctrine (CA, NY, TX) — non-physicians can't own clinical entities; affects MSO structures.

## FDA — Software as Medical Device (SaMD)

- Class I/II/III based on risk.
- 510(k) clearance OR de novo OR PMA depending on class.
- **Clinical Decision Support**: 21st Century Cures Act exemption IF software (1) doesn't acquire device data, (2) displays clinical info, (3) recommends action, AND (4) clinician can independently review basis. Closed-loop / image-interpretation = device.
- Quality Management System (21 CFR 820 / ISO 13485) required for devices.
- UDI (Unique Device Identification).
- Premarket cybersecurity (2023 guidance) + post-market.

## State Privacy / Health-Specific Laws

- **Texas Medical Privacy Act** — broader than HIPAA; consumer data not just CE.
- **California CMIA** + AB 1184 (sensitive services confidentiality).
- **New York SHIELD Act** — security requirements for any business with NY resident data.
- **My Health My Data (Washington 2024)** — broad consumer health privacy.
- **Florida 408.051** — patient access timing.

## International (if you serve abroad)

- **GDPR (EU)** — special-category data requires explicit consent OR Article 9(2) basis (e.g., health-care provision).
- **PIPEDA (Canada)** + provincial (PHIPA Ontario, HIA Alberta).
- **DPDPA (India)** + DISHA proposed.
- **PIPL (China)** — strict cross-border for health data.

## Data Retention

- Adult medical records: 7-10 years post-last-encounter (state varies; California 7, Texas 7, Florida 5 from last visit OR until age of majority + 4 for minors).
- Pediatric: until age of majority + state limit (often 21 + 7 = 28).
- Mental health: longer in some states.
- Medicare records: 10 years.
- Audit logs: 6 years HIPAA minimum.
- Imaging: 5 years adult / age-of-majority + 5 minor (typical).

## Workforce

- **Annual HIPAA training** + sanction policy enforcement.
- **OIG Exclusion check** monthly (LEIE) — can't bill federally for excluded individuals.
- **Background check + sanction screening** at hire and ongoing.
- **Credentialing + privileging** via NCQA/Joint Commission for clinicians.

## Specific operational obligations

- **No Surprises Act (2022)**: Good Faith Estimate to self-pay/uninsured; balance billing prohibition for emergency + ancillary at in-network facility.
- **Price Transparency (CMS-9915-F)**: hospitals publish standard charges + 300 shoppable services.
- **Information sharing for care coordination**: TEFCA participation expectations growing.
- **Anti-Kickback Statute** + **Stark Law** — referral relationships; fee structures with physician owners.
- **Civil Monetary Penalty Law** — claims accuracy.

## Common compliance gaps in v1

- Audit log records WRITES but not READS — HIPAA requires both.
- Patient list endpoint returns demographics for any authenticated user (no role/relationship check).
- Backup snapshot of prod copied to dev → PHI in non-compliant env.
- BAA signed with parent vendor but sub-processor (e.g., AWS sub-region used by your vector DB) NOT under BAA.
- Patient-portal MFA optional (HHS strongly recommends mandatory for portals).
- Lab results released to portal with manual provider hold required → often forgotten → information blocking penalty risk.
- Dev/staging seeded with REAL patient data → broad workforce access to PHI without role.
- Email notifications include diagnosis or test name → PHI in cleartext through customer's email server.
- TLS terminated at load balancer + cleartext to backend → Security Rule transmission security failure.
- Soft-delete used for PHI without true erasure on right-to-erasure request honoring (where applicable).
- Test patient records not flagged → contaminate quality reporting.
- Engineer access to prod DB without break-glass logging.
- No automatic logoff (45 CFR 164.312(a)(2)(iii)) — workstations stay logged in indefinitely.
- Mobile app stores PHI cache without device-wipe-on-loss capability.
- Subprocessor list public but stale.
