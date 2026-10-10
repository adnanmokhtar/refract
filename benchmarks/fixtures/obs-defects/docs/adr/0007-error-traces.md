# ADR 0007 — Keep every error trace

Status: accepted (2025-11-04)

## Context

Most of our incidents start with "which request failed, and where". Search through logs alone takes too long
when a checkout fails across the API, orders-api and inventory.

## Decision

- We keep 100% of error traces, across every service, for 14 days in Tempo.
- To keep the bill flat, the SDKs head-sample everything else at 10 % (`OTEL_TRACES_SAMPLER_ARG=0.1` on the worker,
  `TraceIDRatioBased(0.1)` in inventory, `management.tracing.sampling.probability: 0.1` in refunds).
- The collector gateway keeps slow traces (over 2 s) on top of the baseline.

## Consequences

On-call opens the trace for any failed request from the Grafana log view (the `trace_id` derived field).
