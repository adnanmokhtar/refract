---
description: The brain. Scaffold new projects OR analyze + enhance existing ones. Detects mode, refines the prompt, mixes track-based packs, generates domain-specific tooling. One command. Any stack. Any shape. New or existing.
version: 2.0.0
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
# Exits 0 = safe to report success. Exits 1 = REFUSED — must address findings.
```

**Hard contract (M17):** the orchestrator MUST run `run-preflight.sh` at Phase 0.0 (before any other Phase 0 work) AND `audit-setup.sh` as the final step of Phase 5. If `audit-setup.sh` exits non-zero, the run is REFUSED — the agent MUST NOT report `success` / `idempotent` / `no work to do`. Phase 4 reads the 4 reports as its work plan; every actionable row must be addressed or explicitly skipped with a documented rationale.

**Hard contract (M23) — apply study decisions deterministically:**

```bash
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --apply --include=replace,add
```

Phase 4 MUST run this. It reads `_study-existing-report.md` and applies REPLACE-OR-ENHANCE + ADD rows by file copy (with backup). LLM judgment cannot skip these — the script is deterministic shell.

**Flag composition (M23):** flags COMPOSE; they do NOT narrow scope.

- `/setup-project --refresh` → applies study-decisions across ALL existing files (every pack the project has).
- `/setup-project --include=migration` → adds migration pack content on top.
- `/setup-project --refresh --include=migration` → does **BOTH**:
  - Applies study-decisions across ALL existing files (a thin `add-feature.md` from the backend pack gets REPLACED from pack source).
  - PLUS adds the migration pack files.

The agent MUST NOT interpret `--include=<pack>` as "only touch that pack." `--include` ADDS scope; never SUBTRACTS. Refresh always covers the whole pack-source vs target diff. Multiple flags compose additively.

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
  Total: <500 lines (vs ~3500 for naive 7-file pre-flight)

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

## 📑 How this command is organized (post-M2 split)

This command is now a thin orchestrator. The detail lives in imported files:

| Concern                                | File                                                |
|----------------------------------------|-----------------------------------------------------|
| Critical execution rules (read first)  | `@templates/critical-execution-rules.md`            |
| Quick start, flags, end states         | `@templates/quick-start.md`                         |
| What this command knows about          | `@templates/knowledge-hub.md`                       |
| 4-input decision engine + tie-breaks   | `@templates/decision-engine.md`                     |
| Re-run safety (markers, merge rules)   | `@templates/idempotency.md`                         |
| Track plugin schema + loader           | `@templates/tracks/_loader.md`                      |
| Phase 0 — backup + extract             | `@templates/phases/phase-0-backup-extract.md`       |
| Phase 1 — detect mode                  | `@templates/phases/phase-1-detect-mode.md`          |
| Phase 2 — profile + deep extraction    | `@templates/phases/phase-2-profile.md`              |
| Phase 3 — parse + delta + plan         | `@templates/phases/phase-3-plan.md`                 |
| Phase 4 — apply (write artifacts)      | `@templates/phases/phase-4-apply.md`                |
| Phase 5 — verify + report              | `@templates/phases/phase-5-verify.md`               |
| Phase 6 — continuous learning loop     | `@templates/phases/phase-6-learn.md`                |
| Hard rules (Always / Never overlay)    | `@templates/governance/hard-rules.md`               |
| Canonical command template (META)      | `@templates/canonical-command-template.md`          |
| Cross-cutting capabilities (1-7)       | `@templates/capabilities.md`                        |
| Appendices A-F (detection, filter, …)  | `@templates/appendices.md`                          |
| Tool-adapter command (sibling)         | `commands/setup-project-adapters.md`                |

## 🛑 Critical execution rules

Before executing any phase, read `@templates/critical-execution-rules.md`. The seven rules there override anything else in this command. They exist because each represents a previously-shipped bug class.

## 🚀 Quick start

Flags, end states, and a one-page cheat sheet live in `@templates/quick-start.md`. New users start there.

## 🧠 Decision engine

Four inputs (domain / stack / intent / history) → six rules → tie-breaking → uncertainty handling → self-audit. Full text in `@templates/decision-engine.md`.

## 🔁 Idempotency contract (re-run safety)

A second run on the same repo MUST be safe. Per-file class behavior, marker conventions, ADR append-only rule, version interaction — all in `@templates/idempotency.md`.

## 🧩 Track plugin system

Tracks are pluggable. Drop a directory under `templates/tracks/<name>/` with `detect.md` + `pack.md` + `conventions.md` + `meta.yaml`. Loader behavior in `@templates/tracks/_loader.md`. Existing `templates/packs/*` remain the body content.

## 🔄 Execution flow (phases)

```
Phase 0 — Backup + extract        (REFRESH / REFINE only)   @templates/phases/phase-0-backup-extract.md
Phase 1 — Detect mode             (always)                  @templates/phases/phase-1-detect-mode.md
Phase 2 — Profile codebase        (ENHANCE / REFRESH / REFINE) @templates/phases/phase-2-profile.md
Phase 3 — Plan + delta            (always)                  @templates/phases/phase-3-plan.md
Phase 4 — Apply                   (always)                  @templates/phases/phase-4-apply.md
Phase 5 — Verify + report         (always; HALT + RETRY)    @templates/phases/phase-5-verify.md
Phase 6 — Continuous learning     (forever, after setup)    @templates/phases/phase-6-learn.md
```

Each phase file is self-contained with frontmatter declaring its inputs / outputs / exit criteria. Read each phase before executing it; do not paraphrase across phases.

## 📕 Hard rules (Always / Never)

The Always / Never governance overlay is `@templates/governance/hard-rules.md`. A `must` / `must-not` violation surfaced in Phase 5 audit means the command refuses to report success. M3 will reformat as a Rule | Why | Applies-To-Phases | Severity table.

## 🛠 Capabilities (cross-cutting features)

Seven capabilities thread through multiple phases:

1. Setup versioning + migration (every artifact carries `setup-project: vN`)
2. Setup health score + telemetry (`/setup-project --health`)
3. Schema validation harness (frontmatter + dry-invoke smoke)
4. Failure catalog (don't re-attempt previously-failed approaches)
5. Test fixtures + factories generation (per business-domain)
6. Multi-language UX (interactive prompts + bilingual headers)
7. Conversational wizard mode

Detail: `@templates/capabilities.md`. M3 will split each capability into `templates/capabilities/<name>.md`.

## 🧱 Canonical command template (META — for generated commands)

When Phase 4 generates an operational command into a target repo's `.claude/commands/`, that command follows the canonical 8-phase template in `@templates/canonical-command-template.md`. This is META: it describes the shape of GENERATED commands, not the shape of `/setup-project` itself.

## 📚 Appendices

- A — Detection commands (scripted signals used by Phase 2)
- B — Relevance filter (when to pull a track / pattern / domain)
- C — Merge decision matrix (file overlap rules)
- D — Codebase profile shape (the schema of `ai/codebase-profile.md`)
- E — Learnings encoded (where each rule comes from — traceability)
- F — Glossary (single canonical definition per term)

All in `@templates/appendices.md`.

---

## How to invoke

```
/setup-project                    # auto-detect mode
/setup-project --plan             # produce a plan-only artifact, do not write
/setup-project --upgrade          # migrate from older version
/setup-project --health           # report current setup health
/setup-project --validate-schemas # run schema validation harness only
/setup-project --diff             # preview changes against current state
```

For tool adapters (Cursor, OpenCode, Aider, …): `/setup-project-adapters`.

For continuous learning loop ops: `/learn-from-task` or scheduled curator runs (Phase 6).

---

## Where to start reading

If you are an agent picking this command up cold, read in this order:

1. `@templates/critical-execution-rules.md` — the seven hard guardrails.
2. `@templates/decision-engine.md` — how to reason.
3. `@templates/idempotency.md` — what re-runs preserve / replace.
4. The phase your context indicates you should be running.

Do NOT read the full set of files at once — that defeats the tiered loading goal. Pull each file when its phase is the active one.
