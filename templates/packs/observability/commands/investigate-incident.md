---
description: "Read-only incident RCA: three or more competing hypotheses, evidence for and against each, reviews/hypotheses.json."
kind: command
pack: observability
allowed-tools: [Read, Grep, Glob, Bash, Task, Write]
---

# /investigate-incident

## The Premise (read this first, do not deviate)

**The first plausible story is the most expensive one.** Under pressure a responder sees the newest
deploy, or the loudest error, and stops looking. The loudest error is usually a symptom (the pool is
exhausted *because* something else holds connections), and the newest deploy is often innocent.
This command makes the alternative explicit: at least **three competing hypotheses**, each tested
against the evidence by an investigator that is trying to *refute* it, and a root cause is named only
when one hypothesis survives with evidence for it and the others fall with evidence against them.

It is **read-only, and it never touches production.** It reads the repository, git history, the
deploy ledger, an exported incident bundle, and — only when the user names the endpoint — read-only
queries to the telemetry backend (PromQL / LogQL / a trace search over HTTP GET). It runs no
`kubectl`, `helm`, cloud CLI or database client, read-only or not: the first line of every Bash call
that could reach a cluster is the empty-KUBECONFIG line, and `guard-irreversible.sh` denies any
irreversible command from a subagent outright. Mitigation is out of scope here; it is printed as a
plan for the human (H3) and done through `/rollback-deploy`, a flag, or the runbook.

This is the bug track's diagnosis step for production (architecture proposal §4.5, "Incident"):
investigator hypotheses → a red regression test (`/fix-bug`; `@test-engineer` writes it when the delivery pack is installed) → the fix → the verifier.

## When to use

- After the page is mitigated, or in parallel with mitigation when the mitigation is already known.
- A `/release` that `ABORTED`, a `monitor-deploy` breach, an SLO burn alert with no obvious cause.
- Replaying a recorded incident (`--bundle=`), including the `incident-replay` benchmark fixture.

## When NOT to use

- The service is down right now and nobody has mitigated: run the runbook's mitigation ladder first
  (`@incident-responder` § The loop). Diagnosis waits for the bleeding to stop.
- A reproducible local bug with a stack trace → `/fix-bug`.
- Writing the review afterwards → `/postmortem` (it reads this command's output).

## Inputs

```
/investigate-incident "<alert or symptom>" [--since=<ISO> --until=<ISO>]
/investigate-incident --bundle=<dir>        # an exported incident: alert.md, logs/, metrics/, deploy/, code
/investigate-incident --run=<run-id>        # attach to an existing run (e.g. the release that aborted)
/investigate-incident --telemetry=<url>     # a read-only query endpoint the user names; never discovered
/investigate-incident --hypotheses=N        # fan-out width, default 3, at most 5
```

## Phase 1 — Understand: fix the window and the symptom

1. **The symptom, in the alert's own terms** — which SLI moved, from what to what, from when to
   when, for whom (all tenants, one region, one plan). Cite the alert line or the bundle's
   `alert.md`. "Errors are high" is not a symptom.
2. **The change log for the window** — `ai/runtime/deploys.md` rows, `git log --since --until` on the
   deploy branch, flag changes the repo records, config and migration files touched, the bundle's
   `deploy/`. A change that landed *after* the symptom started is evidence against it, not for it.
3. **The run** — `--run=<id>`, else open `ai/runs/<YYYYMMDD>-incident-<slug>-<4hex>/` with a `run.json`
   shaped by `.claude/templates/snippets/run-ledger.md § 3` (request = the alert text, phase `P14`),
   tiered and validated by `python3 .claude/scripts/risk-tier.py --run=<id> --request="<alert text>" --write`.

## Phase 2 — Organize: generate competing hypotheses

Write at least three hypotheses (`--hypotheses=N`) **from different categories** before reading
deeply: one per plausible mechanism, never three wordings of one. Categories: `deploy` (the change
in the window), `config`, `dependency` (a downstream or third party), `capacity` (load, saturation,
a limit), `data` (a migration, a poison record, a backfill), `code` (a latent bug the window
triggered), `infrastructure` (node, network, DNS, certificate), `external` (traffic shape, abuse).

Each hypothesis is a **mechanism**, stated so it predicts something checkable:
`H-1 (config): the 1.4.0 deploy cut the DB pool from 20 to 5 → requests queue on acquire →
predicts acquire-timeout errors starting with the rollout, DB CPU flat, and recovery on rollback.`
The prediction is what makes it falsifiable: write down what you would see if it were false.

The symptom everyone saw first is a hypothesis too, so it gets tested rather than assumed — and the
loudest log line is checked for being a *consequence* of another hypothesis.

## Phase 3 — Retrieve: the investigator fan-out (one hypothesis per instance)

Dispatch one read-only instance per hypothesis **in a single message** (they parallelize safely):
`@incident-responder` in hypothesis mode when it is installed, else a `Task` instance. The brief is
paths and one hypothesis, never the other hypotheses' conclusions (`delegation-brief.md`):

```
run_id: <run-id> · incident: <id or alert + start> · hypothesis: H-2 (<category>) <the mechanism + its prediction>
read: <bundle dir or the repo paths> · ai/runtime/deploys.md · <the window>
mode: refute — look first for evidence that this hypothesis is FALSE; read-only; no cluster, cloud or DB client;
end with one refract/hypotheses/v1 JSON object carrying exactly this hypothesis.
```

Each instance returns `{id, hypothesis, category, root_cause?, supporting[], contradicting[], verdict, next_probe?}`:
- `supporting[]` / `contradicting[]` — each item a **source** (`<file>:<line>`, a bundle log line, a
  query with its time range, a ledger row, a commit) and the **observation** there, checkable by a reader.
- `verdict` — `supported` (evidence for, none decisive against, **and** `root_cause {file, line, claim}`:
  the line where the cause lives — code, config, migration, manifest), `refuted` (at least one
  contradicting item), `inconclusive` (with the read-only `next_probe` that would decide it).

`persist-review.sh` (SubagentStop) validates each record — a `supported` with no evidence or no
root-cause line, or a `refuted` with no contradicting evidence, is sent back — and merges it by id into
**`ai/runs/<run-id>/reviews/hypotheses.json`** (schema `.claude/schemas/hypotheses.schema.json`).
Nothing else writes that file: `test-lock.sh` denies a tool write to `ai/runs/*/reviews/`. Without
the repo-baseline hook installed the file cannot be written; say so and print the records instead.

After the fan-out, `git status --porcelain` must be unchanged: an instance that edited a file broke
read-only, and its record is discarded.

## Phase 4 — Generate: adjudicate

Read `hypotheses.json` and decide, in this order:

1. **Exactly one `supported`, the others `refuted`** → that is the root cause. Check it explains
   *every* symptom in Phase 1 (onset time, scope, recovery). A cause that explains the errors but not
   the onset time is a contributing factor, not the root.
2. **Two or more `supported`** → they are either one causal chain (A causes B: the root is A — name
   B a symptom) or genuinely independent; run each one's `next_probe` that separates them.
3. **None `supported`** → widen: one more round of hypotheses (round 2, at most), each from a
   category not yet tried. Still none → `INCONCLUSIVE` with the probes that would settle it. A guess
   is never promoted to a root cause to close the run.

Decoy symptoms are named as such in the output — the loudest log line that turned out to be a
consequence is exactly what the next responder will chase.

## Phase 5 — Update

- `ai/runs/<run-id>/reviews/hypotheses.json` — written by the hook only (Phase 3).
- `ai/runs/<run-id>/incident.md` — the timeline (UTC, source per line), the adjudication, the
  mitigation plan for the human, and the hand-offs below. ≤ 120 lines.
- `ai/_history.md` — `<iso> investigate-incident <run-id> → <ROOT CAUSE | INCONCLUSIVE>`.

## Phase 6 — Validate: the closure gate

`COMPLETE` only when all of these hold, each checked, not asserted:
- `hypotheses.json` exists and holds ≥ 3 hypotheses from ≥ 2 categories:
  `python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); h=d["hypotheses"]; print(len(h), len({x.get("category") for x in h}))' ai/runs/<run-id>/reviews/hypotheses.json`.
- Every hypothesis carries evidence on the side its verdict claims (the hook enforced it; re-read).
- Exactly one root cause, with a `root_cause` line that `sed -n '<line>p' <file>` shows saying what
  the claim says, **and** it explains onset, scope and recovery.
- `git status --porcelain` unchanged from before the fan-out.

Otherwise `INCONCLUSIVE — <what is missing>`. A root cause from one hypothesis with no competitors
is not this command's output; it is the first plausible story this command exists to prevent.

## Output

```
## Incident <id> — checkout 5xx, 2026-10-19 09:12–09:41 UTC — run 20261019-incident-checkout-5xx-9a1c

Symptom: checkout.success fell 99.95 % → 91.2 % at 09:12 (alert CheckoutFastBurn, bundle alert.md:3); all tenants

Hypotheses (reviews/hypotheses.json, 3 instances, refute mode):
  H-1 config      SUPPORTED  pool cut 20 → 5 in the 1.4.0 deploy (config/db.yml:8)
                  + logs/app.log:41 acquire timeout 2000 ms first at 09:12:04, 70 s after rollout end (deploy/diff.patch:9)
                  + metrics/snapshot.txt:22 db_cpu 18 % flat through the window
  H-2 dependency  REFUTED    payment provider degraded
                  − metrics/snapshot.txt:31 provider p99 180 ms flat; errors are pool acquires, not provider calls
  H-3 data        REFUTED    slow orders query after the index migration
                  − logs/app.log:17 the "slow query" lines predate the incident by 3 h at the same rate  ← decoy symptom

ROOT CAUSE: config/db.yml:8 — when concurrent checkouts exceed 5, `pool: 5` queues requests past the 2 s
            acquire timeout instead of serving them (onset = rollout end, scope = every pod, recovery = rollback)
Decoy symptoms: the "slow query" warnings (pre-existing, unchanged rate)
Mitigation (human, H3): /rollback-deploy --env=production --to=rev 57 — or set DB_POOL_SIZE=20 through the pipeline
Hand-offs: /fix-bug "pool size regression" (red test first) · /postmortem --run=20261019-incident-checkout-5xx-9a1c
Status: COMPLETE (3 hypotheses, 3 categories, 1 root cause, tree unchanged)
```

## Halt conditions

- No symptom with a time window → ask for the alert and its start time; do not investigate "slowness".
- An instance returns prose instead of the JSON record → re-dispatch once; then `INCONCLUSIVE`.
- Any step would need a cluster, cloud or database client → stop; write the read-only probe into
  `next_probe` for a human to run, and say so.

## Hard rules

- **≥ 3 competing hypotheses, ≥ 2 categories.** Never one.
- **Refute first.** Each instance looks for evidence against its own hypothesis before evidence for it.
- **Every claim has a source a reader can open.** A log line, a query with its range, a file line.
- **Read-only, never production.** No cluster, cloud or database client; mitigations are printed for the human.
- **Symptoms are not causes.** A consequence of the root cause is named a decoy symptom, not a factor.

## Related

- `@incident-responder` (this pack) — the hypothesis instances; the live mitigation loop.
- `/postmortem` (this pack) — reads `hypotheses.json` and `incident.md`.
- `/rollback-deploy`, `/release` (devops pack) — mitigation and the release that may have aborted.
- `/fix-bug` (repo baseline) — the red regression test and the fix.
- `benchmarks/fixtures/incident-replay` (Refract repo) — RCA accuracy is measured on its ten bundles.
