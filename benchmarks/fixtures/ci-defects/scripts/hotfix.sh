#!/usr/bin/env bash
# hotfix.sh: on-call levers for the storefront during an incident.
set -euo pipefail
case "${1:-}" in
  scale-up)
    kubectl scale deploy/web -n shop-web --replicas=6
    ;;
  status)
    kubectl get deploy/web -n shop-web -o wide
    ;;
  *)
    echo "usage: hotfix.sh scale-up|status" >&2; exit 2
    ;;
esac
