---
description: Add tests for a target file or feature, mirroring the repo's test framework and style.
---

# /add-test [target]

Build command. Generates unit + integration + (optional) e2e tests using project conventions. Runs them green before reporting. All 7 phases apply.

## When to use / NOT to use
- USE: new code shipped without tests.
- USE: bug fix needs a regression test (after `/fix-bug` reproduces it).
- USE: coverage gap surfaced by `/check-health`.
- NOT: prototypes flagged P0/exploratory — tests on throwaway code = waste.
- NOT: as a substitute for `/fix-bug`'s failing-test-first step — that flow generates the regression test inline.

## Phase 1 — Understand
- Resolve target: file path, feature name, or interview if no arg.
- Confirm test layer goal: unit (pure logic) / integration (DB/persistence) / e2e (user flow). Default = mirror what siblings have.

## Phase 2 — Organize
- Read target file: signatures, dependencies, control flow, error branches.
- Identify which sibling test to mirror (same module preferred).
- Decide test framework from `jest.config.*`, `vitest.config.*`, `pytest.ini`, `go test`, etc.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Test-specific:
- 1-2 sibling tests in the same module — copy style verbatim (`*.spec.ts` vs `*.test.ts`, `__tests__/` vs adjacent).
- Test config (runner, setup files, fixtures, testcontainers).
- `ai/patterns/test-strategy.md` if present.

## Phase 4 — Generate
- Dispatch `test-engineer` to produce the plan: cases, layer (unit / integration / e2e), fakes vs real.
- Generate test files:
  - **Unit** — pure logic, mocked deps. One file per use-case / service.
  - **Integration** — real DB via testcontainers or in-memory equivalent. Only for repository / persistence layers.
  - **E2E** — Playwright / Cypress / supertest, only if the flow is user-facing AND uncovered.
- Run them: `<runner> path/to/new-tests`.
- Iterate until green.

## Phase 5 — Update
- `ai/dynamic/changelog.md` — one-line: `Added <N> test files for <module>, <C> cases, coverage <X>% → <Y>%`.
- `ai/modules.md` — bump test-coverage column if tracked.

## Phase 6 — Validate
- All new tests pass; previously-green tests still green.
- No `setTimeout` waits (use fake timers).
- No `.skip` / `.only` left in the file (reviewer-blocker).
- No real external HTTP in unit tests (`msw` / `nock` / framework HTTP test client).
- Naming mirrors existing convention exactly.

## Phase 7 — Improve
- `/learn-from-task` — capture test-shape patterns introduced.
- If same test setup boilerplate repeats 3+ times → queue to `ai/dynamic/learned-patterns.md` as a candidate fixture/helper.
- If coverage gap was systemic (multiple modules at < 60%) → queue ADR: enforce coverage threshold in CI.

## Output format
```
## /add-test — <N> files, <C> cases, all green

Phase 1 (Understand): target = <file|feature>; layers = <unit|integration|e2e>
Phase 3 (Retrieved): siblings mirrored; runner = <jest|vitest|pytest|...>
Phase 4 (Generated):
  src/orders/__tests__/create-order.spec.ts (unit, 12 cases)
  src/orders/__tests__/order-repo.integration.spec.ts (integration, 6 cases)
  e2e/orders.e2e.spec.ts (e2e, 5 cases)
Phase 5 (Updated): changelog; coverage 64% → 89%
Phase 6 (Validated): green; no .only/.skip; no real HTTP
Phase 7 (Improved): patterns queued

Status: COMPLETE
```

## Failure modes
- Tests assert internal calls instead of behavior → brittle; rewrite to assert outputs.
- Adding tests that pass against the buggy code → wrong; reproduce bug first, fix second.
- Real network / filesystem in unit tests → flakiness incoming; mock at HTTP / FS boundary.
- `setTimeout` waits → fake timers (`jest.useFakeTimers()` / `vi.useFakeTimers()`).
- `.only` / `.skip` left in committed file → CI silently skips other tests; reviewer-blocker.
- E2E added when integration would suffice → slow + flaky; only when user-facing flow is uncovered.

## Related

### Sibling commands in testing pack
- `/flaky-test-hunt` — sibling command in testing pack

### Patterns
- `ai/patterns/test-doubles.md`
- `ai/patterns/test-strategy.md`

### Rules
- `.claude/rules/testing-principles.md`
