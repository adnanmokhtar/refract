#!/usr/bin/env bash
# run-preflight.sh — single composite invocation of all M15+M16 deterministic checks.
#
# Solves the "agent forgot to run all 4 scripts" risk: now there is ONE script.
# The orchestrator's hard rule becomes "run scripts/run-preflight.sh <target>"
# instead of "run these 4 separate scripts in order."
#
# Usage:
#   run-preflight.sh <target-repo> [--mode=refresh|refine|enhance|create] [packs...]
#
# Modes:
#   refresh / refine / enhance — runs all 4 scripts (full deterministic preflight).
#   create — runs only deep-codebase-scan + pack-coverage (skips refresh-extract;
#            CREATE has nothing to extract from).
#
# Output: 4 reports under <target>/.claude/_*.md. Exit 0 on success.
# Failure: any sub-script returns non-zero → this script exits same code.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--mode=refresh|refine|enhance|create] [packs...]" >&2
  exit 2
fi

TARGET="$1"; shift
MODE="refresh"
PACKS=()
INCLUDE_PACKS=()
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)     MODE="${1#--mode=}"; shift ;;
    --include=*)  IFS=',' read -ra INCLUDED <<< "${1#--include=}"
                  for p in "${INCLUDED[@]}"; do
                    # Track --include packs separately so refresh can UNION them with
                    # detected tracks (M23: --include ADDS scope; never SUBTRACTS).
                    [[ -n "$p" ]] && { PACKS+=("$p"); INCLUDE_PACKS+=("$p"); }
                  done
                  shift ;;
    --force)      FORCE=1; shift ;;
    *)            PACKS+=("$1"); shift ;;
  esac
done

# Normalize the mode string (#4): Phase 1 emits CREATE / ENHANCE-retrofit / ENHANCE-extend /
# REFRESH / REFINE; downstream string-matches lowercase create|enhance|refresh|refine.
MODE=$(printf '%s' "$MODE" | tr 'A-Z' 'a-z' | sed 's/enhance-.*/enhance/; s/refresh-.*/refresh/; s/refine-.*/refine/')

# When --force is set, propagate to the LLM-section-preserving sub-scripts
# (refresh-extract-checklist + deep-codebase-scan) so they regenerate fresh
# templates and overwrite existing LLM-filled content. Default = preserve.
FORCE_FLAG=""
[[ "$FORCE" -eq 1 ]] && FORCE_FLAG="--force"

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

echo "=== run-preflight: mode=$MODE target=$TARGET ==="
echo ""

# STEP -1 (M35): deterministic Phase 0 backup — REFRESH / REFINE only.
# The backup is taken by THIS script, not by agent discipline: two observed runs
# (2026-06-10) skipped it when left to judgment. Skips only if a backup younger
# than 60 minutes already exists (re-running preflight within one session).
if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
  BK_ROOT="$TARGET/.claude/backups"
  recent_bk=$( { find "$BK_ROOT" -mindepth 1 -maxdepth 1 -type d -mmin -60 2>/dev/null || true; } | head -1)
  if [[ -n "$recent_bk" ]]; then
    echo "[backup] recent backup exists (<60 min): ${recent_bk#$TARGET/} — not duplicating"
  else
    BK="$BK_ROOT/$(date +%Y%m%d-%H%M)"
    mkdir -p "$BK/.claude"
    # Track exactly what we copied so restore.sh + the manifest are accurate (#5).
    BK_DIRS=()   # repo-relative dirs copied
    BK_FILES=()  # repo-relative files copied
    for d in commands agents skills rules hooks; do
      [[ -d "$TARGET/.claude/$d" ]] && { cp -R "$TARGET/.claude/$d" "$BK/.claude/$d"; BK_DIRS+=(".claude/$d"); }
    done
    for f in settings.json settings.local.json codebase-profile.md GUIDE.md _refresh-decisions.md; do
      [[ -f "$TARGET/.claude/$f" ]] && { cp "$TARGET/.claude/$f" "$BK/.claude/$f"; BK_FILES+=(".claude/$f"); }
    done
    [[ -d "$TARGET/ai" ]] && { cp -R "$TARGET/ai" "$BK/ai"; BK_DIRS+=("ai"); }
    for f in CLAUDE.md AGENTS.md; do
      [[ -f "$TARGET/$f" ]] && { cp "$TARGET/$f" "$BK/$f"; BK_FILES+=("$f"); }
    done

    # Adapter files (#5): REFRESH re-syncs adapters via /setup-project-adapters, so
    # an unbacked refresh can destroy a user's hand-edited Cursor/OpenCode/etc native
    # files. Back up every adapter dir + config so restore.sh can recover them.
    ADAPTER_DIRS=(.cursor .opencode .clinerules .windsurf .continue .kimi .qwen .github/agents .github/prompts .agents)
    ADAPTER_FILES=(opencode.json .cursorrules .aider.conf.yml .aiderignore GEMINI.md AGENTS.override.md .github/copilot-instructions.md)
    for d in "${ADAPTER_DIRS[@]}"; do
      if [[ -d "$TARGET/$d" ]]; then
        mkdir -p "$BK/$(dirname "$d")"
        cp -R "$TARGET/$d" "$BK/$d"
        BK_DIRS+=("$d")
      fi
    done
    for f in "${ADAPTER_FILES[@]}"; do
      if [[ -f "$TARGET/$f" ]]; then
        mkdir -p "$BK/$(dirname "$f")"
        cp "$TARGET/$f" "$BK/$f"
        BK_FILES+=("$f")
      fi
    done

    # Manifest lists every backed-up path (C2a / manifest verification reads this).
    {
      printf 'mode: %s\n' "$MODE"
      printf 'created: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'by: run-preflight.sh (M35 deterministic Phase 0 backup)\n'
      printf 'restore: run ./restore.sh from inside this backup dir\n'
      printf '\n## Backed-up paths\n'
      # Guard empty-array expansion under `set -u` (bash 3.2): only iterate when non-empty.
      [[ ${#BK_DIRS[@]}  -gt 0 ]] && for p in "${BK_DIRS[@]}";  do printf -- '- %s\n' "$p"; done
      [[ ${#BK_FILES[@]} -gt 0 ]] && for p in "${BK_FILES[@]}"; do printf -- '- %s\n' "$p"; done
    } > "$BK/_backup-manifest.txt"

    # restore.sh — deterministic, idempotent recovery of every backed-up path.
    {
      printf '#!/usr/bin/env bash\n'
      printf '# Auto-generated by run-preflight.sh (M35). Restores this backup over the target.\n'
      printf 'set -euo pipefail\n'
      printf 'BK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n'
      printf 'TARGET="%s"\n' "$TARGET"
      printf 'echo "Restoring backup $BK → $TARGET"\n'
      if [[ ${#BK_DIRS[@]} -gt 0 ]]; then
        for p in "${BK_DIRS[@]}"; do
          printf 'rm -rf "$TARGET/%s"; mkdir -p "$TARGET/$(dirname "%s")"; cp -R "$BK/%s" "$TARGET/%s"\n' "$p" "$p" "$p" "$p"
        done
      fi
      if [[ ${#BK_FILES[@]} -gt 0 ]]; then
        for p in "${BK_FILES[@]}"; do
          printf 'mkdir -p "$TARGET/$(dirname "%s")"; cp "$BK/%s" "$TARGET/%s"\n' "$p" "$p" "$p"
        done
      fi
      printf 'echo "Restore complete."\n'
    } > "$BK/restore.sh"
    chmod +x "$BK/restore.sh"
    echo "[backup] Phase 0 backup → ${BK#$TARGET/} (${#BK_DIRS[@]} dirs + ${#BK_FILES[@]} files; restore.sh written)"
  fi
  echo ""
fi

# STEP 0 (M28): signal-driven track detection BEFORE any pack-coverage / study
# work. Replaces the old fallback ("scan all 17 packs when no tracks declared")
# which polluted frontend projects with backend/database/mobile content.
#
# M23 union fix (#4): in refresh/refine/enhance, `--include=<pack>` must ADD scope,
# never narrow it — refresh covers ALL existing tracks PLUS the included pack. The
# old guard `if [[ ${#PACKS[@]} -eq 0 ]]` skipped detection entirely whenever
# --include was passed, so `--refresh --include=migration` scoped preflight to ONLY
# migration (contradicting M23). Now: detect tracks and UNION with --include packs.
# For CREATE (and explicit positional packs with no --include), keep the old
# behaviour — detection only runs when nothing was supplied.
run_detection=0
if [[ ${#PACKS[@]} -eq 0 ]]; then
  run_detection=1
elif [[ ( "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ) && ${#INCLUDE_PACKS[@]} -gt 0 ]]; then
  # Only --include packs were supplied (or --include + positionals) in a refresh-
  # family mode → still detect and union so we don't drop existing tracks.
  run_detection=1
fi

if [[ $run_detection -eq 1 ]]; then
  echo "[0/5] detect-tracks.sh (union with any --include packs)"
  detected_tracks=()
  while IFS= read -r t; do
    [[ -n "$t" ]] && detected_tracks+=("$t")
  done < <("$SCRIPTS/detect-tracks.sh" "$TARGET" --write 2>/dev/null)
  # Union: existing PACKS (which may carry --include + positionals) + detected,
  # de-duplicated, order-stable (existing first, then new detected).
  # Guard empty-array expansion under `set -u` (bash 3.2).
  if [[ ${#detected_tracks[@]} -gt 0 ]]; then
    for t in "${detected_tracks[@]}"; do
      dup=0
      if [[ ${#PACKS[@]} -gt 0 ]]; then
        for p in "${PACKS[@]}"; do [[ "$p" == "$t" ]] && { dup=1; break; }; done
      fi
      [[ $dup -eq 0 ]] && PACKS+=("$t")
    done
  fi
  if [[ ${#PACKS[@]} -eq 0 ]]; then
    echo "  WARN detect-tracks returned nothing — falling back to all packs"
  else
    echo "  tracks (detected ∪ --include): ${PACKS[*]}"
  fi
  echo ""
fi

# STEP 0.5 (M29): MCP server recommendations driven by the same signals.
# Emits the report AND merges recommended servers into <target>/.mcp.json.
# Merge semantics: user-added servers are preserved; only adds entries whose
# server key isn't already present. Never overwrites or removes.
if [[ -x "$SCRIPTS/detect-mcp.sh" ]]; then
  echo "[0.5/5] detect-mcp.sh"
  "$SCRIPTS/detect-mcp.sh" "$TARGET" --apply 2>&1 | tail -4
  echo ""
fi

# Helper: invoke a script with target + optional pack list. Avoids the
# `"${PACKS[@]:-}"` trap (expands to "" when empty, which downstream scripts
# read as a real pack-name argument and skip their auto-detect path).
run_with_packs() {
  local script="$1"; shift
  if [[ ${#PACKS[@]} -gt 0 ]]; then
    "$script" "$TARGET" "${PACKS[@]}" 2>&1 | tail -3
  else
    "$script" "$TARGET" 2>&1 | tail -3
  fi
}

# 1. Pack coverage scan — scoped to detected/declared tracks
echo "[1/4] pack-coverage-scan.sh"
run_with_packs "$SCRIPTS/pack-coverage-scan.sh"

# 2. Refresh-extract checklist — skip in CREATE mode
if [[ "$MODE" == "create" ]]; then
  echo "[2/4] refresh-extract-checklist.sh — SKIPPED (CREATE mode has nothing to extract)"
else
  echo "[2/4] refresh-extract-checklist.sh"
  "$SCRIPTS/refresh-extract-checklist.sh" "$TARGET" $FORCE_FLAG 2>&1 | tail -2
fi

# 3. Study existing — always
echo "[3/4] study-existing.sh"
run_with_packs "$SCRIPTS/study-existing.sh"

# 4. Deep codebase scan — always
echo "[4/4] deep-codebase-scan.sh"
"$SCRIPTS/deep-codebase-scan.sh" "$TARGET" $FORCE_FLAG 2>&1 | tail -2

echo ""
echo "=== preflight complete ==="
echo ""
echo "Reports written to $TARGET/.claude/:"
ls -1 "$TARGET/.claude/" 2>/dev/null | grep -E '^_(pack-coverage|refresh-extract|study-existing|codebase-scan)' | sed 's/^/  /'
echo ""
echo "Next: agent reads ALL reports, fills <TBD> sections, applies decisions in Phase 4."
echo "Phase 5 will fail the run if any required section is left <TBD> OR if any actionable row was silently skipped."
exit 0
