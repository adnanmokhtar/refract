---
description: Comprehensive, signal-aware review of pending changes. Classifies the diff, dispatches every relevant specialist agent in parallel, consults all applicable patterns, produces a single consolidated verdict with GO/NO-GO.
---

# /review-changes

Use before opening a PR. Use before every commit if the habit fits. Never wave changes through.

## Phases applied

1, 2, 3, 6, 7. Phases 4 + 5 = N/A — review doesn't generate or persist changes; output is a verdict + list of fixes for the implementer.

## Invariants

- **Classify the diff first** — which areas changed? Wrong classification = wrong reviewers.
- **Universal reviewers ALWAYS**.
- **Specialist reviewers BASED on area touched**.
- **Domain reviewers BASED on project signals** (from `CLAUDE.md`).
- **Patterns consulted**, not just principles.
- **Single consolidated output** — blockers first, then requests, then nits.

## When to use / NOT to use

- USE: before opening a PR.
- USE: before every commit if the habit fits.
- USE: when you want a comprehensive sweep, not a single-area check.
- NOT: as a substitute for area-specific commands when scope is narrow (`/security-audit` for auth-only change).
- NOT: to gate trivial changes (formatting, dependency bump) — overhead exceeds value.

## Phase 1 — Understand (scope detection)

```bash
git status
git diff --stat                  # summary
git diff                         # full diff (staged + unstaged)
git log <base>..HEAD --oneline   # commits on this branch
```

Classify touched files into categories:

| File matches | Category |
|---|---|
| `src/**/*.ts` / `src/**/*.py` / `src/**/*.go` etc. | backend-code |
| `**/entities/` / `**/orm-entity*` / `prisma/schema.prisma` | db-entity |
| `**/migrations/**` | db-migration |
| `**/repositories/**` / `**/repo*` / raw SQL files | db-repo |
| Frontend `*.vue` / `*.tsx` / `*.svelte` / `*.component.ts` | ui |
| `locales/**` / `i18n/**` / `messages/**` | i18n |
| `**/auth/**` / JWT / crypto / session / password | auth |
| `Dockerfile` / `docker-compose` | docker |
| `k8s/**` / `*.yaml` with `kind:` | k8s |
| `.github/workflows/**` / `.gitlab-ci.yml` | ci |
| `terraform/**` / `*.tf` | iac |
| `openapi*.json` / `api-snapshots/**` | api-contract |
| `**/*.test.*` / `**/*.spec.*` / `test/**` | tests |
| `**/*prompt*` / `**/ai/**` / Claude/OpenAI client | ai-code |
| `**/webhook*` / `**/*-webhook/**` | webhook |
| `**/events/**` / `**/handlers/**` / queue consumers | events |
| `**/metrics*` / `**/logger*` / `**/tracer*` | telemetry |

One file can be in multiple categories.

State the success criteria: produce a single APPROVE / REQUEST_CHANGES / BLOCK verdict with prioritized findings.

## Phase 2 — Organize (plan reviewer dispatch)

Detect project-level signals (from CLAUDE.md):
- Multi-tenant?
- AI / LLM usage?
- Webhook-driven?
- Payment?
- Event-sourced?
- Multi-region / distributed?
- Compliance (GDPR / HIPAA / PCI)?

These drive signal-based reviewers regardless of what the diff touches.

Plan dispatch:
- Universal reviewers (always).
- Category-based reviewers (per touched file category).
- Signal-based reviewers (per project signal).
- Universal skill checks.

Read `ai/status.md` current phase. Plan the scope-creep check.

## Phase 3 — Retrieve (read context + patterns)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Plus:
- All `.claude/rules/` (auto-loaded, re-confirm).

CATEGORY-BASED (in parallel):
| Category | Pattern to read |
|---|---|
| backend-code | `api-contract.md`, `error-handling.md` |
| db-entity / db-repo / db-migration | `indexing-strategy.md`, `migrations.md` |
| db-migration | `zero-downtime-deploys.md` |
| ui | `rendering-strategy.md`, `design-systems.md` |
| i18n | `i18n.md`, `rtl.md` |
| auth | `auth-flow.md`, `zero-trust.md` |
| docker / k8s | `docker.md`, `kubernetes.md` refs |
| api-contract | `api-versioning.md` |
| tests | `test-strategy.md`, `test-doubles.md` |
| ai-code | `prompt-builder.md`, `ai-cost-tracking.md` |
| webhook | `webhook-flow.md` |
| events | `saga.md`, `outbox.md`, `idempotency.md` |
| telemetry | `structured-logging.md`, `metrics.md`, `tracing.md` |

## Phase 4 — N/A

Read-only review; no code generated. (Findings produced in Phase 6.)

## Phase 5 — N/A

Review doesn't persist findings to `ai/`. The implementer who acts on findings does that via `/learn-from-task` after fixes land.

## Phase 6 — Validate (dispatch reviewers + consolidate)

### Dispatch reviewers (parallel)

#### Universal (ALWAYS)
- `code-reviewer`

#### Category-based (based on diff categories)
| Category | Reviewers |
|---|---|
| backend-code | `api-reviewer` |
| db-entity / db-repo | `schema-reviewer`, `query-optimizer` |
| db-migration | `schema-reviewer` + invoke `/migration-review` |
| ui | `ui-reviewer`, `design-system-guardian`, `accessibility-auditor` (+ skill `a11y-scan` on changed routes if significant) |
| i18n | `i18n-auditor` |
| auth | `security-auditor`, `auth-reviewer` |
| docker | invoke `dockerfile-lint` skill |
| k8s | `k8s-reviewer` |
| ci | `ci-reviewer` |
| api-contract | invoke `api-snapshot` skill for breaking-change detection |
| tests | `test-reviewer` |
| ai-code | `prompt-reviewer` |
| webhook | `resilience-reviewer` (idempotency + signature check) |
| events | `resilience-reviewer` |
| telemetry | `observability-reviewer` |
| Hot-path / performance-sensitive changes | `performance-optimizer` + `n-plus-one-scan` skill |

#### Signal-based (based on project, always when signal present)
| Signal | Reviewer |
|---|---|
| Multi-tenant | `tenant-isolation-reviewer` (any DB-touching change) |
| AI | `prompt-reviewer` (if AI code touched) |
| Payment | payment-specific reviewer if available |

#### Universal skill checks
- `dead-branch-scan` (on changed files) — find unreachable code you just added.
- `doc-drift-scan` — does the change need doc updates? `ai/status.md`? `ai/modules.md`? `ai/conventions.md`?

### Pattern-specific invariant checks

Quick sweep per diff:

**Any new endpoint** (backend-code + HTTP handler):
- Auth guard present (not public unless explicit)?
- Input DTO validated?
- Pagination on list endpoints?
- Response shape consistent with project?

**Any new DB query** (db-repo + raw or query-builder):
- Parameterized (no string concat)?
- Tenant filter applied (if multi-tenant)?
- Soft-delete filter (if used)?
- Indexed columns?

**Any new external call** (HTTP client, DB, queue, SDK):
- Timeout explicit?
- Retry policy (if applicable)?
- Circuit breaker / bulkhead (if applicable)?
- Logged + metered?

**Any auth/permission change**:
- Tests cover unauthorized access?
- Token handling correct?

**Any new env var**:
- Added to `.env.example`?
- Added to env schema (Joi / Zod / Pydantic)?

### Phase discipline check

Read `ai/status.md` current phase. Is this change in-scope?

Scope creep = blocker or a discussion. "This is Phase 3 work but we're in Phase 1" → push back OR amend the roadmap in an ADR.

### Consolidate findings

Merge all reviewer outputs into one report, grouped by severity. GO / NO-GO verdict:
- Any **Blocker** → **REQUEST_CHANGES** (or **BLOCK** if critical security / data integrity).
- Only requests/nits + all tests green → **APPROVE**.
- No reviewer ran cleanly → investigate before approving.

## Phase 7 — Improve (feed the learning loop)

- If the same blocker class repeats across reviews (e.g., 3 PRs in a row missed tenant filters): queue to `ai/dynamic/learned-patterns.md` AND propose adding to `.claude/rules/multi-tenancy.md`.
- If the user disagreed with a reviewer's blocker (false positive): append to `ai/dynamic/feedback-learned.md` so future review tone calibrates.
- If a reviewer missed something obvious that was caught later: log as drift in `ai/dynamic/drift-log.md`.
- Suggest `/learn-from-task` after fixes are applied + PR opened.

## Output

```
## /review-changes — <branch>

Phase 1 (Understand): scope detected — <N> files in categories: <list>.
Phase 2 (Organize): planned <N> reviewers across universal/category/signal axes.
Phase 3 (Retrieved): <N> patterns + all rules + universals.
Phase 6 (Validated): <N> reviewers ran in parallel; <N> skills run.

**Verdict: APPROVE | REQUEST_CHANGES | BLOCK**

### Blockers (N)
1. [security] src/modules/admin/export.controller.ts:18 — missing auth guard on admin endpoint
   Fix: @UseGuards(JwtAuthGuard, AdminRoleGuard)
   Verify: e2e test asserts 401 unauthenticated.
   
2. [tenant] src/modules/reports/reports.repository.impl.ts:84 — raw SQL missing tenant filter
   Fix: add `AND tenant_id = :tenantId`
   Verify: cross-tenant leak test.

### Requests (N)
1. [perf] src/modules/orders/list.use-case.ts:24 — N+1 on customer lookup
   Fix: eager-load customer in the list query.
   
2. [test] Missing regression test for the webhook idempotency path.
   Fix: add test POSTing same message_id twice, assert single DB row.

### Nits (N)
1. [i18n] Hardcoded "Save changes" in products/form.vue:42
   Fix: add to en.json + ar.json as `products.form.save`.

### Positives (genuine only)
- Tenant isolation test coverage improved — new cross-tenant leak tests in 3 repos.

### Scope creep
- Nothing out of Phase 1 declared scope.

### Agents dispatched
code-reviewer, api-reviewer, schema-reviewer, tenant-isolation-reviewer, test-reviewer,
observability-reviewer, prompt-reviewer, security-auditor

### Skills run
a11y-scan (3 routes), n-plus-one-scan, doc-drift-scan, api-snapshot

### Patterns consulted
api-contract, error-handling, multi-tenancy, tenant-isolation, idempotency, structured-logging

Phase 7 (Improved): 0 recurring blocker classes; 1 false-positive captured to feedback-learned.md.

Status: REQUEST_CHANGES
```

## Rules

- Don't filler-praise.
- Don't propose changes outside the PR's declared intent.
- Don't skip signal-based reviewers — tenant leaks slip through when tenant-isolation-reviewer is skipped because "it's a small change".
- Block on: security, data integrity, tenant isolation, correctness. Request on: perf, DX, maintainability. Nit on: style, i18n, minor docs.
- Every blocker has a fix AND a verification step.
- Scope creep gets called out, not silently approved.
