# Conventions — ops-dashboard

These are enforced conventions, not suggestions. New code matches them; existing code that
does not is drift to be corrected.

## Files and naming

- Component files are PascalCase and match the exported component name exactly:
  `OrdersToolbar.tsx` exports `OrdersToolbar`.
- Hook files are camelCase and start with `use`: `useOrders.ts`.
- Non-component modules under `src/lib/` are kebab-case: `api-client.ts`.

## Layering

`components/` → `hooks/` → `lib/api-client.ts` → network.

- Components MUST NOT import `src/lib/api-client.ts`, and MUST NOT call `fetch` directly.
  All data access goes through a hook in `src/hooks/`.
- `src/lib/api-client.ts` is the only module permitted to construct an HTTP request.
  It attaches auth, base URL, and error normalisation. Bypassing it loses all three.

## Error handling

- Never swallow an error. Every `catch` either surfaces it through the hook's `error`
  state or re-throws. An empty `catch` block is a defect.
- Every data hook exposes the full triple `{ data, loading, error }`, and every consumer
  renders all three states. A component that renders only the success state is incomplete.

## Design tokens

- Colours, spacing, radii and font sizes come from `src/styles/tokens.css`. Never hardcode
  a hex colour, an rgb() literal, or a pixel value that a token already covers.
- Spacing is on a 4px scale: `--space-1` (4px) through `--space-6` (32px).

## Accessibility

- Every interactive element has an accessible name. Icon-only buttons carry `aria-label`.
- Every `<img>` has an `alt` attribute; decorative images use `alt=""`.
- Focus states come from the `--focus-ring` token; never remove an outline without a
  replacement.

## Internationalisation

- Every user-visible string goes through `t()` from `src/lib/i18n.ts`. No literal copy in
  JSX text nodes, `placeholder`, `title`, or `aria-label`.

## Permissions

- Any action the user may not be allowed to perform is wrapped in `<Can action="...">`
  from `src/components/ui/Can.tsx`. Destructive actions are never rendered ungated.
