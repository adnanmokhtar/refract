---
phase: 0
name: backup-extract
applies-to-modes: [REFRESH, REFINE]
inputs: [target-repo, prior-setup-version-marker]
outputs: [backup-tarball, .claude/_refresh-extract.md]
exit-criteria: backup tarball written; prior knowledge serialized into .claude/_refresh-extract.md sections 2-12 for downstream phases
---

### Phase 0 — Backup + extract prior knowledge (REFRESH mode only)

**Triggers when**: `--refresh` flag is set OR Phase 1 detects REFRESH conditions (rare — REFRESH is almost always user-initiated).

#### 0.0 Mandatory deterministic checks (M15 — pre-flight)

**Three shell scripts MUST run before any other Phase 0 substep.** They write structured reports the agent MUST read. The agent CANNOT skip them by claiming "I already know what's there." Bash output is the authority; LLM judgment is not.

**Canonical wrapper (preferred):** run all of these as ONE command — `run-preflight.sh` also runs
`detect-tracks.sh` (M28) + `detect-mcp.sh` (M29), which the four individual calls below omit (audit
finding #3). The individual invocations are what the wrapper calls, kept here for reference:

```bash
~/.claude/scripts/run-preflight.sh "$TARGET_REPO" --mode=$MODE $SELECTED_PACKS
```

```bash
# 1. Pack-source coverage scan — what files in selected packs are missing/present in target
~/.claude/scripts/pack-coverage-scan.sh "$TARGET_REPO" $SELECTED_PACKS
# → writes $TARGET_REPO/.claude/_pack-coverage-report.md

# 2. Refresh-extract checklist — auto-inventories existing artifacts; defines required prose sections
~/.claude/scripts/refresh-extract-checklist.sh "$TARGET_REPO"
# → writes $TARGET_REPO/.claude/_refresh-extract.md

# 3. Study-existing — per-file decisions (ADD / MERGE / KEEP / REVIEW) per Appendix C merge matrix
~/.claude/scripts/study-existing.sh "$TARGET_REPO" $SELECTED_PACKS
# → writes $TARGET_REPO/.claude/_study-existing-report.md

# 4. Deep codebase scan (M16) — file inventory + suffix patterns + 8 semantic questions LLM must answer
~/.claude/scripts/deep-codebase-scan.sh "$TARGET_REPO"
# → writes $TARGET_REPO/.claude/_codebase-scan.md
```

**These four reports are the contract:**

- `_pack-coverage-report.md` — answers "what files in the pack are missing in the target?"
- `_refresh-extract.md` — answers "what existing knowledge must be preserved?" (the agent fills sections 2-9 gated + 10-12 recorded, in § 0.2)
- `_study-existing-report.md` — answers "for files in BOTH pack and target, which need ENHANCE / MERGE / KEEP / REVIEW?"
- `_codebase-scan.md` — answers "what does the actual codebase look like, what patterns/conventions/decisions are visible, and what STRUCTURAL improvements are warranted?" (the agent fills sections 8-15 including section 15: minimum 3 structural recommendations on non-trivial codebases)

**Hard rule:** if any of these three reports shows ANY actionable item, declaring "no work to do" is FORBIDDEN. Phase 5 audit checks the reports vs the actions taken in Phase 4 and refuses success on any silent skip.

The historic bug (M11 / M15): the agent read prose rules saying "scan the directory" and skipped the scan. Shell-side scripts can't be skipped — the file either exists with content or it doesn't, and Phase 5 verifies.

**Purpose**: existing setup files are accumulated knowledge assets. Treating them as files-to-overwrite throws away months of refinement. Phase 0 captures both the safety net (backup) and the durable knowledge (extract) BEFORE any regen-write touches them.

**Skipped entirely** in CREATE / ENHANCE-retrofit / ENHANCE-extend modes — those modes either have nothing to back up (CREATE) or never overwrite existing user content (ENHANCE; see Hard Rules § Never).

#### 0.1 Backup (the rollback safety net)

> **M35**: `run-preflight.sh` already creates a deterministic backup (`.claude/` artifacts + `ai/` + CLAUDE.md/AGENTS.md) at Step −1 in REFRESH / REFINE mode — `audit-setup.sh` C2a verifies it exists and refuses success otherwise. The block below remains the FULL backup (tarball, honors `--backup-dir` / `--no-backup`); run it for anything the preflight copy doesn't cover. Even if this step is interrupted, the preflight safety net already exists.

```bash
# Default backup target
BACKUP_DIR=".claude/backups/$(date +%Y%m%d-%H%M)"

# Honor --backup-dir override if user passed it
if [ -n "$ARG_BACKUP_DIR" ]; then BACKUP_DIR="$ARG_BACKUP_DIR/$(date +%Y%m%d-%H%M)"; fi

# Honor --no-backup ONLY if confirmed in plan
if [ "$ARG_NO_BACKUP" = "1" ]; then
  echo "WARNING: --no-backup set. REFRESH will be destructive without rollback path."
  # Plan must show a [Y/N] confirmation; stop unless user typed Y
  exit_unless_confirmed
else
  mkdir -p "$BACKUP_DIR"

  # Resolve project root NOW (cwd at start of Phase 0) and stamp it into the backup
  # so restore.sh never has to guess via path-arithmetic. This is what fixes the
  # `--backup-dir` override case (where the backup may live anywhere on disk).
  PROJECT_ROOT="$(pwd -P)"
  printf '%s\n' "$PROJECT_ROOT" > "$BACKUP_DIR/.project-root"

  # Copy whatever exists; missing dirs are silently skipped (CREATE-mode-leaning state).
  # CRITICAL: when the backup dir lives INSIDE .claude/ (the default
  # `.claude/backups/<ts>` layout), naively `cp -R .claude $BACKUP_DIR/.claude`
  # would recursively copy `.claude/backups/` into the new backup, causing
  # quadratic storage growth across runs. Use rsync with explicit excludes
  # (or fall back to tar with --exclude on systems without rsync) to skip it.
  if command -v rsync >/dev/null 2>&1; then
    [ -d ".claude" ] && rsync -a \
        --exclude='/backups/' \
        --exclude='/_telemetry.jsonl.tmp*' \
        ".claude/" "$BACKUP_DIR/.claude/"
  else
    # Portable fallback: tar with exclude patterns
    [ -d ".claude" ] && (cd .claude && tar --exclude='./backups' --exclude='./_telemetry.jsonl.tmp*' -cf - .) | (mkdir -p "$BACKUP_DIR/.claude" && cd "$BACKUP_DIR/.claude" && tar -xf -)
  fi
  [ -d "ai"      ] && cp -R "ai"      "$BACKUP_DIR/ai"
  [ -f "CLAUDE.md"  ] && cp "CLAUDE.md"  "$BACKUP_DIR/CLAUDE.md"
  [ -f "AGENTS.md"  ] && cp "AGENTS.md"  "$BACKUP_DIR/AGENTS.md"
  [ -f "opencode.json" ] && cp "opencode.json" "$BACKUP_DIR/opencode.json"
  [ -d ".cursor"    ] && cp -R ".cursor"    "$BACKUP_DIR/.cursor"
  [ -d ".clinerules" ] && cp -R ".clinerules" "$BACKUP_DIR/.clinerules"
  [ -f ".aider.conf.yml" ] && cp ".aider.conf.yml" "$BACKUP_DIR/.aider.conf.yml"

  # Verify
  if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "HALT: backup verification failed. $BACKUP_DIR is missing or empty. Refusing to proceed with REFRESH."
    exit 1
  fi
  echo "✓ Backup taken: $BACKUP_DIR ($(find "$BACKUP_DIR" -type f | wc -l) files)"
fi

# Write a restore-script at the backup root so the user has a one-liner rollback.
# It reads PROJECT_ROOT from the .project-root sibling stamped above — never from
# path arithmetic — so it works whether the backup lives at the default
# `<project>/.claude/backups/<ts>` OR somewhere a `--backup-dir` flag pointed it.
cat > "$BACKUP_DIR/restore.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$BACKUP_ROOT/.project-root" ]; then
  PROJECT_ROOT="$(cat "$BACKUP_ROOT/.project-root")"
else
  # Last-resort fallback for hand-edited backups: assume default layout
  # `<project>/.claude/backups/<ts>/` and walk up three levels.
  PROJECT_ROOT="$(cd "$BACKUP_ROOT/../../.." && pwd)"
  echo "WARN: .project-root stamp missing; guessing PROJECT_ROOT=$PROJECT_ROOT"
fi
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "HALT: resolved PROJECT_ROOT=$PROJECT_ROOT does not exist. Aborting restore."
  exit 1
fi
echo "Restoring from $BACKUP_ROOT into $PROJECT_ROOT"
[ -d "$BACKUP_ROOT/.claude" ] && rm -rf "$PROJECT_ROOT/.claude" && cp -R "$BACKUP_ROOT/.claude" "$PROJECT_ROOT/"
[ -d "$BACKUP_ROOT/ai"      ] && rm -rf "$PROJECT_ROOT/ai"      && cp -R "$BACKUP_ROOT/ai"      "$PROJECT_ROOT/"
[ -f "$BACKUP_ROOT/CLAUDE.md"  ] && cp "$BACKUP_ROOT/CLAUDE.md"  "$PROJECT_ROOT/"
[ -f "$BACKUP_ROOT/AGENTS.md"  ] && cp "$BACKUP_ROOT/AGENTS.md"  "$PROJECT_ROOT/"
[ -f "$BACKUP_ROOT/opencode.json"   ] && cp "$BACKUP_ROOT/opencode.json"   "$PROJECT_ROOT/"
[ -d "$BACKUP_ROOT/.cursor"         ] && rm -rf "$PROJECT_ROOT/.cursor"    && cp -R "$BACKUP_ROOT/.cursor"    "$PROJECT_ROOT/"
[ -d "$BACKUP_ROOT/.clinerules"     ] && rm -rf "$PROJECT_ROOT/.clinerules"&& cp -R "$BACKUP_ROOT/.clinerules" "$PROJECT_ROOT/"
[ -f "$BACKUP_ROOT/.aider.conf.yml" ] && cp "$BACKUP_ROOT/.aider.conf.yml" "$PROJECT_ROOT/"
echo "✓ Restored. Review with: git status"
EOF
chmod +x "$BACKUP_DIR/restore.sh"
```

Backup contents are **never** auto-cleaned. The user decides when (if ever) to delete `.claude/backups/`. The `.claude/backups/` + `.claude/plans/` gitignore entries are written by the **deterministic gitignore block in `phase-4.0-preflight.md`** (the same block that ignores the learning/scheduler outputs) — NOT by a prose step here. They previously lived only as prose ("Phase 4.1 enforces this") and were silently skipped, leaving backups tracked and bloating every `TBD`/`TODO` search (observed 2026-06). Phase 4.0 now appends them mechanically.

**Plans directory gitignore**: `.claude/plans/*.md` + `!.claude/plans/README.md` + `.claude/plans/_archive/` are in that same Phase 4.0 block. Plans are per-engineer working artifacts (not shared history) by default. Teams that want plans tracked can flip the gitignore to commit them as PR-attached design docs — that's a project decision, not a setup-project default.

#### 0.2 Extract prior knowledge (the memory)

Read every existing setup file and pull out durable insights. The output is **`.claude/_refresh-extract.md`** — the same file § 0.0's `refresh-extract-checklist.sh` already scaffolded. Phase 0.2 FILLS its sections; it does not create a second file.

> **One artifact, one name.** This step used to name its output `.claude/_refresh-knowledge-extract.md` with a 13-section schema of its own (inherited from the M1 monolith, `.archive/setup-project.M1.monolith.md:1614`). No script ever wrote that name and no gate ever read it: the only writer is `scripts/refresh-extract-checklist.sh:44`, which scaffolds `_refresh-extract.md`, and the only reader is `scripts/audit-setup.sh` — `:152` for presence and `:183` for the seven gated headings, matched **by heading name**. An agent that followed the old prose therefore wrote a file nothing consumes while the file the gate does read stayed at its scaffolded `<TBD>`s, and `audit-setup.sh` C2b1 fails the run on exactly that state. That is a mechanism, not a recorded incident — no field report of it exists, and `docs/REFERENCE.md § Mid-run interruption leaves <TBD>` documents a *different* cause (an interrupted run) with a different fix (re-run `--refresh`), so it is not evidence for this one. The section numbers below are the ones `refresh-extract-checklist.sh` actually emits and `audit-setup.sh` C2b1 actually reads.
>
> **Not a temp file.** Do NOT delete it at end of Phase 5. `audit-setup.sh:155` errors when it is absent, and `/setup-project-health` re-audits it long after the run.

**Files to read (in this order — most authoritative first):**

| Priority | Path glob | What to extract | → `_refresh-extract.md` § |
|---|---|---|---|
| 1 | `ai/decisions/*.md` (NOT `_decision-index.md`) | Every ADR — decision title, context, decision, consequences. ALL preserved verbatim into the extract; ADRs are append-only history. | §2 |
| 2 | `ai/business-domain.md` | Domain glossary (custom terms with project-specific meanings), core flows, compliance notes. | §4 |
| 3 | `ai/project-goals.md` / `ai/users-and-personas.md` | Mission, target users, business model, success KPIs, constraints, anti-goals — the project-intent block. | §4 |
| 4 | `ai/conventions.md` + `ai/_convention-cheatsheet.md` | Project-specific naming, suffix matrix, base classes, MUST/MUST-NOT bullets that are NOT generic. | §5 |
| 5 | `ai/patterns/*.md` | Patterns referenced by ADRs OR cited in CLAUDE.md OR with non-obvious WHY blocks. Generic copy-paste patterns are NOT extracted (will regen). | §7 |
| 6 | `.claude/rules/*.md` | Custom rules — anything that is NOT a verbatim pack rule. Diff against `~/.claude/templates/packs/*/rules/*.md`; keep only the delta. | §5 |
| 7 | `.claude/agents/*.md` | Custom agents — same diff logic against pack agents. Hand-tuned prompt prose is the durable asset; pack-equivalent agents are NOT extracted. | §6 |
| 8 | `.claude/skills/**/*.md` + `.claude/commands/*.md` | Custom skills/commands not in any pack; user corrections to pack versions. | §6 |
| 9 | `.claude/codebase-profile.md` | Detected base classes, paths, conventions — already-paid-for analysis. Re-validate in Phase 2; if codebase still matches, don't re-detect. | §8 |
| 10 | `CLAUDE.md` + `AGENTS.md` | Top-of-file project-specific blocks (above the line "Detected stack"). Generic prose below that line is regen-replaceable. | §4 |
| 11 | `ai/dynamic/learnings.md` + `ai/dynamic/corrections.md` (if Phase 6 has been running) | Validated corrections — these are the "user told us no, do it this way" memory. ALWAYS extracted. | §3 |
| 12 | `ai/runbooks/*.md` | Project-specific operational steps (incident response, deploy, debug). Anything beyond pack templates. | §7 |
| 13 | `ai/architecture.md` | Project-specific architecture overview (modules, deps, boundaries). Diff against any pack-template archetype; keep delta verbatim. | §7 |
| 14 | `ai/runtime/*.md` | Runtime topology, deployment surfaces, env-var contracts. Always extracted verbatim — these are facts the codebase doesn't fully encode. | §7 |
| 15 | `ai/audits/*.md` | Past audit reports + their findings. Append-only history; preserve verbatim alongside ADRs. | §2 |
| 16 | `ai/failures/*.md` (incl. `_index.md`) | Failure catalog (B10) — past architectural failures + their lessons. Append-only; preserve verbatim. | §2 |
| 17 | `.claude/hooks/*.sh` (only the user-edited ones) | Project-customised hooks. Diff against `~/.claude/templates/repo-baseline/.claude/hooks/*.sh`; keep delta. Pack-verbatim hooks regen from baseline. | §10 |
| 18 | `.claude/git-hooks/post-*` | Only if the user added project-specific logic above the `exec` line. Otherwise the baseline shim regenerates verbatim. | §10 |
| 19 | `**/* — catch-all sweep` | After the table is fully consumed, run a final sweep over every other file in `ai/` and `.claude/` not yet covered. Anything user-touched (mtime newer than the baseline copy or content not byte-identical to its pack source) gets recorded verbatim in `## 11. Uncategorized user-touched files — catch-all sweep`. This is the safety net against future spec drift — new file categories never silently lose data on REFRESH. | §11 |

**Extraction format** — fill the sections `refresh-extract-checklist.sh` already wrote into `.claude/_refresh-extract.md`. Replace each `<TBD>` in place; do not renumber, do not add a section the script did not emit, and do not start a second file.

| § | Heading (as emitted) | What goes in it | Gated by `audit-setup.sh` C2b1? |
|---|---|---|---|
| 1 | Existing artifact inventory | Script-owned. Never rewrite, reorder or prune the inventory rows the script emitted. **The one permitted addition** is the single-line extraction tally appended at the end of this section when § 0.2 closes (see below) — that is an append, not an edit, and no new heading is created for it. | n/a (auto) |
| 2 | ADRs preserved | Every ADR by ID + title + one-line summary, plus every `ai/audits/*.md` and `ai/failures/*.md` entry. All append-only — preserved verbatim, never regenerated. | **yes** |
| 3 | Validated user corrections | Verbatim from `ai/dynamic/corrections.md` + `learnings.md` — the "user told us no, do it this way" memory. | **yes** |
| 4 | Project intent | Mission, target users, business model, KPIs, constraints, anti-goals, domain glossary terms + core flows, plus the project-specific blocks of `CLAUDE.md` / `AGENTS.md`. | **yes** |
| 5 | Custom rules | `.claude/rules/*.md` deltas against pack rules, plus the non-generic bullets of `ai/conventions.md` / `ai/_convention-cheatsheet.md`. | **yes** |
| 6 | Custom agents/skills/commands | Non-pack agents/skills/commands, and pack-derived ones the project specialized. Name + role + which generic it replaces. | **yes** |
| 7 | Architecture decisions implicit in code | Undocumented layering / data-access / error-handling patterns, plus project-idiom `ai/architecture.md`, `ai/patterns/*.md`, `ai/runbooks/*.md`, `ai/runtime/*.md` content. | **yes** |
| 8 | Detected stack + version | Languages, frameworks, ORMs, test runners, build tools with versions — including the already-paid-for detection in `.claude/codebase-profile.md`, to be re-validated in Phase 2. | **yes** |
| 9 | Migration / V1↔V2 mapping | Only when `--include=migration` or a V1+V2 layout was detected. | yes, **conditionally** |
| 10 | Custom hooks — delta from baseline | `.claude/hooks/*.sh` + `.claude/git-hooks/post-*` diffs against the repo-baseline shims. Phase 4.1 re-applies them. | no — recorded |
| 11 | Uncategorized user-touched files — catch-all sweep | Priority-19 sweep output, verbatim. The safety net against spec drift. Phase 4 restores every entry or lists it in § 12. | no — recorded |
| 12 | Drop list — intentionally NOT preserved | Pack-equivalent files being regenerated rather than extracted, plus any § 11 entry deliberately not restored. Path + one-line rationale. | no — recorded |

**Why 10-12 are not shell-gated**: `audit-setup.sh` reads sections 2-8 (and 9 conditionally) by heading name. Sections 10-12 exist so Phase 4.1's hook re-apply, Phase 4's catch-all restore, and Phase 5's "Intentional drops" report each address a numbered section of a file that deterministically exists, instead of one only prose ever created. They are enforced by Phase 5 § "knowledge preservation check", which is prose — treat them as MUST, and know that only your own discipline is checking.

Close § 0.2 by appending a one-line tally at the end of § 1 — the one write this phase makes to that script-owned section, and the reason the table above calls it an append rather than an edit. Do not create a new heading:

```
Extraction tally: <N> durable items from <M> files read; <P> marked regen-without-preservation (see § 12).
```

**Critical rule for extraction**: when in doubt, EXTRACT. The cost of extracting a generic item is one extra entry in the extract file (Phase 4 deduplicates against pack output). The cost of dropping a project-specific item is permanent knowledge loss. Bias toward inclusion.

**Subagent delegation**: if existing setup is large (`.claude/` + `ai/` total > 200 files), delegate the read-and-extract loop to the Explore agent in parallel batches (e.g., 4 concurrent batches: ADRs+domain, conventions+patterns, rules+agents, skills+commands+runbooks). Each batch returns its extract section; main thread concatenates into the final extract file.

#### 0.3 Plan presentation (REFRESH-specific)

Before Phase 1 announces mode, the plan output MUST include:

```
REFRESH MODE — preview before apply:
  Phase 0.1 BACKUP target: .claude/backups/<YYYYMMDD-HHmm>/
    Files to back up: <count> (<size>)
    Restore script: .claude/backups/<YYYYMMDD-HHmm>/restore.sh

  Phase 0.2 KNOWLEDGE EXTRACT: <N durable items from M files>
    [list top-level categories with counts: ADRs, domain terms, conventions, custom rules, corrections]
    Drop list: <P pack-equivalent files marked for regen-without-preservation>

  Phase 4 will REGENERATE all of:
    - .claude/rules/, .claude/agents/, .claude/skills/, .claude/commands/
    - ai/conventions.md, ai/patterns/, ai/_session-digest.md, ai/_convention-cheatsheet.md
  Phase 4 will PRESERVE (write extracted content into new structure):
    - All ADRs (ai/decisions/*.md — append-only)
    - Domain glossary, project intent, validated corrections
    - Custom rules/agents/skills/commands not present in any pack

Proceed with backup + regen? [y/n]
```

Wait for `y` unless `--force-replace-all` is set. `--dry-run` shows this plan and exits without writing.

