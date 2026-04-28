---
name: contract-test
description: Generate and verify consumer-driven contracts between services (Pact-style). Catches "the frontend + backend disagree on the API" BEFORE integration.
---

# contract-test

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

## Example (Pact JS)

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
- External APIs you don't own (Stripe, Meta) — those are test doubles, not contracts.

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
