---
name: promote-decision
description: Graduates a VALIDATED pending decision into a numbered ADR.
kind: command
allowed-tools: [Read, Grep, Glob, Edit, Write]
pack: learning
---

<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with `/setup-project --refine`)

> Auto-populated by `scripts/apply-anchors.sh` from `.claude/codebase-profile.md`. Round-one floor — `/setup-project --refine` deepens shallow blocks based on `compute-anchor-density` scoring.
>
> - **Architecture** (`.claude/codebase-profile.md:15`): Modular NestJS monolith: one module per folder under `apps/api/src/modules/`.
> - **Naming** (`.claude/codebase-profile.md:19`): kebab-case files with role suffixes (`*.service.ts`, `*.controller.ts`, `*.entity.ts`).
> - **Testing** (`.claude/codebase-profile.md:27`): Jest specs beside the code (`*.spec.ts`); e2e suites under `apps/api/test/`.
> - **Data access** (`.claude/codebase-profile.md:23`): MikroORM over MySQL 8; one `EntityManager` fork per request.
> - **Error handling** (`.claude/codebase-profile.md:31`): Services throw `DomainError` subclasses; `HttpErrorFilter` maps them to problem+json responses.
> - **Detected load-bearing idioms** (`_extracted-idioms.md`): `BaseRepository` (1 abstract base, extended per aggregate)
>
> - **Where this applies here** (`decisions`): `ai/_decision-index.md`, 1 file(s) in ai
> Cite-able sources: package.json, apps/api/package.json, apps/web/package.json, top-level: apps, packages, docs.

<!-- project-specific:end -->

# /promote-decision

Turn one VALIDATED entry of `ai/dynamic/decisions-pending.md` into an ADR.

## Steps

1. Read the pending entry and its implementations.
2. Pick the next free ADR number.
3. Fill the template: context, decision, consequences.
4. Write the ADR to `ai/decisions/<NNNN>-<slug>.md` from `ai/decisions/_template.md`.
5. Mark the pending entry PROMOTED with the ADR id.
6. Regenerate the decision index.
