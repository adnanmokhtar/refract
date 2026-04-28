# Infrastructure Principles

Prevents the patterns that turn cloud bills + outage minutes into avoidable losses: untagged images, secrets in git, unbounded autoscale, missing probes, unrestored backups.

## Must

- Match complexity to need. A single VM + systemd / Caddy / nginx is valid infrastructure for many products. K8s adoption is justified by real pain (multi-team, multi-env, > 5 services), not resume gravity.
- Multi-stage Dockerfile in every service. Final stage = distroless / alpine / scratch + binary + ca-certificates. No build tools in the runtime image.
- Run as non-root in containers (`USER 1001` / `USER node`). Read-only root filesystem where possible.
- Container images pinned to immutable tag in production: `image:@sha256:...` or `image:GIT_SHA`. `:latest` is forbidden in any prod manifest.
- Healthcheck declared at every layer: Dockerfile `HEALTHCHECK`, Kubernetes `livenessProbe` + `readinessProbe` + `startupProbe`, load balancer health.
- Resource `requests` + `limits` on every container. Without `requests`, scheduler over-packs nodes; without `limits`, one container OOM-kills the host.
- TLS everywhere, including service-to-service. Auto-renewed certs (Let's Encrypt via cert-manager / ACME, AWS ACM, GCP Managed Certs).
- Secrets from a manager (AWS Secrets Manager, Vault, External Secrets Operator, Doppler, GCP Secret Manager). Mounted as files preferred over env vars (env is leaked by every `/proc/<pid>/environ` and ps tool).
- Persistent data on managed DB or object storage. Never on container-local disk — pods die, disks die.
- Backups automated AND restore tested at least quarterly. An untested backup is a folder of bytes.

## Must not

- Push to `:latest` and rely on it. Forces rollback into "rebuild and pray".
- Commit secrets to git, even base64-encoded — `gitleaks` / `trufflehog` finds them; so do attackers.
- Run as root in containers. Container escape + root = host compromise.
- `kubectl apply` / `terraform apply` from a developer laptop against prod. Use CI with audit trail.
- Skip readiness probes ("the app takes 30s to come up"). Without readiness, traffic hits a dead pod during deploy.
- Wildcard cluster roles (`*` verbs / `*` resources) on service accounts. Least privilege per workload.
- Single point of failure on revenue-critical paths. Multi-AZ at minimum; multi-region if your SLO demands it.
- Horizontal autoscaler without `min` + `max`. Unbounded scale-up = bill shock; unbounded scale-down = cold-start at peak.
- Stateful workloads (DB, message broker) without a tested backup + restore runbook.

## Should

- Infrastructure as code: Terraform / OpenTofu / Pulumi / CDK / Crossplane. Reviewed in PRs like app code, with `tflint` + `tfsec` / `checkov` / `terrascan`.
- Image vulnerability scan in CI (`trivy`, `grype`, `snyk container`). Block on critical CVEs.
- Network policies default-deny + explicit allows in K8s (`NetworkPolicy` or service mesh authz).
- PodDisruptionBudget on critical services so cluster maintenance can't take all replicas at once.
- Drift detection: scheduled `terraform plan` (or Atlantis / Spacelift / Terragrunt) alerts on diff vs main.
- Cost guardrails: per-environment budget alerts, non-prod auto-shutdown overnight where feasible.
- Object storage lifecycle: transition to cheap tier after 30/90 days, expire per retention policy.

## Review checklist

- [ ] No `:latest` in any prod manifest.
- [ ] No secret in plaintext anywhere in the diff.
- [ ] Image scan green (no critical CVEs unless waived).
- [ ] Healthchecks + probes declared.
- [ ] Resource requests + limits set.
- [ ] Container runs as non-root.
- [ ] Network policy / SG / firewall rule restricts to least access.
- [ ] Backup + restore documented for any new stateful service.

## Enforcement

- `hadolint` lints Dockerfiles; `dive` checks layer bloat.
- `trivy` / `grype` scans images in CI; blocks on critical CVEs.
- `kube-linter`, `kubeval`, `polaris`, or `datree` validates K8s manifests.
- `tfsec` / `checkov` / `terrascan` lints IaC for misconfigurations.
- `gitleaks` / `trufflehog` blocks secrets in commits.
- OpenTofu / Terraform Cloud / Atlantis enforces "plan reviewed → apply".
