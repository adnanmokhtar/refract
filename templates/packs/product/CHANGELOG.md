# product pack — changelog

Release history for `templates/packs/product/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.0.0 — 2026-08-20

- NEW pack. The business pack already covers the spec-to-shipped-feature span: `@business-analyst`
  writes specs, `/analyze-task` and `/expand-task` turn ideas into them, `@business-auditor` and
  `@workflow-integrity` audit what shipped, and `/suggest-features` proposes capabilities from a
  domain checklist. This pack deliberately does NOT duplicate any of that. It owns the span
  UPSTREAM of the spec — problem framing, evidence, requirement quality, scope classification, and
  whether a launch can be judged — plus the one downstream gate the business pack has no equivalent
  for (`launch-readiness`).
- agents (4): `requirements-reviewer` (opus — reviews prose with the severity a code reviewer
  applies to a diff: falsifiability, two-reading ambiguity, solution-in-problem, the eight-cell
  coverage grid, non-functional bounds, traceability, metric linkage), `product-strategist` (opus —
  the mechanism-free problem statement, labelled evidence, the do-nothing baseline, the metric pair,
  kill criteria with an owner), `user-research-synthesizer` (opus — fidelity over narrative: verbatim
  quotes with locators, counts with denominators, observed/said/interpreted labels, disconfirming
  material, and a refusal to upgrade an evidence class), `scope-arbiter` (sonnet — mechanical
  must/should/could/won't classification, one row per item, `must` requiring a stated consequence of
  omission).
- commands (4): `/frame-problem`, `/audit-requirements`, `/synthesize-research`, `/define-success`.
- skills (4): `acceptance-criteria-check`, `evidence-trace`, `assumption-ledger`, `launch-readiness`.
- rules (1): `product-principles`.
- ai-patterns (4): `problem-framing`, `acceptance-criteria`, `research-synthesis`,
  `opportunity-sizing`.
- The pack's central discipline is the label rule, mirroring the finops pack's three-label rule for
  cost: every claim about users is cited, or labelled an assumption, and nothing is ever invented —
  no fabricated quotes, personas, participants, or numbers. "No direct evidence; assumption ranked 1"
  is treated as a better brief than a confident one, because it names what to go and find out.
- Boundaries stated in every artifact: `business` owns the spec and the shipped-feature audit;
  `ui-ux` `@ux-reviewer` owns flow and content review, which is heuristic evaluation and not
  research; `/roadmap` (orchestration) maps intended-but-unbuilt capability from code while this
  pack decides what *should* be intended; `observability` `/add-telemetry` implements the
  instrumentation `/define-success` specifies; `devops` owns deploy mechanics while
  `launch-readiness` owns only whether the launch can be learned from.
