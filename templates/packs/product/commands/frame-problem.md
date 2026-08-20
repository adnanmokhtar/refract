---
description: Produce the problem brief before anyone designs a solution — who has it, what evidence says so, what they do today instead, the do-nothing baseline, the success and counter-metric pair, and the kill criteria. Writes a brief, never a spec.
kind: command
pack: product
---

# /frame-problem [<problem or feature request>]

Turn a request, an idea, or a complaint into a refutable problem statement with its evidence, its alternatives, and its stopping condition — before it attracts commitment and becomes unarguable.

## When to use / NOT to use

- USE: a solution arrived with no problem attached; a feature request needs assessing before it enters a roadmap; nobody can answer "why are we building this" in one sentence; before committing to anything larger than a sprint.
- NOT: to turn an agreed problem into a buildable spec — that is `/analyze-task` and `@business-analyst` in the business pack.
- NOT: to map what is intended-but-unbuilt in an existing codebase — that is `/roadmap`.
- NOT: to review a written spec's quality — that is `/audit-requirements`.

## Phases applied

1-3 + 4 + 5. Phase 6 is deliberately absent: a brief cannot be validated by inspection, only by the tests it names. Phase 7 is the review at the kill-criteria date.

## The Premise (read this first, internalize, do not deviate)

**Evidence or assumption — every claim carries one label, and there is no third category.** An unlabelled claim reads as fact to everyone downstream and gets repeated as one.

**Never invent evidence.** No fabricated quotes, no imagined personas, no invented numbers, no "users say". Where there is no research, the brief says *"no direct evidence; assumption ranked <n>"* — and it is more useful than a confident brief, because it says what to go and find out.

**The do-nothing baseline is a scored option**, including what users do today instead: a competitor, a spreadsheet, a manual process, nothing at all.

**Kill criteria before commitment.** A project with no stated failure condition cannot fail; it can only be quietly extended.

**Escalation triggers (halt and ask):**
- The problem statement, after questioning twice, is still a solution.
- The target segment is "everyone".
- Success cannot be measured by anything the system emits or could emit.
- The decision has already been made and the brief is being requested as justification — say so plainly.

## Phase 1 — Understand

One consolidated question covering whatever is missing:
- **Who** — a named segment, not "users". If the answer is "everyone", narrow it or record that it cannot be narrowed, which is itself a signal.
- **When** — the trigger situation, not a general condition.
- **What they are trying to accomplish** — the outcome, in their vocabulary.
- **What blocks them today**, and **what it costs them** in their terms.
- **What evidence exists** — research, tickets, metrics, sales notes, customer commitments — and whether any of it is reachable.

Then apply the mechanism test to the resulting paragraph: does any noun in it name a feature? If so, rewrite. This catches most bad briefs in one pass.

## Phase 2 — Organize

Four blocks, in this order, because each constrains the next:
1. Problem statement (mechanism-free).
2. Evidence, classified and counted.
3. Alternatives, including do-nothing, each scored.
4. Success metric, counter-metric, kill criteria, decision owner.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/problem-framing.md`, `ai/patterns/opportunity-sizing.md`, `ai/patterns/research-synthesis.md`.
- `.claude/rules/product-principles.md`.
- `ai/users-and-personas.md`, `ai/project-goals.md`, `ai/business-model.md`, `ai/competitive-context.md` where present — a brief that contradicts the stated strategy is a finding about one of the two.
- `ai/product/research/` — synthesised findings are the strongest available evidence. If raw material exists but has not been synthesised, run `/synthesize-research` first rather than quoting raw notes.
- Support-ticket volumes and product metrics, where reachable.

## Phase 4 — Generate

Dispatch `@product-strategist`, then assemble:

1. **Problem statement** — one paragraph, mechanism-free, in the user's vocabulary.
2. **Evidence table** — source, class, count, recency, what it supports, what it does not. Classes ranked: observed behaviour > support and sales records > direct research (for *why*) > stated preference > internal opinion.
3. **Today's alternative** — named precisely, with the switching cost: what must be true for someone to move off it.
4. **Options** — each sized via `ai/patterns/opportunity-sizing.md`, with do-nothing as a row. Every input is sourced or an explicitly-labelled guess with a range.
5. **Success metric** — the one number, its current value, its target, its window, and whether it is instrumented today.
6. **Counter-metric** — the number that would reveal damage, with the threshold at which the change is rolled back. Every optimisation has one.
7. **Kill criteria** — a condition and a date. **Decision owner** — a named person.
8. **Assumption ledger** — everything not evidence-backed, ranked by impact × uncertainty, each with its cheapest test. Run the `assumption-ledger` skill.

## Phase 5 — Update

- Write `ai/product/briefs/<slug>.md` — the brief above, dated.
- Append the assumption ledger's top rows to `ai/product/assumptions.md`, which is the running list across briefs.
- Where the brief identifies an instrumentation gap for the success or counter-metric, record it — that gap is work, and it must land before launch or the launch cannot be judged.

## Output format

```
## /frame-problem — <slug>

Problem: <who · when · trying to · blocked by · costing them>     mechanism-free: <yes>

Evidence:
| Source | Class | Count | Recency | Supports | Does NOT support |
Strongest class present: <class>   |   Claims labelled assumption: <n>

Today's alternative: <named>   Switching cost: <what must be true>
Do-nothing baseline: <what happens, with what attached>

Options:
| Option | Sized | Confidence | Cost | Trade-off |
| do nothing | — | — | — | <consequence> |

Success metric:  <name> — now <x> → <y> by <date>   instrumented: <yes | gap: …>
Counter-metric:  <name> — rollback at <z>            instrumented: <yes | gap: …>
Kill criteria:   <condition> by <date>               Decision owner: <named person>

Assumption ledger (top rows):
| # | Assumption | Impact | Uncertainty | Cheapest test | Cost |

Recommendation: pursue | pursue smaller | test first | do not pursue — <one line>

Status: <see gate below>
```

### Closure gate — COMPLETE only when the brief is refutable

- **`Status: COMPLETE`** — the problem statement passes the mechanism test, every claim carries evidence or an assumption label, do-nothing is a scored row, both metrics are named with their instrumentation status, and the kill criteria carry a date and a named owner.
- **`Status: INCOMPLETE — unmet: <list>`** — any unlabelled claim, a missing counter-metric, an absent do-nothing row, kill criteria with no date, or no named decision owner. Name each.

This gate is **[self-policed]** on the Status line. `@requirements-reviewer` will BLOCK a downstream spec whose brief has no counter-metric, and `@scope-arbiter` cannot classify anything without the success metric this brief declares.

## Hard rules

- **Never fabricate a quote, a persona, a number, or a finding.** "No direct evidence" is the correct output when there is none.
- **Every claim is cited or labelled an assumption.**
- **Do-nothing is scored, not mentioned.**
- **A success metric without a counter-metric is incomplete.**
- **Kill criteria have a date and an owner.**
- **This command never writes a spec.** Hand the agreed problem to `/analyze-task`.
- **Never produce a brief to justify a decision already made.** Say that is what is happening.

## Failure modes

- The problem statement names a feature, so the discussion becomes design and the alternatives are never considered.
- Internal opinion presented in the same voice as data.
- A market size that assumes total reach.
- A success metric that counts activity rather than outcome.
- No counter-metric, so the first number is optimised at any price.
- Kill criteria written, never revisited, and the review date passing unnoticed.
- The brief written after the work started, and edited to match.

## Related

- `@product-strategist` — the agent this command dispatches.
- `@user-research-synthesizer` — supplies the evidence; run `/synthesize-research` first if raw material is unsynthesised.
- `assumption-ledger` — the ranked ledger this brief ends with.
- `/define-success` — turns the metric pair into an instrumentation plan.
- `/analyze-task` (business pack) — takes the agreed problem and writes the spec.
- `ai/patterns/problem-framing.md`, `ai/patterns/opportunity-sizing.md`.
