# 2. Queue webhook deliveries with Bull

Date: 2026-01-20

Status: Superseded by [0004](0004-bullmq-for-queues.md)

## Context

Webhook deliveries must survive a restart and be retried with backoff.

## Decision

Webhook deliveries go through `bull`, wired in `apps/api/src/queue/bull.provider.ts`, with one
queue per event type and Redis as the store.

## Consequences

A Redis outage stops deliveries; they resume when Redis is back.
