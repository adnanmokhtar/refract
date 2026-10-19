---
track: product
purpose: Decide what to build and why, and check that what shipped is finished and judgeable — evidence-labelled framing, falsifiable requirements, honest synthesis, half-built-feature, tracking-plan and entitlement detectors, and a launch-readiness scorecard.
essentials:
  agents: [product-strategist]
  commands: [audit-requirements, frame-problem]
  skills: [acceptance-criteria-check]
  rules: [product-principles]
  ai-patterns: [acceptance-criteria, problem-framing]
---

# Product — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `product-strategist` is the upstream half of every requirement review: without it `@requirements-reviewer` has no brief to check metric linkage against. `@requirements-reviewer` itself is owned by the `delivery` pack (always-on, applied first, and essential there), so this pack ships no copy: `/audit-requirements --spec` dispatches delivery's agent. `user-research-synthesizer` requires raw research material to exist — it refuses to run without it, so shipping it into a project that has none would be shipping a halt — and `scope-arbiter` requires a declared success metric plus a capacity constraint; both are kept out of minimal.
- commands: `/audit-requirements` (its `--spec` lane is the gate on prose that is already being written) and `/frame-problem` (the brief that gate checks against). `/synthesize-research` presumes a corpus, `/define-success` presumes a measurable metric surface, `/to-questionnaire` presumes both a blocked artifact and a named person outside the session who can unblock it, and `/product-fix` presumes an `/audit-requirements --repo` report — all four ship in standard mode.
- skills: `acceptance-criteria-check` is the only skill whose input is the spec itself and nothing else (its trace lane prints `N/A (no criterion ids)` where tests carry none). `evidence-trace` needs reachable evidence sources and `assumption-ledger` a stated objective to rank impact against. The detectors stay out of minimal by decision (`feature-surface-scan`, `tracking-plan-scan`, `entitlement-consistency-scan`): they presume a running product with routes, analytics calls and plans, and a fresh project has none. `launch-readiness` reads a success file (`/define-success`), an assumptions ledger and the owners' same-day ledgers, none of which a minimal install produces. On a minimal install `/audit-requirements --repo` prints those ledger rows `not run (skill not installed)`, which forces `GO-UNVERIFIED`; it never reports them clean.
- rules: `product-principles` is the single rules file in the pack.
- ai-patterns: `acceptance-criteria` (falsifiability, the eight-cell coverage grid, non-functional bounds) and `problem-framing` (mechanism-free statement, labelled evidence, do-nothing baseline, metric pair) back the two essential agents directly. `research-synthesis` is gated on a corpus existing and `opportunity-sizing` on a countable population, both of which ship in standard mode.

## What this pack is for

- Making the problem explicit and refutable before it attracts commitment.
- Reviewing requirement prose with the severity a code review applies to a diff.
- Extracting findings from research at the strength the material actually supports.
- Ensuring a launch can be judged, and judged against a threshold set before the result was known: `launch-readiness` types the success definition and grades 21 cumulative bronze / silver / gold rules (`rules.json`, `readiness-score.py`).
- Finding what shipped half-built: client calls nobody serves, links to no page, placeholders and mock rows, dead controls (`feature-surface-scan`); analytics that drift from the tracking plan or fire before the outcome (`tracking-plan-scan`); plan facts that pricing copy and gates state differently (`entitlement-consistency-scan`); criteria no test names (`acceptance-criteria-check`). `/audit-requirements --repo` runs them; `/product-fix` closes the findings test-first.

## What this pack is NOT for

- Writing the spec — that is `/analyze-task`, `/expand-task`, and `@business-analyst` in the `business` pack. A strategist who specs has stopped being able to say "do not build this".
- Auditing a SHIPPED feature's business completeness — that is `@business-auditor` and `/audit-business`.
- UX flow and content review — that is `@ux-reviewer` in the `ui-ux` pack. Heuristic evaluation is not research and the two must never be cited interchangeably.
- Mapping intended-but-unbuilt capability from code and phasing it — that is `/roadmap`.
- Implementing instrumentation — that is `/add-telemetry` in the `observability` pack; `/define-success` decides what to instrument and hands it over.

## How this pack relates to others

- **`business`** — the direct neighbour, and the split is a handoff: this pack ends at an agreed, evidence-labelled problem with a metric pair; `/analyze-task` picks it up and writes the spec. `@requirements-reviewer` then reviews what `@business-analyst` wrote — running the author as the reviewer defeats the purpose.
- **`ui-ux`** — overlapping findings on the same feature are expected; each names the lens that produced it.
- **`observability`** — `/define-success` produces instrumentation gaps that `/add-telemetry` closes; a gap that blocks launch must land first.
- **`data-engineering`** — `semantic-layer` is where a metric definition lives once, so `/define-success` reuses a definition rather than creating a second one.
- **`devops`** — `progressive-delivery` owns the rollout mechanics `launch-readiness` presumes exist; this pack checks only whether the result can be learned from.
- **`testing`** — an acceptance criterion made falsifiable here is what a test can be written against; unfalsifiable criteria are why test coverage arguments happen.
