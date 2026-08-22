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
- **Stack mismatch — halt, do not re-aim.** If the target path is a frontend feature directory or a mobile screen module, this command's reviewer set is the wrong one and it does not own the right one. Halt and redirect to that pack's audit (`/design-review` or `/a11y-audit` in the frontend pack; the mobile pack's own module audit) *when it is installed*, and say so plainly when it is not — a backend audit re-labelled is worse than no audit, because it reports six green axes it never examined.
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

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

`ai/dynamic/feedback-learned.md` is load-bearing *here specifically*: it holds the findings a maintainer already looked at and rejected. An audit that never reads it re-raises them, and a second identical finding is how a maintainer learns to stop reading the report.

AUDIT-SPECIFIC:
- `ai/modules.md` — the module's row + its declared dependencies (an undeclared import is itself a finding).
- `ai/patterns/` — the patterns this module is supposed to follow. These are the **oracle each axis grades against**; an axis with no oracle produces opinions, not findings.

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

If a named agent is not installed in this project, perform that review inline against the corresponding pack/domain checklist — never silently skip the axis. **This matters more here than anywhere else in the pack:** only `api-reviewer` ships in the backend pack itself. The other five come from the database, performance, security, testing and code-quality packs, so on a backend-only install five of the six axes have no agent behind them. An axis with no agent and no inline pass is an axis that produced no findings — which is not the same as an axis that found nothing.

Wait for all; consolidate by severity (BLOCKER / REQUEST / NIT) and area.

Compute verdict — **coverage first, then blockers**:

| Condition | Verdict |
|---|---|
| Any axis neither dispatched nor covered inline | **INCOMPLETE** — name the uncovered axes explicitly. Do not report a blocker count as if it were the whole picture. |
| Every axis dispatched or covered inline, 0 blockers | Ready to extend. |
| Every axis dispatched or covered inline, 1+ blocker | Must fix or write an ADR before extending. |

A "0 blockers" read off a partial run is a manufactured pass — the same failure `/add-endpoint`'s production-readiness gate exists to prevent, and worse than a missing agent, because it looks like a green light.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-<module>-analysis.md` — full report.
- `ai/status.md` — Recent Changes entry with verdict + blocker count.
- `ai/dynamic/drift-log.md` — append findings categorized as `code-vs-rule`.
- `ai/modules.md` — update row's last-audited date.

## Phase 6 — Validate

- Self-audit: did every dispatched agent return? Missing agent = incomplete analysis.
- **Coverage ledger before the verdict.** One row per axis: `dispatched` / `covered inline` / `NOT COVERED`. Any `NOT COVERED` row forces verdict INCOMPLETE regardless of blocker count.
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

## Hard rules

- **Run BEFORE extending, not after.** Post-change analysis biases toward the diff.
- **Every BLOCKER cites file:line evidence.** "Architecture violation" without a path is a hypothesis.
- **A verdict states its coverage.** "Ready to extend" is a claim about six axes; it may only be made when all six were actually examined. Uncovered axes are named in the output, never averaged away.
- **A BLOCKER is fixed OR written into an ADR before extending.** "Acknowledged" alone doesn't count.
- **Cross-check findings to avoid duplicate reporting.** N+1 from perf-reviewer and missing-eager-load from schema-reviewer = one issue, not two.
- **Don't mark dead code dead without confirming it's not framework-magic loaded** (NestJS auto-discovered modules, Next.js auto-routed pages, Django apps registered in INSTALLED_APPS).
- **Coverage % is not quality.** A test-reviewer that says 95% but never asserts anything is failing the audit.
- **This command audits backend modules only.** It does not carry a frontend or mobile reviewer set and must not improvise one; a non-backend target halts and redirects (§ Premise). Naming twelve agents from four other packs would be the same manufactured coverage the verdict table exists to prevent.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the analysis findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (BLOCKERS — structural / coupling / layer-boundary / security-relevant problems that gate extending the module) → **SHOULD FIX** (REQUESTS — fix now unless you have a reason not to) → **OPTIONAL** (NITS — safe to defer) — each step carrying `<file:line>` + **Fix** (concrete — the named refactor / index / guard, never "consider X") + **Verify** (required on every MUST-FIX step; the test or re-check that proves it's closed), then the closing steps (re-run `/analyze-module` to confirm the verdict comes back clean, `/learn-from-task`, then extend the module). A clean run collapses to a single line ("No blockers — clear to extend"). The reader must never reassemble the next steps from the severity groups themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Running AFTER changes — confirmation bias on the diff. Run BEFORE.
- "Acknowledged blocker" without ADR — that's just ignoring it; require ADR file path in the verdict.
- Coverage % treated as quality — `test-reviewer` looks at assertions; 95% coverage of getter tests means nothing.
- Dead-code finding on dynamically loaded files (DI containers, framework auto-discovery) — false positive; verify before deletion.
- Re-running not scheduled — module clean today won't stay that way; re-audit on each significant change.
- Treated module size (LOC) as quality signal — large is not bad, complex is. Audit complexity per agent (cyclomatic / coupling), not LOC.

## Related

### Sibling commands — where the boundary falls
- `/fix-bug` — **closes what this command opens.** This run produces blockers and stops; it never edits code. Every BLOCKER either becomes a `/fix-bug` run or an ADR.
- `/add-endpoint` · `/add-module` — the work this audit gates. Run this BEFORE extending, not after; post-change analysis grades the diff instead of the module.
- `/trace-flow` · `/log-tail` — evidence sources when a static finding needs a runtime confirmation (an unmeasurable hot path, a suspected N+1 nobody can reproduce).

### Patterns
Patterns are read as the **oracle each axis grades against**, not as background:
- `ai/patterns/api-contract.md` + `error-handling.md` — the oracle for `api-reviewer`'s envelope and error-shape findings.
- `ai/patterns/multi-tenancy.md` — the oracle for the tenant-isolation axis on any module owning tenant-scoped tables.
- `ai/patterns/parallel-io.md` + `caching-strategy.md` — the oracle for `performance-optimizer`'s sequential-await and invalidation findings.

A pattern with no axis behind it produced no findings; listing it here would manufacture coverage the run did not have.

### Rules
- `.claude/rules/backend-principles.md`
- `.claude/rules/concurrency-discipline.md`
