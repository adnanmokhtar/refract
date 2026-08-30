# `_review-decisions.md` — human verdicts on the `proposed` queue

**Read before both text signals.** A verdict here is final for its cell: the two proxies in
[`_review-matrix.md`](_review-matrix.md) §1 exist only to triage cells nobody has read, and a
cell that has been read is no longer a triage problem.

## What this resolved

All **242 `proposed` cells** — one text signal, no human read — were opened and judged
one surface at a time, reading each surface's material once and deciding every concern queued
against it. That ordering is not incidental: it is the same surface-major insight the
dispatcher uses, applied to the review of the index itself.

| Verdict | Count | Meaning |
|---|---|---|
| `confirmed` | 142 | the material makes a **checkable claim** about this concern on this surface |
| `empty` | 100 | the concern has a real shape here and nothing addresses it — **a gap** |

**The bar for `confirmed` was a checkable claim, not a mention.** A line that names the concern
while doing something else does not count: `payment × Authorization` reads `empty` because
"authorization" there means *holding funds*, not access control — a false friend the keyword
signals cannot see. Agent `description:` frontmatter and "cites `<path:line>`" boilerplate were
treated as noise wherever they were the only evidence, and they were the only evidence often.

> **This reopens the empty column, and that is the correct outcome.** The automated pass
> reported 0 empty; reading found **100 real gaps** it could not see. Automation closed the
> cells where a fingerprint was written; it could not tell a fingerprint from a passing mention.

---

## Verdicts

| Surface | Concern | Verdict | Reason |
|---|---|---|---|
| `_database` | C1  Security | `empty` | no rule on grants, row-level security, at-rest or backup encryption; matches are buffer tuning and join plans |
| `_database` | C3  Observability | `confirmed` | before/after metric is a halt condition — "no before-metric, no p95, no rows-scanned: halt" |
| `_database` | C4  Error Handling | `confirmed` | metadata-lock queueing and lock_wait_timeout / lock_timeout so an ALTER fails fast instead of building a queue |
| `_database` | C5  Logging | `empty` | slow-log appears only as an instrumentation source; nothing reviews query logs for PII or who-read-what |
| `_database` | C8  Authorization | `empty` | matches are row locks (SELECT FOR UPDATE), not authorization; no grant or RLS review |
| `_deployment` | C10 Versioning | `empty` | matches are object versioning and runtime inventory; nothing reviews N-1 rolling-deploy compatibility or config-schema change |
| `_deployment` | C12 Tenancy | `confirmed` | tenant_id required in structured logs, tenant-safe response caching, per-tenant cost dashboards |
| `_deployment` | C2  Performance | `confirmed` | RPS today + projected, latency SLO, CPU/memory shape, multi-region latency trade-off |
| `_deployment` | C4  Error Handling | `confirmed` | health checks per target, idle timeout above longest legitimate response, fail-closed admission policy, per-route retries and circuit breaking |
| `_deployment` | C5  Logging | `confirmed` | central sink, structured JSON with tenant_id + correlation_id required, egress logs captured |
| `_deployment` | C6  Configuration | `confirmed` | ConfigMap separate from Secret, no long-lived static keys baked into images, per-env infrastructure question |
| `_deployment` | C8  Authorization | `confirmed` | IAM least-privilege per service, never the default ServiceAccount, cluster-admin binding graded High |
| `_deployment` | C9  Idempotency | `confirmed` | cluster state reconciled from git, no manual apply against prod — declarative reconciliation is the idempotency mechanism |
| `_routes` | C1  Security | `confirmed` | SSRF egress allowlist before fetch, explicit field-allowlist bind against mass assignment |
| `_routes` | C6  Configuration | `confirmed` | env-diff skill compares .env to .env.example on the route surface |
| `_routes` | C7  Compliance | `confirmed` | error-envelope check asserts no stack or PII leak; rate limit required on export/report/bulk |
| `_routes` | C9  Idempotency | `confirmed` | failure-shape check names idempotency key, outbox, compensating action, reconcile job per multi-step path |
| `_screens` | C5  Logging | `empty` | matches are consent-banner and a11y text; nothing reviews console logging, SDK breadcrumbs or PII in error reports |
| `ab-testing` | C1  Security | `confirmed` | assignment must be a deterministic hash of experimentId+unit+salt from a server-authoritative unit, never Math.random |
| `ab-testing` | C10 Versioning | `confirmed` | analysis contract must be pre-registered and declared; exposure events route through the analytics contract |
| `ab-testing` | C12 Tenancy | `confirmed` | readout computed via the reporting layer tenant-scoped; a non-tenant-scoped readout is REQUEST_CHANGES |
| `ab-testing` | C3  Observability | `empty` | no exposure-count or SRM alerting discipline; matches are the agent's own description |
| `ab-testing` | C4  Error Handling | `confirmed` | an SRM mismatch quarantines the result — contain-on-failure, not proceed |
| `ab-testing` | C6  Configuration | `confirmed` | kill-switch: every experiment force-disabled to a safe control without a deploy |
| `ab-testing` | C7  Compliance | `empty` | no consent or regime material; matches are generic reviewer prose |
| `admin` | C1  Security | `confirmed` | a blanket is_admin gate is a BLOCKER; admin mutation with no audit record is a finding |
| `admin` | C11 Data Lifecycle | `confirmed` | impersonation session is time-boxed; reversible soft-delete with retention preferred over hard delete |
| `admin` | C12 Tenancy | `confirmed` | the admin surface acts on customer data across tenant lines — named as its core danger |
| `admin` | C4  Error Handling | `confirmed` | bulk actions carry a hard blast-radius cap, fail-closed on an over-broad filter |
| `admin` | C7  Compliance | `confirmed` | SELECT * into an admin view rendering raw PII inline is a named finding |
| `ai` | C10 Versioning | `confirmed` | cache key versioned (prompt-ctx:v<N>); cost computed from a versioned pricing table |
| `ai` | C12 Tenancy | `confirmed` | no PII in the prompt beyond what the tenant authorized; tenant context via a documented serializer |
| `ai` | C3  Observability | `confirmed` | every call traced with tenant_id/model/token counts; per-tenant cost alert wired to billing |
| `ai` | C4  Error Handling | `confirmed` | tenant-configured fallback on timeout rather than crash; rate limit plus circuit breaker on the external LLM |
| `ai` | C5  Logging | `confirmed` | contact info sent to an LLM is retained in provider logs; tokens tracked in logs which rotate, rows do not |
| `ai` | C6  Configuration | `confirmed` | tenant-configured fallback text and a documented context serializer |
| `ai` | C7  Compliance | `empty` | no regime or consent material for prompt data; matches are generic verdict prose |
| `ai` | C8  Authorization | `confirmed` | prompt may carry no PII beyond what the tenant authorized — an authorization boundary on context assembly |
| `analytics` | C1  Security | `confirmed` | an email/token/address in an event property sent to a third party is a privacy BLOCKER |
| `analytics` | C10 Versioning | `empty` | no event-schema evolution rule; the tracking plan is named but never versioned |
| `analytics` | C12 Tenancy | `confirmed` | tenant_id and identify() traits come from the verified server session, never the client |
| `analytics` | C2  Performance | `confirmed` | sampling with the rate labelled for downstream weighting; vendor slowness must not spike checkout latency |
| `analytics` | C3  Observability | `confirmed` | the pipeline itself is observable — event, consent, sampled, dedupKey, queuedAt, flushedAt |
| `analytics` | C4  Error Handling | `confirmed` | non-blocking buffered dispatch; a vendor outage cannot fail or slow the user's request |
| `audit-log` | C10 Versioning | `confirmed` | hash_version stored so historical hashes still reproduce after a serialization format change |
| `audit-log` | C11 Data Lifecycle | `confirmed` | retention and immutability are ask-conditions; WORM bucket named as the store shape |
| `audit-log` | C12 Tenancy | `empty` | emits carry actor and impersonator but nothing scopes trail READS per tenant |
| `audit-log` | C2  Performance | `empty` | durable+queryable is a storage-shape claim, not a cost-per-write or query-cost one |
| `audit-log` | C3  Observability | `empty` | matches are the agent's own description; no metric or alert on emission failure |
| `audit-log` | C7  Compliance | `confirmed` | named as the record of last resort for a breach, a dispute, or a regulator's request |
| `audit-log` | C8  Authorization | `confirmed` | an UPDATE/DELETE-capable audit table is a BLOCKER — write authority on the trail is the check |
| `auth` | C10 Versioning | `empty` | matches are code samples; no token-format or session-schema migration rule |
| `auth` | C11 Data Lifecycle | `confirmed` | revocation path required — jti blocklist, family revoke, or short TTL so logout and compromise invalidate |
| `auth` | C12 Tenancy | `empty` | prose says auth touches every tenant's data but no tenant-scoping check is stated |
| `auth` | C3  Observability | `confirmed` | structured auth events for login, logout, failed-login and lockout with outcome and correlationId |
| `auth` | C4  Error Handling | `confirmed` | absolute AND idle timeout both enforced; missing timeouts is a named finding |
| `auth` | C5  Logging | `confirmed` | never log the password, token, refresh token, OTP or reset token |
| `auth` | C6  Configuration | `confirmed` | pepper lives in KMS or env, never the DB |
| `auth` | C9  Idempotency | `confirmed` | state parameter verified on callback and OIDC nonce for id-token replay defence |
| `background-jobs` | C1  Security | `confirmed` | six greppable BLOCKER classes including secret-in-payload and non-idempotent money job |
| `background-jobs` | C10 Versioning | `empty` | no job-payload schema evolution rule; matches are code samples |
| `background-jobs` | C11 Data Lifecycle | `empty` | checkpointing is covered, retention of job records and payload archives is not |
| `background-jobs` | C12 Tenancy | `empty` | tenantId is logged but nothing requires the worker's own reads to be tenant-scoped |
| `background-jobs` | C2  Performance | `empty` | queue tech is detected but no cost-per-job or throughput budget is reviewed |
| `background-jobs` | C3  Observability | `confirmed` | DLQ existence AND monitoring are both checked |
| `background-jobs` | C5  Logging | `confirmed` | every job logs jobId, queueName, attempt, tenantId, duration_ms and terminal status |
| `background-jobs` | C6  Configuration | `confirmed` | attempts and backoff must be declared explicitly, never left to library defaults |
| `background-jobs` | C7  Compliance | `confirmed` | no PII, secrets, tokens or payment data in the payload — fetch by id inside the worker |
| `caching` | C1  Security | `confirmed` | unscoped shared keys named as the cross-tenant leak class |
| `caching` | C10 Versioning | `confirmed` | every scoped key namespaces tenant + visibility scope + a schema/version tag |
| `caching` | C3  Observability | `confirmed` | hit/miss/load-latency/stampede-suppressed/eviction metrics emitted per key prefix |
| `caching` | C5  Logging | `confirmed` | structured per-op log with keyPrefix, hit, loadMs, ttlMs, scope; alert on per-prefix hit-rate |
| `caching` | C6  Configuration | `empty` | the scope hash is key composition, not environment configuration; TTL config source unreviewed |
| `caching` | C8  Authorization | `confirmed` | key must carry the permission/visibility scope so a cached value cannot cross an authorization boundary |
| `compliance` | C1  Security | `confirmed` | hard delete OR cryptographic shredding — encrypt PII per subject, delete by dropping the key |
| `compliance` | C10 Versioning | `empty` | lawful-basis documentation is not a compatibility rule |
| `compliance` | C11 Data Lifecycle | `confirmed` | retention enforcement and deletion endpoints are the domain's stated subject |
| `compliance` | C12 Tenancy | `confirmed` | the purge job is required to be tenant-scoped |
| `compliance` | C3  Observability | `confirmed` | alert if zero purges for 7 days — a dead purge job is a monitored condition |
| `compliance` | C6  Configuration | `confirmed` | consent must be a stored record, not just a UI toggle |
| `compliance` | C9  Idempotency | `confirmed` | the purge job is required to be idempotent as well as tenant-scoped |
| `data-pipeline` | C2  Performance | `empty` | matches are the agent description; no per-stage cost or throughput budget |
| `data-pipeline` | C3  Observability | `empty` | "silently-wrong-capable" is prose; no row-count or freshness metric is required |
| `data-pipeline` | C5  Logging | `empty` | watermarking is covered; nothing reviews what pipeline logs contain or cost |
| `data-pipeline` | C6  Configuration | `empty` | PII classification is a compliance declaration, not environment configuration |
| `data-pipeline` | C7  Compliance | `confirmed` | PII classification must be declared before any lower-environment extract is approved |
| `document-generation` | C10 Versioning | `confirmed` | templateVersion recorded on every generation and download |
| `document-generation` | C11 Data Lifecycle | `confirmed` | artifact delivery via signed URL with an explicit 1h expiry |
| `document-generation` | C12 Tenancy | `confirmed` | download path is tenant-scoped — another tenant gets not-found, not forbidden |
| `document-generation` | C2  Performance | `confirmed` | unbounded font payload named as bloat plus egress cost |
| `document-generation` | C4  Error Handling | `empty` | no rule on a failed or timed-out render, or on partial-output cleanup |
| `document-generation` | C5  Logging | `confirmed` | generation and download audit-logged with actor, tenant, docType, templateVersion, contentHash |
| `document-generation` | C6  Configuration | `confirmed` | the renderer engine must be identifiable, not inferred |
| `document-generation` | C8  Authorization | `confirmed` | the download path re-authorizes on tenant and actor rather than trusting the signed URL alone |
| `document-generation` | C9  Idempotency | `empty` | nothing prevents a retried render from producing a second artifact for the same document |
| `event-sourced` | C10 Versioning | `empty` | event immutability is stated but no upcasting or event-schema evolution path is defined |
| `event-sourced` | C11 Data Lifecycle | `confirmed` | crypto-shredding is the deletion mechanism — encrypt PII payloads, delete by dropping the key |
| `event-sourced` | C2  Performance | `empty` | "permanence is the operating constraint" is framing; no snapshot or replay cost budget |
| `event-sourced` | C3  Observability | `confirmed` | every event carries correlationId and causationId alongside aggregate identity |
| `event-sourced` | C4  Error Handling | `confirmed` | one transaction equals one aggregate; cross-aggregate atomicity is a saga, i.e. compensation |
| `event-sourced` | C5  Logging | `confirmed` | append-only enforced at the schema — REVOKE UPDATE, DELETE on event store rows |
| `event-sourced` | C7  Compliance | `confirmed` | a GDPR delete may not be a DELETE FROM event_store; crypto-shredding is required instead |
| `event-sourced` | C9  Idempotency | `empty` | nothing requires projection handlers to be idempotent under replay |
| `feature-flags` | C1  Security | `empty` | "flags are technical debt" is a cost argument, not an exploitability one |
| `feature-flags` | C12 Tenancy | `confirmed` | targeting must use stable identifiers such as tenantId, never session id or IP |
| `feature-flags` | C3  Observability | `empty` | evaluations are logged but no metric or alert on default_used rate |
| `feature-flags` | C4  Error Handling | `confirmed` | evaluation must pass a fallback default literal rather than crash when the SDK cannot resolve |
| `feature-flags` | C5  Logging | `confirmed` | every evaluation logs flag_key, variant, target_id and default_used, sampled when hot |
| `feature-flags` | C6  Configuration | `confirmed` | declaration, rollout config and cleanup are the audited surface |
| `feature-flags` | C7  Compliance | `confirmed` | a flag gating compliance behaviour is a BLOCKER — compliance is environment, not a toggle |
| `feature-flags` | C8  Authorization | `empty` | matches are citation boilerplate; nothing checks who may flip a flag |
| `feature-flags` | C9  Idempotency | `empty` | cleanup reconciliation is not a replay-safety rule |
| `file-upload` | C10 Versioning | `empty` | bucket versioning is recoverability; no upload-contract or field compatibility rule |
| `file-upload` | C11 Data Lifecycle | `confirmed` | bucket versioning required for recoverability on any bucket holding user content |
| `file-upload` | C12 Tenancy | `confirmed` | the presign endpoint requires auth plus tenant scope |
| `file-upload` | C3  Observability | `confirmed` | infected uploads move to quarantine and alert security |
| `file-upload` | C4  Error Handling | `confirmed` | ingesting >10MB through the app causes memory pressure and timeouts — presigned PUT direct to storage instead |
| `forms` | C12 Tenancy | `confirmed` | the privileged-field model must declare which fields are server-set, tenantId among them |
| `forms` | C2  Performance | `empty` | matches are an example file path |
| `forms` | C3  Observability | `empty` | the credential-in-logs line is a logging finding; no metric on submission failure rate |
| `forms` | C4  Error Handling | `empty` | double-submit is treated as an idempotency failure; no rule on rendering a failed submission's state |
| `forms` | C5  Logging | `confirmed` | a credential reaching the observability pipeline is retained for the log TTL and named as a leak |
| `forms` | C7  Compliance | `empty` | no consent or regime material on collected form data |
| `forms` | C8  Authorization | `confirmed` | repo.create(req.body) named as the mass-assignment finding — which fields a caller may write |
| `i18n` | C1  Security | `empty` | no rule on translation-as-HTML injection or user-contributed strings; matches are the agent description |
| `i18n` | C10 Versioning | `empty` | catalog evolution and key-removal compatibility are not covered |
| `i18n` | C4  Error Handling | `empty` | a screen of raw keys is named as a symptom but no fallback-chain rule is stated |
| `i18n` | C5  Logging | `empty` | the no-literal-strings rule is not about logging; missing-key events are not logged |
| `import` | C11 Data Lifecycle | `empty` | checkpointing is covered; retention of uploaded source files and rejected rows is not |
| `import` | C5  Logging | `confirmed` | the import is audit-logged with actor, file hash, rows committed and rejected, and batch key |
| `import` | C7  Compliance | `empty` | matches are pointers to pattern docs, not a regime or consent rule |
| `import` | C8  Authorization | `empty` | the upsert merge rules are a correctness contract, not an authorization one |
| `integrations` | C10 Versioning | `confirmed` | the vendor's retry, rate-limit and webhook-signature contract must be declared, not inferred |
| `integrations` | C11 Data Lifecycle | `empty` | credential encryption is covered; retention of synced vendor data is not |
| `integrations` | C3  Observability | `confirmed` | last_synced_at per connection plus a drift metric make divergence measurable |
| `integrations` | C5  Logging | `confirmed` | no token, signing secret or full Authorization header may reach logs, errors or traces |
| `integrations` | C7  Compliance | `confirmed` | no raw PII payload may reach logs, errors or traces |
| `integrations` | C8  Authorization | `empty` | matches are citation boilerplate; no rule on which actor may create or use a connection |
| `ledger` | C10 Versioning | `empty` | matches are the agent description; no posting-schema evolution rule |
| `ledger` | C12 Tenancy | `empty` | matches are the agent description; nothing scopes postings or balances per tenant |
| `ledger` | C3  Observability | `confirmed` | a reconciliation job must exist, name its source of truth, and alert rather than auto-correct |
| `ledger` | C8  Authorization | `empty` | matches are the agent description; nothing states who may post an entry |
| `media-processing` | C10 Versioning | `empty` | codec inventory is not a compatibility rule; derived-variant format changes are unreviewed |
| `media-processing` | C12 Tenancy | `empty` | matches are the agent description; nothing scopes derived variants per tenant |
| `media-processing` | C2  Performance | `empty` | the match is "color-profile"; no transcode cost or concurrency budget is reviewed |
| `media-processing` | C3  Observability | `confirmed` | variant generation logs sourceHash, codec, inBytes, outBytes, durationMs and peakMemMB |
| `media-processing` | C4  Error Handling | `empty` | a failed or partial transcode has no stated cleanup or retry contract |
| `media-processing` | C6  Configuration | `empty` | matches are citation boilerplate; codec limits as configuration are not reviewed |
| `media-processing` | C8  Authorization | `empty` | bomb guards are resource limits, not an authorization boundary |
| `media-processing` | C9  Idempotency | `confirmed` | a transcode triggered on every webhook retry with no idempotency key on the source hash is a named finding |
| `moderation` | C10 Versioning | `empty` | action attribution is not a compatibility rule; the action enum's evolution is unreviewed |
| `moderation` | C11 Data Lifecycle | `confirmed` | known-illegal-content policy must declare the hash corpus and the mandatory-reporting/retention obligation |
| `moderation` | C3  Observability | `empty` | "trace each ingress" means map the path, not emit telemetry; no queue-depth or scan-failure metric |
| `moderation` | C4  Error Handling | `empty` | no rule for a scanner outage — whether content is held or served unscanned |
| `moderation` | C8  Authorization | `confirmed` | the moderator authorization model must be declared — scoped capability versus broad admin |
| `moderation` | C9  Idempotency | `empty` | nothing prevents a replayed report or a re-applied ban from double-acting |
| `multi-tenant` | C1  Security | `confirmed` | scans for queries without a tenant_id filter and cache keys without a tenant segment |
| `multi-tenant` | C10 Versioning | `empty` | the shared-DB row-level model is stated but tenant-schema evolution is unreviewed |
| `notifications` | C1  Security | `empty` | the email-to-SMS fallback is a reliability rule, not an exploitability one |
| `notifications` | C10 Versioning | `empty` | matches are a code sample; template and payload compatibility are unreviewed |
| `notifications` | C12 Tenancy | `confirmed` | per-user-per-channel caps are configurable per tenant |
| `notifications` | C3  Observability | `empty` | the fallback rule is not telemetry; no delivery-failure or bounce-rate metric is required |
| `notifications` | C4  Error Handling | `confirmed` | fail-closed when a locale is missing rather than sending default English; defined channel fallback on bounce |
| `notifications` | C6  Configuration | `confirmed` | sender domain config (SPF/DKIM/DMARC, transactional vs marketing split) must be declared in IaC or env |
| `notifications` | C7  Compliance | `confirmed` | preference bypass is the named catch — consent and opt-out are the reviewed surface |
| `notifications` | C9  Idempotency | `empty` | provider identification is not a replay rule; nothing dedups a resent notification |
| `payment` | C10 Versioning | `empty` | provider identification is not a compatibility rule |
| `payment` | C11 Data Lifecycle | `confirmed` | TTL on the stored idempotency key must be at least 24h to match the provider's own window |
| `payment` | C3  Observability | `empty` | the single-source-of-truth refund rule is not telemetry; no settlement-drift metric |
| `payment` | C4  Error Handling | `confirmed` | failed authentication means no charge — the server must not retry without re-authentication |
| `payment` | C5  Logging | `confirmed` | any PAN, CVV or track data reaching our systems breaks SAQ-A scope |
| `payment` | C8  Authorization | `empty` | "authorization" here means holding funds, not access control — a false friend, and no actor check is stated |
| `public-api` | C12 Tenancy | `empty` | matches are a code sample, not a rule |
| `public-api` | C2  Performance | `confirmed` | very large exports route to the async-job plus streaming contract, never a synchronous page loop |
| `public-api` | C3  Observability | `empty` | the external contract gate covers deprecation and overexposure, not telemetry |
| `public-api` | C4  Error Handling | `empty` | the Idempotency-Key rule is replay safety; no error-envelope or partial-failure contract here |
| `public-api` | C5  Logging | `empty` | matches are the gate's own description |
| `public-api` | C7  Compliance | `empty` | overexposure is a contract concern; no regime, consent or data-sharing-terms rule |
| `rate-limiting` | C1  Security | `confirmed` | the limiter is wrong until proven atomic, shared and per-identity — an in-memory counter behind a load balancer fails all three |
| `rate-limiting` | C10 Versioning | `empty` | matches are a code sample; limit changes as a breaking change for clients are unreviewed |
| `rate-limiting` | C2  Performance | `confirmed` | an export streaming the whole table with no cost weight and no concurrency cap is a named finding |
| `rate-limiting` | C3  Observability | `confirmed` | fail-open invocations are metered and alertable — a spike is an incident |
| `rate-limiting` | C4  Error Handling | `confirmed` | fail-open is the declared behaviour when the limiter backend is unavailable, and it is metered |
| `rate-limiting` | C6  Configuration | `confirmed` | limiter config is part of the reviewed surface |
| `rate-limiting` | C7  Compliance | `empty` | the sensitive-endpoint inventory is a security scope, not a regulatory one |
| `rate-limiting` | C8  Authorization | `empty` | guard ordering is placement, not an authorization boundary |
| `rate-limiting` | C9  Idempotency | `empty` | RateLimit-* headers are client guidance, not replay safety |
| `real-time` | C11 Data Lifecycle | `empty` | no retention rule for message buffers, presence data or session transcripts |
| `real-time` | C12 Tenancy | `empty` | connection auth is named but nothing scopes a subscription's topic per tenant |
| `real-time` | C2  Performance | `confirmed` | server-side coalescing drops intermediate updates when the client is behind |
| `real-time` | C3  Observability | `confirmed` | per-client buffer depth metric with an alert on sustained threshold breach |
| `real-time` | C4  Error Handling | `confirmed` | reconnect handling is an inspected path rather than assumed |
| `real-time` | C5  Logging | `confirmed` | a token in the URL leaks via referrer, server log, browser history and proxy log |
| `real-time` | C6  Configuration | `confirmed` | single-node versus multi-node must be declared — Redis adapter or sticky-session config visible |
| `real-time` | C8  Authorization | `confirmed` | the credential moves to an Authorization header on first frame rather than riding in the URL |
| `real-time` | C9  Idempotency | `confirmed` | reconnects identified by session-resume token and missed messages replayed from a per-session buffer |
| `reporting` | C1  Security | `confirmed` | a report bug is named as a melted primary database or a cross-tenant leak |
| `reporting` | C10 Versioning | `empty` | SELECT * overexposure is a contract-shape finding, not a compatibility one |
| `reporting` | C11 Data Lifecycle | `confirmed` | artifact store privacy, signed download URLs with expiry, and a cleanup TTL are all confirmation points |
| `reporting` | C3  Observability | `empty` | matches are the agent description; no query-cost or export-duration metric |
| `reporting` | C4  Error Handling | `empty` | read topology is identified but no rule for a report that times out or partially fails |
| `reporting` | C5  Logging | `confirmed` | export access audit-logged with actor, tenant, columns, row count and as-of, before the link is issued |
| `reporting` | C8  Authorization | `empty` | matches are the agent description; nothing states who may run which report |
| `reporting` | C9  Idempotency | `confirmed` | any report over ~1s must run as an asynchronous idempotent job |
| `scheduling` | C10 Versioning | `empty` | timezone rendering is not a compatibility rule; recurrence-rule changes on existing bookings are unreviewed |
| `scheduling` | C4  Error Handling | `empty` | the cron re-run is described as a duplicate-insert, i.e. an idempotency failure, with no error-path rule |
| `scheduling` | C8  Authorization | `empty` | the concurrency arbiter is a correctness guard, not an authorization one |
| `search` | C1  Security | `confirmed` | query strings hashed rather than stored raw when they may carry PII |
| `search` | C10 Versioning | `empty` | index mapping changes and reindex compatibility are unreviewed |
| `search` | C12 Tenancy | `confirmed` | the engine has no concept of tenant — every query MUST carry the scope filter |
| `search` | C2  Performance | `confirmed` | synchronous indexing binds handler latency to engine availability |
| `search` | C3  Observability | `confirmed` | queries/sec, p50/p95/p99 latency, cache hit rate and engine error rate are required metrics |
| `search` | C4  Error Handling | `confirmed` | the engine's _shards.failed is treated as a partial-failure signal, not success |
| `search` | C6  Configuration | `empty` | the denormalized-cache framing is not a configuration rule |
| `search` | C7  Compliance | `confirmed` | search engines have weaker access controls than the DB, so indexed PII must be minimized |
| `search` | C8  Authorization | `confirmed` | same weaker-access-control premise drives what may be indexed at all |
| `search` | C9  Idempotency | `confirmed` | the indexer is idempotent — re-indexing the same entity twice yields the same final document |
| `settings` | C11 Data Lifecycle | `confirmed` | retention is itself a security-sensitive setting requiring a server-side authz check on write |
| `settings` | C12 Tenancy | `confirmed` | org/workspace policy is the reviewed surface — settings resolve per tenant scope |
| `settings` | C8  Authorization | `confirmed` | the reviewer confirms how security-sensitive writes are authorized and where change audit is written |
| `streaming-delivery` | C11 Data Lifecycle | `empty` | matches are the agent description; no retention rule for segments, manifests or issued licences |
| `streaming-delivery` | C5  Logging | `empty` | matches are the agent description; the key-in-logs grep is a secret check, not a logging-content rule |
| `streaming-delivery` | C6  Configuration | `confirmed` | the key source must be located — KMS or secret-manager fetch versus a literal, env or committed key |
| `subscriptions` | C1  Security | `empty` | "a recurring bug mis-bills every cycle" is a correctness framing, not an exploitability one |
| `subscriptions` | C10 Versioning | `confirmed` | trial length, card-required and conversion behaviour must be explicit per plan |
| `subscriptions` | C3  Observability | `confirmed` | reconciliation cron diffs local against provider and alerts on drift |
| `subscriptions` | C4  Error Handling | `empty` | provider identification is not a failure-path rule; dunning retry exhaustion is unreviewed here |
| `subscriptions` | C5  Logging | `confirmed` | unknown provider event types are logged and acked 200 rather than silently dropped |
| `subscriptions` | C7  Compliance | `empty` | mis-billing is a correctness harm; no tax, invoicing or consumer-rights regime is named |
| `subscriptions` | C9  Idempotency | `confirmed` | subscription state, cycles and plan changes are the reviewed surface against duplicate provider events |
| `webhook` | C12 Tenancy | `confirmed` | per-tenant signing secret with a rotation surface in the tenant dashboard |
| `webhook` | C3  Observability | `confirmed` | window drift is logged and raises an ops alert — clock skew or an actual replay attack |
| `webhook` | C4  Error Handling | `confirmed` | without idempotency, signature verification and fast ack an externally-controlled retry storm compounds |
| `webhook` | C5  Logging | `confirmed` | a signature mismatch logs source IP, endpoint and signature PREFIX only — never the full signature |
| `webhook` | C6  Configuration | `empty` | the retry-storm framing is not a configuration rule; endpoint and secret configuration is unreviewed |
| `webhook` | C8  Authorization | `empty` | signature verification authenticates the sender; nothing states which tenant a verified payload may act on |
| `workflow` | C1  Security | `empty` | deadlines on waiting states are a liveness rule, not an exploitability one |
| `workflow` | C10 Versioning | `empty` | matches are citation boilerplate; migrating in-flight instances across a transition-table change is unreviewed |
| `workflow` | C11 Data Lifecycle | `empty` | matches are the agent description; retention of completed instances and transition history is unreviewed |
| `workflow` | C2  Performance | `empty` | the match is an optimistic-lock UPDATE example, not a cost or throughput rule |
| `workflow` | C3  Observability | `confirmed` | every transition writes who, when, from-to, reason and correlation-id in the SAME transaction as the state change |
| `workflow` | C7  Compliance | `empty` | unreachable illegal states are a correctness guarantee, not a regulatory one |

