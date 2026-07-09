---
name: profiling
kind: example
pack: observability
---

# Pattern: Continuous Production Profiling (the 4th signal)

The fourth telemetry signal, alongside metrics/logs/traces. Metrics/traces tell you *that* it's slow and *which span*; profiling tells you *which lines of code*, sampled from real production, burned the CPU / allocated the heap / held the lock. Spec-mature as of 2024–25 (OpenTelemetry profiling signal + pprof wire format; eBPF whole-system agents).

**Boundary:** the performance pack owns AD-HOC / dev-time profiling (`pprof`, `py-spy`, `async-profiler`, `/profile-perf`). This pattern owns the ALWAYS-ON production profiler that's *already running* when the incident happens.

## Profile types

| Profile | Finds |
|---|---|
| CPU (on-CPU) | hot functions, regex-per-call, JSON churn |
| Heap / in-use | leaks, oversized caches, retained buffers |
| Alloc | GC pressure / allocation churn (even when heap looks flat) |
| Lock / off-CPU | contention, serialization bottlenecks |

## Low-overhead eBPF agent (zero instrumentation, all languages)

```yaml
# Parca-style eBPF agent as a DaemonSet — one per node, ~1% CPU
args:
  - --node=$(NODE_NAME)
  - --remote-store-address=parca.observability:7070
  - --profiling-duration=10s
  - --profiling-frequency=19        # Hz — the overhead budget lives here
```

State the sampling frequency AND the overhead budget (≤ a few % CPU) and verify it — a high-frequency always-on profiler *is itself* a production incident. In-process SDKs (OTel profiling SDK, Pyroscope SDKs) are the alternative where eBPF can't symbolize JIT/interpreted frames.

## Exemplar → profile linkage (close the loop)

```ts
// share resource attributes so the backend correlates spans and profiles
const resource = resourceFromAttributes({
  'service.name':            'checkout',
  'deployment.environment':  'prod',
});
// tracer + profiler both stamp these → from a p99 alert, click the exemplar trace,
// then open the flame graph captured during that span's time window.
```

metrics → traces → profiles: *that* it's slow → *where* (which span) → *which lines*.

## Reading the flame graph

Each box = a stack frame; width ∝ samples in that frame + children; x-axis is aggregated samples, not time. Look for **self-time**: a wide box with narrow children is the hot leaf → your `<file:line>` target. No wide self-time frame = diffuse cost (death by a thousand cuts), a different fix than a single hot function.

## Detectors

- A CPU / latency mystery with no continuous profiler — traces bottom out at span granularity, nothing to drop into.
- Profiling only ad-hoc in dev — can't reproduce the prod traffic pattern locally.
- High-overhead always-on misconfig — full-fidelity / high-frequency capture fleet-wide with no stated overhead budget.
- Profiler not linked to traces — no `service`/timestamp correlation, so a slow trace can't reach the flame graph of that moment.
