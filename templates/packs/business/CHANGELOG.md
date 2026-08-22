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

## 1.7.0 — 2026-08-23

FIXED (the gate that never reached greenfield)
- **All three gate-bearing artifacts shipped a fallback that DROPPED the gate.** `_examples/` is
  copied verbatim when extraction finds no signal, and on greenfield it is the ONLY path — so a new
  project received the discipline's shell without its enforcement. Measured before repair:
  `workflow-integrity` 54L/188L with the whole `$-conserve` money-conservation battery absent and a
  verdict enum missing "conservation unproven"; `domain-model-auditor` 55L/192L missing premise (e)
  (a cited guard is the FLOOR, a probed guard is the BAR) and the register's `Edge-proof` column
  entirely; `pricing-tax-audit` 62L/178L with the whole `UNVERIFIED (N unproven)` state gone, so a
  pure shape check could print `clean`. All three gates restored, compressed, in the fallbacks.
- **`/suggest-metrics` and `/suggest-features` declared `fallback: stub-from-sections`.** On
  greenfield they materialised as three empty headings — losing all three recommendation gates, the
  reverse `defer-capability` gate and the `→ Spec it` pipeline that IS the command. Both now declare
  source-as-fallback (`commands/<name>.md`), the shape `phase-4.2-apply.md` step 2 provides for and
  the security pack already used to repair the identical defect twice.
- **`@workflow-integrity` and `@domain-model-auditor` were unreachable.** The rule and the pattern
  both promised them; no command dispatched either. `/audit-business` now dispatches all three
  agents as three named axes and reports coverage per axis.
- business-completeness: `/business-flow-audit` appeared exactly once in the whole repo — in the
  rule that cited it. Deleted; the real commands are named instead. The undated
  `TODO: validator at scripts/audit-business-flows.sh` (a file that does not exist, and the only
  `TODO: validator` line in `templates/packs/`) deleted — an undated TBD in an always-loaded rule is
  what `doc-principles` forbids. Empty `## Related` heading whose body read "(Cross-references in
  the rule body above.)" deleted.
- Unsourced magnitude removed: "wording shifts conversion 5-15%" had no source. The Should now says
  to measure the lift on this product rather than import a figure.
- `missing-counterparts`: "Apple requires account-delete since iOS 16" (twice) was wrongly framed —
  App Store Review Guideline 5.1.1(v) is unconditional and not keyed to an iOS version. Now quotes
  the guideline and cites it.
- Stack leakage in fallbacks the sources had genericised: `StripeService.changePlan`
  (`_examples/audit-business.md`), "also integrate Stripe" (`_examples/business-analyst.md`),
  "Postmark dashboard" (`audit-funnel-completion`).

IMPROVED (correct, but not doing its job)
- **business-completeness rule: 2156 -> 1479 tok (-31%).** Three mega-Musts were prose précis of
  agents that ship in full and end by naming them; each is now the obligation + its trigger. The
  six-item failure history MOVED to `ai-patterns/missing-counterparts.md` (a verified
  unconditional-ship destination) and became a two-column table of what each half-cycle COST — the
  part that actually teaches. Review-checklist rows that restated the mega-Musts collapsed to one
  line each and now demand a cited verdict.
- **`@business-auditor` printed `Completeness: <N%>` with no computation rule anywhere in the
  file** — no denominator, no method — while both its siblings compute their header coverage from a
  register. Replaced with a cycle register: one row per forward action, evidence per row, and
  `NOT WALKED` rows that STAY in the denominator (dropping them is how an audit of half a feature
  reports 100%).
- **`check-business-coverage` demanded concrete paths in its Premise and then printed bare
  checkmarks** — the exact thing its pack-mate `pricing-tax-audit` bans. Every matrix cell now
  carries the route/click-path that makes it true, MISSING states what was searched, and severity
  cites the regulation (GDPR Art. 7(3) quoted and linked).
- **`audit-funnel-completion` forbade unbacked lift figures and then demonstrated one**
  ("34% -> 55%... +21pp"). A lift is now reportable only as observed (cite the experiment), bounded
  (the arithmetic ceiling, showing its inputs), or unquantified — never a point forecast.
- **`@business-analyst` listed ONE sibling of four.** Now states the boundary against all three
  post-ship auditors, and gained a `Lifecycle & invariants` spec section — because those auditors
  can only grade what the spec named, and an invariant left implicit becomes an
  `enforced-where: NOWHERE` BLOCKER discovered after the code exists.
- `/analyze-task`: measured 10 bullet pairs at Jaccard >= 0.30 across Hard rules / Failure modes /
  Phase 6. Phase 6 became a mechanical run-this table, Failure modes became the five ways a spec
  passes every check and is still wrong. Now 3 pairs, all the legitimate obligation-to-check link.
- `/expand-task`: `## Gotchas` deleted — 4 of its 5 bullets restated a Hard rule or Failure mode
  (0.77 / 0.55 / 0.28 / 0.17). Hard rules now cite `/analyze-task` for the shared spec contract and
  keep only what is different about an expansion.
- `/audit-business` gained `INCOMPLETE — <axis> not audited`. `COMPLETE` over an un-audited axis is
  indistinguishable, to a reader, from a clean audit of all three.

FIXED (integration pass, same release)
- **`_examples/analyze-task.md` kept the pre-release Phase-6 bullet list.** The source replaced it
  with an ordered 8-row HALT/re-emit table this release. The fallback's bullets kept most of the
  enforceable substance but lost the **run order**, the **HALT-vs-re-emit distinction** for rows
  5-8, and **row 5 entirely** — exactly one section holds confirmed answers, named `Resolved
  decisions`, with no answered question still phrased as open. That is the sibling-shape-drift check
  this command's premise, its `--resume` contract and its failure-modes list all name; Phase 6 was
  the only place that actually *ran* it, and greenfield did not get it. Table restored,
  verbatim-abridged.

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
