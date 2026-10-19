#!/usr/bin/env bash
# deploy-host.sh: the two Compose hosts. The shop host runs the full stack from compose.yaml;
# the reports host runs the production overlay.
set -euo pipefail
host="${1:?usage: deploy-host.sh shop|reports}"
case "$host" in
  shop)
    ssh deploy@shop-host-1.shop.example 'cd /srv/shop && git pull --ff-only && docker compose pull && docker compose up -d'
    ;;
  reports)
    ssh deploy@reports-host-1.shop.example 'cd /srv/shop && git pull --ff-only && docker compose -f compose.yaml -f compose.prod.yaml up -d --wait'
    ;;
esac
