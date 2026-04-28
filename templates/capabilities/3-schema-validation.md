---
artifact: capability-3-schema-validation
purpose: Schema validation harness (B4). Phase 5.4 validates every JSON config + frontmatter against templates/schemas/.
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🔬 3. Schema validation harness (B4)

**Problem solved**: Phase 5 verifies file PRESENCE, not file VALIDITY. Generated `settings.json` could have a typo. Generated `opencode.json` could miss required keys. `.cursor/rules/*.mdc` frontmatter could be malformed. No automated catch.

**Design**:

#### 3.1 Schema directory

```
~/.claude/templates/schemas/
  claude-code/
    settings.schema.json      # Claude Code settings.json schema
    mcp.schema.json           # .mcp.json schema
    skills.schema.json        # SKILL.md frontmatter schema
    agents.schema.json        # agent frontmatter schema
    commands.schema.json      # command frontmatter schema
  cursor/
    rules.schema.json         # .cursor/rules/*.mdc frontmatter schema
    cursorrules.schema.json
  opencode/
    config.schema.json        # opencode.json schema
  aider/
    config.schema.json
  generic/
    agents-md.schema.json     # AGENTS.md (universal anchor) shape
    codebase-profile.schema.json
    session-digest.schema.json
```

Each schema is JSON Schema Draft 2020-12. Updated alongside the corresponding tool adapter version.

#### 3.2 Phase 5.4 — Schema validation step (NEW)

After Phase 5 file-presence + self-consistency audit:

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

#### 3.3 Dry-invoke smoke test

For each generated command: parse the frontmatter, simulate invocation with a minimal test prompt, verify output matches expected shape:

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

#### 3.4 `--validate-schemas` flag

Standalone read-only run:

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

#### 3.5 Rules (graceful degradation)

- **Schema validation is opt-in.** When `--validate-schemas` is passed (or the user runs `--refresh` and schemas are present), Phase 4.8 validates every generated config against its schema. If a schema is missing for a selected adapter, Phase 4.8 emits a `SCHEMA_MISSING <adapter>` warning in the report and continues. It does NOT halt.
- **Recommended seed schemas** (ship in `~/.claude/templates/schemas/` over time): `claude-code/settings.schema.json`, `claude-code/agents.schema.json`, `claude-code/commands.schema.json`, `claude-code/skills.schema.json`, `cursor/rules.schema.json`, `opencode/config.schema.json`, `aider/config.schema.json`, `generic/agents-md.schema.json`. Anything beyond these is a future enhancement, not a hard requirement.
- **Schema version pinning** (when schemas exist): schemas declare `$id` with version (e.g. `https://<your-org>.com/schemas/claude-code/settings/v1.json`). Adapter version bump = schema version bump.
- **`--refresh` SHOULD run schema validation** as part of Phase 5 when schemas are present. Failures degrade to warnings unless `--strict` is also passed.

---

