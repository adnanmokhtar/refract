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
| `admin` | admin route namespaces / guards (`/admin`, `role=admin` / `is_staff`), impersonation / act-as, back-office frameworks (AdminJS / react-admin / Forest / Django admin) | Granular-capability + audited-action + safe-impersonation pattern, audit-every-action + least-privilege + reauth-for-destructive + bounded-blast-radius rule, admin-surface audit command, admin reviewer |
| `ai` | LLM SDKs, prompt templates, embeddings DBs, agent frameworks | LLM-call pattern, prompt-injection rules, eval patterns |
| `analytics` | product-analytics SDKs (Segment / Amplitude / Mixpanel / PostHog / GA), `track()` / `capture()` call-sites, event schemas / data layer | Typed-tracking-plan + consent-gated + idempotent-event pattern, PII-minimization + consent + no-ad-hoc-events + analytics-≠-audit-log rule, tracking-plan audit command, analytics reviewer |
| `audit-log` | append-only audit / activity tables, who-did-what records, immutable event trail | Tamper-evident append-only rule (hash-chain), audit-trail pattern, coverage+integrity verify command, audit-log reviewer |
| `auth` | auth libs (passport / next-auth / devise / spring-security), JWT/session middleware, password hashing (argon2/bcrypt), OAuth/OIDC clients, guards/RBAC | AuthN-vs-AuthZ architecture pattern, session/token/RBAC discipline rule, access-control (IDOR) audit command, auth reviewer |
| `background-jobs` | bull / sidekiq / celery / temporal / agenda / cron | Job pattern, retry/idempotency rules, queue agent |
| `caching` | cache clients (Redis / Memcached), CDN / `Cache-Control` / `ETag` config, `@Cacheable` / react-query / SWR | Cache-aside + stampede-protection pattern, scoped-key (no cross-tenant leak) + invalidate-on-write + bounded-jittered-TTL + fail-open rule, probe-cache command, caching reviewer |
| `compliance` | references to HIPAA / GDPR / PCI / SOC2 in code/docs/CI | Compliance-aware logging, PII handling rules |
| `event-sourced` | event-store / CQRS infra / projections | Aggregate pattern, projection rebuild runbook |
| `feature-flags` | LaunchDarkly / Unleash / Flagsmith / homegrown gates | Flag-introduction pattern, cleanup runbook |
| `file-upload` | multipart endpoints, S3/GCS SDKs, virus-scan hooks | Upload pattern, AV-scan rule, content-type allowlist |
| `i18n` | i18n libs (i18next / react-intl / formatjs / vue-i18n / gettext), locale catalogs, ICU messages, `t()` call-sites, `Accept-Language` | Message-catalog + ICU + locale-negotiation pattern, no-hardcoded-strings + CLDR-pluralization + locale-edge-formatting + RTL + translation-isn't-HTML rule, i18n-coverage scan command, i18n reviewer |
| `import` | bulk CSV/XLSX upload+parse endpoints, batch insert/upsert, parse libs (papaparse / xlsx / csv-parse), ingest jobs | Streamed-parse + per-row-validate + idempotent-tenant-scoped-upsert pattern, partial-failure-policy + cross-tenant-write + formula-injection + bounded-size rule, dry-run-import command, import reviewer |
| `media-processing` | image/video toolchains (sharp / ImageMagick / ffmpeg), transcode / thumbnail jobs, CDN image pipelines, EXIF handling | Validated sandboxed-async-transcode pipeline pattern, magic-byte-validation + resource/bomb-limits + codec-hardening (ImageTragick / ffmpeg-protocol) + EXIF-strip + signed-delivery rule, media-pipeline audit command, media reviewer |
| `multi-tenant` | tenant_id columns / row-level-security / per-tenant DB | Tenant isolation rule, query-scope agent, leak audit |
| `notifications` | email/SMS/push providers, template engines | Template + channel pattern, rate-limit rule |
| `payment` | Stripe / Paddle / Adyen / PSP SDKs, webhook signatures | PCI-aware pattern, idempotency rule, reconciliation runbook |
| `rate-limiting` | rate-limit middleware (express-rate-limit / @nestjs/throttler / rack-attack), Redis token buckets, 429 handlers | Algorithm + distributed-counter rule, limiter pattern, probe-limits command, rate-limit reviewer |
| `real-time` | websockets / SSE / WebRTC / pub-sub | Connection-lifecycle pattern, backpressure rule |
| `reporting` | report/export endpoints, CSV/XLSX generation, BI/analytics queries, scheduled report jobs | Async/streaming/read-replica + tenant-scope rule, report-generation pattern, query-profile command, reporting reviewer |
| `search` | Elasticsearch / Algolia / Typesense / Meilisearch / pgvector | Indexing pattern, relevance-tuning runbook |
| `subscriptions` | Stripe Billing / Paddle / Chargebee subscriptions, plan/price tables, recurring invoices, dunning | State-machine + server-derived-entitlements + proration + dunning rule, lifecycle pattern, simulate-renewal command, subscription reviewer |
| `webhook` | endpoints labelled "webhook", signature verification, replay-protection | Webhook receiver pattern, signature/idempotency rule |

## Registry (cataloged but generate-on-detection)

These keys are reserved. If a project triggers one and the folder is empty, Phase 4.5 generates the contents from external research + best practices and saves back to `~/.claude/templates/domains/<key>/` for reuse:

- `event-driven`
- `workflow-orchestration`
- `mlops`
- `gitops`
- `desktop-apps`
- `developer-portal`

## Maintenance

- **Adding a signal**: create `~/.claude/templates/domains/<key>/` with the 4 artifact subfolders + `_version.json`, then add a row above. Phase 4.0 preflight enforces presence.
- **Renaming**: never rename in place. Add the new key + leave the old one with `deprecated: true` (`replaced_by: <new-key>`) so Phase 0.2 extract can still read older installs.
- **Promoting a cataloged key to implemented**: move the row from the second table to the first.

## Relevance Filter (Appendix B in `commands/setup-project.md`)

This registry is consumed by Appendix B's Relevance Filter which decides — per project — which signals are load-bearing for the run. Phase 4.4 only applies signals classified as load-bearing.
