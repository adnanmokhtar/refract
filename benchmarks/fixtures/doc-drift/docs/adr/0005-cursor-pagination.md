# 5. Cursor pagination for list endpoints

Date: 2026-04-20

Status: Accepted

Supersedes ADR-0009 (offset pagination for list endpoints).

## Context

Offset pages skip or repeat orders when new orders arrive between two requests.

## Decision

List endpoints take an opaque `cursor` and a `limit`, and return `nextCursor`.

## Consequences

Clients cannot jump to an arbitrary page; the dashboard shows "load more" instead.
