# GraphQL servers (Node) reference — Apollo Server and Mercurius

> **Framework**: Apollo Server 5.x (`@apollo/server` 5.5.1, peer `graphql ^16.11.0`, Node 20+) • Mercurius 16.x on Fastify (16.12.0, peer `graphql ^16 || ^17`) — npm registry, 2026-10-14. `graphql` 17.0.2 is `latest`; Apollo Server 5.5.1 does not accept it.
> **Official docs**: https://www.apollographql.com/docs/apollo-server • https://mercurius.dev
> **Version-specific gotchas**: Apollo Server 5 answers **400** for bad variables (v4 answered 200); a resolver error is **200 + `errors[]`** on both servers; one `null` in a non-null list can wipe the whole `data`.
> **Substitution markers**: Replace `<Type>` / `<resolver>` with the project's actual names from `_extracted-idioms.md`.

Every row says how it was established: **run** = executed on Apollo Server 5.5.1 and Mercurius 16.12.0 with `graphql` 16.14.2 (`NODE_ENV=production`) in the backend research labs, or on `dataloader` 2.2.3, on 2026-10-14. Read the installed versions from the lockfile before relying on a row. N+1 and batching efficiency are the database pack's; what an error message leaks is security's.

## Nullability blast radius

| Schema and resolver | Response (run, both servers) |
|---|---|
| `order: Order` (nullable) whose non-null field `total: Money!` resolves `null` | 200, `data.order: null` + one error |
| `orders: [Order!]!` where **one** item resolves `null` or throws | **200, `data: null`** — every other row is lost |

A `!` promises the field never fails. Over a nullable column, an outbound call, or a per-row permission check, mark it nullable (`[Order]!` or `[Order!]` keeps the other rows) or resolve the failure to a value. Owner: http-contract-scan §11 (V346).

## Errors and HTTP status

| Case | Mercurius 16.12.0 | Apollo Server 5.5.1 |
|---|---|---|
| resolver `throw new Error('db at 10.0.0.5 refused')` | 200, raw message in `errors[0].message` | 200, raw message (stack hidden in production) |
| unknown field (document validation) | 400 | 400 `GRAPHQL_VALIDATION_FAILED` |
| variable of the wrong type | 400 | **400 `BAD_USER_INPUT`** (`status400ForVariableCoercionErrors` defaults to true in v5 and is deprecated; v4 answered 200) |
| partial success (`{ boom order }`) | 200, `data` + `errors` | — |

Under the GraphQL-over-HTTP norm, 200 with `errors[]` is correct; what the project owes is one mapping from domain and ORM errors to `extensions.code` in `formatError` (Apollo) or `errorFormatter` (Mercurius), and alerting that reads `errors[]` rather than the HTTP status. Owner: edge-error-scan §7 (V345); domain and ORM classes, edge-error-scan §2 (V330).

## DataLoader scope

| Setup | Result (run, `dataloader` 2.2.3) |
|---|---|
| one `new DataLoader(batchFn)` at module scope; request A loads key 1 (balance 100); a write sets it to 40; request B loads key 1 | B reads **100** — served from A's cache, the batch function ran once |
| `new DataLoader(batchFn)` built per request in the context factory | B reads 40 |

A module-scope loader caches across requests and users: stale reads, and another user's row when the key is not tenant-qualified (the cross-tenant reading is security's). Build loaders in the per-request `context` function. Owner: http-contract-scan §11.

## Input and output

- Variables are coerced by the GraphQL type system before resolvers run; custom scalars (`Decimal`, `BigInt`, `DateTime`) decide what reaches the resolver — a `Float` for money or an `Int` for a 64-bit id is wire-format-scan §1–§2.
- A resolver may return any object; only fields in the schema are sent, so a field added to the row but not to the type silently never ships (wire-format-scan §3).
- Input objects reject unknown fields: the GraphQL specification makes them a coercion error, unlike most REST validators (spec; not run here).

## Which detector owns what

| Concern | Owner |
|---|---|
| non-null lists, module-scope DataLoader | http-contract-scan §11 |
| `formatError` / `errorFormatter` mapping, 200 + `errors[]` | edge-error-scan §7 |
| domain and ORM errors unmapped | edge-error-scan §2 |
| `Float` money, `Int` 64-bit ids, schema projection | wire-format-scan §1–§3 |

Sources: the backend research runs on Apollo Server 5.5.1, Mercurius 16.12.0 and `graphql` 16.14.2 (2026-10-14, research-backend § 1.3 BE-07, § 1.4 BN-13/14); the `dataloader` 2.2.3 run and the npm registry metadata, both 2026-10-14. Paraphrased; no text reproduced beyond identifiers.
