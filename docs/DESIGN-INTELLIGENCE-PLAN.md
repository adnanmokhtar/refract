# Design Intelligence — what exists, what is missing, what to build

**Status: PLAN. Nothing here is built except where marked DONE.** Written 2026-09-19 against a
twelve-point brief whose goal is an AI design-and-engineering *team* rather than a set of task
runners.

The useful finding up front: **most of the brief already exists.** Seven of the twelve points are
implemented, two are partial, and **three are genuinely absent** — and one of those three is why
the existing machinery keeps feeling thinner than it is.

---

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
| 5 | **Engineering track** | `/audit` already has the bar and per-variant resolution; the rest is the pack-wide review in `REVIEW-PLAN.md` | see that file |

**Do 1–3 before 4.** The library's value is entirely in what it accumulates; consuming an empty one
adds a lens that always answers "no reference available" and teaches the run to ignore it.

---

## The honest caveat, carried from `REVIEW-PLAN.md`

Everything above is written against machinery that **has never completed a real run.** `/ui-audit`'s
one observed execution rendered nothing and reported every page clean. Phase 1.4, Phase 1.5, HALT #6,
the `/unify-surfaces` dispatch and the scope-tier resolution are all unexercised.

**The first real run on a real app is worth more than the next three items on this list.** Every
defect found this week was invisible to reading and obvious within minutes of running — and the
scoring step in particular is exactly the kind of instruction a model satisfies cheaply if nothing
stops it.

Build 1–3 if they are cheap. Run the thing first.
