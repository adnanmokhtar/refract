---
name: concurrency-discipline
description: Backend Rule: Concurrency discipline (parallelize independent I/O)
kind: rule
pack: backend
severity: must
applies-to: backend-track, every-code-writing-task-in-backend
---

# Backend Rule: Concurrency discipline (parallelize independent I/O)

> **Hard rule.** Independent I/O calls in a per-request / per-batch / per-job code path MUST run concurrently with a bounded primitive. Sequential `await` of independent calls, unbounded `Promise.all` over user-controlled arrays, and parallel work inside a DB transaction are forbidden — each is a review halt.

> **Project-specific values** — concurrency primitive in use, bounded-concurrency helper path, default outbound-HTTP concurrency cap, default DB concurrency cap — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Sourced from `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`. Do **not** edit those values here; edit the extraction sources and re-run `apply-anchors.sh` (or `/setup-project --refresh`) to propagate.

This rule is always loaded, so it carries only what must be resident *before* you know you are writing a fan-out: the shape to recognise, the ranking to apply, and the two cases where the rule does not fire. Recipes, per-language primitives, cap tables, tracing and the grep-able detectors are `ai/patterns/parallel-io.md`, which loads when the work is actually concurrent.

## Must

- **Answer the independence question before writing the loop.** "Does iteration N+1 read a value produced by iteration N?" No → it is parallelizable. Yes → it is sequential by data dependency; leave it, and say so at the call site, because the next reader will re-ask and the answer is not visible in the code.
- **Rank the three options in this order: batch API → bounded parallel → sequential.** Parallelism is the *second* choice. Calling `findUserById` 100 times concurrently is wrong even when bounded — the right answer is `findUsersByIds([...])`, because N bounded round-trips are still N round-trips. Fan-out is what you do when the source ships no batch call.
- **Every fan-out is bounded, and the bound cites the ceiling it came from.** The cap is the smallest of: the connection pool size, the provider's published rate limit, and the process file-descriptor limit. Name which one at the call site. A cap with no cited ceiling is itself the finding — this rule states no portable default, because a literal `N` in a MUST-severity rule is unenforceable and the real numbers are in the anchored block above.
- **Match the primitive already in the codebase.** A new feature reaching for a different concurrency helper than the one the project standardised on needs an ADR, not a preference. Mixing them is dual maintenance for zero behaviour change.
- **Decide the partial-failure policy explicitly.** Fail-fast (`Promise.all` / `gather`) discards the successes; collect-and-partition (`allSettled` / `return_exceptions=True`) surfaces them. Reading 100 profiles where 1 fails is a partition, not a `500` — but the caller must be told which 99 it got.
- **Bound every parallel task in time as well as in count.** Per-task timeout strictly under the parent request budget, and cancellation propagated on first hard failure (`AbortController` / `context.Context` / `CancellationToken`). A fan-out's wall-clock is its slowest tail, and un-cancelled siblings keep burning connections after the response has already been sent.

## Must not

- **Sequential `await` of independent calls** in any per-request / per-batch / per-job path — `for (const x of xs) await f(x)` where `f` does not consume the previous result. This is the single largest source of "why does this endpoint take 8 seconds for 80 items?", and it is the reason this rule is always on.
- **Unbounded fan-out over an array whose length the client controls.** The defect is in *two* places and both must be fixed: the missing concurrency cap, and the missing length cap on the validator that let 10K ids in. Bounding only the concurrency leaves a user-triggerable downstream melt.
- **Parallel work inside a DB transaction.** Most ORM transactions are pinned to one connection, so concurrent queries deadlock, race, or silently serialise — best case zero win, worst case an outage. Sequential inside a transaction is correct.
- **Parallel writes that share a key.** `Promise.all([updateBalance(u, +5), updateBalance(u, -5)])` is a race. If order matters it is sequential; if it does not, make the operation commutative (`SET x = x + ?`, not read-modify-write). And `Promise.race([dbWrite, cacheWrite])` is not a fast path, it is a non-deterministic bug.
- **Parallelize for "future-proofing".** When `n` is provably ≤ 3 — three known config reads — the readability cost exceeds the wall-clock win. This rule fires when `n` is variable, request-driven, or large; applying it to a fixed triple is cargo-culting it.

## Should

- **Re-shape into stages rather than nesting.** Fetch-all-inputs ‖ → transform ‖ → write-results ‖ reads as three phases; nested `Promise.all` chains read as nothing. If a dependency appears later, the staged form absorbs it and the nested form decays.
- **Stream, don't cap, when the dataset is the problem.** Loading 1M rows into memory and then bounded-mapping them still OOMs: the cap limits in-flight work, not resident memory. Stream plus bounded transform is the answer, and the wall-clock claim on any of this is expected-vs-actual (calls × per-call latency ÷ concurrency, compared to a measured number), never "looks faster".

## Where the depth lives

- `ai/patterns/parallel-io.md` — the per-language recipes, the project's shipped helper, the observed cap table, tracing, the pitfall list, and the six cite-or-halt detectors with their closure verbs. This rule decides; that pattern executes.
- `.claude/skills/parallelize-independent-ops/SKILL.md` — the procedure for converting an existing sequential path.
- **Lint reach, stated honestly**: ESLint `no-await-in-loop` flags every `await` in a loop in JS/TS — review each against the independence question above. Python and Go have no core linter for sequential-await fan-out (Ruff's `ASYNC*` rules catch blocking calls in async code, not serial awaits; Go has no `await`), so on those stacks this rule is enforced at review, not in CI.
