# 8. Cursor pagination

Status: Accepted
Date: 2026-06-29

## Context

Offset pages skip and repeat rows while orders are being placed.

## Decision

List endpoints take an opaque `after` cursor (the last id) and a `limit` of at most 100.

## Consequences

Clients cannot jump to page N; exports stream instead.
