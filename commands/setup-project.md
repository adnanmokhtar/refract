---
description: Install or refresh the Claude orchestration layer for a repo. Packs, rules, commands, agents, and project-aware tooling; mode is detected from the repo (CREATE, ENHANCE, --refresh, --refine, --upgrade) and mode drift halts. Trigger on 'set up Claude orchestration here', 'analyze this codebase and generate tooling', 'refresh my setup'. Do NOT trigger to create a CODEBASE from an idea (/scaffold-project chains this itself), to re-sync adapters only (/setup-project-adapters), to report health without writing (/setup-project-health), or to re-run --refine after a PLATEAU-DEEP verdict.
compatibility: Requires bash and the framework scripts synced to ~/.claude/scripts — run-preflight.sh, audit-setup.sh, apply-study-decisions.sh, apply-anchors.sh. Without them the deterministic preflight and the Phase-5 audit cannot run, and success must not be declared. Writes across .claude/ and ai/. Adapter chaining needs the adapter set resolved in .claude/codebase-profile.md. Not verified outside a POSIX shell.
version: 2.1.0
# Tier 1 = HOT (load every session). Tier 2 = WARM (load by phase/task type).
# Tier 3 = COLD (load on demand only). The orchestrator always loads tier 1;
# tier 2/3 are pulled by the active phase. See @templates/import-tiers.md.
imports:
  hot:
    - templates/critical-execution-rules.md
    - templates/decision-engine.md
    - templates/idempotency.md
    - templates/governance/hard-rules.md
  warm:
    - templates/quick-start.md
    - templates/persona.md
    - templates/knowledge-hub.md
    - templates/tracks/_loader.md
    - templates/phases/phase-0-backup-extract.md
    - templates/phases/phase-1-detect-mode.md
    - templates/phases/phase-2-profile.md
    - templates/phases/phase-3-plan.md
    - templates/phases/phase-4-apply.md
    - templates/phases/phase-4.0-preflight.md
    - templates/phases/phase-4.2-apply.md
    - templates/phases/phase-4.6-deep.md
    - templates/phases/phase-4.7-deep.md
    - templates/phases/phase-4.8-deep.md
    - templates/phases/phase-5-verify.md
    - templates/phases/phase-5.0-retry.md
    - templates/phases/phase-5.1-baseline.md
    - templates/phases/phase-5.5-quality.md
    - templates/phases/phase-5-checklist.md
    - templates/phases/phase-6-learn.md
    - templates/observability.md
    - templates/capabilities.md
  cold:
    - templates/phases/phase-4-templates.md
    - templates/canonical-command-template.md
    - templates/appendices.md
related-commands:
  - /setup-project-adapters — re-sync tool adapters (Cursor, OpenCode, Aider, …)
---

# /setup-project

## The Premise (read first, internalize, do not deviate)

**Existing codebase is the truth — extract first, plan second, write third.** The repo's idioms (its base classes, its naming, its layer boundaries, its test conventions) are the intentional reality. Generic packs are a *floor* the project must meet, not a ceiling to overwrite it with. **Project wins; generics align.**

**The agent's job is exactly this:**
1. Detect mode (CREATE / ENHANCE / REFRESH / REFINE) and run the ceremony for THAT mode — not heavier, not lighter.
2. Extract project-specific facts (codebase profile + scan + study) BEFORE writing.
3. Write packs that bend toward the project, not packs that flatten it.
4. Anchor every generated artifact with cited project-specific facts (file paths, class names, real conventions). No skeletons.

**Mode → ceremony (closure-verb table; what each mode actually executes):**

| Mode      | Triggered when                                              | Ceremony                                                          | Closure verb                       |
|-----------|-------------------------------------------------------------|-------------------------------------------------------------------|------------------------------------|
| CREATE    | Empty / near-empty repo, or `--create`                      | **FULL**: all phases 0→6, all packs, full anchoring               | "scaffolded + anchored + audited"  |
| ENHANCE   | Existing repo, no `.claude/` yet, or `--enhance`            | **LIGHTER**: Phase 0/2 read-only extract, Phase 4 anchored writes | "extracted + layered + audited"    |
| REFRESH   | `.claude/` present + `--refresh`                            | **BACKUP-THEN-STUDY-THEN-TARGETED**: deterministic Phase 0 backup (in preflight), full study report, every flagged row APPLIED or LEDGER-RECORDED, reconciliation audit | "backed-up + studied + reconciled + audited" |
| REFINE    | `.claude/` present + `--refine` (or post-REFRESH deepening) | **DEEP-ONLY-ON-FLAGGED**: 4.6/4.7/4.8-DEEP rewrite shallow blocks; untouched files = no-op | "deepened-where-shallow + audited" |

The agent does NOT run CREATE ceremony on REFINE flag, does NOT run REFINE deep-pass on a fresh CREATE, does NOT promote ENHANCE into a full re-scaffold. **Mode-mismatch = bug.**

## Halt conditions (refuse to declare success on any of these)

Two enforcement classes — be honest about which is which:
- **[mechanical]** = a shell check in `audit-setup.sh` / `audit-anchoring.sh` fails the run deterministically. The agent cannot talk its way past it.
- **[self-policed]** = the LLM must police itself; no shell catches it. These are the soft spots — treat them with extra discipline.

1. **Phase 5 audit failure** [mechanical]: if `audit-setup.sh` exits non-zero, the run is REFUSED. The agent MUST NOT report `success` / `idempotent` / `no work to do`. Address every actionable row OR document a skip rationale.
2. **Generic-over-project / skeleton violation** [mechanical]: `audit-anchoring.sh` (surfaced via `audit-setup.sh` C2d) fails when a pack-derived artifact's anchor block is missing, is a placeholder skeleton (carries `<src/path`, `<e.g.,`, `<EntityA>`, `<DetectedBase>`, …), has fewer than 3 substantive lines, or cites no real identifier/path. Project wins; align generics, don't ship them.
3. **Skipped deterministic step** [self-policed]: if `apply-study-decisions.sh` (M23) or `apply-anchors.sh` (M25) was not invoked in Phase 4 → halt. The audit infers this indirectly (C2k reconciliation, C2d anchoring), but invocation itself is LLM-policed — do not skip the scripts.
4. **Adapter chain skipped** [mechanical]: `audit-setup.sh` C2m FAILS the run when adapters are enabled, `--no-adapters` was not passed, and `claude_config.adapters: false` is not set, yet `/setup-project-adapters` did not produce native artifacts. (Was WARN-only before M34 promotion.)
5. **Mode drift** [self-policed]: if Phase 1 detected mode X but ceremony Y was executed → halt. No shell check verifies the executed ceremony matches the detected mode — the agent MUST self-audit this in Phase 5.
6. **Cross-project leak** [mechanical]: `audit-anchoring.sh` (C2d) fails when a generated anchor cites identifiers/paths that exist in NO file of the target codebase — the "ships another project's class names" failure.
7. **Knowledge loss** [mechanical]: `audit-setup.sh` C2n fails a REFRESH/REFINE when `ai/decisions/` or `ai/patterns/` shrank vs the pre-refresh backup, or any backed-up ADR is absent post-refresh.

These halts override every other instruction below. The audit scripts + this section are the load-bearing contract.

## 🛑 STEP ZERO — deterministic preflight (M17 — runs FIRST, no exceptions)

**Before reading any other section, before persona, before phase imports — invoke this:**

```bash
~/.claude/scripts/run-preflight.sh "$TARGET_REPO" --mode=$MODE $SELECTED_PACKS
```

This produces 4 reports under `$TARGET_REPO/.claude/`:

- `_pack-coverage-report.md` — every pack file vs target (Missing / Present)
- `_refresh-extract.md` — auto-inventory + 9 prose sections agent must fill
- `_study-existing-report.md` — per-file Appendix C decisions (ADD / MERGE / KEEP / REVIEW)
- `_codebase-scan.md` — codebase inventory + 8 semantic sections agent must fill (incl. **section 15: ≥3 structural recommendations**)

**Then before declaring success, invoke this:**

```bash
~/.claude/scripts/audit-setup.sh "$TARGET_REPO" --mode=$MODE
# When the run skipped adapters, forward the flag so C2m records the sanctioned skip:
#   ~/.claude/scripts/audit-setup.sh "$TARGET_REPO" --mode=$MODE --no-adapters
# Exits 0 = safe to report success. Exits 1 = REFUSED — must address findings.
```

**Hard contract (M17):** the orchestrator MUST run `run-preflight.sh` at Phase 0.0 (before any other Phase 0 work) AND `audit-setup.sh` as the final step of Phase 5. If `audit-setup.sh` exits non-zero, the run is REFUSED — the agent MUST NOT report `success` / `idempotent` / `no work to do`. Phase 4 reads the 4 reports as its work plan; every actionable row must be addressed or explicitly skipped with a documented rationale.

**Hard contract (M23) — apply study decisions deterministically:**

```bash
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --apply --include=replace,add
```

Phase 4 MUST run this. It reads `_study-existing-report.md` and applies REPLACE-OR-ENHANCE + ADD rows by file copy (with backup). LLM judgment cannot skip these — the script is deterministic shell.

**Hard contract (M25) — apply Phase-4.6 round-one anchors deterministically:**

```bash
~/.claude/scripts/apply-anchors.sh "$TARGET_REPO" --apply
```

After `apply-study-decisions.sh` finishes copying pack content, Phase 4.6 MUST run this. It injects the canonical `<!-- project-specific:start --> ... :end -->` block (populated with facts cited from `codebase-profile.md` + `_codebase-scan.md`) into every pack-derived artifact in `.claude/{commands,agents,skills,rules}` + `ai/patterns`. Round-one floor only — `/setup-project --refine` deepens shallow blocks via `compute-anchor-density` scoring + `apply-pack-adaptation` skill. The deterministic floor is non-negotiable: without it, every artifact is a generic skeleton and the agent has no project-aware guidance for the user's stack.

**Flag composition (M23):** flags COMPOSE; they do NOT narrow scope.

- `/setup-project --refresh` → applies study-decisions across ALL existing files (every pack the project has).
- `/setup-project --include=migration` → adds migration pack content on top.
- `/setup-project --refresh --include=migration` → does **BOTH**:
  - Applies study-decisions across ALL existing files (a thin `add-feature.md` from the backend pack gets REPLACED from pack source).
  - PLUS adds the migration pack files.

The agent MUST NOT interpret `--include=<pack>` as "only touch that pack." `--include` ADDS scope; never SUBTRACTS. Refresh always covers the whole pack-source vs target diff. Multiple flags compose additively.

**Hard contract (M34) — auto-chain adapter translation:**

After Phase 5 audit passes (`audit-setup.sh` exits 0) in CREATE / REFRESH / REFINE / ENHANCE modes, the orchestrator MUST chain into `/setup-project-adapters` to translate `.claude/` artifacts to each enabled tool's native shape:

```
/setup-project-adapters
```

This is a **mechanical** gate: `audit-setup.sh` C2m FAILS the run (not warns) when adapters are enabled, no sanctioned skip applies, and the chain produced no native artifacts. Pass `--no-adapters` through to the audit so C2m records the skip.

Skip only when (sanctioned — C2m treats these as a pass):
- `--no-adapters` flag is passed (logged in the run output, forwarded to `audit-setup.sh --no-adapters`).
- Target's `.claude/settings.json` has `claude_config.adapters: false`.
- ZERO adapters are enabled (no native folder/config present — only `claude-code`; nothing to translate).

Why this is mandatory: `.claude/` is the source of truth, but Cursor reads `.cursor/`, OpenCode reads `.opencode/` + `opencode.json`, Copilot reads `.github/agents/` + `.github/prompts/`, Cline reads `.clinerules/`, etc. Without auto-chaining adapters, Claude gets every M25/M28/M29/M30/M31 improvement and the other tools fall behind ("Claude got smarter, Cursor still talks generic prose"). The hard contract closes this gap.

Pack-level changes propagate automatically through adapter translation — anchoring blocks, new skills, new agents, new MCP entries all reach Cursor / OpenCode / etc. via `/setup-project-adapters`. Global meta-commands (`/setup-project`, `/refine-prompt`, `/scaffold-project`) remain Claude-Code-only (other tools have their own command systems).

**Hard contract (M35) — deterministic backup + durable refresh decisions:**

Refresh's purpose: re-audit because Refract changed OR the project's code/business changed — keep what must be kept, change what must change, add the new, and NEVER lose the current setup. Two failure modes observed 2026-06-10 broke this: (a) a run that studied and stopped, (b) a run that curated by judgment, skipped the backup, and skipped the audit. M35 closes both:

1. **Backup is deterministic.** `run-preflight.sh` itself creates `.claude/backups/<ts>/` (`.claude/` artifacts + `ai/` + CLAUDE.md/AGENTS.md) in REFRESH / REFINE mode before any report is generated. The agent never decides whether to back up. `audit-setup.sh` C2a refuses success if no backup exists.

2. **Curation is sanctioned ONLY through the decisions ledger** `.claude/_refresh-decisions.md`. Every actionable study row must end in exactly one of two states — APPLIED (copy / merge / enhance) or RECORDED:
   ```bash
   apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'     # permanent: artifact class wrong for this project
   apply-study-decisions.sh <target> --keep-ours='pack/kind/file.md:rationale'  # our version beats the CURRENT pack version
   apply-study-decisions.sh <target> --resolve='pack/kind/file.md:note'         # MERGE/INJECT performed by hand
   apply-study-decisions.sh <target> --keep='kind/file.md:rationale'            # project-only orphan keeper
   ```
   `KEEP-OURS` / `RESOLVED` entries are stamped `pack@sha8` and **re-open automatically when the pack source changes** — so a kept file is re-audited exactly when there's something new to audit, never sooner. `REJECTED` / `KEEP` are permanent until a human deletes the line. Ledger rows are never re-proposed (kills the "same 95 rows every refresh" loop).

3. **Reconciliation is audited.** `audit-setup.sh` C2k regenerates the study report against the post-apply state and REFUSES success while any actionable row is neither applied nor ledger-recorded. "I curated, so I skipped the audit" is forbidden — curate all you want, in the ledger, with rationale; the audit still runs.

4. **Rejecting a pack COMMAND must never silently delete a command surface.** A `--reject` is sanctioned by a *same-name collision* (the project already has its own `kind/file.md`). When you reject a pack **command** instead on *capability overlap* — "the repo already covers this with `design-iterate` / `visual-check` / some agent" under a **different name** — the deterministic study classified that file as ADD, and the user will later type `/<command>` and get "not found". So a capability-overlap rejection of a command is incomplete until BOTH hold: (a) the rationale names the replacement — `→ use /<equivalent>`; and (b) a **native same-named command** exists in `.claude/commands/` that routes to the curated equivalent (a real specialist wired to the project's actual skills/agents — never a copy of the pack version, which assumes pack-only deps like `/align-recheck`). The REJECTED ledger line then protects that native file from being overwritten on future refreshes. Observed 2026-06-20 (a consumer project): the whole `ui-ux` pack was reject-on-overlap; `/enhance-ui` vanished with no breadcrumb and a "review" reported all-OK. Agents/skills/rules don't have this failure (they're not typed by the user); only commands do.

This block exists because prose rules in lower-priority sections were skipped under context pressure. Step Zero is the load-bearing contract.

---

## Persona — Principal Engineer of this project

(Full text: `@templates/persona.md`. Five bullets carry the weight.)

1. **Decide, don't survey.** Pick the choice; one-sentence reason. Survey trade-offs only when asked.
2. **Push back when wrong.** "Better default is Y because Z." Then proceed either way.
3. **Cite prior art.** Standard patterns over invention.
4. **Think long-term.** Survives team rotation, 10× scale, audits, framework upgrades.
5. **Audit yourself.** Phase 5 self-consistency is non-negotiable. Self-contradicting output = failed run.

This persona carries through to every generated artifact — CLAUDE.md, agent prompts, rules read as written by a senior engineer who owns the project, not a generic doc-spinner.

## Mandate

**Vibe-coding mandate**: high code, low token. Every action is deliberate. No filler output. No placeholders. Reuse what exists; add what's missing; don't rewrite what works.

**Domain + stack + intent + history awareness** — four inputs always considered, never just one. (See @templates/decision-engine.md.)

**Continuously evolving** — setup is the START, not the end. Phase 6 (continuous learning loop) keeps the knowledge layer in sync with reality forever.

---

## 🎯 Drop-in replacement principle (Claude = primary; every other tool = full alternative)

When this command generates tool adapters, the goal is NOT "list of files Claude reads + a stub config for each tool". The goal is: if the user closes Claude Code and opens Cursor (or OpenCode, or Aider, or any selected tool), they get the SAME feature surface — same commands available, same agent personas usable, same knowledge accessible, same conventions enforced.

The full per-adapter contract + re-sync flow lives in **`/setup-project-adapters`** (sibling command). The core orchestrator is no longer responsible for adapter detail — it produces source artifacts; the adapters command translates them to native shapes.

### Critical Execution Rule 4 — translate to the native shape, never a thin stub at a legacy path

The **standalone-tool guarantee**: every selected adapter must work as a standalone tool — a user who opens Cursor / OpenCode / Aider (or runs it in CI) gets the full feature surface **without `.claude/` present**. Two anti-patterns break that guarantee and are forbidden:

- **Thin-stub anti-pattern** — emitting a placeholder that just points back at `.claude/` (e.g. "see `.claude/commands/<name>.md`") instead of a real native artifact carrying the actual instructions. A thin stub is not a drop-in replacement; the tool reads it and gets nothing usable on its own.
- **Legacy-path anti-pattern** — writing to a superseded location the tool no longer reads natively. The canonical example is `.cursor/rules/command-<name>.mdc` (pre-Apr-2026 Cursor): Cursor 2.3+ reads native commands from `.cursor/commands/`, so a `.cursor/rules/command-` file is a **legacy** shape that silently produces DUAL outputs. When a pre-existing setup has legacy files, document them as a **harmless fallback** and let Phase 4.8 re-translate to the native path on next refresh — never leave both as the live surface.

Each adapter's native target + legacy→native migration is enumerated in `templates/tool-adapters/_registry.md`; `/setup-project-adapters` performs the translation. The orchestrator's job is only to hold the guarantee: native shape, no thin stubs, no live legacy paths.

---

## 🏛 The 4 pillars (this is an AI Engineering System, not a tool collection)

```
1. UNDERSTAND  →  full project extraction from code OR prompt
                  (Phase 2 detection + business-domain detection + intent capture)

2. FOLLOW      →  every output respects detected conventions + best-of-stack practices
                  (Phase 4.6 convention adaptation; ai/conventions.md auto-populated)

3. RESPECT     →  prior decisions (ADRs) constrain future ones; never silently contradict
                  (ai/decisions/ append-only; _decision-index.md for fast lookup)

4. LEARN       →  knowledge survives sessions; corrections persist; patterns mature
                  (Phase 6 learning loop; promotion pyramid; compact session digest)
```

These pillars are EQUAL — missing any one degrades the system. Detail in @templates/knowledge-hub.md.

## ⚡ Token efficiency (tiered context loading)

Naive systems read 7+ files in every agent's pre-flight. This system uses **3 tiers**:

```
TIER 1 — HOT  (auto-loaded every session via @ imports)
  • CLAUDE.md (≤200 lines)
  • ai/_session-digest.md (≤300 lines — compact bootstrap)
  Total budget: ≤600 lines combined (per `templates/import-tiers.md`); typical: ~500

TIER 2 — WARM (loaded by command/task type)
  • ai/_convention-cheatsheet.md → code-write + quick reviews
  • ai/business-domain.md → feature work
  • ai/business-flows.md → feature work
  • ai/_decision-index.md → architectural decisions

TIER 3 — COLD (loaded on demand — only when directly relevant)
  • Full ai/conventions.md (when cheatsheet is not enough)
  • Full ai/patterns/<name>.md files
  • Individual ai/decisions/<NNNN>-*.md ADRs
  • Specific .claude/rules/ files
  • ai/runbooks/, ai/runtime/, ai/audits/ contents
```

**Compact derived files** (Tier 1 + Tier-2 cheatsheet + indexes) are auto-maintained by `knowledge-curator`:

- `_session-digest.md` — distilled "what's important right now": project one-liner, stack, current phase, top 5 conventions, last 3 decisions, top 3 active follow-ups, top 3 recent corrections.
- `_convention-cheatsheet.md` — top 20 conventions in 1 screen.
- `_decision-index.md` — every ADR as one line.

These are REGENERATED, not hand-edited. Source of truth is the full files; compact files are derived projections.

**The token win**: every session starts with <500 lines of context covering 80% of decisions. Tier 2 + 3 load on demand for the remaining 20%. ~7× token reduction on bootstrap vs naive "read everything every time."

---

## Modules — see imports

This command is a thin orchestrator. The full detail lives in the files declared via `imports:` in this file's frontmatter — execution flow modules (phases 0–6), governance overlays (critical-execution-rules, hard-rules, idempotency), the decision engine, the track plugin loader, capabilities, the canonical command template (META — for generated commands), and the appendices. Each module is self-contained with frontmatter declaring its inputs / outputs / exit criteria. Read each on demand; do not paraphrase across modules.

**Execution flow** — phase files, gated by mode:

```
Phase 0 — Backup + extract        (REFRESH / REFINE only)
Phase 1 — Detect mode             (always)
Phase 2 — Profile codebase        (ENHANCE / REFRESH / REFINE)
Phase 3 — Plan + delta            (always)
Phase 4 — Apply                   (always)
Phase 5 — Verify + report         (always; HALT + RETRY)
Phase 6 — Continuous learning     (forever, after setup)
```

Critical execution rules at `@templates/critical-execution-rules.md` override anything below; read first. Quick start at `@templates/quick-start.md`. Decision engine at `@templates/decision-engine.md`. Tool-adapter sibling: `commands/setup-project-adapters.md`.

## Deep REFINE — round two (`--refine`)

REFINE mode runs a **round-two deepening pass** on top of the round-one floor. It rewrites only the auto-generated `## Project-specific` anchor blocks whose density is shallow; user-authored sections and the `<!-- refine-enriched -->` / `<!-- generated -->` partitions are preserved verbatim. All phases below are REFINE-only and imported as `templates/phases/phase-*.md`; `--max-subagents=<N>` (default 8) caps the parallel Explore / re-anchor / adapter-sync subagents they fan out.

### Phase 2.7 — Deep extraction: domain entities

Invoke the `extract-domain-entities-deeply` skill per detected business-domain — entities, fields with types/constraints, relationships, enumerations, lifecycle events, invariants.

### Phase 2.8 — Deep extraction: architecture

Invoke `extract-architecture-deeply` — layer/import graph + representative request lifecycles with `file:line` citations and the deliberate bounded-context boundaries.

### Phase 2.9 — Deep extraction: end-to-end flows

Invoke `extract-flows-deeply` — ≥3 business-critical + ≥2 internal flows, step by step with side effects, error paths, and idempotency mechanism (or its absence).

### Phase 2.10 — Deep extraction: emerging conventions

Invoke `extract-conventions-emerging` — the conventions the code actually follows that round-one's shallow pass did not capture.

### Phase 2.11 — Deep extraction: performance hot paths

Invoke `extract-hotpaths` — high-volume endpoints/queries/jobs, eager-loading patterns, indexes, cache usage, and N+1 risk markers.

### Phase 2.12 — Deep extraction: failure history

Invoke `extract-failures-from-history` — revert/hotfix/incident/rollback commits grouped by recurring theme (`--include-incidents=<path>` adds postmortem docs on top of git log).

### Phase 4.6-DEEP — Re-anchor shallow blocks

Re-anchor every block flagged shallow by `compute-anchor-density`, rewriting the `## Project-specific` block via `apply-pack-adaptation` from the deep extraction above.

### Phase 4.7-DEEP — Enrich the knowledge layer

Deepen `ai/` knowledge from the round-two extraction; optionally write `ai/runbooks/<flow>.md` from the Phase 2.9 flow narrations (`--include-runbooks`).

### Phase 4.8-DEEP — Propagate the deepening to adapters

Incrementally re-translate the deepened `.claude/` + `ai/` to every selected non-claude-code adapter so Cursor / OpenCode / Aider / etc. see the same guidance, not just Claude. Ordering is **4.6-DEEP → 4.7-DEEP → 4.8-DEEP**; every per-adapter decision is logged to `.claude/_phase-4-8-decisions.md`.

### Phase 5.5 — Setup-quality score + plateau verdict

Emit `.claude/_setup-quality.md` (per-artifact 0–100 anchor-density score) and a **three-class plateau verdict** from the `setup-quality-scoring` rubric — a bare "plateau reached" is forbidden:

- **PLATEAU-DEEP** — `plateau_delta ≤ 2` AND `plateau_consumed ≥ 0.85` AND `avg_score ≥ 80`: setup is anchored; stop running `--refine` until significant new code lands (exit 0).
- **PLATEAU-WEAK** — plateaued but `plateau_consumed < 0.85` OR `avg_score < 80`: NOT yet deep, but extraction is exhausted — the message lists the WEAK phases and the user must grow upstream signal first (exit 2, "user action required upstream").
- **NOT-PLATEAU** — `plateau_delta > 2` or no prior baseline: another `--refine` would still climb.

Plateau thresholds are tunable via `--plateau-delta` / `--plateau-consumed` / `--plateau-score`.

---

## How to invoke

```
/setup-project                    # auto-detect mode
/setup-project --upgrade          # migrate from older version
/setup-project --health           # ALIAS ONLY -> runs /setup-project-health, writes nothing
/setup-project --validate-schemas # run schema validation harness only
/setup-project --diff             # preview changes against current state
/setup-project --no-adapters      # sanctioned M34 skip: do NOT chain /setup-project-adapters
/setup-project --refine           # round-two deepening (Phases 2.7–2.12 + 4.6/4.7/4.8-DEEP + 5.5)
/setup-project --refine --max-subagents=<N>   # REFINE-only cost cap on parallel deep-extraction subagents (default 8)
```

`--no-adapters` is the **only** sanctioned key for skipping the M34 adapter chain (besides `claude_config.adapters: false` in settings.json, or zero adapters enabled). Pass it through to the audit (`audit-setup.sh … --no-adapters`) so C2m records the skip instead of failing the run.

**`--health` is an alias, not a mode.** `/setup-project-health` is the canonical, read-only health command and the only one that can honestly carry "never writes — not even logs" plus contractual exit codes 0 / 1 / 2 — a mode of a write command cannot promise that. `--health` here forwards to it verbatim and this command writes nothing on that path; prefer typing `/setup-project-health` directly.

For tool adapters (Cursor, OpenCode, Aider, …): `/setup-project-adapters`.

For a read-only staleness / drift report with no writes: `/setup-project-health`.

For continuous learning loop ops: `/learn-from-task` or scheduled curator runs (Phase 6).

---

## Where to start reading

If you are an agent picking this command up cold, read in this order:

1. `@templates/critical-execution-rules.md` — the seven hard guardrails.
2. `@templates/decision-engine.md` — how to reason.
3. `@templates/idempotency.md` — what re-runs preserve / replace.
4. The phase your context indicates you should be running.

Do NOT read the full set of files at once — that defeats the tiered loading goal. Pull each file when its phase is the active one.
