---
name: data-retention
description: Data retention
kind: rule
---

# Data retention

## Hard rule

Every data class MUST have a declared retention period and a scheduled job that hard-deletes past it. "Just in case" retention beyond policy is FORBIDDEN. PII MUST NOT be logged, copied to analytics events, or held in backups beyond the policy unless a jurisdictional requirement is cited in an ADR.

Storing data forever is a liability. Explicit retention per data class, enforced by code.

## Classifications (typical)

| Class | Examples | Retention |
|---|---|---|
| Auth sessions | refresh tokens, login sessions | 30 days past expiry |
| User PII | name, email, phone | until deletion request / account deactivation + 30 days |
| Financial records | invoices, payments | 7 years (regulatory — check jurisdiction) |
| Communications | chat messages, emails sent | per tenant plan (90d / 1y / forever) |
| Audit logs | security events, admin actions | 2 years |
| Analytics events | page views, clicks | 13 months |
| Temp uploads | in-process files | 24 hours |

## Enforcement

- Scheduled job (daily) purges rows past retention.
- Soft delete first (`deleted_at`) → hard delete after grace period.
- Hard delete = ACTUAL DB delete, not flag. Backups retention separately declared.

## GDPR / similar requests

- User data export: endpoint returns all data for a user (JSON).
- User deletion request: cascade delete + audit log entry.
- Processor duty: inform downstream providers (Stripe, Sendgrid) of deletion within 30 days.

## Audit

- Every PII access logged with user + purpose + tenant.
- Retention job logs what was purged (counts, not content).
- Annual review — are retention periods still accurate?

## Forbidden

- "Just in case" retention beyond policy.
- Keeping deleted data in logs.
- Backups that outlive retention (unless jurisdictionally required).
- PII in analytics events.
- Logging full payment / auth payloads.

## Enforcement

- `/retention-audit` command — verifies every PII-bearing table is matched by a retention rule + a daily purge job.
- Purge job MUST log structured counts (rows purged per class) — alert on zero counts where activity exists.
- GDPR export + delete endpoints MUST ship with integration tests; CI fails if missing.
- TODO: `scripts/validate-retention-coverage.sh` to cross-reference DB schema (`*_pii` / known PII columns) against `retention.yaml` declarations and fail on uncovered tables.
