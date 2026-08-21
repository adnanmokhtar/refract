# Flask (Python) reference

> **Framework**: Flask 3.0+ on Python 3.9+ • SQLAlchemy 2.0+ • Alembic
> **Official docs**: https://flask.palletsprojects.com/en/3.0.x/
> **Version-specific gotchas**: Flask 3 dropped Python < 3.8; SQLAlchemy 2.0 changed query API (`Session.execute(select(...))` instead of `Model.query`) — Flask-SQLAlchemy 3.1+ tracks this; async views run in threadpool, NOT true async (use Quart for that).
> **Substitution markers**: Replace `<name>` with the project's actual module name.

For small APIs / internal tools. For larger services consider FastAPI (async, typed) or Django.

## Structure

```
app/
├── __init__.py            # create_app() factory
├── config.py
├── extensions.py          # SQLAlchemy, Migrate, JWT, etc.
├── modules/
│   └── <name>/
│       ├── __init__.py    # Blueprint registration
│       ├── routes.py      # endpoints
│       ├── services.py    # business logic
│       ├── models.py      # SQLAlchemy
│       └── schemas.py     # marshmallow / pydantic
└── common/
    ├── errors.py
    └── middleware.py
wsgi.py                    # prod entrypoint
```

## Rules

### App factory pattern
```python
def create_app(config_name='production'):
    app = Flask(__name__)
    app.config.from_object(config[config_name])
    
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    
    register_blueprints(app)
    register_error_handlers(app)
    return app
```

NEVER use the default `app = Flask(__name__)` at module scope for production — it breaks testing + configuration.

### Blueprints
- One blueprint per module.
- URL prefix per blueprint: `products_bp = Blueprint('products', __name__, url_prefix='/products')`.
- Register blueprints explicitly in `create_app`.

### Validation
- **marshmallow** or **pydantic** schemas.
- `@validate()` decorator (from `flask-pydantic`) or `schema.load()` manually.
- Return 422 on validation errors via error handler.

### Database
- **Flask-SQLAlchemy** for ORM.
- **Flask-Migrate** (Alembic wrapper) for migrations.
- `db.session` scope: request-scoped automatically.
- NEVER use `scoped_session` manually in Flask — extension handles it.

### Errors
- Custom exception classes in `common/errors.py`.
- Global error handler maps to JSON responses:

```python
@app.errorhandler(DomainError)
def handle_domain_error(error):
    return jsonify({'code': error.code, 'message': str(error)}), error.status_code
```

### Auth
- **Flask-JWT-Extended** for JWT.
- `@jwt_required()` decorator on protected routes.
- Never roll your own — Flask ecosystem is mature.

### Async (if needed)
- Flask 2.0+ supports `async def` endpoints but they run in a threadpool (not true async).
- For true async: use **Quart** (Flask-compatible, ASGI-native) or **FastAPI**.

## Resilience, streaming, conditional requests & pagination

> Flask-idiomatic wiring for the cross-cutting HTTP patterns. Each maps to a sibling ai-pattern that owns the policy; this section is the framework hook only.

- **Rate limiting** — `flask-limiter`: `Limiter(key_func=get_remote_address, app=app)` + `@limiter.limit("100/minute")` per route (or `default_limits`). Its default `memory://` storage is per-process — behind `gunicorn --workers N` each worker keeps its own counter and the real limit is `N × limit`; set `storage_uri="redis://…"` (shared) for any multi-worker deploy. Enable draft headers (`RATELIMIT_HEADERS_ENABLED = True`) so it emits `Retry-After` + a `RateLimit-*` set on the `429` — which set depends on the flask-limiter version, so check it. The current IETF draft (`draft-ietf-httpapi-ratelimit-headers`, still a DRAFT) defines only two fields — `RateLimit-Policy: "default";q=100;w=60` and `RateLimit: "default";r=0;t=30`; add them yourself if the version emits the older `RateLimit-Limit/Remaining/Reset` triple, and keep the triple alongside only while clients still read it. → `ai-patterns/rate-limiting.md`.
- **Conditional requests** (RFC 9110) — reads: `response.set_etag(tag)` then `response.make_conditional(request)` (Werkzeug) handles `If-None-Match` → `304` and Range for you; `send_file(...)` sets an ETag + `make_conditional` automatically. Writes: gate on `If-Match` manually — missing on an unsafe method → `abort(428)` (Precondition Required), stale tag → `abort(412)` (Precondition Failed); this is optimistic concurrency over HTTP, pair it with a `version` column, not a DB lock. → `ai-patterns/conditional-requests.md`.
- **Streaming** — `Response(stream_with_context(generator()), mimetype="application/x-ndjson")` for unbounded result sets (yield one JSON object + `\n` per row), or `mimetype="text/event-stream"` for SSE. `stream_with_context` keeps the request/app context alive inside the generator. Note: a sync WSGI worker is pinned for the whole stream — use `gevent`/`eventlet` workers (or Quart) so long streams don't starve the pool. End with a terminal sentinel; you cannot change the already-sent `200` mid-stream. → `ai-patterns/response-streaming.md`.
- **Async job offload** — for work beyond a request budget enqueue to **Celery** / **RQ** and return `202 Accepted` + `Location: /jobs/<id>`; expose `GET /jobs/<id>` as the status state machine (`queued → running → succeeded|failed`, result URL + TTL when done). Don't run heavy work in the handler (or an unsupervised thread) — no status, no retry, dies with the worker. → `ai-patterns/async-job-offload.md`.
- **Pagination** — cursor/keyset by default: SQLAlchemy 2.0 `select(Model).where(tuple_(Model.created_at, Model.id) < (c, i)).order_by(Model.created_at.desc(), Model.id.desc()).limit(limit)` — the row-value predicate matches the (unique, tiebroken) sort. Apply a default limit and a hard cap; fetch `limit + 1` for `hasMore` instead of `COUNT(*)`. Flask-SQLAlchemy's `db.paginate()` / `.limit().offset()` is offset-based — fine for small quiescent admin tables, but it re-scans on deep pages and skips rows under concurrent writes, so keep it off hot/growing tables. → `ai-patterns/pagination.md`.

## WSGI vs ASGI

- Production WSGI server: **gunicorn** + **gevent** or **uvicorn workers**.
- Example: `gunicorn --workers 4 --worker-class gevent wsgi:app`.
- Behind nginx / ingress for TLS + static files.

## Testing

- pytest + `app.test_client()`.
- Factories (factory-boy) for test data.
- Separate test DB, wipe between tests.

## Observability

- `flask-logging` + structured formatter for structured logs.
- Prometheus: **prometheus-flask-exporter**.
- OpenTelemetry: `opentelemetry-instrumentation-flask`.

## Anti-patterns

- Global state in request handlers.
- Business logic in routes.
- Returning SQLAlchemy models directly (always serialize via schema).
- `debug=True` in production.
- `app.run()` in production (use gunicorn / uvicorn).
- Forgetting `db.session.rollback()` on exception (leaks transactions).
- Long-running tasks in request handlers (use Celery / RQ / arq).
