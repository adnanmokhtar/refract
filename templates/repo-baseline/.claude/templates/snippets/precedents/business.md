# Precedents — Business (money rules, tax and issued documents, ledger and records, reports and business time, lifecycle graph, business cycles)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **business** class: a money rule nobody declared or two paths apply differently (the
rounding mode and point, a unit, an FX rate, a discount order, a price snapshot, a promotion window, a
refund share, a billing period), a tax computation or an issued document that breaks the authority's
rule, a ledger that can commit an imbalance or be edited, records of fact erased or kept too short, a
reported number that is not the business's number, a lifecycle graph with dead or trap states, and a
forward action with no inverse. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Business (V450–V489). The detectors are
`pricing-rule-scan` (MP §1–§3, PR §4–§9, BL §10–§13), `tax-invoice-scan` (TX §1–§6, IV §7–§11),
`ledger-scan` (LG §1–§7, FR §8–§10, DM §11–§12), `report-scan` (RP §1–§7, BT §8–§9),
`lifecycle-scan` (LC §1–§6, `status-graph.py`) and `check-business-coverage` (CY §1–§6) (business
pack). They are run by `/audit-business` and closed by `/business-fix`. The judges are
`@domain-model-auditor` (money, tax, ledger, report rows), `@workflow-integrity` (lifecycle rows) and
`@business-auditor` (cycle rows and the walk); every BLOCKER and HIGH a run keeps goes once more to
`@verifier` mode `refute`.

**Business owns the rule; other packs own the shape.** A neighbour that sees the same `file:line`
lists it as corroboration, deduped by `file:line`; without the owner's pack the row is tagged
`<class> (owner pack <x> not installed)` and listed, never graded as business would grade its own.
The splits:
- float money in code, `parseFloat` / `toFixed` / `Math.round(x*100)` on the arithmetic path, the
  rounding *call*, allocation that does not re-sum, overflow, calendar arithmetic and DST are
  code-quality `correctness-smell-scan` §4 / §6 — §4 reads `pricing-rule-scan` §1's policy row for
  the mode and the point;
- Decimal → JSON float, output rounding, float money in a carrier and time binding on the wire are
  backend `wire-format-scan`; an FSM library swallowing an illegal event or re-opening a terminal state
  is backend `state-transition-scan`, which reads `lifecycle-scan`'s graph; a cron's schedule zone is
  backend `job-lifecycle-scan` §6;
- a float column, a missing CHECK, `ON DELETE CASCADE` into records of fact, PII column mechanics and
  a gapless number from a sequence are database `schema-integrity-scan` §4/§6/§2/§10/§11 (business
  supplies the jurisdiction fact §11 needs); a lost update on a balance or a status is database
  `transaction-scan` §7/§8;
- a price, total or quantity the client chose, step skipping, a late provider event re-opening a
  settled record, Idempotency-Key on money routes, check-then-act on a balance, stock or a single-use
  coupon, per-process limits and a trial checked at the wrong time are security `logic-race-scan`;
- consumer dedupe, outbox and saga compensation are distributed-systems `messaging-scan` §2,
  `dual-write-scan`, `workflow-scan`; divergent copies of one rule are code-quality `duplication-scan`;
- error, empty and loading states of a screen are ui-ux `ui-state-scan`; app-store account deletion is
  mobile `store-compliance-scan` G7; V1 ↔ V2 money parity is migration `semantics-parity-scan`.

"Is the arithmetic, the column, the race or the library call correct" belongs to its owner; "which
rule must it obey, and does the business's own record agree with itself" is business's.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the
flip evidence is shown with a `file:line`, a policy row, a dated authority document, or a recorded
oracle run. Numbers are stable: detectors cite `precedents/business.md § <n>`. § 1–28 follow the
business research catalog's § 4 order; § 29 onwards were settled while building the report,
lifecycle and cycle detectors.

Index: the claim and the gates · money policy and pricing § 1–9, § 24–26 · tax and documents
§ 3, § 7–8, § 15–16 · ledger and records § 10–14, § 17 · reports and business time § 18–20,
§ 34–37 · lifecycle § 21–22, § 27–33 · cycles § 23, § 38–42 · posting rules · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. Every business claim names **the rule** as well as the
code: a candidate with no rule is a policy gap (`UNDECLARED`), printed as an enabler, never graded as
a defect of the code.

> Under **[the policy row — money policy, tax policy, metric definition, the graph, the invariant
> register — with its source, or `UNDECLARED`]**, **[the entry point: checkout, refund, invoice
> run, posting, report query, webhook, deletion flow]** executes **[the code or statement at
> file:line]** and produces **[the amount, document, posting, figure, state or missing inverse]**
> where the rule says **[the expected one]**, for **[the seeded input: a tie, a stacked coupon, a
> month-end anchor, a rate change, a direct-SQL insert, two child rows, a 23:30-local row, a replayed
> event]**, proven by **[V-number, tier]**.

**Two parts, refuted separately.** Part A says *the rule is real*: it is declared (an ADR,
`ai/business-domain.md`, one money module, a dated authority document, a transition table), or the
code itself carries two rules for one amount. Part B says *the code breaks it on a production path*.
A finding whose rule was recalled from memory — a rounding level, a retention period, a chaining
rule, a "standard" business day — is Refuted at Part A until the source is cited with its date.

**The proof rule.** Static two-ended facts (the writer and the reader of a unit; the policy row and
the call; the posting function and the absent constraint; the forward route and the searched-for
inverse) pass gate 6 with both ends cited. Behaviour classes (composition, proration, conservation,
fan-out, day buckets, event replay, cross-aggregate state) need the oracle red. Without either the
row is **Unconfirmed** with the oracle written out.

## Reading the seven gates for business

| Gate | Business |
|---|---|
| 1 Reachability | a checkout, refund, renewal, invoice run, posting, report, webhook, deletion flow or purge job reaches the code in production; seeds, one-off backfills that already ran and dead exports fail here |
| 2 Trigger | the input occurs: a tie at the minor unit, two coupons, a day-31 anchor, a rate change date, a second delivery, a tenant off UTC, a one-to-many child, a refund after a discount |
| 3 Version | the money library, the billing SDK, the tax engine, the FSM library, the ORM's decimal mapping, from the lockfile (Ruby `money` 7.0 flipped its default rounding on 2026-07-31); `UNREAD` without a lockfile |
| 4 Existing control | **the declared rule and its single owner first**: one money module, a tax engine with address and tax code, a deferred balance trigger, a unique source key, a transition table, a provider that owns proration or refund bounds, the authority's validator in CI |
| 5 Impact | money created or lost, a customer charged or refunded wrongly, a document an authority rejects, books that disagree with the dashboard, an entity stuck in a state, a legal obligation (erasure, retention, unsubscribe) unmet. Hygiene with none of these is Hardening (§ 43) |
| 6 Proof | the two-ended static fact, or the V-oracle red on the real path (tie corpus, golden invoice, direct-SQL probe, replay, golden report, graph diff, route-pair diff) |
| 7 Environment | the jurisdictions and currencies the product actually serves, the provider in the lockfile, the tenants' zones, the deployment that runs the purge |

## Money policy and pricing

1. **Decimal read as a string is correct.** node-postgres, MikroORM's `decimal` default, TypeORM, Sequelize and Laravel's `decimal:` cast return `numeric` as a string; only a conversion on the arithmetic path is a candidate, and that is code-quality §4's. *Flips back:* a conversion (`parseFloat`, `Number`, `setTypeParser(1700, parseFloat)`, MikroORM `DecimalType('number')`, Drizzle `mode: 'number'`) sits on a path that computes a charged, refunded or booked amount.
2. **A declared mode other than half-even is a policy.** Half-up or half away from zero, applied by one money module everywhere, is not MP-1 (a real NestJS + React monorepo declares `roundHalfAwayFromZero` once and imports it from POS "so the system has one rounding rule"). *Flips back:* a second service, the PDF renderer or a report rounds the same amount with another mode, or an upgrade in the lockfile changed a library default under an unstated call.
3. **Per-line tax rounding is legal where the national rule allows it.** The VAT Directive prescribes no method (*Ahold*, C-484/06, 2008); Peppol rounds line parts separately; Stripe offers the choice for manual rates only and sums-then-rounds under automatic tax. *Flips back:* the emitted document's totals fail the authority's sum rules (EN 16931 BR-CO-10…17), or two paths round one document at different levels.
4. **`toFixed` / `Intl.NumberFormat` in the view is display.** After exact arithmetic, formatting for a human (Intl uses the currency's ISO minor digits and `halfExpand`) is not a money finding. *Flips back:* the formatted string is parsed back into an amount, stored, or sent to a provider.
5. **An authority's payload format is the carrier's format.** Integer minor units converted to decimal major units with the authority's precision (a real e-receipt payload uses JSON numbers with 5 decimals) is not float money. *Flips back:* the converted value is read back and used in arithmetic, or the precision differs from the authority's spec.
6. **A documented single-currency product.** With a currency constant at the boundary and the policy written, amounts without a currency column are not MP-2 / PR-4 / RP-4 / LG-5. *Flips back:* a second currency is accepted anywhere (a settings field, a provider account, a price list), or a 0- or 3-decimal currency is listed.
7. **A hard-coded VAT rate in a single-jurisdiction business** with an effective-dated config and the rate persisted on each line is not TX-1. *Flips back:* the rate is read at render time, or the product sells into a second jurisdiction.
8. **Tax delegated to a tax engine** (Stripe Tax, Avalara, TaxJar, Vertex) with the address and the tax code on the call is not TX-2 / TX-5. *Flips back:* the call omits the address or the tax code, or a second path computes tax in-house.
9. **Proration and anchors delegated to the billing platform.** Stripe `proration_behavior`, Chargebee and Paddle own the formula; `billing_cycle_anchor_config.day_of_month` and date-fns / `java.time` / Luxon clamping are not BL-2. *Flips back:* the app recomputes the platform's figure, adds months from the previous period's end instead of the anchor, or turns proration off on upgrades without a written policy.

## Ledger and records

10. **A deferred balance trigger is Traced.** A ledger balance enforced by a deferred constraint trigger that sums every touched entry at COMMIT (seen on a real monorepo's GL), or by TigerBeetle / Formance / pgledger, satisfies LG-1 for every writer. *Flips back:* the trigger does not group by currency, a second line table bypasses it, or it is `DEFERRABLE` but not `INITIALLY DEFERRED` and a writer never sets it.
11. **Non-financial ledger columns are mutable.** UPDATE of `memo`, `reconciled_at`, `exported_at` or `metadata` is not LG-2; `pending` transactions are mutable until posted (Modern Treasury's model). *Flips back:* the UPDATE touches amount, account, currency, direction or the posting date of a posted entry.
12. **A unique source key closes LG-3.** A unique `(source_type, source_id, leg)`, or a provider idempotency key derived deterministically from the business id, makes posting idempotent at the ledger. Stripe prunes idempotency keys after at least 24 h — a key reused later is a new request. *Flips back:* the key is generated at retry time, or the uniqueness lives in code only.
13. **A balance cache in the posting transaction plus a drift sweep** is not LG-4 ("the ledger is the truth"). *Flips back:* another service writes the cache, the write is outside the posting transaction, or no sweep compares the cache with the fold of entries.
14. **Accounts meant to go negative** — clearing, liquidity, equity, provider receivable — are not an overdraft or DM-1 finding. *Flips back:* a customer, merchant or courier wallet goes negative with no credit-limit policy.
15. **Drafts are mutable; issued documents are not.** Drafts and unissued invoices may be edited and deleted under a status guard; a void before transmission may be allowed by the authority — cite it. *Flips back:* the guard is missing on one writer (admin panel, bulk update, raw SQL), or the document was already transmitted.
16. **Gaps in internal ids are fine.** The legal number is a separate per-series counter; whether it must be gapless is national (database `schema-integrity-scan` §11 owns the shape; `tax-invoice-scan` supplies the jurisdiction). *Flips back:* the internal id *is* printed as the legal invoice number in a jurisdiction that requires consecutive numbering.
17. **Retention after erasure, done right.** Keeping invoices after an erasure request under GDPR Art. 17(3)(b), with PII pseudonymised in mutable tables and the invoice snapshot intact, is correct for FR-1 / FR-3. *Flips back:* the deletion flow hard-deletes issued records, or the anonymiser blanks legally required buyer fields on an issued invoice.

## Reports and business time

18. **Pre-aggregation is not fan-out.** A child CTE aggregated per parent before the join, `distinct on`, or a join on a primary key (one row per summed key) is not RP-1 (a real monorepo's cross-sell facts pre-aggregate per order). *Flips back:* the summed column belongs to the parent and the join multiplies it.
19. **Two names, two metrics.** Gross vs net revenue are two metrics, not RP-2; a metric that intentionally reads the current state is not RP-7 when its label says so ("orders currently in shipping"). *Flips back:* one label, two definitions; or a historical figure labelled "confirmed in March" changes when a row's status changes in April.
20. **A UTC business day, documented, for a single-zone business** (no tenant zone field) is not BT-1. Three zone policies for one "day" are. *Flips back:* any tenant, store or user carries a zone field, or the product sells across zones.

## Lifecycle

21. **A write inside the machine is not a bypass.** A status write inside the FSM library's own transition (an AASM event block, a django-fsm `@transition`, a statesman adapter, a spatie `Transition::handle`), an admin repair command with an audit row, or a migration is not a §2 bypass. *Flips back:* the library's direct-write protection (AASM `no_direct_assignment`, django-fsm-2 `protected=True`) is off and a service writes the column.
22. **An explicit ignore list is a mapping.** Provider event types listed as ignored are not LC-5; re-fetching the provider object before deciding is the recommended shape. *Flips back:* a subscribed type is neither handled nor listed, or the handler maps a late event onto a settled state.

## Cycles

23. **Some actions need no inverse.** Irrevocable actions (signed contracts, sent payouts, filed tax documents) need no inverse; a legal hold blocks deletion on purpose; an asynchronous deletion request with a stated SLA is an inverse. *Flips back:* the action is reversible by policy and the inverse exists only as a support ticket.

## Money policy and pricing (continued)

24. **The provider-recommended landing shape.** A landing page that calls the same idempotent `fulfil(sessionId)` after a server-side retrieve is not a client-trusted success. *Flips back:* fulfilment reads the amount or the status from the redirect's query string.
25. **Accepted but recomputed.** Fields accepted in a body but recomputed server-side and never reaching the charge are not client-trusted prices — follow the data flow (and the class is security's either way). *Flips back:* the body value reaches the charge, the refund or the stored total.
26. **The provider bounds refunds on its own path only.** Stripe enforces Σ refunds ≤ charge for its refunds; internal store-credit and wallet refund paths still need the bound (PR-6 / LG-7). *Flips back:* —; the internal path is the finding when it has no bound.

## Lifecycle (continued)

27. **"Refund without return" as a written policy** is not LC-4. *Flips back:* no policy names it, and a report counts the order as both returned and kept.
28. **A date-only value stored as a date** (`DATE`, `LocalDate`, `PlainDate`, Prisma `@db.Date`) is not a time-binding issue (PR-5 / BT-1 read it as a day, which it is). *Flips back:* it is compared with an instant without choosing the business zone's end of day.
29. **A declared reversal edge is not a re-open.** A terminal state left by an edge in a code-declared reversal table, or by a library event the graph names, with the reversal recorded (an audit or history row), is not LC-2 / LC-5 re-open (a real monorepo keeps a forward table and a separate reversal table for its order statuses). *Flips back:* the reversal is reachable by a role the policy does not name, or no record of it is written.
30. **Legacy states kept for history.** States written only by a migration, an import or a seed, documented as legacy and locked (an empty entry in the transition table), are not LC-1. *Flips back:* a live reader branches on the state as if new rows could enter it, or a writer outside migrations still sets it.
31. **Low-stakes toggles need no history.** `draft ↔ published`, read/unread, a UI preference: LC-6 is a NIT at most. *Flips back:* the entity is money-, order-, access- or compliance-bearing (order, payment, subscription, invoice, role, consent).
32. **An implied machine is a gap, not yet a defect.** A status column with no declared state set (`status-graph.py` prints `implied`) is the finding only when two writers spell one state differently, or a reader branches on a value no writer sets; otherwise it is Hardening with "declare the set" as the fix. *Flips back:* the spelling split or the dead branch, cited at both ends.
33. **A shared literal is not attribution.** `'pending'` declared by dozens of machines makes a write with no enum, receiver or entity hint `ambiguous`; it is evidence for none of them until the write is read. *Flips back:* the read names the entity.

## Reports and business time (continued)

34. **A count that is a count.** `count(*)` over a join whose grain is the counted entity (one row per order line when the metric is "lines") is not RP-1. *Flips back:* the label names the parent ("orders") and the join is to-many.
35. **An operational figure needs no books reconciliation.** A dashboard number labelled operational or estimated, never shown as revenue to finance, customers or investors and never exported as books, is not RP-6. *Flips back:* the figure is labelled revenue, payout or balance, or feeds an invoice, a payout or an export.
36. **A UTC axis that says so.** An internal operations chart bucketed in UTC with the zone printed on the axis is a declared policy (extends § 20). *Flips back:* the same bucket feeds a tenant-facing report, a cutoff, a daily limit or a payout day.
37. **A maintained calendar is a calendar.** Business days computed by a maintained holiday-calendar library, a provider's settlement calendar, or a calendar table the business edits, are not BT-2. *Flips back:* weekend days are hard-coded for a region whose weekend differs (Friday–Saturday), or the holiday list is a literal array with no owner.

## Cycles (continued)

38. **The ESP adds the unsubscribe headers.** Marketing mail sent through a provider that injects `List-Unsubscribe` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click` itself (read the provider's dated docs or a captured raw message) is not CY-4; transactional mail needs no unsubscribe. *Flips back:* the provider feature is off, or the message is marketing sent as transactional.
39. **A provider-hosted inverse is an inverse when linked.** Cancelling through the billing provider's customer portal or the app store's subscription management is an inverse when the app links to it. *Flips back:* no screen links there, and the only path is a support ticket.
40. **The inverse belongs to the forward's role.** An admin-only forward action with an admin-only inverse is complete; CY-2 asks for a UI entry point for the role that has the forward action. *Flips back:* the end user can do the forward action in the UI and the inverse exists only in the API or the admin panel.
41. **A command is not a resource.** A POST that runs a command (confirm, recalculate, export, extract, callback) is not a creation and needs no delete; archive, soft-delete and close are inverses of create. *Flips back:* the POST creates a durable, user-visible thing the user would expect to remove.
42. **Mobile store deletion is mobile's.** In-app account deletion for apps is mobile `store-compliance-scan` G7; CY-5 asks only for the web path and the data export. *Flips back:* —; without the mobile pack the app row is tagged `store deletion (owner pack mobile not installed)`.

## Posting rules (business)

43. Hygiene with no money, document, books, state or obligation impact is **Hardening**: an `UNDECLARED` policy row alone (it is an enabler), an implied machine with consistent writers, an unaudited low-stakes toggle, a dashboard rounding difference that never reaches a document. NITs are capped at 5 per report, each with its site.
44. Every MP, PR, BL, TX and IV row carries the policy row (or `UNDECLARED`) and its source; every LG, FR and DM row carries the table and its constraints as read; every RP and BT row carries the metric definition (or its absence) and the zone policy; every LC row carries the machine and its source; every CY row carries the forward site and the searched-for inverse ("none after the written search").
45. One root cause at N sites is one finding with N sites: one money module with the wrong mode, one tax function taxing the gross, one posting function with no sum check, one report helper bucketing in the session zone, one status setter with no guard.
46. **Business decisions are not code fixes.** A rounding mode or point, a discount order, a tax rate or tax point, a business zone, a metric definition shown to customers, a retention period, an erasure policy, an overdraft limit: the finding names the decision and stops; `/business-fix` asks before writing it.

## Rationalizations to reject (business)

**Wrongly accepting "correct":**
- "We use Decimal everywhere." Which mode, at which point, and does the PDF worker agree (§ 2)?
- "The ledger is append-only by convention." Show the trigger or the grant (§ 10, § 11).
- "Tax is right, the totals match on screen." Run the authority's validator on the emitted document (§ 3).
- "The dashboard matches what the CEO expects." Reconcile it with the books on a golden day (§ 35).
- "Every status write goes through the service." Show the graph: the writes are where they are (§ 21, § 32).
- "Users can cancel by emailing support." That is not an inverse for a self-serve forward action (§ 23, § 39).

**Wrongly flagging a defect:**
- "This rounds half-up, not banker's." Is half-up the declared policy (§ 2)?
- "This number comes back as a string." That is the driver doing the right thing (§ 1).
- "This invoice can be edited." Is it a draft (§ 15)?
- "This SUM has a JOIN." Read the grain (§ 18, § 34).
- "This state has outgoing edges after `cancelled`." Is it a declared reversal (§ 29)?
- "There is no DELETE for this POST." Is it a command, not a resource (§ 41)?

---

Sources: the business research catalog (2026-10-19) § 4 for entries 1–28, and its notes on money
libraries and ORMs, tax and e-invoicing, retention, ledgers, payment state machines, pricing and
business time; the batch-7 business eval (2026-10-19) for the ownership splits. The real-repo
observations behind § 2, § 5, § 10, § 13, § 18 and § 29 were measured read-only on one NestJS +
React monorepo on 2026-10-19. Authority facts (EN 16931 sum rules, GDPR Art. 17(3)(b), the VAT
Directive) are cited as the research read them; a run that rests a verdict on one cites the
authority's own document with its date. Paraphrased; no text is reproduced beyond identifiers.
