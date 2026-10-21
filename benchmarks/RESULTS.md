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

Rows recorded from the three lanes `run-pack-evals.sh` runs per pack also carry: **ask with / without**
and **ask Δ** — the hard case (`audit-<fixture>-slice`; delivery `spec-…`) asked in plain words, with the
pack loaded and without it; **cmd score** — the same slice and graders behind the pack's own audit command
(`cmd-<fixture>-slice`, one arm); **cmd Δ** = cmd score − ask without, the command against the bare model on
the same ask, the figure a pack must keep above 0; **skill fired** — the share of the plain-ask runs with the
pack in which one of its skills or commands ran. Seed and decoy graders follow `benchmarks/score.py
--strict-line`'s credit rule.

<!-- history:eval:begin -->
| date | pack | model | judge | sha | cases passed | score | Δ vs no-plugin | ask with / without | ask Δ | cmd score | cmd Δ | skill fired | cost | notes |
|------|------|-------|-------|-----|--------------|-------|-----------------|--------------------|-------|-----------|-------|-------------|------|-------|
| 2026-10-19 | ai-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.79 | -0.02 | 0.58 / 0.62 | -0.04 | 0.75 | +0.12 | 100% | $1.81 | — |
| 2026-10-19 | algorithms | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 2/2 | 1.00 | +0.02 | 1.00 / 0.96 | +0.04 | 0.75 | -0.21 | 0% | $0.98 | — |
| 2026-10-19 | align | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.91 | +0.07 | 0.82 / 0.68 | +0.14 | 0.73 | +0.05 | 0% | $1.33 | — |
| 2026-10-19 | backend | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.83 | -0.03 | 0.67 / 0.72 | -0.06 | 0.83 | +0.11 | 0% | $2.60 | — |
| 2026-10-19 | business | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.88 | +0.08 | 0.77 / 0.62 | +0.15 | 0.73 | +0.12 | 50% | $1.75 | — |
| 2026-10-19 | code-quality | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.87 | -0.02 | 0.73 / 0.77 | -0.03 | 0.80 | +0.03 | 0% | $1.26 | — |
| 2026-10-19 | data-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.89 | +0.07 | 0.79 / 0.64 | +0.14 | 0.75 | +0.11 | 0% | $1.17 | — |
| 2026-10-19 | database | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.80 | -0.03 | 0.60 / 0.65 | -0.05 | 0.50 | -0.15 | 0% | $3.02 | — |
| 2026-10-19 | security | claude-sonnet-5-5 | claude-haiku-5-5 | 1daf19e9c60f | 2/2 | 1.00 | +0.00 | — | — | — | — | — | $0.50 | — |
| 2026-10-20 | algorithms | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.98 | +0.02 | 0.96 / 0.92 | +0.04 | 0.88 | -0.04 | 0% | $1.01 | — |
| 2026-10-20 | delivery | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.89 | +0.00 | 0.79 / 0.79 | +0.00 | 0.86 | +0.07 | 0% | $0.96 | — |
| 2026-10-20 | devops | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.90 | -0.04 | 0.81 / 0.88 | -0.08 | 0.88 | +0.00 | 0% | $2.17 | — |
| 2026-10-20 | devops | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.92 | -0.04 | 0.85 / 0.92 | -0.08 | 0.96 | +0.04 | 0% | $1.69 | — |
| 2026-10-20 | distributed-systems | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.93 | -0.00 | 0.85 / 0.85 | -0.00 | 0.75 | -0.10 | 0% | $1.37 | — |
| 2026-10-20 | distributed-systems | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.97 | +0.07 | 0.95 / 0.80 | +0.15 | 0.60 | -0.20 | 0% | $1.76 | — |
| 2026-10-20 | documentation | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.98 | +0.00 | 0.96 / 0.96 | +0.00 | 0.92 | -0.04 | 0% | $1.08 | — |
| 2026-10-20 | documentation | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 2/2 | 1.00 | +0.00 | 1.00 / 1.00 | +0.00 | 0.92 | -0.08 | 0% | $1.31 | — |
| 2026-10-20 | finops | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.82 | +0.02 | 0.64 / 0.59 | +0.05 | 0.59 | +0.00 | 100% | $2.54 | — |
| 2026-10-20 | finops | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.89 | +0.09 | 0.77 / 0.59 | +0.18 | 0.73 | +0.14 | 100% | $2.60 | — |
| 2026-10-20 | frontend | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.78 | +0.03 | 0.56 / 0.50 | +0.06 | 0.50 | +0.00 | 0% | $1.50 | — |
| 2026-10-20 | frontend | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.75 | -0.03 | 0.50 / 0.56 | -0.06 | 0.50 | -0.06 | 0% | $1.50 | — |
| 2026-10-20 | infrastructure | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.94 | +0.02 | 0.88 / 0.83 | +0.04 | 0.75 | -0.08 | 0% | $1.18 | — |
| 2026-10-20 | infrastructure | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.92 | +0.02 | 0.83 / 0.79 | +0.04 | 0.92 | +0.12 | 0% | $1.20 | — |
| 2026-10-20 | learning | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.92 | +0.08 | 0.83 / 0.67 | +0.17 | 0.72 | +0.06 | 0% | $1.18 | — |
| 2026-10-20 | migration | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.95 | +0.07 | 0.90 / 0.75 | +0.15 | 0.90 | +0.15 | 0% | $1.47 | — |
| 2026-10-20 | mobile | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.90 | +0.02 | 0.81 / 0.77 | +0.04 | 0.92 | +0.15 | 0% | $1.74 | — |
| 2026-10-20 | observability | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.97 | +0.06 | 0.94 / 0.83 | +0.11 | 0.67 | -0.17 | 0% | $1.33 | — |
| 2026-10-20 | observability | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.97 | +0.08 | 0.94 / 0.78 | +0.17 | 0.83 | +0.06 | 0% | $1.29 | — |
| 2026-10-20 | performance | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.90 | +0.00 | 0.80 / 0.80 | +0.00 | 0.75 | -0.05 | 0% | $1.60 | — |
| 2026-10-20 | performance | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.90 | +0.00 | 0.80 / 0.80 | +0.00 | 0.85 | +0.05 | 0% | $1.59 | — |
| 2026-10-20 | product | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.81 | -0.04 | 0.62 / 0.71 | -0.08 | 0.67 | -0.04 | 100% | $1.27 | — |
| 2026-10-20 | product | claude-sonnet-5-5 | claude-haiku-5-5 | 5692017dc479 | 1/2 | 0.86 | -0.09 | 0.73 / 0.91 | -0.18 | 0.91 | +0.00 | 100% | $1.28 | — |
| 2026-10-20 | security | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.88 | +0.05 | 0.75 / 0.65 | +0.10 | 0.65 | +0.00 | 0% | $2.56 | — |
| 2026-10-20 | testing | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.85 | +0.04 | 0.71 / 0.62 | +0.08 | 0.75 | +0.12 | 50% | $1.36 | — |
| 2026-10-20 | ui-ux | claude-sonnet-5-5 | claude-haiku-5-5 | 538ed41e97d9 | 1/2 | 0.68 | -0.09 | 0.36 / 0.55 | -0.18 | 0.55 | +0.00 | 0% | $1.12 | — |
| 2026-10-21 | ai-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 0/1 | 0.67 | +0.21 | 0.67 / 0.46 | +0.21 | 0.67 | +0.21 | 100% | $4.10 | — |
| 2026-10-21 | algorithms | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.96 | +0.06 | 0.92 / 0.79 | +0.12 | 0.96 | +0.17 | 50% | $1.80 | — |
| 2026-10-21 | align | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.93 | +0.05 | 0.86 / 0.77 | +0.09 | 1.00 | +0.23 | 0% | $2.10 | — |
| 2026-10-21 | backend | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.78 | -0.08 | 0.56 / 0.72 | -0.17 | 1.00 | +0.28 | 0% | $3.34 | — |
| 2026-10-21 | business | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.87 | +0.02 | 0.73 / 0.69 | +0.04 | 0.81 | +0.12 | 0% | $3.15 | — |
| 2026-10-21 | code-quality | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.87 | -0.02 | 0.73 / 0.77 | -0.03 | 0.80 | +0.03 | 0% | $2.41 | — |
| 2026-10-21 | data-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.95 | +0.09 | 0.89 / 0.71 | +0.18 | 0.89 | +0.18 | 0% | $2.59 | — |
| 2026-10-21 | database | claude-sonnet-5-5 | claude-haiku-5-5 | 7ee421c01fbf | 1/2 | 0.72 | -0.03 | 0.45 / 0.50 | -0.05 | 0.75 | +0.25 | 0% | $5.80 | — |
| 2026-10-21 | delivery | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.93 | +0.07 | 0.86 / 0.71 | +0.14 | 0.86 | +0.14 | 0% | $0.93 | — |
| 2026-10-21 | devops | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.92 | -0.04 | 0.85 / 0.92 | -0.08 | 0.92 | +0.00 | 0% | $2.60 | — |
| 2026-10-21 | distributed-systems | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.93 | +0.00 | 0.85 / 0.85 | +0.00 | 1.00 | +0.15 | 0% | $2.71 | — |
| 2026-10-21 | documentation | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.96 | +0.00 | 0.92 / 0.92 | +0.00 | 1.00 | +0.08 | 0% | $1.71 | — |
| 2026-10-21 | finops | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 0/1 | 0.77 | +0.14 | 0.77 / 0.64 | +0.14 | 0.77 | +0.14 | 100% | $4.16 | — |
| 2026-10-21 | frontend | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.75 | +0.00 | 0.50 / 0.50 | +0.00 | 0.62 | +0.12 | 0% | $2.65 | — |
| 2026-10-21 | infrastructure | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.92 | +0.02 | 0.83 / 0.79 | +0.04 | 0.96 | +0.17 | 0% | $2.21 | — |
| 2026-10-21 | learning | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.94 | -0.03 | 0.89 / 0.94 | -0.06 | 0.94 | +0.00 | 0% | $1.82 | — |
| 2026-10-21 | migration | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.72 | -0.07 | 0.45 / 0.60 | -0.15 | 0.85 | +0.25 | 0% | $2.56 | — |
| 2026-10-21 | mobile | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 0/1 | 0.85 | +0.08 | 0.85 / 0.77 | +0.08 | 0.88 | +0.12 | 0% | $3.53 | — |
| 2026-10-21 | observability | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.97 | +0.03 | 0.94 / 0.89 | +0.06 | 0.89 | +0.00 | 0% | $1.92 | — |
| 2026-10-21 | performance | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.90 | -0.07 | 0.80 / 0.95 | -0.15 | 0.85 | -0.10 | 0% | $3.04 | — |
| 2026-10-21 | performance | claude-sonnet-5-5 | claude-haiku-5-5 | 7ee421c01fbf | 1/2 | 0.90 | -0.03 | 0.80 / 0.85 | -0.05 | 1.00 | +0.15 | 0% | $2.33 | — |
| 2026-10-21 | product | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.93 | +0.02 | 0.86 / 0.82 | +0.05 | 1.00 | +0.18 | 0% | $1.16 | — |
| 2026-10-21 | security | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 0/1 | 0.72 | +0.11 | 0.72 / 0.61 | +0.11 | 0.89 | +0.28 | 0% | $3.98 | — |
| 2026-10-21 | testing | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.81 | -0.06 | 0.62 / 0.75 | -0.12 | 0.88 | +0.12 | 0% | $2.41 | — |
| 2026-10-21 | ui-ux | claude-sonnet-5-5 | claude-haiku-5-5 | 181884964817 | 1/2 | 0.93 | -0.02 | 0.86 / 0.91 | -0.05 | 0.73 | -0.18 | 0% | $1.38 | — |
| 2026-10-21 | ui-ux | claude-sonnet-5-5 | claude-haiku-5-5 | 7ee421c01fbf | 1/2 | 0.86 | -0.05 | 0.73 / 0.82 | -0.09 | 0.95 | +0.14 | 0% | $1.42 | — |
<!-- history:eval:end -->

### With Bash granted (`run-pack-evals.sh --bash`)

The same three lanes with Bash granted to **both** arms (`allowed_tools` + `--allow-tools Bash` on the staged
copy only), so a pack's runnable detectors — the skills' pre-flight `rg` and the stdlib scripts under
`skills/<x>/scripts/` — can run under the run's OS sandbox. Rows carry `variant: "bash"` and never mix with the
table above. **no-Bash cmd Δ** is the latest row above for the same pack and model. **pack scripts ran** —
pack-loaded runs (ask with + cmd) in which a bundled `skills/<x>/scripts/<file>` executed, over all of them;
**pre-flight rg** — of the same runs, those that loaded the pack's skill or command and ran `rg` through Bash;
**Bash used** — runs that executed any Bash command, with the pack / without it (read from each run's trace).

<!-- history:eval-bash:begin -->
| date | pack | model | judge | sha | ask with / without | ask Δ | cmd score | cmd Δ | no-Bash cmd Δ | skill fired | pack scripts ran | pre-flight rg | Bash used with / without | cost |
|------|------|-------|-------|-----|--------------------|-------|-----------|-------|---------------|-------------|------------------|---------------|--------------------------|------|
| 2026-10-20 | ai-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.62 / 0.54 | +0.08 | 0.67 | +0.12 | +0.12 | 50% | 2/4 | 0/4 | 4 / 2 | $2.80 |
| 2026-10-20 | algorithms | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.96 / 0.96 | +0.00 | 0.83 | -0.12 | -0.04 | 0% | 0/4 | 0/4 | 4 / 2 | $1.24 |
| 2026-10-20 | align | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.82 / 0.82 | +0.00 | 0.77 | -0.05 | +0.05 | 0% | 0/4 | 1/4 | 4 / 2 | $1.37 |
| 2026-10-20 | backend | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.89 / 0.72 | +0.17 | 0.72 | +0.00 | +0.11 | 0% | 0/4 | 0/4 | 4 / 2 | $2.31 |
| 2026-10-20 | business | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.62 / 0.50 | +0.12 | 0.81 | +0.31 | +0.12 | 0% | 0/4 | 1/4 | 3 / 2 | $1.93 |
| 2026-10-20 | code-quality | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.67 / 0.60 | +0.07 | 0.63 | +0.03 | +0.03 | 0% | 0/4 | 0/4 | 4 / 2 | $1.38 |
| 2026-10-20 | data-engineering | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.75 / 0.79 | -0.04 | 0.79 | +0.00 | +0.11 | 0% | 0/4 | 0/4 | 4 / 2 | $2.17 |
| 2026-10-20 | delivery | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.79 / 0.79 | +0.00 | 0.93 | +0.14 | +0.07 | 0% | 0/4 | 0/4 | 4 / 2 | $1.10 |
| 2026-10-20 | devops | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.88 / 0.92 | -0.04 | 0.88 | -0.04 | +0.00 | 0% | 0/4 | 0/4 | 4 / 2 | $1.86 |
| 2026-10-20 | distributed-systems | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.80 / 0.85 | -0.05 | 0.65 | -0.20 | -0.10 | 0% | 0/4 | 0/4 | 4 / 2 | $1.78 |
| 2026-10-20 | documentation | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 1.00 / 0.96 | +0.04 | 0.79 | -0.17 | -0.04 | 0% | 1/4 | 0/4 | 4 / 2 | $1.40 |
| 2026-10-20 | finops | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.64 / 0.55 | +0.09 | 0.55 | +0.00 | +0.00 | 100% | 0/4 | 0/4 | 4 / 2 | $1.04 |
| 2026-10-20 | frontend | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.44 / 0.44 | +0.00 | 0.50 | +0.06 | +0.00 | 0% | 0/4 | 0/4 | 4 / 2 | $1.38 |
| 2026-10-20 | infrastructure | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.88 / 0.96 | -0.08 | 0.83 | -0.12 | -0.08 | 0% | 0/4 | 0/4 | 4 / 2 | $1.41 |
| 2026-10-20 | learning | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.89 / 0.67 | +0.22 | 0.72 | +0.06 | +0.06 | 0% | 0/4 | 0/4 | 4 / 2 | $1.35 |
| 2026-10-20 | migration | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.90 / 0.85 | +0.05 | 0.80 | -0.05 | +0.15 | 0% | 0/4 | 0/4 | 4 / 2 | $1.85 |
| 2026-10-20 | mobile | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.88 / 0.88 | +0.00 | 0.96 | +0.08 | +0.15 | 0% | 0/4 | 0/4 | 4 / 2 | $1.77 |
| 2026-10-20 | observability | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.67 / 0.44 | +0.22 | 0.72 | +0.28 | -0.17 | 0% | 0/4 | 0/4 | 4 / 2 | $1.33 |
| 2026-10-20 | performance | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.85 / 0.85 | +0.00 | 0.75 | -0.10 | -0.05 | 50% | 0/4 | 0/4 | 4 / 2 | $2.08 |
| 2026-10-20 | product | claude-sonnet-5-5 | claude-haiku-5-5 | 58bbb8437cdd | 0.67 / 0.62 | +0.04 | 0.67 | +0.04 | -0.04 | 50% | 1/4 | 0/4 | 4 / 2 | $1.43 |
<!-- history:eval-bash:end -->

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
