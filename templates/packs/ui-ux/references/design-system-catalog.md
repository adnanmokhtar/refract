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

## What adoption actually runs

Adopting a system is not this file's job either. Once one is chosen:

- `/clone-design <reference>` — reproduce the language as framework-neutral HTML/CSS with the brand placeholdered, then `--adopt=tokens` to bring it in.
- `design-system-architect` — codify the adopted values into this project's token layers, at the ~30–50 semantic-token cap.
- `/redesign <surface> --from-canvas` — rebuild surfaces once the system is the project's system.

## Arabic / RTL projects

Every row above is LTR-first. Adopting one on an Arabic product means budgeting for: logical properties throughout, mirrored icons, a typeface that actually carries Arabic (most of these ship Latin-only defaults), and a type scale re-checked at Arabic's larger x-height and longer strings. See [`rtl.md`](../ai-patterns/rtl.md). This is the single most underestimated cost on this page.
