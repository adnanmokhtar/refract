---
name: extract-project-context
description: GREENFIELD / Path-B project-context bootstrap — derives mission, domain, personas, KPIs, anti-goals from a user PROMPT when there's no codebase to read yet, and writes ai/project-goals.md + ai/users-and-personas.md + ai/business-domain.md. For EXISTING codebases the canonical pipeline (extract-codebase-overview → extract-business-context → Phase 4.7b) owns these targets; this skill is the greenfield path only.
---

# Skill: extract-project-context

The **greenfield / Path-B** project-context bootstrap. Without it, a brand-new project (empty folder + a prompt) has no durable record of "what is this" — every session re-derives it from the prompt. This skill captures the prompt-derived identity ONCE into durable files.

> **Scope boundary (existing-codebase path is owned elsewhere).** When the target already has source code, the canonical pipeline owns the `ai/` context targets:
> - `extract-codebase-overview` → `.claude/_extracted-codebase.md` (modules, stack, conventions, signals).
> - `extract-business-context` → `.claude/_extracted-business.md` (mission, personas, KPIs, business model, anti-goals).
> - Phase 4.7b → projects `_extracted-business.md` into `ai/project-goals.md`, `ai/users-and-personas.md`, `ai/business-model.md`, `ai/competitive-context.md`, `ai/roadmap.md`.
>
> That pipeline has mechanical halts + provenance markers this skill does not. **Do NOT run this skill's Path A on an existing codebase** — it would collide with those skills for the same files. This skill runs ONLY when there is no code to read (greenfield / CREATE mode from a prompt). Path A below is retained only for the degenerate case "a repo exists but has zero source files and the user is bootstrapping from a prompt" — in that case it behaves as greenfield.

## Premise

- Real source is the truth. Read READMEs + manifests + git history + sibling repos before populating any facet — and on greenfield, parse the prompt explicitly before falling back to defaults.
- Every fact written to `ai/business-domain.md` / `ai/project-goals.md` / `ai/users-and-personas.md` cites its source (README path, manifest field, commit signal, prompt line, or user answer).
- Inferred values are flagged as inferred with the signal they derive from; default values from the prompt are flagged as defaults the user can override.
- Empty extraction is honest — `_TBD — ask user_` for a facet no source covers is a valid output; the gap report surfaces them.
- Fabrication — inventing a persona from training-data tropes, a KPI from product-category memory, a competitor never named — locks the wrong identity into every downstream agent prompt.

## Mechanical halt

- Hand-wave facet content — `enterprise customers`, `typical SaaS users`, `appears to target`, `etc.`, `...`, a non-`_TBD_` answer without a cited source — REFUSE to write.
- Re-derive from a real source OR write `_TBD — ask user_` and surface the gap.
- If a source is genuinely absent (no README, no manifest description, no git history, no prompt content for the facet), record `<NOT-DETECTED: <facet>: <sources searched>>` in the report's gaps section.
- Never synthesize a persona / KPI / competitor / business-model to make the file feel complete — Path B's consolidated question is the only mechanism for filling unknowns, not LLM imagination.

## When to use

- **Greenfield only**: `/setup-project` in CREATE mode (Path B — prompt, no codebase). This is the canonical use.
- A degenerate "repo exists but has zero source files" bootstrap from a prompt — behaves as greenfield.

**Do NOT use** on an existing codebase — `extract-codebase-overview` + `extract-business-context` + Phase 4.7b own those targets (see the scope boundary at the top). On stale-context refresh for an existing project, run `/refresh-knowledge`, which re-runs the canonical pipeline, NOT this skill.

## Prerequisites

- Repository (or empty folder + user prompt).
- Read access to: `README*`, `package.json`/equivalent manifests, `.git/`, sibling repos in workspace if any.

## Procedure

### Path A — Degenerate bootstrap (a repo dir exists but has no source code to analyze)

> For a repo with real source, STOP — this is not your path. Use `extract-codebase-overview` + `extract-business-context`. Path A applies only when the only signals available are README / manifest / git metadata with no code body to walk (treat as a richer greenfield).


1. **README mining**:
   ```bash
   find . -maxdepth 3 -iname 'README*' -not -path '*/node_modules/*' -not -path '*/.git/*'
   ```
   For each README found, extract:
   - One-line description (first paragraph after title).
   - Setup commands (look for `## Setup`, `## Getting started`, `## Installation` sections).
   - Listed features (`## Features` bullets).
   - Tech stack mentioned (`Built with` / `Tech stack` / badge URLs).
   - Mission / vision statement if explicit.

2. **Manifest mining**:
   ```bash
   find . -maxdepth 3 \( -name 'package.json' -o -name 'pyproject.toml' -o -name 'composer.json' -o -name 'go.mod' -o -name 'Cargo.toml' -o -name 'Gemfile' \) -not -path '*/node_modules/*'
   ```
   For each manifest:
   - Project name, version, description fields.
   - Dependencies (top 20 — gives stack signal).
   - Scripts (lint / test / build / dev) — feeds Phase 4.1 permission allowlist.

3. **Git history mining** (last 6 months):
   ```bash
   git log --since='6 months ago' --pretty=format:'%s' | head -100
   ```
   Cluster commit messages by prefix (`feat:`, `fix:`, `refactor:`, `chore:`) — gives signal on:
   - Velocity + cadence.
   - Active areas (most-touched modules from `git log --name-only --since='6 months ago' | sort | uniq -c | sort -rn | head -20`).
   - Recently-removed concerns (deleted files in same window).

4. **Sibling repo detection** (workspace mode):
   - Check parent dir for `PROJECTS.md`, `pnpm-workspace.yaml`, `lerna.json`.
   - For each sibling: extract its README one-liner.
   - Inferred relationship (API vs frontend vs admin from naming).

5. **Domain-signal scan** (entity / route / dep names):
   - Run business-domain detection from `/setup-project` Phase 2.x.
   - Run technical-signal detection from `/setup-project` Phase 2 (multi-tenant, payment, AI, webhook, real-time, etc.).

6. **Synthesize into files**:
   - `.claude/codebase-profile.md` — facts (paths, base classes, naming, signals).
   - `ai/business-domain.md` — detected business domain + entities.
   - `ai/project-goals.md` — mission (from README) + KPIs (ASK if not in README) + anti-goals (ASK).
   - `ai/users-and-personas.md` — primary user (extract from README "for whom" or ASK).
   - `ai/business-model.md` — ASK (rarely in README).
   - `ai/competitive-context.md` — ASK.
   - `ai/roadmap.md` — derived from git history + open issues if accessible.

7. **Surface gaps**: every facet that couldn't be auto-extracted gets a `_TBD — ask user_` placeholder + listed in the report.

### Path B — Greenfield (from prompt)

1. **Parse prompt** for facets:
   - Mission (if stated).
   - Domain (extract domain keywords).
   - Stack (if specified).
   - Users / personas (if mentioned).
   - Constraints / anti-goals (if mentioned).

2. **Identify gaps** — facets the prompt doesn't cover.

3. **Ask ONE consolidated question** with sensible defaults from the prompt:
   ```
   I extracted from your prompt:
   - Mission: <X>
   - Domain: <Y>
   - Stack: <Z>

   To complete the setup, please confirm or fill in:
   1. Primary user persona: <inferred default | ASK>
   2. Business model: <inferred default | ASK>
   3. Top 3 KPIs that would mean "this works":
   4. Anti-goals (what this project is NOT):
   5. Maturity stage: idea | prototype | MVP | production

   Reply with corrections or "all defaults look good".
   ```

4. **Synthesize into files** with `_TBD_` for anything still unknown after the consolidated question.

## Output

```
## extract-project-context — extraction report

Mode: existing-codebase | greenfield-from-prompt

Files written:
  .claude/codebase-profile.md       (N facts captured)
  ai/business-domain.md              (domain: <X>, signals: <list>)
  ai/project-goals.md                (mission ✓, KPIs <count>, anti-goals <count>)
  ai/users-and-personas.md           (personas: <count>)
  ai/business-model.md               (model: <X> | _TBD_)
  ai/competitive-context.md          (alternatives: <count> | _TBD_)
  ai/roadmap.md                      (phases: <count>)

Auto-extracted from:
  - <path>/README.md (mission + setup)
  - <path>/package.json (stack + scripts)
  - git history (velocity + active areas)
  - <N sibling repos>

Gaps requiring user input (placeholder _TBD_ written):
  - ai/business-model.md (no signal in README or code)
  - ai/competitive-context.md (no signal)
  - ai/project-goals.md KPIs (ASK)

Next step:
  - Review the generated files.
  - Fill in _TBD_ placeholders.
  - Run /audit-knowledge to regenerate the compact derived files (_session-digest, _decision-index, _convention-cheatsheet).
```

## Failure modes

- **README missing or unhelpful** (template README with placeholder text): rely on manifests + git history + ASK.
- **Multiple READMEs in monorepo**: read each sub-project's README; aggregate at workspace level.
- **No git history yet** (brand-new repo): skip the history step; rely on prompt.
- **Domain detection ambiguous** (signals from 2+ domains): ASK with the candidates as options.
- **User refuses to answer the consolidated question**: write `_TBD_` for every unknown; flag in report.

## See also

- `/setup-project` CREATE mode (Path B, greenfield) — the canonical invoker.
- `extract-codebase-overview` + `extract-business-context` + Phase 4.7b — the **existing-codebase** owners of these `ai/` targets; this skill defers to them.
- `/refresh-knowledge` — re-runs the canonical pipeline on existing projects to catch drift (NOT this skill).
- `ai/business-domain.md`, `ai/project-goals.md`, `ai/users-and-personas.md` — destinations.
- `knowledge-curator` agent — uses this skill's output to maintain compact derived files.
