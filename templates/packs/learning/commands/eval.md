---
description: Score the project's accumulated AI knowledge against saved eval cases — the measurement half of the learning loop. Proves promoted rules/conventions/patterns actually make the AI produce correct work, and catches regressions when knowledge rots. Sibling to `/learn-from-task` (which captures) — `/eval` grades.
---

# /eval

`/learn-from-task` **captures** what a session learned and promotes it into the formal layer (`.claude/rules/`, `ai/conventions.md`, `ai/patterns/`). Nothing in the shipped loop ever checks that a promoted rule **actually works**. `/eval` is that missing check: it replays saved scenarios with known-good answer keys against the AI *as configured by the current knowledge base*, scores each, and records a dated scorecard. It is the exam to `/learn-from-task`'s note-taking.

This closes the loop:

```
/learn-from-task → captures "AI kept getting refund-auth wrong" → curator promotes a rule
/eval            → re-runs the refund-auth case → PASS ⇒ proof the rule worked
                                                → FAIL ⇒ appends to ai/dynamic/learnings.md, try again
```

## Scope (the artifact set this command owns)

| Artifact | Role |
|----------|------|
| `ai/evals/cases/<slug>.md` | one frozen scenario + answer key + `guards:` provenance |
| `ai/evals/_scorecard.md` | append-only dated run log — the REAL recorded outcome (Phase 6 asserts it was written) |
| `ai/evals/README.md` | lifecycle + case format reference (ships in the baseline) |

`/eval` is the ONLY writer of `_scorecard.md`, and (besides `--seed`) never edits case files — a run must not silently rewrite the answer key it is being graded against.

## Closed verb vocabulary (this command does these and nothing else)

- **RUN** — execute a case: give the AI the scenario, capture output, score vs the answer key.
- **SEED** — generate a missing case stub from an unguarded rule / convention / failure (`--seed`). Writes a stub; never scores it.
- **GUARD** — the `guards:` link from a case to the promoted knowledge it protects (the coverage unit).
- **REGRESS** — flag a case that got **worse** than the previous scorecard run: verdict PASS→FAIL, **or** `score` dropped while the verdict stayed FAIL.
- **RETIRE** — mark a case STALE when its `guards:` target no longer exists.

No architectural moves, no code edits to product source, no promotion — promotion is `knowledge-curator`'s job; `/eval` only measures.

## Modes

- **default** — RUN every case in `ai/evals/cases/`, write a scorecard run, feed failures to `ai/dynamic/learnings.md`.
- **`--case <slug>`** — RUN one case only (fast iterate on a single scenario).
- **`--coverage`** — read-only. Report coverage % + the five detectors below. No runs, no writes.
- **`--seed [rules|conventions|failures]`** — SEED case stubs for unguarded knowledge of the given kind (default: all). Writes stubs to `cases/`; does not run them.

## Detectors (the specialist lenses — run in every mode except `--case`)

1. **UNGUARDED** — a promoted knowledge unit with no case citing it in `guards:`. Sources swept: every `.claude/rules/*.md`, every managed entry in `ai/conventions.md`, every `ai/patterns/<name>.md`. Coverage = guarded units ÷ total units.
2. **REGRESS** — a case that got worse since the previous `_scorecard.md` run. Two triggers, not one:
   - **verdict regression** — PASS in the prior run, FAIL now. A promoted rule stopped protecting.
   - **score regression** — FAIL in both runs, but `score` fell (7/8 → 2/8). Verdict-only detection is blind here: both runs are FAIL, so the flip never happens, and a case collapsing from one missed assertion to six looks *identical to no change at all*. The scorecard already records the fraction that proves it; the detector simply was not reading it. This is the common shape — a case that has never passed is exactly the case nobody watches.

   Both are reported as `−`. A score that **rose** while still FAIL is `+`, not `=`: partial progress on a failing case is the signal that the last fix helped, and flattening it to `=` tells the user their work did nothing.
3. **STALE** — a case whose `guards:` cites a rule/convention/pattern that no longer exists (RETIRE candidate).
4. **TOOTHLESS** — a case whose answer key has zero checkable MUST-include assertions. Unscoreable → reported, counted as no coverage.
5. **UNCOVERED-FAILURE** — an `ai/failures/_index.md` entry or a `feedback-learned.md` correction with `Repeated ≥ 2` that no case guards against recurrence. These are the mistakes most worth an eval.

## Pre-flight gate (mechanical)

- If `ai/evals/cases/` has zero non-template case files AND mode is default/`--case`: halt with `no eval cases yet — run /eval --seed to generate stubs from your promoted rules, then fill in the answer keys.` (Do NOT fabricate a passing scorecard from nothing — that is the enforcement-theater failure mode.)
- If `--case <slug>` names a file that doesn't exist: halt, list available case slugs.

## Phase 1 — Understand (what is being graded)

Establish the knowledge surface under test:
- Enumerate promoted units: `.claude/rules/*.md`, managed entries in `ai/conventions.md`, `ai/patterns/*.md`.
- Enumerate cases: `ai/evals/cases/*.md` (skip `_template.md`).
- Read the previous run block in `ai/evals/_scorecard.md` (for the REGRESS Δ).

## Phase 2 — Decompose (one independent scoring unit per case)

Each case is scored in isolation, in its own sub-context, so one case's scenario can't leak knowledge into another's. Cases are independent, so RUN order never changes a verdict. On Claude Code, RUN them as a parallel wave (one scoring sub-agent per case); this fan-out is **Claude-native and degrades to sequential** on adapters without parallel sub-agent dispatch — same cases, same answer keys, same scorecard, only slower (see `## Adapter execution`). Collect every verdict, then write ONE scorecard block.

## Phase 3 — Retrieve (per case)

For each case, load exactly what its `Setup` block allows the graded AI to see (default: the project knowledge base — `ai/`, `.claude/rules/` — i.e. the real configuration a normal session runs with). Do NOT show the graded sub-agent the answer key.

## Phase 4 — RUN + score (per case)

> **HARD INVARIANT — the graded sub-agent is READ-ONLY. Scoring must NEVER mutate the repo.** A case is testing what the AI *would* produce, captured as text and graded — not something to apply. The Scenario prompts ("add a service", "show me the `useAsyncData` call") will make a write-capable agent actually create/edit product source (observed 2026-07-12: a scoring run leaked `brandService.ts` + 5 other source changes that had to be reverted by hand). Prevent it structurally, not by hoping the agent behaves.

For each case:
1. Dispatch the graded sub-agent **read-only**: give it ONLY read tools (`Read`, `Grep`, `Glob`) — NEVER `Write`/`Edit`/`MultiEdit`/`NotebookEdit`/`Bash` or any codegen/apply tool. Tell it explicitly: *answer the Scenario by PROPOSING your code/answer as fenced text — do NOT create, edit, or apply any file.* (Belt-and-suspenders for adapters/harnesses that can't restrict tools: run it under `isolation: worktree` so any stray write lands in a throwaway tree, never the real repo.) Give it the `## Scenario` prompt (and any `## Setup` fixtures) — nothing else, and NEVER the answer key.
2. Capture its proposed answer (text only). If the sub-agent nonetheless wrote to the repo, that is a HARNESS FAILURE, not a valid run: revert every product-source change it made, record the run as VOID (not PASS/FAIL — a mutated repo can't be trusted to reflect fresh authoring), and fix the read-only dispatch before re-running.
3. Score against `## Answer key`:
   - `must_have_hits` = MUST-include assertions satisfied.
   - `must_not_violations` = MUST-NOT assertions violated.
   - `score = must_have_hits / total_must_have`.
   - **verdict = PASS** iff `score == 1.0` AND `must_not_violations == 0` (unless the case overrides its own threshold); else **FAIL**.
4. Compare to the previous run for this case → set Δ. **Compare `score` first, verdict second** — verdict is a threshold over score, so score carries strictly more information and a verdict-only comparison discards it:
   - no prior run → `NEW`
   - `score` fell, OR verdict PASS→FAIL → `−` (REGRESS)
   - `score` rose, OR verdict FAIL→PASS → `+`
   - `score` and verdict both unchanged → `=`

## Phase 5 — Record (the real outcome artifact)

Append ONE run block to `ai/evals/_scorecard.md` (never overwrite prior runs — it is the regression history):

```markdown
### <YYYY-MM-DD> — run <N>  ·  cases: <X>  pass: <Y>  fail: <Z>  coverage: <C>%
| case            | guards                          | score        | Δ prev | verdict |
|-----------------|---------------------------------|--------------|--------|---------|
| refund-auth     | .claude/rules/refund-auth.md    | 3/3, 0 viol  | =      | PASS    |
| order-n-plus-1  | ai/conventions.md#queries       | 2/3, 0 viol  | −      | REGRESS |
| bulk-import     | .claude/rules/import.md         | 2/8, 0 viol  | −      | REGRESS |   <!-- was 7/8 FAIL: verdict unchanged, score collapsed -->

Unguarded (no case): <n> — <list top 3>
Stale (RETIRE): <list>  ·  Toothless: <list>
Failures fed to ai/dynamic/learnings.md: <case slugs, or "none">
```

Then, for every FAIL/REGRESS, append a raw observation to `ai/dynamic/learnings.md` (status `RAW`, `Seen: 1` or increment) describing what the AI got wrong and which GUARD it broke — this is the sink hand-off the curator later reads. See the canonical sink table: [`templates/snippets/learning-sink.md`](../../../snippets/learning-sink.md). `/eval` is a third *writer* of the `learnings.md` sink (alongside `/learn-from-task` and `knowledge-curator`); it never writes any other sink.

## Phase 6 — Validate (assert a real recorded outcome — anti-theater)

- `ai/evals/_scorecard.md` gained exactly one new dated run block, with a row per RUN case (not a summary claim — actual rows).
- `pass + fail == cases run`; coverage % = guarded ÷ total promoted units, recomputed this run (not copied).
- Every REGRESS/ FAIL produced a matching `learnings.md` entry (count them — a scorecard FAIL with no sink entry is a broken loop).
- No case file was modified by a default/`--case` run (diff `cases/` — must be clean unless `--seed`).

## Phase 7 — Improve (surface, do not auto-drain)

Same honesty contract as `/learn-from-task`: **there is no auto-invoking hook and no cron in the shipped baseline.** After a run:
- REGRESS rows are the action list — a promoted rule stopped working; fix the rule or the code, then re-`/eval`.
- UNGUARDED units are the backlog — `/eval --seed` turns them into case stubs to fill in.
- The `learnings.md` entries this run wrote are drained by the normal path (`/audit-knowledge` → `knowledge-curator`).

If you want it automatic, wire `/eval` into a `Stop` hook (run after a task) or into CI on push yourself — the baseline does not do this for you. Recommended order: run it manually until you trust the scores, THEN add the hook. (See the "auto vs manual" note in `ai/evals/README.md`.)

## Adapter execution (runs on every tool, not just Claude)

`/eval` is a learning-pack command: it ships as `.claude/commands/eval.md` and rides the **generic per-command translation** into each adapter's native primitive (OpenCode `.opencode/commands/eval.md` + `agent: build`, Cursor `.cursor/skills/eval/SKILL.md`, Continue `invokable: true`, Copilot `mode: agent`, Gemini `.gemini/commands/eval.toml`, Codex `.agents/skills/eval/SKILL.md`, Kimi dual-surface skill + subagent with the EXECUTE NOW preamble, Aider `CONVENTIONS.md` EXECUTE-NOW prose, …) — the exact path `/learn-from-task` already travels, so no per-adapter special-casing is needed.

Two portability contracts the translation depends on — keep them true if you edit this command:

- **Fan-out is Claude-native; sequential is the floor.** The only Claude-specific step is Phase 2's parallel scoring wave. Because cases are independent, scoring them one-by-one yields the *identical* scorecard — so every adapter runs `/eval` correctly, just slower. Never let a verdict depend on other cases running concurrently. On sequential adapters, use `--case <slug>` to iterate without re-running the whole suite. (Same split as `/execute-plan` and the spec→build reviewer fan-out — see `templates/tool-adapters/_registry.md`.)
- **Tool scope = read + write, never shell/codegen.** `/eval` (the orchestrator) reads the knowledge base and writes ONLY `ai/evals/_scorecard.md` + `ai/dynamic/learnings.md`; it never edits product source. Translators derive the Kimi/Aider tool whitelist from this (`read,write`, not full-action `shell`) — so this command must stay a knowledge-writer, not a code-writer. **The GRADED sub-agents are stricter still: read-only (`read` only, no `write`/`shell`/codegen) — they PROPOSE answers as text and must never touch the repo (see the Phase 4 hard invariant).** `--coverage` is fully read-only (no sub-agents, no writes) — the cheap way to check the knowledge base before paying for a scoring run.

## Output

```
## /eval — scored

Phase 1 (Understand): 12 promoted units (4 rules, 6 conventions, 2 patterns), 7 cases, prev run = run 4.
Phase 4 (Ran): 7 cases in parallel.
Phase 5 (Recorded): ai/evals/_scorecard.md +1 run block (run 5).

Scorecard — run 5 · cases: 7  pass: 5  fail: 2  coverage: 58%
  PASS    refund-auth        (guards rules/refund-auth.md)        3/3  =
  PASS    tenant-scope       (guards conventions#tenancy)         2/2  =
  REGRESS order-n-plus-1     (guards conventions#queries)         2/3  −   ← was PASS in run 4
  FAIL    idempotency-key    (guards patterns/idempotency.md)     1/3  NEW

Detectors:
  Unguarded (5 units, no case): rules/webhook-retry, conventions#pagination, conventions#error-envelope, patterns/base-service, ...
  Stale (RETIRE): none
  Toothless: eval "misc-check" has no MUST-include assertions — unscoreable
  Uncovered-failure: failures/_index #0001 (TypeORM decorator) has no guarding case

Loop close: 2 failures → ai/dynamic/learnings.md (+2 RAW).
Action: fix the query rule (order-n-plus-1 regressed), then re-run /eval --case order-n-plus-1.

Status: COMPLETE (2 regressions — knowledge base degraded since run 4)
```

## Failure modes

- **No cases yet**: halt + point to `/eval --seed` (never invent a green scorecard).
- **Toothless case** (no checkable MUST assertions): report it, exclude from pass/fail counts — don't guess a score.
- **Non-deterministic case** (output legitimately varies): the answer key should assert invariants (must-include / must-not), not exact strings. If a case flaps across runs with no code/knowledge change, flag it as flaky in the scorecard, not as a real REGRESS.
- **Case leaks the answer**: if `## Setup` accidentally exposes the answer key, the score is meaningless — flag and RETIRE.
- **Coverage gaming**: a case that `guards:` a unit but has a toothless key counts as UNGUARDED for coverage, not guarded — you can't inflate coverage with empty cases.

## See also

- `ai/evals/README.md` — case lifecycle + the auto-vs-manual wiring note (ships in the baseline).
- `ai/evals/cases/_template.md` — the case format (scenario + answer key + `guards:`).
- `ai/evals/_scorecard.md` — append-only run history (the regression record).
- `ai/dynamic/learnings.md` — where FAIL/REGRESS observations land (the sink `/eval` writes).
- `templates/snippets/learning-sink.md` — the canonical sink table (`/eval` is a `learnings.md` writer).

## Related

### Sibling commands in learning pack
- `/learn-from-task` — the capture half; `/eval` is the grade half (this command).
- `/audit-knowledge` — drains the sinks `/eval` feeds (dispatches `knowledge-curator`).
- `/promote-pattern` / `/promote-decision` — graduate a READY entry; seed an eval case after promoting.
- `/refresh-knowledge` — long-term knowledge refresh; re-run `/eval` after to catch what changed.

### Patterns
- `ai/patterns/setup-quality-scoring.md` — the sibling scoring rubric (setup quality); `/eval` scores knowledge-base quality.
