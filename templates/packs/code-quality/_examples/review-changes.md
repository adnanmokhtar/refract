---
description: Comprehensive, signal-aware review of a PENDING DIFF, ending in a merge verdict (APPROVE / REQUEST_CHANGES / BLOCK) backed by a real test run. Classifies the diff, triages it by blast radius, dispatches every relevant specialist agent in parallel, consults all applicable patterns. Read-only — it never edits. Anti-triggers: ranking what is wrong with existing code at target scale is `/audit`; changing code to make it better (architecture, measured perf, cleanup) is `/optimize`; the staged-file commit gate is `/pre-commit`; the periodic no-diff repo pulse is `/check-health`.
---

# /review-changes

Use before opening a PR. Use before every commit if the habit fits. Never wave changes through.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every comment cites `<file:line>`.** A review is a list of findings, each anchored to a specific location in the diff with a concrete fix. Generic advice ("consider error handling", "think about performance", "this could be cleaner") is noise. If the agent cannot cite the file and line, the finding does not exist.

**The closure verb is `cite-or-drop`.** Each finding row MUST contain:
- A `<path>:<line>` reference inside the current diff.
- A 1-line description of the actual defect (not a category label).
- A concrete fix (code snippet, command, or named pattern from the project's pattern library).
- Optionally a verification step (test name, manual check) — required for blockers.

If any of those are missing, the agent drops the finding rather than emitting a hand-wave.

**Forbidden:**
- "Consider X" / "you might want to Y" / "in some codebases people Z" — hand-wave grep. Drop or cite.
- Findings on lines NOT in the diff (out-of-scope nags) unless they're caused by the diff (new caller of an existing buggy helper — cite both lines).
- Filler praise ("great job", "looks clean overall") — only `Positives` if a genuine improvement is named with `<file:line>`.
- Restating the diff back as a finding ("you added a function" — that's not a finding).
- Inventing a violation of a pattern that the project doesn't have a documented rule for. Cite the rule file or drop the finding.

**Mechanical halt — hand-wave grep on comments:** before emitting, the agent self-greps every finding for hand-wave shapes (`consider`, `might want`, `could be`, `in general`, `often`, `sometimes`, `it would be nice`). Any match without a `<file:line>` + concrete fix HALTS that finding — drop it or rewrite it with the citation. The final output passes the grep.

**Lightweight default.** Read-only review; no code generated, no `ai/` files written. The implementer who acts on findings runs `/learn-from-task` after fixes land. The verdict is one of `APPROVE` / `REQUEST_CHANGES` / `BLOCK` — single-line at the top, then findings grouped by severity.

## Phases applied

1, 2, 3, 6, 7. Phases 4 + 5 = N/A — review doesn't generate or persist changes; output is a verdict + list of fixes for the implementer.

## Invariants

- **Classify the diff first** — which areas changed? Wrong classification = wrong reviewers.
- **Universal reviewers ALWAYS**.
- **Specialist reviewers BASED on area touched**.
- **Domain reviewers BASED on project signals** (from `CLAUDE.md`).
- **Patterns consulted**, not just principles.
- **No axis silently skipped** — a reviewer that isn't installed is performed inline against its checklist, never dropped.
- **Secrets scanned on every changed file** — not just `auth`-category files; a leaked key in a test fixture or config is still a blocker.
- **New dependencies reviewed** — a diff that adds a package (not a version bump) is gated like the rest of the suite.
- **New logic ships with tests** — added behaviour with no covering test is flagged even when no test file was touched.
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
| `package.json` / `*-lock.*` / `yarn.lock` / `pnpm-lock.yaml` / `go.mod` / `go.sum` / `requirements.txt` / `poetry.lock` / `Pipfile*` / `Gemfile*` / `Cargo.toml` / `Cargo.lock` / `*.csproj` / `pom.xml` / `build.gradle` / `Podfile*` | dependency-manifest |

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

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

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
- `change-brief` skill (mode B — validate): the PR/commit body must carry a passing 5-field change brief (What / Why this shape / Edge cases / Blast radius / Verified by) for any change matching the skill's trigger tiers. Missing/failing brief is a blocker finding — the comprehension gate ("if you can't explain the code, it isn't yours") applied at review time.

#### Category-based (based on diff categories)

Two dispatch surfaces — **agents** (sub-agents the dispatcher spawns) and **skills** (procedures the dispatcher invokes inline). Route each to its own primitive; do not dispatch a skill as an agent or vice-versa.

| Category | Agents (dispatch) | Skills (invoke) |
|---|---|---|
| backend-code | `api-reviewer` | — |
| db-entity / db-repo | `schema-reviewer`, `query-optimizer` | — |
| db-migration | `schema-reviewer` + invoke `/migration-review` | — |
| ui | `ui-reviewer`, `design-system-guardian`, `accessibility-auditor` | `a11y-scan` (on changed routes if significant) |
| i18n | `i18n-auditor` | — |
| auth | `security-auditor`, `auth-reviewer` | — |
| docker | — | `dockerfile-lint` |
| k8s | `k8s-reviewer` | — |
| ci | `ci-reviewer` | — |
| api-contract | — | `api-snapshot` (breaking-change detection) |
| tests | `test-reviewer` | — |
| ai-code | `prompt-reviewer` | — |
| webhook | `resilience-reviewer` (idempotency + signature check) | — |
| events | `resilience-reviewer` | — |
| telemetry | `observability-reviewer` | — |
| Hot-path / performance-sensitive changes | `performance-optimizer` | `n-plus-one-scan` |
| dependency-manifest | `security-auditor` (dep review) | `deps-audit` — for each **added** package (ignore pure version bumps): maintenance health, license compatibility, transitive/install-size cost, known-CVE check, and whether an already-present primitive or the stdlib covers it. A new dep on a security / data-handling surface with no rationale is a blocker. |

#### Signal-based (based on project, always when signal present)
| Signal | Reviewer |
|---|---|
| Multi-tenant | `tenant-isolation-reviewer` (any DB-touching change) |
| AI | `prompt-reviewer` (if AI code touched) |
| Payment | payment-specific reviewer if available |

#### Universal skill checks
- `dead-branch-scan` (on changed files) — find unreachable code you just added.
- `doc-drift-scan` — does the change need doc updates? `ai/status.md`? `ai/modules.md`? `ai/conventions.md`?
- `secret-scan` (on **every** changed file, not just `auth`) — hardcoded API keys / tokens / passwords / private keys / connection strings, and accidentally-staged `.env` / credential files. A real secret in the diff is a **BLOCK** (data integrity / security), independent of which category the file is in. If the skill isn't installed, run the inline check: high-entropy strings + known key prefixes (`AKIA`, `sk-`, `ghp_`, `-----BEGIN * PRIVATE KEY-----`, etc.) over the added lines.
- `coverage-gap` (on changed lines) — added business logic with no covering test is a finding **even when no test file was touched** (otherwise `test-reviewer` never dispatches and the gap is invisible). Severity: request by default, blocker on a security / data-integrity / write-path change.

**Missing-agent fallback (applies to every dispatch table above):** if a named reviewer is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis. Note the substitution in the consolidation note (`inline:<reviewer-name>`). A skipped axis is the worst failure mode for a comprehensive sweep: it reads as "clean" when it was never checked.

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

**Any added dependency** (manifest/lockfile diff shows a NEW package, not a version bump):
- Actually new, or does a sibling already ship an equivalent?
- Maintained (recent release, no known CVEs) and license-compatible?
- Transitive / install-size cost justified vs an existing primitive or the stdlib?
- Rationale present in the PR body? (A new dep on a security / data-handling path needs one — or an ADR.)

### Phase discipline check

Read `ai/status.md` current phase. Is this change in-scope?

Scope creep = blocker or a discussion. "This is Phase 3 work but we're in Phase 1" → push back OR amend the roadmap in an ADR.

### Suite state — run it, never infer it

`APPROVE` is conditional on the suite being green, and **a diff that contains test files is not evidence that tests pass.** Reading `*.spec.ts` in the diff and writing "tests green" is the Trusted-Summary failure this command exists to prevent, committed by the command itself. Measure it here:

```bash
# Read the project's own commands from `ai/stack.md § Scripts` (or CLAUDE.md / package.json /
# Makefile / pyproject.toml). Run THEM — never a substituted toolchain, never invented flags.
<project test command>        # e.g. pnpm test --run · pytest -q · go test ./... · cargo test
<project typecheck command>   # if the project declares one
```

Scope to the suites covering the diff (`vitest related` / `jest --findRelatedTests` / `pytest --picked` / `go test ./<changed-pkgs>/...`), full suite if there is no related-tests mode. Three outcomes, and the third is first-class:

| Outcome | Recorded as | Effect |
|---|---|---|
| Exit 0 | `Suite: GREEN (<N>/<N>, <command>)` | APPROVE available |
| Non-zero | `Suite: RED (<failing tests>)` | **BLOCK** — outranks every finding below |
| Cannot run here (not declared / not installed / needs DB or browser / CI-only) | `Suite: UNVERIFIED — <reason>` | caps the verdict at `APPROVE (SUITE UNVERIFIED)` |

Never launder UNVERIFIED into green.

### Consolidate findings

Merge all reviewer outputs into one report, grouped by severity. GO / NO-GO verdict:
- **Suite RED** → **BLOCK**, regardless of what the reviewers found.
- Any **Blocker** → **REQUEST_CHANGES** (or **BLOCK** if critical security / data integrity).
- Only requests/nits + **Suite GREEN as recorded above** → **APPROVE**.
- Only requests/nits + **Suite UNVERIFIED** → **APPROVE (SUITE UNVERIFIED)**, naming what could not run.
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
1. [security] <modules-root>/admin/export.controller.<ext>:18 — missing auth guard on admin endpoint
   Fix: apply the project's auth + admin-role gate primitive (per `_extracted-idioms.md § Auth`).
   Verify: e2e test asserts 401 unauthenticated.

2. [tenant] <modules-root>/reports/reports.repository.impl.<ext>:84 — raw SQL missing tenant filter
   Fix: add `AND tenant_id = :tenantId`
   Verify: cross-tenant leak test.

### Requests (N)
1. [perf] <modules-root>/orders/<list-handler>.<ext>:24 — N+1 on customer lookup
   Fix: eager-load customer in the list query.
   
2. [test] Missing regression test for the webhook idempotency path.
   Fix: add test POSTing same message_id twice, assert single DB row.

### Nits (N)
1. [i18n] Hardcoded "Save changes" in products/form.<ext>:42
   Fix: add to en.json + <other-locale>.json as `products.form.save`.

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

## What to do next  (do these in order)

MUST FIX — merge is blocked until these are done:
1. <modules-root>/admin/export.controller.<ext>:18 — add the auth + admin-role gate.
   Fix: wrap the route with the project's auth guard primitive.
   Verify: e2e test asserts 401 when unauthenticated.

SHOULD FIX — fix now unless you have a reason not to:
2. <modules-root>/orders/<list-handler>.<ext>:24 — resolve the N+1 on customer lookup.
   Fix: eager-load customer in the list query.
   Verify: query count drops in the list-endpoint test.

Then: re-run `/review-changes` to confirm it comes back clean, and open the PR.
```

(When the verdict is **APPROVE**, this section collapses to one line — e.g. `What to do next: No blockers — clear to open the PR. Optional: fix nit #1.`)

## Rules

- Don't filler-praise.
- Don't propose changes outside the PR's declared intent.
- Don't skip signal-based reviewers — tenant leaks slip through when tenant-isolation-reviewer is skipped because "it's a small change".
- Never silently skip an axis — an uninstalled reviewer is performed inline (`inline:<reviewer-name>`), not dropped.
- Run `secret-scan` on every changed file regardless of category — a committed credential is a BLOCK.
- **Never assert suite state from the diff.** `Suite: GREEN` requires a runner exit code recorded in this run; anything else is `UNVERIFIED` and caps the verdict.
- A diff that adds a dependency (not a version bump) gets a dependency review — flag it, don't wave it through.
- Block on: security, data integrity, tenant isolation, correctness, committed secrets. Request on: perf, DX, maintainability, unreviewed new dependency. Nit on: style, i18n, minor docs.
- Every blocker has a fix AND a verification step.
- Scope creep gets called out, not silently approved.

## Related

### The boundary this command owns

**`/review-changes` reviews a DIFF and returns a merge verdict.** Input `git diff`, output APPROVE / REQUEST_CHANGES / BLOCK on *this change*. Every neighbour either takes a different input or produces a different output.

**Anti-triggers — route away:**
- *"Rank what's wrong at 10× traffic / pre-launch hardening"* → **`/audit`** (global): existing code, 8 axes, ranked at target scale, then fixed P0–P4. No diff, no merge verdict.
- *"Clean up the auth flow / speed up the dashboard"* → **`/optimize`** (global): it **changes** code after a Phase-0 architectural diagnosis. This command never edits a file.
- Trivial diffs (formatting, lockfile bump) → skip; overhead exceeds value.

### Sibling commands in code-quality pack
- `/pre-commit` — same sweep one moment earlier and one scope narrower (staged files), and it blocks the commit. Shares this file's category→reviewer routing; this file is the source of record.
- `/check-health` — no diff at all: the weekly whole-repo pulse.
- `/simplify` — applies four entropy-reducing verbs; this command produces findings only.
- `/refactor` (pack overlay) — behaviour-preserving structure moves; route `refactor:`-shaped findings there.
- `/find-module` — locate the code before reviewing it.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
