# Modules

The map of every module / feature area in this project. **One row per module.** Auto-populated at `/setup-project` from `.claude/_extracted-codebase.md § Modules`. Hand-edited as the project grows.

> **Why this file matters**: Hard rule A16 says *every new file maps to a defined home in `ai/modules.md` BEFORE writing*. Without this map, agents and humans default to dropping new code into `utils/` / `shared/` / the repo root — the failure mode that produces the catch-all-folder problem. This file is the registry that prevents it.

Last updated: <YYYY-MM-DD>

---

## Module catalog

| Module | Path | Owns | Public surface | Cross-cuts |
|---|---|---|---|---|
| <name> | `<src/path/>` | <one-line responsibility> | <exported types / endpoints / events> | <auth, i18n, multi-tenant, logging, …> |

Add one row when a module is introduced. The five columns answer the questions an agent needs before adding code:

- **Module** — the name humans + commits use
- **Path** — where files actually live (use the real path, not `<placeholder>`)
- **Owns** — what business / technical concept this module is responsible for
- **Public surface** — what callers depend on (the contract)
- **Cross-cuts** — non-functional concerns this module participates in

## Module boundaries (which modules MUST NOT import which)

When the architecture defines hard boundaries (clean-architecture layers, bounded contexts, public-vs-internal modules), enumerate them here. Crossing a boundary is a code-review fail.

- `<module-A>` MUST NOT import from `<module-B>` — reason: <one line>
- `<module-A>` MAY import from `<module-B>` only via `<facade-or-port>`

If the project has no declared boundaries, leave this section empty (do NOT invent constraints).

## "Where does new code go?" — quick lookup

| New thing | Goes under |
|---|---|
| HTTP endpoint for `<feature-X>` | the module that owns `<feature-X>`'s primary entity (Owns column) |
| Background job for `<feature-X>` | same module, `jobs/` (or project's job convention) |
| Cross-feature shared utility | `shared/` ONLY when ≥2 modules already need it; ≥3 callers means promote to its own module |
| New entity / aggregate root | new module — open an ADR before adding |
| One-off script | `scripts/` (or project's script convention) — not a module |

## How to keep this current

- **Add a row** when a new module is introduced. Add the ADR link if the module's existence was a deliberate decision (`ai/decisions/NNNN-<slug>.md`).
- **Update a row** when a module's responsibility changes (e.g., `Owns` widens to include a new entity).
- **Remove a row** when a module is fully deleted. Note the removal in `ai/dynamic/changelog.md` so future agents don't grep for the dead path.
- **Run `/find-module <feature>`** before adding new code — it consults this file to suggest the right home.

## Anti-patterns this file prevents

- **Loose files at the repo root** ("just put it in `src/`")
- **`utils/` dumping ground** — utilities without a documented home accumulate forever
- **Drive-by module creation** — agent invents a new top-level dir without an ADR
- **Cross-module imports through internals** — bypassing the documented public surface

## See also

- `ai/architecture.md` — the layering strategy this module map sits inside
- `ai/business-domain.md` — entities + vocabulary; modules typically own one or more entities
- `.claude/codebase-profile.md § Modules` — the deeper extraction this file projects
- `ai/decisions/` — every module's existence-as-deliberate-choice should have an ADR
