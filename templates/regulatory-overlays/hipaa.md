# HIPAA overlay (US Health Insurance Portability and Accountability Act)

> Appended to `ai/business-compliance.md` by `/setup-project` Phase 4.4b.1 when HIPAA is declared in Phase 2.y `Constraints` facet. Operative text: 45 CFR Parts 160, 162, 164 — Privacy Rule (Subpart E), Security Rule (Subpart C), Breach Notification Rule (Subpart D), as amended by HITECH (2009) and the Omnibus Rule (2013).

## Scope

Two regulated roles, and which one you are decides everything downstream:

- **Covered Entity (CE)** — providers billing electronically, health plans, clearinghouses. Directly regulated.
- **Business Associate (BA)** — anyone creating, receiving, maintaining, or transmitting PHI *on behalf of* a CE. Since the 2013 Omnibus Rule a BA is **directly liable** for the Security Rule and much of the Privacy Rule, not merely contractually liable. Most health-tech products are BAs. **A BA's subcontractors are themselves BAs** — the obligation flows the whole vendor chain.

Holding health data does NOT make you a CE or BA. A consumer fitness app, a D2C wellness product, or an employer wellness platform outside a group health plan is typically outside HIPAA — and inside the FTC Health Breach Notification Rule plus state health-privacy law (Washington My Health My Data, Nevada SB 370, Connecticut CTDPA health provisions) instead. **Settle your status before writing schema**; the wrong answer buys either a pointless compliance burden or an uninsured liability.

**PHI** = individually identifiable health information held or transmitted by a CE/BA in any form. **ePHI** = the electronic subset the Security Rule governs. Health information alone is not PHI; health information plus one of the 18 identifiers below (or a realistic re-identification path) is.

**HIPAA is a floor.** More stringent state law is not preempted (California CMIA, Texas Medical Privacy Act — broader than HIPAA and reaching non-CEs, New York SHIELD). 42 CFR Part 2 (substance-use-disorder records) is materially stricter and needs patient consent even for treatment/payment/operations.

## The 18 identifiers (Safe Harbor list, §164.514(b)(2))

Load-bearing in code — this one list is simultaneously the definition of PHI, the Safe Harbor de-identification checklist, and the column-classification input for the data catalog:

names · geographic subdivisions smaller than a state (street, city, county, precinct, ZIP) · all date elements except year relating to an individual (birth, admission, discharge, death, service) plus all ages over 89 · telephone numbers · fax numbers · email addresses · Social Security numbers · medical record numbers · health-plan beneficiary numbers · account numbers · certificate / license numbers · vehicle identifiers + serial numbers including plate · device identifiers + serial numbers · web URLs · IP addresses · biometric identifiers including finger + voice prints · full-face photographs and comparable images · **any other unique identifying number, characteristic, or code**.

The last entry is a catch-all, and it is where naive pipelines fail: a stable pseudonymous `patient_uuid` handed to a system that also holds the mapping is an identifier.

## Minimum necessary (§164.502(b), §164.514(d))

Every use, disclosure, and *request* is limited to the minimum PHI needed. In code:

- **Role-scoped projections as the default read path**, not row filtering bolted on late. Billing sees encounter + payer + charge, not the clinical note; the full chart is the exception path.
- **No standing engineer access to production PHI.** Debug against de-identified or synthetic data; production access is time-boxed, justified, audited.
- **Internal analytics runs on a de-identified copy**, not a clinical replica with a `WHERE` clause.

Minimum necessary does **not** apply to: disclosures to or requests by a provider for treatment, disclosures to the individual, uses under a valid authorization, disclosures to HHS for enforcement, or uses required by law. Over-restricting clinical care paths in the name of compliance is its own patient-safety failure.

## Technical safeguards (§164.312) — Required vs Addressable

"Addressable" is not optional. It means implement it, or document why it is not reasonable and appropriate here **and** implement an equivalent alternative. Addressable with no implementation and no documented analysis is a finding.

| Spec | §164.312 | Status | In the codebase |
|---|---|---|---|
| Unique user identification | (a)(2)(i) | **Required** | Every actor is a distinct principal. No shared clinic logins; no service account acting as "the app" without carrying the human actor into the audit record. |
| Emergency access procedure | (a)(2)(ii) | **Required** | Documented break-glass path that works when normal auth is down, with heightened logging and mandatory post-hoc review. |
| Automatic logoff | (a)(2)(iii) | Addressable | Server-enforced idle timeout on clinical and admin sessions (10–15 min is the shared-workstation norm), not a client timer. |
| Encryption / decryption (at rest) | (a)(2)(iv) | Addressable | Addressable in the rule, effectively mandatory because it is the breach safe harbor. |
| Audit controls | (b) | **Required** | Mechanisms that record and examine activity in ePHI systems. No implementation spec is given — you choose the mechanism and you own proving it works. |
| Integrity — authenticate ePHI | (c)(2) | Addressable | Detect improper alteration or destruction: checksums, versioned records, append-only clinical history, referential integrity. |
| Person or entity authentication | (d) | **Required** | MFA is not literally named in the current rule text; it is the de facto expectation and is explicit in the proposed update below. |
| Transmission security — integrity controls | (e)(2)(i) | Addressable | Detect modification in transit. |
| Transmission security — encryption | (e)(2)(ii) | Addressable | TLS. Same practical conclusion as at-rest encryption. |

Behind these sit the **Administrative safeguards (§164.308)** engineering has to service: the enterprise-wide **risk analysis** (§164.308(a)(1)(ii)(A)) — the most-cited failure in OCR resolution agreements — plus sanction policy, workforce training, periodic technical evaluation (§164.308(a)(8)), and the **contingency plan** (§164.308(a)(7)), whose data-backup, disaster-recovery, and emergency-mode-operation specs are **Required** (testing/revision and criticality analysis are addressable).

> **Pending change**: HHS published a proposed Security Rule overhaul (NPRM, Dec 2024 / Jan 2025) that would remove Required/Addressable entirely and explicitly mandate MFA, encryption of all ePHI at rest and in transit, asset inventory, network segmentation, and annual compliance audits. **Verify whether it has been finalized before relying on the table above** — do not assume either way.

## Encryption

- **At rest** — NIST SP 800-111 is the reference. Full-disk encryption satisfies the letter but only protects against physical loss; it does nothing against a compromised application or a leaked credential. Add database-level encryption plus **application-level field encryption for the highest-sensitivity columns** (SSN, SUD flags, mental health, HIV status, reproductive care) so a replica dump or an injection payload yields ciphertext.
- **In transit** — TLS 1.2+ per NIST SP 800-52 Rev 2. Service-to-service traffic is transmission: mTLS or a service mesh, not "it's inside the VPC."
- **The safe harbor is why this is not optional.** PHI that is *secured* — encrypted per HHS guidance, or destroyed per NIST SP 800-88 — is not *unsecured* PHI, so losing it is **not a reportable breach**. A stolen encrypted laptop is paperwork; an unencrypted one is a 60-day notification, an HHS filing, and possibly a press release. **The safe harbor evaporates if the key travelled with the data** — so key custody is the real control: managed KMS/HSM, keys never in the repo or image, documented rotation, key-management principal separated from the data-plane principal.
- Encryption does **not** exempt a cloud provider from being a BA. HHS's 2016 Cloud Computing guidance is explicit: a CSP storing encrypted ePHI **without the key** is still a business associate and still needs a BAA. "No-view services" is not a carve-out.

## Audit controls + logging

§164.312(b) is Required and deliberately unspecified. What satisfies an OCR investigator:

- **Log every READ of PHI, not just every write.** This is the biggest divergence from ordinary audit-log design, which instruments mutations. The HIPAA question is "who looked at this chart?" — snooping (celebrity records, a neighbour, an ex-spouse, a colleague) is the most common real-world violation and is invisible in a mutation log.
- **Each record carries** actor (unique user ID), subject (patient), action, timestamp with timezone, source address/device, records touched, access path (UI / API / report / direct query), and outcome (permitted / denied / break-glass).
- **Break-glass is a first-class event type** — justification captured at access time, routed to a review queue with an owner and a closure SLA. Break-glass with no review is worse than none: it manufactures evidence of an uninvestigated access.
- **Direct database access is in scope.** A DBA session on the clinical database is a PHI access. Un-attributable, un-reviewed paths must be closed.
- **Detection, not just retention** — same-surname access, VIP flags, access with no active care relationship, volume anomalies. Proactive review is what turns the log from liability into control.
- **Retention: 6 years is the operative floor**, and be precise about why, because the number is widely misquoted. The Security Rule sets **no explicit log-retention period**. §164.316(b)(2)(i) requires rule-mandated *documentation* to be kept 6 years from creation or last effective date, and §164.528 gives patients an accounting of non-TPO disclosures **covering the prior 6 years** — unproducible without the underlying records. State medical-record retention (often 7–10 years, longer for minors) can extend it. Set 6 years as the minimum, then check state law. Logs stay searchable within the window, tamper-evident (append-only / WORM / hash-chained), and access to the audit log is itself audited.

## Business Associate Agreements

- **Required with every BA** (§164.502(e), §164.504(e)) and by the BA with **every subcontractor** touching PHI. A BAA with your cloud provider and none with the error-tracker its SDK forwards stack traces to is a gap, not a technicality.
- **The conduit exception is vanishingly narrow** — transport with transient access only (postal service, ISP). It never covers storage.
- **"HIPAA compliant" is not a certification.** No body certifies it. A vendor badge means nothing; a countersigned BAA plus your own risk analysis is the artifact. HITRUST CSF is evidence, not compliance.
- **Vendors are often covered only in a specific mode or tier.** Messaging, email, video, error-tracking, and LLM providers routinely offer a HIPAA configuration that is neither the default nor the free tier. Running on a plan the BAA does not cover is the same as having no BAA.
- **Cloud BAAs cover an enumerated service list.** Processing PHI through a service outside your provider's HIPAA-eligible list voids coverage for that path — a live risk whenever a team adopts a new managed service.
- Keep the **BAA inventory as a versioned repo artifact**, not a spreadsheet: vendor, PHI category, coverage mode, execution date, subcontractor chain, owner. Gate new egress destinations and dependencies against it in review.

## Breach notification (Subpart D, §164.400–414)

- **Presumption of breach.** Any impermissible use or disclosure of unsecured PHI **is** a breach unless you demonstrate low probability of compromise via the documented four-factor risk assessment (§164.402): nature and extent of the PHI including re-identification likelihood; who received it; whether it was actually acquired or viewed; extent of mitigation. **Document the assessment even when the answer is "not a breach"** — the analysis is the deliverable.
- **Individuals**: without unreasonable delay, no later than **60 calendar days from discovery** (§164.404). Discovery is when the incident is known **or would have been known with reasonable diligence** by any workforce member — not when the investigation concludes.
- **HHS**: **≥500 individuals** — contemporaneously with individual notice, within 60 days, and published on the OCR breach portal. **<500** — logged and submitted annually, within 60 days after the calendar year ends (§164.408).
- **Media**: ≥500 residents of one state or jurisdiction — prominent media outlets there, within 60 days (§164.406).
- **BA → CE**: no later than 60 days from discovery (§164.410). **Your BAAs will contract this down** — 24 to 72 hours is the market norm, and that contractual clock, not the regulatory one, is what on-call actually has to hit.
- Enforcement is **HHS OCR**, across four HITECH culpability tiers (no knowledge / reasonable cause / willful neglect–corrected / willful neglect–not corrected). Per-violation amounts and annual caps are **inflation-adjusted annually** — look up the current Federal Register figures rather than quoting a stale table. State AGs may also enforce; DOJ handles criminal cases under 42 U.S.C. §1320d-6. Demonstrating 12 months of **Recognized Security Practices** (NIST CSF, HICP/405(d)) mitigates penalties under the 2021 HITECH amendment.

## De-identification (§164.514) — two lawful methods, and only two

De-identified data is **not PHI** and leaves HIPAA entirely. This is the highest-leverage architectural move available: it is what makes analytics, ML, vendor demos, and non-production environments tractable.

**Safe Harbor (§164.514(b)(2))** — remove all 18 identifiers **and** hold no actual knowledge that the residual data could identify someone alone or in combination. Mechanical, cheap, auditable, lossy. What engineers get wrong:

- **Dates**: year only. Admission, discharge, service, and birth dates lose month and day. For longitudinal work apply a **consistent per-patient date shift** so intervals survive — but shifting alone is not Safe Harbor; retained precision must still be year-level.
- **Ages over 89** collapse into a single "90 or older" bucket, along with any date element indicative of such an age.
- **ZIP** truncates to 3 digits, and only where the population sharing those 3 digits exceeds 20,000. For the small set of prefixes below that threshold the field must be `000`. HHS publishes the list; refresh it rather than hardcoding a copy with no review date.
- **Free text is where Safe Harbor dies.** Applying the checklist to structured columns while shipping clinical notes, chief complaints, `address_line_2`, or transcripts verbatim to a warehouse is the classic failure. Free text needs NLP scrubbing plus sampled human review, and the output is best-effort, not certified.

**Expert Determination (§164.514(b)(1))** — a person with appropriate statistical and scientific knowledge determines re-identification risk is **very small** and documents the methods and results. More expensive, retains far more utility (real dates, finer geography, rare diagnoses), and is the right answer for research and ML datasets. The determination is scoped to a specific dataset, recipient, and release context — **it does not generalize** — and should be re-evaluated on a defined cadence as auxiliary data grows. The report is the only evidence the data is out of scope.

**Limited Data Set (§164.514(e))** is neither, and is routinely confused with de-identification. It strips 16 direct identifiers but **may retain dates and city/state/ZIP**. Still PHI; permitted only for research, public health, and operations, and only under a signed **Data Use Agreement**. Useful — not an exit from HIPAA.

## Data residency

HIPAA imposes **no data-residency requirement**; PHI may lawfully be stored and processed outside the US. This surprises teams arriving from GDPR, and it cuts both ways:

- The BAA must still bind the offshore processor, and OCR's practical reach against a foreign subcontractor is weaker — so your own risk analysis carries more weight.
- **Contracts, not the regulation, are what usually pin you to a region.** CE customers, Medicaid/state agency contracts, and VA/DoD work routinely mandate US-only storage and US-person access. Model residency as a per-tenant customer commitment, not a global constant.
- Offshore *access* is disclosure even when storage stays domestic — an offshore support team with production console access is a cross-border flow.

## Consent + disclosure surfaces

- **Notice of Privacy Practices (§164.520)** — given at first encounter with a good-faith effort to obtain acknowledgment, and posted on the website. Capture the acknowledgment as a dated record referencing the NPP version served.
- **Authorization (§164.508)** — required for marketing, any sale of PHI, psychotherapy notes, and uses outside treatment/payment/operations. Model it as a **first-class record with scope, purpose, recipient, expiry, and revocation**, never a boolean column — and propagate revocation to downstream consumers.
- **Right of access (§164.524)** — copy of the designated record set within **30 days**, one 30-day extension, in the form and format requested where readily producible; fees cost-based and narrow. OCR's Right of Access Initiative has produced a long run of enforcement actions against slow or over-charging responders. Treat export as a product feature with an SLA, not a support ticket.
- **Right to amendment (§164.526)** — patients request corrections; denial must be documented and the patient's statement of disagreement attached. Note what this is *not*: **HIPAA confers no right to erasure.** Amendment appends; it does not delete.
- **Accounting of disclosures (§164.528)** — 6 years of non-TPO disclosures on request, producible only if disclosures are recorded as structured events when they happen.
- **Online tracking technologies** — the OCR/FTC bulletin (Dec 2022, revised Mar 2024) treats third-party trackers transmitting identifiers alongside health context as impermissible disclosures absent a BAA. The portion covering *unauthenticated* pages was vacated in *AHA v. Becerra* (N.D. Tex., June 2024); **authenticated patient-portal pages remain squarely in scope**, and this is an active enforcement and class-action area. A pixel, session-replay script, or ad SDK on a logged-in portal page is a disclosure to that vendor.

> **Verify before relying on it**: the 2024 Privacy Rule amendment on reproductive-health-care privacy (attestation requirements for certain disclosures) has been litigated, including a nationwide vacatur ruling. Confirm where it stands rather than assuming it is in force or dead.

## Engineering consequences — what MUST and MUST NOT appear in the code

**MUST NOT**

- **PHI in URLs** — path segments or query strings. It lands in access logs, proxy and CDN logs, browser history, `Referer` headers sent to third parties, and APM trace names. Opaque surrogate IDs in the path; identifiers in the body.
- **PHI in application logs, stack traces, or exception payloads.** Scrub at the emitter, not the sink, and test it — the failure mode is a serialized request body inside an error report. An error-tracker or APM without a BAA *and* with body capture disabled is an unlogged disclosure.
- **PHI in analytics events, session replay, heatmaps, chat widgets, or ad pixels** (see tracking technologies above).
- **PHI in prompts to an LLM provider without an executed BAA and zero-retention configuration.** The major providers offer both; neither is the default.
- **Production PHI in non-production.** No prod snapshots into staging, no PHI in seeds, fixtures, demo tenants, or local dumps. De-identified extracts or synthetic generation only.
- **PHI in commit messages, tickets, ticket screenshots, or chat.** The most common day-to-day leak, and a workflow problem — mask in the UI so a screenshot cannot capture what it must not.
- **A GDPR-style hard-delete endpoint.** Engineers who have shipped erasure build one by reflex. HIPAA has no erasure right and state law imposes multi-year retention on the designated record set; a `DELETE` that destroys a clinical record can itself be the violation. Amendment, correction, status flags — not destruction.
- **Unencrypted PHI in email or SMS by default.** A patient may request unencrypted email and you must honour it after advising of the risk — a per-patient recorded election, not a global setting. Reminders must not disclose the reason for the visit; the diagnosis-revealing SMS or voicemail is a textbook breach.
- **Shared accounts anywhere on the path to PHI** — including the front-desk login and the database.

**MUST**

- **Authorize at the query layer, scoped to the care relationship.** An IDOR on a chart endpoint is not a bug ticket, it is a reportable breach. Deny by default; the patient identifier in the request is never the authorization.
- **Emit an audit event on every PHI read**, structured as above, on every path — UI, API, report, export, direct query.
- **Ship a break-glass path** with justification capture and a reviewed queue.
- **Encrypt at rest and in transit with key custody separated from the data plane** — this is what buys the breach safe harbor.
- **Classify PHI columns in the schema itself** (annotation, catalog, or migration-enforced tag) so the de-identification pipeline, the log scrubber, and the export builder read one source of truth instead of three drifting allow-lists.
- **Keep de-identification as real code with tests** exercising the date, age-90, ZIP, and free-text rules — plus the Expert Determination report on file where you rely on it.
- **Encrypt backups and DR copies and test the restore** — the contingency-plan specs are Required, and an untested backup is a control failing silently.
- **Enumerate every egress destination** (vendor, region, PHI category, BAA status) and gate new ones in review.
- **Time-box and audit production access**, with engineering defaulting to de-identified data.

## Required integrations

- **HIPAA-eligible cloud configuration with a signed BAA** — plus a check that every service on the PHI path is on the provider's eligible list.
- **Managed KMS / HSM** for key custody, with rotation policy and separated access.
- **SIEM / log platform** with ≥6-year retention, tamper-evident storage, and audit-log access itself audited.
- **PHI-scrubbing log pipeline** — redaction at the emitter plus a detector at the sink for what the emitter missed.
- **Access-monitoring / patient-privacy analytics** for snooping detection — the proactive-review half of §164.312(b).
- **Identity provider with MFA + SSO**, automatic session termination, and same-day deprovisioning wired to HR.
- **Messaging / email / video providers in HIPAA mode, with BAA** — default modes are not covered.
- **Error tracking + APM with BAA and body capture disabled.**
- **De-identification tooling** for structured and free-text data, plus **synthetic patient-data generation** for non-production.
- **Secret manager** — no credentials in the repo or image.
- **MDM + full-disk encryption + remote wipe** on any workstation that can reach PHI.
- **Risk-analysis and BAA-tracking system of record** — the HHS/ONC Security Risk Assessment tool is a reasonable starting point for smaller organizations.

## Anti-patterns (pass generic compliance, fail HIPAA)

- **Audit logging only mutations.** Every general-purpose audit design logs writes; HIPAA asks who *read* the chart. Invisible until OCR requests an access history you cannot produce.
- **"We're encrypted at rest"** — via the storage checkbox, while the analytics warehouse copy, the nightly export bucket, the search index, and the queue backlog are not.
- **Assuming encryption removes the BAA obligation.** HHS cloud guidance says otherwise, explicitly, including for zero-knowledge storage.
- **A pixel, session-replay script, or ad SDK on the patient portal** — enforcement-active, class-action-active, and usually added by a tag manager with no engineering review.
- **De-identification that means "we dropped the name column."** Dates, ZIP, ages over 89, free text, and the catch-all identifier are where identity survives.
- **A BAA with the vendor but not its subcontractor** — or one covering a plan tier you are not on.
- **Trusting a "HIPAA compliant" badge.** No such certification exists; only a countersigned BAA plus your own assessment.
- **A GDPR-shaped delete endpoint on clinical records** — destroying what retention law requires you to keep.
- **Break-glass with no review queue** — an audit trail nobody reads is evidence of a control that does not operate.
- **Engineers with standing production read access to full charts**, justified as "we need it to debug." A minimum-necessary violation every ordinary workday.
- **Prod data in staging** — the most common source of large healthcare breaches that had nothing to do with an attacker.
- **Treating 60 days as the plan.** The clock starts at discovery, discovery includes what a workforce member *should* have known, and your BAA almost certainly obligates a 24–72 hour notice to the covered entity long before the regulatory deadline.
- **No enterprise-wide risk analysis, or one done once at launch** — the most-cited failure in OCR resolution agreements. "We did a pen test" is not it.
- **Confusing HITRUST certification with HIPAA compliance** — evidence toward it, not a substitute, and neither replaces the BAA.
- **Compliance owned outside engineering** — policies written without the team that must implement audit-on-read, key custody, and the de-identification pipeline describe a system nobody built.

## Cross-references

- Pair with **`soc2.md`** — health-tech buyers ask for a SOC 2 report *and* a BAA; access control, logging, vendor management, and incident response overlap heavily. Run one evidence programme, not two.
- Pair with **`pci-dss.md`** if you take copays, patient balances, or self-pay — card data is governed separately from the chart.
- Pair with **`gdpr.md`** if you serve EU patients, and reconcile the conflict deliberately: GDPR grants an erasure right; HIPAA and state retention law forbid destroying the designated record set. Usual resolution is jurisdiction-scoped retention plus a documented Art. 17(3)(b) legal-obligation ground.
- Pair with **`ferpa.md` (planned — not yet shipped)** for student-health records, where the FERPA/HIPAA boundary is genuinely tricky; **`iso-27001.md` (planned — not yet shipped)** for formal infosec governance; **`ccpa.md` (planned — not yet shipped)** for California consumer-health overlap; **`nphies.md` (planned — not yet shipped)** if the product is Saudi rather than US, where HIPAA defaults are the wrong regime entirely.
- Domain landscape: **`templates/business-domains/healthcare/compliance.md`** carries the wider US picture — 42 CFR Part 2, Cures-Act information blocking, ONC certification, CMS quality programmes, DEA/EPCS, FDA SaMD, state boards, retention schedules. Read it alongside this file; this overlay is the engineering-facing HIPAA slice and does not restate it.
- Technical signals: **`templates/domains/audit-log/`** (tamper-evident append-only trail), **`templates/domains/compliance/`** (retention rules — note its export/delete pattern is GDPR-shaped and must NOT be applied to a clinical record set), **`templates/domains/auth/`** (unique IDs, MFA, session discipline), **`templates/domains/multi-tenant/`** (isolation between covered entities).
- Authority: HHS Office for Civil Rights — hhs.gov/hipaa for rules, guidance, and the breach portal. **NIST SP 800-66 Rev. 2** (Feb 2024) is the practical Security Rule implementation guide and maps each spec to concrete controls; **SP 800-111** (at rest), **SP 800-52 Rev. 2** (in transit), and **SP 800-88** (destruction) define the safe-harbor bar.
