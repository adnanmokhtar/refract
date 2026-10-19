# 5. HTTP adapter

Status: Accepted
Date: 2026-05-20

## Context

NestJS ships two HTTP adapters.

## Decision

Use Express as the HTTP adapter; middleware from the Express ecosystem can be reused as is.

## Consequences

Request handlers receive Express request objects.
