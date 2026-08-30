---
name: observability
description: Cross-cutting rules for whether a surface can be diagnosed when it breaks at 03:00
kind: rule
concern: C3
---

# Observability

## Hard rule

Every surface MUST emit enough signal to answer *is it broken*, *how badly*, and *where* — without
shipping new code. A surface that requires a deploy to diagnose is unobservable regardless of how
many metrics it emits. Alerts fire on **symptoms users feel**, never on causes; every alert names
a runbook and an owner.

## A measurement note, recorded because it is easy to misread

The first matrix build scored `Observability 0/35` using the curated registry column alone — and
that was **wrong**: 32 of 35 domain rule files do discuss metrics, traces or alerts. But the two
signals disagreeing is itself the finding. Observability is *mentioned* nearly everywhere and
*shipped* as a detector almost nowhere. The gap is not awareness; it is that no domain owns the
question for its own surface.

## Per-surface fingerprints

| Surface | The symptom a user feels | Typical finding |
|---|---|---|
| `admin` | an admin action appears to succeed and does not | no metric on admin action outcomes; failures visible only in logs nobody reads |
| `document-generation` | a document never arrives | render queue depth and failure rate unmeasured; a stuck renderer is invisible until a support ticket |
| `i18n` | text appears in the wrong language or as a raw key | missing-key events not counted, so catalog gaps are discovered by users |
| `import` | an import "worked" but rows are missing | per-row rejection counts not emitted; only the job's own success/failure is visible |
| `multi-tenant` | one tenant is slow, dashboards look fine | metrics aggregated across tenants, so a single-tenant outage never crosses a threshold |
| `scheduling` | a booking silently double-books or vanishes | conflict-resolution outcomes unmeasured; DST-boundary failures invisible |
| `settings` | a setting change does not take effect | no signal on cache invalidation after a settings write |
| `streaming-delivery` | playback stalls or fails to start | client-side QoE (startup time, rebuffer ratio) never collected, so only server 5xx is visible — and stalls are not 5xx |

> The pattern across these rows: **aggregate metrics hide per-slice failures.** A tenant, a
> locale, a codec, or a single import batch fails while the aggregate stays green. Cardinality is
> the cost of seeing it; that trade-off should be a decision, not an accident.

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Signal source** | metrics, traces, structured logs | RUM / web-vitals field data — lab tools cannot measure INP | crash + ANR reporting, frame-time percentiles | exit codes, a `--verbose` mode, machine-readable output |
| **The classic miss** | dashboards for the happy path only | measuring in the lab and shipping to the field blind | crash-free rate tracked, jank not | failure indistinguishable from success in a pipeline |

## Closure verbs

`emit-outcome-metric` · `slice-by-tenant` · `alert-on-symptom` · `attach-runbook` ·
`collect-field-qoe` · `count-the-rejections`
