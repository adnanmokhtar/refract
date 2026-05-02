---
name: component-playground
description: Mount any shared component in an isolated route under src/modules/_playground/ with controls for its props, so edge cases can be probed without touching real pages. Invoke when the user says "test this component in isolation", "play with props", or "see what X looks like with Y".
---

# Component Playground

Think Storybook-lite. Mounts a single component with knob-style prop controls on an isolated route.

## Location

All playgrounds live in `src/modules/_playground/`. Routes under `/playground/<component-name>`. Ignored in production, safe to delete.

Bootstrap the folder on first use:
- `src/modules/_playground/routes.ts` — aggregates all playground routes
- `src/modules/_playground/pages/<ComponentName>Playground.vue`
- Register `_playground/routes.ts` in `src/router/index.ts` gated by `import.meta.env.DEV`

## Inputs

- `$COMPONENT` — path to a component (`src/shared/components/form/FormField.vue`) or name (`BaseModal`)

## Steps

1. Read `$COMPONENT` to extract `defineProps<{ ... }>()` and `defineEmits<{ ... }>()`.
2. Generate a playground page that:
   - Imports the component
   - Renders it with `v-bind="bindings"` where `bindings` is a `reactive({})` built from the props
   - Renders one control per prop next to the component:
     - `boolean` → `<InputSwitch>`
     - `string` → `<InputText>`
     - `number` → `<InputNumber>`
     - enum/union → `<Dropdown>` with the enum values
     - object/array → `<Textarea>` with JSON
   - Logs every emit to a list on the right (so user can see events fire)
3. Register the route `/playground/<kebab-name>`.
4. Run `visual-check` on the playground route.
5. Share the URL with the user.

## Rules

- NEVER import `_playground/` from anywhere except the router.
- ALWAYS use shared `FormField` + inputs so controls feel native.
- Gate the route behind `import.meta.env.DEV` — no shipping playgrounds to prod.
- Playgrounds are disposable — delete them when the component's API stabilizes.
