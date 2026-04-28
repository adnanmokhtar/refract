---
name: test-reviewer
description: Reviews tests — coverage of behavior, quality of assertions, flakiness, mock correctness, meaningful regression catches. Framework-agnostic.
---

# Test Reviewer

## Pre-flight

1. Read `CLAUDE.md` + `ai/conventions.md` + `ai/patterns/test-strategy.md` + `test-doubles.md`.
2. Detect test framework + style from existing tests.
3. Read the tests under review + the code they cover.

## Checklist

### Coverage of behavior (not lines)

- Every business rule branch has a test?
  - Happy path.
  - At least one error path per typed error.
  - Boundary conditions (empty, null, max, min, TZ edges).
- Bug fix → is there a REGRESSION test?
- Multi-tenant code → is there a cross-tenant leak test?
- Webhook code → idempotency + signature tests?
- Auth changes → unauthorized access tests?

Grep for changes that lack tests:
```bash
# Changed files without corresponding test files
git diff --name-only <base>..HEAD | grep -v test | while read f; do
  # does a matching *.spec.* / *.test.* exist?
done
```

### Quality of assertions

- Test names describe BEHAVIOR, not method names. ✓ "rejects empty cart" ✗ "test1".
- Arrange / Act / Assert visible (blank lines or comments).
- ONE concept per test (exceptions for grouped invariants).
- Asserting on observable output, not implementation details.

### Mock correctness

- Mocks at PORT boundaries, not internal functions:
  ```
  ✓ OK:   mock the EmailClient interface
  ✗ BAD:  mock internal `formatDate` helper
  ```
- Fakes used for stateful deps (in-memory repo > mocked methods returning canned values).
- Mock return values match REAL behavior (not "whatever makes the test pass").
- No partial mocks (half real, half canned).

### Flakiness

- No `sleep()` / fixed timeouts for async waits.
- No `Date.now()` / `Math.random()` / `UUID()` unfrozen.
- No shared state between tests.
- No reliance on execution order.
- Polling uses bounded `waitFor` helper, not raw `setInterval`.

### Dangerous patterns

- `.skip` without a tracked reason → flag.
- `.only` checked in → BLOCKER.
- Commented-out assertions → flag.
- `expect(true).toBe(true)` / similar always-pass → BLOCKER.
- Test with no assertion (just runs the code) → flag.

### Structural

- Test file name matches source file: `user.service.ts` ↔ `user.service.spec.ts`.
- Test folder matches source (or colocated per repo convention).
- Fixtures in `test/fixtures/` (or project convention), not inlined.
- Shared test utilities in `test/helpers/`.

### Parallel + isolation

- Tests safe to run in parallel? (No shared DB state, no shared port, no shared file.)
- Integration tests: worker-isolated DB / truncate per test / tx-rollback per test.
- E2E: browser context isolation.

### Coverage metric

- Line coverage acceptable (per project — usually 70-80% for business logic).
- Branch coverage tracked (more meaningful than line).
- Uncovered business branches flagged.
- Uncovered trivial (getters, plain DTOs) fine.

### Mutation testing (if project uses it)

- Mutants killed rate > 70%.
- Surviving mutants = tests aren't actually verifying the behavior (common: asserting on side effects but missing the main output).

## Flag patterns (examples)

### BLOCKER — test doesn't catch the bug it claims to
```
src/modules/orders/__tests__/list-orders.spec.ts:18

it('filters by tenant', async () => {
  await service.listOrders('tenantA');
  expect(service.listOrders).toHaveBeenCalledWith('tenantA');  // ← asserts a CALL, not BEHAVIOR
});

Impact: test passes even if the filter is broken.
Fix:
  it('filters by tenant', async () => {
    await seed({ tenantId: 'A', amount: 100 });
    await seed({ tenantId: 'B', amount: 200 });
    const result = await service.listOrders('tenantA');
    expect(result).toHaveLength(1);
    expect(result[0].amount).toBe(100);
  });
```

### BLOCKER — flaky (timing-dependent)
```
src/modules/jobs/__tests__/delayed-job.spec.ts:24

await jobQueue.schedule(job, 100);
await sleep(200);                         // ← flake bomb
expect(await jobRepo.find()).toHaveLength(1);

Impact: fails randomly on slow CI.
Fix: use fake timers, advance time, then assert.
  jest.useFakeTimers();
  await jobQueue.schedule(job, 100);
  jest.advanceTimersByTime(100);
  await Promise.resolve();  // flush microtasks
  expect(await jobRepo.find()).toHaveLength(1);
```

### REQUEST — missing regression test
```
PR fixes "webhook fires reply twice on retry".

src/modules/webhooks/__tests__/ — no new test file.

Impact: bug can regress silently.
Fix: add idempotency test:
  it('does not re-process a retried webhook', async () => {
    const payload = { messageId: 'abc-123', ... };
    await handler.process(payload);
    await handler.process(payload);  // retry
    expect(await messageRepo.find()).toHaveLength(1);
  });
```

### REQUEST — mock returning whatever
```
src/modules/ai/__tests__/generate-reply.spec.ts:42

  claudeClient.reply.mockResolvedValue({ text: 'ok' });

Fake `{ text: 'ok' }` doesn't reflect real Claude responses (includes tokens, etc.).
Tests pass but missing-field bugs slip through.

Fix: use a realistic fixture or a minimal fake that returns the full shape:
  claudeClient.reply.mockResolvedValue({
    text: 'ok', inputTokens: 100, outputTokens: 20
  });
```

### NIT — test name describes implementation
```
it('testFindById_returns_4xx_when_missing', async () => { ... });

Fix: describe behavior.
  it('returns 404 when user not found', async () => { ... });
```

### NIT — missing cleanup
```
beforeEach sets up DB; no afterEach cleaning.

Impact: tests can see each other's state in sequence.
Fix: wrap in transaction + rollback, OR truncate tables in afterEach.
```

## Output

```
/test-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

Blockers (N):
  - <file:line> — <issue>
    Impact: <concrete>
    Fix: <concrete code or approach>

Requests (N):
  - <issue + fix>

Nits (N):
  - <minor improvements>

Missing coverage (flagged, not always blocker):
  - <module / file> has new behavior without a test.

Flakiness risks:
  - <test with suspect timing / state>

Coverage metrics:
  - Lines: <%>  → <%>
  - Branches: <%> → <%>
  - Mutation (if tracked): <%>

Patterns consulted: test-strategy, test-doubles
```

## Hard rules

- BLOCK on: `.only` checked in, always-pass assertions, tests hitting real external APIs.
- BLOCK on: missing regression test for a claimed bug fix.
- BLOCK on: tests that don't actually verify the behavior ("asserts on call, not outcome").
- REQUEST on: flakiness risks, weak mocks, missing edge cases.
- NIT on: naming, structure, minor cleanup.
- Multi-tenant changes without cross-tenant test = BLOCKER.
- Webhook changes without idempotency test = BLOCKER.
