# Business-domain registry

Single source of truth for the business domains supported by `/setup-project`. Phase 2.4 (business-domain detection), Phase 4.4b (regulatory overlay generation), and the Glossary all consult this file rather than hard-coded lists.

## What a business domain is

A **business domain** describes WHAT the product is (ecommerce, lms, fintech) — not HOW it's built. It maps the project to a body of domain knowledge so generated content is domain-aware (entities, flows, compliance regime, anti-patterns) instead of generic backend scaffolding.

Each domain folder under `~/.claude/templates/business-domains/<name>/` ships:

- `glossary.md` — domain vocabulary
- `core-flows.md` — happy paths + edge cases
- `feature-checklist.md` — common features for the domain
- `compliance.md` — regulatory regime hints (drives Phase 4.4b overlay selection)
- `stakeholders.md` — internal + external personas
- `anti-patterns.md` — known failure modes
- `factories.md` — test factories (B17 contract; required)
- `_version.json` — version stamp consumed by Phase 4.0 preflight + Phase 5.6 drift report

## Registry

| Key | Summary | Regulatory overlay hints |
|---|---|---|
| `affiliate` | Referral / partner / commission tracking platforms | GDPR, CCPA |
| `booking` | Appointment / scheduling / reservation systems | GDPR, CCPA, regional health/wellness rules |
| `content` | Publishing, CMS, media libraries, blogging | GDPR, CCPA, copyright/DMCA, COPPA (if minors) |
| `ecommerce` | Online stores, carts, checkout, fulfillment | PCI-DSS, GDPR, CCPA, regional consumer protection |
| `fintech` | Banking, lending, payments, wallets | PCI-DSS, KYC/AML, SOC2, regional (SAMA, MAS, FCA, etc.) |
| `healthcare` | Patient records, clinical systems, telehealth | HIPAA, GDPR, NPHIES, SCFHS, MOH-SA, CBAHI, regional |
| `insurance` | Policy management, claims, underwriting | NAIC, GDPR, regional (CCHI, SAMA, etc.) |
| `lms` | Learning management, courses, assessments | FERPA, COPPA, GDPR |
| `logistics` | Shipping, fleet, last-mile, warehousing | GDPR, regional transport regulations |
| `marketplace` | Multi-sided platforms (buyers + sellers) | PCI-DSS (if payments), GDPR, CCPA, ZATCA (KSA e-invoicing) |
| `on-demand` | Ride-hail, delivery, gig-work | GDPR, CCPA, labor classification, regional |
| `real-estate` | Listings, transactions, property management | GDPR, fair housing, regional title regulations |
| `restaurant-pos` | Restaurant POS, online ordering, KDS | PCI-DSS, food-safety, regional |
| `saas-b2b` | Multi-tenant SaaS for businesses | SOC2, ISO-27001, GDPR, CCPA, HIPAA (vertical) |
| `social` | Social networks, communities, UGC | GDPR, CCPA, COPPA, DSA, content moderation |

## Maintenance

- **Adding a domain**: create `~/.claude/templates/business-domains/<key>/` with the 7 required files + `_version.json`, then add a row above. Phase 4.0 preflight enforces presence.
- **Removing a domain**: bump `deprecated: true` in `_version.json` and add a `Status: deprecated` note in the row. Don't delete the folder — Phase 0.2 extract still needs to read it from older `~/.claude/` installs.
- **Renaming**: never rename in place. Add the new key + leave the old one with `deprecated: true` pointing at the replacement in its `_version.json` (`replaced_by: <new-key>`).

## Drift detection

`scripts/lint-tool-parity.sh` (and the planned `scripts/lint-registry-drift.sh`) cross-check this file against the actual `~/.claude/templates/business-domains/*/` folder list. Any folder without a row, or any row without a folder, is reported as drift.
