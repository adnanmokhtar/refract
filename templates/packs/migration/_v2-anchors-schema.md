# V2 anchors — schema

Every project running the migration pack declares an `ai/migration/_v2-anchors.md` file that the validator + agents READ to know what's project-specific.

Without it, the validator falls back to **defaults** suitable for Vue 3 + TypeScript front-end repos. With it, the validator becomes project-shape-agnostic.

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

| Raw / forbidden | Wrapper to use | Reason |
|---|---|---|
| `<Dialog>` | `<BaseModal>` | unified header + RTL + focus trap |
| `<Paginator>` | `<CrudPaginator>` | wired to useCrud |
| `<InputSwitch>` (in forms) | `<StatusSwitch>` | typed + label-aware |
| ... | ... | ... |

## Shared composables (open-coded → composable map)

| Open-coded fingerprint | Composable to use |
|---|---|
| `reactive({ items: [], page: 1, perPage: ..., total: ... })` | `useCrud` / `useTable` |
| Country → state → city dropdown chain | `useGeoCascade` |
| Form values + Yup schema + setFieldValue | `useForm` |
| ... | ... |

## Layering rules (forbidden import directions)

| Layer | May import from | May NOT import from |
|---|---|---|
| Components (`<v2_root>/**/*.vue`) | composables, services, types, shared/ | apiClient, axios, other modules |
| Composables | services, types, core/ | components, pages |
| Services | core/ (apiClient), types | vue, vue-router, vue-i18n, pinia |
| Core | (nothing — leaf) | vue ecosystem |

## Lifecycle anchors

```yaml
keepalive_layout: src/shared/layouts/MainLayout.vue
keepalive_exclude_pattern: noCache\s*=\s*\[([^\]]+)\]
```

The validator reads this to know which pages bypass KeepAlive (and thus may safely use `onMounted` instead of `onActivated`).

## V1 fingerprints to forbid in V2 (project-specific)

```
forbidden_patterns:
  - { regex: '<Dialog\b', severity: fail, message: "raw <Dialog> — use <BaseModal>" }
  - { regex: ':label="\$t\(', context: '<FormField|<TranslatedInput', severity: fail, message: "FormField double-translation" }
  - { regex: '<div class="col-(md|sm|lg)-[0-9]+[^>]*>\s*<FormField', severity: fail, message: "wrapper col around FormField" }
  - { regex: 'phone-row', severity: warn, message: "hand-rolled phone field — use <PhoneInput>" }
  ...
```

The defaults in `validate-migration-artifacts.sh § check_v2_structure` are suitable starting points; projects override or extend.

## Required V2 patterns (positive — must appear in new V2 code)

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
api_contract_repo: ../capsolah-api/
api_contract_command: /sync-contract
```

The validator runs `/sync-contract` checks before allowing a feature to advance state.
