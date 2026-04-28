# Django / Django REST Framework reference

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
