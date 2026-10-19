# 8. Generate the SDK from the spec

Date: 2026-06-03

Status: Proposed

## Context

The SDK's types are written by hand and lag the spec.

## Decision

Generate the SDK's types from `apps/api/openapi.json` at build time.

## Consequences

Hand-written helpers stay; the generated types replace the hand-written interfaces.
