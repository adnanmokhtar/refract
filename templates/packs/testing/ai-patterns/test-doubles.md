---
name: test-doubles
description: Pattern: Test Doubles (Mocks, Stubs, Fakes, Spies)
kind: ai-pattern
pack: testing
---

# Pattern: Test Doubles (Mocks, Stubs, Fakes, Spies)

> **Hard rule** — Mock at port (interface) boundaries only. Prefer fakes for stateful deps (`InMemoryRepo` over per-call mock script). Asserting on internal call sequences or mocking internal helpers is forbidden.

**When to apply**
- Dependency is an interface the SUT receives via constructor / DI / factory.
- Dependency reaches outside the process (network, FS, clock, RNG, third-party API).
- A stateful collaborator's behaviour matters across multiple test calls — write a fake.

**When NOT to apply**
- Pure functions and value objects — use the real thing.
- Internal helpers and private methods — exercise via the public surface.
- Dependencies the system doesn't own (your web framework's request router, framework internals).

**Halt conditions / mandatory cites**
- Cite the port interface file as `<path:line>` before mocking it; mocking concrete classes without an interface is a halt.
- Cite the fake's implementation as `<path:line>` when proposing one; "I'll mock it inline" for a stateful dep across > 2 tests is a halt.
- Cite the clock / RNG / UUID injection point as `<path:line>` before asserting on time-dependent behaviour; `Date.now = ...` rewrites are forbidden.
- Cite the production code path that requires the special case before adding any test-only branch (`if (process.env.TEST)`); mock creep into production is a halt.
- Hand-wave grep ban — never claim "no real network in tests" without citing the MSW/nock setup file or CI guard rule.

> **Code samples below are illustrative.** Concrete syntax shown uses one stack (TypeScript + a JS-family test runner) for readability; the principles apply across language families. Substitute your stack's mocking primitives (`MagicMock` / `monkeypatch` / `Mockito.mock` / `instance_double` / `gomock` / framework-equivalent) using the substitution table in `testing/STACK.md`.

Wrong double = brittle test OR false confidence. Know the difference.

## The 5 types

### Dummy
Passed to satisfy a signature, never used.
```ts
await service.process(order, dummyLogger);
```

### Stub
Canned responses. No interaction tracking.
```pseudo
userRepo = { findById: (id) => { id: 1, name: "Alice" } }
```

### Mock
Canned responses + asserts on interactions.
```pseudo
emailClient = mock()
userService.signup({ email: "a@b.com" })
assert emailClient.calledWith("a@b.com", "welcome")
assert emailClient.callCount == 1
```

### Spy
Wraps a REAL object, records calls, delegates to real behaviour.
```pseudo
logger = new Logger()
spy = wrapAndSpy(logger, "error")
service.handle(bad)
assert spy.calledWithMatching(contains("validation"))
```

### Fake
Alternative working implementation. Functional but simplified.
```pseudo
class InMemoryUserRepo implements UserRepo {
  users = map<id, User>()
  save(user)    { users[user.id] = user }
  findById(id)  { return users[id] or null }
  findAll()     { return values(users) }
}
```

## Which to use when

| Scenario | Prefer |
|---|---|
| External API (payment provider / email vendor / SMS vendor / etc.) | Mock (assert specific calls made correctly) |
| Logger / metrics / tracer | Spy (verify side effects, delegate real work) |
| Database / repository with state | Fake (in-memory impl preserving query semantics) |
| Clock / random / UUID | Fake (seeded generators for determinism) |
| Third-party lib you don't own | Mock at the port (interface) boundary, not the lib itself |
| Pure function dependency | No double needed — use the real thing |

## Fake > Mock for stateful dependencies

Mocks get brittle when state matters:
```pseudo
// MOCK — brittle
userRepo.findById.returnsOnce({ id: 1, name: "Alice" })
userRepo.findById.returnsOnce({ id: 1, name: "Alice Updated" })
```

```pseudo
// FAKE — natural
userRepo = new InMemoryUserRepo()
userRepo.save({ id: 1, name: "Alice" })
// test runs, maybe calls save again
user = userRepo.findById(1)
// reflects actual state — no per-call scripting
```

Invest once in a fake; reuse forever.

## Mocking at the right boundary

### BAD — mocking internal functions
```pseudo
// TESTING UserService
mockModule("./helpers", { formatDate: () => "..." })
// Brittle: refactoring the helper breaks tests.
```

### GOOD — mocking PORTS (dependencies declared by interface)
```pseudo
userRepo: UserRepo       = new InMemoryUserRepo()
emailClient: EmailClient = mock()
service = new UserService(userRepo, emailClient)
```

Rule: mock what the system-under-test OWNS as a dependency, not its internals.

## Mocking frameworks (per stack)

Pick the project's idiomatic library — examples per language family:

- JS / TS: jest, vitest, sinon, msw (network).
- Python: unittest.mock, pytest-mock, responses (HTTP).
- Go: interface-based — write fakes by hand (idiomatic).
- Rust: mockall (trait mocks), wiremock (HTTP).
- Java / Kotlin: Mockito, MockK.
- Ruby: RSpec mocks, webmock.
- .NET: Moq, NSubstitute.
- PHP: PHPUnit mocks, Mockery.
- Elixir: Mox, Hammox.

## Anti-patterns

### Over-mocking
Every dependency mocked → test passes but verifies nothing real.

### Mocking time incorrectly
```pseudo
// BAD — monkey-patch the global
now() = () => 1234567890

// GOOD — use the project's fake-clock helper, OR inject a clock dependency
fakeClock.set("2026-01-01T00:00:00Z")
```

### Partial mocks
Mocking some methods of an object, leaving others real → confusing behavior, hard to debug.

### Asserting on implementation
```pseudo
// BAD — couples test to internal call sequence
assert db.query.calledWith("SELECT ...")

// GOOD — assert on observable behaviour
assert service.getUserCount() == 5
```

### Mock creep
Production code gains a special code path for tests (`if testEnvActive() { ... }`). Sign you're testing wrong.

## Determinism essentials

Always fake:
- **Time** — `Date.now()`, `new Date()`, `performance.now()` and language-equivalents. Inject a clock OR use the project's fake-timer helper (`jest.useFakeTimers` / `vi.useFakeTimers` / `freezegun.freeze_time` / `Timecop.freeze` / `Clock.fixed` / framework-equivalent).
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
