---
purpose: Mechanical halt for observability commands — span/metric/log/alert naming parity with sibling instrumentation.
---

# Mechanical halt — instrumentation-naming parity

Before finishing implementation, run these checks. Any failure = **HALT**, surface, do not advance:

1. **Span attribute parity** — search the repo for `setAttribute` / `set_attribute` / SDK equivalents. Every new span attribute name MUST match sibling spans for the same semantic (`tenant_id`, `user_id`, `request_id`, `route`, …).
2. **Metric prefix parity** — new metric names share the prefix root + separator of the closest sibling feature. New prefix = ADR required.
3. **Log field parity** — every new log field is reused from sibling logs OR documented in an ADR. No smuggled field names.
4. **Alert severity parity** — severity labels (`page` / `ticket` / `info`, etc.) mirror sibling alerts; no new tiers without ADR.

Add results to the output block under `Naming-parity: ✓ | halts=<N>`.

Link this file from `/add-telemetry`, `/add-metrics`, `/add-tracing` instead of duplicating the four steps.
