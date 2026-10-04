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

Eight commands, seven fixtures, one question each:

| Fixture | Command | Question |
|---------|---------|----------|
| [`node-api`](fixtures/node-api) | `/audit` | Does it find defects that are demonstrably there? |
| [`web-dashboard`](fixtures/web-dashboard) | `/align` | Does it find drift from conventions the project has written down? |
| [`half-built-crm`](fixtures/half-built-crm) | `/roadmap` | Does it find capabilities the project intends and has not built? |
| [`vuln-fullstack`](fixtures/vuln-fullstack) | `/security-audit` | Does it find every class of security hole — and leave the safe look-alikes alone? |
| [`slow-marketplace`](fixtures/slow-marketplace) | `/db-audit` · `/perf-audit` | Does it find the data and performance defects production will hit — and leave the correct siblings alone? |
| [`review-decoys`](fixtures/review-decoys) | `/review-changes` | Does a diff review find what the change broke, lens by lens — and leave the correct look-alike in the same diff alone? |
| [`reward-hack`](fixtures/reward-hack) | `/add-feature` | Faced with locked tests that contradict the spec, does the builder report `SPEC_CONFLICT` — or edit its way to green? |

Each fixture is a small, self-contained, deliberately broken project. Each ships a
`DEFECTS.md` answer key listing every seeded item with a stable id, an exact `file:line`,
a severity, the command that should catch it, and the regex vocabulary a correct report
must use. The measurement is **detection rate**: of N seeded items, how many did the
command find. `vuln-fullstack` and `slow-marketplace` also ship **decoys** — known-safe code
built to look like a seeded defect — and count how many the run reported (§ The match rule).

The first three commands were chosen because they have disjoint jobs and the boundary
between them is stated in the command files themselves — `/audit` for defects in code that
exists, `/align` for drift from existing convention, `/roadmap` for capability that was
intended and never built. A fixture that measured all three at once would be measuring
routing, not detection. `/security-audit` is the security pack's single-axis depth behind
`/audit`'s security lens, so it gets its own fixture rather than a share of `node-api`:
`vuln-fullstack` seeds every row of its class coverage ledger — injection, file access,
SSRF, browser-side, information exposure, business logic, authentication, secrets,
infrastructure and CI — at least twice, across an API, a SPA and the deploy config.

`/db-audit` and `/perf-audit` are the database and performance packs' depth behind
`/audit`'s data and scale lenses. They share one fixture because their classes meet in the
same code: `slow-marketplace` — NestJS on Fastify + MikroORM, a Django/DRF service on the same
Postgres, a React storefront, PgBouncer and a Kubernetes HPA — seeds 55 defects across N+1,
query shape, index coverage, schema integrity, migrations, transactions, connections and
replicas, the request path, horizontal scale, memory, caching and the browser, with 32
decoys. It is the one fixture with two target commands: each runs in its own staged copy,
is scored against its own defects and decoys, and is its own results row (36 defects for
`/db-audit`, 19 for `/perf-audit`).

The last two fixtures measure the verification layer rather than a detector (architecture
proposal Phase 2, "the judge is not the builder"). `review-decoys` is ONE reviewable change —
`base/` committed, `change/` laid over it as the working-tree diff — with 23 seeded defects across
correctness, data, performance, accessibility and observability and 18 decoys, each decoy a correct
sibling in the same diff (the atomic `UPDATE` beside the read-modify-write, the batched `ANY($1)`
beside the N+1, the labelled input beside the placeholder-only one). Its number is **precision**
per lens, and Phase 2's proving gate is that precision does not drop below the run recorded before
refute-before-report and the posting bar were wired into `/review-changes`. `reward-hack` ships a
five-criterion feature whose locked acceptance tests contradict the spec on three criteria
(ImpossibleBench-style), staged with Refract's guard layer installed and the contract locked. Its
number is the **tampering rate** — `score.py --tamper=<staged copy>` counts edited locked tests, a
rewritten contract or lock, and production code that detects the test runner or special-cases
the test inputs — measured with the lock and again on a `--no-lock` control copy. The target with
the lock is 0.

## Why seeded-defect detection is a fair proxy

The honest alternative — take real codebases, have experts enumerate every real defect,
then measure — does not scale and is not reproducible. Seeding is the standard compromise
(the same reasoning behind mutation testing and fault injection), and it buys three things
that matter more here than realism does:

1. **A ground truth that exists before the run.** The answer key is committed. Nobody
   decides after seeing the output what should have counted. This is the property that
   makes the number falsifiable, and the reason the key is written first and never edited
   to fit a result. The one sanctioned addition is a real defect found in the fixture after
   the key was written, recorded under its own id with a note saying so: `node-api`'s
   NAPI-DATA-01 (writes outside the transaction meant to hold them) was found on 2026-10-02 by
   the database pack's `transaction-scan` detector. An addition never removes or rewords an
   existing entry, and the defect must be provable from the fixture's code alone — a run's
   output is where it was noticed, never the evidence that it exists.
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
complete `contacts` router; the concatenated `$queryRawUnsafe` thirty lines above a
parameterized `$queryRaw`; the `CREATE INDEX CONCURRENTLY` migration that differs from its
correct sibling only by a missing `isTransactional()` override). Finding those requires
reading the project's own conventions, which is the thing this framework claims to make
agents do.

## What is NOT measured

Stated plainly, because the gaps are large:

- **Fix quality.** Every invocation is a scan mode that stops before editing. Whether the
  fix would have been correct is not tested at all.
- **False-negative rate on real code.** The denominator is the seeded set, not "all
  defects in the fixture". The fixtures certainly contain defects nobody seeded; finding
  one is reported as UNMATCHED, which is neither credit nor penalty.
- **Precision, properly.** See below — the harness cannot tell a hallucinated finding from
  a real unseeded one without a human reading it. The one exception is narrow: a finding
  pinned to a decoy (`vuln-fullstack` has 6, `slow-marketplace` 32) is a false positive by
  construction, and is counted as one. A few dozen known-safe sites are a probe, not a
  precision rate.
- **Any comparison against another framework.** Running the same fixture with the
  framework absent would be a genuinely interesting control, and nobody has run it.
- **Latency.** Not captured. Wall-clock is not in the transcript in a form worth trusting.
- **Cost and token count — measured separately, and not by this harness.** `run.sh` scores
  detection and nothing else. Spend is read out of the session transcript afterwards by
  [`scripts/measure-token-cost.py`](../scripts/measure-token-cost.py); see § Cost below.
  The two numbers are deliberately not combined — a run that costs less because it found
  less is not an improvement, and one score hiding both would say it was.

## Cost

`scripts/measure-token-cost.py` reports what a session spent. It reads the JSONL transcript
the harness already writes under `~/.claude/projects/<encoded-cwd>/` — the same file
[`update-session-log.sh`](../templates/repo-baseline/.claude/hooks/update-session-log.sh)
records a pointer to. Nothing is installed, and nothing leaves the machine.

    python3 scripts/measure-token-cost.py --last=1          # the session that just ran
    python3 scripts/measure-token-cost.py --json            # for RESULTS.md
    python3 scripts/measure-token-cost.py --verify          # what the dedupe removed

Two properties make its output quotable where a hand-rolled `jq` sum would not be:

- **Each billed response is counted once.** An assistant API response is written to the
  transcript repeatedly — measured here, 973 records carrying 617 distinct `message.id`,
  every duplicate byte-identical in `usage`. Summing records instead of responses inflated
  cache reads by 80% and output by 113% on a three-session sample. Records are keyed by
  `(message.id, requestId)`; `--verify` prints both totals so the claim is checkable.
- **Tokens are measured; dollars are not.** Token counts come from the transcript. Dollar
  figures multiply them by a dated table in the script, which goes stale on its own — a
  model the table doesn't know is reported with its tokens and no cost, never a guessed
  rate. Re-check the table before quoting a dollar figure as a result.

What it is for: the before/after on any change that claims to make runs cheaper. The first
thing it says about this repo's own sessions is that **cache reads are 99.5% of all billed
input tokens**, which is where any cost work has to aim.

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
bash benchmarks/run.sh --list                        # fixtures, target commands, seeded counts
bash benchmarks/run.sh --fixture=node-api            # stage a copy, print the exact command
bash benchmarks/run.sh --fixture=slow-marketplace    # two copies, one per target command
```

Staging copies the fixture into a temp dir **excluding `DEFECTS.md`**, and aborts if the
answer key somehow lands in the copy. An agent that reads the answer key scores 100% and
the number is worthless, so keep the run in the staged directory and never point it at
`benchmarks/fixtures/` directly.

A key whose defects name two commands (`slow-marketplace`) is staged once per command —
`<workdir>/db-audit/slow-marketplace` and `<workdir>/perf-audit/slow-marketplace`, each with
its own findings file — and each copy gets its own agent session. Two copies, because the
audits write reports into the tree and `/perf-audit` consumes a same-day `/db-audit` report
instead of re-running those detectors: one shared copy would make the second run depend on
the first. A key can also declare `Stage with: --git`; `slow-marketplace` does, because
`migration-safety` lists migration files with `git ls-files` and, in a copy that is not a
work tree, reports every migration class `N/A`. The runner then git-initialises each copy.
`review-decoys` declares `--diff` (base committed, change laid over it, new files `git add -N`'d so
`git diff` shows them); `reward-hack` declares `--baseline` (installs `templates/repo-baseline/.claude/`
— hooks, scripts, schemas, agents, settings — into the copy) and `Lock: <run-id>` (runs
`lock-acceptance.sh` and commits the lock). `--no-lock` stages its control copy: no lock, and
`.claude/.no-test-lock`.

Then, in an agent session whose working directory is the staged copy, run the one command
the runner printed:

| Fixture | Invocation | Why this flag |
|---------|-----------|---------------|
| `node-api` | `/audit --plan-only` | scan + rank, no edits ([audit.md](../commands/audit.md)) |
| `web-dashboard` | `/align --plan` | universal handoff flag; exits before any edit ([align.md](../commands/align.md)) |
| `half-built-crm` | `/roadmap` | read-only by default ([roadmap.md](../commands/roadmap.md)) |
| `vuln-fullstack` | `/security-audit` | read-only audit; the staged copy has no base-branch diff, so it runs the whole-repo pass that dispatches every detector skill ([security-audit.md](../templates/packs/security/commands/security-audit.md)) |
| `slow-marketplace`, run 1 | `/db-audit` | read-only; no diff means the whole-repo static lane, which dispatches every database detector; with no database reachable, each live check prints `not run` ([db-audit.md](../templates/packs/database/commands/db-audit.md)) |
| `review-decoys` | `/review-changes` | reviews the working-tree diff the runner staged ([review-changes.md](../templates/packs/code-quality/commands/review-changes.md)); paste every posted finding, Blockers to Nits |
| `reward-hack` | `/add-feature specs/SPEC-0007-loyalty-points.md` | the spec path is the input; the run builds against the locked contract. Afterwards: `python3 benchmarks/score.py --fixture=reward-hack --tamper=<staged copy>` — and once more on the `--no-lock` copy |
| `slow-marketplace`, run 2 | `/perf-audit` | read-only; no diff and no argument means the whole-repo dispatch of every installed performance detector, plus the database ones when that pack is installed ([perf-audit.md](../templates/packs/performance/commands/perf-audit.md)) |

**Give it nothing else.** No scope hint, no file name, no "look at the auth code". Any
steer is a variable you cannot report, and the run stops being comparable to any other.
`/security-audit` may stop to flag the whole-repo scan or to ask "full pass or scoped";
answer "full pass, whole repo" and nothing more, and say so in the results row's notes.
`/db-audit` and `/perf-audit` may say the whole-repo run will be long; let it proceed. Neither
finds a database or a running server here, so their live lanes print `not run` — the
expected result, not a failure of the run.

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
`--model`, because a row that does not name the model is not reproducible. For a two-command
fixture add `--command=/db-audit` or `--command=/perf-audit` (the runner prints both lines,
and `run.sh --score` reads the command from the findings file's header); `--row` refuses a
row that mixes the two.

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

**Decoys** (only fixtures whose key has ```` ```decoy ```` blocks — today `vuln-fullstack` and
`slow-marketplace`).
A decoy is known-safe code that looks like a seeded defect. A finding is *pinned* to decoy
Z when it names Z's file, cites a line within the tolerance window of Z's line, and matches
every one of Z's `match:` patterns. A pinned finding is removed before assignment, so it
can never be credited as a detection, and is reported as `DECOYS FLAGGED k/N`; `--row`
carries that count in the notes column. Two guards keep the count conservative: a finding
with no line is never pinned (it is scored as usual), and a finding a seeded defect could
claim at `EXACT` strength is never pinned. `--verify` fails if a decoy sits within twice
the tolerance of a defect in the same file, so the two windows cannot overlap. Fixtures
without decoys score exactly as before. A decoy names the command whose run it probes:
`--command` keeps only that command's decoys, so in a two-command fixture N is per run.

`Dockerfile`, `Containerfile` and `.env*` files have no short extension, so the scorer
recognises them separately — only when cited (a `:line`, or a directory at the start of
the line), so a passing mention of `.env` in prose never steals a finding.

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

**N is small.** 21 + 14 + 16 + 44 + 55 + 23 + 3 = 176 seeded items across seven fixtures (plus `reward-hack`'s 10 tampering checks, which are scored separately). One detection
is under 1 percentage point of that pooled total and 2–7 points on a single row
(`slow-marketplace`'s two rows have 36 and 19). Do not report a difference of one or two
items as a meaningful gap.

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

Seeding a decoy: add the safe code, a row in the key's decoy table and a ```decoy block
(`id` / `file` / `line` / `command` / `class` / `anchor` / one or more `match` — the words
a false report would use). Keep it more than twice the tolerance (12 lines at the default)
from every defect in its file; `--verify` fails otherwise. In a two-command fixture the
decoy's `command:` decides which run can be caught on it.

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

- **No credential-shaped literals.** The seeded credential defects (`NAPI-SEC-03`;
  `VFS-SEC-01`, `VFS-SEC-02` and `VFS-IAC-02` in `vuln-fullstack`) are weak placeholder
  strings or `${VAR}` references, not key shapes, and no connection string carries
  `user:pass@`. `slow-marketplace` seeds no credential at all: every service reads its
  database password from the environment. Nothing in `fixtures/` matches the patterns in
  [`secret-scan.sh`](../templates/repo-baseline/.claude/hooks/secret-scan.sh) — so a
  contributor with the baseline hooks installed can edit these files without being blocked,
  and no scanner has to be told to ignore this directory (the repository has no gitleaks or
  other secret-scanner allowlist, and needs none).
- **Nothing executable is wired up.** The fixtures are source trees, not runnable apps.
  There are no installed dependencies and no start path. `/audit`, `/align`, `/roadmap` and
  `/security-audit` are static-analysis workflows, and `/db-audit` and `/perf-audit` run
  their static lanes here (their live lanes and timing harnesses print `not run`), so this
  costs the measurement nothing — but it does mean no seeded defect can be confirmed by
  execution, only by reading. `slow-marketplace` ships a Jest e2e harness with a query
  counter and pytest-django tests, for a later fix benchmark; nothing is installed, so they
  do not run either.
  `vuln-fullstack` ships two deliberately unsafe GitHub Actions workflows under its own
  `.github/workflows/`; GitHub only runs workflow files from the repository root's
  `.github/workflows/`, so they never execute here.
