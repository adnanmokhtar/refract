# Benchmarks

**What the CI gates prove, and what they don't.** The nine gates in
[`quality-gates.yml`](../.github/workflows/quality-gates.yml) prove this repo is internally
consistent: every command is documented, every cited validator exists, the adapter matrix
agrees with itself, the hooks block what they claim to block. Not one of them looks at
what a command actually *produces*. A framework can be flawlessly self-consistent and
still generate mediocre output.

This directory is the apparatus for measuring the other half. It does not contain results
— see [RESULTS.md](RESULTS.md), which currently records none.

---

## What is measured

Three commands, three fixtures, one question each:

| Fixture | Command | Question |
|---------|---------|----------|
| [`node-api`](fixtures/node-api) | `/audit` | Does it find defects that are demonstrably there? |
| [`web-dashboard`](fixtures/web-dashboard) | `/align` | Does it find drift from conventions the project has written down? |
| [`half-built-crm`](fixtures/half-built-crm) | `/roadmap` | Does it find capabilities the project intends and has not built? |

Each fixture is a small, self-contained, deliberately broken project. Each ships a
`DEFECTS.md` answer key listing every seeded item with a stable id, an exact `file:line`,
a severity, the command that should catch it, and the regex vocabulary a correct report
must use. The measurement is **detection rate**: of N seeded items, how many did the
command find.

The three commands were chosen because they have disjoint jobs and the boundary between
them is stated in the command files themselves — `/audit` for defects in code that exists,
`/align` for drift from existing convention, `/roadmap` for capability that was intended
and never built. A fixture that measured all three at once would be measuring routing, not
detection.

## Why seeded-defect detection is a fair proxy

The honest alternative — take real codebases, have experts enumerate every real defect,
then measure — does not scale and is not reproducible. Seeding is the standard compromise
(the same reasoning behind mutation testing and fault injection), and it buys three things
that matter more here than realism does:

1. **A ground truth that exists before the run.** The answer key is committed. Nobody
   decides after seeing the output what should have counted. This is the property that
   makes the number falsifiable, and the reason the key is written first and never edited
   to fit a result.
2. **A denominator.** "Found 14 issues" is unfalsifiable marketing. "Found 14 of 20
   seeded, missed these 6, and reported 3 things we did not seed" is a claim someone can
   check by re-running it.
3. **Comparability across runs.** The same fixture scored the same way is the only way a
   model upgrade, a prompt change, or a pack edit can be shown to have moved anything.

The fixtures are also built to make detection *mean* something rather than be a keyword
hunt. Every seeded item sits in code long enough to have context; several are only
identifiable as defects by comparison with a correct sibling in the same repo (the
unhandled `chargeCard` next to the correctly-guarded `refundCharge`; the drifted
`useOrders` next to the reference `useCustomers`; the partial `deals` router next to the
complete `contacts` router). Finding those requires reading the project's own conventions,
which is the thing this framework claims to make agents do.

## What is NOT measured

Stated plainly, because the gaps are large:

- **Fix quality.** Every invocation is a scan mode that stops before editing. Whether the
  fix would have been correct is not tested at all.
- **False-negative rate on real code.** The denominator is the seeded set, not "all
  defects in the fixture". The fixtures certainly contain defects nobody seeded; finding
  one is reported as UNMATCHED, which is neither credit nor penalty.
- **Precision, properly.** See below — the harness cannot tell a hallucinated finding from
  a real unseeded one without a human reading it.
- **Any comparison against another framework.** Running the same fixture with the
  framework absent would be a genuinely interesting control, and nobody has run it.
- **Cost, latency, token count.** Not captured.

## Unmatched is not the same as false

The scorer reports `UNMATCHED` for every finding it could not map to a seeded id. That
number is **not** a false-positive count and must not be published as one. An unmatched
finding is one of three things, and only a human reading it can tell which:

- a real defect in the fixture that nobody seeded — the fixtures were written by hand and
  are not certified clean;
- a correct finding phrased outside the vocabulary the answer key anticipated — a scorer
  bug, and the fix is to widen that defect's `match:` line, never to hand-credit the run;
- an actual false positive.

If you publish a precision figure, publish the triage that produced it, per finding.

## Running one

```bash
bash benchmarks/run.sh --list                # fixtures, target commands, seeded counts
bash benchmarks/run.sh --fixture=node-api    # stage a copy, print the exact command
```

Staging copies the fixture into a temp dir **excluding `DEFECTS.md`**, and aborts if the
answer key somehow lands in the copy. An agent that reads the answer key scores 100% and
the number is worthless, so keep the run in the staged directory and never point it at
`benchmarks/fixtures/` directly.

Then, in an agent session whose working directory is the staged copy, run the one command
the runner printed:

| Fixture | Invocation | Why this flag |
|---------|-----------|---------------|
| `node-api` | `/audit --plan-only` | scan + rank, no edits ([audit.md](../commands/audit.md)) |
| `web-dashboard` | `/align --plan` | universal handoff flag; exits before any edit ([align.md](../commands/align.md)) |
| `half-built-crm` | `/roadmap` | read-only by default ([roadmap.md](../commands/roadmap.md)) |

**Give it nothing else.** No scope hint, no file name, no "look at the auth code". Any
steer is a variable you cannot report, and the run stops being comparable to any other.

Paste every reported finding into the findings file the runner created — including
findings you believe are wrong, and in the agent's own wording. Rewriting the agent's
words to match the answer key scores your paraphrase, not the run. (That file's own
instructions sit in an HTML comment, which the scorer strips, so the example line inside
them is never read back as a finding. Leave the comment; append below it.)

```bash
python3 benchmarks/score.py --fixture=node-api \
  --findings=<path> \
  --model="<model id>" --model-version="<build>" --date=<ISO> --row
```

`--row` prints the line for [RESULTS.md](RESULTS.md). It refuses to print without
`--model`, because a row that does not name the model is not reproducible.

## The match rule

The whole rule, so a reader can audit a score without reading the code. A reported finding
F matches seeded defect D when **both**:

1. `basename(F.file) == basename(D.file)`, and
2. every one of D's `match:` patterns hits F's text (case-insensitive regex).

Text is always required — landing on the right line while describing something else is not
detection, and the scorer rejects it. A line number is never required, because agents
legitimately cite a function head or a range.

Matches are then labelled by how close they landed: `EXACT` (within `--tolerance`, default
6 lines) or `TEXT` (no line, or outside the window). Both count; the split is reported so
you can see how many detections were line-accurate. `--strict-line` makes the window a
hard requirement — a useful sensitivity check, and the harsher number to publish if you
want the conservative reading.

Assignment is one-to-one and greedy — `EXACT` pairs first, ties broken by line distance —
so two defects a few lines apart need two findings for both to count. That is deliberate:
`node-api` seeds two defects one line apart (`NAPI-CAP-01`, `NAPI-CAP-02`) precisely so
this can be verified.

The scorer prints the finding text behind every credited detection. Read that column
before believing a score.

## Reproducibility

Record with **every** row, no exceptions:

- **model id** — the exact string, not "Claude" or "GPT"
- **model version / build** — snapshot, release date, or build id
- **date of the run**
- **fixture** and **command** as invoked
- **tolerance**, if not the default 6
- whether the framework was installed in the staged copy, and which packs

Detection rate on the same fixture will move between model versions, between temperature
settings, and between runs of the identical setup. A single run is an anecdote. If you
publish a number, publish how many runs it came from and their spread; if you ran it once,
say so in the notes column.

## Limitations

These are the reasons a number from this harness can be wrong, listed so nobody has to
discover them by being surprised.

**Seeded defects are not real-world defects.** They were written to be findable by a
careful reader. Real defects hide in code nobody wrote deliberately, in interactions
between modules, in assumptions that were true when written. A high detection rate here is
evidence about *these* defects, and it does not license a claim about a real codebase.

**A model may pattern-match the fixture rather than reason about it.** Some of these
shapes — `jwt.decode` where `verify` belongs, a query inside a loop, string-concatenated
SQL — are textbook and appear thousands of times in any training corpus. Recognising a
textbook shape is a weaker skill than the one the framework claims. The fixtures push back
where they can (defects that need a sibling comparison, an absence rather than a presence,
a promise in a README with no code to grep) but they cannot eliminate it. Treat the
textbook defects as a floor, not as the result.

**Published fixtures leak.** Anything in a public repo can end up in a future training
set. That is a one-way door: the longer these fixtures exist, the weaker their evidence
gets. Date every run, and treat a rise in the score over time as contaminated until proven
otherwise. Rotating in fresh, unpublished fixtures is the only real defence.

**The answer key encodes one reviewer's judgement.** Severities are assigned by hand.
Someone else would rank several differently, and the severity-weighted score moves with
them. The unweighted rate does not, which is why both are reported.

**The scorer is regex matching, not comprehension.** A correct finding phrased unusually
scores as a miss. Vocabulary in the `match:` lines was written to be generous, but "widen
the pattern after seeing a run miss" is a real hazard: doing it changes every past score,
so re-run every published row when you touch a pattern, or the table stops being
comparable with itself.

**N is small.** 20 + 14 + 16 = 50 seeded items across three fixtures. One detection is
2 percentage points on a single fixture. Do not report a difference of one or two items as
a meaningful gap.

**The loop has a human in it.** Someone copies findings from an agent session into a text
file. That step is not automated and is not tamper-proof. It is why the raw findings file
should be kept alongside any published row.

## Fixture maintenance

Line numbers in the answer keys are exact, and they rot the moment anyone edits fixture
source. The guard:

```bash
bash benchmarks/run.sh --verify        # every fixture
bash benchmarks/run.sh --verify --fixture=node-api
```

Each defect carries an `anchor:` — a literal substring that must appear **exactly once**
in its file, at the recorded line. `--verify` exits non-zero on any drift. Run it after
touching anything under `fixtures/`.

Seeding a new defect: add the code, add a `### <ID>` section with a ```defect block
(`id` / `file` / `line` / `severity` / `command` / `class` / `anchor` / one or more
`match`), update the summary table and the counts, then `--verify`. Adding a defect
changes the denominator, so every previously published row for that fixture is now
measuring something else — note the change in RESULTS.md rather than silently
re-baselining.

## Relationship to the CI gates

Nothing in `benchmarks/` is wired into [`quality-gates.yml`](../.github/workflows/quality-gates.yml),
and it should not be: the gates must stay deterministic, and a benchmark that needs an
interactive agent session is not. The nine gates scope themselves to `commands/`,
`templates/`, `scripts/`, `docs/`, `tests/` and the root `README.md`, so this directory is
outside all of them by construction — verified, not assumed.

`run.sh --verify` is the closest thing here to a gate and is the one thing worth running
by hand after any fixture edit.

Two deliberate constraints on fixture content, both so the fixtures stay safe to check out
anywhere:

- **No credential-shaped literals.** The seeded credential defect
  (`NAPI-SEC-03`) is a weak fallback string, not a key shape. Nothing in `fixtures/`
  matches the patterns in
  [`secret-scan.sh`](../templates/repo-baseline/.claude/hooks/secret-scan.sh) — so a
  contributor with the baseline hooks installed can edit these files without being blocked,
  and no scanner has to be told to ignore this directory.
- **Nothing executable is wired up.** The fixtures are source trees, not runnable apps.
  There are no installed dependencies and no start path. `/audit`, `/align` and `/roadmap`
  are static-analysis workflows, so this costs the measurement nothing — but it does mean
  no seeded defect can be confirmed by execution, only by reading.
