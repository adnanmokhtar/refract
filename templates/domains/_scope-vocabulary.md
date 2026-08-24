# Domain scope vocabulary (authoritative)

Every domain that ships a `rules/*.md` declares the **module-name tokens** that identify where
its code lives. `scripts/scope-domain-rules.sh` reads this table at Phase 4.2, matches the tokens
against the module map the extraction already recorded in `.claude/_extracted-codebase.md`, and
scopes the domain's rule to those real paths.

## Why tokens, and why from the module map

A domain rule is scoped **by definition** — `payment-idempotency` matters when you are in payment
code and nowhere else. Yet measured 2026-08-24, **0 of 35 domain rules and 0 of 28 pack rules
carried `paths:`**, so ~156,738 tokens of rules loaded on every turn regardless of what was being
edited. On capsolah-api that was ~11,576 tok/turn, of which 3,681 were domain rules with nothing
to do with most edits.

The obvious fix — guess a glob from the domain name — was tried and **measured to fail in both
directions** on that repo's 6,187 source files:

| guessed glob | matched | why it is wrong |
|---|---|---|
| `**/*ai*` | 257 files | `account/domain/**` — "dom**ai**n" contains "ai" |
| `**/*tenant*` | 3,193 files (52%) | the app *is* multi-tenant; a glob over half the repo is not scoping |

A substring is not a word, and a template cannot know a project's layout. The extraction already
recorded 80 real module paths for that repo. **Tokens matched against recorded module names** hit
`apps/master/src/ai-provider-settings` and nothing else — because `ai-provider-settings` splits on
`-` into `ai · provider · settings`, while `domain` does not contain the token `ai` at all.

## The two safety rules

1. **No module matched → the rule stays always-loaded.** Absence of evidence is not evidence the
   rule is unneeded. Scoping a rule to a path that does not exist makes it load NEVER — the exact
   knowledge loss this whole mechanism must not cause. Measured on capsolah-api:
   `background-jobs`, `file-upload` and `search` matched no module and correctly stayed as they
   were.
2. **A domain spanning most of the repo stays always-loaded.** If the matched modules cover more
   than `SCOPE_MAX_SHARE` (default 40%) of mapped modules, the concept is pervasive rather than
   local — `multi-tenant` on a multi-tenant app — and scoping it buys nothing while risking a miss.

> Adding a domain here without rules, or a token so generic it matches unrelated modules, puts a
> rule back into the "configured but never loads" state. `scripts/test-domain-scoping.sh` checks
> this table against `templates/domains/` in both directions and asserts both safety rules.

---

## Table

| domain | rule file(s) | module-name tokens |
|---|---|---|
| ab-testing | ab-testing-discipline.md | experiment, experiments, ab, abtest, variant, variants, split |
| admin | admin-backoffice-discipline.md | admin, backoffice, console |
| ai | ai-cost-discipline.md | ai, llm, prompt, prompts, openai, anthropic, embedding, embeddings |
| analytics | analytics-tracking-discipline.md | analytics, tracking, telemetry, stats |
| audit-log | audit-log-discipline.md | audit, auditlog, activity |
| auth | auth-discipline.md | auth, authentication, authorization, login, session, sessions, rbac, permission, permissions |
| background-jobs | job-design.md | job, jobs, queue, queues, worker, workers, cron, scheduler |
| caching | caching-discipline.md | cache, caching, redis |
| compliance | data-retention.md | compliance, retention, gdpr, privacy, consent |
| data-pipeline | data-pipeline-discipline.md | pipeline, pipelines, etl, warehouse, ingestion |
| document-generation | document-generation-discipline.md | pdf, docx, invoice, invoices, document, documents |
| event-sourced | event-sourcing-discipline.md | eventstore, aggregate, aggregates, projection, projections, saga |
| feature-flags | flag-discipline.md | flag, flags, toggle, toggles, unleash, launchdarkly |
| file-upload | upload-safety.md | upload, uploads, attachment, attachments, storage |
| forms | forms-discipline.md | form, forms |
| i18n | i18n-localization-discipline.md | i18n, locale, locales, translation, translations, intl |
| import | import-ingest-discipline.md | import, imports, csv, xlsx |
| integrations | integrations-sync-discipline.md | integration, integrations, connector, connectors |
| ledger | ledger-integrity-discipline.md | ledger, journal, ledgers, posting, postings |
| media-processing | media-processing-discipline.md | media, image, images, video, videos, thumbnail, transcode |
| moderation | moderation-discipline.md | moderation, moderate, abuse |
| multi-tenant | multi-tenancy.md | tenant, tenants, tenancy, subscriber, subscribers |
| notifications | notification-discipline.md | notification, notifications, notify, mailer, sms, push |
| payment | payment-idempotency.md | payment, payments, billing, checkout, invoice, invoices, subscription, subscriptions, plan, plans |
| public-api | public-api-discipline.md | openapi, swagger, publicapi |
| rate-limiting | rate-limit-discipline.md | ratelimit, throttle, throttling, quota |
| real-time | realtime-discipline.md | realtime, websocket, websockets, socket, sockets, sse, pubsub, broadcast |
| reporting | reporting-export-discipline.md | report, reports, reporting, export, exports |
| scheduling | scheduling-discipline.md | schedule, scheduling, booking, bookings, appointment, appointments, availability |
| search | search-discipline.md | search, elasticsearch, opensearch, algolia, indexing |
| settings | settings-config-discipline.md | setting, settings, preference, preferences |
| streaming-delivery | streaming-delivery-discipline.md | streaming, hls, cdn, delivery |
| subscriptions | subscription-billing-discipline.md | subscription, subscriptions, plan, plans, entitlement, entitlements |
| webhook | webhook-signature-verification.md | webhook, webhooks, callback, callbacks |
| workflow | workflow-discipline.md | workflow, workflows, statemachine, approval, approvals |
