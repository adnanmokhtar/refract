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
- **Stack mismatch — halt, do not re-aim.** A frontend feature directory or mobile screen module is not this command's reviewer set, and this command does not own the right one. Halt and redirect to that pack's audit when it is installed; say so plainly when it is not. A backend audit re-labelled reports six green axes it never examined.
- A BLOCKER cites a file:line that is dynamically loaded (DI auto-discovery, Next.js auto-routing) and may be a false positive — confirm before reporting.

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

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = the consolidated report; no code changes here. Phase 5 records the audit; Phase 7 feeds repeat-finding patterns.

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

ALWAYS (universal pre-flight): see `templates/snippets/phase-3-always-reads.md`.

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

## Hard rules

- **Run BEFORE extending, not after.** Post-change analysis biases toward the diff.
- **Every BLOCKER cites file:line evidence.** "Architecture violation" without a path is a hypothesis.
- **A verdict states its coverage.** "Ready to extend" is a claim about six axes; it may only be made when all six were actually examined. Uncovered axes are named in the output, never averaged away.
- **A BLOCKER is fixed OR written into an ADR before extending.** "Acknowledged" alone doesn't count.
- **Cross-check findings to avoid duplicate reporting.** N+1 from perf-reviewer and missing-eager-load from schema-reviewer = one issue, not two.
- **Don't mark dead code dead without confirming it's not framework-magic loaded** (DI containers, auto-discovered modules, auto-routed pages).
- **Coverage % is not quality.** A test-reviewer that says 95% but never asserts anything is failing the audit.
- **Stack-aware reviewer dispatch.** Backend reviewers on frontend modules produce noise; pick the right set.

## Failure modes

- Running AFTER changes — confirmation bias on the diff. Run BEFORE.
- "Acknowledged blocker" without ADR — that's just ignoring it; require ADR file path in the verdict.
- Coverage % treated as quality — `test-reviewer` looks at assertions; 95% coverage of getter tests means nothing.
- Dead-code finding on dynamically loaded files (DI containers, framework auto-discovery) — false positive; verify before deletion.
- Re-running not scheduled — module clean today won't stay that way; re-audit on each significant change.
