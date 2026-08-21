---
description: Scaffold a page/route with view, store slice, service, types, i18n keys, and tests.
---

# /add-page <route>

Scaffolds a new top-level route or sub-route, mirroring an existing page in the same area. Lazy-loads if the repo's convention says so.

## Phases applied

All 7. Standard build/add command.

## The Premise (read this first, internalize, do not deviate)

**Existing siblings are the truth.** Every page in the same area is the intentional shape — its routing entry, its layout import, its data-fetch call site, its loading/error/empty states, its permission gate, its lifecycle hook, its locale-key path. New pages copy that shape silently.

**The agent's job is exactly this:** find ≥2 sibling pages in the same area; mirror their structure (composables, shared Base*-wrappers, the caching lifecycle hook the siblings use, shared service layer, permission-gate import, locale-key naming, lazy-load convention); add only the delta the new page actually needs.

**The agent ONLY asks the user when:** no sibling page exists in the area (truly new shape); state location is genuinely ambiguous and no sibling answers it; a new permission gate is required that no sibling uses. Everything else — loading/empty/error state shape, lazy-load wrapper, i18n key naming, lifecycle hook — is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does an existing route/page already cover this user-facing capability under another name? Near-duplicate found → **HALT**: surface it (route + what it does) and ask extend / replace / deliberate parallel.

**New-dependency gate (all tiers):** a package **no sibling already imports** needs justification + a **bundle-size delta** (gzipped, tree-shakeable?) before it lands. **HALT** on an unreviewed new dependency; no silent install.

**Lightweight default.** A page that mirrors an existing sibling is code only — page + service + types + locale keys (BOTH locales) + tests, no plan and no ADR.

## When to use / NOT to use
- USE: new top-level route; new tab/sub-route inside an existing section.
- NOT: modal/drawer (use `/add-component`); shared layout fragment (`/add-component` or compose in existing page).

## Phase 1 — Understand

### Intent gate

If the description suggests a different intent, halt with a redirect: "enhance / improve / polish / cleaner" → `/enhance-ui` *(ui-ux pack)*. "fix / broken / wrong" → `/fix-bug` (core). "audit / review" → `/design-review` *(ui-ux pack)*, or this pack's `/a11y-audit` / `/i18n-audit` when the ask names that axis. Proceed only for adding a new page.

**A redirect must land somewhere.** Both ui-ux destinations exist only when that pack is co-installed — check first, and if it is absent offer `/polish` (core) for visual finish and `/audit` (core) for read-only review instead of halting into a command the project does not have.

### Standard inputs

- Parse `<route>` arg.
- Consolidated question if missing: page purpose, data dependencies, required permissions.
- Success: route renders skeleton + loading + error + empty states; i18n keys exist in every locale; tests cover render + fetch + interaction.

## Phase 2 — Organize

- Detect framework (see Phase 3) — file layout depends on it.
- Sub-tasks: route file, page component, loading/error states, store slice (if shared), service method, DTO type, i18n keys, tests.
- Pause for confirmation on state-location decision (page-local vs store) before writing files.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Page-specific:
- `ai/patterns/` — the page pattern, `data-fetching.md`, `i18n.md`, and `rendering-strategy.md` for this route's strategy.

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

Before declaring success, compare the new page against ≥2 sibling pages in the same area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where the project's shared wrappers exist (modal / paginator / form).
- Uses a plain mount hook where siblings use the cache-aware activate hook — a silent re-mount on every navigation.
- Doesn't use the project's gold-standard composable for the page kind when siblings do.
- i18n keys present in the pivot locale but missing in declared alt locales — a silent break.
- Default-true wrapper props left implicit when affordances should be hidden — pass the explicit `false`.
- New file placed outside the area's path convention.
- Lazy-load convention diverges from siblings (statically imported where siblings dynamic-import, or vice versa).
- Inbound nav links to the new route don't prefetch where siblings' equivalents do, with no documented prefetch=off.
- Loading state missing or not layout-stable (spinner / blank / CLS) where siblings paint a skeleton.

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
