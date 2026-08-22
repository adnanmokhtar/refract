---
name: parallelize-independent-ops
description: Convert a sequential I/O-bound code path into bounded parallel execution using the project's concurrency primitive. Used when an endpoint, batch job, or aggregation does N independent awaits in a loop — the most common backend perf failure. Refuses to parallelize when data dependencies, transactions, or shared keys make it unsafe.
---

# parallelize-independent-ops

## Premise

Existing project primitives are the truth. Use what `ai/patterns/parallel-io.md` already declared — never introduce a new dependency without an ADR. Independence is proven, not assumed: the Step 2 checklist is mandatory. Wall-clock measurement before AND after is non-negotiable; without numbers, the change is just unverified refactoring. Refuse to ship if the "after" run doesn't beat the "before" run — revert and investigate elsewhere.

Refuse to parallelize without naming the sibling code that uses the same primitive (or an ADR that establishes it).

This skill is the operational arm of `.claude/rules/concurrency-discipline.md` + `ai/patterns/parallel-io.md` — the rule says *what's required*, the pattern says *what it looks like in this codebase*, this skill says *how to do the conversion safely*.

## When to use

- Endpoint p99 is unexplainably slow and a sequential loop is on the call stack.
- Code review surfaces `for (const x of xs) await f(x)` where `f` is independent.
- Refactoring a batch job / cron / queue consumer that processes items one at a time.
- The user says "make this faster" and the bottleneck is wall-clock not CPU.

## When NOT to use (refuse + explain)

`ai/patterns/parallel-io.md` § When NOT to use owns the refusals that hold regardless of conversion — open transaction, required ordering, a collection too small to repay the ceremony, a job already CPU-pinned. Read them there; a second copy here would drift.

These three are this skill's own, because they only bite once you are mid-conversion:

- **Iteration N+1 reads a value produced by iteration N.** Sequential is correct as written. Step 2 is the gate that has to prove otherwise, and it proves it about *reads* only.
- **A batch API already exists** (`findByIds`, `multiGet`, an `IN` clause). One round trip beats N bounded ones; parallelising here optimises the wrong axis and leaves the round-trip count untouched.
- **Two iterations write the same row or key.** A write collision survives Step 2's read-independence gate, then surfaces as a lost update under load rather than a red test. Convert to atomic SQL, or leave the loop sequential, before parallelising anything else in it.

## Prerequisites

- `.claude/_extracted-codebase.md` exists. If not, run `/setup-project --refresh` first — without extraction we'd guess the project's primitive.
- `ai/patterns/parallel-io.md` exists with the project's primitive filled in.
- `.claude/rules/concurrency-discipline.md` exists.
- Dev server / CI can run; you'll measure before AND after.

## Procedure

### Step 1 — Identify the candidate

Grep for the sequential shape (`for … of` with an `await` in the body; `.forEach(async …)`, which is unbounded parallel and also a finding). Open it and confirm the awaited call is I/O-bound — DB, cache, HTTP, queue, disk — not pure CPU.

### Step 2 — Prove independence (the gate)

Before any code change, answer **YES to all** of:

- [ ] Iteration N+1 does **not** read any value produced by iteration N.
- [ ] No iteration writes a row / key that another iteration reads or writes.
- [ ] Loop is **not** inside a DB transaction OR the ORM allows concurrent tx-bound queries (rare; default to "no").
- [ ] Iteration order does not encode a constraint (idempotency key sequence, append-only log, FIFO requirement).
- [ ] The downstream system tolerates concurrent calls at the cap you'll choose.

**If any answer is "no" → STOP. Document why parallelism is unsafe + suggest the right alternative** (batch API, atomic SQL, sequential is correct, transaction redesign). Never silently force.

### Step 3 — Pick the primitive

Read `ai/patterns/parallel-io.md` § "Concurrency primitive in use" and use **that** primitive. If extraction returned empty, use the language canonical, then **propose** standardising it in an ADR under `ai/decisions/` so the next run reuses it rather than re-deciding.

### Step 4 — Pick the cap

The cap is derived from the resource it consumes, not chosen for comfort: outbound HTTP from the provider's rate limit with headroom (per-provider, never one global cap); DB reads from `pool_size − margin`; DB writes lower than the pool allows, because lock contention arrives before pool exhaustion does; cache reads high; file I/O from FD limits; CPU work at `#cores`. **Default if unsure: `8`** — start conservative and raise after measurement.

### Step 5 — Transform (mechanical)

Replace the loop using the chosen primitive and cap. Keep the diff surgical — every changed line traces to this conversion.

### Step 6 — Add timeouts + cancellation

Every task gets a per-task timeout and the group gets a wall-clock parent budget. Failure-cancel (siblings stop when one fails) and timeout-cancel (a ceiling on the whole group) are **different mechanisms that compose** — neither replaces the other. A bounded fan-out with no timeout is an unbounded wait wearing a cap.

### Step 7 — Decide on partial-failure tolerance

**Fail-fast** (default for endpoints) keeps the reject-on-first-error primitive. **Partial-OK** (batch jobs, dashboards, best-effort reads) switches to the settle-all variant and **partitions** the result into successes and failures, logging failures with a correlation ID and a count. State which path you chose in the PR description.

### Step 8 — Measure (before AND after)

```
Before: <N> sequential awaits × <per-call p50 ms> ≈ <wall-clock ms>
After:  <N> tasks @ concurrency=<C> × <per-call p50 ms> ≈ <wall-clock ms>
Actual: <measured wall-clock from logs / tracing>
```

Run at least 3 times and take p50. If actual ≪ expected, downstream is the bottleneck (rate limit / pool exhaustion) — lower the cap. If actual ≈ before, the loop wasn't the bottleneck — **revert** and keep investigating elsewhere.

### Step 9 — Update tests

A test that mocks the per-item call and asserts call count survives the transform — keep it. Add one that asserts the cap is respected.

### Step 10 — Self-review against the rule + pattern

Re-read `concurrency-discipline.md` and `parallel-io.md` and confirm the diff violates neither.

## Output format

```
PARALLELIZATION REPORT — <file:line>
================================================
Candidate:           <code path + brief>
Independence:        proven | unsafe (reason)
Primitive chosen:    <project's primitive | proposed default>
Concurrency cap:     <N> (rationale: <pool size / rate limit / cores>)
Failure mode:        fail-fast | partial-tolerant
Timeouts:            <per-task ms> / <parent budget ms>
Cancellation:        <AbortController | context | …>
Measured:
  Before:            <wall-clock>
  After:             <wall-clock>
  Speedup:           <ratio>
Tests added:         <list>
Open follow-ups:     <e.g. "downstream rate-limit hits at cap=8 — provider review needed">
```

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Speedup ≪ expected | Cap exceeds pool/limit; downstream throttling | Lower cap; check `429` / connection-wait logs |
| Speedup ≈ 0 | Loop wasn't the bottleneck | Revert; profile; the slow call is elsewhere |
| Intermittent test failures after change | Race on shared state in the per-item call | Make it pure or add a per-item local accumulator |
| Connection pool exhausted in prod | Cap > `pool_size − safety_margin` | Lower cap or increase pool (with capacity review) |
| OOM under load | Unbounded fan-out missed somewhere upstream | Re-grep the file; the cap must be on the **outermost** fan-out |
| Trace shows tasks running serially anyway | Inside a transaction OR a shared `await` outside the cap | Re-read Step 2 + Step 5 |

## Related

- `.claude/rules/concurrency-discipline.md` — the MUST/MUST-NOT contract this skill enforces.
- `ai/patterns/parallel-io.md` — recipes + project's primitive citation.
- `ai/patterns/data-access.md` — *batch APIs first*; parallelism is the fallback.

## Halt conditions

- Halt if the Step 2 independence checklist has any unchecked box — never silently force parallelism.
- Halt if a new concurrency dependency is introduced without an ADR or a sibling that already uses it.
- Halt if the "before" or "after" wall-clock measurement is missing — without numbers this is unverified refactoring, not optimization.
- Halt if the measured speedup is ≈ 0 and the change is shipped anyway — revert; the bottleneck is elsewhere.
- Halt if a parallel write shares a key without atomic SQL / CAS, or if the loop is inside a DB transaction — both are silent corruption risks.
