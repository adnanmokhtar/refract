---
description: Scaffold list + create + edit + delete pages for one entity end-to-end.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. Inline syntax in this file uses Vue 3 + PrimeVue + TypeScript for illustration; substitute your stack's primitives from `_extracted-idioms.md`.


# /add-crud-page <entity>

Build command. Full CRUD bundle: list with pagination/filter, create/edit form, delete confirmation, store, service, i18n, tests. All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Two gates run before anything is mirrored, and shape is the second one.**

1. **Data-sensitivity gate — what does this entity HOLD?** (Phase 1, first block.) A sensitive entity is refused the generic scaffold on its sensitive fields no matter how standard its shape looks. "Saved payment methods" is textbook-standard in shape and unscaffoldable in substance; a command that only asks about shape mirrors a sibling straight into a card-number input.
2. **Bespoke-shape gate — is this a wizard / kanban / drag-drop?** Reject; route to `/add-feature`.

**Existing CRUD siblings are the truth.** Every CRUD page already in the admin area is the intentional shape — its list/form composables, its shared CRUD service extension, its paginator / form / modal wrappers, its dialog-vs-page choice for create/edit, its permission gate on routes AND action buttons, its optimistic-update presence-or-absence. New CRUD pages copy that shape silently.

**The agent's job is exactly this:**
1. Run the data-sensitivity gate (Phase 1) — it decides whether the generic scaffold applies at all.
2. Take the **sibling census** (Phase 1) — the count sets the mode: `ask` (0), `mirror-single` (1), `mirror` (≥2 agreeing), `mirror-newest` (≥2 disagreeing).
3. Mirror EXACTLY: form library (zod/yup/vee-validate/react-hook-form), table library (PrimeVue DataTable, AG Grid, TanStack Table), the project's list/form composables, its shared CRUD service extension, dialog vs page for create/edit, server-side vs client-side pagination, optimistic-update pattern (or its absence), the cache-aware activate hook siblings use for list caching, permission-gate copy from sibling routes.
4. Add only the delta the new entity actually needs (its DTO fields, its column set, its filter list). Everything else: copy the sibling shape silently.

**The agent ONLY asks the user when:**
- **Sibling count is 0** — no sibling CRUD exists in this admin area (first CRUD in the module). See Phase 1 § Sibling census for what it asks and what it records.
- **API endpoints missing** (`POST/PATCH/DELETE` not implemented) — STOP, route to `/add-feature`.
- **Bespoke flow** required (multi-step wizard, kanban, drag-drop) — reject; route to `/add-feature`.
- **The data-sensitivity gate fired and the project ships no provider primitive** for that class of data — STOP, route to `/add-feature`, which owns the integration. Everywhere else the gate does not ask, it **refuses**: the sensitive branch in Phase 1 is taken silently, exactly like a sibling mirror.

Everything else — column order, filter shape, pagination size, validation message text, empty-state copy, dialog-vs-page — is silent sibling-mirror.

**Prior-art gate (all tiers):** before scaffolding, search by **behaviour, not name** — does an existing route/page already manage this entity (or an equivalent capability) under another name? Near-duplicate found → **HALT**: surface it (route + what it does) and ask extend / replace / deliberate parallel. (Inherited from `/add-feature` when invoked via it; runs mechanically when called standalone.)

**New-dependency gate (all tiers):** a package **no sibling already imports** (table lib, form lib, date lib) needs justification + **bundle-size delta** (gzipped, tree-shakeable?) before it lands — reuse the repo's declared form/table library by default. **HALT** on an unreviewed new dependency; no silent `npm install`.

**Closure-verb table — CRUD complexity → ceremony:**

| Tier | Trigger | Ceremony | Default? |
|---|---|---|---|
| **Trivial** | New entity, API exists, sibling CRUD page lives in the same admin area | Code only — list + form + delete + store + service + locale keys (BOTH locales) + tests. **No plan, no ADR.** | YES |
| **Standard** | New entity needs 1 custom column renderer OR 1 new filter widget | Trivial + 1-paragraph sibling-shape note inline | NO |
| **Heavy** | First CRUD in a new admin area, OR new shared CRUD wrapper required, OR **the data-sensitivity gate fired** (a tokenised create path is an integration, never a scaffold) | Standard + ADR + `@ui-reviewer` + `@accessibility-auditor` + `@i18n-auditor` cascade | NO |

**Lightweight default.** Trivial-tier is the default. Drafting an ADR to legitimize a new CRUD page on an existing entity is the same anti-pattern as the migration pack's "ADR-as-closure" trap.

## When to use / NOT to use
- USE: new admin entity needing standard CRUD.
- USE: replacing a half-built CRUD that diverged from repo conventions.
- NOT: API endpoints don't exist yet — flag, stop, route to `/add-feature` (API-first).
- NOT: bespoke flow (multi-step wizard, kanban, drag-drop) — those need design + `/add-feature`, not CRUD scaffold.
- NOT, for the sensitive fields only: an entity holding a credential / payment instrument / government identifier / health record / third-party token. The list, the permission gates and the non-sensitive fields are still this command's job; the create path is not. See Phase 1 § Data-sensitivity gate.

## Phase 1 — Understand

### Data-sensitivity gate (runs FIRST — before shape, before siblings)

Answer for the entity AND for every field on it: **does it hold a credential, a payment instrument, a government or tax identifier, a health / biometric record, or a third-party access token?**

Read the DTO / OpenAPI schema field by field. Do not infer from the entity name — the signal is the field, not the noun. `Customer` is ordinary until it carries a national ID; `Integration` is ordinary until it carries an access token; `PaymentMethod` is never ordinary.

**No →** proceed to the sibling census; the rest of this command applies unchanged.

**Yes → the generic scaffold is REFUSED for those fields.** Not "ask the user" — refused, the same way a form-library mismatch is refused. The reason is mechanical, not stylistic: a value your form never receives cannot be logged by your logger, captured by your error tracker, replayed by your session recorder, retained in your form library's state, or read out of your bundle. That is the entire purpose of the provider primitive. Take this branch:

| Surface | Generic CRUD would | Sensitive branch does instead |
|---|---|---|
| **Create** | a repo-owned input bound to the repo's validation schema | the provider's hosted / tokenised primitive — the payment provider's hosted field or element, the identity provider's widget, a direct-to-storage signed upload. The repo receives a **token or reference** and stores that. No sensitive value enters the repo's form state, its schema, or its store. |
| **Edit** | `PATCH` the whole DTO | restricted to the **non-sensitive subset** (label, billing address, default flag, expiry-as-metadata). A sensitive value is **replaced by re-tokenising**, never patched — most providers cannot patch one, and a form that renders the field promises they can. |
| **List** | every field is a candidate column | only the provider's **display token** is renderable (brand + last four, issuer + masked tail, expiry). The raw value is never a column, never a tooltip, never an export cell. |
| **Search / filter** | any field is a candidate search field | sensitive fields are **not searchable**. Filter on the display token, the label, the owner, or the created date. |
| **Delete** | `DELETE` the row | **detach / revoke at the provider first**, then delete locally — and run the dependent check before either (Phase 4 § Delete). |
| **Tests + fixtures** | fixtures carry realistic values | provider **test tokens** only. No sensitive value in a fixture, a snapshot, an error message, a log line, or an analytics event. |

**Mandatory report line when the gate fires:**
`data-sensitivity: <class> — create via <provider primitive>; editable subset = <fields>; non-renderable = <fields>`

If the project ships no provider primitive for this class of data, that is a **HALT** and not a licence to build the input: surface it and route to `/add-feature`, which owns the integration.

### Sibling census (sets the mode for the whole run)

Count sibling CRUD pages in the same admin area, then take exactly one branch — the premise says "siblings are the truth" in the plural, and the truth is different at each count:

| Siblings | Mode | What it changes |
|---|---|---|
| **0** | `ask` | No shape to mirror. Ask the shape questions once, up front (dialog vs page, pagination side, form + table library), and record the answers as this area's first CRUD shape. The Phase 4 sibling-shape halt is **declared not-evaluated**, never silently skipped. |
| **1** | `mirror-single` | Mirror that sibling and **name it**. The Phase 4 halt runs against `n=1` — a weaker gate, not an absent one. Report reads `siblings compared: 1 (<path>)`. |
| **≥2, agreeing** | `mirror` | The default. Full halt as written. |
| **≥2, disagreeing** | `mirror-newest` | Tie-break below. |

**Tie-break when siblings disagree.** In a two-year-old admin area the older page uses a dialog and the newer a route; one is optimistic and one is not. Resolve **per axis, not per file**: for each disputed axis (create surface, pagination side, optimistic-update, caching hook, wrapper set) the **most recently modified** sibling wins — `git log -1 --format=%cI -- <path>` per candidate. Then **report the divergence**:
`sibling divergence: create surface (dialog @ <old-path> vs route @ <new-path>) -> took route (newest)`
A divergence resolved silently is drift the next run re-resolves the other way. Consolidating the drift that already shipped is not this command's job (see the creation-time-only bullet in Phase 4).

### The rest of Phase 1
- Entity name (singular).
- List endpoint path; confirm `POST/PATCH/DELETE` exist (read OpenAPI spec / controller).
- Fields with type + validation; display columns; search fields — **minus anything the sensitivity gate marked non-renderable or non-searchable.**
- **Cross-row exclusivity** — is any field exclusive across the collection (one default, one primary, one active)? Every "yes" is an action in the Phase 4 store contract.
- Confirm: standard CRUD really fits, or is this bespoke?
- **Sensitive-entity halt — run this BEFORE any form is scaffolded.** The bespoke test above asks
  about SHAPE (wizard / kanban / drag-drop) and passes almost any regulated entity straight through.
  Shape is not the only reason CRUD is wrong. If the entity carries a value the application must
  never receive, store or re-display, a standard create/edit form is the wrong artifact no matter
  how ordinary the shape looks. Ask, per field: *may this application legitimately receive this
  value?*
  - **Payment instruments** — a card number (PAN), CVC or full expiry must be collected by the
    provider's hosted field, iframe or Element, never by a form this command scaffolds. Doing so
    moves the merchant from SAQ-A to SAQ-D. There is also no edit: a PAN cannot be PATCHed. "Edit"
    for a stored card means billing address and default-flag only, and "delete" means detach at the
    provider — which must be refused while a dependent record (an active subscription) still points
    at it.
  - **Credentials and secrets** — passwords, API keys, tokens, recovery codes: write-only, never
    rendered back, and never a column in the list view.
  - **Government and health identifiers** — national ID, tax ID, and anything in a regulated health
    or biometric category: these are storage-and-retention decisions before they are form decisions.
  If any field trips this: HALT and route to `/add-feature`, which can carry the provider
  integration and the non-CRUD lifecycle. Say WHICH field tripped it — an unexplained halt reads as
  a bug and gets overridden.
- **The mutation set is not always five.** The store slice below assumes `list / getOne / create /
  update / remove`. Cross-row state — "make this the default" — is the most-used action on many real
  admin surfaces and has no slot in those five. If the entity has one, name it now; retrofitting a
  cross-row mutation after the slice is written is a rewrite, not an addition.

## Phase 2 — Organize
- Verify API exists. If `POST/PATCH/DELETE` missing → STOP with "API needed first" message; route to `/add-feature`.
- Decide layout: dialog vs page for create/edit (mirror existing CRUD; on `mirror-newest`, the newest sibling wins this axis).
- If the sensitivity gate fired: locate the provider primitive the project already uses (the payment provider's element, the identity widget, the signed-upload helper) and mirror **that** integration's mount + token-return handling. A second integration mechanism for the same provider is the same defect as a second form library.
- Decide pagination: server-side default; client-side only for bounded reference data (< 1000 rows).
- Dispatch plan: `ui-architect` for file list + state shape; `api-architect` *(backend pack)* only to confirm the contract is sufficient — **and only when that pack is co-installed**. Absent → read the endpoint's controller signature + DTO directly and record `contract check: inline (backend pack absent)`. Never resolve this step to nothing.

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
- **Delete** — confirmation dialog or undo-toast per repo convention; never silent. **And blocked before it is confirmed.** A row something live still points at — the card funding an active subscription, the address on an open order, the last admin on a tenant — is not a confirmable delete, it is a refused one. Ask the contract whether this row is deletable (a `409` on delete, a `can_delete` flag, a dependent count the DTO exposes) and render the **blocked reason** in place of the confirm dialog. Where the contract exposes no such signal, say so in the report — `delete-dependency check: unavailable (no contract signal)` — rather than shipping a dialog that promises a delete the server will refuse. Where the sensitivity gate fired, the delete also revokes at the provider before the local row goes.
- **Store slice** — the five row verbs (`list`, `getOne`, `create`, `update`, `remove`) + paginated list state, **plus this entity's cross-row actions.** Five verbs is the floor, not the shape of CRUD. The moment one row's state depends on another's — `setDefault` (default card, primary address), `activate` (one live plan), `reorder` (explicit rank), `archive`-with-successor — a per-row `update` cannot express it: one user action changes **two** rows, so the action belongs on the slice and must settle both on success. A naive optimistic `update` here leaves two rows each claiming to be the default; either re-read the affected pair from the server or patch both locally, and mirror whichever the siblings do. Phase 1 § Cross-row exclusivity is where the list comes from; every entry there is one store action here **and** one row action on the list surface.
- **Service** — typed methods against shared DTO.
- **Routes** — list + create + edit, with auth/permission guards copied from sibling.
- **i18n** — keys for every label, button, validation message, empty state, in EVERY locale.
- **Tests** — list (renders, paginates, filters), form (valid + invalid submit), delete (confirms + executes).
- **List→detail prefetch** — list rows prefetch the detail/edit route on hover/intent (the hot nav path: list→detail is THE fast page-to-page case) via the framework's nav primitive. Mirror how siblings prefetch; framework specifics in `references/<framework>.md`, audit via the `navigation-speed` skill.
- **Instant loading skeletons** — the list AND the create/edit page paint an instant, layout-stable loading skeleton (no CLS), not a spinner. Mirror the sibling skeleton shape; per `frontend-principles.md` (instant layout-stable skeleton on navigation).
- **Virtualize large lists** — a list likely rendering > ~100 visible rows VIRTUALIZES (windowed render) in addition to server-side pagination, mirroring sibling virtualized lists; per `frontend-principles.md`.
- Run lint + tests scoped to new files; iterate to green.

### Sibling-shape mechanical halt (mandatory, all tiers)

Before declaring success, compare the new CRUD bundle against ≥2 sibling CRUD pages in the same admin area. For each gap, return one of: `closed` (matches sibling shape), `still-open` (divergent), `regressed` (introduced a new break on an unrelated axis).

**Halt if any of:**

- Uses raw framework components where the project's shared wrappers exist — a raw modal, paginator, form or dropdown where the repo ships a wrapper for it. (Name the repo's own wrappers from `_extracted-idioms.md`; the idiom names differ per project and the gate is the bypass, not the spelling.)
- Hand-rolls list + form state where siblings use the project's CRUD / form composables — silent divergence in a codebase that has one.
- Calls the HTTP client directly where siblings extend the shared CRUD service.
- Uses a plain mount hook where siblings use the **cache-aware activate hook** on the list page — siblings keep the list alive across navigation, the new page silently re-mounts and re-fetches. Frameworks without a keep-alive/activate concept satisfy this by mirroring whatever refetch policy the siblings' query layer declares; the halt is the divergence, not the hook name.
- i18n keys present in the pivot locale but missing in declared alt locales — a silent break in the alt locale.
- Default-true wrapper props left implicit — removing a handler does NOT hide the underlying button; pass the explicit `false` for delete / create / export / bulk-action affordances.
- Optimistic-update mismatch — siblings don't use optimistic; new page does (or vice versa). Partial adoption is worse than none.
- Form library mismatch (zod into a yup repo, react-hook-form into a vee-validate repo) — reject.
- **A sensitive field reached a repo-owned surface** — an input bound to the repo's schema, a table column, a search/filter field, a fixture, a log line, an error message, or an analytics payload, where Phase 1's gate marked it non-renderable. This halt outranks sibling-mirror: a sibling that already does it is a defect to report, not a shape to copy.
- **Cross-row exclusivity implemented as a per-row `update`** — a "make this the default" action that patches one row and leaves the previously-default row untouched in the store. Two rows change or the halt fires.
- **Delete ships with no dependent check and the contract exposes one** — a confirm dialog in front of a delete the server will refuse with a `409`.
- Permission gate on route but not on action buttons — leak via direct URL or component remount.
- List→detail navigation doesn't prefetch the detail/edit route on hover/intent where sibling CRUD lists do — the hot nav path stays cold.
- Loading skeleton missing or unsized (CLS on first paint) on the list or the form where siblings paint an instant layout-stable skeleton.
- A list likely > ~100 visible rows isn't virtualized where siblings virtualize windowed rows.
- **Table semantics missing on the list surface** — a data table with no `<caption>` (or `aria-label`), no `scope="col"`/`scope="row"` on its header cells, and no `aria-sort` on the column the user just sorted by. Sighted users read the sort arrow; screen-reader users get nothing. If siblings ship a shared table wrapper that already handles this, the halt is "you bypassed the wrapper"; if nothing in the repo does it, this is the first table to fix it and it says so in the report.
- **Creation-time only.** This gate compares the NEW bundle against its siblings. Consolidating drift that already shipped across many files is not this command's job — that is `ui-design-sweep`'s `unify-component` verb *(ui-ux pack)* or the core `/unify-surfaces`.

**Hard rule:** `gap_count_in != gap_count_closed` → HALT. Surface the open list and ask the user: refix, escalate to next tier, or accept. Any `regressed` → HALT.

**Whether that rule is evaluable is set by the Phase 1 sibling census, and the mode is printed either way:**

- `mirror` / `mirror-newest` (`n≥2`) — fully evaluable; HALT as written.
- `mirror-single` (`n=1`) — evaluated against the one sibling. A gap is still a gap and still HALTs; the report reads `siblings compared: 1 (<path>)`.
- `ask` (`n=0`) — there is nothing to compare against. `gap_count` is `n/a` and the report says `sibling-shape halt: n/a (first CRUD in area)`; the Phase 1 answers become the recorded shape. A hard rule that quietly cannot be computed is worse than either outcome, because it reads as a pass.

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
- Delete is reversible (soft-delete + undo) or confirmed (modal); never silent permanent delete — **and blocked, with a reason rendered, when a dependent record exists.**
- Sensitivity branch (only when Phase 1's gate fired): grep the generated bundle for the sensitive field names. Zero hits in inputs, columns, filters, fixtures, snapshots, log lines and analytics payloads, or the run does not close. The create surface mounts the provider primitive and the store holds a token, not a value.
- Hardcoded strings → all routed through i18n.
- **Nav-speed sign-off** — dispatch the `navigation-speed` skill on the list→detail surface (verify detail/edit prefetch on intent, bfcache safety — no unload/beforeunload, instant layout-stable skeleton on navigation). If the list is SSR with a slow query, also dispatch the `streaming-ssr` skill to stream the shell and cut TTFB. Enforces `frontend-principles.md` route-prefetch + stream-the-shell + instant-skeleton + bfcache MUSTs.
- **Observability sign-off** (gated on what the project ships — check `.claude/codebase-profile.md` / `CLAUDE.md`): error boundary / error-tracking captures errors from the list + form + delete routes the way siblings wire it; route-level perf signal (web-vitals / RUM) + CRUD analytics events added if siblings of this surface emit them. If the project ships NO observability layer: note `observability: none configured` in the report — explicit, never silent.

## Phase 7 — Improve
- `/learn-from-task` — capture CRUD-shape conventions confirmed.
- If 3+ entities now share the same CRUD scaffold → queue to `ai/patterns/crud-page.md` as a project pattern (or refresh existing).
- If form library duplicated logic surfaces (date pickers, file upload) → queue extraction proposal.

## Output format
```
## /add-crud-page — <Entity>

Phase 1 (Understand): API verified; standard CRUD fits
  data-sensitivity: none  (or: <class> — create via <provider primitive>;
                           editable subset = <fields>; non-renderable = <fields>)
  sibling census:   3 found -> mode = mirror
  divergence:       none  (or: <axis> (<old> vs <new>) -> took <newest>)
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
  sibling-shape halt: 4 gaps in / 4 closed (siblings compared: 3)
  delete-dependency check: contract exposes can_delete -> blocked-reason rendered
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
- **Scaffolding a sensitive field because its shape looked standard** — the walk this command is built to refuse: a "saved payment methods" entity is not a wizard, not a kanban and not drag-drop, so a shape-only gate waves it through and the sibling mirror produces a repo-owned card-number input bound to the repo's validation schema. Shape is the second question; Phase 1's first block is the first.
- **Cross-row mutation squeezed into `update`** — "make this the default" patches one row, the previously-default row keeps its flag, and the list shows two defaults until a refetch.
- **Delete confirmed, then refused by the server** — a `409` surfaced as a toast after the user already confirmed, because nothing asked whether the row was deletable.
- **`n=1` treated as `n≥2`** — the sibling-shape halt reports a `gap_count` it never computed. Print the census mode or the number is decoration.

## Related

### Sibling commands — where the boundary falls
- `/add-page` — one route. This command **supersedes** it for a list + form + delete bundle on one entity; running both produces two competing shapes for the same entity.
- `/add-component` — authors the shared wrappers this command mirrors rather than invents. A missing modal / paginator / form wrapper is that command's job first; bypassing the wrapper is a halt here.
- `/add-feature` — the escalation target named twice in § When to use / NOT to use: missing `POST/PATCH/DELETE`, or a bespoke flow (wizard / kanban / drag-drop). A hand-off, not an alternative.
- `/a11y-audit` · `/i18n-audit` — read-only. The table-semantics halt (`<caption>`, `scope`, `aria-sort`) and the alt-locale halt here are the creation-time subsets of those sweeps.

### Skills this command dispatches (and when)
- `navigation-speed` — Phase 6 sign-off on the hot list→detail path: row prefetch on intent, bfcache safety, instant layout-stable skeleton.
- `streaming-ssr` — Phase 6, only when the list is SSR with a slow query: stream the shell, cut TTFB.
- `lcp-audit` — LCP priority hints for the list / detail above-the-fold.

### Patterns actually read
- `forms.md` — the create/edit half: one library per repo, schema-driven validation, server-error mapping, and the § Accessibility contract behind the form halts.
- `auth-session-client.md` — read when the sensitivity gate fires on a credential or a third-party token: it owns the client-side handling of values the repo must hold by reference rather than by value.
- `i18n.md` — the key structure and ICU plural categories behind the "`en.ts` ✓, `ar.ts` ✗" halt.
- `list-virtualization.md` — its detectors and scroll-restoration rule are what Phase 4's "virtualize a list likely > ~100 visible rows" and the matching halt are graded against.

### Rules
- `.claude/rules/frontend-principles.md`
