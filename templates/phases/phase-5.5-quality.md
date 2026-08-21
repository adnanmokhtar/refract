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

**Mechanism**: invoke the `compute-anchor-density` skill (lives in `~/.claude/templates/packs/learning/skills/compute-anchor-density/SKILL.md`) for every Phase-4-generated artifact (`.claude/agents/*.md`, `.claude/skills/*/SKILL.md`, `.claude/rules/*.md`, `.claude/commands/*.md`, `ai/*.md`). The skill scores each file on four axes (each 0–25, total 0–100):

1. **Name density** (0–25): how many concrete project identifiers (class names, function names, table names, endpoint paths, package names) appear in the `## Project-specific` block. ≥ 6 = full marks; 0 = zero.
2. **Path density** (0–25): how many concrete `file:line` or `file/path/` citations appear in the block, AND whether each citation is verified to exist in `.claude/_extracted-codebase.md` or `.claude/_refine-extract.md`. ≥ 5 verified = full marks.
3. **Signal density** (0–25): how many of the deep-extraction inputs (entities, flows, hot paths, emergent conventions, failure themes) the block actually consumes — only counts when the block exists AND the upstream extraction yielded STRONG results. ≥ 4 distinct signals consumed = full marks.
4. **Specificity** (0–25): the inverse of generic-prose ratio. Counts placeholder-y phrases (`<TODO>`, `<base>`, `the project's <X>`, "use parameterized queries", "follow framework conventions" — no specific framework named) and deducts 5 per phrase up to 25.

Total per artifact = sum of the four. Reported in `.claude/_setup-quality.md`.

**Plateau is two-class** — never a single binary. The user reading the report MUST know whether the plateau means "we're done because everything is deep" (good) or "we're stuck because extraction was weak" (the user has work to do upstream before another `--refine` will help). The plateau classifier:

| Class | Condition | Message | What the user should do |
|---|---|---|---|
| **PLATEAU-DEEP** | `plateau_delta ≤ ΔMax` AND `plateau_consumed ≥ Cmin` AND `avg_score ≥ Smin` | `## Plateau reached (DEEP) — setup is anchored; further --refine adds nothing meaningful.` | Stop running `--refine` until significant new code lands. |
| **PLATEAU-WEAK** | `plateau_delta ≤ ΔMax` AND (`plateau_consumed < Cmin` OR `avg_score < Smin`) — it converged, but not to a DEEP state: either less than `Cmin` of available signal was consumable (the upstream extraction phases hit their `[REFINE-WEAK: <axis>]` quality gates) or the average never reached `Smin` | `## Plateau reached (WEAK) — setup is NOT yet anchored deeply, but no further refinement is possible from current extraction. <N> phases produced WEAK output: <list>.` | Grow upstream signal: more commits (failure-history), more code/tests (entities/flows), opt into `--include-incidents=<path>` if postmortems exist, etc. THEN re-run `--refine`. |
| **NOT-PLATEAU** | `plateau_delta > ΔMax` OR (first run with no prior baseline) | (no plateau message) | Re-running `--refine` would still climb. Run again if score < 70 average. |

**Default thresholds (tunable via flags):**
- `ΔMax = 2`   — override with `--plateau-delta=<N>`
- `Cmin = 0.85` — override with `--plateau-consumed=<F>`
- `Smin = 80`   — override with `--plateau-score=<N>`

**The two plateau classes are exhaustive by construction** — `PLATEAU-WEAK` is `plateau_delta ≤ ΔMax` AND NOT `PLATEAU-DEEP`. That is why the `OR` in its condition is not a typo: with `AND` a converged run at `plateau_consumed = 0.9, avg_score = 75` would match neither class, and the exit table at the end of this file would have no verdict to read. The same `OR` form is already carried by `templates/packs/learning/skills/compute-anchor-density/SKILL.md § Step 7`, `templates/packs/learning/ai-patterns/setup-quality-scoring.md § Plateau detection` and `commands/setup-project.md § Phase 5.5`; this table was the outlier.

**Every `PLATEAU-WEAK` carries a reason**, because the three that reach it call for three different actions and the message template above ("<N> phases produced WEAK output") only fits the first: `signal` — less than `Cmin` was consumable, so grow the codebase; `score` — the substrate *was* consumed (`plateau_consumed ≥ Cmin`) and the artifacts still did not anchor above `Smin`, so the generators are the problem, not the extraction; `coverage` — the `[SAMPLED]` demotion below, so raise the sample. A bare `PLATEAU-WEAK` with no reason is the same defect as a bare `## Plateau reached`.

The reason is **emitted, not inferred here**: `compute-anchor-density § Step 7` computes it and the run-level JSON carries it as `"reason": "signal" | "score" | "coverage"`, alongside `sampled_sections` and `coverage_accepted`. That wiring used to be missing — this file specified a three-way branch against a JSON with no field to branch on, so every WEAK run would have printed the `signal` message, which is wrong advice for the other two (`score` blames the codebase for a generator failure; `coverage` tells a user to write code they have already written but which was never read). Do not re-derive the reason from `weak_phases`: the coverage case has an EMPTY `weak_phases` list by construction, and a consumer inferring from that list reads "nothing weak" and prints the DEEP message under a WEAK verdict.

**Why thresholds are tunable**: the defaults above are theoretical — calibrated against synthetic fixtures, not against a real-world corpus of `--refine` runs. As REFINE telemetry accumulates in `.claude/_setup-quality.md` history across many projects, maintainers should re-evaluate whether `2 / 0.85 / 80` actually predicts "stop running --refine" for the median project, OR whether the classifier should be more aggressive (lower `ΔMax`, higher `Smin`) to push users toward growing upstream signal. For now: defaults are conservative — they prefer "keep climbing" over "declare plateau," because the cost of an extra REFINE run (a few minutes, no user-content damage thanks to marker safety) is much less than the cost of stopping at score 65 thinking the setup is done.

**Critical**: a plain `## Plateau reached` message is forbidden. The classifier MUST tag DEEP vs WEAK. A user seeing "plateau reached" with score 58 should immediately understand "we plateaued because there's nothing more to consume, not because we got everything." The two-class messaging is the contract.

#### Coverage precondition on PLATEAU-DEEP

`PLATEAU-DEEP` asserts *the substrate is exhausted*. That claim is false whenever round-one extraction only read part of the source: `signals_consumed = 92%` measures the fraction of the signals that were **extracted**, not the fraction of the codebase they were extracted **from**. If `## Conventions` rested on 10 of 412 files, 92% of an 8% sample is not exhaustion — it is exhaustion of the part that was read.

**Rule**: while `_extracted-codebase.md` carries any `[SAMPLED: <seen>/<present> <unit>]` section marker, `PLATEAU-DEEP` may not be emitted. The verdict becomes `PLATEAU-WEAK` with reason `coverage`. The markers reach the classifier as `compute-anchor-density`'s `sampled_sections` input, and the `PLATEAU-DEEP` row of that skill's verdict table carries the precondition — the rule is enforced where the verdict is computed, not only asserted here.

**What makes that demotion observable, and what nearly made it inert.** The exit table at the end of this file is *verdict-first*: `PLATEAU-WEAK` exits `2` whatever the average is. Read the other way round — exit `0` on any `avg_score ≥ 70`, with the verdict as a tie-break — this demotion would be **unreachable by construction**, not merely rare: `PLATEAU-DEEP` already requires `avg_score ≥ Smin` (`80`), so every run the demotion can possibly fire on has already cleared 70 and would exit `0` no matter which verdict it carried. The worked example below scores 81 and is exactly that case. The precedence rule *is* the wiring; without it this whole section is a message change wearing an enforcement costume. `commands/setup-project.md:333-334` states the same verdict→exit mapping (DEEP → exit 0, WEAK → exit 2, no score override), so the two files agree rather than one inventing a rule.

The demotion is driven by the **`[SAMPLED]` section markers**, not by the raw coverage percentage. The percentage informs the human; the markers drive behaviour. This matters because `files_cited` under-counts by construction (a file can be read and cite nothing), so a healthy run can show 15% and be fine — gating on that number produces noisy exit-2 runs and the feature gets switched off.

**Coverage may only ever demote, never promote.** It can block `PLATEAU-DEEP`; it can never raise a score or upgrade a verdict. Once a percentage gates a verdict, the cheapest way to move it is to cite files gratuitously — and the citation-path check catches *ghost* citations, not *padding*. A metric that can only cost you is not worth gaming. Do not relax this.

**Escape hatch, so the rule stays usable**: Step 8-class sampling fires on almost every non-trivial repo, so an un-escapable rule would make `PLATEAU-DEEP` unreachable and train users to ignore exit 2. A maintainer who has read `## Coverage` and judged the sample sufficient records `coverage-accepted: <name>@<iso> — <seen>/<present> <unit> reviewed` in `.claude/_setup-quality.md`; `PLATEAU-DEEP` is then available again and the report prints the acceptance beside the verdict. The acceptance is a human statement on the record, not a flag the tool can set for itself, and it is scoped to the coverage figures it names — new figures need a new acceptance.

The WEAK message template below already has the right shape for this ("Grow signal first"); the coverage variant reads **"raise coverage first"** — re-run without `--lightweight`, or raise the per-category sample — which is a different and more actionable instruction than "go write more code."

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
| `.claude/skills/parallelize-independent-ops/SKILL.md` | 51 | 84 | +33 | DEEP — cites 4 hot paths with N+1 |
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

Exit: 0 (verdict is DEEP).
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
Exit: 2 (verdict is WEAK, reason `signal`).
```

Contrast again — the coverage-blocked variant, where the substrate is NOT exhausted and the instruction is the opposite one:

```markdown
## Plateau verdict
**PLATEAU-WEAK (reason: coverage)** — scores plateaued at avg 81/100 and signals_consumed = 92%, but round-one extraction cited 214 of 1,204 source files (18%). `signals_consumed` measures the extracted signals, not the source they came from, so this is NOT a DEEP plateau — the substrate was never exhausted, only the part that was read.
- `## Conventions` [SAMPLED: 10/412 files] — every convention-derived anchor is carried as `[inferred:]` and was re-verified against source before anchoring.
- `## Architecture` [SAMPLED: 8/1,204 files] — import-graph direction rests on the sampled files only.
**Raise coverage first**, then re-run `--refine`: re-run extraction without `--lightweight`, or raise the per-category sample in `extract-codebase-overview` Step 8. If 10/412 is genuinely enough for this project, record `coverage-accepted:` in this file and `PLATEAU-DEEP` becomes available again.
Exit: 2 (verdict is WEAK; avg 81 does not override it).
```

**Exit codes** — evaluated in this order, first match wins. **The verdict outranks the score**: a passing average never cancels a WEAK verdict.

1. `1` — hard error (rollback occurred, missing required input, schema validation failed).
2. `2` — `PLATEAU-WEAK`, for either reason. "Rerunning `--refine` will not help; act upstream." Honouring this in CI lets a maintainer surface "REFINE didn't help" without conflating it with hard errors. Reason `signal` → grow the codebase; reason `score` → fix the generators; reason `coverage` → raise the sample. The coverage reason is the one that exits `2` on a *high* average — avg 81 with `[SAMPLED]` markers still exits `2`, because the 81 was scored over the part of the source that was read.
3. `0` — `PLATEAU-DEEP` (converged and anchored), or `NOT-PLATEAU` (has not converged — re-run it).

`avg_score ≥ 70` is the "anchored" threshold the report prints and the frontmatter's exit criterion; it is **reported, not gated**. A `NOT-PLATEAU` run below 70 still exits `0`, because the correct action there is "run `--refine` again", not the upstream action exit `2` means, and failing CI on an unconverged first run against a young repo would train maintainers to ignore the code.

**This ordering used to be implicit, and the ambiguity was load-bearing.** Written as an unordered set — `0` on `PLATEAU-DEEP OR avg_score ≥ 70`, `2` on `PLATEAU-WEAK` — both rules matched every plateaued run scoring ≥ 70, which is *every* run the coverage demotion above can reach, and the `NOT-PLATEAU`-below-70 case matched none of the three. The old set was latent while the only WEAK example in this file scored 58; the coverage demotion put it on the load-bearing path.

**Idempotency check**: REFINE compares the new score to the prior `.claude/_setup-quality.md` (if present). If 2nd / 3rd `--refine` run produces Δ ≤ 2 points, REFINE writes the report and emits the appropriate plateau verdict per the classifier above. The plain "## Plateau reached — no further refinement needed" wording is NEVER emitted alone — it is always one of the two classes.

---

