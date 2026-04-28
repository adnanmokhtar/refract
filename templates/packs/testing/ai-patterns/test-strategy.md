---
name: test-strategy
description: Pattern: Test Strategy
kind: ai-pattern
pack: testing
---

# Pattern: Test Strategy

Tests have a cost (write time, run time, maintenance). They have a value (regression prevention, design pressure, documentation). The strategy is matching the right kind of test to the right concern, in the right ratio, so the value/cost ratio stays positive as the codebase grows.

## Context

You need a deliberate test strategy when:
- Test runtime exceeds 5 minutes and devs start skipping locally.
- A bug ships that "tests" "covered" because the test was a tautology.
- Tests are flaky — retries hide real failures.
- New features take longer to test than to write.

For a 200-LOC script you're going to throw away next week, full pyramid is overkill — a single happy-path E2E may suffice. The strategy applies to anything you'll maintain past one quarter.

## The pyramid (and its critics)

```
       /\
      /e2e\        few, slow, broad     ← golden journeys only
     /------\
    /  intg  \    some, medium          ← persistence + IO + middleware
   /----------\
  /    unit    \  many, fast, narrow    ← branches + edge cases
 /--------------\
```

Rough ratio targets: 80% unit / 15% integration / 5% E2E.

Critics ("test trophy" — Kent C. Dodds) argue integration tests are underused. They're right for stateless React components and REST APIs that have no domain logic. They're wrong for systems with rich domain models — unit tests on the domain layer are the cheapest defect-prevention.

Pick the model honestly. If the codebase is 80% glue between services and 20% logic, you'll have more integration than unit. If it's 60% domain logic, the classic pyramid wins.

## What goes where

| Layer | Speed budget | Scope | What to test | Examples |
|---|---|---|---|---|
| Unit | < 100ms | One class/function | Branches, edge cases, pure logic | Domain rules, mappers, validators, value objects |
| Integration | < 1s | Repo + DB; service + fake deps | Persistence, queries, multi-component flows | Repository against real Postgres in container, service with mock external API |
| E2E | < 30s | Full stack, real HTTP, real browser | Golden user journey, auth flow, payment | Login → place order → verify email |

## What to test

Test:
- Every business rule branch (each `if/else`, each error path, each status transition).
- Boundary conditions (empty list, null, max value, timezone edges, leap year, locale).
- Regression for every fixed bug — write the failing test BEFORE the fix.
- Authorization (every endpoint: authenticated user gets 200, anon gets 401, wrong-tenant gets 404).
- Tenant isolation explicitly — see Multi-tenancy section below.

Don't test:
- Framework internals (NestJS' `@Body` parses JSON — they tested it).
- Trivial getters/setters (no logic = no test value).
- Private methods directly — exercise via public surface.
- The same behavior at multiple pyramid levels (DRY: test once at the lowest level that's meaningful).

## Test doubles — terminology that matters

Mixing these up causes brittle tests.

| Type | What it does | When to use |
|---|---|---|
| **Fake** | Real impl with shortcuts (in-memory DB, in-memory queue) | Stateful deps you exercise repeatedly |
| **Stub** | Returns canned values, no assertions | Read-only deps; "this call doesn't matter, just return X" |
| **Mock** | Records calls, returns scripted values, allows assertions | External APIs you want to assert "was called with X" |
| **Spy** | Wraps real object, records, delegates | When you want real behavior + verification |

Preference order for stateful deps: **fake > stub > spy > mock**. A fake repository (`InMemoryUserRepository`) you write once and reuse across 50 tests is more maintainable than 50 mocks.

```ts
// Fake — in-memory implementation, behaves correctly
class InMemoryOrderRepo implements OrderRepository {
  private orders = new Map<string, Order>();
  async save(o: Order) { this.orders.set(o.id, o); }
  async findById(id: string) { return this.orders.get(id) ?? null; }
}

// Mock — script + assert (use for outbound API calls)
const stripeMock = { charge: jest.fn().mockResolvedValue({ id: 'ch_1' }) };
expect(stripeMock.charge).toHaveBeenCalledWith({ amount: 1000, currency: 'usd' });
```

## Determinism

Flaky tests are bugs, not "just retry". Fix the root cause:

```ts
// Time
beforeEach(() => jest.useFakeTimers().setSystemTime(new Date('2026-04-24T10:00:00Z')));
afterEach(() => jest.useRealTimers());

// RNG / UUID — inject, don't import
class OrderService {
  constructor(private idGen: () => string) {}
  // tests pass () => 'ord_test_1'; prod passes () => crypto.randomUUID()
}

// State leakage between tests
beforeEach(async () => { await db.query('TRUNCATE orders, items CASCADE'); });

// Async waits — use waitFor with assertions, never sleep
await waitFor(() => expect(screen.getByText('Saved')).toBeInTheDocument(), { timeout: 2000 });
```

`sleep(500)` is the smell. The right fix is "wait for X to be true", not "wait long enough that X is probably true".

## Fixtures

Minimal data scoped to the scenario, named by the scenario:

```
test/fixtures/orders/
  order-pending.json                   ← order in 'pending' state, has 1 item
  order-paid-with-shipping.json
  order-with-partial-refund.json
```

Avoid `order1.json` / `order2.json` — they evolve to "what was order2 again?" three months later. Inline JSON in tests is worse — same fixture re-typed in 12 tests, drift between them.

Test data builders for richness:

```ts
const order = anOrder()
  .withTenant('tenant_a')
  .withItems([anItem().withQty(2).build()])
  .pending()
  .build();
```

Defaults are sane; overrides express the scenario specifically. Far more readable than `JSON.parse(...)` walls.

## Coverage

Coverage measures lines executed, NOT scenarios tested. 100% line coverage of `if (x) doA(); else doB();` with one test is meaningless.

Target meaningful branches, not a percentage. Set a ratchet:
- Coverage cannot decrease per PR.
- New code requires tests (a CI rule, not a vibe check).

Uncovered lines you actually care about → write a test. Uncovered lines you don't → delete the code.

## Multi-tenancy: explicit isolation tests

For multi-tenant systems, EVERY repo + EVERY service that handles tenant data ships an isolation test:

```ts
it('does not return tenant B orders to tenant A', async () => {
  await TenantContext.run({ tenantId: 'A' }, async () => {
    await orderRepo.save(anOrder().build());
  });
  await TenantContext.run({ tenantId: 'B' }, async () => {
    await orderRepo.save(anOrder().build());
  });

  const aOrders = await TenantContext.run({ tenantId: 'A' }, () => orderRepo.findAll());
  expect(aOrders).toHaveLength(1);
  expect(aOrders.every(o => o.tenantId === 'A')).toBe(true);
});
```

These are the most boring tests in the codebase and the most important.

## CI rules

- Unit + integration on every PR. Block merge on red.
- E2E on main + nightly. Slower; running them on every PR is unaffordable past a small suite.
- `.skip` without a linked issue = blocker. The reviewer asks "what's the ticket?"
- `.only` checked in = blocker. Skipped CI run shipped to main.
- Flaky test = quarantine for 24h, fix or delete. Retries hide bugs.

## Common mistakes

- **Mocks that return "whatever makes the test pass".** The test asserts the code calls `mock.x()`; the mock returns `42`; the code uses `42`; the test passes. The test is a tautology.
- **Asserting on framework internals.** Testing that `@Body()` decorator extracts JSON — that's NestJS's test, not yours.
- **Slow unit tests.** A "unit" test that hits a real DB is an integration test. Unit tests should be < 100ms; if you can't, you've coupled to infrastructure that should be abstracted.
- **E2E that re-tests business logic.** E2E asserts the wires are connected; unit tests assert the logic. E2E checking "order total is correct" duplicates the unit test that already covers totals.
- **No test for the bug fix.** The bug shipped; the fix shipped without a regression test. Same bug returns in 6 months.
- **Test files larger than the source.** A 1500-line test for a 200-line service usually means the design is wrong (too many dependencies, too many branches). Refactor the source.
- **Snapshot tests as the primary assertion.** Snapshots catch drift but encode no intent. Reviewers blindly approve snapshot updates. Use snapshots for shape (DTO contracts, rendered HTML) where the shape IS the assertion.

## Testing tests

The mutation-testing trick: corrupt the source (`==` → `!=`), re-run tests. If they still pass, the test wasn't actually testing the corrupted line. Tools: Stryker (JS/TS), PIT (Java), mutmut (Python). Don't run on every PR (slow); run weekly to find weak tests.

## Migration path

If you have no test discipline:
1. Get the build green. If tests are red, fix or delete — red CI normalizes red.
2. Add a coverage report (no threshold yet). See where you stand.
3. Pick the most-changed module of the last quarter. Add unit tests there. Set a ratchet — coverage can't decrease.
4. Add ONE E2E for the golden journey (login → core action → result). Run nightly.
5. Add an integration test against a real DB for the most query-heavy repository.
6. Quarantine flakes; fix them as they bite. Don't try to fix all at once.
7. Expand outward.

## References

- Martin Fowler "Test Pyramid" (martinfowler.com/bliki/TestPyramid.html) — the canonical pyramid.
- Kent C. Dodds "Testing Trophy" (kentcdodds.com/blog/the-testing-trophy-and-testing-classifications) — the integration-heavy alternative.
- "Working Effectively with Legacy Code" (Feathers) — testing without rewrite, when retrofitting.
- "xUnit Test Patterns" (Meszaros) — the lexicon for fakes/stubs/mocks/spies.
