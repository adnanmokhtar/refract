---
description: Write a new ADR in ai/decisions/ with proper numbering and Recent Changes log.
kind: command
pack: documentation
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

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

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
- `ai/_decision-index.md` — append the new ADR row (`| NNNN | <title> | <status> | <one-line> |`) so the Tier-2 index stays current. `add-runbook` reads this index for related-decision lookup; skipping it guarantees staleness. If the project uses `knowledge-curator` / `/audit-knowledge` to regenerate derived Tier-1/2 files (this index is one), delegate the regeneration to it after writing the ADR — and say so in the output — rather than hand-editing. Either way the index must reflect the new ADR before this command reports COMPLETE.
- `ai/decisions/MMMM-*.md` (if superseding) — set `Status: Superseded by NNNN-<slug>` with link.
- `ai/dynamic/decisions-pending.md` — remove entry if this ADR resolves a queued decision.

## Phase 6 — Validate

Each check is mechanical and its failure has a named terminal state — this command does not get to narrate "done".

| # | Check (run it) | Failing means |
|---|---|---|
| 1 | `ls ai/decisions/` — the new number appears exactly once | numbering collision (parallel branch) |
| 2 | ≥ 2 alternatives, each with a concrete reject reason tied to the cited Context | straw-man alternative → not a decision record |
| 3 | `Consequences` contains ≥ 1 negative bullet | all-positive = incomplete analysis; future-you re-litigates |
| 4 | If superseding: `grep 'Superseded by NNNN' ai/decisions/MMMM-*.md` resolves, AND the new ADR names `Supersedes MMMM` | **dangling supersession** — a one-way link is how the canon forks |
| 5 | `grep '^| NNNN ' ai/_decision-index.md` returns the new row (or knowledge-curator regeneration was triggered and its output verified) | the Tier-2 index lags the ADR; `/add-runbook` reads this index and will miss the decision |
| 6 | If `Status: Accepted`: the implementing file or commit is cited | promote-without-impl (the pattern's own halt) |

### Terminal verdict — computed from the checks above

- `Status: COMPLETE` — every check passes. The output line names the number, the sibling ADRs read, and the index row written.
- `Status: INCOMPLETE — <what is unmet>` — the honest state whenever check 4, 5 or 6 fails: a supersession link that only points one way, an index row that was not written (or a knowledge-curator regeneration that was triggered but not confirmed), or a `Status: Accepted` with no implementing commit. **The ADR file still ships** — an ADR on disk beats a decision in a Slack thread — but the run is labelled and names what would close it. Reporting `INCOMPLETE` here is a success of this command; `COMPLETE` printed over a dangling supersession is the failure it exists to prevent, because the next reader follows a link into nothing.
- `Status: HALT — no sibling ADRs` — the pre-Phase-4 halt already covers this: shape is confirmed with the user, never invented from training data.

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

Example of the honest form:
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
- **One-way supersession** — the new ADR says `Supersedes 0031` and 0031 still reads `Accepted`. Two ADRs now claim to be current policy and nothing in either file reveals the conflict. This is check 4, and it is why `COMPLETE` is not this command's only terminal state.
- **Index written by assumption** — `knowledge-curator` regeneration was triggered and never confirmed, so `ai/_decision-index.md` silently lags. `/add-runbook` reads that index for related-decision lookup and will not find this ADR.

## Related

### Sibling commands in documentation pack
- `/doc-refresh` — sibling command in documentation pack

### Patterns
- `ai/patterns/adr-template.md`
- `ai/patterns/slo-doc-template.md`
- `ai/patterns/system-design.md`

### Rules
- `.claude/rules/doc-principles.md`
