---
name: devops-principles
description: DevOps Principles
kind: rule
pack: devops
severity: must
applies-to: devops-track, every-code-writing-task-in-devops
---

# DevOps Principles

> **Hard rule.** Deploys MUST be zero-downtime, rollback MUST be one command (redeploy a previous immutable image — no rebuild), and migrations MUST be backward-compatible. Secrets in git, `:latest` tags in prod, hand-edits to production servers, and alerts without runbooks are forbidden.

## Must

- Zero-downtime deploys: rolling update + readiness probes, or blue-green. A "maintenance window" is a process bug.
- Migrations are backward-compatible — old and new code run against one schema mid-rollout. Additive changes migrate before the code; destructive ones only after the code that stopped reading them has rolled out. A breaking change is expand → backfill → deploy → contract, contract in a LATER release.
- Rollback is one command, tested once per release: redeploy the previous immutable tag, no rebuild. Reverting code reverts nothing else — schema, cache, queues and flags stay. Check the migration direction BEFORE reverting.
- Every PR runs lint + typecheck + test + build, enforced as required checks by branch protection.
- Secrets resolve at runtime from a secret manager — never in committed env files, never in images.
- Images pinned to an immutable digest or git SHA in prod. `:latest` is forbidden; a pinned but END-OF-LIFE base is the same defect wearing a pin.
- Structured logs (JSON) with a correlation/trace ID on every line, to one sink.
- Alerts carry a symptom, a runbook link, and an owner. Alerts without runbooks become noise within a quarter.

## Must not

- Hand-edit production servers — it breaks reproducibility, audit, and rollback.
- Echo secrets in CI logs. Masking is per-provider and misses env vars derived from a secret; scope each secret to the job that needs it.
- Interpolate untrusted CI context (PR title, branch name, issue body) into a shell script — it is substituted before the shell runs. Bind it to an env var and reference the variable.
- Skip CI on main. `[skip ci]` on a hotfix is how outages double in length.
- Migrate large tables at peak — long exclusive locks freeze the app.
- Ship build tools in the runtime image.
- Run as root — judged on the FINAL stage; a `USER` in the builder is discarded with it.
- Ship without distinct liveness and readiness signals, or let liveness depend on a downstream (a dependency blip then becomes a restart loop).

## Should

- Infrastructure is code: PR-reviewed, linted in CI, drift-detected on a schedule — a non-empty plan against main pages on-call.
- Rotate long-lived secrets quarterly; immediately on suspected exposure.
- Risky changes ship behind a flag with a kill-switch, an automated canary gate and a removal date — `progressive-delivery` audits it.
- Cluster state is git-reconciled: drift detection, no out-of-band apply, no plaintext secrets in git — `gitops-audit` audits it.
- Release artifacts scanned, SBOM'd and signed before promotion — `release-security` runs it.

Deploy-PR checklist → `ai/patterns/deployment.md § Review checklist`. Pipeline tooling (linters, scanners, secret hooks, dependency-update policy, branch protection) → `ai/patterns/cicd-pipeline.md § Enforcement`.
