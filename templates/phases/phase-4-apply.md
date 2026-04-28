---
phase: 4
name: apply
applies-to-modes: [all]
inputs: [approved-plan, codebase-profile, selected-tracks]
outputs: [CLAUDE.md, ai/, .claude/, tool adapters when enabled]
exit-criteria: every planned artifact written; deterministic copy verified; idempotency markers in place
sub-phases:
  - 4.0  — pack-load preflight                                @templates/phases/phase-4.0-preflight.md
  - 4.1  — project-specific block authoring                   (inline below)
  - 4.2  — apply (COPY-mode + AUTHOR-mode + verification)     @templates/phases/phase-4.2-apply.md
  - 4-templates — generated-output template skeletons         @templates/phases/phase-4-templates.md
  - 4.6-DEEP — re-anchor Project-specific blocks (REFINE)     @templates/phases/phase-4.6-deep.md
  - 4.7-DEEP — refresh ai/ knowledge base (REFINE)            @templates/phases/phase-4.7-deep.md
  - 4.8-DEEP — re-sync tool adapters (REFINE)                 @templates/phases/phase-4.8-deep.md
adapter-detail: commands/setup-project-adapters.md (sibling command)
---

# Phase 4 — Apply

Phase 4 turns the approved plan into files on disk. It is split into five executable sub-phases plus a templates file:

| Step       | What it does                                                          | When        |
|------------|-----------------------------------------------------------------------|-------------|
| 4.0        | Pack-load preflight (refuses any pack without `_version.json`)        | always      |
| 4.1        | Project-specific block authoring                                       | always      |
| 4.2        | Deterministic copy (COPY-mode) + AUTHOR-mode emit + verify             | always      |
| 4.6-DEEP   | Re-anchor managed Project-specific blocks                              | REFINE only |
| 4.7-DEEP   | Refresh `ai/` knowledge base from deep extraction                      | REFINE only |
| 4.8-DEEP   | Re-sync tool adapters (lighter touch path; full detail in sibling)     | REFINE only |

Each sub-phase has its own frontmatter with inputs/outputs/exit-criteria. The `phase-4-templates.md` file is NOT an executable step — it holds the template skeletons (CLAUDE.md, conventions.md, mandatory pre-flight injection block, verification block) that the executable sub-phases consume.

## Phase 4.1 — Project-specific block authoring

Phase 4.1 writes the LEAD section of every generated artifact: the "you are the principal engineer of THIS project" block, anchored to the project's actual:

- module map (`ai/modules.md`)
- detected stack + base classes from `.claude/_extracted-codebase.md`
- conventions cited by file path + line number
- failure catalog references for architectural agents (rule A29)

This sub-phase is intentionally short — most of the heavy lifting is the deterministic pack copy in 4.2. The templates that get filled here are in `@templates/phases/phase-4-templates.md`.

Authoring constraints from the hard rules:

- **Never** ship a generated rule that omits the project-specific block (rule N16).
- **Never** invent symbols / paths / methods. AUTHOR-mode citations must trace to the extraction file (rule A12).
- **Always** map every new file to a defined home in `ai/modules.md` BEFORE writing (rule A16).

After 4.1 completes, 4.2 runs the deterministic copy pass. See `@templates/phases/phase-4.0-preflight.md` for the gate that must pass before any of this runs, and `@templates/phases/phase-4.2-apply.md` for the copy + author + verify cycle.

## Adapter detail

Multi-tool adapter logic (Cursor / OpenCode / Aider / Cline / Codex / Continue / Copilot / Gemini / Windsurf) is NOT in this file. It moved out in M2 to:

- `commands/setup-project-adapters.md` — re-sync command + per-adapter completeness contract.
- `templates/phases/phase-4.8-deep.md` — REFINE-time refresh path (refers to the sibling).
- `templates/tool-adapters/<tool>/` — per-tool emission contract.

This split keeps the core Phase 4 path focused on the source artifacts; adapters are a translation layer over that output.

## Idempotency

Every file Phase 4 writes is bracketed by managed markers per `@templates/idempotency.md`. A second run of `/setup-project` on the same repo produces an empty diff for the managed regions; user-authored content outside the markers stays byte-identical. Phase 5's checklist (C2) enforces this contract.
