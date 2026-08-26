---
name: direction-vocabulary
description: "Pattern: the enumerated positions on the four STRUCTURAL divergence axes — IA archetype, grid logic, shape language, density register — that make creative-director's divergence check generative instead of hopeful"
kind: ai-pattern
pack: ui-ux
---

# Pattern: Direction vocabulary (the structural divergence axes, enumerated)

> **Hard rule** — Divergence lives in STRUCTURE, never in paint. `creative-director`'s divergence check requires each pair of directions to differ on **≥2 of four structural axes**; this file enumerates the positions those axes can take. A direction names its position on each axis explicitly, or the check has nothing to compare. Type, colour and motion are **expressive registers, not divergence axes** — two directions identical in structure and different in palette collapse under the colour-ramp-swap test, by design.

**The failure this prevents:** an agent asked for "three different directions" regresses to the mean and produces one idea in three tints — clean-modern-minimal in blue, in green, and in warm neutral. `creative-director` already *detects* that (the colour-ramp-swap test plus the ≥2-structural-axes rule), but detection without vocabulary means the regenerate-and-retry loop keeps drawing from the same exhausted well. The positions below are the well. They are structural, project-agnostic, and deliberately NOT a style catalogue: a named position tells you how the screen is ORGANIZED, never what it looks like, so using one cannot produce the `borrowed-skin / derivative` diagnosis that a style catalogue reliably does.

**When to apply**
- `creative-director` § 3 (Diverge) — pick a position per axis per direction, before writing any concept prose.
- `/art-direct` — when a direction fails the divergence check and must regenerate from an unused cluster, this is where "unused" is defined.
- `/redesign` — when a page's IA archetype is being chosen for the rebuild.

**When NOT to apply**
- Choosing a palette, typeface or motion curve. Those are registers; see § Registers are not axes.
- Enforcing the usability floor. That is [`axis-catalog.md`](axis-catalog.md) — a completely different sense of the word "axis", and conflating the two is the most common misread of this pack.

**Halt conditions / mandatory cites**
- A direction that does not name its position on all four axes — halt. An unnamed position cannot be compared, so the divergence check silently passes.
- Two directions sharing a position on 3+ of the four axes — halt; they have collapsed regardless of how different the palettes look.
- A position chosen with no stated JOB it serves — halt. The archetype follows from the screen's verb; picking one because it is unused is novelty, and `creative-director` halts on undisciplined-invention.
- Inventing a position not listed here **without** naming its job, its failure mode and the case where it does NOT fit — halt. This is an OPEN vocabulary (unlike the 16-axis floor), but an addition owes the same three columns as every row below.

## How this feeds the divergence check

`creative-director`'s check is two-part: (a) the **colour-ramp-swap** test — swapping any direction's palette must not make it indistinguishable from another — and (b) each pair differs on **≥2** of the four structural axes. This file supplies (b)'s comparable values.

The working method: pick the axis positions FIRST, then write the concept sentence that explains why those positions serve this product's promise. Concept-first still holds — the concept comes from goals and personas — but the structure is chosen consciously rather than defaulted into.

## Axis 1 — IA archetype (how the screen ranks the task)

The layout archetype the screen's primary verb demands. Task ranking made structurally visible.

| Archetype | The verb it serves | What it does structurally | Its failure mode | Does NOT fit |
|---|---|---|---|---|
| **compare-grid** | *choose between* | Peer items in a uniform lattice; differences aligned on a shared axis so the eye scans one attribute across all | Everything peer-ranked, so nothing is recommended | A set of one, or a decision with a clear default |
| **triage-stream** | *work through* | Ordered queue, newest or most-urgent first, each row carrying its own resolve action | Infinite scroll with no sense of done | Reference material nobody works through |
| **focus-canvas** | *make* | One object fills the frame, tools recede to the edges, chrome collapses while working | Discoverability dies with the chrome | Tasks that are decided, not made |
| **guided-flow** | *complete* | One decision per step, progress visible, back always safe | Steps for a task the user could do in one screen | Expert users repeating a known path |
| **dashboard-of-one-number** | *check* | A single number owns the frame; everything else is its explanation | The one number is not the one that matters | Surfaces with several equal owners |
| **split-context** | *cross-reference* | Persistent list beside persistent detail; selection drives the pane without navigation | Both panes too narrow to be usable | Small screens, and single-item tasks |
| **layered-drill** | *investigate* | Summary that opens progressively deeper without losing the parent | Depth becomes a maze with no orientation | Flat data with no natural hierarchy |
| **canvas-of-relations** | *understand structure* | Position and connection encode meaning; a graph, board or map, not a list | Spatial freedom becomes spatial chaos | Ordered data where a list is simply better |
| **command-surface** | *act fast* | Keyboard-first entry point ranks actions; the UI is a fallback for discovery | Unusable for anyone who has not learned it | Occasional users and touch-primary contexts |
| **narrative-scroll** | *be convinced* | Vertical sequence paced as an argument, each section one beat | Applied to a working tool, where it is friction | Anything a user returns to daily |

## Axis 2 — Grid / layout logic (how space is organised)

| Logic | What it produces | Its failure mode | Does NOT fit |
|---|---|---|---|
| **strict-column** | Predictable, dense, engineered; everything snaps to the same columns | Monotony; no natural emphasis | Content that needs a hierarchy of scale |
| **editorial-asymmetric** | Deliberate imbalance; one dominant field against a narrow counterweight | Reads as a mistake if the imbalance is not decisive | Dense operational surfaces |
| **modular-card** | Independent units, reorderable, each self-contained | Everything becomes a card; the page loses a spine | Content with a single continuous reading order |
| **baseline-locked** | Every element sits on a shared vertical rhythm; typographic precision | Rigid under mixed content and long translations | Media-heavy or user-generated layouts |
| **canvas-free** | Position carries meaning; no grid to snap to | No fallback structure when the freedom is unused | Anything that must reflow to 320px |
| **rail-and-body** | Persistent navigational rail against a scrolling body | The rail accretes until it is the interface | Single-surface tools with no navigation |
| **centred-measure** | One column at reading measure, everything else subordinate | Wastes the viewport on wide screens | Comparison and operational density |

## Axis 3 — Shape language (the recurring geometric decision)

| Language | The recurring decision | Its failure mode | Does NOT fit |
|---|---|---|---|
| **keyline** | Depth comes from hairline borders; no shadows at all | Flat and cold if contrast is not carefully held | Interfaces needing strong z-ordering |
| **soft-elevation** | Layered shadow scale carries hierarchy; radii generous | Everything floats; nothing is ground | Print-adjacent and high-density surfaces |
| **hard-geometric** | Zero or near-zero radii, right angles, structural corners | Reads as unfinished or brutal without deliberate restraint | Consumer surfaces courting warmth |
| **pill-and-round** | Fully rounded controls, capsule affordances | Toy-like at scale; wastes horizontal space | Data-dense and professional registers |
| **inset-panel** | Recessed wells group content; grouping by depression not elevation | Reads dated fast — the classic era-tell | Anything chasing a current register |
| **rule-and-band** | Full-bleed horizontal rules and colour bands segment the page | Banding becomes stripes; rhythm turns to noise | Modular and card-based compositions |

## Axis 4 — Density register & signature interaction

The pack's fourth structural axis bundles two decisions that always move together.

**Density register** — keyed to persona frequency and expertise, set as a RULE per surface type, never a constant.

| Register | Row / control rhythm | Serves | Its failure mode |
|---|---|---|---|
| **compact** | Tight; maximum information per viewport | Daily operators, expert users, triage work | Punishing for occasional users; tap targets fight the floor |
| **cozy** | Balanced; the safe middle | Mixed-frequency products | The default nobody chose — reads as tasteful-beige |
| **comfortable** | Generous; whitespace as a signal of calm | Occasional users, consumer surfaces, onboarding | Scrolling replaces scanning on real data volumes |
| **editorial** | Long measure, wide leading, deliberate pacing | Reading and persuasion | Any surface where the user is working, not reading |

**Signature interaction** — one or two ownable moves that collapse a job step. Each names the success proxy it moves plus its responsive, RTL and reduced-motion behaviour.

| Move | The job step it collapses | Its failure mode |
|---|---|---|
| **inline bulk-resolve** | Navigating away to act on many items | Destructive actions one mis-click away |
| **command-palette-first** | Hunting through navigation for a known action | Invisible to anyone who has not learned it |
| **progressive-reveal canvas** | Loading a full editor for a small edit | State lost when the reveal collapses |
| **optimistic-commit-with-undo** | Waiting on a round trip to see the result | A failed commit that silently reverts |
| **inline-compare pin** | Losing the reference item while browsing | Pins accumulate into a second, unmanaged list |
| **live-filter-as-you-type** | Submitting a query to learn it was wrong | Thrash on large sets; results shifting under the cursor |
| **contextual-peek** | Full navigation to confirm one detail | Peek becomes the interface; the real page never loads |

## Registers are not axes

Type personality, colour concept and motion personality are **expressive registers**. A direction owes all three — they are on the ten-part mini-brief — but they do **not** count toward the ≥2-structural-axes requirement, because the colour-ramp-swap test exists precisely to strip them out. Two directions differing only in register are one direction.

- **Type class** — geometric · humanist · grotesk · mono · serif · slab. A class, never a brand-locked family.
- **Colour concept** — ink + one signal · duotone · saturated mono · neutral-with-earned-accent · full-spectrum-categorical.
- **Motion personality** — crisp-mechanical · soft-organic · editorial-cut · minimal-functional.

Registers still carry the concept, and a mismatch between register and structure is an `off-concept drift` finding. They just cannot be the *reason* two directions are called different.

## Common mistakes

- **Treating this as a style catalogue.** These are organisational positions, not looks. "Pick `editorial-asymmetric` and make it look like that famous site" is `borrowed-skin / derivative` — the diagnosis, not the method.
- **Confusing these axes with the 16.** [`axis-catalog.md`](axis-catalog.md)'s axes are the usability FLOOR — a closed set that never grows. These four are the divergence axes, and this vocabulary is deliberately open.
- **Picking an unused position because it is unused.** Novelty with no job is `undisciplined-invention`; the archetype descends from the screen's verb.
- **Naming a position and not building it.** A direction that says `triage-stream` and renders a compare-grid has not diverged; it has mislabelled.
- **Diverging on all four axes every time.** Two is the floor, not the target. Four-way divergence across three directions usually means one of them is not serving any real job.
- **Letting the density register do the structural work.** Compact-versus-comfortable is a real difference, but on its own it is one axis; it needs a partner.

## Cross-references

- `creative-director` (agent) § 3 Diverge + § the divergence check invariant — the consumer this file supplies values to.
- `/art-direct` — enforces the divergence check operationally before the build.
- `/redesign` — builds the page inside the chosen archetype.
- [`axis-catalog.md`](axis-catalog.md) — the usability floor. A different meaning of "axis"; read the distinction above before filing anything.
- [`motion.md`](motion.md) § The duration scale — motion personalities resolve to durations there, never to numbers invented here.
