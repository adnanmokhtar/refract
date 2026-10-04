# Seeded defects — `review-decoys`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans.
If you stage the fixture by hand, delete this file from the copy first.

Fixture shape: `orders-service` — one reviewable change (Express + Postgres API, React back-office screens, SQL migrations) staged as a diff against a committed base; 23 seeded defects across correctness, data, performance, accessibility and observability, plus 18 look-alike decoys.

Stage with: --git --diff — `base/` is committed as the baseline and `change/` is laid over it as the
uncommitted change (new files added with `git add -N`, so `git diff` shows them). The reviewer sees
exactly one diff, the way `/review-changes` is run on a branch.

**What it measures.** Precision and recall of a diff review, per lens: correctness (6), data (5),
performance (5), accessibility (4), observability (3). Every defect has a correct sibling **in the
same change** — the atomic UPDATE beside the read-modify-write, the batched `ANY($1)` beside the
N+1, the labelled input beside the placeholder-only one — so a reviewer that pattern-matches on
`UPDATE`, `readFileSync` or `<img` reports the decoy too, and a reviewer that refutes before it
reports (refute-before-report § 10) does not. Precision is the Phase-2 proving number: it must not
drop below the run recorded before refute-before-report and the posting bar were wired into
`/review-changes`.

**Not seeded:** security classes (`vuln-fullstack` owns them), style (a formatter is configured —
`package.json` `prettier`; a style comment is a posting-bar violation, not a finding).

Line numbers are exact against `change/`; `benchmarks/run.sh --verify` re-checks every anchor and
that no decoy sits inside a defect's scoring window. File paths are fixture-relative; scoring matches
on the basename, so a report citing `src/orders/refunds.ts:19` lands on `change/src/orders/refunds.ts`.

## Summary

| id | file:line | severity | class |
|----|-----------|----------|-------|
| RD-COR-01 | `src/orders/refunds.ts:19` | high | correctness/overwrite-accumulator |
| RD-COR-02 | `src/orders/refunds.ts:26` | medium | correctness/missing-await |
| RD-COR-03 | `src/lib/retry.ts:5` | high | correctness/assignment-in-condition |
| RD-COR-04 | `src/orders/list.ts:18` | medium | correctness/off-by-one-pagination |
| RD-COR-05 | `web/src/RefundDialog.tsx:19` | high | correctness/double-submit |
| RD-COR-06 | `web/src/useRefund.ts:12` | medium | correctness/stale-effect-deps |
| RD-DATA-01 | `src/orders/refunds.ts:13` | high | data/lost-update |
| RD-DATA-02 | `src/orders/refunds.ts:10` | high | data/money-float |
| RD-DATA-03 | `migrations/2026_10_02_refunds.sql:2` | critical | data/not-null-without-default |
| RD-DATA-04 | `migrations/2026_10_02_refunds.sql:11` | high | data/blocking-index-build |
| RD-DATA-05 | `migrations/2026_10_02_refunds.sql:6` | medium | data/missing-foreign-key |
| RD-PERF-01 | `src/orders/list.ts:15` | high | performance/n-plus-one |
| RD-PERF-02 | `src/orders/list.ts:11` | high | performance/unbounded-query |
| RD-PERF-03 | `src/orders/list.ts:17` | medium | performance/sync-io-on-request-path |
| RD-PERF-04 | `src/orders/export.ts:10` | high | performance/unbounded-memory |
| RD-PERF-05 | `src/orders/export.ts:18` | medium | performance/sequential-independent-awaits |
| RD-A11Y-01 | `web/src/RefundDialog.tsx:11` | high | a11y/non-semantic-control |
| RD-A11Y-02 | `web/src/RefundDialog.tsx:12` | medium | a11y/missing-alt |
| RD-A11Y-03 | `web/src/RefundDialog.tsx:15` | high | a11y/missing-label |
| RD-A11Y-04 | `web/src/RefundDialog.tsx:17` | medium | a11y/error-not-announced |
| RD-OBS-01 | `src/orders/refunds.ts:29` | high | observability/swallowed-error |
| RD-OBS-02 | `src/orders/refunds.ts:8` | high | observability/pii-in-logs |
| RD-OBS-03 | `src/orders/refunds.ts:7` | medium | observability/missing-metric |

## Defects

```defect
id:       RD-COR-01
file:     change/src/orders/refunds.ts
line:     19
severity: high
command:  /review-changes
class:    correctness/overwrite-accumulator
anchor:   order.refunded_cents = cents;
match:    overwrit|replac|instead of (add|accumul|increment|sum)|\+=|previous refund|lose|lost|accumul|running total
```

The running total is assigned the new refund instead of adding to it: a second partial refund forgets the first, and the 409 guard above then lets refunds exceed the order total.

```defect
id:       RD-COR-02
file:     change/src/orders/refunds.ts
line:     26
severity: medium
command:  /review-changes
class:    correctness/missing-await
anchor:   notifyCustomer(order.id, refund.id);
match:    await|unhandled|floating|fire.and.forget|not awaited|promise|reject
```

`notifyCustomer` returns a promise that is neither awaited nor caught: a mailer failure becomes an unhandled rejection (process crash on Node ≥ 15) instead of a logged warning. Decoy RD-DEC-05 is the deliberate `void … .catch()` form.

```defect
id:       RD-COR-03
file:     change/src/lib/retry.ts
line:     5
severity: high
command:  /review-changes
class:    correctness/assignment-in-condition
anchor:   if (res.status < 500 && (res.status = 429)) return res;
match:    assign|=\s*429|===|always (true|truthy)|overwrit|retry|429
```

`res.status = 429` assigns where `!== 429` was meant (the base had `!== 429`). `Response.status` is a read-only getter and an ES module runs in strict mode, so the assignment throws a TypeError on every response under 500 — every customer notification fails — and a 429 is never retried.

```defect
id:       RD-COR-04
file:     change/src/orders/list.ts
line:     18
severity: medium
command:  /review-changes
class:    correctness/off-by-one-pagination
anchor:   const offset = page * pageSize;
match:    off.by.one|first page|page 1|skip|1.based|\(page\s*-\s*1\)|offset
```

`page` is 1-based (README, and the clamp above), so `page * pageSize` skips the whole first page; the base and the sibling compute `(page - 1) * pageSize`.

```defect
id:       RD-COR-05
file:     change/web/src/RefundDialog.tsx
line:     19
severity: high
command:  /review-changes
class:    correctness/double-submit
anchor:   <button type="button" onClick={() => submit(amount)}>
match:    double|twice|disabled|pending|re.?submit|duplicate|idempot|multiple
```

The submit button stays enabled while the refund is pending: a double click issues two refunds (the API has no idempotency key). The sibling RefundReason disables its button while saving.

```defect
id:       RD-COR-06
file:     change/web/src/useRefund.ts
line:     12
severity: medium
command:  /review-changes
class:    correctness/stale-effect-deps
anchor:   }, []);
match:    depend|deps|stale|orderId|exhaustive|\[\]|re.?run|empty
```

The effect reads `orderId` but declares no dependencies: reopening the dialog for another order keeps showing the first order's refunded total.

```defect
id:       RD-DATA-01
file:     change/src/orders/refunds.ts
line:     13
severity: high
command:  /review-changes
class:    data/lost-update
anchor:   const [order] = await db.query('SELECT id, total_cents, refunded_cents FROM orders WHERE id = $1', [req.params.id]);
match:    race|concurren|lost update|transaction|for update|lock|atomic|read.modify.write|two refunds|simultaneous
```

Read-modify-write across two statements with no transaction, row lock or conditional UPDATE: two concurrent refunds both read the old total and both pass the guard. RD-DEC-01 is the single-statement atomic form.

```defect
id:       RD-DATA-02
file:     change/src/orders/refunds.ts
line:     10
severity: high
command:  /review-changes
class:    data/money-float
anchor:   const amount = parseFloat(req.body.amount);
match:    float|parseFloat|cents|decimal|rounding|precision|integer|money
```

Money parsed as a float and rounded: the codebase's money is integer cents end to end (README), and `0.1 + 0.2`-class errors and `NaN` (no validation) reach the database. RD-DEC-02 parses integer cents and validates.

```defect
id:       RD-DATA-03
file:     change/migrations/2026_10_02_refunds.sql
line:     2
severity: critical
command:  /review-changes
class:    data/not-null-without-default
anchor:   ALTER TABLE orders ADD COLUMN refunded_cents integer NOT NULL;
match:    not null|default|backfill|existing rows|fail|populated|40m|rewrite
```

A NOT NULL column with no default on a populated table: the migration fails on deploy (existing rows violate it). RD-DEC-07 is the nullable look-alike.

```defect
id:       RD-DATA-04
file:     change/migrations/2026_10_02_refunds.sql
line:     11
severity: high
command:  /review-changes
class:    data/blocking-index-build
anchor:   CREATE INDEX idx_orders_status ON orders(status);
match:    concurrent|lock|block|writes|downtime|40m|large table
```

A plain CREATE INDEX on the 40M-row orders table takes a SHARE lock and blocks every write for the build. RD-DEC-09 indexes a table created in the same migration, which is empty.

```defect
id:       RD-DATA-05
file:     change/migrations/2026_10_02_refunds.sql
line:     6
severity: medium
command:  /review-changes
class:    data/missing-foreign-key
anchor:   order_id int NOT NULL,
match:    foreign key|references|\bfk\b|orphan|referential
```

refunds.order_id has no REFERENCES orders(id): refunds can point at orders that do not exist. RD-DEC-08 carries the foreign key.

```defect
id:       RD-PERF-01
file:     change/src/orders/list.ts
line:     15
severity: high
command:  /review-changes
class:    performance/n-plus-one
anchor:   order.items = await db.query('SELECT sku, qty FROM order_items WHERE order_id = $1', [order.id]);
match:    n\s*\+\s*1|per order|each order|in a loop|loop|round.?trip|batch|any\(|one query per
```

One query per order inside the loop. RD-DEC-03 loads every item in one `= ANY($1)` query.

```defect
id:       RD-PERF-02
file:     change/src/orders/list.ts
line:     11
severity: high
command:  /review-changes
class:    performance/unbounded-query
anchor:   'SELECT id, total_cents, refunded_cents, status FROM orders WHERE customer_id = $1 ORDER BY id DESC',
match:    limit|unbounded|all orders|pagina|every order|in memory|slice
```

The LIMIT/OFFSET the base had is gone: every order of the customer is loaded (and their items fetched) and then sliced in memory.

```defect
id:       RD-PERF-03
file:     change/src/orders/list.ts
line:     17
severity: medium
command:  /review-changes
class:    performance/sync-io-on-request-path
anchor:   const footer = readFileSync(new URL('./footer.txt', import.meta.url), 'utf8');
match:    sync|readFileSync|block|event loop|per request|every request|cache|module load
```

Synchronous file read on every request blocks the event loop. RD-DEC-04 reads the same file once at module load.

```defect
id:       RD-PERF-04
file:     change/src/orders/export.ts
line:     10
severity: high
command:  /review-changes
class:    performance/unbounded-memory
anchor:   res.type('application/json').send(JSON.stringify(rows));
match:    memory|stream|whole table|every order|all rows|cursor|batch|heap|oom|unbounded|select \*
```

The whole orders table (40M rows) is loaded and serialised in one string: heap exhaustion. Needs a cursor and a streamed response.

```defect
id:       RD-PERF-05
file:     change/src/orders/export.ts
line:     18
severity: medium
command:  /review-changes
class:    performance/sequential-independent-awaits
anchor:   const shipping = await fetchShippingReport(req.params.month);
match:    parallel|promise\.all|concurren|sequential|independent|latency|serial
```

Two independent reports awaited one after the other: the latency is the sum, not the max. RD-DEC-10 is the dependent pair, ordered on purpose.

```defect
id:       RD-A11Y-01
file:     change/web/src/RefundDialog.tsx
line:     11
severity: high
command:  /review-changes
class:    a11y/non-semantic-control
anchor:   <div className="refund-dialog__close" onClick={onClose}>×</div>
match:    button|keyboard|focus|role|div|tab|aria|accessible name|label
```

A clickable div: not focusable, no role, no accessible name — keyboard and screen-reader users cannot close the dialog. The base Modal and RD-DEC-11 use a labelled button.

```defect
id:       RD-A11Y-02
file:     change/web/src/RefundDialog.tsx
line:     12
severity: medium
command:  /review-changes
class:    a11y/missing-alt
anchor:   <img src={logo} className="refund-dialog__brand" />
match:    \balt\b|alternative text|image|img
```

An image with no alt attribute. RD-DEC-12 is a decorative image with alt="", which is correct.

```defect
id:       RD-A11Y-03
file:     change/web/src/RefundDialog.tsx
line:     15
severity: high
command:  /review-changes
class:    a11y/missing-label
anchor:   <input value={amount} placeholder="Amount" onChange={(e) => setAmount(e.target.value)} />
match:    label|placeholder|accessible name|aria
```

A form field labelled only by its placeholder (WCAG 1.3.1 / 4.1.2). RD-DEC-13 pairs a label with the input.

```defect
id:       RD-A11Y-04
file:     change/web/src/RefundDialog.tsx
line:     17
severity: medium
command:  /review-changes
class:    a11y/error-not-announced
anchor:   {error && <span style={{ color: 'red' }}>{error}</span>}
match:    announce|alert|aria-live|live region|screen reader|colou?r (only|alone)|red
```

The error is conveyed by colour alone and is not announced (no role=alert / live region). RD-DEC-14 uses role=alert.

```defect
id:       RD-OBS-01
file:     change/src/orders/refunds.ts
line:     29
severity: high
command:  /review-changes
class:    observability/swallowed-error
anchor:   return res.status(500).end();
match:    swallow|log|silent|no trace|lost|catch|observab|error is not
```

The catch returns 500 and drops the error: no log, no rethrow — a failed refund leaves no trace. RD-DEC-06 logs and rethrows.

```defect
id:       RD-OBS-02
file:     change/src/orders/refunds.ts
line:     8
severity: high
command:  /review-changes
class:    observability/pii-in-logs
anchor:   logger.info('refund.requested', { body: req.body });
match:    pii|body|email|personal|sensitive|redact|log.{0,20}request
```

The full request body is logged; the README says bodies carry customer email and address and logs carry ids only. RD-DEC-15 logs ids.

```defect
id:       RD-OBS-03
file:     change/src/orders/refunds.ts
line:     7
severity: medium
command:  /review-changes
class:    observability/missing-metric
anchor:   export async function createRefund(req: Request, res: Response) {
match:    metric|timer|latency|instrument|histogram|observab
```

Every route handler is wrapped in `metrics.timer(...)` (README, list.ts, refund-audit.ts); the new refund endpoint — a money write path — has none.

## Decoys — known-safe look-alikes a correct review does NOT report

```decoy
id:       RD-DEC-01
file:     change/src/orders/refund-audit.ts
line:     15
command:  /review-changes
class:    decoy/rd-dec-01
anchor:   'UPDATE orders SET refunded_cents = refunded_cents + $1 WHERE id = $2 AND refunded_cents + $1 <= total_cents RETURNING id, refunded_cents',
match:    race|concurren|lost update|transaction|lock|atomic|read.modify.write
```

Single-statement conditional increment: atomic, no lost update.

```decoy
id:       RD-DEC-02
file:     change/src/orders/refund-audit.ts
line:     10
command:  /review-changes
class:    decoy/rd-dec-02
anchor:   const cents = Number.parseInt(String(req.body.cents), 10);
match:    float|parseFloat|parseInt|cents|decimal|rounding|precision|money
```

Integer cents, validated on the next line.

```decoy
id:       RD-DEC-03
file:     change/src/orders/list-summary.ts
line:     19
command:  /review-changes
class:    decoy/rd-dec-03
anchor:   const items = ids.length ? await db.query('SELECT order_id, sku, qty FROM order_items WHERE order_id = ANY($1)', [ids]) : [];
match:    n\s*\+\s*1|loop|round.?trip|batch|per order
```

One batched query for all items.

```decoy
id:       RD-DEC-04
file:     change/src/orders/list-summary.ts
line:     6
command:  /review-changes
class:    decoy/rd-dec-04
anchor:   const SUMMARY_FOOTER = readFileSync(new URL('./footer.txt', import.meta.url), 'utf8');
match:    sync|readFileSync|block|event loop
```

Read once at module load, not per request.

```decoy
id:       RD-DEC-05
file:     change/src/orders/refund-audit.ts
line:     20
command:  /review-changes
class:    decoy/rd-dec-05
anchor:   void audit.record('refund.adjusted', { orderId: rows[0].id }).catch((err) => logger.warn('audit.failed', { err: String(err) }));
match:    await|unhandled|floating|fire.and.forget|promise
```

Deliberate fire-and-forget with the rejection caught and logged.

```decoy
id:       RD-DEC-06
file:     change/src/orders/refund-audit.ts
line:     24
command:  /review-changes
class:    decoy/rd-dec-06
anchor:   logger.error('refund.adjust_failed', { orderId: req.params.id, err: String(e) });
match:    swallow|silent|catch
```

Logged and rethrown — not swallowed.

```decoy
id:       RD-DEC-07
file:     change/migrations/2026_10_02b_refund_reasons.sql
line:     2
command:  /review-changes
class:    decoy/rd-dec-07
anchor:   ALTER TABLE orders ADD COLUMN refund_note text;
match:    not null|default|backfill|fail|rewrite
```

Nullable column with no default: metadata-only on PostgreSQL ≥ 11.

```decoy
id:       RD-DEC-08
file:     change/migrations/2026_10_02b_refund_reasons.sql
line:     6
command:  /review-changes
class:    decoy/rd-dec-08
anchor:   refund_id int NOT NULL REFERENCES refunds(id),
match:    foreign key|references|\bfk\b|orphan
```

Carries its foreign key.

```decoy
id:       RD-DEC-09
file:     change/migrations/2026_10_02b_refund_reasons.sql
line:     10
command:  /review-changes
class:    decoy/rd-dec-09
anchor:   CREATE INDEX idx_refund_reasons_refund ON refund_reasons(refund_id);
match:    concurrent|lock|block
```

Index on a table created in this same migration — empty, nothing to block.

```decoy
id:       RD-DEC-10
file:     change/src/orders/export-carrier.ts
line:     11
command:  /review-changes
class:    decoy/rd-dec-10
anchor:   const invoice = await fetchCarrierInvoice(report.manifestId);
match:    parallel|promise\.all|sequential|independent|serial
```

The second call needs the first call's result; the order is required.

```decoy
id:       RD-DEC-11
file:     change/web/src/RefundReason.tsx
line:     24
command:  /review-changes
class:    decoy/rd-dec-11
anchor:   <button type="button" aria-label="Dismiss reason" onClick={onDismiss}>×</button>
match:    button|keyboard|focus|role|aria|label
```

A real button with an accessible name.

```decoy
id:       RD-DEC-12
file:     change/web/src/RefundReason.tsx
line:     25
command:  /review-changes
class:    decoy/rd-dec-12
anchor:   <img src={divider} alt="" />
match:    \balt\b|alternative text|image|img
```

Decorative image, correctly hidden with alt="".

```decoy
id:       RD-DEC-13
file:     change/web/src/RefundReason.tsx
line:     28
command:  /review-changes
class:    decoy/rd-dec-13
anchor:   <input id="refund-reason" value={reason} onChange={(e) => setReason(e.target.value)} />
match:    label|accessible name|aria
```

Labelled by the <label htmlFor> above it.

```decoy
id:       RD-DEC-14
file:     change/web/src/RefundReason.tsx
line:     30
command:  /review-changes
class:    decoy/rd-dec-14
anchor:   {problem && <p role="alert">{problem}</p>}
match:    announce|alert|aria-live|live region|screen reader
```

Announced with role=alert.

```decoy
id:       RD-DEC-15
file:     change/src/orders/refund-audit.ts
line:     21
command:  /review-changes
class:    decoy/rd-dec-15
anchor:   logger.info('refund.adjusted', { orderId: rows[0].id, cents });
match:    pii|body|email|personal|sensitive|redact
```

Logs ids and an amount — no request body.

```decoy
id:       RD-DEC-16
file:     change/web/src/RefundReason.tsx
line:     32
command:  /review-changes
class:    decoy/rd-dec-16
anchor:   <button type="button" disabled={saving} onClick={save}>
match:    double|twice|disabled|pending|duplicate
```

Disabled while saving: no double submit.

```decoy
id:       RD-DEC-17
file:     change/web/src/useRefundHistory.ts
line:     15
command:  /review-changes
class:    decoy/rd-dec-17
anchor:   }, [orderId]);
match:    depend|deps|stale|exhaustive
```

Complete dependency list.

```decoy
id:       RD-DEC-18
file:     change/src/lib/retry.ts
line:     18
command:  /review-changes
class:    decoy/rd-dec-18
anchor:   while ((match = re.exec(header)) !== null) {
match:    assign|===|always (true|truthy)
```

The standard RegExp.exec loop; the assignment is intended and compared.

