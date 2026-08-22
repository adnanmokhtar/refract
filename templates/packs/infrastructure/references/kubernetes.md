# Kubernetes reference

> **Tool**: Kubernetes. **This file does NOT pin a version, deliberately.** Upstream maintains only the three most recent minors, each with roughly a year of patch support, and ships about three minors a year (https://kubernetes.io/releases/) — any version written here is wrong within months. Read the cluster: `kubectl version`. Managed providers (EKS / GKE / AKS) track their own, narrower windows.
> **Official docs**: https://kubernetes.io/docs/ • Removed-API schedule: https://kubernetes.io/docs/reference/using-api/deprecation-guide/
> **Version-specific gotchas**: PodSecurityPolicy has not been served since v1.25 — Pod Security Admission (`pod-security.kubernetes.io/enforce`) replaced it. `NetworkPolicy` default-deny is OFF unless you explicitly add a policy. `topologySpreadConstraints` (zone-keyed) over manual anti-affinity for HA spread. Native sidecars are `initContainers` with `restartPolicy: Always` — confirm support on the target minor with `kubectl explain pod.spec.initContainers.restartPolicy`.
> **Substitution markers**: Replace `registry.example.com/api@sha256:<digest>` with the project's actual image reference.

## Resolve API versions from the cluster, never from memory

Group versions are removed on a published schedule and the schedule is the citation, not recall:

```bash
kubectl version                       # the minor everything below is relative to
kubectl api-resources                 # every kind the cluster serves, with its version
kubectl explain <kind>.<field>        # whether a field exists on THIS minor
```

Removals already in effect (see the deprecation guide for the full list, and check it rather than this line): `policy/v1beta1` PodDisruptionBudget and `batch/v1beta1` CronJob have not been served since v1.25; `autoscaling/v2beta2` HorizontalPodAutoscaler since v1.26. A manifest carrying a removed version lints clean, passes review, and fails at apply.

`kubeconform -kubernetes-version <minor>` validates against the target's schema rather than the newest one on disk. (`kubeval` is unmaintained; its README points at kubeconform: https://github.com/instrumenta/kubeval.)

## Canonical Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels: { app: api }
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels: { app: api }
  template:
    metadata:
      labels: { app: api }
    spec:
      serviceAccountName: api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: api
          image: registry.example.com/api@sha256:<digest>  # pinned
          ports:
            - { containerPort: 3000, name: http }
          env:
            - name: DATABASE_URL
              valueFrom: { secretKeyRef: { name: api-secrets, key: database_url } }
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: 500m, memory: 512Mi }
          livenessProbe:
            httpGet: { path: /health, port: http }
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet: { path: /ready, port: http }
            initialDelaySeconds: 5
            periodSeconds: 5
          startupProbe:
            httpGet: { path: /health, port: http }
            failureThreshold: 30
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          volumeMounts:
            - { name: tmp, mountPath: /tmp }
      volumes:
        - name: tmp
          emptyDir: {}
      terminationGracePeriodSeconds: 30
```

## Companions

- **Service** (ClusterIP) — stable DNS + load balance across pods.
- **North-south edge** — `Ingress` or Gateway API; see below. Whichever the cluster already serves wins.
- **HorizontalPodAutoscaler** — CPU-based scaling `{ min: 2, max: 10, target-cpu: 70% }`. Memory is a poor scaling signal (it grows and holds); use a custom/external metric for queue- or IO-bound work.
- **PodDisruptionBudget** — `minAvailable: 1` prevents voluntary drains from killing everything.
- **NetworkPolicy** — default-deny + explicit allows for DNS + service ports.
- **ServiceAccount + RoleBinding** — least-privilege for pod-to-API access.

## Secrets

- **NEVER** commit secrets, even base64'd.
- Use External Secrets Operator (sync from AWS SM / GCP SM / Vault).
- OR Sealed Secrets (encrypted in repo, decrypted in cluster).
- OR Kubernetes Secrets with restricted RBAC (acceptable for dev/staging).

## Probes

- **livenessProbe** — "should we restart this pod?" — failure kills + reschedules.
- **readinessProbe** — "can this pod serve traffic?" — failure removes from Service.
- **startupProbe** — for slow-boot apps, gates liveness until first success.

## Rolling updates

- `maxSurge: 1, maxUnavailable: 0` — zero-downtime.
- Readiness probe MUST pass before traffic shifts.
- Old pods drain per `terminationGracePeriodSeconds`.
- **Endpoint removal and SIGTERM are issued in parallel**, so a pod can still receive traffic after it has begun shutting down. A `lifecycle.preStop` delay on the container is the standard mitigation — see `ai/patterns/zero-downtime-deploys.md`.

## Autoscaling

- HPA on CPU for CPU-bound apps.
- HPA on custom metrics (queue depth, request rate) for I/O-bound.
- VPA (vertical) for right-sizing; use with caution in prod.
- Cluster Autoscaler adds nodes when pods can't schedule.

## Networking — the edge decision

- Services: ClusterIP (internal), NodePort (discouraged), LoadBalancer (public cloud).
- NetworkPolicy default-deny, then allow-list.
- DNS: `<svc>.<ns>.svc.cluster.local`.

**Ingress NGINX is retiring.** The Kubernetes Steering Committee and Security Response Committee announced retirement in **March 2026**: *"There will be no more releases for bug fixes, security patches, or any updates of any kind after the project is retired"*, and *"choosing to remain with Ingress NGINX after its retirement leaves you and your users vulnerable to attack"* (https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/). The named paths off it are Gateway API and third-party Ingress controllers, and the statement is explicit that **none is a drop-in replacement**.

Note the ambiguity that bites: "nginx ingress" can mean the retiring upstream project OR a vendor's separately-maintained NGINX-based controller. `ingressClassName` does not distinguish them — check the controller Deployment's image.

**`Ingress` (`networking.k8s.io/v1`)** — set `spec.ingressClassName`, declare `pathType`, terminate TLS. Behaviour beyond host/path routing is expressed in controller-specific annotations, which are NOT portable and are silently ignored when the installed controller does not implement them.

**Gateway API (`gateway.networking.k8s.io/v1`)** — kinds `GatewayClass` / `Gateway` / `HTTPRoute` / `GRPCRoute`. It is an **add-on installed as CRDs, not built into Kubernetes** (https://kubernetes.io/docs/concepts/services-networking/gateway/), so confirm the CRDs exist:

```bash
kubectl api-resources --api-group=gateway.networking.k8s.io
```

The design point is the ownership split: the platform owns the `Gateway` (listeners, TLS, addresses), each team owns its `HTTPRoute` and attaches via `parentRefs`. Cross-namespace attachment requires the `Gateway`'s `allowedRoutes` to permit it — check `status.parents[].conditions` for `Accepted`, because an unattached route fails silently. Weights, header matches and redirects are first-class route fields, not annotations.

## Observability

- Prometheus scrapes `/metrics` from every pod (ServiceMonitor for Prom Operator).
- Logs to stdout → collected by fluent-bit / vector → sink.
- Traces via OpenTelemetry DaemonSet collector.

## Operations

- Namespace per team / environment.
- ResourceQuota per namespace.
- LimitRange sets default requests/limits for pods that don't specify.
- Use `kubectl apply -f` (or Helm / Kustomize) — NEVER edit resources manually in prod.
- GitOps (Argo CD / Flux) — cluster state = git state.

## Forbidden

- No resource limits/requests.
- `:latest` images.
- Root user.
- Secrets in ConfigMap / Deployment env literal.
- `kubectl exec` into prod pods as a regular workflow (use proper tooling).
- Manual cluster state edits bypassing git.
