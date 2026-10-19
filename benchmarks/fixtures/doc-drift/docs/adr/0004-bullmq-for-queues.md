# 4. BullMQ for every queue

Date: 2026-03-09

Status: Accepted

Supersedes [0002](0002-bull-for-webhook-queue.md).

## Context

Bull is in maintenance mode, and the reports job needs a second queue with the same tooling.

## Decision

All queues use BullMQ through `@nestjs/bullmq`; the worker process runs the processors.

## Consequences

Queue names are part of the operational surface: runbooks refer to them.
