# Seeded defects — `obs-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Harbor` — NestJS 11 / Fastify 5 API with nestjs-pino, a BullMQ + winston worker, React/Vite storefront and admin, FastAPI + Celery, Go, Spring Boot, plus Prometheus/Alertmanager/Loki/Alloy/collector/Grafana/SLO config.
Log fidelity, correlation, trace propagation and sampling, metric hygiene and health, error tracking, alert rules and
routing, vendor monitors, SLO definitions, telemetry pipeline and dashboards, burn coverage and synthetic coverage —
seeded across six code roots and `deploy/`, plus decoys: correct siblings that look like a seeded defect and must NOT
be reported.

Invocation: /obs-audit --whole-repo
Invocation[/security-audit]: /security-audit
Invocation[/quality-audit]: /quality-audit --whole-repo
Invocation[/perf-audit]: /perf-audit --whole-repo
Stage with: --git — `/obs-audit` reads the history for its context map, and a whole-repo run on a copy with no base
branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 4, item 23 (`eval-batch4-observability.md` § 3.6). Classes follow the owning skills' own
§ numbering (`templates/packs/observability/skills/*/SKILL.md`). Roots: `api/` (NestJS 11.2.7 on
`@nestjs/platform-fastify`, nestjs-pino 5.3.1, pino 10.4.0, pino-http 11.0.0, MikroORM 6.4.5, prom-client 15, OTel
`sdk-node`, BullMQ producer, terminus), `worker/` (Nest application context, BullMQ consumer, winston 3.19.0,
`@nestjs/schedule`), `web/` and `admin/` (React 19 + Vite + `@sentry/react` 10), `py-svc/` (FastAPI, structlog, Celery,
`prometheus_client`, OTel, `sentry-sdk`), `go-svc/` (zap, otelhttp, client_golang), `jvm-svc/` (Spring Boot 4,
Logback, Micrometer + Micrometer Tracing), and `deploy/` (compose production host with Prometheus v3.5.0, Alertmanager
v0.34.1, Loki 3.7.8, Promtail, Alloy, Grafana; Kubernetes worker + collector gateway, Prometheus CR, PrometheusRules,
ServiceMonitors; sloth, Pyrra and OpenSLO specs with generated rules; Datadog and New Relic monitors). The SLO registry
is `ai/runtime/slos.md`; ADRs are under `docs/adr/`.

Departures from the eval, stated so a reader can audit them:
- **The eval's "no Watchdog" §6 seed is dropped**: decoy 11 (a Watchdog `vector(1)` with no `for`) needs a Watchdog in
  the tree. AL §6 keeps two seeds. **Added:** `admin/` (a second Vite app, so ET §3 can seed a release mismatch
  *without* debug IDs — with debug IDs the eval's shape is only Hardening), OD-AL-03b (`rate(sum(…))`), OD-AL-02d
  (the Pyrra pages carry no runbook — a real defect of the generated file, seeded rather than left as noise),
  OD-AL-09c (New Relic `fill_option`), OD-MT-01d (Micrometer `Tag.of("uri", getRequestURI())`), OD-MT-02c (an asyncpg
  pool with no USE gauge, which the §2 grep surfaced), OD-SLO-05b (Go `DefBuckets` vs `le="0.2"`), and two
  `alert-audit` §5 rows. The eval's table sums to 120 + 6; this key holds 126 + 6.
- **The SLO §2 burn seed is a real mismatch** (coordinator correction): `14.4 * (1 - 0.99)` on a 99.9 % registry SLO.
  The eval's `14 * (1 - 0.999)` 1h/5m on 30d is only a precedents § 12 note under `burn-check.py` (1.94 % vs 2 %).
- **Telemetry §6's second seed** is an unexpanded `${LOKI_BUCKET}` (the eval's "audit-log stream 7d" is
  `audit-logging`'s class, precedents § 31); **§2's** is an explicit `sending_queue: { enabled: false }` (the pre-flight
  prints explicit switches, not an absent key).
- **Postgres and Redis are managed services**, outside `deploy/` (the compose header says so), so the compose host
  carries no database to back up; that keeps infrastructure `dr-audit` and devops backup classes out of this key.

Ownership and scoring. Every row names the detector § that owns it. Four runs, four results rows, each staged in its own
copy. **`/obs-audit`** (the `Invocation:` line) scores the 126 observability rows: a whole-repo run dispatches every
observability detector plus `alert-audit`, `slo-audit --no-write` and `synthetic-monitoring`. The six `OD-HO-*`
hand-off rows are scored **only under their owner** — `/security-audit` (3: `data-exposure-scan` § 6),
`/quality-audit` (2: `error-handling-scan` §1), `/perf-audit` (1: `request-path-scan` §15) — and `/obs-audit` must list
each as a routed row, never grade it; an `/obs-audit` finding on them is UNMATCHED, not credited.

Secrets. None. The Sentry DSNs are public ingest keys (error-tracking-scan § Boundaries), every notification
credential is a `*_file` path, and the webhook and partner tokens are header *names*.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it. The
generated rule files (`deploy/slo/generated/api.yml`, `deploy/slo/pyrra/generated/api-latency.yaml`) are written in
the generators' output shapes the skills measured (sloth 0.16.0, pyrra 0.10.2) and were not produced by the binaries.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| OD-LG-01a | `api/src/pricing/price.service.ts:24` | medium | `/obs-audit` | logs/handled-failure-invisible |
| OD-LG-01b | `py-svc/app/payments.py:17` | high | `/obs-audit` | logs/handled-failure-invisible |
| OD-LG-02a | `api/src/payments/capture.service.ts:23` | high | `/obs-audit` | logs/error-object-dropped |
| OD-LG-02b | `api/src/orders/refund.service.ts:19` | high | `/obs-audit` | logs/error-object-dropped |
| OD-LG-02c | `api/src/webhooks/carrier-webhook.service.ts:24` | medium | `/obs-audit` | logs/stack-lost-message-only |
| OD-LG-02d | `api/src/catalog/catalog-sync.service.ts:19` | medium | `/obs-audit` | logs/stack-lost-stringified |
| OD-LG-02e | `worker/src/logger.ts:10` | high | `/obs-audit` | logs/winston-no-format-errors |
| OD-LG-02f | `go-svc/internal/inventory/handler.go:45` | medium | `/obs-audit` | logs/error-as-string-field |
| OD-LG-02g | `jvm-svc/src/main/java/com/harbor/refunds/RefundService.java:33` | high | `/obs-audit` | logs/stack-lost-concatenation |
| OD-LG-03a | `api/src/main.ts:17` | low | `/obs-audit` | logs/nest-bootstrap-no-logger-handoff |
| OD-LG-03b | `api/src/app.module.ts:25` | low | `/obs-audit` | logs/pretty-transport-in-production |
| OD-LG-03c | `py-svc/app/orders.py:18` | low | `/obs-audit` | logs/interpolated-message |
| OD-LG-04a | `api/src/common/http-exception.filter.ts:15` | medium | `/obs-audit` | logs/4xx-at-error |
| OD-LG-04b | `api/src/app.module.ts:22` | medium | `/obs-audit` | logs/request-log-no-level-map |
| OD-LG-04c | `deploy/k8s/worker-configmap.yaml:7` | medium | `/obs-audit` | logs/debug-in-production-config |
| OD-LG-05a | `api/src/catalog/import.service.ts:18` | medium | `/obs-audit` | logs/payload-per-item-in-loop |
| OD-LG-05b | `api/src/app.module.ts:21` | low | `/obs-audit` | logs/probe-requests-logged |
| OD-LG-06a | `api/src/app.module.ts:20` | medium | `/obs-audit` | correlation/request-id-per-process-counter |
| OD-LG-06b | `api/src/main.ts:12` | medium | `/obs-audit` | correlation/request-id-per-process-counter |
| OD-LG-07a | `worker/src/jobs/invoice.processor.ts:7` | medium | `/obs-audit` | correlation/job-logger-unbound |
| OD-LG-07b | `jvm-svc/src/main/java/com/harbor/refunds/RequestContextFilter.java:21` | medium | `/obs-audit` | correlation/mdc-never-cleared |
| OD-LG-08a | `api/src/tracing.ts:9` | medium | `/obs-audit` | correlation/trace-ids-not-in-logs |
| OD-LG-08b | `worker/src/logger.ts:7` | medium | `/obs-audit` | correlation/trace-field-renamed |
| OD-TR-01a | `go-svc/internal/inventory/handler.go:50` | medium | `/obs-audit` | traces/context-lost-async-hop |
| OD-TR-01b | `jvm-svc/src/main/java/com/harbor/refunds/RefundService.java:15` | medium | `/obs-audit` | traces/context-lost-async-hop |
| OD-TR-02a | `api/src/orders/orders.service.ts:27` | high | `/obs-audit` | traces/queue-hop-no-propagation |
| OD-TR-02b | `py-svc/app/receipts.py:5` | high | `/obs-audit` | traces/queue-hop-no-propagation |
| OD-TR-03a | `worker/src/http/partner-client.ts:24` | medium | `/obs-audit` | traces/allow-list-drops-traceparent |
| OD-TR-03b | `go-svc/internal/warehouse/client.go:30` | medium | `/obs-audit` | traces/outbound-client-uninstrumented |
| OD-TR-04a | `api/src/shipping/quote.service.ts:12` | medium | `/obs-audit` | traces/span-never-ended |
| OD-TR-04b | `worker/src/invoices/invoice-renderer.ts:25` | medium | `/obs-audit` | traces/error-not-recorded |
| OD-TR-05a | `api/src/main.ts:4` | high | `/obs-audit` | traces/sdk-initialised-late |
| OD-TR-05b | `api/src/tracing.ts:20` | medium | `/obs-audit` | traces/no-flush-on-exit |
| OD-TR-06a | `deploy/docker-compose.yml:31` | medium | `/obs-audit` | traces/propagator-mismatch |
| OD-TR-06b | `py-svc/app/telemetry.py:9` | medium | `/obs-audit` | traces/service-identity-missing |
| OD-TR-07a | `api/src/orders/orders.service.ts:23` | medium | `/obs-audit` | traces/span-name-from-data |
| OD-TR-07b | `py-svc/app/users.py:12` | medium | `/obs-audit` | traces/span-name-from-data |
| OD-TR-08a | `api/src/integrations/carrier.client.ts:15` | medium | `/obs-audit` | traces/deprecated-semconv |
| OD-TR-08b | `deploy/grafana/provisioning/dashboards/api-red.json:163` | medium | `/obs-audit` | traces/deprecated-semconv-consumer |
| OD-TR-09a | `deploy/k8s/worker-deployment.yaml:29` | medium | `/obs-audit` | sampling/ratio-without-parentbased |
| OD-TR-09b | `web/src/sentry.prod.ts:8` | medium | `/obs-audit` | sampling/always-on-in-production |
| OD-TR-10a | `docs/adr/0007-error-traces.md:12` | medium | `/obs-audit` | sampling/error-requirement-head-sampled |
| OD-TR-10b | `deploy/otel/collector.yaml:76` | medium | `/obs-audit` | sampling/sampling-before-span-metrics |
| OD-MT-01a | `api/src/metrics/metrics.ts:26` | high | `/obs-audit` | metrics/unbounded-label |
| OD-MT-01b | `api/src/metrics/http-metrics.hook.ts:9` | high | `/obs-audit` | metrics/unbounded-label |
| OD-MT-01c | `go-svc/internal/httpx/metrics.go:31` | high | `/obs-audit` | metrics/unbounded-label |
| OD-MT-01d | `jvm-svc/src/main/java/com/harbor/refunds/RefundMetrics.java:20` | high | `/obs-audit` | metrics/unbounded-label |
| OD-MT-02a | `worker/src/jobs/billing.cron.ts:18` | medium | `/obs-audit` | metrics/entry-point-unmetered |
| OD-MT-02b | `py-svc/app/tasks.py:22` | medium | `/obs-audit` | metrics/entry-point-unmetered |
| OD-MT-02c | `py-svc/app/db.py:10` | medium | `/obs-audit` | metrics/pool-without-use |
| OD-MT-03a | `api/src/payments/capture.service.ts:26` | medium | `/obs-audit` | metrics/unit-misfit-ms-into-seconds |
| OD-MT-03b | `py-svc/app/metrics.py:9` | medium | `/obs-audit` | metrics/bucket-misfit |
| OD-MT-04a | `api/src/metrics/metrics.ts:19` | medium | `/obs-audit` | metrics/gauge-as-counter |
| OD-MT-04b | `worker/src/metrics.ts:17` | medium | `/obs-audit` | metrics/summary-across-replicas |
| OD-MT-05a | `api/src/promo/promo.service.ts:10` | medium | `/obs-audit` | metrics/registration-per-call |
| OD-MT-05b | `go-svc/internal/export/export.go:22` | medium | `/obs-audit` | metrics/registration-per-call |
| OD-MT-06a | `api/src/metrics/metrics.ts:52` | low | `/obs-audit` | metrics/dead-metric |
| OD-MT-06b | `py-svc/app/metrics.py:14` | low | `/obs-audit` | metrics/dead-metric |
| OD-MT-07a | `api/src/health/health.controller.ts:20` | medium | `/obs-audit` | health/readiness-always-200 |
| OD-MT-07b | `py-svc/app/health.py:10` | medium | `/obs-audit` | health/readiness-always-200 |
| OD-MT-08a | `api/src/tracing.ts:13` | low | `/obs-audit` | health/probe-traffic-in-traces |
| OD-MT-08b | `api/src/metrics/http-metrics.hook.ts:6` | low | `/obs-audit` | health/probe-traffic-in-red |
| OD-ET-01a | `web/src/sentry.prod.ts:4` | medium | `/obs-audit` | errors/tracker-no-release-environment |
| OD-ET-01b | `py-svc/app/main.py:12` | medium | `/obs-audit` | errors/tracker-no-release-environment |
| OD-ET-02a | `worker/src/main.ts:7` | high | `/obs-audit` | errors/no-process-hook |
| OD-ET-02b | `go-svc/cmd/worker/main.go:23` | high | `/obs-audit` | errors/goroutine-without-recover |
| OD-ET-03a | `web/vite.config.ts:8` | medium | `/obs-audit` | errors/maps-never-uploaded |
| OD-ET-03b | `admin/package.json:8` | medium | `/obs-audit` | errors/release-mismatch-no-debug-ids |
| OD-ET-04a | `api/src/common/all-exceptions.filter.ts:15` | high | `/obs-audit` | errors/boundary-500-silent |
| OD-ET-04b | `jvm-svc/src/main/java/com/harbor/refunds/ApiErrorAdvice.java:19` | medium | `/obs-audit` | errors/boundary-500-silent |
| OD-AL-01a | `deploy/prometheus/rules/api.rules.yml:33` | medium | `/obs-audit` | alerts/page-without-for |
| OD-AL-01b | `deploy/prometheus/rules/api.rules.yml:53` | medium | `/obs-audit` | alerts/page-for-too-long |
| OD-AL-02a | `deploy/prometheus/rules/api.rules.yml:61` | medium | `/obs-audit` | alerts/page-without-runbook |
| OD-AL-02b | `deploy/prometheus/rules/api.rules.yml:31` | low | `/obs-audit` | alerts/template-label-dropped |
| OD-AL-02c | `deploy/prometheus/rules/api.rules.yml:105` | high | `/obs-audit` | alerts/value-in-labels |
| OD-AL-02d | `deploy/slo/pyrra/generated/api-latency.yaml:54` | medium | `/obs-audit` | alerts/page-without-runbook |
| OD-AL-03a | `deploy/prometheus/rules/api.rules.yml:43` | medium | `/obs-audit` | alerts/raw-counter-threshold |
| OD-AL-03b | `deploy/prometheus/rules/api.rules.yml:71` | medium | `/obs-audit` | alerts/rate-over-aggregation |
| OD-AL-03c | `deploy/prometheus/rules/api.rules.yml:80` | medium | `/obs-audit` | alerts/quantile-without-le |
| OD-AL-04a | `deploy/prometheus/rules/api.rules.yml:90` | high | `/obs-audit` | alerts/selector-not-in-inventory |
| OD-AL-04b | `deploy/prometheus/rules/legacy-imports.yml:4` | high | `/obs-audit` | alerts/rule-never-loaded |
| OD-AL-04c | `deploy/k8s/prometheusrule-worker.yaml:6` | high | `/obs-audit` | alerts/prometheusrule-not-selected |
| OD-AL-05a | `deploy/prometheus/rules/api.rules.yml:15` | high | `/obs-audit` | alerts/window-under-2x-scrape |
| OD-AL-05b | `deploy/prometheus/rules/api.rules.yml:110` | high | `/obs-audit` | alerts/prometheus3-integer-le |
| OD-AL-06a | `deploy/prometheus/rules/api.rules.yml:4` | medium | `/obs-audit` | alerts/ratio-nan-no-traffic-sibling |
| OD-AL-06b | `deploy/prometheus/rules/api.rules.yml:119` | medium | `/obs-audit` | alerts/absent-misuse |
| OD-AL-07a | `deploy/prometheus/rules/api.rules.yml:127` | medium | `/obs-audit` | alerts/cause-page |
| OD-AL-07b | `deploy/prometheus/rules/orders-api.rules.yml:5` | low | `/obs-audit` | alerts/mean-latency-page |
| OD-AL-08a | `deploy/alertmanager/alertmanager.yml:5` | high | `/obs-audit` | routing/emitted-set-to-null-receiver |
| OD-AL-08b | `deploy/alertmanager/alertmanager.yml:33` | medium | `/obs-audit` | routing/inhibit-equal-unemitted |
| OD-AL-09a | `deploy/grafana/provisioning/alerting/api-alerts.yaml:24` | medium | `/obs-audit` | vendor-monitors/no-data-ok |
| OD-AL-09b | `deploy/monitors/datadog.tf:39` | medium | `/obs-audit` | vendor-monitors/traffic-no-notify-no-data |
| OD-AL-09c | `deploy/monitors/newrelic.tf:25` | medium | `/obs-audit` | vendor-monitors/fill-last-value |
| OD-SLO-01a | `deploy/slo/sloth/api.yml:50` | medium | `/obs-audit` | slo/no-burn-alert |
| OD-SLO-01b | `deploy/monitors/datadog.tf:20` | medium | `/obs-audit` | slo/no-burn-alert |
| OD-SLO-02a | `deploy/prometheus/rules/payments-slo.rules.yml:18` | high | `/obs-audit` | slo/burn-budget-for-another-objective |
| OD-SLO-02b | `deploy/slo/generated/api.yml:171` | medium | `/obs-audit` | slo/generated-rules-hand-edited |
| OD-SLO-03a | `deploy/slo/openslo/partner-webhooks.yaml:32` | high | `/obs-audit` | slo/impossible-objective |
| OD-SLO-03b | `deploy/slo/sloth/api.yml:29` | low | `/obs-audit` | slo/low-traffic-standard-tiers |
| OD-SLO-04a | `deploy/slo/sloth/api.yml:13` | medium | `/obs-audit` | slo/4xx-counted-as-bad |
| OD-SLO-04b | `deploy/slo/sloth/api.yml:34` | medium | `/obs-audit` | slo/only-500-counted |
| OD-SLO-05a | `deploy/prometheus/rules/slo-latency.rules.yml:6` | high | `/obs-audit` | slo/latency-threshold-not-a-bucket-edge |
| OD-SLO-05b | `deploy/prometheus/rules/slo-latency.rules.yml:38` | high | `/obs-audit` | slo/latency-threshold-not-a-bucket-edge |
| OD-SLO-06a | `deploy/docker-compose.yml:71` | medium | `/obs-audit` | slo/window-longer-than-retention |
| OD-SLO-06b | `ai/runtime/slos.md:1` | low | `/obs-audit` | slo/no-budget-policy |
| OD-PL-01a | `deploy/otel/collector.yaml:75` | medium | `/obs-audit` | pipeline/processor-order |
| OD-PL-01b | `deploy/otel/collector.yaml:39` | medium | `/obs-audit` | pipeline/component-unused |
| OD-PL-02a | `deploy/otel/collector.yaml:57` | medium | `/obs-audit` | pipeline/exporter-retry-off |
| OD-PL-02b | `deploy/otel/collector.yaml:62` | medium | `/obs-audit` | pipeline/exporter-queue-off |
| OD-PL-03a | `deploy/otel/collector.yaml:26` | medium | `/obs-audit` | pipeline/tail-sampling-no-load-balancer |
| OD-PL-03b | `deploy/otel/collector.yaml:27` | medium | `/obs-audit` | pipeline/tail-decision-too-early |
| OD-PL-04a | `deploy/promtail/promtail.yaml:25` | high | `/obs-audit` | pipeline/loki-label-holds-id |
| OD-PL-04b | `deploy/alloy/config.alloy:32` | medium | `/obs-audit` | pipeline/loki-label-holds-id |
| OD-PL-05a | `deploy/docker-compose.yml:117` | medium | `/obs-audit` | pipeline/promtail-eol |
| OD-PL-05b | `deploy/alloy/edge.alloy:22` | medium | `/obs-audit` | pipeline/shipper-config-invalid |
| OD-PL-06a | `deploy/loki/loki.yaml:30` | medium | `/obs-audit` | pipeline/retention-not-enforced |
| OD-PL-06b | `deploy/loki/loki.yaml:15` | medium | `/obs-audit` | pipeline/config-env-not-expanded |
| OD-PL-07a | `deploy/otel/collector.yaml:69` | medium | `/obs-audit` | pipeline/debug-exporter-in-production |
| OD-PL-07b | `deploy/k8s/servicemonitor-worker.yaml:6` | high | `/obs-audit` | pipeline/monitor-not-selected |
| OD-PL-08a | `deploy/grafana/provisioning/dashboards/api-red.json:90` | low | `/obs-audit` | dashboards/hard-coded-datasource |
| OD-PL-08b | `deploy/grafana/provisioning/dashboards/orders.json:51` | low | `/obs-audit` | dashboards/counter-without-rate |
| OD-PL-08c | `deploy/grafana/provisioning/dashboards/api-latency.json:51` | medium | `/obs-audit` | dashboards/rate-window-under-scrape |
| OD-AA-05a | `deploy/prometheus/rules/slo-latency.rules.yml:16` | medium | `/obs-audit` | alert-behaviour/burn-gap-page-tiers-only |
| OD-AA-05b | `ai/runtime/slos.md:16` | high | `/obs-audit` | alert-behaviour/burn-gap-no-burn-alert |
| OD-SY-01a | `api/src/checkout/checkout.controller.ts:4` | high | `/obs-audit` | synthetic/journey-without-probe |
| OD-SY-02a | `deploy/prometheus/prometheus.yml:44` | high | `/obs-audit` | synthetic/health-probe-claimed-as-journey |
| OD-HO-SEC-a | `api/src/app.module.ts:31` | high | `/security-audit` | security/log-redaction-gap |
| OD-HO-SEC-b | `api/src/dispatch/dispatch.adapter.ts:22` | high | `/security-audit` | security/pii-in-logs |
| OD-HO-SEC-c | `web/src/sentry.prod.ts:10` | medium | `/security-audit` | security/tracker-default-pii |
| OD-HO-CQ-a | `api/src/orders/orders.service.ts:49` | medium | `/quality-audit` | quality/error-dropped |
| OD-HO-CQ-b | `api/src/webhooks/carrier-webhook.controller.ts:21` | medium | `/quality-audit` | quality/error-dropped |
| OD-HO-PERF-a | `api/src/health/health.controller.ts:14` | medium | `/perf-audit` | performance/liveness-checks-shared-dependency |

Severity split: 33 high · 85 medium · 14 low. Total 132 seeded defects (126 scored under `/obs-audit`, 6 routed hand-offs scored under their owners), 26 decoys.

### Coverage by detector §

One row per detector §; every row carries at least two seeds, except where the note says why.

| family | detector § | classes | seeded | ids |
|--------|------------|---------|--------|-----|
| logs | `log-signal-scan §1` | logs/handled-failure-invisible | 2 | OD-LG-01a, OD-LG-01b |
| logs | `log-signal-scan §2` | logs/error-object-dropped, logs/stack-lost-message-only, logs/stack-lost-stringified, logs/winston-no-format-errors, logs/error-as-string-field, logs/stack-lost-concatenation | 7 | OD-LG-02a, OD-LG-02b, OD-LG-02c, OD-LG-02d, OD-LG-02e, OD-LG-02f, OD-LG-02g |
| logs | `log-signal-scan §3` | logs/nest-bootstrap-no-logger-handoff, logs/pretty-transport-in-production, logs/interpolated-message | 3 | OD-LG-03a, OD-LG-03b, OD-LG-03c |
| logs | `log-signal-scan §4` | logs/4xx-at-error, logs/request-log-no-level-map, logs/debug-in-production-config | 3 | OD-LG-04a, OD-LG-04b, OD-LG-04c |
| logs | `log-signal-scan §5` | logs/payload-per-item-in-loop, logs/probe-requests-logged | 2 | OD-LG-05a, OD-LG-05b |
| logs | `log-signal-scan §6` | correlation/request-id-per-process-counter | 2 | OD-LG-06a, OD-LG-06b |
| logs | `log-signal-scan §7` | correlation/job-logger-unbound, correlation/mdc-never-cleared | 2 | OD-LG-07a, OD-LG-07b |
| logs | `log-signal-scan §8` | correlation/trace-ids-not-in-logs, correlation/trace-field-renamed | 2 | OD-LG-08a, OD-LG-08b |
| traces | `trace-propagation-scan §1` | traces/context-lost-async-hop | 2 | OD-TR-01a, OD-TR-01b |
| traces | `trace-propagation-scan §2` | traces/queue-hop-no-propagation | 2 | OD-TR-02a, OD-TR-02b |
| traces | `trace-propagation-scan §3` | traces/allow-list-drops-traceparent, traces/outbound-client-uninstrumented | 2 | OD-TR-03a, OD-TR-03b |
| traces | `trace-propagation-scan §4` | traces/span-never-ended, traces/error-not-recorded | 2 | OD-TR-04a, OD-TR-04b |
| traces | `trace-propagation-scan §5` | traces/sdk-initialised-late, traces/no-flush-on-exit | 2 | OD-TR-05a, OD-TR-05b |
| traces | `trace-propagation-scan §6` | traces/propagator-mismatch, traces/service-identity-missing | 2 | OD-TR-06a, OD-TR-06b |
| traces | `trace-propagation-scan §7` | traces/span-name-from-data | 2 | OD-TR-07a, OD-TR-07b |
| traces | `trace-propagation-scan §8` | traces/deprecated-semconv, traces/deprecated-semconv-consumer | 2 | OD-TR-08a, OD-TR-08b |
| traces | `trace-propagation-scan §9` | sampling/ratio-without-parentbased, sampling/always-on-in-production | 2 | OD-TR-09a, OD-TR-09b |
| traces | `trace-propagation-scan §10` | sampling/error-requirement-head-sampled, sampling/sampling-before-span-metrics | 2 | OD-TR-10a, OD-TR-10b |
| metrics | `metric-hygiene-scan §1` | metrics/unbounded-label | 4 | OD-MT-01a, OD-MT-01b, OD-MT-01c, OD-MT-01d |
| metrics | `metric-hygiene-scan §2` | metrics/entry-point-unmetered, metrics/pool-without-use | 3 | OD-MT-02a, OD-MT-02b, OD-MT-02c |
| metrics | `metric-hygiene-scan §3` | metrics/unit-misfit-ms-into-seconds, metrics/bucket-misfit | 2 | OD-MT-03a, OD-MT-03b |
| metrics | `metric-hygiene-scan §4` | metrics/gauge-as-counter, metrics/summary-across-replicas | 2 | OD-MT-04a, OD-MT-04b |
| metrics | `metric-hygiene-scan §5` | metrics/registration-per-call | 2 | OD-MT-05a, OD-MT-05b |
| metrics | `metric-hygiene-scan §6` | metrics/dead-metric | 2 | OD-MT-06a, OD-MT-06b |
| metrics | `metric-hygiene-scan §7` | health/readiness-always-200 | 2 | OD-MT-07a, OD-MT-07b |
| metrics | `metric-hygiene-scan §8` | health/probe-traffic-in-traces, health/probe-traffic-in-red | 2 | OD-MT-08a, OD-MT-08b |
| errors | `error-tracking-scan §1` | errors/tracker-no-release-environment | 2 | OD-ET-01a, OD-ET-01b |
| errors | `error-tracking-scan §2` | errors/no-process-hook, errors/goroutine-without-recover | 2 | OD-ET-02a, OD-ET-02b |
| errors | `error-tracking-scan §3` | errors/maps-never-uploaded, errors/release-mismatch-no-debug-ids | 2 | OD-ET-03a, OD-ET-03b |
| errors | `error-tracking-scan §4` | errors/boundary-500-silent | 2 | OD-ET-04a, OD-ET-04b |
| alerts | `alert-rule-lint §1` | alerts/page-without-for, alerts/page-for-too-long | 2 | OD-AL-01a, OD-AL-01b |
| alerts | `alert-rule-lint §2` | alerts/page-without-runbook, alerts/template-label-dropped, alerts/value-in-labels | 4 | OD-AL-02a, OD-AL-02b, OD-AL-02c, OD-AL-02d |
| alerts | `alert-rule-lint §3` | alerts/raw-counter-threshold, alerts/rate-over-aggregation, alerts/quantile-without-le | 3 | OD-AL-03a, OD-AL-03b, OD-AL-03c |
| alerts | `alert-rule-lint §4` | alerts/selector-not-in-inventory, alerts/rule-never-loaded, alerts/prometheusrule-not-selected | 3 | OD-AL-04a, OD-AL-04b, OD-AL-04c |
| alerts | `alert-rule-lint §5` | alerts/window-under-2x-scrape, alerts/prometheus3-integer-le | 2 | OD-AL-05a, OD-AL-05b |
| alerts | `alert-rule-lint §6` | alerts/ratio-nan-no-traffic-sibling, alerts/absent-misuse | 2 | OD-AL-06a, OD-AL-06b |
| alerts | `alert-rule-lint §7` | alerts/cause-page, alerts/mean-latency-page | 2 | OD-AL-07a, OD-AL-07b |
| alerts | `alert-rule-lint §8` | routing/emitted-set-to-null-receiver, routing/inhibit-equal-unemitted | 2 | OD-AL-08a, OD-AL-08b |
| alerts | `alert-rule-lint §9` | vendor-monitors/no-data-ok, vendor-monitors/traffic-no-notify-no-data, vendor-monitors/fill-last-value | 3 | OD-AL-09a, OD-AL-09b, OD-AL-09c |
| slo | `slo-rule-scan §1` | slo/no-burn-alert | 2 | OD-SLO-01a, OD-SLO-01b |
| slo | `slo-rule-scan §2` | slo/burn-budget-for-another-objective, slo/generated-rules-hand-edited | 2 | OD-SLO-02a, OD-SLO-02b |
| slo | `slo-rule-scan §3` | slo/impossible-objective, slo/low-traffic-standard-tiers | 2 | OD-SLO-03a, OD-SLO-03b |
| slo | `slo-rule-scan §4` | slo/4xx-counted-as-bad, slo/only-500-counted | 2 | OD-SLO-04a, OD-SLO-04b |
| slo | `slo-rule-scan §5` | slo/latency-threshold-not-a-bucket-edge | 2 | OD-SLO-05a, OD-SLO-05b |
| slo | `slo-rule-scan §6` | slo/window-longer-than-retention, slo/no-budget-policy | 2 | OD-SLO-06a, OD-SLO-06b |
| pipeline | `telemetry-config-scan §1` | pipeline/processor-order, pipeline/component-unused | 2 | OD-PL-01a, OD-PL-01b |
| pipeline | `telemetry-config-scan §2` | pipeline/exporter-retry-off, pipeline/exporter-queue-off | 2 | OD-PL-02a, OD-PL-02b |
| pipeline | `telemetry-config-scan §3` | pipeline/tail-sampling-no-load-balancer, pipeline/tail-decision-too-early | 2 | OD-PL-03a, OD-PL-03b |
| pipeline | `telemetry-config-scan §4` | pipeline/loki-label-holds-id | 2 | OD-PL-04a, OD-PL-04b |
| pipeline | `telemetry-config-scan §5` | pipeline/promtail-eol, pipeline/shipper-config-invalid | 2 | OD-PL-05a, OD-PL-05b |
| pipeline | `telemetry-config-scan §6` | pipeline/retention-not-enforced, pipeline/config-env-not-expanded | 2 | OD-PL-06a, OD-PL-06b |
| pipeline | `telemetry-config-scan §7` | pipeline/debug-exporter-in-production, pipeline/monitor-not-selected | 2 | OD-PL-07a, OD-PL-07b |
| pipeline | `telemetry-config-scan §8` | dashboards/hard-coded-datasource, dashboards/counter-without-rate, dashboards/rate-window-under-scrape | 3 | OD-PL-08a, OD-PL-08b, OD-PL-08c |
| alert behaviour | `alert-audit §5` | alert-behaviour/burn-gap-page-tiers-only, alert-behaviour/burn-gap-no-burn-alert | 2 | OD-AA-05a, OD-AA-05b |
| synthetic | `synthetic-monitoring §1` | synthetic/journey-without-probe | 1 | OD-SY-01a |
| synthetic | `synthetic-monitoring §2` | synthetic/health-probe-claimed-as-journey | 1 | OD-SY-02a |
| hand-off | `data-exposure-scan §6` (security) | security/log-redaction-gap, security/pii-in-logs, security/tracker-default-pii | 3 | OD-HO-SEC-a, OD-HO-SEC-b, OD-HO-SEC-c |
| hand-off | `error-handling-scan §1` (code-quality) | quality/error-dropped | 2 | OD-HO-CQ-a, OD-HO-CQ-b |
| hand-off | `request-path-scan §15` (performance) | performance/liveness-checks-shared-dependency | 1 | OD-HO-PERF-a |
| **decoys (must not be reported)** | — | — | **26** | OD-DECOY-01 … OD-DECOY-26 |

---

## OD-LG-01a — A failed price quote falls back to the stale cached price and writes nothing

```defect
id:       OD-LG-01a
file:     api/src/pricing/price.service.ts
line:     24
severity: medium
command:  /obs-audit
class:    logs/handled-failure-invisible
detector: log-signal-scan §1
anchor:   return this.cache.getStale(sku);
match:    stale|cache|fallback|degrad
```

The checkout keeps working — the degrade is right for the caller — but the catch has no log at warn, no counter and no span event, so the rate at which customers are charged a stale price is invisible to on-call. Fix: `fallbacks.inc({ reason: 'quote' })` plus `this.logger.warn({ err, sku }, 'quote failed, stale price')` (bind the error). Proof: V190 — make `pricing.quote` throw, assert a warn line or a counter +1.

## OD-LG-01b — PSP status timeouts are suppressed and the endpoint answers `unknown`

```defect
id:       OD-LG-01b
file:     py-svc/app/payments.py
line:     17
severity: high
command:  /obs-audit
class:    logs/handled-failure-invisible
detector: log-signal-scan §1
anchor:   with contextlib.suppress(httpx.TimeoutException):
match:    suppress|timeout|silent|invisible|unknown
```

`contextlib.suppress(httpx.TimeoutException)` on the payment-status path: a PSP that times out turns into `status: unknown` with no log, metric or span event. Payment path, so high. Fix: catch the timeout, `log.warning("psp status timeout", payment_id=..., exc_info=True)` and count it. Proof: V190 with an httpx mock transport that raises `ReadTimeout`.

## OD-LG-02a — `PinoLogger.error('capture failed', err)` drops the error

```defect
id:       OD-LG-02a
file:     api/src/payments/capture.service.ts
line:     23
severity: high
command:  /obs-audit
class:    logs/error-object-dropped
detector: log-signal-scan §2
anchor:   this.logger.error('capture failed', err);
match:    drop|lost|stack|err(?:or)? object|second arg|discard
```

nestjs-pino's `PinoLogger` (pino 10) treats a second string-position argument as a format argument: the line carries the message and nothing of `err` — no type, no stack (log-signal-scan § measured table). The error is rethrown to `AllExceptionsFilter`, which does not log, so this is the only trace of a failed capture. Fix: `this.logger.error({ err, paymentId }, 'capture failed')`. Proof: V189 captured log — assert `err.stack` on the parsed line.

## OD-LG-02b — `{ error: err }` with no `error` serializer logs `{}`

```defect
id:       OD-LG-02b
file:     api/src/orders/refund.service.ts
line:     19
severity: high
command:  /obs-audit
class:    logs/error-object-dropped
detector: log-signal-scan §2
anchor:   this.logger.error({ error: err, orderId }, 'refund failed');
match:    serializ|\{\}|stack|lost|error key|\berr\b
```

pino only serializes the `err` key by default; `error: err` is JSON-stringified to `{}` (precedents § 22, § 52). The decoy `ledger-export.ts` configures an `error` serializer; this logger does not. Fix: `{ err, orderId }`. Proof: V189.

## OD-LG-02c — Carrier callback failures log only `err.message`

```defect
id:       OD-LG-02c
file:     api/src/webhooks/carrier-webhook.service.ts
line:     24
severity: medium
command:  /obs-audit
class:    logs/stack-lost-message-only
detector: log-signal-scan §2
anchor:   this.logger.warn(`carrier callback failed: ${(err as Error).message}`);
match:    message|stack|lost|type
```

The template literal keeps the message and loses the type and stack (measured for the façade and `PinoLogger`). Fix: `this.logger.warn({ err, trackingNumber: event.trackingNumber }, 'carrier callback failed')`. Proof: V189.

## OD-LG-02d — `err: String(e)` turns the error into a string

```defect
id:       OD-LG-02d
file:     api/src/catalog/catalog-sync.service.ts
line:     19
severity: medium
command:  /obs-audit
class:    logs/stack-lost-stringified
detector: log-signal-scan §2
anchor:   this.logger.error({ sku, err: String(e) }, 'catalog sync failed');
match:    String\(|stack|lost|string
```

`String(e)` is `Error: message` — the pino `err` serializer never sees an Error, so no type and no stack. Fix: `{ sku, err: e }`. Proof: V189.

## OD-LG-02e — The worker's winston logger has no `format.errors({ stack: true })`

```defect
id:       OD-LG-02e
file:     worker/src/logger.ts
line:     10
severity: high
command:  /obs-audit
class:    logs/winston-no-format-errors
detector: log-signal-scan §2
anchor:   export const logger = winston.createLogger({
match:    format\.errors|errors\(|stack|winston
```

Every `log.error('…', { err })` in the invoice worker (`invoice.processor.ts`, `invoice-renderer.ts`) prints `err` as `{}`: winston's JSON format does not serialize Error objects (precedents § 52). One finding with every worker site (P4); consumer path, so high. Fix: `format.combine(format.errors({ stack: true }), …)` and log `{ err }`. Proof: V189 with a winston Stream transport.

## OD-LG-02f — Go logs the reservation error as a plain string field

```defect
id:       OD-LG-02f
file:     go-svc/internal/inventory/handler.go
line:     45
severity: medium
command:  /obs-audit
class:    logs/error-as-string-field
detector: log-signal-scan §2
anchor:   zap.String("err", err.Error())
match:    zap\.Error|\.Error\(\)|string field|type
```

`zap.String("err", err.Error())` loses the error type and any wrapped chain zap's `zap.Error` would render (`errorVerbose`). Fix: `zap.Error(err)`. Proof: V189 with an `zaptest/observer` core.

## OD-LG-02g — `log.error("refund failed: " + e)` concatenates the exception

```defect
id:       OD-LG-02g
file:     jvm-svc/src/main/java/com/harbor/refunds/RefundService.java
line:     33
severity: high
command:  /obs-audit
class:    logs/stack-lost-concatenation
detector: log-signal-scan §2
anchor:   log.error("refund failed: " + e);
match:    stack|concat|throwable|toString|\+ e
```

SLF4J only prints a stack for a trailing Throwable argument; `+ e` calls `toString()`, so the PSP failure keeps its message and loses its stack (precedents § 23). Payment path. Fix: `log.error("refund failed for {}", orderId, e)`. Proof: V189 with a Logback `ListAppender`.

## OD-LG-03a — The Nest bootstrap never hands its logger to pino

```defect
id:       OD-LG-03a
file:     api/src/main.ts
line:     17
severity: low
command:  /obs-audit
class:    logs/nest-bootstrap-no-logger-handoff
detector: log-signal-scan §3
anchor:   const app = await NestFactory.create<NestFastifyApplication>(AppModule, adapter);
match:    useLogger|bufferLogs|ConsoleLogger|plain|text|json|unstructured
```

No `bufferLogs: true` and no `app.useLogger(app.get(Logger))`: Nest's own lines (bootstrap, route map, exceptions Nest logs itself) go through the default `ConsoleLogger` as coloured text the log store cannot split into fields. Fix: `NestFactory.create(AppModule, adapter, { bufferLogs: true })` + `app.useLogger(app.get(Logger))`. Proof: V191.

## OD-LG-03b — pino-pretty is the production request-log transport

```defect
id:       OD-LG-03b
file:     api/src/app.module.ts
line:     25
severity: low
command:  /obs-audit
class:    logs/pretty-transport-in-production
detector: log-signal-scan §3
anchor:   transport: { target: 'pino-pretty'
match:    pretty
```

`transport: { target: 'pino-pretty' }` with no environment guard, and `pino-pretty` is a runtime dependency (`api/package.json`), so production prints one-line text, not JSON. Fix: only add the transport when `NODE_ENV !== 'production'`. Proof: V191 — the production config's request line parses as JSON.

## OD-LG-03c — An f-string message on the order-confirm path

```defect
id:       OD-LG-03c
file:     py-svc/app/orders.py
line:     18
severity: low
command:  /obs-audit
class:    logs/interpolated-message
detector: log-signal-scan §3
anchor:   logger.info(f"order {oid} confirmed")
match:    f-?string|interpolat|format|template|structur|field
```

The message template changes per call and the id is not a field (ruff `G004`). Fix: `log.info("order confirmed", order_id=oid)` through structlog. Proof: V191 — two calls, one template.

## OD-LG-04a — Every HttpException — 400, 404, 402 — is logged at error

```defect
id:       OD-LG-04a
file:     api/src/common/http-exception.filter.ts
line:     15
severity: medium
command:  /obs-audit
class:    logs/4xx-at-error
detector: log-signal-scan §4
anchor:   this.logger.error({ err: exception, cause: exception.cause, status
match:    4\d\d|4xx|404|level|warn
```

The filter has no status branch: validation failures and not-found requests land at error and drown the real failures (`THR-OBS-LEVEL`: 4xx at warn or below). Fix: `status >= 500 ? error : warn`. Proof: V192 — drive a 404, a 400 and a 500, assert the three levels.

## OD-LG-04b — pino-http has no `customLogLevel`

```defect
id:       OD-LG-04b
file:     api/src/app.module.ts
line:     22
severity: medium
command:  /obs-audit
class:    logs/request-log-no-level-map
detector: log-signal-scan §4
anchor:   level: process.env.LOG_LEVEL ?? 'info',
match:    customLogLevel|status.?code|4xx|5xx|every request
```

Without `customLogLevel` every request line is `info` whatever its status, so a 5xx is indistinguishable from a 200 by level. Fix: `customLogLevel: (req, res, err) => err || res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info'`. Proof: V192.

## OD-LG-04c — The production worker ConfigMap sets `LOG_LEVEL: debug`

```defect
id:       OD-LG-04c
file:     deploy/k8s/worker-configmap.yaml
line:     7
severity: medium
command:  /obs-audit
class:    logs/debug-in-production-config
detector: log-signal-scan §4
anchor:   LOG_LEVEL: "debug"
match:    debug
```

`worker-configmap.yaml` is in the cluster kustomization the worker Deployment loads through `envFrom` — not a dev overlay (precedents § 30). Fix: `info`. Proof: V192 on the rendered config.

## OD-LG-05a — The supplier feed import logs every row, serialized, at info

```defect
id:       OD-LG-05a
file:     api/src/catalog/import.service.ts
line:     18
severity: medium
command:  /obs-audit
class:    logs/payload-per-item-in-loop
detector: log-signal-scan §5
anchor:   this.logger.info({ row: JSON.stringify(row) }, 'importing feed row');
match:    loop|per.?row|per.?item|volume|JSON\.stringify|payload|hot
```

40–60k rows per nightly run, each a full JSON string on one info line: the volume half is this skill's (the value half, if a row carried personal data, would be security's). Fix: one summary line per batch plus a counter. Proof: count lines and bytes per import run (V192).

## OD-LG-05b — pino-http logs every `/health/*` and `/metrics` request

```defect
id:       OD-LG-05b
file:     api/src/app.module.ts
line:     21
severity: low
command:  /obs-audit
class:    logs/probe-requests-logged
detector: log-signal-scan §5
anchor:   pinoHttp: {
match:    autoLogging|health|probe|ignore
```

No `autoLogging.ignore`: the load balancer and Prometheus each add a request line every few seconds per replica. Fix: `autoLogging: { ignore: (req) => req.url?.startsWith('/health') || req.url === '/metrics' }`. Proof: V201 — 100 probe hits, 0 lines.

## OD-LG-06a — nestjs-pino runs with no `genReqId`

```defect
id:       OD-LG-06a
file:     api/src/app.module.ts
line:     20
severity: medium
command:  /obs-audit
class:    correlation/request-id-per-process-counter
detector: log-signal-scan §6
anchor:   LoggerModule.forRoot({
match:    genReqId|request.?id|req-\d|counter|collid
```

The default request id is a per-process counter (`req-1`, `req-2`, measured on nestjs-pino 5.3.1 / Fastify 5): two replicas mint the same ids and an incoming `x-request-id` is ignored. Fix: `genReqId: (req) => req.headers['x-request-id'] ?? randomUUID()`. Proof: V193 — two concurrent requests, two distinct ids.

## OD-LG-06b — The Fastify adapter sets neither `genReqId` nor `requestIdHeader`

```defect
id:       OD-LG-06b
file:     api/src/main.ts
line:     12
severity: medium
command:  /obs-audit
class:    correlation/request-id-per-process-counter
detector: log-signal-scan §6
anchor:   const adapter = new FastifyAdapter({
match:    genReqId|requestIdHeader|request.?id|counter|x-request-id
```

Fastify 5's `request.id` (what `request.log` binds) is the same per-process counter, and the upstream header is not honoured. Fix: `new FastifyAdapter({ requestIdHeader: 'x-request-id', genReqId: () => randomUUID() })`. Proof: V193.

## OD-LG-07a — Invoice job lines carry no request or trace id

```defect
id:       OD-LG-07a
file:     worker/src/jobs/invoice.processor.ts
line:     7
severity: medium
command:  /obs-audit
class:    correlation/job-logger-unbound
detector: log-signal-scan §7
anchor:   @Processor('invoices')
match:    correlat|request.?id|trace.?id|cls|AsyncLocalStorage|context|bind
```

The processor logs through a module logger with the order id only. The job payload carries no originating request id, BullMQ has no telemetry (`OD-TR-02a`), and `withTraceIds` only stamps ids when a span is active — none is in a job. Nobody can join a job's lines to the checkout that queued it (precedents § 40). Fix: put the request id in the payload and bind it (`log.child({ requestId })`), or restore it through CLS. Proof: V193 — one request plus its job, same id on both.

## OD-LG-07b — `MDC.put` with no `MDC.remove`

```defect
id:       OD-LG-07b
file:     jvm-svc/src/main/java/com/harbor/refunds/RequestContextFilter.java
line:     21
severity: medium
command:  /obs-audit
class:    correlation/mdc-never-cleared
detector: log-signal-scan §7
anchor:   MDC.put("order_id", orderId);
match:    MDC|remove|clear|leak|thread
```

Servlet threads are pooled: the next request on the thread inherits the previous caller's `order_id` whenever it sends no header, so log lines are attributed to the wrong order. Fix: `try (var c = MDC.putCloseable("order_id", orderId)) { chain.doFilter(…); }`. Proof: two sequential requests on a one-thread executor; the second line has no `order_id`.

## OD-LG-08a — The API traces but its log lines carry no trace id

```defect
id:       OD-LG-08a
file:     api/src/tracing.ts
line:     9
severity: medium
command:  /obs-audit
class:    correlation/trace-ids-not-in-logs
detector: log-signal-scan §8
anchor:   const sdk = new NodeSDK({
match:    pino|trace.?id|span.?id|bridge|instrumentation-pino|correlat
```

The hand-picked instrumentation list has no `PinoInstrumentation` and the pino config has no mixin, so no API line carries `trace_id`, while the Grafana Loki derived field (`datasources.yaml`) joins on `trace_id`. Fix: add `new PinoInstrumentation()` (it injects `trace_id` / `span_id`). Proof: V193 — the log `trace_id` equals the exporter's traceId.

## OD-LG-08b — The worker writes `traceId` / `spanId`; everything else reads `trace_id`

```defect
id:       OD-LG-08b
file:     worker/src/logger.ts
line:     7
severity: medium
command:  /obs-audit
class:    correlation/trace-field-renamed
detector: log-signal-scan §8
anchor:   traceId: ctx.traceId
match:    traceId|camel|trace_id|rename|field name
```

The hand-rolled winston format uses camelCase, while Alloy's `stage.json` and the Loki derived field read `trace_id` (snake case, as the Python and Go services write it). The worker's lines never link to their traces. Fix: `trace_id` / `span_id`. Proof: V193.

## OD-TR-01a — The warehouse notification starts a new root trace

```defect
id:       OD-TR-01a
file:     go-svc/internal/inventory/handler.go
line:     50
severity: medium
command:  /obs-audit
class:    traces/context-lost-async-hop
detector: trace-propagation-scan §1
anchor:   go h.notifyWarehouse(context.Background(), req.SKU, req.Qty)
match:    Background|context|orphan|root|parent|WithoutCancel
```

`context.Background()` drops the request span, so the outbound call and its failure land in a separate, parentless trace. The sibling `Release` uses `context.WithoutCancel(ctx)` (decoy `OD-DECOY-18`). Fix: `context.WithoutCancel(ctx)`. Proof: V194 — the hop's span shares the request's traceId.

## OD-TR-01b — Refund notifications run on a bare executor

```defect
id:       OD-TR-01b
file:     jvm-svc/src/main/java/com/harbor/refunds/RefundService.java
line:     15
severity: medium
command:  /obs-audit
class:    traces/context-lost-async-hop
detector: trace-propagation-scan §1
anchor:   Executors.newFixedThreadPool(4)
match:    Executor|thread|context|wrap|propagat
```

Micrometer Tracing is on the classpath and there is no Java agent, so a task submitted to `Executors.newFixedThreadPool` loses the observation context: the customer notification is an orphan. Fix: `ContextExecutorService.wrap(...)` (Micrometer context-propagation) or `Context.taskWrapping(...)`. Proof: V194.

## OD-TR-02a — Checkout → invoice job: the BullMQ hop carries no trace context

```defect
id:       OD-TR-02a
file:     api/src/orders/orders.service.ts
line:     27
severity: high
command:  /obs-audit
class:    traces/queue-hop-no-propagation
detector: trace-propagation-scan §2
anchor:   await this.invoiceQueue.add('render', { orderId: order.id });
match:    BullMQ|queue|telemetry|inject|propagat|BullMQOtel
```

No `telemetry: new BullMQOtel(…)` on the `Queue` (and none on the worker), and `auto-instrumentations-node` has no BullMQ entry: every invoice job starts a new trace. Fix: BullMQ telemetry on both the queue and the worker. Proof: V194 against a real Redis — one traceId from HTTP through consume.

## OD-TR-02b — Celery `.delay` with no `CeleryInstrumentor`

```defect
id:       OD-TR-02b
file:     py-svc/app/receipts.py
line:     5
severity: high
command:  /obs-audit
class:    traces/queue-hop-no-propagation
detector: trace-propagation-scan §2
anchor:   send_receipt.delay(order_id)
match:    Celery|CeleryInstrumentor|delay|propagat|instrument
```

Neither the orders-api process nor the `orders-worker` container instruments Celery, so the receipt task runs untraced and unlinked. Fix: `CeleryInstrumentor().instrument()` in both processes (worker: in `worker_process_init`). Proof: V194.

## OD-TR-03a — The partner client injects trace context, then filters it out

```defect
id:       OD-TR-03a
file:     worker/src/http/partner-client.ts
line:     24
severity: medium
command:  /obs-audit
class:    traces/allow-list-drops-traceparent
detector: trace-propagation-scan §3
anchor:   headers: pick(carrier, FORWARD_HEADERS),
match:    traceparent|allow.?list|FORWARD_HEADERS|pick|propagat
```

`propagation.inject` writes `traceparent` into `carrier`; `pick(carrier, FORWARD_HEADERS)` keeps only four header names. The worker's SDK has no HTTP instrumentation (only `IORedisInstrumentation`), so nothing re-injects at the transport. Fix: add `traceparent` and `tracestate` to the forwarded set (or instrument `http`). Proof: V194 — a local sink records the received `traceparent`.

## OD-TR-03b — Warehouse calls go through `http.DefaultClient`

```defect
id:       OD-TR-03b
file:     go-svc/internal/warehouse/client.go
line:     30
severity: medium
command:  /obs-audit
class:    traces/outbound-client-uninstrumented
detector: trace-propagation-scan §3
anchor:   resp, err := http.DefaultClient.Do(req)
match:    DefaultClient|otelhttp|transport|instrument|traceparent
```

`otelhttp.NewTransport` wraps a `RoundTripper`; `http.DefaultClient` is not wrapped, so there is no client span and no `traceparent`. Fix: `&http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport), Timeout: …}`. Proof: V194 with `httptest.Server`.

## OD-TR-04a — The carrier-quote span is ended only on success

```defect
id:       OD-TR-04a
file:     api/src/shipping/quote.service.ts
line:     12
severity: medium
command:  /obs-audit
class:    traces/span-never-ended
detector: trace-propagation-scan §4
anchor:   const span = tracer.startSpan('carrier.quote', { kind: SpanKind.CLIENT });
match:    end|finally|leak|status|recordException
```

On a carrier failure the catch rethrows without `span.end()`, `recordException` or `setStatus(ERROR)`: the failing span never reaches the exporter. Fix: `startActiveSpan` with `try / catch (record, ERROR) / finally (end)`. Proof: V195 — the failing path exports the span with `status=ERROR`.

## OD-TR-04b — The invoice render span is ended UNSET when the render fails

```defect
id:       OD-TR-04b
file:     worker/src/invoices/invoice-renderer.ts
line:     25
severity: medium
command:  /obs-audit
class:    traces/error-not-recorded
detector: trace-propagation-scan §4
anchor:   } catch (err) {
match:    recordException|setStatus|ERROR|status|exception event
```

The catch logs and rethrows, `finally` ends the span — but no `span.recordException(err)` / `setStatus({ code: ERROR })`, so a failed render looks successful in the trace. Fix: record and set status in the catch. Proof: V195.

## OD-TR-05a — The API imports its tracing bootstrap after `@nestjs/core` and Fastify

```defect
id:       OD-TR-05a
file:     api/src/main.ts
line:     4
severity: high
command:  /obs-audit
class:    traces/sdk-initialised-late
detector: trace-propagation-scan §5
anchor:   import './tracing';
match:    import order|before|first|preload|--require|late|after
```

`main.ts` imports `@nestjs/core` and `@nestjs/platform-fastify` before `./tracing`, and `api/Dockerfile` runs `node dist/main.js` with no `--require ./dist/tracing.js` (the worker's Dockerfile does preload). Modules loaded before the SDK are not patched, so server spans are missing. Fix: `CMD ["node", "--require", "./dist/tracing.js", "dist/main.js"]`. Proof: V196 — spawn the real start command, one request, assert a SERVER span.

## OD-TR-05b — The API's NodeSDK is never shut down

```defect
id:       OD-TR-05b
file:     api/src/tracing.ts
line:     20
severity: medium
command:  /obs-audit
class:    traces/no-flush-on-exit
detector: trace-propagation-scan §5
anchor:   sdk.start();
match:    shutdown|flush|SIGTERM|exit
```

No `sdk.shutdown()` on SIGTERM (the worker's `tracing.ts` has one): every deploy drops the spans still in the batch processor. Fix: `process.on('SIGTERM', () => sdk.shutdown())` before Nest's own shutdown hooks. Proof: V196 — SIGTERM, then the sink holds the last span.

## OD-TR-06a — orders-api reads only B3; every other service sends W3C `traceparent`

```defect
id:       OD-TR-06a
file:     deploy/docker-compose.yml
line:     31
severity: medium
command:  /obs-audit
class:    traces/propagator-mismatch
detector: trace-propagation-scan §6
anchor:   OTEL_PROPAGATORS: b3
match:    b3|propagator|tracecontext
```

The API, inventory and the worker keep the default `tracecontext,baggage`; with `OTEL_PROPAGATORS=b3` the orders-api cannot extract their context, so every call into it starts a new trace. Fix: drop the override, or `tracecontext,b3multi` on both sides of a real B3 edge. Proof: V196 cross-service test.

## OD-TR-06b — orders-api exports as `unknown_service:python`

```defect
id:       OD-TR-06b
file:     py-svc/app/telemetry.py
line:     9
severity: medium
command:  /obs-audit
class:    traces/service-identity-missing
detector: trace-propagation-scan §6
anchor:   provider = TracerProvider()
match:    service.?name|OTEL_SERVICE_NAME|unknown_service|resource|identity
```

`TracerProvider()` has no `Resource` and the compose service sets no `OTEL_SERVICE_NAME`, unlike every other service (pre-flight 6b set-difference). Fix: `OTEL_SERVICE_NAME=orders-api` (or `Resource.create({"service.name": "orders-api"})`). Proof: V196 — the exporter resource names the service.

## OD-TR-07a — The checkout span name embeds the cart id

```defect
id:       OD-TR-07a
file:     api/src/orders/orders.service.ts
line:     23
severity: medium
command:  /obs-audit
class:    traces/span-name-from-data
detector: trace-propagation-scan §7
anchor:   tracer.startActiveSpan(`checkout ${cartId}`
match:    span name|cardinal|unbounded|cartId|interpolat
```

One span name per cart: span metrics and the service graph explode. Fix: `startActiveSpan('orders.place', { attributes: { 'cart.id': cartId } }, …)`. Proof: V194 — 100 random carts, one span name.

## OD-TR-07b — An f-string span name per user

```defect
id:       OD-TR-07b
file:     py-svc/app/users.py
line:     12
severity: medium
command:  /obs-audit
class:    traces/span-name-from-data
detector: trace-propagation-scan §7
anchor:   start_as_current_span(f"user {uid} orders")
match:    span name|cardinal|unbounded|uid|f-?string|interpolat
```

Same class in Python. Fix: `start_as_current_span("users.orders", attributes={"user.id": uid})`. Proof: V194.

## OD-TR-08a — `http.url` set by hand

```defect
id:       OD-TR-08a
file:     api/src/integrations/carrier.client.ts
line:     15
severity: medium
command:  /obs-audit
class:    traces/deprecated-semconv
detector: trace-propagation-scan §8
anchor:   setAttribute('http.url', url)
match:    http\.url|url\.full|deprecat|semconv|semantic
```

`http.url` is the deprecated name (`url.full` in the stable HTTP conventions) and no `OTEL_SEMCONV_STABILITY_OPT_IN` dual-emit window is declared (precedents § 46). Fix: `url.full`. Proof: V194 exporter dump / Weaver live-check.

## OD-TR-08b — A dashboard panel groups span metrics by `http_method`

```defect
id:       OD-TR-08b
file:     deploy/grafana/provisioning/dashboards/api-red.json
line:     163
severity: medium
command:  /obs-audit
class:    traces/deprecated-semconv-consumer
detector: trace-propagation-scan §8
anchor:   sum by (http_method)
match:    http_method|http\.request\.method|deprecat|semconv|empty|dimension
```

The collector's `spanmetrics` connector configures no `http_method` dimension, and current instrumentation emits `http.request.method`: the panel is an empty view. Fix: group by a dimension the connector emits (add `http.request.method` to its dimensions). Proof: V194 exporter dump against the panel query.

## OD-TR-09a — The worker samples with a bare `traceidratio`

```defect
id:       OD-TR-09a
file:     deploy/k8s/worker-deployment.yaml
line:     29
severity: medium
command:  /obs-audit
class:    sampling/ratio-without-parentbased
detector: trace-propagation-scan §9
anchor:   value: traceidratio
match:    ParentBased|parentbased|traceidratio|ratio
```

A root-ratio sampler ignores the parent's decision: a request the API kept can lose its worker half, and vice versa. Fix: `OTEL_TRACES_SAMPLER=parentbased_traceidratio`. Proof: V197 — the resolved sampler's description contains `ParentBased`.

## OD-TR-09b — The production storefront bundle traces every page load

```defect
id:       OD-TR-09b
file:     web/src/sentry.prod.ts
line:     8
severity: medium
command:  /obs-audit
class:    sampling/always-on-in-production
detector: trace-propagation-scan §9
anchor:   tracesSampleRate: 1.0,
match:    tracesSampleRate|1\.0|100 ?%|every|sampl
```

`tracesSampleRate: 1.0` in `sentry.prod.ts` (the dev file, `OD-DECOY-08`, is the right place for it), with no `tracesSampler` and no stated budget (precedents § 33). Fix: a rate or a per-route `tracesSampler`. Proof: span-count arithmetic, priced by finops when installed.

## OD-TR-10a — ADR 0007 promises every error trace; nothing keeps them

```defect
id:       OD-TR-10a
file:     docs/adr/0007-error-traces.md
line:     12
severity: medium
command:  /obs-audit
class:    sampling/error-requirement-head-sampled
detector: trace-propagation-scan §10
anchor:   We keep 100% of error traces
match:    100 ?%|error trace|head|tail|status_code
```

The SDKs head-sample at 10 % before an error is known, and the gateway's `tail_sampling` has no `status_code` policy (latency and probabilistic only): about 90 % of error traces are never recorded. Fix: a `status_code: ERROR` tail policy behind a trace-id load balancer, with SDKs at `parentbased_always_on` into the gateway. Proof: V197 — send N error traces, count the retained ones.

## OD-TR-10b — Span metrics are computed after the samplers

```defect
id:       OD-TR-10b
file:     deploy/otel/collector.yaml
line:     76
severity: medium
command:  /obs-audit
class:    sampling/sampling-before-span-metrics
detector: trace-propagation-scan §10
anchor:   exporters: [otlp/tempo, spanmetrics, debug]
match:    spanmetrics|span metrics|sampl|before|RED
```

The `spanmetrics` connector is an exporter of the traces pipeline whose processors include `probabilistic_sampler` and `tail_sampling`: request rates and error counts derived from spans see only the sampled fraction. Fix: a separate traces pipeline with no sampler that feeds `spanmetrics`. Proof: static two-ended trace (processor list + connector), both cited.

## OD-MT-01a — `checkout_attempts_total` is labelled by `user_id`

```defect
id:       OD-MT-01a
file:     api/src/metrics/metrics.ts
line:     26
severity: high
command:  /obs-audit
class:    metrics/unbounded-label
detector: metric-hygiene-scan §1
anchor:   labelNames: ['route', 'user_id'],
match:    user_id|unbounded|cardinal
```

One series per customer (`checkout.service.ts` passes the user id). Fix: drop the label; the id belongs on a log line or a span attribute (precedents § 19). Proof: V198 — 100 random users, one series.

## OD-MT-01b — The latency histogram's route label is Fastify's raw URL

```defect
id:       OD-MT-01b
file:     api/src/metrics/http-metrics.hook.ts
line:     9
severity: high
command:  /obs-audit
class:    metrics/unbounded-label
detector: metric-hygiene-scan §1
anchor:   httpDuration.labels(request.method, request.url, code)
match:    request\.url|raw (?:url|path)|unbounded|cardinal|routeOptions
```

`request.url` carries ids and query strings: every order id is a new set of bucket series. The counter two lines above uses `request.routeOptions.url` correctly. Fix: the same route template. Proof: V198.

## OD-MT-01c — Inventory requests are labelled by the raw path

```defect
id:       OD-MT-01c
file:     go-svc/internal/httpx/metrics.go
line:     31
severity: high
command:  /obs-audit
class:    metrics/unbounded-label
detector: metric-hygiene-scan §1
anchor:   requests.WithLabelValues(r.URL.Path, strconv.Itoa(rec.status)).Inc()
match:    URL\.Path|raw path|unbounded|cardinal|pattern
```

`/v1/reservations/{sku}` makes one series per SKU. Fix: `r.Pattern` (Go 1.22+ mux) as the label. Proof: V198.

## OD-MT-01d — Micrometer tag `uri` from `getRequestURI()`

```defect
id:       OD-MT-01d
file:     jvm-svc/src/main/java/com/harbor/refunds/RefundMetrics.java
line:     20
severity: high
command:  /obs-audit
class:    metrics/unbounded-label
detector: metric-hygiene-scan §1
anchor:   Tag.of("uri", request.getRequestURI())
match:    getRequestURI|uri|unbounded|cardinal
```

The raw URI (with the refund id) as a tag value: unbounded series in `refunds_processed_total`. Fix: the templated `uri` Spring's own `http.server.requests` uses, or drop it. Proof: V198.

## OD-MT-02a — The nightly renewal charge run emits no metric

```defect
id:       OD-MT-02a
file:     worker/src/jobs/billing.cron.ts
line:     18
severity: medium
command:  /obs-audit
class:    metrics/entry-point-unmetered
detector: metric-hygiene-scan §2
anchor:   @Cron('0 2 * * *')
match:    metric|counter|duration|RED|unmetered
```

No counter with an outcome, no duration, no wrapper meters `@Cron` handlers (grep 2c is empty). A failed or skipped run is invisible until customers notice. Fix: `jobs_total{job,outcome}` + `job_duration_seconds{job}` around the run. Proof: V200.

## OD-MT-02b — The Celery index rebuild emits no metric

```defect
id:       OD-MT-02b
file:     py-svc/app/tasks.py
line:     22
severity: medium
command:  /obs-audit
class:    metrics/entry-point-unmetered
detector: metric-hygiene-scan §2
anchor:   def rebuild_search_index() -> None:
match:    metric|counter|duration|RED|unmetered
```

Its sibling task `send_receipt` counts itself; this one logs only. Fix: a counter with outcome and a duration (or Celery's `task_postrun` / `task_failure` signals for every task). Proof: V200.

## OD-MT-02c — The orders-api connection pool exposes no USE metrics

```defect
id:       OD-MT-02c
file:     py-svc/app/db.py
line:     10
severity: medium
command:  /obs-audit
class:    metrics/pool-without-use
detector: metric-hygiene-scan §2
anchor:   pool = await asyncpg.create_pool(
match:    pool|USE|in.?use|idle|saturat|gauge|wait
```

`asyncpg.create_pool(max_size=10)` with no in-use / idle / waiting gauge: pool exhaustion shows up only as latency. Fix: gauges from `pool.get_size()` / `get_idle_size()` (`set_function`). Proof: V200 — hold N connections in a test, scrape.

## OD-MT-03a — Milliseconds observed into `payment_capture_duration_seconds`

```defect
id:       OD-MT-03a
file:     api/src/payments/capture.service.ts
line:     26
severity: medium
command:  /obs-audit
class:    metrics/unit-misfit-ms-into-seconds
detector: metric-hygiene-scan §3
anchor:   captureDuration.observe(Date.now() - startedAt);
match:    millisecond|\bms\b|seconds|unit|1000|\+Inf
```

`Date.now() - startedAt` is milliseconds; the histogram's top bucket is 5 (seconds), so every capture lands in `+Inf`. Fix: `/ 1000`. Proof: V199 — observe a 200 ms capture, assert the `le="0.25"` bucket.

## OD-MT-03b — The orders-api latency histogram has no 0.3 edge; its board reads `le="0.3"`

```defect
id:       OD-MT-03b
file:     py-svc/app/metrics.py
line:     9
severity: medium
command:  /obs-audit
class:    metrics/bucket-misfit
detector: metric-hygiene-scan §3
anchor:   buckets=(0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
match:    0\.3|300 ?ms|bucket|edge
```

The `Orders` dashboard's "requests under 300 ms" panel selects `orders_api_request_duration_seconds_bucket{le="0.3"}`, a series this bucket list never produces: the panel is empty. Fix: add 0.3 to the buckets. Proof: V199 — `x_bucket{le="0.3"}` exists after one observation.

## OD-MT-04a — A Gauge named `_total` and only ever incremented

```defect
id:       OD-MT-04a
file:     api/src/metrics/metrics.ts
line:     19
severity: medium
command:  /obs-audit
class:    metrics/gauge-as-counter
detector: metric-hygiene-scan §4
anchor:   name: 'http_requests_handled_total',
match:    Gauge|counter|monoton|reset
```

`handledRequests.inc()` on every response: as a gauge, a restart looks like a drop, and `rate()` on the api-red board cannot handle the reset. Fix: a Counter. Proof: V198 — `# TYPE` in the exposition.

## OD-MT-04b — Invoice render latency is a Summary on 3 replicas

```defect
id:       OD-MT-04b
file:     worker/src/metrics.ts
line:     17
severity: medium
command:  /obs-audit
class:    metrics/summary-across-replicas
detector: metric-hygiene-scan §4
anchor:   export const invoiceRender = new Summary({
match:    Summary|quantile|replica|aggregat|histogram
```

`invoice-worker` runs 3 replicas and `InvoiceRenderSlow` averages `invoice_render_seconds{quantile="0.99"}` across them — the average of three p99s is no percentile. Fix: a Histogram and `histogram_quantile`. Proof: V198 static two-ended trace (declaration + the consuming rule).

## OD-MT-05a — A Counter is constructed inside `redeem()`

```defect
id:       OD-MT-05a
file:     api/src/promo/promo.service.ts
line:     10
severity: medium
command:  /obs-audit
class:    metrics/registration-per-call
detector: metric-hygiene-scan §5
anchor:   const redemptions = new Counter({
match:    regist|per (?:call|request)|already|duplicate|module scope|inside
```

prom-client 15 throws `A metric with the name promo_redemptions_total has already been registered` on the second redemption — on the request path. Fix: module-scope registration. Proof: a second call through the entry point throws in the test.

## OD-MT-05b — `MustRegister` inside the export handler

```defect
id:       OD-MT-05b
file:     go-svc/internal/export/export.go
line:     22
severity: medium
command:  /obs-audit
class:    metrics/registration-per-call
detector: metric-hygiene-scan §5
anchor:   prometheus.MustRegister(exports)
match:    MustRegister|regist|panic|duplicate|per request
```

The second export request panics with a duplicate-registration error (net/http recovers it and drops the connection). Fix: register once in `init()` / the constructor. Proof: two requests in an `httptest` server.

## OD-MT-06a — `cart_abandon_total` is read by no rule, dashboard or SLO

```defect
id:       OD-MT-06a
file:     api/src/metrics/metrics.ts
line:     52
severity: low
command:  /obs-audit
class:    metrics/dead-metric
detector: metric-hygiene-scan §6
anchor:   cart_abandon_total
match:    cart_abandon|dead|unused|no consumer|nothing reads
```

Every consumer of this stack is in the repo (`deploy/`) and none names it. Fix: graph it or delete it. Proof: S, the set-diff; L, `mimirtool analyze` when a backend is given.

## OD-MT-06b — `retry_attempts` is registered and read by nothing

```defect
id:       OD-MT-06b
file:     py-svc/app/metrics.py
line:     14
severity: low
command:  /obs-audit
class:    metrics/dead-metric
detector: metric-hygiene-scan §6
anchor:   RETRY_ATTEMPTS = Counter("retry_attempts"
match:    retry_attempts|dead|unused|no consumer
```

Never incremented in code and named by no consumer. Fix: wire and graph it, or delete it. Proof: S.

## OD-MT-07a — `/health/ready` checks nothing

```defect
id:       OD-MT-07a
file:     api/src/health/health.controller.ts
line:     20
severity: medium
command:  /obs-audit
class:    health/readiness-always-200
detector: metric-hygiene-scan §7
anchor:   return this.health.check([]);
match:    readiness|ready|empty|always|200|constant
```

terminus with an empty indicator list answers `status: ok` while the MikroORM pool and Redis are down, so a replica that cannot serve stays in rotation. Fix: `[() => this.db.pingCheck('database'), …redis]` here (and nothing shared in liveness, `OD-HO-PERF-a`). Proof: V201 — stop the DB, `/health/ready` 503, liveness 200.

## OD-MT-07b — orders-api `/readyz` is a constant while the app holds an asyncpg pool

```defect
id:       OD-MT-07b
file:     py-svc/app/health.py
line:     10
severity: medium
command:  /obs-audit
class:    health/readiness-always-200
detector: metric-hygiene-scan §7
anchor:   return {"ok": True}
match:    readiness|readyz|always|200|constant|pool|database
```

The load balancer polls `/readyz`; it answers 200 with Postgres unreachable. Fix: `async with db.pool.acquire() as c: await c.fetchval("select 1")` with a short timeout, 503 on failure. Proof: V201.

## OD-MT-08a — Every health probe becomes a server span

```defect
id:       OD-MT-08a
file:     api/src/tracing.ts
line:     13
severity: low
command:  /obs-audit
class:    health/probe-traffic-in-traces
detector: metric-hygiene-scan §8
anchor:   new HttpInstrumentation(),
match:    ignoreIncomingRequestHook|probe|health|ignore|exclude
```

`HttpInstrumentation` with no `ignoreIncomingRequestHook`, and the collector's `filter/drop-probes` is not wired into the pipeline (`OD-PL-01b`). Fix: `new HttpInstrumentation({ ignoreIncomingRequestHook: (req) => req.url?.startsWith('/health') ?? false })`. Proof: V201 — 100 probe hits, 0 spans.

## OD-MT-08b — The RED hook counts `/health/*` and `/metrics`

```defect
id:       OD-MT-08b
file:     api/src/metrics/http-metrics.hook.ts
line:     6
severity: low
command:  /obs-audit
class:    health/probe-traffic-in-red
detector: metric-hygiene-scan §8
anchor:   app.addHook('onResponse', async (request, reply) => {
match:    probe|health|/metrics|exclude|skip|filter
```

No skip set (its sibling `slow-request.hook.ts` has one), and no consumer filters probe routes (grep 8c): kubelet and scrape traffic inflate request rate and dilute the 5xx ratio. Fix: skip the probe routes in the hook. Proof: V201 — 100 probe hits leave the SLI series unchanged.

## OD-ET-01a — The production storefront `Sentry.init` has no `release` and no `environment`

```defect
id:       OD-ET-01a
file:     web/src/sentry.prod.ts
line:     4
severity: medium
command:  /obs-audit
class:    errors/tracker-no-release-environment
detector: error-tracking-scan §1
anchor:   Sentry.init({
match:    release|environment
```

A browser bundle has no process env and the Vite config injects nothing, so events carry neither: regressions cannot be tied to a deploy and staging noise mixes with production. Fix: `release: import.meta.env.VITE_RELEASE, environment: import.meta.env.MODE`. Proof: V202 test transport.

## OD-ET-01b — orders-api's `sentry_sdk.init` sets neither, and compose supplies neither

```defect
id:       OD-ET-01b
file:     py-svc/app/main.py
line:     12
severity: medium
command:  /obs-audit
class:    errors/tracker-no-release-environment
detector: error-tracking-scan §1
anchor:   sentry_sdk.init(dsn=os.environ.get("SENTRY_DSN"))
match:    release|environment|SENTRY_RELEASE
```

No `SENTRY_RELEASE` / `SENTRY_ENVIRONMENT` in `deploy/docker-compose.yml` for `orders-api` or `orders-worker`; the Python SDK then defaults `environment` to `production` everywhere. Fix: pass both from the deploy. Proof: V202.

## OD-ET-02a — The invoice worker has no `unhandledRejection` hook and no tracker

```defect
id:       OD-ET-02a
file:     worker/src/main.ts
line:     7
severity: high
command:  /obs-audit
class:    errors/no-process-hook
detector: error-tracking-scan §2
anchor:   const app = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
match:    unhandledRejection|uncaught|process hook|process\.on|crash|exit
```

Node 22 turns an unhandled rejection into an exit; the stack goes to stderr as text, outside the JSON logger, and the pod restarts silently. The API registers the hook; the worker does not. Fix: `process.on('unhandledRejection', (r) => logger.error('unhandled rejection', { err: r }))` then exit. Proof: V202 spawn test.

## OD-ET-02b — The outbox relay's drain goroutine has no `recover()`

```defect
id:       OD-ET-02b
file:     go-svc/cmd/worker/main.go
line:     23
severity: high
command:  /obs-audit
class:    errors/goroutine-without-recover
detector: error-tracking-scan §2
anchor:   go func() {
match:    recover|panic|goroutine
```

A panic in `DrainOutbox` kills the relay process with nothing in the JSON log; stock events stop flowing to the warehouse. Fix: `defer func(){ if r := recover(); r != nil { logger.Error("drain panicked", zap.Any("panic", r)) } }()` in the loop body. Proof: V202 — panic in a test double, assert one error line.

## OD-ET-03a — The storefront build emits source maps and never uploads them

```defect
id:       OD-ET-03a
file:     web/vite.config.ts
line:     8
severity: medium
command:  /obs-audit
class:    errors/maps-never-uploaded
detector: error-tracking-scan §3
anchor:   sourcemap: true,
match:    source ?map|upload|symbolicat|minif|plugin
```

No `sentryVitePlugin`, no `sentry-cli sourcemaps inject/upload` step: every production stack trace is minified. (The maps left in `dist/` are also publicly served — security `xss-scan` § 13's half, routed.) Fix: `sourcemap: 'hidden'` + `sentryVitePlugin({ sourcemaps: { filesToDeleteAfterUpload: ['./dist/**/*.map'] } })`. Proof: V202 L-tier, else `NO-DATA(tracker)` with the command written out.

## OD-ET-03b — Admin maps are uploaded under `$GIT_SHA`; the SDK reports `admin@1.4.0`

```defect
id:       OD-ET-03b
file:     admin/package.json
line:     8
severity: medium
command:  /obs-audit
class:    errors/release-mismatch-no-debug-ids
detector: error-tracking-scan §3
anchor:   "sentry:upload": "sentry-cli sourcemaps upload --release
match:    release|GIT_SHA|admin@1\.4\.0|mismatch|inject|debug.?id
```

No `sentry-cli sourcemaps inject`, so no debug IDs: matching falls back to the release name, and the two differ — admin frames stay minified. Fix: `sentry-cli sourcemaps inject dist && sentry-cli sourcemaps upload dist` (or one release value in both places). Proof: V202.

## OD-ET-04a — Unknown API errors become a 500 with no log and no capture

```defect
id:       OD-ET-04a
file:     api/src/common/all-exceptions.filter.ts
line:     15
severity: high
command:  /obs-audit
class:    errors/boundary-500-silent
detector: error-tracking-scan §4
anchor:   void reply.status(500).send({ statusCode: 500, message: 'Internal server error' });
match:    500|5xx|capture|log|silent
```

Everything that is not an `HttpException` ends here, and the API has no tracker: a database error or a PSP outage leaves only the status code. Fix: `this.logger.error({ err: exception }, 'unhandled')` (and a tracker capture when one is adopted). Proof: V202 — a throwing route through `fastify.inject`, one error line per 500.

## OD-ET-04b — The refunds `@ControllerAdvice` maps every exception to 500 silently

```defect
id:       OD-ET-04b
file:     jvm-svc/src/main/java/com/harbor/refunds/ApiErrorAdvice.java
line:     19
severity: medium
command:  /obs-audit
class:    errors/boundary-500-silent
detector: error-tracking-scan §4
anchor:   return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
match:    500|5xx|INTERNAL_SERVER_ERROR|capture|log|silent
```

Spring no longer logs an exception an advice has handled. Fix: `log.error("unhandled exception", ex)` in `unexpected(...)`. Proof: V202 with MockMvc.

## OD-AL-01a — `OrdersFailing` pages with no `for`

```defect
id:       OD-AL-01a
file:     deploy/prometheus/rules/api.rules.yml
line:     33
severity: medium
command:  /obs-audit
class:    alerts/page-without-for
detector: alert-rule-lint §1
anchor:   - alert: OrdersFailing
match:    \bfor\b|one.?sample|blip|spike|debounce
```

One evaluation above 20 failures pages on-call. Fix: `for: 5m`. Proof: V203 promtool blip/sustained pair.

## OD-AL-01b — `PaymentErrorsSustained` waits an hour before paging

```defect
id:       OD-AL-01b
file:     deploy/prometheus/rules/api.rules.yml
line:     53
severity: medium
command:  /obs-audit
class:    alerts/page-for-too-long
detector: alert-rule-lint §1
anchor:   for: 1h
match:    \bfor\b|1h|late|30m|hour
```

Past `THR-OBS-ALERT.page_for_max` (30m): a capture outage pages after an hour of failed payments. Fix: `for: 10m`. Proof: V203.

## OD-AL-02a — `RefundErrors` pages with no `runbook_url`

```defect
id:       OD-AL-02a
file:     deploy/prometheus/rules/api.rules.yml
line:     61
severity: medium
command:  /obs-audit
class:    alerts/page-without-runbook
detector: alert-rule-lint §2
anchor:   - alert: RefundErrors
match:    runbook
```

Every other page in the file links a runbook; this one does not (the unit is the rule, not the file). Fix: add it. Proof: pint `alerts/annotation`.

## OD-AL-02b — The summary reads `$labels.instance` after `sum by (job)`

```defect
id:       OD-AL-02b
file:     deploy/prometheus/rules/api.rules.yml
line:     31
severity: low
command:  /obs-audit
class:    alerts/template-label-dropped
detector: alert-rule-lint §2
anchor:   summary: "5xx rate above 10/s on {{ $labels.instance }}"
match:    instance|label|template|by \(job\)
```

The aggregation drops `instance`, so the notification reads "on ". Fix: use `{{ $labels.job }}`. Proof: promtool `exp_annotations`.

## OD-AL-02c — `$value` in a label

```defect
id:       OD-AL-02c
file:     deploy/prometheus/rules/api.rules.yml
line:     105
severity: high
command:  /obs-audit
class:    alerts/value-in-labels
detector: alert-rule-lint §2
anchor:   failed_orders: "{{ $value }}"
match:    \$value|value
```

Every new value is a new alert identity: `for: 5m` never completes, and notifications churn. Fix: move it to an annotation. Proof: pint / promtool.

## OD-AL-02d — The Pyrra burn pages (`severity: critical`) carry no runbook

```defect
id:       OD-AL-02d
file:     deploy/slo/pyrra/generated/api-latency.yaml
line:     54
severity: medium
command:  /obs-audit
class:    alerts/page-without-runbook
detector: alert-rule-lint §2
anchor:   exhaustion: 4d
match:    runbook
```

The 14× and 7× `ErrorBudgetBurn` tiers page and link nowhere (generated rules: fix at the generator or in the Alertmanager template, never by hand, precedents § 42). Proof: pint `alerts/annotation` on the generated file.

## OD-AL-03a — A raw counter compared to a constant

```defect
id:       OD-AL-03a
file:     deploy/prometheus/rules/api.rules.yml
line:     43
severity: medium
command:  /obs-audit
class:    alerts/raw-counter-threshold
detector: alert-rule-lint §3
anchor:   expr: orders_failed_total > 100
match:    rate|increase|raw counter|counter
```

`orders_failed_total > 100` is true for ever once the process has failed 100 orders since start, and resets on restart. Fix: `increase(orders_failed_total[1h]) > 100`. Proof: V204.

## OD-AL-03b — `rate(sum(…)[10m:1m])` — rate over an aggregation

```defect
id:       OD-AL-03b
file:     deploy/prometheus/rules/api.rules.yml
line:     71
severity: medium
command:  /obs-audit
class:    alerts/rate-over-aggregation
detector: alert-rule-lint §3
anchor:   rate(sum(http_requests_total{job="api"})[10m:1m])
match:    rate\(sum|aggregat|reset|subquery
```

Summing first hides every replica's counter reset: a restart reads as a huge negative rate step. Fix: `sum(rate(http_requests_total{job="api"}[10m]))`. Proof: V204 with a reset in the input series.

## OD-AL-03c — `histogram_quantile` over `sum … by (job)` drops `le`

```defect
id:       OD-AL-03c
file:     deploy/prometheus/rules/api.rules.yml
line:     80
severity: medium
command:  /obs-audit
class:    alerts/quantile-without-le
detector: alert-rule-lint §3
anchor:   histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job="api"}[5m])) by (job))
match:    \ble\b|bucket|histogram_quantile
```

Without `le` the quantile is NaN: the p99 page cannot fire. Fix: `by (job, le)`. Proof: V204.

## OD-AL-04a — `http_request_duration_second_bucket` — a selector no code registers

```defect
id:       OD-AL-04a
file:     deploy/prometheus/rules/api.rules.yml
line:     90
severity: high
command:  /obs-audit
class:    alerts/selector-not-in-inventory
detector: alert-rule-lint §4
anchor:   http_request_duration_second_bucket
match:    second_bucket|typo|inventory|never.?fire|missing|exist|_seconds
```

The registered histogram is `http_request_duration_seconds`; this page selects nothing and never fires. HIGH Unconfirmed until a live `count()` (precedents § 16). Fix: the right name. Proof: inventory diff + live count (V203/V204).

## OD-AL-04b — `legacy-imports.yml` matches no `rule_files` glob

```defect
id:       OD-AL-04b
file:     deploy/prometheus/rules/legacy-imports.yml
line:     4
severity: high
command:  /obs-audit
class:    alerts/rule-never-loaded
detector: alert-rule-lint §4
anchor:   - alert: CatalogFeedStale
match:    rule_files|glob|never loaded|not loaded|legacy-imports
```

`prometheus.yml` loads `rules/*.rules.yml`; this file is `legacy-imports.yml`, so the feed-staleness page is never evaluated. Fix: rename to `catalog.rules.yml`. Proof: the glob and the file name, both cited.

## OD-AL-04c — The worker PrometheusRule is labelled `release: kps`; the Prometheus CR selects `release: monitoring`

```defect
id:       OD-AL-04c
file:     deploy/k8s/prometheusrule-worker.yaml
line:     6
severity: high
command:  /obs-audit
class:    alerts/prometheusrule-not-selected
detector: alert-rule-lint §4
anchor:   release: kps
match:    ruleSelector|release|kps|selected|loaded
```

None of the four invoice-worker alerts — one of them a page — is loaded by the operator. Fix: `release: monitoring`. Proof: the CR selector and the rule labels, both cited.

## OD-AL-05a — `rate(…[30s])` on the `api` job, scraped every 30 s

```defect
id:       OD-AL-05a
file:     deploy/prometheus/rules/api.rules.yml
line:     15
severity: high
command:  /obs-audit
class:    alerts/window-under-2x-scrape
detector: alert-rule-lint §5
anchor:   code=~"5.."}[30s]
match:    30s|scrape|window|interval
```

Exactly one scrape interval: on Prometheus 3 (compose and CR both v3.5.0, read from file) the left-open range holds one sample and `rate()` returns nothing — `ApiErrorBurst` never fires. Fix: `[2m]` (4×). Proof: V204 — `[30s]` → `[]`, `[1m]` fires.

## OD-AL-05b — `le="1"` on a Prometheus 3 server

```defect
id:       OD-AL-05b
file:     deploy/prometheus/rules/api.rules.yml
line:     110
severity: high
command:  /obs-audit
class:    alerts/prometheus3-integer-le
detector: alert-rule-lint §5
anchor:   le="1"}[5m]
match:    le="?1|1\.0|float|Prometheus 3|normali
```

Prometheus 3 normalizes `le` to floats (`"1.0"`); `le="1"` matches nothing and `ApiFastRequestsDropped` never fires (precedents § 45). Fix: `le="1.0"`. Proof: V204 on 3.x.

## OD-AL-06a — The API 5xx ratio page has no zero-traffic sibling

```defect
id:       OD-AL-06a
file:     deploy/prometheus/rules/api.rules.yml
line:     4
severity: medium
command:  /obs-audit
class:    alerts/ratio-nan-no-traffic-sibling
detector: alert-rule-lint §6
anchor:   - alert: ApiHigh5xxRatio
match:    NaN|zero traffic|0/0|traffic|absent|sibling
```

At zero traffic the ratio is 0/0 = NaN and the page is silent through a total outage; no other rule watches API traffic (compare `OrdersApi5xxRatio` + `OrdersApiNoTraffic`, decoy `OD-DECOY-22`). Fix: `sum(rate(http_requests_total{job="api"}[5m])) == 0` for 10m, page. Proof: V204 total-outage test.

## OD-AL-06b — `absent(up{job=~"api.*"})` with no `for`

```defect
id:       OD-AL-06b
file:     deploy/prometheus/rules/api.rules.yml
line:     119
severity: medium
command:  /obs-audit
class:    alerts/absent-misuse
detector: alert-rule-lint §6
anchor:   expr: absent(up{job=~"api.*"})
match:    absent|regex|\bfor\b
```

No `for` pages on the first missed scrape or a restart; the regex means one surviving target hides every missing one. Fix: `absent(up{job="api"})` with `for: 5m`. Proof: V204.

## OD-AL-07a — A CPU-above-80 % page

```defect
id:       OD-AL-07a
file:     deploy/prometheus/rules/api.rules.yml
line:     127
severity: medium
command:  /obs-audit
class:    alerts/cause-page
detector: alert-rule-lint §7
anchor:   - alert: HostCpuHigh
match:    CPU|cause|symptom|resource
```

A cause, not a user-facing symptom, and not definite-and-imminent (precedents § 4). Fix: demote to a ticket or a dashboard. Proof: V206 routes matrix for the ticket set.

## OD-AL-07b — orders-api latency pages on the mean

```defect
id:       OD-AL-07b
file:     deploy/prometheus/rules/orders-api.rules.yml
line:     5
severity: low
command:  /obs-audit
class:    alerts/mean-latency-page
detector: alert-rule-lint §7
anchor:   - alert: OrdersApiMeanLatencyHigh
match:    mean|average|_sum|_count|percentile|quantile
```

`rate(_sum) / rate(_count)` hides the tail. Fix: `histogram_quantile(0.99, sum by (le) (rate(…_bucket[5m])))`. (`rule-inventory.py` also prints two AL-10 rows here — an inventory gap, see IR-1.) Proof: S.

## OD-AL-08a — `severity=critical` reaches the `dev-null` root

```defect
id:       OD-AL-08a
file:     deploy/alertmanager/alertmanager.yml
line:     5
severity: high
command:  /obs-audit
class:    routing/emitted-set-to-null-receiver
detector: alert-rule-lint §8
anchor:   receiver: dev-null
match:    dev-null|null|critical|root|vanish|unmatched|receiver
```

The Pyrra burn pages emit `severity: critical`; the routes match only `page` and `ticket|warning`, so they fall to the root receiver, which has no integrations. Fix: route `severity=~"page|critical"` to PagerDuty. Proof: V206 — `amtool config routes test --verify.receivers=pagerduty-oncall severity=critical` exits 1.

## OD-AL-08b — The inhibit rule matches on `cluster`, which no rule emits

```defect
id:       OD-AL-08b
file:     deploy/alertmanager/alertmanager.yml
line:     33
severity: medium
command:  /obs-audit
class:    routing/inhibit-equal-unemitted
detector: alert-rule-lint §8
anchor:   equal: [cluster]
match:    cluster|inhibit|equal
```

Empty equals empty: any page mutes every ticket across all services. Fix: `equal: [team]` or a label the rules emit. Proof: V206 with a containerised Alertmanager, else `NO-DATA(alertmanager)` with the static half cited.

## OD-AL-09a — The Grafana-managed login page treats no data as OK

```defect
id:       OD-AL-09a
file:     deploy/grafana/provisioning/alerting/api-alerts.yaml
line:     24
severity: medium
command:  /obs-audit
class:    vendor-monitors/no-data-ok
detector: alert-rule-lint §9
anchor:   noDataState: OK
match:    noDataState|no.?data|OK
```

A dead datasource or a renamed series silences the login-errors page. Fix: `noDataState: Alerting` (or NoData with a companion datasource-loss rule, precedents § 11). Proof: V205 field check.

## OD-AL-09b — The storefront traffic monitor: no `notify_no_data`, no recipient

```defect
id:       OD-AL-09b
file:     deploy/monitors/datadog.tf
line:     39
severity: medium
command:  /obs-audit
class:    vendor-monitors/traffic-no-notify-no-data
detector: alert-rule-lint §9
anchor:   resource "datadog_monitor" "storefront_traffic"
match:    notify_no_data|no.?data|@|recipient|handle
```

A traffic monitor whose data stops is exactly the outage it watches, and its `message` names no `@` handle, so even a trigger notifies nobody. Fix: `notify_no_data = true`, `no_data_timeframe = 20`, `@pagerduty-web-oncall`. Proof: V205.

## OD-AL-09c — The New Relic error-rate condition fills gaps with the last value

```defect
id:       OD-AL-09c
file:     deploy/monitors/newrelic.tf
line:     25
severity: medium
command:  /obs-audit
class:    vendor-monitors/fill-last-value
detector: alert-rule-lint §9
anchor:   fill_option                  = "last_value"
match:    fill_option|last_value|fill|gap
```

When orders-api stops reporting, the last (healthy) error rate is repeated: the condition cannot open. Fix: `fill_option = "none"` with the expiration handling it already has. Proof: V205.

## OD-SLO-01a — `search-availability` has both sloth alert tiers disabled

```defect
id:       OD-SLO-01a
file:     deploy/slo/sloth/api.yml
line:     50
severity: medium
command:  /obs-audit
class:    slo/no-burn-alert
detector: slo-rule-scan §1
anchor:   - name: "search-availability"
match:    disable|alert|burn
```

The registry lists it in force at 99.5 %; `sloth generate` emits zero alerts for it and no hand-written rule covers it. Fix: enable the page and ticket alerts. Proof: V207 — regenerate, count `alert:`.

## OD-SLO-01b — The Datadog checkout SLO has no `slo alert` monitor

```defect
id:       OD-SLO-01b
file:     deploy/monitors/datadog.tf
line:     20
severity: medium
command:  /obs-audit
class:    slo/no-burn-alert
detector: slo-rule-scan §1
anchor:   resource "datadog_service_level_objective" "checkout_web"
match:    slo alert|monitor|burn|alert
```

No `datadog_monitor` with `type = "slo alert"` references it: the budget can burn to zero silently. Fix: add the burn-rate monitor. Proof: the resource set, cited.

## OD-SLO-02a — Payments burn tiers use a 99 % budget on a 99.9 % SLO

```defect
id:       OD-SLO-02a
file:     deploy/prometheus/rules/payments-slo.rules.yml
line:     18
severity: high
command:  /obs-audit
class:    slo/burn-budget-for-another-objective
detector: slo-rule-scan §2
anchor:   expr: payments:error_ratio:rate1h > 14.4 * (1 - 0.99)
match:    0\.99|99\.9|objective|budget|0\.01|0\.001|10 ?x|10×
```

`14.4 * (1 - 0.99)` — copied from another SLO — fires at 10× the intended burn on the registry's 99.9 % / 30d objective, i.e. never in practice; all three tiers share it. `burn-check.py --slo='PaymentsAvailability.*=99.9/30d'` prints SLO-03 H. (The eval's `14*(1-0.999)` shape is only a § 12 note: 1.94 % vs 2 %.) Fix: `(1 - 0.999)`. Proof: V207 arithmetic + promtool pair.

## OD-SLO-02b — The committed sloth output was hand-edited: the 6× tier reads 5×

```defect
id:       OD-SLO-02b
file:     deploy/slo/generated/api.yml
line:     171
severity: medium
command:  /obs-audit
class:    slo/generated-rules-hand-edited
detector: slo-rule-scan §2
anchor:   ratio_rate6h{sloth_id="api-requests-availability", sloth_service="api", sloth_slo="requests-availability"} > (5 *
match:    \b5\b|hand.?edit|drift|regenerat|factor
```

`sloth generate` from `deploy/slo/sloth/api.yml` emits 6 × 30m/6h; the committed file says 5 (`burn-check.py`: factor 5 vs expected 6, SLO-03 M). Generated rules are fixed at the spec and regenerated (precedents § 42). Proof: V207 regenerate-and-diff.

## OD-SLO-03a — A 100 % objective for partner webhooks

```defect
id:       OD-SLO-03a
file:     deploy/slo/openslo/partner-webhooks.yaml
line:     32
severity: high
command:  /obs-audit
class:    slo/impossible-objective
detector: slo-rule-scan §3
anchor:   target: 1.0
match:    100 ?%|1\.0|no (?:error )?budget|impossible
```

No error budget: every failed delivery is an incident and no burn rate exists (precedents § 14; `burn-check.py` SLO-04 H). Fix: the agreement's real figure (e.g. 99.9 %). Proof: S.

## OD-SLO-03b — A few dozen exports a day on the 14.4× / 1h page

```defect
id:       OD-SLO-03b
file:     deploy/slo/sloth/api.yml
line:     29
severity: low
command:  /obs-audit
class:    slo/low-traffic-standard-tiers
detector: slo-rule-scan §3
anchor:   - name: "admin-export-availability"
match:    low.?traffic|admin|export|few|traffic|one (?:error|failure)
```

At that volume one failed export is a 2–5 % error ratio over the hour and pages (precedents § 15). Fix: ticket-only tiers or a longer window. Proof: S; the traffic half is L-tier.

## OD-SLO-04a — The API availability SLI counts 4xx as failures

```defect
id:       OD-SLO-04a
file:     deploy/slo/sloth/api.yml
line:     13
severity: medium
command:  /obs-audit
class:    slo/4xx-counted-as-bad
detector: slo-rule-scan §4
anchor:   code=~"4..|5.."}[{{.window}}]
match:    4xx|4\.\.|404|client
```

Every 404 and validation error spends budget (precedents § 13; no doc names a 4xx class as a server failure). Fix: `code=~"5.."`. Proof: V207 — replay 404s, the SLI must not move.

## OD-SLO-04b — The admin-export SLI counts only `code="500"`

```defect
id:       OD-SLO-04b
file:     deploy/slo/sloth/api.yml
line:     34
severity: medium
command:  /obs-audit
class:    slo/only-500-counted
detector: slo-rule-scan §4
anchor:   code="500"}[{{.window}}]
match:    500|502|503|504|5xx|5\.\.
```

502, 503 and 504 — the gateway and timeout failures — never spend budget. Fix: `code=~"5.."`. Proof: V207.

## OD-SLO-05a — The checkout latency SLI reads `le="0.25"`; the histogram's edges are 0.1, 0.5, 1, 2

```defect
id:       OD-SLO-05a
file:     deploy/prometheus/rules/slo-latency.rules.yml
line:     6
severity: high
command:  /obs-audit
class:    slo/latency-threshold-not-a-bucket-edge
detector: slo-rule-scan §5
anchor:   checkout_duration_seconds_bucket{le="0.25"}[5m]
match:    0\.25|bucket|edge
```

No 0.25 bucket exists, so the numerator is empty and the SLI reads every checkout as slow — the burn alerts fire on nothing real. Fix: add 0.25 to `checkoutDuration`'s buckets. Proof: V199 `count(checkout_duration_seconds_bucket{le="0.25"}) > 0`.

## OD-SLO-05b — The inventory latency SLI reads `le="0.2"` on `prometheus.DefBuckets`

```defect
id:       OD-SLO-05b
file:     deploy/prometheus/rules/slo-latency.rules.yml
line:     38
severity: high
command:  /obs-audit
class:    slo/latency-threshold-not-a-bucket-edge
detector: slo-rule-scan §5
anchor:   inventory_reserve_duration_seconds_bucket{le="0.2"}[2h]
match:    0\.2|bucket|edge|DefBuckets
```

client_golang's default buckets are .005 … .1, .25, .5 … 10: no 0.2 edge. Fix: explicit buckets with 0.2. Proof: V199.

## OD-SLO-06a — 30-day SLOs on a Prometheus that keeps 15 days

```defect
id:       OD-SLO-06a
file:     deploy/docker-compose.yml
line:     71
severity: medium
command:  /obs-audit
class:    slo/window-longer-than-retention
detector: slo-rule-scan §6
anchor:   --storage.tsdb.retention.time=15d
match:    retention|15d|30d|28d|long.?term
```

The compose Prometheus evaluates every SLO rule and keeps 15d with no Thanos / Mimir / remote read: budgets and the 30d ratio are computed on half the period (`burn-check.py --retention=15d`: SLO-10 on five SLOs, one finding). Fix: `--storage.tsdb.retention.time=35d` or a long-term store. Proof: S.

## OD-SLO-06b — Ten SLOs and no error-budget policy

```defect
id:       OD-SLO-06b
file:     ai/runtime/slos.md
line:     1
severity: low
command:  /obs-audit
class:    slo/no-budget-policy
detector: slo-rule-scan §6
anchor:   # SLO registry — Harbor
match:    polic|exhaust
```

No policy document in the repo and none in the registry: nothing says what happens when a budget is gone. Fix: a policy (owner, freeze rule) — `@sre-engineer` writes the text. Proof: S.

## OD-PL-01a — `batch` runs before `memory_limiter` in the traces pipeline

```defect
id:       OD-PL-01a
file:     deploy/otel/collector.yaml
line:     75
severity: medium
command:  /obs-audit
class:    pipeline/processor-order
detector: telemetry-config-scan §1
anchor:   processors: [batch, memory_limiter, k8sattributes, probabilistic_sampler, tail_sampling]
match:    memory_limiter|order|first|batch
```

`memory_limiter` must be first to refuse data under pressure, and `batch` belongs last. Fix: `[memory_limiter, k8sattributes, …, batch]`. Proof: V208 key diff + validate on a copy.

## OD-PL-01b — `filter/drop-probes` is defined and wired into no pipeline

```defect
id:       OD-PL-01b
file:     deploy/otel/collector.yaml
line:     39
severity: medium
command:  /obs-audit
class:    pipeline/component-unused
detector: telemetry-config-scan §1
anchor:   filter/drop-probes:
match:    unused|not referenced|filter|pipeline|wired
```

The probe spans it was written to drop reach Tempo (`otelcol validate` passes unused components). Fix: add it to the traces pipeline. Proof: V208 key diff.

## OD-PL-02a — Retries are off on the Tempo exporter

```defect
id:       OD-PL-02a
file:     deploy/otel/collector.yaml
line:     57
severity: medium
command:  /obs-audit
class:    pipeline/exporter-retry-off
detector: telemetry-config-scan §2
anchor:   retry_on_failure:
match:    retr(?:y|ies)
```

Any Tempo restart or 503 drops the batch. Fix: remove the override (the default retries). Proof: V208 — a sink answering 503 for 30 s, count what arrives.

## OD-PL-02b — The gateway's Loki exporter has its sending queue switched off

```defect
id:       OD-PL-02b
file:     deploy/otel/collector.yaml
line:     62
severity: medium
command:  /obs-audit
class:    pipeline/exporter-queue-off
detector: telemetry-config-scan §2
anchor:   sending_queue:
match:    queue|sending_queue
```

With no queue a slow Loki back-pressures every log producer through the gateway. Fix: the default queue (with `storage` where loss on restart matters). Proof: V208.

## OD-PL-03a — Tail sampling on a 3-replica gateway behind a round-robin Service

```defect
id:       OD-PL-03a
file:     deploy/otel/collector.yaml
line:     26
severity: medium
command:  /obs-audit
class:    pipeline/tail-sampling-no-load-balancer
detector: telemetry-config-scan §3
anchor:   tail_sampling:
match:    load.?balanc|replica|routing_key|trace.?id|same trace
```

Spans of one trace reach different replicas and each decides alone. Fix: an agent tier with the `loadbalancing` exporter (`routing_key: traceID`) in front. Proof: S — replica count, Service, no balancer.

## OD-PL-03b — `decision_wait: 1s` while the policy itself keeps traces over 2 s

```defect
id:       OD-PL-03b
file:     deploy/otel/collector.yaml
line:     27
severity: medium
command:  /obs-audit
class:    pipeline/tail-decision-too-early
detector: telemetry-config-scan §3
anchor:   decision_wait: 1s
match:    decision_wait|1s|wait
```

The decision is taken before slow traces finish. Fix: above the p99 trace duration (e.g. 10s). Proof: S.

## OD-PL-04a — Promtail promotes `trace_id` and `user_id` to stream labels

```defect
id:       OD-PL-04a
file:     deploy/promtail/promtail.yaml
line:     25
severity: high
command:  /obs-audit
class:    pipeline/loki-label-holds-id
detector: telemetry-config-scan §4
anchor:   - labels:
match:    trace_id|user_id|label|cardinal|stream
```

One Loki stream per request and per user: past the tenant stream limit pushes are rejected and logs drop in the incident. Fix: structured metadata for `trace_id`, keep `user_id` in the line. Proof: L `logcli series --analyze-labels`, else `NO-DATA(loki)` with the arithmetic.

## OD-PL-04b — Alloy promotes the request path to a stream label

```defect
id:       OD-PL-04b
file:     deploy/alloy/config.alloy
line:     32
severity: medium
command:  /obs-audit
class:    pipeline/loki-label-holds-id
detector: telemetry-config-scan §4
anchor:   values = { level = "", path = "" }
match:    path|label|cardinal|stream
```

`req.url` with ids and query strings. Fix: drop `path` from `stage.labels`. Proof: as OD-PL-04a.

## OD-PL-05a — Promtail still ships production logs

```defect
id:       OD-PL-05a
file:     deploy/docker-compose.yml
line:     117
severity: medium
command:  /obs-audit
class:    pipeline/promtail-eol
detector: telemetry-config-scan §5
anchor:   image: grafana/promtail:3.0.0
match:    promtail|end.?of.?life|EOL|Alloy|deprecat
```

Promtail reached end of life on 2026-03-02 (precedents § 51). Fix: finish the Alloy conversion (`alloy-edge`, `OD-PL-05b`). Proof: the image line.

## OD-PL-05b — The converted edge Alloy config forwards to a component that does not exist

```defect
id:       OD-PL-05b
file:     deploy/alloy/edge.alloy
line:     22
severity: medium
command:  /obs-audit
class:    pipeline/shipper-config-invalid
detector: telemetry-config-scan §5
anchor:   forward_to = [loki.write.grafana_cloud.receiver]
match:    grafana_cloud|undefined|not defined|validate|forward_to|edge
```

Only `loki.write "edge"` is defined; `alloy validate` exits 1 and `alloy-edge` cannot start. Fix: `loki.write.edge.receiver`. Proof: V208 shipper validate.

## OD-PL-06a — Loki states 31-day retention with compactor retention off

```defect
id:       OD-PL-06a
file:     deploy/loki/loki.yaml
line:     30
severity: medium
command:  /obs-audit
class:    pipeline/retention-not-enforced
detector: telemetry-config-scan §6
anchor:   retention_period: 744h
match:    retention_enabled|compactor|retention|delete
```

Without `compactor.retention_enabled: true` (and `delete_request_store`) nothing is deleted — logs live forever. Fix: both keys. Proof: V208 key pair + `-verify-config`.

## OD-PL-06b — `${LOKI_BUCKET}` without `-config.expand-env=true`

```defect
id:       OD-PL-06b
file:     deploy/loki/loki.yaml
line:     15
severity: medium
command:  /obs-audit
class:    pipeline/config-env-not-expanded
detector: telemetry-config-scan §6
anchor:   bucketnames: ${LOKI_BUCKET}
match:    expand-env|\$\{|env|LOKI_BUCKET|expand
```

Compose starts Loki with `-config.file=…` only, so the bucket name is the literal string. Fix: add `-config.expand-env=true`. Proof: `loki -verify-config` exits 1 without the flag, 0 with it.

## OD-PL-07a — The production gateway prints every span at `verbosity: detailed`

```defect
id:       OD-PL-07a
file:     deploy/otel/collector.yaml
line:     69
severity: medium
command:  /obs-audit
class:    pipeline/debug-exporter-in-production
detector: telemetry-config-scan §7
anchor:   verbosity: detailed
match:    debug|detailed|verbosity
```

Cost, and every attribute in plain container logs (the PII half is security's). Fix: drop `debug` from the traces exporters. Proof: S — the key in the file the kustomization mounts.

## OD-PL-07b — The worker ServiceMonitor is never selected

```defect
id:       OD-PL-07b
file:     deploy/k8s/servicemonitor-worker.yaml
line:     6
severity: high
command:  /obs-audit
class:    pipeline/monitor-not-selected
detector: telemetry-config-scan §7
anchor:   release: kps
match:    serviceMonitorSelector|release|kps|scrap|selected
```

`serviceMonitorSelector` matches `release: monitoring`; the worker's metrics — which the worker page alerts read — are never scraped. Fix: `release: monitoring`. Proof: the selector and the labels, both cited.

## OD-PL-08a — A panel pins a datasource uid that is not provisioned

```defect
id:       OD-PL-08a
file:     deploy/grafana/provisioning/dashboards/api-red.json
line:     90
severity: low
command:  /obs-audit
class:    dashboards/hard-coded-datasource
detector: telemetry-config-scan §8
anchor:   "uid": "P1809F7CD0C75ACF3"
match:    datasource|uid|P1809
```

The stack provisions Prometheus as uid `prometheus`; the latency panel names an imported uid and shows "datasource not found". Fix: `${datasource}`. Proof: dashboard-linter error row + `dash.py`.

## OD-PL-08b — "Orders placed" graphs a raw counter

```defect
id:       OD-PL-08b
file:     deploy/grafana/provisioning/dashboards/orders.json
line:     51
severity: low
command:  /obs-audit
class:    dashboards/counter-without-rate
detector: telemetry-config-scan §8
anchor:   sum(orders_created_total{job=
match:    rate|increase|counter|orders_created_total
```

A monotonic total since process start, reset on every deploy. Fix: `sum(increase(orders_created_total[$__range]))` or a rate. Proof: `dash.py` counter-no-rate.

## OD-PL-08c — `rate(…[30s])` on the `api` job, scraped every 30 s

```defect
id:       OD-PL-08c
file:     deploy/grafana/provisioning/dashboards/api-latency.json
line:     51
severity: medium
command:  /obs-audit
class:    dashboards/rate-window-under-scrape
detector: telemetry-config-scan §8
anchor:   [30s]
match:    30s|rate_interval|window|scrape
```

Under 2× the scrape interval the panel is empty at every zoom on Prometheus 3. Fix: `$__rate_interval`. Proof: `dash.py` window flag.

## OD-AA-05a — Checkout latency has page tiers only

```defect
id:       OD-AA-05a
file:     deploy/prometheus/rules/slo-latency.rules.yml
line:     16
severity: medium
command:  /obs-audit
class:    alert-behaviour/burn-gap-page-tiers-only
detector: alert-audit §5
anchor:   - alert: CheckoutLatencyFastBurn
match:    ticket|slow (?:burn|tier)|page.?(?:tiers? )?only|1x|1×|3d|BURN GAP|leak
```

14.4× 1h/5m and 6× 6h/30m, both pages; no 3× / 1× ticket tier, so a steady 1× leak trips neither and the SLO is missed with no signal (BURN GAP M). The arithmetic itself passes `burn-check.py --slo='CheckoutLatency.*=99/30d'`. Fix: add the Workbook ticket tiers. Proof: the `slo-rule-scan` rows + the registry row.

## OD-AA-05b — `search-latency` is in force with no spec, no burn rule and no monitor

```defect
id:       OD-AA-05b
file:     ai/runtime/slos.md
line:     16
severity: high
command:  /obs-audit
class:    alert-behaviour/burn-gap-no-burn-alert
detector: alert-audit §5
anchor:   | search-latency |
match:    no burn|burn|alert|BURN GAP|rule
```

The registry row's rules column is empty and no rule reads a search latency SLI (BURN GAP H; slo-rule-scan's SLO-01 row credited there). Fix: `/alert-design` Phase 1. Proof: the registry row + the empty rule inventory.

## OD-SY-01a — Checkout has no synthetic probe

```defect
id:       OD-SY-01a
file:     api/src/checkout/checkout.controller.ts
line:     4
severity: high
command:  /obs-audit
class:    synthetic/journey-without-probe
detector: synthetic-monitoring §1
anchor:   @Controller('checkout')
match:    probe|synthetic|journey|monitor
```

The route table has `POST /checkout` and `web/src/pages/CheckoutPage.tsx`; the only probe config (`prometheus.yml` blackbox job) targets a health URL. `[report-flagged]` until a vendor inventory is read. Fix: a multi-step probe on a test account. Proof: the two-ended set-diff.

## OD-SY-02a — `login-probe` probes `/health/ready`

```defect
id:       OD-SY-02a
file:     deploy/prometheus/prometheus.yml
line:     44
severity: high
command:  /obs-audit
class:    synthetic/health-probe-claimed-as-journey
detector: synthetic-monitoring §2
anchor:   - targets: ['https://api.harbor.example/health/ready']
match:    health|ready|login|journey
```

The job and its comment claim the login journey; the target proves only that a replica is up (and `/health/ready` checks nothing, `OD-MT-07a`). It is the only probe on an auth journey. Fix: a probe that posts to `/auth/login` on a test account. Proof: S, the target and the claim side by side.

## OD-HO-SEC-a — pino-http's redact list misses both vendor token headers

```defect
id:       OD-HO-SEC-a
file:     api/src/app.module.ts
line:     31
severity: high
command:  /security-audit
class:    security/log-redaction-gap
detector: data-exposure-scan §6 (security)
anchor:   'req.headers["X-Partner-Token"]',
match:    x-partner-token|x-carrier-token|redact|lower.?case|case
```

Node lower-cases header names, so `req.headers["X-Partner-Token"]` never matches `x-partner-token`, and `x-carrier-token` (the carrier webhook's credential) is not listed at all: both are written into every request log line. Routed: `/obs-audit` lists it as security's, never grades it.

## OD-HO-SEC-b — The dispatch adapter logs name, phone and address at info

```defect
id:       OD-HO-SEC-b
file:     api/src/dispatch/dispatch.adapter.ts
line:     22
severity: high
command:  /security-audit
class:    security/pii-in-logs
detector: data-exposure-scan §6 (security)
anchor:   { orderId: order.id, name: order.customerName, phone: order.customerPhone, address: order.deliveryAddress },
match:    PII|personal|phone|address
```

Customer personal data in every dispatch line, shipped to Loki and kept by its retention. Routed (precedents § 32: never offer a hash as the fix).

## OD-HO-SEC-c — The storefront sends default PII to Sentry

```defect
id:       OD-HO-SEC-c
file:     web/src/sentry.prod.ts
line:     10
severity: medium
command:  /security-audit
class:    security/tracker-default-pii
detector: data-exposure-scan §6 (security)
anchor:   sendDefaultPii: true,
match:    sendDefaultPii|PII|personal|IP|cookie
```

IP addresses, cookies and user data on every event (`sendDefaultPii`, deprecated for `dataCollection` in JS SDK 10, precedents § 47). Routed.

## OD-HO-CQ-a — The order status-history write swallows its failure

```defect
id:       OD-HO-CQ-a
file:     api/src/orders/orders.service.ts
line:     49
severity: medium
command:  /quality-audit
class:    quality/error-dropped
detector: error-handling-scan §1 (code-quality)
anchor:   this.em.persistAndFlush(change).catch(() => undefined);
match:    catch|swallow|undefined|dropped|ignored|lost|silent
```

`.catch(() => undefined)` on a write: the history row can be lost with no trace. The caller cannot tell — code-quality's half (log-signal-scan § Boundaries). Routed.

## OD-HO-CQ-b — A comment-only catch around the carrier webhook's event write

```defect
id:       OD-HO-CQ-b
file:     api/src/webhooks/carrier-webhook.controller.ts
line:     21
severity: medium
command:  /quality-audit
class:    quality/error-dropped
detector: error-handling-scan §1 (code-quality)
anchor:   } catch {
match:    empty|comment|swallow|catch|ignored|dropped|silent
```

The raw carrier event is not recorded and the 202 tells the carrier it was. Routed.

## OD-HO-PERF-a — Liveness pings the database

```defect
id:       OD-HO-PERF-a
file:     api/src/health/health.controller.ts
line:     14
severity: medium
command:  /perf-audit
class:    performance/liveness-checks-shared-dependency
detector: request-path-scan §15 (performance)
anchor:   return this.health.check([() => this.db.pingCheck('database', { timeout: 1500 })]);
match:    liveness|live|database|DB|ping|restart
```

A Postgres blip fails liveness on every replica at once and the orchestrator restarts the whole fleet. Routed (metric-hygiene-scan § Boundaries).

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect, in the same product, built from the eval's decoy list (§ 3.6,
items 1–26 in order) and `precedents/observability.md`. How they score (`score.py`, § DECOYS): a finding that names the
decoy's file, cites a line within the tolerance window and matches every one of the decoy's `match:` patterns is
**pinned** to it, removed before defect assignment, and reported as `DECOYS FLAGGED k/N`. Every decoy sits more than 12
lines from any defect in its file (`--verify` enforces it). `OD-DECOY-05` also probes `/quality-audit` (the cause is
kept) and `OD-DECOY-14` also probes `/perf-audit` (a constant liveness is request-path-scan §15's right design).

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| OD-DECOY-01 | `api/src/payments/capture.service.ts:44` | OD-LG-02a | pino `error({ err }, msg)` keeps type and stack (precedents § 22) |
| OD-DECOY-02 | `api/src/orders/refund.service.ts:38` | OD-LG-02b | pino `error(err, msg)` is the documented error-first form (precedents § 22); the 4c log-and-rethrow print is refuted too: the rethrown error reaches a filter that does not log |
| OD-DECOY-03 | `api/src/ledger/ledger-export.ts:16` | OD-LG-02b | `ledgerLog` maps `error` through `pino.stdSerializers.err` (grep 0b prints it, precedents § 22) |
| OD-DECOY-04 | `api/src/notifications/notifications.service.ts:14` | OD-LG-02a | Nest `Logger.error(message, stack)`: the second argument is the trace (precedents § 38) |
| OD-DECOY-05 | `api/src/billing/charges.service.ts:23` | OD-LG-02a | the error is rethrown as `{ cause: e }` and `HttpExceptionFilter` logs `err` and `cause` (precedents § 39); the cause is not lost either (code-quality's §6) |
| OD-DECOY-06 | `api/src/metrics/slow-request.hook.ts:9` | OD-MT-01b | Fastify's route template, collapsed to `unmatched` for 404s (precedents § 29); probes skipped |
| OD-DECOY-07 | `go-svc/main.go:44` | OD-TR-09a | the ratio is the root sampler inside `ParentBased` |
| OD-DECOY-08 | `web/src/sentry.dev.ts:10` | OD-TR-09b | development-only init, imported behind `import.meta.env.DEV` (precedents § 30, § 33) |
| OD-DECOY-09 | `deploy/slo/pyrra/generated/api-latency.yaml:41` | OD-SLO-02a | Pyrra 14 / 7 / 2 / 1 on 28d passes `factor = budget_fraction × period / long_window` (precedents § 12) |
| OD-DECOY-10 | `deploy/slo/generated/api.yml:186` | OD-SLO-02b | sloth `google-30d`'s 3× 1d/2h ticket tier is an accepted Workbook tier (precedents § 12) |
| OD-DECOY-11 | `deploy/prometheus/rules/platform.rules.yml:5` | OD-AL-01a | a Watchdog takes no `for` and routes to the heartbeat receiver (precedents § 2) |
| OD-DECOY-12 | `deploy/prometheus/rules/platform.rules.yml:41` | OD-AL-02a | a ticket, not a page: no runbook required (precedents § 1) |
| OD-DECOY-13 | `deploy/prometheus/rules/platform.rules.yml:32` | OD-AL-05a | `[1m]` on a 15 s job is 4×: no row (precedents § 6) |
| OD-DECOY-14 | `py-svc/app/health.py:23` | OD-MT-07b | a constant liveness is the right design (metric-hygiene-scan §7, request-path-scan §15) |
| OD-DECOY-15 | `deploy/monitors/datadog.tf:3` | OD-AL-09b | an error-count monitor: no data means zero errors (precedents § 10) |
| OD-DECOY-16 | `deploy/alloy/config.alloy:50` | OD-PL-04b | level / app plus static cluster / namespace: a small fixed label set |
| OD-DECOY-17 | `api/src/checkout/checkout.service.ts:38` | OD-MT-01a | `trace_id` as an exemplar, not a label (precedents § 20) |
| OD-DECOY-18 | `go-svc/internal/inventory/handler.go:78` | OD-TR-01a | `context.WithoutCancel` keeps the trace values (precedents § 26) |
| OD-DECOY-19 | `py-svc/app/orders.py:32` | OD-TR-04b | `start_as_current_span` records the exception and sets ERROR by default (precedents § 25) |
| OD-DECOY-20 | `api/src/checkout/checkout.service.ts:23` | OD-MT-03a | converted to seconds |
| OD-DECOY-21 | `deploy/slo/pyrra/api-latency.yaml:14` | OD-SLO-05a | `http_request_duration_seconds` registers a 0.3 bucket |
| OD-DECOY-22 | `deploy/prometheus/rules/platform.rules.yml:12` | OD-AL-06a | `OrdersApiNoTraffic` (`== 0`, same job) is its zero-traffic sibling (precedents § 5) |
| OD-DECOY-23 | `api/.env.development:5` | OD-LG-04c | a development env file; production gets its environment from compose (precedents § 30) |
| OD-DECOY-24 | `deploy/alertmanager/alertmanager.yml:19` | OD-AL-08a | the incident bot dedupes per fingerprint itself (precedents § 8) |
| OD-DECOY-25 | `api/scripts/seed-dev.ts:14` | OD-LG-03a | a one-shot developer CLI no deploy file runs (precedents § 44; grep 3b2 empty) |
| OD-DECOY-26 | `api/src/audit/audit-logger.ts:17` | OD-LG-05a | the refund audit trail: its own sink and its own retention stream, never sampled or trimmed (precedents § 31) |

```decoy
id:       OD-DECOY-01
file:     api/src/payments/capture.service.ts
line:     44
command:  /obs-audit
class:    decoy/OD-LG-02a
anchor:   this.logger.error({ err, paymentId }, 'void failed');
match:    stack|lost|drop|serializ
```

```decoy
id:       OD-DECOY-02
file:     api/src/orders/refund.service.ts
line:     38
command:  /obs-audit
class:    decoy/OD-LG-02b
anchor:   this.logger.error(err, 'cancel refund failed');
match:    stack|lost|drop|argument
```

```decoy
id:       OD-DECOY-03
file:     api/src/ledger/ledger-export.ts
line:     16
command:  /obs-audit
class:    decoy/OD-LG-02b
anchor:   ledgerLog.error({ error: err, day }, 'ledger export failed');
match:    serializ|\{\}|error key|stack|lost
```

```decoy
id:       OD-DECOY-04
file:     api/src/notifications/notifications.service.ts
line:     14
command:  /obs-audit
class:    decoy/OD-LG-02a
anchor:   this.logger.error('push delivery failed', (err as Error).stack);
match:    stack|lost|string
```

```decoy
id:       OD-DECOY-05
file:     api/src/billing/charges.service.ts
line:     23
command:  /obs-audit /quality-audit
class:    decoy/OD-LG-02a
anchor:   this.logger.warn('charge declined, rethrowing with the PSP error as its cause');
match:    cause|stack|lost|error object|binding
```

```decoy
id:       OD-DECOY-06
file:     api/src/metrics/slow-request.hook.ts
line:     9
command:  /obs-audit
class:    decoy/OD-MT-01b
anchor:   const route = request.routeOptions.url ?? 'unmatched';
match:    unbounded|cardinal|raw (?:url|path)
```

```decoy
id:       OD-DECOY-07
file:     go-svc/main.go
line:     44
command:  /obs-audit
class:    decoy/OD-TR-09a
anchor:   sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))),
match:    ParentBased|parent|ratio|sampler
```

```decoy
id:       OD-DECOY-08
file:     web/src/sentry.dev.ts
line:     10
command:  /obs-audit
class:    decoy/OD-TR-09b
anchor:   tracesSampleRate: 1.0,
match:    tracesSampleRate|1\.0|100 ?%|sampl
```

```decoy
id:       OD-DECOY-09
file:     deploy/slo/pyrra/generated/api-latency.yaml
line:     41
command:  /obs-audit
class:    decoy/OD-SLO-02a
anchor:   burnrate5m{job="api",slo="api-latency"} > (14 *
match:    factor|14\.4|multiplier
```

```decoy
id:       OD-DECOY-10
file:     deploy/slo/generated/api.yml
line:     186
command:  /obs-audit
class:    decoy/OD-SLO-02b
anchor:   ratio_rate1d{sloth_id="api-requests-availability", sloth_service="api", sloth_slo="requests-availability"} > (3 *
match:    factor|\b3x|3×|fourth|4th|24h|1d
```

```decoy
id:       OD-DECOY-11
file:     deploy/prometheus/rules/platform.rules.yml
line:     5
command:  /obs-audit
class:    decoy/OD-AL-01a
anchor:   expr: vector(1)
match:    \bfor\b|watchdog
```

```decoy
id:       OD-DECOY-12
file:     deploy/prometheus/rules/platform.rules.yml
line:     41
command:  /obs-audit
class:    decoy/OD-AL-02a
anchor:   - alert: RefundsFailing
match:    runbook
```

```decoy
id:       OD-DECOY-13
file:     deploy/prometheus/rules/platform.rules.yml
line:     32
command:  /obs-audit
class:    decoy/OD-AL-05a
anchor:   path="/v1/reservations",code=~"5.."}[1m]
match:    1m|window|scrape
```

```decoy
id:       OD-DECOY-14
file:     py-svc/app/health.py
line:     23
command:  /obs-audit /perf-audit
class:    decoy/OD-MT-07b
anchor:   return {"status": "ok"}
match:    liveness|livez|constant|always|200
```

```decoy
id:       OD-DECOY-15
file:     deploy/monitors/datadog.tf
line:     3
command:  /obs-audit
class:    decoy/OD-AL-09b
anchor:   resource "datadog_monitor" "storefront_js_errors"
match:    notify_no_data|no.?data
```

```decoy
id:       OD-DECOY-16
file:     deploy/alloy/config.alloy
line:     50
command:  /obs-audit
class:    decoy/OD-PL-04b
anchor:   values = { level = "", app = "" }
match:    label|cardinal|stream
```

```decoy
id:       OD-DECOY-17
file:     api/src/checkout/checkout.service.ts
line:     38
command:  /obs-audit
class:    decoy/OD-MT-01a
anchor:   exemplarLabels: { trace_id: traceId }
match:    trace_id|label|cardinal
```

```decoy
id:       OD-DECOY-18
file:     go-svc/internal/inventory/handler.go
line:     78
command:  /obs-audit
class:    decoy/OD-TR-01a
anchor:   go h.auditRelease(context.WithoutCancel(ctx), sku)
match:    WithoutCancel|context|trace|detach
```

```decoy
id:       OD-DECOY-19
file:     py-svc/app/orders.py
line:     32
command:  /obs-audit
class:    decoy/OD-TR-04b
anchor:   with tracer.start_as_current_span("orders.cancel") as span:
match:    record_exception|exception|status|ERROR
```

```decoy
id:       OD-DECOY-20
file:     api/src/checkout/checkout.service.ts
line:     23
command:  /obs-audit
class:    decoy/OD-MT-03a
anchor:   checkoutDuration.observe((Date.now() - t0) / 1000);
match:    millisecond|\bms\b|unit|seconds
```

```decoy
id:       OD-DECOY-21
file:     deploy/slo/pyrra/api-latency.yaml
line:     14
command:  /obs-audit
class:    decoy/OD-SLO-05a
anchor:   metric: http_request_duration_seconds_bucket{job="api",le="0.3"}
match:    0\.3|bucket|edge
```

```decoy
id:       OD-DECOY-22
file:     deploy/prometheus/rules/platform.rules.yml
line:     12
command:  /obs-audit
class:    decoy/OD-AL-06a
anchor:   sum(rate(orders_api_requests_total{job="orders-api",status=~"5.."}[5m])) /
match:    NaN|zero traffic|0/0|sibling|absent
```

```decoy
id:       OD-DECOY-23
file:     api/.env.development
line:     5
command:  /obs-audit
class:    decoy/OD-LG-04c
anchor:   LOG_LEVEL=debug
match:    debug
```

```decoy
id:       OD-DECOY-24
file:     deploy/alertmanager/alertmanager.yml
line:     19
command:  /obs-audit
class:    decoy/OD-AL-08a
anchor:   group_by: ['...']
match:    group_by|\.\.\.|group
```

```decoy
id:       OD-DECOY-25
file:     api/scripts/seed-dev.ts
line:     14
command:  /obs-audit
class:    decoy/OD-LG-03a
anchor:   console.log('seeded 25 demo orders into', config.dbName);
match:    console|stdout|unstructured|print
```

```decoy
id:       OD-DECOY-26
file:     api/src/audit/audit-logger.ts
line:     17
command:  /obs-audit
class:    decoy/OD-LG-05a
anchor:   auditLog.info({ actorId, refundId: refund.id, sku: item.sku
match:    loop|volume|per.?item|hot|per.?line
```

## Detector measurement — the pre-flights run on this fixture

Measured 2026-10-10 with ripgrep 15.2.0 under `/bin/bash` 3.2.57 (stdin from `/dev/null`), Python 3 for the two
scripts, in a staged copy (this key removed, `git init`, `rule-inventory.py` and `burn-check.py` copied to
`.claude/skills/<skill>/scripts/` where the pre-flights call them). Each skill's pre-flight block was copied verbatim
from its `SKILL.md` as of that date; the only edit is `alert-rule-lint` step 4's placeholders, filled from its own step
0 output: `--prom-major=3` (compose `prom/prometheus:v3.5.0`, CR `spec.version: v3.5.0`),
`--prometheus-config=./deploy/prometheus/prometheus.yml`, `--prometheus-cr=./deploy/k8s/prometheus.yaml`,
`--am=./deploy/alertmanager/alertmanager.yml`. Every script exits 0, prints nothing to stderr but the two scripts'
summary lines, and leaves `git status` clean. **Tool lane: blocked** on the measuring host — promtool, pint, amtool,
otelcol-contrib, alloy, loki, sloth, pyrra, dashboard-linter, ruff and golangci-lint are not installed, so this is the
eval's "tools blocked" run: every config seed must surface through the greps and the two stdlib scripts, and does.

A seed is **caught** when its owner's script prints its file (file-level and set-difference lines), a line within 6 of
its anchor, or the script row that names its rule or spec. A decoy is **hit** when a script prints it for the class it
imitates; every hit below is refuted by the read the skill already prescribes, so it produces **0 findings**. These are
grep results, not a scored `/obs-audit` run — no run is recorded in `RESULTS.md` yet.

| detector | lines printed | seeds it owns | caught by its pre-flight | decoys hit → findings | other printed lines |
|----------|---------------|---------------|--------------------------|-----------------------|---------------------|
| `log-signal-scan` | 64 (0.5 s) | 23 (§1–§8) | **23 / 23** — 1a, 1b, 2a ×2, 2c, 2d, 2e (file), 2g, 2h, 3a (Python), 3c (file), 3d, 4a (file), 4b, 4d, 5a + 5b, 5c (file), 6b ×2 (files), 7a (file), 7c (file), 8a (SDK list, empty bridge list), 8b | DECOY-03 by 2d → 0 (0b prints its `serializers: { error: … }`, § 22); DECOY-05 by 2b → 0 (`{ cause: e }` to `HttpExceptionFilter`, which logs `err` + `cause`, § 39); DECOY-02 by 4c (log-and-rethrow) → 0 (the rethrow reaches `AllExceptionsFilter`, which does not log: one log per error); DECOY-26 by 5b → 0 (§ 31). DECOY-01, -04, -23, -25: 0 hits | context only: 0a/0b/0c; 3a prints the LG-02c and LG-02g sites again (same lines, template / concatenation) |
| `trace-propagation-scan` | 120 (0.4 s) | 20 (§1–§10) | **20 / 20** — 1a, 1c (file), 2a, 2a2 (Celery), 3a, 3d, 4a, 4c, 5a2 (`main.ts` import order; `api/Dockerfile` CMD in 0c), 5c (file), 6a, 6b (set-difference: every service but orders-api names itself), 7 ×2, 8a, 8a2, 9a, 9b, 10a, 10c | DECOY-07 by 9a → 0 (`ParentBased(...)`); DECOY-08 by 9b → 0 (dev-only init, § 30 / § 33). DECOY-18, -19: 0 hits | gate open (0a/0b ≈ 45 lines), 0c process map, 2b consumers, 2c inject sites, 3b Python client libraries, 3c instrumentation lists (the worker's IORedis-only list is OD-TR-03a's evidence), 5b the module-scope `TracerProvider` (uvicorn, no `preload_app`: refuted), 10b collector sampler lines |
| `metric-hygiene-scan` | 187 (0.4 s) | 19 (§1–§8) | **19 / 19** — 1a ×3, 1b ×3, 2 ×2 + 2b (`db.py`), 3a, 3c + 3d (py buckets and the board's `le="0.3"`), 4a + 4b, 4c (Summary + `replicas: 3`), 5a, 5b, 6 ×2 (exactly the two seeds: every other registered name has a consumer), 7b ×2, 8b ×2 (files) | DECOY-14 by 7a (route list) → 0 (constant liveness is right); DECOY-21 by 3d → 0 (0.3 is an edge of `http_request_duration_seconds`). DECOY-06, -17, -20: 0 hits | 99 lines of 8c RED selectors with no probe filter — one root cause, the RED hook counting probes (OD-MT-08b); 2 `@Processor` at class level (metered inside `process()`, refuted); 8b `worker/src/tracing.ts` (no HTTP instrumentation, refuted) and `app.module.ts` (credited to OD-LG-05b); 7c `pingCheck` in liveness (= OD-HO-PERF-a, routed) |
| `error-tracking-scan` | 43 (0.2 s) | 8 (§1–§4) | **8 / 8** — 1b + 1c (`sentry.prod.ts`, `main.py`; 1d prints no `SENTRY_*` for orders-api), 2a + 2b (worker entry with no hook), 2c (`cmd/worker/main.go`), 3a, 3b (`admin` upload vs its init's `release`), 4b ×2 | DECOY-08 by 1a → 0 (it sets `release` and `environment`) | 0b start commands; 2c `go-svc/main.go` (a shutdown-only goroutine, refuted); R `sendDefaultPii` (= OD-HO-SEC-c, routed) |
| `alert-rule-lint` + `rule-inventory.py` | 71 (0.2 s); 41 alerts, 65 recording rules, 32 H/M/L rows | 23 (§1–§9) | **23 / 23** — rows AL-01, AL-02, AL-04 ×2 (RefundErrors, Pyrra 7× tier), AL-05, AL-06, AL-08, AL-13, AL-20, AL-10, AL-22 ×2 (glob, `ruleSelector`), AL-12, AL-21, AL-16, AL-17, SY-01, SY-03, AM-01, AM-03; §9 from grep 3 (`noDataState: OK`, the two monitors' resource lines) | 0 H/M/L rows on DECOY-09, -10, -11, -12, -13, -22, -24; DECOY-15 by grep 3's resource list → 0 (error-count monitor, § 10) | **2 false AL-10 [H]** on `OrdersApiMeanLatencyHigh` (`orders_api_request_duration_seconds_sum/_count`): the inventory misses a multi-line `Histogram(` call — IR-1; AL-04 [L] "no summary" ×4 and AL-04 [M] on the 14× tier (the OD-AL-02d group, P4); AL-01 on `ApiTargetMissing` (same alert as OD-AL-06b) |
| `slo-rule-scan` + `burn-check.py` | 49 (0.2 s); 15 burn alerts, 5 SLO specs, 3 rows | 12 (§1–§6) | **12 / 12**, one only on the prescribed re-run: SLO-01 (search), 0b Datadog SLO with no `slo alert` monitor, SLO-03 M (hand edit), SLO-04 H (OpenSLO 1.0), grep 3b (admin export), grep 4 ×2, step 5 `le` 0.25 vs `[0.1, 0.5, 1, 2]`, step 6 `retention.time=15d` with no long-term store, the empty policy grep. **OD-SLO-02a** prints only on the re-run the skill prescribes with the registry's objectives (`--slo='PaymentsAvailability.*=99.9/30d' …`): SLO-03 H ×3, "fires at 10× the intended burn". **OD-SLO-05b**: `le="0.2"` prints, but step 5 does not print the Go `Buckets: prometheus.DefBuckets` line (IR-2; `metric-hygiene-scan` 3c does) | 0 rows on DECOY-09 (Pyrra, objective and period read from the spec) and DECOY-10 (sloth 3× ticket tier); DECOY-21 by step 5 → 0 | the re-run with `--retention=15d` adds SLO-10 on 5 SLOs (one finding, OD-SLO-06a) |
| `telemetry-config-scan` | 54 (0.2 s) | 17 (§1–§8) | **17 / 17** — key diff ×3 (order, batch, unused `filter/drop-probes`), grep 2 ×2, grep 3 (sampler + `decision_wait`, no balancer line), grep 4 ×2, grep 5 (Promtail image + config; both Alloy sources listed), grep 6 ×2, grep 7 (`debug` + monitor labels vs `serviceMonitorSelector`), `dash.py` ×3 | DECOY-16: 0 hits | versions; the matched collector ServiceMonitor; the grep 2/3/7 lines print without a file name (IR-3) |
| `synthetic-monitoring` | 15 (0.1 s) | 2 (§1–§2) | **2 / 2** — journey list (`@Controller('checkout')`, `CheckoutPage.tsx`) vs a target list with no checkout; 2b `…/health/ready` on the `login-probe` job | — | grep 4 lists the Datadog SLO (not a probe SLO) |
| `alert-audit` | no pre-flight (consumes rows) | 2 (§5) | **2 / 2** from the rows above — the `CheckoutLatency*` burn alerts are two page tiers and no ticket tier (`burn-check.py --slo='CheckoutLatency.*=99/30d'` passes their arithmetic); `search-latency` is a registry row with no spec, rule or monitor | — | every other §1–§4 verdict is `NO-DATA(alert history)` on a fixture, as designed |

Totals: **126 of 126** observability seeds surface in their owner's pre-flight or prescribed script re-run (124 in the
verbatim pre-flight; OD-SLO-02a on the `--slo` re-run; OD-SLO-05b half-printed, its bucket half via
`metric-hygiene-scan`). **0 decoys** survive their owner's prescribed read (9 decoy hits above, each refuted by one
precedent or one printed line). Unseeded false lines: **2** (the AL-10 pair, IR-1). Excluded trees: the fixture has no
test, migration or i18n tree, so the "0 hits in excluded trees" check is not exercised here.

Hand-off rows, run through their owners' pre-flights the same way: `data-exposure-scan` prints OD-HO-SEC-a (6c the
`redact` block, 6d the accepted header names `x-carrier-token` / `x-partner-token` to diff against it) and OD-HO-SEC-c
(6b `sendDefaultPii`) — **OD-HO-SEC-b is printed by none of its greps** (IR-5); `error-handling-scan` prints both CQ
rows; `request-path-scan` prints the liveness `pingCheck` (OD-HO-PERF-a).

Self-check of the key: a findings file built from each seed's own title and text scores 126/126 under `/obs-audit`
(3/3, 2/2, 1/1 under the owners) with 0 decoys pinned; a file of one typical false report per decoy pins 26/26.

### Integrator requests (skill gaps found by this fixture — the skills are other agents' files)

- **IR-1 — `alert-rule-lint` pre-flight step 2 (inventory), `prometheus_client` line:** it runs without `-U`, so a
  black-formatted registration (`Histogram(\n    "orders_api_request_duration_seconds",`, `py-svc/app/metrics.py`) is
  not inventoried and every selector on it is a false AL-10 [H] (2 here). Run that line with `-U` and `\s*` across the
  newline, as the prom-client line already does. `metric-hygiene-scan` grep 6's name extraction has the same single-line
  limit: a multi-line registration is never checked for a consumer (silently, no false line).
- **IR-2 — `slo-rule-scan` pre-flight step 5:** the bucket-list grep matches `prometheus.ExponentialBuckets(...)` but not
  `Buckets: prometheus.DefBuckets` (no call parentheses), so a Go SLI on default buckets is never paired with its
  edges. Add `\bprometheus\.DefBuckets\b` (and print the default list beside it, as `metric-hygiene-scan` §3 states it).
- **IR-3 — `telemetry-config-scan` greps 2, 3 and 7 (debug exporter):** they run over `"${COL[@]}"` without `-H`; with
  one collector config the lines print as `57:    retry_on_failure:` with no file name. Add `-H` (grep 6 already has it).
- **IR-4 — `slo-rule-scan` step 2 / `burn-check.py`:** the verbatim pre-flight runs `burn-check.py` without objectives,
  so a hand-written burn rule copied from another SLO (OD-SLO-02a) shows only a hidden `note`; it surfaces on the manual
  re-run the prose prescribes. Suggest a `--registry=ai/runtime/slos.md` input (or building the `--slo` list from the
  registry table in the pre-flight) so the mismatch prints on the first pass.
- **IR-5 — security `data-exposure-scan` § 6 (owner of OD-HO-SEC-b):** grep 6a's field list is secret-shaped only
  (`password|token|…`) and 6e needs a serializer call, so `logger.info({ name, phone, address }, …)` prints nowhere.
  Add personal-data field names (`name|phone|address|email|dob`) to 6a or a 6h, read per hit.
