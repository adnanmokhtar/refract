### Stack: Django

- **Server framework:** Django (with DRF when serializers/views detected).
- **Settings layout:** split into `base.py` + per-environment files when any env-specific override exists.
- **Apps location:** `apps/` for projects with ≥3 apps; root for smaller.
- **Async support:** detected per view; sync ORM in async views uses `sync_to_async`.

Conventions: `@ai/conventions/web-backend-django.md`. Rules: `@.claude/rules/web-backend-django.md`.
