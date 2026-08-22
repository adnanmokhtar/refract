# V2 anchors — schema

Every project running the migration pack declares an `ai/migration/_v2-anchors.md` file that the validator + agents READ to know what's project-specific.

> **All inline examples in this schema are illustrative only** — they are NOT defaults the validator assumes. Concrete component / hook / library / template tag names belong in PER-STACK packs. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack pack's fingerprint set (e.g., `frontend/rules/migration-frontend.md` for frontend stacks, `backend/rules/migration-backend.md` for backend stacks). Substitute your project's actual primitives when filling in the anchor file.

## File location

```
<project-root>/ai/migration/_v2-anchors.md
```

## Required sections

```yaml
---
project_kind: frontend-vue3 | frontend-react | frontend-svelte | frontend-nuxt | backend-nest | backend-laravel
              | backend-python | data-warehouse | data-pipeline | mobile-flutter | mobile-react-native
              | mobile-native | api-other | mixed
v1_root: <path>                     # absolute or repo-relative; e.g. ../<frontend-v1>/
v2_root: <path>                     # repo-relative; e.g. src/
parity_test_root: <path>            # repo-relative; e.g. tests/parity/
ledger_path: ai/migration/ledger.md
contracts_dir: ai/migration/contracts
plans_dir: ai/migration/plans
audits_dir: ai/migration/audits
perf_dir: ai/migration/perf-decisions
runbooks_dir: ai/runbooks
---

# Project anchors — <project name>

## Gold-standard files (per feature shape)

| Shape | Path | Notes |
|---|---|---|
| CRUD list page | <path> | gold standard for /port-feature § Phase 3 read |
| Detail page | <path> | "  |
| Form dialog | <path>, <path> | at least 2 dialogs that demonstrate every shared form component |
| Composable (CRUD) | <path> | the canonical useCrud equivalent |
| Composable (form) | <path> | the canonical useForm equivalent |
| Service (CRUD) | <path> | the canonical BaseCrudService equivalent + 1 instance |
| Service (custom) | <path> | a non-CRUD service with manual HTTP |

## Shared component wrappers (raw-equivalent → wrapper map)

> *Illustrative example — substitute your stack's primitives. The shape is universal: name the raw library primitive, the project's wrapper around it, and why the wrapper exists.*

| Raw / forbidden | Wrapper to use | Reason |
|---|---|---|
| Raw modal/dialog primitive from the project's UI library | The project's modal wrapper | unified header + RTL + focus trap |
| Raw paginator primitive from the project's UI library | The project's paginator wrapper | wired to the project's CRUD primitive |
| Raw toggle/switch primitive used in forms | The project's typed status-switch wrapper | typed + label-aware |
| ... | ... | ... |

## Shared composables / hooks (open-coded → reusable map)

> *Illustrative example — substitute your stack's hook / composable / service / mixin convention.*

| Open-coded fingerprint | Reusable to use |
|---|---|
| Open-coded list state (items array + page + perPage + total) | The project's CRUD/table primitive |
| Cascading dropdown chain (country → state → city) | The project's geo-cascade primitive |
| Form values + schema + field-mutation pattern | The project's form-state primitive |
| ... | ... |

## Layering rules (forbidden import directions)

> *Illustrative example — substitute your stack's layer names + file extensions. The shape is universal: name each layer, what it MAY import from, what it MUST NOT.*

| Layer | May import from | May NOT import from |
|---|---|---|
| Leaf components / pages (e.g. `<v2_root>/**/*.<leaf-ext>`) | hooks / composables / mixins, services, types, shared/ | http client, other modules |
| Hooks / composables / shared logic | services, types, core/ | leaf components, pages |
| Services / data-access layer | core/ (http client), types | framework runtime, router, state library |
| Core | (nothing — leaf) | framework ecosystem |

## Lifecycle anchors

> *Illustrative example. Each stack has its own route-cache / data-revalidation mechanism — declare the equivalent in your project's anchors. See the per-stack pack rule for the concrete hook / lifecycle pair.*

```yaml

> **`project_kind` is a family prefix, not a closed list.** `validate_project_kind_strict()` in
> `scripts/validate-migration-artifacts.sh` accepts `frontend-*`, `backend-*`, `data-*`, `mobile-*`,
> `mixed` and `api-other`, and `extract_inventory_primitives()` branches on four families —
> **frontend** (`frontend-*` and `mixed`), **backend**, **data** and **mobile** — each counting a
> different primitive set. Any `<family>-<flavour>` value is legal; the values listed above are the
> ones in use. The suffix after the hyphen is documentation for humans, so a new stack does NOT
> need a schema change — only a correct family prefix.
>
> **Pick the prefix that matches the primitives you want counted, not the one that reads best.**
> `api-other` is accepted by the validator but matches no family branch: it falls through to the
> `*)` default, which counts **frontend** primitives (two-way form bindings, component tags,
> click handlers). An API-only migration declared `api-other` is therefore inventoried against primitives
> it does not have, and the tier promoter that fires when a primitive's V2 count is under 70% of
> V1's fires on that noise. Declare `backend-other` instead — it takes the `backend-*` branch.

route_cache_layout: <path to the project's route-cache / cache-shell layout file>
route_cache_exclude_pattern: <regex matching the cache-exclude declaration>
```

The validator reads this to know which pages bypass route caching (and thus may safely use the project's mount-only hook instead of the mount-AND-reactivate pair).

## V1 fingerprints to forbid in V2 (project-specific)

> *Illustrative shape only — fingerprints below are placeholders. Stack-conditional fingerprints live in the per-stack pack rule (`frontend/rules/migration-frontend.md` enumerates the frontend ones, `backend/rules/migration-backend.md` the backend ones); projects extend by appending entries here.*

```
forbidden_patterns:
  - { regex: '<RawModalPrimitive\b', severity: fail, message: "raw modal primitive — use the project's modal wrapper" }
  - { regex: '<wrapping-grid-class>\s*<FormField', severity: fail, message: "wrapper grid around shared field component" }
  - { regex: 'open-coded-phone-row', severity: warn, message: "hand-rolled phone field — use the project's phone-input wrapper" }
  ...
```

`validate-migration-artifacts.sh § check_v2_structure` **parses this `forbidden_patterns:` list at runtime** (via `load_project_anchors`) and, when non-empty, uses it INSTEAD of the built-in reference set — so detection is portable to any project (#13). Each entry must be `- { regex: '<rx>', severity: fail|warn, message: "<msg>" }`. When no `forbidden_patterns:` is declared, the script falls back to its built-in reference fingerprints (stack-conditional via `PROJECT_KIND`) and prints a notice recommending you declare your own.

## Required V2 patterns (positive — must appear in new V2 code)

> *Illustrative shape only — substitute your stack's primitives.*

```
required_patterns:
  - { in: '<v2_root>/**/*Page.<leaf-ext>', regex: '<project mount-AND-reactivate hook regex>', message: "page must use the project's mount-AND-reactivate hook pair" }
  - { in: '<v2_root>/**/services/<index-file>', regex: '<project base CRUD service symbol>', message: "CRUD services must use the project's base CRUD service" }
```

## ADR catalog reference

```
adr_dir: ai/decisions/
adr_pattern: ADR-[0-9]{3,4}
```

## Backend-specific (only if `project_kind: backend-*`)

> *Illustrative shape only — substitute your stack's domain layering convention. See `backend/rules/migration-backend.md` for stack-specific specifics.*

```
hex_layers:
  domain: <v2_root>/<feature>/domain/
  application: <v2_root>/<feature>/application/
  infrastructure: <v2_root>/<feature>/infrastructure/

aggregate_root_pattern: '<project's DI/decorator marker for aggregate roots>'
repository_interface_suffix: '<project's repository suffix>'
command_handler_suffix: '<project's command-handler suffix>'
```

## Cross-stack contract (only for repos depending on another)

```
api_contract_repo: <path-to-V1-api-repo>
api_contract_command: /sync-contract
```

The validator runs `/sync-contract` checks before allowing a feature to advance state.
