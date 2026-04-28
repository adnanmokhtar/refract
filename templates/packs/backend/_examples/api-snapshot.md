---
name: api-snapshot
description: Snapshot the API's OpenAPI spec and diff against the last committed snapshot. Catches contract breaks before they ship. Blocks merge on breaking changes without an ADR.
---

# api-snapshot

## Why

A CI check that fails LOUDLY when you change an endpoint shape. Prevents: accidental field rename, silent type change, removed endpoint, etc.

## Prerequisites

Project emits OpenAPI: NestJS (`@nestjs/swagger`), FastAPI (auto), Spring (`springdoc-openapi`), Laravel (`scramble`), etc.

## Setup

```
api-snapshots/
├── openapi.v1.json              # committed current baseline
├── openapi.v1.snapshot.json     # working baseline (CI re-generates)
└── changes.md                   # optional change log
```

## Flow

### 1. Generate current spec
Framework-specific:
- NestJS: `curl http://localhost:3000/api-json > current.json`
- FastAPI: `curl http://localhost:8000/openapi.json > current.json`
- Built artifact: expose `/openapi.json` in test mode, hit it during CI.

### 2. Diff against committed baseline

Use `openapi-diff` or `oasdiff`:
```bash
oasdiff breaking api-snapshots/openapi.v1.json current.json
oasdiff changelog api-snapshots/openapi.v1.json current.json
```

`breaking` exits non-zero if breaking changes detected. `changelog` produces a human-readable diff.

### 3. Classify diff

**Breaking (blocks merge)**:
- Endpoint removed
- Parameter removed
- Required request field added
- Required response field removed
- Type changed (string → number)
- Enum value removed
- Auth requirement added

**Non-breaking (warn)**:
- Endpoint added
- Optional parameter added
- Optional response field added
- Deprecated field marked
- Enum value added (consumers tolerant)

### 4. Handle breaking changes

If breaking AND no ADR present at `ai/decisions/` that references this change → FAIL CI.

If ADR exists (declares intentional break + migration path) → warn, ask approval.

### 5. Update baseline after approved break

```bash
cp current.json api-snapshots/openapi.v1.json
# commit together with the breaking-change ADR
```

## CI integration

```yaml
- name: API snapshot diff
  run: |
    pnpm build
    pnpm start &
    until curl -sf http://localhost:3000/health; do sleep 1; done
    curl http://localhost:3000/api-json > /tmp/current.json
    npx @tufin/oasdiff breaking api-snapshots/openapi.v1.json /tmp/current.json
    # exit non-zero on breaking
```

## Output

```
API snapshot diff — feature/add-pagination

Changes detected: 3

✓ Added — GET /products now accepts ?page, ?limit query params (optional)
✓ Added — GET /products response includes `meta.page` (additive)
✗ Breaking — POST /orders: `customer` field renamed to `customerId`

Breaking change detected.

No ADR found referencing this change.
Blocking merge.

To proceed:
  1. If intentional: write ADR in ai/decisions/ describing rename + migration path.
     Update the API to support both `customer` AND `customerId` for a deprecation window.
  2. If unintentional: revert the rename.
```

## Multi-version handling

If the project serves v1 and v2 simultaneously:
- One snapshot per version: `openapi.v1.json`, `openapi.v2.json`.
- Diff only within a version.
- v2 can diverge from v1 freely — no diff between them.

## Rules

- Snapshot files committed to repo.
- Diff runs on every PR.
- Breaking changes require ADR.
- Non-breaking changes warn, don't block.
- Baseline updated only in the same PR as the approved breaking change.
