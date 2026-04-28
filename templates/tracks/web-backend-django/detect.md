---
track: web-backend-django
signals:
  - { kind: file, glob: "**/manage.py",                     weight: 10 }
  - { kind: file, glob: "**/wsgi.py",                       weight: 4 }
  - { kind: file, glob: "**/asgi.py",                       weight: 4 }
  - { kind: file, glob: "**/settings.py",                   weight: 5 }
  - { kind: file, glob: "**/settings/*.py",                 weight: 5 }
  - { kind: dep,  ecosystem: pip, name: "django",           weight: 8 }
  - { kind: dep,  ecosystem: pip, name: "djangorestframework", weight: 5 }
  - { kind: dep,  ecosystem: pip, name: "django-ninja",     weight: 4 }
  - { kind: dep,  ecosystem: pip, name: "celery",           weight: 2 }
  - { kind: negative, glob: "**/Gemfile",                   weight: -10 }
  - { kind: negative, glob: "**/composer.json",             weight: -10 }
threshold: 10
exclusive-with:
  - web-backend-rails
  - web-backend-fastapi
  - web-backend-laravel
  - web-backend-express
---

# Detection — web-backend-django

Selects when the codebase is a Django (with or without DRF) project.

## Signal rationale

- `manage.py` (weight 10): definitive — alone meets threshold. Every Django project has it.
- `settings.py` / `settings/*.py` (weight 5): expected location for Django config. Common across split-settings layouts.
- `wsgi.py` / `asgi.py` (weight 4 each): present in any deployable Django project.
- `django` dep (weight 8): from a manifest scan. Sums with file signals to lift confidence.
- `djangorestframework` (weight 5), `django-ninja` (weight 4): variant-discriminating; not required.
- `celery` (weight 2): cross-cutting; suggests background-jobs technical signal alongside this track.
- Negative signals on `Gemfile` (Rails) and `composer.json` (Laravel/PHP): in a polyglot repo, prefer the track whose signals dominate.

## Threshold

`10` — meets on `manage.py` alone, OR on `django` dep + 1 file signal, OR on 2 file signals + 1 dep at 4+.

## Exclusivity

Mutually exclusive with other server-framework tracks. In a monorepo where Django sits alongside (e.g.) a Next.js frontend, both tracks select but on DIFFERENT subdirectories — see Phase 2 monorepo handling.
