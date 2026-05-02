---
description: Scaffold a page/route with view, store slice, service, types, i18n keys, and tests.
---

# /add-page <route>

Scaffolds a new top-level route or sub-route, mirroring an existing page in the same area. Lazy-loads if the repo's convention says so.

## Phases applied

All 7. Standard build/add command.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** Every page in the same area is the intentional shape — its routing entry, its layout import, its data-fetch call site, its loading/error/empty states, its permission gate, its lifecycle hook, its locale-key path. New pages copy that shape silently.

**The agent's job is exactly this:**
1. Find ≥2 sibling pages in the same area (same module, same `pages/`/`views/`/`app/` subtree).
2. Mirror their structure: composables (`useCrud`, `useForm`), Base*-wrappers (`<BaseModal>`, `<BaseForm>`, `<CrudPaginator>`), `onActivated` for KeepAlive caching (NOT `onMounted`), shared service-layer (`BaseCrudService`), permission-gate import, locale-key naming, lazy-load convention.
3. Add only the delta the new page actually needs. Everything else: copy the sibling shape silently.

**The agent ONLY asks the user when:**
- **No sibling page exists** in the area (truly new shape — first list page, first wizard, first chart panel).
- **State location is genuinely ambiguous** (no sibling answers it — page-local vs store).
- **New permission gate** (route requires a role/scope that no sibling uses).

Everything else — loading/empty/error state shape, lazy-load wrapper, i18n key naming, lifecycle hook, default-true wrapper props — is silent sibling-mirror.

**Closure-verb table — page complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New page that mirrors an existing sibling (list, detail, settings tab) | Code only — page + service + types + locale keys (BOTH locales). Tests required. **No plan, no ADR.** | YES |
| **Standard** | New shape that needs 1 new composable OR a new shared loading/empty primitive | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | New routing pattern (multi-route flow, dynamic segment shape, SSR vs CSR switch on this route family) | Standard + ADR + `@ui-reviewer` + `@accessibility-auditor` cascade | NO |

**Lightweight default.** Trivial-tier is the default. Drafting an ADR for a sibling-mirror page is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new top-level route; new tab/sub-route inside an existing section.
- NOT: modal/drawer (use `/add-component`); shared layout fragment (`/add-component` or compose in existing page).

## Phase 1 — Understand

### Intent gate

If description suggests a different intent, halt with redirect: "enhance / improve / polish / cleaner" → `/enhance-ui`. "fix / broken / wrong" → `/fix-bug`. "audit / review" → `/design-review`. Proceed only for adding a new page.

### Standard inputs

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

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new page against ≥2 sibling pages in the same area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where Base*-wrappers exist — raw `<Dialog>` instead of `<BaseModal>`, raw `<Paginator>` instead of `<CrudPaginator>`, raw `<form>` instead of `<BaseForm>`.
- Uses `onMounted` instead of `onActivated` on a route page when siblings cache across navigation (KeepAlive cache divergence — silent re-mount).
- Doesn't use the project's gold-standard composable (`useCrud` for list pages, `useForm` for forms) when siblings do.
- i18n keys present in pivot locale but missing in declared alt locales (`en.ts` ✓, `ar.ts` ✗) — silent break.
- Default-true wrapper props left implicit when affordances should be hidden — pass `:show-delete="false"` / `:can-edit="false"` explicitly.
- New file placed outside the area's path convention (e.g., `pages/orders/NewOrder.vue` when siblings live at `views/orders/Form.vue`).
- Lazy-load convention diverges from siblings (sibling pages use `defineAsyncComponent` / dynamic-import; new page is statically imported, or vice versa).

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT.

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
