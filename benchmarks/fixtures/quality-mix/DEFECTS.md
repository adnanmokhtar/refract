# Seeded defects — `quality-mix`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `tollgate`, subscription billing — NestJS 11 on Fastify + Prisma 6 API, React 19 + Vite portal, Python 3.12 renewal worker, Go 1.23 webhook ingest, ESLint flat config, dependency-cruiser rules, GitHub Actions.
62 code-quality defects seeded across every class row of `/quality-audit`'s fixed ledger that a
one-commit tree can show — error handling, type safety, correctness smells, suppressions, dead
code, duplication and architecture — plus **27 decoys**: known-safe siblings that look like a
seeded defect and must NOT be reported. Primary target command: **`/quality-audit`** (a whole-repo
run: the staged copy has no base branch).

Stage with: --git — the context map's churn query, `duplication-scan` 1b and `architectural-diagnosis`
§ 9 read `git log`; an un-initialised copy fails those lanes. `run.sh` git-initialises the staged
copy with one commit, so churn, fix density and the diff lanes read as flat or `N/A`.

**Money, time and state machines are the domain on purpose.** Most defects are wrong for one
concrete input — a JPY payout, a refund of credit, a renewal on 29 March west of UTC, a `past_due`
subscription, a discount of exactly 0 % — and the proof is that input at the real entry point.

What makes the fixture measure more than keyword recall: most defects have a correct sibling in the
same tree. `charges.service.ts` rethrows with `{ cause }` in `refundCharge` and drops the cause in
`chargeRenewal`; `credit-transfer.service.ts` calls `transfer(customer, merchant)` correctly for a
payment and the same way for a *refund*; `minor-units.ts` converts fees with the currency's exponent
and payouts with `* 100`; `subscription-status.ts` ends one switch with `assertNever` and the other
with `return 'full'`; `store.go` wraps with `%w` everywhere except the one error the handler matches
with `errors.Is`; the portal's tax preview is a copy of `billing/tax.ts` from before its rounding fix.
Several are only defects once two files are read together: the domain's Prisma import breaks a rule
that `api/.dependency-cruiser.cjs` declares and no CI job runs; `eqeqeq: 'off'` in the web block is
what lets `percent == ''` ship. Reporting the safe half of a pair is scored too — see **Decoys**.

**On "Pre-existing" (the research sketch's untouched items).** The `quality-fullstack` sketch
(`research-code-quality.md` § 7) shipped as a base commit plus a PR branch and scored items the PR
did not touch as **Pre-existing**. `/quality-audit` has that bucket only on a diff run
(`quality-audit.md` Phase 4: "a whole-repo run has no Pre-existing bucket"), and `run.sh` stages one
commit with no base branch, so this fixture is a **whole-repo** measurement and every seeded item is
a finding. The two untouched items of the sketch are kept: the C02 swallow is `QM-EH-19`, scored as
a finding; the god class is `api/src/admin/admin-ops.service.ts` (32 imports, eight responsibilities),
which `architectural-diagnosis` § 4 reports only with hotspot or change-coupling evidence that a
one-commit tree cannot carry — so it is **neither a defect nor a decoy**: a report on it is
UNMATCHED. A diff-mode variant (base + change, scored for Pre-existing) belongs with
`review-decoys`' `--diff` staging, not here.

Ownership. Every row names the detector that owns its class: `error-handling-scan`,
`type-safety-scan`, `correctness-smell-scan`, `suppression-scan`, `dead-code-scan`,
`duplication-scan` and `architectural-diagnosis` (code-quality pack), the seven detectors
`/quality-audit` dispatches on a whole-repo run. Where two own one site (an unchecked status in front
of a cast; a suppression and the diagnostic it hides), the row carries one id and its `match:`
accepts either detector's vocabulary.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| QM-EH-01 | `api/src/webhooks/payment-webhook.controller.ts:23` | critical | `/quality-audit` | error/dropped |
| QM-EH-02 | `worker/worker/renewals/dunning.py:16` | high | `/quality-audit` | error/dropped |
| QM-EH-04 | `ingest/handler.go:81` | high | `/quality-audit` | error/dropped |
| QM-EH-03 | `web/src/invoices/useInvoices.ts:24` | medium | `/quality-audit` | error/success-shaped |
| QM-EH-19 | `api/src/billing/charges.service.ts:44` | medium | `/quality-audit` | error/success-shaped |
| QM-EH-05 | `ingest/dedupe.go:33` | medium | `/quality-audit` | error/unread-error-return |
| QM-EH-06 | `worker/worker/exports/ledger_export.py:19` | high | `/quality-audit` | error/unread-exit-code |
| QM-EH-07 | `api/src/billing/provider.client.ts:30` | high | `/quality-audit` | error/unchecked-status |
| QM-EH-08 | `api/src/checkout/checkout.controller.ts:15` | critical | `/quality-audit` | error/unobserved-async |
| QM-EH-09 | `api/src/checkout/checkout.service.ts:16` | critical | `/quality-audit` | error/unobserved-async |
| QM-EH-10 | `worker/worker/renewals/receipts.py:13` | medium | `/quality-audit` | error/unobserved-async |
| QM-EH-11 | `worker/worker/renewals/charge_runner.py:16` | high | `/quality-audit` | error/catch-all |
| QM-EH-12 | `api/src/billing/charges.service.ts:35` | high | `/quality-audit` | error/cause-lost |
| QM-EH-13 | `worker/worker/renewals/charge_runner.py:26` | medium | `/quality-audit` | error/cause-lost |
| QM-EH-14 | `ingest/store.go:46` | high | `/quality-audit` | error/cause-lost |
| QM-EH-15 | `api/src/common/http-exception.filter.ts:17` | high | `/quality-audit` | error/wrong-status |
| QM-EH-16 | `ingest/ratelimit.go:40` | high | `/quality-audit` | error/paired-state |
| QM-EH-17 | `worker/worker/exports/ledger_export.py:10` | high | `/quality-audit` | error/paired-state |
| QM-EH-18 | `web/src/billing/usePaymentMethod.ts:10` | medium | `/quality-audit` | error/paired-state |
| QM-TY-01 | `api/src/imports/order-import.consumer.ts:23` | high | `/quality-audit` | types/boundary-cast |
| QM-TY-02 | `ingest/handler.go:58` | high | `/quality-audit` | types/boundary-cast |
| QM-TY-03 | `web/src/api/client.ts:10` | high | `/quality-audit` | types/boundary-cast |
| QM-TY-04 | `api/src/billing/invoice-pdf.controller.ts:29` | high | `/quality-audit` | types/non-null-assertion |
| QM-TY-05 | `api/tsconfig.json:6` | medium | `/quality-audit` | types/strictness-off |
| QM-TY-06 | `web/src/reports/RevenueChart.tsx:1` | medium | `/quality-audit` | types/strictness-off |
| QM-CS-01 | `api/src/coupons/coupon-code.ts:5` | medium | `/quality-audit` | logic/discarded-result |
| QM-CS-02 | `api/src/billing/invoice-lines.ts:9` | high | `/quality-audit` | logic/discarded-result |
| QM-CS-03 | `api/src/wallet/credit-transfer.service.ts:38` | critical | `/quality-audit` | logic/swapped-arguments |
| QM-CS-24 | `web/src/api/retry.ts:8` | medium | `/quality-audit` | logic/unit-mismatch |
| QM-CS-04 | `web/src/checkout/DiscountOverrideInput.tsx:11` | high | `/quality-audit` | logic/loose-equality |
| QM-CS-05 | `worker/worker/renewals/plans.py:6` | high | `/quality-audit` | logic/identity-on-literal |
| QM-CS-06 | `api/src/subscriptions/feature-gate.ts:5` | high | `/quality-audit` | logic/always-true |
| QM-CS-07 | `api/src/coupons/coupon-code.ts:11` | medium | `/quality-audit` | logic/regex-precedence |
| QM-CS-08 | `ingest/dedupe.go:29` | high | `/quality-audit` | logic/time-equality |
| QM-CS-09 | `worker/worker/renewals/discounts.py:10` | high | `/quality-audit` | logic/mutable-default |
| QM-CS-10 | `ingest/store.go:69` | high | `/quality-audit` | logic/shadowed-error |
| QM-CS-25 | `ingest/counters.go:8` | high | `/quality-audit` | logic/data-race |
| QM-CS-11 | `web/src/billing/money.ts:3` | high | `/quality-audit` | logic/float-money |
| QM-CS-12 | `api/src/payouts/minor-units.ts:12` | critical | `/quality-audit` | logic/minor-units |
| QM-CS-13 | `api/src/usage/usage.controller.ts:12` | medium | `/quality-audit` | logic/unsafe-parse |
| QM-CS-14 | `api/src/invoices/invoice-list.service.ts:16` | high | `/quality-audit` | logic/off-by-one-page |
| QM-CS-15 | `web/src/pricing/PriceLadder.tsx:6` | medium | `/quality-audit` | logic/numeric-sort |
| QM-CS-16 | `worker/worker/exports/batching.py:6` | high | `/quality-audit` | logic/chunk-drops-tail |
| QM-CS-17 | `api/src/subscriptions/subscription-status.ts:25` | critical | `/quality-audit` | logic/non-exhaustive-switch |
| QM-CS-18 | `worker/worker/renewals/schedule.py:11` | high | `/quality-audit` | time/naive-utcnow |
| QM-CS-26 | `worker/worker/renewals/schedule.py:6` | high | `/quality-audit` | time/calendar-month |
| QM-CS-19 | `api/src/billing/billing-anchor.ts:4` | high | `/quality-audit` | time/date-only-parse |
| QM-CS-20 | `api/src/invoices/invoice-number.ts:5` | high | `/quality-audit` | time/week-year-token |
| QM-CS-21 | `web/src/account/DisplayName.tsx:5` | medium | `/quality-audit` | text/code-unit-slice |
| QM-CS-22 | `web/src/search/SearchPage.tsx:20` | low | `/quality-audit` | breakpoint/debugger |
| QM-CS-23 | `worker/worker/renewals/dunning.py:25` | high | `/quality-audit` | breakpoint/pdb |
| QM-SUP-01 | `api/src/subscriptions/renewal.controller.ts:12` | high | `/quality-audit` | suppression/hides-live-diagnostic |
| QM-SUP-02 | `worker/worker/renewals/customers.py:10` | medium | `/quality-audit` | suppression/hides-live-diagnostic |
| QM-SUP-03 | `api/src/reports/revenue-report.service.ts:1` | high | `/quality-audit` | suppression/blanket |
| QM-SUP-04 | `eslint.config.mjs:22` | medium | `/quality-audit` | suppression/rule-off |
| QM-DC-01 | `api/src/billing/legacy-invoice-number.ts:2` | low | `/quality-audit` | dead/unused-file |
| QM-DC-02 | `api/src/subscriptions/plan-change.service.ts:9` | low | `/quality-audit` | dead/flag |
| QM-DC-03 | `api/src/usage/quota.ts:20` | high | `/quality-audit` | dead/unreachable-check |
| QM-DU-01 | `worker/worker/billing/proration.py:13` | high | `/quality-audit` | duplication/divergent-copy |
| QM-DU-02 | `web/src/checkout/tax-preview.ts:13` | high | `/quality-audit` | duplication/divergent-copy |
| QM-AR-02 | `api/src/billing/billing.events.ts:5` | high | `/quality-audit` | architecture/runtime-cycle |
| QM-AR-03 | `api/src/domain/pricing.ts:1` | high | `/quality-audit` | architecture/layer-violation |

Severity split: 6 critical · 37 high · 16 medium · 3 low. All 62 target `/quality-audit`.

### Coverage by class

Grouped by the detector that owns each class, so a miss can be read as "this detector did not
fire" rather than as a number.

| group | owner | seeded | ids |
|-------|-------|--------|-----|
| dropped error (empty, comment-only, log-only) | `error-handling-scan` § 1 | 3 | EH-01, EH-02, EH-04 |
| failure turned into a success-shaped value | `error-handling-scan` § 2 | 2 | EH-03, EH-19 |
| failure signal never read (status, exit code, error return) | `error-handling-scan` § 3 | 3 | EH-05, EH-06, EH-07 |
| unobserved async failure | `error-handling-scan` § 4 | 3 | EH-08, EH-09, EH-10 |
| catch-everything around business logic | `error-handling-scan` § 5 | 1 | EH-11 |
| cause or outcome rewritten | `error-handling-scan` § 6 | 4 | EH-12, EH-13, EH-14, EH-15 |
| paired state the error path skips | `error-handling-scan` § 7 | 3 | EH-16, EH-17, EH-18 |
| boundary cast with no runtime check | `type-safety-scan` § 1 | 3 | TY-01, TY-02, TY-03 |
| non-null assertion on a nullable | `type-safety-scan` § 2 | 1 | TY-04 |
| checker strictness off | `type-safety-scan` § 3 | 2 | TY-05, TY-06 |
| discarded result; swapped arguments; unit mismatch | `correctness-smell-scan` § 1 | 4 | CS-01, CS-02, CS-03, CS-24 |
| equality, boolean and pattern logic | `correctness-smell-scan` § 2 | 5 | CS-04, CS-05, CS-06, CS-07, CS-08 |
| shared, aliased or captured state | `correctness-smell-scan` § 3 | 3 | CS-09, CS-10, CS-25 |
| numbers, bounds and order | `correctness-smell-scan` § 4 | 6 | CS-11, CS-12, CS-13, CS-14, CS-15, CS-16 |
| non-exhaustive switch | `correctness-smell-scan` § 5 | 1 | CS-17 |
| time, zone, locale and text | `correctness-smell-scan` § 6 | 5 | CS-18, CS-26, CS-19, CS-20, CS-21 |
| breakpoints in shipped code | `correctness-smell-scan` § 7 | 2 | CS-22, CS-23 |
| blanket suppression | `suppression-scan` § 1 | 1 | SUP-03 |
| suppressed rule hiding a live diagnostic | `suppression-scan` § 2 | 2 | SUP-01, SUP-02 |
| correctness rule off in config | `suppression-scan` § 3 | 1 | SUP-04 |
| unused file; dead flag; unreachable check | `dead-code-scan` § 1, § 3, § 4 | 3 | DC-01, DC-02, DC-03 |
| divergent copy / one rule implemented twice | `duplication-scan` § 1, § 2 | 2 | DU-01, DU-02 |
| runtime cycle with init-order impact; declared layer broken | `architectural-diagnosis` § 2, § 1 | 2 | AR-02, AR-03 |
| **decoys (must not be reported)** | — | **27** | DECOY-01 … DECOY-27 |

---

## QM-EH-01 — The payment webhook swallows a failed status write and answers 200

```defect
id:       QM-EH-01
file:     api/src/webhooks/payment-webhook.controller.ts
line:     23
severity: critical
command:  /quality-audit
class:    error/dropped
anchor:   } catch (err) {
match:    catch|swallow|empty|ignor|dropp|comment.?only|200|acknowledg
```

`receive()` writes the invoice status inside a `try` whose `catch` holds only a comment, then
answers 200. ingest marks a 2xx as delivered for good (the controller's own header comment), so a
failed write — database down, a lock timeout — leaves the invoice `open` forever and nothing retries:
the comment's "the provider retries" is false at this hop. Proof (port fault injection): `$executeRaw`
rejects → expected 503, got 200. Fix: log with the event id and rethrow (the global filter answers
5xx; ingest retries). Owner: `error-handling-scan` § 1 (grep 1a).

## QM-EH-02 — Dunning: a bare `except: pass` around the decline email

```defect
id:       QM-EH-02
file:     worker/worker/renewals/dunning.py
line:     16
severity: high
command:  /quality-audit
class:    error/dropped
anchor:   except:
match:    except|bare|swallow|pass\b|catch.?all|silent
```

A mail-provider outage, a template error and a `KeyboardInterrupt` alike are dropped; the account
is not counted as sent, but nothing records that the customer was never told their card was
declined. Proof: the mailer fake raises → the function returns 0 with no log and no retry. Fix:
`except MailerError as e: log.warning(...)` and queue a retry; never a bare `except`. Owner:
`error-handling-scan` § 1 (grep 1a; Ruff `E722`, `S110`).

## QM-EH-04 — ingest: a failed forward answers 204 and is never retried

```defect
id:       QM-EH-04
file:     ingest/handler.go
line:     81
severity: high
command:  /quality-audit
class:    error/dropped
anchor:   the nightly sweep re-forwards stragglers
match:    return nil|nil|swallow|ignor|dropp|lost|sweep|forward
```

When `Forward` fails the handler returns `nil`, so `ServeHTTP` answers 204 and the provider never
redelivers. The comment's "nightly sweep re-forwards stragglers" exists nowhere in the repository —
and the event is already stored and deduped, so a manual redelivery is dropped as a duplicate. The
payment never reaches the API, and a later redelivery never reaches `Forward`: the id is already
stored. Proof: a forwarder fake returns an error → the handler answers 204.
Fix: `return fmt.Errorf("forward %s: %w", evt.ID, err)` (503 → provider retry). Owner:
`error-handling-scan` § 1 / § 2 (grep 2b).

## QM-EH-03 — `.catch(() => setRows([]))`: an API outage reads "You have no invoices yet"

```defect
id:       QM-EH-03
file:     web/src/invoices/useInvoices.ts
line:     24
severity: medium
command:  /quality-audit
class:    error/success-shaped
anchor:   .catch(() => setRows([]))
match:    catch|setRows|empty|success|swallow|no invoices|error state
```

The portal cannot tell "failed" from "empty": `InvoicesPage` renders "You have no invoices yet."
on a 500 or a network error. Proof: the API answers 500 → the empty state renders, no error state.
Fix: an `error` state the page renders. Owner: `error-handling-scan` § 2 (grep 2a).

## QM-EH-19 — `listCharges` turns a provider failure into an empty history

```defect
id:       QM-EH-19
file:     api/src/billing/charges.service.ts
line:     44
severity: medium
command:  /quality-audit
class:    error/success-shaped
anchor:   return [];
match:    catch|return \[\]|empty|success|swallow|no charges
```

`catch { return []; }` around the provider call: the portal's charge history shows "no charges"
during a provider outage, and support reads it as fact. The research sketch's untouched C02 swallow
(scored here as a finding — whole-repo run). Proof: `provider.listCharges` rejects → `[]`. Fix:
rethrow (the filter maps it) or return a typed failure the portal renders. Owner:
`error-handling-scan` § 2 (grep 1b / 2a).

## QM-EH-05 — `_ = d.store.MarkProcessed(...)` discards a write error

```defect
id:       QM-EH-05
file:     ingest/dedupe.go
line:     33
severity: medium
command:  /quality-audit
class:    error/unread-error-return
anchor:   _ = d.store.MarkProcessed(
match:    _ =|MarkProcessed|ignor|discard|errcheck|unchecked
```

The processed marker is what the replay tool uses to skip forwarded events; a failed write is
dropped and the replay re-forwards the event. Proof: the store fake returns an error → `Seen`
returns true with nothing logged. Fix: return the error (or log and count it) — `Seen` has no
error path today. Owner: `error-handling-scan` § 3 (grep 3a; `errcheck`).

## QM-EH-06 — `subprocess.run(["gsutil", ...])` without `check=True`

```defect
id:       QM-EH-06
file:     worker/worker/exports/ledger_export.py
line:     19
severity: high
command:  /quality-audit
class:    error/unread-exit-code
anchor:   subprocess.run(["gsutil"
match:    subprocess|check|exit (code|status)|returncode|ignor|silent
```

A failed upload (credentials, quota, network) exits non-zero and the nightly export reports
success; finance's 06:00 import finds nothing and the ledger misses a day. Proof: `gsutil` stubbed
to `exit 1` → `export_and_upload` returns normally. Fix: `check=True` (and let the job fail).
Owner: `error-handling-scan` § 3 (grep 3d; Ruff `PLW1510`).

## QM-EH-07 — `createCharge` parses the body with no status check

```defect
id:       QM-EH-07
file:     api/src/billing/provider.client.ts
line:     30
severity: high
command:  /quality-audit
class:    error/unchecked-status
anchor:   const body = await res.json();
match:    res\.ok|status|402|unchecked|json\(\)|declin
```

`fetch` resolves on 402 and 5xx; the body of a declined charge (`{ "id": "ch_x", "status":
"failed", ... }` or an error object) is returned as a charge, and its siblings `listCharges` and
`refund` both check `res.ok`. Proof: a stub answers 402 with a JSON body → `chargeRenewal` returns
it as a charge. Fix: `if (res.status === 402) throw new PaymentDeclinedError(...)`; `if (!res.ok)
throw ...` before parsing, as `refund()` does. Owner: `error-handling-scan` § 3 (grep 3c).

## QM-EH-08 — `void this.ledger.post(...)` — the shipping line floats

```defect
id:       QM-EH-08
file:     api/src/checkout/checkout.controller.ts
line:     15
severity: critical
command:  /quality-audit
class:    error/unobserved-async
anchor:   void this.ledger.post(
match:    void|float|await|unobserved|fire.?and.?forget|unhandled|promise
```

The response says `status: 'booked'` before the shipping ledger line is posted, and a rejected
post is an unhandled rejection (Node ≥ 15 exits, or a handler logs and the line is lost). `void`
also silences `no-floating-promises` (its `ignoreVoid` default), which is why the lint at error in
CI did not catch it. Proof: the ledger fake rejects → the controller still answers `booked`. Fix:
`await` it inside the booking. Owner: `error-handling-scan` § 4 (type-aware lane; no grep shape).

## QM-EH-09 — `items.forEach(async ...)` posts the ledger lines after the response

```defect
id:       QM-EH-09
file:     api/src/checkout/checkout.service.ts
line:     16
severity: critical
command:  /quality-audit
class:    error/unobserved-async
anchor:   items.forEach(async (item) => {
match:    forEach|async|await|Promise\.all|float|unobserved|before
```

`forEach` drops the promises: `book()` returns `{ booked: n }` before any line is posted and no
rejection is observed. The refunds module does it right with `Promise.all(items.map(async ...))`
(QM-DECOY-15). `no-misused-promises` would flag it; the config runs only `no-floating-promises`.
Proof: a deferred ledger fake → `book()` resolves with nothing posted. Fix: `await Promise.all(...)`.
Owner: `error-handling-scan` § 4 (grep 4a).

## QM-EH-10 — `asyncio.create_task(...)` with no reference kept

```defect
id:       QM-EH-10
file:     worker/worker/renewals/receipts.py
line:     13
severity: medium
command:  /quality-audit
class:    error/unobserved-async
anchor:   asyncio.create_task(send_receipt(
match:    create_task|reference|garbage|task|RUF006|float|unobserved
```

The event loop keeps only weak references to tasks: the receipt task can be collected mid-run,
and its exception is never retrieved. `refund_receipts.py` keeps a strong set and a done-callback
(QM-DECOY-16). Proof: the unhandled-failure hook (`-W error::RuntimeWarning`, the loop's
exception handler) with a failing mailer. Fix: the same pattern as `after_refund`. Owner:
`error-handling-scan` § 4 (grep 4a; Ruff `RUF006`).

## QM-EH-11 — `except Exception` around the renewal charge and the ledger write

```defect
id:       QM-EH-11
file:     worker/worker/renewals/charge_runner.py
line:     16
severity: high
command:  /quality-audit
class:    error/catch-all
anchor:   except Exception as e:
match:    except Exception|catch.?all|broad|KeyError|programmer error|BLE001
```

A `KeyError` from a provider response without `amount` (a bug) and a ledger failure *after* the
customer was charged both become "charge failed" → `None` → dunning emails a customer who was
charged. Proof: inject `KeyError` into `ledger.record` → dunning is scheduled for a paid renewal.
Fix: catch `ProviderError` around the charge only; let the ledger failure propagate. Owner:
`error-handling-scan` § 5 (grep 5; Ruff `BLE001`).

## QM-EH-12 — `new ChargeFailedError((e as Error).message)` drops the provider error

```defect
id:       QM-EH-12
file:     api/src/billing/charges.service.ts
line:     35
severity: high
command:  /quality-audit
class:    error/cause-lost
anchor:   throw new ChargeFailedError((e as Error).message);
match:    cause|message|stack|lost|preserve-caught-error|rethrow
```

The comment above says dunning reads the decline code from the error chain; the rethrow keeps
only the message, so every decline looks soft and a stolen card is retried. `refundCharge` above
passes `{ cause: e }` (QM-DECOY-09). Proof: `err.cause` is `undefined` after a provider decline.
Fix: `new ChargeFailedError('renewal charge failed', { cause: e })`. Owner: `error-handling-scan`
§ 6 (grep 6a).

## QM-EH-13 — `raise BillingError(...)` inside `except` without `from`

```defect
id:       QM-EH-13
file:     worker/worker/renewals/charge_runner.py
line:     26
severity: medium
command:  /quality-audit
class:    error/cause-lost
anchor:   raise BillingError(f"refund of
match:    from e|from\b|cause|B904|chain|traceback
```

The provider's reason (already refunded, charge too old) is lost to support; Python prints "during
handling of the above exception, another exception occurred" instead of a cause. Proof:
`__cause__` is `None`. Fix: `raise BillingError(...) from e`. Owner: `error-handling-scan` § 6
(grep 6b; Ruff `B904`).

## QM-EH-14 — `%v` wraps `ErrDuplicate`, so `errors.Is` never matches

```defect
id:       QM-EH-14
file:     ingest/store.go
line:     46
severity: high
command:  /quality-audit
class:    error/cause-lost
anchor:   %v", e.ID, err)
match:    %v|%w|errors\.Is|wrap|ErrDuplicate|duplicate
```

`handler.go` treats a duplicate delivery as success with `errors.Is(err, ErrDuplicate)`; `%v`
flattens the error to text, so a redelivery returns 503 and the provider retries it until it gives
up — and the event is never forwarded. Every other wrap in `store.go` uses `%w` (QM-DECOY-11).
Proof: `errors.Is(store.Save(dup), ErrDuplicate)` is false. Fix: `%w`. Owner: `error-handling-scan`
§ 6 (grep 6c; `errorlint`).

## QM-EH-15 — The global filter answers a `ValidationError` with 500

```defect
id:       QM-EH-15
file:     api/src/common/http-exception.filter.ts
line:     17
severity: high
command:  /quality-audit
class:    error/wrong-status
anchor:   : 500;
match:    500|422|ValidationError|status|validation
```

`ValidationError` is neither an `HttpException` nor a `DomainError`, so it falls through to 500,
is logged at error and its message is replaced by "Internal error" — while `errors.ts` documents
422 for it. Every rejected plan change reads as an outage on the error dashboard. Found by reading
the class hierarchy; no grep shape. Proof: the status table — `PUT /subscriptions/me/plan` with an
invalid body → expected 422, got 500. Fix: map `ValidationError` to 422 with its fields. Owner:
`error-handling-scan` § 6.

## QM-EH-16 — `l.mu.Lock()` with no `defer`: the error return leaks the lock

```defect
id:       QM-EH-16
file:     ingest/ratelimit.go
line:     40
severity: high
command:  /quality-audit
class:    error/paired-state
anchor:   l.mu.Lock()
match:    Lock|Unlock|defer|deadlock|hang|leak|mutex
```

`Allow` returns early when `bucketFor` fails (an event with an empty `account`) without unlocking;
the next webhook blocks forever and ingest stops. Proof: paired-state restore — call `Allow("")`
then `Allow("m_1")` with a timeout → it hangs. Fix: `l.mu.Lock(); defer l.mu.Unlock()`. Owner:
`error-handling-scan` § 7 (grep 7a).

## QM-EH-17 — `open(path, "w")` outside `with`: the close error and the handle are lost

```defect
id:       QM-EH-17
file:     worker/worker/exports/ledger_export.py
line:     10
severity: high
command:  /quality-audit
class:    error/paired-state
anchor:   f = open(path, "w", newline="")
match:    open\(|with\b|close|handle|leak|SIM115|context manager
```

A failing `writerows` leaves the file open and truncated; a failed `close()` (disk full on
flush) raises after part of the export is written — and nothing removes the half file before the
upload. Proof: inject an `OSError` in `writerows` → the handle stays open. Fix: `with open(...) as
f:`. Owner: `error-handling-scan` § 7 (grep 7a; Ruff `SIM115`).

## QM-EH-18 — `setSaving(true)` with no `finally`: a failed save disables the button for good

```defect
id:       QM-EH-18
file:     web/src/billing/usePaymentMethod.ts
line:     10
severity: medium
command:  /quality-audit
class:    error/paired-state
anchor:   setSaving(true);
match:    saving|finally|busy|flag|stuck|disabled|setSaving
```

`apiOrThrow` throws on a declined card; `setSaving(false)` never runs and "Save card" stays
disabled until a reload. `error` is never set either. Proof: the API answers 402 → `saving` stays
true. Fix: `try { ... } catch (e) { setError(...) } finally { setSaving(false) }`. Owner:
`error-handling-scan` § 7 (grep 7b).

## QM-TY-01 — `JSON.parse(message.body) as OrderImported` on a versioned queue

```defect
id:       QM-TY-01
file:     api/src/imports/order-import.consumer.ts
line:     23
severity: high
command:  /quality-audit
class:    types/boundary-cast
anchor:   JSON.parse(message.body) as OrderImported
match:    JSON\.parse|cast|as OrderImported|validat|schema|zod|amountCents|amountMinor
```

The storefront plugin's v3 sends `amountMinor`; the cast says `amountCents`, so `totalCents` is
`undefined` and Prisma rejects the insert three calls deep — on every v3 message, forever. The plan
consumer next to it parses with zod first (QM-DECOY-03). Proof: boundary value vector — a v3
message → a Prisma validation error instead of a typed refusal at the boundary. Fix: a zod schema
for both versions and a dead letter. Owner: `type-safety-scan` § 1 (grep 1a).

## QM-TY-02 — Go: `raw["account"].(string)` panics on a platform event

```defect
id:       QM-TY-02
file:     ingest/handler.go
line:     58
severity: high
command:  /quality-audit
class:    types/boundary-cast
anchor:   MerchantID: raw["account"].(string),
match:    \.\(string\)|type assertion|panic|, ok|comma.?ok|account
```

Provider events for the platform's own account carry no `account` field; the unchecked assertion
panics, `net/http` recovers it, the connection drops and the provider redelivers the same event —
forever. Grep 1c misses it: its pattern needs `x.(T)` with an identifier before `.(`, and an index
expression (`raw["account"]`) is not one. Proof: post an event without `account` → panic in the
log. Fix: `account, ok := raw["account"].(string)`, or decode into a struct. Owner:
`type-safety-scan` § 1.

## QM-TY-03 — `api<T>()` casts every response body to `T` with no check — status included

```defect
id:       QM-TY-03
file:     web/src/api/client.ts
line:     10
severity: high
command:  /quality-audit
class:    types/boundary-cast
anchor:   return (await res.json()) as T;
match:    as T|cast|generic|validat|schema|res\.ok|status|unchecked
```

Every portal call trusts the server's shape and never looks at the status: a 500 error envelope
becomes an `InvoiceRow[]` of `undefined` fields, a 401 page throws a `SyntaxError` from `res.json()`.
One finding, N callers. Proof: the API answers `{ error: {...} }` with 500 → `useInvoices` sets it as
rows. Fix: check `res.ok` (throw `toApiError`) and take a schema parameter. Owner:
`type-safety-scan` § 1 (shape) with `error-handling-scan` § 3 (status), one site.

## QM-TY-04 — `billingAddress!.country` on an optional relation

```defect
id:       QM-TY-04
file:     api/src/billing/invoice-pdf.controller.ts
line:     29
severity: high
command:  /quality-audit
class:    types/non-null-assertion
anchor:   invoice.customer.billingAddress!.country
match:    !\.|non.?null|nullable|optional|billingAddress|null|undefined|TypeError
```

`BillingAddress` is optional in `schema.prisma`, and free-plan customers never enter one; their
invoice PDF route throws a `TypeError` → 500. (With `strictNullChecks: false` the `!` is not even
needed to compile — QM-TY-05.) Proof: an invoice of a customer without an address → 500. Fix:
`?.country` and a typed `MissingBillingAddress` (or render without a country). Owner:
`type-safety-scan` § 2 (grep 2).

## QM-TY-05 — `"strictNullChecks": false` in the API

```defect
id:       QM-TY-05
file:     api/tsconfig.json
line:     6
severity: medium
command:  /quality-audit
class:    types/strictness-off
anchor:   "strictNullChecks": false
match:    strictNullChecks|strict|null check
```

The whole API compiles without null tracking, so every optional relation and every
`findUnique` result is treated as present. Proof: the checker diagnostic — a scratch tsconfig with the
flag on reports `invoice-pdf.controller.ts` (QM-TY-04's line) among the rest. Fix: turn it on with a
dated per-folder plan. Owner: `type-safety-scan` § 3 (grep 3).

## QM-TY-06 — `// @ts-nocheck` on the revenue chart hides a misspelt field

```defect
id:       QM-TY-06
file:     web/src/reports/RevenueChart.tsx
line:     1
severity: medium
command:  /quality-audit
class:    types/strictness-off
anchor:   // @ts-nocheck
match:    ts-nocheck|nocheck|type.?check|refunded_cents|NaN
```

The opt-out hides `r.refunded_cents` (the rows carry `refundedCents`), so the caption's net revenue
is `NaN`. Proof: delete the directive → TS2339 at that line. Fix: type the props and fix the field.
Owner: `type-safety-scan` § 3 (grep 3).

## QM-CS-01 — `code.replace(/\s+/g, '')` — the result is thrown away

```defect
id:       QM-CS-01
file:     api/src/coupons/coupon-code.ts
line:     5
severity: medium
command:  /quality-audit
class:    logic/discarded-result
anchor:   code.replace(/\s+/g, '');
match:    replace|discard|ignored|immutable|return value|no effect
```

Strings are immutable; `normalizeCouponCode(" spring 24 ")` returns `"SPRING 24"`, which the
pattern then accepts (QM-CS-07). Proof: input `"spring 24"` → `"SPRING 24"`, expected `"SPRING24"`.
Fix: `return code.replace(/\s+/g, '')`. Owner: `correctness-smell-scan` § 1 (grep 1a).

## QM-CS-02 — `lines.concat(adjustments)` — credits never reach the invoice

```defect
id:       QM-CS-02
file:     api/src/billing/invoice-lines.ts
line:     9
severity: high
command:  /quality-audit
class:    logic/discarded-result
anchor:   lines.concat(adjustments);
match:    concat|discard|ignored|immutable|return value|adjustment
```

`concat` returns a new array; `buildInvoiceLines` returns the plan line alone, so proration
credits and coupons are dropped and the customer is invoiced the full price. Proof: one plan line +
one `-500` adjustment → total = plan price. Fix: `return [planLine, ...adjustments]`. Owner:
`correctness-smell-scan` § 1 (grep 1a).

## QM-CS-03 — A credit refund calls `transfer(customer, merchant)` — the wrong way

```defect
id:       QM-CS-03
file:     api/src/wallet/credit-transfer.service.ts
line:     38
severity: critical
command:  /quality-audit
class:    logic/swapped-arguments
anchor:   await this.transfer(customerWallet, merchantWallet, amountCents, 'invoice-refund');
match:    swap|order|argument|from.{0,20}to|direction|refund
```

`transfer(from, to)` always moves money from the first wallet; `refundCredit` passes the customer
first, so a refund *debits* the customer again and credits the merchant. `payWithCredit` makes the
same call for a payment, where it is right (QM-DECOY-25) — only the comment's direction tells
them apart. No grep shape. Proof: asymmetric balances (customer 0, merchant 5 000) → refund 1 000
fails the balance guard, or with credit available moves it the wrong way. Fix: `transfer(merchantWallet,
customerWallet, ...)`. Owner: `correctness-smell-scan` § 1.

## QM-CS-24 — `Retry-After` seconds passed to `setTimeout` as milliseconds

```defect
id:       QM-CS-24
file:     web/src/api/retry.ts
line:     8
severity: medium
command:  /quality-audit
class:    logic/unit-mismatch
anchor:   setTimeout(resolve, retryAfter)
match:    seconds?|milli|ms\b|unit|Retry-After|1000
```

RFC 9110 `Retry-After` is in seconds (the comment says so); `setTimeout(resolve, 2)` waits 2 ms,
so the portal hammers a rate-limited API three times in a few milliseconds. Proof: a 429 with
`Retry-After: 2` → the second call 2 ms later. Fix: `retryAfter * 1000` (and parse the HTTP-date
form). Owner: `correctness-smell-scan` § 1.

## QM-CS-04 — `percent == ''` is true for 0: "no discount" becomes the default discount

```defect
id:       QM-CS-04
file:     web/src/checkout/DiscountOverrideInput.tsx
line:     11
severity: high
command:  /quality-audit
class:    logic/loose-equality
anchor:   if (percent == '') {
match:    ==|eqeqeq|loose|coerc|strict equal|0
```

`Number('0') == ''` is `true` (both coerce to 0), so an agent who types 0 % gets the plan's default
discount instead of none. Possible only because the web block sets `eqeqeq: 'off'` (QM-SUP-04).
Proof: type `0` → `onChange(undefined)`; expected `onChange(0)`. Fix: test the raw string
(`next.trim() === ''`) before converting. Owner: `correctness-smell-scan` § 2 (grep 2a).

## QM-CS-05 — `interval is "month"` compares identity, not value

```defect
id:       QM-CS-05
file:     worker/worker/renewals/plans.py
line:     6
severity: high
command:  /quality-audit
class:    logic/identity-on-literal
anchor:   if subscription.interval is "month":
match:    \bis\b|identity|==|literal|F632|interned
```

An interval read from the database is a new string object; `is` is false, so every monthly plan
is annualized ×1 and annual revenue is under-reported 12-fold for them. Python warns
(`SyntaxWarning: "is" with a literal`). Proof: `Subscription(interval="".join(["mon", "th"]))` →
`periods_per_year == 1`. Fix: `==`. Owner: `correctness-smell-scan` § 2 (grep 2c; Ruff `F632`).

## QM-CS-06 — `plan !== 'free' || plan !== 'trial'` is always true

```defect
id:       QM-CS-06
file:     api/src/subscriptions/feature-gate.ts
line:     5
severity: high
command:  /quality-audit
class:    logic/always-true
anchor:   if (plan !== 'free' || plan !== 'trial') {
match:    always (true|false)|\|\||&&|tautolog|condition|logic
```

Every plan passes, so free and trial accounts can turn on metered billing. Proof: the truth table —
`canUseMeteredBilling('free')` is `true`. Fix: `&&`. Owner: `correctness-smell-scan` § 2 (grep 2b).

## QM-CS-07 — `/^[A-Z0-9]+|-PROMO$/` anchors each side of `|` separately

```defect
id:       QM-CS-07
file:     api/src/coupons/coupon-code.ts
line:     11
severity: medium
command:  /quality-audit
class:    logic/regex-precedence
anchor:   /^[A-Z0-9]+|-PROMO$/.test(code)
match:    regex|anchor|precedence|\||alternation|group
```

The pattern means "starts with letters/digits" **or** "ends with -PROMO": `"SPRING 24 !!"` and
`"x-PROMO"` both pass. Proof: the near-miss table (`"SPRING24!"`, `"a-PROMO"`) → true, expected
false. Fix: `/^[A-Z0-9]+(?:-PROMO)?$/`. Owner: `correctness-smell-scan` § 2 (grep 2f).

## QM-CS-08 — Go: `lastSentAt == sentAt` compares `time.Time` with `==`

```defect
id:       QM-CS-08
file:     ingest/dedupe.go
line:     29
severity: high
command:  /quality-audit
class:    logic/time-equality
anchor:   if ok && lastSentAt == sentAt {
match:    ==|Equal|time\.Time|location|offset|monotonic
```

`==` compares the location too; the comment above says redeliveries carry another region's offset,
so the same instant parsed from `+02:00` and `Z` is not `==` and the duplicate is forwarded twice.
Proof: two `time.Parse` of one instant with different offsets → `==` false, `Equal` true. Fix:
`lastSentAt.Equal(sentAt)`. Owner: `correctness-smell-scan` § 2 (grep 2d).

## QM-CS-09 — `applied=[]` — the default list is shared across renewals

```defect
id:       QM-CS-09
file:     worker/worker/renewals/discounts.py
line:     10
severity: high
command:  /quality-audit
class:    logic/mutable-default
anchor:   applied=[]) -> tuple[int, list[str]]:
match:    mutable default|default arg|B006|shared|\[\]|applied
```

A discount applied in one call is "already applied" in every later call that uses the default,
so the second customer of the night gets no discount. Proof: call twice with the same code →
the second returns the undiscounted amount. Fix: `applied: list[str] | None = None`. Owner:
`correctness-smell-scan` § 3 (grep 3a; Ruff `B006`).

## QM-CS-10 — Go: `if err := tx.Commit()` shadows the named result, so a failed commit returns nil

```defect
id:       QM-CS-10
file:     ingest/store.go
line:     69
severity: high
command:  /quality-audit
class:    logic/shadowed-error
anchor:   if err := tx.Commit(); err != nil {
match:    shadow|:=|named (return|result)|Commit|nil
```

`SaveBatch` returns its named `err`, which is nil at the end; the commit failure lives in the
inner `err`, is logged and dropped — the replay tool reports "replayed n events" for a batch that
was rolled back. Proof: a commit fake fails → `SaveBatch` returns nil. Fix: `if err = tx.Commit();
err != nil { return err }`. Owner: `correctness-smell-scan` § 3 (grep 3f lists the function; read).

## QM-CS-25 — Go: a package-level map written from every request goroutine

```defect
id:       QM-CS-25
file:     ingest/counters.go
line:     8
severity: high
command:  /quality-audit
class:    logic/data-race
anchor:   deliveriesByMerchant[merchantID]++
match:    race|concurren|goroutine|map|mutex|sync
```

`net/http` serves each request on its own goroutine; `deliveriesByMerchant[merchantID]++` is an
unsynchronised map write — Go aborts the process with `fatal error: concurrent map writes`, taking
ingest down. `metrics.go` guards the same shape with a mutex (QM-DECOY-12). Proof: `go test -race`
with 50 concurrent `recordDelivery` calls. Fix: a mutex or `sync.Map`. Owner:
`correctness-smell-scan` § 3.

## QM-CS-11 — `Math.round(parseFloat(amountInput) * 100)` for account credit

```defect
id:       QM-CS-11
file:     web/src/billing/money.ts
line:     3
severity: high
command:  /quality-audit
class:    logic/float-money
anchor:   return Math.round(parseFloat(amountInput
match:    float|parseFloat|\* ?100|round|1\.005|cents|decimal
```

`"1.005"` becomes 100 cents (binary float), and `"12,50"` only works because of the `,` → `.`
replace. Proof: the exact-decimal table — `1.005` → 100, expected 101 (half-up). Fix: parse the
decimal string into integer minor units without floats. Owner: `correctness-smell-scan` § 4
(grep 4b).

## QM-CS-12 — Payouts multiply every currency by 100 (JPY, KWD wrong)

```defect
id:       QM-CS-12
file:     api/src/payouts/minor-units.ts
line:     12
severity: critical
command:  /quality-audit
class:    logic/minor-units
anchor:   return Math.round(row.amount * 100);
match:    100|minor unit|exponent|JPY|KWD|currenc|decimal
```

JPY has 0 minor units and KWD 3: a 5 000 JPY payout is sent as 500 000, a 12.345 KWD payout as
1 235. `feeToMinorUnits` in the same file uses the currency table (QM-DECOY-26). Proof: `{ amount:
5000, currency: 'JPY' }` → 500 000, expected 5 000. Fix: `10 ** MINOR_UNITS[row.currency]`. Owner:
`correctness-smell-scan` § 4 (grep 4b).

## QM-CS-13 — `Number(query.qty)` records 0 units for an empty or junk value

```defect
id:       QM-CS-13
file:     api/src/usage/usage.controller.ts
line:     12
severity: medium
command:  /quality-audit
class:    logic/unsafe-parse
anchor:   const qty = Number(query.qty);
match:    Number\(|parse|NaN|empty|validat|0
```

`Number('')` is 0 and `Number(' ')` is 0; `Number('12abc')` is `NaN`, which reaches the SQL update.
The export route below validates with `parseInt(..., 10)` and a range (QM-DECOY-23). Proof: `?qty=`
→ a 0-unit record; `?qty=abc` → `NaN`. Fix: integer parse with a range check, 422 otherwise. Owner:
`correctness-smell-scan` § 4 (grep 4d).

## QM-CS-14 — `offset = page * pageSize` with a 1-based page skips the first page

```defect
id:       QM-CS-14
file:     api/src/invoices/invoice-list.service.ts
line:     16
severity: high
command:  /quality-audit
class:    logic/off-by-one-page
anchor:   const offset = page * pageSize;
match:    offset|page|off.?by.?one|1.?based|skip
```

The comment says pages are 1-based; page 1 skips the 20 newest invoices, so the portal never shows
the latest ones. Proof: 25 invoices, page 1 → items 21–25. Fix: `(page - 1) * pageSize`. Owner:
`correctness-smell-scan` § 4 (grep 4e).

## QM-CS-15 — `prices.sort()` sorts numbers as strings

```defect
id:       QM-CS-15
file:     web/src/pricing/PriceLadder.tsx
line:     6
severity: medium
command:  /quality-audit
class:    logic/numeric-sort
anchor:   prices.sort();
match:    sort|comparator|lexicograph|string order|numeric
```

`[1900, 9900, 49900].sort()` gives `[1900, 49900, 9900]`: the ladder shows enterprise before growth.
Proof: that input. Fix: `toSorted((a, b) => a - b)`. Owner: `correctness-smell-scan` § 4 (grep 4a).

## QM-CS-16 — `range(0, len(rows) - size, size)` drops the last batch

```defect
id:       QM-CS-16
file:     worker/worker/exports/batching.py
line:     6
severity: high
command:  /quality-audit
class:    logic/chunk-drops-tail
anchor:   for start in range(0, len(rows) - size, size):
match:    range|last|drop|off.?by|chunk|tail|missing
```

With 1 200 rows and size 500 the loop yields rows 0–999 and silently drops the last 200 ledger
rows; with exactly 500 rows it yields nothing. The docstring promises every row. Proof: the
property `concat(batches(xs)) == xs` fails at 1 200 and 500. Fix: `range(0, len(rows), size)`.
Owner: `correctness-smell-scan` § 4 (reading).

## QM-CS-17 — `accessLevel` answers `full` for `past_due`

```defect
id:       QM-CS-17
file:     api/src/subscriptions/subscription-status.ts
line:     25
severity: critical
command:  /quality-audit
class:    logic/non-exhaustive-switch
anchor:   return 'full'; // any other status keeps access
match:    default|exhaustive|past_due|PastDue|switch|assertNever|enum
```

`PastDue` was added in 5.2 and has no case, so a customer whose renewal failed keeps full access
indefinitely. The label switch below ends in `assertNever` (QM-DECOY-04). Proof: a test over
`Object.values(SubscriptionStatus)` fails on `past_due`. Fix: an explicit `PastDue` arm (product
decision: read-only?) and `assertNever` in the default. Owner: `correctness-smell-scan` § 5
(grep 5a).

## QM-CS-18 — `datetime.utcnow()` compared to an aware timestamp

```defect
id:       QM-CS-18
file:     worker/worker/renewals/schedule.py
line:     11
severity: high
command:  /quality-audit
class:    time/naive-utcnow
anchor:   datetime.utcnow()
match:    utcnow|naive|aware|timezone|UTC|DTZ
```

`next_renewal_at` comes from a `timestamptz` column (aware); comparing it with a naive `utcnow()`
raises `TypeError: can't compare offset-naive and offset-aware datetimes` — every renewal check
crashes. `utcnow` is also deprecated since 3.12. Proof: an aware value → `TypeError`. Fix:
`datetime.now(UTC)`. Owner: `correctness-smell-scan` § 6 (grep 6b; Ruff `DTZ003`).

## QM-CS-26 — A monthly renewal is "+ 30 days"

```defect
id:       QM-CS-26
file:     worker/worker/renewals/schedule.py
line:     6
severity: high
command:  /quality-audit
class:    time/calendar-month
anchor:   timedelta(days=30)
match:    30|month|calendar|timedelta|drift
```

Monthly plans renew on the calendar day (the billing anchor); +30 days drifts five days a year and
bills twice in some months (2026-01-31 → 03-02 → 04-01 → 05-01 → 05-31: no February, two Mays).
Proof: from 2026-01-31 the next renewal is 2026-03-02, expected 2026-02-28. Fix: add a calendar month in the customer's zone,
clamped to the month's last day. Owner: `correctness-smell-scan` § 6.

## QM-CS-19 — `new Date(startDate)` then `getDate()`: the anchor day is off by one west of UTC

```defect
id:       QM-CS-19
file:     api/src/billing/billing-anchor.ts
line:     4
severity: high
command:  /quality-audit
class:    time/date-only-parse
anchor:   const start = new Date(startDate);
match:    new Date|UTC|time ?zone|getDate|date.?only|off by one|local
```

`new Date('2026-03-29')` is UTC midnight; `getDate()` reads the process's zone, which is not pinned
anywhere in the repo — at `TZ=America/New_York` the anchor is the 28th. Proof: `TZ=America/New_York`
→ `billingAnchorDay('2026-03-29') === 28`. Fix: split the date string (or a date-only type).
Owner: `correctness-smell-scan` § 6 (perturbation; the literal-only grep 6a misses a variable).

## QM-CS-20 — `YYYY` with `useAdditionalWeekYearTokens`: week-numbering year in invoice numbers

```defect
id:       QM-CS-20
file:     api/src/invoices/invoice-number.ts
line:     5
severity: high
command:  /quality-audit
class:    time/week-year-token
anchor:   format(issuedAt, 'YYYY'
match:    YYYY|week.?(numbering )?year|yyyy|ISO week|token
```

date-fns' `YYYY` is the week-numbering year (it throws unless that option is set — someone set it
to silence the error). Invoices issued on 2025-12-29 get `TG-2026-…`, colliding with next year's
sequence; `statementFileName` below uses `yyyy`. Proof: `invoiceNumber(new Date('2025-12-29'), 1)` →
`TG-2026-000001`. Fix: `yyyy`, drop the option. Owner: `correctness-smell-scan` § 6 (grep 6a).

## QM-CS-21 — `displayName.slice(0, 20)` cuts a surrogate pair

```defect
id:       QM-CS-21
file:     web/src/account/DisplayName.tsx
line:     5
severity: medium
command:  /quality-audit
class:    text/code-unit-slice
anchor:   displayName.slice(0, MAX_HEADER_CHARS)
match:    slice|emoji|surrogate|code unit|grapheme|unicode|Segmenter
```

A name whose 20th code unit is the first half of an emoji renders a lone surrogate (`�`). Proof: a
name whose 20th UTF-16 unit is the first half of `👍` → the header shows a lone surrogate. Fix: `Intl.Segmenter` graphemes, or
`Array.from` code points. Owner: `correctness-smell-scan` § 6 (grep 6e).

## QM-CS-22 — `debugger;` in the invoice search handler

```defect
id:       QM-CS-22
file:     web/src/search/SearchPage.tsx
line:     20
severity: low
command:  /quality-audit
class:    breakpoint/debugger
anchor:   debugger;
match:    debugger|breakpoint
```

Inert without an inspector, but it ships in the bundle and stops every finance user with devtools
open on each keystroke. Proof: the line, and `no-debugger` firing there. Fix: delete. Owner:
`correctness-smell-scan` § 7 (grep 7).

## QM-CS-23 — `breakpoint()` in the collections escalation

```defect
id:       QM-CS-23
file:     worker/worker/renewals/dunning.py
line:     25
severity: high
command:  /quality-audit
class:    breakpoint/pdb
anchor:   breakpoint()
match:    breakpoint|pdb|debugger|T100
```

In the nightly worker `breakpoint()` opens pdb on stdin: the job blocks (or dies on a closed TTY)
at the first escalation. Proof: the line, Ruff `T100`. Fix: delete. Owner: `correctness-smell-scan`
§ 7 (grep 7).

## QM-SUP-01 — `no-floating-promises` disabled over a live charge

```defect
id:       QM-SUP-01
file:     api/src/subscriptions/renewal.controller.ts
line:     12
severity: high
command:  /quality-audit
class:    suppression/hides-live-diagnostic
anchor:   // eslint-disable-next-line @typescript-eslint/no-floating-promises
match:    eslint-disable|no-floating-promises|suppress|float|unobserved|await
```

"Retry payment" answers `processing` and the charge floats with no reason on the directive; a
declined retry is an unhandled rejection the customer never sees. The rule is at error for the API,
so the directive is the only reason CI is green. Proof: `npx eslint --no-inline-config` reports
`no-floating-promises` at the call; the unhandled-failure hook test fails. Fix: queue the retry (or
await it) and delete the directive. Owner: `suppression-scan` § 2 (grep 2b) with
`error-handling-scan` § 4.

## QM-SUP-02 — `# type: ignore[union-attr]` hides a `None` the docstring predicts

```defect
id:       QM-SUP-02
file:     worker/worker/renewals/customers.py
line:     10
severity: medium
command:  /quality-audit
class:    suppression/hides-live-diagnostic
anchor:   # type: ignore[union-attr]
match:    type: ?ignore|union-attr|None|Optional|suppress|mypy
```

The docstring says deleted accounts are no longer in the map; `find_account` returns `None` for
them and `.email` raises `AttributeError` in the dunning run. mypy (strict, in CI) found it; the
directive silenced it. Proof: delete the directive → mypy `union-attr` at the line; a missing id →
`AttributeError`. Fix: handle `None` (skip and log). Owner: `suppression-scan` § 2.

## QM-SUP-03 — `/* eslint-disable */` over the revenue report service

```defect
id:       QM-SUP-03
file:     api/src/reports/revenue-report.service.ts
line:     1
severity: high
command:  /quality-audit
class:    suppression/blanket
anchor:   /* eslint-disable */
match:    eslint-disable|blanket|file.?wide|suppress|all rules
```

A rule-less, file-wide directive in production code. The unsuppressed re-run prints
`no-floating-promises` at `this.saveSnapshot(month, rows)`: the snapshot the auditors read is
written fire-and-forget and its failure is never observed. Proof: `npx eslint --no-inline-config`
on the file. Fix: delete the directive, await the write. Owner: `suppression-scan` § 1 (grep 1),
the revealed diagnostic `error-handling-scan` § 4.

## QM-SUP-04 — `eqeqeq: 'off'` for the whole web app

```defect
id:       QM-SUP-04
file:     eslint.config.mjs
line:     22
severity: medium
command:  /quality-audit
class:    suppression/rule-off
anchor:   eqeqeq: 'off',
match:    eqeqeq|\boff\b|disabled|switched off
```

A correctness rule switched off for every portal file, with no reason; it is what let QM-CS-04
ship. The API block holds the same rule at error. Proof: a scratch config with `eqeqeq` at error
reports the `DiscountOverrideInput.tsx` line. Fix: `eqeqeq: ['error', 'always', { null: 'ignore' }]`
as in the API block. Owner: `suppression-scan` § 3 (grep 3a).

## QM-DC-01 — `legacy-invoice-number.ts`: nothing imports it

```defect
id:       QM-DC-01
file:     api/src/billing/legacy-invoice-number.ts
line:     2
severity: low
command:  /quality-audit
class:    dead/unused-file
anchor:   export function legacyInvoiceNumber(
match:    unused|dead|no import|never imported|unreferenced|orphan
```

The pre-2025 numbering helpers have no importer in any path form, no loader matches the folder,
and nothing names them in config. Proof: removal — build, boot and suite unchanged. Fix
(`/simplify`): delete. Owner: `dead-code-scan` § 1 (grep 1).

## QM-DC-02 — `FEATURE_NEW_PRORATION` is `"true"` in every environment

```defect
id:       QM-DC-02
file:     api/src/subscriptions/plan-change.service.ts
line:     9
severity: low
command:  /quality-audit
class:    dead/flag
anchor:   if (process.env.FEATURE_NEW_PRORATION === 'true') {
match:    flag|FEATURE_NEW_PRORATION|dead|always|rollout|stale
```

`deploy/values-{production,staging,dev}.yaml` and `.env.example` all set it to `"true"`; the old
half-period rule below the branch is dead and still selectable by a missing variable — a pod
started without the env var would bill with the pre-2025 rule. Proof: the three values files;
removal with the flag pinned on. Fix: delete the flag and the old branch. Owner: `dead-code-scan`
§ 4 (grep 4).

## QM-DC-03 — The quota check sits after an unconditional `return`

```defect
id:       QM-DC-03
file:     api/src/usage/quota.ts
line:     20
severity: high
command:  /quality-audit
class:    dead/unreachable-check
anchor:   if (account.usedUnits + units > account.quota) {
match:    unreachable|after (the |an? )?return|never runs|dead
```

`admitUsage` returns `admitted: true` before the quota comparison, so metered plans are never
stopped at their quota — revenue the plans were priced on. A check that was meant to run: high and
correctness (`dead-code-scan` § 3). Proof: the intended-behaviour test — quota 100, used 100, 1 more
unit → expected refused, got admitted. Fix (`/quality-fix`): move the check above the return.
Owner: `dead-code-scan` § 3 (grep 3b).

## QM-DU-01 — The worker's `prorate` still counts every month as 30 days

```defect
id:       QM-DU-01
file:     worker/worker/billing/proration.py
line:     13
severity: high
command:  /quality-audit
class:    duplication/divergent-copy
anchor:   return price_cents * unused // DAYS_IN_PERIOD
match:    duplicat|copy|diverg|clone|30|leap|February
```

`api/src/billing/proration.ts` took fix #418 (calendar days; February over-credited); the nightly
worker's copy did not, and `ai/architecture.md` says the rule lives once. A plan change on
2028-02-15 credits 14/29 of the price in the API and 14/30 in the batch. Proof (divergence): the
same inputs through both copies differ. Fix: one implementation the worker calls (or the fix applied
with the API's test run against both). Owner: `duplication-scan` § 1 / § 2 (grep 2: `prorate` in two
areas).

## QM-DU-02 — The checkout tax preview is a pre-fix copy of `computeTax`

```defect
id:       QM-DU-02
file:     web/src/checkout/tax-preview.ts
line:     13
severity: high
command:  /quality-audit
class:    duplication/divergent-copy
anchor:   return Math.round(input.netCents * rate);
match:    duplicat|copy|diverg|clone|reverse.?charge|round|banker
```

The API's `computeTax` took the half-cent banker's rounding fix and the EU reverse charge; the
portal's copy has neither, although its comment says it must match the invoice. A B2B customer
with a VAT id in another EU country sees 19 % VAT at checkout and 0 on the invoice; 0.5-cent
cases differ by a cent. Proof: `{ netCents: 1_250, country: 'NL', b2bVatId: 'NL123' }` → 263 vs 0.
Fix: serve the tax from the API (or share one module). Owner: `duplication-scan` § 1 / § 2 (grep 2;
jscpd pairs the two files).

## QM-AR-02 — `billing.events` ↔ `billing.service`: a value cycle read at module load

```defect
id:       QM-AR-02
file:     api/src/billing/billing.events.ts
line:     5
severity: high
command:  /quality-audit
class:    architecture/runtime-cycle
anchor:   renewed: BillingService.RENEWED,
match:    cycl|circular|import order|TDZ|undefined|init|load
```

`billing.events.ts` reads `BillingService.RENEWED` at module evaluation, and `billing.service.ts`
imports `BILLING_EVENTS`. The app boots only because `billing.module.ts` imports the listener (and
so `billing.events`) first; any entry that loads `billing.service` first — `renewal.service.ts` in a
unit test, a reordered import — dies with "Cannot read properties of undefined (reading
'RENEWED')". Proof (boot): `node -e "require('./dist/subscriptions/renewal.service')"` throws.
Fix (`decouple-cycle`): move the event names to a leaf module both import. Owner:
`architectural-diagnosis` § 2 (dependency-cruiser `no-circular`; blocked on Node 23 — trap 1).

## QM-AR-03 — The domain imports `@prisma/client` against the declared rule

```defect
id:       QM-AR-03
file:     api/src/domain/pricing.ts
line:     1
severity: high
command:  /quality-audit
class:    architecture/layer-violation
anchor:   import { Prisma } from '@prisma/client';
match:    layer|prisma|framework|hexagonal|ADR|depend|boundar
```

ADR 0002 and `ai/architecture.md` make `api/src/domain` framework-free, and
`api/.dependency-cruiser.cjs` declares it at error (`domain-is-framework-free`) — but no CI job runs
dependency-cruiser, so the rule is unrun (gate 4) and `seatPrice` returns `Prisma.Decimal`. The
worker cannot port the rule without the ORM, which is the ADR's stated reason. Proof: `npx depcruise
src --config .dependency-cruiser.cjs` (Node 22) reports the edge. Fix (`move-responsibility`): a
domain money type, mapped to `Prisma.Decimal` in the application layer; run depcruise in CI.
Owner: `architectural-diagnosis` § 1.

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect — same file or same feature, same vocabulary,
no defect — and most were written so that only reading the code tells them apart. Each matches a
precedent in `templates/snippets/precedents/code-quality.md`. A run that reports one has produced a
false positive **by construction**.

How they score (`score.py`, § DECOYS in its header): a finding that names the decoy's file, cites a
line within the tolerance window of the decoy's line, and matches every one of the decoy's `match:`
patterns is **pinned** to it, removed before defect assignment, and reported as `DECOYS FLAGGED
k/27`. A finding with no line is never pinned, and a finding a seeded defect could claim at EXACT
strength is never pinned. Every decoy sits more than 12 lines from any defect in its file, which
`--verify` enforces.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| QM-DECOY-01 | `web/src/account/useCurrentUser.ts:23` | QM-EH-03 | a documented degrade mode: logged, counted, and the signed-out render is the designed outcome (§ 14) |
| QM-DECOY-02 | `web/src/api/client.ts:29` | QM-EH-01 | parsing an error body tolerantly; the HTTP status already decided the outcome (§ 15) |
| QM-DECOY-03 | `api/src/imports/plan-import.consumer.ts:21` | QM-TY-01 | the zod `parse` runs first; the cast only adds a brand (§ 26) |
| QM-DECOY-04 | `api/src/subscriptions/subscription-status.ts:43` | QM-CS-17 | `assertNever` in the default is the exhaustiveness control (§ 28) |
| QM-DECOY-05 | `api/src/lib/sdk-shim.ts:9` | QM-SUP-01 | a line-scoped disable of one rule with a checkable reason and an issue link (§ 60) |
| QM-DECOY-06 | `api/src/jobs/dunning-reminder.job.ts:6` | QM-DC-01 | `JobsModule` loads every `*.job.ts` by `globSync` (a 0b loader); no importer is expected |
| QM-DECOY-07 | `web/src/api/generated/billing-client.ts:16` | QM-DU-02 | a generated client, identical by construction in both apps (§ 54) |
| QM-DECOY-08 | `api/src/imports/csv-dialect.ts:12` | QM-AR-02 | branchy but stable, table-tested, no churn and no fix commits: complexity alone is not a finding (§ 51) |
| QM-DECOY-09 | `api/src/billing/charges.service.ts:22` | QM-EH-12 | the provider error is attached as `cause` and logged |
| QM-DECOY-10 | `ingest/archive.go:16` | QM-EH-05 | `Close` on a read-only file in a deferred cleanup, the reason in a comment (§ 17) |
| QM-DECOY-11 | `ingest/store.go:27` | QM-EH-14 | `%w` keeps the chain for `errors.Is` |
| QM-DECOY-12 | `ingest/metrics.go:16` | QM-CS-25 | the counter map is guarded by its own mutex on every access |
| QM-DECOY-13 | `api/src/billing/invoice-pdf.controller.ts:15` | QM-TY-04 | `has(k) ? get(k)!` — the check the compiler cannot see, same expression (§ 27) |
| QM-DECOY-14 | `worker/worker/exports/ledger_export.py:33` | QM-EH-02 | `contextlib.suppress(FileNotFoundError)` on best-effort temp-file cleanup, documented (§ 17) |
| QM-DECOY-15 | `api/src/refunds/refund-batch.service.ts:15` | QM-EH-09 | `Promise.all(items.map(async …))` is awaited and returned (§ 22) |
| QM-DECOY-16 | `worker/worker/renewals/refund_receipts.py:16` | QM-EH-10 | the task is held in a module-level set and observed in a done-callback |
| QM-DECOY-17 | `api/src/app.module.ts:18` | QM-AR-03 | the composition root is the one module that may import everything (§ 57) |
| QM-DECOY-18 | `api/src/invoices/invoice-status.ts:1` | QM-AR-02 | the cycle closes through `import type` only: no runtime edge (§ 87) |
| QM-DECOY-19 | `web/src/invoices/InvoiceDate.tsx:3` | QM-CS-19 | display-only, deliberately in the reader's locale and zone (§ 42) |
| QM-DECOY-20 | `web/src/reports/period-picker.ts:4` | QM-CS-15 | ISO-8601 dates sort correctly as strings; the copy keeps the caller's array (§ 38) |
| QM-DECOY-21 | `worker/worker/renewals/batch.py:6` | QM-CS-18 | `datetime.now(UTC)` is aware, in a job documented as UTC-pinned (§ 45) |
| QM-DECOY-22 | `worker/worker/renewals/discounts.py:24` | QM-CS-09 | a tuple default is immutable |
| QM-DECOY-23 | `api/src/usage/usage.controller.ts:29` | QM-CS-13 | `Number.parseInt(x, 10)` with an integer and range check |
| QM-DECOY-24 | `api/src/usage/retention.ts:5` | QM-CS-26 | a retention cutoff is an elapsed duration, not a calendar step |
| QM-DECOY-25 | `api/src/wallet/credit-transfer.service.ts:25` | QM-CS-03 | a payment moves money customer → merchant: `transfer(customer, merchant)` is right here |
| QM-DECOY-26 | `api/src/payouts/minor-units.ts:27` | QM-CS-12 | converts with the currency's own exponent from the table |
| QM-DECOY-27 | `web/src/subscriptions/plan-change.ts:4` | QM-DU-02 | client and server run the same schema from `@tollgate/contracts` (§ 46) |

```decoy
id:       QM-DECOY-01
file:     web/src/account/useCurrentUser.ts
line:     23
command:  /quality-audit
class:    decoy/declared-degrade-mode
anchor:   if (!cancelled) setUser(null);
match:    catch|setUser|null|swallow|degrade|empty
```

```decoy
id:       QM-DECOY-02
file:     web/src/api/client.ts
line:     29
command:  /quality-audit
class:    decoy/tolerant-error-body
anchor:   // not JSON (proxy page, empty body)
match:    catch|swallow|empty|ignor
```

```decoy
id:       QM-DECOY-03
file:     api/src/imports/plan-import.consumer.ts
line:     21
command:  /quality-audit
class:    decoy/cast-after-validator
anchor:   PlanImportedSchema.parse(JSON.parse(message.body)) as PlanImported
match:    JSON\.parse|cast|as PlanImported|validat|unchecked
```

```decoy
id:       QM-DECOY-04
file:     api/src/subscriptions/subscription-status.ts
line:     43
command:  /quality-audit
class:    decoy/exhaustiveness-sentinel
anchor:   return assertNever(status);
match:    default|exhaustive|switch|assertNever
```

```decoy
id:       QM-DECOY-05
file:     api/src/lib/sdk-shim.ts
line:     9
command:  /quality-audit
class:    decoy/justified-suppression
anchor:   eslint-disable-next-line @typescript-eslint/no-explicit-any
match:    eslint-disable|suppress|any
```

```decoy
id:       QM-DECOY-06
file:     api/src/jobs/dunning-reminder.job.ts
line:     6
command:  /quality-audit
class:    decoy/glob-loaded
anchor:   export class DunningReminderJob {
match:    unused|dead|no import|never imported|unreferenced|orphan
```

```decoy
id:       QM-DECOY-07
file:     web/src/api/generated/billing-client.ts
line:     16
command:  /quality-audit
class:    decoy/generated-clone
anchor:   export class BillingClient {
match:    duplicat|copy|clone|identical
```

```decoy
id:       QM-DECOY-08
file:     api/src/imports/csv-dialect.ts
line:     12
command:  /quality-audit
class:    decoy/complex-but-cold
anchor:   export function sniffDialect(
match:    complex|hotspot|nest|cognitive|god|long
```

```decoy
id:       QM-DECOY-09
file:     api/src/billing/charges.service.ts
line:     22
command:  /quality-audit
class:    decoy/rethrow-with-cause
anchor:   { cause: e }
match:    cause|message|lost|rethrow|swallow
```

```decoy
id:       QM-DECOY-10
file:     ingest/archive.go
line:     16
command:  /quality-audit
class:    decoy/best-effort-close
anchor:   _ = f.Close()
match:    _ =|Close|ignor|discard|errcheck
```

```decoy
id:       QM-DECOY-11
file:     ingest/store.go
line:     27
command:  /quality-audit
class:    decoy/wrap-with-w
anchor:   mark %s processed: %w
match:    %v|%w|wrap|errors\.Is
```

```decoy
id:       QM-DECOY-12
file:     ingest/metrics.go
line:     16
command:  /quality-audit
class:    decoy/guarded-map
anchor:   c.byMerchant[merchantID]++
match:    race|concurren|map|mutex|sync
```

```decoy
id:       QM-DECOY-13
file:     api/src/billing/invoice-pdf.controller.ts
line:     15
command:  /quality-audit
class:    decoy/assertion-after-check
anchor:   COUNTRY_NAMES.get(code)!
match:    !|non.?null|nullable|undefined
```

```decoy
id:       QM-DECOY-14
file:     worker/worker/exports/ledger_export.py
line:     33
command:  /quality-audit
class:    decoy/suppress-on-cleanup
anchor:   contextlib.suppress(FileNotFoundError)
match:    suppress|swallow|ignor|except
```

```decoy
id:       QM-DECOY-15
file:     api/src/refunds/refund-batch.service.ts
line:     15
command:  /quality-audit
class:    decoy/collected-promises
anchor:   Promise.all(items.map(async
match:    async|await|Promise\.all|float|map
```

```decoy
id:       QM-DECOY-16
file:     worker/worker/renewals/refund_receipts.py
line:     16
command:  /quality-audit
class:    decoy/kept-task
anchor:   task.add_done_callback(_background.discard)
match:    create_task|task|reference|garbage|float
```

```decoy
id:       QM-DECOY-17
file:     api/src/app.module.ts
line:     18
command:  /quality-audit
class:    decoy/composition-root
anchor:   // Composition root
match:    layer|import|god|fan.?out|depend|coupl
```

```decoy
id:       QM-DECOY-18
file:     api/src/invoices/invoice-status.ts
line:     1
command:  /quality-audit
class:    decoy/type-only-cycle
anchor:   import type { InvoiceModel }
match:    cycl|circular|import
```

```decoy
id:       QM-DECOY-19
file:     web/src/invoices/InvoiceDate.tsx
line:     3
command:  /quality-audit
class:    decoy/display-locale
anchor:   .toLocaleDateString()
match:    locale|time ?zone|toLocaleDateString|UTC
```

```decoy
id:       QM-DECOY-20
file:     web/src/reports/period-picker.ts
line:     4
command:  /quality-audit
class:    decoy/iso-date-sort
anchor:   [...isoDates].sort()
match:    sort|comparator|lexicograph
```

```decoy
id:       QM-DECOY-21
file:     worker/worker/renewals/batch.py
line:     6
command:  /quality-audit
class:    decoy/aware-now
anchor:   datetime.now(UTC)
match:    datetime\.now|naive|UTC|time ?zone|utcnow
```

```decoy
id:       QM-DECOY-22
file:     worker/worker/renewals/discounts.py
line:     24
command:  /quality-audit
class:    decoy/immutable-default
anchor:   def stackable(codes=())
match:    mutable default|default arg|B006|shared
```

```decoy
id:       QM-DECOY-23
file:     api/src/usage/usage.controller.ts
line:     29
command:  /quality-audit
class:    decoy/radix-parse-with-range
anchor:   Number.parseInt(limitRaw ?? '100', 10)
match:    parseInt|parse|radix|NaN|validat
```

```decoy
id:       QM-DECOY-24
file:     api/src/usage/retention.ts
line:     5
command:  /quality-audit
class:    decoy/elapsed-duration
anchor:   return new Date(now - days * DAY_MS);
match:    DAY_MS|86400|day|DST|calendar|time ?zone
```

```decoy
id:       QM-DECOY-25
file:     api/src/wallet/credit-transfer.service.ts
line:     25
command:  /quality-audit
class:    decoy/correct-argument-order
anchor:   await this.transfer(customerWallet, merchantWallet, amountCents, 'invoice-payment');
match:    swap|order|argument|direction|from.{0,20}to
```

```decoy
id:       QM-DECOY-26
file:     api/src/payouts/minor-units.ts
line:     27
command:  /quality-audit
class:    decoy/currency-exponent
anchor:   return Math.round(amount * 10 ** exponent);
match:    100|minor unit|exponent|float|round|currenc
```

```decoy
id:       QM-DECOY-27
file:     web/src/subscriptions/plan-change.ts
line:     4
command:  /quality-audit
class:    decoy/shared-schema-validation
anchor:   export function validatePlanChange(
match:    duplicat|copy|diverg|twice|clone
```

## Not seeded (read before triaging UNMATCHED)

- **`api/src/admin/admin-ops.service.ts`** — 32 imports and eight responsibilities: the research
  sketch's god class. `architectural-diagnosis` § 4 needs hotspot or change-coupling evidence the
  one-commit tree cannot carry, so a report on it is UNMATCHED, neither credited nor pinned.
- **Hotspots** (`architectural-diagnosis` § 9) — no churn exists in a one-commit tree.
- **Security classes** — the API has no authentication layer at all; `vuln-fullstack` owns security.

## Pre-flight reach (measured 2026-10-05)

Each detector's `## Pre-flight` block, extracted from its `SKILL.md` and run unchanged from the root
of a git-initialised copy of this fixture. "Reached" means a grep line cites the defect's file within
the scoring window; "file" or "folder" means the grep lists the file or its folder without the line.
Ids no grep reaches are found by reading, a value vector, a perturbation or a tool run — by design.

| detector | grep → ids reached |
|----------|--------------------|
| `error-handling-scan` | 1a → EH-01, EH-02 · 1b/2a → EH-19, EH-04 · 2a → EH-03 · 2b → EH-04 · 3a → EH-05 · 3c → EH-07 · 3d → EH-06 · 4a → EH-09, EH-10 · 5 → EH-11 · 6a → EH-12 · 6b → EH-13 · 6c → EH-14 · 7a → EH-16, EH-17 · 7b → EH-18 |
| `type-safety-scan` | 1a → TY-01, TY-03 · 2 → TY-04 · 3 → TY-05, TY-06 |
| `correctness-smell-scan` | 1a → CS-01, CS-02 · 2a → CS-04 · 2b → CS-06 · 2c → CS-05 · 2d → CS-08 · 2f → CS-07 · 3a → CS-09 · 3f → CS-10 (file) · 4a → CS-15 · 4b → CS-11, CS-12 · 4d → CS-13 · 4e → CS-14 · 5a → CS-17 · 6a → CS-20 · 6b → CS-18 · 6e → CS-21 · 7 → CS-22, CS-23 |
| `suppression-scan` | 1 → SUP-03 · 2b → SUP-01, SUP-02 · 3a → SUP-04 |
| `dead-code-scan` | 1 → DC-01 (folder) · 3b → DC-03 · 4 → DC-02 |
| `duplication-scan` | 2 → DU-01, DU-02 (`prorate`, `computeTax` in two areas) · jscpd step 1 → DU-02's files as an exact 10-line pair; 1b needs history |
| `architectural-diagnosis` | 0a → the declared rule file for AR-03 · dependency-cruiser `blocked` on Node 23.8 (trap 1), so § 2 printed 0 cycles from the fallback graph: AR-02 needs the Node 22 lane · § 4 lists `admin-ops.service.ts` (fan-out 32, not seeded) |

**Reached by no grep:** EH-08 (`void` silences the type-aware rule too), EH-15 (a class hierarchy),
TY-02 (type-safety grep 1c needs an identifier before `.(T)`; `raw["account"].(string)` is an index
expression — a gap worth closing in the skill, since decoded JSON is the commonest shape), CS-03,
CS-16, CS-19, CS-24, CS-25, CS-26, AR-02, AR-03.

**Decoys the greps also print** (each must be cleared by reading): DECOY-02 (1a, comment-only
catch), DECOY-10 (3a `_ =`), DECOY-03 (type-safety 1a), DECOY-05 (suppression 2b), DECOY-06
(dead-code grep 1 folder), DECOY-19 and DECOY-24 (correctness 6a), DECOY-01 (correctness 3d, the
empty-deps effect beside it), DECOY-27 (duplication grep 2 `validatePlanChange`).
