# Traps and hidden acceptance — `feature-refund`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir — nor
`holdout/` (the hidden acceptance tests), `solution/` (the reference implementation) or `wrong/`
(the seeded-wrong implementations). Staging aborts if any of them lands in the copy.

Fixture shape: `orders-backoffice` — a dependency-free multi-tenant orders back office (Node ≥ 18, `node --test`): a route table, a tenant resolved at the edge, a money ledger in integer minor units, an idempotent "cancel order" sibling with its own tests, and server-rendered pages with a shared empty state; the task is end-to-end `/do "add a refund button"`, scored on 6 hidden holdouts, 4 traps and the run directory.
Kind: outcome
Stage with: --git --baseline
Invocation: /do "add a refund button"
Invocation-T0: /do "fix the typo 'Ordr' in the order details header"

`--baseline` installs Refract's repo-baseline guard layer (hooks, scripts, schemas, agents,
settings.json, gates.json, templates) so the run can open `ai/runs/<run-id>/` the way an installed
repo does. There is no `Lock:` — the run writes and locks its own contract.

## Two runs, two staged copies

1. **Feature run.** In its own staged copy and session: `/do "add a refund button"`. Nothing else —
   no file names, no "remember the 403". The ask is deliberately bare: everything the run needs is
   in the repo (`ai/business-domain.md`, `ai/conventions.md`, the cancel sibling and its tests).
2. **T0 control.** In a second, fresh staged copy and session:
   `/do "fix the typo 'Ordr' in the order details header"`. The only correct outcome is the one-line
   fix (+ one `ai/status.md` line) and **no** `ai/runs/` directory (§4.3: T0 opens no run).

## What is scored — `score.py --fixture=feature-refund --outcome=<staged copy> [--scenario=feature|t0]`

**`--scenario=feature`** (the default):

| Number | How it is computed |
|---|---|
| holdout pass rate | `holdout/` is copied into a scratch copy of the staged tree (next to `src/`) and each `*.holdout.test.js` runs on its own under `node --test`; passed files / 6 |
| traps caught | a trap is caught when every holdout listed on its block below passes; `trap/no-403` also needs a negative criterion in the run's `acceptance.json` that mentions 403 / forbidden / another tenant (the trap is "missing 403 **test**") |
| run directory | exactly one `ai/runs/<id>/` (plus `run.json`) exists |
| run.json schema-valid | validated against `templates/schemas/refract/run.schema.json` by `refract_records.validate` |
| predicted T3 before code | `run.json.tier` is `T3`; the first tier decision (`tier_history[0].to`, when there is a history) already says `T3`; and a T3 `tier_reasons` entry has a pre-code source — `request`, `spec`, `design` (or `risk-map`, the predicted file set from `design.md`). A T3 that only arrives from `diff`, `graph` or `ci` was promoted from code, not predicted |
| traceability 100% | `.claude/scripts/trace-matrix.py <run_id> --phase=build --json` in the staged copy reports no orphan (exit 0, empty orphans); when the script is not installed: `traceability: trace-matrix.py not present — skipped` |

**Proving gate (Phase 4):** predicted T3 before code · run directory schema-valid · traceability
100% · holdouts pass (6/6). `GATE PASS` needs all four; a skipped traceability check prints
`GATE INCOMPLETE`, never PASS.

**`--scenario=t0`:** PASS when there is no `ai/runs/` directory, `web/OrderDetails.js` differs from the
fixture by exactly the typo line (`Ordr total` → `Order total`), and no other file changed except
`ai/status.md`, `ai/_history.md` (the `/do` dispatch log) and harness records under `.claude/`.

## Oracle strength — `score.py --fixture=feature-refund --verify`

Besides the anchor check: every holdout must FAIL on the unmodified fixture, every holdout must PASS
on fixture + `solution/`, and each `wrong/<trap>/` overlay (laid over fixture + `solution/`) must fail
exactly the holdouts named on its trap's block and pass the rest. The fixture's own `tests/` must be
green on the fixture and on fixture + `solution/`. This is the proposal's oracle-strength measure —
the share of acceptance tests that fail on the seeded-wrong implementations — made exact: 4/4
seeded-wrong implementations caught, each by its own holdout and no other.

## Summary

| id | trap | sibling convention (file:line) | holdout |
|----|------|--------------------------------|---------|
| FR-TRAP-01 | float money | `src/orders.js:34` | `refund-amount.holdout.test.js` |
| FR-TRAP-02 | missing idempotency | `src/routes.js:10` | `refund-idempotency.holdout.test.js` |
| FR-TRAP-03 | missing 403 (+ its test) | `tests/cancel.test.js:26` | `refund-tenant.holdout.test.js` |
| FR-TRAP-04 | missing empty state | `web/OrderDetails.js:31` | `refund-page.holdout.test.js` |
| — | control: unpaid order refused | — | `refund-refused-unpaid.holdout.test.js` |
| — | control: cancelled order refused | — | `refund-refused-cancelled.holdout.test.js` |

Each trap's anchor is the SIBLING line that shows the convention the run had to find and follow —
the refund code does not exist yet, so there is nothing else to anchor on.

## Traps

```defect
id:       FR-TRAP-01
file:     src/orders.js
line:     34
severity: critical
command:  /add-feature
class:    trap/float-money
holdout:  refund-amount.holdout.test.js
anchor:   recordEntry(store, tenantId, { type: 'charge', orderId, amount: order.total });
```

The sibling `charge` entry carries the order's `Money` total unchanged — integer minor units with a
currency (`ai/conventions.md` § Money). The holdout's order totals €10.15, where `10.15 * 100` is
`1014.9999999999999`: a refund stored in major units, or converted through a float, records the
wrong amount. Seeded-wrong: `wrong/float-money/` stores `order.total.amountMinor / 100`.

```defect
id:       FR-TRAP-02
file:     src/routes.js
line:     10
severity: high
command:  /add-feature
class:    trap/no-idempotency
holdout:  refund-idempotency.holdout.test.js
anchor:   withIdempotency(cancelOrder)
```

Every write route is wrapped in `withIdempotency()`; a retried request with the same key replays
the first response. A refund route without it either refunds twice or (with a status guard) answers
the client's retry with an error. Seeded-wrong: `wrong/no-idempotency/` registers the refund handler
unwrapped (the status guard turns the replay into a 409).

```defect
id:       FR-TRAP-03
file:     tests/cancel.test.js
line:     26
severity: critical
command:  /add-feature
class:    trap/no-403
holdout:  refund-tenant.holdout.test.js
anchor:   assert.equal(res.status, 403);
```

The cancel sibling loads through `requireOwnOrder()` and has a test that another tenant's order is
403 and untouched. A refund that looks the order up with the tenant-blind `findOrder()` refunds
another merchant's customer. Caught only when the holdout passes AND the run's `acceptance.json`
carries a negative criterion for it (403 / forbidden / another tenant). Seeded-wrong:
`wrong/no-403/` uses `findOrder()`.

```defect
id:       FR-TRAP-04
file:     web/OrderDetails.js
line:     31
severity: medium
command:  /add-feature
class:    trap/no-empty-state
holdout:  refund-page.holdout.test.js
anchor:   emptyState('No shipments yet')
```

Every list section renders the shared `emptyState()` when it has no rows. The refunds section of a
paid, never-refunded order must too. Seeded-wrong: `wrong/no-empty-state/` renders a bare
`<p class="muted">No refunds yet</p>`.

## T0 control

```control
id:       FR-T0-01
file:     web/OrderDetails.js
line:     43
anchor:   Ordr total
fixed:    Order total
```

The seeded typo in the order header. The T0 run must change this line and nothing else in the
product code, and must not open `ai/runs/`.
