---
project_kind: mixed
roots:
  - { path: v2/apps/api, kind: backend-nest }
  - { path: v2/apps/web, kind: frontend-react }
  - { path: v2/packages/contracts, kind: backend-nest }
  - { path: v2/scripts, kind: data-pipeline }
  - { path: v2/deploy, kind: backend-other }
v1_root: v1
v1_remote: origin
v1_branch: main
v2_root: v2
parity_test_root: v2/apps/api/test/parity
ledger_path: ai/migration/ledger.md
contracts_dir: ai/migration/contracts
plans_dir: ai/migration/plans
audits_dir: ai/migration/audits
perf_dir: ai/migration/perf-decisions
runbooks_dir: ai/runbooks
---

# Project anchors — Norrow Supply portal (Laravel 11 → NestJS 11 + React)

`roots:` declares one kind per V2 root (the per-root extension of `project_kind`, eval batch 6
item 2); `project_kind: mixed` stays for validators that read the single key.

## Gold-standard files (per feature shape)

| Shape | Path | Notes |
|---|---|---|
| CRUD controller (API) | v2/apps/api/src/orders/orders.controller.ts | `@ZodBody`/`@ZodQuery`, `@Permissions` per handler |
| Account-scoped entity | v2/apps/api/src/invoices/invoice.entity.ts | `@scoped.AccountScoped()` = V1 `AccountScope` |
| Soft-deletable entity | v2/apps/api/src/inventory/stock-item.entity.ts | `@scoped.SoftDeletable()` = V1 `SoftDeletes` |
| Subscriber (V1 observer) | v2/apps/api/src/notifications/ticket-notifications.subscriber.ts | skips replicated writes during dual-run |
| Transaction with after-commit effect | v2/apps/api/src/common/tx-runner.ts | `onCommit` = Laravel `->afterCommit()` |
| List page with URL state | v2/apps/web/src/pages/InvoicesPage.tsx | `useUrlState` = V1 GET filter form |
| Backfill | v2/scripts/backfill/orders.backfill.ts | checkpointed, throttled, upsert on `legacy_id` |

## Layering rules (forbidden import directions)

| Layer | May import from | May NOT import from |
|---|---|---|
| `v2/apps/web/src/pages/**` | `lib/`, `@norrow/contracts` | `v2/apps/api/**` |
| `v2/apps/api/src/<module>/**` | `common/`, `config/`, other modules' services | `v2/apps/web/**` |
| `v2/packages/contracts/**` | `zod` | everything else |

## ADR catalog reference

```
adr_dir: ai/decisions/
adr_pattern: ADR-[0-9]{4}
```

## Backend-specific

```
aggregate_root_pattern: '@Entity\('
repository_interface_suffix: 'Repository'
command_handler_suffix: 'Service'
```
