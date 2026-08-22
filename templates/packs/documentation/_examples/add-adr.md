---
description: Write a new ADR in ai/decisions/ with proper numbering and Recent Changes log.
kind: command
pack: documentation
---

# /add-adr [title]

Build command for the knowledge layer. Captures a non-obvious architectural decision so future-you doesn't re-litigate it. All 7 phases apply but Phase 6 (Validate) is structural, not lint/test.

## The Premise (read this first, internalize, do not deviate)

**Existing ADRs are the truth.** The repo's `ai/decisions/` folder is the canon of how this team writes a decision record — section names (`Status / Context / Decision / Consequences / Alternatives considered`), numbering convention (`NNNN-kebab-title.md`), supersession linking, status lifecycle (Proposed → Accepted → Superseded). A new ADR is a **sibling**, not a new template.

**The agent's job is exactly this:** read 2-3 recent ADRs before drafting; mirror their structure exactly (same section list, ordering, heading levels, status field format); confirm the decision is real — there must be ≥ 2 viable options with substantive pros/cons, and single-option ADRs route to `ai/conventions.md` or the changelog instead; and include **at least one negative bullet** in Consequences, because all-positive consequences mean the analysis is incomplete.

**The agent does NOT:** invent sections (`Strategic Vision`, `Executive Summary`, `Risk Matrix`) that no sibling ADR has; skip `Alternatives considered` because the choice felt obvious (the rejected option is the whole point); list a straw-man alternative to satisfy the section; write an ADR retroactively to justify already-merged code with no real choice; edit an Accepted ADR in place (a reversal is a NEW ADR with `Supersedes NNNN`, and the prior gets `Status: Superseded by MMMM`); or number-collide on parallel branches.

**Mechanical halt — sibling-shape parity (mandatory before generating the file):** name the 2-3 sibling ADRs read; confirm the same section list + ordering; confirm ≥ 2 substantive alternatives with real pros/cons; confirm Consequences has ≥ 1 negative bullet; confirm the next number does not collide. **If no sibling ADRs exist — HALT.** Ask the user to confirm the ADR template; do not invent shape from training data.

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
- `ai/_decision-index.md` — append the new ADR row so the Tier-2 index stays current (`add-runbook` reads it for related-decision lookup; skipping it guarantees staleness). If the project regenerates derived files via `knowledge-curator` / `/audit-knowledge`, delegate the regen and say so. Either way the index reflects the new ADR before COMPLETE.
- `ai/decisions/MMMM-*.md` (if superseding) — set `Status: Superseded by NNNN-<slug>` with link.
- `ai/dynamic/decisions-pending.md` — remove entry if this ADR resolves a queued decision.

## Phase 6 — Validate

| # | Check (run it) | Failing means |
|---|---|---|
| 1 | `ls ai/decisions/` — the new number appears exactly once | numbering collision (parallel branch) |
| 2 | ≥ 2 alternatives, each with a concrete reject reason tied to the cited Context | straw-man → not a decision record |
| 3 | `Consequences` contains ≥ 1 negative bullet | all-positive = incomplete analysis |
| 4 | If superseding: the OLD ADR reads `Status: Superseded by NNNN` AND the new one names `Supersedes MMMM` | **dangling supersession** — a one-way link forks the canon |
| 5 | `grep '^| NNNN ' ai/_decision-index.md` returns the new row (or a triggered knowledge-curator regen whose output you verified) | the Tier-2 index lags; `/add-runbook` reads it and will miss this ADR |
| 6 | If `Status: Accepted`: the implementing file or commit is cited | promote-without-impl |

### Terminal verdict — computed from the checks

- `COMPLETE` — every check passes; the line names the number, the siblings read, the index row written.
- `INCOMPLETE — <what is unmet>` — the honest state when check 4, 5 or 6 fails. **The ADR still ships** (an ADR on disk beats a decision in a Slack thread), labelled, naming what would close it. Reporting `INCOMPLETE` is a success; `COMPLETE` over a dangling supersession is the failure this gate exists to prevent, because the next reader follows a link into nothing.
- `HALT — no sibling ADRs` — confirm the shape with the user; never invent one from training data.

## Phase 7 — Improve
- `/learn-from-task` — capture decision + alternatives + tradeoffs as a teachable moment.
- If the same kind of decision recurs (3+ ADRs on related topics), surface to user — likely deserves a project-wide pattern in `ai/patterns/`.

## Output format
```
## /add-adr — ADR-NNNN: <title>

Phase 1 (Understand): real choice confirmed (alternative was X)
Phase 3 (Retrieved): N prior ADRs scanned for overlap
Phase 4 (Generated): ai/decisions/NNNN-<slug>.md (Status: Proposed)
Phase 5 (Updated): ai/status.md Recent Changes; ai/_decision-index.md row appended (or knowledge-curator regen triggered); ai/decisions/MMMM superseded
Phase 6 (Validated): 1 number unique · 2 alternatives substantive · 3 negative consequence present ·
   4 supersession links both ways · 5 index row written · 6 impl cited (Accepted only)
Phase 7 (Improved): captured to /learn-from-task

Status: COMPLETE | INCOMPLETE — <unmet check + what closes it>
```

Honest form:
```
Status: INCOMPLETE — check 4 open: this ADR names `Supersedes 0031`, but
   ai/decisions/0031-single-region-writes.md still reads `Status: Accepted`.
   To close: set it to `Status: Superseded by 0042` with a link, then re-run check 4.
```

## Failure modes
- ADR written retroactively to justify already-merged code = documentation, not a decision. Use `ai/dynamic/changelog.md` instead.
- Single-option ADR (no real alternative) — abort and write a convention note instead.
- "Status: Proposed" left dangling for weeks → noise. Push user to triage in next review cycle.
- ADRs are immutable once Accepted. Reversal = NEW ADR, never edit-in-place.
- Numbering collision on simultaneous PRs → use timestamp suffix on branch, finalize at merge.
- **One-way supersession** — the new ADR says `Supersedes 0031` and 0031 still reads `Accepted`. Two ADRs now claim to be current policy and neither file reveals the conflict.
- **Index written by assumption** — a `knowledge-curator` regen triggered and never confirmed leaves `ai/_decision-index.md` silently lagging.
