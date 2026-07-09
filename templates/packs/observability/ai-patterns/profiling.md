---
name: profiling
description: 'Pattern: Continuous Production Profiling (the 4th signal)'
kind: ai-pattern
pack: observability
---

# Pattern: Continuous Production Profiling (the 4th signal)

> **Hard rule:** Services with real production load run a **low-overhead, always-on profiler** (eBPF-based or in-process sampling) exporting CPU / heap / alloc / lock profiles continuously, joined to traces via **exemplar → profile linkage** (a slow span links to the flame graph of what the CPU was doing at that instant). Metrics/logs/traces tell you *that* it's slow and *where* the time is attributed; profiling tells you *which lines of code* burned it. Always-on profiling must stay under a few-percent overhead budget — a high-overhead profiler left on in prod is a bug.

**When to apply**
- A latency or CPU-cost mystery keeps recurring and traces bottom out at "this span took 400ms" without revealing *which function* inside it. Profiling is the layer below the span.
- Cloud spend is dominated by CPU/memory and you need to attribute cost to code paths ("this JSON re-serialization is 12% of fleet CPU") to know what to optimize.
- A memory leak or allocation-churn problem only manifests under production traffic patterns you can't reproduce in dev.

**When NOT to apply**
- A low-traffic or batch service where ad-hoc dev-time profiling (below) answers the occasional question — always-on infra isn't worth the overhead budget.
- A runtime/platform with no low-overhead continuous profiler available and a hard latency budget that even a few percent would blow — profile ad-hoc instead.

**Halt conditions / mandatory cites**
- Any "it's slow / it's CPU-bound" claim MUST cite a **flame graph** with `<function>` self-time attribution — not a guess. "I think it's the DB" without a profile is forbidden (mirrors the performance pack's premise).
- The profiler config MUST cite its **overhead budget** and the sampling rate that keeps it there — an always-on profiler with no overhead bound is a bug, reject.
- A profile-derived fix MUST cite the `<file:line>` hot frame it targets AND the trace exemplar / time range it was captured over.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this is the bottleneck".
- If the continuous-profiler agent/backend + its symbolization source aren't extracted, halt.

Profiling is the fourth telemetry signal, alongside metrics, logs, and traces. The first three answer "*is* it slow, and *which service/span*?"; profiling answers "*which lines of code*, sampled from real production, are spending the CPU / allocating the heap / holding the lock?" As of 2024–25 it's a first-class, spec-mature signal — **OpenTelemetry profiling** reached a stable signal specification and pprof-based wire format, and eBPF whole-system profilers made it near-zero-instrumentation.

## Boundary — performance owns AD-HOC, observability owns ALWAYS-ON

Same tools, two different modes; keep the seam clean:

- **performance pack** owns **ad-hoc / dev-time profiling**: you have a specific slow endpoint, you attach `pprof` / `py-spy` / `async-profiler` / a flamegraph run under representative load, read the dominant frame, fix it, detach. That's the `/profile-perf` workflow — targeted, on-demand, in dev or a load test. Deep dive lives there.
- **observability pack** (this pattern) owns **always-on production profiling**: a fleet-wide, continuous, low-overhead profiler that's *already running* when the incident happens, so you can open the flame graph for 14:03 last Tuesday without reproducing anything. The pipeline concern — sampling budget, symbolization, retention, trace linkage — is observability's.

Rule of thumb: if you attach a profiler *because* something is slow, that's performance's ad-hoc mode. If the profiler was *already collecting* when it got slow, that's this pattern.

## Profile types

A continuous profiler collects several profile *kinds*, each answering a different resource question:

| Profile | Measures | Finds |
|---|---|---|
| **CPU** (on-CPU) | Where CPU cycles go, by stack | Hot functions, regex-per-call, JSON churn, tight loops |
| **Heap / in-use** | Live allocated memory by allocation site | Leaks, oversized caches, retained buffers |
| **Alloc** (allocations) | Allocation *rate* by site | GC pressure, allocation churn even when heap looks flat |
| **Lock / off-CPU / block** | Time spent blocked on locks / IO waits | Contention, serialization bottlenecks, mutex hotspots |

## Flame graphs — how to read the output

The universal visualization: each box is a stack frame, width is proportional to samples (time/allocations) spent in that frame **and its children**; the x-axis is not time, it's aggregated samples sorted for grouping. What matters is **self-time** — a wide box whose children are narrow is the hot leaf; that's your `<file:line>` target. Read top-down for "what's actually executing", bottom-up for "which entry path led here". A flame graph with no wide self-time frame means the cost is diffuse (death by a thousand cuts), which is a different fix than a single hot function.

## Low-overhead sampling — the overhead budget

Always-on is only acceptable because it's **sampled**, not traced. Two collection strategies:

- **eBPF whole-system profilers** (Parca Agent, Pyroscope eBPF, Grafana Alloy, Polar Signals) — the kernel samples stacks of *every* process at a fixed frequency (e.g., 19–100 Hz) with no code changes and no per-language SDK. Overhead is typically ~1% CPU. Best default for a fleet: zero instrumentation, all languages at once.
- **In-process sampling SDKs** (OTel profiling SDK, language runtime profilers, Pyroscope SDKs) — the runtime samples its own stacks; richer language-level symbols, needs a library per service. Use where eBPF can't symbolize (interpreted/JIT frames) or you want managed-runtime detail.

Either way, **state the sampling frequency and the overhead budget** (commonly "≤ a few percent CPU") and verify it — an always-on profiler misconfigured to a high sample rate or full-fidelity capture *is itself* a production incident.

## Exemplar → profile linkage

The payoff of profiling being a real signal: **join it to traces**. A slow span carries an exemplar (or the profiler is time-aligned by `service` + timestamp) so that from a p99-latency alert you click the exemplar trace, then click into the **profile captured during that span's window** and land on the flame graph of exactly what the CPU was doing while that request was slow. This closes the loop metrics→traces→profiles: *that* it's slow → *where* (which span) → *which lines*. Wire the profiler and tracer to share `service.name` + `deployment.environment` resource attributes so the backend can correlate them.

## Detectors (what a reviewer flags)

- **A CPU / latency mystery with no continuous profiler** — repeated "it's slow and we don't know why", traces bottoming out at span granularity, and no always-on profile to drop into. Add the eBPF agent.
- **Profiling only ad-hoc in dev** — the only way to profile is to reproduce the problem locally, which never reproduces the production traffic pattern. That's the performance-pack mode; production needs the always-on layer too.
- **High-overhead always-on misconfig** — a full-fidelity or high-frequency profiler left running fleet-wide with no stated overhead budget, adding measurable latency. Cap the sample rate; verify the overhead.
- **Profiler not linked to traces** — profiles exist but there's no `service`/timestamp correlation to spans, so you can't get from a slow trace to the flame graph of that moment. Share resource attributes.

## Related

- `performance` pack (`commands/profile-perf.md`, `agents/performance-optimizer.md`) — owns AD-HOC / dev-time profiling (`pprof` / `py-spy` / `async-profiler`); this pattern is the ALWAYS-ON production counterpart. Cross-link, don't duplicate.
- `tracing.md` — the exemplar → profile linkage rides on trace context; share `service.name` + `deployment.environment`.
- `metrics.md` — RED/USE tells you *that* it's slow and flags the symptom; profiling tells you which code burned it.
- `agents/incident-responder.md` — a live flame graph is a primary diagnostic during a CPU/latency sev.
