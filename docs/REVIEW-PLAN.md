# Pack-wide review — what to check, and why these checks

**Status: NOT STARTED.** This is the brief, not the result. Written 2026-09-19 after two defects
in `/ui-audit` were found by *running it on a real app* rather than by reading it, and the same
questions have never been asked of the other 150 commands, 118 skills and 89 agents.

## Why a review at all

The repo has 49 gates and they are all green. None of them can fail on the defects that actually
shipped:

| Shipped defect | Every gate said |
|---|---|
| `/ui-audit` reported every page clean having rendered nothing | green |
| The quality rubric existed in `/redesign` and `/ui-audit` routed around it | green |
| The signal scanner never opened a monorepo's workspace manifests | green |
| An anchor cited a file deleted weeks earlier; the audit flagged it forever and the repairer skipped it | green |
| `unify-component` closed the easy half of unification and nothing owned the hard half | green |

The gates check **structure** — does the file exist, does the link resolve, is the count right, is
the budget kept. Not one of them asks **does this artifact do what it claims**. That is the gap
this review is for, and it is why the review is mostly reading and running, not scripting.

## The five questions

Ask every one of them of every artifact. They are ordered by how often they found something.

### 1. Can it report success without doing the work?

The `/ui-audit` defect, and the most valuable question in the list. An artifact passes only if
something **mechanical** — not a sentence of prose — prevents a verdict with no evidence behind
it. `/audit` passes this: its cell ledger forces every `surface × concern` cell into *reviewed* /
*N/A with a reason* / *live-unreviewed*, and makes it print the arithmetic. `/ui-audit` failed it
until HALT #6 was added.

**Check**: what artifact must exist before this thing may say "done"? If the answer is "it says it
won't lie", that is a fail.

### 2. Is it a bar, or only a defect list?

A fingerprint that does not match means *no defect of that shape was found* — never *this is good*.
An artifact built only on fingerprints reports `clean` on work that is correct and mediocre, which
is how it fails while appearing to work.

**CLOSED for the two audit commands, 2026-09-19.** `/ui-audit` Phase 1.5 scores every rendered
surface; `/audit` Phase 1.5 scores every resolved surface against its own axes (Architecture 01,
Maintainability 10, Modularity 22, Domain Modeling 12, Testing 08, Developer Experience 30), and a
below-bar surface becomes a first-class P3 row with no finding behind it. Both reject a scorecard
derivable from metrics alone. Both make the score part of the ledger arithmetic, so `scanned,
nothing found` can no longer stand in for `looked at properly`.

**Still open everywhere else.** The question applies to `/optimize`, `/polish`, `/align`,
`/security-audit`, `/db-audit`, `/perf-audit` and every pack audit skill, none of which have been
asked it.

### 3. Does it route around machinery that already exists?

`/ui-audit` reached `/redesign`'s refine loop only for `compose` surfaces and sent everything else
to verbs with no bar — so the quality machinery was present, correct, and unreachable in the common
case. This is the hardest class to see by reading one file, because each file is individually
right.

**Check**: list what this artifact *composes*, then list the conditions under which each dispatch
actually fires. A dispatch behind a rare condition is a dispatch that does not exist.

### 4. Does the seam with its sibling leak?

Two artifacts covering one domain will each assume the other owns the overlap. `/audit` ÷
`/ui-audit` is written down now (split by **evidence**, not by topic). The other pairs are not:

- `/optimize` ÷ `/audit` — both touch performance and architecture
- `/align` ÷ `/unify-surfaces` ÷ `/polish` — enforce vs consolidate vs introduce
- `/refactor` ÷ `/optimize` — one file vs whole project
- `/enhance-ui` ÷ `/redesign` ÷ `/art-direct` — the language-or-composition test decides two of
  these; the third boundary is not tested anywhere
- `design-system-guardian` ÷ `ux-reviewer` ÷ `ui-designer` — token violation vs usability floor vs
  craft; newly three-way as of 2026-09-19 and never exercised together

**Check**: name a finding that fits both. Who takes it, and what happens to a finding neither can
verify? If the answer is not "it is named in a ledger", it is dropped.

### 5. Is the role real, or is it a file?

The `ui-designer` gap was a **missing chair**, not a missing file: five agents that could each pass
a screen which is correct, conformant, usable and mediocre. Map the agents of each pack onto the
real team that does that work and look for the empty seat.

**Check per pack**: write the roster as roles, not filenames. Backend, database, security, devops
and testing have never been mapped this way.

## Scope, in the order worth doing

| # | Scope | Why here |
|---|---|---|
| 1 | ~~`/audit` — question 2~~ | **Done 2026-09-19.** Both audit commands now carry a bar |
| 2 | The 12 ui-ux artifacts as one system | Just changed substantially; the three-way agent seam is untested |
| 3 | The 16 global commands | Every project pays for them; `/optimize` ÷ `/audit` is the widest open seam |
| 4 | The other 22 packs' agent rosters — question 5 | Cheapest question, and the one that found the last real gap |
| 5 | The 118 skills — question 1 | A skill with no halt is the easiest thing to ship and the hardest to notice |

## How to run it, and how NOT to

**Run the artifact against a real repo before reading it.** Every defect above was invisible to
reading and obvious within minutes of running. Fixtures exercise shape; they do not exercise a
6,357-file monorepo with a Tailwind 3→4 migration in its history.

**Do not start by writing a gate.** Four of the five questions are judgements. A gate that could
answer them would have to understand intent, and a gate that *looks* like it answers them is worse
than none — it turns an open question into a green tick. Write a gate only where the review finds a
**mechanical** invariant, the way HALT #6 came out of the `/ui-audit` finding.

**Record what was NOT reviewed.** The review's own cell ledger. An artifact nobody opened must be
distinguishable from one that was opened and found clean — which is the same discipline `/audit`
Phase 2b already enforces on its findings, applied one level up.

## Current known-open list

Carry these into the review; each was found and deliberately not fixed on 2026-09-19.

1. **Neither Phase 1.5 has ever run.** `/audit`'s and `/ui-audit`'s bars are both unexercised —
   the next real run is the first test either gets, and the scoring step is exactly the kind of
   instruction a model satisfies cheaply if it can.
2. **`unify-component`'s boundary is documented in prose only.** `/ui-audit` V0 now dispatches
   `/unify-surfaces`, but nothing tests that the dispatch condition fires on a real repo with two
   competing wrappers.
3. **`design-score`'s anti-cheat is self-policed.** The skill instructs itself to reject a
   metrics-only scorecard. Nothing external verifies that a returned scorecard cites the image.
4. **`/ui-audit` has never completed a full run.** Its one observed run did nothing. Phase 1.5,
   HALT #6, the V0 dispatch and the refine-loop wiring are all **unexercised**; the next real run
   is the first test any of them will get.
5. **Seven pack probes named directories that could not exist** in one real target, five of them
   inside framework-conditional tables the check cannot read as conditional. Either the probes
   carry their condition machine-readably, or the check learns to skip a conditional table.
