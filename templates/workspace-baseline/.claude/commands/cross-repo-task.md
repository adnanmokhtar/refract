---
description: Orchestrate a feature that touches multiple sibling repos — API first, then frontends.
---

# /cross-repo-task

Use when a feature requires coordinated changes across 2+ repos in the workspace.

## Flow

1. **Understand the task** — ask the user for the feature description if not given.
2. **Read `PROJECTS.md`** — know every sibling's stack + role.
3. **Build impact matrix**: which repos are affected and why. Present to user for approval.
4. **Write spec** to `specs/<YYYYMMDD-slug>.md` at workspace root.
5. **Execute sequentially**:
   - API repo FIRST — add DTOs, endpoints, migrations, tests.
   - Then frontends — consume the new contract, add i18n keys in both locales.
6. **Per repo**: `Read` its `CLAUDE.md` FIRST, then apply changes using its conventions.
7. **Final report**: per-repo diff summary + i18n keys added + follow-ups.

## Rules

- Never commit across repos in one step.
- Flag any frontend change that depends on an API change that isn't shipped.
- For UI changes, remind the user to run visual verification inside that repo's own session.
