# observability pack — changelog

Release history for `templates/packs/observability/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.4.1 — 2026-08-23

**Four topics were declaring a strategy that emits an empty file.**
`_topics.md` declared `fallback: stub-from-sections` with **no `sections:` key** on `add-metrics`,
`add-tracing`, `alert-design` and `slo-audit`. `phase-4.2-apply.md:26` builds that stub *from* the
`sections:` list, so an empty list emits nothing — while `commands/add-metrics.md` (181 lines),
`commands/add-tracing.md` (184), `commands/alert-design.md` (255) and `skills/slo-audit/SKILL.md`
(235) sat beside them on disk. 855 finished lines the pack was refusing to deliver. All four now
point at their source, the repair `security`, `data-engineering`, `distributed-systems` and `finops`
each made by hand before this.

Declaring the sentinel is strictly *worse* than omitting `fallback:` when a source exists: per
`phase-4.2-apply.md:26` a topic with no `fallback:` falls through to `_examples/<topic>.md`, then to
the closest template in the pack, and only then to a stub — the sentinel opts the topic out of the
chain that would have found the finished file.

This defect had now recurred five times, hand-repaired every time and gated none of them.
`validate-pack-consistency.sh` gained **check 3b** `STUB-NO-SECTIONS` (hard FAIL, not ledgerable) so
it cannot recur a sixth. The pack's greenfield topic coverage goes 79% → 100% and its line delivery
72% → 96%.

**Recorded as a trade, not a pure win.** Pointing `fallback:` at the pack's own source moves these
four topics *out of check 8b*, which walks `_examples/` only (`phase-4.2-apply.md:32`) — the
artifacts are now delivered in full but are no longer compared against anything, because they *are*
the thing. Strictly better than the empty file they replaced, and the pattern the repo already uses
(the 8b pair count fell 293 → 282 for exactly this reason), but it is a file leaving the gate's
reach rather than a repair the gate verified. See `templates/packs/_fallback-baseline.md`
§ "Source-as-fallback is a trade, not a pure win".

## 1.4.0 — 2026-08-22

- **The audits now measure or say they didn't.** `slo-audit` and `alert-audit` each gained a
  `NO-DATA(reason)` verdict, a per-row **evidence column** carrying the query/grep actually run and
  what it returned, and a closure gate that computes COMPLETE/INCOMPLETE from the ledger. Both
  previously had a verdict vocabulary in which every option asserted a fact the agent usually could
  not measure from a code repo — the ledger discipline the two *commands* already carried never
  reached the skills 40 lines away. `slo-audit` also separates `STALE` (the service stopped
  emitting — a system defect) from `NO-DATA` (I could not look — a run defect), which were being
  conflated in both directions.
- **OpenTelemetry semantic conventions refreshed across the pack.** `http.url` → `url.full` (client)
  / `url.path`+`url.scheme`+`server.address` (server), `http.method` → `http.request.method`,
  `http.status_code` → `http.response.status_code`, `db.system` → `db.system.name`, `db.statement`
  → `db.query.text`, `deployment.environment` → `deployment.environment.name` (Stable; the old name
  is Deprecated in the registry), and `http.server.duration` → `http.server.request.duration`
  (Histogram, seconds). The resource rename is not covered by an `OTEL_SEMCONV_STABILITY_OPT_IN`
  value, so the migration is: carry both keys on the `Resource`, re-point dashboard and alert
  filters, then drop the deprecated one.
  These fail *silently* — the backend's built-in view is empty and nothing errors — so
  `ai/patterns/tracing.md` gained the deprecated→current table, the `OTEL_SEMCONV_STABILITY_OPT_IN`
  `/dup` migration switch, span-naming + SpanKind rules, a detectors section and References, and
  the deprecated names left the always-loaded rule entirely.
- **`slo-audit` can now create the registry three other artifacts route creation to.** Its
  `## Related` declared it the pack's only writer of `ai/runtime/slos.md` while its `## Inputs`
  listed that file read-only and `## Outputs` never mentioned it — so `/alert-design` Phase 1,
  `synthetic-monitoring`'s probe-SLO finding and `add-telemetry` all deferred registry creation to a
  skill whose contract said it only reads, and the bootstrap could never complete. Step 1 now has an
  explicit define branch with the two defensible sources for a first target (an existing commitment,
  or measured 90d behaviour rounded down), `PROPOSED(<what would settle it>)` for when neither
  resolves, and a halt on writing a target with an empty `origin`. Outputs now lists the registry.
- **The burn-rate table is now Google's three tiers everywhere.** Five artifacts disagreed on whether
  6h/6× pages or tickets, two wrote `14` for `14.4`, `sre-engineer` computed 10% where the arithmetic
  gives 5%, and the tier Google actually tickets (**3d / 1×**) was missing from the pack entirely —
  leaving no detector at all for a leak burning at exactly the target rate. `slo.md` now carries the
  three tiers, the derivation, and the 1/12 confirmation-window rule; `alert-design`, `add-telemetry`,
  `alert-audit`, `sre-engineer`, `telemetry-architect` and `observability-reviewer` cite it.
- **Tenant cardinality is taught as arithmetic, not a threshold.** "Fine if <10k tenants" replaced
  everywhere by `series = ∏(distinct label values) × replicas` with a worked multi-tenant table, plus
  the two-part resolution (top-N + `other` on the metric; full fidelity on logs/traces/exemplars).
  `add-telemetry` Phase 6 gained an explicit tenant-label rule — it previously mandated `tenant_id`
  on every log line and omitted it from the forbidden-label list one line later.
- **`/add-telemetry` gained a greenfield convention ledger** — four rows (log field casing,
  correlation-ID mechanism, metric prefix, span-attribute namespace) with options and what decides
  each, plus the shim-and-backfill migration for a project that logs to stdout today. The greenfield
  escalation trigger previously halted with "user picks the convention" and handed the user a blank.
- **`add-metrics` / `add-tracing` are now declared narrow entry points into `/add-telemetry`**, and
  route closure back to its ledger and gate — the narrower command no longer gets the weaker gate.
  Both shed duplicated premise boilerplate; `add-metrics` lost its millisecond bucket list (which
  contradicted the pack's own base-SI-units rule) and `add-tracing` lost a dangling A33 citation that
  read as forbidding production OTel export.
- **Three dangling artifacts wired to a gate.** `slo-audit` ← `/alert-design` Phase 1 (it is the only
  artifact that *writes* `ai/runtime/slos.md`, which four others read); `synthetic-monitoring` ←
  `/alert-design` Phase 2 (blackbox is now a fourth alert class); `@incident-responder` ←
  `/alert-design` Phase 5 and `/add-telemetry` Phase 4, to author runbook *bodies* — and a runbook
  whose body says "investigate" is now an ORPHAN in both ledgers.
- **The fallbacks caught up.** `_examples/add-telemetry.md` shipped a hardcoded `Status: COMPLETE`
  against a source that forbids hand-writing it; re-cut with the ledger, the closure gate and the
  greenfield table. `_examples/observability-reviewer.md` regained `model: opus`, the emit-and-assert
  BLOCK verb and the coverage table; `_examples/telemetry-architect.md` regained § 5b (RUM reached
  greenfield through zero artifacts); `_examples/synthetic-monitoring.md` regained all six gotchas and
  the multi-location reasoning; `_examples/dashboards.md` regained the tiered drill-path diagram;
  `_examples/{profiling,audit-logging}.md` regained their cross-pack boundary sections; every agent
  fallback gained a `## Related` with siblings + invoked-by.
- **Stale specifics corrected**: Prometheus native histograms are stable in **v3.8.0** (not "GA 2024")
  and still require `scrape_native_histograms` until v4.0 — a service emitting them into a server not
  scraping them emits nothing; OpenTelemetry profiling is **Alpha**, not "a stable signal
  specification"; `metrics.md` References attributed RED+USE to SRE-book ch. 6 (which defines the four
  golden signals) two lines above correctly crediting Wilkie and Gregg, and carried five bare titles
  with no URLs.
- **Trigger fix**: the rule, `add-telemetry`, `observability-reviewer` and `structured-logging` were
  gated on `logger_lib_detected` — so the rule whose first Must-not bans direct stdout calls declined
  to install on the projects that use them. All four are now `always: true`.
- **`_essentials.md`**: added `telemetry-architect` and `alert-audit`, without which minimal-mode
  `/add-telemetry` could not reach its own generate step or compute COMPLETE; cross-pack boundary
  prose moved to `STACK.md`, which also gained the `## Enforcement` section the rule now points at.
- **rules/observability-principles.md: 1,487 → ~1,126 tokens (−24%)** — duplicated bullets deleted,
  five multi-line paragraphs demoted to one-line pointers at the skills and patterns that already own
  them, `## Enforcement` moved to `STACK.md`, deprecated attribute names removed from the
  always-loaded surface.

## 1.3.0 — 2026-07-10

- add-telemetry: static thresholds replaced with SLO burn-rate alerts (fast 1h/14x page · slow 6h/6x
  ticket); alert-design REQUIRED actionability ledger (per-alert SLO/SLI + burn window +
  runbook-file-exists).
- observability-reviewer: emit-and-assert closure verb BLOCKs Status: COMPLETE when the
  ledger/assertions are missing.

## 1.2.1 — 2026-07-10

- add-telemetry: emit-and-assert gates for metrics (scrape /metrics, assert new series) and traces
  (log-in-span, assert trace_id/span export) + a logs field-assertion — all four primitives now have
  an executable verification gate, not just alerts.

## 1.2.0 — 2026-07-10

- skill +1: synthetic-monitoring (blackbox critical-journey probes + probe-SLO, catches 'server
  healthy, user path broken'); ai-pattern +1: dashboards (tiered RED/USE dashboards-as-code +
  alert-to-panel linkage).

## 1.1.0 — 2026-07-09

- NEW ai-patterns/slo.md (resolves the slo.md dangling in sre-engineer/incident-responder/metrics —
  SLI menu, error budget, two-tier multi-window multi-burn-rate 14.4x@1h page / 6x@6h ticket,
  SLO-as-code, pattern-vs-runtime-registry split, detectors). NEW audit-logging.md (tamper-evident
  append-only/WORM + hash-chain, actor/subject/action/before-after/IP schema, retention-by-regime
  SOC2/PCI 1y / HIPAA 6y / SOX 7y, must-not-redact, security-owns-WHAT/observability-owns-pipeline
  boundary, detectors) — closes the backend OBS-1 audit-log deferral that landed on one line. NEW
  profiling.md (continuous production profiling as the 4th signal —
  eBPF/Pyroscope/Parca/OTel-profiles, CPU/heap/alloc/lock, flame-graph self-time, exemplar->profile
  linkage, perf-owns-adhoc/obs-owns-always-on boundary). Registered all three in _topics +
  _essentials.
- metrics.md: native (Prometheus GA 2024) + OTel exponential histograms noted as the
  auto-scaling-bucket alternative to the fixed-bucket trade-off.
- observability-reviewer.md: added the hand-wave token hard-halt + verdict-matches-body clauses + a
  coverage/pass-fail table + literal rg commands. rules/observability-principles.md: slow-burn 24h
  -> 6h (canonical Google window; +example mirror). telemetry-architect.md -> model:opus, 3-pillars
  reframed to logs/metrics/traces+profiling, NEW RUM/client-telemetry method + cross-pack boundary.
  sre-engineer/incident-responder: +slo/audit-logging/profiling Related + Skills subsections.
  alert-audit/slo-audit: ## Related + name-frontmatter + house headings. tracing.md: reciprocal
  distributed-systems trace-boundary link.
