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

**Verification**: cross-check every cited identifier against `_extracted-codebase.md` § Identifiers OR `_refine-extract.md` (any section). If the artifact cites an identifier that's not in extraction, the artifact is hallucinating — DEDUCT 5 per ghost identifier.

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

**What it measures**: the inverse of generic-prose ratio — how much of the block is concrete vs how much is filler.

**Why it matters**: a block can have all the right identifiers + paths + signals AND still be drowned in generic prose ("apply best practices when implementing"). Specificity penalizes that prose.

**Scoring**: starts at 25. Each generic phrase = -5 (capped at 0).

Generic phrases the scorer flags:

- `<TODO>`, `<FIXME>`, any angle-bracket placeholder.
- `<base>`, `<entity>`, `<service>`, `<module>` (placeholder identifiers).
- `the project's <X>` with literal `<X>`.
- `your service layer / your repository / your controller` (generic referent without a name).
- `use parameterized queries` (without naming the actual data-access lib).
- `follow framework conventions` (without naming the framework).
- `apply best practices` (without specifying which).
- `as appropriate for your stack`, `depending on your setup`.
- Any auto-comment indicating un-filled-in content.

## Classification

Total = sum of axes. Classification:

| Range | Class | What REFINE does |
|---|---|---|
| 0 (markers absent) | **MISSING** | Round-one bug — re-run standard Phase 4.6, NOT a REFINE concern. |
| 1-69 | **SHALLOW** | Phase 4.6-DEEP rewrites the `## Project-specific` block. |
| 70-84 | **ANCHORED** | Phase 4.6-DEEP skips by default. Aggressive flag (`--refine --aggressive`, future) would re-anchor for 85+ ceiling. |
| 85-100 | **DEEP** | Phase 4.6-DEEP skips. Further rewriting won't help. |

## Plateau detection — three-way verdict

After scoring all artifacts in a `--refine` run, compare to the prior `_setup-quality.md` (if present):

```
plateau_delta    = avg(this_run_scores) - avg(prior_run_scores)
plateau_consumed = signals_consumed_across_all_artifacts / signals_available_in_refine_extract
weak_phase_count = count(phases in 2.7..2.12 with [REFINE-WEAK: ...])
avg_score        = avg(this_run_scores)
```

The verdict is **always one of three classes — never a single binary** "plateau / not-plateau". The distinction matters because PLATEAU-DEEP and PLATEAU-WEAK look identical from the deltas alone but call for opposite user actions:

| Verdict | Conditions | Per-artifact tag | Run-level message | User action |
|---|---|---|---|---|
| **PLATEAU-DEEP** | `plateau_delta ≤ 2` AND `plateau_consumed ≥ 0.85` AND `avg_score ≥ 80` | `LEAVE-DEEP-IDEMPOTENT` | "Plateau reached (DEEP) — setup is anchored." | Stop running `--refine` until significant new code lands. |
| **PLATEAU-WEAK** | `plateau_delta ≤ 2` AND (`plateau_consumed < 0.85` OR `avg_score < 80`) | `LEAVE-DEEP-IDEMPOTENT` (with `weak_phases:` list in row) | "Plateau reached (WEAK) — setup is NOT yet anchored deeply. <N> phases produced WEAK output: <list>." | Grow upstream signal first, then re-run `--refine`. |
| **NOT-PLATEAU** | `plateau_delta > 2` OR no prior baseline | (none) | (no plateau message) | Re-running `--refine` would still climb. Run again if score < 70 average. |

### The PLATEAU-WEAK action map

When the verdict is `PLATEAU-WEAK`, the run-level message MUST list each WEAK extraction phase + the recommended user action:

| WEAK phase | Recommended action |
|---|---|
| Phase 2.7 (entities) | Add more domain models / migrations / Pydantic-or-Zod schemas. |
| Phase 2.8 (architecture) | Add more clearly-bounded modules / cross-cutting middleware. |
| Phase 2.9 (flows) | Trace more endpoints (need ≥5 total). |
| Phase 2.10 (conventions) | Let conventions emerge across more files (need 5+ recurrences). |
| Phase 2.11 (hot paths) | Add monitoring config / Datadog dashboard / git churn signal. |
| Phase 2.12 (failures) | Accumulate more git history (need ≥30 commits) OR opt into `--include-incidents=<path>`. |

### Why this matters

A user seeing "plateau reached" with avg_score 58 and assuming "we got everything" is the misleading-message bug this distinction prevents. The two-class verdict makes the actionable difference visible:

- **DEEP**: "Stop running `--refine` against unchanged code; the setup is anchored. Next round: when you ship more features."
- **WEAK**: "Stop running `--refine` against unchanged code; you're stuck at a low ceiling because extraction was thin. Next round: grow upstream signal first."

Both verdicts say "stop running `--refine`" — but for opposite reasons that imply opposite next steps.

## Anti-patterns this rubric exists to prevent

1. **The "I rewrote everything" trap** — without scoring, REFINE could rewrite anchored artifacts repeatedly, churning diffs without improving content. The threshold (skip ≥ 70) prevents this.
2. **The "REFINE never converges" trap** — without plateau detection, the user has no signal that "we're done." Plateau converts subjective "is this good enough?" into a measurable answer.
3. **The "high score, no signal" trap** — an artifact could score 100 by stuffing the block with identifiers and paths copied from another project (LEAK). The verification rule (cross-check against extraction; deduct 5 per ghost) prevents this.
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
