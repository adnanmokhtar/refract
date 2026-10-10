# Platform runbook — production EKS cluster

The cluster itself (EKS 1.36, one managed node group of 3–9 nodes across eu-central-1a/b/c) is created by
Terraform in `iac/envs/prod/eks.tf`. Everything below runs once per cluster build, from a laptop with the
cluster's kubeconfig, after `aws eks update-kubeconfig --name larder-prod`.

## 1. Platform charts

Ingress (Traefik behind an NLB), autoscaling, certificates and config reloads.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

helm upgrade --install argocd argo/argo-cd --version 8.5.2 -n argocd --create-namespace \
  --set server.replicas=2 --set repoServer.replicas=2

helm upgrade --install traefik traefik/traefik --version 37.1.2 -n traefik --create-namespace \
  --set service.type=LoadBalancer --set ports.websecure.tls.enabled=true

helm upgrade --install keda kedacore/keda --version 2.18.1 -n keda --create-namespace

helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
  --set crds.enabled=true --set replicaCount=2 --set webhook.replicaCount=2

helm upgrade --install reloader stakater/reloader --version 2.2.3 -n reloader --create-namespace

helm upgrade --install metrics-server metrics-server/metrics-server --version 3.13.0 -n kube-system \
  --set replicas=2

helm upgrade --install velero vmware-tanzu/velero --version 11.1.0 -n velero --create-namespace \
  --set configuration.backupStorageLocation=null --set deployNodeAgent=true
```

kube-prometheus-stack is installed by Argo CD (`k8s/argo/larder-observability.yaml`), not from here.

## 2. Workloads applied by hand

Argo CD owns `k8s/overlays/prod` and the storefront chart. The rest is applied from this runbook:

```bash
kubectl apply -f k8s/argo/
kubectl apply -f k8s/platform/
kubectl apply -f edge/k8s/
kubectl create configmap caddy-config -n edge --from-file=edge/caddy/shop.caddy --from-file=edge/caddy/events.caddy --from-file=edge/caddy/api.caddy \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap nginx-edge-conf -n edge --from-file=edge/nginx/nginx.conf \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap partner-gateway-conf -n edge --from-file=edge/nginx/partner-gateway.conf \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k dns/cert-manager/overlays/prod
kubectl apply -f dns/monitoring/
kubectl apply -k dr/k8s
kubectl apply -f dr/velero/
kubectl apply -f dr/databases/
```

`nginx-edge` and the Caddy DaemonSet pick up a re-created ConfigMap on their own (Reloader; `caddy run --watch`).
After editing `edge/nginx/partner-gateway.conf` (the partner allowlist), re-create its ConfigMap with the command
above and bump `larder.io/config-revision` in `edge/k8s/partner-gateway.yaml` so the pods restart.

## 3. Trial cluster (single node, pre-launch demos)

```bash
kubectl apply -k k8s/overlays/trial-single-node
```
