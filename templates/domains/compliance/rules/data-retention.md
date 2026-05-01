---
name: data-retention
description: Data retention
kind: rule
---

# Data retention

## Hard rule

Every data class MUST have a declared retention period and a scheduled job that hard-deletes past it. "Just in case" retention beyond policy is FORBIDDEN. PII MUST NOT be logged, copied to analytics events, or held in backups beyond the policy unless a jurisdictional requirement is cited in an ADR. Storing data forever is a liability — explicit retention per data class, enforced by code.

## Classifications (typical)

| Class | Examples | Retention |
|---|---|---|
| Auth sessions | refresh tokens, login sessions | 30 days past expiry |
| User PII | name, email, phone | until deletion request / account deactivation + 30 days |
| Financial records | invoices, payments, charges | 7 years (regulatory — check jurisdiction) |
| Communications | chat messages, emails sent | per tenant plan (90d / 1y / forever) |
| Audit logs | security events, admin actions | 2 years |
| Analytics events | page views, clicks | 13 months |
| Temp uploads | in-process files | 24 hours |
| Webhook events | dedupe rows, raw payloads | 90 days (long enough for replay; short enough to limit scope) |

Project-specific overrides live in `<retention-config-path>` (e.g. `ai/compliance/retention.yaml`).

## Must

- **One declared retention per data class.** A class without a retention is a TODO, not policy. CI fails on a PII-bearing table missing a `retention.yaml` entry.
- **Scheduled purge job** runs daily, hard-deletes rows past retention, logs structured counts (rows purged per class).
- **Two-stage delete**: soft-delete (`deleted_at`) → hard-delete after grace period. Hard-delete is the actual `DELETE FROM`, not a flag flip.
- **PII inventory** lives in version control (`<inventory-path>`, e.g. `ai/compliance/pii-inventory.yaml`); every PII column has a row.
- **GDPR / CCPA exporter** exists per PII-bearing entity, returns all data for a user as JSON; coverage test fails CI when an entity is unwired.
- **GDPR / CCPA deleter** exists per PII-bearing entity; orchestrator endpoint cascades + writes audit-log entry.
- **Sub-processor notification path** exists for every external provider holding the same data (Stripe, ESP, analytics). Deletion request triggers a notify-or-API-call within 30 days.
- **Backups respect retention** — backup retention is declared separately and never exceeds the data-class retention without an ADR + jurisdictional citation.
- **PII access audit log** records `{user, purpose, tenant, timestamp, data_class}` on every read of a PII-flagged column outside the user's own data.

## Must not

- "Just in case" retention beyond policy.
- Keep deleted data in logs.
- Hold backups that outlive retention (unless jurisdictionally required + cited in ADR).
- Persist PII in analytics events (page-view payloads, click events, A/B test exposure events).
- Log full payment / auth / webhook payloads at info level.
- Send PII to a third party (Sentry, DataDog, Mixpanel, LogRocket) without explicit configuration to scrub it.
- Soft-delete-only: a `deleted_at` flag without a hard-delete cron is data hoarding under a different name.
- Hard-delete event-sourced data via `DELETE FROM events` — use crypto-shredding (drop the per-subject encryption key).

## Should

- Annual review — are retention periods still accurate against current regulation + product reality?
- Crypto-shred PII in long-retention stores (event store, audit log) so "deletion" = drop the per-subject key, leaving the event/audit-trail structurally intact.
- Compute retention from a clear anchor — `created_at`, `last_used_at`, `closed_at` — and document which.
- Surface retention in the privacy policy + the user account UI (so users can see when their data expires).
- Test the purge job in staging against fixture data; never deploy a purge job that hasn't run end-to-end somewhere.

## Review checklist (PRs touching schema / PII handling)

- [ ] New columns containing PII are flagged in `<inventory-path>`.
- [ ] New tables containing user data have a retention class declared in `<retention-config-path>`.
- [ ] Exporter + deleter wired for new PII-bearing entities; coverage test passes.
- [ ] No PII in newly-added analytics / log lines.
- [ ] No new third-party SDK send-path without scrubber configuration.
- [ ] Purge job updated to cover the new class (if class is new).
- [ ] Sub-processor list updated if a new external provider holds the data.
- [ ] Backup retention configuration reviewed if class retention changed.

## Anti-patterns

- **Soft-delete forever** — `deleted_at` set, hard-delete cron never written. Looks compliant on day 1; isn't on day 365.
- **PII in logs at info** — `logger.info({ user })` where `user` is the full row. Use `logger.info({ userId: user.id })` or a redactor.
- **PII in analytics** — `track('checkout_started', { email })`. Analytics is forever; user deletion never reaches it.
- **Backup retention drift** — DB retention is 30d; the warm backup is 90d; the glacial backup is 7y. The longest one is your effective retention.
- **Manual deletion** — "ticket-driven" deletes via DBA. No audit, no test, no proof. Automated endpoint with logged orchestrator only.
- **Third-party silent retention** — Stripe / Sendgrid / Intercom keep copies after our delete. Notify-or-API-delete sub-processors within 30 days; track the calls.
- **Inventory drift** — `pii-inventory.yaml` says 12 entities; schema has 15. Coverage test must walk both and refuse skew.

## Enforcement

- `<commands-path>/compliance-audit.md` (slash: `/compliance-audit` / `/retention-audit`) — verifies every PII-bearing table is matched by a retention rule + a daily purge job; verifies exporter + deleter wired for every PII entity; runs the coverage test.
- Purge job MUST log structured counts (rows purged per class) — alert on zero counts where activity exists (job is broken, not idle).
- GDPR export + delete endpoints MUST ship with integration tests; CI fails if missing.
- `<agents-path>/compliance-reviewer.md` — review gate hard-failing on missing inventory entries, missing retention classes, PII-in-logs, PII-in-analytics.
- TODO: `scripts/validate-retention-coverage.sh` to cross-reference DB schema (`*_pii` annotations / known PII columns) against `<retention-config-path>` and fail on uncovered tables.

## Cross-references

- `<patterns-path>/gdpr-export-delete.md` — exporter / deleter / inventory architecture (the "how"); coverage test details; sub-processor notification.
- `<commands-path>/compliance-audit.md` — audit scanner.
- `<agents-path>/compliance-reviewer.md` — review gate.
- `<rules-path>/payment-idempotency.md` — financial-record retention is non-negotiable for chargeback windows.
- `<adr-path>/<NNN>-data-retention-policy.md` — ADR pinning per-class retention with jurisdictional citations.
