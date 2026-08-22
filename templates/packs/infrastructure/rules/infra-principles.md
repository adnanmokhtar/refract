---
name: infra-principles
description: Infrastructure Principles
kind: rule
pack: infrastructure
severity: must
applies-to: infrastructure-track, every-code-writing-task-in-infrastructure
---

# Infrastructure Principles

> **Hard rule.** Production container images MUST be pinned to an immutable digest or git-SHA tag (`:latest` is forbidden); MUST run as non-root; MUST declare healthchecks + resource `requests` + `limits`. Secrets MUST come from a manager (not git, not env files in images), and every stateful workload MUST have a tested backup + restore runbook.

## Must

- Match complexity to need. A VM + a process supervisor + a reverse proxy is valid infrastructure for many products. K8s is justified by real pain (multi-team, multi-env, > 5 services), not resume gravity.
- Multi-stage build: the runtime stage carries the artifact and its runtime deps — no compiler, no package manager, no source tree.
- Non-root container user; read-only root filesystem where the app allows it.
- Images pinned to an immutable reference in prod — `@sha256:…` or a git-SHA tag, never a moving tag.
- Healthcheck at every layer: image healthcheck, orchestrator liveness + readiness (+ startup for slow boots), load-balancer health. No readiness probe means traffic hits a dead pod mid-deploy.
- Resource `requests` + `limits` on every container. No `requests` — the scheduler over-packs the node; no `limits` — one container starves its neighbours.
- TLS everywhere, service-to-service included, auto-renewed.
- Secrets from a manager, mounted as files rather than env vars — env is readable from `/proc/<pid>/environ`, crash dumps, and every child process.
- Persistent data on a managed store or object storage, never on container-local disk.
- Every stateful production store: automated backups + point-in-time recovery + a restore drilled on a fixed cadence + a declared RPO/RTO. Backup config with no fresh drill is BLOCK, never ready — `dr-audit` verifies the coverage.
- Every ingress path intentional and least-exposed: no `0.0.0.0/0` (or `::/0`) on non-public ports, datastores in private subnets, default-deny `NetworkPolicy` per namespace — `network-exposure-audit` sweeps the running and declared footprint.
- Resolve versions from the vendor, not from memory. Supported orchestrator minors, provider majors, runtime LTS windows and controller support status all move on a published schedule; a version recalled rather than looked up is how a manifest ships a removed API or an unpatched base.

## Must not

- Commit secrets to git, even base64-encoded. Scanners find them; so do attackers.
- Apply IaC or cluster changes from a developer laptop against prod. Use CI, with an audit trail.
- Grant wildcard cluster roles (`*` verbs / `*` resources) to a service account.
- Leave a single point of failure on a revenue-critical path. Multi-AZ at minimum; multi-region only if the SLO demands it.
- Run a horizontal autoscaler without `min` + `max`. Unbounded up is bill shock; unbounded down is a cold start at peak.

## Should

- All infrastructure defined as code, reviewed in PRs like app code, linted in CI, with the provider lock file committed so a plan is reproducible.
- Drift detection: a scheduled `plan` alerts on any diff vs main.
- Image vulnerability scan in CI blocking on critical CVEs — and the signature it produces verified at admission, not merely generated (`release-security` signs, `admission-policy` enforces).
- PodDisruptionBudget on critical services so cluster maintenance MUST NOT take all replicas at once.
- Cost guardrails: per-environment budget alerts, non-prod auto-shutdown overnight, object-storage lifecycle to a cheaper tier then expiry.

Enforcement tooling is named in `STACK.md § Enforcement tooling`, not here — tools churn (two of the four manifest validators this rule used to name are unmaintained or dead); these rules do not.
