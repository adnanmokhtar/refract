---
name: design-systems
description: Pattern: Design System
kind: ai-pattern
pack: ui-ux
---

# Pattern: Design System

> **Hard rule** — Feature code consumes **semantic** tokens and shared primitives only: never a raw hex / px / font literal, and never a *primitive* token (`--blue-500`) where a semantic one (`--color-brand`) exists. A new primitive, a new token, or a documented deviation is a system-level change with a named owner — not a line in a feature PR.

**The failure this prevents:** not "ugly UI". It is the **fork**. One sprint someone needs a button the shared one doesn't do, copies it into their feature folder, and tweaks it. Nothing breaks. Six months later there are four Buttons, the a11y fix lands in one of them, the dark-theme values land in two, and the "design system" is a folder nobody trusts enough to import. Every rule below exists to make that copy expensive at the moment it is made, instead of cheap now and unpayable later.

**This pattern is the CONSUMER side** — what feature code must obey and what a reviewer checks. The *producer* side (token-layer design, when a primitive earns promotion, the alias/migration plan) is owned by the `design-system-architect` agent; the closure verbs that fix a violation are `ui-design-sweep`.

**When to apply**
- Multiple apps / squads share UI surface and drift is visible across PRs.
- A component catalog exists (or lands in the same milestone) — Storybook, Ladle, Histoire, or the framework's equivalent.
- The token layer can be enforced in CI. Without enforcement this is a wish, not a system.

**When NOT to apply**
- Single-screen prototype thrown away within the quarter.
- Pre-PMF product where component shapes still change weekly — premature freezing wastes effort, and a system frozen around the wrong shapes is worse than none.
- No CI to enforce the rules — undocumented governance becomes folklore in three months. Ship the lint rule *with* the system or don't claim one.

**Halt conditions / mandatory cites**
- Cite the token source-of-truth file as `<path:line>` (e.g. `packages/design-system/tokens.ts:12`) before adding a new component; if missing, halt and create it.
- Cite at least one existing primitive's catalog entry as `<path:line>` proving the variant + a11y contract is established; do not propose a new primitive without that precedent.
- Cite the **enforcement rule that is actually configured in this repo** as `<path:line>` (see § Enforcement for what qualifies). "We'll add lint later" is a halt — but so is citing a plugin the repo does not install. Name the rule, not a tool that sounds plausible.
- Cite the ADR governing the system's scope (`ai/decisions/<n>-design-system.md`) before declaring a token deprecated; never sweep tokens without an ADR link.
- Hand-wave grep ban — never claim "components don't use raw hex" without a cited grep result file or CI rule path.

## The one question a feature PR must answer

**"Does this belong in the system, or in my feature?"** The test is mechanical, not aesthetic:

| Signal | Verdict |
|---|---|
| **≥ 2 unrelated consumers** would use it (different features, not two screens of one flow) | System. Promote it — `design-system-architect` owns the promotion. |
| One consumer, and you can name the *product* reason it differs | Local. Compose system primitives; leave a comment saying why. |
| One consumer, and the reason is "the shared one looked slightly off here" | **This is the fork.** Fix the shared one (or add a variant); never copy it. |
| It needs a value that has no token | A **request for a token**, routed to the architect — not a licence to inline a literal. |

## Layers — and the rule about skipping them

```
Tokens        — the values (color, spacing, type, radius, shadow, motion)
    ↓
Primitives    — styled building blocks (Button, Input, Badge)
    ↓
Patterns      — composed UI (Card, Modal, Form, Table, DataGrid)
    ↓
Templates     — page layouts (Dashboard, Auth, List, Detail)
    ↓
Screens       — actual pages (ProductList, OrderDetail)
```

**Don't skip a layer.** A "Card" built from raw `<div>`s and magic spacing bypasses the system: it inherits neither the next theme, nor the next density change, nor the next a11y fix. The tell is a screen file that contains colour or spacing literals at all.

**Within Tokens there are three sub-layers, and feature code may only touch one.** `--blue-500` (primitive ramp) → `--color-brand` (semantic role) → `--button-bg` (component). Feature code references **semantic**. Referencing a primitive directly hardcodes the value under a nicer name and blocks re-theming. The layer design and the ~30–50 semantic-token ceiling belong to `design-system-architect`.

## Component contract (what "in the system" obliges)

A component that lives in the system carries **all** of:

- **Typed props**, with an API that does not leak implementation (no utility-class strings as props, no `style` passthrough as the extension mechanism).
- **Variants** — size, intent, and the full state set. The states routinely missing are **disabled, loading, focus-visible**; a primitive without them pushes every consumer to reinvent them locally — the fork again.
- **Slots** — the sanctioned extension point. If consumers reach past the API, the slot set is wrong.
- **A11y built in** — keyboard model, focus ring, roles/labels. Accessibility applied per call site is wrong at half the call sites.
- **A catalog entry** covering every variant *and* the loading / error / empty / RTL renders.

## Single source of truth

One package or folder owns the system and every app imports from it. The shape matters less than the invariant: **there is exactly one place a component can be defined, and feature folders are not it.**

## Enforcement (this is what makes it a system rather than a preference)

Governance that lives only in a doc decays. Wire at least one of these and cite it by path:

- **stylelint** `declaration-property-value-allowed-list` restricting colour properties to `var(--*)` and spacing/radius to the token set — the highest-value single rule.
- **ESLint** `no-restricted-syntax` rejecting literal colour/spacing in `style={{…}}` / `:style` bindings, where stylelint cannot see.
- **Utility-framework theme config** — restricting the theme IS the enforcement; an arbitrary value then fails review as an off-theme escape, not a matter of taste.
- **A CI grep with a committed allowlist** — crude fallback, but a failing build beats a convention.

Do **not** cite a plugin the repo does not install; a halt that can only be cleared by an absent package stops work instead of improving it.

## Forbidden

- Magic pixel values in components (`margin-top: 13px`).
- Hex / rgb literals inline (`color: #3366ff`) — including inside a chart config that *could* read a resolved token.
- Primitive tokens (`--blue-500`) in feature code where a semantic role exists.
- Inline font families.
- Rebuilding a system component per feature ("quick one-off Button").
- Custom spacing that doesn't fit the scale.
- Component APIs that leak implementation (utility-class strings as props).
- Declaring the system "adopted" with no enforcement rule in CI.
