---
description: Deploy current branch to staging environment. Detects deploy target (kubectl / helm / docker-compose / serverless / vercel / netlify / etc.) from project config. Runs pre-flight (CI green, no uncommitted changes, working branch), executes deploy, monitors initial health, surfaces logs + error rate. Halt on red. Pairs with /rollback-deploy.
kind: command
pack: devops
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

Check (in order):
1. `_extracted-codebase.md § Deploy` — explicit project config.
2. `Dockerfile` + `docker-compose.staging.yml` — Docker Compose deploy.
3. `helm/` directory + `Chart.yaml` — Helm-based k8s deploy.
4. `k8s/staging/` directory — kubectl deploy.
5. `vercel.json` / `.vercel/` — Vercel.
6. `netlify.toml` — Netlify.
7. `serverless.yml` — Serverless framework.
8. `.github/workflows/deploy.yml` — workflow-driven (read for the staging job).

If none detected → halt; route to `/setup-project --refine` to populate `_extracted-codebase.md § Deploy`.

## Phase 2 — Organize

```
1. PRE-FLIGHT     — clean tree, CI green, target reachable
2. DETECT         — deploy mechanism + staging endpoint
3. BUILD          — produce the deployable artifact (image / bundle / archive)
4. DEPLOY         — push to staging
5. MONITOR        — health check + log tail for 5 min (or --watch=)
6. REPORT         — surface deploy URL, version, health status
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

Result: GREEN

Deployed to: https://staging.example.com
Version:     abc1234 (feature/refund-button)
Rollback:    /rollback-deploy --to=<previous-version>
Cleanup:     /deploy-stage --branch=main (when feature merges)
```

On failure:

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
- `ai/runtime/deploys.md` (if exists) — append deploy entry.
- Deploy mechanism's own logs (k8s events, Helm history, Vercel deployment record) preserved by the tool.

## Phase 6 — Validate

- Health check endpoint returns 200 within timeout.
- Pod / function / container reaches READY state.
- Log tail shows no ERROR-level entries in monitoring window.
- Error rate stays within configured threshold.

If any fail → mark RED; suggest `/rollback-deploy`.

## Phase 7 — Improve

- If deploys repeatedly fail in monitoring (red after green pre-flight), surface "infra/config drift between dev and staging."
- If image build time grows > 50%, flag for caching review.
- If monitor surfaces same error 3+ deploys, flag for ADR — recurring config issue.

## Hard rules

- **Pre-flight halts the deploy.** Dirty tree, red CI, unreachable target — refuse.
- **One staging deploy at a time.** If staging is mid-deploy from another run, halt; don't race.
- **Don't deploy to production.** Refuses with `--target=prod`; that's a different command + runbook.
- **Monitor before declaring success.** First 5 min are the most likely failure window; can't skip.
- **Log every deploy.** The audit trail in `ai/_history.md` is non-optional.

## Failure modes

- **Deploy mechanism not detected** → halt; route to `/setup-project --refine`.
- **CI not green** → halt unless `--skip-ci-check`.
- **Staging cluster unreachable** → halt; check VPN / credentials.
- **Image build fails** → halt with build log tail.
- **Pod fails to start** → halt; surface logs; suggest rollback.
- **Health check times out** → mark RED; suggest rollback.

## Related

- `/rollback-deploy` — pair command for reverting.
- `/add-ci` — adds CI workflow (pre-requisite for the CI-green check).
- `/dockerize` — adds Dockerfile (pre-requisite for image-based deploy).
- `monitor-deploy` skill — extended monitoring (longer windows, custom metrics).
- `ai/runbooks/release.md` — production deploy procedure.

### Called by
- Manual user invocation (most common).
- CI workflow on merge to `staging` branch (some projects).
