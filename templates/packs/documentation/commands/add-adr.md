---
description: Write a new ADR in ai/decisions/ with proper numbering and Recent Changes log.
---

# /add-adr [title]

Build command for the knowledge layer. Captures a non-obvious architectural decision so future-you doesn't re-litigate it. All 7 phases apply but Phase 6 (Validate) is structural, not lint/test.

## When to use / NOT to use
- USE: choosing one library / pattern / boundary over a viable alternative.
- USE: reversing a prior decision (writes a superseding ADR).
- USE: adopting a constraint future contributors will question (e.g. "no shared DB across services").
- NOT: trivial choices (lint rule, file naming, formatter) — those go in `ai/conventions.md`.
- NOT: documenting code already merged with no real choice — use `ai/dynamic/changelog.md`.

## Phase 1 — Understand
- Title (kebab in filename, sentence-case in body) — confirm with user.
- Confirm this is a real decision: is there a viable alternative being rejected? If "no", abort and route to `ai/conventions.md`.

## Phase 2 — Organize
- Compute next ADR number: `ls ai/decisions/ | grep -E '^[0-9]{4}-' | sort -n | tail -1` → increment, zero-pad to 4 digits.
- If multiple ADRs are in flight on parallel branches, use timestamp-suffix branch name (`NNNN-YYYYMMDD-slug.md`) and pick a final number at merge.
- Identify if this supersedes a prior ADR (read `ai/decisions/` for related topics).

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

ADR-specific:
- All `ai/decisions/*.md` — find ADRs touching the same domain (to supersede or cross-reference).
- `ai/architecture.md` — confirm the decision aligns or explicitly diverges.

## Phase 4 — Generate
- Collect inputs in ONE round of questions (no drip-feed):
  - Context: what forced this choice now? (deadline, outage, scale event, cost).
  - Options considered (≥ 2 — single-option ADRs hide the tradeoff).
  - Chosen option + reasoning.
  - Consequences (positive AND negative — all-positive = incomplete analysis).
- Write `ai/decisions/NNNN-<kebab-title>.md` with sections:
  ```
  # <Title>
  ## Status (Proposed | Accepted | Superseded by NNNN)
  ## Context
  ## Decision
  ## Consequences
  ## Alternatives considered
  ```
- Status defaults to `Proposed`. User flips to `Accepted` after review.

## Phase 5 — Update
- `ai/status.md` — append bullet to `## Recent Changes`: `- ADR-NNNN: <title> (Proposed|Accepted)`.
- `ai/decisions/MMMM-*.md` (if superseding) — set `Status: Superseded by NNNN-<slug>` with link.
- `ai/dynamic/decisions-pending.md` — remove entry if this ADR resolves a queued decision.

## Phase 6 — Validate
- Numbering: file is uniquely numbered; no collision with sibling branches.
- Both options listed have real pros/cons (no straw-man alternative).
- Consequences section has at least one negative bullet.
- Cross-link: superseded ADR (if any) points back to the new one.

## Phase 7 — Improve
- `/learn-from-task` — capture decision + alternatives + tradeoffs as a teachable moment.
- If the same kind of decision recurs (3+ ADRs on related topics), surface to user — likely deserves a project-wide pattern in `ai/patterns/`.

## Output format
```
## /add-adr — ADR-NNNN: <title>

Phase 1 (Understand): real choice confirmed (alternative was X)
Phase 3 (Retrieved): N prior ADRs scanned for overlap
Phase 4 (Generated): ai/decisions/NNNN-<slug>.md (Status: Proposed)
Phase 5 (Updated): ai/status.md Recent Changes; ai/decisions/MMMM superseded
Phase 6 (Validated): unique number, both alternatives substantive, negative consequences listed
Phase 7 (Improved): captured to /learn-from-task

Status: COMPLETE
```

## Failure modes
- ADR written retroactively to justify already-merged code = documentation, not a decision. Use `ai/dynamic/changelog.md` instead.
- Single-option ADR (no real alternative) — abort and write a convention note instead.
- "Status: Proposed" left dangling for weeks → noise. Push user to triage in next review cycle.
- ADRs are immutable once Accepted. Reversal = NEW ADR, never edit-in-place.
- Numbering collision on simultaneous PRs → use timestamp suffix on branch, finalize at merge.

## Related

### Sibling commands in documentation pack
- `/doc-refresh` — sibling command in documentation pack

### Patterns
- `ai/patterns/adr-template.md`
- `ai/patterns/slo.md`
- `ai/patterns/system-design.md`

### Rules
- `.claude/rules/doc-principles.md`
