# FastAPI (Python) reference

> **Framework**: FastAPI 0.110+ on Python 3.10+ • pydantic v2 (BREAKING change vs v1)
> **Official docs**: https://fastapi.tiangolo.com/
> **Version-specific gotchas**: pydantic v2 changed `.dict()` → `.model_dump()`, `Config` class → `model_config = ConfigDict(...)`, validators use `@field_validator` (not `@validator`); FastAPI 0.100+ requires pydantic v2.
> **Substitution markers**: Replace `<name>` with the project's actual module name from `_extracted-idioms.md`.

## Structure

```
app/
├── main.py                   # FastAPI() app
├── core/
│   ├── config.py             # pydantic settings
│   ├── security.py
│   └── deps.py               # shared dependencies
├── modules/
│   └── <name>/
│       ├── router.py         # APIRouter with endpoints
│       ├── service.py        # business logic
│       ├── repository.py     # SQLAlchemy / motor
│       ├── schemas.py        # pydantic Schemas (DTOs)
│       ├── models.py         # ORM models
│       └── dependencies.py
└── tests/
```

## Rules

- Endpoints declared on `APIRouter`; register routers in `main.py`.
- Use pydantic `BaseModel` for every request/response — validation is automatic.
- Dependencies via `Depends(...)` — auth, db session, current user.
- Async endpoints when the route hits async I/O; sync is fine for CPU-bound or sync libs.
- Use `HTTPException` for error responses; custom exception handlers for domain errors.
- `response_model=` on every endpoint — don't let ORM objects leak.

## Resilience, streaming & conditional requests

> See sibling ai-patterns for the contract each one implements: `ai-patterns/rate-limiting.md`, `ai-patterns/conditional-requests.md`, `ai-patterns/response-streaming.md`, `ai-patterns/async-job-offload.md`.

- **Rate limiting** — use `slowapi` (`Limiter` + `@limiter.limit("100/minute")`, attach `app.state.limiter` + the `_rate_limit_exceeded_handler`) or `fastapi-limiter` (Redis-backed). The store MUST be shared (Redis), never in-process `slowapi` default storage — with multiple Uvicorn/Gunicorn workers each worker keeps its own counter and the real limit becomes `limit × workers`. Emit `Retry-After` (RFC 9110 §10.2.3) on the 429 (RFC 6585) plus the two quota fields the current IETF draft defines — `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30` (`draft-ietf-httpapi-ratelimit-headers` — a DRAFT, not an RFC); add them in the rate-limit exception handler. The `RateLimit-Limit/Remaining/Reset` triple is draft-05 legacy — emit it alongside only while clients still read it. → `ai-patterns/rate-limiting.md`.
- **Conditional requests** (RFC 9110) — for cacheable reads compute a strong/weak ETag and set `response.headers["ETag"] = etag`; if `request.headers.get("if-none-match") == etag` return `Response(status_code=304)` (empty body, keep the `ETag`). For writes, gate on `If-Match`: missing → `Response(status_code=428)` (Precondition Required), stale → `412` (Precondition Failed) — this is optimistic concurrency over HTTP, not a DB lock. → `ai-patterns/conditional-requests.md`.
- **Streaming** — return `StreamingResponse(async_gen(), media_type="application/x-ndjson")` for unbounded result sets (one JSON object + `\n` per line), or `EventSourceResponse(async_gen())` from `sse-starlette` for SSE. Because the route `await`s the async generator, a slow client gives natural backpressure; check `await request.is_disconnected()` inside the loop to cancel server work when the client hangs up. Emit a terminal error sentinel as the last record (you cannot change the already-sent `200` status mid-stream). → `ai-patterns/response-streaming.md`.
- **Async job offload** — for work longer than a request budget, enqueue to `Celery` / `arq` / `Dramatiq` and return `Response(status_code=202, headers={"Location": f"/jobs/{job_id}"})`; expose a `GET /jobs/{id}` status route (`queued → running → succeeded/failed`, result URL + TTL when done). `BackgroundTasks` is fire-and-forget (runs in-process after the response, dies with the worker, no status, no retry) — NOT a tracked job. → `ai-patterns/async-job-offload.md`.

> **Error contract**: raise structured errors as `application/problem+json` (Problem Details, RFC 9457 — obsoletes 7807) via a custom exception handler returning `JSONResponse(..., media_type="application/problem+json")`; the `type` is a stable dereferenceable URI per error class, not the human `title`.
> **Adjacent-pack hooks** (detect + point, don't duplicate): unbounded streaming/job repository queries are a `SELECT *` / over-fetch smell → see the database pack; outbound calls inside a job (retry/timeout/DLQ, stored idempotency keys for the submit endpoint) are owned by the distributed-systems pack; per-stream/per-job RED metrics + trace propagation belong to the observability pack.

## Pagination

> No built-in paginator — use `fastapi-pagination` (cursor support) or hand-wire keyset in the repository. → `ai-patterns/pagination.md`.

- **Cursor-first (keyset)** — prefer a `cursor` + `limit` query over `offset`/`skip`; keyset is O(log n) and stable under writes, offset rescans and skips/dupes rows on a hot table.
- **Bounded limit** — declare `limit: int = Query(20, ge=1, le=100)` so pydantic/FastAPI validates and caps the page size at the schema boundary; never read an unbounded page size.
- **SQLAlchemy row-value keyset** — translate the cursor to a tuple comparison matching the sort: `.where(tuple_(Model.created_at, Model.id) < (c, i)).order_by(Model.created_at.desc(), Model.id.desc()).limit(limit)`.
- **Stable, unique sort** — always append the PK tiebreaker; a bare `order_by(created_at)` is non-total and shuffles rows between pages.
- **Opaque cursor, no count** — encode `{created_at, id}` as a base64 cursor; fetch `limit + 1` for `hasMore` instead of a per-page `func.count()`; return `{ data, meta: { nextCursor, hasMore } }`.

## Anti-patterns

- Mixing sync and async DB calls within the same endpoint
- Returning ORM models directly (use pydantic response_model)
- Business logic in routers
- Using `print` — use `logging` with structured format
