---
description: Recommend the business metrics/KPIs a project's dashboard SHOULD show for its domain — detect the domain, inventory the metrics already displayed, diff against the domain's decision-metric set, and recommend the missing high-value ones (grouped, prioritized, each with the decision it drives + the formula + the data source it comes from). Answers "I want to add stats but don't know which." Recommends; does not build the tiles.
kind: command
pack: business
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /suggest-metrics [<scope>]

## The Premise (read this first, internalize, do not deviate)

**A dashboard tends to show what's easy to compute, not what drives a decision — that is metric-theater.** "Total page views" is cheap and changes nothing; "cart-abandonment rate trending up week-over-week" tells the operator to go fix checkout. The job of this command is NOT "add more numbers" — it is to **cover the decision surface**: for each recurring decision the product's personas actually make, is there a metric that informs it?

**Every recommended metric MUST clear three gates or it is not recommended:**
1. **Decision-linked** — name the concrete decision/action a persona takes because of it ("restock product X", "fix the checkout step where 40% drop", "re-engage the customers who bought once"). A metric that informs no decision is **vanity** — flagged, not recommended (unless the user asks for it explicitly).
2. **Computable** — it must be derivable from data the system ALREADY has (name the tables/events/endpoints), OR the recommendation names the **exact missing instrumentation** required (an event to emit, a column to add). No hand-waved "just track engagement".
3. **Non-duplicate** — it is not already shown on the surface (diff against the inventory in Phase 2), and where a **rate** is the real signal it does not merely restate a **count** already shown (a shown "abandoned carts: 27" still lacks the *rate*).

**Ownership boundary:** this command **recommends WHICH metrics + HOW to compute each** and hands off. It does NOT build the dashboard tile (that's `/add-feature` / the frontend pack), write the aggregation query (that's the backend pack), or wire the event (that's observability). It is the analyst's recommendation, cited and prioritized, ready to build.

## When to use / NOT to use

**Use when:** "what stats should my dashboard show?", "I want to add metrics but don't know which", "is our analytics missing anything a store like ours should track?", a pre-launch analytics-coverage pass, or after a domain shift adds new decisions.

**NOT for:**
- Building a metric tile / chart → `/add-feature` (frontend) after this recommends it.
- Writing the aggregation query → backend pack.
- Auditing a single flow's drop-off + instrumentation → `audit-funnel-completion` skill (this command is broader — the whole dashboard's KPI coverage, not one funnel).
- Auditing whether a *feature* is complete (forward/inverse/recovery) → `/audit-business`.

## Phase 1 — Understand (detect the domain + the personas)

- **Domain** — detect the business domain (ecommerce / marketplace / saas-b2b / lms / booking / fintech / …) from `ai/business-domain.md`, entity names, and the installed `business-domains/<domain>/` knowledge. If ambiguous, ASK once — the metric set is domain-specific.
- **Personas + their decisions** — read `ai/users-and-personas.md`. The store owner, the ops manager, the marketer each make different recurring decisions; the recommended set must cover *their* decisions, not a generic list.
- `<scope>` (optional) — narrow to a surface/audience (`the owner dashboard`, `the marketing view`). Default: the primary analytics surface.

## Phase 2 — Retrieve (inventory what is ALREADY shown)

Do NOT recommend blind. First build the **current-metrics inventory** — every stat the surface already displays, and its shape (raw count vs rate vs trend):
- Grep the dashboard/analytics components + the endpoints/queries that feed them (`grep` for the metric labels, the stat cards, the `/stats` / `/analytics` / `/dashboard` API, the aggregation functions).
- Record each as `metric | shape (count / rate / money / trend) | source`. This inventory is the diff baseline — a recommendation that duplicates a shown metric is a bug.
- Note **counts that should be rates**: a shown count whose *rate* is the decision signal (abandoned-carts count → abandonment **rate**; repeat-customer count → repeat-purchase **rate**).

## Phase 3 — Retrieve (the domain decision-metric set)

Load the domain's standard decision-metric set, organized by the **six coverage categories** (this frame is domain-agnostic; the specific metrics per category come from the domain knowledge + best practice):

| Category | The decision it serves | Examples (illustrative — ecommerce storefront) |
|---|---|---|
| **Acquisition** | where to spend to get traffic | sessions by channel/source, new-visitor share, cost per acquisition (if ad data), revenue by channel |
| **Conversion** | where the funnel leaks | conversion rate, **checkout funnel drop-off** (view→cart→checkout→paid), **cart-abandonment RATE**, revenue per visitor (RPV) |
| **Revenue** | is money healthy | total sales, AOV, **gross/profit margin**, discount/coupon impact, refund-adjusted net revenue |
| **Retention / loyalty** | is the base growing or churning | **repeat-purchase rate**, **new vs returning** split, **customer lifetime value (CLV)**, days-between-orders, cohort retention |
| **Operational health** | what is breaking / at risk | **refund/return rate**, fulfillment/delivery time, failed-payment rate, out-of-stock incidents, support/complaint rate |
| **Product / inventory** | what to restock / promote / cut | best & worst sellers, inventory turnover, low-stock alerts, margin by product, best-margin vs best-selling gap |

Cite the domain's `business-domains/<domain>/feature-checklist.md` § Reports as the FLOOR and expand it — that file is usually thin; this command's job is to complete the coverage, not stop at three metrics.

## Phase 4 — Generate (diff → prioritize → recommend)

1. **Diff** the domain set (Phase 3) against the inventory (Phase 2). For each category, mark: `covered` / `count-only (needs rate)` / `MISSING`.
2. **Prioritize** each gap by **decision-leverage × computability**:
   - *Leverage*: does knowing it change what a persona does this week? (high / med / low)
   - *Computability*: `have-data` (name the source) / `needs-instrumentation` (name the exact event/column).
   - High-leverage + have-data = recommend first. High-leverage + needs-instrumentation = recommend + name the one thing to add. Low-leverage = flag as optional/vanity, do not pad the list.
3. **Emit the recommendation** grouped by category. **Closure verbs** (each recommendation is exactly one):
   - `recommend-metric` — a missing metric worth adding (with formula + source + the decision).
   - `upgrade-count-to-rate` — a shown count whose rate is the real signal (abandoned count → abandonment rate).
   - `pair-metric` — a shown metric that is misleading alone and needs a companion (conversion rate needs traffic-source split; AOV needs margin).
   - `flag-vanity` — a metric the user might expect that informs no decision; named so they know it was considered and why it's skipped.
   - `name-missing-instrumentation` — a high-value metric blocked on one missing event/column; recommend the metric AND the exact instrumentation to unblock it.

## Phase 5 — Update

- Write the recommendation to `ai/analytics/metric-recommendations.md` (append-dated). If the same gap recurs across surfaces, note it once.
- If a recommended metric is blocked on missing instrumentation, log the instrumentation ask so the observability/backend follow-up is traceable.

## Phase 6 — Validate

- Every recommended metric has: a named decision, a formula, and a data source (`have-data <where>` or `needs-instrumentation <what>`). A recommendation missing any of the three is dropped (it would be metric-theater).
- No recommendation duplicates a Phase-2 inventory metric.
- Counts-that-should-be-rates are surfaced as `upgrade-count-to-rate`, not re-recommended as new.

## Phase 7 — Improve

- If ≥3 recommendations across runs are blocked on the same missing instrumentation, promote "instrument <event>" as a foundational analytics gap (it unblocks a whole category).
- If the surface is already full-coverage, say so — "analytics coverage is complete for <domain>; nothing high-leverage missing" — never invent low-value metrics to fill a quota.

## Output format

```
/suggest-metrics — <domain> · <surface>
Coverage: <C>/6 categories covered · <N> gaps · <V> vanity flagged

Already shown (inventory): <list, shape>

Recommended (by leverage):
  [Conversion]  cart-abandonment RATE        upgrade-count-to-rate  HIGH  have-data
      decision: fix checkout when the rate climbs
      formula:  abandoned_carts / carts_created  · source: carts table (status)
  [Retention]   customer lifetime value (CLV) recommend-metric       HIGH  have-data
      decision: how much to spend acquiring a customer
      formula:  avg(order_total) × repeat_rate × avg_lifespan · source: orders
  [Acquisition] revenue by channel            recommend-metric       HIGH  needs-instrumentation
      decision: where to spend marketing · blocked on: capture referrer/utm on session
  ...

Vanity flagged (skipped, with why): <metric — informs no decision>

Not validated: <domain confidence | missing persona file | none>
```

## What to do next — required closing section

Per `~/.claude/templates/snippets/actionable-next-steps.md`: each recommended metric gets one paste-ready follow-up — comment (WHAT + WHY) + the build command, sorted by leverage:
- **have-data** metric → `/add-feature "<metric> tile on the dashboard"` (frontend builds the tile; backend the query).
- **needs-instrumentation** metric → first `/add-telemetry`/backend to emit the event/column, THEN the tile.
Never leave a recommendation as prose without its build command.

## Failure modes

- **Domain unknown / unset** → ASK once; do not guess a metric set (an ecommerce set on a SaaS product is noise).
- **Personas file missing** → recommend the domain-standard set, flag `Not validated: personas — decisions inferred, not confirmed`.
- **Everything already covered** → say so; do not pad with vanity metrics.
- **A high-value metric is uncomputable** → recommend it WITH the exact missing instrumentation; never silently drop it or hand-wave the data.
- **User wants a specific vanity metric** → build it, but label it vanity in the output so the decision is eyes-open.

## Related

### Sibling commands in business pack
- `/audit-business` — audits a *feature's* completeness (forward/inverse/recovery); this command audits the *dashboard's* metric coverage.
- `/analyze-task` — turns a rough ask into a spec; use after this to build a recommended metric.

### Skills
- `audit-funnel-completion` — one flow's drop-off + instrumentation; this command is the whole-dashboard complement.
- `check-business-coverage` — cross-feature forward/inverse/recovery audit.

### Rules
- `.claude/rules/business-completeness.md` — "a feature is done when forward + inverse + recovery + **metrics** all wired"; this command is the metrics arm of that rule.

### Hands off to
- `/add-feature` (build the tile) · backend pack (the aggregation query) · `/add-telemetry` (emit a missing event for a `needs-instrumentation` metric).
