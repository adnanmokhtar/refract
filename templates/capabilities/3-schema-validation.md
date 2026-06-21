---
artifact: capability-3-schema-validation
purpose: Schema-validation DESIGN SPEC (B4) — NOT WIRED. Describes how a schema-validation harness over templates/schemas/ would work. No script in this repo runs it; treat as future-work reference, not an active guarantee.
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🔬 3. Schema-validation design spec (B4) — NOT WIRED

> **Status: reference / future-work, NOT runtime-enforced.** The harness described below is a DESIGN, not a shipped mechanism. There is no `ajv` / `yamllint` / `--validate-schemas` step that runs in any phase or hook — the schemas under `templates/schemas/` are reference shapes (see `templates/schemas/README.md`), and the validation steps, the `--validate-schemas` flag, and the dry-invoke smoke test in this document are all unimplemented. Phase 5's real, wired gate is `audit-setup.sh` (file presence + self-consistency), NOT schema validation. Read this section as the spec a future validator would implement, not as something that runs today.

**Problem this WOULD solve**: Phase 5 verifies file PRESENCE, not file VALIDITY. Generated `settings.json` could have a typo. Generated `opencode.json` could miss required keys. `.cursor/rules/*.mdc` frontmatter could be malformed. There is currently no automated catch — the snippets below are the proposed design for one.

**Design (proposed, not wired)**:

#### 3.1 Schema directory

```
~/.claude/templates/schemas/
  claude-code/
    settings.schema.json      # Claude Code settings.json schema           [SHIPPED]
    skills.schema.json        # SKILL.md frontmatter schema                [SHIPPED]
    agents.schema.json        # agent frontmatter schema                   [SHIPPED]
    commands.schema.json      # command frontmatter schema                 [SHIPPED]
    mcp.schema.json           # .mcp.json schema                           [PLANNED]
  cursor/
    rules.schema.json         # .cursor/rules/*.mdc frontmatter schema     [SHIPPED]
    cursorrules.schema.json   # legacy .cursorrules schema                 [PLANNED]
  opencode/
    config.schema.json        # opencode.json schema                       [SHIPPED]
  aider/
    config.schema.json        # .aider.conf.yml shape                      [PLANNED]
  generic/
    agents-md.schema.json     # AGENTS.md (universal anchor) shape         [SHIPPED]
    codebase-profile.schema.json   # .claude/codebase-profile.md frontmatter [PLANNED]
    session-digest.schema.json     # ai/_session-digest.md shape            [PLANNED]
```

Each schema is JSON Schema Draft 2020-12. `[SHIPPED]` schemas exist on disk as **reference shapes** (nothing validates against them at runtime); `[PLANNED]` are referenced by future-work only. Adapter version bumps update the corresponding schema version.

#### 3.2 Phase 5.4 — Schema validation step (PROPOSED — not wired)

The snippet below is the design for a validation step that would run after Phase 5's file-presence + self-consistency audit. It is **not implemented** — `ajv` and `yamllint` are not invoked anywhere in this repo. Shown as the contract a future harness would fulfil:

```bash
for config in $(find . -name "settings.json" -path "*/.claude/*" -o \
                       -name "opencode.json" -o \
                       -name ".mcp.json"); do
  schema="$(basename "$config")".schema.json
  ajv validate -s ~/.claude/templates/schemas/claude-code/$schema -d "$config" \
    || HALT_VALIDATION="$HALT_VALIDATION\n  $config FAILED schema $schema"
done

# Frontmatter validation (markdown files with YAML frontmatter)
for skill in .claude/skills/*/SKILL.md; do
  extract_frontmatter "$skill" | yamllint --schema ~/.claude/templates/schemas/claude-code/skills.schema.json
done
```

If any failure → halt + retry the offending generator. If retry also fails → halt with report.

#### 3.3 Dry-invoke smoke test (PROPOSED — not implemented)

`validate_command_invocation` is a proposed helper; it does not exist. The design: for each generated command, parse the frontmatter, simulate invocation with a minimal test prompt, verify output matches expected shape:

```bash
for cmd in .claude/commands/*.md; do
  desc=$(yq '.description' "$cmd")
  # Generate a minimal test prompt that should trigger the command
  # Pipe into a dry-evaluator (does NOT actually invoke the LLM — just parses + validates structure)
  validate_command_invocation "$cmd" || FAIL=1
done
```

The validator checks:
- All `Read` directives in the command point to existing files.
- All `Bash` snippets are syntactically valid (parse with `bash -n`).
- All referenced agents exist in `.claude/agents/`.
- All referenced skills exist in `.claude/skills/`.
- Phase numbers are sequential (1→7) per the canonical 7-phase structure.

#### 3.4 `--validate-schemas` flag (PROPOSED — not implemented)

This flag does not exist on `/setup-project` today. The mock transcript below illustrates what a standalone read-only validation run would print if the harness were built:

```
$ /setup-project --validate-schemas

VALIDATING 47 generated files against schemas...

  .claude/settings.json                    ✓
  .mcp.json                                ✓
  .claude/skills/*/SKILL.md (7 files)     ✓
  .claude/agents/*.md (14 files)          ✓
  .claude/commands/*.md (20 files)        ⚠
    /add-module: Phase 5 missing (canonical 7-phase structure violated)
    /fix-bug: references nonexistent agent `db-architect`

  opencode.json                            ✓
  .cursor/rules/*.mdc (6 files)           ✓

DRY-INVOKE smoke test (20 commands):
  /add-module        ✓ structure OK
  /fix-bug           ✗ broken cross-ref to .claude/agents/db-architect.md (does not exist)
  ...

RESULT: 2 issues found.
Run /setup-project --refresh to regenerate (auto-fixes structural violations).
```

#### 3.5 Rules (graceful degradation) — describe the PROPOSED behaviour, not current behaviour

- **Schema validation is not implemented.** The rules below describe how the proposed harness would behave (opt-in, warn-on-miss, never-halt). Today none of it runs: there is no `--validate-schemas` flag and no schema check in any phase. When/if the harness is built, it would validate every generated config against its schema, emit `SCHEMA_MISSING <adapter>` for missing schemas, and continue without halting.
- **Recommended seed schemas** (ship in `~/.claude/templates/schemas/` over time): `claude-code/settings.schema.json`, `claude-code/agents.schema.json`, `claude-code/commands.schema.json`, `claude-code/skills.schema.json`, `cursor/rules.schema.json`, `opencode/config.schema.json`, `aider/config.schema.json`, `generic/agents-md.schema.json`. Anything beyond these is a future enhancement, not a hard requirement.
- **Schema version pinning** (when schemas exist): schemas declare `$id` with version (e.g. `https://<your-org>.com/schemas/claude-code/settings/v1.json`). Adapter version bump = schema version bump.
- **(Proposed)** a future `--refresh` would run schema validation as part of Phase 5 when schemas are present, with failures degrading to warnings unless `--strict` is also passed. Not implemented today.

---

