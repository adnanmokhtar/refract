---
description: Deploy current branch to staging environment. Detects deploy target (kubectl / helm / docker-compose / serverless / vercel / netlify / etc.) from project config. Runs pre-flight (CI green, no uncommitted changes, working branch), executes deploy, monitors initial health, surfaces logs + error rate. Halt on red. Pairs with /rollback-deploy.
kind: command
pack: devops
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
disable-model-invocation: true
---

# /deploy-stage

## The Premise (read this first)

**One command to ship the current branch to staging.** Detects the deploy mechanism from project config, runs pre-flight checks, executes deploy, monitors initial health (first 5 min). If anything goes red, surfaces logs + suggests `/rollback-deploy`.

This is NOT for production deploys — production needs a release process (PR review + on-call sign-off + scheduled window). For staging, the bar is lower: branch + CI green + no dirty tree.

## When to use

- Validate a feature in staging before opening PR for review.
- Reproduce a staging-only issue.
- Pre-merge integration check.
- Rebuild staging after a rollback.

## When NOT to use

- For production → use the project's release runbook (typically `ai/runbooks/release.md`).
- For local dev → `pnpm dev` / `yarn dev` / `make run` / etc.
- Mid-incident — staging is for testing, not for incident response.

## Pre-requisites

- Working tree clean (commit or stash first).
- CI green on the current branch's HEAD commit.
- Deploy target accessible (network, credentials).
- `_extracted-codebase.md § Deploy` populated OR project has standard config (Dockerfile + docker-compose.yml, k8s manifests, vercel.json, etc.).

## Optional flags

- `--branch=<name>` — deploy a specific branch (default: current).
- `--commit=<sha>` — deploy a specific commit (default: branch HEAD).
- `--no-monitor` — deploy without the post-deploy monitoring step (just push and exit).
- `--watch=<duration>` — extend monitoring window (default: 5min; max: 60min).
- `--allow-dirty` — proceed with uncommitted changes (default: refuse).
- `--skip-ci-check` — proceed if CI hasn't passed yet (use only for emergency staging tests).

## Phase 1 — Understand

### Intent gate

If description suggests a different intent: "deploy to production" → halt; route to release runbook. "rollback" → `/rollback-deploy`. "monitor without deploying" → `monitor-deploy` skill. Proceed only for staging deploy.

### Detect deploy target

Check (in order). Every root comes from discovery, never from a guessed directory name: `rg --files -g 'Chart.yaml' -g 'kustomization.y*ml' -g '*compose*.y*ml' -g 'Dockerfile*' -g 'vercel.json' -g 'netlify.toml' -g 'serverless.yml' -g '!**/{node_modules,vendor,fixtures,__fixtures__,testdata}/**' .`
1. `_extracted-codebase.md § Deploy` — explicit project config.
2. A compose file whose name or deploy script marks it staging, plus the Dockerfile it builds — Docker Compose deploy.
3. A `Chart.yaml` with a staging values file — Helm-based k8s deploy.
4. A `kustomization.yaml` overlay for staging (wherever it lives: `deploy/overlays/staging/`, `k8s/staging/`, …) — kubectl deploy.
5. `vercel.json` / `.vercel/` — Vercel.
6. `netlify.toml` — Netlify.
7. `serverless.yml` — Serverless framework.
8. The CI deploy job for staging (`ci-graph.py --all` lists `deploys=` jobs; read the one whose `environment:` is staging) — workflow-driven.

If none detected → halt; route to `/setup-project --refine` to populate `_extracted-codebase.md § Deploy`.

## Phase 2 — Organize

```
1. PRE-FLIGHT     — clean tree, CI green, target reachable
2. DETECT         — deploy mechanism + staging endpoint
3. BUILD          — produce the deployable artifact (image / bundle / archive)
4. DEPLOY         — push to staging
5. MONITOR        — dispatch `monitor-deploy` skill: health + error-rate + latency for 5 min (or --watch=); skipped under --no-monitor
6. SAFE-GATE      — Safe-Delivery Gate S1-S5: exercise the rollback drill (S1); render the staging deploy roots offline and read the owners' rows on that render for probes, resource requests, plaintext secrets and the image reference (S2-S5, Phase 6). Dispatch `@deployment-engineer` to adjudicate the verdict. Emits the scorecard
7. REPORT         — deploy URL, version, and the GREEN-PRODUCTION-GRADE | INCOMPLETE verdict with any unmet items named
```

## Phase 3 — Retrieve

- `_extracted-codebase.md § Deploy` — staging URL, deploy command, healthcheck endpoint.
- Latest CI run on the branch — confirm green before deploy.
- Project's `Dockerfile` / k8s manifests / equivalent — deploy artifact source.

## Phase 4 — Generate (output)

```
/deploy-stage --branch=feature/refund-button

Pre-flight:
  ✓ Working tree clean
  ✓ Branch feature/refund-button at commit abc1234
  ✓ CI status: PASS (workflow #1842)
  ✓ Staging cluster reachable (https://staging.example.com)

Detected deploy target:
  Mechanism:           Helm chart
  Chart:               helm/web/Chart.yaml
  Staging values:      helm/web/values.staging.yaml
  Cluster context:     staging-eks

Building...
  ✓ Docker image built: registry.example.com/web:abc1234 (387MB, 1m 24s)
  ✓ Image pushed

Deploying...
  ✓ Helm upgrade --install web ./helm/web -f helm/web/values.staging.yaml --set image.tag=abc1234
  ✓ Rollout status: web/web-deployment ready (3/3 pods)

Monitoring (5 min)...
  Health endpoint:     https://staging.example.com/health
  ✓ /health returning 200
  ✓ Pod logs: no ERROR-level entries
  ✓ Error rate: 0.02% (within 0.5% threshold)
  ✓ Latency p95: 145ms (baseline: 152ms)

Safe-Delivery Gate (production-grade bar — each line carries evidence, no bare ✓):
  S1 Rollback exercised  PASS  /rollback-deploy --dry-run resolved rev 41 (def5678); HEALTH source =
                               ai/runtime/deploys.md:88 (GREEN 2026-08-21); gate R1-R3 PASS (only
                               additive migration in abc1234; rev 41 retained; digest-pinned);
                               rehearsal flipped abc1234→def5678, monitor-deploy GREEN 90s,
                               rolled forward to abc1234 [wired: rollback-deploy + monitor-deploy]
  S2 Health/readiness    PASS  0 K-READINESS-MISSING / K-PROBE-STARTUP rows for render-staging
                               (k8s-availability-scan §2; probe at helm/web/templates/deploy.yaml:38) AND
                               monitor-deploy polled /health 200×20/20, 3/3 READY [wired: monitor-deploy + owner rows]
  S3 Resource requests   PASS  0 K-RES-MISSING / K-QUOTA-SHAPE rows for render-staging (k8s-availability-scan §1:
                               requests + memory limit on both containers; no CPU limit required) [owner rows]
  S4 Secrets sourced     PASS  0 iac-scan §3 rows for render-staging; env from secretKeyRef → web-secrets [owner rows]
  S5 Reproducible build  PASS  0 iac-scan §3 4j rows: image …/web@sha256:9f2c… (the digest CI recorded);
                               release-integrity-scan §4 checked (scanned = pushed digest); container-build-scan §4:
                               --frozen-lockfile in Dockerfile:12 [owner rows]

Result: GREEN — PRODUCTION-GRADE (S1-S5 all evidenced)

Deployed to: https://staging.example.com
Version:     abc1234 (feature/refund-button)
Rollback:    /rollback-deploy --to=def5678  (resolved + rehearsed above)
Cleanup:     /deploy-stage --branch=main (when feature merges)
```

Functional-but-not-production-grade (health held, safety items unmet — the run NAMES them, never assumes them):

```
Monitoring (5 min)...
  ✓ /health returning 200   ✓ Error rate 0.03%   ✓ p95 141ms

Safe-Delivery Gate:
  S1 Rollback exercised  INCOMPLETE  `helm history web` lists one revision (first-ever staging
                                     deploy) and ai/runtime/deploys.md has no GREEN record →
                                     no target to resolve, rollback path UNEXERCISED
  S2 Health/readiness    UNMET       /health polled GREEN, but K-READINESS-MISSING api (k8s-availability-scan §2,
                                     render-staging; source helm/web/templates/deploy.yaml:30) — no automated
                                     readiness gate on the next rollout
  S3 Resource requests   UNMET       K-RES-MISSING api: no memory request (k8s-availability-scan §1,
                                     render-staging; source helm/web/values.staging.yaml:14)
  S4 Secrets sourced     PASS        0 rows for render-staging and the staging compose file
                                     [self-policed: § Fallback reads — security-class (owner pack not installed)]
  S5 Reproducible build  UNMET       image tag `:staging` in the deploy command, no digest (§ Fallback S5 read;
                                     security-class (owner pack not installed)) — no fixed rollback target

Result: INCOMPLETE — deployed and HEALTHY, but NOT production-grade.
        Unmet: S1 (rollback unexercised), S2 (no readinessProbe), S3 (no memory request), S5 (mutable tag).
        This artifact would be un-rollback-able and unbounded in prod. Fix before promotion:
          - add the readinessProbe and the requests + memory limit in the chart (infrastructure owns the fix shape)
          - deploy the digest CI recorded from the scanned build (S5 is what makes S1 possible)
Do NOT report this deploy as "done" — it is functional, not safe.
```

On health breach:

```
Result: RED

Failure mode:        Pod crash loop (3/3 pods CrashLoopBackOff)
Pod logs (last 50 lines):
  Error: ENOENT: no such file or directory, open 'config/staging.json'
  ...

Suggested:
  - /rollback-deploy --to=<previous>
  - Check that config/staging.json was committed.
  - Re-run /deploy-stage after fix.
```

## Phase 5 — Update

- `ai/_history.md` — `<iso> deploy-stage <branch>@<commit> → <result>`.
- **`ai/runtime/deploys.md` — append this deploy's row; create the file (header included) if it does
  not exist.** This write is not conditional. It is the artifact the *next* run's S1 resolves a
  prior-healthy revision against (Phase 6), so an `if exists` guard on a project that has never had
  one guarantees it never gets one. One row per deploy, newest last:

  | when (ISO) | env | revision (the platform's own selector) | artifact ref (immutable) | commit | verdict |
  |---|---|---|---|---|---|
  | 2026-08-21T14:02Z | staging | `rev 41` | `ghcr.io/acme/api@sha256:9f2c…` | `abc1234` | GREEN |

  Two things make the row usable rather than decorative. **The revision cell is whatever the platform
  would accept back** — the `kubectl rollout history` revision number, the `helm history` revision,
  the platform's deployment id — because step 3 of `/rollback-deploy` has to match it against that
  same list. **The verdict cell is the `monitor-deploy` result, never the deploy tool's exit code**: a
  rollout that converged on a broken build exits 0 and is `RED`. Write the row after Phase 4 returns,
  so the verdict is observed rather than predicted, and write it for `RED` and `INCOMPLETE` runs too —
  "rev 41 was RED" is precisely what stops the next rollback from targeting it.
- Deploy mechanism's own logs (k8s events, Helm history, Vercel deployment record) preserved by the tool.

## Phase 6 — Validate: the Safe-Delivery Gate — production-grade-or-INCOMPLETE (the closing verdict)

**"It deployed once and /health returns 200" is the FLOOR, not the bar.** A deploy that rolled out and held healthy through the window is merely FUNCTIONAL. The run declares **`Result: GREEN — PRODUCTION-GRADE`** ONLY when all five safety dimensions below PASS with cited evidence. If health held but any safety item is UNMET or its evidence could not be produced, the verdict is **`Result: INCOMPLETE`** with the unmet items NAMED — never assumed, never silently upgraded to GREEN. Staging is precisely where these are exercised *before* prod; a staging deploy that ships GREEN while the same artifact would be un-rollback-able / unbounded / secret-leaking in prod has taught you nothing. A `GREEN` sitting on bare ✓ marks with no cited evidence is enforcement theater — forbidden here.

The health-window sub-gate (readiness READY, `/health` 200, no ERROR logs, error-rate + latency within threshold) is owned by the `monitor-deploy` skill and feeds S2. A breach there is `RED` → the skill triggers `/rollback-deploy` (unchanged). The Safe-Delivery Gate runs *on top of* a GREEN health window.

**Who adjudicates.** Collect the S1-S5 evidence here, then **dispatch `@deployment-engineer`** with the collected citations to sign the verdict — that agent owns the same S1-S5 table and the rule that `PRODUCTION-GRADE` requires all five evidenced. It is the adjudicator, not a second opinion: if it returns `INCOMPLETE`, this run reports `INCOMPLETE`. When the agent is not installed (e.g. `--minimal`), this command applies the table itself and says so in the scorecard footer — an unadjudicated GREEN is still a GREEN, but it is self-signed and must be labelled `[self-adjudicated]`.

| # | Dimension (production bar) | PASS requires (evidence, not assertion) | If unmet |
|---|---|---|---|
| **S1 Rollback path RESOLVED + EXERCISED** | A rollback "plan" in words is not a rollback path. The target must resolve to a real prior-healthy revision, its **reversibility gate must pass**, AND the flip must have been rehearsed | `/rollback-deploy --dry-run` returned (a) a concrete target id resolved from platform history, (b) that target's health established from a named source — the deploy ledger (`ai/runtime/deploys.md`), a `monitor-deploy` GREEN record for that revision, or the platform's deployment status — never from revision history alone, and (c) a PASS on R1-R3 of its reversibility gate; AND a staging rollback drill flipped to it, `monitor-deploy` confirmed it recovered GREEN, then rolled forward — cite the monitor line | **INCOMPLETE (rollback-unexercised)** — no prior healthy revision (first-ever deploy), health source unresolvable (target `UNVERIFIED`), a gate halt, or drill not run. Cannot be GREEN; name which |
| **S2 Health + readiness probes PRESENT + EXERCISED** | A polled `/health` is not the same as an *automated* readiness gate the platform enforces on every future rollout | `monitor-deploy` polled the endpoint live (cite `200×N/N`, `k/k READY`) AND the staging render has no K-READINESS-MISSING or K-PROBE-STARTUP row for the served container: infrastructure `k8s-availability-scan` §2 (when installed). A liveness probe that checks a shared dependency is performance `request-path-scan` §15. Compose: `compose-scan` §2. A Dockerfile `HEALTHCHECK` counts only where compose, Swarm or ECS reads it; the kubelet ignores it (precedents § 29). Both halves, not either | **UNMET**: a probe polled green but absent from the render means no gate on the next deploy; or no resolvable endpoint at all |
| **S3 Resource requests present** | A container with no requests is scheduled blind, and an HPA on CPU never acts | The staging render has no K-RES-MISSING or K-QUOTA-SHAPE row: infrastructure `k8s-availability-scan` §1 (when installed). It wants CPU and memory requests and a memory limit where nothing defaults one. **A missing CPU limit is not a defect** (its precedent 1). Compose `deploy.resources` / `mem_limit` and serverless or PaaS memory and timeout settings are read by hand, `[self-policed]`. Cite the source `file:line` | **UNMET**: name the container and the row |
| **S4 No plaintext secrets in the deploy surface** | A secret in env/manifest/compose is leaked the moment the manifest is committed or the image is pulled | Secrets sourced by reference: `secretKeyRef`/`valueFrom` (k8s), a secrets manager, sealed-secret, SOPS or a platform secret store, never an inline literal. The owner rows: security `iac-scan` §3 on the staging render (a secret-named env with a literal `value:`, a committed `kind: Secret`), §2 on the compose file staging loads, `secret-scan-method` for values (when installed) | **UNMET**: any inline secret literal; cite it (redact the value) |
| **S5 Reproducible, addressable build** | A tag (`:latest`, `:staging`, even a git-SHA tag on a mutable registry) has no fixed rollback target, and it silently breaks S1 | The reference deployed is the digest CI recorded from the scanned build. Owner rows: security `iac-scan` §3 grep 4j finds no digest-less image on the staging render (credited there). `release-integrity-scan` §4 confirms scanned = pushed = deployed digest (V223). `container-build-scan` §4 confirms the lockfile is enforced in the build. Cite the image string + the Dockerfile line | **UNMET**: a mutable reference, a rebuild after the scan, or a non-frozen install |

### Reading the render (S2–S5)

S2–S5 read the **staging render**, never guessed source directories: a field set only by the staging overlay or values file exists only there. The render is offline even though this command deploys. Its first line points `KUBECONFIG` at an empty scratch file, so no read in this gate can reach a cluster, the staging one included.

```bash
export KUBECONFIG="$SCAN/empty-kubeconfig"; : > "$KUBECONFIG"      # always first
bash .claude/skills/k8s-render-scan/scripts/render.sh . --out="$SCAN"      # infrastructure pack: render-<env>.yaml per environment
# without it: kubectl --kubeconfig="$KUBECONFIG" kustomize <staging root> > "$SCAN/render-staging.yaml"
#             helm template --kubeconfig "$KUBECONFIG" <chart> -f <staging values file> > "$SCAN/render-staging.yaml"
```

A root that fails to render makes S2–S5 `SKIPPED — UNVERIFIED (render failed: <root>)`, never PASS. With no Kubernetes root, S2–S5 read the compose file or the platform config the staging deploy uses.

**§ Fallback — an owner pack is absent.** The S-line runs these reads on the render and the staging compose file. It is labelled `[self-policed]` and `<class> (owner pack <x> not installed)`. Every hit is a candidate to read, and the S-line cites the source `file:line`:

```bash
R="$SCAN/render-staging.yaml"
rg -n '^\s*(-\s*)?(kind|name|image|readinessProbe|livenessProbe|startupProbe|resources|requests|limits|cpu|memory):' "$R"   # S2, S3: read every container
K='[\w.-]*(?i:password|passwd|secret|token|api[_-]?key|private[_-]?key|credentials?)(?![\w.-]*(?i:_path|_file|_ref|name|keyref|ref)\b)[\w.-]*'
rg -n --pcre2 -g '*compose*.y*ml' -g '!**/{node_modules,fixtures,testdata}/**' -e "(?<![\w\${/.-])${K}\s*[:=]\s*(?![\x22\x27]?\\$)[\x22\x27]?[^\s\x22\x27#\$\{][^\s\x22\x27#]*" "$R" .   # S4: one-line literals
rg -n -U --pcre2 -e "-\s*name:\s*[\x22\x27]?${K}[\x22\x27]?\s*\n\s*value:\s*(?![\x22\x27]?\\$)[\x22\x27]?[^\s\x22\x27#\$]" "$R"   # S4: k8s name/value pair
rg -n --pcre2 '^\s*(-\s*)?image:\s*[\x22\x27]?(?![^\s\x22\x27]*@sha256:)\S' "$R"   # S5: no digest
```

### How this gate is actually enforced (honest mechanism — no theater)

- **S1 is wired to two real closure verbs.** RESOLVED = `/rollback-deploy --dry-run`, which runs its steps 1-4 and returns a target id, a **named health source** for that target, and a reversibility-gate result. Its own halts (`rollback-deploy.md § Halts`) refuse an `UNVERIFIED` target without `--force`, refuse a target behind an already-applied contract migration (R1), refuse a target that is no longer retained (R2), and refuse a mutable tag (R3) — so the id this gate cites cannot be a guess, and "a rollback exists" cannot mean "a revision number exists". EXERCISED = a staging rollback drill whose recovery is confirmed by the `monitor-deploy` skill, whose halts **refuse GREEN without a live-polled probe** — so "it recovered" cannot be asserted. If no prior healthy revision exists, EXERCISED is *impossible*, and the item is `INCOMPLETE (rollback-unexercised)`, never a faked PASS. [wired-to-closure-verb + wired-to-required-output]
- **How S1 reaches `/rollback-deploy`.** Both commands are level D (`disable-model-invocation: true`), so the Skill tool refuses `/rollback-deploy` from inside this run. The dry-run and the drill are steps of the deploy the user typed, not a new dispatch: read `.claude/commands/rollback-deploy.md` and execute its steps 1-4 (`--dry-run`) in this session. A non-D command or agent that wants a rollback never does this — it prints `/rollback-deploy …` for the user to type.
- **Where the health of a prior revision comes from.** Nothing in `kubectl rollout history` / `helm history` / a deployments list carries health — they list revisions, not verdicts. S1's "prior-healthy" claim resolves against the deploy ledger this command writes in Phase 5 (`ai/runtime/deploys.md` / `ai/_history.md`), a `monitor-deploy` GREEN record keyed to that revision, or the platform's deployment status — in that order. **This is why Phase 5's ledger write is non-optional**: it is the artifact that makes the *next* run's S1 resolvable. A project whose first deploys skipped it will legitimately sit at `INCOMPLETE (rollback-unexercised)` until two ledgered deploys exist.
- **S2's health half is wired to the `monitor-deploy` required output** (it refuses GREEN without a real poll). The *probe-present* half is the infrastructure owner's row on the staging render. A polled-green endpoint with no readiness probe in the render is a real, common gap.
- **S2–S5 cite owner rows on the render when those packs are installed:** infrastructure `k8s-availability-scan` §1–§2, security `iac-scan` §2–§3 and `secret-scan-method`, and devops `release-integrity-scan` §4 and `container-build-scan` §4. The S-line names the row, or "0 rows for render-staging" with the owner's coverage line. Cite an owner only if it actually ran in this session.
- **Without an owner pack, the S-line is a `[self-policed]` read** (§ Fallback) and MUST NOT be dressed as mechanical.

### Required output artifact

Every run MUST emit the **Safe-Delivery Gate** scorecard (see Phase 4 Output): one `S1..S5` line each carrying `PASS <evidence-citation>` | `UNMET <what's missing + where>` | `INCOMPLETE <why unexercisable>` | `SKIPPED — UNVERIFIED <why>`, then the single `Result:` line. A reader greps this block: a `Result: GREEN — PRODUCTION-GRADE` whose S-lines carry no citation is an **invalid artifact** — reject it and re-run. `GREEN — PRODUCTION-GRADE` is reserved for all-five-evidenced; a healthy deploy with any item short of that is `INCOMPLETE` with the gap named, so the next actor knows exactly what stands between this deploy and prod. `--no-monitor` cannot produce S1/S2 evidence → it exits `INCOMPLETE (unverified-deploy)`, never GREEN.

## Phase 7 — Improve

- If deploys repeatedly fail in monitoring (red after green pre-flight), surface "infra/config drift between dev and staging."
- If image build time grows > 50%, flag for caching review.
- If monitor surfaces same error 3+ deploys, flag for ADR — recurring config issue.

## Hard rules

- **Pre-flight halts the deploy.** Dirty tree, red CI, unreachable target — refuse.
- **One staging deploy at a time.** If staging is mid-deploy from another run, halt; don't race.
- **Don't deploy to production.** Refuses with `--target=prod`; that's a different command + runbook.
- **Monitor before declaring success.** First 5 min are the most likely failure window; can't skip.
- **A healthy deploy is not a safe deploy.** `GREEN — PRODUCTION-GRADE` is reserved for S1-S5 all evidenced (Phase 6). A functional-but-unsafe deploy reports `INCOMPLETE` with the unmet items NAMED — never assume a safety item you did not verify, never round a healthy-but-unbounded deploy up to GREEN.
- **Rollback is EXERCISED, not declared.** The rollback target must resolve to a real prior-healthy revision and the flip must have been rehearsed (staging is where you rehearse it). "Redeploy the previous SHA" in prose is not a rollback path.
- **Log every deploy.** The audit trail in `ai/_history.md` is non-optional.

## Failure modes

- **Deploy mechanism not detected** → halt; route to `/setup-project --refine`.
- **CI not green** → halt unless `--skip-ci-check`.
- **Staging cluster unreachable** → halt; check VPN / credentials.
- **Image build fails** → halt with build log tail.
- **Pod fails to start** → halt; surface logs; **name the state** (below), then suggest rollback.
- **Health check times out** → mark RED; **name the state** (below), then suggest rollback.

**Any halt AFTER the deploy command ran must say what staging is running now.** "Suggest rollback"
is advice; a halted operator needs a fact. Both failures above happen *after* the apply, and what
the environment is left running is mechanism-dependent, not obvious:

- **Helm without `--atomic`** — the release sits in `failed` state with the NEW manifest applied.
  You are **not** back on the old revision. Undo: `helm rollback <release> <prev-rev>`.
- **`kubectl apply` / rollout** — the new ReplicaSet exists and is unhealthy; the old pods keep
  serving only while the rollout has not completed. Undo: `kubectl rollout undo deploy/<name>`.
- **Vercel / Netlify / serverless** — the new deployment exists but may or may not hold the alias.
  Say whether traffic actually moved, and give that platform's promote-previous command.

Report three things before ending a halted run: **what is deployed**, **what is serving traffic**,
and **the exact one-line command to undo it** for the detected mechanism. This is the contract
`/execute-plan` applies to local git state — and it matters more here, because this state sits on
infrastructure other people are using, not in a working tree only you can see.
- **Health green but a safety item (S1-S5) unmet** → `INCOMPLETE`, not GREEN; name the unmet items; do not report the deploy as done.
- **No prior healthy revision (first-ever deploy)** → S1 rollback cannot be EXERCISED → `INCOMPLETE (rollback-unexercised)`; say so, don't fake a rollback drill.
- **`--no-monitor`** → S1/S2 evidence cannot be produced → exits `INCOMPLETE (unverified-deploy)`.

## Related

- `/rollback-deploy` — pair command for reverting; `--dry-run` supplies S1's resolved target, its health source, and its reversibility-gate result.
- `@deployment-engineer` — dispatched in Phase 6 to adjudicate the Safe-Delivery verdict.
- infrastructure `k8s-render-scan` (`scripts/render.sh`) renders the staging set S2–S5 read; `k8s-availability-scan` §1–§2, security `iac-scan` §2–§3, `release-integrity-scan` §4 and `container-build-scan` §4 are the owner rows they cite (Phase 6).
- `/add-ci` — adds CI workflow (pre-requisite for the CI-green check).
- `/dockerize` — adds Dockerfile (pre-requisite for image-based deploy).
- `monitor-deploy` skill — extended monitoring (longer windows, custom metrics).
- `ai/runbooks/release.md` — production deploy procedure.

### Called by
- Manual user invocation (most common).
- CI workflow on merge to `staging` branch (some projects).
