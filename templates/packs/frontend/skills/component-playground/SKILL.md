---
name: component-playground
description: Mount any shared component in an isolated dev-only route with knob-style controls for its props, so edge cases can be probed without touching real pages (Storybook-lite). Framework-adaptive — Vue / React / Svelte / Angular. Invoke on "test this component in isolation", "play with props", "see what X looks like with Y".
---

# Component Playground

Mounts a single component with prop controls on an isolated, dev-only route. Storybook-lite — no dependency, disposable.

## Premise

**Probe the component in isolation, in the project's own stack — never impose a framework or UI kit the repo doesn't use.** The playground must be built from the component's real prop/emit declarations (read them, don't guess) and wired with the project's own shared input components and router. A playground that hard-codes a different framework's controls is worse than none. Cite the component's actual props at `<file:line>` when generating controls.

## Adapt to the codebase

Detect the component framework + the shared input components + where dev-only routes live, and mirror them:

| Framework | Read props from | Emits / events | Prop-control widget (prefer the project's shared inputs) |
|---|---|---|---|
| **Vue 3** | `defineProps<{…}>()` | `defineEmits<{…}>()` | its `<Switch>` / `<InputText>` / `<InputNumber>` / `<Select>` / `<Textarea>` (or the UI kit in use) |
| **React** | the props `type` / `interface` (or `Props` param) | callback props (`onX`) | the design-system `Switch` / `Input` / `NumberInput` / `Select` / `<textarea>` |
| **Svelte 5** | `$props()` (runes) or `export let` (legacy) | `createEventDispatcher` / callback props | project inputs or native `<input>` |
| **Angular** | `input()` signals or `@Input()` | `output()` / `@Output()` | project inputs / Angular Material |

Control mapping by prop type (same across frameworks): `boolean` → toggle/switch · `string` → text input · `number` → number input · enum/union → select · object/array → JSON `<textarea>`. Log every emit/event to a visible list so the user sees them fire.

## Location

- Put playgrounds in the project's dev-only routes area — reuse an existing `_dev/` / `_playground/` / `dev/` convention if one exists; otherwise create `<routes-root>/_playground/` next to the app's routes.
- Route path `/_playground/<kebab-component-name>`; **gate behind the framework's dev flag** (`import.meta.env.DEV` for Vite/Nuxt/SvelteKit, `process.env.NODE_ENV !== 'production'` for Next/Angular) so it never ships.
- Register the playground route in the project's router the same way real routes are registered.

## Steps

1. Resolve `$COMPONENT` (path or name) and **read it** to extract the real prop + emit/event declarations (see the Adapt table for where they live).
2. Generate a playground page that: imports the component; binds a reactive/stateful `bindings` object built from the props; renders one control per prop (mapped by type, using the project's shared inputs); and logs each emit/event to a list beside the component.
3. Register the route (dev-gated) in the project's router.
4. Run `visual-check` on the playground route to confirm it renders.
5. Share the URL.

## Rules

- Import `_playground/` from nowhere except the router; it is disposable.
- Use the project's shared input components so controls feel native to the app (fall back to native `<input>` only if there is no shared kit).
- Gate behind the dev flag — never ship a playground to production.
- Delete the playground once the component's API stabilizes.

## Halt conditions

- Halt if the component's props/emits cannot be read from source — do not invent controls for props you have not seen at `<file:line>`.
- Halt if the generated playground uses a framework or UI kit the project does not use (mirror the detected stack from the Adapt table).
- Halt if no dev-only gating is applied to the route (would leak the playground to production).
