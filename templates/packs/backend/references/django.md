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

## Anti-patterns

- Fat viewsets with business logic
- Raw SQL when ORM would work
- Forgetting `select_related` on serializer foreign keys (N+1)
- Bypassing permissions with `AllowAny` on sensitive endpoints
