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
9. Least-privilege (in-cluster IAM) halt — the k8s equivalent of "no wildcard IAM": any workload binding the namespace `default` ServiceAccount; any bound Role/ClusterRole granting a wildcard verb or resource (`verbs: ["*"]`, `resources: ["*"]`, `apiGroups: ["*"]`) or a `cluster-admin` binding; `automountServiceAccountToken` unset/`true` on a workload that never calls the K8s API; or any container with `privileged: true`, `hostNetwork: true`, `hostPID/hostIPC: true`, or a `hostPath` volume → halt. Least-privilege in k8s is a dedicated, minimally-scoped ServiceAccount + a namespaced Role, never `default` + never wildcard verbs.
10. Cost-bound halt: worst-case spend must be computable before write — an HPA without a bounded `maxReplicas`, or a Deployment where `maxReplicas × per-pod (cpu+memory requests)` cannot be stated, is unbounded cost → halt. Record the computed ceiling inline (`# worst-case: 10 pods × (500m cpu, 512Mi mem)`).
11. **API-version halt — resolve every `apiVersion` from the cluster, never from memory.** Run `kubectl api-resources` (and `kubectl explain <kind>.<field>` where a field's graduation is uncertain) against the TARGET cluster and use what it reports. Kubernetes serves only the three most recent minors (https://kubernetes.io/releases/) and removes group versions on a published schedule (https://kubernetes.io/docs/reference/using-api/deprecation-guide/) — `policy/v1beta1` PodDisruptionBudget has not been served since v1.25, `autoscaling/v2beta2` HorizontalPodAutoscaler since v1.26. No cluster reachable → take the sibling manifests' values as the oracle and say so; neither cluster nor sibling → halt and ask which minor to target. A free-generated `apiVersion` passes review and fails at apply.
12. **Edge-API halt.** No `Ingress` without confirming an ingress controller exists (`kubectl get ingressclass`); no Gateway API objects without confirming the CRDs are installed (`kubectl api-resources --api-group=gateway.networking.k8s.io`) — Gateway API is an add-on, not built in (https://kubernetes.io/docs/concepts/services-networking/gateway/). Mirror whichever the siblings use, and copy controller-specific annotations from the sibling rather than inventing them: an annotation the installed controller does not implement is ignored silently.

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

- Sub-tasks: Deployment, Service, edge object (if public), HPA, PDB, NetworkPolicy, ServiceAccount + RBAC, ConfigMap, ExternalSecret.
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
- **Edge object** — whichever API the cluster serves (halt #12): an `Ingress` with `ingressClassName` + TLS, or a Gateway API `HTTPRoute` attaching to the platform's `Gateway`. Annotations and route fields copied from the closest sibling, never invented.
- **HorizontalPodAutoscaler** — min/max bounded. **CPU, or a custom/external metric tracking the real bottleneck (queue depth, in-flight requests, RPS). Do NOT emit a memory target as a scaling signal** — memory usually grows and holds, so it scales up and never back down, and `k8s-reviewer` grades memory-only HPA metrics as a Medium finding; this command must not generate what its own Phase-6 gate flags. A genuinely memory-bound workload says so inline with its evidence.
- **PodDisruptionBudget** — `minAvailable: <replicas - 1>` for `replicas >= 3`; two replicas → `minAvailable: 1`. Never emit a PDB for a 1-replica Deployment: `minAvailable: 1` blocks every voluntary drain forever and `minAvailable: 0` protects nothing. Skip it, or raise replicas to at least two.
- **NetworkPolicy** — default-deny ingress + egress; explicit allows (DNS, observability, dependencies).
- **ServiceAccount + RBAC** — a dedicated ServiceAccount (never `default`); `automountServiceAccountToken: false` unless the workload calls the K8s API; if it does, a namespaced `Role` + `RoleBinding` scoped to the exact verbs/resources needed. Reference it from `spec.template.spec.serviceAccountName`.
- **ConfigMap** for non-secret env. Secret references via External Secrets Operator / Sealed Secrets — never inline base64.

If repo uses Helm, scaffold under `charts/<service>/` with `Chart.yaml`, `values.yaml` + per-env overlays, `templates/` mirroring the manifest list, `README.md` documenting every value.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/deployment.md` — append rollout/rollback for this service.
- `ai/architecture.md` — append the new service node + dependencies.

## Phase 6 — Validate + production-grade gate

`kubectl apply` succeeding is the FLOOR, not the bar. This command declares **PRODUCTION-GRADE** only when the scorecard below is fully MET; otherwise it reports **INCOMPLETE** with the unmet controls named. It never reports "done" on a merely-functional manifest.

### 6a — Static gates (agent-run, before any done-declaration)

- `kubeconform` — `0 errors` required, run with `-kubernetes-version <target minor>` so the schema matches the cluster. (`kubeval` is unmaintained; its own README points at `kubeconform`: https://github.com/instrumenta/kubeval.) No tool available → mark **UNVERIFIED**, never a faked pass.
- API-version resolution recorded: the `kubectl api-resources` line (or the sibling manifest) each generated `apiVersion` came from. "Resolved from memory" is not a pass.
- Dispatch `k8s-reviewer` on the RENDERED manifests (`helm template` / `kustomize build` output, not values files). Record its **PRODUCTION-GRADE verdict verbatim**. **Any Blocker finding → NOT-PRODUCTION-GRADE → this command halts the done-declaration** and reports INCOMPLETE with the Blocker's `<file:JSONPath>` named. The reviewer verdict IS the enforcement mechanism for the judgment controls no grep can prove.
- Apply to a dev cluster + `kubectl rollout status` succeeds. No cluster reachable → mark that line **UNVERIFIED (no cluster)**, never claim it passed.

### 6b — Production-readiness scorecard (REQUIRED OUTPUT ARTIFACT)

Each control is **MET** with the citing `<file:JSONPath>`, or **UNMET** (named). Grep-verifiable controls are `[mechanical]`; judgment controls are `[self-policed by k8s-reviewer]` — labelled honestly because no shell catches them.

| # | Production control | How proven |
|---|---|---|
| 1 | Least-privilege in-cluster IAM: dedicated ServiceAccount (not `default`), no wildcard RBAC, no `cluster-admin`, `automountServiceAccountToken: false` unless API-calling, no `privileged`/`hostNetwork`/`hostPath` | cite `serviceAccountName`, the `Role.rules`, the `securityContext` fields |
| 2 | Resource requests AND limits on every container; no privileged containers | cite `resources.requests`/`resources.limits` per container |
| 3 | Secrets via a manager, never inline base64 | cite the `ExternalSecret`/`SealedSecret`; assert no committed `kind: Secret` with `data:` |
| 4 | NetworkPolicy default-deny ingress+egress with explicit minimal allows incl. DNS | cite the default-deny policy + each allow rule |
| 5 | Reproducible + cost-aware: digest/semver-pinned image, every `apiVersion` resolved and still served, HPA `maxReplicas` bounded, worst-case spend stated | cite the pinned `image:`, the api-resources line per kind, `hpa.spec.maxReplicas`, the ceiling |

**Verdict rule (halting):** report **PRODUCTION-GRADE** only when all 5 controls are MET **and** kubeconform = PASS **and** the k8s-reviewer verdict is PRODUCTION-GRADE (0 Blockers). Otherwise report **INCOMPLETE — unmet: &lt;controls&gt;** and do not declare done.

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

Static gates:
  kubeconform         PASS, 0 errors (schema pinned to the target minor)
  apiVersions         resolved from `kubectl api-resources` on <cluster>
  k8s-reviewer        PRODUCTION-GRADE (0 blocker / 0 high)
  dev rollout status  UNVERIFIED (no cluster reachable)

Production-readiness scorecard:
  1 least-privilege IAM   MET  (serviceAccountName: orders-api-sa; Role scoped to configmaps:get)
  2 requests+limits       MET  (containers[0].resources.{requests,limits} cpu+mem)
  3 secrets via manager   MET  (external-secret.yaml; no committed kind: Secret data:)
  4 network policy scoped MET  (default-deny + 3 explicit allows incl. dns)
  5 reproducible + cost   MET  (image @sha256:…; apiVersions resolved; maxReplicas bounded)

VERDICT: PRODUCTION-GRADE

# On any gap:
#   1 least-privilege IAM   UNMET (deployment.yaml:...serviceAccountName absent → binds `default`)
# VERDICT: INCOMPLETE — unmet: least-privilege IAM. Not declared done.
```

## Failure modes

- **An `apiVersion` recalled instead of resolved** — the manifest lints clean, passes review, and fails at `kubectl apply` on the one cluster that matters.
- Declaring "done" on `kubeconform PASS` + `kubectl apply` alone — that is the functional floor; PRODUCTION-GRADE requires the Phase 6b scorecard fully MET, else INCOMPLETE with the unmet controls named.
- Image tag = `:latest` — non-reproducible deploys, broken rollbacks; use digest or semver.
- Requests-only or limits-only — oversubscription or runaway resource use.
- Confused liveness vs readiness — silent dead pods OR cascading restarts during slow startup.
- NetworkPolicy default-deny without DNS allow — pods can't resolve anything.
- HPA without resource requests — never scales (computes percent-of-request).
- PDB `minAvailable >= replicas` — node drains hang forever. Single-replica PDB is the same trap inverted: `minAvailable: 1` on 1 replica blocks every drain; `minAvailable: 0` is a no-op.
- Secrets in ConfigMap `data:` committed to git — leak; use ESO / Sealed Secrets / Vault.
- Read-only root FS breaks apps writing logs/temp — mount `emptyDir` for those paths instead of disabling RO.
