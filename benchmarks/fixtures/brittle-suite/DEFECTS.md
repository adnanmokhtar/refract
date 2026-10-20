# Seeded defects — `brittle-suite`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `returnsdesk`, returns and refunds for online merchants — NestJS 11 on Fastify + MikroORM 6 API (Jest 30 unit, e2e on Testcontainers Postgres, integration), React 19 back office (Jest + MSW, Playwright), FastAPI risk service (pytest 9), Go 1.23 payout ledger, Java 21 payouts library (JUnit 5 + PIT), one GitHub Actions workflow.
65 test-suite defects — the testing counterpart of `vuln-fullstack` and `slow-marketplace` —
seeded across every class family the testing pack's six detectors own: tests that cannot fail,
tests that never run or never fail CI, flake sources, test doubles that lie, code no test reaches or
pins, and measured strength — plus **21 decoys**: known-safe siblings that look like a seeded
defect and must NOT be reported. Primary target command: **`/test-audit`** (a whole-repo run: the
staged copy has no base branch).

Stage with: --git — `coverage-gap` § 7, `mutation-probe` and the context map read `git`; an
un-initialised copy fails those lanes rather than reporting them `N/A`. `run.sh` reads this line and
git-initialises the staged copy (one commit, no remote: every diff-scoped lane prints `N/A
(whole-repo)`).

**The production code is mostly correct; the defects live in the tests, the runner configs and CI.**
Where production code is wrong (the refund `capture_refund` / `refund_capture` mismatch, the
`€NaN` invoice total, the negative refund window), it is wrong *because* a test that should have
caught it cannot fail — the defect id sits on the test, and the production bug is the evidence.

What makes the fixture measure more than keyword recall: most defects have a correct sibling in
the same tree, and several are only defects once two files are read together. `refund-window.spec.ts`
asserts inside a `catch` the parser never enters, while its sibling rejection test uses `toThrow` —
and that sibling's `.toThrow` is exactly what hides the unreached assertion from the file-level grep.
The `sms.service.spec.ts` victim passes *because* the first case leaked a message into a module-level
array. `orders.service.spec.ts` passes because the drifted double throws a `TypeError`, not because
the order is missing. The `/admin/agents/:id/disable` route has its 403 test; the force-refund route
four handlers above it does not. The invoice snapshot records `€NaN` because the hand-written MSW
body says `total: '12.00'` where the API sends `totalCents`. Reporting the safe half of a pair is
scored too — see **Decoys** below.

Ownership. Every row names the detector that owns its class: `assertion-strength-scan`,
`suite-execution-scan`, `flake-source-scan`, `test-double-scan`, `coverage-gap` and `mutation-probe`
(testing pack), the six detectors `/test-audit` dispatches on a whole-repo run. Where two detectors
legitimately see one site (`--forceExit` is `suite-execution-scan` § 4 and `flake-source-scan` § 6;
`jest -u` in CI is `assertion-strength-scan` § 6c), the row carries one id and its `match:` accepts
either detector's vocabulary.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| BS-AS-01 | `api/src/refunds/refund-batch.service.spec.ts:22` | high | `/test-audit` | assertion/no-assertion |
| BS-AS-02 | `svc/tests/test_risk.py:6` | medium | `/test-audit` | assertion/no-assertion |
| BS-AS-03 | `api/src/billing/invoice-total.spec.ts:9` | high | `/test-audit` | assertion/weak-sole-oracle |
| BS-AS-04 | `api/src/pricing/discount.spec.ts:13` | high | `/test-audit` | assertion/expected-from-sut |
| BS-AS-05 | `api/src/customers/customer.service.spec.ts:14` | medium | `/test-audit` | assertion/mock-echo |
| BS-AS-06 | `api/src/refunds/refund-approval.service.spec.ts:32` | high | `/test-audit` | assertion/interaction-only |
| BS-AS-07 | `ledger/settle_test.go:22` | medium | `/test-audit` | assertion/interaction-only |
| BS-AS-08 | `api/src/refunds/refund-approval.service.spec.ts:37` | high | `/test-audit` | assertion/unawaited |
| BS-AS-09 | `svc/tests/test_receipts.py:5` | high | `/test-audit` | assertion/unawaited-coroutine |
| BS-AS-10 | `api/src/refunds/refund-window.spec.ts:16` | high | `/test-audit` | assertion/unreached |
| BS-AS-11 | `svc/tests/test_validation.py:14` | medium | `/test-audit` | assertion/assert-in-except |
| BS-AS-12 | `api/src/fees/processing-fee.spec.ts:10` | high | `/test-audit` | assertion/swallowed |
| BS-AS-13 | `svc/tests/test_risk.py:19` | high | `/test-audit` | assertion/swallowed |
| BS-AS-14 | `web/src/invoices/InvoiceView.test.tsx:8` | high | `/test-audit` | assertion/snapshot-only |
| BS-AS-15 | `web/package.json:10` | high | `/test-audit` | assertion/snapshot-self-update |
| BS-AS-16 | `jvm/src/test/java/dev/returnsdesk/payouts/PayoutCalculatorTest.java:27` | high | `/test-audit` | assertion/no-op-assertion-api |
| BS-AS-17 | `web/e2e/refund-request.spec.ts:12` | medium | `/test-audit` | assertion/unawaited-web-first |
| BS-SE-01 | `api/src/pricing/shipping-tier.spec.ts:8` | high | `/test-audit` | execution/focused-test |
| BS-SE-02 | `svc/tests/test_chargebacks.py:10` | medium | `/test-audit` | execution/ownerless-skip |
| BS-SE-03 | `api/test/e2e/refund-ledger.e2e-spec.ts:6` | high | `/test-audit` | execution/gate-never-satisfied |
| BS-SE-04 | `api/src/refunds/refund-policy.test.ts:11` | high | `/test-audit` | execution/never-collected |
| BS-SE-05 | `ledger/refund_test.go:8` | high | `/test-audit` | execution/never-collected |
| BS-SE-06 | `svc/tests/test_settlement.py:6` | medium | `/test-audit` | execution/never-collected |
| BS-SE-07 | `jvm/src/test/java/dev/returnsdesk/payouts/PayoutScheduleTest.java:6` | high | `/test-audit` | execution/never-collected |
| BS-SE-08 | `jvm/src/test/java/dev/returnsdesk/payouts/PayoutRepositoryIT.java:12` | high | `/test-audit` | execution/never-collected |
| BS-SE-09 | `.github/workflows/ci.yml:27` | critical | `/test-audit` | execution/ci-masking |
| BS-SE-10 | `.github/workflows/ci.yml:72` | critical | `/test-audit` | execution/ci-masking |
| BS-SE-11 | `.github/workflows/ci.yml:89` | high | `/test-audit` | execution/ci-masking |
| BS-SE-12 | `api/jest.config.ts:13` | high | `/test-audit` | execution/coverage-hiding |
| BS-SE-13 | `svc/app/tax.py:12` | high | `/test-audit` | execution/coverage-hiding |
| BS-SE-14 | `api/src/fx/fx-rate.client.spec.ts:3` | high | `/test-audit` | execution/retry-masking |
| BS-SE-15 | `web/playwright.config.ts:6` | medium | `/test-audit` | execution/retry-masking |
| BS-SE-16 | `api/package.json:11` | high | `/test-audit` | execution/suite-not-in-ci |
| BS-FL-01 | `api/src/coupons/coupon.spec.ts:6` | high | `/test-audit` | flake/time-bomb |
| BS-FL-02 | `svc/tests/test_statements.py:9` | high | `/test-audit` | flake/real-clock |
| BS-FL-03 | `api/test/e2e/refunds.e2e-spec.ts:24` | medium | `/test-audit` | flake/fixed-sleep |
| BS-FL-04 | `ledger/ledger_test.go:71` | medium | `/test-audit` | flake/fixed-sleep |
| BS-FL-05 | `api/src/fx/fx-rate.client.spec.ts:9` | medium | `/test-audit` | flake/real-network |
| BS-FL-06 | `svc/tests/test_fx.py:7` | medium | `/test-audit` | flake/real-network |
| BS-FL-07 | `api/src/subscriptions/trial.spec.ts:5` | medium | `/test-audit` | flake/order-dependence |
| BS-FL-08 | `svc/tests/test_limits.py:7` | medium | `/test-audit` | flake/order-dependence |
| BS-FL-09 | `api/package.json:10` | medium | `/test-audit` | flake/forced-exit |
| BS-FL-10 | `api/src/notifications/digest.spec.ts:5` | medium | `/test-audit` | flake/async-leak |
| BS-FL-11 | `api/src/notifications/sms.service.spec.ts:3` | medium | `/test-audit` | flake/order-dependence |
| BS-FL-12 | `web/src/refunds/RefundDue.test.tsx:7` | medium | `/test-audit` | flake/time-zone |
| BS-FL-13 | `api/test/support/factories.ts:12` | low | `/test-audit` | flake/unseeded-random |
| BS-FL-14 | `web/e2e/refund-request.spec.ts:17` | medium | `/test-audit` | flake/e2e-fixed-wait |
| BS-FL-15 | `web/e2e/refund-request.spec.ts:26` | medium | `/test-audit` | flake/e2e-read-once |
| BS-TD-01 | `api/src/refunds/refund.service.spec.ts:3` | high | `/test-audit` | double/sut-mocked |
| BS-TD-02 | `svc/tests/test_pricing.py:8` | high | `/test-audit` | double/sut-mocked |
| BS-TD-03 | `api/src/orders/orders.service.spec.ts:6` | high | `/test-audit` | double/drifted-double |
| BS-TD-04 | `svc/tests/test_gateway.py:9` | high | `/test-audit` | double/drifted-double |
| BS-TD-05 | `api/test/integration/customer-email.int-spec.ts:10` | high | `/test-audit` | double/engine-substitution |
| BS-TD-06 | `api/src/auth/tenant.guard.ts:17` | high | `/test-audit` | double/test-seam |
| BS-TD-07 | `svc/app/signatures.py:13` | high | `/test-audit` | double/test-seam |
| BS-TD-08 | `web/src/test/handlers.ts:9` | high | `/test-audit` | double/hand-written-http-body |
| BS-TD-09 | `api/test/e2e/orders.e2e-spec.ts:17` | high | `/test-audit` | double/repository-mocked-in-e2e |
| BS-TD-10 | `api/src/loyalty/points.ts:4` | high | `/test-audit` | double/special-cased-input |
| BS-CG-01 | `api/src/orders/orders.controller.ts:16` | critical | `/test-audit` | coverage/no-denial-test |
| BS-CG-02 | `api/src/admin/admin.controller.ts:12` | critical | `/test-audit` | coverage/no-denial-test |
| BS-CG-03 | `api/src/refunds/refund.service.ts:36` | high | `/test-audit` | coverage/error-never-asserted |
| BS-CG-04 | `api/src/webhooks/payment-webhook.handler.ts:24` | high | `/test-audit` | coverage/critical-module-untested |
| BS-CG-05 | `api/src/shipping/carrier.client.ts:28` | medium | `/test-audit` | coverage/no-contract-test |
| BS-MC-01 | `api/src/shipping/free-shipping.ts:6` | high | `/test-audit` | mutation/boundary-survivor |
| BS-MC-02 | `jvm/src/main/java/dev/returnsdesk/payouts/PayoutCalculator.java:23` | high | `/test-audit` | mutation/pseudo-tested |

Severity split: 4 critical · 39 high · 21 medium · 1 low. All 65 target `/test-audit`.

### Coverage by class

Grouped by the detector that owns each class, so a miss can be read as "this detector did not
fire" rather than as a number.

| group | owner | seeded | ids |
|-------|-------|--------|-----|
| no / weak / tautological oracle, no-op assertion API | `assertion-strength-scan` § 1 | 4 | AS-01, AS-02, AS-03, AS-16 |
| interaction-only where a result exists | `assertion-strength-scan` § 2 | 2 | AS-06, AS-07 |
| assertion unreached or un-awaited | `assertion-strength-scan` § 3 | 5 | AS-08, AS-09, AS-10, AS-11, AS-17 |
| failure swallowed by the test | `assertion-strength-scan` § 4 | 2 | AS-12, AS-13 |
| expected value from the SUT; mock echo | `assertion-strength-scan` § 5 | 2 | AS-04, AS-05 |
| snapshot sole or self-updating oracle | `assertion-strength-scan` § 6 | 2 | AS-14, AS-15 |
| focus and skips (owner, never-satisfied gate) | `suite-execution-scan` § 1, § 2 | 3 | SE-01, SE-02, SE-03 |
| never collected; suite no CI job runs | `suite-execution-scan` § 3 | 6 | SE-04, SE-05, SE-06, SE-07, SE-08, SE-16 |
| CI or runner switch that masks failure | `suite-execution-scan` § 4 | 3 | SE-09, SE-10, SE-11 |
| coverage configuration that hides code | `suite-execution-scan` § 5 | 2 | SE-12, SE-13 |
| retries with no flaky gate | `suite-execution-scan` § 6 | 2 | SE-14, SE-15 |
| clock, zone, expiring fixture dates | `flake-source-scan` § 1 | 3 | FL-01, FL-02, FL-12 |
| unseeded randomness | `flake-source-scan` § 2 | 1 | FL-13 |
| fixed sleeps | `flake-source-scan` § 3 | 2 | FL-03, FL-04 |
| real network | `flake-source-scan` § 4 | 2 | FL-05, FL-06 |
| shared state and order dependence | `flake-source-scan` § 5 | 3 | FL-07, FL-08, FL-11 |
| async leaks (forced exit, timers) | `flake-source-scan` § 6 / `suite-execution-scan` § 4 | 2 | FL-09, FL-10 |
| brittle end-to-end waits | `flake-source-scan` § 8 | 2 | FL-14, FL-15 |
| the double replaces the code under test | `test-double-scan` § 1 | 2 | TD-01, TD-02 |
| doubles the type system or `spec` cannot check | `test-double-scan` § 2 | 2 | TD-03, TD-04 |
| hand-written HTTP mock body | `test-double-scan` § 3 | 1 | TD-08 |
| engine substitution; repository mocked in e2e | `test-double-scan` § 4 | 2 | TD-05, TD-09 |
| test seams in shipped code | `test-double-scan` § 5 | 2 | TD-06, TD-07 |
| special-cased test input in shipped code | `test-double-scan` § 6 | 1 | TD-10 |
| guarded route with no denial test | `coverage-gap` § 2 | 2 | CG-01, CG-02 |
| typed error never asserted | `coverage-gap` § 3 | 1 | CG-03 |
| critical module with no test | `coverage-gap` § 4 | 1 | CG-04 |
| consumed API with no contract test | `coverage-gap` § 6 | 1 | CG-05 |
| surviving mutant: boundary, pseudo-tested method | `mutation-probe` § 2, § 4 | 2 | MC-01, MC-02 |
| **decoys (must not be reported)** | — | **21** | DECOY-01 … DECOY-21 |

---

## BS-AS-01 — A refund-batch case that asserts nothing

```defect
id:       BS-AS-01
file:     api/src/refunds/refund-batch.service.spec.ts
line:     22
severity: high
command:  /test-audit
class:    assertion/no-assertion
anchor:   it('refunds every damaged or unopened line of a returned order'
match:    no.?assert|assert(s|ion)?[- ]?(free|less)|asserts? nothing|nothing (is )?(asserted|checked|pinned)|no (expect|check|oracle)|without (an? )?(expect|assert|check)|cannot fail|can.?t fail|never fail
```

The case calls `batch.refundDamaged(returnedOrder)` and ends. The sibling case below it pins
`refundedLines`, but nothing anywhere pins `refundedCents` or the amount each `refund()` call
carries — the money. Probe (break the SUT): refund `line.unitCents` without the quantity, or skip
the `unopened` line; the suite stays green. Fix: assert `refunds.refund` was called with
`('ord_77', 5_000, …)` and `('ord_77', 990, …)` and `summary.refundedCents === 5_990`. Owner:
`assertion-strength-scan` § 1 (oracle-check `no-assertion`, census `no-assertion`).

## BS-AS-02 — A pytest risk-score test with no assert

```defect
id:       BS-AS-02
file:     svc/tests/test_risk.py
line:     6
severity: medium
command:  /test-audit
class:    assertion/no-assertion
anchor:   score_refund(long_standing)
match:    no.?assert|assert(s|ion)?[- ]?(free|less)|asserts? nothing|nothing (is )?(asserted|checked|pinned)|no (expect|check|oracle)|without (an? )?(expect|assert|check)|cannot fail|can.?t fail|never fail
```

`test_scores_a_long_standing_customer_as_safe` computes the score and throws it away. pytest passes
any test that does not raise. Probe: `score_refund` → `return 100` stays green here (the review
threshold test below uses another input). Fix: `assert score_refund(req) == 0`. Owner:
`assertion-strength-scan` § 1.

## BS-AS-03 — `toBeDefined()` is the only check of an invoice total

```defect
id:       BS-AS-03
file:     api/src/billing/invoice-total.spec.ts
line:     9
severity: high
command:  /test-audit
class:    assertion/weak-sole-oracle
anchor:   expect(total).toBeDefined();
match:    toBeDefined|weak (sole )?oracle|existence|only (checks|asserts) (that )?(it|a|the)|any (value|object)|return(s)? (0|zero|\{)|wrong (value|total|amount)
```

`computeInvoiceTotal` returns an object on every path, so `toBeDefined()` holds for any total —
`{ netCents: 0, taxCents: 0, grossCents: 0 }` included. The per-line half-up tax rounding is the
behaviour, and no test pins it (the empty-invoice case only pins zeros). The decoy
`creditNoteTotal` case further down uses `toBeDefined()` as a guard before a `toEqual` (BS-DECOY-19).
Probe: the tax line `Math.floor(... + 5_000)` → `Math.floor(...)` stays green. Fix:
`expect(total).toEqual({ netCents: 4_742, taxCents: 821, grossCents: 5_563 })` from the worked
example. Owner: `assertion-strength-scan` § 1.

## BS-AS-04 — The expected value is computed by the code under test

```defect
id:       BS-AS-04
file:     api/src/pricing/discount.spec.ts
line:     13
severity: high
command:  /test-audit
class:    assertion/expected-from-sut
anchor:   const expected = applyDiscount(cart);
match:    expected.{0,40}(sut|same (call|function)|applyDiscount|code under test|implementation)|tautolog|mirror|self.?(referential|fulfilling)|both sides|computed by (the )?(sut|code|function)|circular
```

`const expected = applyDiscount(cart); expect(applyDiscount(cart)).toBe(expected)` moves with the
implementation: any change to the coupon arithmetic changes both sides. Not a determinism check —
the case is named for the coupon rule. Probe: `Math.floor` → `Math.ceil` stays green. Fix:
`expect(applyDiscount(cart)).toBe(4_031)` (4 742 − floor(711.3)). Owner: `assertion-strength-scan`
§ 5 (grep 5a).

## BS-AS-05 — A mock echo: the fixture is already in the shape the SUT produces

```defect
id:       BS-AS-05
file:     api/src/customers/customer.service.spec.ts
line:     14
severity: medium
command:  /test-audit
class:    assertion/mock-echo
anchor:   expect(profile).toEqual(customer);
match:    echo|mock(ed)? (value|return|row|object)|return(s|ed)? (what|the (value|object)) the (mock|repo|stub|double)|pass.?through|already (canonical|normali[sz]ed|masked|lower)|same (object|value)|transform
```

`profile()` lower-cases the email and masks the phone, but the stubbed row is already lower-case and
already masked, so `toEqual(customer)` holds whether or not the SUT transforms anything. Probe:
drop `.toLowerCase()` and the masking — green. Fix: stub `{ email: ' Ana@Shop.TEST ', phone:
'+49 151 2345 0142' }` and expect `{ email: 'ana@shop.test', phone: '***-***-0142' }`. The
`test_gateway.py` echo is a pass-through adapter (§ 21) and is not seeded. Owner:
`assertion-strength-scan` § 5 (grep 5b).

## BS-AS-06 — Approval asserts that `save` was called, not what was saved

```defect
id:       BS-AS-06
file:     api/src/refunds/refund-approval.service.spec.ts
line:     32
severity: high
command:  /test-audit
class:    assertion/interaction-only
anchor:   expect(returns.save).toHaveBeenCalled();
match:    interaction|toHaveBeenCalled|count.?only|(save|repo(sitory)?) (was )?called|call (count|happened)|not (the )?(amount|refundCents|payload|arguments|status)|arguments
```

The case is named for "the refund amount net of the restocking fee", and pins only that
`returns.save` ran. A wrong `refundCents` (the fee taken per opened line, or not at all) is saved
green. Probe: `request.refundCents = gross` — green. Fix:
`expect(returns.save).toHaveBeenCalledWith(expect.objectContaining({ status: 'approved',
refundCents: 3_750, approvedBy: 'agent_7' }))`. Owner: `assertion-strength-scan` § 2 (census
`interaction-only:count-only`).

## BS-AS-07 — Go: the settle test asserts only that the payout mock was called

```defect
id:       BS-AS-07
file:     ledger/settle_test.go
line:     22
severity: medium
command:  /test-audit
class:    assertion/interaction-only
anchor:   p.AssertExpectations(t)
match:    AssertExpectations|interaction|mock(ed)? (was )?called|only (checks|asserts|verifies)|mock\.Anything|net(Cents| payout)?|result (is )?(discarded|ignored)|_, _ =
```

`Settle` computes the net payout and the fee; the test discards the result (`_, _ =`) and pins the
call with `mock.Anything` for the settlement, so any amount satisfies `AssertExpectations`. Probe:
`NetCents: credits - debits` (fee dropped) — green. Fix: match the settlement argument
(`Settlement{MerchantID: "m_1", NetCents: 86_500, FeeCents: 1_500}`) and assert the returned value.
Owner: `assertion-strength-scan` § 2 (grep 2b; oracle-check reports it `no-assertion`).

## BS-AS-08 — A floating `.rejects` assertion on the expired-window refusal

```defect
id:       BS-AS-08
file:     api/src/refunds/refund-approval.service.spec.ts
line:     37
severity: high
command:  /test-audit
class:    assertion/unawaited
anchor:   expect(service.refundApproved('ret_9')).rejects
match:    await|floating|un.?awaited|(?:not|n.t) (awaited|returned)|promise
```

`expect(service.refundApproved('ret_9')).rejects.toThrow(...)` is neither awaited nor returned. On
Jest 30 (`api/package.json`) the case ends before the promise settles: a refund that *succeeds*
past the window is a green test, and the rejection surfaces — if at all — as an unhandled
rejection beside another file. Proof (assertion flip): expect `TypeError` instead — still green.
Fix: `await expect(...).rejects.toThrow(RefundWindowExpiredError)`. Owner: `assertion-strength-scan`
§ 3 (census `floating-async`).

## BS-AS-09 — `assert` on an un-awaited coroutine

```defect
id:       BS-AS-09
file:     svc/tests/test_receipts.py
line:     5
severity: high
command:  /test-audit
class:    assertion/unawaited-coroutine
anchor:   assert render_receipt("rf_1"
match:    coroutine|await|truthy|always (true|passes)|never (awaited|runs)
```

`render_receipt` is `async`; `assert render_receipt(...)` asserts a coroutine object, which is
always truthy, and the receipt is never built. Probe: make `render_receipt` return `None` for every
input — green (pytest prints a `RuntimeWarning: coroutine ... was never awaited` it does not fail
on). Fix: `assert await render_receipt(...) == Receipt(...)`, and run with
`-W error::RuntimeWarning`. Owner: `assertion-strength-scan` § 3 (grep 3e).

## BS-AS-10 — The rejection assertion sits in a `catch` the parser never enters

```defect
id:       BS-AS-10
file:     api/src/refunds/refund-window.spec.ts
line:     16
severity: high
command:  /test-audit
class:    assertion/unreached
anchor:   expect(e).toBeInstanceOf(RefundWindowFormatError);
match:    catch|never (throws|reached|runs|entered)|unreached|expect\.assertions|toThrow|no exception|try
```

`parseRefundWindow('P-3D')` does not throw — the pattern `^P(-?\d+)D$` accepts the sign and
returns a negative window — so the `catch` and its `expect` never run and the case passes. That
hides a real bug: a merchant typo of `P-3D` makes every refund "expired". Grep 3b misses it: its
file filter drops any file that also contains `.toThrow`, and the sibling rejection test
(BS-DECOY-21's neighbour) does. Fix: `expect(() => parseRefundWindow('P-3D')).toThrow(...)` — red
until the pattern drops `-?`. Owner: `assertion-strength-scan` § 3.

## BS-AS-11 — pytest: the assertion lives in an `except` (PT017)

```defect
id:       BS-AS-11
file:     svc/tests/test_validation.py
line:     14
severity: medium
command:  /test-audit
class:    assertion/assert-in-except
anchor:   assert "XYZ" in str(e)
match:    except|PT017|never (raises|reached)|pytest\.raises|unreached|no exception|try
```

If `validate_refund_request` stops raising for an unsupported currency, the `except` never runs and
the test passes. Proof: delete the currency check — green. Fix: `with
pytest.raises(ValidationError, match="XYZ"):` as the zero-amount test below already does. Owner:
`assertion-strength-scan` § 3 (grep 3e; Ruff `PT017`).

## BS-AS-12 — A `try { expect } catch {}` that tolerates its own failure

```defect
id:       BS-AS-12
file:     api/src/fees/processing-fee.spec.ts
line:     10
severity: high
command:  /test-audit
class:    assertion/swallowed
anchor:   expect(processingFee(2_500)).toBe(103);
match:    catch|swallow|tolerat|empty catch|discard|try
```

The comment says rounding "differs between card schemes", and the empty `catch` turns any
failure of the fee assertion into a pass. `expect.hasAssertions()` would not help: the swallowed
`expect` still counts. Proof (assertion flip): `toBe(999)` — green. Fix: no `try` around the
assertion; pin 103 (2.9 % of 25.00 = 72.5 → 73, + 30). Owner: `assertion-strength-scan` § 4
(grep 4a).

## BS-AS-13 — `except Exception: pass` around two asserts

```defect
id:       BS-AS-13
file:     svc/tests/test_risk.py
line:     19
severity: high
command:  /test-audit
class:    assertion/swallowed
anchor:   except Exception:
match:    except|swallow|pass\b|AssertionError|discard|try
```

`AssertionError` is an `Exception`, so both asserts in
`test_opened_item_alone_does_not_need_review` can fail silently. Proof (assertion flip): `== 99` —
green. Fix: delete the `try` / `except`. Owner: `assertion-strength-scan` § 4 (grep 4c).

## BS-AS-14 — A 109-line DOM snapshot is the only oracle of the invoice totals

```defect
id:       BS-AS-14
file:     web/src/invoices/InvoiceView.test.tsx
line:     8
severity: high
command:  /test-audit
class:    assertion/snapshot-only
anchor:   expect(container).toMatchSnapshot();
match:    snapshot
```

The only assertion on `InvoiceView` is a snapshot of the whole tree, and the stored snapshot
records **`€NaN`** in the "Total due" cell: the MSW handler (BS-TD-08) answers `total: '12.00'`
where the component reads `totalCents`, and the snapshot faithfully pinned the broken output. A
reviewer cannot see a total in a 109-line diff. Fix: assert the total cell —
`expect(screen.getByTestId('invoice-total')).toHaveTextContent('€12.00')` — and keep at most a small
snapshot. Owner: `assertion-strength-scan` § 6 (census `snapshot-only`, grep 6b).

## BS-AS-15 — CI rewrites every snapshot it would fail on (`jest -u`)

```defect
id:       BS-AS-15
file:     web/package.json
line:     10
severity: high
command:  /test-audit
class:    assertion/snapshot-self-update
anchor:   "test:ci": "jest --ci -u"
match:    -u\b|update.?snapshot|rewrit|overwrit|snapshot
```

The `web` CI job runs `npm run test:ci`, which is `jest --ci -u`: any snapshot mismatch is
rewritten in the runner instead of failing. Every snapshot oracle in `web/` is self-updating — the
`€NaN` above would have been re-recorded as anything. Static fact: the script line and the
`ci.yml` step that runs it. Fix: drop `-u` (`--ci` alone refuses to write snapshots). Owner:
`assertion-strength-scan` § 6 (grep 6c).

## BS-AS-16 — AssertJ `assertThat(payout);` with no terminal call

```defect
id:       BS-AS-16
file:     jvm/src/test/java/dev/returnsdesk/payouts/PayoutCalculatorTest.java
line:     27
severity: high
command:  /test-audit
class:    assertion/no-op-assertion-api
anchor:   assertThat(payout);
match:    assertThat|no (terminal|assertion|matcher)|asserts? nothing|incomplete|never (checks|asserts)|isEqualTo|chain|no-op
```

`assertThat(x)` builds an assertion object and checks nothing until a terminal call
(`isEqualTo`, …). The reserve-hold case therefore passes for any payout. Error Prone
`CheckReturnValue` and PMD `UnitTestShouldIncludeAssert` name it. Probe: `payable = net` (reserve
ignored) — green. Fix: `assertThat(payout.payableCents()).isZero(); assertThat(payout.heldCents())
.isEqualTo(7_880);`. Owner: `assertion-strength-scan` § 1 (grep 1c).

## BS-AS-17 — Playwright: an un-awaited web-first assertion

```defect
id:       BS-AS-17
file:     web/e2e/refund-request.spec.ts
line:     12
severity: medium
command:  /test-audit
class:    assertion/unawaited-web-first
anchor:   expect(page.getByText('Saved')).toBeVisible();
match:    await|floating|not awaited|promise|web.?first
```

`expect(locator).toBeVisible()` returns a promise; without `await` the test ends before the
assertion retries, and a confirmation that never appears is a pass. Proof (assertion flip):
`getByText('Never shown')` — green. Fix: `await expect(page.getByText('Saved')).toBeVisible()`;
lint `playwright/missing-playwright-await`. Owner: `assertion-strength-scan` § 3 (census
`floating-async`).

## BS-SE-01 — A committed `it.only` silently skips three cases

```defect
id:       BS-SE-01
file:     api/src/pricing/shipping-tier.spec.ts
line:     8
severity: high
command:  /test-audit
class:    execution/focused-test
anchor:   it.only('sends a heavy parcel express'
match:    \.only|focus|exclusive
```

`it.only` makes Jest run one case in the file; the fragile, letter and standard cases are
skipped and the file still reports green in the `api-unit` job. No guard exists: no
`jest/no-focused-tests` lint rule, and Jest has no `forbidOnly`. Proof: the collected list with
and without the `.only` (1 of 4). Fix: remove it; add `jest/no-focused-tests` at error. Owner:
`suite-execution-scan` § 1 (grep 1a).

## BS-SE-02 — A bare `@pytest.mark.skip` on the chargeback-reserve rule

```defect
id:       BS-SE-02
file:     svc/tests/test_chargebacks.py
line:     10
severity: medium
command:  /test-audit
class:    execution/ownerless-skip
anchor:   @pytest.mark.skip
match:    skip|disabled|owner|reason|expir
```

No reason, no ticket, no owner, no date — and it disables the only test of the partial-dispute
reserve. The sibling `skipif(sys.platform == "win32", reason=… #431, owner …)` in `test_paths.py`
is the correct shape (BS-DECOY-14). Fix: un-skip (it passes) or carry a reason, owner and
delete-by date (QG-7). Owner: `suite-execution-scan` § 2 (grep 2a).

## BS-SE-03 — An env-gated e2e suite whose variable no CI job sets

```defect
id:       BS-SE-03
file:     api/test/e2e/refund-ledger.e2e-spec.ts
line:     6
severity: high
command:  /test-audit
class:    execution/gate-never-satisfied
anchor:   const describeWithLedger = process.env.LEDGER_DATABASE_URL
match:    LEDGER_DATABASE_URL|env(ironment)? (var|gate)|gated|describe\.skip|never (runs|set|satisfied)|skip
```

`describeWithLedger` is `describe.skip` unless `LEDGER_DATABASE_URL` is set, and the `api-e2e`
job's `env:` sets only `DATABASE_*`. The refund-to-ledger debit — money leaving a merchant
balance — is never exercised in CI. Proof: the job's env block plus the suite absent from the
executed list. Fix: provide the variable in `api-e2e` (or a ledger service container) and fail
when it is missing in CI. Owner: `suite-execution-scan` § 2 (grep 2c).

## BS-SE-04 — `refund-policy.test.ts` under a `\.spec\.ts$` testRegex

```defect
id:       BS-SE-04
file:     api/src/refunds/refund-policy.test.ts
line:     11
severity: high
command:  /test-audit
class:    execution/never-collected
anchor:   describe('isRefundable'
match:    collect|testRegex|\.spec\.ts|never (runs|run|picked)|(?:not|n.t) (run|picked|matched)|pattern|unclaimed
```

`api/jest.config.ts` collects `.*\.spec\.ts$`; this file is `.test.ts`, so its four cases —
final sale, groceries, the 14-day electronics cap — have never run. Proof: `npx jest --listTests`
omits it (grep 3a prints `UNCLAIMED`). Fix: rename to `refund-policy.spec.ts`, then break the SUT
and watch it fail. Owner: `suite-execution-scan` § 3.

## BS-SE-05 — Go: `func Testrefund` is not a test

```defect
id:       BS-SE-05
file:     ledger/refund_test.go
line:     8
severity: high
command:  /test-audit
class:    execution/never-collected
anchor:   func Testrefund(t *testing.T)
match:    Testrefund|lower.?case|not (a test|run|collected)|never (runs|run)|collect|upper.?case|capital|TestRefund
```

`go test` runs `TestXxx` only when the character after `Test` is not lower-case; `Testrefund` is an
ordinary function, so the debit-and-balance check never runs. `go vet` reports it
(`tests` analyzer). Proof: `go test -list '.*' ./...` omits it. Fix: `TestRefund`. Owner:
`suite-execution-scan` § 3 (grep 3c).

## BS-SE-06 — pytest: a test class with `__init__` is never collected

```defect
id:       BS-SE-06
file:     svc/tests/test_settlement.py
line:     6
severity: medium
command:  /test-audit
class:    execution/never-collected
anchor:   def __init__(self):
match:    __init__|collect|PytestCollectionWarning|never (runs|run)|not (run|collected)
```

pytest refuses to collect a `Test*` class that defines `__init__` (a `PytestCollectionWarning`),
so both payout-netting cases are dead. Proof: `pytest --collect-only -q` lists neither. Fix: a
fixture or `setup_method`. Owner: `suite-execution-scan` § 3 (grep 3c).

## BS-SE-07 — JUnit 4 `@Test` under the Jupiter engine without vintage

```defect
id:       BS-SE-07
file:     jvm/src/test/java/dev/returnsdesk/payouts/PayoutScheduleTest.java
line:     6
severity: high
command:  /test-audit
class:    execution/never-collected
anchor:   import org.junit.Test;
match:    junit ?4|org\.junit\.Test|vintage|jupiter|never (runs|run)|not (run|collected|discovered)
```

`pom.xml` declares `junit-jupiter` and, to make this file compile, `junit:junit` 4.13 — but no
`junit-vintage-engine`. Surefire on the JUnit Platform discovers only Jupiter tests; the three
weekend-payout cases compile and never run. Proof: the Surefire report lists `PayoutCalculatorTest`
only. Fix: `org.junit.jupiter.api.Test` and drop the JUnit 4 dependency. Owner:
`suite-execution-scan` § 3 (grep 3c).

## BS-SE-08 — `*IT.java` with only Surefire configured

```defect
id:       BS-SE-08
file:     jvm/src/test/java/dev/returnsdesk/payouts/PayoutRepositoryIT.java
line:     12
severity: high
command:  /test-audit
class:    execution/never-collected
anchor:   class PayoutRepositoryIT {
match:    failsafe|surefire|\bIT\b|never (runs|run)|not (run|executed)|integration
```

Surefire's default includes are `*Test`, `Test*`, `*Tests`, `*TestCase`; `*IT` classes run only
under `maven-failsafe-plugin`, which `pom.xml` does not declare. `mvn verify` in CI therefore never
runs the idempotent-insert test — the one that proves a re-run of a settlement day pays nobody
twice. Found by reading the pom: the absence has no line. Fix: add failsafe with
`integration-test` and `verify` goals. Owner: `suite-execution-scan` § 3.

## BS-SE-09 — `continue-on-error: true` on the e2e job

```defect
id:       BS-SE-09
file:     .github/workflows/ci.yml
line:     27
severity: critical
command:  /test-audit
class:    execution/ci-masking
anchor:   continue-on-error: true
match:    continue-on-error|allowed to fail|never fails|mask|always green|advisory
```

The whole `api-e2e` job — every route-level test, including the tenant 404s — may fail without
failing the workflow, and it carries no owner or end date. Proof: the CI canary (a red e2e case on
a branch leaves the run green); without push rights the line is the static fact. Fix: remove it,
or name an owner and an expiry for an advisory window. Owner: `suite-execution-scan` § 4
(grep 4a).

## BS-SE-10 — `pytest … || true` in the svc job

```defect
id:       BS-SE-10
file:     .github/workflows/ci.yml
line:     72
severity: critical
command:  /test-audit
class:    execution/ci-masking
anchor:   --junitxml=pytest.xml || true
match:    \|\|\s*true|exit (code|status)|mask|swallow|never fails|ignored|always (passes|green)
```

The step's exit status is discarded; a red risk or settlement test leaves the job green. Fix: drop
`|| true`, and give the upload step `if: always()` so the report still uploads on red. Owner:
`suite-execution-scan` § 4 (grep 4a).

## BS-SE-11 — `go test | tee` without `pipefail`

```defect
id:       BS-SE-11
file:     .github/workflows/ci.yml
line:     89
severity: high
command:  /test-audit
class:    execution/ci-masking
anchor:   go test -race ./... | tee go-test.log
match:    pipefail|tee|pipe|exit (code|status)|mask
```

A `run:` step with no `shell:` runs under `bash -e {0}` on GitHub-hosted runners — without
`-o pipefail` — so the step's status is `tee`'s, which is 0. A failing ledger test is green. Proof:
the canary; statically, the step has no `shell: bash` (which would add `pipefail`) and the job has
no `defaults.run.shell`. Fix: `shell: bash` on the step, or `set -o pipefail`. Owner:
`suite-execution-scan` § 4 (grep 4b).

## BS-SE-12 — `coveragePathIgnorePatterns` drops the whole billing module

```defect
id:       BS-SE-12
file:     api/jest.config.ts
line:     13
severity: high
command:  /test-audit
class:    execution/coverage-hiding
anchor:   '<rootDir>/src/billing/'
match:    coverage
match:    billing|ignore|exclu|hid
```

Invoice totals and credit notes — money — are removed from the coverage report, so the 80 %
floor is met without them and their weak test (BS-AS-03) never shows as a gap. No reason is
recorded. Proof: the coverage inventory with the pattern removed (`src/billing/*` appears, with its
hit counts). Fix: delete the entry; exclude only generated code, each with a reason. Owner:
`suite-execution-scan` § 5 (grep 5b).

## BS-SE-13 — `# pragma: no cover` on the cross-border VAT branch

```defect
id:       BS-SE-13
file:     svc/app/tax.py
line:     12
severity: high
command:  /test-audit
class:    execution/coverage-hiding
anchor:   else:  # pragma: no cover
match:    pragma|no cover|coverage|exclu
```

The OSS (distance-sales) VAT branch is hand-written tax logic, not platform glue, and the pragma
hides that no test reaches it — `oss_rate` raises `KeyError` for every country outside AT and NL.
Fix: remove the pragma and test AT and an unsupported country. Owner: `suite-execution-scan` § 5
(grep 5a).

## BS-SE-14 — `jest.retryTimes(3)` on the FX suite with no flaky gate

```defect
id:       BS-SE-14
file:     api/src/fx/fx-rate.client.spec.ts
line:     3
severity: high
command:  /test-audit
class:    execution/retry-masking
anchor:   jest.retryTimes(3);
match:    retr|rerun|flak
```

Three silent retries per case, no owner, no expiry, and Jest has no flaky gate — the real-network
test below (BS-FL-05) is retried green instead of fixed. Proof: retries off, the case fails k of N
offline. Fix: remove the retry and the network call. Owner: `suite-execution-scan` § 6 (grep 6a).

## BS-SE-15 — Playwright `retries: 2` without `--fail-on-flaky-tests`

```defect
id:       BS-SE-15
file:     web/playwright.config.ts
line:     6
severity: medium
command:  /test-audit
class:    execution/retry-masking
anchor:   retries: 2,
match:    retr|flak|fail-on-flaky
```

Every end-to-end test gets two retries in every environment, and neither the config nor the `web`
CI step fails on a test that passed only on retry — the fixed `waitForTimeout` below (BS-FL-14)
is what it hides. Fix: `retries: process.env.CI ? 2 : 0` with `--fail-on-flaky-tests` in CI, or
`retries: 0`. Owner: `suite-execution-scan` § 6 (grep 6a).

## BS-SE-16 — The integration suite (`test:int`) is run by no CI job

```defect
id:       BS-SE-16
file:     api/package.json
line:     11
severity: high
command:  /test-audit
class:    execution/suite-not-in-ci
anchor:   "test:int":
match:    test:int|integration (suite|tests?)|int-spec|jest\.int
```

`jest.int.config.ts` collects `test/integration/*.int-spec.ts` — customer email uniqueness and the
merchant-balance view — and no workflow step, Makefile target or scheduled job invokes
`test:int`. Proof: `ci.yml` runs `test`, `test:e2e` and `test:ci` only (grep 3b: `NOT-IN-CI`). Fix:
an `api-int` job, or a scheduled workflow with an owner. Owner: `suite-execution-scan` § 3.

## BS-FL-01 — A store-credit fixture that expires on 1 January 2027

```defect
id:       BS-FL-01
file:     api/src/coupons/coupon.spec.ts
line:     6
severity: high
command:  /test-audit
class:    flake/time-bomb
anchor:   expiresAt: '2027-01-01',
match:    2027|expir|time.?bomb|fixed (date|day)|hard.?coded date|real clock|future date
```

`redeemRefusal` compares `expiresAt` to `Date.now()`; nothing freezes the clock in this file. On
2027-01-02 the "accepts unused store credit" case turns red with no code change — inside 90 days of
this fixture's date, so high. Proof: `faketime '2027-01-02'` → red; `expiresAt` derived from a pinned
clock → green. Fix: `jest.useFakeTimers().setSystemTime(...)` in the file, or a relative date.
Owner: `flake-source-scan` § 1 (grep 1b).

## BS-FL-02 — A statement label compared to the real month

```defect
id:       BS-FL-02
file:     svc/tests/test_statements.py
line:     9
severity: high
command:  /test-audit
class:    flake/real-clock
anchor:   == "October 2026"
match:    datetime\.now|October 2026|clock|time.?bomb|current (month|date)|freeze|real (time|clock)
```

`statement_label(datetime.now().date()) == "October 2026"` passes only during October 2026. The file
does freeze the clock — for one other test (`@freeze_time`, BS-DECOY-17) — which is why the
file-level freeze filter of grep 1c drops it; grep 1a still lists the line. Proof: `faketime
'2026-11-01'` → red. Fix: `@freeze_time("2026-10-15")`, or pass a fixed date. Owner:
`flake-source-scan` § 1.

## BS-FL-03 — A 500 ms sleep stands in for "the webhook has landed"

```defect
id:       BS-FL-03
file:     api/test/e2e/refunds.e2e-spec.ts
line:     24
severity: medium
command:  /test-audit
class:    flake/fixed-sleep
anchor:   setTimeout(resolve, 500)
match:    sleep|setTimeout|fixed (delay|wait|timeout)|500\s*ms|timing|wait
```

The e2e case sleeps half a second hoping the outbox worker delivered the provider webhook, then
asserts the refunded amount. Under CPU stress or a slow container it reads before the write.
Proof: `stress-ng --cpu $(nproc)` beside the run, k of N. Fix: poll the order until
`refundedCents` matches, with a deadline. Owner: `flake-source-scan` § 3 (grep 3a).

## BS-FL-04 — Go: `time.Sleep` waits for the background flusher

```defect
id:       BS-FL-04
file:     ledger/ledger_test.go
line:     71
severity: medium
command:  /test-audit
class:    flake/fixed-sleep
anchor:   time.Sleep(200 * time.Millisecond)
match:    Sleep|sleep|timing|200\s*ms|wait
```

The test enqueues a posting and sleeps 200 ms for `Run` to drain it. Under `-race` on a busy
runner the goroutine may not have run. Proof: `go test -race -count=200 -run TestQueuedPostings`
with `GOMAXPROCS=1`, k of N. Fix: a flushed signal (`l.Flush(ctx)`), `require.Eventually`, or
`testing/synctest`. Owner: `flake-source-scan` § 3 (grep 3b).

## BS-FL-05 — A unit test calls the live FX provider

```defect
id:       BS-FL-05
file:     api/src/fx/fx-rate.client.spec.ts
line:     9
severity: medium
command:  /test-audit
class:    flake/real-network
anchor:   await fetch('https://api.exchangerate.host
match:    network|exchangerate|real (api|http|endpoint|service|provider)|live (api|call|provider|service)|external|fetch|internet
```

The "plausible mid-market rate" case fetches the provider directly, then calls `client.quote`,
which fetches it again — two live calls per run, and the rates can move between them. No
interceptor exists (grep 0b: only `web/` has an MSW server). Proof: the suite offline
(`unshare -rn`) → red. Fix: `nock.disableNetConnect()` and a recorded body. Owner:
`flake-source-scan` § 4 (grep 4a).

## BS-FL-06 — pytest calls the live FX provider

```defect
id:       BS-FL-06
file:     svc/tests/test_fx.py
line:     7
severity: medium
command:  /test-audit
class:    flake/real-network
anchor:   requests.get("https://api.exchangerate.host
match:    network|exchangerate|real (api|http|endpoint|service|provider)|live (api|call|provider|service)|external|requests\.get|internet
```

Same shape in Python: the expected value is fetched from the live provider with `requests.get`, and
`eur_rate` fetches it again. Proof:
`pytest --disable-socket --allow-hosts=127.0.0.1,::1` → red. Fix: `responses`/`respx` with a
recorded body. Owner: `flake-source-scan` § 4 (grep 4b).

## BS-FL-07 — A `Date.now` spy that leaks into the next case

```defect
id:       BS-FL-07
file:     api/src/subscriptions/trial.spec.ts
line:     5
severity: medium
command:  /test-audit
class:    flake/order-dependence
anchor:   jest.spyOn(Date, 'now')
match:    restore|spyOn|leak|order|polluti|shared state|Date\.now
```

The first case stubs `Date.now` and never restores it; `jest.config.ts` sets `clearMocks` (which
clears calls, not implementations) and no `restoreMocks`. The second case — "a trial started a week
ago" — passes only because the stub is still there: alone (`-t`) or shuffled
(`--randomize --seed=…`) it returns 0, not 7. Proof: the victim alone → red. Fix: `restoreMocks:
true`, and pin the clock in a `beforeEach` both cases share. Owner: `flake-source-scan` § 5
(grep 5b).

## BS-FL-08 — An environment variable set by one test and never restored

```defect
id:       BS-FL-08
file:     svc/tests/test_limits.py
line:     7
severity: medium
command:  /test-audit
class:    flake/order-dependence
anchor:   os.environ["REFUND_LIMIT_CENTS"] = "10000"
match:    environ|env(ironment)? var|restore|leak|monkeypatch|order|polluti
```

The limit stays 10 000 for the rest of the session. `test_settlement.py::test_a_large_settlement_
correction_needs_a_supervisor` passes only because this file runs first (alphabetical order): run
alone, or under `pytest-randomly`, it is red (limit back to 50 000). Proof: the victim alone →
red. Fix: `monkeypatch.setenv`, as `test_settings.py` does (BS-DECOY-12). Owner:
`flake-source-scan` § 5 (grep 5d).

## BS-FL-09 — `--forceExit` on the e2e script hides open handles

```defect
id:       BS-FL-09
file:     api/package.json
line:     10
severity: medium
command:  /test-audit
class:    flake/forced-exit
anchor:   --forceExit
match:    forceExit|force.?exit|open handles?
```

No e2e file closes the Nest app or stops its Postgres container (`boot-app.e2e.ts` has no
teardown), and `--forceExit` makes the run exit 0 over them — on Jest 30 it also lets an
un-awaited failing assertion pass. Proof: `jest --detectOpenHandles` names the app, the pool and
the container. Fix: `afterAll(() => app.close(); db.stop())`, then drop the flag. Owner:
`flake-source-scan` § 6 / `suite-execution-scan` § 4 (grep 6a, 4c).

## BS-FL-10 — Fake timers installed in one case and never restored

```defect
id:       BS-FL-10
file:     api/src/notifications/digest.spec.ts
line:     5
severity: medium
command:  /test-audit
class:    flake/async-leak
anchor:   jest.useFakeTimers();
match:    useRealTimers|fake timers?|useFakeTimers|restore|leak|timer|interval
```

The first case installs fake timers and discards `startDigest`'s stop function; the second case
leans on timers it never installed and leaves a second interval running. Run alone, the second
case advances timers that are not fake. Proof: the second case alone under
`--detectOpenHandles`; reversed order. Fix: `beforeEach(useFakeTimers)` / `afterEach(useRealTimers)`
and call the returned stop. Owner: `flake-source-scan` § 6 (grep 6b).

## BS-FL-11 — A module-level `sent` array no case resets — and a victim that depends on it

```defect
id:       BS-FL-11
file:     api/src/notifications/sms.service.spec.ts
line:     3
severity: medium
command:  /test-audit
class:    flake/order-dependence
anchor:   const sent: SmsMessage[] = [];
match:    module.?level|shared|\bsent\b|reset|leak|order|polluti|toHaveLength\(2\)
```

Both cases push into the same array. The second is named "sends one text for a repeated booking"
and asserts `toHaveLength(2)` — true only because the first case's message is still there. Alone or
reversed it is red; and the dedupe it claims to pin is unchecked. Proof: `jest -t 'repeated
booking'` → red. Fix: `beforeEach(() => { sent.length = 0 })` and `toHaveLength(1)`. Owner:
`flake-source-scan` § 5 (grep 5c).

## BS-FL-12 — A due-date assertion that holds only in UTC

```defect
id:       BS-FL-12
file:     web/src/refunds/RefundDue.test.tsx
line:     7
severity: medium
command:  /test-audit
class:    flake/time-zone
anchor:   toHaveTextContent('Refund due by Mar 29, 2026')
match:    time ?zone|\bTZ\b|toLocaleDateString|UTC|Mar 29|zone
```

`RefundDue` formats `2026-03-29T00:30:00Z` with `toLocaleDateString` in the runner's zone. In UTC
(the CI runner) it prints Mar 29; west of UTC it prints Mar 28 and the case is red. No grep sees
it: the clock read is in the component, not the test. Proof: `TZ=America/New_York npx jest
RefundDue` → red. Fix: format with an explicit `timeZone` (the merchant's), and pin `TZ` in the Jest
config. Owner: `flake-source-scan` § 1 (perturbation only).

## BS-FL-13 — Unseeded faker emails against a unique `(tenant, email)` key

```defect
id:       BS-FL-13
file:     api/test/support/factories.ts
line:     12
severity: low
command:  /test-audit
class:    flake/unseeded-random
anchor:   email: faker.internet.email()
match:    faker|seed|random|collision|unique
```

Every seeded order seeds a customer with a random email in one tenant; `(tenant_id, email)` is
unique and case-insensitive (`citext`). faker's address space is small (name × provider), so the
birthday bound makes a duplicate-key failure a matter of suite size. Proof: three `faker.seed(n)`
runs, or force a repeated value. Fix: `faker.seed(...)` once per file and a sequence suffix. Owner:
`flake-source-scan` § 2 (grep 2a).

## BS-FL-14 — `waitForTimeout(800)` before reading the recomputed refund amount

```defect
id:       BS-FL-14
file:     web/e2e/refund-request.spec.ts
line:     17
severity: medium
command:  /test-audit
class:    flake/e2e-fixed-wait
anchor:   await page.waitForTimeout(800);
match:    waitForTimeout|fixed (wait|sleep|delay)|sleep|800
```

The amount is recomputed after a debounced request; 800 ms is a guess, and the two retries
(BS-SE-15) hide the misses. Proof: `--repeat-each=50 --retries=0 --fail-on-flaky-tests` with CPU
throttling, k of N. Fix: delete the wait — the following `await expect(...).toHaveText()` already
retries. Owner: `flake-source-scan` § 8 (grep 8).

## BS-FL-15 — `expect(await row.isVisible()).toBe(true)` reads once and races the render

```defect
id:       BS-FL-15
file:     web/e2e/refund-request.spec.ts
line:     26
severity: medium
command:  /test-audit
class:    flake/e2e-read-once
anchor:   expect(await reasonRow.isVisible()).toBe(true);
match:    isVisible|web.?first|read.?once|race|auto.?(wait|retr)|retry
```

`isVisible()` answers immediately; if the row renders a frame later the case fails, and the
retries mask it. Fix: `await expect(reasonRow).toBeVisible()`. Owner: `flake-source-scan` § 8
(grep 8).

## BS-TD-01 — `jest.mock('./refund.service')` in `refund.service.spec.ts`

```defect
id:       BS-TD-01
file:     api/src/refunds/refund.service.spec.ts
line:     3
severity: high
command:  /test-audit
class:    double/sut-mocked
anchor:   jest.mock('./refund.service');
match:    mock
match:    itself|under test|\bSUT\b|refund\.service|own module|the (class|service|module) (it|being) test
```

The spec automocks the module it claims to test, then stubs `service.refund` and asserts the stub's
values back. Nothing in `RefundService` runs — not the window check, not the over-refund guard.
Proof (break the SUT): make `refund()` return `{ amountCents: 0 }` — green. Fix: mock the
collaborators (`EntityManager`, `PaymentGateway`), never the SUT. Owner: `test-double-scan` § 1
(greps 1a, 1b).

## BS-TD-02 — `@patch("app.pricing.compute_total")` then asserting `compute_total`

```defect
id:       BS-TD-02
file:     svc/tests/test_pricing.py
line:     8
severity: high
command:  /test-audit
class:    double/sut-mocked
anchor:   @patch("app.pricing.compute_total"
match:    patch|mock
match:    compute_total|itself|under test|\bSUT\b|patched function
```

The coupon test patches the function it calls and asserts the patch's return value; the coupon
arithmetic is never executed. Probe: delete the coupon branch — green. Fix: no patch; expect
`Decimal("42.30")` for this cart. Owner: `test-double-scan` § 1 (grep 1c).

## BS-TD-03 — An `as any` double with `findOne` — the SUT calls `findOneOrFail`

```defect
id:       BS-TD-03
file:     api/src/orders/orders.service.spec.ts
line:     6
severity: high
command:  /test-audit
class:    double/drifted-double
anchor:   new OrdersService(orders as any)
match:    as any|drift|findOne|untyped|cast|shape|interface|wrong reason|TypeError|not a function
```

`OrderRepository` exposes `findOneOrFail(tenantId, id)`; the double still has the old `findOne`.
`service.get()` throws `TypeError: this.orders.findOneOrFail is not a function`, and the case —
`rejects.toThrow()` with no type — passes for that reason, not because the order is missing. The
tenant-scoped not-found path is untested. Proof: type the double (`satisfies
Partial<OrderRepository>`) → an excess-property error (TS2353 / TS2561); or `toThrow(NotFoundError)` → red. Fix: a typed double with
`findOneOrFail` rejecting `NotFoundError`. Owner: `test-double-scan` § 2 (grep 2a).

## BS-TD-04 — `MagicMock()` without `spec` hides a renamed gateway method

```defect
id:       BS-TD-04
file:     svc/tests/test_gateway.py
line:     9
severity: high
command:  /test-audit
class:    double/drifted-double
anchor:   gw = MagicMock()
match:    MagicMock|spec|autospec|capture_refund|refund_capture|renamed|drift
```

`Gateway` defines `refund_capture`; `issue_refund` calls `gateway.capture_refund`, which a spec-less
`MagicMock` happily provides. The test is green and every production refund raises
`AttributeError`. Proof: `create_autospec(Gateway, instance=True)` → `AttributeError` at the call.
Fix: `MagicMock(spec=Gateway)` (as `test_payouts.py` does, BS-DECOY-11) and fix the call. Owner:
`test-double-scan` § 2 (grep 2b).

## BS-TD-05 — SQLite in memory for a `citext` uniqueness rule

```defect
id:       BS-TD-05
file:     api/test/integration/customer-email.int-spec.ts
line:     10
severity: high
command:  /test-audit
class:    double/engine-substitution
anchor:   dbName: ':memory:'
match:    sqlite|:memory:|engine|postgres|citext|in.?memory|case.?insensitiv
```

Production emails are `citext` (case-insensitive) with a unique `(tenant_id, email)`. On SQLite
`citext` is just a type name, so "Bo@Shop.test" and "bo@shop.test" are two rows — and the case
"keeps two sign-ups whose emails differ only in case apart" pins exactly the behaviour production
must refuse (the entity's own comment). Proof: the same file on `@testcontainers/postgresql` → the
second case fails with a unique violation. Fix: Testcontainers on Postgres 16 and invert that case.
Owner: `test-double-scan` § 4 (grep 4a).

## BS-TD-06 — The tenant guard trusts `x-test-*` headers whenever `NODE_ENV` is `test`

```defect
id:       BS-TD-06
file:     api/src/auth/tenant.guard.ts
line:     17
severity: high
command:  /test-audit
class:    double/test-seam
anchor:   if (process.env.NODE_ENV === 'test') {
match:    NODE_ENV|test (mode|seam|branch|env)|seam|bypass|skips? (auth|verification|the guard|session)|x-test
```

Jest sets `NODE_ENV=test`, so every e2e request takes this branch: the session verifier never runs
in any test, and a production pod started with the wrong `NODE_ENV` accepts identity from request
headers. Proof (env parity): the e2e suite with `NODE_ENV=production` — every request 401s.
Fix: inject a `SessionVerifier` double in the e2e harness and delete the branch. Owner:
`test-double-scan` § 5 (grep 5a).

## BS-TD-07 — `if settings.TESTING: return` skips the merchant-callback signature

```defect
id:       BS-TD-07
file:     svc/app/signatures.py
line:     13
severity: high
command:  /test-audit
class:    double/test-seam
anchor:   if settings.TESTING:
match:    TESTING|test (mode|seam|flag)|seam|bypass|skips? (the )?(signature|verification|hmac)
```

`conftest.py` sets `RETURNSDESK_TESTING=1`, so the HMAC check never runs in the suite — the only
callback test signs with an empty secret and passes for any signature, and `SignatureError` is
named by no test. Proof (env parity): `RETURNSDESK_TESTING=0` → the callback test raises. Fix:
inject the secret and test both a valid and a forged signature. Owner: `test-double-scan` § 5
(grep 5a); `coverage-gap` § 3 lists `SignatureError` as never asserted.

## BS-TD-08 — A hand-written MSW body with `total: '12.00'` — the API sends `totalCents`

```defect
id:       BS-TD-08
file:     web/src/test/handlers.ts
line:     9
severity: high
command:  /test-audit
class:    double/hand-written-http-body
anchor:   total: '12.00',
match:    totalCents|\btotal\b|schema|contract|shape|hand.?written|MSW|mock (body|response)|string
```

`web/src/api/invoices.ts` documents the wire shape (`totalCents: number`); the handler answers a
string `total`. The component renders `€NaN`, and the snapshot (BS-AS-14) recorded it. The handler
is not typed from the schema or the DTO. Proof: `satisfies InvoiceDto` on the body → a type error;
or a schema validation of the body. Fix: type the handler body (`satisfies InvoiceDto`, or
openapi-msw). Owner: `test-double-scan` § 3 (grep 3d).

## BS-TD-09 — The orders e2e suite replaces the repository with `jest.fn()`s

```defect
id:       BS-TD-09
file:     api/test/e2e/orders.e2e-spec.ts
line:     17
severity: high
command:  /test-audit
class:    double/repository-mocked-in-e2e
anchor:   overrideProvider(OrderRepository)
match:    overrideProvider|repository|useValue|mock(ed)? (repo|the repository)
```

An e2e file on Testcontainers Postgres that never touches Postgres: the tenant-scoped `where`
(`{ id, tenantId }`) and the refunds `populate` are replaced by a double that answers the same
row for any tenant. Proof: delete `tenantId` from the repository's `where` — the suite stays green.
Fix: seed rows through `factories.ts` and drop the override. Owner: `test-double-scan` § 4
(grep 4b).

## BS-TD-10 — Shipped code answers the test's input with the test's expected value

```defect
id:       BS-TD-10
file:     api/src/loyalty/points.ts
line:     4
severity: high
command:  /test-audit
class:    double/special-cased-input
anchor:   if (orderCents === 4999) return 50;
match:    4999|special.?cas|hard.?coded|magic (number|value)|literal
```

`4999` appears in no rule — the comment says one point per full euro — and in exactly one place
outside this file: the input of the "promotional fifty points" test. It ignores refunds as well:
`pointsFor(4999, 4999)` is 50. Proof: the neighbouring input `pointsFor(4998, 0)` is 49 and
`pointsFor(5000, 0)` is 50 — the "promotion" exists only at the tested value. Fix: delete the
branch and the case (or specify the promotion). Owner: `test-double-scan` § 6 (grep 6b).

## BS-CG-01 — `GET /orders/:id` has no other-tenant test

```defect
id:       BS-CG-01
file:     api/src/orders/orders.controller.ts
line:     16
severity: critical
command:  /test-audit
class:    coverage/no-denial-test
anchor:   @Get(':id')
match:    tenant|other (merchant|account)|cross.?tenant|isolation|404|denial|negative
```

The handler's comment states the rule — another tenant's order reads as 404 — and no test sends
another tenant to it. The grep cannot see the gap: `refunds.e2e-spec.ts` names `/orders/${id}` (a
same-tenant 200 read) and also contains `.expect(404)`, so the route reads as covered; and the
orders e2e mocks the repository (BS-TD-09). Proof (seeded violation): drop `tenantId` from
`OrderRepository.findOneOrFail` — every test stays green. Fix: a `tn_b` request for a `tn_a` order,
`.expect(404)`, on the real repository. Owner: `coverage-gap` § 2.

## BS-CG-02 — The admin force-refund route has no 403 test

```defect
id:       BS-CG-02
file:     api/src/admin/admin.controller.ts
line:     12
severity: critical
command:  /test-audit
class:    coverage/no-denial-test
anchor:   @Post('returns/:id/force-refund')
match:    403|forbidden|denial|negative|non.?admin|role|unauthori[sz]ed|permission
```

The route bypasses the risk score and the window and refunds the full capture. Its siblings
(`/admin/agents`, `/admin/agents/:id`, `/admin/agents/:id/disable`) each have a non-admin 403 test
in `admin.e2e-spec.ts` (BS-DECOY-20); this one has none. Proof (seeded violation): remove
`@Roles('admin')` from it — green. Fix: a non-admin `.expect(403)` case. Owner: `coverage-gap` § 2
(grep 2 lists the route).

## BS-CG-03 — `PartialRefundExceedsCaptureError` is thrown and never asserted

```defect
id:       BS-CG-03
file:     api/src/refunds/refund.service.ts
line:     36
severity: high
command:  /test-audit
class:    coverage/error-never-asserted
anchor:   throw new PartialRefundExceedsCaptureError(
match:    PartialRefundExceedsCapture|never (asserted|tested|named|exercised)|untested|no test|over.?refund|exceeds
```

The over-refund guard is the line that stops a second partial refund from exceeding the capture,
and no test names the error or reaches the branch (the only `RefundService` spec mocks the SUT,
BS-TD-01). Proof: the throw line at 0 hits in a merged report; or delete the guard — green. Fix:
two partial refunds whose sum exceeds the capture → `rejects.toThrow(PartialRefundExceedsCaptureError)`.
Owner: `coverage-gap` § 3.

## BS-CG-04 — The payment-webhook handler has no test at all

```defect
id:       BS-CG-04
file:     api/src/webhooks/payment-webhook.handler.ts
line:     24
severity: high
command:  /test-audit
class:    coverage/critical-module-untested
anchor:   async apply(event: ProviderEvent)
match:    no test|untested|not tested|never tested|without (a |any )?tests?|zero tests?|no (unit|e2e|spec|coverage)|uncovered
```

`apply()` flips a refund to `failed` when the provider reports it — the line that stops a shopper
being told the money is on its way — and `verify()` is the signature check. No test imports
either file; the route `/webhooks/payments` has no 401 test either (grep 2 lists it). Proof: the
coverage inventory — both files absent. Fix: a handler spec for both event types and an e2e with a
forged signature. Owner: `coverage-gap` § 4.

## BS-CG-05 — The carrier label client parses a vendor response no contract pins

```defect
id:       BS-CG-05
file:     api/src/shipping/carrier.client.ts
line:     28
severity: medium
command:  /test-audit
class:    coverage/no-contract-test
anchor:   costCents: Math.round(body.price.amount * 100),
match:    contract|pact|schema|vendor|provider|response (shape|body)
```

`createReturnLabel` reads `body.tracking.number`, `body.documents[0].url`,
`body.service.carrier_code` and `body.price.amount` — a vendor's shape, validated nowhere and pinned
by no consumer contract or recorded response (grep 6b: no contract tooling in any test). Proof:
rename one field in a recorded response — no test fails (none exists). Fix: a schema at the parse
and a recorded-response contract test. Owner: `coverage-gap` § 6 → `contract-test`.

## BS-MC-01 — The free-return threshold is never tested at the boundary

```defect
id:       BS-MC-01
file:     api/src/shipping/free-shipping.ts
line:     6
severity: high
command:  /test-audit
class:    mutation/boundary-survivor
anchor:   if (merchandiseCents >= FREE_SHIPPING_THRESHOLD) return 0;
match:    boundary|>=|threshold|mutant|mutation|5[_,]?000|off.?by.?one|exactly
```

Both cases sit far from 5 000 (2 000 and 9 000), so `>=` → `>` survives: an order of exactly
50.00 EUR would be charged the label, against the comment ("50.00 EUR and above"). Proof:
`npx stryker run --mutate src/shipping/free-shipping.ts:6-6` → `EqualityOperator` Survived. Fix:
`returnLabelCharge(5_000) === 0` and `returnLabelCharge(4_999) === 495`. The equivalent mutant in
`points-counter.ts` is the decoy (BS-DECOY-10). Owner: `mutation-probe` § 2.

## BS-MC-02 — The payout audit trail is pseudo-tested

```defect
id:       BS-MC-02
file:     jvm/src/main/java/dev/returnsdesk/payouts/PayoutCalculator.java
line:     23
severity: high
command:  /test-audit
class:    mutation/pseudo-tested
anchor:   audit.record(payout);
match:    record|audit|pseudo|mutant|mutation|removed|never (checked|asserted)
```

Every `compute()` call writes the audit trail finance reconciles against, and no test reads
`audit.lines()`: removing the call (PIT `VoidMethodCall`) or emptying `record()` (Descartes) leaves
the suite green. Proof: `mvn org.pitest:pitest-maven:mutationCoverage` → `VOID_METHOD_CALLS`
SURVIVED at this line. Fix: assert `audit.lines()` after a compute. Owner: `mutation-probe` § 4.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect — same file or same feature, same vocabulary,
no defect — and most were written so that only reading the code tells them apart. A run that reports
one has produced a false positive **by construction**.

How they score (`score.py`, § DECOYS in its header): a finding that names the decoy's file, cites a
line within the tolerance window of the decoy's line, and matches every one of the decoy's `match:`
patterns is **pinned** to it, removed before defect assignment, and reported as `DECOYS FLAGGED
k/21`. A finding with no line is never pinned, and a finding a seeded defect could claim at EXACT
strength is never pinned. Every decoy sits more than 12 lines from any defect in its file, which
`--verify` enforces.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| BS-DECOY-01 | `api/src/cache/price-cache.spec.ts:19` | BS-AS-03 | a cache hit at exactly the ttl: existence is the behaviour, and the case above pins the value (§ 14) |
| BS-DECOY-02 | `api/src/notifications/notify.service.spec.ts:11` | BS-AS-06 | the email on a port the project owns is the use case's only outcome, every argument pinned (§ 20) |
| BS-DECOY-03 | `api/src/carts/carton-fit.spec.ts:6` | BS-SE-01 | `fit` is the packing station's assertion helper from `carton-fit.ts`, not Jasmine focus |
| BS-DECOY-04 | `api/test/e2e/refunds.e2e-spec.ts:42` | BS-SE-02 | the skip carries a ticket (#812), an owner and a delete-by date (QG-7, § 25) |
| BS-DECOY-05 | `web/e2e/session-timeout.spec.ts:14` | BS-FL-03 | real time is the behaviour (the browser idle timer against the real session API), with margins of 5 s and 25 s (§ 35) |
| BS-DECOY-06 | `api/src/subscriptions/renewal-reminder.spec.ts:4` | BS-TD-01 | it mocks the clock collaborator so the month-end date is pinned; `dueForReminder` itself runs for real |
| BS-DECOY-07 | `api/src/coupons/coupon.spec.ts:25` | BS-FL-12 | the UTC day is the right "today" here: `redeemRefusal` ends the expiry day at 23:59:59.999Z, so both sides are UTC |
| BS-DECOY-08 | `api/test/e2e/boot-app.e2e.ts:13` | BS-SE-04 | a shared e2e bootstrap that declares no case; no config should collect it (§ 32) |
| BS-DECOY-09 | `api/src/jobs/settlement.queue.ts:16` | BS-SE-14 | an outbound HTTP retry policy for an idempotent payout API in shipped code, not a test-runner retry |
| BS-DECOY-10 | `api/src/loyalty/points-counter.ts:9` | BS-MC-01 | `count` is an array length: `>` → `!=` is an equivalent mutant (check 1, type context); `>` → `>=` is killed by the empty-card case |
| BS-DECOY-11 | `svc/tests/test_payouts.py:14` | BS-TD-04 | `spec=Gateway` makes a misspelled method raise; the void is the outcome and its argument is pinned |
| BS-DECOY-12 | `svc/tests/test_settings.py:5` | BS-FL-08 | `monkeypatch` restores the variable at teardown |
| BS-DECOY-13 | `ledger/ledger_test.go:41` | BS-FL-08 | `t.Setenv` restores the variable and refuses `t.Parallel` |
| BS-DECOY-14 | `svc/tests/test_paths.py:12` | BS-SE-02 | a platform condition CI never meets (ubuntu), with a reason, a ticket and an owner (§ 25, § 26) |
| BS-DECOY-15 | `jvm/src/test/java/dev/returnsdesk/payouts/PayoutCalculatorTest.java:12` | BS-SE-14 | a determinism check run 50 times — every repetition must pass; nothing is retried |
| BS-DECOY-16 | `api/src/fx/currency-table.gen.ts:1` | BS-SE-12 | a generated data table, excluded with the generator named as the reason (§ 31) |
| BS-DECOY-17 | `svc/tests/test_statements.py:26` | BS-FL-02 | `@freeze_time("2026-03-31 23:30:00")` pins `datetime.now()` for this test |
| BS-DECOY-18 | `api/test/integration/ledger-sql.int-spec.ts:6` | BS-TD-05 | PGlite is real Postgres SQL; one statement on one connection needs no locking semantics (§ 40) |
| BS-DECOY-19 | `api/src/billing/invoice-total.spec.ts:22` | BS-AS-03 | a guard followed by a `toEqual` on every field (§ 13) |
| BS-DECOY-20 | `api/src/admin/admin.controller.ts:30` | BS-CG-02 | `admin.e2e-spec.ts` sends a non-admin to this route and expects 403 |
| BS-DECOY-21 | `api/src/refunds/refund-window.spec.ts:30` | BS-AS-10 | `not.toThrow` on the default window, paired with the `toThrow` rejection case below it (§ 17) |

```decoy
id:       BS-DECOY-01
file:     api/src/cache/price-cache.spec.ts
line:     19
command:  /test-audit
class:    decoy/existence-is-the-behaviour
anchor:   expect(cache.get('TEA-12')).toBeDefined();
match:    toBeDefined|weak|existence|defined
```

```decoy
id:       BS-DECOY-02
file:     api/src/notifications/notify.service.spec.ts
line:     11
command:  /test-audit
class:    decoy/interaction-is-the-outcome
anchor:   expect(mailer.send).toHaveBeenCalledWith({
match:    interaction|toHaveBeenCalled|called|mock
```

```decoy
id:       BS-DECOY-03
file:     api/src/carts/carton-fit.spec.ts
line:     6
command:  /test-audit
class:    decoy/fit-is-not-focus
anchor:   fit(plan, CARTONS.small);
match:    \bfit\b|focus|only
```

```decoy
id:       BS-DECOY-04
file:     api/test/e2e/refunds.e2e-spec.ts
line:     42
command:  /test-audit
class:    decoy/owned-skip
anchor:   it.skip('refunds a split-tender order
match:    skip|disabled
```

```decoy
id:       BS-DECOY-05
file:     web/e2e/session-timeout.spec.ts
line:     14
command:  /test-audit
class:    decoy/wall-clock-e2e-with-margins
anchor:   expect(elapsedMs).toBeLessThan(55_000);
match:    elapsed|timing|wall.?clock|real (time|clock)|sleep|bound|flak
```

```decoy
id:       BS-DECOY-06
file:     api/src/subscriptions/renewal-reminder.spec.ts
line:     4
command:  /test-audit
class:    decoy/collaborator-mocked
anchor:   jest.mock('../shared/clock'
match:    mock
```

```decoy
id:       BS-DECOY-07
file:     api/src/coupons/coupon.spec.ts
line:     25
command:  /test-audit
class:    decoy/utc-today-against-a-utc-rule
anchor:   const today = new Date().toISOString().slice(0, 10);
match:    toISOString|UTC|time ?zone|today|real clock|date
```

```decoy
id:       BS-DECOY-08
file:     api/test/e2e/boot-app.e2e.ts
line:     13
command:  /test-audit
class:    decoy/helper-not-a-test
anchor:   export async function bootApp(
match:    collect|not (run|picked)|never (runs|run)|no (cases|tests)|unclaimed
```

```decoy
id:       BS-DECOY-09
file:     api/src/jobs/settlement.queue.ts
line:     16
command:  /test-audit
class:    decoy/retries-in-shipped-config
anchor:   retries: 3,
match:    retr
```

```decoy
id:       BS-DECOY-10
file:     api/src/loyalty/points-counter.ts
line:     9
command:  /test-audit
class:    decoy/equivalent-mutant
anchor:   return count > 0;
match:    boundary|mutant|mutation|>|count
```

```decoy
id:       BS-DECOY-11
file:     svc/tests/test_payouts.py
line:     14
command:  /test-audit
class:    decoy/specced-double
anchor:   MagicMock(spec=Gateway)
match:    MagicMock|spec|mock
```

```decoy
id:       BS-DECOY-12
file:     svc/tests/test_settings.py
line:     5
command:  /test-audit
class:    decoy/restored-env
anchor:   monkeypatch.setenv("REFUND_LIMIT_CENTS"
match:    env|environ|leak|restore
```

```decoy
id:       BS-DECOY-13
file:     ledger/ledger_test.go
line:     41
command:  /test-audit
class:    decoy/restored-env
anchor:   t.Setenv("LEDGER_RESERVE_CENTS"
match:    env|Setenv|leak|restore
```

```decoy
id:       BS-DECOY-14
file:     svc/tests/test_paths.py
line:     12
command:  /test-audit
class:    decoy/owned-conditional-skip
anchor:   @pytest.mark.skipif(sys.platform == "win32"
match:    skip
```

```decoy
id:       BS-DECOY-15
file:     jvm/src/test/java/dev/returnsdesk/payouts/PayoutCalculatorTest.java
line:     12
command:  /test-audit
class:    decoy/repeated-test
anchor:   @RepeatedTest(50)
match:    repeat|flak|retr
```

```decoy
id:       BS-DECOY-16
file:     api/src/fx/currency-table.gen.ts
line:     1
command:  /test-audit
class:    decoy/reasoned-coverage-exclusion
anchor:   istanbul ignore file
match:    istanbul|coverage|ignore|exclu
```

```decoy
id:       BS-DECOY-17
file:     svc/tests/test_statements.py
line:     26
command:  /test-audit
class:    decoy/frozen-clock
anchor:   assert statement_period(datetime.now().date())
match:    datetime\.now|clock|time.?bomb|real (time|clock)
```

```decoy
id:       BS-DECOY-18
file:     api/test/integration/ledger-sql.int-spec.ts
line:     6
command:  /test-audit
class:    decoy/pglite-single-connection
anchor:   const db = new PGlite();
match:    PGlite|engine|in.?memory|postgres|emulat
```

```decoy
id:       BS-DECOY-19
file:     api/src/billing/invoice-total.spec.ts
line:     22
command:  /test-audit
class:    decoy/guard-before-value-check
anchor:   expect(note).toBeDefined();
match:    toBeDefined|weak|defined
```

```decoy
id:       BS-DECOY-20
file:     api/src/admin/admin.controller.ts
line:     30
command:  /test-audit
class:    decoy/route-with-denial-test
anchor:   @Post('agents/:id/disable')
match:    403|denial|negative|role|forbidden|non.?admin
```

```decoy
id:       BS-DECOY-21
file:     api/src/refunds/refund-window.spec.ts
line:     30
command:  /test-audit
class:    decoy/acceptance-paired-with-rejection
anchor:   expect(() => parseRefundWindow('P30D')).not.toThrow();
match:    not\.toThrow|weak|throw
```

## Proof — the `make prove` target, kept out of the tree

The weak-suite research proposal (`research-testing.md` § 7) asked for a `make prove` target that
runs each seeded defect's oracle so the fixture validates itself. It is **not shipped in the
fixture**: anything in the tree is visible to the agent being measured, and a target that names
each probe is an answer key by another name. The oracles are listed here instead, per family, and
nothing is installed in the fixture, so none of them runs as checked in; they are the commands a
fix benchmark (`/test-fix`) will run in its staged copy.

```make
prove-assertions:   # break the SUT / assertion flip, one probe per id; each must leave the case GREEN
	cd api && npx stryker run --mutate "src/refunds/refund-batch.service.ts,src/billing/invoice-total.ts,src/pricing/discount.ts,src/customers/customer.service.ts,src/refunds/refund-approval.service.ts,src/fees/processing-fee.ts"
	cd svc && python -m pytest -W error::RuntimeWarning tests/test_receipts.py   # BS-AS-09 turns red
prove-execution:    # collection lists and CI facts
	cd api && npx jest --listTests | grep -c refund-policy                     # 0 → BS-SE-04
	cd ledger && go test -list '.*' ./... | grep -c Testrefund                  # 0 → BS-SE-05
	cd svc && python -m pytest --collect-only -q -W error::pytest.PytestCollectionWarning   # BS-SE-06 errors
prove-flakes:       # perturbations
	cd api && faketime '2027-01-02' npx jest coupon                            # BS-FL-01 red
	cd svc && faketime '2026-11-01' python -m pytest tests/test_statements.py  # BS-FL-02 red
	cd api && npx jest -t 'a trial started a week ago'                          # BS-FL-07 red alone
	cd api && npx jest -t 'repeated booking'                                    # BS-FL-11 red alone
	cd svc && python -m pytest tests/test_settlement.py                        # BS-FL-08 victim red alone
	cd web && TZ=America/New_York npx jest RefundDue                           # BS-FL-12 red
	cd svc && python -m pytest --disable-socket tests/test_fx.py     # BS-FL-06 red
prove-doubles:
	cd svc && RETURNSDESK_TESTING=0 python -m pytest tests/test_callbacks.py   # BS-TD-07 red
	cd api && NODE_ENV=production npm run test:e2e                              # BS-TD-06: every request 401s
prove-mutation:
	cd api && npx stryker run --mutate src/shipping/free-shipping.ts:6-6       # BS-MC-01 Survived
	mvn -f jvm/pom.xml org.pitest:pitest-maven:mutationCoverage                # BS-MC-02 SURVIVED
```

## Pre-flight reach (measured 2026-10-05)

Each detector's `## Pre-flight` block, extracted from its `SKILL.md` and run unchanged from the root
of a git-initialised copy of this fixture (`MODE=whole-repo`; the repo-baseline's `oracle-check.py`
found at its global path). "Reached" means a grep line (or a census row) cites the defect's file
within the scoring window; "file" means the grep lists the file without a line. Ids no grep reaches
are found by reading, by a perturbation run, or by the mutation tool — that is by design: several
are only defects once two files are read together.

| detector | grep → ids reached |
|----------|--------------------|
| `assertion-strength-scan` | 1a oracle-check → AS-01, AS-02, AS-03, AS-06, AS-07, AS-09 · census → AS-01, AS-02, AS-03 (weak-sole), AS-06 (count-only), AS-08, AS-14, AS-17 · 1c → AS-16 · 2b → AS-07 · 3e → AS-09, AS-11 · 4a → AS-12 · 4c → AS-13 · 5a → AS-04 · 5b → AS-05 · 6b → AS-14 (109-line entry) · 6c → AS-15 |
| `suite-execution-scan` | 1a → SE-01 · 2a → SE-02 · 2c → SE-03 · 3a `UNCLAIMED` → SE-04 (file) · 3b `NOT-IN-CI` → SE-16 · 3c → SE-05, SE-06, SE-07 · 4a → SE-09, SE-10 · 4b → SE-11 · 4c → FL-09 · 5a → SE-13 · 5b → SE-12 · 6a → SE-14, SE-15 |
| `flake-source-scan` | 1a → FL-02 · 1b → FL-01 · 2a → FL-13 · 3a → FL-03 · 3b → FL-04 · 4a → FL-05 · 4b → FL-06 · 5b → FL-07 (file) · 5c → FL-11 · 5d → FL-08 · 6a → FL-09 · 6b → FL-10 (file) · 8 → FL-14, FL-15 |
| `test-double-scan` | 1a, 1b → TD-01 · 1c → TD-02 · 2a → TD-03 · 2b → TD-04 (and the `mock.Anything` of AS-07) · 3d → TD-08 (file) · 4a → TD-05 · 4b → TD-09 · 5a → TD-06, TD-07 · 6b → TD-10 |
| `coverage-gap` (no report: § 1 `blocked`) | 2 → CG-02 (+ `/webhooks/payments`, CG-04's route) · 3 → CG-03 (+ `SignatureError`, TD-07's) · 4 → CG-04 (file, among 25 — see below) · 6a → CG-05 (file, among 4; 6b empty) |
| `mutation-probe` | lanes detected (`api/stryker.conf.json`, `pitest-maven`); no merge-base, so the diff scope is empty: MC-01, MC-02 need the tool run |

**Reached by no grep (reading, perturbation or a tool run):** AS-10 (grep 3b's file filter drops
any file that also contains `.toThrow`, and the sibling rejection case does), SE-08 (an absent
failsafe plugin has no line), FL-12 (the zone read is in the component), CG-01 (the route literal
appears in a deny file through a same-tenant 200 read), MC-01, MC-02.

**Decoys the greps also print** (each must be cleared by reading): DECOY-01 and DECOY-21 (census
`weak-sole`), DECOY-02 (census `interaction-only`), DECOY-03 (grep 1a `fit(`), DECOY-04 (grep 2a),
DECOY-05 (grep 3c), DECOY-07 and DECOY-17 (grep 1a), DECOY-08 (grep 3a `UNCLAIMED`).

**Two grep notes for the pack** (found while measuring, not fixture defects): `coverage-gap` grep 4
strips the last dotted segment of every import specifier (`sed -E 's/\.[a-z]+$//'`), so
`./refund.service` becomes `refund` and every `*.service.ts` / `*.guard.ts` module reads as having no
test — 25 files here, most of them tested. `mutation-probe`'s scope block prints `awk: can't open
file …/ranges.all` on a run with no merge-base instead of an empty scope.
