---
artifact: canonical-command-template
purpose: How any generated operational command should be structured (8-phase template). Applies to commands generated INTO target repos, not to /setup-project itself.
imported-by: Phase 4 when generating commands into a target repo's .claude/commands/.
---

## Canonical command structure (every operational command follows this)

Commands declare which phases apply based on type. Below are the 7 phases — your command uses the **subset matched by your command type**, not all 7 by default. Skipping is the default, not the exception: trivial commands carry no ceremony they don't need.

The 7 phases:

```
Understand → Organize → Retrieve → Generate → Update → Validate → Improve
```

### Phase selection by command type (consult FIRST, before reading phase descriptions)

| Command type | Phases that apply |
|---|---|
| Build / add (e.g., `/add-feature`, `/add-module`) | All 7 |
| Fix / debug (e.g., `/fix-bug`) | All 7, with Phase 4 = TDD (failing test first) |
| Audit / review (e.g., `/security-audit`, `/detect-drift`) | 1-3 + 6 (no Generate/Update; output is findings) |
| Maintain / refresh (e.g., `/refresh-knowledge`) | 1, 3, 5, 6 (no Generate; is updating the knowledge layer itself) |
| Diagnostic / read-only (e.g., `/log-tail`, `/find-module`) | 1, 3 (Retrieve dominates) |

**Every command MUST declare which phases apply** at the top of its file, even if it's "all 7". This makes deviations visible. For phases that don't apply, write a one-line `## Phase X — N/A — <reason>` block rather than silently omitting.

Each phase has a specific job; skipping a phase that DOES apply to your command type leaves a gap that shows up as a bug, drift, or lost knowledge.

### Canonical command template

```markdown
---
description: <one line — first ≤90 chars front-load the matching keywords>
---

# /<command-name> [<args>]

<one paragraph: what this command does + when to use>

## When to use / NOT to use
- USE: <2-4 trigger scenarios>
- NOT: <2-4 anti-scenarios — use a different command for X>

## Phase 1 — Understand (the ask)
- Parse args, clarify ambiguity (ONE consolidated question if needed; never silently assume).
- State the success criteria in your own words and confirm with the user before proceeding (unless trivial).
- Identify scope boundaries: what's IN, what's explicitly OUT.

## Phase 2 — Organize (decompose the work)
- Break the task into discrete steps.
- Identify which knowledge sources to consult (Phase 3), which agents to dispatch, which skills to run.
- For complex work: produce a mini-plan + pause for confirmation.
- For trivial work: skip the pause, proceed.

## Phase 3 — Retrieve (read the right context)

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](snippets/phase-3-always-reads.md) (single canonical list). Do not paste the seven-path block inline in generated commands.

**SOLID + clean-code discipline** — read [`templates/governance/core-discipline.md`](governance/core-discipline.md) before generating or refactoring code.

### Reusable snippets

If your command uses a **hand-wave grep** gate, **intent routing**, or **instrumentation parity** checks, link to the canonical snippets under [`templates/snippets/`](snippets/) — do not restate long procedural blocks.

SIGNAL-BASED (read additional context based on detected signals):
| Signal | Read these |
|---|---|
| Multi-tenant | `ai/patterns/multi-tenancy.md`, `.claude/rules/multi-tenancy.md` |
| Webhook | `ai/patterns/webhook-flow.md`, `.claude/rules/webhook-signature-verification.md` |
| AI / LLM | `ai/patterns/prompt-builder.md`, `.claude/rules/ai-cost-discipline.md` |
| Payment | `ai/patterns/payment-integration.md`, `ai/patterns/idempotency.md` |
| <other domain signal> | <relevant patterns + rules> |

EXISTING CODE (read before designing/editing):
- The existing module/file you're touching — MIRROR its shape exactly.
- 1-2 sibling modules in the same layer — confirm the pattern is project-wide.

## Phase 3.5 — Handoff (only when `--plan` is set; otherwise skip)

> **This phase runs ONLY when the `--plan` flag is passed. Most commands skip it entirely and proceed directly from Phase 3 to Phase 4.** The ~90 lines below are conditional scaffolding, not canonical ceremony.

`--plan` is a **universal flag** every command supports. When set, this phase runs after Phase 3 and the command exits BEFORE Phase 4 (Generate). The output is a structured plan file other tools (or other agents) can implement.

When `--plan` is NOT set: skip this phase entirely; proceed to Phase 4.

### What Phase 3.5 does

1. **Expand the mini-plan from Phase 2** into a full plan with all the detail an external tool would need.
2. **Compute a Plan ID** — short hash of `(command + slug + timestamp + project-name)`, prefixed with the project's slug (e.g., `phc-7f4a`). The Plan ID is stable for the file (used to cross-reference from commits / PRs / `/verify-plan --plan-id`).
3. **Write to** `.claude/plans/<command>-<short-slug>-<YYYYMMDD-HHmm>.md`. Slug is derived from the command's first argument (kebab-case, ≤30 chars).
4. **Print** the plan file path + Plan ID + a brief summary, and the next step: `/execute-plan <file>` to implement it (Claude-native, executors on Sonnet), or hand the file to any tool; `/verify-plan <file>` audits drift after.
5. **Exit cleanly** — don't run Phase 4-7. Don't update `ai/status.md` (no implementation happened yet). Don't append to `ai/dynamic/changelog.md`.

### Plan file format (the canonical handoff artifact)

```markdown
# Plan: /<command> — <one-line summary derived from the user's prompt>

> Generated by `/<command> --plan` on <YYYY-MM-DD HH:MM>.
> Project: <project-name>. Stack: <detected stack one-liner>.
> Plan ID: <project-slug>-<4-char-hash>  (cite when reporting back via /verify-plan)
> Mode: handoff to <tool — defaults to "any tool"; user can specify with `--target=opencode|cursor|aider|...`>

## Context (everything the implementing tool needs)
- Module: <target-module> (from ai/modules.md)
- Architecture layer: <layer> (from ai/architecture.md)
- Conventions: see ai/_convention-cheatsheet.md
- Cross-cutting rules: <list of relevant .claude/rules/*.md>
- Failure-catalog warnings: <relevant ai/failures/<NNNN> entries, if any>

## Inputs (files to read BEFORE implementing)
- <path/to/file:LINE-LINE> — <why; what to look for>
- <path/to/sibling> — <sibling pattern to mirror>
- <path/to/test.spec> — <existing test conventions>

## Outputs (files to create or modify)
- [ ] CREATE <path> — <2-line description; what shape; what it contains>
- [ ] MODIFY <path>:LINE — <specific change; what's added/removed/replaced>
- [ ] DELETE <path> — <reason>
- [ ] No changes: <files that the user might assume need touching but don't> (explain why)

## Steps (ordered execution recipe)
1. <concrete step with file paths>
2. <concrete step>
3. <concrete step>
...

## Constraints (DO NOT do these)
- DON'T <constraint> — <reason; cite ADR / failure-catalog entry if applicable>
- DON'T <constraint> — <reason>

## Verification (how the implementing tool knows it's done)
- <detected lint cmd>
- <detected typecheck cmd>
- <detected test cmd> <path/to/affected/>
- <UI / API check via curl / Playwright if applicable>

## Known unknowns (decisions to make at implementation time)
- Q: <ambiguity that surfaced during Phase 1-3>
  - Option A: <description + tradeoff>
  - Option B: <description + tradeoff>
  - Recommendation: <A or B + reason>; capture in ADR if architectural.

## Status (the implementing tool updates these)
- [ ] Implementation started
- [ ] Files modified per output list
- [ ] Constraints respected (verified by /verify-plan)
- [ ] Verification commands passed
- [ ] /verify-plan reports PLAN FULFILLED
```

> **Gate scope:** the `/verify-plan` checkbox above applies ONLY to commands that ran with `--plan` (i.e., that produced a plan-file). For commands that don't produce a plan-file, Phase 6 (Validate) is just run-tests-and-checks; no `/verify-plan` invocation is required or implied.

### Plan-file quality bar

- **Concrete, not aspirational**: every `<placeholder>` filled with real content from Phase 1-3. A plan that ships with `<TODO>` markers is malformed.
- **Self-contained**: a different agent (or human) reads the plan + the cited input files only — no other context. If the plan references something not in `Inputs`, that's a bug.
- **Identifier-traceable**: every concrete identifier (class name, file path, helper function) cited in the plan must exist in the current codebase. The pre-flight reads from Phase 3 verified them; the plan repeats only what was confirmed.
- **Constraint-grippy**: the Constraints section must be checkable. "DON'T break UX" is too soft; "DON'T add a new dependency to requirements.txt" is checkable by `git diff requirements.txt`. Aim for the latter.

### Cross-tool semantics

- **Claude Code** (native): `--plan` is recognized at the orchestration layer; this phase runs as written. Execute a saved plan with **`/execute-plan <file>`** (repo-baseline command) — it runs the implementation phases with parallel `model: sonnet` executor sub-agents and auto-invokes `/verify-plan`. Author the plan under Opus (or `opusplan`) and the handoff is "Opus plans, Sonnet executes."
- **OpenCode**: `opencode.json` exposes a `plan` mode for each command; output is the same plan-file format. Implementation entry: `/<command> --from-plan <file>` reads the plan and runs Phases 4-6 against it — the sequential, per-command spelling of what `/execute-plan` does natively (no parallel fan-out outside Claude Code).
- **Cursor / Aider / Continue / Cline / Windsurf / Copilot / Codex / Gemini**: each adapter's `command-<name>` translation includes a "When user appends `--plan` to the prompt, write a plan in the canonical format to `.claude/plans/...`, do not implement" instruction. Phase 4.8 per-adapter spec wires this.
- **Universal fallback**: ANY tool that can read markdown can consume the plan file as a prompt. Paste the file content into Claude Code chat / Cursor chat / OpenCode prompt, instruct "implement per this plan," done.

### When --plan is the wrong choice

- Trivial changes (one-line fixes, typos) — overhead exceeds benefit.
- Spike / exploration where the plan would change as you go.
- Read-only commands (no implementation to plan for) — they exit at Phase 3 anyway.

The flag is FOR non-trivial, decomposable, verifiable work. Use judgment.

### Retrofitting --plan to existing projects

`--plan` is wired into the canonical 7-phase command structure that Phase 4.7 stamps into every generated command. **Commands that were already installed in a project before the `--plan` machinery was added will NOT have it** — their on-disk `.md` files are frozen until regenerated. The flag exists in setup-project.md's canonical structure but has not been propagated into pre-existing command files.

**Symptoms** (how the user notices the gap):
- `/<command> --plan` runs but the command implements anyway, ignoring the flag, because the command file's body has no Phase 3.5 logic.
- The user reports "I added `--plan` and it just ran the command normally."

**Two retrofit paths**:

1. **`/setup-project --refresh`** *(preferred for >2 commands or any team-wide rollout)* — re-runs Phase 4.7 with the current canonical structure; existing commands are regenerated with Phase 3.5 + `--plan` support. Phase 0.1 backup + Phase 0.2 knowledge extract preserve any project-specific edits the user made to those commands (custom prose, cross-references, project-specific instructions are pulled into the extract and re-injected by Phase 4 regen). REFRESH is non-destructive to accumulated knowledge — that's its whole purpose.

2. **Per-command manual edit** *(only sensible for 1-2 commands or surgical fixes)* — hand-edit a single command file: copy the `## Phase 3.5 — Handoff` section from setup-project.md's canonical structure into the command's body (between the existing Phase 3 and Phase 4 sections), then add `--plan` to the command's documented flags. Works, but doesn't scale; refresh is the right answer for anything larger.

**`/verify-plan` retrofit**: `/verify-plan` ships in `repo-baseline/.claude/commands/verify-plan.md`. Projects that pre-date its addition won't have it on disk; `--refresh` installs it as part of Phase 4.1 baseline scaffold. Standalone install (no refresh): `cp ~/.claude/templates/repo-baseline/.claude/commands/verify-plan.md <project-root>/.claude/commands/` — single-file copy, idempotent.

**`.claude/plans/` directory retrofit**: same — `--refresh` creates the directory + README; standalone install is `mkdir -p <project>/.claude/plans && cp ~/.claude/templates/repo-baseline/.claude/plans/README.md <project>/.claude/plans/` plus an entry to the project's `.gitignore`.

**Telemetry hint**: when Phase 6's `/check-health` runs on an existing project and detects commands without Phase 3.5 / no `verify-plan` / no `.claude/plans/` directory, it should output a "Setup capabilities drift" line in the report suggesting `--refresh`. (Phase 6 update — track separately.)

## Phase 4 — Generate (produce the output)
- Concrete steps, real commands, real code.
- Mirror existing patterns; never reinvent shapes.
- Use detected conventions (suffix matrix, naming, base classes from `ai/conventions.md`).
- Dispatch agents in parallel where independent (e.g., architect + reviewer for different layers).
- Pause for confirmation on architectural decisions; proceed without pause for mechanical work.

## Phase 5 — Update (persist changes to the knowledge base)
- `ai/status.md` — prepend a Recent Changes entry if the work is significant.
- `ai/dynamic/changelog.md` — append a one-line summary.
- `ai/modules.md` — add row if a new module was created.
- `ai/decisions/` — add ADR if an architectural decision was made (or queue to `ai/dynamic/decisions-pending.md` if informal).
- `ai/patterns/` — add pattern if a new reusable shape emerged (or queue to `ai/dynamic/learned-patterns.md`).
- For UI changes: regenerate i18n keys in `locales/`.

## Phase 6 — Validate (verify correctness)
- Run lint (`<detected-lint-cmd>`).
- Run typecheck (`<detected-typecheck-cmd>`).
- Run tests for affected modules (`<detected-test-cmd>`).
- For UI: visual diff via `visual-check` skill.
- For API: hit endpoint via `endpoint-test` skill, verify response shape.
- For DB: `EXPLAIN ANALYZE` affected queries, confirm indexes used.
- Self-audit: do the generated files cross-reference correctly? Any contradictions with `ai/conventions.md`?

If any check fails: HALT, report the failure, do not paper over.

## Phase 7 — Improve (feed the learning loop)
- `/learn-from-task` — capture decisions made + patterns followed/introduced + corrections + follow-ups.
- If the task surfaced drift between code + convention: append to `ai/dynamic/drift-log.md`.
- If a user correction was given: append to `ai/dynamic/feedback-learned.md`.
- If a decision deserves an ADR: queue to `ai/dynamic/decisions-pending.md`.
- If a new shape emerged 3+ times across the codebase: queue to `ai/dynamic/learned-patterns.md`.

## Output format

```
## /<command> — <result one-liner>

Phase 1 (Understand): <what was clarified>
Phase 2 (Organize): <plan summary>
Phase 3 (Retrieved): <files consulted, agents dispatched>
Phase 4 (Generated): <files created/modified>
Phase 5 (Updated): <knowledge files touched>
Phase 6 (Validated): <checks run + results>
Phase 7 (Improved): <learning queued>

Status: COMPLETE | BLOCKED on <X> | NEEDS REVIEW

Open follow-ups:
  - <follow-up>
```

## Failure modes
- <4-6 ways this command fails + how to recover>
```

### How to document skipped phases

The phase-selection table above tells you which phases apply to your command type. For each phase that does NOT apply, document the skip explicitly:

```markdown
## Phase 5-7 — N/A

This is a read-only diagnostic command; no state changes, no persistence, no learning hook needed.
```

Don't silently omit. Selection is the default; the documented skip makes the deviation visible.

---

