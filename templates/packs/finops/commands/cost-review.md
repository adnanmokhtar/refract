---
description: Review a change for cost regressions before it merges — always-on resources, per-row paid calls, retry and fan-out bounds, cross-zone movement, retention and log-volume defaults, scan cost, and allocation tags. Diff-scoped; adds the missing cost lens to code review.
kind: command
pack: finops
---

# /cost-review [<scope>] [--since <ref>]

Run the cost lens over a change, the way a security review runs the vulnerability lens. Defaults to the current diff. Produces a per-mechanism verdict with a magnitude on every finding, or an explicit `UNKNOWN` where the volume metric is unreachable.

## When to use / NOT to use

- USE: on any diff touching infrastructure definitions, a hot path, a batch job, retention or logging configuration, or a paid third-party or model API; before merging a change whose cost nobody has considered; as a standing step in review for services with a declared unit-economics model.
- NOT: on a design that has not been written as code — that is `@cost-architect`.
- NOT: to sweep existing infrastructure for waste — that is `/cost-audit` in the infrastructure pack.
- NOT: to explain a spike that already happened — that is `spend-anomaly-triage`.

## Phases applied

1-3 + 6 (review shape — no Generate, no Update; the output is findings).

## The Premise (read this first, internalize, do not deviate)

**A finding needs a mechanism and a magnitude.** The mechanism is what gets billed and why the diff changes it; the magnitude is the per-unit delta and the monthly delta at current volume. A cost finding without a magnitude produces reflexive micro-optimisation and trains people to ignore cost review.

**Where volume is unknown, say so.** `UNKNOWN — needs <metric>` is the correct output. Inventing a plausible volume to produce a plausible dollar figure is the single worst thing this command can do, because the number will be quoted.

**Cost is a trade, not a goal.** A change that triples spend to remove an outage is correct. The failure being prevented is an *unpriced* decision, not an expensive one. Every BLOCKER states what the change buys, or acknowledges that it buys nothing.

**Existing spend patterns are context.** Read `ai/finops/unit-economics.md` first: a change to a branch that is 40% of the unit cost deserves scrutiny that a change to a 0.5% branch does not. Review effort follows the money.

**A review that priced nothing is not an approval.** This command has two failure directions and the hand-wave grep guards only one. The grep stops an *invented* number. It does not stop the opposite: a diff that introduces billed mechanisms, a reviewer with no reachable volume metric and no billing access, every finding correctly marked `UNKNOWN` — and a green `APPROVE` on the verdict line. That output is "spend looks reasonable" with no number read, arriving through the front door rather than through fabrication, and it is the most common way a cost review becomes decorative. The fourth verdict below exists so that outcome has an honest name instead of a green one.

## Mechanical halt — hand-wave grep

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds the cost-review tokens.

Before emitting findings, scan for: `expensive`, `costly`, `a lot of requests`, `could add up`, `significant spend`, `probably fine`, `negligible` — each used without a number. Any match = HALT. Replace with a per-unit and monthly delta plus the volume metric it came from, or with `UNKNOWN — needs <metric>`, or drop the finding. `negligible` in particular must be earned: state the figure that makes it negligible.

## Phase 1 — Understand

Confirm:
- **Scope** — the diff range, or the paths.
- **Pricing model** — on-demand, committed, or flat-rate capacity. Under flat-rate, marginal money findings are fiction; the real finding is contention against a fixed pool. Say which lens is being applied.
- **Environment** — production, or a shared non-production environment with a different profile and owner.
- **Volume context** — which usage metrics are reachable for this service, named individually. This is not scene-setting: it decides whether the run can reach a priced verdict at all, and it is reported on the output's `Priced` line. "No usage metric reachable and no billing export" is a legitimate answer, and it pre-determines the verdict as `UNPRICED`.

## Phase 2 — Organize

Walk the diff once per mechanism class, in the order they cost money:

1. Always-on resources introduced (provisioned instances, node pools, managed endpoints, replicas, per-hour-billed services, unexpiring preview stacks).
2. Per-row and per-request amplification (remote calls in loops, N+1 against billed dependencies, uncapped retries, polling added or tightened).
3. Data movement (new cross-zone or cross-region hops, payload growth, cache or CDN bypass).
4. Storage and retention (new stores without a lifecycle policy, log level raised, new high-cardinality metric labels, backups without expiry).
5. Scan and query cost (predicates that cannot prune, unbounded dashboard ranges, incremental-to-full-refresh changes).
6. Unbounded results (missing limits, page sizes raised, fan-out multiplied by user input).
7. Allocation tags (resources created without the keys the allocation policy requires).

### Where each mechanism's magnitude comes from

`UNKNOWN — needs <metric>` is the correct last resort and a poor first move. Each mechanism has a
canonical volume metric, and most of them are **not** in the billing export — they are counts the
application already emits, or constants readable from the diff itself. Look here before declaring the
magnitude unreachable, and name in the `Volume source` column which of the three tiers you used:

| Mechanism class | The volume that sizes it | Usually reachable from |
|---|---|---|
| always-on resource | hours per month (730) × the shape's rate | **the diff** — the count and size are in the definition being added; the only unknown is price |
| per-row / per-request amplification | rows per run × runs per period, or requests per period | **the app** — the job's own run log or row-count metric; the endpoint's request counter |
| retry / fan-out | worst-case multiplier × the base call volume | **the diff** — the retry cap and fan-out factor are literals in the change; the multiplier is exact even when the base is not |
| data movement | bytes per call × calls per period | **the app** — payload size is measurable from a sample response; call volume from the request counter |
| retention / storage growth | bytes per record × records per period × retention window | **the app** — the write rate is a counter; the record size is a schema calculation |
| log / metric ingestion | lines (or series) per request × request volume × bytes per line | **the diff** for lines-per-request and cardinality; **the app** for request volume |
| scan / query cost | bytes scanned per execution × executions per period | **the platform** — query history exposes both; `warehouse-scan-audit` (data-engineering pack) owns this measurement |
| result-set bounds | page size × pages fetched, or the unbounded worst case | **the diff** — the removed limit *is* the finding; size it at the largest current collection |

Three tiers, in order of preference, and the `Volume source` column states which was used:
1. **measured** — a metric read in this run, with its window. Preferred always.
2. **derived from the diff** — an exact multiplier (a retry cap, a fan-out factor, hours per month, a
   loop over a collection whose size is bounded in code) applied to a measured or stated base. This is
   a legitimate magnitude, not a guess, and it is available with **no billing access whatsoever**.
   A retry cap raised from 3 to 10 is a 3.3× multiplier on that dependency's billed calls, and that is
   reportable even when nobody can say what the base rate is.
3. **UNKNOWN — needs `<metric>`** — the base volume is genuinely unreachable and no exact multiplier
   applies. Name the metric.

The distinction between tier 2 and tier 3 is where most of this command's value sits. A review that
reports "retry cap 3 → 10, a 3.3× multiplier on billed calls to `<dependency>`, base rate UNKNOWN —
needs the client's request counter" has told the author something actionable. "UNKNOWN" alone has not,
and the multiplier was sitting in the diff.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/finops/unit-economics.md` — the declared expectation this change is measured against, and which branches matter.
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`.
- `.claude/rules/finops-principles.md`.
- The usage metrics for the affected paths, so magnitudes come from observed volume rather than assumption.
- Current unit prices with their as-of date for every billed dimension the diff touches.

## Phase 6 — Validate

- Dispatch **`@cost-reviewer`** for the verdict.
- Where the diff touches data transfer, dispatch **`egress-trace`** to establish the actual path rather than the assumed one — cross-zone hops are frequently invisible in application-level reasoning.
- Where the diff changes a branch with a declared expectation, compute the projected new cost per unit and compare against the threshold in `ai/finops/unit-economics.md`. A change that breaches the declared expectation is a BLOCKER regardless of its absolute size.
- Where the change was predicted by a prior `/cost-model` or `@cost-architect` run, note the prediction — a confirmed prediction is how the model earns trust.

### Findings ledger — REQUIRED OUTPUT ARTIFACT

```
Sev      | file:line              | Mechanism                  | Per-unit Δ | Monthly Δ @volume | Volume source        | Buys
BLOCKER  | jobs/enrich.py:88      | paid call moved per-row    | +1 call/row| UNKNOWN — needs    | tier 3               | nothing
                                                                              rows/run metric
BLOCKER  | clients/vendor.py:31   | retry cap 3 → 10           | ×3.3 calls | ×3.3 on this line | tier 2, derived from | nothing
                                                                                                  the diff (base UNKNOWN)
REQUEST  | infra/net/peering.tf:24| new cross-zone hop         | +<bytes>   | $<n>              | tier 1, transfer     | AZ redundancy
                                                                                                  metric, 30d
```

Every row carries either a monthly delta with its volume source, or `UNKNOWN — needs <metric>`. A row with neither is not a finding.

A row is **priced** when its `Monthly Δ @volume` is a figure or an exact multiplier *and* its `Volume source` names the tier and, at tier 1, the metric and window it came from. Tier 2 counts as priced; tier 3 does not. Count the priced rows: that count is what separates a review from a reading, and it decides the verdict.

## Output format

```
## /cost-review — <scope>

Pricing model: <on-demand | committed | flat-rate capacity>
Declared expectation (from ai/finops/unit-economics.md): <$/unit> ± <threshold>

Coverage:
| Mechanism                           | Verdict           |
|-------------------------------------|-------------------|
| Always-on resource introduced       | pass / fail / n-a |
| Per-row / per-request amplification | pass / fail / n-a |
| Retry + fan-out bounds              | pass / fail / n-a |
| Data movement (AZ / region / net)   | pass / fail / n-a |
| Retention + lifecycle set           | pass / fail / n-a |
| Log / metric ingestion volume       | pass / fail / n-a |
| Scan / query cost                   | pass / fail / n-a |
| Result-set bounds                   | pass / fail / n-a |
| Cost-allocation tags                | pass / fail / n-a |

Per-row verdict: `pass` (mechanism checked, diff clean) · `fail` (mechanism fired, a finding exists)
· `n-a` (the diff cannot touch this mechanism) · `unpriced` (mechanism fired and no volume metric was
reachable to size it). `unpriced` is never collapsed into `pass`.

Findings ledger: <the table above, verbatim>

Net monthly delta (sourced rows only): <$>
UNKNOWN-magnitude rows: <N>   (each naming the metric that would settle it)
Projected cost/unit after this change: <$>  vs declared <$> ± <threshold> → <within | BREACH>

Priced: <n> of <n> fired mechanisms carry a magnitude from a named volume source
        unreachable: <the metrics, or the billing-export access, that would settle the rest>

Hand-wave grep: ✓ | halts=<N>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK | UNPRICED
```

### The four verdicts — and when `UNPRICED` is the only honest one

- **APPROVE** — mechanisms checked; nothing fired, or what fired is priced and within the declared expectation.
- **REQUEST_CHANGES** / **BLOCK** — as the findings ledger dictates.
- **UNPRICED — `<n>` mechanisms fired, 0 priced; needs `<named metrics / billing access>`** — at least
  one mechanism fired and **no** row carries a magnitude from a named volume source. It is neither a
  soft `APPROVE` nor a `BLOCK`: the diff may well be fine, and this run cannot say so. What it does say
  is exactly which input would make the review possible, and that is the actionable half.

`UNPRICED` is this pack's verdict for the state every other artifact halts on — no billing access, no
reachable usage metric, a service nobody instrumented (`@finops-analyst` refuses without a row-level
export, `unit-cost-probe` without a denominator, `egress-trace` without flow logs). `/cost-review`
deliberately still runs there, because the *mechanism* half of a finding is derivable from the diff
alone and is worth reporting. What it must not do is launder a mechanism-only reading into an approval.
The verdict line says which half of the job was done.

## Hard rules

- **Every finding has a mechanism and a magnitude, or an explicit `UNKNOWN — needs <metric>`.**
- **Never invent a volume** to produce a dollar figure. An exact multiplier read out of the diff is not an invented volume — it is tier 2, and it is stated as a multiplier rather than as dollars.
- **Never write `UNKNOWN` before checking the mechanism's tier-1 and tier-2 sources.** Most magnitudes in a diff-time review need no billing access at all.
- **Never sum UNKNOWN rows into the net delta.** They are listed separately and counted.
- **Never `APPROVE` a diff in which a mechanism fired and nothing was priced.** That verdict is
  `UNPRICED`. An approval asserts the cost was considered; with zero priced rows, nothing was.
- **Never mark a fired mechanism `pass` because its magnitude was unreachable.** That row is
  `unpriced`, and it is the reason the run's verdict is.
- **A breach of the declared expectation is a BLOCKER** even when the absolute number is small — the expectation exists so that drift is caught early.
- **Every BLOCKER states what the change buys**, including "nothing".
- **Under flat-rate capacity, report contention, not dollars.**

## Failure modes

- Cost findings without magnitudes, so reviewers learn to skip the section.
- Reaching for `UNKNOWN` because the billing export is unreachable, when the mechanism's multiplier was a literal in the diff. This is the most common way a correct refusal to guess turns into a review that says nothing.
- A plausible dollar figure derived from an invented request rate, quoted later in a planning document.
- Missing a cross-zone hop because the code does not mention zones — only the network topology does.
- Reviewing the application diff and not the infrastructure diff in the same change.
- Blocking a change that buys real reliability, because only the cost column was read.
- Reviewing every diff at the same depth instead of following the unit-economics tree to where the money is.
- An `APPROVE` on a run where every magnitude came back `UNKNOWN` — the reviewer correctly avoided
  inventing a number, then let the verdict line imply one anyway. This is what the `UNPRICED` state
  exists for, and it is harder to spot than a fabricated figure because nothing in the body is wrong.

## Related

- `@cost-reviewer` — the agent this command dispatches.
- `@cost-architect` — the design-time counterpart.
- `@finops-analyst` — confirms after the fact whether the predicted delta appeared.
- `egress-trace`, `unit-cost-probe` — the executors.
- `/cost-model` — supplies the declared expectation this review measures against.
- `/cost-guardrails` — the automated pre-merge gate this review complements.
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`.
