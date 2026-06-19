---
description: Generate production-ready k8s manifests (Deployment, Service, Ingress, HPA, PDB, NetworkPolicy).
---

# /k8s-generate <service>

Default-secure manifests for one service: probes, resources, non-root, default-deny network, autoscaling.

## The Premise (read this first, internalize, do not deviate)

**Existing manifests are the truth. Mirror sibling deployment shape: labels, resource limits, security context, probes.** If `k8s/<other-service>/deployment.yaml` already exists in this repo, it IS the convention — labels schema, label values, probe shape, resource-request style, security-context block, topology-spread keys, annotation set. Do NOT invent a fresh shape from k8s docs; do NOT copy a generic template; do NOT mix idioms across siblings.

**The closure verb is `mirror-sibling-shape`.** Before generating, the agent MUST:
1. List `k8s/*/deployment.yaml` (or `charts/*/templates/deployment.yaml`) and pick the closest sibling by service kind (HTTP API → another HTTP API; worker → another worker; cron → another cron).
2. Read that sibling end-to-end and record its: label keys, label-value conventions (e.g. `app.kubernetes.io/name`, `app.kubernetes.io/part-of`), probe paths + thresholds, resource request/limit ratios, security-context fields, topology-spread keys, image-pull-policy, annotation set, NetworkPolicy egress allow-list shape.
3. Generate the new service's manifests with the SAME shape; deviations are allowed ONLY when justified by service kind (e.g. worker has no Service / Ingress) and recorded inline as `# diverges from <sibling>: <reason>`.

**Mechanical halt — sibling-resource-shape parity (mandatory before write):**
1. Untagged-resources halt: every generated resource MUST carry the sibling's full label set. Missing any key from sibling → halt.
2. Missing-labels halt: any object without `metadata.labels` populated → halt.
3. Missing-probes halt: any container in Deployment / StatefulSet without BOTH `livenessProbe` AND `readinessProbe` (and `startupProbe` if sibling has one) → halt.
4. Missing-limits halt: any container without BOTH `resources.requests` AND `resources.limits` for cpu+memory → halt.
5. Missing-securityContext halt: any container without `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop` matching sibling → halt.
6. PDB-replica-coherence halt: `pdb.minAvailable >= deployment.replicas` → halt. Also halt on a degenerate single-replica PDB: a PDB emitted for `replicas == 1`, or any `pdb.minAvailable == 0` → halt (skip the PDB or raise replicas to ≥ 2).
7. Image-tag halt: `:latest` or unpinned digest → halt.
8. NetworkPolicy halt: default-deny without explicit DNS egress allow → halt.

If no sibling exists in the repo, halt and ask the user to point at a gold-standard manifest set OR confirm this service is the new gold standard (then the manifest is reviewed by `infra-architect` before write).

**The agent does NOT:**
- Generate from a generic Kubernetes-docs template when a sibling exists.
- Mix label conventions (`app: foo` in one file, `app.kubernetes.io/name: foo` in another).
- Skip a probe / limit / security-context field because "the app doesn't need it" — siblings set the floor.

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
- **PodDisruptionBudget** — `minAvailable: <replicas - 1>` for `replicas >= 3`. Single-replica (`replicas == 1`): a PDB is degenerate — `minAvailable: 0` protects nothing and `minAvailable: 1` blocks every voluntary drain forever. Either **skip the PDB** (single-replica service tolerates disruption — note it inline) OR, if the service must stay available, **require `replicas >= 2`** and emit the PDB against that. Two replicas → `minAvailable: 1`. Never emit a PDB for a 1-replica Deployment.
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
- Verify: requests AND limits both set; PDB present only for `replicas >= 2` with `0 < minAvailable < replicas` (no PDB for single-replica); NetworkPolicy egress includes DNS; no `:latest` image tag.
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
- PDB `minAvailable >= replicas` — node drains hang forever. Single-replica PDB is the same trap inverted: `minAvailable: 1` on 1 replica blocks every drain; `minAvailable: 0` is a no-op. Skip the PDB or run ≥ 2 replicas.
- Secrets in ConfigMap `data:` committed to git — leak; use ESO / Sealed Secrets / Vault.
- Read-only root FS breaks apps writing logs/temp — mount `emptyDir` for those paths instead of disabling RO.

## Related

### Patterns
- `ai/patterns/zero-downtime-deploys.md`

### Rules
- `.claude/rules/infra-principles.md`
