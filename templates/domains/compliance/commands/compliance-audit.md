---
description: Scan the codebase for PII fields, verify retention + deletion + export coverage, audit log presence on reads, and sub-processor inventory currency.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /compliance-audit

Purpose: produce a snapshot of regulatory posture. Catch drift before a regulator does.

## Premise

Find real issues, no hand-waves. Every finding cites `<file:line>`, `<entity.column>`, or `<vendor>` — never "review PII handling" or "consider adding retention." Inventory drift is measured against the actual code tree and the actual `ai/compliance/pii-inventory.md`; if either is missing, halt and say so before reporting.

## Mechanical halt

Hand-wave grep — refuse to print a BLOCKER / REQUEST_CHANGES row without a concrete anchor (file:line, table.column, or vendor name). Generic posture commentary is dropped. End-to-end check halts on the first synthetic-export failure rather than guessing the rest.

## What it scans

1. **PII fields in entities.** Greps `@Column` / `@Entity` declarations for known PII field names: `email`, `phone`, `address`, `street`, `city`, `postal_code`, `country`, `birth_date`, `dob`, `name`, `first_name`, `last_name`, `national_id`, `passport`, `ip`, `device_fingerprint`, `gender`, `tax_id`. Cross-references against `ai/compliance/pii-inventory.md`.

2. **Retention enforcement.** For each PII field in inventory, find the cron job / scheduled task that purges past-retention rows. Missing job = BLOCKER. Job exists but no log lines for >7d = warning (job may be dead).

3. **Export coverage.** Walks every entity flagged as PII-bearing in inventory. Verifies an exporter exists in `src/modules/compliance/exporters/` that includes that entity. Missing = BLOCKER.

4. **Deletion coverage.** Same walk, verifies a deleter exists. Verifies `ON DELETE CASCADE` or explicit deleter for each FK chain into PII tables. Orphan PII = BLOCKER.

5. **Audit log on PII reads.** Greps controllers + services that return PII (joined with entities flagged in inventory). Verifies an `auditLog.record(...)` call inside the handler. Missing = REQUEST_CHANGES.

6. **PII in logs.** Greps `logger.(info|warn|error|debug)(...)` for known PII field names in the structured payload. Hits = BLOCKER.

7. **Sub-processors.** Greps imports/env-vars for known vendors: `stripe`, `twilio`, `sendgrid`, `mailgun`, `aws-sdk` (S3/SES/SNS), `cloudflare`, `@google-cloud`, `@azure`, `algolia`, `mixpanel`, `segment`, `datadog`, `newrelic`, `sentry`. Cross-references against `ai/compliance/sub-processors.md`. Undeclared = BLOCKER.

8. **Consent records.** If `marketing_consent` / `analytics_consent` columns exist, verify a `consents` table records timestamp + scope + version. Missing = REQUEST_CHANGES.

9. **Backup retention.** Reads `ai/compliance/backups.md`. Verifies declared retention does not exceed PII retention from inventory. Mismatch flagged.

10. **End-to-end check.** Generates a synthetic test user, calls export endpoint, calls delete endpoint, verifies:
    - Export response contains every entity flagged in inventory.
    - After delete, the user is unreachable via search APIs.
    - After delete + retention grace period (simulated), PII rows hard-purged.
    - Audit log captured both export request and deletion.

## How

```bash
# Local dry-run (no external API calls, no synthetic-user provisioning)
.claude/skills/compliance-audit-scan.sh

# Full check (runs end-to-end test against staging)
ENVIRONMENT=staging .claude/skills/compliance-audit-scan.sh --full
```

Or `/compliance-audit` slash. Output is a posture report:

```
/compliance-audit — staging — 2026-04-24

═══ PII inventory ═══
  Fields declared in inventory:        47
  Fields detected in code:             49
  DRIFT (in code, not in inventory):
    - users.date_of_birth        (no retention; no export; no delete) — BLOCKER
    - support_tickets.body_text  (free-text, may contain PII)        — REQUEST_CHANGES

═══ Retention ═══
  Rules with active cron job:          45 / 47
  MISSING:
    - login_attempts (rule: 90d, no purge job)                       — BLOCKER
  Last-purge log line older than 7d:
    - analytics_events                                                — WARNING

═══ Export ═══
  Entities covered by exporter:         44 / 49
  MISSING (PII present, no exporter):
    - users.date_of_birth                                              — BLOCKER
    - referral_codes (carries source user PII)                        — BLOCKER
    - chat_messages (contains user-typed PII)                         — REQUEST_CHANGES

═══ Deletion ═══
  Cascade or explicit deleter present: 46 / 49
  MISSING / orphan risk:
    - referral_codes (source_user_id has no ON DELETE CASCADE)        — BLOCKER

═══ Audit log on PII reads ═══
  Endpoints returning PII:              22
  With audit-log emission:              19
  MISSING:
    - GET /admin/customers/:id          — REQUEST_CHANGES
    - GET /admin/orders/:id             — REQUEST_CHANGES
    - GET /support/lookup?email=        — BLOCKER (PII lookup must be audited)

═══ PII in logs ═══
  Hits in code:                          3
    - src/modules/auth/auth.service.ts:34   logger.info({ email })    — BLOCKER
    - src/modules/orders/order.service.ts:88 logger.warn({ phone })   — BLOCKER
    - src/modules/admin/admin.controller.ts:24 logger.info({ name })  — BLOCKER

═══ Sub-processors ═══
  Vendors declared:                     12
  Vendors detected in code:             14
  UNDECLARED:
    - twilio (sms)                                                    — BLOCKER
    - mixpanel (analytics)                                            — BLOCKER
  Region-mismatch (EU PII to US-only):
    - sendgrid (no EU SCC documented)                                 — REQUEST_CHANGES

═══ End-to-end ═══
  Synthetic export:                     SUCCESS — 47/47 entities returned in 4.2s
  Synthetic deletion:                   PARTIAL — 1 orphan referral_code remained
  Audit log captured:                   YES (request + deletion both logged)

═══ Verdict ═══
  BLOCKERS:        9
  REQUEST_CHANGES: 5
  WARNINGS:        1
  Status: NOT-COMPLIANT — open ticket #compliance-2026-04-24
```

## When to run

- Pre-merge of any PR touching entity definitions / user services / auth / admin endpoints / vendor integrations.
- Quarterly scheduled (calendar reminder; output filed in `ai/audits/compliance-<YYYY-Q>.md`).
- Before every external compliance audit (SOC2, ISO27001 surveillance).
- After adding a new vendor.
- After a privacy policy update.

## Output artifact

Writes `ai/audits/compliance-<YYYY-MM-DD>.md` with full report. Append to retention archive (`ai/audits/`).

## Resolution

Each BLOCKER must be either:

1. Fixed in the same PR (preferred for code findings).
2. Tracked in a ticket linked from `ai/compliance/open-findings.md` with a target close date (≤30d for new findings).
3. Documented as accepted risk in `ai/decisions/<ADR>.md` with sign-off from DPO / legal.

REQUEST_CHANGES findings get a 60d window. WARNINGS get a 90d sweep.

## See also

- `ai/patterns/gdpr-export-delete.md` — how to wire export + delete correctly.
- `.claude/rules/data-retention.md` — retention policy per data class.
- `.claude/agents/compliance-reviewer.md` — code review gate for compliance-touching PRs.
- `ai/compliance/pii-inventory.md` — source of truth for fields + retention + lawful basis.
- `ai/compliance/sub-processors.md` — vendor inventory.
