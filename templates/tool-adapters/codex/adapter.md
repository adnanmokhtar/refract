# Codex / AGENTS.md adapter

**Tool:** OpenAI Codex CLI + the cross-tool `AGENTS.md` standard.
**Docs:** https://developers.openai.com/codex/guides/agents-md | https://agents.md
**Capabilities:** R, partial A (conventions), N (nested AGENTS.md), **S (native Agent Skills at `.agents/skills/<name>/SKILL.md`)** — no hooks, no user-extensible slash commands (built-in slash set is closed: `/model`, `/permissions`, `/compact`, etc.).

> **Agent Skills correction (2026-05)**: prior versions of this adapter claimed Codex had "no executable primitive." That was wrong. Codex implements the **Open Agent Skills standard** — `.agents/skills/<name>/SKILL.md` (repo) / `~/.agents/skills/` (user) / `/etc/codex/skills/` (system). Skills are invoked via the `/skills` picker, by `$mention`, or auto-selected when description matches. Action commands like `/optimize` translate to **Agent Skills**, not to imperative-prose-only AGENTS.md sections. The AGENTS.md fallback remains for tools that consume `AGENTS.md` but lack the Agent Skills standard.

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

Codex CLI has the Open **Agent Skills** standard (`.agents/skills/<name>/SKILL.md`) plus AGENTS.md prose. Commands and skills translate to Agent Skills; agents and reference-only blocks translate to AGENTS.md sections. Other AGENTS.md-only consumers (without Agent Skills support) fall back to the imperative-prose convention.

### Commands → `.agents/skills/<name>/SKILL.md` (NATIVE — Agent Skills standard)

**Path**: `.agents/skills/<name>/SKILL.md` (repo-level — discovered by Codex automatically).
**Invocation**: three paths — (a) `/skills` picker, (b) `$<name>` mention in chat, (c) Codex auto-selects when the user's request matches the skill's `description`.
**Frontmatter**: per the Open Agent Skills spec — `name` (required, `[a-z0-9-]{1,64}`), `description` (required, 1-1024 chars). Body is the workflow prose.

```markdown
.agents/skills/optimize/SKILL.md
---
name: optimize
description: One-command code optimization — deep architectural diagnosis then tactical sweep in parallel waves. Invoke when the user asks to "optimize", "improve quality", "find tech debt", or names this skill via /skills picker / $optimize.
---

# Optimize workflow

> **EXECUTE NOW directive**: When this skill activates (via `/skills`, `$optimize`, or auto-match), do NOT summarise this document and ask the user what to do — immediately begin executing the workflow below against the scope the user named (default: whole repo).

[... workflow body inlined from .claude/commands/optimize.md ...]

## Closure verbs
[... 21-verb closure vocabulary ...]

## Output contract
Write final report to `ai/optimize/final-report.md` ending with `## Actionable next steps`.
```

**Skills list cap**: Codex caps the skills index at ~2% of context (~8K chars total across all skill `description:` fields). Keep descriptions concise — the BODY can be long, the description must be tight.

**Sub-path discovery**: `.agents/skills/<namespace>/<name>/SKILL.md` works for namespacing (e.g., `.agents/skills/migration/scan/SKILL.md`).

### Commands fallback → `## Invokable commands` section in AGENTS.md (for non-Codex AGENTS.md consumers)

For AGENTS.md consumers that do NOT implement the Agent Skills standard (rule-only tools reading AGENTS.md as prose), the adapter ALSO emits an `## Invokable commands` section with the imperative-preamble pattern. Codex itself prefers the Agent Skills path; the AGENTS.md prose is a safety net for AGENTS.md-only consumers (Aider, Gemini, Cline-pre-skills) reading the same file.

**Translation template — imperative-preamble fallback for non-Codex consumers:**

**Translation template — every translated command uses this exact shape:**

```markdown
## Invokable commands

Invoke by asking: "Please run <command>" / "/optimize <scope>" / "run the <name> procedure".

### `optimize` (action command — execute when invoked)

**Invocation phrases**: "run optimize", "optimize <scope>", "/optimize <scope>".

**EXECUTE NOW directive**:
When the user invokes this command, do NOT summarise the workflow below and
ask the user what to do. Begin executing immediately against the scope
the user named (default: whole repo). Drive the workflow to completion or
to an explicit halt; report results, not intent. Read `.claude/commands/optimize.md`
for the full body if needed; this section is a load-bearing summary.

**Workflow** (≤30-line summary from `.claude/commands/optimize.md`):

<command body — trimmed>

**Tool gating** (Codex has no per-section gates — self-gate via this line):
This is a <read-only audit | full-action edit | plan-only write> command.
<For audit-only: "Do not modify files; emit findings only.">
<For plan-only: "Write to `ai/<pack>/plan.md` only; do not edit code.">

**Output contract**: write the final report to `ai/<pack>/final-report.md`
ending with `## Actionable next steps`.

### `tenant-leak-audit` (audit-only — execute when invoked)
<same shape>
```

**Failure mode this preamble prevents**: without "EXECUTE NOW", a user typing "run optimize" in Codex gets a response like "Sure — would you like me to start with architecture or quality findings? Here's what /optimize covers..." The preamble flips that to autonomous execution. The discipline is the same as Kimi subagents' `system_prompt:` field — Codex just has no native subagent primitive to hold it, so it lives inline in AGENTS.md.

**Length discipline**: keep each command ≤30 lines to avoid bloating AGENTS.md (which is loaded on every Codex request). Full bodies stay in `.claude/commands/` — the AGENTS.md section is a summary + pointer. EXCEPT the EXECUTE NOW directive — that block is mandatory and counts toward the 30-line cap; trim the workflow summary first, never the directive.

**Codex-specific limitations**:
- No parallel dispatch — Codex executes serially. For commands that benefit from fan-out (`/optimize`, `/migrate`, `/polish`, `/align`), document that the user can drive parallel execution via `scripts/<command>-parallel.sh` (Codex spawns workers per row via `codex exec`, ledger flock coordinates).
- No headless mode for fully autonomous loops — Codex stays interactive; the user must press through approval prompts. This is a tool-level constraint, not adapter-fixable.

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
- **Refactor pack — companion scripts (2026-05):** Document **`validate-refactor-artifacts.sh`** for `/refactor`; see `templates/tool-adapters/_refactor-pack-coverage.md`.
- **Polish pack — companion scripts (2026-05):** Document **`validate-polish-artifacts.sh`** + **`polish-parallel.sh`** for `/polish` (stack-conditional — frontend / backend / data / mobile evidence); frontend rows additionally gated by **`check_frontend_verb_vocabulary`** against the closed 18-verb **`ui-design-sweep`** set (ui-ux pack v1.1+); see `templates/tool-adapters/_polish-pack-coverage.md` + `templates/tool-adapters/_ui-ux-pack-coverage.md`.
- **Align pack — companion scripts (2026-05):** Document **`validate-align-artifacts.sh`** + **`align-parallel.sh`** for `/align`; see `templates/tool-adapters/_align-pack-coverage.md`.
- **Audit pack — companion scripts (2026-05):** `/audit` artifacts live under `ai/audit/**` (`plan.md`, `progress.md`, per-axis subfiles `_arch.md` / `_quality.md` / `_security.md` / `_db.md` / `_perf.md` / `_scale.md` / `_infra.md` / `_obs.md`, `final-report.md`, `assessment.md`). **Three output modes**: default (execute), `--plan-only` (ranked fix-plan in `plan.md` — executor handoff), `--assess` (8-section senior-engineer narrative in `assessment.md` — what's good / improve / unify / extract / simplify / redesign / remove / optimize — reader handoff). Validator **`validate-audit-artifacts.sh`** ships in `scripts/` — halts on hand-waves (`etc.`, `would be slow`, `at scale this is bad`) and requires P0 findings to cite a target-RPS failure mode (`check_no_handwaves_audit_plan` + `check_p0_failure_mode_cited`; `--strict` adds `<file:line>` citation enforcement on P0/P1/P2). Dispatches existing pack scripts internally (`validate-optimize-artifacts.sh`, `validate-align-artifacts.sh`, `validate-polish-artifacts.sh`) for the architecture / SOLID / clean-code / API-consistency axes; security + DB + scale axes use their respective pack agents and skills directly. See `commands/audit.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Unify-surfaces pack — companion scripts (2026-05):** `/unify-surfaces` (frontend-only, sibling to `/polish`) artifacts live under `ai/unify-surfaces/**` (`progress.md`, per-category inventory, canonical-wrapper decision evidence, `final-report.md`). Validator **`validate-unify-surfaces-artifacts.sh`** is **planned** — will check per-category inventory completeness, canonical-wrapper decision citations, idioms-update co-commit (`_extracted-idioms.md § Wrappers` updated in same commit), `Reuse-Before-Create` enforcement (extracting a duplicate where a shared wrapper exists fails). 7 default categories: tables / forms / headers / tabs / filters / buttons / validation. Validation is a 3-part pipeline (composable + components + API-error mapper), not a single wrapper. Halts on `PROJECT_KIND` not in `frontend-* / mobile-web / mobile-rn` with redirect to `/polish`. See `commands/unify-surfaces.md` + `templates/tool-adapters/_orchestration-sync.md`.
- **Orchestration / validator sync:** **`templates/tool-adapters/_orchestration-sync.md`** — discipline paths (`ai/migrate/progress.md`), optimize oracle fallbacks, align 21-verb closure vocabulary, polish validator env (`QUIET=1`; no `--strict` CLI), refactor hook paths.
- **`/task` integration (MCP-backed):** provider-agnostic task executor — Trello / Jira / Linear / GitHub Issue → fetch → normalize → dispatch → write-back (in-progress → comment → review/done). This tool surfaces it as `.agents/skills/task/SKILL.md` (Open Agent Skills); needs a task-provider MCP from `scripts/detect-mcp.sh` (gated on the repo's own `.env` creds). It routes to Codex specialist skills in place of `/do`. Canonical recipe + per-tool matrix: `templates/tool-adapters/_task-integration-coverage.md`; lifecycle: `commands/task.md`; providers: `templates/integrations/task-providers.md`.
- **Actionable next steps — universal report contract (2026-05):** Every report-producing command (`/optimize`, `/polish`, `/align`, `/migrate`, `/refactor`, `/audit`, `/unify-surfaces`) MUST end its `final-report.md` with a `## Actionable next steps` section per **`templates/snippets/actionable-next-steps.md`** — paste-ready commands. Validator gate: **`check_actionable_next_steps`** halts when missing or prose-not-args. Document in `AGENTS.md` for AGENTS.md-consuming tools.
- Every other adapter references this one — it writes the shared file.
- `claude-code/adapter.md` — source of rule content.
- `gemini/adapter.md` — GEMINI.md is parallel to AGENTS.md for Gemini CLI.
- `ai/references/tool-parity.md` — gap matrix.
