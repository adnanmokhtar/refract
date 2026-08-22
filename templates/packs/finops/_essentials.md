---
track: finops
purpose: Cost as a reviewed engineering dimension — unit economics, spend attribution, commitment posture, preventive guardrails, and a cost lens on every change.
essentials:
  agents: [cost-reviewer]
  commands: [cost-review, cost-model]
  skills: [unit-cost-probe]
  rules: [finops-principles]
  ai-patterns: [unit-economics]
---

# FinOps — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `cost-reviewer` is the one that pays for itself on day one — it adds the missing lens to reviews that already happen, catching regressions at the only moment they are cheap to change; `cost-architect` presumes a design being written, and `finops-analyst` presumes row-level billing export access, so both are signal-gated and kept out of minimal.
- commands: `/cost-review` (the diff-time lens) plus `/cost-model` (the declared expectation everything else is measured against, and without which `cost-reviewer` has no baseline). `/audit-cost-attribution` and `/cost-guardrails` both presume an allocation policy and provider-side controls that a minimal install cannot assume.
- skills: `unit-cost-probe` is the only skill that works with nothing but a billing export and one metric; `commitment-coverage` needs a commitment inventory, `egress-trace` needs flow telemetry, and `spend-anomaly-triage` needs daily granularity plus a change log — each states its own halt condition when those are absent, so shipping them into a project that lacks the inputs would be shipping a halt.
- rules: `finops-principles` is the single rules file in the pack.
- ai-patterns: `unit-economics` carries the three-label discipline (measured / ALLOCATED / NOT DERIVABLE) that every other artifact in the pack depends on; `spend-allocation`, `commitment-strategy`, and `cost-anomaly-detection` are gated on there being multiple owners, a commitment programme, and a detector platform respectively.

## What this pack is for

- Knowing what one unit of the business costs to serve, and which branch of the cost that is.
- Knowing whose spend it is, by dollar rather than by resource count.
- Catching cost regressions in review instead of on an invoice.
- Making the next surprise impossible rather than explicable.

## What this pack is NOT for

- Sweeping existing resources for idle and over-provisioning — that is `/cost-audit` in the `infrastructure` pack, which this pack deliberately does not duplicate.
- Latency and throughput optimisation — that is the `performance` pack. The two frequently find the same defect for different reasons; each names the lens that produced the finding.
- Prompt, model-choice, and token-level spend discipline — the `ai-engineering` pack owns it as AI-3 / `llm-gateway`, and the per-call token-and-cost accounting artifacts (`ai-cost-discipline`, `ai-cost-tracking`) ship from the `ai` **domain overlay**, not from that pack. This pack treats a model call as one more billed dependency; `@cost-reviewer` reports it as unowned when neither is installed.
- Procurement and vendor negotiation. The pack computes the break-even; it does not run the deal.

## How this pack relates to others

- **`infrastructure`** — the closest neighbour. `/cost-audit` sweeps what exists; `@cost-architect` works before the resource exists; `@cost-reviewer` works at the diff. Run `/cost-audit` for waste and this pack for discipline.
- **`observability`** — cost alerts reuse its routing and runbook conventions. A second paging path fragments on-call.
- **`performance`** — `@capacity-planner` owns headroom; the crossover between "add capacity" and "it costs too much" is the shared boundary.
- **`data-engineering`** — `warehouse-scan-audit` owns the SQL producing warehouse spend and hands the money total to `/cost-model`.
- **`business`** — supplies revenue per unit, without which contribution margin cannot be computed and a cost number cannot be judged.
