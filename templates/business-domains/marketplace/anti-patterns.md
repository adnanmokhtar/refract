# Marketplace — domain-specific anti-patterns

Generic code review misses these. Marketplaces compound errors across three sides (buyer, seller, operator) — a small bug becomes a multi-million-dollar reconciliation problem.

## Order splitting

- **Single charge, single order, no split.** Treating a multi-seller cart as one big order with a `seller_ids[]` field. Per-seller fulfillment, cancellation, refund, dispute, payout cannot work cleanly. Always split into Suborders at placement.
- **Splitting at fulfillment time, not at placement.** Lazy split = race conditions when refunding before split happens. Split synchronously inside the place-order transaction.
- **Buyer charged once, but operator stores N pending charges.** Provider tells you the truth — one PaymentIntent = one charge. Don't fake-split the payment; split the SUBORDERS, share the single charge ID.
- **Per-seller shipping calculated AFTER the buyer pays.** Buyer expects $X total at checkout; you discover Seller B's shipping is wrong and back-bill — chargeback. Calculate per-seller shipping at cart, freeze at checkout.
- **Per-seller cancellation cancels the whole order.** Buyer wants to cancel one seller's items only. UI + API must support partial cancellation by suborder.

## Commission + money

- **Commission as a calculated field, not a stored row.** Recomputed every time = drift when rates change. Store the commission amount + the rule version snapshot per suborder, immutable.
- **Floats for commission math.** `0.1 * 19.99 != 1.999`. Integer minor units ALWAYS, or `Decimal`. Test rounding (banker's vs HALF_UP) explicitly; pick one for the whole platform.
- **Commission rounding inconsistency between buyer-side display and seller-side ledger.** Buyer's receipt says $2.00, seller's payout says $2.0001 (truncation). Reconciliation breaks. Single rounding function, called everywhere.
- **Negative seller balance silently allowed.** Refund processed but seller already paid out → balance goes -$50; next sale's payout pays the next $50 to operator (correct), but the seller is unaware they're in debt. Negative-balance handling needs explicit flow + seller notification.
- **No idempotency on payout cron.** Cron retries OR multiple instances → seller paid twice. Idempotency key per (seller_id, payout_period) at the DB layer, not just in app.
- **Payouts initiated for sellers without active KYC.** AML violation. Block at payout-creation time, not at provider-call time.
- **FX rate applied at payout, not at suborder.** Seller's "earnings dashboard" shows numbers that move daily (because FX moves). Lock FX at order placement; payout-time FX is a separate display.

## Wallet / ledger

- **Single-entry ledger.** Just a `seller_balance` column updated on each event. Cannot answer "what was this balance on date X?", cannot reconcile. Use double-entry: every event creates 2+ ledger entries (debit + credit).
- **Wallet balance recomputed by summing transactions on read.** Slow + race-prone. Maintain a materialized balance updated transactionally with each ledger entry, AND have a reconciliation job that verifies balance == sum(entries).
- **No "pending" / "available" / "on-hold" distinction.** Sellers think "balance" = payable now, mismatched with reality. Three explicit columns.
- **Hold release as a cron without idempotency.** Cron runs twice → balance moved twice from pending to available → over-pay. Track release events in ledger; idempotent on event_id.

## Disputes + refunds

- **Refund cascades not handling commission.** Refund $30 to buyer; operator's revenue should drop by its share, not by the full $30. Refund needs to write inverse ledger entries: buyer → -$30, seller pending → -seller_share, operator revenue → -operator_share.
- **Refund issued via provider dashboard, not via system.** Marketplace ledger doesn't know; reports lie; seller balance wrong. All refunds MUST go through your endpoint, which calls provider.
- **Hold released before dispute window expires.** Buyer disputes day 8; payout already sent day 7; clawback impossible. Hold = max(carrier_delivered + N days, dispute_window).
- **Dispute auto-decides "in favor of buyer" without seller notification window.** Operator avoids tickets in short term, sellers churn in long term (fairness perception). Always give seller SLA window with reminders.
- **No clawback flow when chargeback hits after payout.** Operator eats the loss silently. Need debt-recovery process: seller balance can go negative; future earnings garnish until recovered; legal if balance stuck.

## KYC + onboarding

- **KYC verified once at signup, never re-verified.** Documents expire; sanctions lists update; seller's circumstances change. Re-verify on schedule + on triggers (country change, threshold crossing, AML alert).
- **KYC status as a boolean.** `kyc_verified: true/false` doesn't capture "approved", "expired", "requires_more_info", "rejected_appeal_pending". Use enum + state machine.
- **Listing creation allowed before payout method verified.** Seller lists, sells, can't be paid → support nightmare. Block at listing-create gate, not at payout-attempt.
- **Onboarding without saved drafts.** Seller fills 80%, gets called away, returns to blank form. Save every step.
- **KYC rejection reasons shown as provider error codes.** Seller sees "ERR_DOC_QUALITY_LOW" — has no idea what to do. Translate to actionable language.
- **Sanctions screening only at onboarding.** Daily delta scan against updated lists is mandatory.

## Listings + moderation

- **Trusted-seller fast-track without expiration.** Once trusted, forever fast-track — sellers exploit by going dormant then dropping a counterfeit listing. Trust must be re-evaluated periodically.
- **Moderation queue with no SLA.** Listings sit for days; sellers churn citing "platform doesn't care." SLA + alerting on breach.
- **Approval rules as keyword regex only.** "Vape pen" easily becomes "vp pn" or "v_pen" — circumvention trivial. Add image classification + cross-listing similarity + behavioral signals.
- **Edits to active listings auto-publish without re-moderation.** Bait-and-switch: approved as cookbook, edited to fake Rolex. Edits to price > X% or to category/title trigger re-moderation.
- **Same product allowed under multiple sellers without canonical reference.** Buy Box / federated listing logic relies on canonical product IDs; without it, search shows duplicates and buyers can't compare.

## Multi-seller cart UX

- **Cart "merged" into one block at checkout.** Buyer thinks one shipment; surprised by 3 packages, 3 ETAs, 3 carriers. Show grouped clearly throughout.
- **Coupon scoping ambiguous.** Coupon applies to platform-wide order? To one seller? Half each? Document + display per coupon's scope at apply time.
- **Free shipping threshold across sellers.** "$50 free shipping" — does $30 from Seller A + $25 from Seller B qualify? Define and disclose; usually NO (per-seller threshold) but buyers expect cross-seller.
- **Inventory check on one seller's stock at cart-add but not at checkout.** Seller B sells out between add and pay; partial-fail handling absent.

## Payouts

- **Payout amount stored in cents but provider expects dollars.** Off by 100x — paid $5 instead of $500 OR $5000 instead of $50. Always integration test against provider sandbox with non-trivial amounts.
- **Payout to wrong currency.** Seller's bank is EUR; you payout USD; bank rejects + return fee + lost time. FX OR currency match must be explicit.
- **Provider returns "succeeded" then later fails.** Async finality; don't update seller balance from "available" to "paid" until provider's final webhook (e.g. `payout.paid` not `payout.created`).
- **Failed payout silently retried forever.** Sellers don't know they're not getting paid; ops don't know either. After 2 retries, alert + halt + manual intervention required.

## Disputes

- **Dispute opened but seller hold not applied.** Operator pays seller before dispute resolved → cannot claw back if dispute loses. Hold immediately on dispute open.
- **Buyer messaging in dispute leaks PII to seller (or vice versa).** Phone numbers, addresses → off-platform circumvention. Filter messaging both ways.
- **Resolution outcome not auditable.** Mediator decided "in favor of buyer" — no record of why, no rubric followed. Each decision logs reason + evidence reviewed + decider.

## Off-platform circumvention

- **Messaging system passes through phone + email + URL freely.** Sellers + buyers connect off-platform; commission lost; future violations untraceable. Aggressive PII filtering with appeal path for legitimate cases.
- **Order-acknowledgement emails leak seller's contact.** Default email templates expose seller email/phone — buyers go around. Use platform-relayed addresses.
- **No detection on repeat off-platform attempts.** Suspend offenders.

## Reserves + risk

- **No reserve policy for high-risk sellers.** Big chargebacks → seller balance < reserve = operator eats it. Risk-based reserves with disclosed policy.
- **Reserve "hidden" from sellers in dashboard.** Sellers think they have $10k available; really $7k available + $3k reserved. Show clearly + explain.
- **Reserve auto-released on schedule even when chargeback rate spikes.** Adaptive reserves: extend release date if seller's risk score rises.

## Tax

- **Marketplace facilitator state coverage incomplete.** Operator collects in 5 states, ignores 40 → state AG action + back-tax + penalties. Use Avalara/TaxJar/Stripe Tax with all states enabled day one.
- **Tax computed in seller's TZ, not buyer's.** Wrong rate. Tax is destination-based for VAT and most US sales tax.
- **Tax on shipping inconsistent.** Some states tax shipping, some don't. Tax service handles; DIY = error-prone.
- **DAC7 / 1099-K reporting deferred.** Year-end scramble; missing data; fines. Build the data model from day one even if you defer the report.

## Reputation + reviews

- **One review per order, regardless of seller count.** Buyer can only rate one seller in a 3-seller order. Per-suborder reviews.
- **Disputed-order reviews still count toward seller score.** Sellers gamed: bad service → buyer complains → review sticks even after refund. Disputed reviews held until resolution.
- **Review weight not time-decayed.** A 3-year-old 1-star tanks new sellers forever. Weight recent reviews higher.
- **Fake reviews detection absent.** New seller spawns 50 5-star reviews in week 1 from related accounts. Velocity + clustering detection.

## Operational

- **Reconciliation job absent.** No job verifies `sum(suborders) - sum(refunds) - sum(payouts) = sum(wallet balances)`. Daily mismatch goes undetected for months → six-figure crater.
- **Webhook handler blocks on long ops.** Provider retries → duplicate payouts. Webhook acks fast; queues work async; idempotent worker.
- **Test-mode orders mixed with prod reports.** Marketing reports inflated; investors misled.
- **No archival of suborder data.** Suborders, ledger, dispute evidence accrete to TBs; queries slow; lost evidence past dispute window.
- **Cron-based payouts on every node in cluster.** Each node tries to pay → race → multi-pay. Leader-elected scheduler.

## Trust + UX

- **Operator branding dominates seller storefront.** Sellers feel like commodities; top brands won't list. Seller branding visible (within platform consistency).
- **Buyer protection promise vague.** "We'll help if something goes wrong" — vs Amazon's A-to-Z. Specificity drives trust.
- **Seller suspension without right of appeal.** Top sellers churn citing arbitrariness; legal risk under EU P2B. Always provide appeal channel + SLA.
- **No seller community / forum.** Sellers forced to use Reddit / FB groups → operator loses signal on issues + sellers organize against operator.
