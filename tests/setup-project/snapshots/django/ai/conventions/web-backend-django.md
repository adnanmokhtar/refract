<!-- setup-project:managed start id=web-backend-django.ai.conventions.web-backend-django v=1.0.0 track=web-backend-django -->
---
track: web-backend-django
purpose: Stack-specific MUST / MUST-NOT rules for Django projects, with project-anchored RATIONALE.
imported-by: templates/tracks/web-backend-django/pack.md (emitted into ai/conventions/web-backend-django.md).
---

# Conventions — Django

These conventions ship into `ai/conventions/web-backend-django.md` under a managed block. Phase 4.6 will anchor the project-specific lines (paths, base classes by line number) to the actual codebase before this content reaches the user's repo.

## File layout

- **MUST** keep apps under a top-level `apps/` directory if the project has more than 3 apps. Single-app projects can live at root.
  - **Rationale:** Django's flat default scales poorly past ~3 apps; `apps/` becomes the import root and disambiguates from third-party.
- **MUST** colocate `urls.py`, `views.py`, `models.py`, `serializers.py` (DRF) within each app.
  - **Rationale:** Django convention; deviating breaks discovery for new contributors.
- **MUST NOT** create top-level `utils/` or `helpers/` modules with no clear ownership.
  - **Rationale:** Ownerless modules accumulate dead code; map to a feature app.

## URL configuration

- **MUST** include each app's `urls.py` from a single root `urls.py`; do not register apps from `INSTALLED_APPS` alone.
  - **Rationale:** explicit registration matches Django's contract; implicit auto-loading hides ordering bugs.
- **MUST** namespace each app's URLs (`app_name = "..."`) for reverse() reliability.

## Models

- **MUST** add a `Meta.ordering` to every model that's listed by default.
  - **Rationale:** ordering by insertion is non-deterministic across DB backends; tests flake.
- **MUST** use `auto_now_add=True` / `auto_now=True` for `created_at` / `updated_at`, NOT `default=timezone.now`.
  - **Rationale:** `auto_now*` fields are read-only — prevents accidental overwrite.
- **MUST NOT** add database indexes inside `class Meta` if a custom migration already creates them.
  - **Rationale:** double-create migrations on next `makemigrations`.

## Migrations

- **MUST** review `python manage.py makemigrations --dry-run` output before committing schema changes.
- **MUST** name data migrations explicitly: `0042_backfill_user_tier.py`, not `0042_auto_*.py`.
  - **Rationale:** auto-named migrations are silent; reviewers skip them; data changes ship invisibly.
- **MUST NOT** delete a migration that has been applied to any deployed environment.
  - **Rationale:** the migration history is a database fact; deleting it desyncs prod.

## Querysets

- **MUST** use `select_related` for ForeignKey traversals and `prefetch_related` for M2M / reverse FK.
  - **Rationale:** the N+1 query problem is the #1 LLM-authored Django perf failure.
- **MUST** scope querysets in the manager / a custom manager method when filtering is repeated.
  - **Rationale:** prevents the same `.filter(active=True)` from drifting across the codebase.
- **MUST NOT** call `.all()` then iterate to filter in Python — push the predicate into the query.

## Forms / Serializers

- **MUST** validate at the serializer (DRF) or form (HTML) layer, not in the view.
  - **Rationale:** view-level validation rots; serializer/form validation is reusable.
- **MUST NOT** override `to_internal_value` / `to_representation` unless the default is provably wrong.
  - **Rationale:** DRF's defaults are sound; overrides hide bugs.

## Views

- **MUST** prefer ViewSet (DRF) or class-based views over function-based when CRUD shape applies.
- **MUST NOT** access `request.user` in a serializer's `__init__` — read from `context['request']` instead.
  - **Rationale:** serializers are sometimes instantiated without a request; `__init__` access raises.

## Async (when detected)

- **MUST** mark async views with `async def` AND register a corresponding async URL pattern.
- **MUST NOT** call sync ORM methods from an async view without `sync_to_async`.
  - **Rationale:** silent runtime errors at scale.

## Settings

- **MUST** split settings into `base.py` + `dev.py` + `prod.py` + `test.py` once any environment-specific override exists.
- **MUST** load secrets from environment variables, never hardcode.
- **MUST NOT** read `os.environ` directly in app code — read from `django.conf.settings`.

## Testing

- **MUST** use `pytest-django` if the project uses pytest; do not mix with Django's `TestCase` runner.
- **MUST** scope database setup with `@pytest.mark.django_db` (or `TransactionTestCase` for cross-transaction tests).
- **MUST NOT** mock the ORM in tests that exercise queries — use a real test DB.
  - **Rationale:** mocked ORM tests drift from prod migrations.

## Project-specific anchors

(Phase 4.6 will populate this section with the project's actual paths, base-class names, and convention-violating callsites cited by file:line. The block above is the generic ruleset; the project-specific anchors are what make the rules enforceable in THIS codebase.)
<!-- setup-project:managed end -->
