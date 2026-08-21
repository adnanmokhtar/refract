---
name: test-factories
description: Consolidate test data creation into factories/builders with sensible defaults plus per-test overrides — killing copy-pasted object literals and shared mutable fixtures that couple tests to each other. Use when the same literal is built inline across three or more tests, when a mutated shared fixture makes suite order matter, or when a new required field forces edits across many test files. Restructures setup only; it never changes what a test asserts.
---

# test-factories

Test data should be built, not copy-pasted. A test asks a factory for a `User`, overriding only the field under test. Hand-written 12-field literals break forty tests on one schema change; shared mutable fixtures pass in order and fail in isolation.

## Premise

Find real data-construction rot, no hand-waves. Every finding cites `<path:line>` for the duplicated literal or shared fixture, names the anti-class (inline-duplication / shared-mutable / no-override / collision), and states the fix as a concrete API — `userFactory({ role: 'admin' })`, not "add a factory". A factory that hardcodes every field with no override is the shared fixture in a trench coat.

## Halt conditions

- Halt on a finding without `<path:line>` + the count of duplicating tests.
- Halt on a proposed factory with no per-test override path — defaults-only is not a factory.
- Halt on a shared-mutable claim without proving order dependence (passes in suite, fails alone / reordered).
- Halt on a unique field (email, slug, id) with a constant default and no sequence.

## When to run

- The same object literal is rebuilt inline across ≥ 3 tests, differing in one or two fields.
- A `beforeEach` / module-level fixture is mutated by tests and suite order matters.
- Adding a required model field forces edits across many test files.
- Integration tests rebuild a related graph (Order + Customer + LineItems) by hand each time.

## Adapt to the codebase

Use the pinned library — FactoryBot (Ruby), Fishery + faker (JS/TS), factory_boy (Python), Instancio (Java/Kotlin), Laravel factories (PHP), hand-rolled builders (Go, idiomatic), Bogus / AutoFixture (.NET). Sequences for unique fields; `build` vs `create` per what the test asserts.

## Procedure

1. **Inventory duplication.** Group repeated object-literal construction by type; count the duplicating call sites; note which fields actually vary between them.
2. **Find shared mutable fixtures.** Locate module-level / `beforeAll` objects that tests write to, and confirm order dependence by running the suspect test in isolation and reordered.
3. **Design the factory.** Sensible defaults for *every* field (a valid, boring instance) plus an override map, so **only the field being tested differs from the default**.
4. **Add sequences for unique fields** — email, username, slug, external id — so N built instances never collide.
5. **Build associations.** A factory builds its dependencies unless overridden; allow passing an existing parent to avoid over-creating.
6. **Separate seed/reference data from per-test data.** Fixed reference rows are seeded once and treated as read-only; anything a test mutates or asserts identity on is built fresh per test.
7. **Keep factories in sync with the schema** — a factory that drifts produces invalid objects that pass unit tests and explode at the DB boundary; a new required column means a new factory default.
8. **Migrate consumers.** Replace inline literals with factory calls, delete the shared mutable fixture, and confirm tests still pass in isolation and reordered.

## Output (abridged)

```
Test-data findings — feature/checkout-tests  (base=origin/main)
Files: 22  |  Inline-dup groups: 3  |  Shared mutable fixtures: 1

INLINE DUP:  test/order.spec.ts:20-32 (+5 sites) — same 11-field Order, only `status` varies
  → orderFactory.build({ status }) — Fishery; defaults cover the other 10 fields.
SHARED MUTABLE:  test/support/fixtures.ts:8 sharedUser — role mutated, leaks into permissions.spec
  Proof: run permissions.spec alone → FAIL. → userFactory per test; delete sharedUser.
MISSING SEQUENCE:  test/factories/user.ts:12 email constant → unique-index collision on 2nd build.
```

## Boundary

- `test-doubles.md` owns **behavior** — what a collaborator does when the SUT calls it (mocks, stubs, fakes, spies).
- test-factories (this) owns **data** — how the input objects and fixtures the test operates on are constructed.

A test typically needs both: a factory to build the `User` and `Order` it acts on, and a fake repository to stand in for the DB.

Related: `test-doubles`, `@test-engineer`, `test-strategy`.
