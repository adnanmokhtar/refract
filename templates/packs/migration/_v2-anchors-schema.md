# V2 anchors — schema

Every project running the migration pack declares an `ai/migration/_v2-anchors.md` file that the validator + agents READ to know what's project-specific.

> **All inline examples in this schema use Vue 3 + PrimeVue + TypeScript syntax purely as illustration** — they are NOT defaults the validator assumes. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND`; it applies the per-stack pack's fingerprint set (`frontend/rules/migration-frontend.md` for frontend-vue3 etc.). Substitute your project's actual primitives when filling in the anchor file.

## File location

```
<project-root>/ai/migration/_v2-anchors.md
```

## Required sections

```yaml
---
project_kind: frontend-vue3 | frontend-react | frontend-svelte | frontend-nuxt | backend-nest | backend-laravel | backend-python | api-other
v1_root: <path>                     # absolute or repo-relative; e.g. ../tenant-portal/
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

> *Vue 3 + PrimeVue example — substitute your stack's primitives.*

| Raw / forbidden | Wrapper to use | Reason |
|---|---|---|
| `<Dialog>` (PrimeVue) | `<BaseModal>` (project wrapper) | unified header + RTL + focus trap |
| `<Paginator>` (PrimeVue) | `<CrudPaginator>` (project wrapper) | wired to useCrud |
| `<InputSwitch>` raw in forms | `<StatusSwitch>` (project wrapper) | typed + label-aware |
| ... | ... | ... |

## Shared composables / hooks (open-coded → reusable map)

> *Vue 3 example — substitute your stack's hook / composable / service convention.*

| Open-coded fingerprint | Reusable to use |
|---|---|
| `reactive({ items: [], page: 1, perPage: ..., total: ... })` | `useCrud` / `useTable` |
| Cascading dropdown chain (country → state → city) | `useGeoCascade` (or stack equivalent) |
| Form values + schema + setFieldValue | `useForm` (or `react-hook-form` / `formik` / etc.) |
| ... | ... |

## Layering rules (forbidden import directions)

> *Vue 3 frontend example — substitute your stack's layer names + file extensions. The shape is universal: name each layer, what it MAY import from, what it MUST NOT.*

| Layer | May import from | May NOT import from |
|---|---|---|
| Components (e.g. `<v2_root>/**/*.vue`) | composables / hooks, services, types, shared/ | http client, other modules |
| Composables / hooks | services, types, core/ | components, pages |
| Services | core/ (http client), types | framework runtime, router, state library |
| Core | (nothing — leaf) | framework ecosystem |

## Lifecycle anchors

> *Vue 3 + KeepAlive example. Other frameworks: declare the equivalent route-cache mechanism (Next.js route cache, Nuxt page cache, React Router data revalidation, etc.).*

```yaml
keepalive_layout: <path to project's route-cache layout file>
keepalive_exclude_pattern: <regex matching the cache-exclude declaration>
```

The validator reads this to know which pages bypass route caching (and thus may safely use the mount-only hook instead of the mount-AND-reactivate pair).

## V1 fingerprints to forbid in V2 (project-specific)

> *Vue 3 + PrimeVue example. Stack-conditional fingerprints live in the per-stack pack rule (`frontend/rules/migration-frontend.md` enumerates the frontend ones); projects extend by appending entries here.*

```
forbidden_patterns:
  - { regex: '<Dialog\b', severity: fail, message: "raw <Dialog> — use <BaseModal>" }
  - { regex: ':label="\$t\(', context: '<FormField|<TranslatedInput', severity: fail, message: "FormField double-translation" }
  - { regex: '<div class="col-(md|sm|lg)-[0-9]+[^>]*>\s*<FormField', severity: fail, message: "wrapper col around FormField" }
  - { regex: 'phone-row', severity: warn, message: "hand-rolled phone field — use <PhoneInput>" }
  ...
```

The defaults in `validate-migration-artifacts.sh § check_v2_structure` are stack-conditional via `PROJECT_KIND`; projects override or extend.

## Required V2 patterns (positive — must appear in new V2 code)

> *Vue 3 example.*

```
required_patterns:
  - { in: '<v2_root>/**/*Page.vue', regex: '\bonActivated\(', message: "page must use onActivated for KeepAlive" }
  - { in: '<v2_root>/**/services/index.ts', regex: 'BaseCrudService', message: "CRUD services must use BaseCrudService" }
```

## ADR catalog reference

```
adr_dir: ai/decisions/
adr_pattern: ADR-[0-9]{3,4}
```

## Backend-specific (only if `project_kind: backend-*`)

```
hex_layers:
  domain: src/<feature>/domain/
  application: src/<feature>/application/
  infrastructure: src/<feature>/infrastructure/

aggregate_root_pattern: '@AggregateRoot'
repository_interface_suffix: 'Repository'
command_handler_suffix: 'CommandHandler'
```

## Cross-stack contract (only for repos depending on another)

```
api_contract_repo: <path-to-V1-api-repo>
api_contract_command: /sync-contract
```

The validator runs `/sync-contract` checks before allowing a feature to advance state.
