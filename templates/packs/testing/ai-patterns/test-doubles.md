---
name: test-doubles
description: Pattern: Test Doubles (Mocks, Stubs, Fakes, Spies)
kind: ai-pattern
pack: testing
---

# Pattern: Test Doubles (Mocks, Stubs, Fakes, Spies)

Wrong double = brittle test OR false confidence. Know the difference.

## The 5 types

### Dummy
Passed to satisfy a signature, never used.
```ts
await service.process(order, dummyLogger);
```

### Stub
Canned responses. No interaction tracking.
```ts
const userRepo = { findById: () => Promise.resolve({ id: 1, name: 'Alice' }) };
```

### Mock
Canned responses + asserts on interactions.
```ts
const emailClient = jest.fn();
await userService.signup({ email: 'a@b.com' });
expect(emailClient).toHaveBeenCalledWith('a@b.com', 'welcome');
expect(emailClient).toHaveBeenCalledTimes(1);
```

### Spy
Wraps a REAL object, records calls, delegates to real behavior.
```ts
const logger = new Logger();
const spy = jest.spyOn(logger, 'error');
await service.handle(bad);
expect(spy).toHaveBeenCalledWith(expect.stringContaining('validation'));
```

### Fake
Alternative working implementation. Functional but simplified.
```ts
class InMemoryUserRepo implements UserRepo {
  private users = new Map<string, User>();
  async save(user) { this.users.set(user.id, user); }
  async findById(id) { return this.users.get(id) ?? null; }
  async findAll() { return [...this.users.values()]; }
}
```

## Which to use when

| Scenario | Prefer |
|---|---|
| External API (Stripe, SendGrid, Twilio) | Mock (assert specific calls made correctly) |
| Logger / metrics / tracer | Spy (verify side effects, delegate real work) |
| Database / repository with state | Fake (in-memory impl preserving query semantics) |
| Clock / random / UUID | Fake (seeded generators for determinism) |
| Third-party lib you don't own | Mock at the port (interface) boundary, not the lib itself |
| Pure function dependency | No double needed — use the real thing |

## Fake > Mock for stateful dependencies

Mocks get brittle when state matters:
```ts
// MOCK — brittle
userRepo.findById.mockResolvedValueOnce({ id: 1, name: 'Alice' });
userRepo.findById.mockResolvedValueOnce({ id: 1, name: 'Alice Updated' });
```

```ts
// FAKE — natural
const userRepo = new InMemoryUserRepo();
await userRepo.save({ id: 1, name: 'Alice' });
// test runs, maybe calls save again
const user = await userRepo.findById(1);
// reflects actual state — no per-call scripting
```

Invest once in a fake; reuse forever.

## Mocking at the right boundary

### BAD — mocking internal functions
```ts
// TESTING UserService
jest.mock('./helpers', () => ({ formatDate: () => '...' }));
// Brittle: refactoring the helper breaks tests.
```

### GOOD — mocking PORTS (dependencies declared by interface)
```ts
const userRepo: UserRepo = new InMemoryUserRepo();
const emailClient: EmailClient = jest.fn();
const service = new UserService(userRepo, emailClient);
```

Rule: mock what the system-under-test OWNS as a dependency, not its internals.

## Mocking frameworks

- Jest / Vitest: `jest.fn()`, `jest.spyOn()`, auto-mocking.
- Sinon (vanilla JS): spies + stubs + mocks.
- Python: `unittest.mock`, `pytest-mock`.
- Go: interface-based — write fakes by hand (it's idiomatic).
- Rust: `mockall` crate for trait mocks.
- Java: Mockito, MockK (Kotlin).

## Anti-patterns

### Over-mocking
Every dependency mocked → test passes but verifies nothing real.

### Mocking time incorrectly
```ts
// BAD
Date.now = () => 1234567890;

// GOOD
jest.useFakeTimers().setSystemTime(new Date('2026-01-01'));
// or inject a clock
```

### Partial mocks
Mocking some methods of an object, leaving others real → confusing behavior, hard to debug.

### Asserting on implementation
```ts
// BAD — couples test to internal call sequence
expect(db.query).toHaveBeenCalledWith('SELECT ...');

// GOOD — assert on observable behavior
expect(await service.getUserCount()).toBe(5);
```

### Mock creep
Production code gains a special code path for tests (`if (process.env.TEST)`). Sign you're testing wrong.

## Determinism essentials

Always fake:
- **Time** — `Date.now()`, `new Date()`, `performance.now()`. Inject a clock OR use `jest.useFakeTimers`.
- **UUID / random** — seed in tests OR inject a generator.
- **Network** — mock or use a local fake server (MSW, nock, recorded fixtures via vcr).
- **File system** — use a tmpdir + cleanup, or a memory FS.

## Test structure with fakes

```ts
// Arrange
const userRepo = new InMemoryUserRepo();
const clock = new FakeClock('2026-01-01');
const sut = new SignupService(userRepo, clock);

// Act
const result = await sut.signup({ email: 'a@b.com' });

// Assert
expect(result.id).toBeDefined();
expect(await userRepo.findById(result.id)).toMatchObject({
  email: 'a@b.com',
  createdAt: new Date('2026-01-01'),
});
```

## When NOT to use doubles

- Pure functions — test with real inputs.
- Value objects / simple types — use real instances.
- Read-only utilities — use the real thing.
- When the "double" would be 90% the same as the real implementation — just use the real one (maybe with an in-memory config).

## Forbidden

- Mock that returns whatever makes the test pass (proves nothing).
- Changing production code to make it mockable (special test paths).
- Partial mocks (half real, half canned) — confusion.
- Mocking framework internals (don't mock `express.Router`).
- Sharing mocks across tests (pollutes state).
- Real external API calls in unit / integration tests — MSW / nock / fakes only.
