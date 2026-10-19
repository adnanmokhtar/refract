# 7. Transactional outbox for domain events

Status: Accepted
Date: 2026-06-22

## Context

Order events must reach the webhook relay exactly when the order commits.

## Decision

Write events to an `outbox` table in the same flush as the change; a polling relay publishes them.

## Considered options

- An outbox table polled by a relay (chosen).
- `kafkajs` producers called after the commit: rejected, a crash between commit and publish loses the event.

## Consequences

The relay owns retries; handlers stay idempotent.
