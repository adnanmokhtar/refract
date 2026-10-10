#!/usr/bin/env bash
# On-call shortcut: apply a change to the orders database without waiting for the full prod plan.
set -euo pipefail
cd "$(dirname "$0")/.."
terraform -chdir=envs/prod init -input=false
terraform -chdir=envs/prod apply -target=module.orders_db -auto-approve
