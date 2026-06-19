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

Prevents the four classic incidents: bad migration locks the DB, secret leaked to git, deploy rollback impossible, alert fires with no runbook.

## Must

- Deploys are zero-downtime: rolling update + readiness probes, or blue-green. A "maintenance window" is a process bug.
- Migrations are backward-compatible — old code reads new schema, new code reads old schema. Use expand-contract over two deploys for breaking changes (add column → backfill → switch reads → drop old column).
- Rollback is one command, tested at least once per release: redeploy previous immutable image tag (git SHA), no rebuild required.
- Every PR runs lint + typecheck + unit tests + build. Required checks enforced by branch protection (GitHub: Settings → Branches → require status checks).
- Secrets in a manager (AWS Secrets Manager / HashiCorp Vault / Doppler / 1Password / cloud-native KMS) — never in env files committed to git, never in container images.
- Container images pinned to immutable digest (`@sha256:...`) or git SHA tag in prod. `:latest` in prod is forbidden.
- Structured logs (JSON) with correlation/trace ID on every line. Aggregate to a single sink (Datadog / Grafana Loki / CloudWatch Logs).
- Alerts have: a clear symptom, a runbook link, and an owner. Alerts without runbooks become noise within a quarter.

## Must not

- Hand-edit production servers. SSH-in-and-patch breaks reproducibility, audits, and rollback.
- Echo secrets in CI logs. Use `::add-mask::` (GitHub Actions), `secret:` markers, or job-level env scoping.
- Skip CI on main / master. `[skip ci]` on a hotfix is how outages double in length.
- Run migrations during peak traffic on large tables — long ACCESS EXCLUSIVE locks freeze the app.
- Include build tools in the runtime image. Multi-stage Docker; final stage = distroless / alpine + binary + ca-certificates only.
- Run as root in containers. `USER node` / `USER 1001` in Dockerfile.
- Ship without a healthcheck endpoint (`/healthz` for liveness, `/readyz` for readiness).

## Should

- Manage all infrastructure as code: Terraform / Pulumi / CDK / OpenTofu, reviewed in PRs like application code, with `tflint` + `tfsec` / `checkov`.
- Drift detection: `terraform plan` on a schedule; non-empty plan against main MUST page on-call.
- Dependency updates automated via Renovate / Dependabot, grouped by ecosystem, auto-merged for patch versions when tests pass.
- SBOM (`syft`) + image vuln scan (`trivy` / `grype`) in CI — block on critical CVEs.
- Rotate long-lived secrets quarterly even without compromise; rotate immediately on any suspected exposure.
- Feature flags for risky changes (LaunchDarkly / Unleash / Flipt / OpenFeature) — decouple deploy from release.

## Review checklist

- [ ] Migration is reversible OR has a documented forward-fix.
- [ ] Migration plan reviewed for lock impact (`pg_locks`, `SHOW ENGINE INNODB STATUS`).
- [ ] No secrets in the diff (`git diff | gitleaks detect --pipe`).
- [ ] Healthchecks declared.
- [ ] Container runs as non-root.
- [ ] Image built from pinned base.
- [ ] CI green on lint, type, test, build, scan.

## Enforcement

- `gitleaks` / `trufflehog` pre-commit hook + CI scan blocks secret commits.
- Branch protection: required checks, no force-push to main, signed commits if compliance demands.
- `hadolint` lints Dockerfile. `dive` checks image bloat.
- `actionlint` / `nektos/act` validates GitHub Actions locally.
- Runbook link required in alert definition (e.g. PromQL annotations include `runbook_url`).
