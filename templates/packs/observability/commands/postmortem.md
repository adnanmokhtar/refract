---
description: "Blameless postmortem: timeline, contributing factors, owned action items each proved by a red test or a seeded defect."
kind: command
pack: observability
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /postmortem

## The Premise (read this first, do not deviate)

**A postmortem is finished when the same failure cannot ship again unnoticed — not when the document
exists.** Most postmortems end in action items like "be more careful with migrations" and "improve
monitoring": unowned, unprovable, and closed by a quarter passing. This command refuses that shape.
Every action item has a **named owner**, a **future due date**, and a **proof that is red today**:

- a **failing-first regression test** — a unit, integration, promtool alert or policy test that
  fails on the code or config as it stood during the incident and passes after the fix; or
- a **new seeded defect** — the incident turned into an `incident-replay`-shaped bundle with an
  answer-key block, so the next model, review lens or detector is measured against it.

It is **blameless**: the system let a reasonable person do a reasonable thing that turned out
wrong. Names appear in the timeline as roles doing actions, never as causes. "Human error" is where
analysis stops too early; the question is what made the error easy and the detection late.

The postmortem *body* is `@sre-engineer`'s (it writes `ai/reliability/postmortems/`); the live
timeline is `@incident-responder`'s; the root cause comes from `/investigate-incident`. This command
assembles them, enforces the contract, and writes the seeded defect.

## When to use

- After a sev1/sev2 incident, within 48 h (`@incident-responder` § Postmortem).
- After a `/release` that `ABORTED`, or a `/rollback-deploy` in production.
- **After a revert** of a change that reached production (`--revert=<sha>`): an escaped defect is an
  incident even when no page fired; it still yields a seeded defect (architecture proposal §9, Field metrics).

## Inputs

```
/postmortem --run=<run-id>        # an incident run: incident.md + reviews/hypotheses.json (+ release.md)
/postmortem --revert=<sha>        # a revert commit: the reverted change is the root cause
/postmortem --incident=<id> --notes=<path>   # an incident with no run: notes and the timeline the user supplies
```

## Phase 1 — Understand: collect the facts, cited

Read, in this order, and cite each fact's source:
1. `ai/runs/<run-id>/incident.md` and `reviews/hypotheses.json` — the timeline, the adjudicated root
   cause, the refuted hypotheses and the decoy symptoms. A run whose investigation is `INCONCLUSIVE`
   gets a postmortem whose root cause section says so, and whose first action item is the probe.
2. `ai/runtime/deploys.md`, `ai/runbooks/<date>-*-rollback.md` (written by `/rollback-deploy` step 8),
   the run's `release.md` § Step log — what was deployed, when traffic moved, when it moved back.
3. `ai/runtime/slos.md` — the SLO the incident burned, its objective and window.
4. With `--revert=<sha>`: `git show <sha>` and the commit it reverts (`git log -1 --format=%B <sha>`
   names it; else `git show <sha> --stat` against the parent) — the reverted hunk is the root-cause
   line; the deploy ledger dates its time in production.

## Phase 2 — Organize: the document

`@sre-engineer` writes `ai/reliability/postmortems/<YYYY-MM-DD>-<slug>.md` in its own § Postmortems
shape, with these sections filled from Phase 1 — this command checks each one in Phase 6:

| Section | Must contain |
|---|---|
| **Summary** | one paragraph: what users saw, for how long, the root cause in one sentence |
| **Impact** | users or requests affected, duration, **error budget consumed** = bad events in the window ÷ the window's allowed bad events (`(1 − objective) × total events` over the SLO period), cited to the query or bundle that produced the numbers |
| **Timeline** | UTC, one line per event, each with its source; marked: first bad event, detection (alert fired), acknowledgement, mitigation, recovery. Time to detect and time to mitigate are computed from the marks |
| **Root cause** | one sentence + the `file:line` from `hypotheses.json` (or the reverted hunk) |
| **Contributing factors** | why it was not caught earlier and why mitigation took that long, each mapped to the layer that could have caught it: a gate (`G1`, `G4`, `G14` …), a detector § (`migration-safety` §4, `request-path-scan` §12 …), an alert, a review lens, a release step. "Nobody noticed" is not a factor; the missing detector is |
| **Decoy symptoms** | the signals that pointed elsewhere (from `hypotheses.json` refuted rows) — the next responder's time saver |
| **What went well / What went wrong** | system terms, no blame |
| **Action items** | the contract below |

## Phase 3 — Retrieve: what the action items prove against

For each contributing factor, decide the proof that would have turned it red **before** the
incident. That decision picks the item's proof kind:

| The factor | The proof (red today, green after the fix) |
|---|---|
| A code or config defect | a regression test that reproduces the trigger (`/fix-bug`'s red-first test; `@test-engineer` when the delivery pack is installed) |
| An alert that did not fire, or fired late | a promtool `alert_rule_test` fed the incident's series: it fails on the current rules and passes after (`/add-slo` § Phase 6, `/alert-design`) |
| A release or migration step that let it through | a policy or pipeline test (`conftest`, a `gate-check` fixture, a migration-lint case) that fails on the incident's change |
| A class that review, a detector or a model missed | a **seeded defect**: the incident as an `incident-replay` bundle (Phase 4) |

## Phase 4 — Generate: action items and the seeded defect

Each action item is one row, and every field is required:

```
| id   | action                                  | owner        | due        | kind     | proof (red today)                                                     |
| AI-1 | pool size read from env, floor 10       | Dana Reyes   | 2026-10-26 | prevent  | test: tests/config/test_pool.py::test_pool_floor — red: pytest exit 1 (5 < 10) |
| AI-2 | CheckoutPoolSaturation page             | Sam Okafor   | 2026-10-24 | detect   | promtool: tests/alerts/pool.test.yml — red: exit 1 (alert absent)       |
| AI-3 | seeded defect: pool shrink in a deploy  | Dana Reyes   | 2026-10-22 | measure  | seeded: ai/reliability/seeded-defects/2026-10-19-pool-shrink/ (anchor resolves) |
```

- **owner** is a named person, never a team, an alias or "TBD" (the same rule `readiness-score.py`
  types a `person` field with). **due** is an ISO date after today.
- **The red run is recorded, not promised**: the test is written now (or by `/fix-bug` with the
  postmortem as its input) and run against the incident's code; its non-zero exit and the command go
  in the row. A test that passes on the incident's code proves nothing — rewrite it until it fails.
- An action no test or seeded defect can prove (a rotation change, a comms template) is not an
  action item: it goes to § Notes, and does not count toward closing the postmortem.

**The seeded defect** (at least one per postmortem — the proving gate's "new seeded defect"): write
`ai/reliability/seeded-defects/<YYYY-MM-DD>-<slug>/` in the `incident-replay` bundle shape —
`alert.md` (what fired, when), `logs/` and `metrics/` excerpts (the decoy symptoms included, redacted),
`deploy/diff.patch` (the change in the window), the minimal code or config that carries the root
cause — plus a `DEFECTS.md` fragment: one ```defect block (`id`, `file`, `line`, `severity`,
`command: /investigate-incident`, `class: incident/<category>`, `anchor` — a literal that occurs once
in its file, at that line — and `match` patterns a correct root cause would use) and one ```decoy
block per decoy symptom. Redact every secret, customer identifier and internal hostname before writing.

When the learning pack is installed, hand the seeded defect and the lessons to its confirm-list (a
human confirms what becomes a rule, a sensor or a benchmark seed). Without it, the bundle stays under
`ai/reliability/seeded-defects/` and the output says how to contribute it to Refract's
`benchmarks/fixtures/incident-replay/`.

## Phase 5 — Update

- `ai/reliability/postmortems/<YYYY-MM-DD>-<slug>.md` — written by `@sre-engineer`.
- `ai/reliability/seeded-defects/<YYYY-MM-DD>-<slug>/` — the bundle and its key fragment.
- `ai/runs/<run-id>/run.json` — phase `P15` state; `outcome` when the run closes.
- `ai/_history.md` — `<iso> postmortem <slug> → <n> action items, <m> seeded defect(s)`.

## Phase 6 — Validate: the closure gate

`COMPLETE` only when every check runs and holds:
- **Blameless read**: `rg -n -i '\b(human error|should have|failed to|careless|forgot|negligen\w*|blame\w*|fault of)\b' <postmortem>`
  — every hit is rewritten in system terms or quoted from a source with that reason.
- **Owners and dates**: every action row has a named person (not `@org/team`, not a group word) and a
  due date after today.
- **Red proof per row**: a test row names a file that exists and a recorded non-zero exit on the
  incident's code; a seeded row names a bundle whose anchor resolves exactly once at its line:
  `python3 -c 'import sys; t=open(sys.argv[1]).read().splitlines(); h=[i+1 for i,l in enumerate(t) if sys.argv[2] in l]; print(h)' <file> '<anchor>'` prints `[<line>]`.
- **At least one seeded defect** exists for the incident.
- The root cause, impact and timeline each cite a source.

Otherwise `INCOMPLETE — unmet: <list>`, each named (`AI-2: owner "platform team" is a group`,
`AI-1: test passes on the incident's code — not a regression test`).

## Output

```
## /postmortem — checkout 5xx 2026-10-19 — run 20261019-incident-checkout-5xx-9a1c

Postmortem: ai/reliability/postmortems/2026-10-19-checkout-pool-shrink.md (@sre-engineer)
Impact: 4.1 % of checkouts failed for 29 min · checkout.success budget consumed 61 % of 30 d (bundle metrics/snapshot.txt:12-40)
TTD 3 min (CheckoutFastBurn) · TTM 26 min (rollback rev 57, ai/runbooks/2026-10-19-prod-rollback.md)
Root cause: config/db.yml:8 pool 20 → 5 in 1.4.0 (hypotheses.json H-1, supported; H-2, H-3 refuted)
Contributing: no pool-saturation alert (alert) · the pool change passed review as "config only" (review lens) · no load step in /release (release step)
Action items: 3 (prevent 1 · detect 1 · measure 1) — every row red-proved
Seeded defect: ai/reliability/seeded-defects/2026-10-19-pool-shrink/ (1 defect, 1 decoy; anchor resolves at config/db.yml:8)
Blameless read: 2 hits rewritten
Status: COMPLETE
```

## Hard rules

- **No action item without an owner, a future date and a red proof.**
- **At least one seeded defect per postmortem**, including a revert with no page.
- **Blameless.** People appear as roles taking actions; the causes are system properties.
- **Never invent numbers.** Impact and budget come from a cited query, ledger or bundle; missing data
  is written `NO-DATA (<what would answer it>)`.
- **Redact** secrets, customer data and internal hostnames from every artifact this command writes.

## Related

- `/investigate-incident` (this pack) — the hypotheses and the root cause this reads.
- `@sre-engineer` (writes the postmortem), `@incident-responder` (the live timeline) — this pack.
- `/fix-bug` — turns a prevent item into its red test and fix; `/add-slo`, `/alert-design` — detect items.
- `/release`, `/rollback-deploy` (devops pack) — the step log and rollback entries in the timeline.
- `benchmarks/fixtures/incident-replay` (Refract repo) — the bundle shape a seeded defect follows.
