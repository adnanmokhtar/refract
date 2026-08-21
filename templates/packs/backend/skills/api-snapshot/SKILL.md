---
name: api-snapshot
description: Snapshot the API's OpenAPI spec and diff it against the last committed snapshot, blocking merge on breaking changes that carry no ADR. Run on any controller or DTO change. Proves the *declared* contract held — `endpoint-test` is the runtime counterpart that proves the running route still matches its DTO.
---

# api-snapshot

## Premise

Find real contract breaks, not hand-waves. Every flagged change cites the endpoint + the field + the OpenAPI path that changed + the prior shape. "Probably breaking" is not a verdict. A diff that returns clean against a stale baseline is worse than a missing run — re-generate the current spec from a live build, not from cached JSON. Breaking changes without an ADR halt the pipeline.

A "non-breaking" verdict on a renamed field is a misclassification; surface every change explicitly.

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

## What the snapshot does NOT cover — say it out loud

A diff gate's danger is not the changes it flags; it is the changes it cannot see, because a green gate reads as "nothing broke". Two blind spots are structural here, and both are verifiable in this pack rather than hypothetical.

**1. Streaming endpoints are exempt by construction.** `api-reviewer` ENF-4 states that a `text/event-stream` / chunked / NDJSON handler "is not held to the response-envelope or `response_model` checks" — correctly, since a stream has no single buffered body to model. The consequence nobody wrote down: with no declared response model, there is nothing for `oasdiff` to compare, so the record shape a streaming route emits can change freely and this gate stays green. A consumer parsing NDJSON rows breaks in production against a passing CI.

What to do about it, in order of honesty:
- **Snapshot the row/event schema separately** — a committed fixture of one representative record (or SSE `event:` payload) diffed alongside the spec. Crude, but it is a real gate rather than an assumed one.
- **Check whether your OpenAPI version can describe the sequential media type** before concluding it cannot. Later revisions of the specification have added keywords aimed exactly at sequential media types; whether the one you emit supports it depends on your generator's output version, which is why the next point exists. Read your generator's emitted `openapi:` field and the corresponding specification revision before writing this off — do not take this file's word for it.
- **At minimum, list your streaming routes in the snapshot's README** as known-undiffed, with the consumer contract stated in prose. An undiffed route that is *documented* as undiffed is a gap; one that silently passes is a false guarantee.

**2. The baseline has no declared spec version.** Nothing in this pack pins one. `oasdiff` classifies changes against the structure it is handed, and a generator upgrade that changes the emitted `openapi:` revision can shift how constructs are expressed — which surfaces as diff noise, or worse, as a real break that classifies as cosmetic. **Record the spec version in the snapshot directory and treat a change to it as its own reviewed event**, not as part of an ordinary API diff. A baseline regenerated under a new spec revision in the same PR as a code change makes both unreviewable.

## Rules

- **The snapshot directory records the emitted spec version** (`openapi:` field) alongside the baselines; a change to it is reviewed on its own, never bundled with an API change.
- **Streaming routes are listed as known-undiffed**, with their record/event contract stated in prose, so a green gate is not read as coverage they never had.
- Snapshot files committed to repo.
- Diff runs on every PR.
- Breaking changes require ADR.
- Non-breaking changes warn, don't block.
- Baseline updated only in the same PR as the approved breaking change.

## Related

- `.claude/skills/endpoint-test/SKILL.md` — runtime counterpart: api-snapshot proves the *declared* OpenAPI contract didn't break; endpoint-test proves the *running* route still matches its DTO. Run both on a controller/DTO change.
- `.claude/skills/api-consistency-audit/SKILL.md` — sibling scanner for envelope / error-shape uniformity across endpoints; api-snapshot guards the diff, api-consistency-audit guards the shape.
- Consumed by `@api-reviewer` — a breaking snapshot diff with no governing ADR escalates that agent's verdict to **BLOCK** (not REQUEST).
- `ai/patterns/api-contract.md` — the evolution table (safe vs breaking) this skill classifies each diff against.
- `ai/patterns/api-versioning.md` — the version-bump + Sunset policy an approved break must follow.
- `.claude/rules/backend-principles.md` — the MUST behind "breaking changes require an ADR".

## Halt conditions

- Halt on hand-waves: every diff entry must cite the endpoint path, method, and field. "Some endpoints changed" is not a verdict.
- Halt if the current spec was not generated from a live built artifact — diffing a stale JSON file lies.
- Halt if a breaking change ships without an ADR in `ai/decisions/` referencing it. No exceptions for "tiny renames".
- Halt if the baseline is updated in a PR that does NOT also contain the approved breaking change — silent baseline bumps mask regressions.
