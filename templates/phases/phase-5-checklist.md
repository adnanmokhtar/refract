---
artifact: phase-5-checklist
purpose: Phase 5 audit as a checklist that pass/fails per item, not prose. Phase 5 prose lives in phases/phase-5-verify.md; this file is the executable contract.
imported-by: templates/phases/phase-5-verify.md, /setup-project-health (subset).
---

# Phase 5 audit checklist

Phase 5 must NOT report success unless every `must` row passes. `should` rows warn but do not halt. Each row cites the rule from `templates/governance/hard-rules.md` it enforces.

## C1. Required-baseline files

| Check                                                                  | Severity | Rule  |
|------------------------------------------------------------------------|----------|-------|
| `CLAUDE.md` exists                                                     | must     | A09   |
| `AGENTS.md` exists                                                     | must     | A09   |
| `.claude/rules/read-before-write.md` exists                            | must     | A19   |
| `.claude/rules/read-codebase-deeply.md` exists                         | must     | A19   |
| `.claude/rules/code-quality.md` exists                                 | must     | A19   |
| `.claude/rules/think-simplify-surgical.md` exists                      | must     | A19   |
| `ai/conventions.md` exists                                             | must     | N15   |
| `ai/status.md` has `Updated:` and `## Recent Changes`                  | must     | A06   |
| `ai/references/models.md` exists                                       | must     | A09   |

## C2. Idempotency

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| Every managed file has matching `setup-project:managed` markers        | must     | A10               |
| Markers reference a known artifact-id and version                      | must     | idempotency.md    |
| Re-running command in `--dry-run` produces empty diff                  | must     | idempotency.md    |
| `.env*` and lock files unmodified                                      | must     | N01               |
| User-authored sections (outside markers) byte-identical to pre-run     | must     | A04 / N02         |

## C3. Content quality

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| No file contains `<TODO>`, `<TBD>`, `<FILL ME>`, `<placeholder>`       | must     | A02               |
| No generated rule omits the project-specific block at the top          | must     | N16               |
| No generated convention is a generic copy when codebase exists         | must     | N15               |
| No COPY-mode pack output is shorter than its source                    | must     | A11 / N10         |
| No AUTHOR-mode citation references a symbol/path not in extraction     | must     | A12               |

## C4. Pack discipline

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| Every applied pack has `_version.json` + `CHANGELOG.md`                | must     | A27               |
| Per-run version stamps recorded in `codebase-profile.md`               | must     | A28               |
| Pack-load preflight report emitted                                     | must     | phase-4 §4.0.4    |

## C5. Schema validation

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| Every JSON config validates against `templates/schemas/`               | must     | A31               |
| Every markdown frontmatter parses as YAML                              | must     | A31               |
| Every command/agent passes a dry-invoke smoke test                     | should   | A31               |

## C6. Tool-adapter parity (when adapters present)

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| Each enabled adapter has all 4 artifact types translated               | must     | A09 / N09         |
| Each adapter's primary config has gap-disclosure section               | must     | adapters.md §B    |
| `AGENTS.md` lists `## Invokable commands`, `## Named personas`, `## Named procedures` | must | A09       |
| No adapter ships duplicate verbatim rule content                       | must-not | N09               |

## C7. Knowledge-base discipline

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| ADRs preserved verbatim (REFRESH mode)                                 | must     | N19               |
| Failure catalog `_index.md` referenced from architectural agents       | must     | A29               |
| `_session-digest.md` ≤ 300 lines                                       | must     | curator budget    |
| `_convention-cheatsheet.md` ≤ 200 lines                                | must     | curator budget    |
| `CLAUDE.md` ≤ 200 lines                                                | must     | curator budget    |
| Health score appears in `_session-digest.md` (Tier 1)                  | must     | A32               |

## C8. Observability

| Check                                                                  | Severity | Rule              |
|------------------------------------------------------------------------|----------|-------------------|
| `.claude/_telemetry.jsonl` is `.gitignore`d                            | must     | A33               |
| Telemetry contains zero PII / network calls                            | must     | A33               |
| `ai/_setup-history.md` got a one-line entry for this run               | should   | observability     |

## C9. Mode-specific checks

| Mode    | Additional must-pass rows                                          |
|---------|---------------------------------------------------------------------|
| CREATE  | C1, C2, C3, C4, C5                                                  |
| ENHANCE | C1, C2, C3, C4, C5, C7                                              |
| REFRESH | C1, C2, C3, C4, C5, C6, C7, C8 + REFRESH order audit (A25, A26)     |
| REFINE  | C1, C2, C3, C4, C5, C6, C7, C8 + setup-quality score in `_setup-quality.md` |

## What a Phase 5 report looks like

```
Phase 5 audit — <mode> mode — version v2.0.0

C1 required-baseline:    9/9   ok
C2 idempotency:          5/5   ok
C3 content quality:      4/5   FAIL — generated rules/database.md omits project block (N16)
C4 pack discipline:      3/3   ok
C5 schema validation:    3/3   ok
C6 tool-adapter parity:  n/a   (no adapters configured)
C7 knowledge base:       6/6   ok
C8 observability:        2/3   warn — _setup-history.md missing entry
C9 mode-specific:        ok    (CREATE additional checks: n/a)

verdict: HALT — 1 must-row failed (C3.N16). Re-running rule generation.
```

## Halt + retry policy

A `must` failure triggers ONE automatic retry:

1. Halt the report.
2. Re-run the specific phase that produced the failing artifact.
3. Re-audit only the failing rows.
4. If still failing, halt with full diagnostic and surface to user. NO third attempt.

This is the false-idempotent-bug prevention. Reference: phase-4 §4.0.5 + phase-5 prose.
