# SOC2 overlay (System and Organization Controls 2)

> Appended to `ai/business-compliance.md` by `/setup-project` Phase 4.4b.1 when SOC2 is declared in Phase 2.y `Constraints` facet.

## Scope

SOC2 is an **AICPA auditing standard** — not a regulation. There's no "SOC2 fine"; the audit produces a confidential report (not a certification) that customers (especially enterprise B2B buyers) require before signing contracts. **Most B2B SaaS companies need SOC2 to close enterprise deals**, particularly mid-market and up.

Confusingly: the report is called "SOC 2 Report"; you "achieve SOC 2 compliance" but you don't "get SOC 2 certified" — that's marketing-speak.

## Type 1 vs Type 2

- **Type 1**: point-in-time. "These controls exist as of date X." Faster (1-2 months prep + audit), cheaper (~$15-30K), lower credibility.
- **Type 2**: over a period (typically 6-12 months). "These controls operated effectively from X to Y." Standard for production credibility. Cost: $30-80K+ depending on auditor + scope.

Most enterprise buyers want Type 2. Plan for Type 1 → Type 2 path: get Type 1 fast, then 6-12 month observation window, then Type 2.

## Trust Service Criteria (TSCs)

Five TSCs — pick which apply to your audit. **Security is mandatory**; the others are optional based on customer commitments:

| TSC | When to include |
|---|---|
| **Security** (Common Criteria CC1–CC9) | Always — universal infosec controls |
| **Availability** | If you commit to uptime SLAs |
| **Processing Integrity** | If processing-correctness is a customer concern (financial systems, healthcare, supply chain, etc.) |
| **Confidentiality** | If customers send you confidential data (most B2B SaaS) |
| **Privacy** | If you process personal info AND want explicit AICPA Privacy attestation (overlaps GDPR/CCPA partially) |

Most B2B SaaS = **Security + Availability + Confidentiality**. Fintech / healthcare / data-processing → also Processing Integrity. Consumer-facing PII processors → also Privacy.

## Common Criteria highlights (always required)

### Control environment + governance

- **Documented policies** (~15-20 typical): information security, acceptable use, access control, incident response, change management, vendor management, BCP/DR, data classification, encryption, password, remote work, device security, vulnerability management, secure development, asset management, risk management.
- **Annual policy review + update** with version history.
- **Board-level oversight** (or equivalent for smaller cos): security KPIs reported up; board reviews + approves policies.
- **Risk assessment** — documented, reviewed at least annually, drives controls. Quantitative or qualitative; just be consistent.
- **Code of conduct + ethics policy** — signed by all employees on hire + annually.

### Access control (the #1 area auditors scrutinize)

- **MFA on all production access** — admin console, SSH, VPN, code repo with prod access, anything CDE-equivalent. v4.0+ broadened: **MFA into the environment, not just to admin endpoints**.
- **SSO + identity provider** (Okta / Auth0 / Azure AD / Google Workspace) for employee access. Per-app password is a finding.
- **Quarterly access reviews** — managers re-attest each direct report's access. Document attestation; track exceptions.
- **Onboarding + offboarding checklists** with audit trail (HR triggers IT triggers access provision/de-provision; offboard within same day for terminations).
- **Privileged access**: just-in-time elevation preferred; no persistent root. PAM tools (CyberArk, Teleport, AWS SSM) are common.
- **Service accounts**: documented purpose; credentials in secret manager; rotation policy.

### Background checks

- Background checks on all employees + contractors with privileged production access. Timing varies by jurisdiction (some places forbid pre-offer; many require post-offer pre-start).

### Change management

- **Ticketed changes**: every prod-affecting change tracked in Jira / Linear / GitHub Issues with approver + tester. "Just fix it" workflows are an automatic finding.
- **PR review** before merge to protected branches; documented who approved (CODEOWNERS + branch protection enforced).
- **Separation of duties**: developer who wrote the code is NOT the one who deploys to prod (or compensating control documented — e.g., automated CI/CD with no manual override AND post-deploy review).
- **Test environments** that meaningfully mirror prod; changes tested before prod.
- **Rollback plan** documented per change.

### Logging + monitoring

- **Centralized logging** (SIEM) with retention covering audit period + buffer (typically 12+ months).
- **Alerting on security events**: failed logins, privilege escalations, unauthorized access attempts, data exfiltration patterns, anomalous data volumes.
- **Log integrity** — tamper-evident (cloud-native log services typically meet this; rolled-your-own usually doesn't unless WORM-stored).
- **Daily SOC review** of high-priority alerts; documented review process.

### Vulnerability management

- **Documented program**: scan cadence, severity thresholds, SLA for remediation by severity (e.g., critical: 7 days; high: 30 days; medium: 90 days).
- **Quarterly vulnerability scans** (typical); critical vulns patched within agreed SLA.
- **Annual pen test** (typical for Type 2); some auditors accept biennial for low-risk profiles.
- **Dependency scanning** — Dependabot / Snyk / Trivy / GitHub Advanced Security on the SBOM.

### Vendor management

- **Vendor inventory + risk assessment** for every third party touching prod or customer data.
- **DPA / DPIA / security questionnaire** completed for high-risk vendors before contract signature.
- **Annual re-assessment** for critical vendors (tier 1).
- **Incident notification clauses** in vendor contracts (typically 72-hour notification).
- **Vendor SOC2 reports** collected + reviewed annually for tier-1 vendors.

### Incident response

- **Documented IRP** with severity levels + escalation paths + post-mortem process.
- **Tested annually** (tabletop minimum; full simulation better).
- **Post-mortems** for SEV1/SEV2 incidents + tracked corrective actions; auditor will ask to see action items closed.
- **Communication plan** including customer notification thresholds + timeline.

### Encryption

- **At rest** for customer data (AES-256 typical; cloud-native KMS).
- **In transit** (TLS 1.2+ minimum) for all customer-facing endpoints.
- **Key management** documented (rotation policy, access control, HSM/KMS).
- **Internal traffic encryption** increasingly expected (mTLS, service mesh).

## Availability TSC (if in scope)

- **Documented uptime SLA** + measurement + customer-facing status page (Statuspage / Better Stack / Instatus).
- **Capacity planning** documented + reviewed quarterly.
- **BCP/DR plan** + annual test (table-top minimum, full failover better).
- **Backups** with documented retention + restore-tested at least annually.
- **Redundancy** at chosen layers (load balancer, DB, region) — match your SLA promise.
- **RTO + RPO** documented per system; tested via DR exercise.

## Processing Integrity TSC (if in scope)

- **Input validation** + error handling documented in code review checklists.
- **Data integrity checks** (checksums, balancing, reconciliation between systems).
- **Output completeness verification**.
- **Job monitoring** with alerting on failure; failed-job remediation tracked.

## Confidentiality TSC (if in scope)

- **Data classification scheme** (Public / Internal / Confidential / Restricted) + handling rules per class.
- **Encryption controls** scoped to confidential data.
- **NDA** on all employees + contractors with prod access; signed before access granted.
- **Data destruction** on contract termination — documented + customer-confirmable.

## Privacy TSC (if in scope — often deferred unless strategic)

- Aligns with AICPA's Generally Accepted Privacy Principles (GAPP).
- Significant overlap with GDPR/CCPA; if you're already compliant with those, the additional lift is documentation + auditor sign-off.

## Audit + reporting

- **Auditor selection**: pick a CPA firm registered with AICPA. Big 4 (Deloitte / KPMG / EY / PwC) = expensive + maximum credibility. Mid-tier (BDO / RSM / Crowe / Marcum) = balanced. Boutique SOC firms (Schellman / A-LIGN / Insight Assurance / Prescient) = SOC2-specialist + cheaper. **For most early-stage SaaS, boutique is the right pick.**
- **Audit period**: 6-12 months for Type 2. First Type 2 typically uses minimum 6-month period.
- **Evidence collection**: continuous throughout the period. Tools like Vanta / Drata / Secureframe / Tugboat / Thoropass automate evidence collection — strongly recommended; dramatically cheaper than manual prep.
- **Report**: confidential. Customers sign NDA to read it. **Never post the SOC2 report publicly**; share via DocSend / data room / NDA-gated portal. Trust-center pages (Vanta Trust / Drata Trust) are the modern way.

## Anti-patterns (pass generic security, fail SOC2)

- **No ticket trail for prod changes** — engineer SSH'd in and "just fixed it." Top finding by frequency.
- **Shared admin accounts** — `root` SSH key on multiple machines, no per-user accountability. Even one shared service account password is a finding.
- **No quarterly access reviews** — managers never re-attest, ex-employees still have access (or interns from last summer, or contractors whose engagement ended).
- **MFA bypass on "emergency" or "service" accounts** that nobody monitors.
- **Vendors added without security questionnaire** — Marketing signed a 3-letter SaaS vendor without IT involvement; that vendor has API keys to your CRM with PII.
- **Logging gaps in critical paths** — auth events not logged, or PROD logs go to a folder no one reviews.
- **No tested DR plan** — "we have backups" is not DR; can you actually restore + cut over within RTO? Auditor will ask for evidence of last test.
- **Post-mortems that don't drive change** — SEV1 happens, post-mortem written, action items never closed. Auditor reviews action-item closure.
- **Auditor-driven security** — controls only operate the week before the auditor visits. Type 2 catches this; auditors sample throughout the period.
- **Trust-center page that lies** — "we encrypt all data at rest" but the analytics DB is unencrypted. Auditor finds it; customer finds it eventually.
- **Drift between policy + practice** — policy says quarterly access review; in practice it happens annually. Both are findings (control not operating + control not designed).
- **Compliance team siloed from engineering** — controls written without engineer input, then engineers can't (or don't) follow them. Bring engineering in early.

## Required integrations

- **Compliance automation platform**: Vanta / Drata / Secureframe / Tugboat / Thoropass — collects evidence continuously, dramatically cheaper than manual audit prep. Almost mandatory for cost-effective SOC2.
- **SIEM**: Datadog / Splunk / Sumo Logic / open-source ELK with proper retention.
- **SSO + IDP**: Okta / Auth0 / Azure AD / Google Workspace.
- **Ticketing**: Jira / Linear / GitHub Issues with audit trail enforced.
- **MDM** (Mobile Device Management): Kandji / Jamf / Intune for employee laptops.
- **Endpoint protection**: CrowdStrike / SentinelOne / Defender / Sophos.
- **Status page**: Statuspage / Better Stack / Instatus — required if Availability TSC.
- **Background check provider**: Checkr / HireRight / GoodHire.
- **Secret manager**: Vault / AWS Secrets Manager / Doppler / 1Password Secrets Automation.

## Cross-references

- Pair with **`gdpr.md`** if Privacy TSC in scope and serving EU customers.
- Pair with **`pci-dss.md`** if processing payments.
- Pair with **`iso-27001.md` (planned — not yet shipped)** for organizations that want both — significant control overlap reduces double-work; ISO 27001 is more popular internationally, SOC2 in North America.
- AICPA: aicpa.org for current Trust Service Criteria.
- SOC2 reports are CONFIDENTIAL — never share publicly; share via NDA-gated portal.
- Common buyer expectation: **Type 2 with 6+ month period, Security + Availability + Confidentiality, less than 1 year old.**
