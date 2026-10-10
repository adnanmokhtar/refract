#!/usr/bin/env bash
# deploy.sh <service>: re-apply one service's manifest from main and wait for it.
set -euo pipefail
svc="$1"
kubectl apply -f "deploy/k8s/base/${svc}-deployment.yaml" -n shop-prod
kubectl -n shop-prod rollout status "deploy/${svc}" --timeout=5m
