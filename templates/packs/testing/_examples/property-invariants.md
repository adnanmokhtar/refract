---
name: property-invariants
description: Find functions whose correctness lives in properties that must hold for ALL inputs — round-trip, idempotence, commutativity, invariants — and generate property-based tests instead of a handful of examples. Use when a pure function (parser, encoder, formatter, sort/dedupe, path builder) has only example tests, or a serialize/parse pair has no round-trip property. Not for I/O-bound or side-effecting code.
---

# property-invariants

Some correctness doesn't live in examples: `parse(serialize(x)) == x` must hold for *every* `x`, not the three you typed. This skill finds pure/total functions under-tested by example and generates property tests a generator explores for you.

## Premise

Find real properties, no hand-waves. Every candidate cites the function as `<path:line>`, names the property class (round-trip / idempotence / commutativity / invariant / model / oracle), and states an executable for-all predicate — `for all x: decode(encode(x)) == x`, not "should round-trip". A generated test with no shrinker, or that swallows the failing seed, is a flaky test in waiting, not a finding.

## Halt conditions

- Halt on a property without a `<path:line>` and a stated for-all predicate.
- Halt on a generator with no shrinker, or a test that doesn't pin/log the failing seed.
- Halt on calling a function "pure/total" without confirming no I/O, no clock/RNG read, a result for every input.

## When to run

- A pure/total function (parser, encoder, formatter, sort, path builder) has only example tests.
- An `encode`/`decode`, `serialize`/`parse`, `to`/`from` pair has no round-trip property.
- A code-enforced invariant (balance ≥ 0, output sorted, no dupes) is asserted once but never quantified over inputs.
- A reference / brute-force oracle exists (or is cheap) that the fast implementation must match.

## Adapt to the codebase

Drive the pinned framework — fast-check (JS/TS), Hypothesis (Python), jqwik (Java/Kotlin), ScalaCheck, QuickCheck/Hedgehog (Haskell), proptest/quickcheck (Rust), rapid (Go), StreamData (Elixir). Never silently add a heavy dep; propose and STATE the choice.

## Procedure

1. **Spot candidates.** Scan changed/critical code for the four smells: pure/total but examples-only · a round-trip `f`/`f⁻¹` pair with no `decode(encode(x)) == x` test · an algebraic law (idempotence, commutativity/associativity, monotonicity, identity/inverse) · an invariant or oracle the output must always satisfy.
2. **State the property as a predicate.** Write the for-all explicitly: inputs, the relation that must hold, and the input domain (including edge generators — empty, unicode, NaN, negative, huge).
3. **Design the generator.** Cover the real domain, not just easy values. Prefer the framework's composition (`map`/`filter`/`bind`) and constrain to the valid input space, so failures are real rather than precondition violations.
4. **Confirm the shrinker.** Use the framework's built-in shrinking; a hand-built generator with no shrink path is a defect (see Halt).
5. **Stateful / model-based** for state machines — a lightweight model, a command set, a precondition + postcondition per command; assert the model and the real system still agree after every command.
6. **Pin reproducibility.** Ensure the framework prints the failing seed, and capture regressions as pinned examples so a fixed bug never silently returns.

## Output (abridged)

```
Property candidates — feature/codec-hardening  (base=origin/main)
Functions changed: 6  |  With property tests: 1  |  Candidates: 4

ROUND-TRIP:  src/codec.ts:44 encode / :71 decode
  ∀ msg. decode(encode(msg)) deep-equals msg — 2 example tests today; fast-check, built-in shrink.
INVARIANT:   src/ledger.py:88 apply_transaction (model-based)
  ∀ ops. balance ≥ 0 after any sequence — Hypothesis RuleBasedStateMachine.
ORACLE:      src/sort/fast_sort.rs:20  ∀ v. fast_sort(v) == v.sorted()  (proptest)
```

## Boundary

- `coverage-gap.md` = **presence** (did the branch run).
- `mutation-probe.md` = **strength** (would an assertion catch a mutation).
- property-invariants (this) = **input-space breadth** (holds across the whole domain, not the handful of examples you picked).

Related: `coverage-gap`, `mutation-probe`, `@test-engineer`.
