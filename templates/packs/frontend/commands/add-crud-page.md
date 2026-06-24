---
description: Scaffold list + create + edit + delete pages for one entity end-to-end.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-crud-page <entity>

Build command. Full CRUD bundle: list with pagination/filter, create/edit form, delete confirmation, store, service, i18n, tests. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Existing CRUD siblings are the truth.** Every CRUD page already in the admin area is the intentional shape — its `useCrud` composable call, its `BaseCrudService` extension, its `<CrudPaginator>` / `<BaseForm>` / `<BaseModal>` wrappers, its dialog-vs-page choice for create/edit, its permission gate on routes AND action buttons, its optimistic-update presence-or-absence. New CRUD pages copy that shape silently.

**The agent's job is exactly this:**
1. Find ≥2 sibling CRUD pages in the same admin area.
2. Mirror EXACTLY: form library (zod/yup/vee-validate/react-hook-form), table library (PrimeVue DataTable, AG Grid, TanStack Table), `useCrud`/`useForm` composables, `BaseCrudService` extension, dialog vs page for create/edit, server-side vs client-side pagination, optimistic-update pattern (or its absence), `onActivated` for KeepAlive caching, permission-gate copy from sibling routes.
3. Add only the delta the new entity actually needs (its DTO fields, its column set, its filter list). Everything else: copy the sibling shape silently.

**The agent ONLY asks the user when:**
- **No sibling CRUD exists** in this admin area (first CRUD in the module).
- **API endpoints missing** (`POST/PATCH/DELETE` not implemented) — STOP, route to `/add-feature`.
- **Bespoke flow** required (multi-step wizard, kanban, drag-drop) — reject; route to `/add-feature`.

Everything else — column order, filter shape, pagination size, validation message text, empty-state copy, dialog-vs-page — is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does an existing route/page already manage this entity (or an equivalent capability) under another name? Near-duplicate found → **HALT**: surface it (route + what it does) and ask extend / replace / deliberate parallel. (Inherited from `/add-feature` when invoked via it; runs mechanically when called standalone.)

**New-dependency gate (all tiers):** a package **no sibling already imports** (table lib, form lib, date lib) needs justification + **bundle-size delta** (gzipped, tree-shakeable?) before it lands — reuse the repo's declared form/table library by default. **HALT** on an unreviewed new dependency; no silent `npm install`.

**Closure-verb table — CRUD complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New entity, API exists, sibling CRUD page lives in the same admin area | Code only — list + form + delete + store + service + locale keys (BOTH locales) + tests. **No plan, no ADR.** | YES |
| **Standard** | New entity needs 1 custom column renderer OR 1 new filter widget | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | First CRUD in a new admin area, OR new shared CRUD wrapper required | Standard + ADR + `@ui-reviewer` + `@accessibility-auditor` + `@i18n-auditor` cascade | NO |

**Lightweight default.** Trivial-tier is the default. Drafting an ADR to legitimize a new CRUD page on an existing entity is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new admin entity needing standard CRUD.
- USE: replacing a half-built CRUD that diverged from repo conventions.
- NOT: API endpoints don't exist yet — flag, stop, route to `/add-feature` (API-first).
- NOT: bespoke flow (multi-step wizard, kanban, drag-drop) — those need design + `/add-feature`, not CRUD scaffold.

## Phase 1 — Understand
- Entity name (singular).
- List endpoint path; confirm `POST/PATCH/DELETE` exist (read OpenAPI spec / controller).
- Fields with type + validation; display columns; search fields.
- Confirm: standard CRUD really fits, or is this bespoke?

## Phase 2 — Organize
- Verify API exists. If `POST/PATCH/DELETE` missing → STOP with "API needed first" message; route to `/add-feature`.
- Decide layout: dialog vs page for create/edit (mirror existing CRUD).
- Decide pagination: server-side default; client-side only for bounded reference data (< 1000 rows).
- Dispatch plan: `ui-architect` for file list + state shape; `api-architect` only to confirm contract sufficient.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

CRUD-specific:
- An existing CRUD page in the same admin area — mirror EXACTLY (form library, table library, toast/dialog primitives, optimistic-update pattern or lack of).
- API contract (OpenAPI spec or shared DTO file).
- Auth/permission guard pattern from sibling routes.
- i18n setup + locale files.

## Phase 4 — Generate
- **List page** — table with sort, pagination, filter, search, row actions (edit + delete).
- **Create / Edit page** (or dialog if repo prefers): form with same library used elsewhere, validation, submit + cancel.
- **Delete** — confirmation dialog or undo-toast per repo convention; never silent.
- **Store slice** — actions: `list`, `getOne`, `create`, `update`, `remove` + paginated list state.
- **Service** — typed methods against shared DTO.
- **Routes** — list + create + edit, with auth/permission guards copied from sibling.
- **i18n** — keys for every label, button, validation message, empty state, in EVERY locale.
- **Tests** — list (renders, paginates, filters), form (valid + invalid submit), delete (confirms + executes).
- **List→detail prefetch** — list rows prefetch the detail/edit route on hover/intent (the hot nav path: list→detail is THE fast page-to-page case) via the framework's nav primitive. Mirror how siblings prefetch; framework specifics in `references/<framework>.md` + skill `navigation-speed.md`.
- **Instant loading skeletons** — the list AND the create/edit page paint an instant, layout-stable loading skeleton (no CLS), not a spinner. Mirror the sibling skeleton shape; per `frontend-principles.md` (instant layout-stable skeleton on navigation).
- **Virtualize large lists** — a list likely rendering > ~100 visible rows VIRTUALIZES (windowed render) in addition to server-side pagination, mirroring sibling virtualized lists; per `frontend-principles.md`.
- Run lint + tests scoped to new files; iterate to green.

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new CRUD bundle against ≥2 sibling CRUD pages in the same admin area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where Base*-wrappers exist — raw `<Dialog>` instead of `<BaseModal>`, raw `<Paginator>` instead of `<CrudPaginator>`, raw `<form>` instead of `<BaseForm>`, raw `<Dropdown>` instead of `<BaseDropdown>`.
- Doesn't use `useCrud` / `useForm` when siblings do — hand-rolled list + form state in a `useCrud` codebase is silent divergence.
- Doesn't extend `BaseCrudService` when siblings do — direct `axios`/`fetch` call in a `BaseCrudService` codebase.
- Uses `onMounted` instead of `onActivated` on the list page (KeepAlive cache divergence — siblings cache across navigation; new page silently re-mounts and re-fetches).
- i18n keys present in pivot locale but missing in declared alt locales (`en.ts` ✓, `ar.ts` ✗ — silent break in alt locale).
- Default-true wrapper props left implicit — removing a `@delete-selected` handler does NOT hide the underlying button; pass `:show-delete="false"` / `:can-delete="false"` explicitly. Same for `:show-create`, `:can-export`, `:show-bulk-actions`.
- Optimistic-update mismatch — siblings don't use optimistic; new page does (or vice versa). Partial adoption is worse than none.
- Form library mismatch (zod into a yup repo, react-hook-form into a vee-validate repo) — reject.
- Permission gate on route but not on action buttons — leak via direct URL or component remount.
- List→detail navigation doesn't prefetch the detail/edit route on hover/intent where sibling CRUD lists do — the hot nav path stays cold.
- Loading skeleton missing or unsized (CLS on first paint) on the list or the form where siblings paint an instant layout-stable skeleton.
- A list likely > ~100 visible rows isn't virtualized where siblings virtualize windowed rows.

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT.

## Phase 5 — Update
- `ai/modules.md` — add row for the new entity's UI module.
- `ai/dynamic/changelog.md` — one-line: `Added CRUD for <entity>: list + form + delete`.
- `ai/status.md` — `## Recent Changes` bullet.
- Locale files (`locales/<lang>.json` × N locales).
- Permission registry if the project tracks UI-action permissions centrally.

## Phase 6 — Validate
- Lint passes; tests green.
- Permission gating on routes AND on action buttons (hidden button on permitted-route is a leak via direct URL).
- Server-side pagination/sort/filter on lists likely > 1000 rows.
- Delete is reversible (soft-delete + undo) or confirmed (modal); never silent permanent delete.
- Hardcoded strings → all routed through i18n.
- **Nav-speed sign-off** — dispatch `navigation-speed.md` on the list→detail surface (verify detail/edit prefetch on intent, bfcache safety — no unload/beforeunload, instant layout-stable skeleton on navigation). If the list is SSR with a slow query, also dispatch `streaming-ssr.md` to stream the shell and cut TTFB. Enforces `frontend-principles.md` route-prefetch + stream-the-shell + instant-skeleton + bfcache MUSTs.
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md`): error boundary / error-tracking captures errors from the list + form + delete routes the way siblings wire it; route-level perf signal (web-vitals / RUM) + CRUD analytics events added if siblings of this surface emit them. If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.

## Phase 7 — Improve
- `/learn-from-task` — capture CRUD-shape conventions confirmed.
- If 3+ entities now share the same CRUD scaffold → queue to `ai/patterns/crud-page.md` as a project pattern (or refresh existing).
- If form library duplicated logic surfaces (date pickers, file upload) → queue extraction proposal.

## Output format
```
## /add-crud-page — <Entity>

Phase 1 (Understand): API verified; standard CRUD fits
Phase 3 (Retrieved): mirrored sibling at <path>; libs = <form|table>
Phase 4 (Generated):
  Pages:    list + create + edit
  Routes:   /admin/products, /admin/products/new, /admin/products/:id
  Store:    src/store/products.slice.ts (5 actions)
  Service:  src/services/products.service.ts (5 methods)
  i18n:     +24 keys × 2 locales
  Tests:    7 spec files, 32 cases
Phase 5 (Updated): ai/modules.md, changelog, status.md, locale files
Phase 6 (Validated): lint + tests green; permission on routes + buttons; SSR pagination
Phase 7 (Improved): pattern refreshed at ai/patterns/crud-page.md

Status: COMPLETE
```

## Failure modes
- Inventing a new interaction (drawer instead of page) per entity → erodes pattern library; mirror existing.
- Form library mismatch (zod into a yup repo) → reject; use repo's declared library.
- Optimistic updates introduced when repo doesn't use them → desync bugs; partial adoption is worse than none.
- Client-side pagination on a list that may exceed 1000 rows → memory + UX collapse; SSR default.
- Silent permanent delete → user-data loss; require modal or undo-toast.
- Permission gate on route but not on button → leak via direct URL.
- List→detail click feels slow — no row prefetch / no instant skeleton on navigation.

## Related

### Sibling commands in frontend pack
- `/a11y-audit` — sibling command in frontend pack
- `/add-component` — sibling command in frontend pack
- `/add-page` — sibling command in frontend pack
- `/i18n-audit` — sibling command in frontend pack

### Skills
- `navigation-speed.md` — list→detail prefetch / Speculation Rules / bfcache / instant-loading / View Transitions audit (the fast page-to-page nav specialist for the hot list→detail path).
- `streaming-ssr.md` — fast-SSR streaming-boundary scanner; stream the shell when the SSR list has a slow query, cut TTFB.
- `lcp-audit.md` — LCP-resource priority-hint scanner (fetchpriority / preload / preconnect / lazy-hero) for the list/detail above-the-fold.

### Patterns
- `ai/patterns/forms.md`
- `ai/patterns/i18n.md`
- `ai/patterns/rendering-strategy.md`
- `ai/patterns/ssr-safety.md`

### Rules
- `.claude/rules/frontend-principles.md`
