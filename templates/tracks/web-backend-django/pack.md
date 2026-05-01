---
track: web-backend-django
emits:
  - path: ai/conventions/web-backend-django.md
    from: conventions.md
    merge: managed-block
  - path: .claude/rules/web-backend-django.md
    from: rules-template.md
    merge: managed-block
  - path: CLAUDE.md
    section: "## Stack: Django"
    section-id: stack-web-backend-django
    from: claude-md-section.md
    merge: managed-section
  - path: ai/patterns/django-views.md
    from: patterns/views.md
    merge: managed-block
  - path: ai/patterns/django-models.md
    from: patterns/models.md
    merge: managed-block
emits-conditional:
  - when: dep.has(djangorestframework)
    path: ai/patterns/drf-serializers.md
    from: patterns/drf-serializers.md
    merge: managed-block
  - when: dep.has(djangorestframework)
    path: ai/patterns/drf-viewsets.md
    from: patterns/drf-viewsets.md
    merge: managed-block
  - when: dep.has(celery)
    path: ai/patterns/celery-tasks.md
    from: patterns/celery-tasks.md
    merge: managed-block
  - when: detected.has-async-views
    path: .claude/rules/django-async-views.md
    from: rules/async-views.md
    merge: managed-block
  - when: detected.has-channels
    path: ai/patterns/django-channels.md
    from: patterns/channels.md
    merge: managed-block
references-existing-pack: templates/packs/backend/references/django.md
---

# Pack contract — web-backend-django

This file declares WHAT this track emits when selected. The actual content of each emitted artifact lives in:

- `conventions.md` (this directory) — the unconditional convention set
- `templates/packs/backend/references/django.md` — existing pack reference (Phase 4.2 deterministic copy source)

## Emit modes

All emits use `managed-*` merge modes per `templates/idempotency.md`:

- `managed-block` — full file is bracketed by markers; second run replaces the block.
- `managed-section` — within an existing file (e.g., `CLAUDE.md`), only the named section is replaced.

User-authored content outside markers is preserved.

## Conditional emits

`emits-conditional` only run when the `when:` clause is satisfied. Clauses use:

- `dep.has(<name>)` — dependency manifest contains the named package.
- `detected.<flag>` — Phase 2 deep extraction flagged a feature (e.g., async views, Channels websockets).

The detection contract for each flag is in `detect.md` of the relevant cross-cutting signal under `templates/domains/`.

## Why this track exists separately from the existing `templates/packs/backend/`

`templates/packs/backend/` is the legacy single-track-fits-all backend pack. M2 introduces tracks as the preferred unit. This track:

- Pins detection to Django specifically (the legacy pack matched any backend).
- Declares emits as a structured contract (legacy pack relied on prose).
- Composes cleanly with conflicts-with (the legacy pack didn't constrain).

During the migration window (M2 → M5+), Phase 2 may select this track AND fall back to the legacy pack body for content the new track doesn't yet replicate. The body content stays at `templates/packs/backend/references/django.md`; the track's job is detection + emit-contract.
