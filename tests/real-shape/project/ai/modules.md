# Modules

## Module catalog

| Module | Path | Owns | Public surface | Cross-cuts |
|---|---|---|---|---|
| master | `apps/master/src/` | control-plane app | REST | auth |
| tenant | `apps/tenant/src/` | per-tenant app | REST | multi-tenant |
| shared | `libs/shared/src/` | cross-cutting primitives | DTOs, types | — |
| database | `libs/database/src/` | data access | repositories | — |

## Module boundaries (which modules MUST NOT import which)

- `master` MUST NOT import from `tenant` — reason: the control plane must not depend on a tenant runtime
- `tenant` MAY import from `database` only via `libs/database/src/index.ts`
