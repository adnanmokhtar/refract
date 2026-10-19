---
description: Production progressive release (canary, blue-green, flag ramp) of a READY run, plan by default, H3 per step.
kind: command
pack: devops
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
disable-model-invocation: true
---

# /release

## The Premise (read this first)

**A deploy puts an artifact on servers; a release puts users on it.** `/deploy-stage` proves an
artifact in staging. This command moves production traffic onto that same artifact in steps small
enough that the step which goes wrong costs a few percent of users for a few minutes, and every
step that changes production waits for a human (H3, architecture proposal §4.4).

Three properties make it a release process and not a script:

1. **It refuses what was not proved.** The run's `verdict.json` must be PASS and still bound to the
   commit being released, the behavioural baseline diff must be explained, and staging must hold a
   `GREEN — PRODUCTION-GRADE` row for the exact artifact digest. Otherwise the output is `NOT READY`
   with the missing evidence named.
2. **It plans by default.** Without `--execute` it renders the release plan — strategy, steps,
   holds, the analysis that promotes or aborts each step, the abort command, the rollback target —
   writes it to the run's `release.md`, and stops. A plan run never contacts a cluster or a cloud
   API (§ Offline plan).
3. **Each irreversible step is a human decision.** `--execute` runs one step at a time. Each step's
   command reaches `.claude/hooks/guard-irreversible.sh`, which returns `ask`, so the human approves
   that exact command in the permission prompt (auto mode shows it too; with prompts off the hook
   denies). The approval is recorded in `run.json` `approvals[]` as `H3`. This command never batches
   steps, never passes `--yes` past a prompt, and never runs inside a subagent.

## When to use

- A run closed READY (P12) and `/deploy-stage` left a `GREEN — PRODUCTION-GRADE` staging row for
  its artifact: this is P13 Deploy.
- Promoting a hot-fix that went through `/fix-bug` and staging.

## When NOT to use

- Staging → `/deploy-stage`. Recovery from a bad production deploy → `/rollback-deploy`.
- No run directory (a T0 change) → T0 never opens a run, so there is no verdict; ship it through the
  project's own pipeline or open a run first.
- Mid-incident: mitigate first (`/investigate-incident` reads, `/rollback-deploy` reverts).

## Args

```
/release                          # PLAN for the newest run whose verdict is PASS at HEAD (nothing executed)
/release --run=<run-id>           # plan for a named run (ai/runs/<run-id>/)
/release --strategy=canary|blue-green|flag-ramp|rolling   # override the detected strategy
/release --steps=1,5,25,50,100    # traffic percentages (default: canary 5,25,50,100; flag-ramp 1,5,25,50,100)
/release --hold=10m               # minimum hold per step (default 10m; the analysis may extend, never shorten)
/release --execute                # perform the plan, one H3-approved step at a time
/release --resume                 # continue an --execute run from the step release.md records as last PROMOTED
```

## Phase 1 — Understand: the release gate (all must hold, each cited)

Read the run first: `ai/runs/<run-id>/run.json` (tier, phase states, approvals), `verdict.json`,
`release.md`, and `.claude/baselines/main/manifest.json`. Then evaluate, in order:

| # | Gate | PASS requires (evidence, not assertion) | Else |
|---|---|---|---|
| **G-R1 Verdict** | `ai/runs/<run-id>/verdict.json`: schema `refract/verdict/v1`, mode `acceptance`, `verdict: PASS`, and still bound to HEAD: `python3 .claude/scripts/gate-check.py --ci --base=<production sha> --only=G0,G1,G15 --json` reports G0 and G1 `PASS` (a verdict whose scope fingerprint no longer matches is STALE, which G1 reports as FAIL) | `NOT READY (verdict missing / CONCERNS / FAIL / STALE)`. `CONCERNS` passes only with a human `WAIVED(owner, expiry ≤30d, reason, ticket)` in `run.json` `waivers[]` |
| **G-R2 Baseline diff** | `gate-check.py --ci --only=G14,G4` (the same run as G-R1 may carry them): G14 `behaviour` PASS, or N-A with its reason, or EXPLAINED by an AC's `changes_baseline`; G4 `perf` PASS or N-A. Each explained difference is copied into `release.md` § Behaviour changes, because users will see it | `NOT READY (unexplained behaviour diff <entry>/<case>)`; `UNVERIFIED` blocks at T2 and T3 (tier from `run.json`) |
| **G-R3 Staging proof** | `ai/runtime/deploys.md` holds a staging row for this artifact's **digest** with verdict `GREEN` from a `/deploy-stage` run whose Safe-Delivery Gate printed `GREEN — PRODUCTION-GRADE` | `NOT READY (no staging proof for <digest>)` — an `INCOMPLETE` staging row names its unmet S-items, copy them |
| **G-R4 Rollback path** | `/rollback-deploy` steps 1–4 (`--dry-run`) for production resolve a prior target with a named health source and R1–R3 PASS; R4 mitigations are copied into the plan | `NOT READY (rollback unavailable: <R#>)`. An R1 halt means a contract migration ships in this release: split it (expand now, contract in a later release) |
| **G-R5 release.md** | The run's `release.md` names: flag or kill switch, migration order, rollback, staging checks, SLO and alert links, success metric and counter-metric with their instrumentation (proposal §4.1). Required at T3; at T2 a missing section is listed | Write the missing sections as a draft from what the run holds, mark it `DRAFT`, and stop: `NOT READY (release.md incomplete)` |
| **G-R6 SLO analysis source** | `ai/runtime/slos.md` has a row for every service the release touches, and its burn rules exist (`slo-rule-scan` §1 SLO-01 clean when the observability pack is installed) | Without an SLO the step analysis cannot be SLO-based: the plan falls back to explicit error-ratio and latency thresholds named in `release.md`, and the result can never be `RELEASED — SLO-VERIFIED` (§ Phase 6). `/add-slo` defines one |
| **G-R7 Readiness** | product `launch-readiness` (`readiness-score.py --feature=<slug>`, when the product pack is installed) at the feature's stage target exits 0 | Listed with the failing rule ids; a GA feature below silver is `NOT READY` |

Any `NOT READY` ends the run after Phase 5's ledger line. The output names every failing gate, not
the first one.

## Phase 2 — Organize: detect the platform and the strategy

Discover deploy roots exactly as `/deploy-stage` § Detect deploy target does (never a guessed
directory). Then pick the strategy the platform actually supports. The CLI shapes below are a map,
not a script: confirm each against the installed CLI's `--help` before printing it in the plan, and
mark a step `[cli-unverified]` when that CLI is not installed where the plan runs.

| Platform signal | Strategy | Step command (each one is H3) | Abort (also H3) |
|---|---|---|---|
| Argo Rollouts `Rollout` with `strategy.canary` | canary with `AnalysisTemplate` | `kubectl argo rollouts set image <rollout> <ctr>=<image>@<digest>`, then `kubectl argo rollouts promote <rollout>` per paused step | `kubectl argo rollouts abort <rollout>` |
| Argo Rollouts `strategy.blueGreen` | blue-green, `prePromotionAnalysis` | `set image`, then `promote` after the preview analysis | `abort` (traffic stays on the active ReplicaSet) |
| Flagger `Canary` | canary driven by Flagger | the image change through the repo's GitOps path (Flagger owns the steps; this command watches `kubectl get canary`) | revert the image change; Flagger rolls back on failed analysis |
| Service mesh / Gateway API weights (Istio `VirtualService`, `HTTPRoute` `backendRefs[].weight`) | canary by weight | apply the rendered weight change for the step | weight back to 0 on the canary |
| Plain `Deployment` / Helm, no mesh | blue-green by Service selector, or rolling with `maxUnavailable: 0` | `helm upgrade --install … --atomic --wait --timeout <t>` / apply the green Deployment, then switch the selector | `helm rollback` / switch the selector back |
| AWS ECS with CodeDeploy | canary or linear deployment config (`CodeDeployDefault.ECSCanary10Percent5Minutes` family) | `aws deploy create-deployment …` | `aws deploy stop-deployment --auto-rollback-enabled` |
| AWS Lambda alias | weighted alias | `aws lambda update-alias --function-name <f> --name <alias> --routing-config AdditionalVersionWeights={<ver>=<w>}` | the alias back to the previous version, no routing config |
| Cloud Run | revision traffic split | `gcloud run services update-traffic <svc> --to-revisions=<rev>=<pct>` | `--to-revisions=<prev>=100` |
| Azure App Service | deployment slot + traffic routing | `az webapp traffic-routing set --distribution <slot>=<pct>`, then `az webapp deployment slot swap` | `az webapp traffic-routing clear`, swap back |
| Fly.io | `fly deploy --strategy canary` or `bluegreen` | the deploy itself | `fly releases` → redeploy the prior image by digest |
| Feature flag on a risky path (OpenFeature, LaunchDarkly, Unleash, …; `progressive-delivery` §4 lanes) | **flag ramp**: deploy dark, then ramp the flag | deploy with the flag off (one H3), then each ramp percentage in the provider (one H3 each) | flag off — the kill switch; faster than any artifact rollback |
| None of the above | rolling only | the platform's deploy | `/rollback-deploy` |

Rules the plan applies:
- **Prefer a flag ramp when a flag already guards the risky path** (`progressive-delivery` §4 finds it,
  §8 checks its outage default). The kill switch then moves no artifact.
- **A canary needs a gate that can fail.** When `progressive-delivery` §5 (devops pack) reports a
  never-failing analysis on the Rollout or Canary this release uses, the plan refuses that gate and
  runs the analysis below by hand at each pause.
- **Migrations go first and only expand** (`migration-safety` §4 N-1, when the database pack is
  installed): the expand migration is its own H3 step before any traffic moves; a contract step
  belongs to a later release.

## Phase 3 — Retrieve: the step analysis (what promotes, what aborts)

Each step holds for `--hold` (and for at least the SLO's short confirmation window), then reads the
canary-scoped and stable-scoped SLI for that window from the source `ai/runtime/slos.md` names:

```
PROMOTE  requests(canary) ≥ min_requests  AND  error_ratio(canary) ≤ (1 − objective) × fast_factor
         AND  error_ratio(canary) ≤ max(2 × error_ratio(stable), 1 − objective)
         AND  latency SLI(canary) meets its threshold  AND  no page-tier burn alert firing
ABORT    error_ratio(canary) > (1 − objective) × fast_factor   (the canary alone would page)
         OR a page-tier burn alert fires for the service during the hold
HOLD     fewer than min_requests in the window: INCONCLUSIVE, extend the hold — never promote on no data
```

`fast_factor` is the SLO's own fast page factor from its burn set (`burn-check.py`, `slo-rule-scan`
§2 — 14.4 for a Workbook set on 30 days, recomputed for another period, never copied).
`min_requests` defaults to the count at which one failure is within the budget
(`⌈1 / (1 − objective)⌉`, 1,000 at 99.9 %) and is written into `release.md`. The thresholds are the
plan's defaults; a project changes them in `release.md` § Analysis, never per step at 2 a.m.

## Phase 4 — Generate: the plan (default) and the execution (`--execute`)

### Offline plan

```bash
export KUBECONFIG="$SCRATCH/empty-kubeconfig"; : > "$KUBECONFIG"    # always first: a plan never reaches a cluster
bash .claude/skills/k8s-render-scan/scripts/render.sh . --out="$SCRATCH"   # infrastructure pack, when installed
# without it: kubectl --kubeconfig="$KUBECONFIG" kustomize <prod overlay> > "$SCRATCH/render-production.yaml"
#             helm template --kubeconfig "$KUBECONFIG" <chart> -f <prod values> > "$SCRATCH/render-production.yaml"
```

The plan reads platform state from the deploy ledger and the render only; no cloud CLI runs in plan
mode, so no credential is touched. It writes `release.md` § Rollout plan and prints:

```
/release --run=20261019-refund-button-7c2e        (PLAN — nothing executed)

Release gate:
  G-R1 Verdict        PASS  verdict.json PASS (acceptance, signer verifier); gate-check --ci G0/G1/G15 PASS at 4f1a9c2
  G-R2 Baseline diff  PASS  G14 EXPLAINED: refunds/partial-refund (AC-004 changes_baseline) · G4 N-A (no perf entry in scope)
  G-R3 Staging proof  PASS  ai/runtime/deploys.md:41 staging ghcr.io/acme/api@sha256:9f2c… GREEN — PRODUCTION-GRADE
  G-R4 Rollback path  PASS  rollback-deploy --dry-run: rev 57 (GREEN, deploys.md:38) · R1 expand-only · R2 retained · R3 digest · R4 none
  G-R5 release.md     PASS  flag refund-v2 · migration 0042 expand-only · SLO checkout.success · metric refund_completed
  G-R6 SLO source     PASS  checkout.success 99.9 %/30d, Workbook set, fast factor 14.4 (burn-check exit 0)
  G-R7 Readiness      PASS  readiness-score --feature=refund-button exit 0 (silver)

Strategy: flag ramp (refund-v2 guards the refund write; progressive-delivery §4 0 rows, §8 default false)
  Step 0  migrate      npx prisma migrate deploy (0042, expand)            H3   abort: none needed (additive)
  Step 1  deploy dark  kubectl argo rollouts set image api api=…@sha256:9f2c…   H3   abort: kubectl argo rollouts abort api
  Step 2  flag 1 %     provider: refund-v2 → 1 %                           H3   hold 10m · min 1,000 req
  Step 3  flag 5 %     …                                                   H3   hold 10m
  Step 4  flag 25 % · Step 5 50 % · Step 6 100 %                           H3   hold 30m at 100 % before close
Abort at any step: refund-v2 → 0 % (kill switch), then /rollback-deploy --env=production --to=rev 57 if the artifact must go
Analysis per step: PROMOTE / HOLD / ABORT as Phase 3, error budget 0.1 %, abort above 1.44 % canary error ratio

Result: PLAN — 7 H3 steps. Re-run with --execute to perform them one at a time.
```

### Execute (`--execute`)

Re-run the gate first (a plan is stale the moment HEAD or the ledger moves). Then, per step:
1. Print the step: command, blast radius (env, namespace, service, traffic share), abort command.
2. Run the command. `guard-irreversible.sh` asks; the human's approval in that prompt is H3. A denied
   prompt ends the run `HALTED (H3 declined at step N)` — nothing retried, nothing reworded.
3. Append `{gate: "H3", by: "human", at, artifacts: [{path: "ai/runs/<id>/release.md", sha256}]}` to
   `run.json` `approvals[]` (the hash binds the approval to the plan that was shown).
4. Dispatch the `monitor-deploy` skill for the hold window and read the Phase 3 analysis.
   `PROMOTE` → next step. `HOLD` → extend, re-read. `ABORT` → run the abort command (H3 again), watch
   it back to GREEN with `monitor-deploy`, then stop and print `/rollback-deploy --env=production`
   with the resolved target when the artifact itself must go. This command does not dispatch
   `/rollback-deploy` (level D); the human types it.

## Phase 5 — Update

- `ai/runtime/deploys.md` — one row per executed release, the same columns `/deploy-stage` Phase 5
  writes, `env = production`, the verdict from `monitor-deploy` at the final step (never the exit
  code). `NOT READY` and plan runs write no row; `ABORTED` and `HALTED` runs do.
- `ai/runs/<run-id>/release.md` — § Rollout plan (every run), § Step log (each step: time, command,
  approval, analysis numbers, decision), and § Post-release (P14: success metric and counter-metric
  read at the review time `release.md` names).
- `ai/runs/<run-id>/run.json` — `approvals[]` (H3 per executed step) and phase P13 state.
- `ai/_history.md` — `<iso> release <run-id> <strategy> → <result>`.

## Phase 6 — Validate: the result (required output)

Every run ends with exactly one `Result:` line, and each gate and step line carries its evidence:

- **`RELEASED — SLO-VERIFIED`** — G-R1..G-R7 PASS, every step `PROMOTE` on the SLO analysis, 100 %
  held for its final hold with no page-tier burn.
- **`RELEASED — UNVERIFIED-ANALYSIS`** — traffic reached 100 % but G-R6 was unmet (no SLO): the
  thresholds were explicit, not SLO-derived. Name it; `/add-slo` before the next release.
- **`ABORTED — RECOVERED`** — a step aborted and `monitor-deploy` observed GREEN after the abort.
- **`HALTED`** — stopped mid-release (H3 declined, gate re-check failed, analysis INCONCLUSIVE past
  `--hold × 6`). Say **what is deployed, what is serving which traffic share, and the one-line
  command that undoes it**, the contract `/deploy-stage` § Failure modes sets.
- **`NOT READY`** — the gate refused; every failing G-R line is named.
- **`PLAN`** — nothing executed.

A `RELEASED` line whose steps carry no analysis numbers is an invalid artifact: re-run.

## Phase 7 — Improve

- An `ABORTED` release becomes an incident record: `/postmortem` turns the abort into action items and
  a new seeded defect.
- A step that sat `HOLD` for lack of traffic on every release: lower the step count, not the minimum.

## Hard rules

- **Production only behind a PASS verdict bound to HEAD** (G-R1). No flag skips it.
- **One step, one H3.** Never batch steps, never pre-approve, never run `--execute` from a subagent
  (the hook denies there) or under bypassPermissions / dontAsk (the hook denies there too).
- **Plans are offline.** Empty scratch `KUBECONFIG`, no cloud CLI, no live read in plan mode.
- **Never promote on no data.** INCONCLUSIVE holds; it never counts as PROMOTE.
- **Expand ships before code; contract never ships in the same release.**
- **Abort is faster than rollback.** Flag off or traffic back first; the artifact rollback is the
  human's `/rollback-deploy`.

## Failure modes

- **Gate re-check fails between plan and execute** → `NOT READY`, nothing executed.
- **H3 declined** → `HALTED (H3 declined at step N)`, state named.
- **The analysis source is unreachable mid-step** → `HOLD`; past `--hold × 6`, `HALTED` with the
  traffic share stated. Never treat a missing metric as healthy.
- **Abort command fails** → `HALTED`; print the platform's manual traffic reset and
  `/rollback-deploy --env=production`.

## Related

- `/deploy-stage` — the staging proof G-R3 reads and the deploy-ledger row shape.
- `/rollback-deploy` — G-R4 runs its steps 1–4; the human types it after an `ABORTED` release.
- `monitor-deploy` skill — the hold-window watcher; `progressive-delivery` skill — §4/§8 (flags), §5 (canary gate).
- `.claude/hooks/guard-irreversible.sh` — the H3 prompt on every step.
- `/add-slo` (observability pack) — the SLO and burn set Phase 3 reads.
- `/investigate-incident`, `/postmortem` (observability pack) — when a release aborts.

### Called by
- Manual user invocation only (level D: `/do` prints it, never dispatches it).
