# Healthcare — domain-specific anti-patterns

Generic engineering concerns are amplified here. PHI mistakes don't just hurt UX — they're federal violations with named regulators and 7-figure penalties.

## PHI exposure

- **PHI in application logs.** "Got patient John Smith DOB 1980-04-05 result A1C 8.2" — printed in stdout, shipped to a non-BAA log aggregator. Scrub at log layer; never trust upstream code.
- **PHI in URLs.** `GET /api/patient/123/condition/diabetes` — diabetes is PHI; URL is logged in CDN, gateway, browser history. Use IDs only; no diagnosis names in paths.
- **PHI in error messages returned to client.** Stack trace with patient name in unauthorized response; same-origin XHR leaks. Generic 4xx messages.
- **PHI in monitoring tool sample requests.** New Relic / Datadog request body capture pulls in HL7 message bodies. Disable body capture or scrub.
- **PHI in email subject lines.** "Your A1C result is ready" → diagnosis-revealing in subject. Use "Your test result is ready".
- **PHI in browser local storage / IndexedDB.** Cleared on logout? Wiped on device loss? Often neither.
- **Webhook payloads sent over plain HTTP.** Or HTTPS with weak certs. TLS 1.2 minimum, cert pinning where possible.

## Audit + access control

- **Audit log records writes but not reads.** HIPAA requires both — patient can request access list. "Who viewed my chart?" must be answerable.
- **Audit log NOT immutable.** Engineer with DB access can edit; auditor presents incomplete record. Append-only table + signed log shipping.
- **Role-based access without context.** Provider can read any patient because role=physician. Need attribute-based: "treating-relationship exists" OR "explicit consent" OR "break-glass with justification".
- **No break-glass workflow.** Provider needs sealed record in emergency; system blocks; care delayed. Implement break-glass with mandatory reason + post-event review.
- **Break-glass with no review.** Anyone can claim emergency; unmonitored. Compliance officer must review every break-glass within 72h.
- **Test/dev environment seeded from prod.** Engineers + contractors get full PHI access without role need. Use synthetic data (Synthea); if real data necessary, separate BAA + access control.
- **Engineer access to prod DB unaudited.** Read replica with PII exposed for "debugging" but no log of who queried what. Bastion + session recording.
- **Workforce member terminated; portal access lingers.** SCIM deprovisioning + session revocation must be immediate.

## Clinical safety

- **Allergy ignored at e-prescribe.** PCN allergy on chart, amoxicillin prescribed without alert. Drug DB integration must fire BEFORE Rx signs.
- **Drug interaction warning bypassed silently.** Provider clicks override; no documentation of clinical justification. Require reason capture.
- **Alert fatigue from over-firing CDS.** 50 alerts/visit → providers click through all. Track override rate; suppress rules with >90% override.
- **Pediatric dose without weight-based check.** Adult dose given to child. Weight-based dosing in CDS for peds-relevant drugs.
- **Renal dosing not adjusted.** Creatinine clearance available; drug requires adjustment; system silent. Real-time renal CDS for renally-eliminated drugs.
- **Medication list not reconciled at transitions.** Patient discharged; home med list missed; readmission. Required med rec at admit/transfer/discharge.
- **Critical lab value (panic) without documented acknowledgment.** Lab calls; nurse documents in paper; never makes it to chart. Critical results require electronic acknowledgment.
- **Order set with stale clinical content.** "Sepsis bundle" hasn't been updated since SEP-1 changed; killing patients. Order sets need governance + review cadence.

## Documentation

- **Note edited after signing.** Provider amends old note via direct edit, not addendum. Discoverable as fraud (date stamp doesn't match content). Signed = immutable; addendum only.
- **Copy-pasted SOAP note.** "Pt continues to do well. Lungs clear. No cough." copied across 14 visits with same lung findings on someone with progressive disease. Auditors flag identical narratives. Highlight unchanged copy-forward sections.
- **Note signed without time-spent for time-based E/M.** Audit risk + compliance violation under E/M coding. Required field.
- **Co-sign skipped or auto-applied.** Attending didn't actually review trainee note; co-sign is a fiction. Require attending interaction (open + scroll + click) not just bulk sign.
- **Note signed prematurely (before encounter complete).** Imaging result comes in after sign; provider amends; note now misleading. Lock note signing until orders resulted (or workflow deliberately allows + flags).

## Patient identity

- **Wrong-patient documentation.** Two charts open; click in one, type in the other. Active-chart visual cue + patient banner on every screen + 2-second confirmation if switching mid-action.
- **Patient merge irreversible.** Mistaken merge → loses one patient's history forever. Soft-merge with 30-day reversal window.
- **Phone number used as identifier.** Same number used by multiple family members; merges produce wrong-patient records.
- **MRN reused.** Old patient deleted; new patient assigned same MRN; insurance crossover. MRNs are forever.
- **No duplicate-prevention on registration.** Receptionist creates new patient instead of finding existing → duplicate charts → lab results filed to wrong one. Probabilistic match (DOB + name + last4) at create time.
- **Sex/gender conflated.** Single field "gender = M" used for both biological sex (drives drug dosing, reference ranges) and gender identity. Separate columns per USCDI.

## Prescribing + medications

- **Prescription deleted instead of cancelled.** Pharmacy already received NEWRX; doesn't know about delete; fills the medication. Use NCPDP CancelRx transaction.
- **Refill granted on cancelled medication.** Provider discontinues drug clinically but refill request slips through (different workflow). Discontinue must propagate to refill response logic.
- **Schedule II refill granted.** Illegal — Schedule II has no refills, ever. State + federal violation. Hard block in code.
- **EPCS bypassed for "convenience".** Provider in a hurry clicks "send via fax" for controlled substance. Block code path entirely; fax not an option for controlled.
- **PDMP query skipped.** Required by state law before controlled prescribing; silent skip. Force query + acknowledgment.
- **Sig as free text only.** "Take one as needed" — pharmacy can't auto-fill structured Sig. Capture structured (dose + route + frequency + indication) in addition to free text.
- **DEA expired prescriber sending controlled Rx.** No real-time validation. Daily DEA validation + block on expire.

## Lab + results

- **Lab result without reference range.** Value 8.2 — high or low? No reference range = no abnormal flag. Reference range mandatory + age/sex-adjusted.
- **Result released to portal before provider review.** Patient sees "abnormal" without context, panics, calls. Cures Act allows narrow holds; provider reviews must be timely. Don't use blanket holds (information blocking).
- **Result reviewed but not addressed.** Provider clicks "reviewed"; no plan documented. Plan-of-action capture on critical/abnormal.
- **Order placed but result never returned.** Lost-result tracking absent. Outstanding-orders worklist + auto-followup.
- **Critical result acknowledgment delegated improperly.** Nurse acknowledges; provider never sees. Critical = provider-level acknowledgment.
- **Lab results filed to wrong patient.** Manual file; MRN typo. Auto-file via interface with patient-match validation; manual file requires double-check.

## Insurance + billing

- **Eligibility checked at registration but not at visit.** Patient's insurance lapsed in interim; claim denies. Re-check within 24h of service.
- **Coordination of benefits wrong order.** Primary/secondary swapped; rejection. COB rules in patient setup + verification.
- **CPT/ICD pairing without LCD/NCD check.** Medicare denies; A/R aging. Pre-submission scrubber.
- **Modifier omitted.** -25 (separate E/M with procedure same day) missing → procedure-only paid; E/M denied. Modifier prompts in coding.
- **Time-of-service collection skipped.** Patient walks out without paying copay; AR balloons. Display copay; require staff acknowledgment if skipped.
- **Claim submitted with patient demographics out of date.** Address change at check-in; claim built from old data. Refresh from current encounter snapshot.
- **Same claim submitted twice.** Different control numbers; both adjudicated; payer audits and demands refund. Idempotency key on claim submit.
- **Refunds processed outside system.** Front desk refunds copay in cash; no record. Single refund pathway with ledger entry.

## Interop + integrations

- **HL7 message processed twice (no idempotency).** Result filed twice; med list shows duplicates. Dedupe on message control ID.
- **HL7 ACK not sent.** Sender retries; downstream cascade. Always ACK after parse, even if business processing async.
- **FHIR Subscription firing on every change.** Subscriber DDOS'd. Apply rate limits + bundling.
- **CCDA exported includes deleted entries.** Patient asked for amendment to remove erroneous diagnosis; CCDA still has it. Sync from current state, not raw audit log.
- **Direct messaging certificate expired.** Delivery silently fails. Cert renewal automation + monitor.
- **DICOM accession number reused.** New study filed under old accession; viewer mis-displays. Globally unique accession generation.

## Consent + Cures Act

- **Consent assumed evergreen.** Patient signed NPP in 2019; NPP changed in 2023; never re-acknowledged. Version-track NPP + acknowledgment.
- **Sensitive data shared without consent (42 CFR Part 2 SUD).** SUD treatment record disclosed to PCP "because they're in the same network". Part 2 disallows; Part 2 records segregated.
- **Cures Act-blocked release of result.** Provider sets "hold for review" indefinitely; information blocking violation. Apply only narrow exceptions (specific harm cases) + audit.
- **Patient request for amendment ignored.** No workflow; lost in inbox. Amendment request is a regulated workflow with response-time obligation.
- **Right of access fulfilled in non-machine-readable format.** Sending PDFs when patient asked for FHIR/CCDA. Honor format requested if readily producible.

## Operational

- **Backup contains PHI but encryption key in same backup.** Defeats encryption purpose. Separate key management (KMS).
- **Snapshot of prod for "performance testing" emailed to dev.** PHI exfiltration. Synthetic data only outside prod.
- **Patient portal MFA via SMS only.** SIM swap → portal takeover → records exfil. Offer authenticator app + WebAuthn.
- **Account lockout on too-many-attempts NOT enabled.** Brute-force open. Lockout after 5-10 failures; with help-desk reset.
- **Session timeout never.** Unattended workstation in clinic; next user sees previous chart. 15-minute idle timeout (HIPAA "reasonable").
- **Sub-processor list stale.** Customer's BAA references AWS but you've moved to Azure; chain-of-custody broken.
- **Staging accessible from internet.** Pen-tester finds path; PHI in staging. VPN-only or zero-trust.

## UX traps

- **Click count to do common tasks.** Refilling 5 Rxs takes 50 clicks. Bulk actions; favorites.
- **Patient banner missing on screens.** Wrong-patient errors. Banner always visible (name, DOB, age, MRN, allergies, code status).
- **Note "save" vs "sign" ambiguous.** Provider thinks they signed; bills don't go out. Clear visual: draft (gray) vs signed (locked).
- **Inbox without filtering.** All messages, all results, all refills mixed. Filter by type + assigned-to-me + age.
- **Schedule view that doesn't reflect cancellations live.** Provider thinks day is full; staff knows of 3 holes. Real-time slot updates.
