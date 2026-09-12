# Open design systems — adoption starting points

> **What this is**: published, documented design systems a project can **adopt** as its starting point instead of inventing one. Consulted by `/design-first` on the `independent` + "show me options" path, and by `/clone-design` when the reference given is a system rather than a site.
>
> **What this is NOT**: a style menu for `/art-direct`. See § The boundary.

## The boundary — why this file can exist beside `direction-vocabulary.md`

[`direction-vocabulary.md`](../ai-patterns/direction-vocabulary.md) is explicit that it is *"deliberately NOT a style catalogue"*, because picking a look off a menu produces the **borrowed-skin / derivative** diagnosis. That rule governs `/art-direct`'s divergence check, and it still stands: when a run claims to have **invented** three directions, it may not have shopped for them.

Adopting a documented system is a different act, and an honest one. You are not claiming invention — you are choosing to stand on a system someone else maintains, with its tokens, its component anatomy, its a11y work and its documentation. The borrowed-skin diagnosis does not apply because nothing is being passed off as original.

So: **this file is consulted when the user is choosing what to adopt, never when a direction is being invented.** A run that reaches for it to fill `/art-direct`'s three directions is misusing it, and `creative-director`'s divergence check is what catches that.

## Before adopting any row below

- **Check the licence yourself, at the source, today.** Licences change, and the components, the documentation, the icons and the *fonts* are frequently licensed differently from each other — a permissive component library shipping a proprietary typeface is the common shape. Do not take this file's word for it; it is a pointer, not legal advice.
- **Check the platform.** Most of these are web-first. A Flutter or React-Native project adopting a web system inherits its *language* (scale, rhythm, colour logic, component anatomy) but not its code.
- **Adopting is a commitment.** The system's upgrade cadence becomes yours, and its opinions become arguments you will have later. That is usually still cheaper than maintaining an invented system, which is the honest case for this path.

## The catalog

| System | Shape | Reads as | Adopt when |
|---|---|---|---|
| **Material Design 3** | full spec + component libraries, several platforms | Google-era, systematic, dynamic colour | you want the most documented system that exists, and a look people recognize as "Android/Google" is acceptable or wanted |
| **shadcn/ui** | copy-in components over Radix + Tailwind, not a dependency | restrained, neutral, current | you want to **own** the code from day one and restyle freely — the least lock-in on this list |
| **Radix Themes** | React components + a token system | quiet, accessible, unopinionated | accessibility primitives matter more than a distinctive look |
| **IBM Carbon** | full system, tokens, guidance, several platforms | enterprise, dense, engineered | data-heavy internal tools where density beats warmth |
| **Microsoft Fluent** | full system, several platforms | Microsoft-era, soft, familiar | the product lives beside Microsoft surfaces |
| **GitHub Primer** | system + React/CSS components | developer-tool register, functional | you are building a developer tool and want its conventions |
| **Ant Design** | very large component set, React | dense, form-heavy, enterprise | admin/back-office with many tables and forms, and you want the component count |
| **Chakra UI** | component library with a theme layer | friendly, rounded, approachable | you want speed and theming more than a strong identity |

**Reading the "Reads as" column honestly**: every row on this list is *recognizable*. Adopting one means your product will read as built on it, at least until you have restyled it substantially. If being unmistakably yours is the goal, this path is the wrong one and `/art-direct --reimagine` is the right one — and that is a real trade, not a formality.

## Showing them, instead of listing them

A table of eight names is not a choice anyone can make. "Enterprise, dense, engineered" tells you nothing you can picture, and picking a design system from adjectives is how a project ends up six weeks into a system that felt wrong on first sight of a real screen.

**So draw them.** Shortlist 3–4 rows with the user, then dispatch [`design-canvas`](../skills/design-canvas/SKILL.md) at `$SOURCE=independent`, `$FIDELITY=hifi`, to put **the same screen** — one of theirs, with their real content — on one artboard per candidate, side by side on one canvas. Same screen, same copy, same data: the only variable is the system. That is a comparison; three different screens in three different systems is a slideshow.

### The honesty problem this creates, and how it is handled

`design-canvas` **halts** on recreating a look from memory rather than from source, and that halt is correct — it is what stops a confident, plausible, wrong reproduction of an app. A sample artboard drawn from familiarity with Material or shadcn is exactly that shape of thing, and the halt has to be respected, not waived because this file asked for it.

So the sample artboards are **characterizations, not reproductions**, and three rules keep them honest:

1. **Draw from the system's published values**, fetched or read at draw time — its documented type scale, spacing scale, radii, elevation and semantic colour roles. Not from recollection of apps that use it.
2. **Label every sample artboard on the artboard itself**: *"characterization of <system> for comparison — not a reproduction"*. The label is part of the design, not a footnote in the handover, because the canvas outlives the conversation and gets forwarded without it.
3. **Nothing here is adoption.** The sample exists to make a choice; `/clone-design` then reproduces the chosen system's language for real, and its success metric is **fidelity measured from pixels**, not taste. A sample that gets built from is a misuse of both files.

Where the published values cannot be read this run, draw fewer candidates rather than filling the gap from memory, and say which ones you dropped and why.

### What the samples must show

The screen they compare on is the user's, and it carries what actually differentiates these systems in practice — not a hero and a button:

- a **dense** region (a table row, a list item, a form row) — density register is the axis these systems differ on most and the one adjectives hide
- at least one **input** in its rest and error states — control anatomy, and where non-text contrast usually fails
- a **status** signal — colour semantics, and whether the system gives you enough of them
- the app's **real longest string**, in the app's real locale — see § Arabic / RTL projects, which is where a Latin-first system stops looking neutral

## What adoption actually runs

Adopting a system is not this file's job either. Once one is chosen:

- `/clone-design <reference>` — reproduce the language as framework-neutral HTML/CSS with the brand placeholdered, then `--adopt=tokens` to bring it in.
- `design-system-architect` — codify the adopted values into this project's token layers, at the ~30–50 semantic-token cap.
- `/redesign <surface> --from-canvas` — rebuild surfaces once the system is the project's system.

## Arabic / RTL projects

Every row above is LTR-first. Adopting one on an Arabic product means budgeting for: logical properties throughout, mirrored icons, a typeface that actually carries Arabic (most of these ship Latin-only defaults), and a type scale re-checked at Arabic's larger x-height and longer strings. See [`rtl.md`](../ai-patterns/rtl.md). This is the single most underestimated cost on this page.
