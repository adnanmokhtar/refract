---
description: Write a new ADR in ai/decisions/ with proper numbering and Recent Changes log.
---

# /add-adr [title]

Build command for the knowledge layer. Captures a non-obvious architectural decision so future-you doesn't re-litigate it. All 7 phases apply but Phase 6 (Validate) is structural, not lint/test.

## The Premise (read this first, internalize, do not deviate)

**Existing ADRs are the truth.** The repo's `ai/decisions/` folder is the canon of how this team writes a decision record — section names (`Status / Context / Decision / Consequences / Alternatives considered`), numbering convention (`NNNN-kebab-title.md`), supersession linking, status lifecycle (Proposed → Accepted → Superseded). A new ADR is a **sibling**, not a new template. Inventing sections like `Strategic Vision`, `Executive Summary`, or skipping `Alternatives considered` because "the choice was obvious" is drift, not refinement.

**The agent's job is exactly this:**
1. Read 2-3 recent ADRs in `ai/decisions/` before drafting. They define the shape, tone, and depth.
2. Mirror their structure exactly: same section list, same ordering, same heading levels, same status field format.
3. Confirm the decision is real — there must be ≥ 2 viable options with substantive pros/cons. Single-option ADRs hide the tradeoff and degrade to documentation; route those to `ai/conventions.md` or `ai/dynamic/changelog.md`.
4. Consequences include **at least one negative bullet**. All-positive consequences = incomplete analysis = future-you re-litigates anyway.

**The agent does NOT:**
- Invent sections (`Strategic Vision`, `Executive Summary`, `Risk Matrix`) that no sibling ADR has. Sibling shape wins.
- Skip `Alternatives considered` because the choice felt obvious. The whole point of an ADR is the rejected option.
- List a straw-man alternative ("we could write our own framework instead") to satisfy the section. Both options need real pros.
- Write an ADR retroactively to justify already-merged code with no real choice. That's documentation; use `ai/dynamic/changelog.md`.
- Edit an Accepted ADR in place. Reversal = NEW ADR with `Supersedes NNNN`; the prior gets `Status: Superseded by MMMM`.
- Number-collide on parallel branches. Use `NNNN-YYYYMMDD-slug.md` mid-branch; finalize at merge.

**Mechanical halt — sibling-shape parity (mandatory before Phase 4 generate):**

Before writing `ai/decisions/NNNN-<slug>.md`, the agent MUST:
- Name the 2-3 sibling ADRs read (`ai/decisions/*.md` paths).
- Confirm the new ADR uses the same section list + ordering: `Status / Context / Decision / Consequences / Alternatives considered`.
- Confirm ≥ 2 substantive alternatives with real pros/cons (no straw-man).
- Confirm Consequences has ≥ 1 negative bullet.
- Confirm next number via `ls ai/decisions/ | grep -E '^[0-9]{4}-' | sort -n | tail -1` — no collision.
- If no sibling ADRs exist — HALT. Ask the user to confirm the ADR template, do not invent shape from training data.

An ADR that fails sibling-shape parity is rejected; regenerate or halt.

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
