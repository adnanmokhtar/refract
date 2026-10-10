#!/usr/bin/env bash
# verify-release.sh <tag>: check the signature and the build provenance of a released api image.
set -euo pipefail
TAG="${1:?usage: verify-release.sh <tag>}"
cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer https://token.actions.githubusercontent.com "ghcr.io/acme/shop-api:${TAG}"
gh attestation verify "oci://ghcr.io/acme/shop-api:${TAG}" --owner acme
