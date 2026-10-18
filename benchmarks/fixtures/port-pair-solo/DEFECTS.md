# Seeded defects — `port-pair-solo`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans.

Fixture shape: `port-pair` in solo mode — V2 and `ai/` only; V1 is read from the recorded `ai/migration/v1-inventory/` (one stale lane, one old extractor hash); 31 expectations.

Invocation: /compare-v1 --whole-repo --v2=v2 --v1-inventory=ai/migration/v1-inventory --mig=ai/migration
Stage from: port-pair
Stage with: --git --only=v2,ai

Eval source: Track A batch 6, item 29 (`eval-batch6-migration.md` § 3.4 modes, § 4.12 "Two keys"). This key has no
tree of its own: `Stage from: port-pair` copies that fixture's `v2/` and `ai/` (`--only=`), never `v1/`, `change/`,
`clean-overlay/` or either answer key. Every path below is relative to `port-pair/`, and `run.sh --verify` checks the
anchors there.
No `--runs=`: `.refract-fixture/runtime/` is not staged here (`--only=v2,ai`), and its transcripts replay V1, which a
solo run does not have.

**What solo mode may conclude** (eval § 3.4). The V2 side is fully readable; V1 is only the recorded rows. So:
- **Guarantee classes become Findings** from the recorded row plus a full V2 counterpart search: AZ-1 widening, AZ-3 scope
  lost, a unique/FK constraint lost, soft-delete lost, the global trim/empty→null pipe absent.
- **Drop and behaviour classes stay `Unconfirmed-solo`**, with the settling probe "re-run with `--v1=<path>`": whether
  the V1 route, job or effect is live, or whether a V1 middleware did it, needs V1 code.
- **`I-ENUM.tsv` is stale**: its `sha` is not the ledger's `v1_commit_pinned`, so every row from it is
  `Unconfirmed stale-v1-inventory (<sha> vs pin <pin>)` — even the ones a paired run would make Findings.
- **`I-SCHED.tsv` has an old extractor hash**: the lane is `blocked (extractor changed since record; re-record)` and
  emits no candidates; its two seeds are scored on the run printing the lane `blocked`, not on a finding.
- **The verdict is at most `GO-UNVERIFIED`** — solo mode never prints GO.

Each block carries `expect:` (the bucket a correct run puts it in) and, for every bucket but `finding`, a `match:` line
with that bucket's vocabulary, so a run that reports a drop class as a confirmed Finding does not score it. The
second anchor (`v1_file`/`v1_line`/`v1_anchor`) is the recorded inventory row the run must cite — the only V1 it has.

## Summary

| id | V2 file:line | recorded row | expect |
|----|--------------|--------------|--------|
| PX-RT1a | `v2/apps/api/src/orders/orders.controller.ts:45` | `ai/migration/v1-inventory/I-ROUTES.tsv:38` | unconfirmed-solo |
| PX-RT1b | `v2/apps/api/src/invoices/invoices.controller.ts:21` | `ai/migration/v1-inventory/I-ROUTES.tsv:10` | unconfirmed-solo |
| PX-RT2a | `v2/apps/api/src/common/pagination.ts:7` | `ai/migration/v1-inventory/I-ROUTES.tsv:12` | unconfirmed-solo |
| PX-RT2b | `v2/apps/api/src/fastify-options.ts:10` | `ai/migration/v1-inventory/I-ROUTES.tsv:12` | unconfirmed-solo |
| PX-AZ1a | `v2/apps/api/src/wallets/wallets.controller.ts:25` | `ai/migration/v1-inventory/I-AUTHZ.tsv:44` | finding |
| PX-AZ1b | `v2/apps/api/src/users/users.controller.ts:22` | `ai/migration/v1-inventory/I-AUTHZ.tsv:47` | finding |
| PX-AZ2a | `v2/apps/api/src/orders/orders.controller.ts:27` | `ai/migration/v1-inventory/I-AUTHZ.tsv:13` | unconfirmed-solo |
| PX-AZ2b | `v2/apps/api/src/tickets/tickets.controller.ts:40` | `ai/migration/v1-inventory/I-AUTHZ.tsv:33` | unconfirmed-solo |
| PX-AZ3a | `v2/apps/api/src/tickets/ticket.entity.ts:9` | `ai/migration/v1-inventory/I-SCOPE.tsv:11` | finding |
| PX-AZ3b | `v2/apps/api/src/inventory/stock.repository.ts:21` | `ai/migration/v1-inventory/I-SCOPE.tsv:9` | finding |
| PX-DM7a | `v2/apps/api/src/orders/order.entity.ts:7` | `ai/migration/v1-inventory/I-SCOPE.tsv:7` | finding |
| PX-VO1a | `v2/packages/contracts/src/enums.ts:3` | `ai/migration/v1-inventory/I-ENUM.tsv:9` | stale |
| PX-VO1b | `v2/packages/contracts/src/enums.ts:9` | `ai/migration/v1-inventory/I-ENUM.tsv:10` | stale |
| PX-VA1a | `v2/apps/api/src/configure-app.ts:5` | `ai/migration/v1-inventory/I-RULES.tsv:18` | finding |
| PX-VA1b | `v2/packages/contracts/src/orders.ts:17` | `ai/migration/v1-inventory/I-RULES.tsv:37` | unconfirmed-solo |
| PX-STR1a | `v2/apps/api/src/users/accounts.service.ts:11` | `ai/migration/v1-inventory/I-RULES.tsv:20` | unconfirmed-solo |
| PX-ER1a | `v2/apps/api/src/orders/orders.service.ts:34` | `ai/migration/v1-inventory/I-ERR.tsv:4` | unconfirmed-solo |
| PX-ER1b | `v2/apps/api/src/common/zod.ts:14` | `ai/migration/v1-inventory/I-ERR.tsv:8` | unconfirmed-solo |
| PX-SD1a | `v2/packages/contracts/src/common.ts:11` | `ai/migration/v1-inventory/I-CONF.tsv:5` | unconfirmed-solo |
| PX-TZ1a | `v2/apps/api/src/config/app.config.ts:4` | `ai/migration/v1-inventory/I-CONF.tsv:6` | unconfirmed-solo |
| PX-MN2a | `v2/apps/api/src/invoices/invoice-totals.ts:12` | `ai/migration/v1-inventory/I-MONEY.tsv:4` | unconfirmed-solo |
| PX-MN2b | `v2/apps/api/src/wallets/installments.ts:5` | `ai/migration/v1-inventory/I-MONEY.tsv:8` | unconfirmed-solo |
| PX-SE1a | `v2/apps/api/src/orders/order.subscriber.ts:15` | `ai/migration/v1-inventory/I-SIDE.tsv:7` | unconfirmed-solo |
| PX-SE1b | `v2/apps/api/src/wallets/wallet-activity.subscriber.ts:15` | `ai/migration/v1-inventory/I-SIDE.tsv:11` | unconfirmed-solo |
| PX-MN1b | `v2/apps/api/src/orders/pricing.ts:11` | `ai/migration/v1-inventory/I-MONEY.tsv:6` | unconfirmed-solo |
| PX-SE2b | `v2/apps/api/src/invoices/invoices.service.ts:48` | `ai/migration/v1-inventory/I-SIDE.tsv:4` | unconfirmed-solo |
| PX-DM10b | `v2/apps/api/src/migrations/.snapshot-norrow.json:238` | `ai/migration/v1-inventory/I-SCHEMA.tsv:133` | finding |
| PX-JB1a | `v2/apps/api/src/jobs/schedules.ts:13` | `ai/migration/v1-inventory/I-SCHED.tsv:4` | blocked |
| PX-JB1b | `v2/apps/api/src/jobs/schedules.ts:11` | `ai/migration/v1-inventory/I-SCHED.tsv:7` | blocked |
| PX-SOLO-STALE | `ai/migration/v1-inventory/I-ENUM.tsv:1` | — | stale |
| PX-SOLO-HASH | `ai/migration/v1-inventory/I-SCHED.tsv:2` | — | blocked |

Expectations: 7 finding · 18 unconfirmed-solo · 3 stale · 3 blocked. Total 31.

## Expectations

### PX-RT1a — unconfirmed-solo: `POST /api/orders/{order}/duplicate` has no V2 route (the service method was ported, the handler was not)

```defect
id:        PX-RT1a
file:      v2/apps/api/src/orders/orders.controller.ts
line:      45
severity:  high
command:   /compare-v1
class:     surface/route-dropped
mg_class:  MG-RT-1
detector:  surface-parity-scan §1
anchor:    @Post(':id/cancel')
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   38
v1_anchor: handler=OrderController@duplicate
expect:    unconfirmed-solo
match:     duplicat
match:     route|endpoint|handler|404|missing|dropped|not (?:ported|exposed|registered)|absent
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-RT1b — unconfirmed-solo: `GET /api/invoices/{invoice}/pdf` dropped: invoice reads moved to V2 without the PDF download

```defect
id:        PX-RT1b
file:      v2/apps/api/src/invoices/invoices.controller.ts
line:      21
severity:  high
command:   /compare-v1
class:     surface/route-dropped
mg_class:  MG-RT-1
detector:  surface-parity-scan §1
anchor:    @Post(':id/issue')
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   10
v1_anchor: handler=InvoiceController@pdf
expect:    unconfirmed-solo
match:     pdf
match:     route|endpoint|handler|404|missing|dropped|not (?:ported|exposed)|absent
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-RT2a — unconfirmed-solo: Page base drift: `page` is 1-based in V1 (Laravel paginator) but V2 computes `offset = page * perPage`

```defect
id:        PX-RT2a
file:      v2/apps/api/src/common/pagination.ts
line:      7
severity:  high
command:   /compare-v1
class:     surface/path-query-shape
mg_class:  MG-RT-2
detector:  surface-parity-scan §2
anchor:    return page * perPage;
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   12
v1_anchor: handler=OrderController@index
expect:    unconfirmed-solo
match:     page|offset|paginat
match:     1-based|0-based|zero|first page|skip|off.by.one|page \* |base
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-RT2b — unconfirmed-solo: Bracket arrays (`status[]=placed`) are no longer parsed: Fastify's default query parser leaves the key as `status[]` and the status filter is dropped

```defect
id:        PX-RT2b
file:      v2/apps/api/src/fastify-options.ts
line:      10
severity:  high
command:   /compare-v1
class:     surface/path-query-shape
mg_class:  MG-RT-2
detector:  surface-parity-scan §2
anchor:    bodyLimit: 2 * 1024 * 1024,
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   12
v1_anchor: handler=OrderController@index
expect:    unconfirmed-solo
match:     status\[\]|bracket|array|query ?string|querystring|qs
match:     filter|pars|ignored|dropped|strip|every status
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-AZ1a — finding: Wallet adjustment lost its permission: any signed-in user can credit or debit a wallet

```defect
id:        PX-AZ1a
file:      v2/apps/api/src/wallets/wallets.controller.ts
line:      25
severity:  critical
command:   /compare-v1
class:     surface/authz-widened
mg_class:  MG-AZ-1
detector:  surface-parity-scan §3 → security (@api-security-reviewer)
anchor:    @Post(':id/adjust')
v1_file:   ai/migration/v1-inventory/I-AUTHZ.tsv
v1_line:   44
v1_anchor: POST /api/wallets/{}/adjust
expect:    finding
match:     adjust
match:     permission|authori[sz]|guard|wallets?[.:]adjust|any (?:signed|authenticated|logged)|widen
```

### PX-AZ1b — finding: Role assignment moved out of the admin controller without `@Roles('admin')`: a manager can make themselves admin

```defect
id:        PX-AZ1b
file:      v2/apps/api/src/users/users.controller.ts
line:      22
severity:  critical
command:   /compare-v1
class:     surface/authz-widened
mg_class:  MG-AZ-1
detector:  surface-parity-scan §3 → security (@api-security-reviewer)
anchor:    @Put(':id/roles')
v1_file:   ai/migration/v1-inventory/I-AUTHZ.tsv
v1_line:   47
v1_anchor: PUT /api/admin/users/{}/roles
expect:    finding
match:     roles?
match:     admin|privilege|escalat|authori[sz]|guard|widen|any (?:user|role)
```

### PX-AZ2a — unconfirmed-solo: Order export now needs `orders:export`, a permission only managers hold: clerks lose the CSV

```defect
id:        PX-AZ2a
file:      v2/apps/api/src/orders/orders.controller.ts
line:      27
severity:  medium
command:   /compare-v1
class:     surface/authz-narrowed
mg_class:  MG-AZ-2
detector:  surface-parity-scan §4
anchor:    @Permissions('orders:export')
v1_file:   ai/migration/v1-inventory/I-AUTHZ.tsv
v1_line:   13
v1_anchor: GET /api/orders/export
expect:    unconfirmed-solo
match:     export
match:     orders?[.:](?:export|view)|permission|narrow|locked out|403|clerk
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-AZ2b — unconfirmed-solo: Ticket update narrowed from `role:agent|admin` to admins only: support agents cannot update tickets

```defect
id:        PX-AZ2b
file:      v2/apps/api/src/tickets/tickets.controller.ts
line:      40
severity:  medium
command:   /compare-v1
class:     surface/authz-narrowed
mg_class:  MG-AZ-2
detector:  surface-parity-scan §4
anchor:    @Roles('admin')
v1_file:   ai/migration/v1-inventory/I-AUTHZ.tsv
v1_line:   33
v1_anchor: PATCH /api/tickets/{}
expect:    unconfirmed-solo
match:     ticket
match:     agent|narrow|role|403|locked out
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-AZ3a — finding: `Ticket` lost its account scope: ticket lists and lookups cross tenants

```defect
id:        PX-AZ3a
file:      v2/apps/api/src/tickets/ticket.entity.ts
line:      9
severity:  critical
command:   /compare-v1
class:     surface/tenant-scope-lost
mg_class:  MG-AZ-3
detector:  surface-parity-scan §5 → security (@tenant-isolation-reviewer)
anchor:    @Entity({ tableName: 'tickets' })
v1_file:   ai/migration/v1-inventory/I-SCOPE.tsv
v1_line:   11
v1_anchor: app/Models/Ticket.php:
expect:    finding
match:     ticket
match:     account|tenant|scope|filter|cross
```

### PX-AZ3b — finding: Raw `findBySku` query has no account predicate (the ORM filter does not apply to raw SQL): any SKU of any account is readable

```defect
id:        PX-AZ3b
file:      v2/apps/api/src/inventory/stock.repository.ts
line:      21
severity:  critical
command:   /compare-v1
class:     surface/tenant-scope-lost
mg_class:  MG-AZ-3
detector:  surface-parity-scan §5 → security (@tenant-isolation-reviewer)
anchor:    where sku = ? and deleted_at is null limit 1', [sku.trim().toUpperCase()]);
v1_file:   ai/migration/v1-inventory/I-SCOPE.tsv
v1_line:   9
v1_anchor: app/Models/StockItem.php:
expect:    finding
match:     findBySku|sku|stock
match:     account|tenant|scope|raw|predicate|cross
```

### PX-DM7a — finding: `Order` has `deletedAt` but no soft-delete filter: deleted orders (backfilled with `deleted_at`) reappear in lists, counts and exports

```defect
id:        PX-DM7a
file:      v2/apps/api/src/orders/order.entity.ts
line:      7
severity:  high
command:   /compare-v1
class:     cutover-data/soft-delete-lost
mg_class:  DM-7
detector:  data-cutover-orchestrate §7
anchor:    @scoped.AccountScoped()
v1_file:   ai/migration/v1-inventory/I-SCOPE.tsv
v1_line:   7
v1_anchor: app/Models/Order.php:
expect:    finding
match:     soft.?delet|deleted_?at|SoftDeletable
match:     order|list|resurrect|reappear|filter
```

### PX-VO1a — stale: Order status `cancelled` became `canceled` on the wire and in storage

```defect
id:        PX-VO1a
file:      v2/packages/contracts/src/enums.ts
line:      3
severity:  high
command:   /compare-v1
class:     surface/enum-drift
mg_class:  MG-VO-1
detector:  surface-parity-scan §6
anchor:    export const ORDER_STATUSES = ['draft', 'placed', 'packed', 'shipped', 'canceled', 'refunded'] as const;
v1_file:   ai/migration/v1-inventory/I-ENUM.tsv
v1_line:   9
v1_anchor: type:orderstatus
expect:    stale
match:     cancell?ed
match:     enum|status|vocabular|spelling|value
match:     stale|sha|pin|re-?record
```

### PX-VO1b — stale: Ticket priority integers shifted by one: V1 is 1–4, the V2 TypeScript enum is 0–3

```defect
id:        PX-VO1b
file:      v2/packages/contracts/src/enums.ts
line:      9
severity:  high
command:   /compare-v1
class:     surface/enum-drift
mg_class:  MG-VO-1
detector:  surface-parity-scan §6
anchor:    export enum TicketPriority { Low, Normal, High, Urgent }
v1_file:   ai/migration/v1-inventory/I-ENUM.tsv
v1_line:   10
v1_anchor: type:ticketpriority
expect:    stale
match:     priorit
match:     enum|0.based|1.based|off.by.one|integer|shift|value
match:     stale|sha|pin|re-?record
```

### PX-VA1a — finding: No global trim / empty-to-null: V1's `TrimStrings` + `ConvertEmptyStringsToNull` have no V2 counterpart outside the tickets module (one finding, every string field)

```defect
id:        PX-VA1a
file:      v2/apps/api/src/configure-app.ts
line:      5
severity:  high
command:   /compare-v1
class:     surface/validation-drift
mg_class:  MG-VA-1
detector:  surface-parity-scan §7
anchor:    app.setGlobalPrefix('api', { exclude: ['up'] });
v1_file:   ai/migration/v1-inventory/I-RULES.tsv
v1_line:   18
v1_anchor: GLOBAL trim_strings
expect:    finding
match:     trim|empty.?(?:string)?.?to.?null|ConvertEmptyStringsToNull|TrimStrings|normali[sz]
match:     global|middleware|pipe|every|all
```

### PX-VA1b — unconfirmed-solo: `po_number` on create accepts 64 characters of anything; V1 allowed 30 of `[A-Z0-9-]` (the column is varchar(30))

```defect
id:        PX-VA1b
file:      v2/packages/contracts/src/orders.ts
line:      17
severity:  high
command:   /compare-v1
class:     surface/validation-drift
mg_class:  MG-VA-1
detector:  surface-parity-scan §7
anchor:    po_number: z.string().max(64).nullable().optional(),
v1_file:   ai/migration/v1-inventory/I-RULES.tsv
v1_line:   37
v1_anchor: POST /api/orders po_number
expect:    unconfirmed-solo
match:     po_number|po number|purchase order
match:     max|30|64|regex|length|accepts? more|loos|wider
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-STR1a — unconfirmed-solo: Company name limit counts UTF-8 bytes: an Arabic name is refused at 31 letters (V1 `max:60` counts characters)

```defect
id:        PX-STR1a
file:      v2/apps/api/src/users/accounts.service.ts
line:      11
severity:  medium
command:   /compare-v1
class:     semantics/string-semantics
mg_class:  MG-STR-1
detector:  semantics-parity-scan §5
anchor:    if (Buffer.byteLength(value.company_name, 'utf8') > 60) {
v1_file:   ai/migration/v1-inventory/I-RULES.tsv
v1_line:   20
v1_anchor: PATCH /api/account company_name
expect:    unconfirmed-solo
match:     company.?name|byteLength|bytes?
match:     byte|character|utf|arabic|multibyte|length
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-ER1a — unconfirmed-solo: Editing a placed order answers 400 with no `code`; V1 answered 409 `order_not_editable`

```defect
id:        PX-ER1a
file:      v2/apps/api/src/orders/orders.service.ts
line:      34
severity:  high
command:   /compare-v1
class:     surface/error-contract-drift
mg_class:  MG-ER-1
detector:  surface-parity-scan §8
anchor:    throw new DomainError(400, 'Order is not editable');
v1_file:   ai/migration/v1-inventory/I-ERR.tsv
v1_line:   4
v1_anchor: code:order_not_editable
expect:    unconfirmed-solo
match:     editable|409|order_not_editable
match:     400|409|status|code|error
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-ER1b — unconfirmed-solo: Validation errors: V1 reports every failing field, V2 reports only the first

```defect
id:        PX-ER1b
file:      v2/apps/api/src/common/zod.ts
line:      14
severity:  medium
command:   /compare-v1
class:     surface/error-contract-drift
mg_class:  MG-ER-1
detector:  surface-parity-scan §8
anchor:    const issues = result.error.issues.slice(0, 1);
v1_file:   ai/migration/v1-inventory/I-ERR.tsv
v1_line:   8
v1_anchor: envelope=errors-map
expect:    unconfirmed-solo
match:     error|validation|issue
match:     first|only one|slice|all (?:fields|errors)|every
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-SD1a — unconfirmed-solo: Default page size 20 in V2, 25 in V1

```defect
id:        PX-SD1a
file:      v2/packages/contracts/src/common.ts
line:      11
severity:  medium
command:   /compare-v1
class:     surface/silent-default
mg_class:  MG-SD-1
detector:  surface-parity-scan §9
anchor:    per_page: z.coerce.number().default(20)
v1_file:   ai/migration/v1-inventory/I-CONF.tsv
v1_line:   5
v1_anchor: per_page request default
expect:    unconfirmed-solo
match:     per_page|page size|perPage
match:     default|20|25
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-TZ1a — unconfirmed-solo: Business-day zone defaults to UTC in V2 (V1: Asia/Riyadh), and the API deployment does not set `APP_TIMEZONE`

```defect
id:        PX-TZ1a
file:      v2/apps/api/src/config/app.config.ts
line:      4
severity:  high
command:   /compare-v1
class:     semantics/timezone
mg_class:  MG-TZ-1
detector:  semantics-parity-scan §8
anchor:    timezone: process.env.APP_TIMEZONE ?? 'UTC',
v1_file:   ai/migration/v1-inventory/I-CONF.tsv
v1_line:   6
v1_anchor: src=config/app.php + .env.example
expect:    unconfirmed-solo
match:     time ?zone|APP_TIMEZONE|UTC|Riyadh
match:     default|config|day|report|boundar|UTC
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-MN2a — unconfirmed-solo: Invoice tax is rounded once on the subtotal; V1 rounds per line and sums

```defect
id:        PX-MN2a
file:      v2/apps/api/src/invoices/invoice-totals.ts
line:      12
severity:  high
command:   /compare-v1
class:     semantics/rounding-order
mg_class:  MG-MN-2
detector:  semantics-parity-scan §2
anchor:    const tax = roundHalfAway(subtotal * taxRate, 2);
v1_file:   ai/migration/v1-inventory/I-MONEY.tsv
v1_line:   4
v1_anchor: where=InvoiceController::issue
expect:    unconfirmed-solo
match:     tax
match:     per.?line|per.?total|subtotal|order|sum|each line
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-MN2b — unconfirmed-solo: Installments split the total by naive division: 100.00 / 3 = 3 × 33.33 = 99.99 (V1 allocates the remainder cent)

```defect
id:        PX-MN2b
file:      v2/apps/api/src/wallets/installments.ts
line:      5
severity:  high
command:   /compare-v1
class:     semantics/rounding-order
mg_class:  MG-MN-2
detector:  semantics-parity-scan §2
anchor:    return Array.from({ length: count }, () => money.toMoneyString(money.roundHalfAway(total / count, 2)));
v1_file:   ai/migration/v1-inventory/I-MONEY.tsv
v1_line:   8
v1_anchor: where=WalletController::installments
expect:    unconfirmed-solo
match:     installment|allocat|split
match:     remainder|sum|99\.99|cent|allocat|naive|divid
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-SE1a — unconfirmed-solo: "Your order has shipped" e-mail lost: V1 sends it from an observer (`updated`), V2's subscriber ports `created` only

```defect
id:        PX-SE1a
file:      v2/apps/api/src/orders/order.subscriber.ts
line:      15
severity:  high
command:   /compare-v1
class:     effects/side-effect-dropped
mg_class:  MG-SE-1
detector:  side-effect-parity-scan §1
anchor:    return [Order];
v1_file:   ai/migration/v1-inventory/I-SIDE.tsv
v1_line:   7
v1_anchor: order.updated
expect:    unconfirmed-solo
match:     ship
match:     mail|e-?mail|notif|observer|subscriber|afterUpdate|side.?effect
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-SE1b — unconfirmed-solo: Wallet updates are no longer audited: V1's `LogsActivity` trait logged them; V2's subscriber ports create and delete only

```defect
id:        PX-SE1b
file:      v2/apps/api/src/wallets/wallet-activity.subscriber.ts
line:      15
severity:  high
command:   /compare-v1
class:     effects/side-effect-dropped
mg_class:  MG-SE-1
detector:  side-effect-parity-scan §1
anchor:    return [Wallet];
v1_file:   ai/migration/v1-inventory/I-SIDE.tsv
v1_line:   11
v1_anchor: wallet.updated
expect:    unconfirmed-solo
match:     activity|audit|LogsActivity
match:     wallet|balance|adjust
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-MN1b — unconfirmed-solo: Line nets use `toFixed(2)` on a binary float: 1.005 → 1.00 where V1 `round()` gives 1.01

```defect
id:        PX-MN1b
file:      v2/apps/api/src/orders/pricing.ts
line:      11
severity:  high
command:   /compare-v1
class:     semantics/rounding-mode
mg_class:  MG-MN-1
detector:  semantics-parity-scan §1
anchor:    return Number((unitPrice * quantity * (1 - discount)).toFixed(2));
v1_file:   ai/migration/v1-inventory/I-MONEY.tsv
v1_line:   6
v1_anchor: where=PricingService::creditFor
expect:    unconfirmed-solo
match:     toFixed|round
match:     binary|float|1\.005|half|line net|lineNet|pre.?round
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-SE2b — unconfirmed-solo: Invoice-issued job enqueued inside the transaction (V1: `->afterCommit()`): it runs on rollback and can run before the row is visible

```defect
id:        PX-SE2b
file:      v2/apps/api/src/invoices/invoices.service.ts
line:      48
severity:  high
command:   /compare-v1
class:     effects/side-effect-duplicated
mg_class:  MG-SE-2
detector:  side-effect-parity-scan §2
anchor:    await this.queue.add('invoice-issued', { invoiceId: inv.id });
v1_file:   ai/migration/v1-inventory/I-SIDE.tsv
v1_line:   4
v1_anchor: POST /api/invoices/{}/issue
expect:    unconfirmed-solo
match:     invoice.?issued|queue|enqueue
match:     commit|transaction|rollback|before|onCommit
match:     unconfirmed|solo|--v1|re-?run with|cannot (?:confirm|refute)|needs? (?:the )?V1
```

### PX-DM10b — finding: The V2 schema lost `ON DELETE CASCADE` on `ticket_messages.ticket_id` (the entity says cascade; the generated snapshot and migration do not)

```defect
id:        PX-DM10b
file:      v2/apps/api/src/migrations/.snapshot-norrow.json
line:      238
severity:  high
command:   /compare-v1
class:     effects/db-logic-not-reproduced
mg_class:  DM-10
detector:  side-effect-parity-scan §5
anchor:    "deleteRule": "no action"
v1_file:   ai/migration/v1-inventory/I-SCHEMA.tsv
v1_line:   133
v1_anchor: fk:ticket_message(ticket_id)
expect:    finding
match:     cascade|ticket_messages|TicketMessage
match:     delete|foreign key|FK|cascade
```

### PX-JB1a — blocked: `wallets:expire-credits` (daily 00:15) is not scheduled in V2: the service method is ported and nothing calls it

```defect
id:        PX-JB1a
file:      v2/apps/api/src/jobs/schedules.ts
line:      13
severity:  high
command:   /compare-v1
class:     effects/job-not-ported
mg_class:  MG-JB-1
detector:  side-effect-parity-scan §4
anchor:    @Cron('0 0 5 * * *', { name: 'stock-export-feed', timeZone: 'Asia/Riyadh' })
v1_file:   ai/migration/v1-inventory/I-SCHED.tsv
v1_line:   4
v1_anchor: job:credit.expire.wallet
expect:    blocked
match:     expire|promo|credit
match:     cron|schedul|not ported|never (?:runs|called)|missing
match:     blocked|extractor|hash|re-?record
```

### PX-JB1b — blocked: Stale-reservation release (every 5 minutes) is not scheduled: abandoned drafts hold stock forever

```defect
id:        PX-JB1b
file:      v2/apps/api/src/jobs/schedules.ts
line:      11
severity:  high
command:   /compare-v1
class:     effects/job-not-ported
mg_class:  MG-JB-1
detector:  side-effect-parity-scan §4
anchor:    constructor(private readonly stockFeed: StockFeedExport, private readonly wallets: WalletsService, private readonly reservations: StockReservationService) {}
v1_file:   ai/migration/v1-inventory/I-SCHED.tsv
v1_line:   7
v1_anchor: job:release.reservation.stale
expect:    blocked
match:     stale|reservation|release
match:     cron|schedul|not ported|never|missing
match:     blocked|extractor|hash|re-?record
```

### PX-SOLO-STALE — the `I-ENUM` lane was recorded at another V1 commit

```defect
id:        PX-SOLO-STALE
file:      ai/migration/v1-inventory/I-ENUM.tsv
line:      1
severity:  high
command:   /compare-v1
class:     proof/stale-v1-inventory
mg_class:  freshness rule 1
detector:  paired-inventory (freshness)
anchor:    sha=74e3de7b0c6fd8fdcb54d9b77935a6658ddb0950
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   1
v1_anchor: sha=61cb5c927438bcbf4b971b17938abe99c70b70f8
expect:    stale
match:     I-ENUM|enum lane|v1-inventory
match:     stale|sha|pin
```

The header's `sha` differs from the ledger's `v1_commit_pinned`, which every other lane carries (e.g. `I-ROUTES.tsv`
line 1): every `I-ENUM` row is `Unconfirmed stale-v1-inventory`, and the run says
so once for the lane.

### PX-SOLO-HASH — the `I-SCHED` lane was recorded by an older extractor

```defect
id:        PX-SOLO-HASH
file:      ai/migration/v1-inventory/I-SCHED.tsv
line:      2
severity:  high
command:   /compare-v1
class:     proof/extractor-changed
mg_class:  freshness rule 2
detector:  paired-inventory (freshness)
anchor:    extractor=lanes_laravel.py@sha256:984a97c51c2c0cb8
v1_file:   ai/migration/v1-inventory/I-ROUTES.tsv
v1_line:   2
v1_anchor: extractor=lanes_laravel.py@sha256:759ee3ae2adafb91
expect:    blocked
match:     I-SCHED|schedule lane|v1-inventory
match:     blocked|extractor|hash|re-?record
```

The extractor hash differs from the one every other lane was recorded with: the lane is `blocked`, never `checked`.

## Notes

- The recorded lanes are `pair-inventory.py --record-v1` output; every lane but `I-SCHED` carries the extractor hash of
  2026-10-18. Measured: the engine's solo run prints `I-ENUM` stale, `I-SCHED` blocked and the ceiling `GO-UNVERIFIED`.
  If `lanes_laravel.py` changes later, every lane is `blocked` in solo mode — re-record per `port-pair` IR-2.
- Seeds of `port-pair` that live only in `change/`, `v1/` or need no V1 row (data cutover, cutover routing, proof, UI)
  are not re-keyed here: a solo run finds them exactly as a paired run does, and `port-pair` already scores them.
