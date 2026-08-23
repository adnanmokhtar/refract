---
name: models
description: "Pattern: Django models"
kind: ai-pattern
---

# Pattern: Django models

## Required fields on every model

- `created_at` via `auto_now_add=True`.
- `updated_at` via `auto_now=True`.
- `Meta.ordering` whenever the model is listed by default.

## Manager discipline

- One custom manager method per repeated query predicate. `.active()` belongs once, not in 12 views.
- Override `get_queryset` in the manager, not the model.

## Indexes + uniqueness

- Compose `class Meta: indexes = [...]` for composite indexes.
- For uniqueness across multiple fields: `UniqueConstraint(fields=[...], name='...')` over `unique_together`.
- Never declare an index in `Meta` AND in a custom migration — `makemigrations` will create a duplicate.

## Anti-patterns

- `default=timezone.now` for `created_at` / `updated_at`. Use `auto_now*`.
- Auto-named data migrations. Always rename `0042_auto_*.py` to its actual purpose.
- ForeignKey to a string-name model in another app without `app_label`. Future module renames silently break.

## Project-specific anchors

(Phase 4.6 lists the project's actual base model + manager classes by file:line.)
