---
name: think-simplify-surgical
description: Foundational rule — Karpathy-inspired task discipline (assumptions, simplicity, surgical scope, verifiable success). One of the five load-bearing rules every project ships (Hard Rule A19).
applies-to: every-agent, every-command, every-code-writing-task
severity: must
---

# Rule: Think · Simplify · Stay surgical · Verify

> **Hard rule (TL;DR):** State assumptions explicitly. Push back when a simpler approach exists. Stop when confused. Write the minimum that solves the stated problem. Every changed line traces to the request. Define a verifiable success criterion before declaring done.

Loads every session (no `paths:`) and layers task discipline on `read-before-write.md`, `read-codebase-deeply.md` and `code-quality.md`.

Inspired by Andrej Karpathy's observations on LLM coding pitfalls — adapted to our schema and cross-referenced with existing rules.

---

## 1. Think before coding (assumptions, tradeoffs, confusion)

### Must

- **Ask, don't assume,** before writing code. Where the request is ambiguous, list the interpretations and ask which one, with the others, in one round (`.claude/templates/snippets/study-before-build.md`). Pick one yourself only when the choice changes nothing the person sees or relies on (an internal name, a file's layout), and say which.
- **Push back when a simpler approach exists.** If the user asked for X but Y achieves the same goal with less code / fewer moving parts, say so before implementing X.
- **Stop when confused.** Name what's unclear (the file you couldn't reconcile, the contract that contradicts the request, the missing piece) and ask. Confusion that gets papered over with "best-effort" code is the failure mode this rule exists to prevent.
- **Start only on a yes.** Once you have asked "shall I start?", wait for an explicit go. Praise, "I want the best practice", a question, or a forwarded report is not one; neither is a status line you printed yourself. When the person says they are stopping or closing, launch and resume nothing.
- **Every claim in an answer is checked or marked a guess.** Cite the file, the command output or the test that shows it, or write `GUESS:` in front. A claimed defect names the scenario, who it hits and its measured size. Retracting one says what was wrong and why it was missed.
- **Surface tradeoffs; decide before an improvement.** Where there's a real choice, name the options and your recommendation. An improvement that `.claude/templates/snippets/decide-before-change.md` § 1 gates (a new moving part, data at scale, moved responsibilities, more cost, a major upgrade, real alternatives) waits for the person's pick on its decision card: the measured problem, options (leaving it, unless § 4 drops it), cost against gain, what it delays, the risks. No number → measure first. Sophisticated is not better.

### Must not

- Pick an interpretation silently when the request has more than one reasonable reading.
- "Just run with it" when a key fact (file location, base class, contract) is unknown and unread — read it or ask.
- Hide a known tradeoff inside the code (a magic constant, a silent retry, a fallback branch) instead of surfacing it in the response.

### Should

- Default a non-trivial answer to "I'll do A because B; C and D considered. Confirm or correct." Trivial changes skip it (tradeoff note below).

---

## 2. Simplicity first (no speculation, no premature abstraction)

### Must

- Write the **minimum code that solves the stated problem.** Lines beyond that need a stated reason.
- **Match what the codebase already does** for the concern at hand (see `read-before-write.md` "Match classes, folders, suffixes..."). Adding a parallel approach because it's "cleaner" is rejected unless the user explicitly asked for refactoring.
- **Apply the senior-engineer test:** would a senior engineer on this codebase say this is overcomplicated? If yes, simplify before submitting.
- **Reuse before you write**, in this order: this codebase's own helper → the standard library or platform → a dependency already installed → new code. Never add a dependency for a few lines.
- **Mark a shortcut with a known limit** where it lives, one line: `shortcut: <the limit>, <when to upgrade>`. Reviewers read it as a decision, not a finding (`.claude/templates/snippets/precedents/code-quality.md` § 93). Never a shortcut: validation at a trust boundary, error handling that prevents data loss, security, accessibility.

### Must not

- Add features beyond what was asked.
- Introduce a NEW abstraction before its third occurrence; a second copy reuses what exists (`THR-DRY`, precedence A28).
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
- When you notice unrelated drift (dead code, stale comments, broken patterns), **append to `ai/dynamic/drift-log.md`** and mention it in the response — do not silently fix it. A missing engineering-baseline guarantee on the path you change is not drift: it is in scope (precedence A27).

### Must not

- "Improve" adjacent code, comments, or formatting outside the requested scope.
- Refactor things that aren't broken.
- Remove pre-existing dead code unless the user asked.
- Mix unrelated changes in one commit (see `code-quality.md` Must not).

### Should

- The **Boy Scout Rule** applies only to lines this change already touches; surgical wins (precedence A1, Hard Rule A17).

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

- [ ] Every open point was asked, in one round, before code — none filled by an assumption — or the request was unambiguous.
- [ ] Tradeoffs named; an improvement waited for its decision card.
- [ ] Implementation is the minimum that solves the stated problem.
- [ ] No speculative abstractions, configurability, or error handling for impossible scenarios.
- [ ] Every shortcut with a known limit carries its `shortcut: <the limit>, <when to upgrade>` comment.
- [ ] Every changed line traces to the request (no drive-by edits).
- [ ] Drift noticed but out-of-scope was logged to `ai/dynamic/drift-log.md`, not silently fixed.
- [ ] A verifiable success criterion was defined and met (test passing, benchmark moving, lint green, command output matching expected).

## Enforcement

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
- `.claude/templates/governance/precedence.md` — which rule wins when two disagree (A1 Boy Scout, A27 drift vs baseline, A28 DRY).
- Phase 5 audit in `commands/setup-project.md` — the command-level analogue of principle 4.
