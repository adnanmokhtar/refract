# Results

<!-- history:banner:begin -->
> Every row below is GENERATED from `benchmarks/results/history.jsonl` by
> `python3 benchmarks/history.py render`, and carries the model, its version, the date and the
> Refract commit it measured. Cite a number only with its row; a row without those is not a result.
<!-- history:banner:end -->

The harness was built and self-tested; the commands were not run. Running them requires an
interactive agent session, which the harness deliberately does not simulate. See
[README.md](README.md) for the method and its limits.

---

## What was verified (this is not a result)

Distinguishing what is checked from what is measured, so the two never get conflated:

| Checked | How | Status |
|---------|-----|--------|
| Every seeded anchor resolves to its recorded line | `run.sh --verify` | 413/413 across 10 fixtures (106 of them decoys) |
| Staging never leaks the answer key | `run.sh --fixture=<n>`, then `find` for `DEFECTS.md` | 0 copies staged |
| Staged tree is byte-identical to source minus `DEFECTS.md` | `diff -r --exclude=DEFECTS.md` | identical |
| Scorer credits a correct report | synthetic findings → known ids | maps as intended |
| Scorer refuses a right-line / wrong-description report | synthetic adversarial findings | not credited |
| Scorer parses both JSON and text findings | both shapes | both parse |
| Fixture content trips no `secret-scan` pattern | the real hook, over every `benchmarks/` file | permitted |

None of these say anything about `/audit`, `/align` or `/roadmap`. They say the ruler is
straight.

---

## Detection results

<!-- history:detection:begin -->
| date | fixture | command | model | model version | sha | runs | detected | recall | severity-wtd | decoy precision | unmatched | notes |
|------|---------|---------|-------|---------------|-----|------|----------|--------|--------------|-----------------|-----------|-------|
| — | — | — | — | — | — | — | — | — | — | — | — | *no run recorded* |
<!-- history:detection:end -->

Generated from [`results/history.jsonl`](results/history.jsonl) by `python3 benchmarks/history.py render`
(row schema `refract/bench-run/v1`: the docstring of [`history.py`](history.py)). `recall` = detected /
seeded; `decoy precision` = decoys left unflagged / decoys, on fixtures that declare decoys.

Seeded totals, for the denominators above: `node-api` 21 (20 seeded + 1 found later, NAPI-DATA-01) · `web-dashboard` 14 ·
`half-built-crm` 16.

`unmatched` is the count of reported findings that mapped to no seeded id. **It is not a
false-positive count** and must not be published as one — see
[README.md § Unmatched is not the same as false](README.md#unmatched-is-not-the-same-as-false).

---

## How to record a run

1. Stage a fixture and read the printed instructions:

   ```bash
   bash benchmarks/run.sh --fixture=node-api
   ```

2. In an agent session whose working directory is the **staged copy**, run the single
   command the runner printed and nothing else. No scope hints, no file names.

3. Paste every reported finding — in the agent's own wording, including ones you think are
   wrong — into the findings file the runner created.

4. Score, naming the model:

   ```bash
   python3 benchmarks/score.py --fixture=node-api \
     --findings=<findings file> \
     --model="<exact model id>" \
     --model-version="<build / snapshot / release date>" \
     --date=<YYYY-MM-DD> --row
   ```

5. Append the run to the time series and regenerate the tables (never edit a table by hand):

   ```bash
   python3 benchmarks/score.py --fixture=node-api --findings=<findings file> \
     --model="<exact model id>" --model-version="<build>" --date=<YYYY-MM-DD> --json > <run>.json
   python3 benchmarks/history.py append --from-score-json=<run>.json --findings=<findings file> [--runs=N]
   ```

   The row records the Refract commit (`git rev-parse HEAD`, `+dirty` when the tree had changes).
   `python3 benchmarks/history.py render --check` fails when this file and the series disagree.

6. **Keep the raw findings file** and link it from the notes column. A row whose evidence
   was deleted cannot be audited and should be treated as an anecdote.

---

## Plugin eval results

Each pack's `evals/` suite under `claude plugin eval` — with the pack loaded and without it, 3 runs per
case, pinned models (`.github/workflows/refract-evals.yml`; `bash scripts/run-pack-evals.sh`). `Δ` is
the with-pack score minus the no-pack score; a pack ships only with Δ > 0 (spec § 8.8). Partial runs
(cost ceiling hit, paid graders skipped) are refused by `history.py append-eval`.

<!-- history:eval:begin -->
| date | pack | model | judge | sha | cases passed | score | Δ vs no-plugin | cost | notes |
|------|------|-------|-------|-----|--------------|-------|-----------------|------|-------|
| 2026-10-19 | security | claude-sonnet-5-5 | claude-haiku-5-5 | 1daf19e9c60f | 2/2 | 1.00 | +0.00 | $0.50 | — |
<!-- history:eval:end -->

### Rules for this table

- **Never write an estimate.** No projected, expected, or illustrative rows. If it was not
  run, the cell stays empty.
- **One row per run, not per best run.** If you ran a fixture five times, that is five
  rows, or one row that states the count and the spread in notes. Reporting the best of
  five as a single figure is fabrication.
- **State the framework's role.** Was Refract installed in the staged copy? Which packs?
  A run with no packs loaded is a different experiment, and interesting — label it.
- **Re-run the table when the harness changes.** Widening a `match:` pattern or seeding a
  new defect changes what past rows measured. Note the change here and mark the affected
  rows stale rather than leaving them to be compared with rows that are not.
- **Say how many runs.** One run is an anecdote. Write "n=1" in notes if that is what it
  is.
