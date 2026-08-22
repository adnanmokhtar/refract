---
description: Scaffold list + create + edit + delete pages for one entity end-to-end.
---

# /add-crud-page <entity>

Build command. Full CRUD bundle: list with pagination/filter, create/edit form, delete confirmation, store, service, i18n, tests. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Two gates run before anything is mirrored, and shape is the second one.** (1) **Data-sensitivity** — what does this entity HOLD? A sensitive entity is refused the generic scaffold on its sensitive fields no matter how standard its shape looks. (2) **Bespoke shape** — wizard / kanban / drag-drop → reject, route to `/add-feature`.

**Existing CRUD siblings are the truth.** Every CRUD page already in the admin area is the intentional shape — its list/form composables, its service extension, its table / form / modal wrappers, its dialog-vs-page choice for create/edit, its permission gate on routes AND action buttons, its optimistic-update presence-or-absence. New CRUD pages copy that shape silently.

**The agent's job is exactly this:** find ≥2 sibling CRUD pages in the same admin area; mirror EXACTLY their form library, table library, composables, service extension, dialog-vs-page choice, server-side-vs-client-side pagination, optimistic-update pattern (or its absence), caching lifecycle hook, and permission gates; add only the delta the new entity actually needs (its DTO fields, column set, filter list).

**The agent ONLY asks the user when:** the sibling count is 0 (first CRUD in this admin area); the API endpoints are missing (`POST/PATCH/DELETE` not implemented) — STOP and route to `/add-feature`; a bespoke flow is required (wizard, kanban, drag-drop) — reject and route to `/add-feature`; or the sensitivity gate fired and the project ships no provider primitive for that class of data — STOP and route to `/add-feature`, which owns the integration. Everywhere else the sensitivity gate does not ask, it **refuses**. Everything else — column order, filter shape, pagination size, validation message text, empty-state copy — is silent sibling-mirror.

**Prior-art gate (all tiers):** search by **behaviour, not name** — does an existing route/page already manage this entity under another name? Near-duplicate found → **HALT**: surface it and ask extend / replace / deliberate parallel.

**New-dependency gate (all tiers):** a table/form/date package **no sibling already imports** needs justification + a **bundle-size delta** before it lands — reuse the repo's declared libraries by default. **HALT** on an unreviewed new dependency.

**Lightweight default.** A new entity with an existing API and a sibling CRUD page in the same area is code only — list + form + delete + store + service + locale keys (BOTH locales) + tests, no plan and no ADR.

## When to use / NOT to use
- USE: new admin entity needing standard CRUD.
- USE: replacing a half-built CRUD that diverged from repo conventions.
- NOT: API endpoints don't exist yet — flag, stop, route to `/add-feature` (API-first).
- NOT: bespoke flow (multi-step wizard, kanban, drag-drop) — those need design + `/add-feature`, not CRUD scaffold.

## Phase 1 — Understand

### Data-sensitivity gate (runs FIRST — before shape, before siblings)

For the entity AND every field on it: **does it hold a credential, a payment instrument, a government or tax identifier, a health / biometric record, or a third-party access token?** Read the DTO / OpenAPI schema field by field — the signal is the field, not the noun.

**No →** continue to the sibling census; the rest of the command applies unchanged.

**Yes → the generic scaffold is REFUSED for those fields.** Not "ask the user" — refused, the way a form-library mismatch is refused. A value your form never receives cannot be logged, captured by an error tracker, replayed by a session recorder, or retained in form state. Branch:

- **Create** — the provider's hosted / tokenised primitive (payment element, identity widget, signed upload); the repo stores a token or reference, never the value.
- **Edit** — the non-sensitive subset only (label, billing address, default flag). A sensitive value is replaced by re-tokenising, never patched.
- **List** — only the provider's display token is renderable (brand + last four, masked tail). Never a column, tooltip, or export cell.
- **Search / filter** — sensitive fields are not searchable.
- **Delete** — revoke at the provider first, then delete locally; run the dependent check before either.
- **Tests + fixtures** — provider test tokens only; no sensitive value in a fixture, snapshot, log line, or analytics event.

Report line when the gate fires: `data-sensitivity: <class> — create via <provider primitive>; editable subset = <fields>; non-renderable = <fields>`.

### Sibling census (sets the mode for the whole run)

- **0 siblings** → `ask`: no shape to mirror. Ask the shape questions once, up front, and record the answers as the area's first CRUD shape. The Phase 4 sibling-shape halt is declared not-evaluated, never silently skipped.
- **1 sibling** → `mirror-single`: mirror it and name it. The halt runs against one sibling — weaker, not absent.
- **≥2 agreeing** → `mirror`: the default; full halt as written.
- **≥2 disagreeing** → `mirror-newest`: resolve **per axis, not per file** — for each disputed axis (create surface, pagination side, optimistic-update, caching hook, wrapper set) the most recently modified sibling wins (`git log -1 --format=%cI -- <path>`). Then report the divergence; a divergence resolved silently is drift the next run re-resolves the other way.

### The rest of Phase 1
- Entity name (singular).
- List endpoint path; confirm `POST/PATCH/DELETE` exist (read OpenAPI spec / controller).
- Fields with type + validation; display columns; search fields — minus anything the sensitivity gate marked non-renderable or non-searchable.
- **Cross-row exclusivity** — is any field exclusive across the collection (one default, one primary, one active)? Every "yes" is an action in the Phase 4 store contract.
- Confirm: standard CRUD really fits, or is this bespoke?

## Phase 2 — Organize
- Verify API exists. If `POST/PATCH/DELETE` missing → STOP with "API needed first" message; route to `/add-feature`.
- Decide layout: dialog vs page for create/edit (mirror existing CRUD).
- Decide pagination: server-side default; client-side only for bounded reference data (< 1000 rows).
- Dispatch plan: `ui-architect` for file list + state shape; `api-architect` *(backend pack)* only to confirm the contract is sufficient — **and only when that pack is co-installed**. Absent → read the endpoint's controller signature + DTO directly and record `contract check: inline (backend pack absent)`. Never resolve this step to nothing.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

CRUD-specific:
- An existing CRUD page in the same admin area — mirror EXACTLY (form library, table library, toast/dialog primitives, optimistic-update pattern or lack of).
- API contract (OpenAPI spec or shared DTO file).
- Auth/permission guard pattern from sibling routes.
- i18n setup + locale files.

## Phase 4 — Generate
- **List page** — table with sort, pagination, filter, search, row actions (edit + delete).
- **Create / Edit page** (or dialog if repo prefers): form with same library used elsewhere, validation, submit + cancel.
- **Delete** — confirmation dialog or undo-toast per repo convention; never silent, **and blocked before it is confirmed.** A row something live still points at (the card funding an active subscription, the last admin on a tenant) is a refused delete, not a confirmable one: ask the contract (`409` on delete, a `can_delete` flag, a dependent count) and render the blocked reason instead of the dialog. No contract signal → say `delete-dependency check: unavailable (no contract signal)` rather than promising a delete the server will refuse.
- **Store slice** — the five row verbs (`list`, `getOne`, `create`, `update`, `remove`) + paginated list state, **plus this entity's cross-row actions.** Five verbs is the floor, not the shape of CRUD: `setDefault`, `activate`, `reorder`, `archive`-with-successor each change two rows from one user action, so they live on the slice and must settle both on success. A naive optimistic `update` leaves two rows claiming to be the default.
- **Service** — typed methods against shared DTO.
- **Routes** — list + create + edit, with auth/permission guards copied from sibling.
- **i18n** — keys for every label, button, validation message, empty state, in EVERY locale.
- **Tests** — list (renders, paginates, filters), form (valid + invalid submit), delete (confirms + executes).
- Run lint + tests scoped to new files; iterate to green.

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new CRUD bundle against ≥2 sibling CRUD pages in the same admin area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where the project's shared wrappers exist (modal / paginator / form / dropdown).
- Hand-rolls list + form state where siblings use the project's CRUD/form composables.
- Calls the HTTP client directly where siblings extend the shared CRUD service.
- Uses a plain mount hook instead of the cache-aware activate hook on the list page — siblings cache across navigation; the new page silently re-mounts and re-fetches.
- i18n keys present in the pivot locale but missing in declared alt locales — a silent break.
- Default-true wrapper props left implicit — removing a handler does NOT hide the underlying button; pass the explicit `false`.
- Optimistic-update mismatch — siblings don't use optimistic updates and the new page does, or vice versa. Partial adoption is worse than none.
- Form or table library mismatch with the repo's declared one — reject.
- **A sensitive field reached a repo-owned surface** — an input bound to the repo's schema, a table column, a search field, a fixture, a log line, or an analytics payload, where Phase 1's gate marked it non-renderable. This halt outranks sibling-mirror: a sibling that already does it is a defect to report, not a shape to copy.
- **Cross-row exclusivity implemented as a per-row `update`** — "make this the default" patches one row and leaves the previously-default row untouched.
- **Delete ships with no dependent check while the contract exposes one.**

**Hard rule:** `gap_count_in != gap_count_closed` → HALT; any `regressed` → HALT. Evaluability comes from the sibling census, and the mode is printed either way: `n≥2` fully evaluable; `n=1` evaluated against the one sibling (`siblings compared: 1 (<path>)`); `n=0` reports `sibling-shape halt: n/a (first CRUD in area)`. A hard rule that quietly cannot be computed reads as a pass.

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

## Phase 7 — Improve
- `/learn-from-task` — capture CRUD-shape conventions confirmed.
- If 3+ entities now share the same CRUD scaffold → queue to `ai/patterns/crud-page.md` as a project pattern (or refresh existing).
- If form library duplicated logic surfaces (date pickers, file upload) → queue extraction proposal.

## Output format
```
## /add-crud-page — <Entity>

Phase 1 (Understand): API verified; standard CRUD fits
  data-sensitivity: none   sibling census: 3 found -> mode = mirror
Phase 3 (Retrieved): mirrored sibling at <path>; libs = <form|table>
Phase 4 (Generated):
  Pages:    list + create + edit
  Routes:   /admin/products, /admin/products/new, /admin/products/:id
  Store:    src/store/products.slice.ts (5 row actions + 1 cross-row: setDefault)
  Service:  src/services/products.service.ts (6 methods)
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
- Scaffolding a sensitive field because its shape looked standard — a saved-payment-method entity is not a wizard, not a kanban and not drag-drop, so a shape-only gate waves it through and the sibling mirror produces a repo-owned card-number input.
- Cross-row mutation squeezed into `update` → the list shows two defaults until a refetch.
- Delete confirmed, then refused by the server — nothing asked whether the row was deletable.
- `n=1` treated as `n≥2` — a `gap_count` reported but never computed.
- Permission gate on route but not on button → leak via direct URL.
