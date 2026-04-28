# Flask (Python) reference

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
