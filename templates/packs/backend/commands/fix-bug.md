---
description: Comprehensive orchestration for a bug fix. Gathers context via skills, investigates root cause, writes failing test first, fixes, verifies, scans for similar bugs, reviews with domain-appropriate agents, and updates telemetry if the bug went undetected.
---

# /fix-bug

Bugs are undersold in reports. This flow prevents "fixed" bugs from reappearing and catches their siblings.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve), with Phase 4 = TDD (failing test first, then fix).

## Invariants

- **Regression test is NOT optional.**
- **Root cause, not symptom.**
- **Similar-bug scan** — one bug is often N bugs.
- **Observability gap check** — was this detectable? If not, fix the gap.
- **Zero placeholders** in test / fix.

## When to use / NOT to use

- USE: a defect (incorrect behavior, error, regression).
- USE: when symptom + reproduction available (or extractable).
- NOT: feature work disguised as a bug → use `/add-feature`.
- NOT: pure refactor → use `/refactor`.

## Phase 1 — Understand (the bug)

One consolidated question if info missing:
- Exact symptom.
- Steps to reproduce.
- Expected vs actual.
- Environment (dev / staging / prod) + timestamp.
- Correlation id / trace id / user id / tenant id if available.
- Severity — is prod burning right now?

State the success criteria: failing regression test in place, fix applied, similar bugs scanned, telemetry gap closed.

## Phase 2 — Organize (plan the fix)

Plan steps:
1. Reproduce locally (or mark intermittent).
2. Investigate (bug-investigator) for root cause.
3. Consult patterns matching the bug area.
4. Similar-bugs scan (blast radius).
5. Failing test first (TDD).
6. Minimal fix.
7. Verify + similar-bug fixes.
8. Observability gap check.
9. Review (parallel, signal-aware).
10. Document.

If prod is burning: shorten Phase 2 to "stabilize first, then proper flow on follow-up." Note that as a follow-up.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.
- All `.claude/rules/`.

CONTEXT-GATHERING SKILLS:

**If correlation id / timestamp**:
- `log-tail correlation:<id>` OR `log-tail error` + filter by time.
- Read logs end-to-end before theorizing.

**If HTTP endpoint**:
- `/trace-flow <endpoint>` for the call chain.

**If DB-related**:
- `schema-diff` if drift suspected.
- Check recent migrations.

**If performance**:
- `profile-endpoint` on the affected endpoint.
- `n-plus-one-scan` on the affected module.

PATTERN CONSULTATION (per bug area):

| Bug area | Patterns to read |
|---|---|
| DB / query | `indexing-strategy.md`, `migrations.md`, `caching-strategy.md` |
| Cache invalidation | `caching-strategy.md` |
| Tenant leak | `multi-tenancy.md`, `tenant-isolation.md` |
| Webhook double-processing | `idempotency.md`, `outbox.md` |
| Retry amplification | `idempotency.md`, `circuit-breaker.md` |
| Auth bypass / IDOR | `auth-flow.md`, `zero-trust.md` |
| Memory / perf | `caching-strategy.md` + profile tooling |
| Race condition | `idempotency.md`, `saga.md` |
| Test flake | `test-doubles.md`, `test-strategy.md` |
| AI output bad | `prompt-builder.md`, `ai-cost-tracking.md` |
| SSR hydration | `ssr-safety.md`, `rendering-strategy.md` |
| Deploy regression | `zero-downtime-deploys.md`, `api-versioning.md` |

EXISTING CODE:
- The file(s) where the bug lives, end-to-end.
- One sibling that does the same thing correctly (reference for fix shape).

## Phase 4 — Generate (reproduce, investigate, test-first, fix)

### Reproduce locally

- Trigger in dev if reproducible.
- If not: mark "intermittent", proceed with caution. Heisenbugs demand evidence.

### Investigate (bug-investigator)

Dispatch `bug-investigator` with bug description + logs from Phase 3 + trace from Phase 3 + recent commits.

Output: symptom → reproducer → ROOT CAUSE (one sentence) → call chain → why tests didn't catch it → fix plan → similar-bugs-to-check list.

**Root cause named before proceeding.**

### Similar-bugs scan

BEFORE fixing, grep for the root-cause pattern across the codebase.

Example: bug is "raw SQL missing tenant filter in reports.repository" — grep ALL repos for the pattern.

```bash
rg "createQueryBuilder|datasource\.query|em\.createQueryBuilder" src/modules/*/infrastructure/
# For each hit: is the tenant filter applied?
```

Report: "this bug exists in N files" OR "localized to one file".

Plan the fix — sometimes broader fix (with approval), sometimes just this file + tickets for others.

### Failing test FIRST

Dispatch `test-engineer` with the root cause + a spec for a test that REPRODUCES the bug.

Requirements:
- Test currently FAILS (confirms it catches the bug).
- Deterministic (no sleep, seeded randomness, fake time).
- Right level (unit if pure logic; integration if DB; e2e if HTTP).

**Don't proceed until the test reliably fails.**

### Minimal fix

- Change only what's needed to make the test pass.
- No incidental cleanup / refactor. File separately.
- Match existing code style exactly.

## Phase 5 — Update (persist changes to the knowledge base)

Prepend to `ai/status.md` Recent Changes:

```
### Bug fix — <short title>
- Symptom: <what users saw>
- Root cause: <one sentence>
- Fix: <one sentence>
- Regression test: <file path>
- Similar bugs elsewhere: <N fixed / 0 / ticket XXX>
- Observability improvement: <metric/alert/span added | none>
```

- Deeper architectural issue? → new ADR.
- New reusable insight? → add to `ai/patterns/` or enhance existing.
- Append one-line summary to `ai/dynamic/changelog.md`.
- If prod-affecting → write postmortem at `ai/audits/<date>-<slug>.md`:
  - Timeline (started, detected, mitigated, resolved).
  - Root cause.
  - Contributing factors.
  - What went well / badly.
  - Action items (each with owner).
  Blameless. Systems, not people.

## Phase 6 — Validate (verify fix + review)

Mandatory:
- Failing test now passes ✓
- ALL existing tests still pass ✓
- Manual reproduction confirms fix ✓
- Similar-bug grep: fixed OR ticketed ✓

Run skills:
- `endpoint-test` if endpoint logic changed.
- `coverage-gap` — all branches of the fix tested?
- `schema-diff` if DB involved.
- `n-plus-one-scan` if perf bug.

### Observability gap check

Ask: **why didn't prod / oncall know sooner?**

- Silently swallowed in catch? → Add log + metric.
- No alert on the affected endpoint's error rate? → Add alert.
- No trace span on the external call that failed? → Add span.
- No counter on the failing branch? → Add metric.

Any gap: dispatch `/add-telemetry` for detection improvement.

### Review (parallel, signal-aware)

**Always**:
- `code-reviewer`
- `test-reviewer` — does the regression test genuinely catch the bug?

**Based on area touched**:
| Touched | Agent |
|---|---|
| Backend logic | `api-reviewer` |
| DB / query | `schema-reviewer`, `query-optimizer` |
| Auth / crypto | `security-auditor`, `auth-reviewer` |
| Performance-sensitive | `performance-optimizer` |
| Cross-service | `resilience-reviewer` |
| Telemetry changes | `observability-reviewer` |

**Based on project signals**:
| Signal | Agent |
|---|---|
| Multi-tenant (any DB change) | `tenant-isolation-reviewer` |
| AI code touched | `prompt-reviewer` |

Block on any BLOCKER.

## Phase 7 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: symptom, root cause, fix shape, similar-bug count, telemetry gap.
- If similar-bug scan found N>1 occurrences: queue to `ai/dynamic/learned-patterns.md` as a project-wide concern → consider lint rule / codemod.
- If observability gap was filled: append to `ai/dynamic/feedback-learned.md` ("future code in this area should ship with X metric").
- If the bug class is preventable by a `.claude/rules/` update: queue to `ai/dynamic/decisions-pending.md`.
- If the test-engineer output was off-style: append correction to `ai/dynamic/feedback-learned.md`.

## Output

```
✅ Bug fix: <short title>

Phase 1 (Understand): symptom <X>, severity <Y>, repro confirmed locally.
Phase 2 (Organize): 10-step fix plan with TDD (failing test first).
Phase 3 (Retrieved): logs (correlation:<id>), trace, 3 patterns, 7 universals.
Phase 4 (Generated): regression test (failing), minimal fix, similar-bug scan (<N> hits).
Phase 5 (Updated): ai/status.md Recent Changes, postmortem at ai/audits/<file> (if warranted).
Phase 6 (Validated): test now passes, all existing tests green, observability gap filled.
Phase 7 (Improved): /learn-from-task queued.

Severity:    <prod-down | degraded | minor>
Symptom:     <one line>
Root cause:  <one line>
Fix:         <one line + file:line>

Regression test: <path> — was failing, now passes
Similar bugs:    <N fixed | 0 found | filed TICKET-NNN>

Review verdict: APPROVE / REQUEST_CHANGES / BLOCK
Agents run:     <list>
Patterns consulted: <list>

Observability gap: <detected + fixed | none>

Docs updated:
  - ai/status.md Recent Changes
  - <any other>

Incident write-up: <ai/audits/... | not warranted>

Status: COMPLETE

Next:
  - /review-changes  (final independent pass)
  - Commit + open PR
```

## Hard rules

- Failing test BEFORE fix. Always.
- Root cause named before fix attempted.
- Similar-bugs scan done first — blast radius known.
- Observability gap checked — "why didn't we know sooner?".
- No incidental refactor in bug-fix PR.
- No skipping review.
- Prod-affecting bugs get a write-up.
