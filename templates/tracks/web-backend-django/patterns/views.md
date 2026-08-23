---
name: views
description: "Pattern: Django views"
kind: ai-pattern
---

# Pattern: Django views

## When to use which

| View kind             | Use when                                              |
|-----------------------|-------------------------------------------------------|
| `ModelViewSet` (DRF)  | Full CRUD over a single model + DRF serializer        |
| `GenericAPIView` (DRF)| Custom shape on top of a queryset                     |
| `APIView` (DRF)       | No queryset — orchestration / fan-out / non-CRUD ops  |
| Class-based view      | HTML form / template rendering with shared mixins     |
| Function-based view   | One-off endpoint with no shared behavior              |

## Anti-patterns

- Business logic in `views.py`. Move it to `services.py` and call from the view.
- Manual permission checks inside the view body. Use `permission_classes`.
- Mixing async and sync handlers in the same router. Pick one per app.

## Project-specific anchors

(Phase 4.6 cites the project's actual viewset base + service layer locations.)
