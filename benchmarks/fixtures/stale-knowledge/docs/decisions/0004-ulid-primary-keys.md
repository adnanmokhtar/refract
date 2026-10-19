# 4. ULID primary keys

Status: Superseded by ADR-0006
Date: 2026-05-18

## Context

Primary keys must be sortable by creation time and safe to generate in the client.

## Decision

Entities use ULIDs generated in the constructor.

## Consequences

Keys are 26-character strings.
