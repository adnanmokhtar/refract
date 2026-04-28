# Kubernetes reference

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
- **Ingress** (nginx / traefik) — external HTTP + TLS.
- **HorizontalPodAutoscaler** — CPU-based scaling `{ min: 2, max: 10, target-cpu: 70% }`.
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

## Autoscaling

- HPA on CPU for CPU-bound apps.
- HPA on custom metrics (queue depth, request rate) for I/O-bound.
- VPA (vertical) for right-sizing; use with caution in prod.
- Cluster Autoscaler adds nodes when pods can't schedule.

## Networking

- Services: ClusterIP (internal), NodePort (discouraged), LoadBalancer (public cloud).
- Ingress: one or more controllers (nginx, traefik, istio).
- NetworkPolicy default-deny, then allow-list.
- DNS: `<svc>.<ns>.svc.cluster.local`.

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
