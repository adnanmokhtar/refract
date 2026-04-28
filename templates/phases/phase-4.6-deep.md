---
phase: 4
sub-phase: "4.6-DEEP"
name: re-anchor-project-blocks
applies-to-modes: [REFINE]
inputs: [.claude/_extracted-idioms.md, .claude/_refine-extract.md, existing managed Project-specific blocks]
outputs: [rewritten Project-specific blocks (managed markers preserved); user blocks untouched]
exit-criteria: every artifact whose anchor density was below threshold has been re-anchored OR plateau reached
imported-by: templates/phases/phase-4-apply.md
---

### Phase 4.6-DEEP — Re-anchor Project-specific blocks with deep extraction (REFINE mode only)

**Trigger**: REFINE mode (`--refine`). Skipped in CREATE / ENHANCE / REFRESH (those modes already ran the standard Phase 4.6 — round-one anchors are sufficient there).

**Why this exists**: standard Phase 4.6 anchors with whatever extraction is available at first-pass time — typically file paths + base classes + suffix matrix + stack identifiers. That's enough for the floor. But a backend rule that cites the project's framework + a base class is still **mostly generic prose with a 5-line project-specific header**. Round-two anchors with the deep-extraction substrate from Phases 2.7–2.12 — turning the 5-line header into a 20-30-line concrete block: actual entity names with their invariants, actual flow citations, actual hot paths with their N+1 risk, actual emergent error-shape conventions. The body of the rule still gets to be teaching prose; the project-specific block gets to be exact.

**Mechanism**: invoke the `apply-pack-adaptation` skill (same skill as standard Phase 4.6) with **mode = `REFINE`**, **inputs additionally include `.claude/_refine-extract.md`**, and the **`max_subagents` parameter wired from the `--max-subagents=<N>` flag** (default `8`). The skill fans out one re-anchor subagent per shallow artifact up to the cap; remaining artifacts serialize. The skill follows the same STUDY → DECIDE → ACT contract but with extra ACT options:

| Standard 4.6 ACT | REFINE 4.6-DEEP ACT |
|---|---|
| ANCHOR — write Project-specific block from round-one signals | ANCHOR-DEEP — REWRITE existing Project-specific block using `_refine-extract.md` (entities / flows / hot paths / emergent conventions). Round-one block becomes the 5-line summary at top; deep details fill the rest. |
| LEAVE-with-redirect | LEAVE-DEEP — leave round-one block when the deep extraction adds NO new signal for this artifact's topic (e.g. a `code-quality.md` rule has no new domain entities to cite — round-one anchor is already optimal). Record reason in `_refine-log.md`. |
| CHANGE-anchor-with-warn | (same; rare in REFINE since round-one floor already established) |
| *(no analog)* | NEW-FILE — when deep extraction surfaces a genuine artifact need that round-one didn't catch. Examples: Phase 2.12 found a recurring auth-bypass theme → write `ai/failures/auth-bypass.md`. Phase 2.11 found 6 hot paths with N+1 risk → ENSURE `query-optimizer.md` is present (gap-fill if not, deep-anchor if present). |

**Decision-file**: appends to `.claude/_phase-4-6-decisions.md` with section header `## REFINE — round two (<YYYY-MM-DD HH:MM>)`. Each per-file entry includes the new ACT type + which deep-extraction sections were consumed.

**Idempotency contract**: every REFINE run reads BOTH the prior round-one anchor (from disk) AND the prior REFINE entries in `_phase-4-6-decisions.md`. If the deep-extraction content unchanged AND the artifact's anchor already cites the deep details → ACT becomes `LEAVE-DEEP-IDEMPOTENT` (no rewrite). This is what makes 2nd / 3rd `--refine` runs converge to "plateau reached."

**Coverage target**: every artifact whose anchor-density score (Phase 5.5) was < 70 in round-one MUST be re-anchored OR explicitly marked `LEAVE-DEEP` with reason. Files with score ≥ 70 are skipped by default (not worth the rewrite churn).

**Safety**: REFINE 4.6-DEEP rewrites ONLY the `## Project-specific` block delimited by the markers `<!-- project-specific:start -->` and `<!-- project-specific:end -->` (these markers are auto-injected by every Phase 4.6 anchor; standard 4.6 already uses them). User-authored content outside the markers is BIT-IDENTICAL pre/post run. The skill's pre-write step re-reads the file, computes a hash of the user-authored regions, performs the rewrite, computes the hash again — mismatch = halt with rollback.

