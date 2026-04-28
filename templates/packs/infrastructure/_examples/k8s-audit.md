---
name: k8s-audit
description: Audit a running K8s cluster (or its manifests) for safety, HA, security, and cost issues. Run weekly.
---

# k8s-audit

## Tools (install on first run)

- `kube-score` — static manifest analysis
- `kubeconform` — validate against OpenAPI
- `kubesec.io` — security risk score
- `kubent` (kube-no-trouble) — deprecated API detection
- `kube-bench` (CIS benchmark) — if cluster-level
- `kubectl cost` + `kubecost` / `opencost` — cost

## Checks

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
