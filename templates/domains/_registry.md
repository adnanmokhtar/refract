# Technical-signal (domain) registry

Single source of truth for the **technical signals** (cross-cutting tech concerns) supported by `/setup-project`. Phase 2 (signal detection), Phase 4.4 (technical-domain tooling application), and the Glossary all consult this file rather than hard-coded lists.

## What a technical signal is

A **technical signal** is a cross-cutting tech concern detected from code (multi-tenant, payment, AI, webhook, etc.) — distinct from a **business domain** (what the product IS) and from a **track** (the discipline of the practitioner).

Each signal folder under `~/.claude/templates/domains/<name>/` ships:

- `agents/<name>.md` — domain-specific agent personas
- `commands/<name>.md` — workflows that operate on this concern
- `rules/<name>.md` — must / must-not for the concern
- `ai-patterns/<name>.md` — code patterns the agents read
- `_version.json` — version stamp consumed by Phase 4.0 preflight

## Registry (implemented)

| Key | Detection signal | What it ships |
|---|---|---|
| `ab-testing` | experiment SDKs (Optimizely / Statsig / GrowthBook / Split / LaunchDarkly experiments), assignment / bucketing, exposure logging, variant configs | Stable-deterministic-bucketing + exposure-logged + analysis-ready pattern, server-authoritative-assignment + no-peeking + mutual-exclusion + SRM rule, audit-experiment command, ab-testing reviewer |
| `admin` | admin route namespaces / guards (`/admin`, `role=admin` / `is_staff`), impersonation / act-as, back-office frameworks (AdminJS / react-admin / Forest / Django admin) | Granular-capability + audited-action + safe-impersonation pattern, audit-every-action + least-privilege + reauth-for-destructive + bounded-blast-radius rule, admin-surface audit command, admin reviewer |
| `ai` | LLM SDKs, prompt templates, embeddings DBs, agent frameworks | LLM-call pattern, prompt-injection rules, eval patterns |
| `analytics` | product-analytics SDKs (Segment / Amplitude / Mixpanel / PostHog / GA), `track()` / `capture()` call-sites, event schemas / data layer | Typed-tracking-plan + consent-gated + idempotent-event pattern, PII-minimization + consent + no-ad-hoc-events + analytics-≠-audit-log rule, tracking-plan audit command, analytics reviewer |
| `audit-log` | append-only audit / activity tables, who-did-what records, immutable event trail | Tamper-evident append-only rule (hash-chain), audit-trail pattern, coverage+integrity verify command, audit-log reviewer |
| `auth` | auth libs (passport / next-auth / devise / spring-security), JWT/session middleware, password hashing (argon2/bcrypt), OAuth/OIDC clients, guards/RBAC | AuthN-vs-AuthZ architecture pattern, session/token/RBAC discipline rule, access-control (IDOR) audit command, auth reviewer |
| `background-jobs` | bull / sidekiq / celery / temporal / agenda / cron | Job pattern, retry/idempotency rules, queue agent |
| `caching` | cache clients (Redis / Memcached), CDN / `Cache-Control` / `ETag` config, `@Cacheable` / react-query / SWR | Cache-aside + stampede-protection pattern, scoped-key (no cross-tenant leak) + invalidate-on-write + bounded-jittered-TTL + fail-open rule, probe-cache command, caching reviewer |
| `compliance` | references to HIPAA / GDPR / PCI / SOC2 in code/docs/CI | Compliance-aware logging, PII handling rules |
| `data-pipeline` | ETL frameworks (Airflow / Dagster / dbt / Spark / Beam), batch / backfill jobs, CDC, warehouse loads | Idempotent + checkpointed + schema-validated + backfill-safe pattern, watermark-incremental + DLQ-quarantine + backfill-isolation rule, audit-pipeline command, data-pipeline reviewer |
| `document-generation` | PDF/DOCX libs (puppeteer / wkhtmltopdf / pdfkit / react-pdf), invoice/contract/statement templates, print stylesheets | Async sandboxed-render + template-injection-safe + signed-delivery pattern, no-sync-render + SSRF/LFI-block + resource-cap + deterministic-legal-output rule, audit-document-pipeline command, document-generation reviewer |
| `event-sourced` | event-store / CQRS infra / projections | Aggregate pattern, projection rebuild runbook |
| `feature-flags` | LaunchDarkly / Unleash / Flagsmith / homegrown gates | Flag-introduction pattern, cleanup runbook |
| `file-upload` | multipart endpoints, S3/GCS SDKs, virus-scan hooks | Upload pattern, AV-scan rule, content-type allowlist |
| `forms` | form libs (react-hook-form / formik / zod / vee-validate), `<form>` handlers, validation schemas, multipart posts, captcha | Server-validated + CSRF-safe + idempotent-submission pattern, server-is-the-boundary + no-mass-assignment + sanitize-rich-input + rate-limit-public-forms rule, audit-form-handling command, forms reviewer |
| `i18n` | i18n libs (i18next / react-intl / formatjs / vue-i18n / gettext), locale catalogs, ICU messages, `t()` call-sites, `Accept-Language` | Message-catalog + ICU + locale-negotiation pattern, no-hardcoded-strings + CLDR-pluralization + locale-edge-formatting + RTL + translation-isn't-HTML rule, i18n-coverage scan command, i18n reviewer |
| `import` | bulk CSV/XLSX upload+parse endpoints, batch insert/upsert, parse libs (papaparse / xlsx / csv-parse), ingest jobs | Streamed-parse + per-row-validate + idempotent-tenant-scoped-upsert pattern, partial-failure-policy + cross-tenant-write + formula-injection + bounded-size rule, dry-run-import command, import reviewer |
| `integrations` | third-party SDKs (Salesforce / HubSpot / Slack / QuickBooks), OAuth-to-vendor clients, sync jobs, connector configs, stored vendor tokens | Token-vaulted + rate-aware + retried + drift-reconciled pattern, encrypted-per-tenant-credentials + backoff-on-429/5xx + idempotent-sync + circuit-breaker + verify-inbound rule, audit-integration command, integrations reviewer |
| `ledger` | journal/entries tables, double-entry, balance columns, wallet/credits, debit/credit transactions | Immutable-entries + balanced + idempotent + reconciled double-entry pattern, append-only (reversing-entries) + debits=credits-atomic + integer-money + overspend-locked rule, audit-ledger command, ledger reviewer |
| `media-processing` | image/video toolchains (sharp / ImageMagick / ffmpeg), transcode / thumbnail jobs, CDN image pipelines, EXIF handling | Validated sandboxed-async-transcode pipeline pattern, magic-byte-validation + resource/bomb-limits + codec-hardening (ImageTragick / ffmpeg-protocol) + EXIF-strip + signed-delivery rule, media-pipeline audit command, media reviewer |
| `moderation` | report/flag tables, moderation queues, content-scanning (Perspective / Hive / Rekognition), ban/suspend, profanity/CSAM hooks | Scan + queue + audited-action + appeal pipeline pattern, scan-before-serve + illegal-content-hash-match+report + attributed-action + reporter-PII-shield rule, audit-moderation command, moderation reviewer |
| `multi-tenant` | tenant_id columns / row-level-security / per-tenant DB | Tenant isolation rule, query-scope agent, leak audit |
| `notifications` | email/SMS/push providers, template engines | Template + channel pattern, rate-limit rule |
| `payment` | Stripe / Paddle / Adyen / PSP SDKs, webhook signatures | PCI-aware pattern, idempotency rule, reconciliation runbook |
| `public-api` | public/versioned routes (`/v1`), OpenAPI specs, API-key auth, published SDKs, deprecation/rate-limit headers | Versioned + keyed + paginated + deprecation-safe contract pattern, DTO-not-model + version-on-breaking-change + scoped-hashed-keys + idempotent-POST + OpenAPI-is-truth rule, audit-api-contract command, public-api reviewer |
| `rate-limiting` | rate-limit middleware (express-rate-limit / @nestjs/throttler / rack-attack), Redis token buckets, 429 handlers | Algorithm + distributed-counter rule, limiter pattern, probe-limits command, rate-limit reviewer |
| `real-time` | websockets / SSE / WebRTC / pub-sub | Connection-lifecycle pattern, backpressure rule |
| `reporting` | report/export endpoints, CSV/XLSX generation, BI/analytics queries, scheduled report jobs | Async/streaming/read-replica + tenant-scope rule, report-generation pattern, query-profile command, reporting reviewer |
| `scheduling` | calendar / availability / appointment tables, RRULE / iCal, slot generation, recurrence, timezone handling | Timezone-correct + recurrence-safe + conflict-free + DST-aware pattern, UTC+IANA-storage + RRULE-not-naive-add + transactional-no-double-book + DST-boundary rule, audit-scheduling command, scheduling reviewer |
| `search` | Elasticsearch / Algolia / Typesense / Meilisearch / pgvector | Indexing pattern, relevance-tuning runbook |
| `settings` | settings/preferences tables, config services, org/user settings UIs, env+db config merge | Typed-schema + precedence-resolved + validated + cache-safe layered-settings pattern, deterministic-precedence + validate-on-write + encrypt-secrets + scoped-invalidated-cache + audit-changes rule, audit-settings command, settings reviewer |
| `streaming-delivery` | HLS/DASH/CMAF manifests (`.m3u8`/`.mpd`), media-segment serving, `EXT-X-KEY` / DRM license endpoints, byte-range/`206` handlers, hls.js / Shaka / fluent-ffmpeg packaging-to-deliver, segment encryption/decryption (AES-128 / SAMPLE-AES / CENC) | Adaptive-delivery pattern (manifest + byte-range/206 + ABR + live-vs-VOD + cache/CORS) + encrypted-segment pattern (entitlement-gated key/license delivery, server-side-decrypt cleartext containment, per-scheme AES-128/SAMPLE-AES/CENC-DRM/clear-key, KMS key management), entitlement-gate + key-custody + cleartext-containment + range/cache-correctness rule, audit-streaming-delivery command, streaming-delivery reviewer |
| `subscriptions` | Stripe Billing / Paddle / Chargebee subscriptions, plan/price tables, recurring invoices, dunning | State-machine + server-derived-entitlements + proration + dunning rule, lifecycle pattern, simulate-renewal command, subscription reviewer |
| `webhook` | endpoints labelled "webhook", signature verification, replay-protection | Webhook receiver pattern, signature/idempotency rule |
| `workflow` | app-level state machines (xstate / aasm / spring-statemachine), status columns with transitions, approval flows | Explicit-transitions + guarded + idempotent + audited state-machine pattern, allowed-transition-table + optimistic-lock + transactional-side-effects + saga-compensation rule, audit-state-machine command, workflow reviewer |

## Registry (cataloged but generate-on-detection)

These keys are reserved. If a project triggers one and the folder is empty, Phase 4.5 generates the contents from external research + best practices and saves back to `~/.claude/templates/domains/<key>/` for reuse. Each entry notes the nearest implemented sibling it should NOT duplicate.

Infrastructure / platform shape:
- `event-driven` — broker-level pub/sub topology (distinct from app-level `workflow` + `event-sourced`)
- `workflow-orchestration` — distributed orchestration infra: Temporal / Cadence / Step Functions (distinct from app-level `workflow`)
- `mlops` — model training/serving/eval lifecycle (distinct from `data-pipeline` ETL and `ai` inference)
- `gitops` — declarative infra reconciliation (ArgoCD / Flux)
- `desktop-apps` — Electron / Tauri / native desktop concerns
- `developer-portal` — internal developer platform / service catalog

Engagement / content building blocks (mostly UGC + feature-shaped — generate when load-bearing):
- `comments` — threaded comments / mentions / reactions (pairs with `moderation`, `real-time`, `notifications`)
- `reviews-ratings` — review submission + aggregate scoring + fraud/abuse (pairs with `moderation`)
- `content-versioning` — drafts / revisions / optimistic-lock history (pairs with `audit-log`)
- `taxonomy` — tagging / categorization / hierarchical labels
- `activity-feed` — timeline / fan-out-on-write vs read (pairs with `notifications`, `real-time`)
- `recommendations` — personalization / ranking (pairs with `ai`, `analytics`, `ab-testing`)
- `onboarding` — setup wizards / checklists / progressive activation
- `cms` — content management / publishing workflow (pairs with `content-versioning`, `workflow`)

Identity / commerce extensions (some overlap implemented packs — generate only the gap):
- `user-team-management` — invites / roles / ownership transfer (extends `auth` + `multi-tenant`)
- `api-keys` — key issuance/rotation/scopes as a standalone concern (currently inside `public-api`)
- `invoicing` — invoice documents + numbering + tax lines (extends `payment` + `subscriptions` + `document-generation`)
- `tax` — VAT / sales-tax / e-invoicing calculation (extends `payment`)
- `gamification` — points / badges / streaks / leaderboards

> Note: purely product-vertical concepts (cart/checkout, catalog) live in `templates/business-domains/`, not here — this registry is for **cross-cutting technical signals** only.

## Maintenance

- **Adding a signal**: create `~/.claude/templates/domains/<key>/` with the 4 artifact subfolders + `_version.json`, then add a row above. Phase 4.0 preflight enforces presence.
- **Renaming**: never rename in place. Add the new key + leave the old one with `deprecated: true` (`replaced_by: <new-key>`) so Phase 0.2 extract can still read older installs.
- **Promoting a cataloged key to implemented**: move the row from the second table to the first.

## Relevance Filter (Appendix B in `commands/setup-project.md`)

This registry is consumed by Appendix B's Relevance Filter which decides — per project — which signals are load-bearing for the run. Phase 4.4 only applies signals classified as load-bearing.
