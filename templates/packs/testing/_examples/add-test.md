---
description: Add tests for a target file or feature, mirroring the repo's test framework and style.
---

# /add-test [target]

Build command. Generates unit + integration + (optional) e2e tests using project conventions. Runs them green before reporting. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Existing tests are the truth. Mirror sibling test shape: same fixture pattern, same assertion style, same setup/teardown.** The repo already has a runner, a fixture convention, an arrange/act/assert idiom, a way to mock HTTP, a way to spin up the DB, and a filename scheme. New tests do not get to invent a new style — they copy the closest sibling. Convention drift in tests is convention drift in the codebase.

**The agent's job is exactly this:** resolve the target file / feature; find the closest sibling test in the same module (or failing that, the same layer) and read it line-by-line; **mirror its shape** — same imports, same nesting, same fixture builder, same mock boundary, same teardown, same filename scheme; generate the tests, run them green, and report the mirroring evidence.

**The agent does NOT:** pick a different runner from the one in use; introduce a new fixture-builder pattern when one exists; use sleep-style waits when the codebase already uses fake timers; mock at a different boundary than siblings; or leave `.only` / `.skip` in committed files.

**Closure verbs (mandatory per generated test file):** `mirror-sibling` (shape copied, sibling path cited in the run summary), `extend-sibling` (sibling lacked the needed layer; shape still mirrored, the layer-specific addition justified), `bootstrap-new-module` (no sibling in the module or layer — consult `ai/patterns/test-strategy.md` plus the project's gold-standard test of that kind and mirror it; halt if neither exists and ask the user to point at one).

**Mechanical halt (sibling-shape parity).** Before declaring a test file done, verify parity with its mirror source on every axis: runner, filename scheme, import style, describe nesting, fixture pattern, mock boundary, teardown, assertion style. Any axis that diverges WITHOUT a written justification HALTS the run — "I thought my version was cleaner" is exactly the noise this rule kills.

**Lightweight default:** if exactly one sibling exists in the module, mirror it 1:1 and skip the gold-standard lookup. If 2+ siblings disagree, pick the most recent + most-imported one and cite the choice.

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

## Phase 6 — Validate (production-grade or INCOMPLETE)

**A green suite is FUNCTIONAL, not production-grade.** Line coverage is the FLOOR, never the bar. A generated test is production-grade only when it (1) **FAILS when the behaviour breaks** — mutation-verified, not coverage theatre — (2) covers the branch's real edges/invariants, and (3) is **deterministic** across reruns. This phase measures all three and picks the terminal verdict.

- **Determinism proof:** run the new files 3× back-to-back — identical pass set each run. Any file whose result flips is non-deterministic → name it; do NOT report it green. Previously-green tests still green.
- No `setTimeout` waits (use fake timers). No `.skip` / `.only` left in the file. No real external HTTP in unit tests — use the project's HTTP-faking primitive. Naming mirrors existing convention exactly.

**Effectiveness gate — mutation-verified. Measure effectiveness; do not assert it.** A green assertion proves nothing until a mutation of the branch it covers makes it go RED.
  1. **Harness present** — run the project's mutation tool scoped to the changed SUT (its `--since` / changed-files mode). Every survivor on a branch your new tests own is an assertion gap: add the assertion, re-run, confirm the mutant now dies. Record the **measured mutation score on the changed scope**, equivalent mutants excluded from the denominator.
  2. **No harness** — seed the mutant by hand. For **each core branch per generated file**, mutate the SUT one operator at a time (flip the comparison, return the wrong value / `null`, short-circuit the guard), re-run the covering test, confirm it goes **RED**, then **restore the SUT** and confirm GREEN. This proves one branch per file, not the whole scope — label the file `manual-seed`, not `harness-measured`.
  - **Self-policed:** no shell verifies the SUT was reverted or that RED was really observed. Leaving a mutation in place is a worse bug than a weak test. What IS checkable is the per-file ledger below.
  - **HALT — assertion theatre:** if the test stays GREEN while its branch is mutated, the assertion is coupled to incidental state, not behaviour. Tighten it until the mutant dies, then restore. Do NOT count a survived mutant as done.

**Effectiveness closure verbs (exactly one per generated file):**
- `mutation-killed` — a seeded or harness mutant on the file's core branch was demonstrably killed (RED observed, SUT restored). Cite `<sut-file:line>` + the mutation operator + the test that went red.
- `effectiveness-unverified` — the mutant could not be seeded or the harness could not run for this file. The file ships marked UNVERIFIED — never silently as killed.

**Terminal verdict (there is no blanket COMPLETE):**
- **PRODUCTION-GRADE** — every generated file is `mutation-killed`, deterministic across the 3× rerun, and its edges/invariants are covered.
- **INCOMPLETE** — a production requirement is unmet. NAME each: surviving mutant `<sut-file:line>` + the assertion to add, an uncovered boundary, or a file that flipped on rerun.
- **UNVERIFIED** — effectiveness could not be measured for one or more files; name those files. Never a faked pass.

## Phase 7 — Improve
- `/learn-from-task` — capture test-shape patterns introduced.
- If same test setup boilerplate repeats 3+ times → queue to `ai/dynamic/learned-patterns.md` as a candidate fixture/helper.
- If the gap was systemic — several modules missing tests on the *same* axis (every error path, or one whole layer) → queue ADR: gate CI on a coverage **ratchet** (fail on a drop below the number the repo already measures), never on a borrowed absolute. A threshold nobody measured either fires on everything and gets muted, or fires on nothing.

## Output format
```
## /add-test — <N> files, <C> cases — <PRODUCTION-GRADE | INCOMPLETE | UNVERIFIED>

Phase 1 (Understand): target = <file|feature>; layers = <unit|integration|e2e>
Phase 3 (Retrieved): siblings mirrored; runner = <jest|vitest|pytest|...>
Phase 4 (Generated):
  <source-root>/orders/<test-dir>/create-order.<test-ext> (unit, 12 cases)
  <source-root>/orders/<test-dir>/order-repo.integration.<test-ext> (integration, 6 cases)
  <e2e-root>/orders.e2e.<test-ext> (e2e, 5 cases)
Phase 5 (Updated): changelog; coverage 64% → 89% (floor, not the bar)
Phase 6 (Validated): effectiveness ledger per file —
  create-order.<test-ext>      mutation-killed  (<sut-file:line>, `>=` → `>`, "rejects zero-qty order" went RED)
  order-repo.integration.<ext> effectiveness-unverified (no harness; SUT not safely revertible in-loop)
  determinism: 3× rerun identical
Phase 7 (Improved): patterns queued

Status: UNVERIFIED — order-repo.integration.<ext> effectiveness not measured
  # OR: PRODUCTION-GRADE — every file mutation-killed, deterministic, edges covered
  # OR: INCOMPLETE — <surviving mutant / uncovered boundary / flipped file, each named>
```

## Failure modes
- Tests assert internal calls instead of behavior → brittle; rewrite to assert outputs.
- Adding tests that pass against the buggy code → wrong; reproduce bug first, fix second.
- Real network / filesystem in unit tests → flakiness incoming; mock at HTTP / FS boundary.
- `setTimeout` waits → fake timers (`jest.useFakeTimers()` / `vi.useFakeTimers()`).
- `.only` / `.skip` left in committed file → CI silently skips other tests; reviewer-blocker.
- E2E added when integration would suffice → slow + flaky; only when user-facing flow is uncovered.
