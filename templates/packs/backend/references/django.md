# Django / Django REST Framework reference

> **Framework**: Django 5.0+ • DRF 3.15+ on Python 3.10+
> **Official docs**: https://docs.djangoproject.com/en/5.0/ • https://www.django-rest-framework.org/
> **Version-specific gotchas**: Django 5 dropped Python 3.9; `USE_TZ = True` is the new default; async ORM operations stable in 5.1+; DRF 3.15 changed `pagination_class` defaults; `default_auto_field = "django.db.models.BigAutoField"` required for new projects.
> **Substitution markers**: Replace `<name>` with the project's actual app name from `_extracted-idioms.md`.

## Structure

```
project/
├── project/                  # settings, urls, wsgi
├── apps/
│   └── <name>/
│       ├── models.py
│       ├── serializers.py    # DTOs (DRF)
│       ├── views.py          # viewsets / apiviews
│       ├── services.py       # business logic
│       ├── urls.py
│       ├── admin.py
│       └── tests.py
└── manage.py
```

## Rules

- DRF `ModelViewSet` for full CRUD; custom `APIView` or `GenericAPIView` for custom flows.
- Serializers validate AND shape responses — one file per entity is fine.
- Business logic belongs in `services.py`, NOT in viewsets or serializers.
- Custom managers / querysets for reusable filters (e.g., `objects.active()`).
- Migrations are auto-generated (`makemigrations`) — review before committing.
- Permissions classes for auth; don't hand-roll per-view checks.

## Data

- Use `select_related` / `prefetch_related` to avoid N+1 on the queryset level.
- Indexes via `class Meta: indexes = [...]`.
- Soft delete: use `django-safedelete` or a custom manager; NEVER forget the filter.

## Resilience, streaming & conditional requests

> Cross-pack hooks (do NOT duplicate the policy): outbound resilience / stored-idempotency-replay → `distributed-systems`; `SELECT *` / over-fetch on the streamed cursor → `database`; RED metrics / OTel spans around jobs + streams → `observability`.

- **Rate limiting** → [rate-limiting.md](../ai-patterns/rate-limiting.md). Use DRF `ScopedRateThrottle` (per-`throttle_scope` buckets) or `django-ratelimit`; emit `429 Too Many Requests` (RFC 6585) + `Retry-After` (RFC 9110 §10.2.3) + unprefixed `RateLimit-Limit/Remaining/Reset` (IETF draft-ietf-httpapi-ratelimit-headers — a DRAFT, not an RFC; prefer over legacy `X-RateLimit-*`).
  - Detector — `django.md:rate-throttle-backend`: a throttle class configured with the default `LocMemCache` `CACHES` backend → counts are per-process and reset on worker recycle, so the limit silently multiplies by worker count. **Fix**: point throttling at a shared store, e.g. `CACHES["default"]["BACKEND"] = "django.core.cache.backends.redis.RedisCache"`, and decide FAIL-OPEN vs FAIL-CLOSED on cache outage. **Closure**: assert a single shared cache backend backs every throttle scope.

- **Conditional requests** → [conditional-requests.md](../ai-patterns/conditional-requests.md). Read revalidation via `@condition(etag_func=…, last_modified_func=…)` (`django.views.decorators.http`) or set `ETag` on the DRF `Response`; `If-None-Match` match → `304 Not Modified`. Writes carry `If-Match`: mismatch → `412 Precondition Failed`, absent on a concurrency-guarded write → `428 Precondition Required` (all RFC 9110, obsoletes RFC 7232).
  - Detector — `django.md:lost-update-write`: a mutating `update()`/`save()` view with no `If-Match` gate → last-writer-wins clobbers concurrent edits. **Fix**: compute the row ETag (version/`updated_at`) in the view, compare against `request.headers["If-Match"]`, return `412`/`428` before persisting. **Closure**: assert every concurrency-sensitive write rejects a stale/absent `If-Match`.

- **Streaming** → [response-streaming.md](../ai-patterns/response-streaming.md). Unbounded results stream via `StreamingHttpResponse` over a generator (NDJSON, `content_type="application/x-ndjson"`); SSE uses the same response with `content_type="text/event-stream"`. Drive the generator from `queryset.iterator(chunk_size=…)` (server-side cursor), never `.all()` (materializes the whole table in memory). Emit a terminal error sentinel mid-stream — a `200` is already committed, so a late failure cannot become a `5xx`. Chunked transfer + trailers per RFC 9112.
  - Detector — `django.md:stream-eager-queryset`: a `StreamingHttpResponse` generator iterating `Model.objects.all()` / a list-materialized queryset → defeats streaming, loads everything before the first byte. **Fix**: switch to `.iterator(chunk_size=2000)` and yield per row; guard the generator body so a mid-stream exception writes a `{"error": …}` sentinel line, not a silent truncation. **Closure**: assert the streamed source is a cursor iterator and a sentinel terminates the partial stream.

- **Async job offload** → [async-job-offload.md](../ai-patterns/async-job-offload.md). Long work enqueues to Celery / RQ / Dramatiq and returns `202 Accepted` + `Location:` pointing at a status view; the status view exposes the job-status state machine (`queued → running → succeeded | failed`) and serves the result from a TTL'd store. Make submit idempotent — key the task on a client `Idempotency-Key` so a retried POST returns the same job, not a duplicate.
  - Detector — `django.md:sync-blocking-view`: a request handler doing report/export/bulk work inline (no `.delay()`/`.enqueue()`) → ties up the WSGI worker and risks gateway timeout. **Fix**: enqueue the task, return `202` + `Location` to a `JobStatusView`, persist `task_id` keyed by idempotency key. **Closure**: assert the endpoint returns `202` with a dereferenceable status URL and a duplicate submit yields the same job id.

## Anti-patterns

- Fat viewsets with business logic
- Raw SQL when ORM would work
- Forgetting `select_related` on serializer foreign keys (N+1)
- Bypassing permissions with `AllowAny` on sensitive endpoints
