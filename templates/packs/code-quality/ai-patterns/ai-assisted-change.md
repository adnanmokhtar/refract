---
name: ai-assisted-change
description: How a model-authored change gets safely into this repo — the comprehension gate, the conventions problem, verifying agent reports, and capturing corrections.
kind: ai-pattern
pack: code-quality
---

# Pattern: AI-Assisted Change

## Context

Load this when a change was **written by a model** — which is most of them now — and you are deciding what has to be true before it merges. The always-loaded rule carries the one mechanical gate (a passing change brief). This file carries why the gate exists, what the model gets wrong that a human reviewer does not, and what to do with the corrections you make along the way.

**Applies universally.**

## Why this is a control-system problem, not a hygiene problem

The instinct is to treat "review the AI's code" as ordinary diligence. The measured effect is stronger than that. DORA's 2025 report on AI-assisted development states its central finding plainly:

> "AI accelerates software development, but that acceleration can expose weaknesses downstream. Without robust control systems, like strong automated testing, mature version control practices, and fast feedback loops, an increase in change volume leads to instability."
> — *2025 DORA Report: State of AI-Assisted Software Development*, <https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report>

Read the mechanism, not just the conclusion. Throughput rises either way; what decides whether stability holds is whether the safety net **already existed** when volume went up. That inverts the usual sequencing argument — "we'll add tests once the feature lands" is not a scheduling preference under AI-assisted development, it is the removal of the control system at exactly the moment change volume is climbing. The same report notes the gains land for teams in loosely coupled architectures with fast feedback and largely do not land for teams without them.

So the tests, the boundary linter and the pre-commit gate in this pack are not tidiness. They are the thing that determines whether the acceleration is worth having.

## The comprehension gate

**If you can't explain the code, it isn't yours — and it doesn't merge.** This is mechanical rather than advisory: every non-trivial change carries a 5-field **change brief** (What / Why this shape / Edge cases / Blast radius / Verified by) in the commit or PR body, generated and validated by the [`change-brief`](../skills/change-brief/SKILL.md) skill, which `/pre-commit` and `/review-changes` dispatch.

The gate works because of an asymmetry: writing the brief takes about two minutes when you understand the change, and is impossible when you don't. It cannot be satisfied by re-reading the diff. A brief that paraphrases the diff, cites nothing, or says "should work" fails the skill's own validation.

Two things the brief is not: it is not a summary for the reader's convenience, and it is not a substitute for the review. It is a check on the *author's* comprehension, which is the thing that silently went missing when the code stopped being typed by hand.

## The conventions problem

A model's default is its training distribution, not your repo. When an agent proposes a generic pattern that does not match the project's conventions, **reject it** — the fact that it compiles is not an argument. This is the single most common way an AI-assisted codebase acquires two ways to do everything.

`ai/conventions.md` and `.claude/codebase-profile.md` exist precisely so the agent has the project's actual conventions available. If the agent is still drifting, that is a diagnosis, not a mystery: either the conventions file is not being loaded, or it does not actually record the convention being violated. Fix the input rather than re-correcting the output every time.

Related, and cheap: **prefer refactoring prompts to generation prompts in existing code.** "Refactor this function to handle X" produces code shaped like its neighbours; "write a function that does X" produces a generic function that may not fit. Generation is for greenfield; refactoring is for everything else.

## Verifying agent reports

Agents have a known, specific failure mode: producing a plausible summary that does not match what happened. When an agent reports "done", the checks are mechanical, and each one has caught a real regression:

- **Did the tests it claims to have run actually run?** Look for the invocation and its output in the session, not the sentence about it. "Tests pass" with no run is the Trusted-Summary failure this repo names by hand in several places.
- **Does the diff contain the change?** A summary describing an edit that is not in `git diff` is not a partial success; it is a fabricated one.
- **Did any step get skipped silently?** A skipped step reported as clean reads identical to a step that passed. Absence of a failure is not evidence of a check.

The general rule this generalises to: a report may claim only what an artifact in the run demonstrates. Anything else is marked `UNVERIFIED` with the reason — never upgraded to a pass because it probably would have passed.

## Capturing corrections

When you correct an agent's output, that correction is durable knowledge and it is about to be lost. Append it to `ai/dynamic/corrections.md` (or `feedback-learned.md`) so the next agent in the same session inherits it, rather than earning the same correction again. The Phase 6 learning loop graduates repeated corrections into permanent rules — which is the only mechanism that makes the correction cost fall over time instead of recurring forever.

## Common mistakes

- **Reviewing the AI's code the way you'd review a junior's.** A junior's mistakes cluster around inexperience; a model's cluster around plausibility. The convincing-but-wrong region is much larger, so citation and execution matter more than reading for smells.
- **Accepting the brief as the verification.** The brief proves comprehension. Tests, types and the boot check prove behaviour. They are different gates and neither substitutes.
- **Letting volume set the bar.** The temptation under high change volume is to lower the gate to keep up. That is the exact condition under which DORA measures stability falling.

## Related

- `.claude/rules/engineering-principles.md` — the always-loaded MUST this pattern explains.
- [`change-brief`](../skills/change-brief/SKILL.md) — the mechanical surface for the comprehension gate.
- [`smoke-verify`](../skills/smoke-verify/SKILL.md) · [`test-shield`](../skills/test-shield/SKILL.md) — the "did it actually run / does it still boot" half.
- `ai/conventions.md` · `ai/dynamic/corrections.md` — the two files that make the conventions problem and the correction loop tractable.
