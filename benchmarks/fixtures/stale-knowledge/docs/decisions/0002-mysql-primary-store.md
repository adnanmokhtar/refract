# 2. MySQL as the primary store

Status: Superseded by ADR-0003
Date: 2026-05-11

## Context

The first prototype ran on a managed MySQL 8 instance.

## Decision

Use MySQL 8 through MikroORM's `@mikro-orm/mysql` driver.

## Consequences

Superseded once row-level tenancy and JSONB reporting were needed; see ADR-0003.
