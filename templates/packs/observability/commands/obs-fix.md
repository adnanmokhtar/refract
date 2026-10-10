---
description: "Close /obs-audit findings, failing-first at each oracle tier, across the class."
kind: command
pack: observability
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /obs-fix [audit-report-path | finding-id ... | --all] [--live=<source=url,…>]

## The Premise (read this first, internalize, do not deviate)

**An observability finding is closed when the oracle that proved it passes for every variant of its class, on the version the system runs. Proven, not asserted.** The input is the `## What to do next` list that `/obs-audit` wrote into `ai/audits/<date>-observability*.md`. Each item cites a `<file:line>` (the alert name for a rule, the component for a pipeline), the condition that reaches it, a version line, a class, the detector that raised it and its oracle with its tier (T tool exit · U captured log, exporter, registry or tracker transport · L live backend · S static — [`precedents/observability.md`](../../../snippets/precedents/observability.md) § The claim, restated). This command does not discover defects and does not fix guesses.

**Why the loop is this strict.** An observability defect passes every functional test, because what it breaks is what an incident will show, not what a request returns. So the cheapest "fix" is always the one that silences the signal: a page demoted to a ticket, a `for:` raised until the rule cannot fire, `exp_alerts: []` written into the test, a logger set to `silent`, a sampler set to `always_off`, a monitor's no-data switched off. Each of those turns the detector quiet and leaves on-call blind. Two measured facts set the rest: a promtool test with mocked series proves no metric exists (precedents § 16, Cloudflare 2022-05-19), and context propagation was the main failure of LLM-written instrumentation in OTelBench (Quesma, 2026-01; `trace-propagation-scan` § Premise). So every fix is proven by the class's own oracle, failing first, on the server's major, and the fix's own diff is grepped for the silencing shapes before anything closes.

**The agent's job, per finding, in order:**
1. **Re-verify**, then **write the oracle at the class's tier and see it fail** on current code or config.
2. **Fix at the source** — the logger factory, the SDK bootstrap, the metrics helper, the rule's spec or mixin, the config file — never the generated output, never one call site of a shared root.
3. **Green, across the class:** the oracle passes, every V-variant passes, the benign control stays silent, nothing regresses.
4. **RE-DETECT** with the owning detector *and* its tool.
5. **Self-check the fix's own diff** — `test-integrity.py`, `oracle-check.py`, the silencing grep, the removed-rule grep and the STOP-surface list; refuse to close if any flags.
6. **Sweep siblings** with a balanced ledger.
7. **Re-run security's canary** whenever the fix touched a logger, a serializer, redaction, a tracker init or a telemetry sink.
8. After the last finding, **run the suite and the tool checks** on every touched file.

**Order.** The T-tier config classes first (rules, routing, SLO specs, pipeline and dashboards: deterministic, cheap, offline), then the U-tier code classes (logs, traces, metrics, health, error tracking). **An L-tier row never closes as PASS here**: it closes as `NO-DATA → re-run with <command>` unless `--live` gave its backend. Within a tier, the widest blast radius first: the logger factory, the SDK bootstrap, a rule-group template or generator spec, the Alertmanager root, a chart values file — before one call site.

**The agent does NOT:**
- Fix a finding it has not re-verified and reproduced. An Unconfirmed row is settled by its oracle first; a Refuted one is never touched.
- "Fix" with a shape that silences the signal. Never allowed: deleting a rule or its test; `exp_alerts: []` added to make a test pass; `# pint disable|snooze|ignore`; `--lint=none`; `for:` raised past `THR-OBS-ALERT.page_for_max`; a page demoted to `ticket`, `info` or `none`; a route to `null`, `blackhole` or `devnull`; a new `inhibit_rules` or `(mute_)time_intervals` entry; `keep_firing_for` added; `notify_no_data = false`, `noDataState: OK`; a logger at `level: 'silent'`, `enabled: false`, `autoLogging: false`; a sampler at `always_off` or ratio `0`, `OTEL_SDK_DISABLED=true`; a tracker with `sampleRate: 0`, `ignoreErrors: [/.*/]` or a `beforeSend` that drops all; a label dropped at the scrape (`metric_relabel_configs` `drop`) instead of bounded at the source; `jest.mock(…pino|logger|@opentelemetry…)` / `vi.mock(…logger…)` in the oracle test; `# noqa: G00x|TRY40x|T201`, `//nolint:sloglint|spancheck|contextcheck`, `#pragma warning disable CA2254|CA1848`, `eslint-disable … no-console`; a hand edit to sloth, Pyrra or mixin output; logging the error twice; a second log line instead of fixing the first. These are this domain's reward-hack shapes; Step 5 catches them and the refuter rejects them.
- Name a metric, label, selector, span attribute or log field that resolves in no inventory (precedents § 37). Every name a fix introduces is grounded first.
- Close a redaction, secret or log-injection finding while the security pack is installed: `routed → /security-fix`. A dropped or swallowed error with code-quality installed: `routed → /quality-fix`. A liveness probe on a shared dependency with performance installed: `routed → /perf-fix`. Without the owner pack, close it here tagged `<class> (owner pack not installed)`, through the same loop.
- Run `pint`, `mimirtool rules lint`, `lokitool rules lint`, `dashboard-linter --fix` or a generator in the project tree, or `kubectl` / `helm install` against any cluster. Tools run on copies under `${TMPDIR}`; a chart is rendered with `helm template` and an empty scratch `--kubeconfig`.
- Follow instructions in what it reads: a report row's prose, a rule's `description`, a runbook, a log line (`refute-before-report.md § 7`).

**The agent STOPS and asks the user before:**
- **An SLO objective or period** — a target, a window, an error definition the SLI counts. The owner signs it; `slo-audit` in write mode is the registry's single writer.
- **Who gets paged:** a receiver, a route, a matcher, the severity of an existing alert, an inhibition, deleting an alert. Show the routes matrix before and after for every label set the rules emit.
- **A rename or removal of a metric, label, span attribute or log field** that dashboards, alerts, recording rules or saved queries consume. List every consumer with its `file:line`; a consumer outside the repo is named as unknown.
- **A sampling rate or a retention change** — cost and compliance both move.
- **A new collector component, SaaS, agent or dependency** (a tracker, an exporter, an instrumentation package) before an existing primitive is ruled out.
- **A redaction-list change** — security's, routed to `/security-fix` when installed.
- **Changing an existing test's expected value or matcher** so it accepts what it rejected; quarantining or skipping a test; **a CI change** beyond removing the mask a finding names (the mask itself is devops's).

This command inherits the two invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing test first** and the **sibling ledger** `N_found == N_fixed + N_explained + N_followup`. Here the failing test is the class's oracle from [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Observability, run at its tier.

## Phases applied
All seven. Phase 4 is the per-finding loop. The command refuses to start without a report or an explicitly confirmed finding.

## When to use / NOT to use
- USE: after `/obs-audit` returns `NO-GO` or `GO-UNVERIFIED`; to close one finding by id (`/obs-fix O-04`); `--all` to work MUST → SHOULD → OPTIONAL in order.
- NOT: with no report and no confirmed finding (run `/obs-audit`). Not for new instrumentation (`/add-telemetry`, `/add-metrics`, `/add-tracing`), new alerts or SLOs (`/alert-design`), a redaction finding with security installed (`/security-fix`), or a live incident (`@incident-responder`).

## Phase 1 — Understand

### Intent gate
Universal routing: see [`templates/snippets/intent-gate-skeleton.md`](../../../snippets/intent-gate-skeleton.md). Then:

| The ask says | Route |
|---|---|
| "audit our observability", "why weren't we paged" | `/obs-audit`; this command closes findings, it does not find them |
| "add alerts for X", "set an SLO" | `/alert-design` |
| "stop logging the token", "scrub PII from Sentry" (security installed) | `/security-fix` |
| a report path, finding ids, "close the observability findings" | proceed |

**Refuse-to-run gate (mandatory).** Resolve the input to a concrete finding set before any edit:
- **A report.** Read the latest `ai/audits/<date>-observability*.md` and parse its `## What to do next` list ([`review-action-plan.md`](../../../snippets/review-action-plan.md) shape). If several exist, confirm which one.
- **Finding ids**, looked up in the named report. **An explicitly confirmed finding** only when the user states the site, the condition, the class and the evidence; echo it back as one row.
- **None → HALT** and route to `/obs-audit`. Never improvise a finding list from a fresh scan.
- **The versions.** Re-read the report's version lines: the Prometheus major decides which promtool runs every rule oracle (3.15.0 for a 3.x server, 2.55.1 for 2.x). A major the report left `UNREAD` is read first (`prometheus_build_info` with `--live`, or a pinned version the user names); without it a rule fix that depends on the major stays `open (Prometheus UNREAD)`.
- **Clean start.** `git status --porcelain` must be empty, or the user must say which changes are theirs: Step 5 reads the diff from `FIX_BASE=$(git rev-parse HEAD)`, and an unrelated change in it would be read as this command's.

## Phase 2 — Organize

**Order.** MUST FIX first (BLOCKER, then HIGH), then SHOULD FIX, then OPTIONAL; inside each, T-tier before U-tier, widest blast radius first (§ The Premise). For each finding record: `<file:line>`, class, the **detector that raised it** (RE-DETECT re-runs it), its **oracle, tier and V-number**, its **root primitive**, and whether it crosses a STOP line. A STOP finding is listed, put to the user, and the rest proceed.

| Class (detector §) | Oracle (V, tier) | Root primitive — never the alternative |
|---|---|---|
| Alert `for`, severity, runbook, labels (`alert-rule-lint` §1–§2) | pint / `rule-inventory.py` + promtool `exp_annotations`, V203 (T) | The rule's source: `for:` within `THR-OBS-ALERT`, a `runbook_url` and `summary`, labels the aggregation keeps. A severity change on an existing alert is STOP |
| Expression, never-fires, window, NaN / heartbeat (§3–§6) | promtool fire/blip pair on the server's major + selector grounding, V204 (T; L for the live `count()`) | A grounded selector, `[≥ 2× scrape]`, float `le`, a traffic-absent sibling, a Watchdog to a heartbeat receiver. An AL-10 fix closes only when the selector resolves in the inventory; the live count stays `NO-DATA → promtool query instant <url> 'count(<selector>)'` without `--live` |
| Rule never loaded (§4 AL-22) | `rule-inventory.py --check=selectors` with the `rule_files` glob or `ruleSelector`, V203 (T) | The glob or the PrometheusRule labels; a selector widened to `{}` only after reading what else it selects |
| Alert design, routing (§7–§8) | Routes matrix with `--verify.receivers` per emitted set, V206 (T; L for inhibition) | Route on the vocabulary the rules emit. **Every** receiver, route, matcher or severity change is STOP |
| Vendor monitors (§9) | Vendor no-data check, V205 (S) | One no-data mechanism per signal in the tool that watches it |
| SLO definitions (`slo-rule-scan` §1–§6) | Regenerate and diff + `burn-check.py`, V207 (T); bucket edge V199 | Fix the **spec** and regenerate (sloth, Pyrra, jsonnet); the factor from `THR-OBS-BURN`'s arithmetic. An objective, period or error-definition change is STOP |
| Pipeline (`telemetry-config-scan` §1–§7) | Pipeline validate + key diff + staged config, V208 (T + S); Loki labels V198 | `memory_limiter` first and `batch` last, retry and queue on, a trace-id load balancer, `structured_metadata` for ids, compactor retention with `delete_request_store`, Alloy for Promtail. Retention or a new component is STOP |
| Dashboards (§8) | `dashboard-linter` with the scoped rule set + `dash.py`, on the copy (T) | The board JSON or its generator: `$__rate_interval`, a provisioned datasource uid, units. Never a `.lint` exclusion added to pass |
| Logs (`log-signal-scan` §1–§5) | Captured log V189–V192 (U); fault injection V190 | The logger factory or wrapper: pino `error({ err }, msg)` or `error(err, msg)`, winston `format.errors({ stack: true })`, `logger.exception` / `exc_info`, a trailing SLF4J throwable; a warn log or a counter in the degrade path; `useLogger` + `bufferLogs`; `customLogLevel` (4xx ≤ warn, 5xx error, `THR-LOG-LEVEL`); `autoLogging.ignore` for probes |
| Correlation (§6–§8) | Captured log, two concurrent requests + one async hop, V193 (U) | `genReqId` honouring the incoming header and minting a unique id; CLS / AsyncLocalStorage or the id in the job payload; the log bridge for `trace_id` under its snake_case name |
| Tracing (`trace-propagation-scan` §1–§8) | In-memory span exporter V194–V196 (U); SIGTERM sink for §5 | Context wrapping at the executor or queue client (`BullMQOtel` on the Queue **and** the Worker), the instrumented client, `finally { span.end() }` + `recordException`, the preload before the framework import, `sdk.shutdown()` on SIGTERM, one propagator set, `service.name`. A span-attribute rename a dashboard reads is STOP |
| Sampling (§9–§10) | Resolved sampler + retained count, V197 (U) | `ParentBased` around the ratio; a tail policy on `status_code` or tracker capture beside the sampled trace. A rate change is STOP |
| Metrics (`metric-hygiene-scan` §1–§6) | Registry scrape V198–V200 (U) + `promtool check metrics` | The route template as the label (precedents § 29), seconds not milliseconds, a bucket at each SLO threshold, registration once at module scope. A rename, a removed label or a removed metric is STOP with its consumers listed |
| Health (§7–§8) | Dependency kill + probe hits, V201 (U) | Readiness checks each dependency the pod needs; liveness stays constant; probe paths excluded at the source. A liveness that checks a shared dependency is `/perf-fix`'s |
| Error tracking (`error-tracking-scan` §1–§4) | Tracker test transport, V202 (U; L for resolved frames) | `release` and `environment` from the deploy env, process hooks per process type, capture or `logger.error({ err })` at status ≥ 500 in the global filter, `sourcemap: 'hidden'` + upload + `filesToDeleteAfterUpload`. A new tracker SaaS is STOP |
| Synthetic coverage (`synthetic-monitoring` §1–§5) | The probe config read + routes test for the probe alert (S + T) | A probe per critical journey in the tool the repo already runs. A new SaaS or location is STOP |

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Observability-specific:
- The report being closed: its context map (versions and their sources, the Prometheus major, process types, rule surfaces and what loads them, the harness, the owners installed), the finding rows and their evidence.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/observability.md`](../../../snippets/precedents/observability.md), [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Observability (the oracle shapes and the *Class variants (observability)* V189–V208), and the owning skill's `## Proof`.
- The site end to end, the factory, helper, rule group, spec or chart it runs through, and **one sibling that does it right** (the shape to match). `.claude/rules/observability-principles.md`; `ai/patterns/` for structured logging, metrics, tracing and SLOs.
- The inventory every new name is grounded against: `alert-rule-lint`'s pre-flight step 2 (metric names in code), recording-rule outputs, exporter defaults, the logger's field names.
- The tool lanes: `TI=.claude/scripts/test-integrity.py`, `OC=.claude/scripts/oracle-check.py`, each falling back to `$HOME/.claude/templates/repo-baseline/.claude/scripts/<name>`; `.claude/skills/alert-rule-lint/scripts/rule-inventory.py`; `.claude/skills/slo-rule-scan/scripts/burn-check.py`; the pinned tool binaries each detector's § Tool lane downloads into `${TMPDIR}`.

## Phase 4 — Generate (the per-finding loop)

Run every step for each finding, in Phase-2 order. Do not start the next finding until this one's closure row is complete.

### 1. Re-verify, then reproduce — an oracle that FAILS on current code
**Re-verify.** Run the finding through `refute-before-report.md` with `precedents/observability.md`: restate the claim in its shape, run the seven gates as § Reading the seven gates for observability reads them, with the version line and the config production loads. **Refuted** → do not touch it; record the gate. **Unconfirmed** → its oracle first. **Finding** → reproduce it.

**Reproduce at the class's tier:**
- **Rules (T).** On a copy in `${TMPDIR}`, with the promtool of the server's major: one test that **must fire** at the failure point and one that **must stay silent** at a blip; for a ratio, a total-outage test where the traffic-absent sibling must fire; `exp_annotations` for AL-05. Routing: `amtool config routes test --verify.receivers=<the receiver the design names> <labels>` for every label set the rules emit. SLOs: regenerate from the committed spec and diff; `burn-check.py` with the registry's `--slo` map. Pipeline: the validator on the copy, plus the key diff, plus a staged config run where the class needs one (a 503-then-200 sink, two sampler replicas).
- **Code (U)** in a scratch worktree, through the real entry point: the captured log from the logger's real destination (pino `{ write }` with `fastify.inject`, nestjs-pino in the testing module with `useLogger` and `flushLogs`, `caplog`, slog into a buffer, `ListAppender`, `FakeLogger`); the in-memory span exporter across the hop against a real broker; the registry scrape after randomized ids, one known duration, one run per job, a stopped dependency; the tracker transport through the project's own init.
- The test must fail **on the oracle's assertion**, not on setup. Paste the failing line into the closure row. Name it after the class (`orders-retry.err-stack.e2e-spec.ts`, `api-short-window.blip.test.yml`). **No fix until the oracle fails.** Without a harness the row is `Probe (written, not run)` and the finding stays open; never claim a test that was not run.

### 2. Fix at the source
- Apply the Phase-2 primitive in the project's idiom, matching the correct sibling, at the **shared** root when there is one: the logger factory, the SDK bootstrap, the metrics helper, the rule-group template, the generator spec, the chart values. One fix closes every site.
- Generated rules are fixed in the spec or mixin and **regenerated** with the repo's own flags (precedents § 42), never edited by hand.
- Every name the fix introduces resolves in the inventory (precedents § 37). Every log line, span or metric the fix adds ships with the test that observes it.
- Every STOP line is put to the user first.

### 3. Green, across the class — all five
1. **The oracle passes** at the same tier, on the same server major.
2. **Every class variant passes** (`proof-oracles.md` § Observability, *Class variants*): V189 every logger factory and wrapper, not the one call site; V194 every hop kind and queue client the repo has; V203–V204 every rule surface and every page rule of the group; V206 every emitted {severity × team}; V207 every SLO spec and environment; V208 every collector, agent and gateway.
3. **The benign control stays silent.** The healthy path logs nothing at error; a 404 stays at warn or below (`THR-LOG-LEVEL`); the blip test stays silent; the sampler still keeps the parent's decision; the 404 sends no tracker event.
4. **No regression.** Every other rule the touched group or spec renders still passes its pair; `rule-inventory.py` and pint print nothing new for the touched files; series counts and log bytes per request do not grow unless the finding was about them.
5. **Every number is labelled measured**, with the tool and version that produced it.

If any of the five fails, the fix is wrong. Do not move on.

### 4. RE-DETECT (the owning detector and its tool on the diff)
Re-run the detector recorded in Phase 2 on the patched `<file:line>` and its surrounding diff, and its tool on the touched files: pint and promtool on a touched rule file, `burn-check.py` on a touched burn rule, the validator on a touched config. It must go quiet there and raise nothing new. A detector that still reports means the patch moved the symptom; reopen the finding.

### 5. Self-check the fix's own diff
The command does not grade its own honesty; the scripts do. On the diff from `FIX_BASE` to the working tree:

```bash
python3 "$TI" --base="$FIX_BASE" --json      # deleted test or case, fewer assertions, new skip/only/xfail, removed CI test step
python3 "$OC" --base="$FIX_BASE" --json      # no-assertion, weak-oracle, tautology in every case this fix added or touched
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^\+(?!\+\+)(?:\s*-?\s*(?:for|keep_firing_for):|.*(?:exp_alerts:\s*\[\s*\]|#\s*pint\s+(?:disable|snooze|ignore)|--lint=none|\bseverity:\s*["\x27]?(?:ticket|info|none|warning|low)\b|\breceiver:\s*["\x27]?(?:null|blackhole|devnull|dev-null)\b|\binhibit_rules:|\b(?:mute_)?time_intervals:|\bnotify_no_data\s*=\s*false|\bon_missing_data\b|\bnoDataState:\s*["\x27]?OK\b|\blevel:\s*["\x27]silent["\x27]|\benabled:\s*false|\bautoLogging:\s*false|\balways_off\b|\bOTEL_SDK_DISABLED\b|(?:sampleRate|tracesSampleRate|traces_sample_rate|OTEL_TRACES_SAMPLER_ARG|ratio)\s*[:=]\s*["\x27]?0(?:\.0+)?(?![.\d])|\bignoreErrors\s*:|\baction:\s*["\x27]?(?:drop|labeldrop)\b|\b(?:jest|vi)\.mock\([^)]*(?:pino|logger|winston|@opentelemetry|@sentry|prom-client)|#\s*noqa:\s*(?:G00\d|TRY40\d|T201|LOG\d+)|//\s*nolint:\s*(?:sloglint|spancheck|contextcheck|loggercheck)|#pragma\s+warning\s+disable\s+CA(?:2254|2017|1848)|eslint-disable[^\n]*no-console))'
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^-(?!--)(?:\s*-?\s*(?:alert|record):\s*\S|.*\b(?:exp_alerts|alert_rule_test|promql_expr_test):|.*(?:\bname\s*:\s*["\x27][a-z_:][\w:.]*["\x27]|\blabelNames\b|\bWithLabelValues\(|\bOpts\s*\{))'
git diff --name-only "$FIX_BASE" | rg -n --pcre2 '(?:alertmanager|sloth|pyrra|openslo|(?:^|/)slos?/|loki|promtail|alloy|collector|otel|fluent-bit|vector)[^\n]*\.(?:ya?ml|alloy|river|conf)$|values[^/]*\.ya?ml$|(?:^|/)prometheus\.ya?ml$|\.tf$|(?:^|/)slos\.md$'
```

- **Either script exits 1 → the finding does not close.** Rework the fix so nothing is net-removed, or put the row to the user as a STOP item; until approved it stays `escalated (integrity: <kind> <file:line>)`. Exit 2 is a failed lane: `self-check: blocked`, never clean.
- **Every line the silencing grep prints** is read in context and either cited as legitimate in the closure row — a `for:` within `THR-OBS-ALERT` on a non-burn rule, a new ticket-tier alert that adds a tier rather than demoting a page, `enabled: false` on an unrelated feature flag — or the hunk is reverted. A severity, receiver, inhibition or no-data line on an **existing** alert is a STOP line: it needs the user's recorded yes.
- **Every line the removal grep prints** is a deleted rule, a deleted rule test, or a renamed metric, label or name: each needs its STOP approval with the consumer list, or the hunk is reverted.
- **Every file the last line prints** is a paging, SLO, pipeline, retention or chart surface: the closure row cites the STOP approval for its hunk, or shows the hunk crosses no STOP line.
- Without the repo-baseline scripts, read `git diff -U0 "$FIX_BASE"` for removed assertions and added skips, run the three greps, and mark the row `self-check: inline (repo-baseline scripts absent)`.

### 6. Sweep for siblings
State the root cause in one line (`refute-before-report.md § 6`): "the shared logger façade interpolates `String(error)` into the message", "every BullMQ queue is built by one factory with no telemetry", "the rule template writes `[30s]` for every job", "the chart values set no `customLogLevel`" — not "orders logs badly". Grep it with the owning detector's pre-flight line narrowed to that cause, and run each hit back through Step 1. Each confirmed hit is **fixed**, **explained** (one line, or Refuted by a named gate), or **followup** (its own id). `N_found == N_fixed + N_explained + N_followup` must hold.

### 7. The security canary (every fix that touches a logger, serializer, redaction, tracker init or sink)
The redaction variant list is security's ([`proof-oracles.md`](../../../snippets/proof-oracles.md) § Observability cites `data-exposure-scan` § 6; it is not restated here). After any such fix, re-run that canary: seed a canary secret (an `Authorization` bearer, a `password` field, a token in the query string) through the same captured-log, exporter or transport test and assert it is absent from every byte the sink received. **With the security pack installed**, run `data-exposure-scan` § 6 on the touched files and route any new row to `/security-fix`. **Without it**, run the seeded canary here and tag the row `canary: inline (owner pack security not installed)`. A canary that appears closes nothing: the fix widened what the logger writes, and it is reworked.

### 8. Suites and tool checks (after the last finding)
Run the project's tests (through `bash .claude/hooks/test-lane.sh run '<cmd>'` when the repo-baseline is installed), the typecheck and the lint at its CI level; then, on copies, `promtool check rules` and every `promtool test rules` file, `amtool check-config`, `otelcol-contrib validate`, `alloy validate`, `loki -verify-config` over every touched file, each with the binary of the deployed major. Red here reopens the finding whose change it traces to.

### Commit (one finding = one commit, only where the repo allows it)
Read the convention first (recent `git log`, a protected or PR-only branch, a no-commit rule in `CLAUDE.md` or `CONTRIBUTING`). Where commits are allowed: `fix(obs): <what on-call could not see or was not paged for> — <finding id>`, for example `fix(obs): payment retry errors were logged without their stack — O-02`. Otherwise **leave the change staged and say so**.

## Phase 5 — Update
- Update `ai/audits/<date>-observability*.md` in place, or write a `-fix.md` companion: mark each finding and append the closure table.
- `ai/dynamic/changelog.md`: `Observability fix on <scope>: C closed, S staged, N no-data (L-tier, re-run owed), E escalated, D deferred`.
- `ai/status.md` `## Recent Changes`: one bullet per STOP decision still owed (an objective, a receiver, a rename and its consumers, a sampling or retention change).

### Closure table (required artifact)
```
| Finding | Class (detector §)            | Tier | Oracle: before → after                        | Variants  | Self-check (TI · OC · grep · rm · files) | RE-DETECT     | Canary       | State                          |
|---------|-------------------------------|------|-----------------------------------------------|-----------|------------------------------------------|---------------|--------------|--------------------------------|
| O-01    | window vs scrape (arl §5)     | T    | promtool 3.15.0 sustained 503: [] → fires     | V204 4/4  | 0 · 0 · 0 · 0 · 0                        | quiet + pint  | —            | <sha> fix(obs)                 |
| O-02    | stack lost (lss §2)           | U    | captured log: no err.stack → type + stack     | V189 35/35| 0 · 0 · 0 · 0 · 0                        | quiet         | absent (§ 6) | staged (PR-only)               |
| O-04    | never fires (arl §4 AL-10)    | T+L  | selector grounded; live count NO-DATA         | V204 2/2  | 0 · 0 · 0 · 0 · 0                        | quiet         | —            | NO-DATA → re-run count() (L)   |
| O-06    | routing (arl §8 AM-01)        | T    | routes matrix: dev-null → (proposed) pager    | —         | —                                        | —             | —            | escalated: STOP who gets paged |
```
A finding with no failing-first proof at its tier, a variant not run, a benign control that fired, a self-check that flagged, a canary that appeared, or a RE-DETECT that is not `quiet` is **not** closed. An L-tier row reads `NO-DATA → <command>`, never closed.

## Phase 6 — Validate
- Each closed finding has a failing-first proof at its tier on the deployed major, a green run of every variant, a silent benign control, a clean self-check, a quiet RE-DETECT, the canary where Step 7 applies, a balanced sibling ledger and green suites and tool checks.
- **Re-run `/obs-audit` on the touched scope** (with the same `--classes`). The verdict must not regress, and each first-pass finding must no longer reproduce at its `<file:line>`.
- No objective, period, receiver, route, existing severity, consumed name, sampling rate or retention changed without the user's yes; no generated file edited by hand; no name introduced that the inventory does not hold.

## Phase 7 — Improve
- `/learn-from-task`: record each closed class and the primitive that closed it.
- A class seen in two audits gets an ADR in `ai/decisions/` and its mechanical guard: the rules gate in CI with the promtool fire/blip test kept beside each page rule, `burn-check.py` and regenerate-and-diff in CI, a routes test per emitted label set, the captured-log test per logger factory, the exporter test across each queue hop, the linter rule at error.

## Output format
```
## /obs-fix — <N closed · M staged · L no-data (L-tier) · E escalated · K deferred>
Input:  ai/audits/<date>-observability.md  (findings: <total>; routed: /security-fix <s>, /quality-fix <q>, /perf-fix <p>)
Versions: Prometheus 3.5.0 (deploy/k8s/prometheus.yaml:7) → promtool 3.15.0 · Alertmanager 0.28.1 · nestjs-pino 5.1.0 · pino 10.3.1
Order:  MUST FIX (<c>: T <t>, U <u>) → SHOULD FIX (<m>) → OPTIONAL (<l>)
Closure table: (Phase 5 — one row per finding)
Escalated (decision owed):
  - O-06  pyrra emits severity=critical; the routes match only page — route critical to pager? (matrix before/after attached)
  - O-09  http_request_duration_ms → _seconds: 3 dashboards and 2 recording rules read the old name — rename now and migrate them?
Suite: jest PASS · promtool check/test rules (3.15.0) PASS · amtool check-config PASS · otelcol validate PASS
Re-audit: /obs-audit on touched scope → verdict <was → now>, no regression
Status: COMPLETE | INCOMPLETE  (COMPLETE only when every MUST-FIX finding is closed, escalated or NO-DATA with its command, the self-check is clean and the re-audit did not regress)
```

## What to do next — required closing section
Every run ends with `## What to do next`: the remaining work as ONE ordered, numbered to-do. **MUST FIX** (open or escalated BLOCKER and HIGH) first, then **SHOULD FIX**, then **OPTIONAL**. Each step carries `<file:line>` (the alert name for a rule), the **Fix**, and the **Verify** (the oracle, its tier and V-number). An escalated item names the decision the user owes: the objective and its owner, the receiver and the label sets it would page, the rename and every consumer, the sampling or retention change and its cost. A `NO-DATA` item names the live query and the `--live` source that settles it. The closing steps are: re-run `/obs-audit` to confirm the verdict, `/learn-from-task`, then ship or open the PR. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **Green by silencing.** A page demoted, a `for` raised, `exp_alerts: []`, a silent logger, `always_off`: the detector goes quiet and on-call goes blind. Step 5 refuses them.
- **A mocked series as proof.** A promtool test that passes proves the rule logic, never that the metric exists (precedents § 16).
- **The wrong promtool.** A 2.x test passing for a 3.x server, or the reverse.
- **The generated file fixed.** A hand edit to sloth or Pyrra output that the next generate erases.
- **One call site fixed, the factory left.** Thirty-five sites share one façade; the fix goes there.
- **A STOP line crossed quietly:** a receiver, a severity, an objective, a consumed name, a sampling rate changed as "just the fix".
- **Committing against repo policy.** On a PR-only branch, leave the change staged and say so.

## Related

### Sibling commands
- `/obs-audit`: the producer. Without a report the refuse-to-run gate halts.
- `/alert-design`, `/add-telemetry`, `/add-metrics`, `/add-tracing` (this pack): new alerts, SLOs and instrumentation. `/security-fix` (security pack, when installed): redaction and secrets. `/quality-fix` (code-quality, when installed): swallowed errors. `/perf-fix` (performance, when installed): liveness on a shared dependency. `/fix-bug`: the general discipline ([`fix-bug-core.md`](../../../snippets/fix-bug-core.md)).

### Detector skills (re-run for RE-DETECT)
This pack: `log-signal-scan` · `trace-propagation-scan` · `metric-hygiene-scan` · `error-tracking-scan` · `alert-rule-lint` (`scripts/rule-inventory.py`) · `slo-rule-scan` (`scripts/burn-check.py`) · `telemetry-config-scan` · `synthetic-monitoring`. Security (when installed): `data-exposure-scan` § 6 (the Step-7 canary).

### Agents
`@observability-reviewer` (this pack; the judge, refute mode) · `@verifier` (repo-baseline, mode `refute`) · `@sre-engineer` (this pack; the budget policy an objective change needs).

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/observability.md`](../../../snippets/precedents/observability.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Observability · [`fix-bug-core.md`](../../../snippets/fix-bug-core.md) · [`review-action-plan.md`](../../../snippets/review-action-plan.md)
