---
name: compliance
description: Cross-cutting regulatory rules — which regime binds this surface, and whether the obligation is met at the call site
kind: rule
concern: C7
---

# Compliance

## Hard rule

Where a regime applies, the obligation MUST be met **at the call site**, not in a policy document.
A codebase is compliant when the code enforces the rule, not when a README claims it. Every
surface that touches regulated data MUST name which regime binds it and where the enforcement
lives; a surface that cannot name either has a finding even if nothing has gone wrong.

Distinct from **C11 Data Lifecycle**, which asks the mechanical question *does deletion code
exist and run*. Compliance asks the prior one: *which rule applies here at all*. A retention job
that deletes after 90 days is a lifecycle answer; whether 90 days is legal for this data in this
jurisdiction is a compliance answer.

## Per-surface fingerprints

| Surface | Regime that typically binds | Typical finding |
|---|---|---|
| `auth` | GDPR/CCPA (identity), SOC2 (access) | no lawful-basis record for profile fields collected at signup; MFA reset path bypasses the audited flow |
| `file-upload` | GDPR (content), sector rules (HIPAA/PCI if the file carries them) | uploads accepted with no classification, so regulated content enters an unregulated store |
| `ledger` | tax / accounting retention, SOX-style immutability | entries mutated rather than reversed; no jurisdiction-aware retention on financial records |
| `media-processing` | GDPR (biometrics if faces), copyright | EXIF GPS retained in derivatives; no consent record for face-detection features |
| `multi-tenant` | data residency | tenants in different jurisdictions share one region; no per-tenant residency pin |
| `real-time` | wiretap / recording consent, GDPR | sessions recorded or transcribed with no consent gate; presence data retained as behavioural profile |
| `scheduling` | labour law, healthcare booking rules | appointment data carrying health context stored with no regime tag |
| `settings` | GDPR (consent as a setting) | consent toggles stored without timestamp + version of the notice consented to — an unprovable consent |
| `streaming-delivery` | licensing / geo-restriction, DRM obligations | entitlement checked at manifest but not at segment; no geo-enforcement despite a licence that requires it |
| `webhook` | contractual data-sharing terms | outbound payloads carry more fields than the data-sharing agreement permits |

**N/A with reason**

| Surface | Reason |
|---|---|
| `i18n` | catalogs carry no personal or regulated data; a locale is a preference |
| `caching` | inherits the regime of what it caches — reviewing it here double-counts the origin surface |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where the obligation lands** | the handler that writes the regulated field | the consent gate before the first network call | OS permission prompt + the SDK that fires before it | the prompt before first telemetry send |
| **The classic miss** | policy documented, no enforcing code | analytics fire before the consent banner resolves | SDK initialised in `Application.onCreate`, before any consent | telemetry on by default with an opt-out nobody reads |

## Closure verbs

`tag-regime` · `gate-on-consent` · `record-lawful-basis` · `pin-residency` · `version-the-notice` ·
`enforce-at-call-site`

A fix that adds a paragraph to a policy file and no code is not a closure.
