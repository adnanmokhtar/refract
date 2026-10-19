# 3. In-memory rate limiting

Date: 2026-02-02

Status: Superseded by [0006](0006-redis-rate-limit.md)

## Context

The API needs a per-key rate limit before the first public launch.

## Decision

Each API process keeps its own token bucket per key in memory.

## Consequences

With several replicas the effective limit is the per-process limit times the replica count.
