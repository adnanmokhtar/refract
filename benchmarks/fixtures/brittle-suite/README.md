# returnsdesk

Returns and refunds for online merchants. A shopper opens a return, the merchant approves it, the
platform refunds the captured payment, and the payout ledger settles the merchant's balance overnight.

```
api/      NestJS 11 on Fastify + MikroORM 6 (Postgres 16) — returns, refunds, orders, coupons, admin
web/      React 19 + Vite — merchant back office; Jest component tests, Playwright end-to-end tests
svc/      FastAPI — refund risk scoring, receipts, FX quotes, settlement statements
ledger/   Go 1.23 — the payout ledger the nightly settlement job posts to
jvm/      Java 21 — payout calculation library used by the finance batch (Maven)
```

## Tests

| Package | Runner | Command | Where |
|---------|--------|---------|-------|
| api unit | Jest 30 | `npm test --workspace api` | `api/src/**/*.spec.ts` |
| api e2e | Jest 30 + Testcontainers Postgres | `npm run test:e2e --workspace api` | `api/test/e2e` |
| api integration | Jest 30 | `npm run test:int --workspace api` | `api/test/integration` |
| web components | Jest 30 + Testing Library + MSW | `npm test --workspace web` | `web/src/**/*.test.tsx` |
| web e2e | Playwright | `npm run e2e --workspace web` | `web/e2e` |
| svc | pytest 9 | `make test-svc` | `svc/tests` |
| ledger | go test | `make test-ledger` | `ledger/*_test.go` |
| jvm | JUnit 5 (Surefire) | `make test-jvm` | `jvm/src/test/java` |

CI is `.github/workflows/ci.yml`: one job per package on every push and pull request.

Mutation testing: `npm run mutation --workspace api` (StrykerJS) and `mvn -f jvm/pom.xml
org.pitest:pitest-maven:mutationCoverage` (PIT). Neither runs in CI; both are run before a release.

## Configuration

Every service reads its settings from the environment (`.env.example` lists them). Nothing in this
repository holds a credential.
