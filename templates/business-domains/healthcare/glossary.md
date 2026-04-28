# Healthcare — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `healthcare`:

**Entity / model names**: `Patient`, `Provider`, `Physician`, `Encounter`, `Visit`, `Diagnosis`, `Procedure`, `Prescription`, `Medication`, `Allergy`, `Vital`, `LabOrder`, `LabResult`, `Insurance`, `Payer`, `Claim`, `Consent`, `MRN`, `Encounter`, `ChartNote`, `SOAPNote`, `Immunization`.

**Folder / route names**: `chart/`, `patients/`, `encounters/`, `prescriptions/`, `labs/`, `claims/`, `eligibility/`, `referrals/`, `/chart/[mrn]`, `/encounter/[id]/note`, `/eprescribe`, `/eligibility-check`.

**Dependencies**: `fhir`, `hl7`, `redox`, `1up`, `metriport`, `surescripts`, `epcs`, `change-healthcare`, `availity`, `eligible-api`, `nadac`, `rxnorm`, `loinc`, `snomed`, `icd-10`, `cpt`, `npi-registry`, `dosespot`.

**Database schema**: tables for `patients` + `encounters` + `medications` + `diagnoses` (linked by ICD-10) is the strongest signal. Presence of `mrn` (medical record number) column is near-conclusive.

**Distinguishing from telehealth-only**: full healthcare = chart + ePrescribing + claims. Telehealth-only = video session + visit notes, often without claims/Rx.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Patient` | the person receiving care | `id, mrn, first_name, last_name, dob, sex_assigned_at_birth, gender_identity, ssn_last4, addresses[], phones[], emergency_contact, preferred_language, race, ethnicity` | registered → active → deceased / merged / inactive |
| `Provider` | physician / NP / PA / clinician | `id, npi, dea, license_number, license_state, taxonomy_code, specialty, prescribing_authority` | credentialed → active → suspended → terminated |
| `Encounter` | a single clinical interaction | `id, patient_id, provider_id, location_id, type (office/tele/inpatient/ed), start_at, end_at, status, chief_complaint, billing_status` | scheduled → checked_in → in_progress → signed → billed |
| `ChartNote` / `SOAPNote` | clinical documentation for an encounter | `encounter_id, subjective, objective, assessment, plan, signed_at, signed_by, addenda[]` | draft → pending_signature → signed → amended |
| `Diagnosis` | what the patient has | `encounter_id, icd10_code, description, type (primary/secondary), onset_date, resolved_date, problem_list_status` | active → resolved → ruled_out |
| `Procedure` | what was done | `encounter_id, cpt_code, modifier[], performed_at, performed_by, units, body_site` | scheduled → performed → documented → billed |
| `Prescription` | medication order | `id, patient_id, prescriber_id, drug (rxnorm), strength, form, sig, dispense_qty, refills, daw, controlled_schedule, transmitted_at, pharmacy_ncpdp` | draft → signed → transmitted → filled / cancelled |
| `Medication` | active med list | `patient_id, rxnorm, name, status (active/discontinued/completed), source (rx/otc/reported)` | active → discontinued |
| `Allergy` | drug/food/env allergy | `patient_id, allergen (rxnorm/snomed), reaction, severity (mild/moderate/severe/anaphylaxis), onset, status, source` | active → entered_in_error → inactive |
| `Vital` | measurement | `encounter_id, type (bp/hr/temp/spo2/wt/ht/bmi), value, unit, recorded_at, recorded_by` | recorded (immutable; corrections via amendment) |
| `LabOrder` | test ordered | `id, encounter_id, ordering_provider_id, loinc_codes[], specimen, priority, lab_id, ordered_at, status` | ordered → collected → in_lab → resulted → reviewed |
| `LabResult` | result of a lab | `lab_order_id, loinc, value, unit, reference_range, abnormal_flag (H/L/HH/LL/A), resulted_at, reviewed_by, reviewed_at` | preliminary → final → corrected → cancelled |
| `Insurance` / `Coverage` | payer relationship | `patient_id, payer_id, member_id, group_number, plan_type, subscriber_relationship, effective_date, term_date, eligibility_last_checked` | active → terminated |
| `Claim` | bill to insurer | `id, encounter_id, payer_id, total_charge, claim_lines[] (cpt+icd+units+charge), status, control_number, submitted_at, paid_amount, denial_reason` | draft → submitted (837) → accepted → adjudicated (835) → paid / denied / appealed |
| `Consent` | patient authorization | `patient_id, type (treatment/release/research/42cfr2), scope, signed_at, witnessed_by, expires_at, revoked_at` | active → expired → revoked |
| `Referral` | provider → provider | `id, patient_id, from_provider_id, to_provider_id_or_specialty, reason, urgency, auth_required, auth_number, status` | requested → authorized → scheduled → completed |
| `Appointment` | scheduled encounter slot | `id, patient_id, provider_id, slot_start, slot_end, reason, status, reminders_sent[]` | requested → confirmed → arrived → completed / no_show / cancelled |
| `Immunization` | vaccine given | `patient_id, cvx_code, manufacturer, lot, dose_number, route, site, administered_at, administered_by, vis_provided` | recorded (immutable; iis-reported) |

## Status state machines

**Encounter:**
```
scheduled → checked_in → in_progress → signed → billed
   ↓            ↓             ↓
cancelled   no_show     amended (via addendum, never edit signed note)
```

**Prescription:**
```
draft → signed → transmitted → filled
                    ↓             ↓
                cancelled    refilled (creates new Rx fill)
                    ↓
                  (controlled: EPCS-signed before transmit; cancellation via CancelRx)
```

**Claim (X12 837/835 lifecycle):**
```
draft → 837 submitted → 277CA accepted → adjudicated (835) → paid
                            ↓                  ↓
                         rejected           denied → appealed → reprocessed
```

**Lab result:**
```
preliminary → final → reviewed_by_provider → released_to_patient (per Cures Act timing)
                ↓
            corrected (creates new version; preliminary remains in audit)
```

## Vocabulary distinctions (don't conflate)

- **MRN** vs **Patient ID** — MRN is human-facing, scoped to a facility/network; Patient ID is internal UUID. MRNs collide across organizations.
- **Provider** vs **Rendering provider** vs **Billing provider** — rendering = who saw the patient; billing = who collects. Often same person, often not (residents render, attendings bill).
- **Diagnosis** vs **Problem** — Diagnosis is encounter-scoped (what did we treat today); Problem is patient-scoped (chronic list).
- **Medication** vs **Prescription** — Medication = entry on med list (could be OTC, reported by patient, historic); Prescription = an order written by a provider.
- **ICD-10** vs **CPT** vs **HCPCS** vs **LOINC** vs **SNOMED** vs **RxNorm** — ICD-10 = diagnosis; CPT = procedure; HCPCS = supplies + Medicare procedures; LOINC = lab tests; SNOMED = clinical terms; RxNorm = drug names.
- **Encounter** vs **Visit** vs **Episode** — Encounter = single billable interaction; Visit = colloquial; Episode = clinical concept spanning multiple encounters (e.g. pregnancy episode).
- **Signed note** vs **Locked chart** — Signed = provider attests; Locked = no edits allowed (signed notes are addendable, never editable).
- **PHI** vs **PII** — PHI is PII tied to health (name + diagnosis = PHI; name alone = PII). PHI scope is broader under HIPAA than generic PII rules.
- **Eligibility** vs **Authorization** — Eligibility = is the patient covered; Authorization = is THIS service approved for THIS patient. Both required pre-service for many specialties.
- **Refill** vs **Renewal** — Refill = remaining quantity on existing Rx; Renewal = new Rx after refills exhausted. Different ePrescribing flows.
- **Controlled substance schedule** — Schedule II (no refills, EPCS or paper) vs III-V (refills allowed, EPCS required as of 2023 in most states).

## Multi-tenancy variants

- **Single-practice**: one organization. Tenant boundary = organization-level audit only.
- **Multi-location practice**: one organization, many locations. `location_id` on encounters/labs/claims; same patient population.
- **Health system / IDN**: many practices under one corporate parent. Patient may be cross-facility (MPI required to merge).
- **MSP / SaaS EHR**: many independent practices on one platform. Strict tenant isolation; a patient belongs to ONE practice (or signed BAA-mediated sharing).
- **HIE (Health Information Exchange)**: federated; not a tenant model — a query-based interop layer (FHIR + IHE).
