# Healthcare — core flows

The flows every clinical software must support. P1 is "without these, you can't open the doors." P2 is "you'll lose the practice as a customer." P3 is "differentiator vs incumbent EHRs."

## P1 — must-have for v1

### 1. Patient registration + insurance verification
The intake gate. Wrong here = denied claims downstream.

```
Front desk receives patient (new or returning)
  → match against MPI (master patient index) — DOB + name + last4 SSN; manual review if fuzzy match
  → if new: create patient record with MRN
  → capture demographics + addresses + emergency contact
  → capture insurance card (front + back image)
  → run real-time eligibility check (270/271 transaction or payer API)
  → display: active? copay? deductible remaining? authorization required?
  → capture consent forms (treatment, NPP acknowledgment, financial responsibility)
  → patient flagged ready for clinical
```

Key invariants:
- MRN never reused, never edited (issue corrections via merge, not overwrite).
- Eligibility check stamped with date + payer response code; re-run if stale (>24h).
- Consent acknowledgment requires signature + timestamp + version of NPP at time of signing.
- Idempotency on patient creation — duplicate prevention via demographic hash.

### 2. Appointment scheduling
```
Patient or staff requests slot
  → check provider availability (block schedule, lunch, off days)
  → check resource availability (exam room, equipment if procedure)
  → reserve slot (status=requested)
  → if requires authorization: pre-auth workflow before confirming
  → confirm slot (status=confirmed)
  → send reminders (text/email/call) per patient preference + per practice rules (24h, 1h)
  → patient arrives → status=arrived → encounter created from slot
  → no-show → status=no_show → optional fee + rebook prompt
```

Self-scheduling adds: consent-to-text capture, blocked appointment types (new patient must call), insurance verification before confirm.

### 3. Encounter documentation (SOAP note)
The chart note is the legal record. Edits after signing are forbidden.

```
Provider opens encounter
  → reviews chart (problem list, meds, allergies, recent labs)
  → captures chief complaint
  → SUBJECTIVE — patient narrative
  → OBJECTIVE — vitals + exam findings
  → ASSESSMENT — diagnoses (ICD-10) added to problem list if new
  → PLAN — orders (Rx, labs, imaging, referrals) + follow-up
  → reviews + signs note (cryptographic attestation: user + timestamp + IP)
  → note locked; addenda only path for changes
  → coding (CPT) finalized → claim queued
```

Key invariants:
- Allergy + drug interaction check fires when Rx is added to plan (NOT after signing).
- Co-signing required for residents/students by attending — chart cannot be billed until co-signed.
- Time-spent fields populated for time-based E/M coding (>50% counseling rule).
- Note signed in <72h or compliance flag (CMS expectations).
- Signed notes are immutable; corrections via addendum that references original.

### 4. e-Prescribing
```
Provider chooses medication during encounter
  → search drug DB (RxNorm)
  → drug allergy check vs patient allergies — block on severe match, warn on moderate
  → drug-drug interaction check vs current med list
  → dosage check (weight-based for peds; renal function for many)
  → formulary check via patient's insurance (preferred? PA required?)
  → prescription drafted with sig, qty, refills, DAW
  → for controlled substances: EPCS two-factor auth required (DEA mandate)
  → patient's preferred pharmacy retrieved
  → SureScripts NCPDP transmission to pharmacy
  → pharmacy responds with received/dispensed (RxFill notification — opt-in by pharmacy)
  → if cancel needed: CancelRx transaction (NOT just delete the order)
```

Key invariants:
- Controlled substance (Schedule II-V) ALWAYS via EPCS — paper Rx illegal in most states post-2023.
- Schedule II: no refills allowed, ever.
- Prescriber NPI + DEA on every transmission; expired DEA blocks send.
- Sig must be human-readable AND structured (FHIR `Dosage` or NCPDP SIG segments).

### 5. Lab order + result
```
Provider orders lab during encounter
  → choose tests by LOINC (or panel that maps to LOINC list)
  → ABN (Advance Beneficiary Notice) prompt if Medicare + non-covered
  → order routed to lab (HL7 ORM, or FHIR ServiceRequest, or interface to LIS)
  → specimen collected → label/requisition printed/transmitted
  → lab performs test
  → result returned (HL7 ORU or FHIR Observation)
  → result auto-filed to patient chart with abnormal flag
  → provider review queue populated
  → provider reviews + writes interpretation note
  → result released to patient portal (Cures Act: must be released without delay; no provider-blocking holds except per state-specific exceptions)
  → critical/panic values: page provider immediately + document acknowledgment
```

### 6. Billing claim 837/835
```
Encounter signed → coder reviews CPT/ICD pairing → scrubber checks
  → claim built per CMS-1500 (professional) or UB-04 (institutional)
  → 837P/I transmitted to clearinghouse → forwarded to payer
  → payer 277CA acknowledgment (accepted/rejected with edits)
  → adjudication → 835 ERA returned with payments + adjustments
  → ERA auto-posted: contractual adjustment, patient responsibility, denial codes
  → patient statement generated for residual responsibility (after secondary if any)
  → denials routed to denial management worklist
  → appeals filed where appropriate (within payer's filing limit; 90-180 days typical)
```

## P2 — keep the practice

### 7. Refill request handling
- Pharmacy sends RefillRequest (RxRenewalRequest in NCPDP).
- Routed to provider or designee per protocol (chronic meds delegable; controlled never delegable).
- Approve / deny / change — response transmitted within 24h or pharmacy follows up with patient.
- New Rx generated with new fill quantity + refills.

### 8. Referral coordination
- Referral order → eligibility/auth check vs receiving specialty.
- Records package sent (labs, recent notes, imaging) to specialist.
- Receiving specialist's note returned → filed to referring provider's review queue.
- Loop closed when consult note received and reviewed.

### 9. Patient portal
- Secure messaging (provider-patient) — must comply with timely-response expectations.
- Lab results visible (timing per Cures Act + state law).
- Visit summaries downloadable (CCDA or FHIR bundle).
- Appointment self-scheduling, prescription refill request, bill pay.
- Proxy access (parent for minor, caregiver for elderly) with explicit authorization.

### 10. Denial management
- Daily denial worklist by reason code (CARC/RARC).
- Appeal templates per payer.
- Track appeal outcome + filing-limit timer per claim.

### 11. Care gaps + quality reporting
- Identify patients overdue for screenings (mammogram, colonoscopy, A1C, etc.).
- MIPS / MACRA / HEDIS measures computed automatically.
- Gap-closure outreach lists for staff.

## P3 — differentiator

### 12. Population health + chronic disease registries
- Diabetes registry (last A1C, BP, foot exam).
- Hypertension control rates.
- Risk stratification (HCC scoring for ACOs).

### 13. Telehealth
- Video integrated into encounter UI; recording with consent capture.
- Geofencing — provider must be licensed in the state where patient is located AT TIME OF VISIT.
- Different CPT codes (99421-99423 vs in-person 99213-99215); place-of-service code (02 telehealth, 10 from home).

### 14. CDS (Clinical Decision Support)
- Hard stops vs warnings vs FYIs.
- Alert fatigue is real — track override rate; suppress noisy rules.
- USCDI v3 + USCDI+ data classes integrated.

### 15. Interop — FHIR R4 APIs
- Bulk export (Flat FHIR / $export) for analytics partners.
- SMART on FHIR app launch (third-party integrations).
- TEFCA participation for nationwide exchange.

### 16. Direct messaging (Direct Trust)
- Provider-to-provider secure email-style messaging via DIRECT protocol.
- Common for referrals, transition of care.

## Specific concerns

### Break-glass workflow
Emergency override of consent restrictions (e.g., patient unconscious; clinician needs sealed psych/SUD record).
- Requires reason + supervisor co-sign + automatic post-event audit notification to compliance.
- All access logged + visible to patient/representative on request.

### Patient merge
Two records for same person (common after marriage, MRN reissue).
- Soft-merge (alias linkage) vs hard-merge (data unification).
- Audit trail preserves original records; reversible for 30+ days.
- Insurance, claims, prescriptions all reattributed.

### Patient unmerge
Mistaken merge → unmerge restores both records.

## Webhooks / interfaces the system must produce

- ADT (admission/discharge/transfer) — A04 register, A08 update, A40 merge, A11 cancel.
- ORU — outbound results to referring providers.
- DFT — charge/billing events.
- FHIR Subscription notifications (modern equivalent).
- ePrescribing: NEWRX, RXCHG, RXRENEW, RXFILL, CANRX.
- Claim: 837P, 837I.

## Webhooks / interfaces the system must consume

- Eligibility: 270/271 (or payer real-time API).
- Claim status: 276/277.
- Remittance: 835.
- Lab: ORM/ORU via interface engine (Mirth, Rhapsody, Cloverleaf) or FHIR.
- Pharmacy: NCPDP SCRIPT messages from SureScripts.
- Patient device data (FHIR Observation, Apple HealthKit, Google Fit).

## Idempotency-critical endpoints

- `POST /encounters/:id/sign` — re-sign must be no-op; never produces second signature.
- `POST /prescriptions/:id/transmit` — duplicate transmissions = duplicate dispenses.
- `POST /claims/:id/submit` — submitting twice triggers payer duplicate rejection (J1 code).
- Webhook handlers for HL7/FHIR — same message delivered multiple times under at-least-once semantics.
- `POST /patients/merge` — must produce same outcome on retry.
