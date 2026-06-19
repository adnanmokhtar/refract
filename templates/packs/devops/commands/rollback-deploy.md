---
description: Roll back the current environment to a previous known-good deploy. Detects the deploy mechanism (kubectl / helm / docker-compose / serverless / vercel / netlify / etc.) from project config, picks the rollback target (previous revision by default, or `--to=<version>`), runs a pre-flight confirm, executes the revert, monitors health until green, and writes a rollback runbook entry. The recovery pair of `/deploy-stage` — invoked when a staged/prod deploy goes red.
kind: command
pack: devops
---

# /rollback-deploy

**One command. Revert the current environment to the last known-good deploy and confirm it recovered.** The pair of `/deploy-stage` — when a deploy goes red, this is the 2-minute path back instead of a 2-hour incident.

## When to use

- `/deploy-stage` (or a CI deploy) went red — error rate / health probe / smoke failed after rollout.
- A canary or post-deploy alert fired and you need the previous revision back NOW.
- NOT for code changes — this reverts a *deployment*, not a commit. (Use git for code.)

## Args

```
/rollback-deploy                 # roll back to the immediately previous revision
/rollback-deploy --to=<version>  # roll back to a specific revision/tag/deployment id
/rollback-deploy --env=staging   # target a specific env (default: the one /deploy-stage last touched)
/rollback-deploy --dry-run       # show the rollback plan + target revision; execute nothing
```

## What happens

1. **Detect the deploy mechanism** from project config (same detection as `/deploy-stage`): `kubectl rollout` / `helm rollback` / `docker compose` re-pin / serverless `rollback` / `vercel rollback` / `netlify` API / bare-metal release symlink. If none detected → halt, ask.
2. **Resolve the rollback target** — the previous successful revision from the platform's deploy history (`kubectl rollout history`, `helm history`, Vercel deployments list, etc.), or the explicit `--to=<version>`. Confirm the target is a *known-good* (previously-healthy) revision; refuse to roll back to another red one.
3. **Pre-flight (read-confirm-execute)** — show: current (bad) revision → target (good) revision, the exact command, blast radius (which env/namespace/service). For prod or `--to` skipping intermediate revisions, require explicit confirmation. `--dry-run` stops here.
4. **Execute the revert** via the native mechanism (reversible operation only — never a destructive re-deploy).
5. **Monitor health** until green — dispatch the `monitor-deploy` skill on the rolled-back revision (health/readiness probe, error rate, latency vs baseline) plus the `smoke-verify` skill (boot-check) where applicable. Watch for the agreed observation window; declare recovery only on observed GREEN.
6. **Data reconciliation** — if the bad deploy ran a forward DB migration, surface whether a down-migration / reconciliation is needed (do NOT auto-run destructive down-migrations; name the step).
7. **Write the runbook entry** — append to `ai/runbooks/` (or the project's incident log): what failed, target rolled back to, health-recovery evidence, follow-ups.

## Halts (refuse, don't guess)

- No deploy mechanism detected → ask which platform.
- Rollback target is itself a red/unknown revision → refuse; require explicit `--to`.
- The deploy is not reversible by a native operation (e.g., schema change with no down path) → surface the manual reconciliation steps; do not fake a rollback.

## Output (brief)

- Mechanism · from-revision → to-revision · health-recovery status · data-reconciliation note (if any) · runbook entry path.

## See also

- `/deploy-stage` — the forward deploy this reverses.
- `devops/skills/monitor-deploy.md` — the health-watch used to confirm the rolled-back revision recovered to GREEN.
- `code-quality/skills/smoke-verify.md` — the boot-check used to confirm recovery.
- `ai/runbooks/` — where the rollback evidence lands.
