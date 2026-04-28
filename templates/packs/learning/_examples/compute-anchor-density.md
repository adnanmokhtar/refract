---
name: compute-anchor-density
description: Score the anchor-density of a generated artifact (rule / agent / skill / command / ai-file) on four axes (name density, path density, signal density, specificity) for a total 0-100. Used by /setup-project Phase 5.5 in REFINE mode to identify which artifacts are shallow (< 70) and need round-two re-anchoring, AND to detect plateau (Δ ≤ 2 between runs = "no further refinement available").
---

# Skill: compute-anchor-density

## Purpose

REFINE rewrites only artifacts whose round-one anchor is shallow. To decide which is "shallow," we need a deterministic score, not a vibe check. This skill is the score. It's also the plateau detector — when 2nd / 3rd `--refine` runs produce Δ ≤ 2 points across the artifact set, REFINE exits with "plateau reached."

## When to use

- `/setup-project --refine` Phase 5.5 — score every Phase-4-generated artifact (`.claude/agents/*.md`, `.claude/skills/*.md`, `.claude/rules/*.md`, `.claude/commands/*.md`, `ai/*.md`).
- Internally by Phase 4.6-DEEP — to identify which artifacts to re-anchor (skip ≥ 70).
- On-demand via `/health` when the user wants to know "how anchored is my setup, really?"

## Inputs

- `artifact_path` — absolute path to the file to score.
- `extracted_codebase_path` — `.claude/_extracted-codebase.md` (round-one extraction substrate).
- `refine_extract_path` (optional) — `.claude/_refine-extract.md` (round-two extraction substrate; required for high signal-density scores).

## Procedure

### Step 1 — Locate the `## Project-specific` block

Every Phase-4-generated artifact ships with markers:

```
<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with `/setup-project --refine`)

...content...

<!-- project-specific:end -->
```

If markers are absent → the artifact has zero project-specific anchor. Score = 0/100. Record reason: `markers-missing` (this is a round-one bug; flag for re-run of standard Phase 4.6, not REFINE).

If markers present → extract the block content (between the markers). All scoring below applies to this block.

For `ai/*.md` files, the markers are `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->`. If absent in REFINE mode, score the whole file body but cap "name density" at 12/25 (since the round-one auto-population did include detected facts, just not deeply).

### Step 2 — Score Name density (0-25)

Count concrete project identifiers in the block. An identifier is:

- A class / function / module name from `_extracted-codebase.md` § "Identifiers" or `_refine-extract.md` (any section).
- A table column / model field / migration name.
- An endpoint path (e.g. `POST /api/invoices`).
- A package/module name from this project (NOT external libs).

Rules:
- Each unique identifier counts ONCE (repetition doesn't multiply).
- Identifiers must appear verbatim in extraction. Cross-check. If the artifact cites `BillingService.create_invoice` but extraction shows `BillingService.create_invoice_with_line_items`, that's a MISCITATION — DEDUCT 5 (capped at 0).

Scoring:
- 0 unique identifiers → 0
- 1-2 → 8
- 3 → 13
- 4 → 18
- 5 → 22
- ≥ 6 → 25

### Step 3 — Score Path density (0-25)

Count concrete file path or `file:line` citations in the block.

Rules:
- A bare `file.py` is a path. A `file.py:42` is a path-with-line (counts as 1, but verified-existence carries more weight).
- For each citation, verify the file exists in the project (use the codebase profile's file inventory). If the cited file does NOT exist → MISCITATION, deduct 5 per ghost path.
- For `file:line` citations, the verification is harder (we can't always confirm the line). Heuristic: if the file exists AND total lines ≥ cited line, accept. Otherwise flag as ghost.

Scoring (after deductions):
- 0 → 0
- 1 → 8
- 2 → 13
- 3 → 18
- 4 → 22
- ≥ 5 → 25

### Step 4 — Score Signal density (0-25)

Signal density measures how many of the deep-extraction inputs the block actually consumes. Sources:

| Signal | Where to find it in `_refine-extract.md` |
|---|---|
| domain-entity | `## Domain entities` — entity names with field lists |
| invariant | `## Domain entities` → `cross_entity_invariants` or per-entity `invariants:` |
| lifecycle-event | `## Domain entities` → per-entity `lifecycle_events:` |
| flow | `## Flows` — flow names |
| hot-path | `## Hot paths` — path names |
| n+1-citation | `## Hot paths` → per-path `n_plus_1_sites:` |
| missing-index | `## Hot paths` → per-path `missing_indexes:` |
| layer-or-boundary | `## Architecture` — layer or boundary names |
| emergent-convention | `## Conventions (emergent)` — pattern names |
| failure-theme | `## Failure history` → `recurring_themes:` |

Count distinct signal categories the block consumes. A block can cite a `domain-entity` AND a `flow` AND an `emergent-convention` — that's 3 distinct signals.

Rules:
- Only count if the upstream extraction is STRONG for that signal (see each extraction skill's quality gate). A WEAK extraction can't be consumed productively.
- A block is said to "consume" a signal if it uses the signal's NAME and at least 1 of the signal's FIELDS (citation, count, etc.).

Scoring:
- 0 distinct signals consumed → 0
- 1 → 8
- 2 → 13
- 3 → 18
- 4 → 22
- ≥ 5 → 25

### Step 5 — Score Specificity (0-25)

Start at 25. Deduct for generic-prose phrases. Each phrase = -5, capped at 0.

Generic phrases (case-insensitive substring):

- `<TODO>`, `<FIXME>`, `<...>` (any angle-bracket placeholder).
- `<base>`, `<class>`, `<entity>`, `<service>`, `<module>` (placeholder identifiers).
- `the project's <X>` (with literal `<X>` left in).
- `your service layer`, `your repository`, `your controller` (generic referent without a name).
- `use parameterized queries` (without naming the project's actual ORM / data-access lib).
- `follow framework conventions` (without naming the framework).
- `apply best practices` (without specifying which).
- `as appropriate for your stack`, `depending on your setup`.
- `# project-specific content goes here` or any auto-comment indicating un-filled-in content.

Each occurrence is one deduction. (A block with 5 occurrences = score 0.)

### Step 6 — Compute total + classify

Total = sum of the 4 axes (range: 0-100).

Classification:
- **DEEP** ≥ 85 — the block is concrete enough that an agent reading it gets project-specific guidance. Phase 4.6-DEEP skips this artifact (further re-anchoring won't help much).
- **ANCHORED** 70-84 — sufficient. Phase 4.6-DEEP skips by default but rewrites if `--refine --aggressive` is passed.
- **SHALLOW** < 70 — Phase 4.6-DEEP rewrites this artifact's `## Project-specific` block.
- **MISSING** = 0 (markers absent OR block empty) — flag separately; not a REFINE concern (it's a Phase 4.6 / round-one bug).

### Step 7 — Compute plateau verdict (when scoring multiple artifacts for the run)

After scoring all artifacts, compare to the prior `.claude/_setup-quality.md` (if present):

```
plateau_delta    = avg(this_run_scores) - avg(prior_run_scores)
plateau_consumed = signals_consumed_this_run / signals_available_in_refine_extract
weak_phase_count = count(phases in 2.7..2.12 with [REFINE-WEAK: ...] flag)
avg_score        = avg(this_run_scores)
```

The plateau verdict is THREE-WAY — never a single binary. The two plateau classes carry very different user actions:

| Verdict | Conditions | Per-artifact tag | Run-level message |
|---|---|---|---|
| **PLATEAU-DEEP** | `plateau_delta ≤ 2` AND `plateau_consumed ≥ 0.85` AND `avg_score ≥ 80` | `LEAVE-DEEP-IDEMPOTENT` | "Plateau reached (DEEP) — setup is anchored; further `--refine` adds nothing meaningful." |
| **PLATEAU-WEAK** | `plateau_delta ≤ 2` AND (`plateau_consumed < 0.85` OR `avg_score < 80`) — i.e. we converged but to a low ceiling because upstream extraction was thin | `LEAVE-DEEP-IDEMPOTENT` (with `weak_phases:<list>` in the row) | "Plateau reached (WEAK) — setup is NOT yet anchored deeply, but no further refinement is possible from current extraction. <N> phases produced WEAK output. Grow upstream signal before re-running." |
| **NOT-PLATEAU** | `plateau_delta > 2` OR no prior baseline | (none) | (no plateau message — REFINE may climb on next run) |

**Critical**: NEVER emit "Plateau reached" without one of `(DEEP)` or `(WEAK)`. A bare "plateau reached" + score 58 is the misleading-message bug this classifier exists to prevent.

**The full set of plateau-WEAK reasons** the run-level message must enumerate (so the user knows what to grow):

- Phase 2.7 (entities) WEAK → "add more domain models / migrations / Pydantic-or-Zod schemas"
- Phase 2.8 (architecture) WEAK → "add more clearly-bounded modules / cross-cutting middleware"
- Phase 2.9 (flows) WEAK → "trace more endpoints (need ≥5 total)"
- Phase 2.10 (conventions) WEAK → "let conventions emerge across more files (need patterns recurring 5+ times)"
- Phase 2.11 (hot paths) WEAK → "add monitoring config / Datadog dashboard / git churn signal"
- Phase 2.12 (failures) WEAK → "accumulate more git history (need ≥30 commits) OR opt into `--include-incidents=<path>`"

The skill MUST emit ALL relevant reasons — silence on a WEAK axis is the same misleading-message bug.

## Output

Per-artifact JSON (in-memory; aggregated by Phase 5.5 into `_setup-quality.md`):

```json
{
  "artifact": ".claude/rules/database.md",
  "name_density": 22,
  "path_density": 18,
  "signal_density": 25,
  "specificity": 23,
  "total": 88,
  "classification": "DEEP",
  "signals_consumed": ["domain-entity", "hot-path", "n+1-citation", "missing-index"],
  "deductions": [],
  "miscitations": [],
  "delta_from_prior": 46,
  "plateau_idempotent": false
}
```

Run-level JSON (one per `--refine` invocation):

```json
{
  "run_timestamp": "2026-04-28T09:14:00Z",
  "artifact_count": 18,
  "avg_score": 81,
  "avg_score_prior": 47,
  "plateau_delta": 34,
  "plateau_consumed": 0.92,
  "weak_phases": [],
  "verdict": "NOT-PLATEAU",
  "verdict_message": "REFINE climbed +34 points; no plateau yet."
}
```

Or, on a converged DEEP run:

```json
{
  "verdict": "PLATEAU-DEEP",
  "verdict_message": "Plateau reached (DEEP) — setup is anchored at avg 81/100 with 92% of signal consumed. Further --refine adds nothing meaningful. Stop running --refine until significant new code lands.",
  "weak_phases": []
}
```

Or, on a converged WEAK run:

```json
{
  "verdict": "PLATEAU-WEAK",
  "verdict_message": "Plateau reached (WEAK) — setup is NOT yet anchored deeply (avg 58/100), but no further refinement is possible. 4 of 6 deep-extraction phases produced WEAK output. Grow upstream signal before re-running --refine.",
  "weak_phases": ["entities", "flows", "hotpaths", "failures"],
  "weak_phase_actions": {
    "entities": "add more domain models / migrations / schemas",
    "flows": "trace more endpoints (need >=5 total)",
    "hotpaths": "add monitoring config / git churn signal",
    "failures": "accumulate more git history OR --include-incidents=<path>"
  }
}
```

Aggregate goes into `.claude/_setup-quality.md` per the format defined in setup-project.md Phase 5.5.

## Anti-patterns

- **Counting an identifier that's only in the artifact's body, not in the `## Project-specific` block** — only the block counts. Body is generic teaching prose; the block is the project anchor.
- **Counting external lib names as identifiers** — only THIS project's identifiers count. `pandas.DataFrame` is not an anchor; `app/services/billing.py:BillingService` is.
- **Crediting a citation that's a ghost** — if the file doesn't exist, the citation is worse than missing. Deduct.
- **Adding bonus points for length** — verbose blocks are not deeper. Keep the scoring axes pure.
- **Self-fulfilling plateau** — if extraction is WEAK across the board, scores will be capped (signal density 0); reporting "plateau reached" without classifying as PLATEAU-WEAK is misleading. The verdict MUST be one of `PLATEAU-DEEP` / `PLATEAU-WEAK` / `NOT-PLATEAU` — never a bare "plateau reached" string.
- **Single-line plateau verdict in the JSON** — the run-level JSON's `verdict_message` MUST enumerate weak phases when verdict is `PLATEAU-WEAK`. Silence on a WEAK axis defeats the diagnostic purpose of the verdict.
