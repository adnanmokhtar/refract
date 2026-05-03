# Testing pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A unit-test runner** with fake-timers + spy/mocks (Jest / Vitest / pytest / JUnit / Go testing / RSpec)
- **A mocking layer** — at port boundaries only (HTTP, DB driver, message bus)
- **An integration-test boundary** — real DB via Testcontainers / Docker Compose / sqlite
- **A property-based testing tool** for invariants (`fast-check` / `hypothesis` / `Hypothesis` / `quickcheck`)
- **Coverage tooling** with thresholds wired to CI (c8 / Istanbul / Jacoco / coverage.py)
- **Mutation testing** capability for critical modules (Stryker / mutmut / Pitest)

## Inline examples in this pack

Wherever this pack's files show concrete test syntax, examples use one stack (a JS-family runner + TypeScript) for readability — they are illustrative, not canonical. The principles apply across language families. Substitute per stack:

| Vitest / Jest + TS (illustrated) | pytest (Python) | JUnit / Spring (Java) | Go testing | RSpec (Ruby) | Substitution source |
|---|---|---|---|---|---|
| `describe` / `it` | `class TestX:` / `def test_x` | `@Test` methods | `func TestX(t *testing.T)` | `describe` / `it` | suite + case |
| `expect(x).toBe(y)` | `assert x == y` | `assertEquals(y, x)` | `if x != y { t.Fatalf(...) }` | `expect(x).to eq(y)` | assertion |
| `vi.useFakeTimers({ now: ... })` | `freezegun.freeze_time(...)` | `Clock.fixed(...)` | `clockwork` / DI clock | `Timecop.freeze` | fake clock |
| `vi.fn()` / `jest.fn()` | `MagicMock()` / `monkeypatch` | `Mockito.mock(...)` | gomock / testify mock | `instance_double` | mock primitive |
| `msw` / `nock` | `responses` / `httpx_mock` | WireMock | `httptest.NewServer` | `WebMock` | HTTP-call faking |
| `fast-check` `fc.property` | `hypothesis @given` | jqwik | `gopter` | `rantly` | property-based tests |
| Testcontainers (Node) | testcontainers-python | Testcontainers (JVM) | `dockertest` | testcontainers-ruby | real-DB integration |
| Stryker | mutmut | Pitest | go-mutesting | mutant | mutation testing |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual test runner, mocking library, coverage thresholds, fake-timer helper, property-based runner.
- The project's `_extracted-codebase.md § Testing` — test directory layout, naming pattern (`*.test.ts` / `*_test.go` / `test_*.py`), CI gates.
- The validator script's stack-conditional checks read `PROJECT_KIND` to apply runner-specific lint hooks (e.g., `forbidOnly: true` for Vitest, `--strict` for pytest).

If your project uses a stack with no current substitution row above (e.g., Deno test, Bun test, Elixir ExUnit), add the row to your project's `_extracted-idioms.md` and the universal principles still apply.
