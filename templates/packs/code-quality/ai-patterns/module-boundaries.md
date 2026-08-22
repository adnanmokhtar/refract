---
name: module-boundaries
description: Where new code lives and what it may import — module homes, public surfaces, layer direction, and the mechanical enforcement that stops all three from rotting.
kind: ai-pattern
pack: code-quality
---

# Pattern: Module Boundaries and Layer Direction

## Context

Load this when you are **placing** code — starting a feature, extracting a module, reviewing an import that crosses a boundary, or arguing about whether something belongs in `shared/`. The always-loaded `engineering-principles.md` carries the two invariants (every feature has a module home; cross-module access goes through the public surface). This file carries the reasoning, the judgement calls, and the enforcement wiring, which are needed at placement time and not before.

**Applies when**: the project organises code into modules / packages / bounded contexts, and/or runs a layered backend (Controller→Service→Repository, MVC, Clean, hexagonal). Skip for single-folder scripts, flat monolithic layouts, actor-model, CQRS+event-sourcing, or functional-core/imperative-shell codebases — for those the boundary that matters is a different one, and forcing this shape on them is the failure mode, not the fix.

## Where a feature lives

- **Locate the home before writing.** Loose files at repo root, or in `utils/` / `shared/` / `common/` / `misc/`, are the failure mode this pattern prevents — they accumulate as debt no later refactor pays back, because nothing ever owns them. New domain → plan the module first, and record an ADR if the boundary is architectural. Module assignment is tracked in `ai/modules.md`.
- **Each feature has a single entry point.** One module, one route group, one façade — not "we touched 7 files and changed 4 conventions". Single entry point means a single place to read to understand the feature, and a single place to change to remove it.
- **Boundaries are explicit, not implied.** Each module has a documented public surface — the `index.ts` / `__init__.py` / package exports / `mod.rs`. Everything else is private until exported. The public surface is the team's promise; the internals are the team's freedom to refactor. Reaching into another module's `internal/` / `_private/` is not a shortcut, it is a future breakage scheduled for whenever those internals change.

### The `shared/` test

A new `shared/` or `utils/` folder is a smell, and the question that resolves it is not "is this reusable?" — almost everything is. It is: **can you name the concept?** If the code has a name of its own (`id-generation`, `money`, `time`, `result-types`), it is genuinely cross-cutting and gets its own named module. If the best name you can find is "helpers", you are avoiding the work of deciding which module owns it. Reviewers reject a new bucket, or growth of an existing one, without an ADR saying which of the two it is; there is no automated folder-size check, so review is the mechanism.

## Layer direction

The rule is one-directional dependency, not four named boxes. Controllers depend on services; services depend on repositories; repositories depend on the DB. What that buys is swapability: REST→gRPC, ORM→another ORM, real DB→fake in tests, each without rewriting the others. A project whose layer names differ (use case, interactor, application service, command handler) has the same rule under different nouns.

| Layer | Owns | Does not own |
|---|---|---|
| Controller / handler | Parse input, call one service, format output | Business decisions, DB access, conditionals beyond input validation |
| Service / use case | The decision — this is where business logic lives | Transport concerns, query construction |
| Repository / DAO | Query construction, mapping to domain types | Business logic, orchestration across aggregates |

The violation that actually ships is **data access from a controller or a view**, usually introduced as "just this once, for performance". There is never a single bypass; the second one always follows, and it cites the first as precedent.

## Enforcement is mechanical, or it is aspirational

A boundary rule no tool checks gets quietly broken, and the breakage is invisible in review because each individual import looks reasonable. Wire a boundary linter in CI and fail the build on cross-layer or cross-module-internal imports. The tool depends on the ecosystem — `dependency-cruiser` (TS/JS), `import-linter` (Python), `ArchUnit` (Java/Kotlin), `arch-go` (Go), Nx `@nx/enforce-module-boundaries` in an Nx workspace, Bazel visibility, Go `internal/`, Rust workspace members — but the wiring is the same shape everywhere: declare the allowed edges, deny the rest, run it in CI rather than on request.

Two adjacent enforcement points that are review-only, and honest about it:
- **New patterns need an ADR.** The PR template carries an "ADR for new pattern?" checkbox; reviewers reject a PR that introduces a shape the codebase does not already have without an `ai/decisions/<NNNN>-*.md`.
- **Convention drift** is reported by `/setup-project-health`, which diffs `ai/conventions.md` against the working tree.

## Common mistakes

- **Treating the layer names as the rule.** A project with `controllers/`, `services/` and `repositories/` folders and business logic in all three has the layout without the rule. The check is the dependency direction, not the directory listing.
- **Declaring a public surface nobody uses.** A barrel file that re-exports everything internal is not a boundary; it is a boundary-shaped file. If every symbol is exported, nothing is private and the promise is empty.
- **Extracting a module for reuse rather than for ownership.** Modules exist so one team/owner can change something safely. "Two callers exist" is not a module; a nameable concept with its own invariants is.
- **Forcing this pattern on a codebase it does not fit.** Read the **Applies when** clause. A functional-core codebase annotated "Not applicable" by Phase 4.6 is the correct outcome, not a gap to close.

## Related

- `.claude/rules/engineering-principles.md` — the always-loaded invariants this pattern explains.
- `architectural-diagnosis` (skill) — detects the violations (layer inversion, god module, cyclic dependency) that this pattern defines.
- `@refactorer` — applies `move-to-module` once a violation is found; it does not decide the boundary.
- `ai/modules.md` · `ai/decisions/` — where module assignment and boundary ADRs are recorded.
