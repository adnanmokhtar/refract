---
name: k8s-audit
description: Audit a running K8s cluster (or its manifests) for safety, HA, security, and cost issues. Run weekly.
---

# k8s-audit

## Premise

Find real issues. Every finding cites a `<resource>` (Deployment/Service/Pod/Namespace + name), the cluster it lives in, and the manifest path or `kubectl get` query that surfaced it. "No NetworkPolicy in namespace X" is grounded in `kubectl get networkpolicy -n X` returning empty. "Running as root" cites the pod spec field that's missing or `runAsUser: 0`. Cost findings cite the actual idle / unattached resource by name + size.

## Halt conditions

- Refuse to flag "no HA" without checking both `replicas` and any HPA covering the Deployment.
- Refuse to call a pod "root" without inspecting `securityContext.runAsUser`.
- Halt on hand-waves like "looks over-provisioned" — cite the request vs measured-usage numbers.
- Halt on any finding that cannot cite the concrete tool-output line / parsed spec field it fired on (see the Checks tool-output → citation table) — no cite, no finding.
- Don't propose auto-fix; report and let humans decide.

## Tools (install on first run)

- `kube-score` — static manifest analysis
- `kubeconform` — validate against OpenAPI
- `kubesec.io` — security risk score
- `kubent` (kube-no-trouble) — deprecated API detection
- `kube-bench` (CIS benchmark) — if cluster-level
- `kubectl cost` + `kubecost` / `opencost` — cost

## Checks

**Tool-output → citation (cite-or-halt).** Like `tf-plan-review` binds every risk to a parsed `tfplan.json` change symbol, and `dr-audit` binds every gap to a resource address + the missing config line, every finding here MUST cite the concrete evidence line from the named tool that surfaced it — not an eyeball impression. Bind each check group to its tool output:

| Check group | Tool | Required citation on every finding |
|---|---|---|
| Safety / HA | `kubectl get deploy/hpa/pdb -o yaml`, `kube-score` | the `<Deployment>` name + the `replicas:`/HPA/`PodDisruptionBudget` field value (or its absence in the parsed spec) |
| Security | `kube-bench`, `kubesec.io`, `kubectl get pod -o yaml` | the failed `kube-bench` control id (e.g. `5.2.5`) OR the `securityContext` field (`runAsUser: 0`, `privileged: true`) from the parsed pod/namespace spec |
| Resources | `kubectl get pod -o yaml`, `kubectl top`, `kubectl cost` | the `requests`/`limits` values + the `kubectl top`/`kubectl cost` measured-usage line (request-vs-usage numbers, never "looks over-provisioned") |
| Operations | `kubectl get ingress/servicemonitor -o yaml` | the `<resource>` + the missing TLS / ServiceMonitor / log-sink field from the parsed manifest |
| Cost | `kubectl cost` / `kubecost` / `opencost`, `kubectl get pvc/svc` | the `kubectl cost` idle-resource line OR the unattached `<PVC>`/`<LoadBalancer Service>` name + size from the parsed output |
| Deprecations | `kubent` | the `kubent` line naming the deprecated API + the removal version |

**Halt: no finding without its tool-output citation.** A check that cannot name the tool line / parsed field it fired on is dropped, not reported as a vibe — same discipline as `dr-audit`'s "no cite → no finding."

### Safety / HA
- Every Deployment has `replicas >= 2` OR is behind an HPA.
- `PodDisruptionBudget` on every critical Deployment.
- Probes on every container.
- `topologySpreadConstraints` distribute across zones / nodes.
- Anti-affinity on critical pods so they don't schedule on one node.

### Security
- No `privileged: true` containers.
- No `hostNetwork: true` / `hostPID: true` unless justified.
- Non-root users.
- Read-only root FS.
- Drop all capabilities.
- NetworkPolicy present.
- Image pulled from trusted registry.
- No `:latest` tags.

### Resources
- Every container has `requests` + `limits`.
- Limits not wildly over requests (avoid noisy neighbor).
- HPA reasonable bounds.

### Operations
- Ingress with TLS.
- Metrics exported (ServiceMonitor / PodMonitor).
- Logs flowing to centralized sink.

### Cost
- Unused resources (Deployments with 0 recent traffic).
- Over-provisioned requests (pod using 5% of 2 CPU request).
- PVCs not attached to any pod.
- LoadBalancers for internal-only services.

### Deprecations
- `kubent` flags APIs removed in next version.

## Output

```
K8s audit — cluster prod-east-1

HIGH:
  ✗ Deployment api has replicas=1, no HPA — no HA
  ✗ 3 pods running as root (postgres, redis, prometheus)
  ✗ No NetworkPolicy in namespace default — default-deny missing

MEDIUM:
  ⚠ Ingress billing-svc has no rate limit
  ⚠ PVC db-backup-2022 unattached, 500 GB — $50/mo wasted
  ⚠ Deployment worker limits 4 CPU, using avg 0.2 — over-provisioned

LOW:
  - 2 Deployments use v1beta API scheduled for removal in K8s 1.31

Run /k8s-audit weekly. File tickets for HIGH findings.
```

## Rules

- Audit production separately from staging.
- Don't auto-fix. Report, let humans decide.
- Critical findings = ticket with owner + deadline.

## Related

- `network-exposure-audit` — the NetworkPolicy presence check here is one axis; that skill drills network exposure across cloud + cluster (public SGs, public DBs/buckets, exposed metrics ports) and the drift this cluster-scoped audit doesn't see.
