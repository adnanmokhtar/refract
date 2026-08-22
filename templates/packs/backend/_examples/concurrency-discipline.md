---
name: concurrency-discipline
kind: example
pack: backend
---

# Backend Rule: Concurrency discipline (parallelize independent I/O)

> **Hard rule.** Independent I/O calls in a per-request / per-batch / per-job code path MUST run concurrently with a bounded primitive. Sequential `await` of independent calls, unbounded `Promise.all` over user-controlled arrays, and parallel work inside a DB transaction are forbidden — each is a review halt.

> **Project-specific values** — concurrency primitive in use, bounded-concurrency helper path, default outbound-HTTP concurrency cap, default DB concurrency cap — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Sourced from `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`.

This rule is always loaded, so it carries only what must be resident *before* you know you are writing a fan-out: the shape to recognise, the ranking to apply, and the two cases where the rule does not fire. Recipes, per-language primitives, cap tables, tracing and the grep-able detectors live in `ai/patterns/parallel-io.md`, which loads when the work is actually concurrent.

## Must

- **Answer the independence question before writing the loop.** "Does iteration N+1 read a value produced by iteration N?" No → parallelizable. Yes → sequential by data dependency; leave it and say so at the call site, because the answer is not visible in the code and the next reader will re-ask.
- **Rank the three options: batch API → bounded parallel → sequential.** Parallelism is the *second* choice. Calling `findUserById` 100 times concurrently is wrong even when bounded — `findUsersByIds([...])` is the answer, because N bounded round-trips are still N round-trips.
- **Every fan-out is bounded, and the bound cites the ceiling it came from** — the smallest of connection-pool size, the provider's published rate limit, and the process file-descriptor limit. A cap with no cited ceiling is itself the finding. This rule states no portable default; the real numbers live in the anchored block above.
- **Match the primitive already in the codebase.** A different concurrency helper than the one the project standardised on needs an ADR, not a preference.
- **Decide the partial-failure policy explicitly.** Fail-fast discards the successes; collect-and-partition (`allSettled` / `return_exceptions=True`) surfaces them. 100 profiles where 1 fails is a partition, not a `500` — but the caller must be told which 99 it got.
- **Bound every parallel task in time as well as in count.** Per-task timeout strictly under the parent request budget; cancellation propagated on first hard failure. Un-cancelled siblings keep burning connections after the response has been sent.

## Must not

- **Sequential `await` of independent calls** in any per-request / per-batch / per-job path — `for (const x of xs) await f(x)` where `f` does not consume the previous result. The single largest source of "why does this endpoint take 8 seconds for 80 items?".
- **Unbounded fan-out over an array whose length the client controls.** The defect sits in two places: the missing concurrency cap AND the missing length cap on the validator. Bounding only the concurrency leaves a user-triggerable downstream melt.
- **Parallel work inside a DB transaction.** Most ORM transactions are pinned to one connection — concurrent queries deadlock, race, or silently serialise.
- **Parallel writes that share a key.** `Promise.all([updateBalance(u, +5), updateBalance(u, -5)])` is a race; make the operation commutative (`SET x = x + ?`) or keep it sequential. `Promise.race([dbWrite, cacheWrite])` is not a fast path, it is a non-deterministic bug.
- **Parallelize for "future-proofing".** When `n` is provably ≤ 3, readability cost exceeds the wall-clock win. The rule fires when `n` is variable, request-driven, or large.

## Should

- **Re-shape into stages rather than nesting.** Fetch-inputs ‖ → transform ‖ → write ‖ reads as three phases; nested `Promise.all` chains read as nothing.
- **Stream, don't cap, when the dataset is the problem.** A cap limits in-flight work, not resident memory — 1M rows still OOM. Any wall-clock claim is expected-vs-actual (calls × per-call latency ÷ concurrency vs a measured number), never "looks faster".

## Where the depth lives

- `ai/patterns/parallel-io.md` — per-language recipes, the project's shipped helper, the observed cap table, tracing, pitfalls, and the cite-or-halt detectors with their closure verbs. This rule decides; that pattern executes.
- `.claude/skills/parallelize-independent-ops/SKILL.md` — the procedure for converting an existing sequential path.
- **Lint reach, stated honestly**: ESLint `no-await-in-loop` flags every `await` in a loop in JS/TS. Python and Go have no core linter for sequential-await fan-out, so on those stacks this rule is enforced at review, not in CI.
