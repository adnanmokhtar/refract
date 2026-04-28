# Healthcare — stakeholders

Each role has different rules, vocabularies, KPIs, and pain. Misunderstanding any role's workflow leads to UI that providers refuse to use → practice churns within 6 months.

## Patient

The reason the system exists. But unlike retail, the patient is often NOT the buyer — payer is.

**Workflows:**
- Schedule appointment (online or via phone).
- Check in (paper forms or kiosk or portal).
- Receive care.
- Pay co-pay / co-insurance / deductible.
- Receive results + follow-up.
- Refill prescriptions.
- Manage chronic conditions over years.
- Coordinate proxy access for dependents.

**Pain points the system must address:**
- "Why am I being charged?" — line-item explanations.
- "Where are my results?" — visibility + interpretation.
- "Who do I contact?" — provider vs nurse vs billing vs front desk.
- Insurance complexity ("what's my deductible?").
- Repeating their history at every visit.
- Multiple portals for multiple specialists (no unified record).

**KPIs (patient-side):**
- Appointment fill rate, no-show rate.
- Portal activation %, message turnaround time.
- CAHPS / HCAHPS satisfaction scores.
- Net Promoter Score.
- Adherence (Rx fill, follow-up, screening).

## Physician (MD / DO) — primary care vs specialist

**Primary care workflows:**
- 15-20 min visits, 20-30 patients/day.
- Chronic disease management, preventive care, acute episodes.
- Heavy ambient inbox (refills, results, messages).
- Documentation pressure (notes after hours = "pajama time").

**Specialist workflows:**
- Procedure-heavy (cardiology, orthopedics, dermatology).
- Often shorter notes, more imaging/labs.
- Dependent on referrals; consult-back loop matters.

**Universal physician pain:**
- Documentation eats clinical time (1 hr docs / 1 hr patient on average — terrible).
- Inbox overflow (avg 100+ messages/day for PCPs).
- Click count to do common tasks (target <3 clicks; many EHRs at 15+).
- Alert fatigue from CDS — they override 95%+; clinically dangerous when real alert hits.
- Compliance burden (PIs, MIPS) feels disconnected from care.

**KPIs:**
- Encounters per session.
- RVUs/wRVUs (productivity).
- Note-completion-within-72h compliance.
- Patient satisfaction.
- Quality measures (HEDIS, MIPS).
- Burnout score (Maslach inventory tracked at health systems).

**Permissions:**
- Full chart for own patients (and for any patient in a treatment relationship).
- Read for consult patients with explicit referral.
- Sign own notes; co-sign trainee notes.
- e-Prescribing within DEA/state scope.

## Nurse (RN) / MA (medical assistant)

The actual chart-runners; physicians spend less time in the EHR than nurses.

**Workflows:**
- Room patient: vitals, chief complaint, med reconciliation.
- Triage phone calls (nurse-line protocols).
- Result review (RN reviews abnormal first; escalates to MD).
- Refill request triage (per protocol; MD signs).
- Patient education (post-visit instructions).
- Documentation in flowsheets.

**Pain points:**
- Med reconciliation eats time; patients don't know their meds.
- Phone-message documentation often double-entry.
- Order signing as "per protocol" needs clear policy + audit.
- Mobile/tablet workflow for inpatient rounding.

**KPIs:**
- Patient throughput (rooms turned).
- Triage response time.
- Result review queue depth.
- Hospital-acquired indicators (CAUTI, CLABSI for inpatient).

**Permissions:**
- Document encounters they participate in.
- Sign verbal orders (with cosign window).
- Refill authorization within delegated scope (NEVER controlled).
- Result triage with route-to-MD.

## NP / PA (nurse practitioner / physician assistant)

State-dependent scope. In some states full practice; in others physician supervision required.

**Permissions:**
- Same as physician where state allows.
- DEA-authorized for prescribing (controlled scope state-dependent).
- Co-signature requirements per state.

## Front desk / patient access

The conversion-and-cash-collection role. If they fumble eligibility, claims deny later.

**Workflows:**
- Phone: schedule, reschedule, cancel.
- In-person: check-in, copay collection, document scanning, demographic update.
- Insurance verification: real-time eligibility, prior auth flagging.
- Referral source documentation.
- Wait list management.

**Pain points:**
- Scheduling complexity (visit-type rules, provider templates, room availability).
- Copay collection embarrassment ("the system says you owe...").
- Insurance card photo OCR errors.
- Patient impatience when system slow.

**KPIs:**
- POS (point of service) collection rate.
- Eligibility verification %.
- Lobby wait time.
- Schedule fill rate.

**Permissions:**
- Demographics + insurance edit.
- Scheduling.
- Copay collection.
- NO clinical chart access by default (display PHI minimum-necessary).

## Coder / biller (often outsourced)

Specialized in CPT/ICD/HCPCS + payer rules.

**Workflows:**
- Pull encounter post-sign.
- Validate coding (provider chose right CPT/ICD pair? Modifier needed? LCD met?).
- Submit claim.
- Adjudicate ERA.
- Work denials.
- File appeals.

**Pain points:**
- Provider's documentation insufficient for billed level.
- Payer rules updates.
- Filing limits expiring.
- Multiple payer portals to navigate (no unified status).

**KPIs:**
- Days in A/R.
- Denial rate (target <5%).
- Clean claim rate (target >95%).
- Net collection ratio.
- First-pass resolution rate.

**Permissions:**
- Encounter coding edit (within rules).
- Claim submit + appeal.
- Read access to chart for documentation justification.
- Limited PHI access (minimum necessary).

## Practice manager / ops

The "run-the-business" role; they have the customer relationship with the EHR vendor.

**Workflows:**
- Provider scheduling templates.
- Staff scheduling.
- Reports (financial, operational, quality).
- Vendor management (lab, IT, supply, payer relations).
- Compliance program oversight.
- Patient grievance handling.

**KPIs:**
- Revenue per provider.
- Profit margin.
- Patient satisfaction.
- Staff turnover.
- Quality scores.

**Permissions:**
- Configuration: templates, fees, providers, locations.
- Read across all patients (limited PHI to ops scope).
- Reports.
- User management.

## CMO / Medical Director

Clinical leadership; the buyer in larger orgs.

**KPIs:**
- Quality scores.
- Patient outcomes.
- Provider satisfaction (retention).
- Risk management (malpractice trends).

**Pain points:**
- Visibility into clinician documentation patterns.
- Data for value-based contracts.
- CDS rule governance.

## Compliance / Privacy / Security Officer

HIPAA Privacy Officer + Security Officer roles required (can be same person in small practice).

**Workflows:**
- Audit log review (sample-based + targeted).
- Risk analysis annual.
- Workforce training tracking.
- Breach response.
- Patient access requests + accounting of disclosures.
- BAA inventory.
- Sanction enforcement.

**Permissions:**
- Read access to all logs.
- Patient access request fulfillment.
- Investigation tools (suspect-account access lookup).
- NO clinical decision authority.

## Lab / pathology / radiology (downstream)

Receivers of orders, senders of results.

**Touchpoints:**
- Order receipt (HL7 ORM or FHIR ServiceRequest).
- Result return (HL7 ORU or FHIR Observation).
- Critical-value notification + documented acknowledgment.
- Image link for radiology (DICOM repository or PACS link).

## Pharmacy

Receivers of e-Rx, sometimes senders of fill notifications + refill requests.

**Touchpoints:**
- NEWRX inbound.
- RXFILL outbound (opt-in).
- RXRENEW (refill request) → providers' inbox.
- CANRX (cancel) handling.
- DUR (drug utilization review) responses.
- Mail-order vs retail variations.

## Payer

Adversarial-cooperative relationship.

**Touchpoints:**
- 270/271 eligibility.
- Prior authorization (often portal, increasingly API via Da Vinci/PARDA initiative).
- 837 claim submission.
- 277CA acceptance + 835 ERA.
- Audit requests (RAC, MAC).
- Quality data submission (HEDIS).

**Pain to engineer around:**
- Prior auth latency (24-72h average; some 14 days).
- Inconsistent denial codes.
- Timely-filing limits varying by payer.
- Coordination of benefits complexity.

## State + federal regulators

- **OIG (Office of Inspector General)** — fraud/abuse audits.
- **OCR (Office for Civil Rights)** — HIPAA enforcement.
- **State medical boards** — license actions.
- **State health departments** — public health reporting.
- **CDC + state** — immunization registry, syndromic surveillance.

**Touchpoints:**
- Public health reporting (immunizations, reportable diseases, syndromic surveillance, electronic case reporting eCR).
- Audit response (logs, records, BAAs).
- Breach notifications.

## Patient's family / proxy

Often the actual decision-maker (parent, adult child, spouse, healthcare power of attorney).

**Pain points:**
- Granting/revoking proxy access.
- Pediatric → adult transition (proxy access dropping at age of majority — varies by state for sensitive services 12-18).
- Multiple proxies for same patient.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Physicians complaining about documentation time | Templates, dot-phrases, dictation, ambient AI scribe |
| Front desk struggling with eligibility | Real-time 270/271 + payer API integrations |
| Billers overwhelmed by denials | Pre-submission scrubber + denial worklist + appeal generator |
| Patients calling for results | Portal + Cures-compliant release workflow |
| Practice manager has no visibility | Operations dashboard + revenue/AR/quality reports |
| Compliance officer panicking | Audit log + access reviews + risk analysis tooling |

## Anti-pattern: "build for the physician, ignore the nurse"

Nurses and MAs spend more time in the chart than physicians. Optimizing only for MD workflows leaves nurses fighting the UI all day; they're the loudest voices in churn.
