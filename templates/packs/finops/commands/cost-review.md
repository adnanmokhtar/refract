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

## Mechanical halt — hand-wave grep

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds the cost-review tokens.

Before emitting findings, scan for: `expensive`, `costly`, `a lot of requests`, `could add up`, `significant spend`, `probably fine`, `negligible` — each used without a number. Any match = HALT. Replace with a per-unit and monthly delta plus the volume metric it came from, or with `UNKNOWN — needs <metric>`, or drop the finding. `negligible` in particular must be earned: state the figure that makes it negligible.

## Phase 1 — Understand

Confirm:
- **Scope** — the diff range, or the paths.
- **Pricing model** — on-demand, committed, or flat-rate capacity. Under flat-rate, marginal money findings are fiction; the real finding is contention against a fixed pool. Say which lens is being applied.
- **Environment** — production, or a shared non-production environment with a different profile and owner.
- **Volume context** — which usage metrics are reachable for this service. Determines which findings can carry a magnitude.

## Phase 2 — Organize

Walk the diff once per mechanism class, in the order they cost money:

1. Always-on resources introduced (provisioned instances, node pools, managed endpoints, replicas, per-hour-billed services, unexpiring preview stacks).
2. Per-row and per-request amplification (remote calls in loops, N+1 against billed dependencies, uncapped retries, polling added or tightened).
3. Data movement (new cross-zone or cross-region hops, payload growth, cache or CDN bypass).
4. Storage and retention (new stores without a lifecycle policy, log level raised, new high-cardinality metric labels, backups without expiry).
5. Scan and query cost (predicates that cannot prune, unbounded dashboard ranges, incremental-to-full-refresh changes).
6. Unbounded results (missing limits, page sizes raised, fan-out multiplied by user input).
7. Allocation tags (resources created without the keys the allocation policy requires).

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
BLOCKER  | jobs/enrich.py:88      | paid call moved per-row    | +1 call/row| UNKNOWN — needs    | —                    | nothing
                                                                              rows/run metric
REQUEST  | infra/net/peering.tf:24| new cross-zone hop         | +<bytes>   | $<n>              | transfer metric, 30d | AZ redundancy
```

Every row carries either a monthly delta with its volume source, or `UNKNOWN — needs <metric>`. A row with neither is not a finding.

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

Findings ledger: <the table above, verbatim>

Net monthly delta (sourced rows only): <$>
UNKNOWN-magnitude rows: <N>   (each naming the metric that would settle it)
Projected cost/unit after this change: <$>  vs declared <$> ± <threshold> → <within | BREACH>

Hand-wave grep: ✓ | halts=<N>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK
```

## Hard rules

- **Every finding has a mechanism and a magnitude, or an explicit `UNKNOWN — needs <metric>`.**
- **Never invent a volume** to produce a dollar figure.
- **Never sum UNKNOWN rows into the net delta.** They are listed separately and counted.
- **A breach of the declared expectation is a BLOCKER** even when the absolute number is small — the expectation exists so that drift is caught early.
- **Every BLOCKER states what the change buys**, including "nothing".
- **Under flat-rate capacity, report contention, not dollars.**

## Failure modes

- Cost findings without magnitudes, so reviewers learn to skip the section.
- A plausible dollar figure derived from an invented request rate, quoted later in a planning document.
- Missing a cross-zone hop because the code does not mention zones — only the network topology does.
- Reviewing the application diff and not the infrastructure diff in the same change.
- Blocking a change that buys real reliability, because only the cost column was read.
- Reviewing every diff at the same depth instead of following the unit-economics tree to where the money is.

## Related

- `@cost-reviewer` — the agent this command dispatches.
- `@cost-architect` — the design-time counterpart.
- `@finops-analyst` — confirms after the fact whether the predicted delta appeared.
- `egress-trace`, `unit-cost-probe` — the executors.
- `/cost-model` — supplies the declared expectation this review measures against.
- `/cost-guardrails` — the automated pre-merge gate this review complements.
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`.
