# observability pack — changelog

Release history for `templates/packs/observability/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 2.0.1 — 2026-10-10

**The `obs-defects` fixture (126 seeds, 26 decoys) found four pre-flight gaps in this pack; all are fixed and re-measured on the fixture and the seeded sample.**
- `alert-rule-lint` step 2: the `prometheus_client` inventory line (and the Micrometer / OTel line) runs with `-U`, so a black-formatted `Histogram(` with its name on the next line is inventoried. On the fixture its two selectors were false AL-10 [H] rows; now 0 false rows (inventory 24 → 25 names, 71 → 69 lines). `metric-hygiene-scan` grep 6 reads names the same way, captured with `-r '$1'` (with `\K`, rg 15.2.0 printed the whole line of a match spanning lines).
- `slo-rule-scan`: `burn-check.py --registry=ai/runtime/slos.md` reads each hand-written burn rule's objective and period from the registry row that names the alert (an `alerts` cell) or its file (a `rules` cell; the alert name picks between two rows on one file), or whose every slo-name word is in the alert name. Both `slo-audit`'s table and a hand-written `| id | SLI | objective (30 days) | … | alerts |` read. A tie lends an objective only to a `> factor * budget` comparison, never to a plain threshold. Step 2 passes it when the registry exists, so a burn rule copied from another SLO prints SLO-03 H on the first pass instead of a hidden note; on a real monorepo's hand-written registry it tied all 6 burn alerts with 0 problems, no `--slo` map needed. Spec, sloth metadata and `--slo` still win. Self-test: a copied objective, two rows on one file, an untied alert, a hand-written registry naming its alerts. Step 5 also lists Go's `Buckets: prometheus.DefBuckets` and prints the default edges.
- `telemetry-config-scan` greps 2, 3 and 7 print the file name (`-H`) and anchor multi-line matches on `^[ \t]*`, so a match never starts on the blank line above the key.
- Personal data in a log call (the fixture's OD-HO-SEC-b) is security's: `data-exposure-scan` § 6 grep 6h (security 2.3.1).

Also: `/obs-audit`, `alert-rule-lint` and `telemetry-config-scan` cite infrastructure `k8s-wiring-scan` §6 (collector RBAC wiring) and `k8s-api-version-scan` §2 (PrometheusRule / ServiceMonitor schema) instead of `@k8s-reviewer`. `log-signal-scan` §5 names the LG-05 probe row (pino-http with no `autoLogging.ignore`) that `metric-hygiene-scan` §8 credits. `proof-oracles.md` V208 gains shipper, Loki and dashboard (DB-01..DB-05) variants, cited from §5, §6 and §8. `ai-patterns/metrics.md`: DB pool waiters > 50 is a ticket, not a page (a cause; precedents § 4 is the only cause-page exception).

## 2.0.0 — 2026-10-10

**The observability pack became a set of detectors with one audit and one fix loop (Track A batch 4).** Before this release the pack was a design pack: four agents, three skills and four commands, all prose or checklists. Three of them prescribed a runnable search and two of those three were broken — `rg -L` (which is `--follow`, not files-without-match) at file granularity, so a rule file where one alert of two lacked a runbook passed. Now every observability defect class has one owning skill with a one-script pre-flight, a tool lane where a tool exists, a class-coverage block, a refute step and a failing-first oracle, and two commands dispatch them and close what they find. Major version: new commands, `alert-audit` and `slo-audit` narrowed to their behavioural half, `@observability-reviewer` rebuilt as a judge, and new Contracts on every agent.

New detectors (`skills/`), each measured 2026-10-10 on a seeded sample and the 15 benchmark fixtures, and all but `trace-propagation-scan` (whose real-repo row is still open) on a read-only real monorepo:
- `log-signal-scan` §1–§8 — handled failures nobody can see (LG-01), errors logged without their stack or type (LG-02, with the measured nestjs-pino / pino / winston shapes), unstructured or stdout logging, level misuse, volume, request ids that collide across replicas, loggers not bound to job context, trace ids missing from logs. Proof: the captured log (V189–V193).
- `trace-propagation-scan` §1–§10 — context lost across async hops and queues, uninstrumented clients, unended spans, SDK init order and flush, propagators and service identity, span names, deprecated semconv, samplers (SA-01..SA-04), behind an SDK gate. Proof: the in-memory span exporter (V194–V197).
- `metric-hygiene-scan` §1–§8 — unbounded labels, unmetered jobs, unit and bucket misfits, type misuse, registration per call, dead metrics, readiness that always answers 200 (HC-01), probe traffic in telemetry (HC-02). Proof: the registry scrape (V198–V201).
- `error-tracking-scan` §1–§4 — tracker init without release or environment, no process hooks, unsymbolicated builds, boundaries that map to 5xx without capture. Proof: the tracker test transport (V202).
- `alert-rule-lint` §1–§9 with `scripts/rule-inventory.py` (stdlib, `--self-test`) — per-rule lint, never-fire grounding against a metric inventory, rules never loaded (AL-22), window vs scrape interval, Prometheus 3 breakage, NaN ratios, routing via `amtool --verify.receivers`, vendor monitors. Tool lane: promtool 3.15.0 / 2.55.1, pint 0.89.2, amtool 0.34.1, mimirtool 3.2.2, all on copies. Proof: the promtool fire / blip pair and the routes matrix (V203–V206).
- `slo-rule-scan` §1–§6 with `scripts/burn-check.py` — no burn alert, factor vs objective and period, single windows, generated-rule drift (regenerate and diff with sloth 0.16.0 / pyrra 0.10.2), impossible targets, wrong SLI error definitions, latency thresholds that are not bucket edges, windows longer than retention (V199, V207).
- `telemetry-config-scan` §1–§8 — collector processor order and unused components, exporters without retry or queue, tail sampling without trace-id load balancing, Loki stream labels, Promtail end of life, retention that does not delete, debug exporters and unselected monitors, dashboards (V198, V208).

Rewritten in place:
- `alert-audit` keeps only alert behaviour (dead, noisy, flapping, orphaned, cause-as-page) judged against fire and paging history, consumes `alert-rule-lint`'s rows, never re-greps a rule file, and prints `NO-DATA(<source>)` without a backend. Its broken `rg -L` line is gone.
- `slo-audit` keeps attainment, STALE vs NO-DATA and the registry; it is now the **single writer** of `ai/runtime/slos.md` and gains `--no-write` for read-only callers.
- `synthetic-monitoring` §1–§5 — a probe-config pre-flight, journeys from the route table, a coverage block.
- `@observability-reviewer` is a judge (`role: judge`, `writes: none`): it dispatches the seven detectors through the Skill tool on a diff, refutes every row, and keeps only the checks no detector can make (sibling divergence, label arithmetic, consumer grounding, emit-and-assert closure). Its two path-less `rg` lines and its `rg -L` line are deleted; with `alert-audit`'s, both observability rows of `lint-rg-traps.sh`'s baseline are cleared.

New commands: `/obs-audit` (read-only; class ledger over every detector, tool and live lanes, RULES GATE and the production bar, a three-state verdict) and `/obs-fix` (re-verify, failing-first oracle on the server's version, fix at the source — the logger factory, the SLO spec, the mixin — RE-DETECT, sibling sweep, security's canary after any logger change).

Commands and patterns brought onto the detectors:
- `/alert-design` Phase 6 runs the decidable gate — `alert-rule-lint` (promtool, pint, `rule-inventory.py` grounding, rule loading, routes matrix), a promtool fire / blip pair per page rule on the server's Prometheus major (read from a file, or pinned), `burn-check.py` — before `alert-audit`'s behavioural replay. It **proposes** SLO rows and dispatches `slo-audit` in write mode instead of writing `ai/runtime/slos.md` itself. Disk pages are `predict_linear` projections, never a static percentage; cause signals are tickets unless definite and imminent.
- `/add-telemetry` dispatches `alert-rule-lint` before `alert-audit` (which now halts without its rows); its alert row asserts promtool check, the fire / blip pair, selector grounding against the series the run asserted on scrape, `burn-check.py` and the runbook; its logger row is the captured-log oracle (V189) — error type and stack on the error line, levels per `THR-LOG-LEVEL`; its trace row adds a cross-hop test (V194). `/add-metrics` adds the unit trap (`observe(Date.now() - t)` into `_seconds`, V199), route-template labels and `promtool check metrics`. `/add-tracing` asserts the resolved sampler is parent-based and that a stated error-retention requirement has a mechanism — a tail `status_code` policy or tracker capture — since a head sampler cannot keep errors (SA-02); it adds the cross-hop test.
- Burn factors are arithmetic, held in one place (`THR-OBS-BURN`: `factor = budget_fraction × period / long_window`). The "write 14.4, not 14" literal is gone from `/alert-design`, `/add-telemetry`, `@sre-engineer`, `@telemetry-architect` and `ai-patterns/slo.md`; Pyrra's 14 / 7 / 2 / 1 and the Workbook's fourth 3× 24h/2h ticket tier are accepted sets. The page budget moved to `THR-OBS-PAGE-BUDGET`.
- `ai-patterns/metrics.md`: counter resets do not break `rate()` (it compensates — that item is deleted); gauge-as-counter and `rate(sum(...))` stay; domain metrics carry a domain prefix while generic semconv metrics keep their shared name and are told apart by `job` / `service.name`. `structured-logging.md` gains the per-logger table of which error-argument shapes keep the type and stack (LG-02). `tracing.md` and `rules/observability-principles.md` no longer promise "100 % of errors traced" from a head sampler, and no longer prescribe hashing as redaction — sensitive values are security's (`data-exposure-scan` § 6).
- `STACK.md` carries one boundaries table: security, code-quality, performance, infrastructure, devops, finops, mobile and distributed-systems, each with what observability keeps.

Agents: `@telemetry-architect` (`role: proposer`), `@sre-engineer` (`writer`, `ai/reliability/**` — postmortems, the quarterly review, the budget policy) and `@incident-responder` (`writer`, `ai/runbooks/**`) carry a `## Contract` block and a grounding halt (every metric, selector and field they name resolves in the inventory, precedents § 37). `lint-agent-contract.sh` now lists observability as a pack whose agents must have one.

Snippets and governance: `precedents/observability.md` § 1–55 (§ 41 group-level rule labels, measured: 3.15.0 applies them, 2.55.1 rejects the file; § 53 pint 0.89.2 does not rewrite in place, mimirtool / lokitool / dashboard-linter do; § 54–55 readiness reflects per-pod dependencies only, and a probe filter in every consuming selector closes HC-02's metric half), `proof-oracles.md` § Observability V189–V208, thresholds `THR-OBS-BURN`, `THR-OBS-RATE-WINDOW`, `THR-OBS-ALERT`, `THR-OBS-CARDINALITY`, `THR-OBS-PAGE-BUDGET` and `THR-LOG-LEVEL` (4xx ≤ warn, 5xx error), and 11 `ownership.json` rows (`obs-logs` … `obs-pipeline`).

`_essentials.md` lists the seven detectors, `alert-audit`, `synthetic-monitoring`, `/obs-audit` and `/obs-fix`. `_examples/alert-audit.md` is deleted (it carried the file-granularity runbook check); the `_examples/` twins of the agents, patterns, rule and `/add-telemetry` carry the same edits as their sources.

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
