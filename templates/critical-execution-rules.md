---
artifact: critical-execution-rules
purpose: Seven rules that override anything else in the command. Read THIS before any other phase.
imported-by: commands/setup-project.md (orchestrator) — top-level, before phase imports.
---

## 🛑 CRITICAL EXECUTION RULES (read THIS before any other section)

These rules override every other section. If you skip them, you ship the false-idempotent bug (silent partial-applies, "no work to do" verdicts that mask 50+ missing files). They exist because the LLM under context pressure historically skipped Phase 4.2 / 4.8 / Phase 5 — these rules force the work to be visible + verified.

**There are seven numbered rules total**: Rules 1-6 are inlined immediately below; Rule 7 (Phase 4.6 per-file adaptation) lives in its own file `templates/rule-7-phase-4-6-file-adaptation.md` because it loads only during Phase 4.6 (not every agent run). All seven are mandatory.

### Rule 1: NEVER conclude "idempotent — no work to do" on prompt-delta alone

The "no work" verdict requires **ALL FOUR** to be true:

1. ✅ **Prompt delta = 0** (Phase 3.1 finds nothing new from prompt vs state).
2. ✅ **Coverage gap = 0** in load-bearing + always-on tracks (Phase 2.6 — profile-informed — confirms existing setup meets minimums for tracks the codebase actually needs, AND per-adapter completeness contracts).
3. ✅ **Drift findings = 0** (no convention/code divergence requiring update).
4. ✅ **Pack-source directory parity = 0** (for every `--include=<pack>` flag, every file in `~/.claude/templates/packs/<pack>/{commands,agents,skills,rules,ai-patterns}/` AND `~/.claude/templates/domains/<signal>/...` directories is either present in target OR has a recorded merge-decision in the current run's report — NEVER trust prior `_apply-pack-report.md` decisions; always re-scan the directory).

If you check only #1 and report "idempotent" → **WRONG VERDICT**. The user's setup may still be missing 50+ files. You MUST run #2, #3, AND #4 before any "no work" conclusion.

**Pack-source parity rule (Rule 1.4) — explicit contract:**

When `--include=<pack>` is set OR the pack was previously selected:

```
For each file F in ~/.claude/templates/packs/<pack>/<kind>/:
    target_path = compute_target_path(F)   # per pack.md emits contract
    if target_path NOT exists in target repo:
        emit ADD decision (subject to merge matrix)
    elif target_path exists AND content differs:
        emit MERGE / REPLACE / KEEP-OURS decision (per Appendix C)
    else:
        emit NO-OP for this file
```

**The directory listing of the pack source IS the source of truth.** The pack's own `_essentials.md` and `_topics.md` manifests are a hint; if they lag behind the directory (which happens when a new command lands but the manifest wasn't updated), the directory wins.

**Prior decision reports MUST NOT short-circuit this check.** A SKIP-with-redirect decision recorded yesterday does NOT mean a NEW file in the pack today gets skipped. Each `--include=<pack>` invocation runs the directory scan fresh.

**Wrong** (the false-idempotent pattern):
```
DELTA: none. No new prompt. Idempotent — no work to do.
```

**Right**:
```
PROMPT DELTA: none.
COVERAGE GAP: 67 files missing across 8 tracks + 8 baseline gaps + 28 missing tool-adapter outputs.
DRIFT: 3 high-severity findings open.
WORK TO DO: fill coverage gaps via Phase 4.2 + 4.8 deterministic copy/translate; resolve drift.
Plan: <details>
Apply now? [y/n]
```

### Rule 2: ENHANCE / REFRESH MUST run the coverage gap check AFTER Phase 2 (profile-informed)

When mode = ENHANCE-retrofit / ENHANCE-extend / REFRESH, the coverage gap check is mandatory — but it MUST run AFTER Phase 2 (profile) + Phase 2.5 (idiom extraction). The check is **profile-informed**: it only flags gaps for tracks the codebase profile says are LOAD-BEARING for this project.

Why the order matters: a static "minimums table" run before profiling forces every project into the same shape (e.g., "you have 1/3 backend agents, 0/2 mobile commands"). Profile-first means the question is *"for the tracks this project actually needs, do we meet the floor?"* — a single-tenant SaaS doesn't need tenant-leak rules, a non-frontend service doesn't need UI agents, a CRUD-heavy backend doesn't need the distributed-systems pack.

The check compares actual artifact counts against:
- **Per-track minimums** (Phase 4.0 minimum-artifacts table) — but ONLY for tracks selected as load-bearing in Phase 2 (signal-detected) or always-on (security, code-quality, learning, documentation). Tracks NOT load-bearing get `n/a` in the report, not a gap.
- **Per-adapter completeness contracts** (Phase 4.8.0 — OpenCode `commands` block populated; Cursor `command-*.mdc` per command; Copilot `prompts/*` per command/agent/skill; etc.) — for adapters selected in Phase 3.2.
- **Required baseline** (7 hooks, settings.json, full seeded `templates/repo-baseline/ai/` tree — 40+ markdown files including root stubs + `core/` / `dynamic/` / `runtime/` / etc., CLAUDE.md, AGENTS.md, codebase-profile.md).

ANY shortfall (in load-bearing tracks or baseline) becomes "work to do" and proceeds to Phase 4 — regardless of whether the prompt added anything new.

**Order of operations** (mandatory): Phase 0 (REFRESH backup+extract) → Phase 1 (mode) → Phase 2 (deep profile) → Phase 2.5 (idiom extraction if extenders found) → Phase 2.6 (profile-informed coverage gap check) → Phase 3 (prompt delta + plan) → Phase 4 (apply) → Phase 5 (audit + leak scan).

### Rule 3: Phase 4.2 (pack copy) is DETERMINISTIC shell, not LLM-controlled

Use `cp -R ~/.claude/templates/packs/<track>/{agents,commands,skills,rules,ai-patterns}/* <target>/` per selected track. NEVER write pack files individually with the Write tool — that's the failure mode. The shell guarantees no skip.

### Rule 4: Phase 4.8 (tool adapters) MUST translate ALL artifacts to each tool's NATIVE shape — the standalone-tool guarantee

**The standalone-tool guarantee**: every selected adapter MUST produce a project that works end-to-end in its tool **without `.claude/` present**. Skills appear in the tool's native skill picker, slash commands appear in chat, hooks fire on lifecycle events, agents surface in the tool's persona picker (when supported). Nothing depends on the tool reading `.claude/`. This is enforced by Phase 4.8.0's per-adapter contract and verified by `scripts/test-adapter-fixtures.sh`.

Every adapter has a completeness contract (Phase 4.8.0 table). The contract uses each tool's **native folder structure** so the tool works standalone, without depending on `.claude/`. As of Apr 2026:

- **OpenCode**: `.opencode/agents/<name>.md`, `.opencode/commands/<name>.md`, `.opencode/skills/<name>/SKILL.md` (each NATIVE folder), plus `opencode.json` (provider + instructions globs) and AGENTS.md (`## Invokable commands` + `## Named personas` + `## Named procedures`).
- **Cursor (≥ 2.3)**: `.cursor/commands/<name>.md`, `.cursor/skills/<name>/SKILL.md`, `.cursor/hooks.json` (all NATIVE), plus `.cursor/rules/*.mdc` for rules.
- **Copilot**: `.github/agents/<name>.agent.md`, `.github/skills/<name>/SKILL.md`, `.github/prompts/<name>.prompt.md`, optional `.github/chatmodes/` (all NATIVE).
- **Cline / Windsurf**: `.clinerules/workflows/<name>.md` / `.windsurf/workflows/<name>.md` (NATIVE slash commands).
- **Continue**: `.continue/prompts/<name>.md` (NATIVE slash commands with `invokable: true`).

Anti-patterns (thin-stub adapter bug + native-shape miss):
1. Write `opencode.json` with only `instructions: [...]` array and stop. That's a thin stub.
2. Cram every command into `.cursor/rules/command-<name>.mdc` instead of using `.cursor/commands/<name>.md`. That's the legacy pre-2.3 shape — the tool won't surface them as slash commands.
3. Skip `.cursor/hooks.json` and only install Husky. Misses Cursor's native lifecycle hooks (≥ 2.3).
4. Keep Continue prompts inline in `config.yaml` only. Misses `.continue/prompts/*.md` slash commands.

The standalone test: open the generated repo in just one tool (e.g. Cursor, no Claude installed). Skills must appear in Cursor's Skills picker; slash commands in chat; hooks fire on edit. If any of those fail, the adapter shipped a translated rule instead of a native artifact.

### Rule 5: Phase 5 verification is HALT + RETRY, not just report

After apply, count actual files vs expected. If shortfall: **automatically re-run** the deterministic copy/translate for that track/adapter. Only halt with error if the retry also fails. The user should see "shortfall detected, retrying ..." not "shipped incomplete setup."

### Rule 6: REFRESH mode MUST run Phase 0 (backup + extract) BEFORE any write

When mode = REFRESH (flag `--refresh` set), you CANNOT skip Phase 0. Phase 0 has TWO non-negotiable sub-steps that BOTH must complete BEFORE Phase 1 (mode detection re-confirmation), Phase 2 (profile), or anything that writes to `.claude/` / `ai/`:

1. ✅ **Backup taken** — `cp -R` of existing `.claude/` + `ai/` into `<backup-dir>/<YYYYMMDD-HHmm>/`. Verify the backup directory exists + has the same file count as source. If backup fails or is empty, HALT — do NOT proceed to regen. Backup is the rollback safety net; without it, REFRESH is destructive without recovery. (Bypass requires explicit `--no-backup` flag AND user confirmation in plan — see Quick Start flag table.)
2. ✅ **Knowledge extracted** — every existing setup file (CLAUDE.md, AGENTS.md, ai/**/*.md, .claude/rules/*.md, .claude/agents/*.md, .claude/skills/**/*.md, .claude/commands/*.md, .claude/codebase-profile.md) is READ and the durable insights pulled into `.claude/_refresh-knowledge-extract.md` (a temp working file, deleted at end of Phase 5). Categories: domain decisions, project intent, business glossary, custom conventions, validated corrections, ADR-grade decisions, custom rules not in any pack, project-specific anti-patterns. Without this, REFRESH discards accumulated knowledge — the failure mode that motivated this mode in the first place.

The knowledge-extract file is consumed by Phase 2 (merge with codebase profile), Phase 4 (regeneration uses extracted insights as input context), and Phase 5 (audit confirms no extracted item was silently dropped).

**Wrong** (the regen-without-memory pattern):
```
REFRESH: regenerating fresh setup based on codebase analysis...
[overwrites ai/business-domain.md with generic template — user's manually-curated 6 months of domain knowledge gone]
```

**Right**:
```
REFRESH:
  Phase 0.1 BACKUP → .claude/backups/20260425-1430/ (47 files, 312KB) ✓
  Phase 0.2 EXTRACT → 23 durable insights captured:
    - 8 ADR-grade decisions from ai/decisions/
    - 6 domain glossary terms (custom: "tenant subscriber" vs "user")
    - 5 project-specific conventions (V2 hexagonal mapping, RPC pattern)
    - 4 validated corrections (e.g., "no TypeOrmModule.forFeature")
  Phase 1+ proceeding with extract loaded as input context.
```

**Rule 7 (Phase 4.6 — per-file adaptation)**: when applying pack files, each file gets per-project judgment per `templates/rule-7-phase-4-6-file-adaptation.md`. That file is loaded ONLY during Phase 4.6 apply, NOT every agent run. See the referenced file for the full procedure (anchors, decision blocks, retry policy).
