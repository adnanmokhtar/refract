---
name: profiling
kind: example
pack: observability
---

# Pattern: Continuous Production Profiling (the 4th signal)

> **Hard rule:** Services with real production load run a **low-overhead, always-on profiler** (eBPF-based or in-process sampling) exporting CPU / heap / alloc / lock profiles continuously, joined to traces via **exemplar → profile linkage** (a slow span links to the flame graph of what the CPU was doing at that instant). Metrics/logs/traces tell you *that* it's slow and *where* the time is attributed; profiling tells you *which lines of code* burned it. Always-on profiling must stay under a few-percent overhead budget — a high-overhead profiler left on in prod is a bug.

**Halt conditions / mandatory cites**
- Any "it's slow / it's CPU-bound" claim MUST cite a **flame graph** with `<function>` self-time attribution — not a guess. "I think it's the DB" without a profile is forbidden (mirrors the performance pack's premise).
- The profiler config MUST cite its **overhead budget** and the sampling rate that keeps it there — an always-on profiler with no overhead bound is a bug, reject.
- A profile-derived fix MUST cite the `<file:line>` hot frame it targets AND the trace exemplar / time range it was captured over.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is the bottleneck".
- If the continuous-profiler agent/backend + its symbolization source aren't extracted, halt.

The fourth telemetry signal, alongside metrics/logs/traces. Metrics/traces tell you *that* it's slow and *which span*; profiling tells you *which lines of code*, sampled from real production, burned the CPU / allocated the heap / held the lock.

**Adopt eBPF now; OTel profiles later.** eBPF whole-system agents (Parca, Pyroscope, Grafana Alloy) are production-ready and need no code changes. The **OpenTelemetry profiles signal is Alpha** — the spec is not stable and SDK support is early-to-absent per language. Check `https://opentelemetry.io/status/` for your runtime before planning around it; its pprof-derived wire format is the convergence point, not today's tool.

## Boundary — performance owns AD-HOC, observability owns ALWAYS-ON

Same tools, two modes; keep the seam clean.

- The **performance** pack owns **ad-hoc / dev-time** profiling: a specific slow endpoint, attach `pprof` / `py-spy` / `async-profiler` under representative load, read the dominant frame, fix, detach. That's `/profile-perf`.
- This pattern owns **always-on production** profiling: a fleet-wide, low-overhead profiler already running when the incident happens, so you can open the flame graph for 14:03 last Tuesday without reproducing anything. Sampling budget, symbolization, retention and trace linkage are the observability concerns.

Rule of thumb: if you attach a profiler *because* something is slow, that's performance's ad-hoc mode. If the profiler was *already collecting* when it got slow, that's this pattern.

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
  'service.name':                'checkout',
  'deployment.environment.name': 'prod',
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
