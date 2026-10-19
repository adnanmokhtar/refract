#!/usr/bin/env bash
# Creates the dev account's managed services that infra/terraform/envs/do does not own yet.
# Run once per fresh dev account; see ai/runbooks/platform-do.md for the Postgres cluster.
set -euo pipefail

REGION="${REGION:-fra1}"

doctl registry create quaywise-dev --subscription-tier basic --region "$REGION"

doctl databases create qw-dev-valkey --engine valkey --version 8 --size db-s-1vcpu-1gb --region "$REGION" --num-nodes 1

VALKEY_ID="$(doctl databases list --format ID,Name --no-header | awk '$2 == "qw-dev-valkey" { print $1 }')"
CLUSTER_ID="$(doctl kubernetes cluster get qw-dev --format ID --no-header)"
doctl databases firewalls append "$VALKEY_ID" --rule "k8s:$CLUSTER_ID"

echo "valkey: $VALKEY_ID (store the connection string in the dev secret, never in this repo)"
