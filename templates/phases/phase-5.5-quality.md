---
phase: 5
sub-phase: "5.5"
name: setup-quality-score
applies-to-modes: [REFINE]
inputs: [generated-artifacts, .claude/_setup-quality.md previous version]
outputs: [.claude/_setup-quality.md (per-artifact density score: name, path, signal, total)]
exit-criteria: per-artifact score >= 70 OR plateau verdict emitted
imported-by: templates/phases/phase-5-verify.md
---

### Phase 5.5 — Setup-quality score (REFINE mode only)

**Trigger**: REFINE mode (`--refine`). Standard modes use the lighter `--health` flag; REFINE produces a richer per-artifact score.

**Why this exists**: REFINE rewrites only artifacts whose round-one anchor was shallow. To decide which is "shallow," we need a deterministic score, not a vibe check. The score is also what tells the user "round two added X points; running `--refine` again would add ≤ 2 — plateau reached, stop here."

**Mechanism**: invoke the `compute-anchor-density` skill (lives in `~/.claude/templates/packs/learning/skills/compute-anchor-density.md`) for every Phase-4-generated artifact (`.claude/agents/*.md`, `.claude/skills/*.md`, `.claude/rules/*.md`, `.claude/commands/*.md`, `ai/*.md`). The skill scores each file on four axes (each 0–25, total 0–100):

1. **Name density** (0–25): how many concrete project identifiers (class names, function names, table names, endpoint paths, package names) appear in the `## Project-specific` block. ≥ 6 = full marks; 0 = zero.
2. **Path density** (0–25): how many concrete `file:line` or `file/path/` citations appear in the block, AND whether each citation is verified to exist in `.claude/_extracted-codebase.md` or `.claude/_refine-extract.md`. ≥ 5 verified = full marks.
3. **Signal density** (0–25): how many of the deep-extraction inputs (entities, flows, hot paths, emergent conventions, failure themes) the block actually consumes — only counts when the block exists AND the upstream extraction yielded STRONG results. ≥ 4 distinct signals consumed = full marks.
4. **Specificity** (0–25): the inverse of generic-prose ratio. Counts placeholder-y phrases (`<TODO>`, `<base>`, `the project's <X>`, "use parameterized queries", "follow framework conventions" — no specific framework named) and deducts 5 per phrase up to 25.

Total per artifact = sum of the four. Reported in `.claude/_setup-quality.md`.

**Plateau is two-class** — never a single binary. The user reading the report MUST know whether the plateau means "we're done because everything is deep" (good) or "we're stuck because extraction was weak" (the user has work to do upstream before another `--refine` will help). The plateau classifier:

| Class | Condition | Message | What the user should do |
|---|---|---|---|
| **PLATEAU-DEEP** | `plateau_delta ≤ ΔMax` AND `plateau_consumed ≥ Cmin` AND `avg_score ≥ Smin` | `## Plateau reached (DEEP) — setup is anchored; further --refine adds nothing meaningful.` | Stop running `--refine` until significant new code lands. |
| **PLATEAU-WEAK** | `plateau_delta ≤ ΔMax` AND `plateau_consumed < Cmin` (i.e. less than `Cmin` of available signal was consumable because the upstream extraction phases hit their `[REFINE-WEAK: <axis>]` quality gates) | `## Plateau reached (WEAK) — setup is NOT yet anchored deeply, but no further refinement is possible from current extraction. <N> phases produced WEAK output: <list>.` | Grow upstream signal: more commits (failure-history), more code/tests (entities/flows), opt into `--include-incidents=<path>` if postmortems exist, etc. THEN re-run `--refine`. |
| **NOT-PLATEAU** | `plateau_delta > ΔMax` OR (first run with no prior baseline) | (no plateau message) | Re-running `--refine` would still climb. Run again if score < 70 average. |

**Default thresholds (tunable via flags):**
- `ΔMax = 2`   — override with `--plateau-delta=<N>`
- `Cmin = 0.85` — override with `--plateau-consumed=<F>`
- `Smin = 80`   — override with `--plateau-score=<N>`

**Why thresholds are tunable**: the defaults above are theoretical — calibrated against synthetic fixtures, not against a real-world corpus of `--refine` runs. As REFINE telemetry accumulates in `.claude/_setup-quality.md` history across many projects, maintainers should re-evaluate whether `2 / 0.85 / 80` actually predicts "stop running --refine" for the median project, OR whether the classifier should be more aggressive (lower `ΔMax`, higher `Smin`) to push users toward growing upstream signal. For now: defaults are conservative — they prefer "keep climbing" over "declare plateau," because the cost of an extra REFINE run (a few minutes, no user-content damage thanks to marker safety) is much less than the cost of stopping at score 65 thinking the setup is done.

**Critical**: a plain `## Plateau reached` message is forbidden. The classifier MUST tag DEEP vs WEAK. A user seeing "plateau reached" with score 58 should immediately understand "we plateaued because there's nothing more to consume, not because we got everything." The two-class messaging is the contract.

The full report:

```markdown
# Setup quality — anchor-density score
> Generated by /setup-project --refine on <YYYY-MM-DD HH:MM>.
> Threshold for "anchored": 70/100. Threshold for "deep": 85/100.

## Summary
- Total artifacts: 18
- Anchored (≥ 70): 14 (was 4 in round one — +10)
- Deep (≥ 85): 6 (was 0 in round one — +6)
- Shallow (< 70): 4 — see § "Refinement opportunities"
- Average score: 81/100 (was 47/100 in round one — +34)
- Plateau check: deep-extraction signals consumed = 92% — re-running `--refine` would add ≤ 2 points.

## Plateau verdict
**PLATEAU-DEEP** — setup is anchored at avg 81/100; signals_consumed = 92% means there's almost nothing left to deepen. Further `--refine` runs will not move scores meaningfully. Stop running `--refine` until significant new code lands.

## Per-artifact scores

| Artifact | Round 1 | Round 2 | Δ | Notes |
|---|---|---|---|---|
| `.claude/rules/database.md` | 42 | 88 | +46 | DEEP — cites 7 entities + 4 hot paths |
| `.claude/rules/code-quality.md` | 65 | 65 | 0 | LEAVE-DEEP — no entity / flow signal applies; round-one anchor is optimal |
| `.claude/agents/backend-architect.md` | 38 | 79 | +41 | ANCHORED — cites 3 lifecycles + 5 boundaries |
| `.claude/skills/parallelize-independent-ops.md` | 51 | 84 | +33 | DEEP — cites 4 hot paths with N+1 |
| ... | | | | |

## Refinement opportunities (artifacts < 70)
- `.claude/rules/security.md` — score 62. Could improve if `.claude/_refine-extract.md` `## Failure history` had STRONG result (currently WEAK). Re-run after committing a `docs/postmortems/` directory.
- ... (3 more)

## Extraction quality (per-axis)
- Phase 2.7 (entities):     STRONG (7 entities, 12 invariants)
- Phase 2.8 (architecture): STRONG (4 boundaries, 5 lifecycles)
- Phase 2.9 (flows):        STRONG (5 flows, all with file:line citations)
- Phase 2.10 (conventions): STRONG (8 emergent patterns)
- Phase 2.11 (hot paths):   STRONG (10 hot paths, 6 with N+1 risk)
- Phase 2.12 (failures):    WEAK (only 18 commits in git log; threshold is 30) — failure-themes section empty
```

Contrast — a WEAK plateau (different project, smaller codebase):

```markdown
## Plateau verdict
**PLATEAU-WEAK** — setup is NOT yet anchored deeply (avg 58/100), but the extraction substrate is exhausted: 4 of 6 deep-extraction phases produced WEAK output (entities, flows, hot paths, failures). Running `--refine` again will not improve scores until you grow upstream signal:
- `entities`: WEAK (only 2 model classes detected) — add more domain models, then re-run.
- `flows`: WEAK (only 1 endpoint traced; threshold is 5) — add more endpoints, then re-run.
- `hot paths`: WEAK (no monitoring config / no Datadog dashboard / no high-churn endpoints) — add more usage signal, then re-run.
- `failures`: WEAK (12 commits; threshold is 30) — accumulate more git history, then re-run.
**Do NOT keep running `--refine` against an unchanged codebase — there's nothing left to consume.** Grow signal first.
```

**Exit codes**:
- `0` if `PLATEAU-DEEP` OR `avg_score ≥ 70` (the setup is good enough or has plateaued in a healthy state).
- `2` if `PLATEAU-WEAK` (the setup is NOT good enough, but rerunning won't help — exit code 2 is "user action required upstream"). Honoring this exit code in CI lets a maintainer surface "REFINE didn't help — go grow signal" without conflating it with hard errors.
- `1` if hard error (rollback occurred, missing required input, schema validation failed).

**Idempotency check**: REFINE compares the new score to the prior `.claude/_setup-quality.md` (if present). If 2nd / 3rd `--refine` run produces Δ ≤ 2 points, REFINE writes the report and emits the appropriate plateau verdict per the classifier above. The plain "## Plateau reached — no further refinement needed" wording is NEVER emitted alone — it is always one of the two classes.

---

