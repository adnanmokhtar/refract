---
name: migration-frontend
description: Frontend-specific extensions to migration-discipline — the navigation-inventory axis, the per-axis density gates, and the V1→V2 anti-patterns that only exist while porting a UI. Stack examples are illustrative; substitute equivalents from your project's `_extracted-idioms.md`.
kind: rule
pack: frontend
severity: must (when a migration layout is detected)
applies-to: frontend-track, v1-to-v2-ports
extends: migration/rules/migration-discipline.md
---

> **STACK-AGNOSTIC**: Inline syntax in this doc is illustrative. Stack-specific primitives are filled by `/setup-project` Phase 4.6 from the project's `_extracted-codebase.md` / `_extracted-idioms.md`. `<TBD: ...>` placeholders survive until then. See also this pack's `STACK.md`.

# Frontend extensions to migration discipline

**This file owns ONE axis, and it is the half of a UI port that no source-level diff can see:**

> **The path a user takes to reach a feature is part of what V1 shipped.** A component that still exists in V2 is not a feature a user can still reach. Every automated parity signal — file diffs, primitive counts, component inventories — reads *existence*, so every one of them reports PARITY on a feature that has been made unreachable. That is why § Frontend audit axes opens with Section 0 rather than with fields.

Its neighbours own the rest and it never restates them: `frontend-principles.md` is what you must do in any frontend code, ported or not; `i18n.md` is the locale axis; the universal `migration-discipline.md` (migration pack) owns the state machine, contract, halts and gate. Like `migration-backend.md`, this rule is not always on — it ships only when a migration layout is detected (`_topics.md § migration-frontend`), so a project that is not porting anything pays nothing for it.

## Stack-aware primitive set (frontend)

`scripts/validate-migration-artifacts.sh § extract_inventory_primitives` counts primitives on both sides of a port and compares nine classes (the three form constituents fold into `form_total` and are skipped, so a form gap fires once, not three times). V2 under 70% of V1 on any compared class **fails** a PARITY verdict outright — *verdict contradicted by primitive inventory* — and otherwise falls through to DRIFT enumeration. Nothing self-promotes: a trivial-tier PARITY row drifting by 5 or fewer only warns, and raising the tier is a human call. The regex alternations that recognise each class across component frameworks and UI libraries live in that function and only there — a prose copy would be a second source of truth with nothing comparing the two, and no agent follows a regex anyway. What an agent follows is the mapping. **For this project's own primitives — its field wrapper, its button, its permission directive — read `_extracted-idioms.md`; do not recall them from whichever framework you saw most recently.**

| Primitive class | Shape (one example; the project's own is in `_extracted-idioms.md`) | Axis where the audit enumerates the gap |
|---|---|---|
| `route_def` | a router entry, or a file-system route | Section 0 — Navigation Inventory |
| `tabs` | a tab-group component, or an in-template tab array | Section 0 — Navigation Inventory |
| `input_html` | `<input>` / `<textarea>` / the project's text-field wrapper | Form fields |
| `form_total` | two-way bindings + form-state fields + child-component fields, folded into one count | Form fields |
| `dropdown` | `<select>` / the project's select or combobox wrapper | UI affordances / Form fields |
| `button` | `<button>` / the project's button wrapper | UI affordances |
| `click_handler` | a click / submit / change binding | Event handlers |
| `conditional_render` | the framework's conditional-render construct | Event handlers / Reactive lifecycle |
| `permission_gate` | the project's permission check, directive, or guard | Per-button permission gates |

## Frontend audit axes (when feature is a UI page / component / route)

The universal rule's 6 generic axes (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) are necessary but not sufficient for a UI port. Add these.

- **Navigation inventory (Section 0 — MANDATORY when the feature spans more than one page or any tabbed surface; TWO-LAYER scan)** — enumerate every user-clickable navigation target reachable from the module entry: top-level tabs, in-page sub-tabs, sidebar items, accordion groups gating distinct content, modal-shell tabs, inner-routes, and any other tab-shaped affordance. Layer-A-only is incomplete and HALTS.
  - **Layer A — Route tree**: read every router file in V1 and V2; build the hierarchy. Catches top-level tabs, route children, redirects.
  - **Layer B — Per-leaf template grep (MANDATORY)**: open EACH leaf Layer A found and grep its own template for tab components, `role="tab"` / `role="tablist"`, sidebar/menu config arrays, tab arrays iterated at template scope, nested router outlets, accordion title arrays. Every match is an additional nav leaf under that parent.
  - **Why both**: routes-only extraction misses in-component tab UIs — one marketing route rendering 14 platform tabs from a radio + conditional-render pattern in its own template. Without Layer B that route is marked PARITY and its 14 tabs were never compared.
  - Map V1 leaves to V2 leaves 1:1. "Reaches X via this tab in V1, that tab in V2" is parity; "via this tab in V1, scroll-to-section in V2" is not.
  - **Section 0 completion checklist (HARD GATE — the audit HALTS until every box is ticked and cannot advance to Section 1):**
    - [ ] V1 routes extracted from every router file
    - [ ] V2 routes extracted from every router file
    - [ ] **For EACH V1 route leaf: source opened + grep'd for tab patterns; matches enumerated**
    - [ ] **Same for V2**
    - [ ] V1 leaf set ↔ V2 leaf set diffed
    - [ ] **Every V1 leaf has a V2 equivalent OR is flagged DRIFT with a closure verb**
    - [ ] **Every V2-extra leaf flagged for a V1-parity decision**
    - [ ] **Unmapped V1 components: grep the V1 view folder for component files imported by no reachable route / tab / sidebar entry; flag as dead-code candidates**
- **Form fields** — name, type, validation (declared + inline), default, placeholder, required, disabled-when, hidden-when. Every field is a contract surface; a missing one is a silent break.
- **UI affordances** — every button, link, dropdown, modal trigger, upload control, toggle, copy button, detail link. Each has a permission gate, a handler, an observable effect.
- **Templated query params** — every param the page reads. V1's list call may send 6 and V2 send 4; the contract is *the union of what V1 sends*, verified by reading V1's call construction line by line.
- **Event handlers** — what each calls, with what args, and the side effect.
- **Per-button permission gates** — V1 may hide an action behind a permission check; V2 must render the same gate. A dropped gate is a security regression, not a UI nit.
- **Accessibility** — keyboard order, names on icon-only buttons, focus management on modal open/close. The parity test is an axe baseline plus a diff, not a re-audit; the depth grade is `@accessibility-auditor`.
- **DOM-equivalent** — semantically equal markup (`parity-testing.md`'s `dom-equivalent` tolerance class). Structural parity, not pixel parity.
- **Reactive lifecycle** — V1's mount-only fetch vs V2's mount-AND-reactivate where the framework caches routes; refetch on locale change and on tenant switch. Stale-on-tab-return is a tenant-leak vector, and it is also where a V1 timer or listener with no teardown becomes N running copies after the first cached resume.

**Density gates — where a prose verdict stops counting as a verdict.** Below the trigger, one sentence per axis is a valid finding. At or above it, `check_per_axis_enumeration` HALTS on a verdict with no table.

| Axis | Trigger (counted in the V1 file) | Table the audit must produce |
|---|---|---|
| Form fields | ≥ 5 form inputs | one row per V1 field, citing `<v1-path:line>` **and** `<v2-path:line>` |
| UI affordances | ≥ 3 (buttons + dropdowns + modal triggers + toggles) | one row per affordance, plus permission-gate and observable-effect columns |
| Event handlers | ≥ 3 distinct handlers | one row per handler, naming the function called on each side |
| Per-button permission gates | ≥ 1 gate on either side | one row per gate, with the gate expression verbatim on both sides |

PARITY requires every V1 row mapped. DRIFT lists the gap with a closure verb. A gate expression that differs between sides is P0/P1, never a NIT.

## Frontend anti-pattern catalogue (V1 → V2 hot list)

Five navigation drifts and one data-shape trap. **They live here rather than in `frontend-principles.md` because each is invisible to every check that reads for existence** — the component is present, the route resolves, the primitive counts match, and the feature is gone. Generic frontend failures a port also carries (fetch in a component, unsanitised HTML, missing lazy-load, logic in a template, an undebounced search input) are already MUSTs in `frontend-principles.md`; a port does not get a second copy of them.

| V1 → V2 anti-pattern | Why every automated signal misses it | Closure |
|---|---|---|
| **The Buried Tab** — V2 collapses V1 sub-tabs into scrollable sections inside another tab. | Every underlying component exists, so a source-only audit reports STRUCTURE_OK. What changed lives in no file. | Restore it as a discrete navigation surface (sidebar entry + route, or an in-page sub-tab). Leaving it buried needs an accepted ADR. |
| **The Fragmented Tab** — V2 splits one V1 tab into several separate routes. | Same class: every destination exists; the click path does not match. | Default closure is consolidating back to the V1 tab shape; an ADR carrying a `user_decision_quote` is the only alternative. |
| **The Consolidated Page** — a V1 standalone route becomes a tab inside another page, or the reverse. | A separate target has its own URL, back-button behaviour and direct-linkability; a tab click has none of the three. The component exists somewhere in V2, so parity is reported. | Revert to the V1 shape — page stays a page, tab stays a tab. Keeping the consolidation needs an ADR with `user_decision_quote`. |
| **The Layer-A-Only Scan** — an audit-process failure: the auditor extracts the route hierarchy and stops, skipping the per-leaf grep. | Routes are not tabs. The scan produces *high-confidence* false PARITY precisely on the components hiding the most surface. | Layer B is mandatory; Section 0 cannot complete until every Layer-A leaf has been opened and grep'd. |
| **The Zombie Tab Component** — V1 ships components no route imports and no reachable tab array renders, and the port makes them live V2 routes. | They exist in V1 source, so an inventory audit ports them as parity work. They were never reachable, so the port ADDS surface V1 users never had — the inverse failure, equally a violation of "V1 wins on observable behaviour". | Prove reachability before porting anything out of V1's view folder: imported by a router entry, OR rendered by a reachable tab array, OR conditionally rendered by a state a reachable interaction can produce. None of the three → dead code, do not port. |
| **The Two-Locale Submit Shape** — V1 submits translated fields as a flat fixed-key object and the port copies the shape. | It succeeds in every environment the developer tests, because those are the locales enabled there. | Match V1's wire shape exactly for parity, but build the object from the project's available-languages source. `i18n.md § Anti-patterns (named)` owns the general ban; what is migration-specific is that the wire shape is V1 contract and cannot be "improved" mid-port. |

## Frontend Transposition Trap fingerprints

`migration-discipline.md § Anti-patterns` defines the trap generically: a line-by-line copy of V1 instead of re-derivation against V2's gold standard. These are the frontend fingerprints `check_v2_structure` HALTs on (stack-conditional via `PROJECT_KIND`). Each is legal code that was *correct inside V1's architecture*, which is why it survives review.

- **Wrapper bypass** — a raw framework / UI-library primitive used where the project ships a wrapper: modal, paginator, dropdown, date, phone, currency-prefix, language toggle, form element, form-field, upload. The wrapper is where RTL, theme tokens, focus management, ARIA wiring and validation styling live, so bypassing it drops all five silently and passes review looking identical.
- **Double translation on a label prop** — a wrapper that translates internally must receive a bare key. Symptom: a missing-key warning plus a raw key rendered to a user.
- **A grid column wrapped around a field wrapper that already takes a column prop** — nested columns misalign labels and collapse children to arbitrary widths, with no error anywhere.
- **A second authenticated HTTP client, or a manually constructed `Authorization` header** — either one creates a second interceptor chain and a second source of truth for the token, so the refresh queue silently stops covering part of the app.
- **Auth or session read from plain browser storage** outside the canonical token helper — detector and treatment in `ai-patterns/auth-session-client.md`.
- **V1's grid system carried over verbatim** — re-derive layout from V2's gold standard, never from V1's template.
- **A mount-only fetch on a page V2's router caches** — pair it with the framework's reactivate hook.
- **Hardcoded locale keys** — fixed-key translation initialisers, active-locale ternaries, per-language flat field names. `i18n.md` owns this; a port is where it arrives.

## Phase 3 (Retrieve) — frontend specifics

The universal Phase 3 mandates reading V2's gold standards before writing. For frontend the gold standard is *by page category*, and `_extracted-codebase.md § Gold standards` names the file for each: CRUD list page, detail / show page, dialog or form, composable / hook, service / data-access. Read the one matching what you are porting and mirror its shape — composition, prop naming for label / column / required / disabled, and which wrappers it substitutes for raw primitives.

Two non-obvious parts. **A dialog port reads at least two** gold standards, never one: a single dialog does not separate the repo's conventions from that dialog's accidents. And **a service port reads the module's own service plus the canonical base service**, because the module service usually shows only its overrides. Writing the `mapping/<feature>.md` artifact (required at every tier) is what proves the read happened.

## Cross-references

- Universal discipline: `migration/rules/migration-discipline.md` — state machine, contract, halts, gate. This file extends it and ships only alongside it.
- Frontend principles: `frontend/rules/frontend-principles.md` — what a port must satisfy *as frontend code*.
- Frontend i18n: `frontend/rules/i18n.md` — the locale axis, including the parity requirement `check_i18n_locale_parity` enforces (a key in one locale exists in all).
- Validator: `scripts/validate-migration-artifacts.sh § check_v2_structure` and `§ extract_inventory_primitives`.
