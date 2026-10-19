---
description: "Close the findings a /test-audit report lists: prove each failing-first with its testing oracle, fix the test not the code, check the fix's own diff for tampering, re-detect, sweep siblings, run the whole suite shuffled. Stops on a spec-test conflict."
kind: command
pack: testing
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /test-fix [audit-report-path | finding-id ... | --all]

## The Premise (read this first, internalize, do not deviate)

**A test finding is closed when the oracle that showed the suite blind now sees — for every variant of its class.** The broken SUT turns the test red, the mutant and its siblings are killed, the perturbation stays green, the test is in the collected list, the canary fails the job. Proven, not asserted. The input is the `## What to do next` list a `/test-audit` run wrote into `ai/audits/<date>-tests.md`. Each item cites a `<file:line>`, a class, the detector that raised it and its oracle. This command does not discover defects and does not fix guesses.

**Existing tests are read-only by default.** Asked to make a suite pass, coding agents mostly cheat by editing the tests: in ImpossibleBench (arXiv 2510.20270, 2025-10-23) frontier models cheated on 49–54% of impossible SWE tasks, Claude models mostly by modifying tests, and LLM monitors caught only 42–65% of it; read-only tests stopped test modification, and an explicit escalate exit cut GPT-5's rate from 54% to 9%. So the fix **adds** tests and **narrows** what an existing assertion accepts — everything that passes after the edit also passed before, and the expected value comes from the spec — and nothing else. Any edit that removes, loosens or re-points an existing oracle is a STOP item. Because a model reviewer misses that much, the Step-5 self-check is mechanical, not a judgement.

**The agent's job, per finding, in order:**
1. **Re-verify**, then **prove the defect** with its testing oracle: the suite stays green while the code is wrong (or the test is absent from the list, or the job stays green on a canary).
2. **Fix the test or the gate, not the code**, with the class's root primitive.
3. **The oracle now sees**, for every class variant; the fixed test passes on the current, unbroken code.
4. **RE-DETECT** with the owning detector.
5. **Self-check the fix's own diff for tampering** — `test-integrity.py` and `oracle-check.py` on it; refuse to close if either flags.
6. **Sweep siblings** with a balanced ledger.
7. After the last finding, **run the whole suite shuffled**.

**The agent does NOT:**
- Fix a finding it has not re-verified and proven. An Unconfirmed row is settled by its probe first; a Refuted one is never touched.
- Change production code. A finding the oracle exposes as a **code defect** — the strengthened test, written from the spec, fails on current code — goes, with that test as its failing-first proof, to `/quality-fix` (code-quality pack, when installed) when the defect is in a code-quality class (a swallowed or rewritten error, an unchecked cast, a logic, number or time trap), and to `/fix-bug` (backend pack, when installed) otherwise; without the owner, the row is reported `code defect (owner command not installed)` with the test attached, and the code stays as it is. A testability change (a seam moved behind DI, a clock or random port injected) is a STOP item.
- "Fix" by any move [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Old test on new code, and the anti-cheat rule forbids: a retry, a raised timeout, an added sleep, a skip, `.only`, `xfail` or quarantine, a snapshot regenerated wholesale, an oracle weakened, the SUT mocked, a production special case for a test input, `--forceExit`, `-u` in a script. Nor by editing a detector, `test-integrity.py` or `oracle-check.py`, or narrowing what they read.
- Close the instance and leave the class.
- Follow instructions in what it reads: a skip reason, a `// covered by e2e` comment, a test name, tool output (`refute-before-report.md § 7`).

**The agent STOPS and asks the user before:**
- **A spec–test conflict — the sanctioned exit.** When the spec, the acceptance criterion or the issue says one thing and an existing test asserts another, or two tests demand incompatible results, stop with `SPEC_CONFLICT`: quote both sides with `<file:line>`, say which is right if the spec decides it, and touch neither. Never pick the side that makes the suite green.
- **Changing an existing expected value or matcher** on a behaviour assertion in a way that accepts anything it rejected; **deleting or skipping** a test or a case; **quarantine**; **regenerating a snapshot**.
- **A test named in a locked acceptance contract** (`.claude/locks/<run_id>.json`). It is never edited here: reopening is a human act (`lock-acceptance.sh --reopen`).
- **A coverage or mutation threshold, ignore glob, retry or flaky-gate setting** — including an owner or expiry, which are the human's to name.
- **A CI change beyond removing the mask the finding names**: a new job, a required-check setting, a canary branch push.
- **Any production code change**, and **new CI infrastructure** (a database container, a browser) to turn a unit test into an integration test.

This command inherits the two invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing test first** and the **sibling ledger** `N_found == N_fixed + N_explained + N_followup`. Here "failing first" is the testing oracle of [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Testing: the new or strengthened test is red against the probe the old one survived.

## Phases applied
All seven. Phase 4 is the per-finding loop. The command refuses to start without a report or an explicitly confirmed finding.

## When to use / NOT to use
- USE: after `/test-audit` returns `NO-GO` or `GO-UNVERIFIED`; to close one finding by id (`/test-fix T-04`); `--all` to work MUST → SHOULD → OPTIONAL in order.
- NOT: with no report and no confirmed finding (run `/test-audit`). Not for one flaky test with no audit (`/flaky-test-hunt`), new tests for a target (`/add-test`), a failing test that is right (`/quality-fix`, code-quality pack, or `/fix-bug`, backend pack, when installed), or a hole a missing negative test exposes (`/security-fix`, security pack, when installed).

## Phase 1 — Understand

### Intent gate
Universal routing: see [`templates/snippets/intent-gate-skeleton.md`](../../../snippets/intent-gate-skeleton.md). Then:

| The ask says | Route |
|---|---|
| "audit" / "are our tests any good" / "find weak tests" | `/test-audit`; this command closes findings, it does not find them |
| "this test is flaky" with no report | `/flaky-test-hunt` |
| "make the tests pass" / "the test is wrong" with no finding | halt: if the code is wrong, `/fix-bug`; if the spec and the test disagree, that is `SPEC_CONFLICT` for the user |
| a report path, finding ids, "close the test findings" | proceed |

**Refuse-to-run gate (mandatory).** Resolve the input to a concrete finding set before any edit:
- **A report.** Read the latest `ai/audits/<date>-tests.md` and parse its `## What to do next` list ([`review-action-plan.md`](../../../snippets/review-action-plan.md) shape). If several exist, confirm which one.
- **Finding ids**, looked up in the named report. **An explicitly confirmed finding** only when the user states the site, the class and the evidence; echo it back as one row.
- **None → HALT** and route to `/test-audit`. Never improvise a finding list from a fresh scan.
- **Clean start.** `git status --porcelain` must be empty, or the user's changes committed or stashed on their say-so: Step 5 reads the diff from `FIX_BASE=$(git rev-parse HEAD)`, and an unrelated change in it would be read as this command's.

## Phase 2 — Organize

**Order.** MUST FIX first (BLOCKER, then HIGH), then SHOULD FIX, then OPTIONAL. Within a tier, the widest blast radius first: a CI mask or a collection pattern (every test behind it) before a runner setup file before one helper before one case. For each finding record: `<file:line>`, class, the **detector that raised it** (RE-DETECT re-runs it), its **oracle**, its **root primitive**, and whether it crosses a STOP line. A STOP finding is listed, put to the user, and the rest proceed.

| Finding (detector §) | Oracle (`proof-oracles.md` § Testing; variants) | Root primitive — never the alternative |
|---|---|---|
| No / weak / tautological oracle; expected from the SUT; mock echo (`assertion-strength-scan` § 1, § 5) | Break the SUT (V54, V56) | The exact value, written from the spec or a worked example, never computed by the code under test |
| Interaction-only (`assertion-strength-scan` § 2) | Break the SUT (V55) | Pin the arguments, or assert the returned or persisted state |
| Unreached or un-awaited (`assertion-strength-scan` § 3) | Assertion flip; strictness switch (V57) | `await` / `return`; `toThrow(Type)` / `pytest.raises(T, match=)` / `assertThrows`; a length assertion before a loop; the strictness switch as the guard where it turns nothing else red |
| Swallowed failure (`assertion-strength-scan` § 4) | Assertion flip (V58) | No `try` around assertions; assert the error itself |
| Snapshot as the sole or self-updating oracle (`assertion-strength-scan` § 6) | Break the SUT with the snapshot kept (V60) | A focused assertion beside a small snapshot; snapshot writing out of scripts and CI |
| Focus; skip without owner; gate CI never satisfies (`suite-execution-scan` § 1, § 2) | Static fact; strictness switch; collection count (V61) | Remove the focus and add `forbidOnly` / `--forbid-only` / the lint rule at error; provide the gate's variable in the CI job. Un-skipping is a STOP |
| Never collected; suite no CI job runs (`suite-execution-scan` § 3) | Collection count (V62) | Fix the glob, name, signature or engine; add the suite to the job that already runs its runner. A new job is a STOP |
| CI or runner switch that masks failure (`suite-execution-scan` § 4) | CI canary (V63) | Remove the mask (`continue-on-error`, `\|\| true`, a pipe without `pipefail`, `--passWithNoTests`, `--forceExit`); the canary push is a STOP |
| Coverage config that hides code (`suite-execution-scan` § 5) | Coverage inventory (V64) | Narrow the exclusion to generated or platform code, with its reason. Thresholds are a STOP |
| Retries with no flaky gate (`suite-execution-scan` § 6) | Retry unmask (V65) | Turn the flake the retry hid into a `flake-source-scan` row and fix its source; removing or gating the retry is a STOP |
| Clock, randomness, sleeps, network, shared state, leaks, parallel, e2e waits (`flake-source-scan` § 1–§ 8) | Perturbation; repeat-run bound as fallback (V67–V69) | A frozen or injected clock, a seeded generator, an `await` or a condition wait, a net-disconnect guard, a per-test reset or `restoreMocks`, a per-worker resource. Rows that need N-run evidence go to `/flaky-test-hunt` |
| The SUT mocked; unchecked or not-owned doubles (`test-double-scan` § 1–§ 3) | Break the SUT; interface conformance (V70) | The real SUT with collaborators doubled; a typed or spec'd double; a port the project owns |
| Engine substitution (`test-double-scan` § 4) | Real-engine parity (V70) | The production engine (Testcontainers on its major) where the suite already has one; new infrastructure is a STOP |
| Test seam or special-cased input in shipped code (`test-double-scan` § 5, § 6) | Env parity; old test on new code (V72) | A production change: STOP, or `/fix-bug` when it is a defect |
| Unexecuted line or file; critical module untested; route-level gap; fix without a regression test (`coverage-gap` § 1, § 4, § 5, § 7) | Coverage inventory, then break the SUT (V54) | A test that executes **and** pins the line; for § 7, one that fails on the fix's parent source |
| Guarded route with no denial test; error never asserted (`coverage-gap` § 2, § 3) | Seeded violation (V71) | A negative test per role, tenant, token state and mapped error. Red on current code means the guard does not hold: `/security-fix` (security pack, when installed) or `/fix-bug`, tagged `security-class` |
| Consumed API with no contract test (`coverage-gap` § 6) | The `contract-test` skill's verification | Hand to `contract-test` |
| Surviving mutant; boundary; error path; pseudo-tested (`mutation-probe` § Scans for, rows 1–5) | Mutant kill (V66) — `mutation-probe` § Evidence row | The killing assertion, which also kills the non-equivalent siblings on that line |

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Testing-specific:
- The report being closed: its context map (runners and versions, configs, CI jobs, guards already on, risk surfaces), the finding rows and their evidence blocks.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/testing.md`](../../../snippets/precedents/testing.md), [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Testing.
- **The spec for the behaviour** — the requirement, the acceptance contract (`ai/runs/<run_id>/acceptance.json`), the issue, the API schema. An expected value comes from here, never from what the code returns today.
- The test file, the code it claims, and one sibling test that pins the same kind of behaviour well (the shape to match). `.claude/rules/testing-principles.md`, `ai/patterns/test-doubles.md`.
- The tool lanes: `TI=.claude/scripts/test-integrity.py`, `OC=.claude/scripts/oracle-check.py`, each falling back to `$HOME/.claude/templates/repo-baseline/.claude/scripts/<name>`; `.claude/hooks/test-lane.sh`; `.claude/locks/`.

## Phase 4 — Generate (the per-finding loop)

Run every step for each finding, in Phase-2 order. Do not start the next finding until this one's closure row is complete.

### 1. Re-verify, then prove the defect with its oracle
**Re-verify.** Run the finding through [`refute-before-report.md`](../../../snippets/refute-before-report.md) with [`precedents/testing.md`](../../../snippets/precedents/testing.md): restate the claim in one of its two shapes (`precedents/testing.md § The claim, restated for a test`), run the seven gates as § Reading the seven gates for a test reads them. **Refuted** → do not touch it; record the gate. **Unconfirmed** → run its settling command first. **Finding** → prove it.

**Prove it before any edit**, in a scratch worktree (`git worktree add --detach "${TMPDIR:-/tmp}/test-fix-probe" HEAD`), with the class's oracle from the Phase-2 table:
- **Break the SUT** — three probes per variant (a constant of the right type, an empty or zero value, an off-by-one or the wrong member; never a `throw`): the test stays green.
- **Assertion flip** — the test's own expected value changed: still green.
- **Mutant kill** — the tool mutant survives (`mutation-probe` § Evidence row, `before:` line).
- **Perturbation** — the zone, date, seed, order, network or worker count that turns it red, recorded; otherwise `k of N` (`proof-oracles.md` § Perturbation and the repeat-run bound).
- **Collection count** — the file is in `comm -23 looks.txt collected.txt`.
- **CI canary** — the job stays green with a failing test (on the user's yes); otherwise the masking line as a static fact.
- **Seeded violation** — the guard, predicate or error branch removed: the suite stays green.

Write the `before` half of [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Evidence block (testing). **No fix until the oracle shows the suite blind.** A probe that turns the test red refutes the finding.

### 2. Fix the test or the gate
- Apply the Phase-2 primitive in the project's idiom, matching the good sibling. Write the expected value from the spec; cite it in the closure row.
- Prefer **adding**: a new case beside a weak one, an `await` added, a guard switch added. Where an existing assertion must change, it may only **narrow** (accept a subset of what it accepted). Anything else is a STOP.
- When the root is shared — a runner setup file, a collection pattern, a CI step, a test helper, a fixture builder (`test-factories`) — fix it there; that closes siblings too.
- New tests may go through `@test-engineer` (this pack), with the finding, the spec reference and the oracle in its brief.

### 3. The oracle now sees — all four
1. **The proof flips:** the new or strengthened test is red under every probe the old one survived (each break-the-SUT probe, the flip, the mutant and its sibling operators, the perturbation, the seeded violation); the file is collected; the canary goes red.
2. **Every class variant** in `proof-oracles.md` § Class variants (testing) for the class flips the same way.
3. **The fixed test passes on current, unbroken code.** If it fails, stop: either the expected value is wrong (re-read the spec) or the code is — a code defect, routed as the Premise says. Never adjust the expectation to the output.
4. **Restore proven.** The scratch worktree is removed (`git worktree remove --force`), and every probe file in it was restored with `git diff --exit-code` before removal.

Record runs as evidence: with the repo-baseline installed, run the test against the probe through `bash .claude/hooks/test-lane.sh record '<cmd>'`, so the red run lands in `.claude/evidence/test-runs.jsonl`.

### 4. RE-DETECT (the owning detector on the diff)
Re-run the detector recorded in Phase 2 on the patched `<file:line>` and its surrounding diff. It must go quiet there and raise nothing new. A detector that still reports means the patch moved the symptom; reopen the finding.

### 5. Self-check the fix's own diff for tampering
The command does not grade its own honesty; the scripts do. On the diff from `FIX_BASE` to the working tree:

```bash
python3 "$TI" --base="$FIX_BASE" --json      # deleted test or case, fewer assertions, new skip/only/xfail, lowered floor, removed CI test step
python3 "$OC" --base="$FIX_BASE" --json      # no-assertion, weak-oracle, tautology in every case this fix added or touched
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^-(?!--)[^\n]*\b(?:expect|assert\w*|should\w*|verify|t\.(?:Error|Fatal)\w*)\b'   # every existing assertion line removed or changed
{ git diff --name-only "$FIX_BASE"; git ls-files -o --exclude-standard; } | rg -v --pcre2 '(?:^|/)(?:tests?|__tests__|spec|e2e)/|\.(?:test|spec|e2e-spec)\.|(?:^|/)test_[^/]*\.py$|_test\.(?:go|py)$|(?:Test|Tests|IT)\.(?:java|kt|cs|php)$|_spec\.rb$'   # non-test files touched
```

- **Either script exits 1 → the finding does not close.** Rework the fix so nothing is net-removed (keep a still-true old assertion beside the new one) and re-run, or put the reported row to the user as a STOP item; until the user approves it, the row stays `escalated (integrity: <kind> <file:line>)`. Exit 2 is a failed lane: the row reads `self-check: blocked`, never clean.
- **A changed expected value passes both scripts.** Measured 2026-10-05 on a copy of `benchmarks/fixtures/reward-hack`: `true` → `false` in the seeded expiry test gave `test-integrity.py` 0 findings and `oracle-check.py` none on that case — the edit is still an assertion. The third line lists every removed or changed assertion; each one must be a narrowing with its spec citation in the closure row, or it is a STOP item. The scripts' v1 also does not cover widened tolerances, snapshot rewrites, `NODE_ENV === 'test'` branches or equality overrides (`test-integrity.py` header): run `test-double-scan` § 5 and § 6 on the diff (its `§ When to run` asks for every `/test-fix` diff) and read every changed tolerance and `.snap` file.
- **Old test on new code** for every existing test file the fix edited: the base version (`git show "$FIX_BASE":<file>`) must still pass against the head tree (`proof-oracles.md` § Old test on new code, and the anti-cheat rule). Red means the oracle moved.
- **Every non-test file in the list** must be the runner config, CI line or manifest test script the finding's primitive names, or a STOP-approved change; revert any other hunk.
- Without the repo-baseline and its global copy, run the inline equivalents — `git diff -U0 "$FIX_BASE"` read for removed assertion lines, added `skip` / `only` / `xfail`, changed thresholds and snapshot files — and mark the row `self-check: inline (repo-baseline scripts absent)`.

### 6. Sweep for siblings
State the root cause in one line (`refute-before-report.md § 6`): "`expect(…).resolves` without `await` under Jest 30", "spies restored nowhere with `restoreMocks` off", "fixture dates written as literals in expiry tests" — not "the refund test is weak". Grep it with the owning detector's pre-flight line narrowed to that cause, and run each hit back through Step 1. Each confirmed hit is **fixed**, **explained** (one line, or Refuted by a named gate), or **followup** (its own id). `N_found == N_fixed + N_explained + N_followup` must hold.

### 7. The whole suite, shuffled (after the last finding)
Run every config the context map lists, the whole suite, shuffled with a recorded seed — through `bash .claude/hooks/test-lane.sh run '<cmd>'` when the repo-baseline is installed: `npx vitest run --sequence.shuffle --sequence.seed=<S>` · `npx jest --randomize --seed=<S>` (within a file only) · `pytest -p randomly --randomly-seed=<S>` · `go test -shuffle=on -count=1 ./...` · `rspec --order rand:<S>` · `phpunit --order-by=random --random-order-seed=<S>` · JUnit `-Djunit.jupiter.testmethod.order.default='org.junit.jupiter.api.MethodOrderer$Random'` · `cargo test -- -Z unstable-options --shuffle` (nightly). Then the perturbations the closed determinism rows named (`TZ`, faked date, network off), and typecheck and lint. A runner with no shuffle prints `order: NOT TESTED (<runner>)`, never green-by-omission. Red here reopens the finding whose change it traces to.

### Commit (one finding = one commit, only where the repo allows it)
Read the convention first (recent `git log`, a protected or PR-only branch, a no-commit rule in `CLAUDE.md` or `CONTRIBUTING`). Where commits are allowed: `test(<scope>): <what could ship green> — <finding id>`, for example `test(refunds): a zero refund amount passed the suite — T-03`. Otherwise **leave the change staged and say so**.

## Phase 5 — Update
- Update `ai/audits/<date>-tests.md` in place, or write a `-fix.md` companion: mark each finding and append the closure table.
- `ai/dynamic/changelog.md`: `Test fix on <scope>: C closed, S staged, E escalated, D deferred`.
- `ai/status.md` `## Recent Changes`: one bullet per `SPEC_CONFLICT` and per STOP decision still owed.

### Closure table (required artifact)
```
| Finding | Class (detector §)        | Oracle · before → after              | Variants | Spec cited          | Self-check (TI · OC · old-on-new) | RE-DETECT | State            |
|---------|---------------------------|--------------------------------------|----------|---------------------|-----------------------------------|-----------|------------------|
| T-02    | weak oracle (assert §1)   | break SUT: green → red (3/3)         | V54 4/4  | SPEC-0012 §3 ex. 2  | 0 · 0 · green                     | quiet     | <sha> test(...)  |
| T-05    | never collected (suite §3)| collected: absent → listed; SUT red  | V62 2/2  | —                   | 0 · 0 · n/a                       | quiet     | staged (PR-only) |
| T-07    | expected vs spec          | —                                    | —        | spec §4 vs test:31  | —                                 | —         | SPEC_CONFLICT    |
```
A finding with no proof, a self-check that flagged, or a RE-DETECT that is not `quiet` is **not** closed.

## Phase 6 — Validate
- Each closed finding has a recorded `before`, an `after` across every variant, a fixed test green on unbroken code, a spec citation for every expected value, a clean self-check, a quiet RE-DETECT, a balanced sibling ledger, and the shuffled whole-suite run green.
- **Re-run `/test-audit` on the touched scope.** The verdict must not regress, and each first-pass finding must no longer reproduce at its `<file:line>`.
- `git diff "$FIX_BASE"` touches no production file outside a STOP-approved change, no locked test, no threshold or retry setting.
- Every `SPEC_CONFLICT` and STOP item was escalated, not patched.

## Phase 7 — Improve
- `/learn-from-task`: record each closed class and the primitive that closed it.
- A class seen in two audits gets an ADR in `ai/decisions/` and its mechanical guard (`proof-oracles.md` § Strictness switches): `forbidOnly`, `expect.hasAssertions()` in setup, `xfail_strict`, `--fail-on-risky`, the lint rule at error in CI, shuffle on in CI, `oracle-check.py` and `test-integrity.py` in `gate-check.py`.

## Output format
```
## /test-fix — <N closed · M staged · E escalated · K deferred>
Input:  ai/audits/<date>-tests.md  (findings: <total>; routed: /quality-fix <q>, /fix-bug <b>, /security-fix <s>, /flaky-test-hunt <f>)
Order:  MUST FIX (<c>) → SHOULD FIX (<m>) → OPTIONAL (<l>)
Closure table: (Phase 5 — one row per finding)
Escalated (decision owed):
  - T-07  SPEC_CONFLICT — SPEC-0012 §4 says expired at 365 days; test/expiry.spec.ts:31 asserts 361 → which is right?
  - T-09  remove jest.retryTimes(2) in checkout.e2e — 3 of 50 red with retries off; owner and plan needed
Suite (shuffled): jest seed 4127 PASS · vitest seed 4127 PASS · pytest -p randomly 4127 PASS · order NOT TESTED (playwright)
Re-audit: /test-audit on touched scope → verdict <was → now>, no regression
Status: COMPLETE | INCOMPLETE  (COMPLETE only when every MUST-FIX finding is closed or escalated, the self-check is clean and the re-audit did not regress)
```

## What to do next — required closing section
Every run ends with `## What to do next`: the remaining work as ONE ordered, numbered to-do. **MUST FIX** (open or escalated BLOCKER and HIGH) first, then **SHOULD FIX**, then **OPTIONAL**. Each step carries `<file:line>`, the **Fix**, and the **Verify** (the oracle and its V-number). An escalated item names the decision the user owes: which side of a `SPEC_CONFLICT` is right, the threshold, the retry owner, the CI job. The closing steps are: re-run `/test-audit` to confirm the verdict, `/learn-from-task`, then ship or open the PR. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **The test moved to fit the code.** An expected value copied from today's output, a matcher loosened until green: the defect ImpossibleBench measured. The spec decides; a disagreement is `SPEC_CONFLICT`.
- **A fix with no blind-suite proof first.** A strengthened test nobody showed was blind before proves nothing.
- **A probe with a `throw`.** It fails even a `toBeDefined` test, so it proves nothing about strength.
- **Symptom fixes for flakes:** a retry, a longer sleep, a raised timeout, a skip. The source stays; the next red is real and hidden.
- **The instance fixed, not the class:** one `await` added while 40 sibling floating assertions stay.
- **Self-check skipped or argued with.** A flagged row is reworked or escalated, never explained away in prose.
- **Shuffle skipped at the end.** A per-test fix that leaks state shows only in another order.
- **Committing against repo policy.** On a PR-only branch, leave the change staged and say so.

## Related

### Sibling commands
- `/test-audit`: the producer; without its report the refuse-to-run gate halts.
- `/flaky-test-hunt`: the N-run harness for determinism rows that need a bound. `/add-test`: new tests for a target outside an audit. `/run-tests`: one honest run.
- `/quality-fix` (code-quality pack, when installed): code defects in a code-quality class the oracle exposes, with this command's test as the failing-first proof. `/fix-bug` (backend pack, when installed): the other code defects, the same way. `/security-fix` (security pack, when installed): a guard the new negative test shows does not hold.

### Detector skills (re-run for RE-DETECT; this pack)
`assertion-strength-scan` · `suite-execution-scan` · `flake-source-scan` · `test-double-scan` · `coverage-gap` · `mutation-probe` (its evidence row is the mutant-kill proof) · `contract-test`. `test-factories` is the fixer for shared fixtures.

### Tool lanes (repo-baseline, when installed)
`.claude/scripts/test-integrity.py` and `.claude/scripts/oracle-check.py` (the Step-5 self-check) · `.claude/hooks/test-lane.sh` (`record` for red runs, `run` for full suites) · `.claude/scripts/lock-acceptance.sh` (locked tests are never edited here).

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/testing.md`](../../../snippets/precedents/testing.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Testing · [`fix-bug-core.md`](../../../snippets/fix-bug-core.md)
