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

# Resolve through the global-install symlink so REPO_ROOT is the CHECKOUT, never ~/.claude.
# ~/.claude/scripts/<name> is a symlink INTO this repo, so an unresolved BASH_SOURCE makes
# dirname() report ~/.claude/scripts and every sibling asset reached for below resolves only
# if it, too, happens to have been linked. That is exactly how the merge engine went missing:
# scripts/merge-decide.py existed at HEAD, sync-to-global.sh had not been re-run since it
# landed, and $REPO_ROOT/scripts/merge-decide.py pointed at a link that was never created — so
# 238 MERGE rows across two live repos degraded to "listed, not decided" and the run still
# exited 0. See CONTRIBUTING § "Scripts run from two places". Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
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

# Normalize the mode string (#4): Phase 1 emits CREATE / ENHANCE-retrofit /
# ENHANCE-extend / REFRESH / REFINE / UPGRADE (templates/phases/phase-1-detect-mode.md
# § "Decide mode" is the single authority on those six spellings); downstream
# string-matches lowercase create|enhance|refresh|refine.
#
# UPGRADE folds to `refresh` — that is not a shortcut, it is the ceremony this
# mode is DEFINED as: `commands/setup-project.md` § "Mode → ceremony" says
# MIGRATE-THEN-REFRESH, "then the REFRESH ceremony verbatim". Until this line
# existed, `UPGRADE` lowercased to `upgrade`, matched no guard in this script or
# in audit-setup.sh, and the mode advertised as the MOST ceremonious got the
# LEAST: no Phase-0 backup (the guard below), no C2a, no C2n. MODE_LABEL keeps
# the announced label so Phase 5's mode-drift self-audit still sees `upgrade`.
MODE_LABEL=$(printf '%s' "$MODE" | tr 'A-Z' 'a-z')
MODE=$(printf '%s' "$MODE_LABEL" | sed 's/enhance-.*/enhance/; s/refresh-.*/refresh/; s/refine-.*/refine/; s/^upgrade.*$/refresh/')

# When --force is set, propagate to the LLM-section-preserving sub-scripts
# (refresh-extract-checklist + deep-codebase-scan) so they regenerate fresh
# templates and overwrite existing LLM-filled content. Default = preserve.
FORCE_FLAG=""
[[ "$FORCE" -eq 1 ]] && FORCE_FLAG="--force"

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

if [[ "$MODE_LABEL" == upgrade* ]]; then
  echo "=== run-preflight: mode=$MODE_LABEL (REFRESH ceremony) target=$TARGET ==="
  echo "[upgrade] this preflight runs the REFRESH half only. The MIGRATE half is a"
  echo "[upgrade] separate step the agent must run FIRST: $REPO_ROOT/scripts/migrate-setup.sh \"$TARGET\""
else
  echo "=== run-preflight: mode=$MODE target=$TARGET ==="
fi
echo ""

# ---- STEP -2: is the global install current? --------------------------------------------
#
# NOTHING USED TO ASK. On 2026-08-23 seven files committed at HEAD were absent from
# ~/.claude/scripts, sync-to-global.sh had not been run since they landed, and the one that
# mattered — merge-decide.py — was the entire payload of a seven-batch programme. Two live
# repos got 238 MERGE rows "listed, not decided" and an exit 0.
#
# Every script now resolves its own checkout (CONTRIBUTING § 2a), so drift can no longer break
# LIBRARY resolution — but the ENTRY POINT the agent types is still whatever the global install
# holds, and a stale entry point is a stale run. So: report it, once, at the top, with the exact
# remedy. This is a REPORT, not a halt: running the scripts straight out of a checkout is a
# supported invocation and there is no global install to be stale in that case.
_gl="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/scripts"
if [[ -d "$_gl" ]]; then
  _missing=0; _stale=0; _first=""
  while IFS= read -r _rs; do
    _b="${_rs##*/}"
    if [[ ! -e "$_gl/$_b" ]]; then
      _missing=$(( _missing + 1 )); [[ -z "$_first" ]] && _first="$_b"
    elif [[ -L "$_gl/$_b" ]]; then
      _tgt="$(readlink "$_gl/$_b")"
      [[ "$_tgt" == "$_rs" ]] || { _stale=$(( _stale + 1 )); [[ -z "$_first" ]] && _first="$_b"; }
    elif ! cmp -s "$_gl/$_b" "$_rs" 2>/dev/null; then
      _stale=$(( _stale + 1 )); [[ -z "$_first" ]] && _first="$_b"
    fi
  done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null | sort)
  if [[ $(( _missing + _stale )) -gt 0 ]]; then
    echo "[install] GLOBAL INSTALL IS BEHIND THIS CHECKOUT: $_missing file(s) missing, $_stale stale (first: $_first)."
    echo "[install] The scripts below resolve their own checkout, so this run is correct either way —"
    echo "[install] but the ENTRY POINT you typed may not be. Re-link when convenient:"
    echo "[install]   bash $REPO_ROOT/scripts/sync-to-global.sh --apply"
    echo ""
  fi
fi

# STEP -1 (M35): deterministic Phase 0 backup — REFRESH / REFINE / UPGRADE /
# ENHANCE. The backup is taken by THIS script, not by agent discipline: two
# observed runs (2026-06-10) skipped it when left to judgment. Skips only if a
# backup younger than 60 minutes already exists (re-running preflight within one
# session).
#
# ENHANCE IS IN SCOPE (M36). It was excluded on the claim that "ENHANCE never
# overwrites existing user content" — false, and the run that disproved it was an
# ENHANCE: it replaced three hand-authored files. `ENHANCE-extend` fires
# (phase-1-detect-mode.md) exactly when `.claude/` + `ai/` + `CLAUDE.md` are ALL
# present, so "there is no prior setup to back up" is true of retrofit-with-nothing
# and of nothing else. The per-run `study-decisions-<ts>/` snapshot is NOT a
# substitute: apply-study-decisions.sh creates it only when it actually replaces a
# file, so a run that damages the tree any other way has nothing to restore from
# and C2n's per-file comparison has nothing to compare. What keeps this honest for
# a genuinely empty retrofit is HAVE_PRIOR below: the backup is taken when there is
# something to back up, in every one of those four modes, and skipped — announced —
# when there is not.
if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
  BK_ROOT="$TARGET/.claude/backups"
  # Is there any prior setup at all? Same path set the copy loops below use.
  HAVE_PRIOR=0
  for _p in .claude/commands .claude/agents .claude/skills .claude/rules .claude/hooks \
            .claude/settings.json .claude/settings.local.json .claude/codebase-profile.md \
            .claude/GUIDE.md .claude/_refresh-decisions.md ai CLAUDE.md AGENTS.md \
            .cursor .opencode .clinerules .windsurf .continue .kimi .qwen .agents \
            .github/agents .github/prompts opencode.json .cursorrules .aider.conf.yml \
            .aiderignore GEMINI.md AGENTS.override.md .github/copilot-instructions.md; do
    [[ -e "$TARGET/$_p" ]] && { HAVE_PRIOR=1; break; }
  done
  # FRESHNESS IS READ FROM THE DIRECTORY NAME, NOT ITS MTIME, AND THE CANDIDATE MUST ACTUALLY
  # HOLD A BACKUP.
  #
  # MEASURED, on the delivery run this comment was written for. `find -mmin -60` asks the
  # FILESYSTEM how old the directory is. A `git reset` (or a checkout, or a restore, or rsync,
  # or Time Machine) refreshes the mtimes of the tracked files inside `.claude/backups/…`, and
  # the directory follows. At 14:09 a backup directory named `20260823-0515` — 8 h 54 m old by
  # the only timestamp that is actually about the backup, the one this script itself encoded in
  # the name — looked younger than 60 minutes. The run deferred to it, and then rewrote 107
  # files. Worse, the thing it deferred to held exactly ONE file (683 bytes of
  # settings.local.json) against a setup of 169 .claude + 117 ai files, so the run proceeded
  # with no usable backup at all, while M35 promises "the agent never decides whether to back
  # up" and C2a is supposed to refuse success without one.
  #
  # Two independent conditions now have to hold before this script skips its own backup:
  #   1. the NAME parses as a timestamp inside the window (mtime is not evidence about a
  #      backup's age — it is evidence about the last thing that touched the filesystem), and
  #   2. the directory holds enough files to be a backup of this setup rather than a token —
  #      at least 10, and at least a fifth of the .claude/+ai/ files it claims to cover.
  # Anything else is treated as "no recent backup" and a real one is taken. Taking a redundant
  # backup costs seconds; skipping a needed one costs the project.
  _now_epoch=$(date +%s)
  _live_files=$( { find "$TARGET/.claude" "$TARGET/ai" -type f -not -path "*/backups/*" 2>/dev/null || true; } | grep -c . || true)
  _live_files="${_live_files:-0}"
  recent_bk=""
  while IFS= read -r _cand; do
    [[ -z "$_cand" ]] && continue
    _nm="${_cand##*/}"
    # `YYYYMMDD-HHMM` or `YYYYMMDD-HHMMSS`, optionally prefixed (`anchors-`, `skill-shape-`…).
    _stamp=$(printf '%s' "$_nm" | sed -nE 's/.*([0-9]{8})-([0-9]{4})([0-9]{2})?$/\1 \2\3/p')
    [[ -z "$_stamp" ]] && continue
    _d="${_stamp%% *}"; _t="${_stamp##* }"
    _hh="${_t:0:2}"; _mm="${_t:2:2}"; _sec="${_t:4:2}"; _sec="${_sec:-00}"
    _bk_epoch=$(date -j -f '%Y%m%d %H%M%S' "$_d ${_hh}${_mm}${_sec}" +%s 2>/dev/null \
                || date -d "${_d:0:4}-${_d:4:2}-${_d:6:2} ${_hh}:${_mm}:${_sec}" +%s 2>/dev/null || true)
    [[ -z "$_bk_epoch" ]] && continue
    _age=$(( _now_epoch - _bk_epoch ))
    [[ "$_age" -lt 0 || "$_age" -ge 3600 ]] && continue
    _bk_files=$( { find "$_cand" -type f 2>/dev/null || true; } | grep -c . || true)
    _bk_files="${_bk_files:-0}"
    _floor=$(( _live_files / 5 ))
    [[ "$_floor" -lt 10 ]] && _floor=10
    if [[ "$_bk_files" -lt "$_floor" ]]; then
      echo "[backup] ${_cand#$TARGET/} is $(( _age / 60 )) min old but holds only $_bk_files file(s) against $_live_files live setup file(s) — that is a partial snapshot, not a backup. Taking a full one."
      continue
    fi
    recent_bk="$_cand"
    break
  done < <( { find "$BK_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true; } | sort -r)
  if [[ "$HAVE_PRIOR" -eq 0 ]]; then
    echo "[backup] no prior setup on disk (no .claude/, ai/, CLAUDE.md or adapter files) — nothing to back up"
  elif [[ -n "$recent_bk" ]]; then
    echo "[backup] recent backup exists (<60 min): ${recent_bk#$TARGET/} — not duplicating"
  else
    # Seconds, not minutes. Two preflights in the same minute used to land in the SAME
    # directory and merge, producing one backup whose manifest describes only the second run.
    # The freshness parser above accepts both -HHMM and -HHMMSS, so old directories still read.
    BK="$BK_ROOT/$(date +%Y%m%d-%H%M%S)"
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
      printf 'mode: %s\n' "$MODE_LABEL"
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
