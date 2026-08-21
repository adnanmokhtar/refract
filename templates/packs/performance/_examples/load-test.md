---
name: load-test
description: Design and run a load / stress / spike / soak campaign against an SLA on a prod-parity env, then interpret it (throughput, latency percentiles, breakpoint, saturation) and return a PASS/FAIL verdict + headroom. Distinct from profile-endpoint (one slow subject) and capacity-planner (analytical estimation).
---

# load-test

Design a load campaign against an SLA, drive it on a prod-parity env, read the result. Ship a verdict, not a vibe.

## Premise

An SLA with no load test behind it is a promise no one has kept. **Cite-or-halt:** every capacity claim cites the run config (tool, model, stages, rate, duration, env) AND the measured percentile / throughput it rests on. A single-VU "quick load" number quoted as capacity is the failure mode this skill kills — one VU in a loop measures an idle system, not peak.

## When to run

- Before a launch, a capacity change, or a big feature on a hot path.
- To validate an SLA/SLO — you have `p99 < X at Y rps with <Z% errors` and need to prove or break it.
- NOT every CI run — a real campaign needs a prod-parity env + minutes of sustained traffic.

## Test taxonomy

| Type | Question | Pass / fail |
|---|---|---|
| Load | Meets SLA at expected peak? | p99 under SLA at target rps, errors < budget |
| Stress | Where does it break past peak? | rps where p99 / errors cross the line |
| Spike | Survives + recovers from a surge? | absorbs, returns to baseline in the window |
| Soak | Degrades over hours? | flat latency + memory + conns; creep = fail |
| Breakpoint | Where is the knee? | max sustainable rps + the resource that binds |

## Procedure (shape)

1. Model the workload from prod traffic shape (realistic mix, think-time, arrival pattern).
2. Establish env parity (instance class, DB tier, data volume) — record it in the run config.
3. Define the SLA gate up front; a gate set after seeing numbers is not a gate.
4. Prefer the OPEN / arrival-rate model — a closed (fixed-VU) model masks saturation (coordinated omission).
5. Ramp in stages; measure p50/p95/p99 + throughput + saturation (CPU, pool, DB conns) per stage.
6. Find the knee, name the binding resource, compute headroom `(breakpoint − peak) / peak`.

## Output (illustrative)

```
### SLA gate: PASS = p99 < 500ms at 4000 rps with < 0.5% errors  →  PASS
| Stage rps | p50 | p95 | p99 | errors | saturation |
| 4000 | 92ms | 310ms | 470ms | 0.3% | CPU 82%, pool 78% |  ← target, PASS
| 6000 | 480ms| 2.1s | 4.8s | 7.2% | pool 100%, DB conns maxed |  ← past knee
Breakpoint ~4600 rps, binds on DB connection pool. Headroom ≈ +53% over 3000 peak.
Verdict: PASS — meets SLA with +53% headroom; pool binds first past the knee.
```

## Gotchas

- Coordinated omission — closed models hide tail latency under saturation; gate on open/arrival-rate.
- Non-parity env (laptop, empty tables, cold cache) describes that env, not prod — record parity or discard.
- The client can be the bottleneck — check generator-side saturation every run.
- Averages lie — gate on p95/p99, never the mean.

## Halt conditions

- **Refuse a capacity claim with no run config + parity note.** "Handles the load" without tool, model, stages, rate, env, and the measured percentile is not a result — halt and demand the run.
- **Single-VU / quick-load numbers are not capacity.** A number from one virtual user, a hammer loop, or a non-parity box may not be presented as system capacity — halt and re-run the campaign under a realistic mix on a parity env.
- **No SLA gate defined before the run** — halt; define `p99 < X at Y rps with < Z% errors` first, or the run has no verdict to reach.
- **Closed model quoted as an SLA pass** — halt; re-run open / arrival-rate before certifying, or the pass may be coordinated-omission theatre.
- **Hand the ROOT CAUSE off, don't fix it here.** This skill owns the campaign and the verdict — it finds the knee and names the saturated resource. It does NOT fix the bottleneck: route the fix to `@performance-optimizer` / `@caching-architect` / the relevant pack, and route single-subject diagnosis to `skill:profile-endpoint`. A load-test PR that also rewrites the query has exceeded its mandate.

## Related

- `profile-endpoint.md` — boundary: it diagnoses ONE slow subject; hand it the subject at the knee.
- `@capacity-planner` (distributed-systems pack) — analytical complement: predicts the breakpoint this skill confirms.
