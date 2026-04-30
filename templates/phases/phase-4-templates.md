---
phase: 4
sub-phase: "4-templates"
name: generated-output-templates
purpose: Template skeletons that Phase 4 writes into the target repo (CLAUDE.md, ai/conventions.md, mandatory pre-flight injection, verification block). NOT a phase step — these are the output shapes consumed by Phase 4.
imported-by: templates/phases/phase-4-apply.md, phase-4.2-apply.md
---

## __REGIME__ — research stub (no prebuilt overlay yet)

> User declared this regulatory regime in Phase 2.y but no overlay file exists at
> `~/.claude/templates/regulatory-overlays/__REGIME__.md`.
>
> **Action items** (queued for Phase 6 `/refresh-knowledge`):
> 1. Research: regime overview, jurisdiction, scope, data-residency rules, consent rules,
>    audit cadence, incident-response timelines, regime-specific anti-patterns, required integrations.
> 2. Author overlay at `~/.claude/templates/regulatory-overlays/__REGIME__.md`.
> 3. Re-run `/setup-project --refresh` to consume the new overlay.
>
> Until then: every PR / agent / change touching __SCOPE__ (PII / payments / clinical data / etc.)
> MUST be reviewed against this regime by a human with regime expertise.
>
> **Validator:** TODO — currently self-policed by human reviewer; future validator at `scripts/lint-regime-review.sh § review_attestation` (asserts each PR touching __SCOPE__ carries a regime-review sign-off trailer).
```

`append_research_stub`'s contract: replace every occurrence of `__REGIME__` with the regime name and `__SCOPE__` with the relevant data scope before writing. After substitution the rendered section MUST contain zero `__…__` and zero `<…>` tokens — Phase 5.3.5 leak scan asserts this.

**Phase 5 audit**: confirms `ai/business-compliance.md` has a regime-specific section for each declared regime (concrete overlay or research stub). Missing section = HALT (the user declared a regime that the system silently dropped).

**4.5 Generate missing** — signal detected but no specialized agent exists? Generate from external library (awesome-subagents / agents-main) or best practices. Save to `packs/<track>/agents/<name>.md` for reuse.

**4.6 Adapt output to detected conventions** — this is what makes the setup actually MATCH the project's style instead of overwriting it with generic prose.

**Execution model — delegated to `apply-pack-adaptation` skill**:

Per-file adaptation (STUDY-DECIDE-ACT loop, anchor templates, tie-breaking, extraction-weak handling, special cases for engineering-principles / workflow files) is delegated to `templates/packs/learning/skills/apply-pack-adaptation.md`. Phase 5.3 audits the skill's output (`.claude/_phase-4-6-decisions.md` + adapted files) for anchor presence, body density, identifier traceability, and absence of placeholder syntax. **Do NOT inline the skill's procedure here — that's the source of truth.** This section only documents the contract: what the skill consumes (extraction artifacts + pack file list + mode), what it produces (adapted files + decision log), and what setup-project depends on downstream.

**Auto-injected blocks (every agent — these are setup-project responsibilities, NOT skill-internal)**:

The pre-flight + verification + frontmatter blocks below are injected by setup-project's main loop into every copied/generated agent BEFORE the skill runs. They're cross-cutting (apply to every agent regardless of file category) and orthogonal to per-file adaptation (which the skill handles).

**Pre-flight injection (every agent)** — every copied agent's frontmatter body gets a mandatory tiered pre-flight section prepended:

```markdown
## Pre-flight (auto-injected — tiered context loading)

### Always (Tier 1)
1. `ai/_session-digest.md` — compact bootstrap (project + stack + top conventions + recent decisions + corrections to avoid).

### Load by task type (Tier 2)
- Code-write tasks → `ai/_convention-cheatsheet.md` (top 20 rules)
- Feature work → `ai/business-domain.md` + `ai/business-flows.md`
- Architectural decisions → `ai/_decision-index.md`
- Bug fix → `ai/runtime/context.md`

### Load on demand (Tier 3)
- Full `ai/conventions.md` (when cheatsheet isn't enough)
- Full `ai/patterns/<name>.md` (when applying that pattern)
- Specific `ai/decisions/<NNNN>-*.md` (when relevant to architectural decision)
- Specific `.claude/rules/<name>.md` (deep dive into a rule)

### Before modifying (mandatory discovery — applies to every code change)
- **Identify inputs, outputs, and dependencies** of the function / class / module you're about to change. Inputs = parameters + reads from outer scope (env, config, DB, network). Outputs = return value + writes (DB, files, events, logs, mutations of inputs). Dependencies = direct callees + injected services + imports. If you can't trace these in ~2 minutes (signature read + caller grep + downstream effects scan), STOP — read more, or ask. The "I'll figure it out as I go" pattern is how silent regressions ship.
- **Read the existing file you're modifying** — MIRROR its shape exactly (imports order, error-handling style, logging style, comment density). The file is the local style guide; deviation is a bug.
- **Read 1-2 sibling files** in the same layer to confirm the shape is project-wide, not just local to one file. Two siblings agreeing = pattern; one file alone = could be drift.
- **Locate the home before writing new code.** Every new file / module / feature must map to a defined home in `ai/modules.md`. If nothing fits, plan a new module first (record an ADR if architectural) or ask. Loose files in the repo root or in catch-all `utils/` / `shared/` / `common/` folders is the failure mode this rule prevents.

### Boy Scout Rule (when modifying)
- Leave the file cleaner than you found it: kill dead imports, delete commented-out code, sharpen vague names, cut redundant comments — but ONLY adjacent to your change. Don't balloon the diff into a whole-file rewrite; one obvious cleanup per touched file is the bound. Real refactors get their own PR with a stated reason.

If your task contradicts what you read at any tier, STOP and ask before acting.
```

**Verification injection (every agent)** — Anthropic's #1 leverage point: agents that ship plausible-looking-but-wrong code lose user trust fast. Every generated agent's frontmatter body gets a mandatory `## Verification` section appended:

```markdown
## Verification (how you know your work succeeded)

Before reporting done, run + show:
1. <Stack-detected lint command — e.g., `pnpm lint` / `mvn checkstyle` / `cargo clippy`>
2. <Stack-detected type-check — e.g., `pnpm typecheck` / `mypy` / `tsc --noEmit`>
3. <Stack-detected tests for the touched module — e.g., `pnpm test path/to/module`>
4. For UI changes: screenshot via Playwright + visual diff.
5. For API changes: hit the endpoint via curl + verify response shape against DTO (use `/endpoint-test`).
6. For DB changes: `EXPLAIN ANALYZE` the affected queries; confirm indexes used.

Failed verification = halt + report, don't paper over.
```

The verification commands are STACK-DETECTED at setup time (Phase 4.6 ADAPT step) so each agent's verification list cites the actual commands the project uses, not generic placeholders.

**Frontmatter constraints (every generated agent)** — token + permission discipline:

```yaml
---
name: <agent-name>
description: <one-line; first ≤90 chars are the matching keyword cluster>
tools: [Read, Grep, Glob, Bash]   # explicit allowlist; default to MINIMUM needed
model: sonnet                      # opus for complex reasoning; haiku for cheap exploration; sonnet default
---
```

Model assignment by agent type:
- **Architect / reviewer / decision-maker**: `opus` (worth the cost for hard reasoning).
- **Default agents**: `sonnet`.
- **Cheap explorers** (find-module, grep-heavy lookups, doc-drift-scan): `haiku`.
- **Test runners + lint runners**: `haiku` (deterministic work).

`tools:` constraint — generated agents get the MINIMUM needed:
- Architects + reviewers: `[Read, Grep, Glob]` (no Edit — they design, they don't implement).
- Implementers: `[Read, Grep, Glob, Edit, Write, Bash]`.
- Test runners: `[Read, Bash]`.
- Skip if absent (defaults to all tools — only do this for top-level orchestrator agents).

This injection is non-negotiable: every agent (pack, generated, framework-specific) gets it. Agent frontmatter `description` field stays as-is from the pack; only the body + frontmatter `tools:`/`model:` get adjusted.

**Per-file adaptation (path injection + convention prose injection + per-rule adaptation shape)** — handled by the `apply-pack-adaptation` skill (see "Execution model" at the top of this section). The skill produces:

- A **`## Reference paths`** section in every generic agent, populated with real base-class paths + extender counts from `.claude/_extracted-codebase.md` (never hand-written, never carried from another project's run).
- A **`## Project-specific (<project-name>)`** block at the TOP of every adapted rule, citing this codebase's actual file/class/property/DB-column/DI/test naming + base classes + helpers (data access, DTOs, controllers, error hierarchy) — all sourced from extraction.
- The **STUDY → DECIDE → ACT loop** per file (CHANGE-anchor / CHANGE-anchor-with-warn / LEAVE-with-redirect / LEAVE-delete) — see skill § "Decision matrix."
- The **`[EXTRACTION-WEAK]`** flag on anchors produced when extraction has no signal for the topic — Phase 5 audit reports these.

The skill's anchor templates are the canonical shapes. Phase 5.3 audits anchor quality (presence + body density ≥3 lines + identifier traceability for path-citing categories + no placeholder syntax + leak scan against extraction). Anti-patterns the audit catches: missing anchor (skill skipped), thin anchor ("`'this project uses TypeScript'`"-class lazy output), placeholder anchor (`<RepositoryBase>`, `<TODO>`), leaked anchor (cites identifier not in extraction).

**Tie-breaking**: see Decision engine § "Tie-breaking" — detected convention wins; pack rule body stays below the project-specific block.

**What gets adapted (per detected facet)**:
| Detected facet | Adaptation site |
|---|---|
| Naming patterns | Top of every rule + `ai/conventions.md` |
| Base class paths | "Reference paths" section in agents + rules |
| Test framework + colocation | `.claude/rules/testing.md` adaptation; agent pre-flight |
| Error handling base + mapper | `.claude/rules/error-handling.md`; controller agent |
| Auth scheme + guards | `.claude/rules/auth.md`; security agents |
| i18n key convention | `.claude/rules/i18n.md`; frontend agents |
| Module folder layout | `.claude/rules/module-structure.md`; api-architect's "File list" template uses detected layout |

**4.7 Knowledge base** — adaptive output:
- Always include `ai/references/models.md` from `~/.claude/templates/repo-baseline/ai/references/` (driver → model routing map, Kimi/local recipes).
- CREATE: generate `CLAUDE.md`, `ai/architecture.md`, `ai/stack.md`, `ai/modules.md`, `ai/status.md`, `ai/conventions.md` (see special handling below), `ai/patterns/project-structure.md` + 1-3 project-critical patterns, `ai/runbooks/phase-1-mvp-plan.md` (DOMAIN-FLAVORED — if ecommerce, the MVP plan covers cart→checkout→pay; if lms, course-creation→enrollment→first-lesson), 2-4 ADRs. All concrete content, no placeholders.
- CREATE knowledge base must also reference the business domain in `CLAUDE.md` opener: "This is a `<domain>` product. Read `ai/business-domain.md` for entities + canonical flows."
- ENHANCE: leave user-authored `ai/` files untouched. Only prepend a dated `Recent Changes` entry to `ai/status.md`. Add new files (ADRs, patterns, business-domain content) ONLY if a new concept emerged; never rewrite existing.

**Tiered context loading (NOT mandatory pre-Phase-4 deliverables):** the 6 foundational files (`CLAUDE.md`, `ai/conventions.md`, `ai/business-domain.md`, `ai/core/glossary.md`, `ai/project-goals.md`, `ai/users-and-personas.md`) are **Tier 1 context** — loaded on demand by agents that need them. They are NOT a doc-before-code gate that blocks Phase 4 from emitting code-touching output. CREATE-mode commands (which establish these from scratch) DO populate them in Phase 5 (Update). ENHANCE / REFRESH commands consult them when present and skip recreation when absent — they don't backfill foundational docs as a side effect.
**Validator:** Phase 5.3 verifies, per mode: CREATE → all 6 present + populated; ENHANCE/REFRESH → no recreation of user-authored versions, only `Recent Changes` append where applicable.

**`ai/conventions.md` MUST be auto-populated from the codebase profile** (not generic). Generic conventions ("use camelCase") are useless. The file content is built from Phase 2 detection results — every value below is a placeholder filled at write time from `.claude/_extracted-codebase.md`. The LLM authoring this file MUST NOT carry concrete class names / paths / library names from any other project's run.

**Validator (auto-populate):** Phase 5.3 confirms each MUST-populate file (`ai/conventions.md`, `ai/business-domain.md`, `ai/core/glossary.md` when applicable) exists and has non-stub content (line count ≥ minimum + zero `_TBD_` / `_UNKNOWN_` markers in required sections).
**Validator (no leak):** Phase 5.3.5 leak-scan asserts zero `__…__` and `<…>` placeholder tokens after render, and cross-checks every cited identifier against `.claude/_extracted-codebase.md` (see `scripts/lint-decision-logs.sh § leak_scan`).

```markdown
# Project conventions

Auto-populated from `.claude/codebase-profile.md` on <DATE>. Re-run `/setup-project` to refresh.

## File naming
- Source files: <detected pattern from extraction — kebab / snake / camel / pascal>.<detected ext>
- Test files: <detected pattern>.<detected ext> (location: <colocated | separate test/ dir>)
- Migration files: <detected pattern — e.g. timestamp-prefix or sequence>

## Class + identifier naming
- Classes: <detected case>
- Properties: <detected case>
- DB columns: <detected case — snake / camel / pascal>
- Constants: <detected case>
- Suffix matrix (only fill rows the codebase actually uses; omit rows that don't apply):
  | Concept | Suffix in this codebase | Example file from extraction |
  |---|---|---|
  | <e.g., Service / Handler / UseCase / Resolver — whichever this codebase uses> | <detected suffix> | <real example path from extraction> |
  | <e.g., Controller / Router / View / Endpoint> | <detected suffix> | <real example path> |
  | <e.g., Repository / DAO / Query / Mapper> | <detected suffix> | <real example path> |
  | <e.g., DTO / Schema / Form / Serializer / Pydantic model> | <detected suffix + create/update prefix if any> | <real example path> |
  | <e.g., Entity / Model / Record> | <detected suffix> | <real example path> |
  ... (only rows the project's extraction shows — do NOT add hypothetical rows)

## Layer architecture (from `ai/architecture.md`)
- <detected dependency direction — e.g., core → application → infrastructure, or controllers → services → repositories, or whatever shape Phase 2 found>
- Layer enforcement: <yes via dependency-cruiser / arch-unit / lint plugin, or no — detected at Phase 2>

## Base classes (from codebase profile — list ONLY base classes with ≥3 extenders found in extraction; OMIT this section if the project doesn't use inheritance-based bases)
- `<DetectedBase>` at `<detected/path>` — extended by <N> <subjects>
- `<DetectedBase>` at `<detected/path>` — extended by <N> <subjects>
- ... (one line per real base from extraction; never invent)

## Code style (from manifest + formatter config)
- Language version: <from manifest — TypeScript x / Python x / Go x / Rust edition / Ruby x / etc.>
- Formatter: <detected — Prettier / Black / gofmt / rustfmt / RuboCop / etc.> with <detected settings: quote style, trailing comma, line width, indent>
- Linter: <detected — ESLint / Ruff / golangci-lint / Clippy / etc.> with <detected plugin set>
- Strict typing: <detected — yes/no based on tsconfig strict / mypy strict / Sorbet / etc.>
- Unused-var convention: <detected — _-prefix / underscore_ / inline disable comment>

## Testing (from extraction Step 10)
- Framework: <detected — Jest / Vitest / Pytest / Go test / RSpec / etc.>
- File naming: <detected suffix>
- Location: <detected — colocated with source / separate test/ dir / mirrored tree>
- Mock style: <detected — fixture / spy / fake / contract>
- E2E: <separate dir + suffix, OR not detected>

## Imports + aliases (from tsconfig / pyproject / module manifest)
- <detected alias 1> → <detected target>
- <detected alias 2> → <detected target>
- ... (only real aliases; omit if project doesn't use any)
- Relative-parent depth limit: <detected from grep / lint, or "no rule detected">

## Anti-patterns to flag (from codebase scan — counts only; we don't fix)
- `<noisy-debug primitive — e.g., console.log / print / fmt.Println / dbg!>` count: <N> instances → use <detected logger from extraction>
- `<broad-type — e.g., any / interface{} / dict / Object>` count: <N> instances → never add new ones
- Swallowed errors (`<detected pattern — e.g., catch {} / except: pass / .ignore()>`): <N> instances → never add new ones

## When this file conflicts with `.claude/rules/*.md`
This file (auto-detected from real code) wins. Pack rules adapt above it via the "Project-specific" block at the top of each rule.
```

If a facet wasn't detected (CREATE mode, no code yet), write `_TBD — populate as code is written_` rather than generic defaults. **Never** copy values from a different project's extraction into this template — that's the leak failure mode Phase 5.3.5 (leak scan) catches.

`CLAUDE.md` opener structure (ALWAYS this shape, regardless of stack):

```markdown
# <Project> — Project Rules

## You are the Principal Engineer of this project

When working in this codebase, you act as a Principal Engineer / Tech Lead — not an assistant. That means:

- Decisions, not surveys. Pick the right approach + state the reason. Survey only when explicitly asked.
- Push back on bad ideas. "That'd work but cost X — Y is better because Z." Then proceed if user confirms.
- Cite prior art. Use this codebase's conventions + the established patterns documented below.
- Think in 6-month consequences, not next-commit consequences.
- Audit your own output. If two of your suggestions contradict, fix them before reporting.
- Teach in the artifacts. Comments + commits + ADRs explain WHY, not just WHAT.

## Project at a glance

- **Mission**: <one-sentence from `ai/project-goals.md`>
- **Domain**: <ecommerce | lms | ...> — see `ai/business-domain.md`
- **Stage**: <P1 MVP | P2 monetization | P3 scale | mature> — see `ai/status.md`
- **Primary user**: <persona from `ai/users-and-personas.md`>

## Detected stack + conventions (this is what your code already looks like)

- Stack: <detected list — language, framework, ORM, runtime, build tool>
- File naming: <detected pattern>
- Class / identifier naming + suffix matrix: <detected pattern>
- Base classes / patterns this project uses: <list ONLY real bases from extraction with their paths + extender counts; OMIT this line if the project doesn't use inheritance-based bases>
- Test colocation: <detected — colocated/separate, pattern>
- Auth scheme: <detected — JWT/session/OAuth/none>
- DB column naming: <detected — snake_case / camelCase / etc., or n/a if no DB>
- Logger lib: <detected from extraction — replaces ad-hoc print statements>
- i18n lib + locales: <detected — replaces hardcoded strings, or n/a>

> Every value above comes from `.claude/_extracted-codebase.md`. Do NOT invent or copy from another project.

For full conventions: see `ai/conventions.md`.

## Required reading before ANY code change

In this exact order:
1. This file (`CLAUDE.md`).
2. `ai/conventions.md` — auto-detected style + naming.
3. `ai/business-domain.md` — what kind of product this is + entities.
4. `ai/project-goals.md` — mission + KPIs + anti-goals.
5. `ai/dynamic/feedback-learned.md` — corrections from prior sessions (don't repeat them).
6. The existing module you're editing — MIRROR its shape exactly.

If the task contradicts what you read in 1-6, STOP. Ask the user before acting.

## Read-before-edit rule (#1 invariant)

Before creating or modifying any file, read the same TYPE of file (controller, service, repo, mapper) elsewhere in the codebase and match the existing pattern exactly. Consistency with existing code beats personal preference.

## Decision boundaries

You CAN decide and proceed without asking:
- Code-level implementation matching existing patterns
- Test additions for the change you're making
- Lint / format fixes within the file you're editing
- Naming choices that follow the suffix matrix

You MUST ask before:
- Adding a new dependency (`pnpm install`).
- Introducing a new architectural layer or pattern.
- Touching > 10 files in one PR.
- Migration / schema change.
- Anything that affects > 1 sub-project (in workspace mode).
- Editing `ai/decisions/` (formal ADRs).

## When you find drift

If existing code violates a documented rule:
- Don't silently fix it (that's scope creep).
- Append finding to `ai/dynamic/drift-log.md` for resolution by the user / curator.
- If the violation blocks your current task, raise it explicitly and ask how to proceed.

## When the user is wrong

Push back briefly + concretely:
> "I'd avoid X because <Y consequence>. The standard for this codebase is Z (see `ai/patterns/<file>.md`). Want me to do Z, or proceed with X anyway?"

Don't capitulate without surfacing the trade-off. Don't lecture either — one or two sentences.

## Tiered context loading (token discipline)

This project uses **3 tiers** of knowledge files. DON'T load everything every session.

### Tier 1 — HOT (auto-loaded via @ at session-start)

@ai/_session-digest.md

That's it. The session digest is a compact (≤300 lines) projection of what matters right now. It includes pointers to deeper files for when you need them.

### Tier 2 — WARM (load by task type)

When working on:
- **Code edits** → also read `ai/_convention-cheatsheet.md` (top 20 rules, ≤80 lines)
- **New feature** → also read `ai/business-domain.md` + `ai/business-flows.md`
- **Architectural decisions** → also read `ai/_decision-index.md` (drill into specific ADRs only when relevant)
- **Bug fix** → also read `ai/runtime/context.md` + relevant `ai/patterns/`
- **Audit / review** → read `ai/conventions.md` (full) + `.claude/rules/`

### Tier 3 — COLD (load on demand only)

- Specific `ai/patterns/<name>.md` files when applying that pattern.
- Specific `ai/decisions/<NNNN>-*.md` files when discussing that decision.
- Specific `.claude/rules/<name>.md` files when working in that domain.
- `ai/audits/`, `ai/runbooks/`, `ai/dynamic/` files only when needed.

### Why tiered?

Naive "read everything" pre-flight burns 3000+ lines of context per agent invocation. Tiered loading: <500 lines for Tier 1 covers ~80% of decisions; Tier 2 + 3 load on demand for the rest. **7× token reduction on bootstrap.**
```

The opener is the FIRST thing Claude reads in every session. The Principal-Engineer framing + tiered context loading + decision boundaries + push-back posture mean every subsequent task picks them up automatically — no per-task re-instruction.

**4.7b Project-context files** (consume `.claude/_extracted-business.md` from Phase 2 Step 13):

The `extract-business-context` skill has captured WHY this project exists, FOR WHOM, and AT WHAT MATURITY into `.claude/_extracted-business.md`. Phase 4.7b PROJECTS that into 5 user-facing files. **Generators here ASK NOTHING** — every needed answer is already in `_extracted-business.md` (or marked `_UNKNOWN_` there for genuine gaps). If 4.7b finds itself wanting to ask the user a question, that's an `extract-business-context` skill bug — fix the skill, don't bolt the question on here.

| File | Source section in `_extracted-business.md` | Content |
|---|---|---|
| `ai/project-goals.md` | `## Mission` + `## Success KPIs` + `## Constraints` + `## Anti-goals` | Mission statement; top 3 KPIs with target numbers; explicit non-goals; success criteria |
| `ai/users-and-personas.md` | `## Target users + personas` | 1-3 primary personas (job role, context, top 3 needs, top 3 frustrations, what makes them choose this product) |
| `ai/business-model.md` | `## Business model` | How money flows or value is delivered; pricing model if monetized; cost structure; unit economics one-liner |
| `ai/competitive-context.md` | `## Competitive context` | Closest 1-3 alternatives; why this product instead; what NOT to copy from competitors; differentiation themes |
| `ai/roadmap.md` | `## Maturity stage` + `ai/status.md` phase | Beyond P1 — what's the trajectory? Phase 2/3/4 high-level (1-2 paragraphs each, not detailed runbooks — those live in `ai/runbooks/`) |

**Population rules:**
- CREATE mode: write all 5 with content from Phase 2.y. If user couldn't answer a facet, write `_UNKNOWN — fill in when decided_` placeholder rather than fake content.
- ENHANCE mode + files absent: write them, populate from existing `ai/status.md` + ask user for the gaps.
- ENHANCE mode + files present: leave them. Append a one-line update to whichever facet changed (similar to status.md Recent Changes).
- The brain refuses to use `_UNKNOWN_` content as input to other generated files — surface them in the plan as "decisions blocked on these unknowns".

**Why these files matter:**
- New session opens → reads `CLAUDE.md` → CLAUDE.md links to these → instant project context.
- Agent working on a feature → consults `ai/users-and-personas.md` → makes UX/i18n/error-message decisions in user's vocabulary, not engineer's.
- Audit / business-auditor agent → consults `ai/project-goals.md` → flags features that drift from declared mission.
- Roadmap-agent or PM → consults `ai/roadmap.md` → proposes work that fits trajectory, not random improvements.

CLAUDE.md opener (CREATE) must reference these:
> "This is a `<domain>` product. **Mission**: `<mission from project-goals.md>`. **Primary user**: `<persona from users-and-personas.md>`. **Stage**: `<maturity stage>`. Read `ai/project-goals.md` + `ai/users-and-personas.md` + `ai/business-domain.md` before starting any non-trivial task."

