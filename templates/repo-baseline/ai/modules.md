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

When the architecture defines hard boundaries (clean-architecture layers, bounded contexts, public-vs-internal modules), enumerate them here.

**These two lines are executable.** `.claude/hooks/module-boundaries.sh` parses this section on every Edit / Write / MultiEdit and refuses the write when the incoming import crosses a boundary declared below — so keep the shape exactly as shown, backticks included. The module names must be names from the catalog table above; that table is where a name is resolved to a path.

- `<module-A>` MUST NOT import from `<module-B>` — reason: <one line>
- `<module-A>` MAY import from `<module-B>` only via `<facade-or-port>`

`MAY … only via` is enforced as the stricter reading: every route into `<module-B>` is refused **except** the named facade. That is what a port is for.

What the hook does NOT do, so you know where a human still has to look:

- **It reads the incoming edit, not the file on disk.** A crossing that was already committed does not block an unrelated edit to the same file — it is a refactor to schedule, not a reason to reject today's work.
- **TypeScript / JavaScript and Python only.** Any other extension is allowed without inspection.
- **It resolves relative specifiers and the `@/` `~/` `#/` sigils, and strips one leading `src/` / `app/` / `lib/`.** A build alias that RENAMES rather than shortens (`@core/*` → `src/billing/*` in `tsconfig.json`) is not resolved, and the hook stays silent rather than guessing.
- **It never invents a boundary.** No catalog row, no rule line, or no `ai/modules.md` at all → it exits without looking.

Bypass one session with `.claude/.no-module-boundaries`. If a boundary is simply wrong, change it here instead — deliberately, in its own commit, with the reason updated.

If the project has no declared boundaries, leave this section empty (do NOT invent constraints). An empty section disables the hook rather than blocking anything.

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
