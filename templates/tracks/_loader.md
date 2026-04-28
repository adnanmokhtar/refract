---
artifact: track-loader
purpose: How the orchestrator finds, scores, and selects tracks at runtime.
imported-by: Phase 2 (profile / detect) and Phase 4 (apply).
---

# Track loader

A track is a discipline-shaped pack (web-frontend, web-backend, mobile, data-pipeline, ml, cli, library, infra). Tracks live under `templates/tracks/<name>/`; existing `templates/packs/<name>/` are the body content of those tracks (M2 keeps them in place; M3 may unify).

## Discovery

The loader scans `templates/tracks/*/meta.yaml` and `templates/tracks/*/detect.md`. Each subdirectory whose name does NOT begin with `_` is a candidate track.

## Detection

Each `detect.md` declares signals:

```yaml
---
track: web-backend-django
signals:
  - { kind: file, glob: "**/manage.py",         weight: 10 }
  - { kind: dep,  ecosystem: pip, name: django, weight: 8 }
  - { kind: file, glob: "**/wsgi.py",           weight: 4 }
  - { kind: file, glob: "**/asgi.py",           weight: 4 }
  - { kind: dep,  ecosystem: pip, name: djangorestframework, weight: 5 }
threshold: 10
exclusive-with: []
---
```

Signal kinds:

- `file` — glob match against the target repo's tracked files.
- `dep` — declared dependency in the relevant ecosystem manifest (pip, npm, gomod, gemfile, cargo, composer).
- `command` — a shell command exits 0 (use sparingly; expensive).
- `negative` — DEDUCT weight if matched (used to disqualify a track that a more specific one would handle).

`threshold` — sum of matched weights ≥ threshold means the track is selected.
`exclusive-with` — list of other track names that cannot be selected alongside this one (e.g., `web-backend-django` exclusive-with `web-backend-rails`).

## Selection algorithm

1. For each candidate track, compute its score = sum of matched signal weights.
2. Drop tracks below their threshold.
3. Apply `exclusive-with` constraints: when two tracks conflict, keep the higher-scored one. Tie → surface as uncertainty per `templates/decision-engine.md`.
4. Sort the remaining set by score (descending) — this is the selection list.
5. The orchestrator passes this list to Phase 4 for application.

## Pack contract (`pack.md`)

```yaml
---
track: web-backend-django
emits:
  - path: ai/conventions/<track>.md
    from: conventions.md
    merge: managed-block
  - path: .claude/rules/<track>.md
    from: rules-template.md
    merge: managed-block
  - path: CLAUDE.md
    section: "## Stack: <track>"
    section-id: stack-<track>
    from: claude-md-section.md
    merge: managed-section
emits-conditional:
  - when: dep.has(celery)
    path: ai/patterns/background-jobs.md
    from: patterns/celery.md
    merge: managed-block
---
```

Merge modes are defined in `templates/idempotency.md`.

## Conventions contract (`conventions.md`)

Stack-specific MUST / MUST-NOT rules with RATIONALE. Follows the format in `templates/governance/hard-rules.md`. Merged into the generated `ai/conventions/<track>.md` under a managed section header.

## Adding a new track

1. Create `templates/tracks/<name>/{detect.md, pack.md, conventions.md, meta.yaml}`.
2. Validate with `scripts/lint-track.sh <name>` (M3).
3. Add a fixture under `tests/setup-project/fixtures/<name>/`.
4. Run the snapshot suite; commit the snapshot if intentional.
5. Run `./scripts/sync-to-global.sh && ./scripts/verify-sync.sh`.

## Existing artifacts and their relation

- `templates/packs/<name>/` — current pack bodies. M2 leaves them in place; tracks read from here for now. M3 may unify the directory layouts.
- `templates/domains/<signal>/` — technical signals (webhook, payment, real-time, etc.). NOT tracks. Cross-cutting; can be triggered alongside any track.
- `templates/business-domains/<domain>/` — business domains (saas-b2b, fintech, healthcare, etc.). NOT tracks. Layered on top of any track.
- `templates/regulatory-overlays/<reg>/` — compliance overlays (GDPR, HIPAA). NOT tracks. Layered on top of business domains.

These four axes (track, signal, business-domain, regulatory-overlay) compose. Tracks answer "what stack?", signals answer "what cross-cutting tech?", business-domains answer "what is the product?", overlays answer "what regulation?".
