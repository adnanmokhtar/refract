---
name: component-playground
kind: example
pack: frontend
---

# component-playground

Mounts ONE shared component on an isolated, dev-gated route with knob-style controls built from its **real** prop declarations. Storybook-lite — no dependency, disposable.

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

## Halt conditions

- Props can't be read from source → halt; do not invent controls.
- Repo already has a component explorer → halt, route to a story.
- No dev gating on the route → halt (leaks to production).
- Generated but never rendered → unverified code, not a delivered probe.
