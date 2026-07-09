---
name: property-invariants
description: Find functions whose correctness lives in properties that must hold for ALL inputs — round-trip, idempotence, commutativity, invariants — and generate property-based tests, not a handful of examples.
---

# property-invariants

Some correctness doesn't live in examples. `parse(serialize(x)) == x` must hold for *every* `x`, not the three you typed. A pure, total function tested only by example under-tests its input space — the bug is in the input you didn't think of. This skill finds those functions and generates property-based tests that a generator explores for you.

## Premise

Find real properties, no hand-waves. Every reported candidate cites the function as `<path:line>`, names the specific property class it satisfies (round-trip / idempotence / commutativity / invariant / model-based / oracle), and states the property as an executable predicate over generated inputs — `for all x: parse(serialize(x)) == x`, not "should round-trip". A generated test that has no shrinker, or that swallows the failing seed, is not a finding — it is a flaky test in waiting. "This looks pure, add property tests" is not a finding; "`codec.ts:44 encode`/`codec.ts:71 decode` form a round-trip pair with only 2 example tests, no property" is.

## Halt conditions

- Halt on a proposed property without a `<path:line>` for the function and a stated for-all predicate.
- Halt on a property test whose generator has no shrinker (or whose framework's shrinking was disabled) — an un-shrunk counterexample is unusable.
- Halt on a property test that does not log/pin the failing seed on failure — non-reproducible property failures are worse than no test.
- Halt on classifying a function as "pure/total" without confirming it has no I/O, no clock/RNG read, and a defined result for every input in the generated domain.

## When to run

- A pure or total function (parser, encoder, formatter, math/geometry, sort/dedupe, path/URL builder) has only example tests.
- A `serialize`/`parse`, `encode`/`decode`, `compress`/`decompress`, or `to`/`from` pair exists with no round-trip property.
- A documented or code-enforced invariant (balance ≥ 0, output sorted, set has no dupes, tree stays balanced) is asserted in one example but never quantified over inputs.
- A reference/brute-force oracle exists (or is cheap to write) that the fast implementation must agree with.
- A state machine / stateful component (cache, queue, allocator, session store) has only scripted happy-path tests.

## Adapt to the codebase

Detect the stack, then use its idiomatic property framework. Do not introduce a new dependency if the repo already pins one.

| Stack | Framework | Generator / shrink notes |
|---|---|---|
| JS / TS | fast-check | `fc.assert(fc.property(gen, pred))`; built-in shrinking; seed via `fc.configureGlobal` / printed on failure |
| Python | Hypothesis | `@given(strategies)`; automatic shrinking; `@seed`/`--hypothesis-seed` to reproduce; `@example` to pin regressions |
| Java / Kotlin | jqwik | `@Property` + `@ForAll`; `@Provide` for custom arbitraries; deterministic `@Seed` |
| Scala / JVM | ScalaCheck | `forAll`; `Gen`/`Arbitrary`; integrates via ScalaTest/specs2 |
| Haskell | QuickCheck / Hedgehog | `Arbitrary`/`Gen`; Hedgehog has integrated shrinking without separate `Shrink` |
| Rust | proptest / quickcheck | proptest = strategy-based + persisted failure corpus; quickcheck = `Arbitrary` trait |
| Go | testing/quick, rapid | stdlib `quick.Check` (no shrink); `pgregory.net/rapid` for shrinking + stateful |
| Elixir | StreamData / PropCheck | `check all`; stateful via PropCheck's model callbacks |

If no framework is pinned, propose the row above and STATE it — do not silently add a heavy dependency.

## Procedure

1. **Spot candidates.** Scan changed/critical code for the four smells:
   - *Pure/total, examples only* — no side effects, deterministic, defined for all inputs, yet 1-5 hardcoded cases.
   - *Round-trip pair* — a `f`/`f⁻¹` couple (`serialize`/`parse`, `encode`/`decode`, `marshal`/`unmarshal`) with no `decode(encode(x)) == x` test.
   - *Algebraic law* — idempotence (`f(f(x)) == f(x)`: normalize, dedupe, saturating clamp), commutativity/associativity (merge, union, add), monotonicity, identity/inverse elements.
   - *Invariant / oracle* — a postcondition the output must always satisfy (sort → output is sorted AND a permutation of input; balance never negative), or a slow reference implementation the fast one must match.
2. **State the property as a predicate.** Write the for-all explicitly: inputs, the relation that must hold, and the input domain (including edge generators — empty, unicode, NaN, negative, huge).
3. **Design the generator.** Cover the real domain, not just easy values. Prefer the framework's composition (`map`/`filter`/`bind`) over ad-hoc loops. Constrain to the valid input space so failures are real, not precondition violations.
4. **Confirm the shrinker.** Use the framework's built-in shrinking; for custom generators built by hand, ensure a shrink path exists so counterexamples reduce to minimal cases. A generator with no shrinker is a defect (see Halt).
5. **Stateful / model-based** for state machines: define a lightweight model (e.g. a plain map/list), a set of commands, a precondition + postcondition per command, and let the framework generate command sequences. Assert model and real system stay in agreement after every command.
6. **Pin reproducibility.** Ensure the framework prints the failing seed; capture regressions as pinned examples (`@example` / persisted failure corpus / `@Seed`) so a fixed bug never silently returns.

## Output

```
Property candidates — feature/codec-hardening  (base=origin/main)

Functions changed: 6  |  With property tests: 1  |  Candidates found: 4

ROUND-TRIP (high value):
  src/codec.ts:44 encode  /  src/codec.ts:71 decode
    Property: ∀ msg. decode(encode(msg)) deep-equals msg
    Today: 2 example tests. Generator: fc.record over the Message schema.
    Shrinker: fast-check built-in. Seed: printed on failure.

INVARIANT:
  src/ledger.py:88 apply_transaction
    Property: ∀ ops. balance after any op sequence >= 0  (model-based)
    Model: running int; commands = [deposit, withdraw]; withdraw precond balance>=amt.
    Framework: Hypothesis stateful (RuleBasedStateMachine).

IDEMPOTENCE:
  src/paths.go:31 Normalize
    Property: ∀ p. Normalize(Normalize(p)) == Normalize(p)
    Framework: pgregory.net/rapid (shrinking). testing/quick lacks shrink — do not use here.

ORACLE:
  src/sort/fast_sort.rs:20 fast_sort
    Property: ∀ v. fast_sort(v) == { let mut c=v; c.sort(); c }  (stdlib oracle)
    proptest strategy: prop::collection::vec(any::<i32>(), 0..1000)
```

## False positives / gotchas

- **Not actually pure.** A function that reads a clock, RNG, env, or global fails intermittently under a generator for the *right* reason — inject the dependency first (see `test-doubles.md`), or it's a bad property candidate, not a bug.
- **Precondition leakage.** If the generator emits inputs the function legitimately rejects, you'll get false failures. Constrain the generator to the valid domain; don't assert on garbage-in.
- **Float exactness.** `parse(serialize(f)) == f` fails on floating point — assert within epsilon or round-trip through the canonical string, not `==`.
- **Weak generator.** A generator that only emits small ints "passes" while missing the empty/unicode/overflow case. Breadth of the generator *is* the strength of the test.
- **Slow oracle in the hot loop.** An O(n²) reference oracle throttles the run — cap generated size, or gate the oracle property behind a slower CI tier.
- **Flaky seed hidden.** If the framework's default swallows the seed, a red build isn't reproducible. Confirm the seed is logged before trusting any property test.

## Boundary

- `coverage-gap.md` = **presence** — did any test hit this branch at all.
- `mutation-probe.md` = **strength** — do the assertions actually catch a mutation.
- `property-invariants` (this) = **input-space breadth** — does the test hold across the whole domain, not the handful of examples you picked.

A branch can be covered (coverage-gap green), assertion-strong on those examples (mutation-probe green), and still wrong on the input you never generated. That last gap is this skill's job.

Related: `coverage-gap`, `mutation-probe`, `@test-engineer`.
