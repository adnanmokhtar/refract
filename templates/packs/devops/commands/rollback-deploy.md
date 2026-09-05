---
description: Roll back the current environment to a previous known-good deploy. Decides rollback-vs-forward-fix, resolves the target and proves it was healthy, runs a four-question reversibility gate (migration direction, target still exists, artifact reference immutable, shared state readable by the old version) BEFORE executing, then executes the revert, monitors health until green, and writes a rollback runbook entry. The recovery pair of `/deploy-stage` — invoked when a staged/prod deploy goes red.
kind: command
pack: devops
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /rollback-deploy

## Premise

**A rollback is a forward state change that happens to move backwards.** It is not an undo. The
running code goes back; the database, the cache, the queue, the flag store and the registry do not.
Every 2am rollback that made things worse made them worse in the same way: the code was reverted to
a revision that could no longer read the state the bad deploy left behind.

So this command's job is not "run the revert command" — you already know that command. Its job is
to answer, in order: **is rolling back the right move at all**, **is there a target that was
actually healthy**, and **will the old code survive the state the new code created**. The revert
itself is the last step, not the first, and it is gated on all three.

## When to use

- `/deploy-stage` (or a CI deploy) went red — error rate / health probe / smoke failed after rollout.
- `monitor-deploy` confirmed a breach past its debounce and triggered recovery.
- A canary or post-deploy alert fired and you need the previous revision back NOW.
- NOT for code changes — this reverts a *deployment*, not a commit. (Use git for code.)
- NOT when the fault is in a dependency, a config value, or data the deploy merely exposed —
  rolling the code back will not move those, and you will burn the window discovering it.

## Args

```
/rollback-deploy                 # roll back to the immediately previous known-good revision
/rollback-deploy --to=<version>  # roll back to a specific revision/tag/deployment id
/rollback-deploy --env=staging   # target a specific env (default: the one /deploy-stage last touched)
/rollback-deploy --dry-run       # run steps 1-4 (decide + resolve + gate); execute nothing
/rollback-deploy --force         # proceed past an UNVERIFIED target or an amber gate item.
                                 # Requires naming which item you are overriding. Never skips step 4.
```

`--dry-run` is what `/deploy-stage`'s S1 calls: it must produce a resolved target id **and** a gate
result, because a target with no gate result is not evidence that rollback is available.

## What happens

### Step 1 — Detect the deploy mechanism

From project config (same detection as `/deploy-stage`): `kubectl rollout` / `helm rollback` /
`docker compose` re-pin / serverless alias flip / platform deployment-promote API / bare-metal
release symlink. If none detected → halt, ask. Record which one — steps 2 and 5 read differently
per mechanism (see § Platform mapping).

### Step 2 — Rollback or forward-fix? (the first 2am question, and the one most runs skip)

Rolling back is the default because it is bounded and rehearsed. It is the **wrong** default in
three cases, and the cost of finding out after the revert is a second outage:

| Situation | Why rollback is the wrong move | Do instead |
|---|---|---|
| The bad deploy ran an **irreversible or already-consumed** migration (dropped column, rewritten rows, backfill in flight) | The old code reads a schema that no longer exists → rollback converts a degraded service into a hard outage | Forward-fix. Roll back only the *behaviour*, via flag/config, not the artifact |
| The failure is in **config, a secret, a dependency, or upstream data** the deploy merely surfaced | The previous artifact reads the same broken input → rollback restores nothing | Fix the input. The deploy is the messenger |
| The fix is **one line and already understood**, and your pipeline's commit-to-deployed is inside the outage budget | A rollback plus a roll-forward is two state changes where one would do | Forward-fix, with the same monitoring window |

Otherwise: roll back. Record the choice and the reason in the runbook entry — this is the line the
post-incident review actually reads.

If a **kill-switch flag** covers the bad path, prefer flipping it: it is faster than any deploy and
it moves no artifact. (`progressive-delivery` audits whether that flag exists; if it does, use it.)

### Step 3 — Resolve the target, and prove it was healthy

Two separate things, and conflating them is the classic failure:

- **Resolving** a target means the platform's history lists it: `kubectl rollout history`,
  `helm history`, the platform's deployments list, the previous immutable tag in the registry.
- **Proving it was healthy** is a different question, and *revision history does not answer it*.
  `kubectl rollout history` returns revision numbers plus whatever `kubernetes.io/change-cause`
  was recorded. It carries no health state. A revision listed there may be the one that broke prod
  last Tuesday.

Health must come from a source that observed the revision **running**. Take the first that resolves:

1. **The deploy ledger** — `ai/runtime/deploys.md` / `ai/_history.md`, which `/deploy-stage` Phase 5
   appends to with the run's verdict. A revision recorded there as `GREEN` is known-good.
2. **A `monitor-deploy` GREEN record keyed to that revision** — the skill refuses GREEN without a
   live poll, so its record is evidence rather than assertion.
3. **The platform's own deployment status** for that revision (release status, deployment state,
   task-set stability) — weaker than 1 or 2, because "the platform finished rolling it out"
   is not "the app served traffic correctly", but it does eliminate revisions that never converged.

If none resolves, the target is **UNVERIFIED**. Say so in those words; do not silently promote
"it is the previous revision" to "it is known-good". An UNVERIFIED target may still be the right
choice at 2am — an unknown revision beats a known-bad one — but the operator makes that call, with
`--force` and the reason named, not the command by omission.

### Step 4 — Reversibility gate (four questions, BEFORE anything is executed)

Each has a halt. This is the step that separates this command from typing the revert by hand.

| # | Question | How to answer | If the answer is bad |
|---|---|---|---|
| **R1 — migration direction** | Did the bad deploy run a schema/format migration, and is it backward-compatible? | Diff the migration directory between the two revisions. An **expand** step (add nullable column, add index, add table) is safe to leave in place — old code ignores it. A **contract** step (drop column, drop table, rename, NOT NULL on a column old code omits, enum narrowing) is **not**: the old code's queries reference what is gone | **HALT.** A contract step already applied means rollback is not available as a code-only operation. Surface the manual reconciliation (re-add the column as nullable, then roll back) or route to forward-fix. Never auto-run a destructive down-migration |
| **R2 — does the target still exist?** | Is the prior revision's artifact still retained? | K8s: `.spec.revisionHistoryLimit` caps retained old ReplicaSets (**defaults to 10**, and teams commonly set it to 0-2 to reduce clutter — at 0 there is nothing to roll back to). Helm: is the revision still in `helm history`? Registry: is the previous image still present, or did a retention policy reap it? | **HALT.** If nothing is retained, `rollout undo` will fail or no-op. The recovery is a fresh deploy of the previous SHA, which needs the image to exist — check before you need it |
| **R3 — is the artifact reference immutable?** | Does the target resolve to a fixed digest/SHA, or to a moving tag? | If the previous deploy used `:latest` / `:staging` / a branch tag, that tag now points at the **bad** build. "Roll back to the previous tag" redeploys the same broken image | **HALT.** Resolve the digest explicitly, or the rollback is a no-op that looks like a success. This is `/deploy-stage`'s S5 breaking S1 in real time |
| **R4 — shared state the old version cannot read** | Did the new version write anything the old version will choke on? | Four places, in descending order of how often they bite: (a) **cache / session store** entries written in a new serialization format the old code cannot parse — often invisible until a cache hit; (b) **queue / topic messages** produced under the new schema that old consumers reject or dead-letter; (c) **feature flags** the new version's bootstrap flipped, which do not flip back with the artifact; (d) **an API contract** a client has already consumed | **Amber, not red.** Name the mitigation with the rollback: flush/namespace the cache by version, drain or pause the consumer, revert the flag explicitly. Rolling back without naming these is how the second incident starts |

Under `--dry-run` this is where the run stops, reporting resolved target + gate result.

### Step 5 — Pre-flight confirm (read-confirm-execute)

Show: current (bad) revision → target revision + how its health was established (or `UNVERIFIED`),
the exact command, blast radius (which env / namespace / service), and every R4 mitigation that has
to happen alongside. For prod, or for a `--to` that skips intermediate revisions, require explicit
confirmation.

### Step 6 — Execute the revert

Via the native, reversible mechanism only — never a destructive re-deploy, never a hand-edit of a
live object. One operation, so it is itself revertible.

### Step 7 — Monitor until green

Dispatch `monitor-deploy` on the rolled-back revision (health/readiness probe, error rate, latency
vs baseline) plus the `smoke-verify` skill (boot-check) where applicable. Declare recovery only on
**observed** GREEN — the same bar the forward deploy had to clear. A rollback that was never polled
is not a confirmed recovery.

If the rolled-back revision does *not* recover, stop rolling further back. Two failed reverts in a
row is a signal the fault is not in the artifact (step 2, row 2) — switch to incident triage.

### Step 8 — Write the runbook entry

Append to `ai/runbooks/` (or the project's incident log): what failed, the step-2 decision and why,
target rolled back to and how its health was established, the gate result including any R4
mitigation performed, health-recovery evidence, follow-ups. Record the revision as recovered in the
deploy ledger — `ai/runtime/deploys.md`, the same row shape `/deploy-stage` Phase 5 writes, created
here if this project has none yet — so the *next* rollback can resolve it in step 3.

## Platform mapping

`--to=<version>` is not a flag anyone's CLI accepts — resolve it to the mechanism's own selector:

| Mechanism | Previous revision | Explicit target |
|---|---|---|
| Kubernetes (Deployment) | `kubectl rollout undo deployment/<name>` | `kubectl rollout undo deployment/<name> --to-revision=<N>`, where `<N>` comes from `kubectl rollout history` |
| Helm | `helm rollback <release>` | `helm rollback <release> <revision>` from `helm history <release>` |
| Registry re-pin (compose / ECS / Nomad / PaaS) | redeploy the previous **digest**, not the previous tag (R3) | pin `@sha256:<digest>` explicitly |
| Serverless alias | point the alias at the previous version | alias → named version id |
| Platform-managed (dashboard/API promote) | promote the previous successful deployment | the platform's deployment id |

Resolve the selector from the platform's own history output; do not infer a revision number.

## Halts (refuse, don't guess)

- No deploy mechanism detected → ask which platform.
- **R1: a contract-step migration already applied** → refuse the code-only rollback; surface the
  reconciliation steps or route to forward-fix. Never auto-run a destructive down-migration.
- **R2: no retained prior revision / artifact** → refuse; a `rollout undo` with nothing to undo to
  is a failed rollback dressed as one.
- **R3: the target resolves to a mutable tag** → refuse until it resolves to a digest/SHA.
- Target health is UNVERIFIED and `--force` was not passed → stop and say which of the three health
  sources failed to resolve. Do not roll back to an unknown revision by default.
- `monitor-deploy` cannot establish a health signal on the rolled-back revision → the recovery is
  unconfirmed; report it as unconfirmed rather than declaring GREEN.

## Hard rules

- **Gate before revert.** Step 4 runs before step 6, always. Discovering a dropped column after the
  revert is the single most expensive ordering mistake this command can make, and it is the reason
  the gate exists.
- **Resolved ≠ known-good.** A revision number from platform history is a target, not evidence of
  health. Health comes from the ledger, a `monitor-deploy` record, or platform deployment status —
  named, or the target is UNVERIFIED.
- **Never fabricate a rollback.** If the deploy is not reversible by a native operation, say so and
  name the manual steps. A reported rollback that did not restore the prior artifact is worse than
  no rollback, because the incident clock keeps running while everyone believes it stopped.
- **One revert at a time.** Do not stack reverts. If the first does not recover, triage.
- **Recovery is observed, not assumed.** GREEN comes from `monitor-deploy`, never from the revert
  command's exit code.
- **Every run writes the runbook entry** — including the aborted ones. A halt at R1 is the most
  valuable entry in the file: it is the migration that has to become reversible before the next
  release.

## Output (brief)

```
/rollback-deploy --env=prod

Mechanism:     Helm (release: web, ns: prod)
Decision:      ROLLBACK  (fault is in the artifact; no in-flight backfill; forward-fix ETA 25m > budget)

Target:        rev 41 (abc1234)   HEALTH: GREEN — ai/runtime/deploys.md:88, monitor-deploy 2026-08-21T14:02Z
Current (bad): rev 42 (def5678)

Reversibility gate:
  R1 migrations   PASS   1 migration in rev 42: add nullable column `users.phone2` (expand) — safe to leave
  R2 target       PASS   rev 41 present in `helm history web`; image digest still in registry
  R3 immutable    PASS   rev 41 pins web@sha256:9f2c… (not a moving tag)
  R4 shared state AMBER  rev 42 wrote session blobs with `v2` envelope — old code cannot parse.
                         Mitigation REQUIRED alongside revert: flush session namespace `sess:v2:*`

Executing:     helm rollback web 41
Recovery:      monitor-deploy — 3/3 READY, /healthz 200×20/20, error rate 0.06% (threshold 0.5%)
Result:        RECOVERED (observed GREEN, 94s)

Runbook:       ai/runbooks/2026-08-22-prod-rollback.md
Follow-ups:    (1) session envelope needs a version-tolerant reader before the next attempt at rev 42
               (2) R4 has no automated check — add a cache-format assertion to /deploy-stage
```

## See also

- `/deploy-stage` — the forward deploy this reverses; its S1 calls `--dry-run` here for evidence
  that a rollback path exists.
- `devops/skills/monitor-deploy/SKILL.md` — the health-watch used to confirm the rolled-back
  revision recovered to GREEN, and the source of the GREEN records step 3 reads.
- `devops/skills/progressive-delivery/SKILL.md` — audits whether a kill-switch flag exists for the
  step-2 "flip, don't revert" path.
- `code-quality/skills/smoke-verify/SKILL.md` — the boot-check used to confirm recovery.
- `ai/runbooks/` — where the rollback evidence lands.
- `ai/runtime/deploys.md` — the deploy ledger step 3 reads and step 8 writes.
