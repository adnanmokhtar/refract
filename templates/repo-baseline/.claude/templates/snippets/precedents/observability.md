# Precedents — observability (logs, correlation, traces, sampling, metrics, health, error tracking, alert rules, routing, vendor monitors, SLOs, telemetry pipeline, dashboards)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10 for
every candidate an observability detector raises: a signal that will fail on-call during a real
incident — absent, dropping the error, never firing, firing on a blip, paging the wrong receiver,
unqueryable or dropped in the pipeline. The detectors are `log-signal-scan`,
`trace-propagation-scan`, `metric-hygiene-scan`, `error-tracking-scan`, `alert-rule-lint`,
`slo-rule-scan` and `telemetry-config-scan` (observability pack), judged by
`@observability-reviewer`; `alert-audit` and `slo-audit` keep the behavioural half. The oracles are
in [`proof-oracles.md`](../proof-oracles.md) § Observability (V189–V208). The three cross-domain
precedents are in `refute-before-report.md § 4`; a dropped or swallowed error is
[`code-quality.md`](code-quality.md)'s.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so); the flip
evidence makes it a candidate again. A precedent applies only when its "must be true" clause is
shown with a `file:line`, a lockfile or image-tag line, or a tool row. Numbers are stable: detectors
cite `precedents/observability.md § <n>`. Posting rules are lettered (P1–P4) so they never take a
number.

Index: the claim and the gates · posting rules P1–P4 · alerts and routing § 1–17 · logs, traces and
metrics § 18–35 · verdict discipline § 36–37 · detector precedents § 38–44 · version and tool
precedents § 45–53 · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that cannot fill every bracket is not a finding.

> When **[the condition that really occurs — a dependency 5xx, a queue redelivery, a total outage at
> zero traffic, a 404 flood, a SIGTERM]** reaches **[the entry point — route, consumer, cron, rule
> evaluation, route tree, collector pipeline]**, **[the signal at file:line — log call, metric
> registration, span, rule, route, pipeline component]** **[is absent / drops the error / can never
> fire / fires on a blip / pages the wrong receiver / is unqueryable / is dropped]**, so on-call
> **[cannot see / cannot diagnose / is not paged / is paged for nothing]**, proven by **[the oracle
> and its tier]**.

**Oracle tiers.** T = a tool's exit code (promtool, pint, amtool, otelcol, sloth, pyrra, alloy,
loki, dashboard-linter, a linter rule id); U = a test with log capture, an in-memory span exporter,
the metrics registry or a tracker test transport; L = a live backend query (TSDB, alert history,
`logcli`, tracker API); S = a static trace. **An L-tier class with no reachable backend prints
`NO-DATA(<source>)`** and is never `checked`; its static half (inventory grounding) still runs and
still reports. A Finding needs its oracle to fire (T or U), or a two-ended static trace for a
static-fact class — a rule never loaded, `$value` in labels, a selector proven absent from the
inventory (marked `[report-flagged]` until the live check).

**The unit.** Alert classes are judged per rule (name + file:line), never per file. Code classes are
judged per call site, grouped by wrapper or factory: a defect in a logger factory, a metrics helper
or a tracing decorator is one finding with N sites.

## Reading the seven gates for observability

| Gate | Observability |
|---|---|
| 1 Reachability | The path runs in production (a route, consumer, cron or worker the process type starts); the rule file is loaded — matched by a `rule_files` glob, or selected by the Prometheus CR `ruleSelector`. An unloaded rule is AL-22's candidate, never dismissed |
| 2 Trigger condition | The failure the signal would reveal occurs: the dependency can fail, the queue redelivers, traffic can drop to zero, the process receives SIGTERM |
| 3 Version | The Prometheus and Alertmanager versions (compose image, Helm values, chart), pint, the logger and SDK majors (pino, pino-http, nestjs-pino, winston, OTel per language, Sentry, dd-trace), the semconv opt-in and Promtail vs Alloy — read from files, printed in the header. A Prom-3-only class on an unread version is Unconfirmed |
| 4 No existing control | Auto-instrumentation, a global filter or exception handler that logs or captures, a custom serializer, generator-emitted absent rules, a routes test, the Java agent |
| 5 Real impact | An incident that cannot be seen, diagnosed or paged, or a page for nothing. "Best practice" alone fails here |
| 6 Proof | T / U / L / S as above (`proof-oracles.md` § Observability), failing first |
| 7 Deployment | The backend actually wired, and which config the production process loads (compose, Helm values, the manifest the deploy applies) |

## Do not flag — posting rules the verifier applies

- **P1 Pre-existing lines.** On a diff run, a defect on lines the change neither touched nor copied is Pre-existing (`refute-before-report.md § 5`).
- **P2 A class another pack owns** is routed and never posted here: a secret or PII value in any sink, a redaction gap and `sendDefaultPii` / `dataCollection` (security `data-exposure-scan` § 6); log injection (security `injection-scan`); public health details (`data-exposure-scan` § 3); publicly served source maps (security `xss-scan` § 13); notification secrets inline (security `secret-scan`); a dropped or swallowed error (code-quality `error-handling-scan`); liveness on a shared dependency (performance `request-path-scan` § 15); probe presence and shape in manifests, collector RBAC, PrometheusRule schema (infrastructure `@k8s-reviewer`). Each applies when that pack is installed; without it the row is tagged `<class> (owner pack not installed)`, listed and never graded.
- **P3 What a configured linter already fails in CI at error level** (ruff `G`/`LOG`/`TRY400`, golangci `sloglint`/`spancheck`, the .NET CA rules, ESLint `no-console`, pint in CI). The finding, if any, is that the rule is off, at warning, suppressed or not run (posting bar § 2).
- **P4 Duplicates.** One finding per wrapper, factory, rule group or config file: N call sites of one logger wrapper, or N rules generated from one template, are one finding with N sites.

## Not a finding — alerts and routing

1. **A missing `runbook_url` on a ticket or info alert.** Mixins mandate `summary` / `description`, not `runbook_url`, and info is usually unrouted. *Flips back:* the alert pages.
2. **No `for:` on a Watchdog `vector(1)` or on a multiwindow burn rule** (the short window debounces). *Flips back:* a single-window or plain threshold rule. Whether the Workbook and sloth burn rules omit `for` by intent is [K?].
3. **A `for` of hours on batch staleness**, set at two or more run cycles.
4. **A cause-based page that is definite and imminent:** `predict_linear` disk-full within hours, a certificate expiring before the next business day, quorum loss. CPU over 80 % is never this.
5. **A NaN-on-zero-traffic error ratio** when a sibling traffic-absent or zero-traffic alert exists for the same job (pint `promql/nan`).
6. **A rate window of 2–4× the scrape interval** is style, not a bug. *Flips back:* under 2× is a bug, and exactly 1× is empty on Prometheus 3 (§ 45).
7. **Deprecated `match` / `match_re`** in Alertmanager is Low; never bundle it with a routing defect.
8. **`group_by: ['...']` on a self-deduping webhook receiver.** *Flips back:* a pager or Slack route.
9. **A null root receiver**, when routes tests with `--verify.receivers` prove every emitted {severity × team} label set reaches a real receiver.
10. **Datadog `notify_no_data` / `on_missing_data` left at the default on an error-count monitor** — empty means zero errors, which is right. *Flips back:* a traffic or heartbeat monitor.
11. **Grafana "Keep last state"** with a companion rule for prolonged datasource loss.
12. **Burn factors 14 / 7 / 2 / 1 (Pyrra) and an extra 3× 24h/2h ticket tier** (the Workbook's final rule, sloth `google-30d`) are correct. A 28d period giving 13.44 instead of 14.4 is a note, not a bug. *Flips back:* the factor fails `budget_fraction × period / long_window` for the declared objective and period (`THR-OBS-BURN`). The literal `14` vs `14.4` is never the test.
13. **Counting 4xx as good** is the Workbook's convention. *Flips back:* the team documents a 4xx class (a self-shed 429) as a server failure and the SLI omits it.
14. **A 100 % SLO is always a finding. 99.999 %** is a finding only when the design relies on burn-rate pages (at 99.999 % over 30d an outage burns the budget in about 26 s).
15. **A low-traffic service paging on one error** is a design issue (synthetic traffic, grouping, a longer window), not a rule bug.
16. **A promtool unit test with mocked series does not prove a metric exists.** Never accept it as AL-10 evidence; pair it with inventory grounding and, when a backend is reachable, a live series check (Cloudflare, *Monitoring our monitoring*, 2022-05-19).
17. **Integer `le="1"` and `[1m:1m]` subqueries are clean on a Prometheus 2 server.** Read the version (gate 3) before reporting AL-21.

## Not a finding — logs, traces and metrics

18. **Health and readiness endpoints excluded from tracing, access logs and SLIs** is correct. *Flips back:* the SLI then has no synthetic probe at all.
19. **A high-cardinality field** (`user_id`, `trace_id`, `order_id`) is correct in a log line, a span attribute or a wide event. It is a defect as a Prometheus label or a Loki label. The PII policy on its *value* is security's (P2).
20. **`trace_id` as an exemplar** is the correct pattern; as a label it is MT-02.
21. **`tenant_id` as a metric label** is neither approved nor rejected without the series arithmetic (∏ distinct values × replicas against `THR-OBS-CARDINALITY`).
22. **pino `logger.error(err, 'msg')` and `logger.error({ err }, 'msg')` are correct.** `{ error: err }` is correct only when a custom `error` serializer is configured: grep `serializers` before flagging.
23. **SLF4J `log.error("failed for {}", id, e)`** (a trailing throwable) keeps the stack. `"failed {}", e` filling the only placeholder is [K?]: test it before flagging.
24. **Python `logger.error(..., exc_info=True)`** is equivalent to `logger.exception`; ruff G201 is style only.
25. **Python `start_as_current_span`** records the exception and sets ERROR by default: a missing `record_exception` there is not TR-04 [K].
26. **Go `context.WithoutCancel(ctx)`** keeps trace values on detached work; it is not TR-01 [K].
27. **.NET `Task.Run` and `new Thread` flow `Activity.Current`;** only `UnsafeQueueUserWorkItem` and `ExecutionContext.SuppressFlow` break it [K].
28. **The Java agent instruments executors and injects MDC trace ids.** With `-javaagent:` present in the runtime config (Dockerfile, `JAVA_TOOL_OPTIONS`, the manifest), the Java rows of TR-01 and CO-03 close [K].
29. **A route-template label** (`req.route.path`, Fastify `request.routeOptions.url`, chi `RoutePattern()`, Spring's templated `uri`) is bounded; only the raw path or URL is MT-01.
30. **A debug level in a dev, staging or override config is noise.** Only the file the production process loads counts; prove which one it loads (gate 7).
31. **Audit logs must not be sampled or dropped;** sampling and volume advice never applies to an audit-log stream sent to its own sink with a retention policy.
32. **Hashing an email or id is not anonymization** (small input spaces reverse). It is a security question: cite `data-exposure-scan` § 6 and stop; never prescribe a hash as redaction.
33. **`tracesSampleRate: 1.0` with a per-route `tracesSampler`, or in a non-production config, or on a low-RPS service with a stated budget,** is not SA-03.
34. **A crash dump, HAR export or support bundle is a telemetry sink.** A redaction fix that skips them is partial (security's verdict, P2).
35. **Telemetry agents are production code:** canary rollout, overload limits and capped fail-open apply to collectors and DaemonSets. An uncapped fail-open forwarder is a finding, not an ops detail (OpenAI status 2024-12-11; Cloudflare 2024-11-26).

## Verdict discipline

36. **"Noisy", "dead" and "flapping" are behavioural.** Without fire history or a pager export the verdict is `NO-DATA(<source>)`, never an estimate. The same holds for cardinality, retention and never-fire claims that only a backend can settle.
37. **A metric, label or field name that appears in no repo file and no live series is fabricated.** A finding or a *proposed* query or rule that names one is **Refuted** (the anchoring rule of `refute-before-report.md` § 1). Ground every name against the inventory: metric names registered in code, recording-rule outputs, exporter defaults (`process_`, `nodejs_`, `go_`, `http_server_*`) and the logger's field names.

## Detector precedents (added 2026-10-10)

38. **Nest `Logger.error(message, err.stack)` keeps the stack.** The second argument is the trace; it is not LG-02.
39. **A catch that rethrows with `{ cause: e }` to a global filter that logs the cause** is not LG-02 at the inner site. Two logs of one error (inner site and filter) is LG-04, not LG-02. *Must be true:* the filter's log call carries the cause or the stack.
40. **Fastify `request.log` and nestjs-pino `PinoLogger` are request-bound.** Jobs, consumers and cron are not: a BullMQ processor or an `@Cron` handler needs CLS (`nestjs-cls`, `AsyncLocalStorage`) or an explicit id in the job payload, or it is CO-02.
41. **Prometheus group-level `labels:`** count toward a rule's labels on a server version that supports them. The minimum version is [K?]: read the server version, and where it is unsupported the group label does not count.
42. **Generated rules** (sloth, pyrra, jsonnet mixins) are judged at their spec. A finding on the generated file is a drift finding (regenerate and diff), never a hand-edit request.
43. **OTel → Prometheus name translation adds unit and `_total` suffixes.** Ground the translated name, not the OTel instrument name; the exact suffixing depends on the server's `translation_strategy` [K?].
44. **`process.exit` / `os.Exit` in a CLI or a one-shot migration script** is not LG-06. *Flips back:* the same call in a server, worker or consumer process after a log or span it expects to ship.

## Version and tool precedents — read the installed version before reporting

45. **Prometheus 3 changed what selects** (Prometheus *Migration to v3* guide, as read for the research catalog 2026-10-10): `le` and `quantile` label values are normalized to floats, so `le="1"` now matches nothing (`"1.0"`); range selectors are left-open, so a window of exactly 1× the scrape interval and `[1m:1m]` subqueries return nothing; regex `.` matches newlines; `holt_winters` is `double_exponential_smoothing` behind a feature flag; Alertmanager API v1 is gone. Each is a finding only on a server proven to run 3.x (§ 17).
46. **Semantic conventions:** deprecated `http.*` / `db.*` names (`http.url`, `http.method`, `http.status_code`, `db.statement`, `deployment.environment`) fail silently as empty views. `OTEL_SEMCONV_STABILITY_OPT_IN=http/dup` (or `database/dup`) is the declared dual-emit window, not TR-08.
47. **Sentry JS v10 deprecated `sendDefaultPii` in favour of `dataCollection`** (Sentry JS options page, as read for the research catalog 2026-10-10). A detector greps both spellings; the verdict is security's (P2).
48. **dd-trace-py 3.0 removed `DD_TRACE_SAMPLE_RATE`;** use `DD_TRACE_SAMPLING_RULES` (dd-trace-py v3.0.0 release notes). Other Datadog tracers still read it: gate the row on the tracer.
49. **sentry-cli 3.0.0 (2025-12-15) removed `sourcemaps explain`.** The settling commands are `sourcemaps inject` + `upload` and, for native files, `debug-files check`; a proof that names `explain` is a proof defect.
50. **.NET 10: CA1848 is off by default.** A clean build log is not evidence that `LoggerMessage` is used; read the `.editorconfig` severity first.
51. **Promtail reached end of life on 2026-03-02;** Alloy replaces it (`alloy convert --source-format=promtail`). Promtail in a config or image tag is PL-05 on any version.
52. **Node logger behaviour, measured** (pino 10.4.0, pino-http 11.0.0, winston 3.19.0, run 2026-10-10): pino `logger.error('failed', err)` drops the error entirely; `logger.error({ error: err })` serializes it as `{}` without a custom serializer; `logger.error(err.message)` loses the stack. pino-http logs every request header and the full query string by default, and its default request id is a per-process counter, so ids collide across replicas without `genReqId`. winston without `format.errors({ stack: true })` turns `logger.error(err)` into `{"level":"error"}`. Re-run the captured-log oracle (V189) on the installed versions before citing these as fact for a different major.
53. **Tool exit codes are read, never assumed:** promtool exits 1 on error and 3 on lint, and `check rules` exits 3 on duplicates only with `--lint-fatal`; `amtool config routes test` without `--verify.receivers` always exits 0, so it is not a test; `otelcol validate` passes defined-but-unused components and does not check processor order; `pint`, `mimirtool rules lint` (without `-n`) and `lokitool rules lint` rewrite files in place and never run in the project tree; pint has no `promql/performance` check.

## Rationalizations to reject (observability)

**Wrongly accepting:** "the alert has been quiet, so it works" (an empty query looks exactly like
healthy) · "promtool test passes, so the metric exists" (§ 16) · "we log the message, the stack is in
Sentry" (show the tracker capture on that path) · "head sampling at 10 % keeps errors" (a head
sampler decides before the outcome is known) · "it's in a catch, so it's handled" (handled but
invisible is LG-01) · "the rule file is in the repo" (is it loaded?) · "the dashboard shows it" (from
which metric name, and does it exist?).

**Wrongly dismissing:** "`14` is close enough to `14.4`" and its mirror "`14` is wrong" — run the
arithmetic (§ 12) · "auto-instrumentation covers it" (for this client, at this version?) · "it's only
a dev config" (which file does production load?) · "the counter resets break `rate()`" (they do not;
`rate()` compensates) · "Pyrra's factors are non-standard" (§ 12) · "no backend, so no finding" (the
static half still reports; the live half is `NO-DATA`, never clean).

---

Sources: the observability research catalog and its batch eval (both 2026-10-10), which cite the
Prometheus docs (promtool, unit testing, migration to v3, naming, alerting practices, Alertmanager
configuration), cloudflare/pint 0.89.2 docs, the Google SRE Workbook *Alerting on SLOs* (re-fetched
2026-10-10; CC BY-NC-ND, paraphrased), sloth 0.16.0 `google-30d` and pyrra 0.10.2 `slo/rules.go`,
OpenTelemetry sampling, sensitive-data and semantic-conventions pages, the sentry-cli changelog,
dd-trace-py v3.0.0 release notes, Grafana Loki/Alloy docs, the .NET 10 CA docs, local runs of pino
10.4.0, pino-http 11.0.0 and winston 3.19.0, the Cloudflare blog of 2022-05-19 and the incident
records of 2024. Paraphrased; no text reproduced beyond short quoted identifiers.
