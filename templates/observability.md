---
artifact: observability
purpose: Per-run history log so humans (and, once wired, the curator agent) can answer "what changed when, and why."
imported-by: commands/setup-project.md (orchestrator — WARM tier).
---

# Observability

## `ai/_setup-history.md`

Every `/setup-project` run appends ONE line to `ai/_setup-history.md` in the target repo. The file is a chronological log; lines are never edited or removed.

## Line format

```
<UTC ISO8601> | <mode> | v<version> | <result> | <tracks-applied> | <files-touched> | <duration-ms> | <one-line note>
```

Example:

```
2026-04-28T13:42:11Z | enhance | v2.0.0 | ok          | backend,frontend,security | 47 | 12318 | added security pack; 1 ADR
2026-05-03T09:15:00Z | refresh | v2.0.0 | halt-c3.n16 | backend                  |  3 |  4421 | rule generation skipped project block (retry succeeded)
2026-05-09T18:02:43Z | refine  | v2.0.0 | plateau     | backend,frontend         |  0 |  6004 | density >= 70 across all artifacts
```

## Field semantics

| Field            | Values                                                      |
|------------------|-------------------------------------------------------------|
| timestamp        | UTC ISO 8601 with seconds                                   |
| mode             | `create` / `enhance` / `refresh` / `refine` / `health`      |
| version          | `v<major>.<minor>.<patch>` of the command                   |
| result           | `ok` / `halt-<rule-id>` / `plateau` / `dry-run` / `error`   |
| tracks-applied   | comma-list, no spaces                                       |
| files-touched    | integer count of write-targets in this run                  |
| duration-ms      | integer ms                                                  |
| note             | one short line; no embedded `\|` (escape if necessary)      |

## What is NEVER logged

- File contents.
- User/PII (project paths inside the repo are fine; absolute home paths are NOT).
- Network calls (none are made).
- Secrets, credentials, env variables.

## `.claude/_telemetry.jsonl`

Telemetry is the in-progress, per-run JSONL emitted during execution. It is local-only and `.gitignore`d (Hard Rule A33).

Schema:

```jsonl
{"ts":"2026-04-28T13:42:00Z","phase":"2","event":"track-detected","data":{"track":"backend","score":18}}
{"ts":"2026-04-28T13:42:01Z","phase":"4","event":"file-written","data":{"path":"ai/conventions.md","bytes":4218}}
{"ts":"2026-04-28T13:42:11Z","phase":"5","event":"audit-row","data":{"id":"C3.N16","status":"fail","retry":1}}
```

Telemetry is written here by Phase 4/5. **No consumer reads it back yet (planned).**
`/setup-project-health` does not: none of its ten checks opens `ai/_setup-history.md`, and the
command never names this file — check 1 reads digest freshness by file mtime instead. The curator
agent's prune signal is the same shape and the same status. Wiring either one is the work; until
then this log is written and read by humans only.

## Retention

- `ai/_setup-history.md` — append-only, never pruned.
- `.claude/_telemetry.jsonl` — rotated by the curator when > 5 MB. Old rotations go to `.claude/_telemetry-archive/<YYYY-MM>.jsonl.gz`.

## Why these two channels separately

`_setup-history.md` is the human-readable audit trail (commit-friendly, diff-friendly). `_telemetry.jsonl` is the structured firehose for tooling. Both are required because:

- A human reading the repo wants prose, not JSON.
- A tool computing drift wants structured fields, not prose.
- Mixing them in one channel makes both worse.
