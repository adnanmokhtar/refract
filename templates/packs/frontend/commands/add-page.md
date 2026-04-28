---
description: Scaffold a page/route with view, store slice, service, types, i18n keys, and tests.
---

# /add-page <route>

Scaffolds a new top-level route or sub-route, mirroring an existing page in the same area. Lazy-loads if the repo's convention says so.

## Phases applied

All 7. Standard build/add command.

## When to use / NOT to use
- USE: new top-level route; new tab/sub-route inside an existing section.
- NOT: modal/drawer (use `/add-component`); shared layout fragment (`/add-component` or compose in existing page).

## Phase 1 — Understand

- Parse `<route>` arg.
- Consolidated question if missing: page purpose, data dependencies, required permissions.
- Success: route renders skeleton + loading + error + empty states; i18n keys exist in every locale; tests cover render + fetch + interaction.

## Phase 2 — Organize

- Detect framework (see Phase 3) — file layout depends on it.
- Sub-tasks: route file, page component, loading/error states, store slice (if shared), service method, DTO type, i18n keys, tests.
- Pause for confirmation on state-location decision (page-local vs store) before writing files.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` — framework + repo conventions.
- `ai/conventions.md` — naming, file structure.
- `ai/patterns/` — page pattern, data-fetching pattern, i18n pattern.

Detect framework:
- `app/` directory with `page.tsx` → Next.js App Router.
- `pages/` with `*.tsx` → Next.js Pages Router.
- `pages/` with `*.vue` → Nuxt.
- `src/views/` + `vue-router` → Vue Router.
- `src/app/.../*.component.ts` → Angular.
- `src/routes/+page.svelte` → SvelteKit.

EXISTING CODE — read one existing page in the same area to mirror routing + state + service patterns.

## Phase 4 — Generate

Dispatch `ui-architect` for the file list + state location decision (page-local vs store).

Generate:
- Page/view file with skeleton + loading state + error state + empty state.
- Route entry (config or file-system depending on framework).
- Store slice if state is shared (and the repo uses a store for similar pages).
- Service method(s) typed against shared DTO location.
- i18n keys in EVERY locale file the repo declares.
- Tests: render + data fetch (mocked) + interaction.

## Phase 5 — Update

- `ai/status.md` — prepend Recent Changes entry.
- `ai/dynamic/changelog.md` — append one-line summary.
- `ai/modules.md` — add row if new module/feature area.
- `locales/<each>/<area>.json` — i18n keys (already covered in Phase 4).

## Phase 6 — Validate

- Lint + typecheck on new files.
- Run tests scoped to new files.
- `visual-check` skill — render in dev server, confirm states (loading/empty/error).
- Verify i18n keys exist in every locale file declared in the repo.

## Phase 7 — Improve

- If the page introduced a new data-fetching shape, queue to `ai/dynamic/learned-patterns.md`.
- If permission gating diverged from existing pages, queue to `ai/dynamic/decisions-pending.md`.

## Output

```
Created:
  app/orders/page.tsx              page (lazy-loaded per repo convention)
  app/orders/loading.tsx           skeleton
  app/orders/error.tsx             error boundary
  src/services/orders.service.ts   list+get methods
  src/types/order.dto.ts           shared DTO
  locales/en/orders.json           +12 keys
  locales/ar/orders.json           +12 keys
  app/orders/__tests__/page.spec.tsx  4 cases
```

## Failure modes

- New HTTP client / form library / validation lib introduced "because it's nicer" — blocker; reuse what's there.
- Hardcoded copy — blocker; every visible string has an i18n key.
- Permission guards reinvented — copy from a sibling with similar permission needs.
- Loading/empty/error states omitted — required, not optional.
- Lazy-loading mismatch with sibling pages — hurts code-split coherence; mirror the convention.
- API URL hardcoded in component — services own that.

## Related

### Sibling commands in frontend pack
- `/a11y-audit` — sibling command in frontend pack
- `/add-component` — sibling command in frontend pack
- `/add-crud-page` — sibling command in frontend pack
- `/i18n-audit` — sibling command in frontend pack

### Patterns
- `ai/patterns/forms.md`
- `ai/patterns/i18n.md`
- `ai/patterns/rendering-strategy.md`
- `ai/patterns/ssr-safety.md`

### Rules
- `.claude/rules/frontend-principles.md`
