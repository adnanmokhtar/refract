---
description: "Comprehensive, signal-aware review of a PENDING DIFF, ending in a merge verdict (APPROVE / REQUEST_CHANGES / BLOCK) backed by a real test run. Classifies the diff, triages it by blast radius, dispatches every relevant specialist agent in parallel, consults all applicable patterns. Read-only — it never edits. Anti-triggers: ranking what is wrong with existing code at target scale is `/audit`; changing code to make it better (architecture, measured perf, cleanup) is `/optimize`; the staged-file commit gate is `/pre-commit`; the periodic no-diff repo pulse is `/check-health`."
allowed-tools: [Read, Grep, Glob, Bash, Task]
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

**Lightweight default.** Read-only review; no code generated, no `ai/` files written. The implementer who acts on findings runs `/learn-from-task` after fixes land. The verdict is one of `APPROVE` / `APPROVE (SUITE UNVERIFIED)` / `REQUEST_CHANGES` / `BLOCK` — single-line at the top, then findings grouped by severity.

**Always end with an ordered action plan.** The review is not finished until the **last** section is a `## What to do next` checklist: the findings re-expressed as numbered, prioritized steps (must-fix → should-fix → optional), each step carrying the `<file:line>`, the fix, and the verify, then the closing steps (re-run `/review-changes`, `/learn-from-task`, open the PR). Severity groups are the *detail*; the action plan is the *to-do*. A reader must never have to assemble the next steps themselves — the command does it for them. If the verdict is `APPROVE`, the action plan says so in one line (no blockers — clear to open the PR; optional nits listed). Canonical contract shared with every review/feedback command: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Phases applied

1, 2, 3, 6, 7. Phases 4 + 5 = N/A — review doesn't generate or persist changes; output is a verdict + list of fixes for the implementer.

## Invariants

- **Classify the diff first** — which areas changed? Wrong classification = wrong reviewers.
- **Universal reviewers ALWAYS**.
- **Specialist reviewers BASED on area touched**.
- **Domain lenses BASED on project signals** (applied domains in `.claude/_domain-coverage-report.md`; each goes to its mapped reviewer with `lens: .claude/lenses/<d>-review.md`).
- **Patterns consulted**, not just principles.
- **No axis silently skipped** — a reviewer that isn't installed is reported `UNREVIEWED(<axis>)` and the sweep ends INCOMPLETE, never dropped and never self-graded.
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
| ui | `ui-reviewer`, `design-system-guardian`, `accessibility-auditor`; `ux-reviewer` when the ui-ux pack is installed — `accessibility-auditor` then defers WCAG to it, and without this dispatch the axis ends `UNREVIEWED(a11y)` | `a11y-scan` (on changed routes if significant) |
| i18n | `i18n-auditor` | — |
| auth | `security-auditor`, `auth-reviewer` | — |
| docker | — | `container-build-scan` (devops pack, when installed) |
| k8s | `k8s-reviewer` (infrastructure pack) — the judge: runs the four detectors in refute mode and ranks what survives | `k8s-render-scan` first (one render per environment — Kustomize base and overlays, chart × values file, Argo `valueFiles` — each object tagged with its source file:line), then over that render `k8s-availability-scan` (floors, PDBs, probes, rollout, shutdown, platform single points of failure), `k8s-wiring-scan` (config rollout, Service and route refs, NetworkPolicy paths, Jobs, RBAC wiring) and `k8s-api-version-scan` (removed APIs, strict schema, admission, support status) (infrastructure pack, when installed). Without the pack the axis is `UNREVIEWED(k8s)` |
| ci | `ci-reviewer` (devops pack) — the judge: refutes every row the skills return and grades the pipeline and cache rows; `deployment-engineer` (devops pack) grades the release, deploy, image and compose rows `ci-reviewer` hands over (listed `handed (judge not installed)` without it) | `pipeline-integrity-scan` (devops pack, when installed) on the changed workflows — masking, exit status, the required-check join, deploy and publish gating; `ci-security-scan` (security pack, when installed) — privileged triggers × PR code, expression injection, pinning × privilege, credentials; its rows stay security's (`ci-reviewer` refutes, never grades them); `suite-execution-scan` (testing pack, when installed) when a workflow runs or gates tests — focus, skips, uncollected suites, `\|\| true` / `continue-on-error`, coverage config, retries. Without the devops pack the axis is `UNREVIEWED(ci)` |
| iac | `infra-reviewer` (infrastructure pack) — the judge: refutes the detector rows and ranks what survives | `iac-state-scan` (backend and locking, pinning, plan discipline, environment isolation) and `iac-lifecycle-scan` (identity churn, lifecycle misuse, stateful replacement, deletion safety) (infrastructure pack, when installed). Without the pack the axis is `UNREVIEWED(iac)` |
| api-contract | — | `api-snapshot` (breaking-change detection) |
| tests | `test-reviewer` | On the changed test files, by signal (testing pack, when installed): `assertion-strength-scan` (a changed test), `flake-source-scan` (a test, helper, fixture or runner config), `test-double-scan` (a double, a mock list, a test DB config, a shipped line naming a test mode), `suite-execution-scan` (a runner config, test script, coverage config, skip or focus) — after the repo-baseline lanes `test-integrity.py` and `oracle-check.py`. `test-reviewer` grades their rows; without the pack, the axis is `UNREVIEWED(tests)` |
| ai-code | `security-auditor` + lens `ai-review` | — |
| webhook | `resilience-reviewer` (idempotency + signature check) | — |
| events | `resilience-reviewer` | — |
| telemetry | `observability-reviewer` | — |
| Hot-path / performance-sensitive changes | `performance-optimizer` | `n-plus-one-scan` (database pack, when installed) |
| dependency-manifest | `security-auditor` (dep review) | `deps-audit` — for each **added** package (ignore pure version bumps): maintenance health, license compatibility, transitive/install-size cost, known-CVE check, and whether an already-present primitive or the stdlib covers it. A new dep on a security / data-handling surface with no rationale is a blocker. |

#### Signal-based (based on project, always when signal present)
| Signal | Reviewer |
|---|---|
| Multi-tenant | `tenant-isolation-reviewer` (any DB-touching change) |
| AI | `security-auditor` + lens `ai-review` (if AI code touched; domain `ai` installed) |
| Any applied technical domain | its domain lens — below |

**Domain lenses (Phase 6).** For each domain marked applied (✅) in `.claude/_domain-coverage-report.md` whose
surface the diff touches, dispatch that domain's reviewer — `reviewer` in `~/.claude/templates/domains/<d>/_version.json`,
or its `fallback` when the reviewer's pack is not installed; installed, the same mapping is the reviewer's generated
`## Lenses` block — with `lens: .claude/lenses/<d>-review.md` in its brief (payment, ledger, subscriptions, workflow,
settings, forms → `code-reviewer`; auth, admin, webhook, … → `security-auditor`; background-jobs, integrations,
real-time, … → `operability-reviewer`; caching, search → `performance-reviewer`). One dispatch per reviewer carries
all its lenses. A reviewer that cannot open a lens returns `BLOCKED(lens missing)`; the domain is then
`UNREVIEWED(<d>)`, never silently skipped.

#### Universal skill checks
- `dead-code-scan` (on changed files) — find what the change orphaned or made unreachable.

#### Code-quality detectors (this pack), by signal on the changed lines
The same detectors `/quality-audit` runs on a whole repo, each dispatched once when its signal fires on a changed file (each skill's `§ When to run`); a defect in lines the diff did not touch goes to **Pre-existing**, never blocking. Their rows are candidates until refuted ([`refute-before-report.md`](../../../snippets/refute-before-report.md) with `precedents/code-quality.md`); `code-reviewer` cites them and does not re-derive them.

| Signal on a changed file | Detector | Classes |
|---|---|---|
| a `catch` / `except` / `rescue`, a promise chain, an `async` callback, an outbound call, a queue or webhook handler, a lock or busy flag | `error-handling-scan` | § 1–§ 7 — dropped error, failure as success, unread status, floating promise, catch-all, lost cause, paired state |
| a parse, a JSON or storage read, a cast or non-null assertion, a checker config | `type-safety-scan` | § 1–§ 4 |
| money or quantity arithmetic, a number or date parse, a status switch, a comparator, a loop closure, a truncation | `correctness-smell-scan` | § 1–§ 7 |
| a suppression directive, an analyzer config, an ignore list or baseline file, the CI lint step | `suppression-scan` | § 1–§ 3 |
| a bug fix (the sibling sweep), pasted code | `duplication-scan` | § 1 divergent copy, § 3 clones the change added |

None fires → no row. A fired detector that did not run is `UNREVIEWED(<detector>)`, which ends the sweep INCOMPLETE like any missing reviewer. For a whole-repo question ("is the codebase hiding errors?") the answer is `/quality-audit`, not this command.
- `doc-drift-scan` — does the change need doc updates? `ai/status.md`? `ai/modules.md`? `ai/conventions.md`?
- `secret-scan-method` (on **every** changed file, not just `auth`) — hardcoded API keys / tokens / passwords / private keys / connection strings, and accidentally-staged `.env` / credential files. A real secret in the diff is a **BLOCK** (data integrity / security), independent of which category the file is in. If the skill isn't installed, run the inline check: high-entropy strings + known key prefixes (`AKIA`, `sk-`, `ghp_`, `-----BEGIN * PRIVATE KEY-----`, etc.) over the added lines.
- `coverage-gap` (on changed lines) — added business logic with no covering test is a finding **even when no test file was touched** (otherwise `test-reviewer` never dispatches and the gap is invisible). Severity: request by default, blocker on a security / data-integrity / write-path change. If the skill isn't installed, run the inline check: for each added function / branch / write-path in the diff, grep the test tree (`*.test.*` / `*.spec.*` / `test/**`) for a reference to the symbol or route; absence of any covering assertion is the finding. Never skip the axis — an unchecked coverage gap reads as "tested".

**Missing-agent contract (applies to every dispatch table above):** if a named reviewer is not installed in this project, that axis is **not reviewed** — do not grade it yourself; the reviewer is the point of the sweep. Record `UNREVIEWED(<axis>) — <reviewer> not installed (<pack> pack)` in the consolidation note and end the sweep **INCOMPLETE**, naming the install that closes it (`/setup-project --include=<pack>`). A skipped axis is the worst failure mode for a comprehensive sweep: it reads as "clean" when it was never checked.

### Pattern-specific invariant checks

Quick sweep per diff:

**Any new endpoint** (backend-code + HTTP handler):
- Auth guard present (not public unless explicit)?
- Input DTO validated?
- Pagination on list endpoints?
- Response shape consistent with project?

**Any new DB query** (db-repo + raw or query-builder) — each question has an owner; cite its row when it ran:
- Parameterized (no string concat)? → `injection-scan` (security pack).
- Tenant filter applied (if multi-tenant)? → `tenant-isolation-reviewer`.
- Soft-delete filter (if used)?
- Indexed columns? → `index-coverage-scan`; N+1 and unbounded reads → `n-plus-one-scan`, `query-shape-scan` (database pack).

**Any new external call** (HTTP client, DB, queue, SDK):
- Timeout explicit? Retry policy? Circuit breaker / bulkhead? → `resilience-reviewer` (distributed-systems pack); `request-path-scan` § 12 (performance pack).
- Failure observed — status checked, rejection awaited, error surfaced? → `error-handling-scan` § 3–§ 4 (this pack).
- Logged + metered?

Without the owner's pack, the question is answered here and the row tagged `<domain>-class (owner pack not installed)`.

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

`APPROVE` below is conditional on the suite being green. **A diff that contains test files is not evidence that tests pass.** Reading `*.spec.ts` in the diff and writing "tests green" is the Trusted-Summary failure this command exists to prevent, committed by the command itself. So the suite state is a *measured* input, produced here:

```bash
# Read the project's own commands from `ai/stack.md § Scripts` (or CLAUDE.md / package.json /
# Makefile / pyproject.toml). Run THEM — never a substituted toolchain, never invented flags.
<project test command>        # e.g. pnpm test --run · pytest -q · go test ./... · cargo test
<project typecheck command>   # if the project declares one
```

Scope: the suites covering the diff (`vitest related <files>` / `jest --findRelatedTests <files>` / `pytest --picked` / `go test ./<changed-pkgs>/...`) — full suite if the runner has no related-tests mode. Record the exit code and the pass/fail counts; they are what the verdict reads.

Exactly three outcomes, and the third is a first-class result:

| Outcome | Recorded as | Effect on verdict |
|---|---|---|
| Runner exits 0 | `Suite: GREEN (<N>/<N>, <command>)` | APPROVE is available |
| Runner exits non-zero | `Suite: RED (<failing test names>)` | **BLOCK** — a red suite outranks every finding below it; report the failures and stop |
| Runner not declared / not installed / cannot run here (no DB, no browser, CI-only) | `Suite: UNVERIFIED — <reason>` | APPROVE is **capped at `APPROVE (SUITE UNVERIFIED)`** and names the reason |

Never launder UNVERIFIED into green. "The tests looked fine in the diff" is UNVERIFIED, not GREEN.

### Consolidate findings

**Refute before posting.** Reviewer output is candidates. Every candidate a reviewer marked Blocker or
Request goes through [`refute-before-report.md`](../../../snippets/refute-before-report.md) (§ 10 for
correctness, a11y, observability, maintainability; security classes through
[`finding-verification.md`](../../../snippets/finding-verification.md)) in `@verifier`, mode `refute`,
dispatched with a [delegation brief](../../../snippets/delegation-brief.md) — candidate files and the diff,
never the reviewers' prose. When the review runs inside a run (`run_id` given, or create
`ai/runs/<YYYYMMDD>-review-<branch-slug>-<4hex>/`), reviewers return `refract/findings/v1` JSON that
`persist-review.sh` records, and the verifier's verdict lands in `verdict-refute.json` — gate-check's
G7 review reads both. Confirmed → posted; Unconfirmed → posted as a question with its probe, never a
Blocker; Pre-existing → listed, **never blocks**; Hardening / Refuted → one tally line.

Then apply [`posting-bar.md`](../../../snippets/posting-bar.md): Blocker and Request map to
**IMPORTANT** (when verified), Nit to **NIT** (at most 5), no style comment where a formatter exists, and
from the second review round IMPORTANT only. Merge into one report, grouped by severity. GO / NO-GO verdict:
- **Suite RED** → **BLOCK**, regardless of what the reviewers found. Fix the build first.
- Any **verified Blocker** (Confirmed by the verifier) → **REQUEST_CHANGES** (or **BLOCK** if critical security / data integrity). An unverified one never blocks; it is a question.
- Only requests/nits + **Suite GREEN as recorded above** → **APPROVE**.
- Only requests/nits + **Suite UNVERIFIED** → **APPROVE (SUITE UNVERIFIED)** — name what could not run and why.
- No reviewer ran cleanly → investigate before approving.

### Build the action plan (mandatory closing section)

After consolidating, re-express the findings as an **ordered, numbered to-do list** — this is the section the implementer actually works from. Rules:
- **Order by priority**, not by severity-group: MUST FIX (every blocker) → SHOULD FIX (every request) → OPTIONAL (nits). Number continuously (1, 2, 3 …) so it reads as one sequence of actions.
- Each step restates the `<file:line>`, the **Fix** (concrete — snippet / command / named pattern), and the **Verify** (test or check; required on every MUST-FIX step).
- End with the **closing steps**: re-run `/review-changes` to confirm the verdict flips to APPROVE, run `/learn-from-task`, then open the PR.
- If the verdict is **APPROVE**, the plan is a single line ("No blockers — clear to open the PR" + any optional nits), not an empty section.
- Do not invent steps that aren't backed by a cited finding (same `cite-or-drop` discipline). The action plan is a re-ordering of real findings, never new advice.

## Phase 7 — Improve (feed the learning loop)

- If the same blocker class repeats across reviews (e.g., 3 PRs in a row missed tenant filters): queue to `ai/dynamic/learned-patterns.md` AND propose adding to `.claude/rules/multi-tenancy.md`.
- If the user disagreed with a reviewer's blocker (false positive): append to `ai/dynamic/feedback-learned.md` so future review tone calibrates.
- If a reviewer missed something obvious that was caught later: log as drift in `ai/dynamic/drift-log.md`.
- Suggest `/learn-from-task` after fixes are applied + PR opened.

## Output

```
## /review-changes — <branch>

Phase 1 (Understand): "<one-sentence change>" — <N> files: carrier <paths>, consequence <N>, incidental <N>.
Phase 2 (Organize): planned <N> reviewers across universal/category/signal axes.
Phase 3 (Retrieved): <N> patterns + all rules + universals.
Phase 6 (Validated): Suite GREEN (245/245, `pnpm test --run`); <N> reviewers ran in parallel; <N> skills run.

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
observability-reviewer, security-auditor (+ lens ai-review)

### Skills run
a11y-scan (3 routes), n-plus-one-scan (database pack), doc-drift-scan, api-snapshot

### Patterns consulted
api-contract, error-handling, multi-tenancy, tenant-isolation, idempotency, structured-logging

Phase 7 (Improved): 0 recurring blocker classes; 1 false-positive captured to feedback-learned.md.

Status: REQUEST_CHANGES

---

## What to do next  (do these in order)

MUST FIX — merge is blocked until these are done:
1. <modules-root>/admin/export.controller.<ext>:18 — add the auth + admin-role gate.
   Fix: wrap the route with the project's auth guard primitive (`_extracted-idioms.md § Auth`).
   Verify: e2e test asserts 401 when unauthenticated.
2. <modules-root>/reports/reports.repository.impl.<ext>:84 — add the missing tenant filter.
   Fix: `AND tenant_id = :tenantId` on the raw query.
   Verify: cross-tenant leak test passes.

SHOULD FIX — fix now unless you have a reason not to:
3. <modules-root>/orders/<list-handler>.<ext>:24 — resolve the N+1 on customer lookup.
   Fix: eager-load customer in the list query.
4. webhook idempotency path has no regression test.
   Fix: add a test POSTing the same message_id twice; assert one DB row.

OPTIONAL — nits, safe to defer:
5. products/form.<ext>:42 — hardcoded "Save changes".
   Fix: add `products.form.save` to en.json + <other-locale>.json.

Then:
6. Re-run `/review-changes` — confirm the verdict flips to APPROVE.
7. Run `/learn-from-task` to capture what was learned.
8. Open the PR.
```

(When the verdict is **APPROVE**, this section collapses to one line — e.g. `What to do next: No blockers — clear to open the PR. Optional: fix nit #1 (products/form.<ext>:42).`)

## Rules

- Don't filler-praise.
- Don't propose changes outside the PR's declared intent.
- Don't skip signal-based reviewers — tenant leaks slip through when tenant-isolation-reviewer is skipped because "it's a small change".
- Never silently skip an axis — an uninstalled reviewer is reported `UNREVIEWED(<axis>)` (the sweep is INCOMPLETE), not dropped and not self-graded.
- Run `secret-scan-method` on every changed file regardless of category — a committed credential is a BLOCK.
- **Never assert suite state from the diff.** `Suite: GREEN` requires a runner exit code recorded in this run; anything else is `UNVERIFIED` and caps the verdict. A red suite is a BLOCK that outranks every finding.
- A diff that adds a dependency (not a version bump) gets a dependency review — flag it, don't wave it through.
- Block on: security, data integrity, tenant isolation, correctness, committed secrets. Request on: perf, DX, maintainability, unreviewed new dependency. Nit on: style, i18n, minor docs.
- Every blocker has a fix AND a verification step.
- Scope creep gets called out, not silently approved.

## Related

### The boundary this command owns

**`/review-changes` reviews the whole branch DIFF and returns a merge verdict.** Its input is `git diff` for the change as a whole; its output is APPROVE / REQUEST_CHANGES / BLOCK on *this change*, backed by a real test run.

It is **not** the only verdict-producer in the repo, and pretending otherwise routes people wrong. Two others emit the same three tokens on narrower inputs: `/pre-commit` (the same sweep against `git diff --cached`, at the commit moment — see Siblings below) and `/migration-review` (`database` pack — one artifact class, judged on lock impact and deploy safety only). What this command owns is the **union**: the full branch diff, the full specialist panel, and the merge decision. So pick by *input*, not by output — staged index → `/pre-commit`; a migration file → `/migration-review`; "may I merge this branch" → here.

Every other neighbour below either takes a different input (the whole codebase) or produces a different output (edits, not a verdict).

**Anti-triggers — route away, do not run this command:**
- *"Is the codebase ready for 10× traffic / pre-launch hardening / rank what's wrong across security + perf + DB"* → **`/audit`** (global). `/audit` ranks defects in code that **already exists**, across 8 axes at target scale, and then fixes them P0–P4. It has no diff and no merge verdict. If you have not opened a PR, you want `/audit`.
- *"Clean up the auth flow / speed up the dashboard / architectural cleanup"* → **`/optimize`** (global). `/optimize` **changes** code (Phase-0 architectural diagnosis, then a measured perf + quality sweep). `/review-changes` never edits a file. If the ask is "make it better", not "may I merge this", it is `/optimize`.
- *"Review the code I just wrote and fix it"* → `/optimize` or the harness `code-review` skill; this command reports, it does not apply.
- Trivial diffs (formatting, a lockfile bump) → skip; the overhead exceeds the value.

Overlap that is deliberate: `/audit` and `/optimize` can both surface findings this command would surface. The split is **moment and mandate** — this one runs at the merge gate and answers a yes/no; those two run on a settled tree and answer "what should change".

### Sibling commands in code-quality pack
- `/pre-commit` — the same sweep, one moment earlier and one scope narrower: **staged** files, and it *blocks the commit*. This command reviews the whole branch diff for the *PR*. The two share the category→reviewer routing; when they disagree, this file is the wider one and the source of record.
- `/quality-audit` — no diff required: every code-quality detector on the whole repo, a fixed class ledger and a verdict; `/quality-fix` closes its findings. This command dispatches the same detectors by signal on the diff.
- `/check-health` — no diff at all: the periodic whole-repo pulse (mechanical + agent RAG grid). Run it weekly; run this per PR.
- `/simplify` — applies four entropy-reducing verbs to code. Findings, then edits. This command produces findings only.
- `/refactor` (pack overlay) — behaviour-preserving structure moves. Route a `refactor:`-shaped finding there rather than describing the move here.
- `/find-module` — locate the code before reviewing it.

### Rules
- `.claude/rules/engineering-principles.md`
- `.claude/rules/quality-principles.md`
