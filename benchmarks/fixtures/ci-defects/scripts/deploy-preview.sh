#!/usr/bin/env bash
# deploy-preview.sh: build and deploy the checked-out pull request to the preview namespace.
set -euo pipefail
printf '%s' "$KUBE_CONFIG" | base64 -d > "${RUNNER_TEMP:-/tmp}/kubeconfig"
helm upgrade --install web-preview deploy/charts/web-preview --kubeconfig "${RUNNER_TEMP:-/tmp}/kubeconfig" -n previews --wait --timeout 10m
