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
| ● `confirmed` | both signals agree — material is shipped **and** described for this pair | 220 / 468 (47%) |
| ○ `proposed` | one signal only — **a review queue, not coverage**. A human must read it. | 242 / 468 (51%) |
| · `empty` | neither signal. No evidence of any material. **This is the deliverable.** | 0 / 468 (0%) |
| – `n/a` | a `templates/concerns/` rule names this surface as having no meaningful fingerprint, **with a reason** | 6 / 468 (1%) |

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
ab-testing              ○   ●   ○   ○   ●   ○   ○   ●   ●   ○   ●   ○
admin                   ○   ●   ●   ○   ●   ●   ○   ●   ●   ●   ○   ○
ai                      ●   ●   ○   ○   ○   ○   ○   ○   ●   ○   ●   ○
analytics               ○   ○   ○   ○   ●   ●   ●   ●   ●   ○   ●   ○
audit-log               ●   ○   ○   ●   ●   ●   ○   ○   ●   ○   ○   ○
auth                    ●   ●   ○   ○   ○   ○   ●   ●   ○   ○   ○   ○
background-jobs         ○   ○   ○   ●   ○   ○   ○   ●   ●   ○   ○   ○
caching                 ○   ●   ○   ●   ○   ○   –   ○   ●   ○   –   ●
compliance              ○   ●   ○   ●   ●   ○   ●   ●   ○   ○   ○   ○
data-pipeline           ●   ○   ○   ●   ○   ○   ○   ●   ●   ●   ●   ●
document-generation     ●   ○   ●   ○   ○   ○   ●   ○   ○   ○   ○   ○
event-sourced           ●   ○   ○   ○   ○   ●   ○   ●   ○   ○   ○   ●
feature-flags           ○   ●   ○   ○   ○   ○   ○   ○   ○   ●   ●   ○
file-upload             ●   ●   ○   ○   ●   ●   ●   ●   ●   ○   ○   ○
forms                   ●   ○   ○   ○   ○   ●   ○   ○   ●   ●   ●   ○
i18n                    ○   ●   ●   ○   ○   ●   –   –   ●   ○   ●   ●
import                  ●   ●   ●   ●   ○   ●   ○   ○   ●   ●   ○   ●
integrations            ●   ●   ○   ●   ○   ●   ○   ○   ●   ○   ○   ●
ledger                  ●   ●   ○   ●   ●   ●   ●   ○   ●   ○   ●   ○
media-processing        ●   ○   ○   ○   ●   ○   ●   ○   ○   ○   ●   ○
moderation              ●   ●   ○   ○   ●   ●   ●   ○   ○   ○   ○   ●
multi-tenant            ○   ●   ●   ●   ●   ●   ●   ●   ●   ○   ●   ●
notifications           ○   ●   ○   ○   ●   ○   ○   ●   ○   ○   ●   ○
payment                 ●   ●   ○   ○   ○   ●   ●   ○   ●   ○   ○   ●
public-api              ●   ○   ○   ○   ○   ●   ○   ●   ●   ●   ●   ○
rate-limiting           ○   ○   ○   ○   ●   ○   ○   ○   ○   ○   –   –
real-time               ●   ○   ○   ○   ○   ○   ●   ○   ○   ●   ○   ○
reporting               ○   ●   ○   ○   ○   ●   ●   ○   ○   ○   ○   ●
scheduling              ●   ●   ●   ○   ●   ●   ●   ○   ●   ○   ●   ●
search                  ○   ○   ○   ○   ●   ○   ○   ○   ○   ○   ●   ○
settings                ●   ●   ●   ●   ●   ●   ●   ○   ●   ●   ○   ○
streaming-delivery      ●   ●   ●   ●   ○   ○   ●   ●   ●   ●   ○   ●
subscriptions           ○   ●   ○   ○   ○   ●   ○   ●   ○   ○   ●   ●
webhook                 ●   ●   ○   ○   ○   ○   ●   ○   ●   ●   ●   ○
workflow                ○   ○   ○   ●   ●   ●   ○   ●   ●   ○   ○   ●
_database               ○   ●   ○   ○   ○   ●   ●   ○   ●   ●   ●   ●
_deployment             ●   ○   ●   ○   ○   ○   ●   ○   ○   ○   ●   ○
_routes                 ○   ●   ●   ●   ●   ○   ○   ●   ○   ●   ●   ●
_screens                ●   ●   ●   ●   ○   ●   ●   ●   ●   ●   ●   ●
---------------------------------------------------------------------
legend                  ● confirmed   ○ proposed (needs a read)   · empty   – n/a (reasoned)
```

---

## 3. The empty column — cells with no evidence at all

**0 of 468 cells — but read what that does and does not mean.**

It means every (concern, surface) pair now has **named material**: all 12 concerns have
a rule in [`concerns/`](concerns/), and each names the surfaces it covers with a
concrete fingerprint. The column that opened at 117 is closed.

**It does not mean the review is complete.** Three things are still true:

1. A fingerprint is a **detector spec, not a running detector**. It says what to look
   for; only a dispatched agent finds anything. Phase 2 dispatches these — no run has
   yet confirmed a single one earns its place.
2. **242 cells are still `proposed`** — one text signal, never read by a
   human. That is the standing review queue and it did not shrink; closing the empty
   column did not touch it.
3. The 4 structural surfaces (§4) are still unpopulated, so the true grid is 468 cells,
   not 468. A gap that is out of scope is still a gap.

> Zero empty is the point at which the matrix stops finding gaps *by absence* and starts
> having to find them *by running*. That is a harder question, and it is the next one.

### The `proposed` queue — what actually remains

**242 cells.** One signal fired, no human has read them. Closing the empty
column did not touch this queue — the two are independent, and this is now the larger
number. Ranked by concern severity × queue length, so a reader can start where a single
session buys the most:

| Concern | Queued | Severity | Read first |
|---|---|---|---|
| **C8  Authorization** | 21 | 5 | `_database`, `_deployment`, `ai`, `audit-log` +17 |
| **C12 Tenancy** | 21 | 5 | `_deployment`, `ab-testing`, `admin`, `ai` +17 |
| **C1  Security** | 17 | 5 | `_database`, `_routes`, `ab-testing`, `admin` +13 |
| **C10 Versioning** | 26 | 3 | `_deployment`, `ab-testing`, `ai`, `analytics` +22 |
| **C4  Error Handling** | 25 | 3 | `_database`, `_deployment`, `ab-testing`, `admin` +21 |
| **C7  Compliance** | 18 | 4 | `_routes`, `ab-testing`, `admin`, `ai` +14 |
| **C11 Data Lifecycle** | 17 | 4 | `admin`, `audit-log`, `auth`, `background-jobs` +13 |
| **C5  Logging** | 22 | 3 | `_database`, `_deployment`, `_screens`, `ai` +18 |
| **C9  Idempotency** | 15 | 4 | `_deployment`, `_routes`, `auth`, `compliance` +11 |
| **C3  Observability** | 28 | 2 | `_database`, `ab-testing`, `ai`, `analytics` +24 |
| **C6  Configuration** | 18 | 2 | `_deployment`, `_routes`, `ab-testing`, `ai` +14 |
| **C2  Performance** | 14 | 2 | `_deployment`, `analytics`, `audit-log`, `background-jobs` +10 |

> Resolving one is a read, not a rewrite: open the surface's material, decide whether it
> genuinely addresses the concern, and either add the surface to the concern rule's
> fingerprint table (→ `confirmed`) or record it as N/A **with a reason**. Both outcomes
> are progress; only leaving it `proposed` is not.

---

## 4. Structural surfaces — populated from packs

The 4 structural surfaces have no `templates/domains/` folder, so the domain signals cannot
see them. Their material lives in packs, mapped by the **Material lives in** column of
[`_review-model.md`](_review-model.md) §2.2 — read from there, not hardcoded here, so the
mapping is reviewed in the file that owns the vocabulary.

The evidence method is **the same two signals**, not a third one: `description:`
frontmatter is the curated signal (every pack artifact carries one), the artifact body is
the full-text signal. Same thresholds, same three states.

| Structural surface | Packs read | Artifacts | Concerns backed by ≥2 |
|---|---|---|---|
| `_database` | `database`, `migration` | 15 | 6 / 12 |
| `_deployment` | `infrastructure`, `devops` | 18 | 4 / 12 |
| `_routes` | `backend` | 17 | 8 / 12 |
| `_screens` | `frontend`, `mobile`, `ui-ux` | 46 | 11 / 12 |

**Evidence strength is not symmetric with the domain half, and the grid does not pretend
otherwise.** A domain surface is backed by 2 files; a structural one by 8 to 46. So the
structural signal is measured **per artifact, never over a concatenated blob** — the first
attempt joined each pack's files into one string and scored `_routes` 12/12 confirmed,
because among 17 backend artifacts *some* description matches every concern. `confirmed`
here means **≥ 2 artifacts are individually about that concern**; one lone artifact out of
46 is `proposed`, not coverage.

> **Cross-cutting packs are deliberately excluded** — `security`, `performance`,
> `observability`, `testing`, `code-quality`, `finops` and the rest are axis-major and apply
> to every surface. Listing them under each structural surface would mark every cell
> confirmed by construction, which is the same over-counting that made the first full-text
> pass score 312/420. They are dispatched in wave B as global axes instead.

## 5. Artifacts behind the grid

166 artifacts across 39 surfaces — domain files for the 35 signal surfaces,
pack files (written `pack:name`) for the 4 structural ones. Every path is asserted to exist by
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
_database             database:database-optimizer, database:query-optimizer, database:schema-architect, database:schema-reviewer, database:database-principles, database:migration-rehearsal, database:schema-consistency-audit, database:schema-diff, migration:migration-architect, migration:parity-auditor, migration:migration-discipline, migration:data-cutover-orchestrate, migration:extract-v1-contract, migration:parity-test-generate, migration:perf-uplift-survey
_deployment           infrastructure:infra-architect, infrastructure:k8s-reviewer, infrastructure:kubernetes-architect, infrastructure:infra-principles, infrastructure:admission-policy, infrastructure:dr-audit, infrastructure:k8s-audit, infrastructure:network-exposure-audit, infrastructure:tf-plan-review, devops:ci-reviewer, devops:deployment-engineer, devops:devops-architect, devops:devops-principles, devops:dockerfile-lint, devops:gitops-audit, devops:monitor-deploy, devops:progressive-delivery, devops:release-security
_routes               backend:api-architect, backend:api-reviewer, backend:bug-investigator, backend:endpoint-tester, backend:websocket-engineer, backend:backend-principles, backend:concurrency-discipline, backend:migration-backend, backend:api-consistency-audit, backend:api-snapshot, backend:debug-tenant, backend:endpoint-test, backend:env-diff, backend:log-tail, backend:migration-safety, backend:module-scaffold, backend:parallelize-independent-ops
_screens              frontend:accessibility-auditor, frontend:api-contract-sentry, frontend:data-flow-auditor, frontend:i18n-auditor, frontend:technical-seo, frontend:ui-architect, frontend:ui-reviewer, frontend:frontend-principles, frontend:i18n, frontend:migration-frontend, frontend:a11y-scan, frontend:bundle-analyze, frontend:component-playground, frontend:dev-server-start, frontend:font-optimization, frontend:image-optimization, frontend:lcp-audit, frontend:lighthouse-ci, frontend:navigation-speed, frontend:seo-audit, frontend:ssr-audit, frontend:streaming-ssr, frontend:verify-with-playwright, frontend:visual-check, mobile:app-store-reviewer, mobile:device-performance-auditor, mobile:mobile-architect, mobile:offline-sync-auditor, mobile:mobile-principles, mobile:render-discipline, mobile:bundle-analyze, mobile:device-harness, mobile:native-bridge-audit, mobile:platform-conventions-audit, ui-ux:creative-director, ui-ux:design-system-architect, ui-ux:design-system-guardian, ui-ux:theme-specialist, ui-ux:ux-reviewer, ui-ux:ui-principles, ui-ux:a11y-quick-check, ui-ux:chart-encoding-audit, ui-ux:design-iterate, ui-ux:design-token-audit, ui-ux:motion-audit, ui-ux:ui-design-sweep
```
