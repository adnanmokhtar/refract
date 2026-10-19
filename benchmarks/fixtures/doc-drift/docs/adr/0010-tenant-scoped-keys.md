# 11. Tenant-scoped API keys

Date: 2026-07-14

Status: Accepted

## Context

Agencies manage several merchants and asked for one key per merchant they manage.

## Decision

An API key belongs to exactly one merchant; an agency holds one key per merchant.

## Consequences

Key rotation is per merchant.
