---
phase: 3
name: plan
applies-to-modes: [all]
inputs: [user-prompt, codebase-profile, mode]
outputs: [delta (additions/removals/conflicts), plan.md, --plan handoff artifact when --plan flag set]
exit-criteria: plan emitted; deltas resolved or surfaced as questions; user-approval gate reached
---

### Phase 3 — Parse prompt + compute delta + build plan

If prompt provided: extract name / purpose / users / stack / shape / multi-tenant y-n / constraints / anti-goals. Normalize tech names. Flag contradictions. Ask ONE consolidated question only if truly ambiguous.

#### 3.1 Prompt-vs-state delta (CRITICAL when BOTH prompt AND existing setup present)

When a user invokes `/setup-project "<prompt>"` on an existing codebase, the prompt is **NOT redundant**. Treat it as a source of DELTA against the current state. If you skip this step, the command concludes "already set up" even when the prompt explicitly declares new scope.

For each declared facet in the prompt, compare against what's detected in the codebase profile + existing setup:

| Facet | Comparison | Action |
|---|---|---|
| **Declared signals** | In prompt + in code | Confirm — no action |
| | In prompt + NOT in code | **NEW** — generate-on-signal + add domain tooling + update `ai/status.md` |
| | In code + NOT in prompt | Keep existing (prompt doesn't deprecate silently) |
| **Declared tech** | Prompt + manifest match | Confirm |
| | Prompt adds tech (e.g., "Stripe") + not in package.json | Add `payment` domain + flag "install Stripe when building payment module" |
| | Prompt contradicts manifest | **FLAG CONFLICT** — ask user (don't silently pick one) |
| **Declared architecture** | Match profile | Confirm |
| | Prompt says different (e.g., "move to hexagonal") | Propose migration path + ADR; don't rewrite existing |
| **Declared phase** | Same as `ai/status.md` | Confirm |
| | Different (prompt ahead or behind) | Prompt intent wins; update `ai/status.md` + log ADR |
| **Declared anti-goals** | "DO NOT build X" | Add to CLAUDE.md anti-patterns; if X already exists, flag for discussion (don't delete) |
| **Scope additions** | Prompt adds concern (multi-region / compliance / new integration / new Phase N feature) | Add applicable tooling + patterns + ADR |
| **Constraints** | Latency / cost / compliance requirements mentioned | Reflect in rules + anti-patterns |

Produce a delta section in the plan:

```
PROMPT-VS-STATE DELTA:
  ✓ Confirmed (prompt + state agree):
    - NestJS + Fastify + TypeORM + PostgreSQL + Redis + Claude + WhatsApp Cloud API
    - Multi-tenant (row-level), AI signal, webhook signal
    - Clean Architecture per module
    - Phase 1 MVP

  + NEW from prompt (not yet in state):
    - "Subscription plans per tenant" (Phase 2) → expand ai/runbooks/phase-2-plan.md
    - "Track usage (tokens/messages)" + "Cost calculation" → extend ai/patterns/ai-cost-tracking.md, add /token-audit if not present
    - "Voice message handling" (Phase 5) → note in modules.md backlog
    - "Redis queues" (Phase 4) → add background-jobs domain signal + patterns (saga, outbox)

  ~ ADJUSTED (existing state updated per prompt):
    - Phase 2 section in ai/runbooks/ expanded with 4 new tasks
    - ai/status.md In-flight work updated to include Phase 2 preview

  ⚠ FLAGS / AMBIGUITIES:
    - Prompt says "thousands of tenants" but current ADR 0001 doesn't declare sharding timeline. Ask user: at what tenant count do we shard?
    - Prompt says "Master system (admin)" in Phase 3 but master app is not scaffolded. Ask: separate app/module or admin endpoints in existing api?

  − NONE to remove (prompt doesn't deprecate current work).
```

**The "no work to do" decision** — see Critical Execution Rule 1 + Phase 2.6.d. Prompt-delta = 0 alone is insufficient; coverage gap = 0 (in load-bearing + always-on tracks) + drift = 0 are also required. If only #1 but coverage gaps exist in load-bearing tracks: proceed to Phase 4 with "Prompt has nothing new, BUT existing setup is below floor for tracks this codebase actually uses — filling gaps."

#### 3.2 Tool-adapter selection (which AI-coding drivers this repo supports)

Distinct from "which packs/tracks apply" — this decides which drivers the generated knowledge must produce configs for. Multiple adapters coexist without conflict (see `~/.claude/templates/tool-adapters/README.md`).

Selection logic:

| Input | Selection |
|---|---|
| `--tools=claude-code,cursor,aider` | Use that list verbatim. |
| `--tools=auto` (or omitted on ENHANCE mode) | Run auto-detection heuristics. |
| No signal + CREATE mode | Default: `claude-code` + universal `AGENTS.md`. |
| `--add-tool=<name>` | Add this adapter on top of existing selections (ENHANCE mode, missing-tool addition). |

Auto-detection heuristics (each signal adds a tool to the set). Each signal must be **specific to that tool** — generic universals (like `AGENTS.md` itself) are NOT signals because every adapter eventually writes them:

| Signal | Tool |
|---|---|
| `.claude/` exists | Claude Code |
| `opencode.json` exists | OpenCode |
| `.cursor/` or `.cursorrules` | Cursor |
| `.aider.conf.yml` / `.aiderignore` | Aider |
| `.continue/` | Continue.dev |
| `.clinerules/` or `.clinerules` file | Cline |
| `.windsurf/` or `.windsurfrules` | Windsurf |
| `.github/copilot-instructions.md` or `.github/instructions/` | Copilot |
| `AGENTS.override.md` at repo root, OR `AGENTS.md` containing the marker `<!-- managed-by: codex -->`, OR an explicit `codex` entry in `.openai/codex.toml` | Codex |
| `GEMINI.md` | Gemini CLI |

`AGENTS.md` alone is **not** a Codex signal — the codex adapter's job is to *write* `AGENTS.md` as the universal cross-tool anchor (8+ other tools fall back to it). Any project that has been touched by any modern AI tool will likely have `AGENTS.md`; selecting Codex on its mere presence would over-trigger the adapter on projects that never use Codex. Instead, look for the codex-specific marker comment, the codex-managed override file, or an explicit codex CLI config file.

If auto-detection finds zero tools, default to `claude-code`.

Report the selected set in the plan as:

```
TOOL ADAPTERS:
  selected: claude-code, cursor, aider
  auto-detected (newly added): cursor (.cursor/ present but no Cursor rules files)
  skipped: opencode, continue, cline, windsurf, copilot, codex, gemini
```

**Missing-tool mode (ENHANCE):** if a tool-config presence is detected (e.g. `.cursor/` exists) but the adapter's output files are absent/stale, flag it as missing and offer to run the adapter. Never silently skip — a partial Cursor setup is worse than none.

#### 3.3 Build the plan

```
MODE:    CREATE | ENHANCE-retrofit | ENHANCE-extend
SHAPE:   <repo_shape>(<member-count>) — <member-a> (<stack>), <member-b> (<stack>)
         multi-track: <is_multi_track>   |   decided by: <shape_signal>
STACK:   <from profile + prompt>

TRACKS (after filter):
  ✓ always: code-quality, documentation, security, business
  + conditional: backend (nestjs), database (mysql), ...
  − filtered out: frontend (no UI detected), mobile (no RN/Flutter), ...

REFERENCES (after filter):
  ✓ nestjs, mysql, docker, kubernetes
  − not applied: postgres, mongo, angular, react, ... (not in stack)

DOMAIN TOOLING:
  + <cmd>  — because <signal evidence>
  + <agent> — ...

MERGE DECISIONS (per overlapping file):
  REPLACE: <file> (our 229 lines > theirs 82 — orchestration)
  MERGE:   <file> (our 209 ≈ theirs 173 — complementary)
  KEEP:    <file> (theirs 391 > ours 237 — much richer)
  SKIP:    <file> (exact match — nothing to add)

TOOL ADAPTERS:
  selected: claude-code, cursor, aider
  outputs: .claude/, CLAUDE.md, AGENTS.md, .cursor/rules/, .aider.conf.yml, CONVENTIONS.md

KB ACTIONS:
  create  <files>
  prepend <Recent Changes entry to ai/status.md>
  leave   <user-authored files untouched>

FILES WRITTEN: <N> added, <M> merged
ESTIMATED TOKENS: <rough>
```

**`SHAPE:` is a printed value, not a menu.** Every token on those two lines is read verbatim out of `.claude/codebase-profile.md § 17` (`repo_shape`, `members`, `is_multi_track`, `shape_signal`), which Phase 1 decided and Phase 2 completed. Printing the three-way choice `single | monorepo | workspace` un-narrowed means the shape was never decided — go back to Phase 1's shape table rather than planning past it, because a wrong shape here silently averages every member's conventions into one.

For `repo_shape: workspace`, the plan is per member: print the block above **once per member** (each has its own STACK / TRACKS / REFERENCES / ADAPTERS), preceded by a workspace-root block listing only the orchestration artifacts. For `repo_shape: monorepo`, print ONE block — one repo, one `.claude/` — but TRACKS shows which member contributed each conditional track, e.g. `+ conditional: <track> (<member-a>), <track> (<member-b>)`.

Show plan to user. Wait for approval. `--dry-run` stops here.

