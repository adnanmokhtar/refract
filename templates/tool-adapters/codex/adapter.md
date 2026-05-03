# Codex / AGENTS.md adapter

**Tool:** OpenAI Codex CLI + the cross-tool `AGENTS.md` standard.
**Docs:** https://developers.openai.com/codex/guides/agents-md | https://agents.md
**Capabilities:** R, partial A (conventions), N (nested AGENTS.md) — no hooks/skills/commands.

**Canonical owner of `AGENTS.md`.** This adapter writes the universal `AGENTS.md` file consumed by Codex, Cursor (fallback), Aider (via `read:`), Amp, Cline, Copilot, Windsurf, OpenCode, Gemini CLI (fallback), and any future AGENTS.md-aware tool. **The `claude-code` adapter intentionally does not write `AGENTS.md`** — it produces `CLAUDE.md` + `.claude/`, and this adapter compacts those into the cross-tool anchor. Writing AGENTS.md correctly is the single highest-leverage action across the whole adapter system.

## Target files

```
repo-root/
├── AGENTS.md                          # THE cross-tool canonical (every adapter references this)
├── AGENTS.override.md                 # Optional; takes precedence over AGENTS.md (per-machine overrides)
├── <subdir>/AGENTS.md                 # Optional; nested overrides for sub-modules
└── ~/.codex/config.toml               # Codex CLI-global config (NOT project-scoped — out of scope)
```

## File formats

### `AGENTS.md` (root)
Plain markdown. No frontmatter. Convention (per agents.md spec):
- **Managed-by marker** — first line of file MUST be the HTML comment `<!-- managed-by: codex -->`. This serves two purposes: (a) signals that this adapter owns the file (other adapters will not rewrite it; they only append cross-references in their own clearly-marked sections); (b) lets Phase 3.2 auto-detection recognize Codex as a target tool without false-positives on every project that happens to have an `AGENTS.md`.
- **Repo overview** — one paragraph: what the project is.
- **Architecture** — short structural description.
- **Key commands** — `npm run dev`, `pnpm test`, etc.
- **Conventions** — MUST / MUST NOT rules.
- **Code style** — language-specific style pointers.
- **Testing** — how to run tests.
- **Deployment** — short summary or pointer.
- **AI-tool deep links** — a final section pointing at `.claude/`, `.cursor/rules/`, etc. so users know where the depth lives.

### Nested `AGENTS.md`
Same format. Scopes to the subdirectory. Codex walks from git root down to cwd and concatenates all AGENTS.md files it finds. Useful for monorepos (e.g., `apps/<app-name>/AGENTS.md` scoped to that specific app).

### `AGENTS.override.md`
Same format. Codex reads this BEFORE `AGENTS.md` and lets its content override. Typical use: per-machine env hints, local-only instructions. Add to `.gitignore` — not committed.

## Translation recipe

`AGENTS.md` is the **compacted superset** of:
1. Project overview from `ai/README.md` intro.
2. **Discipline-enforcement block** (`templates/tool-adapters/_discipline-enforcement.md` — paste verbatim between `<!-- discipline-enforcement:start -->` / `<!-- discipline-enforcement:end -->` markers). Locks every AGENTS.md-reading tool (OpenCode, Cursor fallback, Aider, Copilot, Cline, Windsurf, Codex, Kimi) into canonical pack paths + halts. **MANDATORY when any of migration / align / optimize / polish / per-pack-audit packs are loaded** — without this block, OpenCode and other tools deviate from canonical paths (e.g. write `.claude/_v1-scan-inventory.md` instead of `ai/migration/scan-report.md`). Inject AFTER project overview, BEFORE Architecture.
3. Architecture from `ai/architecture.md` top section.
4. Conventions from `CLAUDE.md` + `.claude/rules/` summaries.
5. Commands from `package.json` scripts (detected).
6. AI-tool pointers to `.claude/`, `.cursor/rules/`, `.continue/rules/`, `.github/instructions/`, etc.

Template structure:
```markdown
<!-- managed-by: codex -->
# <Project Name>

<One-paragraph overview.>

## Architecture
<One-paragraph architecture summary.>

## Key commands
- `<install>` — install dependencies
- `<dev>` — start dev server
- `<test>` — run tests
- `<lint>` — lint
- `<build>` — build for production

## Conventions
### MUST
- <top 5-8 MUST rules>
### MUST NOT
- <top 5-8 MUST NOT rules>

## Code style
- <language>: <formatter + rules>
- Line width: <N>
- Quotes: <single/double>

## Testing
<How to run, where tests live, patterns.>

## Project structure
```
<tree fragment pointing at key folders>
```

## Deeper context
- `ai/README.md` — knowledge base navigation
- `ai/status.md` — current state + roadmap
- `ai/decisions/` — ADRs
- `ai/patterns/` — worked-example patterns
- `.claude/rules/` — detailed per-domain rules (loaded by Claude Code)
- `.cursor/rules/` — Cursor path-scoped rules
- `.github/instructions/` — Copilot path-scoped instructions

## AI-tool adapters present in this repo
<list of adapters detected by /setup-project, e.g.:>
- Claude Code (.claude/, CLAUDE.md)
- Cursor (.cursor/rules/)
- Aider (.aider.conf.yml + CONVENTIONS.md)
- Continue.dev (.continue/config.yaml)
```

## Idempotency

Generator marker above the "Deeper context" section:
```markdown
<!-- GENERATED BY claude-setup-project. User edits below persist. -->
```

User-owned section: anything below the marker. Generator overwrites above.

## Known gotchas

- **Nested AGENTS.md:** Codex walks parent directories, concatenating. If you have deep monorepo nesting, each nested AGENTS.md adds to the context on every request. Keep nested ones short.
- **`AGENTS.md` vs `AGENTS.md` casing:** standard is exactly `AGENTS.md` (uppercase). Some tools accept lowercase — don't rely on it.
- **60k+ repos** now use `AGENTS.md` (as of 2026). Consumer tools: Codex, Cursor, Aider, Copilot, Cline, Amp, Jules, Factory, Zed, Warp, goose, VS Code. Writing this file is the highest-leverage single action this adapter performs.
- `AGENTS.override.md` is Codex-specific. Other AGENTS.md consumers don't know about it. Don't rely on it for cross-tool overrides.
- Keep AGENTS.md **under 200 lines**. Anything longer bloats every request's context. Depth belongs in `.claude/rules/`, `ai/patterns/`, etc.

## Sample output (SHAPE only — values come from extraction at run time)

> Every concrete value below is a placeholder. The actual `AGENTS.md` written by `/setup-project` is filled from `.claude/_extracted-codebase.md` + `.claude/codebase-profile.md` + `.claude/_extracted-business.md` + `ai/_convention-cheatsheet.md` for THIS codebase. Never copy concrete class names / paths / library names / domain summaries from one project's adapter output into another's.

```markdown
# <project name from package.json / repo / prompt>

<one-paragraph product description from `.claude/_extracted-business.md` § Mission — actual product, actual users, actual market>

## Architecture
<one-paragraph from `.claude/codebase-profile.md` § Architecture — detected layering style + real folder names + multi-tenancy / single-tenant / etc. as found in extraction>. See `ai/architecture.md`.

## Key commands (auto-detected from manifest)
<list — extracted from package.json scripts / Makefile targets / pyproject.toml / Cargo.toml; show ONLY the scripts the project actually defines>

## Conventions (top 6-10 from `ai/_convention-cheatsheet.md` — generated for THIS project)
### MUST
- Read before edit: read the same type of file elsewhere before creating or modifying.
- <Convention 2 — generated from extraction; e.g., "Extend the project's `<RealBaseClass>` for <real responsibility>" with real values>
- <Convention 3>
- <...>

### MUST NOT
- Use `<broad-type-from-extraction — e.g. any / interface{} / dict>`.
- Use `<noisy-debug-from-extraction — e.g. console.log / print>` — use the project's `<detected logger lib>`.
- <Anti-pattern 3 from extraction>
- <...>

## Code style (from manifest + formatter config)
- Language version: <detected>; quote / trailing-comma / line-width / indent: <detected from formatter config>.
- File naming: <detected case>; class naming: <detected case>; property naming: <detected case>; DB column naming: <detected case or n/a>.

## Testing (from extraction Step 10)
- Framework: <detected>. Tests live <colocated | in test/ dir>; suffix: <detected>.
- E2E: <detected setup or "not detected">.
- Mocking discipline: <project-specific from extraction — e.g., never hit a real <external>; use the test harness for <X>>.

## Project structure (from extraction Step 4 — actual folders, not invented)
<emit a tree of the project's REAL top-level dirs as found by Phase 2; never invent folders that don't exist>

## Deeper context
- `ai/README.md`, `ai/status.md`, `ai/decisions/`, `ai/patterns/`
- `.claude/rules/` — per-domain rules (Claude Code)
- `.github/instructions/` — path-scoped rules (Copilot, if selected)

## AI-tool adapters (only list the ones THIS project's `--tools=` selected)
- Claude Code: `.claude/` + `CLAUDE.md`
- <Other adapters present in this project>
```

The brain MUST source every value above from this codebase's extraction. Inventing concrete details that aren't in the extraction is the leak failure mode Phase 5.3.5 catches.

## Full artifact translation

Codex / AGENTS.md consumers have NO native command/agent/skill/hook support — the AGENTS.md file is prose only. Translate each artifact as a named section the user invokes verbally.

### Commands → `## Invokable commands` section in AGENTS.md

```markdown
## Invokable commands

Invoke by asking: "Please run <command>".

### endpoint-test
<body of .claude/commands/endpoint-test.md — trimmed to ~30 lines>

### tenant-leak-audit
<body — trimmed>
```

Keep each command ≤30 lines to avoid bloating AGENTS.md. Full bodies stay in `.claude/commands/` — the AGENTS.md section is a summary + pointer.

### Agents → `## Named personas` section

```markdown
## Named personas

Invoke by asking: "Act as the <name> agent".

### backend-reviewer
**Persona**: <agent body — trimmed to ~20 lines>
**Scope**: <from agent frontmatter>
**When to use**: code review on backend changes.

### tenant-isolation-reviewer
...
```

### Skills → `## Named procedures` section

```markdown
## Named procedures

### module-scaffold
<body — trimmed>
Shell scripts at `.claude/skills/module-scaffold/` — user runs manually.
```

### Hooks → `## Driver-dependent safety` section + git hooks

```markdown
## Driver-dependent safety

This project uses Claude Code hooks for guardrails. When running via Codex / AGENTS.md-only drivers, these are not auto-enforced:

| Claude Code hook | Fallback |
|---|---|
| post-edit-check.sh | Git pre-commit hook + CI |
| pre-edit-guard.sh | `.gitignore` + file advisory below |
| session-start.sh | This section — read `ai/status.md` first |
| update-session-log.sh | Manual — append to `ai/dynamic/session-log.md` |

Files not to edit: `.env*`, `*.lock`, `prisma/migrations/`, `database/migrations/`. If the tool tries, refuse.
```

### AGENTS.md bloat watch

When all 4 artifact types translate to AGENTS.md, the file can grow past 500 lines. Rules:
- Keep each artifact section ≤30 lines.
- For more than 5 commands / 5 agents / 5 skills, split into nested `AGENTS.md` in subfolders (Codex walks down) OR keep the bulk in `.claude/` and use AGENTS.md as a catalog-with-pointers ("Full definitions in `.claude/agents/backend-reviewer.md`").

## Cross-references

- **Migration pack — companion scripts (2026-05):** Document in `AGENTS.md` / setup notes that migration users install the **full** script bundle from `claude-config/scripts/` into `~/.claude/scripts/`, not only `validate-migration-artifacts.sh`. Canonical list: `templates/tool-adapters/_migration-pack-coverage.md` § **Companion scripts (2026-05)**.
- **Optimize pack — companion scripts (2026-05):** Document **`validate-optimize-artifacts.sh`** + **`optimize-parallel.sh`** for `/optimize`; see `templates/tool-adapters/_optimize-pack-coverage.md`.
- Every other adapter references this one — it writes the shared file.
- `claude-code/adapter.md` — source of rule content.
- `gemini/adapter.md` — GEMINI.md is parallel to AGENTS.md for Gemini CLI.
- `ai/references/tool-parity.md` — gap matrix.
