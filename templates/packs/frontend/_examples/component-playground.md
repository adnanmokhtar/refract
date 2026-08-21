---
name: component-playground
description: Mount one shared component on an isolated, dev-gated route with knob-style controls generated from its real prop declarations, so edge cases can be probed without touching a real page (Storybook-lite). Framework-adaptive — Vue / React / Svelte / Angular. Invoke on "test this component in isolation", "play with props", "see what X looks like with Y". Do NOT invoke when the repo already has Storybook / Histoire / Ladle or any *.stories.* file — write a story there instead; a second explorer is the anti-pattern. Not for a component already mounted in a real page (that is verify-with-playwright) and not for regression baselines (visual-check).
kind: example
pack: frontend
---

# component-playground

Mounts ONE shared component on an isolated, dev-gated route with knob-style controls built from its **real** prop declarations. Storybook-lite — no dependency, disposable.

## Premise

**Probe the component in isolation, in the project's own stack — never impose a framework or UI kit the repo doesn't use.** The playground must be built from the component's real prop/emit declarations (read them, don't guess) and wired with the project's own shared input components and router. A playground that hard-codes a different framework's controls is worse than none. Cite the component's actual props at `<file:line>` when generating controls.

## Prior art wins (step 0, mandatory)

`ls .storybook histoire.config.* .ladle` and look for any `*.stories.*`. **Any hit → HALT and write a story instead.** A parallel `_playground/` route beside an existing Storybook creates two places to look at the same component, and the one nobody wires into CI rots first. Name the file you found when you halt.

## Adapt to the codebase

Read props from `defineProps<{}>()` (Vue) / the props type (React) / `$props()` (Svelte) / `input()` signals (Angular). Map by type: `boolean` → switch, `string` → text, `number` → number, union → select, object/array → JSON textarea — using the project's own shared inputs, not a foreign UI kit. Log every emit/event to a visible list.

## Steps

0. Prior-art check (above).
1. Read `$COMPONENT` and extract the real props + emits — cite them at `<file:line>`; never invent a control.
2. Generate the playground page (bindings object + one control per prop + event log).
3. Register the route, dev-gated (`import.meta.env.DEV` / `process.env.NODE_ENV !== 'production'`).
4. Run `visual-check` on it, drive one interaction, assert one accessible name.
5. Share the URL.

## Output

```
component-playground — StatusChip
Prior art:   none found
Source:      src/components/orders/StatusChip.vue:12-28 (6 props, 2 emits)
Controls:    variant (select) · label (text) · dense (switch) · count (number)
Route:       /_playground/status-chip   (dev-gated)
Render:      visual-check PASS — 1 interaction, accessible name asserted
```

## Failure modes

- Props invented because the declaration was hard to parse → controls that do not correspond to the component. Read the source or halt.
- A parallel playground scaffolded next to an existing Storybook → two explorers, one maintained. This is the failure the step-0 halt exists to prevent.
- Playground route registered outside the dev gate → ships to production.
- Playground registered in the router but never rendered → the skill reports success on code that was never executed; step 4 is not optional.
- A `string`-typed prop that is really an enum renders as a free-text box — union/enum inference is only as good as the type. Read the component's usage before trusting the control mapping.

## Halt conditions

- Props can't be read from source → halt; do not invent controls.
- Repo already has a component explorer → halt, route to a story.
- No dev gating on the route → halt (leaks to production).
- Generated but never rendered → unverified code, not a delivered probe.
