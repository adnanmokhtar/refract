# Schemas

JSON Schema (Draft 2020-12) and frontmatter schemas for the configs `/setup-project` generates. Used by `--validate-schemas` to catch malformed output before Phase 5 closes.

## Status

Schema validation is **opt-in**. Phase 4.8 emits a `SCHEMA_MISSING` warning for any selected adapter that lacks a schema here, but does not halt. Adding a schema graduates an adapter from "best-effort" to "strict-validatable".

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
└── generic/
    └── agents-md.schema.json  # AGENTS.md (universal anchor) section presence
```

## Conventions

- Each schema has `$id` with version (`https://example.com/schemas/<adapter>/<artifact>/vN.json`).
- Frontmatter schemas validate the YAML block extracted from `.md` files; they don't validate prose body.
- Bumping a schema's major version requires bumping the parent adapter's `_version.json`.

## Extending

To add a schema for an unsupported adapter (Aider, Continue, Cline, Windsurf, Copilot, Codex, Gemini): create `<adapter>/<artifact>.schema.json` with `$id` + Draft 2020-12 root. Phase 4.8 picks it up automatically once present.
