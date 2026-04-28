---
description: Generate production-ready k8s manifests (Deployment, Service, Ingress, HPA, PDB, NetworkPolicy).
---

# /k8s-generate <service>

Default-secure manifests for one service: probes, resources, non-root, default-deny network, autoscaling.

## Phases applied

All 7. Phase 6 includes manifest linting.

## When to use / NOT to use
- USE: net-new service deploying to k8s; migrating from ad-hoc `kubectl apply` to a clean baseline.
- NOT: serverless deploys (Lambda / Cloud Run / Fly Machines without k8s).

## Phase 1 — Understand

- Collect: service name, container image (registry + repo), ports, env vars, replica baseline + min/max, CPU/memory request + limit, public-facing? (Y → Ingress), public domain.
- Consolidated question if any missing.
- Success: manifests pass `kubeconform`, run as non-root with read-only root FS, default-deny NetworkPolicy with explicit allows, HPA bounded, PDB consistent with replicas.

## Phase 2 — Organize

- Sub-tasks: Deployment, Service, Ingress (if public), HPA, PDB, NetworkPolicy, ConfigMap, ExternalSecret.
- Decide Helm vs raw manifests — Helm if `charts/` exists in repo.
- Pause for confirmation on probe shape (liveness vs readiness vs startup).

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` + `.claude/codebase-profile.md` — k8s conventions, secrets manager, ingress controller.
- `ai/runbooks/deployment.md` — deployment procedure.
- `ai/architecture.md` — dependencies for NetworkPolicy egress allows.

CONTEXT:
- Existing manifests under `k8s/<service>/` if present — mirror conventions.
- Cluster's cert-manager / ingress class / external-secrets configuration.

## Phase 4 — Generate

Dispatch `infra-architect` to confirm probes + base image hardening.

Generate under `k8s/<service>/`:
- **Deployment** — `revisionHistoryLimit: 5`, `RollingUpdate` with `maxSurge: 25%` / `maxUnavailable: 0`, probes, resources, `securityContext` (`runAsNonRoot: true`, `readOnlyRootFilesystem: true`, capabilities dropped, `allowPrivilegeEscalation: false`), `topologySpreadConstraints` for AZ spread.
- **Service** — `ClusterIP`, named port matching Deployment.
- **Ingress** — TLS via cert-manager / equivalent; sane annotations (rate-limit, body size).
- **HorizontalPodAutoscaler** — CPU + memory target; min/max bounded.
- **PodDisruptionBudget** — `minAvailable: <replicas - 1>` for replicas > 1.
- **NetworkPolicy** — default-deny ingress + egress; explicit allows (DNS, observability, dependencies).
- **ConfigMap** for non-secret env. Secret references via External Secrets Operator / Sealed Secrets — never inline base64.

If repo uses Helm, scaffold under `charts/<service>/` with `Chart.yaml`, `values.yaml` + per-env overlays, `templates/` mirroring the manifest list, `README.md` documenting every value.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/deployment.md` — append rollout/rollback for this service.
- `ai/architecture.md` — append the new service node + dependencies.

## Phase 6 — Validate

- `kubeconform` (or `kubeval`) — `0 errors` required.
- Dispatch `k8s-reviewer` on the manifests against project conventions.
- Verify: requests AND limits both set; PDB `minAvailable` < `replicas`; NetworkPolicy egress includes DNS; no `:latest` image tag.
- Apply to dev cluster + verify `kubectl rollout status` succeeds before declaring done.

## Phase 7 — Improve

- If a NetworkPolicy allow recurs across services (e.g. shared observability namespace), queue pattern to `ai/dynamic/learned-patterns.md`.
- If probe shape varies per service unintentionally, queue convention update.

## Output

```
Generated under k8s/orders-api/:
  deployment.yaml  (3 replicas, HPA 2-10, PDB minAvailable 2)
  service.yaml
  ingress.yaml     (TLS via cert-manager-issuer-letsencrypt-prod)
  hpa.yaml
  pdb.yaml
  networkpolicy.yaml  (default-deny + 3 allows: dns, postgres, prometheus)
  configmap.yaml
  external-secret.yaml

Linter: kubeconform PASS, 0 errors.
```

## Failure modes

- Image tag = `:latest` — non-reproducible deploys, broken rollbacks; use digest or semver.
- Requests-only or limits-only — oversubscription or runaway resource use.
- Confused liveness vs readiness — silent dead pods OR cascading restarts during slow startup.
- NetworkPolicy default-deny without DNS allow — pods can't resolve anything.
- HPA without resource requests — never scales (computes percent-of-request).
- PDB `minAvailable >= replicas` — node drains hang forever.
- Secrets in ConfigMap `data:` committed to git — leak; use ESO / Sealed Secrets / Vault.
- Read-only root FS breaks apps writing logs/temp — mount `emptyDir` for those paths instead of disabling RO.
