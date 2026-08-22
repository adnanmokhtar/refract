#!/usr/bin/env bash
# audit-setup.sh — Phase 5 deterministic audit. Read the 4 reports + verify completeness.
#
# Solves the "agent forgot to run Phase 5 audit" risk: this is a single script the
# orchestrator MUST invoke at the end of every refresh/refine/enhance/migration run.
# Returns 0 if all checks pass; non-zero with a numbered report otherwise.
#
# Usage:
#   audit-setup.sh <target-repo> [--mode=refresh|refine|enhance|create] [--read-only]
#
# Flags:
#   --read-only  (alias --no-write) Audit WITHOUT writing anything into <target-repo>.
#                Without it, a bare no-flag run of this audit writes THREE files into the
#                repo it is auditing — C2k regenerates `_study-existing-report.md`, C2d
#                `_anchoring-audit.md`, C2e `_adapter-coverage-audit.md` — because each
#                sub-audit's only sink was inside the target. The verdicts are identical
#                either way; --read-only just moves the three sinks to a scratch dir.
#
# Exits:
#   0 — all checks pass; safe to report success
#   1 — at least one mandatory check failed; agent must NOT report success
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--mode=...] [--read-only]" >&2
  echo "       --read-only = audit without writing anything under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
MODE="refresh"
LIGHTWEIGHT=0
NO_ADAPTERS=0
READONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*)      MODE="${1#--mode=}"; shift ;;
    --lightweight) LIGHTWEIGHT=1; shift ;;
    --no-adapters) NO_ADAPTERS=1; shift ;;
    --read-only|--no-write) READONLY=1; shift ;;
    *)             shift ;;
  esac
done
# Normalize the mode string (#4): Phase 1 emits CREATE / ENHANCE-retrofit /
# ENHANCE-extend / REFRESH / REFINE / UPGRADE — the six canonical spellings of
# templates/phases/phase-1-detect-mode.md § "Decide mode" — but every check below
# string-matches lowercase create|enhance|refresh|refine. Without this,
# `ENHANCE-retrofit` never matches "enhance" (adapter-sync + baseline gates
# silently no-op) and `CREATE` runs checks the file says CREATE is exempt from.
#
# UPGRADE folds to `refresh` for the same reason run-preflight.sh does: its
# ceremony IS "the REFRESH ceremony verbatim" (commands/setup-project.md § "Mode →
# ceremony"). Before this, `upgrade` matched no guard here and the most ceremonious
# mode was audited by C2a and C2n not at all. MODE_LABEL keeps the announced label.
MODE_LABEL=$(printf '%s' "$MODE" | tr 'A-Z' 'a-z')
MODE=$(printf '%s' "$MODE_LABEL" | sed 's/enhance-.*/enhance/; s/refresh-.*/refresh/; s/refine-.*/refine/; s/^upgrade.*$/refresh/')

CL="$TARGET/.claude"
fail=0
warn=0

# ── Sub-audit report sinks ─────────────────────────────────────────────────────
# This script is named `audit-*` and reads as a health check, but three of its checks
# REGENERATE their input by shelling out to a sub-audit whose only sink was inside the
# target. So auditing a repo modified it: observed 2026-08-22, a bare `audit-setup.sh
# <target>` wrote _study-existing-report.md (C2k), _anchoring-audit.md (C2d) and
# _adapter-coverage-audit.md (C2e) into a project that had been declared read-only.
# Under --read-only the same three sub-audits run with --report=<scratch>, so the
# numbers below are still freshly computed — only the sink moves off the target.
# The three apply-* scripts this file also calls (apply-adapter-sync, apply-baseline-sync)
# are dry-run by default and are invoked WITHOUT --apply, so they need no equivalent.
STUDY_REPORT="$CL/_study-existing-report.md"
ANCHOR_REPORT="$CL/_anchoring-audit.md"
ADAPTER_REPORT="$CL/_adapter-coverage-audit.md"
RO_STUDY_ARGS=(); RO_ANCHOR_ARGS=(); RO_ADAPTER_ARGS=()
if [[ $READONLY -eq 1 ]]; then
  RO_DIR=$(mktemp -d "${TMPDIR:-/tmp}/audit-setup-ro.XXXXXX")
  # Deliberately NOT trap-deleted: C2d's remediation prints the anchoring report path,
  # and a path that no longer exists by the time the reader copies it is worse than no
  # path. The dir lives under $TMPDIR and is the OS's to reap.
  echo "read-only: nothing will be written under $TARGET; sub-audit reports -> $RO_DIR" >&2
  STUDY_REPORT="$RO_DIR/_study-existing-report.md"
  ANCHOR_REPORT="$RO_DIR/_anchoring-audit.md"
  ADAPTER_REPORT="$RO_DIR/_adapter-coverage-audit.md"
  RO_STUDY_ARGS=(--report="$STUDY_REPORT")
  RO_ANCHOR_ARGS=(--report="$ANCHOR_REPORT")
  RO_ADAPTER_ARGS=(--report="$ADAPTER_REPORT")
fi

err() { echo "  ERR  $*"; fail=$((fail + 1)); }
warn_msg() { echo "  WARN $*"; warn=$((warn + 1)); }
ok() { echo "  ok   $*"; }

# Select the authoritative pre-refresh backup. run-preflight.sh writes the ONLY
# backup that carries restore.sh + a full ai/ snapshot + manifest. But Phase 4's
# apply-study-decisions.sh / apply-anchors.sh each create their own thin,
# timestamped backup dirs (study-decisions-*, anchors-*, resolve-adopt-*) that a
# naive "newest dir" pick (sort | tail -1) lands on — lexically those letter-led
# names sort AFTER the digit-led preflight stamp, so C2a falsely reported a thin
# backup and C2n compared against the wrong (thin) snapshot (observed 2026-07-09).
# Prefer the newest backup that actually has restore.sh; fall back to newest-overall.
newest_preflight_backup() {
  local d picked=""
  while IFS= read -r d; do
    [[ -x "$d/restore.sh" ]] && picked="$d"
  done < <(find "$CL/backups" -mindepth 1 -maxdepth 1 -type d -mmin -1440 2>/dev/null | sort)
  [[ -z "$picked" ]] && picked=$( { find "$CL/backups" -mindepth 1 -maxdepth 1 -type d -mmin -1440 2>/dev/null || true; } | sort | tail -1)
  printf '%s' "$picked"
}

if [[ "$MODE_LABEL" == upgrade* ]]; then
  echo "=== Phase 5 audit — target=$TARGET mode=$MODE_LABEL (REFRESH ceremony) ==="
else
  echo "=== Phase 5 audit — target=$TARGET mode=$MODE ==="
fi
echo ""

# C2a (M35) — Phase 0 backup present for REFRESH / REFINE.
# run-preflight.sh creates it deterministically; if it's absent the preflight
# itself was skipped — the run is structurally invalid, refuse before anything else.
if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
  echo "C2a: Phase 0 backup (M35)"
  recent_bk=$(newest_preflight_backup)
  if [[ -n "$recent_bk" ]]; then
    ok "backup present: ${recent_bk#$TARGET/}"
    # Full-manifest verification (#5): a thin backup that omits adapter files +
    # restore.sh used to pass C2a, so a refresh could destroy unbacked adapter
    # files. Require restore.sh AND — when the target HAS adapter files — that the
    # manifest actually lists them.
    if [[ -x "$recent_bk/restore.sh" ]]; then
      ok "restore.sh present in backup"
    else
      err "backup has no restore.sh — thin backup; re-run run-preflight.sh so adapter files + restore are captured"
    fi
    # Detect adapter presence in the target (same signatures as M34).
    adapter_present=0
    for ap in .cursor .opencode .clinerules .windsurf .continue .kimi .qwen .agents \
              .github/agents .github/prompts opencode.json .cursorrules .aider.conf.yml \
              .aiderignore GEMINI.md AGENTS.override.md .github/copilot-instructions.md; do
      [[ -e "$TARGET/$ap" ]] && { adapter_present=1; break; }
    done
    if [[ $adapter_present -eq 1 ]]; then
      if grep -qE '^- (\.cursor|\.opencode|\.clinerules|\.windsurf|\.continue|\.kimi|\.qwen|\.agents|\.github/|opencode\.json|\.cursorrules|\.aider|GEMINI\.md|AGENTS\.override)' "$recent_bk/_backup-manifest.txt" 2>/dev/null; then
        ok "backup manifest covers adapter files"
      else
        err "target has adapter files but backup manifest omits them — REFRESH could destroy adapter files unbacked. Re-run run-preflight.sh."
      fi
    fi
  else
    err "no backup created in the last 24h — run-preflight.sh (M35 Phase 0 backup) did not run; re-run: ~/.claude/scripts/run-preflight.sh \"$TARGET\" --mode=$MODE_LABEL"
  fi
  echo ""
fi

# --- C2n knowledge-token vocabulary (M36) -------------------------------------
# Keep IN SYNC with scripts/study-existing.sh (KNOW_SRC_EXT / KNOW_PATH_RE /
# KNOW_IDENT_RE). Deliberately duplicated rather than sourced: audit-setup.sh is
# invoked standalone from ~/.claude/scripts and must not acquire a new dependency.
# The gate uses the SAME definition of "project knowledge" the classifier uses to
# protect a file — so a file the classifier would refuse to replace, and whose
# identifiers then vanish anyway, is caught here by construction.
KNOW_SRC_EXT='ts|tsx|js|jsx|mjs|cjs|vue|svelte|py|go|rb|php|java|kt|kts|swift|scala|rs|cs|cpp|hpp|ex|exs|dart|sql|prisma|graphql|proto|tf|yaml|yml|json|toml|env|sh|md|css|scss|html'
KNOW_PATH_RE="[A-Za-z0-9_@.*-]+(/[A-Za-z0-9_@.*-]+)+\.($KNOW_SRC_EXT)"
KNOW_IDENT_RE='[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*|[A-Z][A-Z0-9]*_[A-Z0-9_]+|[a-z][a-z0-9]*_[a-z0-9_]+|[A-Z][A-Za-z0-9]*(-[A-Z][A-Za-z0-9]*)+|[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]+'

# know_tokens <file> <regex> → distinct matches, one per line, from the file with
# its `<!-- project-specific -->` block REMOVED. The anchor block is regenerated
# by apply-anchors.sh from the profile, so it is not hand-authored knowledge and
# must not mask its loss (the destroyed files were re-anchored after replacement,
# which would otherwise have restored an identifier count that means nothing).
know_tokens() {
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
    skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) skip=0; next }
    { print }
  ' "$1" 2>/dev/null | grep -ohE "$2" 2>/dev/null | sort -u || true
}

# C2n (knowledge-preservation) — a run must NOT silently drop extract-captured
# knowledge. ADRs are append-only; documented patterns survive a refresh.
#
# M36 — ENHANCE IS NOW IN SCOPE, and the check is per-file, not per-directory.
# Two inversions were found by running the framework against a real 8,151-file
# project on 2026-08-22:
#   (1) the mode guard was `refresh|refine` only. ENHANCE is the mode that
#       PROMISES to be additive (phase-0-backup-extract.md justifies skipping the
#       Phase-0 backup on exactly that promise), so a loss there is the most
#       surprising and was the least defended. That run was ENHANCE; it
#       overwrote three hand-authored files and this gate never looked.
#   (2) the check counted FILES per directory. All three destroyed files still
#       existed afterwards — only their contents were gone (project identifiers
#       9 -> 0, 18 -> 0, 2 -> 0). A file census cannot see that, in ANY mode.
# So: compare each backed-up file's project-knowledge tokens against the live
# file. Backups are ordered OLDEST-FIRST and the first copy of a path wins —
# apply-study-decisions.sh backs up BEFORE it replaces, apply-anchors.sh backs up
# after, so the oldest copy is the true pre-run state (a union or newest-wins
# pick would score pack text as lost knowledge on a correctly restored file).
if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
  echo "C2n: knowledge preservation (ADRs + patterns + per-file project knowledge)"
  bk=$(newest_preflight_backup)
  if [[ -z "$bk" ]]; then
    if [[ "$MODE" == "enhance" ]]; then
      warn_msg "no backup dir in .claude/backups from the last 24h — file-census comparison skipped. ENHANCE DOES take the Phase-0 backup now (run-preflight.sh STEP -1), so this means the preflight was skipped, or the target had no prior setup to back up (a bare ENHANCE-retrofit). Re-run: ~/.claude/scripts/run-preflight.sh \"$TARGET\" --mode=$MODE_LABEL"
    else
      warn_msg "no recent backup to compare against — cannot verify knowledge preservation (C2a should have already failed)"
    fi
  else
    count_md() { { find "$1" -name '*.md' -not -name '_*' -not -name 'README*' 2>/dev/null || true; } | grep -c . || true; }
    for sub in decisions patterns; do
      # A thin backup (study-decisions-*/anchors-*) holds only the files that run
      # touched, so `pre` is 0 and `post < pre` can never fire. Reporting that as
      # "ok ai/patterns/ preserved (0 -> 72)" is a false all-clear — say so instead.
      if [[ ! -d "$bk/ai/$sub" ]]; then
        warn_msg "ai/$sub/ census skipped — ${bk#$TARGET/} is a partial backup with no ai/$sub/ snapshot (per-file check below still applies)"
        continue
      fi
      pre=$(count_md "$bk/ai/$sub")
      post=$(count_md "$TARGET/ai/$sub")
      pre="${pre:-0}"; post="${post:-0}"
      if [[ "$post" -lt "$pre" ]]; then
        err "KNOWLEDGE_LOSS: ai/$sub/ dropped from $pre → $post since pre-refresh backup. ADRs/patterns are append-only — restore the dropped file(s) from ${bk#$TARGET/}/ai/$sub/"
      else
        ok "ai/$sub/ preserved ($pre → $post)"
      fi
    done
    # Extract-captured ADR IDs must each still exist post-refresh (presence, not just count).
    if [[ -d "$bk/ai/decisions" ]]; then
      missing_adr=0
      while IFS= read -r adr; do
        bn=$(basename "$adr")
        [[ -f "$TARGET/ai/decisions/$bn" ]] || { err "KNOWLEDGE_LOSS: ADR $bn present in backup, absent post-refresh"; missing_adr=$((missing_adr + 1)); }
      done < <(find "$bk/ai/decisions" -name '*.md' -not -name '_*' -not -name 'README*' 2>/dev/null)
      [[ $missing_adr -eq 0 ]] && ok "every backed-up ADR still present by ID"
    fi
  fi

  # --- per-file project-knowledge comparison (M36) -----------------------------
  # Runs off ALL recent backup dirs, not just the one C2a grades, because in
  # ENHANCE the only snapshot of a replaced file is the thin backup the replacing
  # script took itself.
  seen_rel=$(mktemp "${TMPDIR:-/tmp}/c2n-seen.XXXXXX")
  kn_checked=0; kn_lost=0
  while IFS= read -r bkdir; do
    bkdir="${bkdir%/}"   # `ls -1d .../*/` yields a trailing slash; without this the
                         # `${bf#"$bkdir"/}` strip never matches and every path is skipped.
    [[ -d "$bkdir" ]] || continue
    [[ -n "$(find "$bkdir" -maxdepth 0 -mmin -1440 2>/dev/null)" ]] || continue
    while IFS= read -r bf; do
      rel="${bf#"$bkdir"/}"
      # Only the surfaces the framework claims to preserve. Adapter projections
      # (.cursor/, .opencode/, …) are derived sinks — regenerating them is not loss.
      case "$rel" in
        ai/*|.claude/commands/*|.claude/agents/*|.claude/rules/*|.claude/skills/*|CLAUDE.md|AGENTS.md|CONVENTIONS.md) ;;
        *) continue ;;
      esac
      # Oldest backup wins: first sighting of a path is the pre-run state.
      grep -qxF "$rel" "$seen_rel" 2>/dev/null && continue
      printf '%s\n' "$rel" >> "$seen_rel"
      live="$TARGET/$rel"
      [[ -f "$live" ]] || continue   # whole-file deletion is caught by the census above
      kn_checked=$((kn_checked + 1))
      lost_paths=$(comm -23 <(know_tokens "$bf" "$KNOW_PATH_RE") <(know_tokens "$live" "$KNOW_PATH_RE") | grep -c . || true)
      lost_idents=$(comm -23 <(know_tokens "$bf" "$KNOW_IDENT_RE") <(know_tokens "$live" "$KNOW_IDENT_RE") | grep -c . || true)
      lost_paths="${lost_paths:-0}"; lost_idents="${lost_idents:-0}"
      # Same predicate study-existing.sh uses to protect a file from replacement:
      # ≥1 real project path, or ≥3 code identifiers.
      if [[ "$lost_paths" -ge 1 || "$lost_idents" -ge 3 ]]; then
        kn_lost=$((kn_lost + 1))
        err "KNOWLEDGE_LOSS: $rel lost $lost_paths project path(s) + $lost_idents identifier(s) present in ${bkdir#$TARGET/}. Generic pack text cannot regenerate them — restore from ${bkdir#$TARGET/}/$rel and merge the pack depth in instead of replacing."
      fi
      # An anchor that existed and no longer does means the project block was
      # overwritten wholesale, not merged.
      if grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$bf" 2>/dev/null \
         && ! grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$live" 2>/dev/null; then
        err "KNOWLEDGE_LOSS: $rel carried the project-specific anchor in ${bkdir#$TARGET/} and no longer does — the block was replaced, not merged."
      fi
    done < <(find "$bkdir" -type f -name '*.md' 2>/dev/null | sort)
  done < <(ls -1dtr "$CL/backups"/*/ 2>/dev/null || true)
  rm -f "$seen_rel"
  if [[ "$kn_checked" -eq 0 ]]; then
    ok "per-file project knowledge: no backed-up .md files to compare (nothing was overwritten this run)"
  elif [[ "$kn_lost" -eq 0 ]]; then
    ok "per-file project knowledge: $kn_checked backed-up file(s) compared, none lost project paths/identifiers"
  fi
  echo ""
fi

# C2b — required reports exist
echo "C2b: deterministic-coverage reports present"
for rpt in _pack-coverage-report.md _study-existing-report.md _codebase-scan.md; do
  if [[ -f "$CL/$rpt" ]]; then
    ok "$rpt"
  else
    err "$rpt missing — Phase 0.0 / Phase 4.0 didn't run"
  fi
done
if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
  if [[ -f "$CL/_refresh-extract.md" ]]; then
    ok "_refresh-extract.md (REFRESH/REFINE mode requires this)"
  else
    err "_refresh-extract.md missing — REFRESH/REFINE didn't run extract checklist"
  fi
fi

# Project-aware substrate check: in non-CREATE modes, Phase 2.5 should produce
# _extracted-idioms.md whenever the codebase has ≥1 base class with ≥3 extenders.
# Without it, AUTHOR-mode silently falls back to COPY-mode (generic templates with
# only the 5-facet anchor), and the system ships pack content that does not reflect
# this project's actual architecture. We can't deterministically tell whether the
# project HAS such base classes, so emit a WARN (not ERR) to surface the risk.
if [[ "$MODE" != "create" ]]; then
  if [[ -f "$CL/_extracted-idioms.md" ]]; then
    # Empty file or file with no `# <BaseName>` H1 sections = Phase 2.5 ran but
    # found no extenders — that's a valid outcome for true-greenfield code, but
    # the agent should have logged WHY. Just confirm the file exists.
    idioms_h1=$(grep -cE '^# ' "$CL/_extracted-idioms.md" 2>/dev/null || true)
    if [[ "${idioms_h1:-0}" -gt 0 ]]; then
      ok "_extracted-idioms.md (${idioms_h1} base class section(s) — AUTHOR-mode substrate present)"
    else
      warn_msg "_extracted-idioms.md exists but has 0 base-class sections — AUTHOR-mode will fall back to COPY (generic templates). Confirm Phase 2.5's '<3-extenders' rationale is logged in plan."
    fi
  else
    warn_msg "_extracted-idioms.md missing — Phase 2.5 (deep idiom extraction) was skipped. AUTHOR-mode tracks will fall back to COPY-mode (generic templates), so the generated setup will be less project-specific. If the codebase has any base class with ≥3 extenders, re-run with Phase 2.5 enabled."
  fi
fi
echo ""

# C2b — extract sections non-empty
if [[ -f "$CL/_refresh-extract.md" ]]; then
  echo "C2b1: refresh-extract sections filled"
  for section in "ADRs preserved" "Validated user corrections" "Project intent" "Custom rules" "Custom agents" "Architecture decisions" "Detected stack"; do
    # Find section header, then check next non-empty non-blockquote line for <TBD>
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_refresh-extract.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_refresh-extract.md § \"$section\" is still <TBD>"
    else
      ok "_refresh-extract.md § \"$section\" filled"
    fi
  done
  # Section 9 only required when migration in scope
  if grep -q "include=migration\|migration_layout_detected" "$TARGET"/.claude/codebase-profile.md 2>/dev/null; then
    if awk '/^## 9\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec && /^>/ { next } in_sec && /^[[:space:]]*$/ { next } in_sec { print; exit }' "$CL/_refresh-extract.md" | grep -q '<TBD>'; then
      err "_refresh-extract.md § 9 (migration mapping) is <TBD> but migration is in scope"
    fi
  fi
  echo ""
fi

# C2c — codebase-scan sections filled
if [[ -f "$CL/_codebase-scan.md" ]]; then
  echo "C2c: codebase-scan semantic sections filled"
  for section in "Module map" "Architecture pattern" "Conventions visible" "Patterns repeated" "Decisions implicit" "Drift between rules" "Stale references" "Recommended structural"; do
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_codebase-scan.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_codebase-scan.md § \"$section\" is <TBD>"
    else
      ok "_codebase-scan.md § \"$section\" filled"
    fi
  done

  # Section 15 must contain ≥3 structural recommendations
  recs=$(awk '
    /^## 15\./ { in_sec=1; next }
    in_sec && /^## / { exit }
    in_sec && /^- \*\*What\*\*:/ { count++ }
    END { print count + 0 }
  ' "$CL/_codebase-scan.md" 2>/dev/null || true)
  recs="${recs:-0}"

  # Compute LOC from section 5 to gate "non-trivial" check
  loc_total=0
  if grep -q '^## 5\.' "$CL/_codebase-scan.md" 2>/dev/null; then
    loc_total=$({ awk '/^## 5\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec' "$CL/_codebase-scan.md" 2>/dev/null || true; } \
      | { grep -oE '[0-9]+ lines' 2>/dev/null || true; } | { grep -oE '^[0-9]+' 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
    loc_total="${loc_total:-0}"
  fi

  if [[ "$loc_total" -ge 1000 && "$recs" -lt 3 ]]; then
    err "_codebase-scan.md § 15 has $recs structural recommendations; minimum 3 required (LOC=$loc_total)"
  elif [[ "$loc_total" -lt 1000 ]]; then
    ok "_codebase-scan.md § 15 has $recs recommendations (small codebase, threshold relaxed)"
  else
    ok "_codebase-scan.md § 15 has $recs structural recommendations"
  fi
  echo ""
fi

# Pack coverage — every "Missing" row should be addressed (now present in target)
if [[ -f "$CL/_pack-coverage-report.md" ]]; then
  echo "C2b2: pack coverage — Missing rows addressed"
  # Extract every "Missing" target path; check that each file now exists
  missing_unaddressed=0
  while IFS= read -r line; do
    # Lines look like: "- `<target-rel-path>` ← from `<src>`"
    target_rel=$(echo "$line" | sed -nE 's/^- `([^`]+)` ← from .*/\1/p')
    [[ -z "$target_rel" ]] && continue
    if [[ ! -f "$TARGET/$target_rel" ]]; then
      # Honor the curate-out ledger: a "Missing" row deliberately rejected / kept-ours
      # in _refresh-decisions.md is addressed-by-decision, not an unaddressed gap
      # (parity with C2k, which honors the study-decision ledger). Lean/curated refreshes
      # legitimately leave whole tracks uninstalled.
      #
      # The ledger is keyed by the PACK-relative path (`business/commands/x.md`), NOT the
      # deployed target path (`.claude/commands/x.md`). Deriving the pack key from the
      # coverage row's "← from `templates/packs/<pack>/<kind>/<base>`" src and matching
      # THAT is what actually reconciles a REJECTED/KEEP row — grepping only target_rel
      # never matches, so ledger-rejected tracks re-failed the audit forever (observed
      # 2026-07-09: the whole business pack, rejected 2026-06-20, re-flagged every refresh).
      pack_key=""
      src_path=$(echo "$line" | sed -nE 's/^- `[^`]+` ← from `([^`]+)`.*/\1/p')
      [[ -n "$src_path" ]] && pack_key="${src_path##*packs/}"
      if [[ -f "$CL/_refresh-decisions.md" ]] && \
         { grep -qF "$target_rel" "$CL/_refresh-decisions.md" || \
           { [[ -n "$pack_key" ]] && grep -qF "$pack_key" "$CL/_refresh-decisions.md"; }; }; then
        continue
      fi
      err "pack-coverage said missing → $target_rel still missing in target"
      missing_unaddressed=$((missing_unaddressed + 1))
    fi
  done < <(grep -E '^- `' "$CL/_pack-coverage-report.md" | grep '← from')
  [[ "$missing_unaddressed" -eq 0 ]] && ok "all 'Missing' rows addressed (or no missing rows)"
  echo ""
fi

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# C2k (M35) — study-decision reconciliation. Regenerates the study report against
# the CURRENT (post-apply) target state, then requires ZERO unreconciled actionable
# rows: each must have been APPLIED (state change reclassifies it) or RECORDED in
# .claude/_refresh-decisions.md (REJECTED / KEEP-OURS / RESOLVED / KEEP + rationale).
# This kills the observed drift "agent curated by judgment and skipped the audit" —
# curation is fine, but only through the ledger, and the audit still runs.
if [[ "$MODE" != "create" && -x "$SCRIPTS_DIR/study-existing.sh" ]]; then
  echo "C2k: study-decision reconciliation (M35)"
  # Scope to detected tracks (same signal source as preflight) — don't trust the
  # profile's track lines alone; they can be reverted/absent, and an unscoped run
  # falls back to ALL packs, inflating actionable counts with never-selected packs.
  c2k_packs=""
  if [[ -x "$SCRIPTS_DIR/detect-tracks.sh" ]]; then
    c2k_packs=$("$SCRIPTS_DIR/detect-tracks.sh" "$TARGET" --quiet 2>/dev/null | tr '\n' ' ' || true)
  fi
  # shellcheck disable=SC2086 — pack names are single safe words; word-splitting intended
  "$SCRIPTS_DIR/study-existing.sh" "$TARGET" $c2k_packs ${RO_STUDY_ARGS[@]+"${RO_STUDY_ARGS[@]}"} >/dev/null 2>&1 || true
  if [[ -f "$STUDY_REPORT" ]]; then
    act=$(grep -E '^Files with action needed: \*\*[0-9]+\*\*' "$STUDY_REPORT" | grep -oE '[0-9]+' | head -1 || true)
    reopened=$(grep -E '^Ledger entries re-opened' "$STUDY_REPORT" | grep -oE '[0-9]+' | head -1 || true)
    if [[ -z "$act" ]]; then
      warn_msg "could not parse actionable count from regenerated study report"
    elif [[ "$act" == "0" ]]; then
      ok "all actionable rows reconciled (applied or ledger-recorded)"
    else
      err "$act actionable row(s) unreconciled — APPLY them (apply-study-decisions.sh \"$TARGET\" --apply) OR RECORD the decision (--reject= / --keep-ours= / --resolve= per row). Silent skip is forbidden."
    fi
    if [[ -n "${reopened:-}" && "${reopened:-0}" != "0" ]]; then
      warn_msg "$reopened ledger entr(ies) re-opened — pack source changed since the recorded decision; re-audit those rows"
    fi
  else
    err "study report missing after regeneration — study-existing.sh failed; run it manually to see why"
  fi
  echo ""
fi

# C2l — a pack COMMAND rejected because "we already do this HERE under another name"
# (capability-overlap) must not silently delete the command surface: a user typing
# /<cmd> then gets "not found" with no pointer. This fires ONLY on the overlap family
# (rationale asserts an in-repo equivalent: "repo has" / "covered by" / "handled by" /
# "v1 has curated") — NOT on out-of-scope rejections ("not applicable to this SPA",
# "out of scope", "owned outside"), where the capability is correctly absent. The
# rejection is complete when a native same-named command exists OR the ledger line
# carries a `→ use /<equivalent>` breadcrumb. See setup-project.md M35 rule 4.
# Observed 2026-06-20 (a consumer project): /enhance-ui vanished with no breadcrumb and a
# review reported all-OK. Consolidated to one line — the detail lives in the ledger.
if [[ "$MODE" != "create" && -f "$CL/_refresh-decisions.md" ]]; then
  echo "C2l: rejected-command surface preservation"
  c2m_missing=""
  while IFS= read -r line; do
    # overlap family only — rationale claims the capability exists here under another name
    printf '%s' "$line" | grep -qiE 'repo has|covered by|handled by|v1 has curated' || continue
    key=$(printf '%s' "$line" | grep -oE '`[^`]+/commands/[^`]+\.md`' | head -1 | tr -d '`')
    [[ -z "$key" ]] && continue
    name=$(basename "$key" .md)
    [[ -f "$CL/commands/$name.md" ]] && continue                           # native replacement exists
    printf '%s' "$line" | grep -qE '→ use /' && continue                    # breadcrumb to equivalent
    c2m_missing+="${c2m_missing:+, }/$name"
  done < <(grep -E '/commands/.*→ REJECTED ' "$CL/_refresh-decisions.md" || true)
  if [[ -z "$c2m_missing" ]]; then
    ok "overlap-rejected commands all have a native replacement or breadcrumb"
  else
    n=$(printf '%s' "$c2m_missing" | tr ',' '\n' | grep -c .)
    warn_msg "$n command(s) rejected as 'covered here under another name' but a user typing them gets nothing — add a native router or a \`→ use /<equivalent>\` breadcrumb in _refresh-decisions.md (M35 rule 4): $c2m_missing"
  fi
  echo ""
fi

# C2s — a curated COMMAND kept over a richer pack counterpart (KEEP-OURS) must not
# silently HIDE missing standard safety gates. Conservative refresh preserves the
# bespoke body (correct — project-over-generic), but if the pack counterpart carries a
# substantive gate the curated one lacks, the user should be TOLD — not discover a
# capability-shallow command by accident weeks later. Same "no silent gap" principle as
# C2l (rejected commands), applied to kept ones. Warn-only: preserve stays the default;
# this just surfaces a deepen recommendation (the missing gates + `/setup-project
# --refine`). High-precision sampled token set (each names a real gate, never
# boilerplate) — not exhaustive, but enough to flag a shallow kept command. Observed
# 2026-06-20 (a consumer project): add-feature/fix-bug/review-changes kept but missing
# intent / prior-art / new-dependency / action-plan / coverage / secret-scan gates.
if [[ "$MODE" != "create" && -f "$CL/_refresh-decisions.md" ]]; then
  echo "C2s: kept-command capability gap (KEEP-OURS shallowness)"
  c2s_packs_root="$SCRIPTS_DIR/../templates/packs"
  c2s_report=""
  c2s_seen=" "
  # each line = `display::regex` — match the CAPABILITY (spelling-tolerant), not one
  # exact token, so a gate worded "coverage gap"/"coverage gate"/"covering test" is
  # recognised as present and not mis-flagged. Each regex still names a real gate, never
  # boilerplate. (Fixed-string matching here would cry wolf on legitimate synonyms.)
  c2s_gates=$'prior-art::prior[ -]?art\nnew-dependency::new[ -]?dependency\nintent gate::intent gate\n## What to do next::what to do next\nsibling-shape::sibling[ -]?shape\ncoverage-gap::coverage[ -]?gap|coverage gate|covering test\nsecret-scan::secret[ -]?scan\nchange-brief::change[ -]?brief\nmissing-agent::missing[ -]?agent|inline:<'
  # standard STRUCTURAL sections (`display::header-keyword-regex`). A kept command can
  # carry every gate above yet still be a 90-line stub missing the decompose / validate /
  # improve / failure-mode / output scaffold that makes the standard comprehensive — the
  # exact hole a gate-only check missed (observed 2026-06-21 on a consumer project: add-feature
  # had all gates but was 89 lines, 5 sections vs the standard's 14). We flag a kept
  # command as structurally shallow when it lacks >=3 standard sections its pack
  # counterpart has. Matched against header lines only, so prose mentions don't count.
  c2s_sections=$'Phase 2 / Organize::Phase 2|Organize|Decompose\nPhase 5 / Update::Phase 5|Update\nPhase 6 / Validate::Phase 6|Validate\nPhase 7 / Improve::Phase 7|Improve\nFailure modes::Failure modes\nOutput::Output\nInvariants::Invariants'
  while IFS= read -r line; do
    key=$(printf '%s' "$line" | grep -oE '`[^`]+/commands/[^`]+\.md`' | head -1 | tr -d '`')
    [[ -z "$key" ]] && continue
    name=$(basename "$key" .md)
    case "$c2s_seen" in *" $name "*) continue ;; esac           # dedupe (same cmd in >1 pack)
    cur="$CL/commands/$name.md"
    [[ -f "$cur" ]] || continue
    # all pack counterparts of this command (add-feature exists in several packs)
    packs=$(find "$c2s_packs_root" -path "*/commands/$name.md" 2>/dev/null)
    [[ -z "$packs" ]] && continue
    c2s_seen+="$name "
    # --- (1) gate check: substantive gates the pack has but the curated lacks ---
    missing=""
    while IFS= read -r gate; do
      [[ -z "$gate" ]] && continue
      disp="${gate%%::*}"; rx="${gate#*::}"
      pack_has=0
      while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if grep -qiE -- "$rx" "$p" 2>/dev/null; then pack_has=1; break; fi
      done <<< "$packs"
      [[ "$pack_has" -eq 1 ]] || continue
      grep -qiE -- "$rx" "$cur" 2>/dev/null && continue          # curated has it too → fine
      missing+="${missing:+, }$disp"
    done <<< "$c2s_gates"
    # --- (2) structural-depth check: standard SECTIONS the pack has but the curated lacks ---
    struct=""
    while IFS= read -r sec; do
      [[ -z "$sec" ]] && continue
      sdisp="${sec%%::*}"; srx="${sec#*::}"
      pack_has=0
      while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        grep -qiE -- "^#+[[:space:]].*($srx)" "$p" 2>/dev/null && { pack_has=1; break; }
      done <<< "$packs"
      [[ "$pack_has" -eq 1 ]] || continue
      grep -qiE -- "^#+[[:space:]].*($srx)" "$cur" 2>/dev/null && continue  # curated has the section → fine
      struct+="${struct:+, }$sdisp"
    done <<< "$c2s_sections"
    # only call it shallow when SEVERAL standard sections are absent (avoid one-off noise)
    [[ $(printf '%s' "$struct" | tr ',' '\n' | grep -c .) -lt 3 ]] && struct=""
    # corroborate with length: a complete-but-FLAT command (similar length, different
    # header names) is NOT thin — only flag structure when the curated is ALSO
    # substantially shorter than its pack counterpart (< ~55%). This spares dense audits
    # / differently-structured-but-complete commands, and keeps the flag on genuine stubs
    # (e.g. an 89-line build command vs the 402-line standard).
    if [[ -n "$struct" ]]; then
      pack_lines=0
      while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        pl=$(wc -l < "$p" 2>/dev/null || echo 0); (( pl > pack_lines )) && pack_lines=$pl
      done <<< "$packs"
      cur_lines=$(wc -l < "$cur" 2>/dev/null || echo 0)
      (( pack_lines > 0 && cur_lines * 100 >= pack_lines * 55 )) && struct=""
    fi
    # --- combine gate + structure findings into one report line ---
    rpt=""
    [[ -n "$missing" ]] && rpt="missing gates: $missing"
    [[ -n "$struct" ]] && rpt="${rpt:+$rpt; }thin structure — missing sections: $struct"
    [[ -n "$rpt" ]] && c2s_report+="    /$name — $rpt"$'\n'
  done < <(grep -E '/commands/.*→ KEEP' "$CL/_refresh-decisions.md" || true)
  if [[ -z "$c2s_report" ]]; then
    ok "kept commands carry the standard gates + section structure (no shallowness)"
  else
    n=$(printf '%s' "$c2s_report" | grep -c .)
    warn_msg "$n kept command(s) are shallower than the standard — missing safety gates and/or the full section structure (decompose / validate / improve / failure-modes / output) the pack version has. Preserving the bespoke version is fine, but deepen each to the standard's structure (keep its agents + anchor block intact):"$'\n'"$c2s_report"
  fi
  echo ""
fi

# C2h — Adapter sync coverage: when ≥1 adapter is enabled in target, every
# .claude/ source artifact must have its native counterpart in the adapter's
# folder (.opencode/, .cursor/, .github/, etc.). Reports ADD rows from
# apply-adapter-sync.sh. REFRESH/REFINE/ENHANCE require this.
if [[ -x "$SCRIPTS_DIR/apply-adapter-sync.sh" ]]; then
  echo "C2h: adapter-sync coverage (.claude/ → enabled adapters)"
  adapter_out=$("$SCRIPTS_DIR/apply-adapter-sync.sh" "$TARGET" 2>&1 || true)
  if echo "$adapter_out" | grep -q "No adapters enabled"; then
    ok "no adapters enabled — adapter-sync skipped"
  else
    add_count=$(echo "$adapter_out" | grep -cE '^    ADD ' || true)
    add_count=${add_count:-0}
    refresh_count=$(echo "$adapter_out" | grep -cE '^    REFRESH ' || true)
    refresh_count=${refresh_count:-0}
    missing_author=$(echo "$adapter_out" | grep -cE '^    MISSING-AUTHOR ' || true)
    missing_author=${missing_author:-0}
    if [[ "$add_count" -gt 0 || "$refresh_count" -gt 0 ]]; then
      if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
        err "$add_count adapter file(s) missing + $refresh_count drifted — run: ~/.claude/scripts/apply-adapter-sync.sh \"$TARGET\" --apply"
      else
        warn_msg "$add_count adapter file(s) missing (CREATE mode — first scaffold)"
      fi
    else
      ok "all 1:1 adapter-sync rows resolved"
    fi
    if [[ "$missing_author" -gt 0 ]]; then
      warn_msg "$missing_author adapter file(s) need LLM-authored format conversion — run: /setup-project-adapters"
    fi
  fi
  echo ""
fi

# C2g — Baseline coverage check: every file in repo-baseline/ must be present
# in target (ADD-rows from apply-baseline-sync.sh). REFRESH/REFINE/ENHANCE
# all require this; CREATE creates the baseline so the check is informational.
if [[ -x "$SCRIPTS_DIR/apply-baseline-sync.sh" ]]; then
  echo "C2g: repo-baseline coverage (ai/ + .claude/ scaffolds present)"
  baseline_out=$("$SCRIPTS_DIR/apply-baseline-sync.sh" "$TARGET" 2>&1 || true)
  add_count=$(echo "$baseline_out" | grep -cE '^  ADD ' || true)
  add_count=${add_count:-0}
  if [[ "$add_count" -gt 0 ]]; then
    if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
      err "$add_count baseline file(s) missing in target — run: ~/.claude/scripts/apply-baseline-sync.sh \"$TARGET\" --apply"
    else
      warn_msg "$add_count baseline file(s) missing in target (CREATE mode — first scaffold)"
    fi
    # Show first 5 missing files for context
    echo "$baseline_out" | grep -E '^  ADD ' | head -5 | sed 's/^/    /'
  else
    ok "all repo-baseline files present"
  fi
  echo ""
fi

# C2f — STALE_KNOWLEDGE check (REFRESH / REFINE / ENHANCE only).
# After Phase 4.4 / 4.4b / 4.7 / 4.7b regen the ai/ knowledge layer, the derived
# files (_session-digest, _convention-cheatsheet, _decision-index, business-domain,
# users-and-personas, architecture, conventions) MUST be at least as recent as
# the most recent pack-source change. If pack source mtime > ai/<derived>.md mtime,
# the agent silently skipped knowledge regeneration — this is the failure mode
# observed when a REFRESH only updates 5 ai/patterns/ files instead of the full
# knowledge layer. CREATE mode is exempt (greenfield: nothing to compare against).
if [[ "$MODE" != "create" ]]; then
  echo "C2f: ai/ knowledge layer freshness vs pack source"

  # Most recent mtime across pack sources we depend on (the Refract repo).
  # Resolve the templates dir via the symlink at ~/.claude/templates (or use
  # CLAUDE_CONFIG_ROOT if exported).
  PACKS_ROOT="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/packs"
  pack_newest=0
  if [[ -d "$PACKS_ROOT" ]]; then
    # find the newest .md file across pack sources (resolves symlinks via -L)
    while IFS= read -r f; do
      m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || true)
      [[ $m -gt $pack_newest ]] && pack_newest=$m
    done < <(find -L "$PACKS_ROOT" -type f -name '*.md' -not -name '_*' 2>/dev/null | head -2000)
  fi

  if [[ $pack_newest -eq 0 ]]; then
    warn_msg "pack source root not found at $PACKS_ROOT — skipping knowledge-freshness check"
  else
    # Files that REFRESH/REFINE must regenerate (relative to target)
    KNOWLEDGE_FILES=(
      "ai/_session-digest.md"
      "ai/_convention-cheatsheet.md"
      "ai/_decision-index.md"
      "ai/conventions.md"
      "ai/architecture.md"
      "ai/business-domain.md"
    )
    stale_count=0
    for rel in "${KNOWLEDGE_FILES[@]}"; do
      f="$TARGET/$rel"
      if [[ ! -f "$f" ]]; then
        if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
          err "knowledge file missing: $rel — Phase 4.4/4.7 should have written it"
          stale_count=$((stale_count + 1))
        fi
        continue
      fi
      file_mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || true)
      if [[ $file_mtime -lt $pack_newest ]]; then
        # Format both timestamps for the message
        pack_iso=$(date -r "$pack_newest" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "@$pack_newest" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?")
        file_iso=$(date -r "$file_mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "@$file_mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?")
        if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
          err "STALE_KNOWLEDGE: $rel ($file_iso) older than newest pack source ($pack_iso) — Phase 4.4/4.4b/4.7/4.7b silently skipped"
        else
          warn_msg "STALE_KNOWLEDGE: $rel ($file_iso) older than newest pack source ($pack_iso) — consider /setup-project --refresh"
        fi
        stale_count=$((stale_count + 1))
      fi
    done
    [[ $stale_count -eq 0 ]] && ok "ai/ knowledge layer up-to-date vs pack source"
  fi
  echo ""
fi

# C2i — Foundational ai/ populate gate (EVERY mode). The baseline scaffold copies
# stub templates into ai/; ENHANCE/REFRESH historically left them untouched (could
# not tell a freshly-copied stub from real user content), shipping placeholder
# conventions.md / stack.md / modules.md green. C2g (presence) + C2f (mtime
# freshness) BOTH pass on a fresh stub, so neither caught it. This check fails when
# a foundational file is byte-identical to its repo-baseline source OR still carries
# baseline placeholder tokens. Spec: templates/phases/phase-5-verify.md §5.3.6.
echo "C2i: foundational ai/ files populated (not baseline stubs)"
# --lightweight (#25) deliberately skips Phase 4.7 ai/ population (~80% faster, trivial pack
# additions / status checks), so an unpopulated stub is EXPECTED, not a failure. Downgrade C2i
# to a warn under --lightweight rather than REFUSE the run. Full runs keep the hard gate.
C2I_REPORT() { if [[ $LIGHTWEIGHT -eq 1 ]]; then warn_msg "$*"; else err "$*"; fi; }
BASELINE_AI="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/repo-baseline/ai"
FOUNDATIONAL=( architecture stack modules status conventions business-domain _convention-cheatsheet )
# Tokens UNIQUE to unpopulated baseline stubs. NB: bare `<name>` is excluded — it is a
# legitimate code/path placeholder in populated docs (`get_logger(<name>)`, `app/modules/<name>/`)
# and would false-positive. The diff-identical check + these stub-only tokens still catch real stubs.
STUB_TOKENS='<src/path|<e\.g\.,|<YYYY-MM-DD>|<detected|<EntityA>|<DetectedBase>|<NNNN>|<term>|<one-line'
stub_count=0
for fname in "${FOUNDATIONAL[@]}"; do
  tgt="$TARGET/ai/$fname.md"
  if [[ ! -f "$tgt" ]]; then
    C2I_REPORT "foundational ai/ file missing: ai/$fname.md"
    stub_count=$((stub_count + 1)); continue
  fi
  base="$BASELINE_AI/$fname.md"
  if [[ -f "$base" ]] && diff -q "$base" "$tgt" >/dev/null 2>&1; then
    C2I_REPORT "UNPOPULATED_STUB: ai/$fname.md is byte-identical to repo-baseline stub — Phase 4.7 never populated it (run /setup-project --refresh)"
    stub_count=$((stub_count + 1)); continue
  fi
  if grep -qE "$STUB_TOKENS" "$tgt" 2>/dev/null; then
    C2I_REPORT "UNPOPULATED_STUB: ai/$fname.md still carries baseline placeholder tokens — population incomplete"
    stub_count=$((stub_count + 1))
  fi
done
[[ $stub_count -eq 0 ]] && ok "all foundational ai/ files populated"
echo ""

# C2j — App-code stub scan (#46). The "no placeholders" promise was enforced only on the 7
# foundational ai/ docs (C2i), not on generated app code — so a scaffolded route handler left as
# `throw new Error('not implemented')` shipped green. This scans the target's SOURCE for
# high-signal stub markers. WARN-level only (not REFUSE): some markers are legitimate work-in-
# progress; the signal is "you scaffolded a surface and left it hollow." Skips deps + this script's
# own kind (libraries legitimately raise NotImplementedError in abstract bases).
echo "C2j: app-code stub scan (generated surfaces not left hollow)"
STUB_MARKERS='throw new Error\(["'"'"']?[Nn]ot implemented|raise NotImplementedError|TODO:?[[:space:]]*implement\b|coming soon|FIXME:?[[:space:]]*stub|placeholder implementation'
app_stubs=$(grep -rInE "$STUB_MARKERS" "$TARGET" \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.vue' \
  --include='*.py' --include='*.go' --include='*.rb' --include='*.java' --include='*.kt' \
  2>/dev/null | grep -vE '/(node_modules|dist|build|\.git|vendor|tests?|__tests__|spec|\.output|\.nuxt|\.next|\.svelte-kit|\.cache|out|coverage|generated|__generated__|\.prisma|prisma|migrations|\.gen)/' | grep -vE '\.(min|bundle|gen)\.(js|ts)$' | head -20 || true)
if [[ -n "$app_stubs" ]]; then
  n=$(printf '%s\n' "$app_stubs" | grep -c . )
  warn_msg "app-code stub markers found ($n shown, ≤20) — a scaffolded surface may be hollow. Review:"
  printf '%s\n' "$app_stubs" | sed 's#^#      #' | head -8
else
  ok "no app-code stub markers in source"
fi
echo ""

# Anchoring audit (M25.4): per-artifact coverage of the canonical
# `<!-- project-specific:start --> ... :end -->` block + `path:line` citations.
# REFUSE when anchors are missing in REFRESH / REFINE / ENHANCE modes (Phase 4.6
# was supposed to inject them via apply-anchors.sh). CREATE mode warns only —
# the agent may still be mid-flow when this runs and the profile may not exist.
# (SCRIPTS_DIR set earlier at C2g block)
if [[ -x "$SCRIPTS_DIR/audit-anchoring.sh" ]]; then
  echo "C2d: artifact anchoring"
  "$SCRIPTS_DIR/audit-anchoring.sh" "$TARGET" --quiet ${RO_ANCHOR_ARGS[@]+"${RO_ANCHOR_ARGS[@]}"} >/dev/null 2>&1 || true
  if [[ -f "$ANCHOR_REPORT" ]]; then
    pct=$(grep -E '^Coverage: \*\*' "$ANCHOR_REPORT" 2>/dev/null \
          | grep -oE '[0-9]+' | head -1 || true)
    unanchored=$(grep -E '^Unanchored:' "$ANCHOR_REPORT" 2>/dev/null \
                 | grep -oE '[0-9]+$' | head -1 || true)
    leaks=$(grep -E '^Cross-project leaks:' "$ANCHOR_REPORT" 2>/dev/null \
            | grep -oE '[0-9]+$' | head -1 || true)
    leaks="${leaks:-0}"
    # Cross-project leak is always a hard failure in non-CREATE modes — an artifact
    # citing another project's identifiers ships wrong guidance regardless of coverage.
    if [[ "$leaks" -gt 0 ]]; then
      if [[ "$MODE" == "create" ]]; then
        warn_msg "anchoring: $leaks cross-project leak(s) — anchor cites facts absent from target (CREATE mode; verify before chaining adapters)"
      else
        err "anchoring: $leaks cross-project leak(s) — generated artifact cites identifiers/paths NOT in the target codebase. See $ANCHOR_REPORT § Cross-project leaks; re-run apply-anchors.sh \"$TARGET\" --apply"
      fi
    fi
    # When audit-anchoring.sh detects 0 pack-derived files, no `Coverage:` line is
    # emitted (audit-anchoring.sh:180-183 only writes it when total_eligible > 0).
    # Treat that case as a pass: every eligible artifact is anchored when there
    # are zero eligible artifacts.
    if [[ -z "$pct" ]] && grep -qE '^Pack-derived artifacts:[[:space:]]+\*\*0\*\*' "$ANCHOR_REPORT" 2>/dev/null; then
      ok "anchoring coverage n/a — 0 pack-derived artifacts (all are project-specific orphans)"
    fi
    if [[ -n "$pct" ]]; then
      if [[ "$unanchored" == "0" ]]; then
        ok "anchoring coverage ${pct}% — every pack-derived artifact carries an anchor block"
      elif [[ "$MODE" == "create" ]]; then
        warn_msg "anchoring coverage ${pct}% — ${unanchored} unanchored (CREATE mode; Phase 4.6 may not have run yet — re-run apply-anchors.sh)"
      else
        err "anchoring coverage ${pct}% — ${unanchored} pack-derived artifact(s) lack project anchors. Phase 4.6 must run: ~/.claude/scripts/apply-anchors.sh \"$TARGET\" --apply"
      fi
    fi
  fi
  echo ""
fi

# C2m (M34) — adapter-chain HALT. Promoted from WARN to ERR: in
# refresh/refine/enhance/create with adapters enabled and --no-adapters NOT
# passed, a skipped /setup-project-adapters chain FAILS the audit. Previously the
# only adapter signal was C2e's warn-only "no adapter native files" line, so the
# mandatory M34 chain could be silently skipped and the run still reported success.
# Sanctioned skips: --no-adapters flag, claude_config.adapters:false, or zero
# adapters enabled (only claude-code — nothing to translate).
if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" || "$MODE" == "create" ]]; then
  echo "C2m: adapter chain executed (M34)"
  if [[ $NO_ADAPTERS -eq 1 ]]; then
    ok "--no-adapters passed — M34 chain sanctioned-skip"
  elif grep -qE '"adapters"[[:space:]]*:[[:space:]]*false' "$CL/settings.json" 2>/dev/null; then
    ok "claude_config.adapters:false in settings.json — M34 chain sanctioned-skip"
  else
    # An adapter is "enabled" when its native folder/config exists (same signatures
    # as apply-adapter-sync.sh detect_adapters). ZERO enabled = nothing to translate.
    adapters_enabled=0
    [[ -d "$TARGET/.opencode" ]] && adapters_enabled=1
    { [[ -d "$TARGET/.cursor" ]] || [[ -f "$TARGET/.cursorrules" ]]; } && adapters_enabled=1
    { [[ -d "$TARGET/.github/agents" ]] || [[ -d "$TARGET/.github/prompts" ]] || [[ -f "$TARGET/.github/copilot-instructions.md" ]]; } && adapters_enabled=1
    [[ -d "$TARGET/.clinerules" ]] && adapters_enabled=1
    [[ -d "$TARGET/.windsurf" ]] && adapters_enabled=1
    [[ -d "$TARGET/.continue" ]] && adapters_enabled=1
    { [[ -f "$TARGET/.aider.conf.yml" ]] || [[ -f "$TARGET/.aiderignore" ]]; } && adapters_enabled=1
    { [[ -d "$TARGET/.agents/skills" ]] || [[ -f "$TARGET/AGENTS.override.md" ]]; } && adapters_enabled=1
    [[ -f "$TARGET/GEMINI.md" ]] && adapters_enabled=1
    [[ -d "$TARGET/.kimi" ]] && adapters_enabled=1
    [[ -d "$TARGET/.qwen" ]] && adapters_enabled=1
    if [[ $adapters_enabled -eq 0 ]]; then
      ok "zero adapters enabled (claude-code only) — nothing to translate"
    else
      # Adapters enabled + no sanctioned skip → the chain MUST have produced native
      # files. apply-adapter-sync.sh reports ADD/REFRESH rows if the chain is stale
      # or never ran; C2h already runs it. Reuse that signal: any pending ADD means
      # the chain was skipped/incomplete.
      chain_out=$("$SCRIPTS_DIR/apply-adapter-sync.sh" "$TARGET" 2>&1 || true)
      pending=$(echo "$chain_out" | grep -cE '^    (ADD|REFRESH|MISSING-AUTHOR) ' || true)
      pending=${pending:-0}
      if [[ "$pending" -gt 0 ]]; then
        err "M34 adapter chain skipped or incomplete — $pending native artifact(s) pending with adapters enabled and --no-adapters not passed. Chain it: /setup-project-adapters (or pass --no-adapters to skip)"
      else
        ok "adapter chain in sync — native artifacts present for enabled adapters"
      fi
    fi
  fi
  echo ""
fi

# Adapter coverage audit (M34b): warn-only — verifies that adapter native files
# are in sync with .claude/ source artifacts. If no adapters were translated yet
# (zero native folders), this is informational; a passing C2d (anchoring) plus
# zero adapter native files = "user hasn't run /setup-project-adapters yet."
if [[ -x "$SCRIPTS_DIR/audit-adapter-coverage.sh" ]]; then
  echo "C2e: adapter translation coverage (M34b warn-only)"
  # Do NOT swallow the exit code. A dead chain that leaves a STALE report on disk
  # previously reported "all adapters in sync" while audit-adapter-coverage.sh was
  # exiting 1 on every run (measured: a missing ~/.claude/scripts/_adapter-emit.sh
  # symlink took the whole M34 chain down and C2e still printed a pass).
  if "$SCRIPTS_DIR/audit-adapter-coverage.sh" "$TARGET" ${RO_ADAPTER_ARGS[@]+"${RO_ADAPTER_ARGS[@]}"} >/dev/null 2>&1; then
    _adapter_audit_ran=1
  else
    _adapter_audit_ran=0
    warn "C2e: audit-adapter-coverage.sh exited non-zero — coverage numbers below are STALE or absent, not verified"
  fi
  if [[ "$_adapter_audit_ran" -eq 1 && -f "$ADAPTER_REPORT" ]]; then
    # Extract pass/warn/fail counts from the table
    # Use awk — always exits 0 and prints a number, no grep -c "1 on no match" trap.
    err_n=$(awk '/^\| ❌/  {n++} END {print n+0}' "$ADAPTER_REPORT" 2>/dev/null || true)
    warn_n=$(awk '/^\| ⚠/ {n++} END {print n+0}' "$ADAPTER_REPORT" 2>/dev/null || true)
    ok_n=$(awk  '/^\| ✅/ {n++} END {print n+0}' "$ADAPTER_REPORT" 2>/dev/null || true)
    err_n="${err_n:-0}"; warn_n="${warn_n:-0}"; ok_n="${ok_n:-0}"
    if [[ "$ok_n" == "0" && "$warn_n" == "0" && "$err_n" == "0" ]]; then
      warn_msg "no adapter native files detected — run /setup-project-adapters to translate .claude/ to Cursor/OpenCode/etc native shapes"
    elif [[ "$err_n" -gt 0 ]]; then
      warn_msg "adapter coverage: $err_n adapter(s) below 80%; $warn_n warn; $ok_n ok — re-run /setup-project-adapters to refresh"
    elif [[ "$warn_n" -gt 0 ]]; then
      warn_msg "adapter coverage: $warn_n adapter(s) at 80-94%; $ok_n ok — minor drift, /setup-project-adapters to fully sync"
    else
      ok "adapter coverage: $ok_n adapter(s) at ≥95% — all in sync with .claude/"
    fi
  fi
  echo ""
fi

# Stack-agnostic template lint — scans this repo's `commands/` + `templates/**` (not TARGET).
# Ensures universal docs never pin a single stack without multi-stack diversity / `<TBD:...>`.
PACK_TEMPLATE_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
if [[ -x "$SCRIPTS_DIR/audit-stack-leakage.sh" ]]; then
  echo "C2p: stack-agnostic language (template pack source)"
  if leakage_out=$("$SCRIPTS_DIR/audit-stack-leakage.sh" --repo-root="$PACK_TEMPLATE_ROOT" 2>&1); then
    ok "stack leakage audit clean ($PACK_TEMPLATE_ROOT)"
  else
    echo "$leakage_out" >&2
    err "audit-stack-leakage.sh failed — fix universal docs or placeholders in Refract"
  fi
  echo ""
fi

# Command DRY — SOLID/clean-code pointers + Phase 3 snippet links (template pack source).
if [[ -x "$SCRIPTS_DIR/audit-command-dry.sh" ]]; then
  echo "C2q: command DRY (SOLID/clean-code + Phase 3 snippets)"
  if dry_out=$("$SCRIPTS_DIR/audit-command-dry.sh" 2>&1); then
    echo "$dry_out"
    ok "audit-command-dry.sh clean"
  else
    echo "$dry_out" >&2
    err "audit-command-dry.sh failed — link core-discipline.md / phase-3-always-reads.md or remove duplicated prose"
  fi
  echo ""
fi

# Refactor artifact validator — smoke test (template pack source scripts/)
if [[ -x "$SCRIPTS_DIR/validate-refactor-artifacts.sh" ]]; then
  echo "C2r: validate-refactor-artifacts.sh --self-test"
  if refactor_self=$("$SCRIPTS_DIR/validate-refactor-artifacts.sh" --self-test 2>&1); then
    echo "$refactor_self"
    ok "validate-refactor-artifacts.sh --self-test passed"
  else
    echo "$refactor_self" >&2
    err "validate-refactor-artifacts.sh --self-test failed"
  fi
  echo ""
fi

# C2t — deployed snippet/governance link integrity (TARGET artifacts). Commands/agents
# adopted from packs reference `](../../../snippets|governance/...)` (valid under
# templates/packs/.../commands/); on deploy to .claude/{commands,agents,skills,rules}/ they
# MUST be rewritten to `](../templates/snippets|governance/...)` (apply-study-decisions'
# rewrite_deployed_command_links). A deployed file still carrying the `../../../` form has a
# BROKEN relative link (resolves outside the repo). Historically these shipped silently —
# a re-audit found 30 such files that had persisted for a month because no check caught them.
# WARN-level: the artifact still works; only its doc pointer is dead — one-line rewrite fixes it.
echo "C2t: deployed snippet/governance link integrity (.claude/ artifacts)"
broken_links=$(grep -rlE '\]\(\.\./\.\./\.\./(snippets|governance)/' \
  "$CL/commands" "$CL/agents" "$CL/skills" "$CL/rules" 2>/dev/null || true)
if [[ -n "$broken_links" ]]; then
  bl_n=$(printf '%s\n' "$broken_links" | grep -c .)
  warn_msg "$bl_n .claude/ artifact(s) carry broken \`../../../{snippets,governance}/\` links (should be \`../templates/...\`). Fix: perl -i -pe 's{\]\(\.\./\.\./\.\./(snippets|governance)/}{](../templates/\$1/}g' <files>"
  printf '%s\n' "$broken_links" | sed "s#^$TARGET/#      #" | head -8
else
  ok "no broken snippet/governance links in deployed artifacts"
fi
echo ""

# Summary
echo "=== summary ==="
echo "fail: $fail"
echo "warn: $warn"

if [[ "$fail" -gt 0 ]]; then
  echo ""
  echo "REFUSED — $fail mandatory check(s) failed."
  echo "The agent MUST NOT declare 'no work to do' / 'idempotent' / 'success' until these are addressed."
  exit 1
fi

echo ""
echo "PASS — Phase 5 audit clean. Safe to report success."
exit 0
