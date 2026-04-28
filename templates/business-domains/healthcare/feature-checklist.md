# Healthcare — feature checklist

The 80%-of-clinical-software-needs-this list. Most v1 EHR/EMR/practice-management products ship missing several — they pass demos but practices defect after weeks of frustration.

## Patient-facing (portal)

### Identity + access
- [ ] Account creation with proxy invitation flow (parent → minor, caregiver → elder).
- [ ] MFA mandatory; SMS allowed but warn re: SIM-swap.
- [ ] Last-login + active-sessions display.
- [ ] Account recovery without resetting MRN — never let recovery merge accounts.

### Chart access
- [ ] Visit summaries downloadable (CCDA + FHIR bundle).
- [ ] Lab results visible; with non-results (just the value, no interpretation) for sensitive categories per state law.
- [ ] Imaging reports (not raw DICOM in v1; link to imaging portal).
- [ ] Problem list, medication list, allergy list visible.
- [ ] Visit notes per Cures Act — provider notes accessible without delay (no "test" or pending exclusions outside narrow exceptions).
- [ ] Download data in machine-readable format (HIPAA right of access).

### Engagement
- [ ] Secure messaging with response-time expectations stated.
- [ ] Refill request — must surface "controlled substances need office visit".
- [ ] Appointment self-schedule (with appropriate guardrails).
- [ ] Bill pay with line-item breakdown (CPT description, not just code).
- [ ] Statement download.

## Provider-facing (clinical)

### Chart navigation
- [ ] Patient header: name, age, sex, MRN, allergies, code status visible at all times.
- [ ] Single-click to: med list, problem list, last visit, last labs, allergies.
- [ ] "Patient summary" snapshot on chart open (avoid 5-tab navigation).
- [ ] Search within chart (notes, results, history) — providers use it constantly.
- [ ] Forward flow: chart open → encounter open → note write → orders → sign — no modal interrupts.

### Documentation
- [ ] Templated SOAP note + free text.
- [ ] Dot-phrases / smart phrases (`.normal`, `.dmplan`).
- [ ] Voice-to-text dictation integration (Dragon, Augmedix, Suki).
- [ ] Co-sign workflow for trainees.
- [ ] Addendum workflow (NEVER allow note edit post-sign — add only).
- [ ] Time tracking for time-based E/M.
- [ ] Auto-pull last visit info + recent results (cuts chart-prep time 50%).

### Orders
- [ ] Order sets (e.g., "Diabetes panel" expands to A1C + lipid + CMP + UA + microalbumin).
- [ ] Favorites per provider — pre-populated diagnoses, common Rx.
- [ ] Allergy/interaction alerts, non-modal but blocking on severe.
- [ ] Renal-dose adjustment hints from drug DB.
- [ ] Non-formulary warnings via real-time benefits.
- [ ] Print/sticker/wristband options for paper-still workflows.

### Inbox / worklists
- [ ] Single inbox: results to review, refill requests, patient messages, telephone notes, document review.
- [ ] Triage delegation — RN reviews abnormal labs first, escalates.
- [ ] Tag/route messages to colleagues, nurses, billing.
- [ ] Snooze / follow-up reminders.
- [ ] Bulk-handle (mark all reviewed for normal labs).

### Prescribing
- [ ] EPCS for ALL controlled substances (DEA-mandated in most states).
- [ ] Pharmacy preferred-list per patient.
- [ ] Dose/frequency/duration parsed (NCPDP SIG codes), not just free text.
- [ ] Days-supply auto-calculation.
- [ ] Renewal vs new prescription distinction.
- [ ] PDMP (state prescription drug monitoring program) integration on controlled prescribing.

## Front-desk-facing

### Registration
- [ ] Real-time eligibility check on insurance entry.
- [ ] Co-pay/deductible display before patient is roomed.
- [ ] Insurance card image capture (front + back).
- [ ] Driver's license / ID capture.
- [ ] Demographic update prompts ("Has your address/phone/insurance changed since last visit?").
- [ ] Multi-language UI (Spanish baseline; LEP support per Title VI).
- [ ] Consent forms (NPP, treatment, financial responsibility, telehealth) electronically signed and version-tracked.

### Scheduling
- [ ] Provider templates: visit types with durations.
- [ ] Block scheduling for procedures.
- [ ] Wait list for cancellations.
- [ ] Reminder system (text/email/call per patient pref, frequency-capped).
- [ ] No-show tracking + policy enforcement.
- [ ] Recurring appointment series (PT, oncology).

## Back-office (billing + ops)

### Coding
- [ ] CPT/ICD-10 lookup with semantic search.
- [ ] LCD/NCD validation (Medicare local/national coverage determinations).
- [ ] Modifier prompts (-25, -59, etc. with explanations).
- [ ] Claim scrubber — pre-submission edits (NCCI, MUE).
- [ ] HCC suspect coding for risk-adjusted contracts.

### Claims
- [ ] 837 generation + clearinghouse submit.
- [ ] 277CA + 835 auto-posting.
- [ ] Denial worklists by reason code.
- [ ] Appeal letter generator.
- [ ] Filing-limit countdown per claim.
- [ ] Re-bill workflow (corrected claim with proper frequency code).

### Patient billing
- [ ] Statement generation post-secondary adjudication.
- [ ] Payment plans (with interest calc if applicable).
- [ ] Collections workflow + agency handoff.
- [ ] Refund issuance (overpayment).
- [ ] Patient cost estimator (Good Faith Estimate per No Surprises Act).

### Reports
- [ ] Charges + collections + adjustments by provider/location/payer.
- [ ] Days in A/R + aging buckets.
- [ ] Denial rate by reason.
- [ ] Productivity (RVUs, encounters per provider).
- [ ] MIPS dashboards (quality measures, promoting interoperability).

## Compliance + audit

- [ ] Audit log of every chart access (read AND write); patient/representative can request a list.
- [ ] Break-glass workflow with mandatory reason + post-event review.
- [ ] BAA template + tracking with vendors.
- [ ] Risk analysis documentation (HIPAA Security Rule annual requirement).
- [ ] Workforce training tracking (annual HIPAA, annual security awareness).
- [ ] Sanction policy + enforcement log.
- [ ] Disaster recovery plan + annual test.
- [ ] Backup encryption + tested restore.
- [ ] Encryption at rest (DB, files) + in transit (TLS 1.2+).

## Interop

- [ ] FHIR R4 USCDI v3 endpoints (Patient, Observation, Condition, MedicationRequest, etc.) — required by ONC certification.
- [ ] CCDA export.
- [ ] Bulk export ($export) for value-based-care analytics partners.
- [ ] SMART on FHIR EHR launch.
- [ ] Direct messaging address per provider.
- [ ] State immunization registry (IIS) bidirectional.
- [ ] State PDMP query at time of controlled prescribing.

## Things v1s commonly miss

- **Allergy vs intolerance distinction.** Anaphylaxis-to-PCN is allergy; "GI upset on metformin" is intolerance. Conflating leads to over-warning + alert fatigue.
- **Co-sign timer.** Trainee-signed notes that never get attending co-sign sit unbilled forever.
- **Lab abnormal flag inheritance.** A "high" cholesterol on a peds patient uses peds reference range, not adult.
- **Prescription cancellation as DELETE.** Pharmacy thinks it's filled, patient gets it. Use NCPDP CancelRx.
- **No "active medication" filter on med rec.** Provider sees 30 historical meds; misses current ones.
- **Phone number as identifier.** People change numbers; merges via phone produce wrong-patient incidents.
- **Sex assigned at birth + gender identity collapsed.** Required separately by USCDI; many drug doses depend on biological sex (creatinine clearance).
- **Encounter type missing.** Telehealth and in-office have different rules; conflating breaks billing.
- **Claim line ICD-CPT linking missing.** Single primary diagnosis used for all CPTs → denials.
- **No copay collection at check-in display.** Front desk forgets; AR balloons.
- **Patient demographics not propagated to claim.** Old address on patient → claim sent to old PO Box → returned mail.
- **No address/phone/insurance update prompt at check-in.**
- **Lab results visible to portal before provider review.** Patients see "abnormal" without context; phone calls explode. Cures Act allows sensible delay only for narrow exceptions; design the workflow so providers don't drag.
- **Discharge instructions only in English.** LEP patients = readmit + lawsuit.

## Things often over-built in v1 (defer until validated)

- AI ambient scribe (great future state; complex compliance + accuracy proof; Suki/Augmedix/etc. as integration first).
- Full EPCS biometric authentication if soft-token (compliant) suffices.
- Custom CDS rule engine (use commercial — Wolters Kluwer, Elsevier, FDB, MedScape).
- Full HCC/risk-adjustment in-house (use Episource, Apixio, Talix integrations).
- Custom imaging viewer (use Visage, Ambra, Nuance integration).
- Wearable device ingestion at scale (start with manual entry; expand if reimbursed).
- Native iOS/Android EHR (web-first; mobile for portal + provider rounding).
- Multi-FHIR-version simultaneous support (R4 only; DSTU2 is sunset).
