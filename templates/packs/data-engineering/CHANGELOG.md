# data-engineering pack — changelog

Release history for `templates/packs/data-engineering/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 2.0.0 — 2026-10-19

**The data-engineering pack became a detector pack (Track A batch 8).** It owns the derived data — how it is loaded, refreshed, tested, contracted, traced, extracted and copied; business owns the number, database the table, distributed-systems the message.

- **Graph.** `incremental-load-scan/scripts/model-graph.py` reads a dbt project without dbt (projects, configs with their source, refs, sources, tests, exposures, unit tests, adapters, the dbt version; `--class`, `--self-test`). Integration: versioned models (`<name>_v<N>`) now inherit the base entry's tests, access and contract and take their own `versions:` config, and an exposure pinned with `v=` marks only that version — removing a DQ-1 false positive on `data-pipelines` (`dim_customers_v1`) and the exposure-parent SC-1 on versions nobody reads (92 self-tests).
- **Detectors.** New: `incremental-load-scan` (IN §1–§10; grep 2c now spans multi-line `to_sql(`), `orchestration-scan` (OR §1–§9), `data-test-scan` (DQ §1–§8), `derived-data-scan` (MV §1–§6, TB §7–§10), `extract-scan` (EX §1–§4), `pii-copy-scan` (PC §1–§6). Rewritten: `contract-diff` (SC §1–§6), `lineage-trace` (LN §1–§4), `warehouse-scan-audit` (CO §1–§5), `grain-probe` (GR §1–§4).
- **Commands.** `/audit-data-quality` is the read-only whole-repo audit; `/data-fix` (new) closes findings failing first; `/audit-data-model`, `/backfill-plan` (loader gate = `incremental-load-scan` §2/§7/§8) and `/add-data-model` edited; three judges in refute mode (IN rows judged by `@warehouse-modeler`).
- **Cross-pack:** database `query-shape-scan`, business `report-scan`, distributed-systems `dual-write-scan` and backend `job-lifecycle-scan` carry boundary lines; the `data-pipeline` and `reporting` overlays corroborate instead of detecting. The rule is held by `test-rule-loading.sh` to data samples (its globs bind models, DAGs and exports, not every `src/index.ts`).
- **Fixture `data-pipelines`** (132 seeds over 66 classes, 37 decoys). Precedents `precedents/data-engineering.md` §1–45; proof oracles V540–V569; 10 `ownership.json` rows. Warehouse lanes are fixture-measured only (no real dbt repo was available).

## 1.1.0 — 2026-08-23

Fallback-integrity release. The pack's content was sound; two-thirds of it could not reach a
greenfield project.

- **12 of 18 topics declared `fallback: stub-from-sections`, and 4 of those carried no `sections:`
  list at all.** `phase-4.2-apply.md:26` builds a stub from that list, so `grain-probe`,
  `lineage-trace`, `contract-diff` and `warehouse-scan-audit` — 119–146 finished lines each, sitting
  on disk — materialised on greenfield as **empty files**. The other eight arrived as bare heading
  skeletons: `/backfill-plan` without the shadow-target/idempotency-proof/UNEXPLAINED-DELTA gate,
  `/audit-data-quality` without the prove-an-assertion-can-fail step, `data-contract` without the
  SEMANTIC-BREAKING class. All 12 now declare source-as-fallback, the shape
  `phase-4.2-apply.md` step 2 provides for and that `algorithms`, `business`, `code-quality` and
  `mobile` already use. Greenfield coverage: 6/18 → **18/18**. Same defect previously repaired by
  hand in security (CHANGELOG:87) and infrastructure (CHANGELOG:106); no gate catches it, which is
  why it recurred here.
- **`warehouse-scan-audit` was never dispatched.** Its only command mention was a Related line
  calling it "the executor", while `/backfill-plan` Phase 3 re-derived its output by hand — the one
  place in the pack where a cost figure could be reasoned rather than read, inside a command whose
  Premise refuses "an unbounded spend authorised by nobody". `/backfill-plan` Phase 2 now dispatches
  it for the per-chunk bytes/cost/runtime estimate, and carries its `UNKNOWN` and flat-rate-capacity
  verdicts through to the chunk table instead of inventing numbers. All four skills are now
  dispatched from a numbered phase.
- **Closure verbs added to all five patterns** (`dimensional-model`, `transformation-layers`,
  `data-quality-tests`, `data-contract`, `semantic-layer`) and consumed by `/audit-data-model` and
  `/audit-data-quality`. Measured repo-wide, patterns carrying a `Closure verbs:` line ran 7/7 in
  ai-engineering, 16/16 in backend, and **0/5 here** — so findings closed in prose and a second run
  could not diff which ones closed, meaning SYSTEMIC never surfaced. Three of the lists carry the
  case that does *not* close the obvious way: `prove-assertion-can-fail` is the only verb that closes
  a zero-failure suite; `collapse-duplicate-definition` must name which definition survives; and
  `data-contract` deliberately has no verb for a semantic break, because that class closes by
  versioning *plus* consumer notice, never by editing a file.
- **`warehouse-scan-audit` gained an "Adapt to the platform" table keyed on billing shape** — per
  byte scanned, per slot-second, flat-rate capacity, per cluster-hour — because the pricing model,
  not the vendor, decides whether a finding is a saving, a latency change, or fiction. It also now
  requires the platform's own column names in findings rather than house translations, on the same
  reasoning `vector-index-audit` gives for ANN parameters: a renamed metric is un-greppable for the
  engineer who has to reproduce it. `lineage-trace` gained the matching rule for node names.
- **All four agent fallbacks lost their sibling-boundary section** — 4/4 collapsed
  `### Sibling agents in data-engineering pack` into a bare `@name` list, so a greenfield project
  received four auditors with no ownership contract between them. Each now carries a compressed
  `**Boundary:**` line naming who owns what, the form ai-engineering's agents already use (3/3).
  Check 8b does not protect boundary sections, which is why every one of them was dropped.
- Rule shrunk 1964 → 1769 tok (−195, −10%): the Review checklist was 9 restatements of Must items and
  is deleted; `Overwrite a live table during a backfill` was a pure negation of two Musts; and
  `Aggregate over a model whose grain has not been probed in the current change` is folded into the
  grain Must, which is where "in the current change" belongs. **The other four Must-nots proposed for
  deletion were checked and kept** — the late-arrival filter forms, the undated assertion disable, the
  unread quarantine and the BI-layer fix each carry an obligation stated nowhere in Must.
- `@dag-reviewer` referenced `backfill-plan` unslashed — the only unslashed command reference in the
  pack, and the marker of a Related section written by hand rather than checked.

## 1.0.0 — 2026-08-20

- NEW pack. Covers the analytics/warehouse discipline that the `data-pipeline` technical signal
  (`templates/domains/data-pipeline/`) does not: that signal owns per-change MOVEMENT correctness
  (idempotent loads, checkpoints, DLQ, backfill isolation); this pack owns the SHAPE of what lands
  and whether it can be trusted.
- agents (4): `warehouse-modeler` (opus — grain, fact/dimension, additivity, SCD, conformance,
  join cardinality), `analytics-engineer` (opus — staging/intermediate/mart layering, materialization,
  incremental correctness, one-definition-per-metric), `data-quality-auditor` (opus — the four
  trust floors + severity/ownership/routing), `dag-reviewer` (sonnet — mechanical per-task scan of
  orchestration definitions: retries, timeouts, pools, catchup, trigger rules, window parameterisation).
- commands (4): `/add-data-model`, `/audit-data-model`, `/audit-data-quality`, `/backfill-plan`.
  `/backfill-plan` never executes a cutover — it produces an evidence ledger that authorises one.
- skills (4): `grain-probe` (the executable uniqueness proof behind every aggregation claim),
  `lineage-trace` (downstream/upstream consumers including the BI layer, with explicit PARTIAL
  reporting when the consumption layer is unreachable), `contract-diff` (ADDITIVE / BREAKING /
  SEMANTIC-BREAKING classification, with a deliberate hunt for the silent third class),
  `warehouse-scan-audit` (what the SQL actually scans, from platform query history only).
- rules (1): `data-engineering-principles`.
- ai-patterns (5): `dimensional-model`, `transformation-layers`, `data-contract`,
  `data-quality-tests`, `semantic-layer`.
- Boundaries stated in every artifact: `database` pack owns OLTP schema/queries/migrations;
  `data-pipeline` signal owns movement correctness; `finops` owns the spend envelope while
  `warehouse-scan-audit` owns the SQL producing it; `observability` owns alert routing, which data
  assertions reuse rather than duplicating; `business` `/suggest-metrics` decides WHICH metrics a
  domain needs while `semantic-layer` makes each one singular.
