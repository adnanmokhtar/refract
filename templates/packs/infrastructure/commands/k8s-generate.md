---
description: Generate production-ready k8s manifests (Deployment, Service, Ingress, HPA, PDB, NetworkPolicy).
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /k8s-generate <service>

Default-secure manifests for one service: probes, resources, non-root, default-deny network, autoscaling.

## The Premise (read this first, internalize, do not deviate)

**Existing manifests are the truth. Mirror sibling deployment shape: labels, resource requests and memory limits, security context, probes.** If `k8s/<other-service>/deployment.yaml` already exists in this repo, it IS the convention — labels schema, label values, probe shape, resource-request style, security-context block, topology-spread keys, annotation set. Do NOT invent a fresh shape from k8s docs; do NOT copy a generic template; do NOT mix idioms across siblings.

**The closure verb is `mirror-sibling-shape`.** Before generating, the agent MUST:
1. List `k8s/*/deployment.yaml` (or `charts/*/templates/deployment.yaml`) and pick the closest sibling by service kind (HTTP API → another HTTP API; worker → another worker; cron → another cron).
2. Read that sibling end-to-end and record its: label keys, label-value conventions (e.g. `app.kubernetes.io/name`, `app.kubernetes.io/part-of`), probe paths + thresholds, resource request and memory-limit ratios, security-context fields, topology-spread keys, image-pull-policy, annotation set, NetworkPolicy egress allow-list shape.
3. Generate the new service's manifests with the SAME shape; deviations are allowed ONLY when justified by service kind (e.g. worker has no Service / Ingress) and recorded inline as `# diverges from <sibling>: <reason>`.

**Mechanical halt — sibling-resource-shape parity (mandatory before write):**
1. Untagged-resources halt: every generated resource MUST carry the sibling's full label set. Missing any key from sibling → halt.
2. Missing-labels halt: any object without `metadata.labels` populated → halt.
3. Missing-probes halt: any container in Deployment / StatefulSet without BOTH `livenessProbe` AND `readinessProbe` (and `startupProbe` if sibling has one) → halt.
4. Missing-resources halt: any container (init and sidecar containers included) without a CPU request, a memory request AND a memory limit → halt. Keep the memory limit equal to the request unless a measured profile says otherwise. A CPU **limit** is not required and is not added by default: it throttles a request-serving process while the node idles (precedents/infrastructure.md § 1). Copy one only where the sibling sets it for a stated reason (a noisy batch neighbour, CPU-manager pinning with limit = request).
5. Missing-securityContext halt: any container without `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop` matching sibling → halt.
6. PDB-replica-coherence halt (`THR-K8S-PROD-FLOOR`): the floor is the HPA `minReplicas` or KEDA `minReplicaCount` when an autoscaler targets the workload, else `replicas` (precedents § 42). A PDB that is not `maxUnavailable: 1` or a `minAvailable` below that floor → halt. A PDB on a floor of 1, or `minAvailable: 0` → halt (skip the PDB or raise the floor to ≥ 2). A served prod workload with a floor below 2 → halt unless the user accepts the disruption in writing.
7. Image-tag halt: `:latest` or unpinned digest → halt.
8. NetworkPolicy halt: default-deny without explicit DNS egress allow → halt.
9. Least-privilege (in-cluster IAM) halt — the k8s equivalent of "no wildcard IAM": any workload binding the namespace `default` ServiceAccount; any bound Role/ClusterRole granting a wildcard verb or resource (`verbs: ["*"]`, `resources: ["*"]`, `apiGroups: ["*"]`) or a `cluster-admin` binding; `automountServiceAccountToken` unset/`true` on a workload that never calls the K8s API; or any container with `privileged: true`, `hostNetwork: true`, `hostPID/hostIPC: true`, or a `hostPath` volume → halt. Least-privilege in k8s is a dedicated, minimally-scoped ServiceAccount + a namespaced Role, never `default` + never wildcard verbs.
10. Cost-bound halt: worst-case spend must be computable before write — an HPA without a bounded `maxReplicas`, or a Deployment where `maxReplicas × per-pod (cpu+memory requests)` cannot be stated, is unbounded cost → halt. Record the computed ceiling inline (`# worst-case: 10 pods × (500m cpu, 512Mi mem)`).
11. **API-version halt — resolve every `apiVersion` from the target, never from memory.** Read the target minor from files first (runbook, IaC, CI `--kube-version`, Argo destination). A live read — `kubectl --context=<ctx> api-resources`, `kubectl --context=<ctx> explain <kind>.<field>` — names the context and runs only after the user confirms it in this session; never the default context. Otherwise validate offline at the target minor (`k8s-api-version-scan`, Phase 6a). Kubernetes serves only the three most recent minors (https://kubernetes.io/releases/) and removes group versions on a published schedule (https://kubernetes.io/docs/reference/using-api/deprecation-guide/) — `policy/v1beta1` PodDisruptionBudget has not been served since v1.25, `autoscaling/v2beta2` HorizontalPodAutoscaler since v1.26. With no confirmed context, take the sibling manifests' `apiVersion` values plus the offline check at the target minor as the oracle and say so; if there is neither a target minor nor a sibling → halt and ask which minor to target. A free-generated `apiVersion` is the single most damaging thing this command can write: it passes review and fails at apply.
12. **Edge-API halt.** Do not emit an `Ingress` without confirming the cluster has an ingress controller (`kubectl --context=<confirmed ctx> get ingressclass`, or the controller's install line in the repo's runbooks), and do not emit Gateway API objects without confirming the CRDs are installed (`kubectl --context=<confirmed ctx> api-resources --api-group=gateway.networking.k8s.io`, or the CRD install in the repo) — Gateway API is an add-on, not built in (https://kubernetes.io/docs/concepts/services-networking/gateway/). Mirror whichever the siblings use. Controller-specific annotations are copied from the sibling, never invented: an annotation the installed controller does not implement is ignored silently, so a generated "rate limit" that does nothing is worse than none.

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

- Collect: service name, container image (registry + repo), ports, env vars, replica baseline + min/max, CPU request, memory request + memory limit, public-facing? (Y → Ingress), public domain.
- Consolidated question if any missing.
- Success: manifests pass `kubeconform`, run as non-root with read-only root FS, default-deny NetworkPolicy with explicit allows, HPA bounded, PDB consistent with replicas.

## Phase 2 — Organize

- Sub-tasks: Deployment, Service, Ingress (if public), HPA, PDB, NetworkPolicy, ServiceAccount + RBAC, ConfigMap, ExternalSecret.
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
- **Deployment** — `revisionHistoryLimit: 5`, `RollingUpdate` with `maxSurge: 25%` / `maxUnavailable: 0`, probes, resources, `securityContext` (`runAsNonRoot: true`, `readOnlyRootFilesystem: true`, capabilities dropped, `allowPrivilegeEscalation: false`), `topologySpreadConstraints` on hostname, plus zone only where multi-zone node pools exist (precedents § 8).
- **Service** — `ClusterIP`, named port matching Deployment.
- **Edge object** — whichever API the cluster serves (halt #12): an `Ingress` with `ingressClassName` + TLS, or a Gateway API `HTTPRoute` attaching to the platform's `Gateway`. Annotations/route fields copied from the closest sibling, not invented.
- **HorizontalPodAutoscaler** (or KEDA `ScaledObject` when the siblings use KEDA) — min ≥ 2 for a served prod workload and a written max (`THR-K8S-PROD-FLOOR`, `THR-SCALE-CEILING`); omit `replicas` from the Deployment it targets (an SSA or GitOps sync would fight the autoscaler). **CPU (or a custom/external metric that tracks the real bottleneck — queue depth, in-flight requests, RPS). Do NOT emit a memory target as a scaling signal**: memory usually grows and holds, so it scales up and never back down, and `k8s-reviewer` §4 grades memory-only HPA metrics as a Medium finding — this command must not generate what its own Phase-6 gate flags. If the workload is genuinely memory-bound, say so inline (`# memory target: <workload> is memory-bound because <evidence>`) and expect the reviewer to check that claim.
- **PodDisruptionBudget** — `maxUnavailable: 1` against a floor ≥ 2 (the autoscaler minimum when one exists, else `replicas`; `THR-K8S-PROD-FLOOR`). Floor 1: a PDB is degenerate — `minAvailable: 0` protects nothing and `minAvailable: 1` blocks every voluntary drain forever. Either **skip the PDB** (the service tolerates disruption — note it inline) OR **raise the floor to ≥ 2** and emit the PDB against that. Never emit a PDB for a floor of 1.
- **NetworkPolicy** — default-deny ingress + egress; explicit allows (DNS, observability, dependencies).
- **ServiceAccount + RBAC** — a dedicated ServiceAccount (never `default`); `automountServiceAccountToken: false` unless the workload calls the K8s API; if it does, a namespaced `Role` + `RoleBinding` scoped to the exact verbs/resources needed (no wildcard, no `ClusterRoleBinding` to `cluster-admin`). Reference the SA from the Deployment's `spec.template.spec.serviceAccountName`.
- **ConfigMap** for non-secret env. Secret references via External Secrets Operator / Sealed Secrets — never inline base64.

If repo uses Helm, scaffold under `charts/<service>/` with `Chart.yaml`, `values.yaml` + per-env overlays, `templates/` mirroring the manifest list, `README.md` documenting every value.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/deployment.md` — append rollout/rollback for this service.
- `ai/architecture.md` — append the new service node + dependencies.

## Phase 6 — Validate + production-grade gate

`kubectl apply` succeeding is the FLOOR, not the bar. This command declares **PRODUCTION-GRADE** only when the scorecard below is fully MET; otherwise it reports **NOT-PRODUCTION-GRADE** with the unmet controls named — it never reports "done" on a merely-functional manifest. Same two-tier discipline as `provision-tier`'s 6a/6b split: agent-run static gates, then a required verdict.

### 6a — Static gates (agent-run, before any done-declaration)

The pack's detectors run on this command's own output, offline, exactly as `/infra-audit` would run them on the repo (`KUBECONFIG` an empty scratch file throughout; no cluster is contacted):

```bash
export KUBECONFIG="$SCAN/empty.kubeconfig"; : > "$KUBECONFIG"
bash .claude/skills/k8s-render-scan/scripts/render.sh . --out="$SCAN" --kube-version="$TARGET_MINOR"   # every env that will deploy the new manifests
bash .claude/skills/k8s-api-version-scan/scripts/apiversion.sh "$SCAN" --target="$TARGET_MINOR"         # served apiVersions + kubeconform -strict, canaries read
bash .claude/skills/k8s-availability-scan/scripts/availability.sh "$SCAN" --repo=.                      # resources, floor, PDB, probes, rollout, shutdown
bash .claude/skills/k8s-wiring-scan/scripts/wiring.sh "$SCAN" --repo=.                                  # Service/port refs, NetworkPolicy DNS + paths, RBAC wiring
```

- **Render + schema:** every env renders (`render-ledger.tsv` exit 0) and `k8s-api-version-scan` reports 0 rows for the new objects at the target minor, with objects read = objects rendered. No tool or no schema → **UNVERIFIED**, never a faked pass. (`kubeval` is unmaintained; its README points at `kubeconform`.)
- **API-version resolution recorded:** the target minor's source (file:line) or the sibling manifest each generated `apiVersion` came from. "Resolved from memory" is not a pass.
- **Detector rows:** `availability.sh` and `wiring.sh` print no row for the new objects, or each row is fixed or argued under the detector's precedents.
- **Dispatch `@k8s-reviewer`** on the render with those rows. Record its **PRODUCTION-GRADE verdict verbatim**. **Any BLOCKER → NOT-PRODUCTION-GRADE → this command halts the done-declaration** and reports INCOMPLETE with the row's `<file:line>` named.
- **K-tier proofs** (`apply --dry-run=server`, a rollout, a drain) run on a scratch kind cluster through an explicit `KUBECONFIG="$SCAN/kind.kubeconfig"`, never the user's cluster. A dev-cluster rollout is the user's step on a context they confirm in this session; without it the line is **UNVERIFIED (no confirmed cluster)**.

### 6b — Production-readiness scorecard (REQUIRED OUTPUT ARTIFACT)

The run MUST emit this scorecard; a reader checks it against the manifests. Each control is **MET** with the citing `<file:JSONPath>` field that proves it, or **UNMET** (named). Grep-verifiable controls are `[mechanical]`; judgment controls are `[self-policed by k8s-reviewer]` — labelled honestly because no shell catches them.

| # | Production control (= `@k8s-reviewer` § Production-grade verdict) | How proven | Enforced by |
|---|---|---|---|
| 1 | Identity and privilege: dedicated ServiceAccount (not `default`), no wildcard or `cluster-admin` RBAC, `automountServiceAccountToken: false` unless API-calling, no `privileged` / host namespaces / `hostPath` | cite `serviceAccountName`, the `Role.rules`, the `securityContext` fields | `[mechanical]` halt #9 + security `iac-scan` § 3 (breadth, when installed) + `k8s-wiring-scan` § 6 (the SA and bindings resolve) |
| 2 | Resources and floor: a CPU request, a memory request and a memory limit on every container (no CPU-limit requirement); floor ≥ 2 for a served prod workload, PDB `maxUnavailable: 1` or `minAvailable` below the floor, no PDB on one replica (`THR-K8S-PROD-FLOOR`); readiness on served containers; `THR-SHUTDOWN-GRACE` holds | cite `resources.requests.{cpu,memory}` + `resources.limits.memory` per container, the floor and its source, the PDB | `[mechanical]` halts #3/#4/#6 + `k8s-availability-scan` § 1–§ 4, § 7 |
| 3 | Secrets via a manager, never inline base64 | cite the `ExternalSecret`/`SealedSecret`; assert no `kind: Secret` with `data:` in git | `[mechanical]` grep for committed `kind: Secret` + security `secret-scan-method` (when installed) |
| 4 | NetworkPolicy: (a) default-deny ingress + egress with minimal explicit allows; (b) DNS egress on UDP **and** TCP 53 and every configured dependency reachable | cite the default-deny policy + each allow rule | (a) `[mechanical]` halt #8 + security `iac-scan` 4k · (b) `k8s-wiring-scan` § 3 |
| 5 | Reproducible and bounded: image digest/semver-pinned (no `:latest`); charts pinned; every `apiVersion` served at the target minor and schema-valid; every HPA/`ScaledObject` has a written max (`THR-SCALE-CEILING`) and worst-case spend stated (`max × per-pod requests`) | cite the pinned `image:`, the target minor's source, `maxReplicas`/`maxReplicaCount`, the computed ceiling | `[mechanical]` halts #7/#10/#11 + `k8s-api-version-scan` § 1–§ 2 + `k8s-availability-scan` § 4 |

A control whose owner pack is not installed prints `LISTED (<pack> pack not installed: k rows)` exactly as the reviewer prints it; with k = 0 it does not block, and the verdict line names the controls nobody graded.

**Verdict rule (halting):** report **PRODUCTION-GRADE** only when all 5 controls are MET (or LISTED with 0 rows) **and** the render + schema gate passed **and** the `@k8s-reviewer` verdict is PRODUCTION-GRADE (0 BLOCKER). Otherwise report **NOT-PRODUCTION-GRADE — unmet: <controls> · blockers: <n>** (the reviewer's own line) and do not declare done.

## Phase 7 — Improve

- If a NetworkPolicy allow recurs across services (e.g. shared observability namespace), queue pattern to `ai/dynamic/learned-patterns.md`.
- If probe shape varies per service unintentionally, queue convention update.

## Output

```
Generated under k8s/orders-api/:
  deployment.yaml  (replicas omitted: HPA 2-10 owns them; PDB maxUnavailable 1)
  service.yaml
  ingress.yaml     (TLS via cert-manager-issuer-letsencrypt-prod)
  hpa.yaml
  pdb.yaml
  networkpolicy.yaml  (default-deny + 3 allows: dns, postgres, prometheus)
  serviceaccount.yaml (orders-api-sa, automountServiceAccountToken: false)
  configmap.yaml
  external-secret.yaml

Static gates (offline, KUBECONFIG = empty scratch file):
  render.sh            2 envs rendered, exit 0 · canaries read
  k8s-api-version-scan 0 rows at 1.36 (objects read 9/9; kubeconform -strict)
  availability.sh      0 rows · wiring.sh 0 rows
  @k8s-reviewer        PRODUCTION-GRADE (0 BLOCKER)
  dev rollout status   UNVERIFIED (no confirmed cluster context)

Production-readiness scorecard:
  1 identity + privilege    MET  (serviceAccountName: orders-api-sa; Role scoped to configmaps:get; no wildcard; automount off)
  2 resources + floor       MET  (containers[0]: cpu request 250m, memory request = limit 512Mi; floor 2 from hpa.yaml:9; PDB maxUnavailable 1)
  3 secrets via a manager   MET  (external-secret.yaml; no committed kind: Secret data:)
  4 NetworkPolicy (a)(b)    MET  (default-deny + 3 allows; DNS UDP+TCP 53; postgres and prometheus reachable)
  5 reproducible + bounded  MET  (image @sha256:…; apiVersions served at 1.36; maxReplicas 10; worst-case 10×(250m,512Mi))

VERDICT: PRODUCTION-GRADE

# On any gap:
#   1 identity + privilege    UNMET (deployment.yaml:21 serviceAccountName absent → binds `default`)
# VERDICT: NOT-PRODUCTION-GRADE — unmet: 1 · blockers: 1. Not declared done.
```

## Failure modes

- **An `apiVersion` recalled instead of resolved** — the manifest lints clean, passes review, and fails at `kubectl apply` on the one cluster that matters. Group versions are removed on a schedule; the oracle is the target minor read from files (checked offline by `k8s-api-version-scan`) or a `kubectl --context=<confirmed ctx> api-resources` read.
- Image tag = `:latest` — non-reproducible deploys, broken rollbacks; use digest or semver.
- No requests, or no memory limit — oversubscription, first eviction under pressure, one leak taking the node. A CPU limit copied onto a request-serving container is the opposite trap: throttling while the node idles.
- Confused liveness vs readiness — silent dead pods OR cascading restarts during slow startup.
- NetworkPolicy default-deny without DNS allow — pods can't resolve anything.
- HPA without resource requests — never scales (computes percent-of-request).
- PDB `minAvailable >= replicas` — node drains hang forever. Single-replica PDB is the same trap inverted: `minAvailable: 1` on 1 replica blocks every drain; `minAvailable: 0` is a no-op. Skip the PDB or run ≥ 2 replicas.
- Secrets in ConfigMap `data:` committed to git — leak; use ESO / Sealed Secrets / Vault.
- Workload left on the `default` ServiceAccount with token auto-mounted — any RCE now speaks to the API server with the namespace default's rights; give it a dedicated, minimally-scoped SA and `automountServiceAccountToken: false`.
- Running any `kubectl` against the default context to "check" the target — the context is named and confirmed, or the check runs offline / on scratch kind.
- Declaring "done" on `kubeconform PASS` + `kubectl apply` alone — that is the functional floor; the run is PRODUCTION-GRADE only when the Phase 6b scorecard is fully MET, else it reports NOT-PRODUCTION-GRADE with the unmet controls named.
- Read-only root FS breaks apps writing logs/temp — mount `emptyDir` for those paths instead of disabling RO.

## Related

### Agents
- `@k8s-reviewer` — renders the Phase 6 PRODUCTION-GRADE verdict this command gates on, over the four detectors' rows.
- `@infra-architect` — confirms probe shape + base-image hardening in Phase 4.
- `@kubernetes-architect` — owns the cluster operating model these manifests sit inside (edge API, tenancy, upgrade cadence). Consult it when halt #11 or #12 exposes a cluster-level question (an unsupported minor, no ingress controller, no Gateway API CRDs) rather than a manifest-level one.

### Commands
- `audit-iam` — the cloud-IAM analog of control 1; run it against the ServiceAccount's IRSA/Workload-Identity binding after apply.

### Skills
- `k8s-render-scan`, `k8s-api-version-scan`, `k8s-availability-scan`, `k8s-wiring-scan` — Phase 6a runs them on this command's output.

### Patterns
- `ai/patterns/zero-downtime-deploys.md`

### Rules
- `.claude/rules/infra-principles.md`
