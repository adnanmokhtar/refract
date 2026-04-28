---
name: search-discipline
description: Search discipline
kind: rule
---

# Search discipline

Search is a denormalized cache outside your DB transactions. A bad query is a tenant leak; a bad index is hours of rebuild; a missing fallback is downtime. Rules below are non-negotiable.

## Tenant filter

- Every query has a tenant filter applied AT THE ENGINE — `filter: 'tenant_id = ...'` or equivalent. Engine has no concept of tenants; you are the only enforcer.
- Filter built from `TenantContext`, NEVER from request input.
- Query construction goes through a wrapper (`TenantScopedSearchClient`) that injects the filter; raw engine clients are forbidden in feature code.
- Cross-tenant search (admin/ops) lives in `*.admin-search.service.ts` for grep-ability.
- Cross-tenant test mandatory: seed two tenants, query as A, assert zero B documents in results.

## Index schema

- `tenant_id` field on every document, indexable + filterable.
- Indexable fields are MINIMAL — only what users actually search by.
- Fields you'll never filter / sort / search → not in the index. Each adds RAM + write throughput.
- `id` is stable + globally unique within an index — typically entity UUID; tenant filter handles isolation.
- `updated_at` field present for staleness diagnosis.
- PII in indexed fields ONLY if directly searchable (customer name yes, customer phone no). Search engines have weaker access controls than DB; minimize attack surface.

## Indexing strategy (write path)

- ASYNC indexing: DB write succeeds, indexer worker picks up, writes to engine. Hot path NEVER waits on engine.
- Outbox pattern OR domain-event subscriber feeds indexer queue (so DB rollback ≠ phantom index entry).
- Indexer worker idempotent — re-indexing same entity twice produces same final document.
- Entity DELETE → engine DELETE issued. Stale entries are a leak.
- Backfill / bulk-reindex script implemented + tested. Engine outage recovery and schema migrations require it.
- Indexer queue depth alerted — index lag = stale search results.

## Query construction

- Engine timeout set explicitly (`500-1000 ms` typical).
- Pagination limit capped (≤ 100). Deep paging via cursor, not offset (offset > 1000 is expensive on most engines).
- Faceting / aggregations limited to a declared facet set — no arbitrary user-supplied facets (data-volume DoS).
- User input sanitized for engine query syntax (`+`, `-`, `:`, parens) where engine treats them as operators.

## Ranking

- Ranking signals declared in ONE config file (`src/search/ranking.config.ts`).
- Standard signals: exact-match boost, popularity (sales/views), recency decay, explicit boost (promoted SKUs).
- Ranking changes require A/B test or before/after eval on golden query set (`/search-audit`).
- Inline boost numbers in feature code = silent drift.

## Locale + RTL

- Per-language tokenizer configured (Arabic, Chinese, Japanese, Thai have non-trivial tokenization).
- Stop words + stemming per locale.
- Multi-locale fields named explicitly: `name_en`, `name_ar`. Query targets the user's locale.
- RTL display: result rendering uses logical CSS properties (`margin-inline-start`), not `margin-left`.
- Fallback: query in user locale; if zero hits, fall back to canonical locale (configurable per index).

## Typo tolerance + synonyms

- Typo tolerance ON for queries ≥ 3 chars (engine-level: Meilisearch / Typesense default; Elastic via `fuzzy`).
- Typo tolerance OFF for short queries (1-2 chars) — too many false positives.
- Synonyms managed in a config file (`src/search/synonyms.json`); never inline.

## Fallback

- Every search call wrapped: try engine → on error → fallback (DB LIKE for simple queries OR explicit "search temporarily unavailable").
- Circuit breaker on engine — N consecutive failures → skip engine for cooldown window, jump straight to fallback.
- Engine outage NEVER 500s the page.

## Observability

- Per query: latency, hit count, engine error, tenant_id (or hash), query length.
- Metrics: queries/sec, p50/p95/p99 latency, cache hit rate (if you cache), engine error rate, indexer queue depth, index lag (DB write → search-visible).
- Alerts:
  - engine error rate > 1%;
  - p95 latency > SLA;
  - indexer queue depth growing > 5 min;
  - index lag > 60s;
  - search.fallback rate spike (engine struggling).

## Forbidden

- Query without tenant filter.
- Sync indexing in an HTTP handler.
- DB commit + engine write outside an outbox / commit hook.
- Query without engine timeout.
- No fallback when engine fails.
- PII in indexed fields beyond searchable need.
- Inline ranking boost numbers in feature code.
- User input passed raw into engine query DSL (escape / use proper API parameter).
- Cross-tenant search NOT in `*.admin-search.service.ts`.
- Wildcard searches (`*` prefix) without explicit allowlist of tenants/queries — full-index scan.
- Returning facets the user has no permission to see (e.g. counts of admin-only categories).
