---
phase: 0
name: backup-extract
applies-to-modes: [REFRESH, REFINE]
inputs: [target-repo, prior-setup-version-marker]
outputs: [backup-tarball, ai/_extracted/]
exit-criteria: backup tarball written; prior knowledge serialized to ai/_extracted/ for downstream phases
---

### Phase 0 — Backup + extract prior knowledge (REFRESH mode only)

**Triggers when**: `--refresh` flag is set OR Phase 1 detects REFRESH conditions (rare — REFRESH is almost always user-initiated).

#### 0.0 Mandatory deterministic checks (M15 — pre-flight)

**Three shell scripts MUST run before any other Phase 0 substep.** They write structured reports the agent MUST read. The agent CANNOT skip them by claiming "I already know what's there." Bash output is the authority; LLM judgment is not.

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
- `_refresh-extract.md` — answers "what existing knowledge must be preserved?" (the agent fills sections 2-9)
- `_study-existing-report.md` — answers "for files in BOTH pack and target, which need ENHANCE / MERGE / KEEP / REVIEW?"
- `_codebase-scan.md` — answers "what does the actual codebase look like, what patterns/conventions/decisions are visible, and what STRUCTURAL improvements are warranted?" (the agent fills sections 8-15 including section 15: minimum 3 structural recommendations on non-trivial codebases)

**Hard rule:** if any of these three reports shows ANY actionable item, declaring "no work to do" is FORBIDDEN. Phase 5 audit checks the reports vs the actions taken in Phase 4 and refuses success on any silent skip.

The historic bug (M11 / M15): the agent read prose rules saying "scan the directory" and skipped the scan. Shell-side scripts can't be skipped — the file either exists with content or it doesn't, and Phase 5 verifies.

**Purpose**: existing setup files are accumulated knowledge assets. Treating them as files-to-overwrite throws away months of refinement. Phase 0 captures both the safety net (backup) and the durable knowledge (extract) BEFORE any regen-write touches them.

**Skipped entirely** in CREATE / ENHANCE-retrofit / ENHANCE-extend modes — those modes either have nothing to back up (CREATE) or never overwrite existing user content (ENHANCE; see Hard Rules § Never).

#### 0.1 Backup (the rollback safety net)

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

Backup contents are **never** auto-cleaned. The user decides when (if ever) to delete `.claude/backups/`. Add `.claude/backups/` to `.gitignore` if not present (Phase 4.1 enforces this for new projects; Phase 0 enforces it for refreshes).

**Plans directory gitignore** (Phase 4.1 enforces alongside backups): add `.claude/plans/*.md` + `!.claude/plans/README.md` + `.claude/plans/_archive/` to `.gitignore`. Plans are per-engineer working artifacts (not shared history) by default. Teams that want plans tracked can flip the gitignore to commit them as PR-attached design docs — that's a project decision, not a setup-project default.

#### 0.2 Extract prior knowledge (the memory)

Read every existing setup file and pull out durable insights. The output is a temp working file `.claude/_refresh-knowledge-extract.md` consumed by Phase 2 + Phase 4 + Phase 5, then deleted at end of Phase 5.

**Files to read (in this order — most authoritative first):**

| Priority | Path glob | What to extract |
|---|---|---|
| 1 | `ai/decisions/*.md` (NOT `_decision-index.md`) | Every ADR — decision title, context, decision, consequences. ALL preserved verbatim into the extract; ADRs are append-only history. |
| 2 | `ai/business-domain.md` | Domain glossary (custom terms with project-specific meanings), core flows, compliance notes. |
| 3 | `ai/project-goals.md` / `ai/users-and-personas.md` | Mission, target users, business model, success KPIs, constraints, anti-goals — the project-intent block. |
| 4 | `ai/conventions.md` + `ai/_convention-cheatsheet.md` | Project-specific naming, suffix matrix, base classes, MUST/MUST-NOT bullets that are NOT generic. |
| 5 | `ai/patterns/*.md` | Patterns referenced by ADRs OR cited in CLAUDE.md OR with non-obvious WHY blocks. Generic copy-paste patterns are NOT extracted (will regen). |
| 6 | `.claude/rules/*.md` | Custom rules — anything that is NOT a verbatim pack rule. Diff against `~/.claude/templates/packs/*/rules/*.md`; keep only the delta. |
| 7 | `.claude/agents/*.md` | Custom agents — same diff logic against pack agents. Hand-tuned prompt prose is the durable asset; pack-equivalent agents are NOT extracted. |
| 8 | `.claude/skills/**/*.md` + `.claude/commands/*.md` | Custom skills/commands not in any pack; user corrections to pack versions. |
| 9 | `.claude/codebase-profile.md` | Detected base classes, paths, conventions — already-paid-for analysis. Re-validate in Phase 2; if codebase still matches, don't re-detect. |
| 10 | `CLAUDE.md` + `AGENTS.md` | Top-of-file project-specific blocks (above the line "Detected stack"). Generic prose below that line is regen-replaceable. |
| 11 | `ai/dynamic/learnings.md` + `ai/dynamic/corrections.md` (if Phase 6 has been running) | Validated corrections — these are the "user told us no, do it this way" memory. ALWAYS extracted. |
| 12 | `ai/runbooks/*.md` | Project-specific operational steps (incident response, deploy, debug). Anything beyond pack templates. |
| 13 | `ai/architecture.md` | Project-specific architecture overview (modules, deps, boundaries). Diff against any pack-template archetype; keep delta verbatim. |
| 14 | `ai/runtime/*.md` | Runtime topology, deployment surfaces, env-var contracts. Always extracted verbatim — these are facts the codebase doesn't fully encode. |
| 15 | `ai/audits/*.md` | Past audit reports + their findings. Append-only history; preserve verbatim alongside ADRs. |
| 16 | `ai/failures/*.md` (incl. `_index.md`) | Failure catalog (B10) — past architectural failures + their lessons. Append-only; preserve verbatim. |
| 17 | `.claude/hooks/*.sh` (only the user-edited ones) | Project-customised hooks. Diff against `~/.claude/templates/repo-baseline/.claude/hooks/*.sh`; keep delta. Pack-verbatim hooks regen from baseline. |
| 18 | `.claude/git-hooks/post-*` | Only if the user added project-specific logic above the `exec` line. Otherwise the baseline shim regenerates verbatim. |
| 19 | `**/* — catch-all sweep` | After the table is fully consumed, run a final sweep over every other file in `ai/` and `.claude/` not yet covered. Anything user-touched (mtime newer than the baseline copy or content not byte-identical to its pack source) gets extracted into a new `## 9. Uncategorized user-touched files` section verbatim. This is the safety net against future spec drift — new file categories never silently lose data on REFRESH. |

**Extraction format** (`.claude/_refresh-knowledge-extract.md` shape):

```markdown
# Refresh Knowledge Extract — <YYYY-MM-DD HH:MM>

> Auto-generated by `/setup-project --refresh` Phase 0.2.
> Consumed by Phase 2 (merge), Phase 4 (regen input), Phase 5 (audit).
> Deleted at end of Phase 5 once verified durable items survived into final output.

## 1. ADR-grade decisions (verbatim, append-only)
<dump every ai/decisions/*.md file head + body, preserve original IDs>

## 2. Domain knowledge (custom glossary terms + core flows)
<extract from ai/business-domain.md + project-goals.md>
- term: "tenant subscriber" — meaning: <project-specific>; differs from generic "user" because <reason>
- flow: <name> — <steps with project-specific behavior>

## 3. Project intent (mission, users, model, KPIs, constraints)
<extract from ai/project-goals.md + ai/users-and-personas.md>

## 4. Custom conventions (delta from pack defaults)
<extract from ai/conventions.md + _convention-cheatsheet.md, removing generic copy-paste content>

## 5. Custom rules (delta from pack rules)
<diff per .claude/rules/*.md against ~/.claude/templates/packs/*/rules/*.md, keep additions/edits only>

## 6. Custom agents/skills/commands (delta from pack defaults)
<list each non-pack artifact with full body; for pack-derived but edited artifacts, list the diff>

## 7. Validated corrections (from Phase 6 learnings, if any)
<verbatim from ai/dynamic/corrections.md + learnings.md>

## 8. Custom patterns + runbooks
<extract from ai/patterns/*.md + ai/runbooks/*.md; only project-idiom content>

## 9. Uncategorized user-touched files (catch-all sweep)
<every file under ai/ and .claude/ not covered by sections 1-8 that is mtime-newer-than-baseline OR not byte-identical to its pack source. List path + full content verbatim. This is the safety net against silent knowledge loss when the spec adds new file categories faster than this table.>

## 10. Architecture, runtime, audits, failures (verbatim preservation)
<verbatim copy of every ai/architecture.md, ai/runtime/*.md, ai/audits/*.md, ai/failures/*.md not already in section 1>

## 11. Custom hooks (delta from baseline)
<diff per .claude/hooks/*.sh + .claude/git-hooks/post-* against ~/.claude/templates/repo-baseline/.claude/{hooks,git-hooks}/; keep additions/edits only>

## 12. Detected facts to re-validate (from .claude/codebase-profile.md)
<copy current detected stack/base-classes/paths into extract; Phase 2 re-validates against codebase>

## 13. Drop list (what we INTENTIONALLY discarded)
<for transparency: which existing files are pack-equivalent and will be regenerated, not extracted>

---
Total durable items extracted: <N>
Total files read: <M>
Total files marked for regen-without-preservation: <P>
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

