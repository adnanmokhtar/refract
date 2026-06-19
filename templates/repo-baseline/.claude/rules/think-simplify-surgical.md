---
name: think-simplify-surgical
description: Foundational rule — Karpathy-inspired task discipline (assumptions, simplicity, surgical scope, verifiable success). One of the four load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# Rule: Think · Simplify · Stay surgical · Verify

> **Hard rule (TL;DR):** State assumptions explicitly. Push back when a simpler approach exists. Stop when confused. Write the minimum that solves the stated problem. Every changed line traces to the request. Define a verifiable success criterion before declaring done.

**This rule auto-applies to every agent + every command + every code-writing task in this project.** It complements `read-before-write.md` (what you must read), `read-codebase-deeply.md` (how deep to go), and `code-quality.md` (what "clean" means). Read those FIRST; this rule layers task-discipline on top.

Inspired by Andrej Karpathy's observations on LLM coding pitfalls — adapted to our schema and cross-referenced with existing rules.

---

## 1. Think before coding (assumptions, tradeoffs, confusion)

### Must

- **State assumptions explicitly** before writing code. Where the request is ambiguous, list the interpretations and pick one with a one-line justification — never silently.
- **Push back when a simpler approach exists.** If the user asked for X but Y achieves the same goal with less code / fewer moving parts, say so before implementing X.
- **Stop when confused.** Name what's unclear (the file you couldn't reconcile, the contract that contradicts the request, the missing piece) and ask. Confusion that gets papered over with "best-effort" code is the failure mode this rule exists to prevent.
- **Surface tradeoffs the user hasn't considered.** Performance vs. readability, library X vs. library Y, monolith vs. extract — when there's a real choice, name both options and your recommendation.

### Must not

- Pick an interpretation silently when the request has more than one reasonable reading.
- "Just run with it" when a key fact (file location, base class, contract) is unknown and unread — read it or ask.
- Hide a known tradeoff inside the code (a magic constant, a silent retry, a fallback branch) instead of surfacing it in the response.

### Should

- Default the answer to "I'll do A because B; alternatives C and D were considered. Confirm or correct." for any non-trivial change. Trivial changes (typos, obvious one-liners) skip this — see the tradeoff note at the bottom.

---

## 2. Simplicity first (no speculation, no premature abstraction)

### Must

- Write the **minimum code that solves the stated problem.** Lines beyond that need a stated reason.
- **Match what the codebase already does** for the concern at hand (see `read-before-write.md` "Match classes, folders, suffixes..."). Adding a parallel approach because it's "cleaner" is rejected unless the user explicitly asked for refactoring.
- **Apply the senior-engineer test:** would a senior engineer on this codebase say this is overcomplicated? If yes, simplify before submitting.

### Must not

- Add features beyond what was asked.
- Introduce abstractions for code that has exactly one caller.
- Add "flexibility" / "configurability" / "future-proofing" the user did not request.
- Add error-handling branches for scenarios that cannot occur (see `code-quality.md` Anti-patterns: "Fallback branches for scenarios that cannot happen").
- Wrap working code in a class / interface / factory because it "feels right" — feelings are not requirements.

### Should

- If the implementation passed 200 lines for what looked like a 50-line problem, stop and ask whether you misread the request before continuing.

---

## 3. Surgical changes (touch only what you must)

### Must

- **Every changed line traces directly to the request.** If you can't explain why a line changed by pointing at the request, revert it.
- Match existing style (formatting, naming, structure) even if you'd do it differently in a greenfield repo. Style consistency > personal preference (see `read-before-write.md`).
- **Clean up only your own mess.** Imports / variables / functions made unused *by your changes* are yours to remove. Pre-existing dead code is not.
- When you notice unrelated drift (dead code, stale comments, broken patterns), **append to `ai/dynamic/drift-log.md`** and mention it in the response — do not silently fix it (see `read-codebase-deeply.md` Should bullet).

### Must not

- "Improve" adjacent code, comments, or formatting outside the requested scope.
- Refactor things that aren't broken.
- Remove pre-existing dead code unless the user asked.
- Mix unrelated changes in one commit (see `code-quality.md` Must not).

### Should

- Bound the **Boy Scout Rule** to what's *adjacent to the change you were already making* (one obvious cleanup on a touched line is fine; a whole-file rewrite isn't). The setup-project Hard Rules section in `commands/setup-project.md` is the source of truth for this scoping.

---

## 4. Goal-driven execution (define success, loop until verified)

### Must

- **Transform imperative requests into verifiable goals** before implementing. Concrete examples:

  | Imperative request | Verifiable reframe |
  |---|---|
  | "Add validation" | "Write tests for invalid inputs (empty, oversize, malformed, boundary), then make them pass" |
  | "Fix the bug" | "Write a test that reproduces the bug, then make it pass" |
  | "Refactor X" | "Capture current test pass list; refactor; ensure same list still passes" |
  | "Make it faster" | "Capture current benchmark; change; show the new benchmark + delta" |

- For multi-step tasks, **state a brief plan with a verify step per item** before writing code:
  ```
  1. <action> → verify: <check that proves this step worked>
  2. <action> → verify: <check>
  3. <action> → verify: <check>
  ```
- **Loop until verification passes.** Strong success criteria let the agent self-check; weak criteria ("make it work") force the user to be the verifier and waste a round trip.

### Must not

- Declare "done" without running the verification you just stated.
- Substitute "the code looks right" for "the test passes / the benchmark moved / the lint is green".
- Hide a failing check by silencing it (skipping a test, lowering a threshold, swallowing an exception) — surface it as a tradeoff per § 1 instead.

### Should

- For changes touching multiple files, list the files in the plan and verify each before moving to the next, rather than touching all of them then verifying once.

---

## Review checklist (apply to every change before declaring done)

- [ ] Assumptions stated explicitly, or the request was unambiguous.
- [ ] Tradeoffs named where multiple reasonable approaches exist.
- [ ] Implementation is the minimum that solves the stated problem.
- [ ] No speculative abstractions, configurability, or error handling for impossible scenarios.
- [ ] Every changed line traces to the request (no drive-by edits).
- [ ] Drift noticed but out-of-scope was logged to `ai/dynamic/drift-log.md`, not silently fixed.
- [ ] A verifiable success criterion was defined and met (test passing, benchmark moving, lint green, command output matching expected).

## Enforcement

- Auto-loaded from `.claude/rules/` by Claude Code's native rule mechanism (alongside `read-before-write.md` and `read-codebase-deeply.md`), so it applies to every agent + command without per-call injection.
- PR-review prompt: any reviewer who sees scope creep, speculative abstraction, hidden tradeoffs, or "make it work" verification should reject and cite this rule.
- Surfaces in the Phase 5 audit when a generated artifact violates the principles (e.g. an agent file that says "implement X" without a verify step is a quality miss).

## Tradeoff note

These principles bias toward **caution over speed**. For trivial work (typo fixes, obvious one-liners, isolated bug fixes with an existing reproducer test) the full ritual is overkill — apply judgment. The goal is reducing costly mistakes on **non-trivial** work, not slowing down simple tasks.

The cost of cautious-when-trivial: one extra sentence in the response.
The cost of sloppy-when-non-trivial: a wrong design that ships, gets reviewed-as-correct, and decays into the codebase.

When in doubt, treat the task as non-trivial.

## Cross-references

- `read-before-write.md` — what to read before any edit (precondition for principle 1).
- `read-codebase-deeply.md` — tiered reading; ground truth handling (precondition for principles 1 + 3).
- `code-quality.md` — what "clean" means (overlap with principle 2).
- Hard Rules § "Boy Scout Rule" in `commands/setup-project.md` — scoping for principle 3.
- Phase 5 audit in `commands/setup-project.md` — the command-level analogue of principle 4.
