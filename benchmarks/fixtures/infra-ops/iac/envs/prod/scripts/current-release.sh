#!/usr/bin/env bash
# Prints {"tag": "<release>"} for the external data source in release.tf.
set -euo pipefail
tag="$(curl -fsS https://releases.larder.example/api/current | jq -r .tag)"
printf '{"tag": "%s"}\n' "$tag"
