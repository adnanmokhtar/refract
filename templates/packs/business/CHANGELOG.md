# business pack — changelog

Release history for `templates/packs/business/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

The 1.6.0 entry also carries a **Release narrative**: the `_version.json` `summary` string held a
second, independent telling of the release that had grown well past a one-line stamp. It is
preserved below verbatim and unabridged; `summary` now carries a single line for the current
version.

## 1.6.0 — 2026-07-11

- NEW command /suggest-features (business pack) — whole-product capability gap analysis wired to
  business-domains/<domain>/feature-checklist.md: detect domain -> inventory the product's actual
  capabilities from code -> diff -> WRITE ai/business/feature-recommendations.md with
  analyze-task-ready blocks (closure verbs recommend-capability / complete-capability /
  defer-capability). Each block carries a copy-paste /analyze-task line so analysis flows into
  /analyze-task (spec) -> /add-feature (build). Reverse gate flags over-builds to defer.
- Sync: _topics.md (command entry), _essentials.md (commands + rationale), docs/COMMANDS.md business
  track. Completes the pair with /suggest-metrics (measure) as /suggest-features (build).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

New /suggest-features — the capability arm + the analysis->implementation pipeline. Analyzes the
whole product against its domain feature-checklist and WRITES
ai/business/feature-recommendations.md: the missing high-value capabilities, each
'analyze-task-ready' (what/why/touches/have/warrant + a copy-paste /analyze-task line) so you pick
one -> /analyze-task writes a buildable spec -> /add-feature implements it (the spec->build seam, no
re-deriving). Also flags over-builds to DEFER (not just pile on). Together with /suggest-metrics
(what to measure) it completes the pair: /suggest-features = what to build. Breadth counterpart to
/audit-business (one feature deep); recommends + writes buildable candidates, does not build.

## 1.5.0 — 2026-07-11

- NEW command /suggest-metrics (business pack) — domain-aware dashboard-KPI coverage: detect domain
  -> inventory shown metrics -> diff vs the six-category decision-metric set -> recommend missing
  high-value metrics prioritized by decision-leverage x computability, with closure verbs
  recommend-metric / upgrade-count-to-rate / pair-metric / flag-vanity /
  name-missing-instrumentation. Every recommendation carries a decision, a formula, and a data
  source (have-data / needs-instrumentation) or it is dropped.
- Sync: _topics.md (command entry, fallback stub-from-sections), _essentials.md (commands list +
  rationale), docs/COMMANDS.md business track. The metrics arm of business-completeness; hands off
  to /add-feature + backend + /add-telemetry.

## 1.4.0 — 2026-07-10

- pricing-tax-audit Edge-correctness probe: a 9-property money/quantity battery (zero · max ·
  negative · multi-currency · rounding boundaries).
- domain-model-auditor: invariant edge-rejection proof; workflow-integrity: money-conservation probe
  (full reversal restores exact charged cents) on money-moving edges.

## 1.3.0 — 2026-07-10

- agents +1: domain-model-auditor (opus) — aggregate/invariant structure + invariant-enforcement
  register (consumes learning's extract-domain-entities-deeply); skills +1: pricing-tax-audit —
  money-math correctness (integer/decimal money, rounding, tax jurisdiction, currency, idempotent
  metering).

## 1.2.0 — 2026-07-09

- agents +1: workflow-integrity (opus) — audits an entity's lifecycle STATE GRAPH (reachability,
  terminal states, illegal/unguarded transitions, per-transition
  auth/audit/idempotency/concurrency), reconstructed from code. The state-graph counterpart to
  missing-counterparts' cycle-pairs. Backing MUST/SHOULD in business-completeness.
