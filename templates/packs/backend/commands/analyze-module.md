---
description: Deep module analysis — architecture, performance, security, DB, tests, dead code, in parallel.
---

# /analyze-module <path|name>

Pre-flight before refactoring or extending a module. Multiple agents run in parallel and consolidate findings by severity.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves.** An audit's job is to surface concrete, file:line-cited findings the maintainer can act on. A finding without a path is a hypothesis. A finding that says "and similar issues elsewhere" is a hand-wave that hides ignorance behind plausible language. Maintainers cannot fix a hand-wave — they spend an hour grepping for the missing context and lose trust in the audit. The audit either names the file and line, or the finding does not exist.

**The agent's job is exactly this:**
1. Run the dispatched reviewers; collect raw findings.
2. For each finding: confirm a real `file:line` exists in the actual codebase, name it explicitly, quote the offending line.
3. Drop any finding that cannot be backed by a citation. No exceptions.

**The agent does NOT:**
- Emit findings of the form "N+ similar issues" without enumerating each. **Either list every instance with file:line, or drop the finding.**
- Use words like `etc.`, `...`, `among others`, `and many more`, `several places`. **These are hand-waves; surface every instance or none.**
- Repeat one root cause as N findings (perf-reviewer's N+1 + schema-reviewer's missing-eager-load = ONE finding, not two).
- Treat coverage % as quality. 95% getter coverage is 0% protection.

**The agent ONLY escalates to the user when:**
- A reviewer fails to return (incomplete dispatch — the audit is not done).
- Stack mismatch (backend reviewers dispatched on a frontend module — switch reviewer set first).
- A BLOCKER cites a file:line that is dynamically loaded (DI auto-discovery, Next.js auto-routing) and may be a false positive — confirm before reporting.

## Closure verbs (complexity → ceremony)

Default to the lightest tier that fits. Heavy ceremony is opt-in, not default.

| Tier | Triggers | Artifacts | Reviewers |
|---|---|---|---|
| **Trivial** (default) | Single small module (<500 LOC, <8 files), routine pre-flight before a small extension. | 1-page report + ledger row in `ai/audits/`. **No drift-log update unless drift found.** | `api-reviewer` + `test-reviewer` + `dead-code-finder` (3 dispatches) |
| **Standard** | Mid-size module (500-2000 LOC) OR module owns DB tables OR multi-tenant. | Full report + drift-log entry per finding category. | + `schema-reviewer` + `performance-optimizer` + `security-auditor` (6 dispatches) |
| **Heavy** | Large module (>2000 LOC) OR sensitive surface (auth / payment / cross-tenant) OR untouched 90+ days OR known-flaky. | ADR queue for systemic findings + cross-module pattern check. | All 6 + signal-driven (`tenant-isolation-reviewer`, `prompt-reviewer`, etc.) |

**Default is trivial.** Most pre-flights are 3-reviewer scans on a small module. The audit promotes itself to standard/heavy if first-pass findings reveal scope; agent does NOT pre-emptively pick heavy "to be thorough."

## Hand-wave halt (mechanical gate, all tiers)

**Before declaring the audit complete, grep the consolidated report for hand-wave tokens.** Any hit halts the audit until findings are made concrete.

Forbidden tokens (case-insensitive grep):
- `etc.`
- `...` (ellipsis used as "and similar")
- `among others`
- `and many more`
- `several places`
- `multiple locations`
- `various files`
- `N+ items` / `N+ instances` (where N is a placeholder digit)
- `similar issues elsewhere`
- `likely also affects`

Halt rule: if any token appears in the report body (not in quoted code), HALT. The agent must either:
1. Replace the hand-wave with an explicit enumerated list (`OrdersController.ts:42, BillingService.ts:88, ...` becomes the literal list of every file:line).
2. Drop the finding entirely.

No silent advance. The output's reviewer-clean count is meaningless if half the findings are vapor.

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = the consolidated report; no code changes here. Phase 5 records the audit; Phase 7 feeds repeat-finding patterns. **Heavy-tier only runs all phases below; trivial/standard tiers skip Phase 7 unless a finding repeats across modules.**

## When to use / NOT to use
- USE: before extending a module untouched in 30+ days; before merging a 3rd-party module; after a refactor (verify nothing got worse).
- NOT: greenfield modules with < 100 lines — too little surface to review.

## Phase 1 — Understand

- Parse `<path|name>`.
  - Path arg → use directly.
  - Name arg → run `/find-module <name>` first to get the path.
  - No arg → list candidates from `ai/modules.md` and ask.
- Success: every reviewer returned, findings grouped by severity (BLOCKER / REQUEST / NIT) and area, verdict computed.

## Phase 2 — Organize

- Read module structure (file tree depth 3) + module entry file + main service/controller. Capture file count, line count, declared deps.
- Plan parallel agent dispatch (6 agents — see Phase 3/4).

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `ai/conventions.md` + `ai/business-domain.md`.
- `ai/modules.md` — module's row + declared dependencies.
- `ai/patterns/` — patterns the module SHOULD follow.

MODULE-SCOPED:
- Module's own `<module>.module.ts` + entry service + entry controller.
- 1-2 sibling modules for pattern comparison.

## Phase 4 — Generate (dispatch agents; consolidate)

Dispatch in parallel:
- **`api-reviewer`** — architecture compliance: layer boundaries, DTO usage, mapper presence, naming.
- **`schema-reviewer`** — entity design, FK indexes, query shapes (only if module owns DB tables).
- **`performance-optimizer`** — N+1, missing indexes (cross-checked with schema-reviewer), unnecessary serialization.
- **`security-auditor`** — auth on every endpoint, input validation at boundary, tenant isolation if multi-tenant, output filtering.
- **`test-reviewer`** — coverage %, test quality, presence of tenant-isolation tests, flake history.
- **`dead-code-finder`** — unused exports, files with no imports, dead branches.

Wait for all; consolidate by severity (BLOCKER / REQUEST / NIT) and area.

Compute verdict:
- 0 blockers → ready to extend.
- 1+ blocker → must fix or write ADR before extending.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-<module>-analysis.md` — full report.
- `ai/status.md` — Recent Changes entry with verdict + blocker count.
- `ai/dynamic/drift-log.md` — append findings categorized as `code-vs-rule`.
- `ai/modules.md` — update row's last-audited date.

## Phase 6 — Validate

- Self-audit: did every dispatched agent return? Missing agent = incomplete analysis.
- Cross-check N+1 finding (perf agent) against query shapes (schema agent) — same root cause should not appear twice as different findings.
- For BLOCKER findings: confirm file:line evidence is real (not a false positive on dynamically loaded code).

## Phase 7 — Improve

- If a finding repeats across 3+ modules, queue convention/rule update to `ai/dynamic/learned-patterns.md`.
- If a BLOCKER class is recurring (e.g. raw SQL missing tenant filter in N modules), queue ADR for systemic fix.
- If `dead-code-finder` repeatedly flags DI-loaded code as dead, queue exclusion pattern.

## Output

```
Module: orders
Path:   src/modules/orders
Files:  24      Lines:  3,847     Test coverage: 78%

Architecture:
  PASS   Layers respected (core / application / infrastructure)
  FAIL   2 services import infrastructure repositories directly (BLOCKER)
         - create-order.use-case.ts:8 imports OrderTypeOrmRepository
         - cancel-order.use-case.ts:8 same

Performance:
  FAIL   N+1 in listOrders — items lazy-loaded per row (BLOCKER)
         Fix: eager join via repo qb or DataLoader.
  PASS   Queries indexed (FK + tenant_id + created_at composite)

Security:
  PASS   All endpoints behind auth guard
  FAIL   getReport() raw query missing tenant filter (BLOCKER)
  PASS   Input validated via class-validator on every DTO

Database:
  PASS   FK indexes present
  WARN   description column TEXT — consider VARCHAR(N) bound

Tests:
  PASS   80% use-case coverage
  FAIL   No tenant-isolation tests (REQUEST)

Dead code:
  WARN   UnusedMapper.ts not imported anywhere (NIT — confirm before delete)

Verdict: 3 blockers. Fix or ADR before extending.
Suggested next: /fix-bug for blockers, then re-run /analyze-module.
```

## Stack-awareness

This command is in the backend pack but its **shape applies to any module-like construct**. Cross-stack adaptation:

| Stack | "Module" = | Reviewers to dispatch |
|---|---|---|
| Backend (NestJS / Django / Rails / Spring) | controller + service + repo + tests + DTOs | api-reviewer + schema-reviewer + perf + security + test-reviewer + dead-code |
| Frontend (Next / Nuxt / Vue / React feature dir) | components + page + store + tests + i18n keys | ui-reviewer + accessibility-auditor + i18n-auditor + design-system-guardian + test-reviewer + dead-code |
| Mobile (RN screen module / Flutter feature dir) | screens + components + state + native bridge + tests | mobile-architect + accessibility-auditor + i18n-auditor + native-bridge-audit (if bridge) + test-reviewer + dead-code |
| CLI / library | exported API + internal modules + tests | api-reviewer + test-reviewer + dead-code-finder + (security if input handling) |

Detect from `CLAUDE.md` declared stack. If the module path matches a frontend feature folder OR mobile screen folder, dispatch the corresponding reviewers instead of (or alongside) the backend defaults.

## Hard rules

- **Run BEFORE extending, not after.** Post-change analysis biases toward the diff.
- **Every BLOCKER cites file:line evidence.** "Architecture violation" without a path is a hypothesis.
- **A BLOCKER is fixed OR written into an ADR before extending.** "Acknowledged" alone doesn't count.
- **Cross-check findings to avoid duplicate reporting.** N+1 from perf-reviewer and missing-eager-load from schema-reviewer = one issue, not two.
- **Don't mark dead code dead without confirming it's not framework-magic loaded** (NestJS auto-discovered modules, Next.js auto-routed pages, Django apps registered in INSTALLED_APPS).
- **Coverage % is not quality.** A test-reviewer that says 95% but never asserts anything is failing the audit.
- **Stack-aware reviewer dispatch.** Backend reviewers on frontend modules produce noise; pick the right set.

## Failure modes

- Running AFTER changes — confirmation bias on the diff. Run BEFORE.
- "Acknowledged blocker" without ADR — that's just ignoring it; require ADR file path in the verdict.
- Coverage % treated as quality — `test-reviewer` looks at assertions; 95% coverage of getter tests means nothing.
- Dead-code finding on dynamically loaded files (DI containers, framework auto-discovery) — false positive; verify before deletion.
- Re-running not scheduled — module clean today won't stay that way; re-audit on each significant change.
- Dispatched backend reviewers on a frontend module — most findings irrelevant; switch reviewer set per stack.
- Treated module size (LOC) as quality signal — large is not bad, complex is. Audit complexity per agent (cyclomatic / coupling), not LOC.

## Related

### Sibling commands in backend pack
- `/add-endpoint` — sibling command in backend pack
- `/add-feature` — sibling command in backend pack
- `/add-module` — sibling command in backend pack
- `/endpoint-test` — sibling command in backend pack
- `/fix-bug` — sibling command in backend pack
- `/log-tail` — sibling command in backend pack
- `/trace-flow` — sibling command in backend pack

### Patterns
- `ai/patterns/api-contract.md`
- `ai/patterns/api-versioning.md`
- `ai/patterns/caching-strategy.md`
- `ai/patterns/error-handling.md`
- `ai/patterns/parallel-io.md`

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
