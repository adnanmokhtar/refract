# 8. OpenAPI first

Date: 2026-06-01

Status: Accepted

## Context

The SDK and the docs drifted from the API twice in one quarter.

## Decision

The committed `apps/api/openapi.json` is the contract; a pull request that changes an endpoint
changes the spec first.

## Consequences

The spec is reviewed like code.
