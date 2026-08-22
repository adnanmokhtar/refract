---
name: setup-quality-scoring
description: The four-axis anchor-density model used to score generated artifacts (rules / agents / skills / commands / ai-files) on a 0-100 scale. Documents the rubric, the per-axis criteria, the classification thresholds (DEEP / ANCHORED / SHALLOW / MISSING), and the plateau-detection logic that tells `/setup-project --refine` when to stop. Companion document to the `compute-anchor-density` skill (which is the executable scorer) and the Phase 5.5 quality-score report.
---

# Pattern: setup-quality-scoring

> **Hard rule** — Every score axis is computed from verified citations against `_extracted-codebase.md` / `_refine-extract.md`; ghost identifiers and ghost paths deduct 5 each. A bare "plateau reached" string without a class tag (DEEP / WEAK / NOT-PLATEAU) is forbidden.

**When to apply**
- A `/setup-project --refine` Phase 5.5 run needs to decide which artifacts to re-anchor.
- A `/setup-project --health` report needs an objective ceiling number.
- Manual review wants the same lexicon to discuss anchor depth.

**When NOT to apply**
- Round-one Phase 4.6 itself — the scorer is post-hoc, not a substitute.
- Files that don't carry the `## Project-specific` marker — score is undefined; treat as MISSING.
- Comparing across projects — scores are intra-project signals, not benchmarks.

**Halt conditions / mandatory cites**
- Cite each scored identifier against extraction (`<path:line>` in `_extracted-codebase.md` or `_refine-extract.md`); uncited identifier = ghost = -5.
- Cite each scored path's existence; out-of-bounds line numbers in `file:line` cites are halts.
- Cite the WEAK extraction phases by name when emitting PLATEAU-WEAK; bare PLATEAU is forbidden.
- Cite the prior `_setup-quality.md` run by `<path>` when computing `plateau_delta`; without baseline, verdict is `NOT-PLATEAU`, never `PLATEAU-DEEP`.
- Hand-wave grep ban — never claim "all artifacts anchored" without citing each artifact's score row in `_setup-quality.md`.

## Why this exists

REFINE rewrites only artifacts whose round-one anchor is shallow. To decide which is "shallow," we need a deterministic score, not a vibe check. Without a score:

- The user can't tell whether running `--refine` made things better.
- `--refine` can't decide which artifacts to re-anchor (the whole set is too expensive; nothing isn't enough).
- `--refine` can't detect when it's done. It would either stop too early (leaving real shallow artifacts) or never stop (rewriting the same blocks indefinitely).

The score solves all three. Same rubric is applied per-artifact in round one (just records baseline) AND per-artifact in round two (compares to baseline → reports delta).

## The four axes

Each axis scores 0–25. Total = 0–100.

### Axis 1: Name density

**What it measures**: how many concrete, project-specific identifiers (class names, function names, table names, endpoint paths, package names) appear in the `## Project-specific` block.

**Why it matters**: an anchor that says "the project's billing service" cites zero identifiers — generic. An anchor that says "`app/services/billing.py:BillingService.create_invoice` (line 128)" cites three (file, class, method). An agent reading the second one knows where to look; an agent reading the first one infers.

**Threshold**:

| Unique identifiers | Score |
|---|---|
| 0 | 0 |
| 1-2 | 8 |
| 3 | 13 |
| 4 | 18 |
| 5 | 22 |
| ≥ 6 | 25 |

**Verification**: cross-check every cited identifier against `_extracted-codebase.md` (any section — `## Modules` / `## Base classes` / `## Data model` / `## API surface` are where identifiers live; there is no `## Identifiers` section, see `extract-codebase-overview § Step 14`) OR `_refine-extract.md` (any section). If the artifact cites an identifier that's not in extraction, the artifact is hallucinating — DEDUCT 5 per ghost identifier.

### Axis 2: Path density

**What it measures**: how many concrete file paths or `file:line` citations appear in the block.

**Why it matters**: paths route an agent's reading. Without paths, the agent has to grep. With paths, the agent reads the right file in 1 hop.

**Threshold**:

| Citations (verified) | Score |
|---|---|
| 0 | 0 |
| 1 | 8 |
| 2 | 13 |
| 3 | 18 |
| 4 | 22 |
| ≥ 5 | 25 |

**Verification**: confirm each cited file exists in the project. For `file:line` citations, check the line number is within the file's bounds. Ghost citations DEDUCT 5 each.

### Axis 3: Signal density

**What it measures**: how many distinct deep-extraction inputs (entities, flows, hot paths, emergent conventions, failure themes, layer/boundary, lifecycle events, invariants, n+1 sites, missing indexes) the block actually consumes.

**Why it matters**: the deep-extraction substrate is built precisely so artifacts can consume it. An artifact that consumes 4 distinct signal categories is genuinely round-two depth. An artifact that consumes 0 is round-one shallow.

**Threshold**:

| Distinct signals consumed | Score |
|---|---|
| 0 | 0 |
| 1 | 8 |
| 2 | 13 |
| 3 | 18 |
| 4 | 22 |
| ≥ 5 | 25 |

**Verification**: a signal counts only if the upstream extraction is STRONG (per each extraction skill's quality gate). Consuming a WEAK extraction's output is forbidden — round-one anchors stay in those cases.

### Axis 4: Specificity

**What it measures**: the fraction of the block's *directives* — sentences that tell a reader to do, prefer, avoid or check something — that name a verified identifier, a verified path, or a number from extraction. Grounded directives point at this repo; floating ones would fit any repo.

**Why it matters**: a block can have all the right identifiers + paths + signals in its opening paragraph AND still instruct the reader with pure filler ("follow the team's established patterns for this layer"). Axes 1-3 count referents *anywhere* in the block; this axis asks whether the *advice* carries them. That is the discrimination the other three cannot make.

**Why it is a positive test and not a blocklist.** It used to start at 25 and deduct 5 per phrase from a list of nine strings — so prose that avoided those exact nine scored a perfect 25, and this became the one axis a generator could max out by writing more confident prose. That inverted the whole rubric's purpose. Under the positive test, confident prose with no referent scores 0. Placeholder deductions (`<TODO>`, `<entity>`, un-filled auto-comments) survive on top, because those are un-filled output rather than a judgement about writing.

**Thresholds**: `grounded_directives / total_directives` → 25 / 18 / 13 / 8 / 0 across the bands in [`compute-anchor-density § Step 5`](../skills/compute-anchor-density/SKILL.md). A block with zero directives scores 0 — it instructs nobody.

## Plateau detection — classification, verdicts, and where the arithmetic lives

The band boundaries (MISSING / SHALLOW 1-69 / ANCHORED 70-84 / DEEP 85-100), the three-way plateau
verdict with its exact conditions, and the per-WEAK-phase remediation map are **defined once**, in
[`compute-anchor-density`](../skills/compute-anchor-density/SKILL.md) §§ Step 6-7. That skill is what
computes them; this document is what explains them. They are not restated here on purpose — a
threshold written in two files is a threshold that will be changed in one.

What this document owns is the part a number cannot carry: *why the verdict is three-way, and why
two of its reasons look identical and call for opposite actions.*

**The two plateau classes are exhaustive by construction**, and the `OR` in `PLATEAU-WEAK`'s
condition is what makes them so: `PLATEAU-WEAK` is `plateau_delta ≤ ΔMax` AND NOT `PLATEAU-DEEP`.
With `AND` there instead, a converged run at `plateau_consumed = 0.9, avg_score = 75` would match
neither class and the exit table would have no verdict to read. `compute-anchor-density § Step 7`
carries the same `OR` form; they must not diverge.

**The verdict is never a binary.** `PLATEAU-DEEP` and `PLATEAU-WEAK` are indistinguishable from the
deltas alone — both show a run that stopped improving — and they mean opposite things. DEEP means the
substrate was consumed and the artifacts are anchored: stop, you are done. WEAK means the run hit a
ceiling it did not set: stop, and go fix what is below it. A single "plateau reached" string collapses
those two into the first reading, which is the misleading message this whole distinction exists to
prevent.

**And `PLATEAU-WEAK` itself carries three reasons that are not interchangeable.** The per-phase
remediation map in the skill answers exactly one of them:

- `reason: signal` — the extraction phases came back thin. The map applies: grow the upstream signal
  (more models, more traced endpoints, more history) and re-run.
- `reason: score` — the substrate WAS consumed (`plateau_consumed ≥ 0.85`) and the artifacts still
  failed to anchor. The **generators** are at fault, not the codebase. Telling this user to write more
  domain models is a wild-goose chase; the fix is upstream in Phase 4.6/4.7 authoring.
- `reason: coverage` — round-one only *read* part of the source (`[SAMPLED]` markers survive). The
  code is already there and simply was not walked. The instruction is **raise coverage** — re-run
  without `--lightweight`, or raise the per-category sample in `extract-codebase-overview § Step 8` —
  which is the exact opposite of "grow the codebase".

Giving a `score` or `coverage` run the `signal` advice sends the user to change the one thing that is
not the problem, and the run plateaus again at the same number, which is how a user learns to stop
trusting the verdict. `compute-anchor-density § Step 7` emits the `reason` field; a consumer that prints the per-phase map for all three values is answering two of them wrong.

## Anti-patterns this rubric exists to prevent

1. **The "I rewrote everything" trap** — without scoring, REFINE could rewrite anchored artifacts repeatedly, churning diffs without improving content. The threshold (skip ≥ 70) prevents this.
2. **The "REFINE never converges" trap** — without plateau detection, the user has no signal that "we're done." Plateau converts subjective "is this good enough?" into a measurable answer.
3. **The "high score, no signal" trap** — an artifact could score 100 by stuffing the block with identifiers and paths copied from another project (LEAK). The verification rule (cross-check against extraction; deduct 5 per ghost) prevents this.
3b. **The "confident prose" trap** — the sharpest version of trap 3, and the one that survived it for a while: a block citing 6 real identifiers and 5 real paths, consuming zero deep signal, whose every instruction is "follow the team's established patterns", scored `25 + 22 + 0 + 25 = 72` — ANCHORED, therefore skipped by Phase 4.6-DEEP forever. Every citation was real; the advice was worthless. Specificity became a **positive** test for exactly this: the citations are still counted by axes 1-2, but the axis that scores the *advice* now asks whether the advice points anywhere.
4. **The "plateau by WEAK extraction" trap** — if extraction was WEAK, signal density caps at 0 and total scores stay low forever. Without the three-way verdict, reporting "plateau reached" misleads — the user thinks "we got everything" when really "there's nothing left to consume from a thin extraction." The PLATEAU-DEEP / PLATEAU-WEAK / NOT-PLATEAU classifier closes that gap. **A bare "plateau reached" string is forbidden — every verdict carries a class tag.**
5. **The "silent WEAK axis" trap** — a PLATEAU-WEAK verdict that doesn't enumerate which phases produced WEAK output is half-useful. The user knows they're stuck but not what to grow. The verdict message MUST list every WEAK phase + its recommended action.

## How to use this rubric

Three contexts:

1. **`/setup-project --refine` Phase 5.5** — automated. The `compute-anchor-density` skill scores every artifact and writes `_setup-quality.md`.
2. **`/setup-project --health`** — automated. Score is included in the health report (Tier-1 visibility per Hard Rule on `_session-digest.md`).
3. **Manual code review** — a reviewer can read a generated artifact, mentally apply the four axes, and decide "is this anchored enough or do I want to re-run `--refine`?" The rubric is the shared language.

## Companion artifacts

- **Skill**: `compute-anchor-density` (executable scorer; lives in `~/.claude/templates/packs/learning/skills/compute-anchor-density/SKILL.md`).
- **Phase**: setup-project.md § "Phase 5.5 — Setup-quality score (REFINE mode only)".
- **Output**: `.claude/_setup-quality.md` — generated per run; format documented in setup-project.md Phase 5.5.
- **Hard Rule**: setup-project.md § "Always" — the REFINE hard rule references this rubric.
