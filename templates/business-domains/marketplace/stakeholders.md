# Marketplace — stakeholders

Three primary user groups (buyers, sellers, operators) plus regulators + payment partners. A marketplace v1 succeeds only if all three primary groups get value — building for one and tacking on the others is the most common failure pattern.

## Buyer

The reason supply (sellers) shows up. Without buyers, sellers leave; without sellers, buyers leave. Cold-start is brutal.

**Workflows:**
- Search across N sellers offering similar products.
- Compare price + delivery + seller rating.
- Buy from N sellers in one transaction.
- Track N independent shipments.
- Resolve issues per seller (not "marketplace customer service" generic).

**Pain points the system must solve:**
- "Which seller is legit?" — verified badges, ratings, reviews from real buyers.
- "When will it ALL arrive?" — per-seller ETA, with the worst case shown clearly.
- "Who do I contact about Item 2?" — direct seller messaging, NOT generic platform email.
- "What if Seller A ships but Seller B disappears?" — buyer protection promise + visible.
- "Will I get my money back?" — clear refund + dispute path.

**KPIs:**
- Conversion rate (browse → purchase).
- Items per order (the multi-seller cart unlock).
- Repeat purchase rate.
- NPS / CSAT — and breakdowns per seller (a few bad sellers tank platform reputation).

## Seller

Supply side. Marketplaces compete on seller experience as much as buyer experience — Etsy vs eBay vs Amazon competition is largely seller-tooling competition.

### Casual / individual seller (handmade, vintage, hobby)
- Wants: easy onboarding, low fees, simple dashboard, no learning curve.
- Pain points: KYC documents (don't have a business), tax forms (don't know how to file), shipping logistics (no warehouse).
- Permissions: own listings + orders + payouts + messages.

### Professional small business seller (full-time SMB on the platform)
- Wants: bulk operations, inventory sync with their other channels (Shopify, eBay), better analytics, higher payout frequency.
- Pain points: limited bulk tooling, slow payouts (cash flow), opaque algo (why am I ranking lower?).
- Permissions: own + ability to add sub-users (warehouse staff, customer service).

### Enterprise / brand seller (large brand using marketplace as a channel)
- Wants: API integration, dedicated account manager, custom commission negotiation, brand-protection (counterfeit takedowns), promoted-listings spend.
- Pain points: marketplace's policies override their own (returns, pricing), data ownership ambiguity.
- Permissions: org with multiple users + permissions; integration credentials.

**Universal seller pain points:**
- Payout latency vs cash flow ("I shipped today, when do I get paid?").
- Account suspensions without clear reason — biggest seller complaint across all marketplaces.
- Disputes lost despite evidence — perception of unfair mediation.
- Algorithm changes silently affecting ranking.
- Hidden fees / commission opacity.

**KPIs:**
- Time to first listing.
- Time to first sale.
- Seller churn rate.
- Average payout time.
- Dispute resolution time.
- Seller NPS.

## Operator (the marketplace company itself)

Multiple internal roles, each with own dashboards.

### Founder / CEO
- Wants: GMV trend, take-rate, supply growth, demand growth, contribution margin.
- Logs in to see numbers move; drills only when something's off.

### Trust + safety team
- Wants: dispute queue, fraud alerts, counterfeit reports, restricted-listing alerts, account suspension workflow.
- Heaviest user. UX matters most.
- Permissions: read all sellers/orders, write moderation actions, suspend accounts.

### Compliance officer
- Wants: KYC re-verification queue, sanctions hits, AML alerts, DAC7/1099-K export, T&C acceptance audit.
- Episodic but high stakes.
- Permissions: read all KYC docs (logged access), AML actions.

### Finance / accounting
- Wants: ledger reconciliation, payout reports, commission accruals, tax remittance reports, reserve schedule, chargeback impact.
- Daily user during month-end close.
- Permissions: read all financial data, export.

### Seller success / partnership manager
- Wants: top-seller list, at-risk sellers (declining sales), onboarding-stuck sellers, custom commission deal management.
- Permissions: write seller profile flags, negotiate commission, contact sellers.

### Customer support (buyer-facing)
- Wants: order lookup, dispute opener, refund initiator (within limits).
- Permissions: read orders, escalate disputes, refund up to threshold.

### Seller support
- Wants: seller account lookup, payout investigation, listing appeal handler.
- Permissions: read seller account, override moderation, payout retry.

### Engineering / IT
- Wants: webhook health, integration status, audit logs.
- Permissions: full read with audit; write rare.

### Marketing
- Wants: GMV by category, top buyers, top sellers, campaign attribution, promoted-listing performance.
- Permissions: read analytics; write campaigns.

**Critical operator dashboards:**
- Today's GMV + commission accrued.
- Open dispute count + SLA breaches.
- Failed payouts.
- KYC backlog.
- Listing moderation backlog.
- Reserve balance held.

## Payment provider (Stripe Connect / Adyen MarketPay / Mangopay / etc.)

- Their tooling is your foundation. Lock-in is real.
- Webhooks are your source of truth for charge / payout / dispute / refund.
- They report to regulators on YOUR behalf if their license covers it (consult before assuming).
- Pain points: provider's seller-onboarding UX is THEIR product, not yours — you're constrained.
- Account managers matter at scale; build a relationship.

## KYC provider (Persona / Onfido / SumSub / Veriff)

- Their pass-rate determines your seller funnel.
- Tradeoff: stricter checks = lower fraud + lower conversion.
- Their human review SLA matters at scale (peak: 4-6 hours; budget for it).
- Multi-provider strategy at scale (vendor risk).

## Tax provider (Avalara / TaxJar / Stripe Tax)

- Calculate at checkout (real-time API).
- Remit on schedule (batch).
- Provide registrations + filings as a service (PaaS layer).
- Pain points: edge cases (digital goods, mixed carts) often miscalculate.

## Carriers + shipping (per seller, often)

- Seller-managed (each seller has own carrier accounts) vs platform-provided (operator negotiates rates, sellers buy labels through the platform).
- Platform-provided is a major seller benefit at scale; revenue stream too (shipping markup).

## Brand owners + IP rights holders

- Submit counterfeit takedown requests.
- Want: API for VeRO-style programs, fast SLAs, recidivism tracking.
- Litigious if ignored.

## Regulators

### Tax authorities (IRS, HMRC, EU member states)
- DAC7 / 1099-K reporting recipient.
- Audit triggers: seller mismatches, large refunds, late remittance.

### Financial regulators (FinCEN, FCA, BaFin, etc.)
- Care about MSB / EMI status.
- AML reporting recipient.

### Consumer protection (FTC, CMA, EU Commission)
- DSA compliance (EU).
- P2B compliance.
- Investigations triggered by seller complaints.

### Data protection authorities (CNIL, ICO, etc.)
- GDPR fines.
- Breach notification recipient.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Sellers losing disputes despite evidence | Mediation tooling + clear evidence rubric |
| Sellers waiting on payouts | Faster cycle / instant payout option / transparency |
| Buyers receiving from one seller, missing from another | Per-seller order tracking + buyer protection |
| Compliance officer drowning in KYC re-checks | Automation: re-verify only on triggers, not blanket |
| Finance can't reconcile | Ledger model + double-entry + reports |
| Top sellers leaving to competitors | API + bulk tools + custom commission |
| Brand owners suing for counterfeits | Trust + safety automation + takedown SLA |

## Anti-pattern: "single-sided product"

Building only the buyer side first (it's easier — looks like an ecommerce store) leaves seller experience as an afterthought. Sellers churn → supply shrinks → buyers churn → death spiral. Build the seller dashboard with same care as the storefront, in v1.

## Anti-pattern: "we'll add support later"

Marketplaces generate disputes proportionally to GMV. Without a support tooling investment from day one, support quality collapses at the first sale spike, and sellers/buyers churn citing "no one helped me."
