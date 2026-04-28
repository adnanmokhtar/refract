# FastAPI (Python) reference

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

## Anti-patterns

- Mixing sync and async DB calls within the same endpoint
- Returning ORM models directly (use pydantic response_model)
- Business logic in routers
- Using `print` — use `logging` with structured format
