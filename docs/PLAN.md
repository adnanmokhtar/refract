# The plan — one plan

**Status: the DONE rows are built and pushed; everything else is a brief.** Written 2026-09-19,
merged from two separate plans that were about the same thing: Track A (is every artifact
honest?) and Track B (can the system design, not just execute?). Keeping them
apart was the mistake they both warn about — two documents covering one domain, each assuming the
other owned the overlap.

## What this is for

The goal is an **AI Product Design & Engineering Team** inside the repository: something that takes
a requirement and carries it through understanding → UX → design direction → design system →
implementation → render → visual inspection → UX / a11y / responsive review → regression → final
review, on any product type, holding one design language throughout.

The honest position on 2026-09-19: **most of the machinery for that exists.** What was missing was
not capability but *reachability and honesty* — the parts that judge quality were unreachable in
the common path, and the parts that reported success could do so having done nothing.

## Two tracks, one document

| Track | Question | Owner |
|---|---|---|
| **A — Honesty** | Does each artifact do what it claims, and can it report success without doing the work? | § Five questions |
| **B — Design intelligence** | Can the system design and judge, not just execute and enforce? | § The brief, § The gaps |

They are one plan because they keep producing the same finding from opposite directions: **five
times this week, machinery was present, correct, and never reached.** Track A finds it by asking
what a run can fake; Track B by asking what a capability would need. The same defect answers both.

## Done so far (2026-09-19)

| | |
|---|---|
| `/ui-audit` | new command — the design team in one run |
| Quality bar, both sides | `/audit` Phase 1.5 · `/ui-audit` Phase 1.5 — below bar is work even with zero findings |
| Proof of work | `/ui-audit` HALT #6 · both ledgers print `scored N / M` and block on N < M |
| Unit of analysis | view (route + tab + modal) on the visual side · variant (role, plan, flag, tenant-scope, failure path) on the code side |
| The missing chair | `ui-designer` agent + `design-score` skill |
| Scope tier in `/ui-audit` | a fix lands at its true home — token, wrapper or leaf — once |
| Dependency graph reached | blast radius and tier resolution read `.claude/_graph.json` instead of estimating |
| `PRODUCT_CONTEXT` | density, chrome and action norms per product type; the density lens is `NOT RUN` without it rather than graded against an implicit norm |
| Fingerprints | floating surface ("سايح") · control-size agreement, partitioned by control class |

---

# Track A — Honesty

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

---

# Track B — Design intelligence

## The brief, mapped against what ships today

| # | Brief | State | Where it lives |
|---|---|---|---|
| 1 | Code is rule-governed, design is not | **DONE** | Two commands, split by *evidence*: `/audit` (proof is a test/profile) ÷ `/ui-audit` (proof is a re-render). Seam written in `ui-audit.md § The boundary with /audit` |
| 2 | Design needs taste, not just rules | **PARTIAL** | Rubric + `ui-designer` judge craft. **No approved-reference anchor** — see Gap A |
| 3 | Per-project Design Direction | **PARTIAL** | `creative-director` *produces* a direction and `direction-vocabulary.md` enumerates the axes. **Nothing persists it** — see Gap B |
| 4 | Visual feedback loop | **DONE** | `visual-check` renders · `design-score` grades · `/redesign` refine loop (≤3 rounds, must beat its diagnosis) · `/ui-audit` Phase 8 re-renders every touched route |
| 5 | Screenshot analysis in the workflow | **DONE** | `design-score` halts without a render; `/ui-audit` HALT #6 blocks any verdict with no render + scorecard behind it |
| 6 | Visual reference library | **MISSING** | — see Gap A |
| 7 | Design system beyond components | **DONE** | Foundations + components + patterns live in `_extracted-idioms.md` §§ Tokens / Elevation / Wrappers / Surfaces / Breakpoints / Voice; `normalize-surface` carries a table-stakes catalog per composite surface |
| 8 | Context awareness (dense ERP ≠ dense storefront) | **MISSING** | `PROJECT_KIND` splits frontend/backend/mobile; nothing encodes *product context* norms — see Gap C |
| 9 | Multi-role team | **DONE** | UX architect → `ux-reviewer` · UI designer → `ui-designer` · design system → `design-system-architect` + `design-system-guardian` · visual QA → `design-score` + `visual-check` · a11y → `a11y-quick-check` + `ux-reviewer` · consistency → `/ui-sweep` Detector 4 · responsive → Detector 6 · regression → `/ui-audit` Phase 8 |
| 10 | Redesign must be system-wide, not local | **PARTIAL** | Scope-tier analysis (token / wrapper / leaf) exists — **in `/enhance-ui` and `/art-direct` only. `/ui-audit` never calls it** — see Gap D |
| 11 | Quality gates | **DONE** | Visual + UX + responsive + a11y + engineering + regression, all gated: rubric lenses, per-component `below-bar`, axe, Phase 8 drift in both directions |
| 12 | Engineering track kept separate | **DONE** | `/audit` — and it now carries a quality bar and per-variant resolution of its own |

---

## The three real gaps, and why each one matters

### Gap A — There is no approved-reference library

**The brief's point 6, and the one that limits point 2.**

Every judgement the system makes today is against a **rubric** — an abstract description of what
good looks like. A rubric tells you a page lacks hierarchy. It cannot tell you *what this product's
good looks like*, because it has never seen it.

This is the difference between a reviewer who knows the house style and one who has only read the
style guide. The second one is what ships now.

**What it needs to be** — and the shape matters more than the volume:

```
ai/design/reference/
  approved/<surface-type>/<name>.png   + .md   what makes it right, cited to elements
  rejected/<name>.png                  + .md   what made it wrong, and what replaced it
  pairs/<name>.before.png / .after.png + .md   the delta, named — the highest-value form
  decisions/<NNNN>-<slug>.md                   a design call and the reasoning that survived it
```

**The pairs are the valuable part.** An approved screenshot says *this is fine*; a before/after pair
says *this specific change is what fine looks like*, which is the only form a grader can reason
from. Every pair produced by a `/ui-audit` V2 rebuild is free — the run already renders both sides
and already has the diagnosis that connects them. **Capturing them is a handful of lines in Phase 8;
the library then builds itself from real work rather than needing to be authored.**

Consumers, once it exists: `design-score` gains a lens — *does this resemble the approved direction?*
— that is answerable rather than aspirational; `ui-designer` cites a pair instead of a principle;
`/redesign`'s refine loop gets a target rather than a ceiling.

### Gap B — The Design Direction is produced and then thrown away

`creative-director` decides the visual language, scores three candidates on a nine-lens rubric and
writes an Art-Direction Brief. `/art-direct` then hands the winner to `design-system-architect`,
which codifies the **tokens**.

Tokens are the *measurable residue* of a direction. They are not the direction. Nothing persists:

- the register — enterprise or consumer, formal or friendly
- the density intent — dense or spacious, and *what counts as too much here*
- the shape language — sharp or rounded, and at what radius, and why
- elevation intent — flat, or layered, and how far
- what this product deliberately does **not** do

So the next run reads tokens and re-derives intent from them, which is reading the fingerprints and
guessing the hand. Two runs a month apart can codify the same tokens into two different feelings and
neither is wrong by any check that exists.

**What it needs**: `ai/design/direction.md` — authored once by `creative-director`, read by every
command that grades or builds, and **cited by `design-score` when a lens verdict turns on intent
rather than on a measurement**. It is the artifact that makes "modern" mean something in this repo.

### Gap C — No product-context norms

The brief's point 8, and correct: a dense table is right in an ERP and wrong in a storefront. Today
`PROJECT_KIND` distinguishes `frontend-*` from `backend-*` from `mobile-*` — a *stack* axis. Nothing
distinguishes **admin panel ÷ storefront ÷ landing page ÷ dashboard ÷ customer portal**, which is
the axis that decides what density, how much chrome, how much whitespace, how much copy.

Without it every density judgement is made against one implicit norm, and one of those two products
is always being graded by the other's standard.

**Smallest useful form**: a `PRODUCT_CONTEXT` resolved once into `_extracted-idioms.md`, with a
per-context norm table (information density, chrome budget, copy length, action count per screen)
that `design-score` reads before grading density and `ui-designer` reads before proposing. This is
the cheapest of the three gaps and unblocks the most false findings.

### Gap D — `/ui-audit` routes around the impact analysis that already exists — **DONE 2026-09-19**

The brief's point 10. `/enhance-ui` opens with scope-tier detection: is this fix a **token**, a
**shared wrapper variant**, or a **single leaf**? That is exactly the *"is the table footer this page
or the shared Table component?"* question, and it was implemented, correct, and unreachable from
`/ui-audit` — whose V2 dispatched `/redesign` per surface with no tier question asked.

The same defect class as three others this week: machinery present, correct, and never reached in
the common path. **Fixed**: V2 now resolves the tier before building, and a proposal whose true home
is a token or a shared wrapper is applied there once, not re-applied per page.

---

## Build order

Sequenced by *what unblocks what*, not by size.

| # | Build | Why here | Cost |
|---|---|---|---|
| 1 | **Gap C — `PRODUCT_CONTEXT` + norm table** | Cheapest, and every density finding is wrong without it. Blocks nothing else, unblocks accuracy everywhere | small |
| 2 | **Gap B — `ai/design/direction.md`** | Must exist before the reference library means anything: a pair is only readable against a stated intent | small |
| 3 | **Gap A.1 — capture pairs in Phase 8** | Nearly free — the run already renders both sides and holds the diagnosis. Start the library accumulating before anything consumes it | small |
| 4 | **Gap A.2 — consume the library** | `design-score` gains the resemblance lens; `ui-designer` cites pairs. Only worth doing once ~10 pairs exist | medium |
| 5 | **Engineering track** | `/audit` already has the bar and per-variant resolution; the rest is the pack-wide review in Track A | see Track A |

**Do 1–3 before 4.** The library's value is entirely in what it accumulates; consuming an empty one
adds a lens that always answers "no reference available" and teaches the run to ignore it.

---

## The brief expanded to nineteen points (2026-09-19, second pass)

Re-checked against what ships. Roughly twelve of the nineteen exist or are partial; **four are
genuinely new capabilities**, and one more turned out to be the fifth instance this week of
machinery that is built, correct, and never reached.

### Already covered by the twelve-point map above

Design Intelligence breadth (1) · designing before coding (2) · taste as principles + references +
feedback (3) · design system architect (4) · design-to-code with visual fidelity (6) · anti-drift
(7, = `/ui-sweep` Detector 4 + `design-system-guardian` + the V0 `/unify-surfaces` dispatch) ·
visual feedback loop (8) · self-improvement with root-cause routing (12, = the scope tier, now
wired into V2) · engineering track (15) · product builder (17, = `/scaffold-project` chaining) ·
product types (18, = the `PRODUCT_CONTEXT` gap already named as Gap C) · definition of done (19,
= the quality gates).

### Gap E — Repository-wide intelligence is built and unreached (point 16)

`scripts/build-graph.py` produces a real dependency graph — **4,640 nodes and 17,006 edges** on the
reference app, from 6,357 source files. It answers exactly what point 16 asks: where does this
component live, where is it used, is there a duplicate, what pages are affected.

**No ui-ux artifact reads it.** Not `/ui-audit`, not `/enhance-ui`, not the scope-tier resolution
that most needs it — the tier question *"is this a token, a wrapper, or a leaf?"* is answered today
by reading `§ Wrappers` and counting consumers by hand, while a graph that already knows the answer
sits in `.claude/_graph.json`.

This is the fifth occurrence of one pattern this week (the refine loop, `/unify-surfaces`, the
anchor repairer, the scope tier, now the graph). It is cheap to close and it makes Gap D's tier
resolution exact instead of estimated.

### Gap F — Component Laboratory (point 10)

Storybook is *mentioned* in three pack files as a stack signal; there is no workflow that uses it.
Nothing renders a component in isolation across its states — default / hover / disabled / loading /
long text / RTL / empty / one row / a hundred rows / error / mobile.

**Why it matters more than it sounds**: every grading surface today is a *page*, so a component is
only ever seen in the one state that page happened to put it in. A table that is fine with eight
rows and collapses at two hundred, a button whose label wraps in Arabic, a modal that scrolls its
own header away on a phone — none of these are reachable from a route render, and all of them are
what "it looks unfinished" turns out to mean.

### Gap G — Review levels above the page (point 11)

The scored unit is now the **view** (route + tab/modal). Flow-level exists as `/ui-sweep`'s phasing.
**Nothing reviews the application or the product as a whole**: good components can make a bad page,
and good pages can make a bad flow — and good flows can still make a product that feels like three
products, which is exactly the multi-portal complaint that started this.

Levels 1–4 exist (component via Gap F, group, page, flow). Levels 5–6 do not.

### Gap H — Design Memory, including what was REJECTED (point 13)

Gap B covers persisting the chosen direction. Point 13 adds the half that matters more: **the
rejected ones, and why.** The engineering side already has this — `templates/decision-engine.md`
carries a failure catalogue and a tie-break rule: a proposed approach matching a known failure must
surface it and require an explicit override. **Design has no equivalent.** So a direction rejected in
March is re-proposed in September with the same confidence, and nothing in the repo can say it was
already tried.

### Gap I — Design Governance (point 14)

`/audit` reasons about blast radius for code. A token change has no equivalent: changing a button
radius affects N components across M pages, may have sanctioned exceptions, and may or may not agree
with the stated direction. Today that change is made and the visual baseline reports the diff
afterwards. Governance is asking **before**.

---

## Revised build order

Ordered by `unblocks × cheapness`, not by importance.

| # | Build | Why here |
|---|---|---|
| 1 | **Gap E — read the graph** | Built already; makes Gap D's tier resolution exact rather than estimated. Cheapest real win on the list |
| 2 | **Gap C — `PRODUCT_CONTEXT`** | Every density judgement is currently graded against one implicit norm |
| 3 | **Gap B + H — `ai/design/direction.md` incl. rejections** | One artifact serves both; the rejection half reuses the engineering failure-catalogue pattern rather than inventing one |
| 4 | **Gap A.1 — capture before/after pairs in Phase 8** | Nearly free; the library accumulates from real work |
| 5 | **Gap F — Component Laboratory** | The largest genuinely-new capability, and the one that finds what page renders cannot |
| 6 | **Gap A.2 — consume the library** · **Gap I — governance** | Both need ≥10 pairs / a stated direction to mean anything |
| 7 | **Gap G — app and product level review** | Last, because it is a roll-up of everything above and is meaningless until the levels below it are real |

---

## The honest caveat, carried from Track A

Everything above is written against machinery that **has never completed a real run.** `/ui-audit`'s
one observed execution rendered nothing and reported every page clean. Phase 1.4, Phase 1.5, HALT #6,
the `/unify-surfaces` dispatch and the scope-tier resolution are all unexercised.

**The first real run on a real app is worth more than the next three items on this list.** Every
defect found this week was invisible to reading and obvious within minutes of running — and the
scoring step in particular is exactly the kind of instruction a model satisfies cheaply if nothing
stops it.

Build 1–3 if they are cheap. Run the thing first.
