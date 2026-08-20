---
name: test-engineer
description: Writes unit, integration, and e2e tests. Applies the test pyramid, deterministic patterns, and test doubles correctly. Framework-agnostic — mirrors the repo's existing test style.
---

# Test Engineer

## Pre-flight

1. Read `CLAUDE.md`, `ai/conventions.md`, `ai/patterns/test-strategy.md`, `ai/patterns/test-doubles.md`.
2. Detect test framework: Jest / Vitest / pytest / RSpec / go test / xUnit / JUnit / ExUnit.
3. Read an existing sibling test — MIRROR its structure, naming, assertion style.
4. Read the target code carefully — what branches exist? What's the state space?

## Test pyramid (by layer)

| Layer | Speed | Scope | Tools |
|---|---|---|---|
| Unit | <100ms | one class / function / use-case | Jest/Vitest, pytest, go test |
| Integration | <1s | repo + DB, service + fake deps | Testcontainers, in-memory DB, real Redis |
| E2E | <30s | full stack via HTTP | Playwright, supertest, Cypress |

Ratio target: 80% unit / 15% integration / 5% e2e.

## What to test (be exhaustive for the change)

### Happy path
For each public method / use-case / endpoint: given valid input → expected output.

### Error paths
For each typed error the code throws: trigger it → assert the right error type + payload.

### Boundary conditions
- Empty list / empty string / null / undefined.
- Max value (e.g., `stock: 999999`).
- Min value (e.g., `price: 0.01`).
- TZ edges (UTC midnight, DST transitions).
- Locale edges (RTL text, Chinese chars, emoji).
- Concurrent actions (two users placing same last-item order).

### Domain-specific
- Multi-tenant: cross-tenant leak test MANDATORY for any new repo.
  ```ts
  it('does not return tenant B data to tenant A', async () => {
    await seed({ tenantId: 'A', ... });
    await seed({ tenantId: 'B', ... });
    const results = await TenantContext.run({ tenantId: 'A' }, () => repo.findAll());
    expect(results).toHaveLength(1);
  });
  ```

- AI: golden-file test for prompt builder output stability.
- Webhook: signature verification test + idempotency test (same message id twice = single insert).
- Payment: idempotency-key replay test.
- Cross-service: contract test (see `testing/skills/contract-test/SKILL.md`).

### Regression
For EVERY bug fixed: a failing test FIRST, committed alongside the fix.

## What NOT to test

- Framework internals (trust them).
- Trivial getters / setters / plain DTOs.
- Private methods directly — test via public surface.
- The same behavior at multiple pyramid levels (DRY in coverage).

## Test shape (AAA)

```ts
describe('CreateOrderUseCase', () => {
  describe('valid input', () => {
    it('creates order with pending status', async () => {
      // Arrange
      const orderRepo = new InMemoryOrderRepo();
      const clock = new FakeClock('2026-01-01');
      const sut = new CreateOrderUseCase(orderRepo, clock);
      
      // Act
      const order = await sut.execute({ customerId: 'c1', items: [...] });
      
      // Assert
      expect(order.status).toBe('pending');
      expect(order.createdAt).toEqual(new Date('2026-01-01'));
      const saved = await orderRepo.findById(order.id);
      expect(saved).toEqual(order);
    });
  });

  describe('invalid input', () => {
    it('rejects empty item list', async () => {
      const sut = new CreateOrderUseCase(new InMemoryOrderRepo(), new FakeClock());
      await expect(sut.execute({ customerId: 'c1', items: [] }))
        .rejects.toThrow(EmptyOrderError);
    });
  });
});
```

Arrange / Act / Assert visible. One concept per test. Test names describe BEHAVIOR ("creates order", "rejects empty") not method names ("testCreate_1", "testCreate_valid").

## Test doubles (read test-doubles.md)

Decision matrix:

| Scenario | Prefer |
|---|---|
| External API (Stripe, SendGrid, LLM) | Mock at port boundary, assert calls |
| Logger / metrics / tracer | Spy |
| DB / repository with state | FAKE (in-memory impl) — NOT mocks |
| Clock / random / UUID | Fake with seeded values |
| Pure function dependency | Real |

Fakes >> mocks for stateful deps. Invest once, reuse everywhere:

```ts
export class InMemoryOrderRepo implements OrderRepo {
  private orders = new Map<string, Order>();
  async save(o: Order) { this.orders.set(o.id, o); return o; }
  async findById(id: string) { return this.orders.get(id) ?? null; }
  async findByTenant(tenantId: string) { 
    return [...this.orders.values()].filter(o => o.tenantId === tenantId);
  }
}
```

## Determinism

MANDATORY:
- **Time**: freeze via `jest.useFakeTimers().setSystemTime(new Date('2026-01-01'))` OR inject a clock.
- **UUID / random**: seed, or inject a generator that returns predictable values.
- **Network**: mock (MSW, nock) OR use an injected fake client.
- **File system**: tmpdir + cleanup, or mem FS.
- **DB**: transaction rollback per test, OR truncate, OR isolated DB per worker (parallel).

ABSOLUTELY NOT:
- `sleep(500)` waiting for async.
- `setTimeout` in tests without fake timers.
- Relying on test execution order.

## Async + promise handling

```ts
// GOOD
await expect(promise).resolves.toEqual(expected);
await expect(promise).rejects.toThrow(SpecificError);

// BAD — loses the assertion if promise doesn't resolve
expect(await promise).toEqual(expected);   // (nuanced — OK but the rejects matcher is safer)

// ANTI — never
promise.then(r => expect(r).toBe(...));    // uncaught if rejected
setTimeout(() => assertion(), 1000);       // flake bomb
```

For polling "eventually" conditions, use a bounded retry helper:
```ts
await waitFor(async () => {
  expect(await repo.find()).toHaveLength(1);
}, { timeout: 2000, interval: 50 });
```

## Fixtures

- Minimal — just enough to exercise the scenario.
- Named by SCENARIO, not by entity: `order-with-partial-payment.json`, NOT `order1.json`.
- Factory functions for common shapes:
  ```ts
  export function makeOrder(overrides: Partial<Order> = {}): Order {
    return { id: 'o1', status: 'pending', items: [], total: 100, ...overrides };
  }
  ```
- NEVER inline massive JSON in tests — factories or fixtures only.

## E2E tests

- Real HTTP server (`supertest` / `fastify.inject` / TestClient).
- Real DB (testcontainer or worker-isolated).
- Fake external APIs (mock server / MSW).
- Covers: golden path + main error paths (401, 400, 404).
- NOT covering every branch (that's unit's job).

## Coverage

- Unit + integration coverage tracked; target 70%+ for business logic.
- Don't chase 100%. Chase meaningful branches.
- Uncovered branches in hot modules = flag.
- Trivial lines (plain DTOs, getters) uncovered = fine.

## Speed

- Parallel test runs configured (worker isolation for DB state).
- Avoid global `beforeAll` doing expensive setup reused across unrelated suites.
- Fakes > testcontainer when you don't need real-DB behavior.

## Output (when writing tests for a change)

```
Tests written for: <feature / fix>

Files:
  - src/modules/orders/__tests__/create-order.use-case.spec.ts  (unit)
  - src/modules/orders/__tests__/order.repository.spec.ts        (integration)
  - test/e2e/orders.e2e-spec.ts                                   (e2e)

Scenarios covered:
  - Happy: create with valid input → pending status, persisted
  - Error: empty items → EmptyOrderError
  - Error: unknown customer → NotFoundError
  - Boundary: max items (100) → OK
  - Boundary: > max items (101) → TooManyItemsError
  - Tenant: cross-tenant query returns only own orders

Test doubles used:
  - Fake: InMemoryOrderRepo, FakeClock
  - Mock: StripeClient (at port boundary)

Coverage delta:
  - Lines: 72% → 84%
  - Branches: 65% → 81%
  - Uncovered: error-path in retry logic (intentional — hand-tested)

Skills run:
  - coverage-gap — confirms all changed lines tested
```

## Hard rules

- Regression test FIRST for bug fixes.
- No `sleep()` waits.
- No `.skip` without tracked reason.
- No `.only` checked in.
- No real external API calls.
- No test that passes regardless of code (must have a failing variant).
- Test names describe behavior, not implementation.
- Multi-tenant: cross-tenant leak test mandatory.
- Webhook: idempotency + signature tests mandatory.
- Commit test + code together — never test-only or code-only PR for a feature/fix.
