# Seeded regressions — `regression-baseline`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans.

Fixture shape: `pricing` — a "refactor" PR (extract two helpers in `pricing/quote.py`) that silently changes tax rounding on two sampled cases and makes quoting 20% slower; the base ships a registered characterization baseline and a performance entry; 2 seeded regressions, plus a recorded identical-run noise set.

Stage with: --git --diff --baseline
Invocation: /review-changes

`base/` is committed with its behavioural-baseline registry (`.claude/baselines/main/manifest.json`:
a characterization entry over `tests/characterization/quote/` — 8 sampled cases, golden-master format
of `parity-test-generate` — and a performance entry over `bench/bench_quote.py`); `change/` is laid
over it as the uncommitted "refactor". `--baseline` installs the repo-baseline `.claude/` layer, so
`gate-check.py`, `behavior-diff.py` and `perf-compare.py` run in the staged copy.

## Two halves

1. **Mechanical — the Phase-5 proving gate** (architecture proposal §10 Phase 5). Run by
   `tests/hooks/run.sh` § Phase 5 on every CI push, no model involved:
   - the silent behaviour change → **G14 FAIL** (`behavior-diff.py`: cases `021-edge-discount-threshold`
     and `023-edge-half-cent-tax` — 742.5 and 82.5 cents of tax now round half-even through a float);
   - the slowdown → **G4 FAIL** (`perf-compare.py`, base and head interleaved, REGRESSION ≈ +20%,
     95% CI wholly past the 10% `THR-PERF-REGRESSION` threshold);
   - **10 identical runs → 0 false blocks** — a comment-only change, live, plus the recorded
     `noise/identical-10x10.json` pairs (NO-CHANGE);
   - the controls: an AC declaring the cases (`changes_baseline`) turns G14 into EXPLAINED (and G4
     for the bench), a golden file re-recorded without one is a `test-integrity.py` finding, a P5
     capture lands in `.claude/baselines/<sha>/`, a nondeterministic entry is quarantined.
   By hand: stage the fixture, then in the copy
   `REFRACT_G4_LOCAL=1 python3 .claude/scripts/gate-check.py --local --only=G4,G14 --mode=block`.
2. **Agent-scored** — does a diff review find what the "refactor" broke? Score the
   `/review-changes` findings with `run.sh --score`. A reviewer that reports "behaviour preserved"
   on this diff has read the helper names, not the arithmetic.

Line numbers are exact against `change/`; `run.sh --verify` re-checks every anchor.

## Summary

| id | file:line | severity | class |
|----|-----------|----------|-------|
| RB-BEH-01 | `change/pricing/quote.py:20` | high | behaviour/silent-rounding-change |
| RB-PERF-01 | `change/pricing/quote.py:29` | medium | performance/regression-on-hot-path |

```defect
id:       RB-BEH-01
file:     change/pricing/quote.py
line:     20
severity: high
command:  /review-changes
class:    behaviour/silent-rounding-change
anchor:   return int(round(amount))
match:    round|half.?(even|up|cent)|banker|float|rounding|behaviou?r (change|differ)|not (a )?refactor
```

```defect
id:       RB-PERF-01
file:     change/pricing/quote.py
line:     29
severity: medium
command:  /review-changes
class:    performance/regression-on-hot-path
anchor:   return [line for line in order["lines"]]
match:    copy|copies|allocat|slow|regress|perf|extra (pass|list)|per (call|quote)|hot path
```
