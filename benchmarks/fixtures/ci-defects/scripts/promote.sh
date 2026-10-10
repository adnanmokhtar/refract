#!/usr/bin/env bash
# promote.sh <digest>: promote a verified api digest to the :prod tag.
# Both steps act on the digest, never on a tag that could move between them.
set -euo pipefail
DIGEST="${1:?usage: promote.sh sha256:<digest>}"

# 1. The signature must come from the deploy workflow on main, issued by GitHub's OIDC provider.
cosign verify \
  --certificate-identity 'https://github.com/acme/shop/.github/workflows/deploy.yml@refs/heads/main' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "ghcr.io/acme/shop-api@${DIGEST}"

# 2. Point :prod at that exact digest (no rebuild, no pull and re-push).
docker buildx imagetools create --tag ghcr.io/acme/shop-api:prod "ghcr.io/acme/shop-api@${DIGEST}"
