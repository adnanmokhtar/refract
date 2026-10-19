# 6. Redis-backed rate limiting

Date: 2026-04-27

Status: Accepted

## Context

The API now runs at least two replicas, so a per-process limit is not a per-key limit.

## Decision

Rate-limit counters live in Redis, shared by every replica, with a fixed one-minute window.

## Consequences

Redis latency adds to every request; the limiter fails open if Redis is unreachable.
