---
name: contract-test
description: Generate and verify consumer-driven contracts between services (Pact-style), catching "the frontend and backend disagree on the API" before integration. Use in multi-service architectures, when frontend and backend move in parallel, or when an API change carries breaking-change risk. Cross-service agreement only — a single service's internal behaviour belongs to its own suite.
---

# contract-test

## Premise

Existing consumer needs are the truth. Mirror; never invent. The contract is generated from the consumer's actual call sites and expected responses (`<consumer-path:line>`) — not from the provider's OpenAPI spec, not from imagined fields the consumer "might want", not from the backend team's preferred shape. Every interaction in the contract maps to a real consumer code path. Matchers (`like`, `regex`, `eachLike`) reflect the consumer's actual usage — `like(string())` only when the consumer treats the field as opaque; `regex` only when the consumer parses or validates it. Over-specification ("pin every field") is a contract bug, not strictness.

## Halt conditions

- Halt on contract interactions without a consumer call site citation (`<path:line>`).
- Halt on contracts authored from the provider/server side ("backend defines the shape").
- Halt on `can-i-deploy` skipped at the CD gate, or on contract publish without a consumer version tag.

## Philosophy

Consumer defines what it needs. Provider verifies it delivers that. Each tested independently. No flaky end-to-end environment required.

## Tools

- **Pact** — Node, Java, Go, Python, .NET, Ruby, Rust, Swift, Kotlin.
- **Spring Cloud Contract** — Spring ecosystem.
- **Dredd** — OpenAPI-based (less powerful, simpler).

## Flow

### Consumer side (e.g., frontend)
1. Write a test that uses a mock API (provided by Pact).
2. Define interactions: given state X, request Y, expect response Z.
3. Pact generates a **contract file** (JSON) from the interactions.
4. Contract published to a **broker** (Pactflow / self-hosted).

### Provider side (e.g., backend)
1. Fetch the contract from the broker.
2. Run verification: replay each interaction against the real provider.
3. For "given state X" — provider has state setup hooks.
4. Mismatch = broken contract = failing build.

## Example (one stack, illustrative)

> The code below is **Pact's JS binding, shown as one concrete stack** — it is not a recommendation of Pact or of JS. Every contract-testing tool in every language expresses the same three moves (declare the interaction, publish the pact, verify it against the real provider), and the procedure above is written against those moves, not this API. Translate the shape; do not copy the imports.

Consumer:
```ts
provider.addInteraction({
  state: 'user exists with id 42',
  uponReceiving: 'GET /users/42',
  withRequest: { method: 'GET', path: '/users/42' },
  willRespondWith: {
    status: 200,
    body: like({ id: 42, name: string(), email: email() }),
  },
});

await userApi.getUser(42);  // hits mock, records interaction
```

Provider:
```ts
const verifier = new Verifier({
  providerBaseUrl: 'http://localhost:3000',
  pactBrokerUrl: 'https://my-broker',
  stateHandlers: {
    'user exists with id 42': async () => db.users.insert({ id: 42, name: 'Alice' }),
  },
});
await verifier.verify();
```

## Procedure

Provider-side verification (the side with real teeth — replay each interaction against the running provider and cite every mismatch):

1. Fetch the contract(s) for this provider from the broker, scoped to the consumer versions in play:
   ```bash
   pact-broker list-latest-pact-versions --broker-base-url "$PACT_BROKER_URL" --provider <provider>
   # or pull the pact JSON directly: GET /pacts/provider/<provider>/consumer/<consumer>/latest
   ```
2. Start the real provider (not a mock) and register its `stateHandlers` so each `given` state is set up for real.
3. Replay every interaction against the live provider and capture the machine-readable result:
   ```bash
   # JS: verifier.verify() with --reporters json  → verification.json
   # JVM: ./gradlew pactVerify        (build/reports/pact/**)
   # Go:  pact-provider-verifier ... --format=json
   ```
4. Parse the report for mismatches — for each failed interaction capture the `uponReceiving` description, the field/status/header that diverged, and the consumer call-site `<path:line>` the interaction traces to. A mismatch = broken contract = failing build; do not soften it to a warning.
5. Before deploying, run the `can-i-deploy` gate against the prod-deployed consumer versions; a red gate halts the deploy:
   ```bash
   pact-broker can-i-deploy --pacticipant <provider> --version <sha> --to-environment production
   ```
6. Cite the outcome (verified interaction count + mismatch list) in the Output block — a "contracts pass" claim without the replayed counts is a vibe, not a verification.

## Output

A literal report — verified interactions, mismatches cited, and the deploy gate result:

```
Contract verification — <provider> @ <sha>  (broker=<url>)

Consumers verified: 2  |  Interactions replayed: 14  |  Passed: 12  |  Mismatched: 2

MISMATCHES (broken contract — build fails):
  <consumer-a> "GET /users/42 → 200 with user body"
    expected body.email (consumer treats as email())  ←  provider returned null
    consumer call site: web/src/api/user.client.ts:31
  <consumer-b> "POST /orders → 201"
    expected status 201  ←  provider returned 200
    consumer call site: mobile/lib/orders/repo.dart:88

can-i-deploy (to production): BLOCKED
  <provider>@<sha> is not compatible with <consumer-a>@<prod-version> until the 2 mismatches above are fixed.

Closure: 12 interactions verified; 2 mismatches cited with consumer call sites; deploy gate BLOCKED.
```

## Tags + versioning

- Consumer tags contracts with their version.
- Provider verifies specific tag ("contracts from consumer vX").
- `can-i-deploy` CLI checks if current provider works with all consumer versions in prod before deploying.

## When to use

- Multi-service architectures.
- Frontend + backend teams working in parallel.
- Breaking change risk on the API.

## When NOT to use

- Single monolith — unit + integration tests cover it.
- External APIs you don't own (third-party SaaS / vendor APIs) — those are test doubles, not contracts.

## Rules

- Contracts are CONSUMER-DRIVEN. Backend doesn't define what the frontend gets — frontend expresses what it needs.
- Never consume a contract that isn't published + versioned.
- `can-i-deploy` gate in CD pipeline.
- State setup hooks clean up after themselves.

## Anti-patterns

- Over-specifying response bodies (pin everything) — brittle. Use matchers (`like`, `regex`, `eachLike`).
- Writing contracts from the server side (defeats the "consumer-driven" purpose).
- Not versioning contracts.
- Deploying without running `can-i-deploy`.

## Boundary

`contract-test` owns exactly one question: **do two independently-deployed services still agree on the wire?** Everything about a single service's own behaviour belongs elsewhere, and mixing them produces a contract suite that breaks on refactors it should not care about.

- **A single service's internal behaviour** → its own unit / integration suite (`@test-engineer`). If a mismatch is caught by the provider's own tests, it never needed a contract.
- **Presence / strength / breadth of the provider's own tests** → `coverage-gap` (did the branch run), `mutation-probe` (would an assertion catch it breaking), `property-invariants` (does it hold across the input space). A contract can pass against a provider whose logic is entirely untested — it checks the shape of the response, never the correctness of the computation behind it.
- **An API you do not own** (third-party SaaS, a vendor) → those are test doubles, not contracts. You cannot make the vendor run a verification, so there is no second half to the handshake; pin their responses as fixtures and monitor for drift instead.
- **Whether the provider is fast enough under a realistic mix** → `load-test` (performance pack). Contract verification replays interactions one at a time; it says nothing about capacity.

## Related

- `@test-engineer` — writes the provider-side and consumer-side tests the interactions sit inside.
- `@test-reviewer` — audits the resulting assertions; a contract with `like(anything())` on every field passes verification and pins nothing.
- `coverage-gap` / `mutation-probe` — the provider-side quality axes a green contract does not speak to.
- `test-doubles.md` — the pattern for the third-party case above, where a contract is not available.
