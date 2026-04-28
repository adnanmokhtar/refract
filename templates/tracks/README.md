# templates/tracks/

Pluggable track definitions. A "track" is a domain-of-work (web-frontend, web-backend, data-pipeline, ml, mobile, cli, library, infra). Tracks are stack-aware *outputs*; they are NOT business-domains and NOT regulatory overlays.

## Why this exists

Before Milestone 2, track logic was inlined inside the 5,106-line `commands/setup-project.md`. Adding a stack required editing the monolith. After M2, adding a stack = dropping a directory here.

## Layout

```
templates/tracks/<name>/
  detect.md         ← signals (file globs, deps, configs) that match this track
  pack.md           ← what to generate (CLAUDE.md sections, ai/ files, .claude/ rules)
  conventions.md    ← stack-specific MUST/MUST-NOT rules + RATIONALE
  meta.yaml         ← name, version, depends-on, conflicts-with
```

## Detection contract (`detect.md`)

Each track declares signals as a weighted list:

```yaml
---
track: web-backend-django
signals:
  - { kind: file, glob: "**/manage.py", weight: 10 }
  - { kind: dep,  name: "django",       weight: 8 }
  - { kind: file, glob: "**/wsgi.py",   weight: 4 }
threshold: 10
---
```

Orchestrator sums matched weights; threshold passes = track selected.

## Pack contract (`pack.md`)

Pack output is structured, not free prose:

```yaml
---
emits:
  - path: ai/conventions/<track>.md
    from: conventions.md
  - path: .claude/rules/<track>.md
    from: rules-template
  - path: CLAUDE.md
    section: "## Stack: <track>"
    merge: append-once
---
```

`merge: append-once` is enforced by idempotency markers (Milestone 2).

## Existing artifacts being migrated into tracks (M2)

- `templates/packs/*` — most map 1:1 to tracks (backend, frontend, mobile, devops, …).
- `templates/domains/*` — these are *technical patterns* (webhook, payment, real-time). M2 decides: keep as cross-cutting "pattern packs" or fold into tracks.
- `templates/business-domains/*` — these stay separate. Business domain ≠ track.
- `templates/tool-adapters/*` — moved out of the core in Milestone 2 (sibling command).

## Adding a new track

1. Create `templates/tracks/<name>/` with the four files above.
2. Run `scripts/verify-sync.sh` then `scripts/sync-to-global.sh`.
3. Add a fixture under `tests/setup-project/fixtures/<name>/` with an expected snapshot.
4. CI snapshot test (M1 scaffold, populated through M2/M3) catches regressions.
