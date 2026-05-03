---
purpose: Canonical "Phase 3 ALWAYS" reading list for operational commands — link here instead of copying into each command.
---

# Phase 3 ALWAYS reads (universal pre-flight)

Every command's **Phase 3 — Retrieve** MUST include these paths (or a one-line link to this file):

- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

**Before generating or refactoring code**, also read [`templates/governance/core-discipline.md`](../governance/core-discipline.md) (clean-code + SOLID pointers).

Signal-based and sibling reads stay in the command file — only this universal block is deduped here.
