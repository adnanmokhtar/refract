# Schemas

JSON Schema (Draft 2020-12) and frontmatter schemas that document the **expected shape** of the configs `/setup-project` generates.

## Status

> **Reference shapes — NOT runtime-enforced.** These files are documentation of the intended structure for each adapter's artifacts. No script in this repo validates generated output against them at runtime — there is no `ajv` / `yamllint` step wired into any phase or hook. They exist so a human (or an agent reading the spec) can see the required keys, types, and section presence for each artifact, and so a future validation harness has a contract to validate against. Treat a schema here as the authoritative description of the shape, not as a guarantee that anything checks it.

If you want runtime validation, you would have to add a validator (e.g. `ajv-cli`) yourself and a phase/hook that invokes it; that wiring is intentionally not shipped.

## Layout

```
schemas/
├── claude-code/
│   ├── settings.schema.json   # .claude/settings.json
│   ├── agents.schema.json     # .claude/agents/*.md frontmatter
│   ├── commands.schema.json   # .claude/commands/*.md frontmatter
│   └── skills.schema.json     # .claude/skills/<name>/SKILL.md frontmatter
├── cursor/
│   └── rules.schema.json      # .cursor/rules/*.mdc frontmatter
├── opencode/
│   └── config.schema.json     # opencode.json
├── generic/
│   └── agents-md.schema.json  # AGENTS.md (universal anchor) section presence
└── refract/
    ├── evidence.schema.json   # .claude/evidence/<sha>/<gate>-<check>.json — one gate-check.py record per check
    ├── acceptance.schema.json # ai/runs/<run>/acceptance.json — the locked contract, written before code
    ├── findings.schema.json   # ai/runs/<run>/reviews/<agent>-<lens>.json — a review lens's candidates
    └── verdict.schema.json    # ai/runs/<run>/verdict.json (+ verdict-refute.json) — the verifier's record
```

`refract/` holds the shapes of Refract's OWN machine records, not of another tool's config. Unlike the
reference shapes above, these ARE checked: `tests/hooks/run.sh` validates every record `gate-check.py`
writes in its fixtures against `evidence.schema.json`, and the SubagentStop hooks validate every verdict
and review against the other three at write time — refusing a malformed one — through the byte-identical
copies installed at `templates/repo-baseline/.claude/schemas/` (the suite fails if the copies drift).

## Conventions

- Each schema has `$id` with version (`https://example.com/schemas/<adapter>/<artifact>/vN.json`).
- Frontmatter schemas describe the YAML block extracted from `.md` files; they don't describe the prose body.
- Bumping a schema's major version requires bumping the parent adapter's `_version.json`.

## Extending

To add a reference schema for an unsupported adapter (Aider, Continue, Cline, Windsurf, Copilot, Codex, Gemini): create `<adapter>/<artifact>.schema.json` with `$id` + Draft 2020-12 root. It documents the shape; it is not auto-validated by any phase.
