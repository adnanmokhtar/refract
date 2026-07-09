---
track: business
purpose: Translate business ideas into actionable specs, audit shipped features for completeness (forward + inverse + recovery), and surface conversion drop-off.
essentials:
  agents: [business-analyst, business-auditor, workflow-integrity, domain-model-auditor]
  commands: [analyze-task, expand-task, audit-business]
  skills: [audit-funnel-completion, check-business-coverage]
  rules: [business-completeness]
  ai-patterns: [missing-counterparts]
---

# Business — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category:
- **agents**: `business-analyst` writes specs from rough ideas; `business-auditor` walks shipped features for completeness gaps; `workflow-integrity` reconstructs an entity's lifecycle state graph and proves every transition is legal + guarded (the state-graph complement to `business-auditor`'s cycle audit); `domain-model-auditor` reconstructs the aggregates + their invariant-enforcement register and proves each invariant is enforced by a real layer, not left NOWHERE (the structural complement — three orthogonal auditors: experience, state-graph, aggregate-structure). `pricing-tax-audit` (skill) is signal-gated on billing surfaces and kept out of minimal.
- **commands**: `/analyze-task`, `/expand-task` (turning ideas into specs); `/audit-business` (run business-auditor agent).
- **skills**: `audit-funnel-completion` (single-flow drop-off audit), `check-business-coverage` (cross-feature forward/inverse/recovery audit).
- **rules**: `business-completeness` (the foundational rule: a feature is "done" when forward + inverse + recovery + metrics all wired).
- **ai-patterns**: `missing-counterparts` (the canonical forward/inverse table — every Create needs Delete, every Send needs Resend).

## What this pack is for

- Auditing whether a feature is *complete* in the business sense (not just code-complete).
- Translating fuzzy product asks into structured specs.
- Finding the half-cycles that ship under deadline pressure (signup-without-delete, subscribe-without-cancel).
- Funnel drop-off triage.

## What this pack is NOT for

- Code review — use `code-quality` pack.
- UX flow + content review — use `ui-ux` pack (overlapping concern; UX is one dimension; business completeness is broader).
- Architecture — use `code-quality/legacy-modernizer` for strategic, the relevant stack pack for tactical.

## How this pack relates to others

- **`ui-ux`** — overlapping concern. `ui-ux/agents/ux-reviewer` reviews flow + content; this pack reviews business cycle completeness. Both run on a feature; findings rarely overlap.
- **`code-quality`** — code-level completeness; this pack is business-level.
- **Stack packs** (backend, frontend, mobile) — produce the feature; this pack audits it.
