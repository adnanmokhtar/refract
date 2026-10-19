---
track: business
purpose: Translate business ideas into actionable specs, audit the business rules the code must obey (money, tax, ledger, reports, lifecycles, cycles), and close what the audit finds.
essentials:
  agents: [business-analyst, business-auditor, workflow-integrity, domain-model-auditor]
  commands: [analyze-task, expand-task, audit-business, business-fix, suggest-metrics, suggest-features]
  skills: [check-business-coverage]
  rules: [business-completeness]
  ai-patterns: [missing-counterparts]
---

# Business — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category:
- **agents**: `business-analyst` writes specs from rough ideas. The three judges refute and grade the detectors' rows: `@domain-model-auditor` (money, tax, ledger, report rows and the invariant-enforcement register), `@workflow-integrity` (the lifecycle graph, the transition matrix, `$-conserve`), `@business-auditor` (the cycle register, and the walk with `--live`).
- **commands**: `/analyze-task`, `/expand-task` (ideas into specs); `/audit-business` (the whole-repo business audit over six detectors with a class ledger and a verdict, or one feature's three axes); `/business-fix` (closes the audit's findings failing-first and stops on business decisions); `/suggest-metrics` (the decision-driving KPIs a dashboard should show; `--funnel=<flow>` for one funnel's drop-off); `/suggest-features` (capability recommendations against the domain checklist).
- **skills**: `check-business-coverage` (forward / inverse / resend / unsubscribe / erasure / dead-end pairs from the route inventory) is minimal — every product has cycles. The five rule detectors — `pricing-rule-scan`, `tax-invoice-scan`, `ledger-scan`, `report-scan`, `lifecycle-scan` (`status-graph.py`) — are **signal-gated and stay out of `--minimal`**: a project with no money, tax, ledger, report or status surface does not receive them, and `/audit-business` prints their families `N/A (detector not installed)` there.
- **rules**: `business-completeness` (a feature is "done" when forward + inverse + recovery + metrics are wired; the business pack owns the money rule, the arithmetic is code-quality's).
- **ai-patterns**: `missing-counterparts` (the canonical forward / inverse / completion / recovery tables).

## What this pack is for

- Auditing whether a feature is *complete* in the business sense (not just code-complete).
- Translating fuzzy product asks into structured specs.
- Finding the half-cycles that ship under deadline pressure (signup-without-delete, subscribe-without-cancel).
- Auditing the business rules other packs' detectors read as their oracle: the money policy, the tax policy, the ledger invariants, the metric definitions, the lifecycle graph.
- Funnel drop-off triage (`/suggest-metrics --funnel`).

## What this pack is NOT for

- Code review — use `code-quality` pack.
- UX flow + content review — use `ui-ux` pack (overlapping concern; UX is one dimension; business completeness is broader).
- Architecture — use `code-quality/legacy-modernizer` for strategic, the relevant stack pack for tactical.

## How this pack relates to others

- **`ui-ux`** — overlapping concern. `ui-ux/agents/ux-reviewer` reviews flow + content; this pack reviews business cycle completeness. Both run on a feature; findings rarely overlap.
- **`code-quality`** — code-level completeness; this pack is business-level.
- **Stack packs** (backend, frontend, mobile) — produce the feature; this pack audits it.
