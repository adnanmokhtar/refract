# GDPR overlay (EU General Data Protection Regulation)

> Appended to `ai/business-compliance.md` by `/setup-project` Phase 4.4b.1 when GDPR is declared in Phase 2.y `Constraints` facet.

## Scope

GDPR applies to **any product processing personal data of EU/EEA residents**, regardless of where the company is based. One EU user is enough to put you in scope. "Personal data" is broad: name, email, IP address, device ID, location, online identifier, biometric, genetic, health, racial/ethnic, political, religious, trade-union, sexual orientation — anything that identifies a natural person directly OR in combination with other data.

UK GDPR is a near-identical separate regime post-Brexit; comply with both if serving UK + EU.

## Lawful basis (Art. 6) — required for every processing activity

Pick ONE per activity, document it:

- **Consent** — specific, informed, freely given, unambiguous, withdrawable. NOT consent: pre-ticked boxes, bundled consent, "by using this service you agree."
- **Contract** — necessary to perform a contract with the data subject (e.g., shipping address for an order).
- **Legal obligation** — required by EU or member-state law (e.g., tax records, AML).
- **Vital interests** — life-or-death situations (rare).
- **Public task** — government / official authority.
- **Legitimate interests** — your business interests, balanced against the user's rights and freedoms. NOT a catch-all; document the balancing test (Legitimate Interests Assessment / LIA).

Special-category data (Art. 9 — health, biometric, genetic, sexual orientation, etc.) needs a stronger basis: explicit consent, employment law, vital interests, public-interest health, legal claims, or substantial public interest. "Legitimate interests" alone does NOT cover special-category data.

## Data subject rights (build endpoints for ALL of them)

Each user account needs working endpoints for:

- **Access** (Art. 15) — user requests a copy of their data → respond within 30 days.
- **Rectification** (Art. 16) — user corrects inaccurate data.
- **Erasure / "right to be forgotten"** (Art. 17) — user demands deletion → 30 days. Exceptions: legal retention obligations, freedom-of-expression overrides, public-health archiving.
- **Portability** (Art. 20) — user gets their data in machine-readable format (JSON, CSV, XML).
- **Restriction** (Art. 18) — user pauses processing pending dispute.
- **Objection** (Art. 21) — user opts out of legitimate-interest processing (especially marketing — must be a one-click opt-out).
- **Automated decision-making** (Art. 22) — user opts out of solely-automated decisions with legal or similarly-significant effects (loan denial by AI, automated hiring rejection, etc.).

Implementation: `/api/me/export`, `/api/me/delete`, `/api/me/correct`, marketing-preferences endpoint, opt-out for any AI-based decisioning. NOT optional.

## Data handling

- **Encryption at rest** mandatory for special-category data; strongly recommended for all personal data.
- **Encryption in transit** (TLS 1.2+) — hard requirement.
- **Cross-border transfers** (data leaving EU/EEA): need Standard Contractual Clauses (SCCs), Binding Corporate Rules, adequacy decision (UK / Switzerland / Japan / etc.), or specific derogations. Schrems II killed Privacy Shield — US transfers need Transfer Impact Assessment + supplementary measures (Data Privacy Framework, post-2023, restored some adequacy for US transfers but only for participating cos).
- **Data minimization** (Art. 5) — collect ONLY what you need. "We might need it later" is not a lawful basis.
- **Retention limits** — define how long each data type is kept. Auto-delete or auto-anonymize after retention expires.
- **Pseudonymization** preferred over raw identifiers where possible (especially for analytics, telemetry, ML training).
- **Privacy by design + default** (Art. 25) — privacy as the default; opt-in for additional uses.

## Consent + disclosure

- **Cookie consent** — must block tracking cookies / pixels / SDKs UNTIL consent given. "Reject all" must be as easy as "Accept all" (CJEU 2024 rulings + CNIL fines on dark patterns). No pre-ticked checkboxes, no walls of text disguising opt-outs.
- **Privacy policy** — layered (short summary + detailed), kept current, dated. Must list: identity of controller, contact info, lawful basis per activity, retention periods, recipients (including processors), data-subject rights, complaint authority.
- **DPA (Data Processing Agreement)** — required with every processor (vendors that touch personal data on your behalf — Stripe, AWS, SendGrid, OpenAI, Mixpanel, etc.). No DPA = direct GDPR violation by you, regardless of vendor's behavior.
- **Joint controllers** (Art. 26) — if two parties decide jointly on means + purposes, they need a documented arrangement.

## Audit + logging

- **Records of Processing Activities (RoPA, Art. 30)** — maintain documented inventory of every processing activity: purpose, lawful basis, data categories, retention periods, recipients, transfer mechanisms. Required for orgs >250 employees OR processing special-category / regular high-risk data. Most orgs maintain it regardless — auditors will ask.
- **Logs themselves are personal data** if they contain user identifiers — apply retention limits + access controls to log infrastructure.
- **Demonstrate compliance** (Art. 5(2)) — accountability principle. You must be able to PROVE compliance, not just claim it.

## Incident response timeline

- **72-hour breach notification** to lead supervisory authority (the DPA where your "main establishment" is — usually HQ for EU companies; your "lead authority" via one-stop-shop). Clock starts when you become AWARE of the breach, not when you finish investigating. Late notification (without documented justification) = fine.
- **Notify affected users** "without undue delay" if breach is likely to result in HIGH risk to their rights and freedoms (e.g., financial data, health data, large-scale identity exposure).
- **Document every breach** in an internal log (Art. 33(5)) — even ones not reportable.
- **A "breach" is broad** — accidental loss, unauthorized access, unauthorized disclosure. A laptop stolen with encrypted data is a breach but typically not reportable. A misconfigured S3 bucket exposing PII IS reportable.

## Required integrations

- **Cookie consent management platform (CMP)** — OneTrust / Cookiebot / Iubenda / Didomi, or self-built meeting IAB TCF v2.2.
- **DSAR fulfillment system** — tracks data-subject access requests with 30-day SLA. Manual via support tickets is acceptable for small ops; automated for scale.
- **Data deletion pipeline** — must cascade across primary DB + replicas + backups + analytics + 3rd-party processors (Stripe, Mixpanel, Sendgrid, etc.). "Soft delete" alone is NOT erasure under GDPR — backups must have a retention + auto-purge schedule.
- **Breach detection + paging** — SIEM tied to incident-response on-call with documented escalation.
- **DPIA workflow** — for high-risk processing (see below).

## DPIA trigger (Data Protection Impact Assessment, Art. 35)

Required BEFORE high-risk processing starts:
- Systematic + extensive automated decision-making with legal/similar effects.
- Large-scale special-category data (health, genetic, biometric).
- Systematic monitoring of public area.
- Innovative tech on personal data (AI, biometrics, IoT tracking, large-scale ML).

If your product matches any of these → DPIA is mandatory; output a documented assessment + mitigations + DPO sign-off (or external review if no DPO).

## DPO (Data Protection Officer) trigger

Required when:
- Public authority / body.
- Core activities require regular + systematic monitoring of data subjects on a large scale (analytics-driven products often qualify).
- Core activities involve large-scale processing of special-category data.

DPO can be internal (with no conflict of interest — NOT the CTO or CEO) or external (fractional DPO services exist).

## Anti-patterns (pass generic compliance, fail GDPR)

- **Pre-ticked consent boxes** — invalid consent (Planet49 ruling).
- **"Legitimate interests" used as catch-all** — auditor will challenge; needs documented LIA per activity.
- **Shadow PII databases** — that `temp_user_imports` table accumulating CSV uploads is unlogged personal data. Find them, document them, retention-limit them.
- **No DPA with processors** — common with smaller vendors. Each one is a violation.
- **Logs with raw PII** — even error stack traces with user emails are personal data; retention applies.
- **Backups with no deletion plan** — "right to be forgotten" extends to backups; either delete from backups on cycle or document why retention is justified + the timeline for eventual deletion.
- **Cross-border transfer with no SCCs** — using a US analytics tool without DPF participation or SCCs.
- **"By using our service you consent to..."** — bundled consent is not consent.
- **Cookie banner that doesn't actually block tracking** — most common failure mode. Test it: open in incognito, check Network tab BEFORE clicking accept.
- **Treating GDPR as a one-time project** — it's continuous. New processing activity = update RoPA + reassess lawful basis + reassess DPIA need.

## Cross-references

- Pair with **`pci-dss.md`** if processing payments (PCI for card data; GDPR for the customer).
- Pair with **`iso-27001.md` (planned — not yet shipped)** if doing formal infosec governance — significant control overlap.
- Pair with **`ccpa.md` (planned — not yet shipped)** if also serving California users — similar but distinct regime.
- Authority guidance: EDPB (European Data Protection Board), local DPAs (CNIL France, BfDI Germany, AEPD Spain, ICO UK).
- Templates: EDPB has approved DPA + SCC templates; use them as starting points, customize.
