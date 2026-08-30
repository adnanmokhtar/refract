# `_review-matrix.md` — the dispatch index

> **GENERATED — do not hand-edit.** Regenerate with `scripts/gen-review-matrix.py`;
> `scripts/validate-review-matrix.sh` fails the build if this file is stale or if any
> artifact it names has left disk. Phase 1 of
> [`docs/plans/audit-review-matrix.md`](../docs/plans/audit-review-matrix.md).
> Vocabulary comes from [`_review-model.md`](_review-model.md) — surfaces §2, concerns §3.

---

## 1. What a cell state means

Two independent signals per cell. **Neither is trustworthy alone**, which is why both run:

| Signal | Source | Precision | Recall |
|---|---|---|---|
| `curated` | the domain's row in `_registry.md` **What it ships** | high | **low** — alone it scored Observability 0/35 while 32 of 35 domain rule files discuss metrics/traces/alerts |
| `fulltext` | the domain's `rules/` + `agents/` bodies, ≥ 3 matches | **low** | high — alone it scored 312/420 filled, noise (an early `log` pattern also matched `login`, `logic`) |

| State | Meaning | Count |
|---|---|---|
| ● `confirmed` | both signals agree — material is shipped **and** described for this pair | 95 / 420 (22%) |
| ○ `proposed` | one signal only — **a review queue, not coverage**. A human must read it. | 227 / 420 (54%) |
| · `empty` | neither signal. No evidence of any material. **This is the deliverable.** | 95 / 420 (22%) |
| – `n/a` | a `templates/concerns/` rule names this surface as having no meaningful fingerprint, **with a reason** | 3 / 420 (0%) |

> A `confirmed` cell means *material exists*, *not* that the material is good or that a
> detector runs. Phase 2 dispatches it; only a run can say whether it finds anything.

### Calibration

The plan names three cells as ground truth. All three reproduce, which is why this method
is trusted as far as it is trusted:

| Cell | Plan says | Generated |
|---|---|---|
| `C1` × `file-upload` | filled — av-scan, allowlist | `confirmed` |
| `C9` × `public-api` | filled — idempotent-POST | `confirmed` |
| `C8` × `background-jobs` | **empty — a real gap** | `confirmed` |

---

## 2. The grid — 35 signal surfaces × 12 concerns

```
surface                C1  C2  C3  C4  C5  C6  C7  C8  C9 C10 C11 C12
---------------------------------------------------------------------
ab-testing              ○   ·   ○   ○   ●   ○   ○   ●   ●   ○   ●   ○
admin                   ○   ·   ·   ○   ●   ·   ○   ●   ·   ·   ○   ○
ai                      ●   ·   ○   ○   ○   ○   ○   ○   ·   ○   ●   ○
analytics               ○   ○   ○   ○   ●   ·   ●   ●   ●   ○   ●   ○
audit-log               ●   ○   ○   ·   ●   ·   ○   ○   ·   ○   ○   ○
auth                    ●   ·   ○   ○   ○   ○   ·   ●   ○   ○   ○   ○
background-jobs         ○   ○   ○   ●   ○   ○   ○   ●   ●   ○   ○   ○
caching                 ○   ●   ○   ●   ○   ○   ○   ○   ·   ○   –   ●
compliance              ○   ·   ○   ·   ●   ○   ●   ●   ○   ○   ○   ○
data-pipeline           ·   ○   ○   ●   ○   ○   ○   ●   ●   ●   ●   ●
document-generation     ●   ○   ·   ○   ○   ○   ●   ○   ○   ○   ○   ○
event-sourced           ·   ○   ○   ○   ○   ·   ○   ●   ○   ○   ○   ·
feature-flags           ○   ·   ○   ○   ○   ○   ○   ○   ○   ·   ●   ○
file-upload             ●   ·   ○   ○   ·   ·   ·   ●   ·   ○   ○   ○
forms                   ●   ○   ○   ○   ○   ·   ○   ○   ●   ·   ●   ○
i18n                    ○   ·   ·   ○   ○   ·   ○   –   ·   ○   ●   ·
import                  ●   ●   ·   ●   ○   ·   ○   ○   ●   ·   ○   ●
integrations            ●   ●   ○   ●   ○   ·   ○   ○   ●   ○   ○   ●
ledger                  ·   ·   ○   ●   ●   ·   ·   ○   ●   ○   ●   ○
media-processing        ●   ○   ○   ○   ·   ○   ·   ○   ○   ○   ●   ○
moderation              ●   ·   ○   ○   ●   ·   ●   ○   ○   ○   ○   ·
multi-tenant            ○   ·   ·   ·   ·   ·   ·   ●   ·   ○   ●   ●
notifications           ○   ·   ○   ○   ·   ○   ○   ●   ○   ○   ●   ○
payment                 ●   ·   ○   ○   ○   ·   ●   ○   ●   ○   ○   ·
public-api              ●   ○   ○   ○   ○   ·   ○   ●   ●   ●   ●   ○
rate-limiting           ○   ○   ○   ○   ·   ○   ○   ○   ○   ○   –   ○
real-time               ·   ○   ○   ○   ○   ○   ·   ○   ○   ·   ○   ○
reporting               ○   ●   ○   ○   ○   ·   ●   ○   ○   ○   ○   ●
scheduling              ·   ·   ·   ○   ·   ·   ·   ○   ●   ○   ●   ·
search                  ○   ○   ○   ○   ·   ○   ○   ○   ○   ○   ●   ○
settings                ●   ·   ·   ·   ●   ●   ·   ○   ·   ·   ○   ○
streaming-delivery      ●   ●   ·   ·   ○   ○   ·   ●   ·   ·   ○   ·
subscriptions           ○   ·   ○   ○   ○   ·   ○   ●   ○   ○   ●   ·
webhook                 ●   ·   ○   ○   ○   ○   ·   ○   ●   ·   ●   ○
workflow                ○   ○   ○   ●   ●   ·   ○   ●   ●   ○   ○   ·
---------------------------------------------------------------------
legend                  ● confirmed   ○ proposed (needs a read)   · empty   – n/a (reasoned)
```

---

## 3. The empty column — cells with no evidence at all

**95 of 420 cells.** Neither signal found anything. These are the pairs
nobody is looking at; Phase 3 renders them as *live, unreviewed* and Phase 4 sizes the work.

| Concern | Surfaces with no material | n |
|---|---|---|
| **C1  Security** | `data-pipeline`, `event-sourced`, `ledger`, `real-time`, `scheduling` | 5 |
| **C2  Performance** | `ab-testing`, `admin`, `ai`, `auth`, `compliance`, `feature-flags`, `file-upload`, `i18n`, `ledger`, `moderation`, `multi-tenant`, `notifications`, `payment`, `scheduling`, `settings`, `subscriptions`, `webhook` | 17 |
| **C3  Observability** | `admin`, `document-generation`, `i18n`, `import`, `multi-tenant`, `scheduling`, `settings`, `streaming-delivery` | 8 |
| **C4  Error Handling** | `audit-log`, `compliance`, `multi-tenant`, `settings`, `streaming-delivery` | 5 |
| **C5  Logging** | `file-upload`, `media-processing`, `multi-tenant`, `notifications`, `rate-limiting`, `scheduling`, `search` | 7 |
| **C6  Configuration** | `admin`, `analytics`, `audit-log`, `event-sourced`, `file-upload`, `forms`, `i18n`, `import`, `integrations`, `ledger`, `moderation`, `multi-tenant`, `payment`, `public-api`, `reporting`, `scheduling`, `subscriptions`, `workflow` | 18 |
| **C7  Compliance** | `auth`, `file-upload`, `ledger`, `media-processing`, `multi-tenant`, `real-time`, `scheduling`, `settings`, `streaming-delivery`, `webhook` | 10 |
| **C9  Idempotency** | `admin`, `ai`, `audit-log`, `caching`, `file-upload`, `i18n`, `multi-tenant`, `settings`, `streaming-delivery` | 9 |
| **C10 Versioning** | `admin`, `feature-flags`, `forms`, `import`, `real-time`, `settings`, `streaming-delivery`, `webhook` | 8 |
| **C12 Tenancy** | `event-sourced`, `i18n`, `moderation`, `payment`, `scheduling`, `streaming-delivery`, `subscriptions`, `workflow` | 8 |

### Widest gaps, by concern

- **C6  Configuration** — no material on 18 of 35 surfaces.
- **C2  Performance** — no material on 17 of 35 surfaces.
- **C7  Compliance** — no material on 10 of 35 surfaces.

---

## 4. Structural surfaces — NOT populated in this pass

`_database`, `_deployment`, `_routes`, `_screens` have no `templates/domains/` folder, so neither signal
can see them. Their material lives in packs (`database`, `infrastructure`, `backend`,
`frontend`, `mobile`). Mapping packs onto structural surfaces is a separate pass with a
different evidence source; it is **listed here as unpopulated rather than omitted**, so the
gap is visible rather than silent.

Full grid when they land: 39 surfaces × 12 concerns = 468 cells (currently 420).

---

## 5. Artifacts behind the grid

70 domain artifacts across 35 domains. Every path is asserted to exist by
`validate-review-matrix.sh`, in both directions — a renamed file breaks the build, and an
artifact in no cell is reported.

```
ab-testing            ab-testing-reviewer, ab-testing-discipline
admin                 admin-reviewer, admin-backoffice-discipline
ai                    prompt-reviewer, ai-cost-discipline
analytics             analytics-reviewer, analytics-tracking-discipline
audit-log             audit-log-reviewer, audit-log-discipline
auth                  auth-reviewer, auth-discipline
background-jobs       queue-reviewer, job-design
caching               caching-reviewer, caching-discipline
compliance            compliance-reviewer, data-retention
data-pipeline         data-pipeline-reviewer, data-pipeline-discipline
document-generation   document-generation-reviewer, document-generation-discipline
event-sourced         event-store-reviewer, event-sourcing-discipline
feature-flags         flag-reviewer, flag-discipline
file-upload           upload-reviewer, upload-safety
forms                 forms-reviewer, forms-discipline
i18n                  i18n-reviewer, i18n-localization-discipline
import                import-reviewer, import-ingest-discipline
integrations          integrations-reviewer, integrations-sync-discipline
ledger                ledger-reviewer, ledger-integrity-discipline
media-processing      media-processing-reviewer, media-processing-discipline
moderation            moderation-reviewer, moderation-discipline
multi-tenant          tenant-isolation-reviewer, multi-tenancy
notifications         notification-reviewer, notification-discipline
payment               payment-reviewer, payment-idempotency
public-api            public-api-reviewer, public-api-discipline
rate-limiting         rate-limit-reviewer, rate-limit-discipline
real-time             realtime-reviewer, realtime-discipline
reporting             reporting-reviewer, reporting-export-discipline
scheduling            scheduling-reviewer, scheduling-discipline
search                search-reviewer, search-discipline
settings              settings-reviewer, settings-config-discipline
streaming-delivery    streaming-delivery-reviewer, streaming-delivery-discipline
subscriptions         subscription-reviewer, subscription-billing-discipline
webhook               webhook-reviewer, webhook-signature-verification
workflow              workflow-reviewer, workflow-discipline
```
