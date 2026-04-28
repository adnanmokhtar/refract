# Django rules

These rules are auto-applied when the `web-backend-django` track is selected. They sit alongside the universal `repo-baseline` rules; they do NOT replace them.

## File-layout rules

- New apps go under `apps/<name>/` (when project has ≥3 apps) — see Convention #1 of `ai/conventions/web-backend-django.md`.
- Migrations are NEVER deleted once applied to any deployed environment.
- `services.py` holds business logic; views and serializers stay thin.

## URL rules

- Each app's URLs are namespaced (`app_name = "..."`).
- Root `urls.py` includes app `urls.py`; never registers via `INSTALLED_APPS` alone.

## ORM rules

- `select_related` for ForeignKey traversal; `prefetch_related` for M2M / reverse FK. The N+1 problem is the #1 LLM-authored Django perf failure.
- Custom managers for filters used in 2+ places (`Model.objects.active()`).
- Never call `.all()` then filter in Python — push the predicate into the query.

## Migration rules

- Data migrations are explicitly named: `0042_backfill_user_tier.py`, never `0042_auto_*.py`.
- `python manage.py makemigrations --dry-run` before committing schema changes.
- Reversible by default; flag `irreversible_data_migration` when deliberately one-way.

## Async rules (when async views detected)

- `async def` views require an async URL pattern.
- Sync ORM calls inside async views go through `sync_to_async`.

## Test rules

- `pytest-django` if pytest is in use; do not mix with Django's TestCase runner.
- `@pytest.mark.django_db` for DB-touching tests; `TransactionTestCase` for cross-transaction tests.
- Mocking the ORM is forbidden — use a real test DB.

## Project-specific anchors

(Phase 4.6 anchors paths and base classes here from `.claude/_extracted-codebase.md`.)
