---
name: property-invariants
description: Find functions whose correctness lives in properties that hold for ALL inputs — round-trip, idempotence, commutativity, invariants — and generate property-based tests, not a handful of examples.
---

# property-invariants

Some correctness doesn't live in examples: `parse(serialize(x)) == x` must hold for *every* `x`, not the three you typed. This skill finds pure/total functions under-tested by example and generates property tests a generator explores for you.

## Premise

Find real properties, no hand-waves. Every candidate cites the function as `<path:line>`, names the property class (round-trip / idempotence / commutativity / invariant / model / oracle), and states an executable for-all predicate — `for all x: decode(encode(x)) == x`, not "should round-trip". A generated test with no shrinker, or that swallows the failing seed, is a flaky test in waiting, not a finding.

## When to run

- A pure/total function (parser, encoder, formatter, sort, path builder) has only example tests.
- An `encode`/`decode`, `serialize`/`parse`, `to`/`from` pair has no round-trip property.
- A code-enforced invariant (balance ≥ 0, output sorted, no dupes) is asserted once but never quantified over inputs.
- A reference / brute-force oracle exists (or is cheap) that the fast implementation must match.

## Adapt to the codebase

Drive the pinned framework — fast-check (JS/TS), Hypothesis (Python), jqwik (Java/Kotlin), ScalaCheck, QuickCheck/Hedgehog (Haskell), proptest/quickcheck (Rust), rapid (Go), StreamData (Elixir). Never silently add a heavy dep; propose and STATE the choice.

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

## Halt conditions

- Halt on a property without a `<path:line>` and a stated for-all predicate.
- Halt on a generator with no shrinker, or a test that doesn't pin/log the failing seed.
- Halt on calling a function "pure/total" without confirming no I/O, no clock/RNG read, a result for every input.

## Boundary

- `coverage-gap.md` = **presence** (did the branch run).
- `mutation-probe.md` = **strength** (would an assertion catch a mutation).
- property-invariants (this) = **input-space breadth** (holds across the whole domain, not the handful of examples you picked).

Related: `coverage-gap`, `mutation-probe`, `@test-engineer`.
