# PCI-DSS overlay (Payment Card Industry Data Security Standard)

> Appended to `ai/business-compliance.md` by `/setup-project` Phase 4.4b.1 when PCI-DSS is declared in Phase 2.y `Constraints` facet. Current version: PCI-DSS v4.0 (released 2022-03-31; v3.2.1 retired 2024-03-31; new v4.0-only requirements in full enforcement 2025-03-31).

## Scope

PCI-DSS applies to **any system that stores, processes, or transmits cardholder data (CHD) or sensitive authentication data (SAD)**. Even if you "just pass it through to Stripe," your network is in scope if card data transits it. The single biggest design decision is: **how do we stay out of PCI scope as much as possible?** Answer: tokenization at the edge.

**Cardholder data (CHD)**:
- Primary Account Number (PAN) — the 13-19 digit card number.
- Cardholder name.
- Expiration date.
- Service code.

**Sensitive Authentication Data (SAD)** — never stored after authorization, even encrypted:
- Full track data (magstripe / chip equivalent).
- CAV2 / CVC2 / CVV2 / CID (back-of-card 3-4 digit code).
- PIN / PIN block.

## Compliance levels (determines audit depth)

| Level | Volume | Validation |
|---|---|---|
| 1 | >6M total card txns/year | Annual on-site audit by Qualified Security Assessor (QSA) → Report on Compliance (ROC) |
| 2 | 1M–6M total txns/year | Annual SAQ + quarterly ASV scans |
| 3 | 20K–1M e-commerce txns/year | Annual SAQ + quarterly ASV scans |
| 4 | <20K e-commerce or <1M total | Annual SAQ |

**Tokenization (Stripe Elements / Adyen / Braintree / Worldpay) typically reduces scope from SAQ-D (>300 controls) to SAQ-A or SAQ-A-EP (<30 controls).** Strongly preferred for all new builds.

## Storage rules (the hard ones — most-failed audit areas)

- **NEVER store SAD after authorization.** Even encrypted. Even "for refunds." Even "the customer asked us to." This is the #1 audit failure.
- **PAN at rest must be unreadable**: strong cryptography (AES-256 typical), tokenization, truncation (max 6+4), or one-way hash with salt. Pick one; document it.
- **PAN displayed must be masked**: maximum 6 leading + 4 trailing digits visible (`424242******4242`). NEVER display full PAN in UI, CRM, support tools, logs, screenshots, emails, or chat transcripts.
- **Encryption keys**: split-knowledge + dual-control for manual operations; documented rotation policy; HSM strongly preferred (and required at higher transaction volumes).
- **Truncation + lookup table = storing PAN**. If you can recover the full PAN by joining tables, that's storage. Either truncate properly (irreversibly) or tokenize.

## Data handling

- **TLS 1.2+ required** for transmission of CHD over open networks. **TLS 1.0 / 1.1 forbidden** in v4.0.
- **Network segmentation**: cardholder data environment (CDE) isolated from corporate network + dev/staging via firewalls + ACLs. Flat network = entire network is in scope (massive audit cost increase).
- **Dev / staging MUST NOT use prod card data.** Use synthetic test cards (Stripe / Visa / Mastercard publish test ranges). Snapshotting prod DB into staging without scrubbing PAN is an automatic finding.
- **Data flow diagrams** mandatory and current — show every system CHD touches.

## Access control

- **Need-to-know + least privilege.** Document roles + access matrix; review quarterly.
- **MFA for all admin access to CDE.** v4.0 broadened this: MFA required for ALL access into CDE (not just admin), including from internal trusted networks.
- **Unique IDs** — no shared accounts. No `root` over SSH for daily operations. Service accounts are per-service, not per-team.
- **Quarterly access reviews** — confirm each user still needs their access; revoke if not.
- **Strong passwords**: 12+ characters (v4.0; was 7 in v3.2.1), or risk-based authentication (e.g., FIDO2).
- **Idle session timeout**: 15 min for admin/CDE sessions.
- **Lockout after failed attempts**: 10 attempts max, 30 min lockout.

## Logging + monitoring

- **Audit log everything CHD-touching**: access events, modifications, admin actions, failed access attempts, system clock changes, audit-log access (logs of log access).
- **Daily review** of security events — automated SIEM alerting acceptable for first-pass; human review of significant alerts required.
- **1 year minimum log retention**, with **3 months online** (immediately accessible).
- **File Integrity Monitoring (FIM)** on critical files in CDE — detect unauthorized changes.
- **Time synchronization** (NTP from authoritative source) across all systems in scope.
- **Log integrity** — tamper-evident storage (append-only, cryptographic hashing, immutable storage class).

## Vulnerability management

- **Quarterly external ASV scans** by Approved Scanning Vendor (Qualys / Trustwave / Tenable.io with PCI module). Pass = no high/critical findings; failed scans need remediation + rescan within timeframe.
- **Quarterly internal scans** (can be self-run with proper tools — Nessus / OpenVAS / etc.).
- **Ad-hoc scans after significant changes** to network or in-scope systems.
- **Annual penetration test** — network + application, internal + external. Includes segmentation testing if you rely on network segmentation to scope-reduce.
- **Patch within 30 days** of release for critical/high vulnerabilities; sooner is better.

## Incident response

- **Documented IRP tested annually** (full simulation, not just doc review).
- **24/7 monitoring + paging** for security events affecting CDE.
- **Forensic capability** — preserve evidence; some PCI investigations require PCI Forensic Investigator (PFI) within 24-72 hrs of suspected compromise.
- **Card brand notification** + acquirer notification per acquirer's contract terms (typically immediate).
- **Common Point of Purchase (CPP) process** — when fraud is reported, ability to investigate root cause.

## Required integrations

- **Tokenization provider** (Stripe Elements / Adyen / Braintree / Worldpay / Spreedly) — DRAMATICALLY reduces scope. Use **client-side** integration (Stripe.js, Elements, Drop-in) so card data goes browser → tokenizer directly, never touching your server.
- **WAF** (Web Application Firewall) — required for public-facing apps in CDE (or annual code review of CDE-facing apps as compensating control).
- **HSM** for encryption key management at scale (or cloud KMS — AWS KMS, Azure Key Vault, GCP KMS, with proper config).
- **ASV scanner** for quarterly external scans.
- **SIEM** for log aggregation + correlation + alerting (Splunk / Datadog / Sumo Logic / Elastic).
- **FIM** — Tripwire / OSSEC / AIDE / cloud-native (AWS Config + GuardDuty).
- **Anti-malware** on systems "commonly affected" (mostly Windows in CDE; Linux too in v4.0).
- **Vulnerability scanner** (Nessus / Qualys / Rapid7).

## Anti-patterns (pass generic compliance, fail PCI)

- **"We just pass it to Stripe so we're not in scope"** — false if card data transits your servers / network. Use Stripe.js / Elements / hosted fields client-side to truly stay out of scope. Server-side card-data acceptance = SAQ-D = full scope.
- **Logging full PAN in app logs** — single biggest scope-explosion source. One log line = your log infrastructure is in CDE. Sanitize at the logger; pen-test for leaks.
- **Screenshots in support tickets** containing card data — common in fintech, hard to police, often a finding. Train support; mask in UI so screenshots can't capture full PAN.
- **Dev / staging mirroring prod data** — if prod has CHD and staging has the same DB, staging is in scope. Always scrub on snapshot.
- **Storing CVV "for recurring billing"** — explicitly forbidden. Use tokenization (Stripe Customers + saved-card tokens, etc.).
- **Truncated PAN + reversible mapping table** — counts as storing PAN. Either truncate properly OR tokenize.
- **Email containing CHD** — never. Even support tickets. Even one-time exception.
- **TLS 1.0 / 1.1 anywhere on public-facing CDE** — explicit v4.0 fail.
- **Compliant once, then drift** — PCI is continuous; quarterly scans + annual SAQ are checkpoints, not the finish line. Configuration drift between audits = finding.
- **Service-account passwords in code repos** — use a secret manager (Vault / AWS Secrets Manager / Doppler).

## Cross-references

- Pair with **`gdpr.md`** if processing EU customer payments (GDPR governs the customer; PCI governs the card data).
- Pair with **`soc2.md`** if doing B2B SaaS payments (auditors expect both; significant control overlap).
- Pair with **`hipaa.md`** if taking copays / patient balances — the card and the chart are governed by separate regimes with separate scoping rules; tokenize the card, de-identify the chart.
- Pair with **`iso-27001.md` (planned — not yet shipped)** for formal infosec governance.
- PCI Council: pcisecuritystandards.org for current requirements + SAQs + ASV list + QSA list.
- Always check with your **acquiring bank** and **card brands** (Visa CISP, Mastercard SDP, Amex DSOP, Discover DISC) for brand-specific rules in addition to PCI-DSS itself.
