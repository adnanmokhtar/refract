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

# 🔴 AN AUDIT THAT DIES MID-RUN MUST SAY SO. IT USED TO JUST STOP.
#
# `set -euo pipefail` turns any unhandled non-zero — an unset variable, a failed command
# outside a conditional — into an immediate exit with NO message beyond bash's own one-liner
# on stderr, and every check after that point simply never runs. There is no summary, no
# failure count, and nothing in the output that distinguishes "the audit finished and found
# these things" from "the audit stopped a third of the way through".
#
# 📏 That is not hypothetical. On Linux, `stat -f %m` succeeded with a filesystem report
# instead of an mtime (see _mtime below), bash read `File` as a variable in an arithmetic
# test, and this script died at C2f — before C2u, C2y, C2j and C2t. Diagnosing it needed a
# raw CI log and reasoning backwards from which assertions had passed. Every Linux user had
# been getting a truncated audit and the output never once said so.
#
# The trap costs nothing on a clean run and turns the next occurrence into a line number.
# `>&2` and the ABORTED banner are deliberate: the callers that scrape this output look for
# section headers, so a silent stop reads as a section that produced no findings.
# EXIT, NOT ERR. `set -u` does not go through the ERR trap — bash prints its one-line
# "unbound variable" and exits the shell directly, so an ERR trap here caught nothing, which
# is the exact failure being guarded against. Verified by injecting `[[ $NoSuchVar -gt 0 ]]`
# before C2u: with `trap ... ERR` the banner never printed.
#
# So the audit declares completion explicitly and the EXIT trap reports its absence. That
# covers every abnormal end — set -u, set -e, a killed subshell — with one mechanism.
_AUDIT_COMPLETED=0
_audit_exit_report() {
  local rc=$?
  [[ "$_AUDIT_COMPLETED" -eq 1 ]] && return 0
  echo "" >&2
  echo "=== AUDIT ABORTED — this run did NOT complete ===" >&2
  echo "    exited $rc before reaching the summary." >&2
  echo "    Every check after that point did not run. Treat the output above as PARTIAL:" >&2
  echo "    a missing section means 'never executed', NOT 'nothing to report'." >&2
  # 🔴 NEVER EXIT 0 FROM HERE. Measured on the injected-abort fixture: without this the
  # process exited **0** — the trap's own last command masked the status — so a run that
  # stopped at C2f, having executed 6 of 19 sections, reported SUCCESS to its caller. That
  # is the fail-open shape this file already carries a long note about at C2n, arriving by
  # a different road. A partial audit is a failed audit.
  exit $(( rc == 0 ? 1 : rc ))
}
trap _audit_exit_report EXIT

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo, so an unresolved
# BASH_SOURCE puts this dir at ~/.claude/scripts and every sibling asset below resolves only
# if it too was linked (see CONTRIBUTING § "Scripts run from two places").
# Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPTS_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
# EVERY remediation this audit prints is rooted at $SCRIPTS_DIR, never at a literal
# `~/.claude/scripts/`. MEASURED: C2u failed a live run for an inert rules layer and told the
# user to run `~/.claude/scripts/wire-rule-imports.sh … --apply`. That file was one of seven
# committed at HEAD and never linked into the global install, so the audit correctly identified
# a mandatory failure and then handed the reader "No such file or directory". An audit that
# prescribes a command the reader cannot run has not reported a defect, it has added one.
# Gate: lint-setup-contracts.sh Rule 13.
#
# And the same reasoning applies to the framework's DATA, not just its scripts. Anything under
# templates/ must be looked for in the CHECKOUT first and only then at the global-install path.
# `${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/...` alone is the exact shape that made the
# merge engine unreachable: correct when the install happens to be current, silently degrading
# when it is not — and C2i, C2n and C2s all degrade QUIETLY when their corpus is missing, which
# is the worst way for a mandatory check to fail. Checkout first, global second, and say which.
framework_path() {   # $1 = path under the framework root, e.g. templates/repo-baseline/ai
  local rel="$1" c
  for c in "$SCRIPTS_DIR/../$rel" "${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/$rel"; do
    [ -e "$c" ] && { printf '%s' "$c"; return 0; }
  done
  printf '%s' "${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/$rel"
  return 1
}

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
    err "no backup created in the last 24h — run-preflight.sh (M35 Phase 0 backup) did not run; re-run: $SCRIPTS_DIR/run-preflight.sh \"$TARGET\" --mode=$MODE_LABEL"
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

# Does a project-knowledge path token resolve to a real file in the target?
#
# HISTORY — C2n's loss detector below was a pure `comm -23` set difference over path-shaped
# tokens with NO resolvability test, and that made it mutually unsatisfiable with C2k. C2k
# REFUSES the run until every MERGE row is applied; a MERGE row whose pack content CORRECTS a
# broken path reference then deletes a token, and C2n scored that deletion as destroyed
# project knowledge. Measured on a live repo: 2 of the first 5 mandated merges collided, a
# 40% rate, and the run could not be made to pass by doing the work it was refused for.
#
# The distinguishing fact is on disk. Deleting a reference to a path that DOES NOT EXIST is a
# repair; deleting a reference to a path that DOES exist is a loss. This function is that
# test, and it is why C2n keeps catching the real case (a merge that rewrote a live
# `skills/alert-audit.md` into an absent `skills/alert-audit/SKILL.md` is still an ERR) while
# no longer refusing the repair case.
#
# Resolution is tried at the target root and under `.claude/`, because pack cross-references
# are written relative to `.claude/` (`skills/<name>/SKILL.md`, `commands/<name>.md`).
know_token_resolves() {
  local tok="$1"
  [[ -e "$TARGET/$tok" ]] && return 0
  [[ -e "$TARGET/.claude/$tok" ]] && return 0
  # Skill-shape tolerance: the same skill may be installed flat or folder-form, and a
  # reference to either form resolves if the OTHER form is what is on disk. Without this the
  # gate would treat a legitimate shape difference as a dangling reference.
  case "$tok" in
    */SKILL.md)  local d="${tok%/SKILL.md}"
                 [[ -e "$TARGET/$d.md" || -e "$TARGET/.claude/$d.md" ]] && return 0 ;;
    *.md)        local b="${tok%.md}"
                 [[ -e "$TARGET/$b/SKILL.md" || -e "$TARGET/.claude/$b/SKILL.md" ]] && return 0 ;;
  esac
  return 1
}

# --- M42: the SECOND condition. "Resolves on disk" is necessary and NOT sufficient. ---------
#
# HISTORY. The resolve test above fixed the first half of C2n's mutual unsatisfiability with
# C2k: a merge that deletes a reference to a path that does not exist is a repair, not a loss.
# The half it did not fix is the mirror image, and it was measured on a 20-row hand-labelled
# panel while building scripts/merge-decide.py: a rule of exactly this shape fired on
# `ai/patterns/api-contract.md`, `ai/patterns/error-handling.md` and `ai/conventions.md` —
# paths that resolve ONLY BECAUSE THE FRAMEWORK INSTALLED THEM. 2 false positives out of 20,
# both of them "you destroyed project knowledge" on a file whose entire loss was generic pack
# prose plus a cross-reference list. The fix, validated to 20/20 on that panel, is to require
# BOTH conditions:
#
#     it resolves on disk   AND   the packs do not ship it
#
# The same asymmetry applies to identifiers, where C2n had no condition at all — a pure set
# difference. Any merge that rewords prose drops CamelCase and snake_case words, and three of
# them is the firing threshold. So an identifier must also be one the PROJECT actually uses:
# present somewhere in the target's own source, and absent from the packs.
#
# BOTH indexes are built LAZILY and at most once per run, and both fail SAFE: if the pack
# corpus cannot be read the filter removes nothing (C2n stays as noisy as it was), and if the
# project source index cannot be built the identifier test reverts to the unconditional form.
# A gate that goes quiet when its inputs are missing is worse than one that cries wolf.
# M43 — C2n prefers the LINE-level provenance test the merge engine gates its own writes on,
# and falls back to the token test below when python3 or the engine is unreachable.
C2N_ENGINE=""
C2N_PAIRS=""
C2N_LINE_MODE=0
C2N_PACK_IDX=""      # sorted file: every path/ident token the PACKS ship
C2N_REPO_IDX=""      # sorted file: every ident token the PROJECT'S OWN SOURCE uses
C2N_IDX_READY=0
C2N_IDX_NOTE=""

# c2n_token_pair rel backup live label — the TOKEN test for one (backup, live) pair.
#
# Extracted so it has TWO callers, and the second one is the reason it exists: when the
# line-level engine call FAILS, C2n falls back to this instead of going quiet. Noisier than
# the line test, never quieter. Only removed paths that STILL RESOLVE on disk count as loss
# (see know_token_resolves), and an identifier counts only when the PROJECT uses it and the
# PACKS do not ship it (M42's two conditions).
c2n_token_pair() {
  local rel="$1" bf="$2" live="$3" label="$4"
  local lost_paths lost_idents
  lost_paths=$(count_resolvable_lost_paths "$bf" "$live")
  # A repo index that could not be built reverts to the unconditional form rather than going
  # quiet — the direction a safety gate is allowed to err in.
  if [[ -s "$C2N_REPO_IDX" ]]; then
    lost_idents=$(comm -12 \
        <(comm -23 <(comm -23 <(know_tokens "$bf" "$KNOW_IDENT_RE") <(know_tokens "$live" "$KNOW_IDENT_RE")) \
                   <(c2n_pack_stream)) \
        "$C2N_REPO_IDX" | grep -c . || true)
  else
    lost_idents=$(comm -23 <(know_tokens "$bf" "$KNOW_IDENT_RE") <(know_tokens "$live" "$KNOW_IDENT_RE") | grep -c . || true)
  fi
  lost_paths="${lost_paths:-0}"; lost_idents="${lost_idents:-0}"
  # Same predicate study-existing.sh uses to protect a file from replacement:
  # ≥1 real project path, or ≥3 code identifiers.
  if [[ "$lost_paths" -ge 1 || "$lost_idents" -ge 3 ]]; then
    kn_lost=$((kn_lost + 1))
    err "KNOWLEDGE_LOSS: $rel lost $lost_paths project path(s) + $lost_idents identifier(s) present in $label. Each one RESOLVES in this project and is absent from the packs (M42 two-condition test), so generic pack text cannot regenerate it — restore from $label/$rel and merge the pack depth in instead of replacing."
  fi
}

# c2n_twin_archived rel backup — is this file's old content preserved verbatim elsewhere?
#
# `--resolve-shape-conflicts` resolves a both-shapes-on-disk skill by keeping whichever twin
# carries more PROJECT KNOWLEDGE and archiving the other byte-for-byte under
# `.claude/backups/skill-shape-*/resolved-twins/<name>.{flat,folder}.md`. To C2n the winning
# path then looks like a file that lost 13 lines, because the pre-run backup holds the loser's
# text — measured on tenant-portal, that is exactly 2 of the ERRs a clean run produced.
#
# This is NOT a suppression rule. It fires only when the archived copy is byte-identical to the
# pre-run backup, i.e. only when the bytes provably still exist at a named path. Anything less
# than byte-identical falls through to the loss test.
c2n_twin_archived() {
  local rel="$1" bf="$2" name a
  case "$rel" in
    .claude/skills/*/SKILL.md) name="${rel#.claude/skills/}"; name="${name%/SKILL.md}" ;;
    .claude/skills/*.md)       name="${rel#.claude/skills/}"; name="${name%.md}" ;;
    *) return 1 ;;
  esac
  for a in "$CL"/backups/skill-shape-*/resolved-twins/"$name".flat.md \
           "$CL"/backups/skill-shape-*/resolved-twins/"$name".folder.md; do
    [[ -f "$a" ]] || continue
    cmp -s "$a" "$bf" && { C2N_ARCHIVE_AT="${a#$TARGET/}"; return 0; }
  done
  return 1
}

# MUST be called directly, never inside `$( )`. A function that caches into a global and is
# invoked through a command substitution caches into a SUBSHELL, so the cache is discarded on
# every call and the index is rebuilt per token. That is not hypothetical — the first version
# of this did exactly that and turned a 3-second audit into one that had not finished in two
# minutes. apply-study-decisions.sh carries the same warning on resolve_variant_path.
# 🔴 THIS RUN'S BACKUPS ONLY — not "every backup dir that still exists".
#
# C2n reads backups oldest-first and takes the FIRST sighting of a path as its
# pre-run state. That is right within one run, and badly wrong across runs: a
# backup from a PREVIOUS run then supplies the baseline, so every legitimate
# change made since gets reported as knowledge the refresh destroyed.
#
# 📏 Measured on capsolah-api after a third setup in three days: 15 backup dirs
# spanning 2026-08-22 to 08-24, and the audit reported **227 KNOWLEDGE_LOSS
# errors**, every one of them reading `lost 0 line(s), 0 project token(s) and
# 1 project-specific region(s)`. Diffed by hand, the regions were BYTE-IDENTICAL
# to the committed file — 16 lines before, 16 lines after, empty diff. Zero real
# losses, 227 alarms, on a project where nothing was wrong.
#
# That is worse than not checking. A gate that cries wolf on a correct run
# teaches its reader to scroll past it, and the one true ERR in the next run
# scrolls past with them. `--refresh` is DOCUMENTED as a repeatable command, so
# this fired for anyone using the tool the way we tell them to.
#
# Every run opens with a Phase-0 backup named as a BARE timestamp
# (`YYYYMMDD-HHMMSS`, or `YYYYMMDD-HHMM` from older installs); every later
# backup that run takes is `<script>-<stamp>`
# with a later stamp. So the newest bare-timestamp dir is this run's floor, and
# a dir at or after it belongs to this run. No new state to write and nothing to
# keep in sync — the naming convention already carried the answer.
#
# No floor found (a project whose Phase-0 backup was pruned) falls back to the
# old every-dir behaviour: over-reporting beats silently checking nothing.
c2n_run_backups() {
  # `|| true` is load-bearing under `set -euo pipefail`: grep exits 1 when a project
  # has no bare-timestamp backup, pipefail promotes that to the substitution, and a bare
  # assignment propagates it — so the function died HERE and returned an empty list, which
  # reads downstream as "no backups to compare" and silently skips C2n entirely. Caught by
  # test-merge-decide.sh's fail-closed fixture: 3 checks went from pass to silent no-op.
  local floor
  floor="$( { ls -1d "$CL/backups"/*/ 2>/dev/null \
                | sed 's#.*/\([^/]*\)/$#\1#' \
                | grep -xE '[0-9]{8}-[0-9]{4,6}' | sort | tail -1; } || true )"
  if [[ -z "$floor" ]]; then
    ls -1dtr "$CL/backups"/*/ 2>/dev/null || true
    return 0
  fi
  local d n stamp
  for d in $(ls -1dtr "$CL/backups"/*/ 2>/dev/null || true); do
    n="$(basename "$d")"
    # `<script>-<date>-<time>` → the last two dash-separated fields are the stamp.
    case "$n" in
      *-*-*) stamp="$(printf '%s' "$n" | awk -F- '{print $(NF-1)"-"$NF}')" ;;
      *)     stamp="$n" ;;
    esac
    [[ "$stamp" < "$floor" ]] || printf '%s\n' "$d"
  done
}

c2n_build_indexes() {
  [ "$C2N_IDX_READY" -eq 1 ] && return 0
  C2N_IDX_READY=1
  # Prefer the engine's LINE-level test. It answers "did this run delete a line the framework
  # cannot regenerate?", which is the question C2n has always been approximating with tokens —
  # and, unlike a token test over the same corpus, it cannot be blinded by the fact that the
  # packs shipped `DomainMiddleware` and `X-Product-Id` as their own example tokens.
  local eng
  for eng in "$SCRIPTS_DIR/merge-decide.py" \
             "${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/scripts/merge-decide.py"; do  # checkout first
    [ -f "$eng" ] || continue
    command -v python3 >/dev/null 2>&1 || break
    C2N_ENGINE="$eng"; C2N_LINE_MODE=1
    C2N_PAIRS=$(mktemp "${TMPDIR:-/tmp}/c2n-pairs.XXXXXX")
    break
  done
  local root d
  for d in "$SCRIPTS_DIR/../templates/packs" \
           "${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/packs"; do  # checkout first
    [[ -d "$d" ]] && { root="$d"; break; }
  done
  C2N_PACK_IDX=$(mktemp "${TMPDIR:-/tmp}/c2n-pack.XXXXXX")
  if [[ -n "${root:-}" ]]; then
    find -L "$root" -type f -name '*.md' -print0 2>/dev/null \
      | xargs -0 grep -ohE "$KNOW_PATH_RE|$KNOW_IDENT_RE" 2>/dev/null \
      | sed 's|^\./||' | sort -u > "$C2N_PACK_IDX" 2>/dev/null || true
  else
    C2N_IDX_NOTE="pack corpus unreadable — the 'absent from the packs' condition is disabled, so this check is NOISIER, not blinder"
  fi

  # .claude/ and ai/ are excluded on purpose: a token that exists only inside the framework's
  # own artifacts is not evidence about the project's code, and including them would make
  # every pack identifier "used by the project".
  # SOURCE FILES ONLY, by extension. Without the filter this walked into `tenant_mysql_data/`
  # and `.tsbuildinfo` on a real target: 70,325 "identifiers", most of them byte noise out of a
  # database page file, and 32 seconds to collect them. An index that broad is not just slow —
  # it makes the gate BLINDER, because any identifier that happens to occur inside a binary
  # blob then counts as "the project uses this". Narrowing can only make the check noisier,
  # which is the direction a safety gate is allowed to err in.
  C2N_REPO_IDX=$(mktemp "${TMPDIR:-/tmp}/c2n-repo.XXXXXX")
  find "$TARGET" \
       \( -name node_modules -o -name .git -o -name dist -o -name build -o -name vendor \
          -o -name .next -o -name .nuxt -o -name coverage -o -name __pycache__ \
          -o -name .venv -o -name venv -o -name .turbo -o -name .cache \
          -o -name .claude -o -path "$TARGET/ai" \) -prune -o \
       -type f -size -2M -print 2>/dev/null \
    | grep -E "\.($KNOW_SRC_EXT)$" \
    | tr '\n' '\0' \
    | xargs -0 grep -ohE "$KNOW_IDENT_RE" 2>/dev/null | sort -u > "$C2N_REPO_IDX" 2>/dev/null || true
  return 0
}

# Emit a sorted token file for `comm`, or an empty stream when the index is unavailable.
c2n_pack_stream() { [[ -s "${C2N_PACK_IDX:-}" ]] && cat "$C2N_PACK_IDX" || true; }

# Count the removed path tokens that STILL RESOLVE in the target — i.e. real losses only.
count_resolvable_lost_paths() {
  local bf="$1" live="$2" n=0 tok
  # M42 — BOTH conditions. The pack filter is a set difference (one `comm`), not a grep per
  # token; the resolve test has to stay per-token because it touches the filesystem.
  while IFS= read -r tok; do
    [[ -z "$tok" ]] && continue
    know_token_resolves "$tok" && n=$((n + 1))
  done < <(comm -23 <(comm -23 <(know_tokens "$bf" "$KNOW_PATH_RE") <(know_tokens "$live" "$KNOW_PATH_RE")) \
                    <(c2n_pack_stream) || true)
  printf '%s\n' "$n"
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
      warn_msg "no backup dir in .claude/backups from the last 24h — file-census comparison skipped. ENHANCE DOES take the Phase-0 backup now (run-preflight.sh STEP -1), so this means the preflight was skipped, or the target had no prior setup to back up (a bare ENHANCE-retrofit). Re-run: $SCRIPTS_DIR/run-preflight.sh \"$TARGET\" --mode=$MODE_LABEL"
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
  c2n_build_indexes
  [[ -n "$C2N_IDX_NOTE" ]] && warn_msg "C2n: $C2N_IDX_NOTE"
  # Report the two index sizes. A silently-empty index is the difference between a gate that
  # checks two conditions and one that checks none, and there is no way to tell from the ERRs.
  if [[ "$C2N_LINE_MODE" -eq 1 ]]; then
    # ANNOUNCES THE MECHANISM, NOT THE RESULT — and it has to say so. This line used to read
    # `ok   loss test: LINE-level provenance (…)` and was printed BEFORE the engine ran, so a
    # run in which the engine went on to report 227 losses showed an `ok` for the loss test
    # followed immediately by 227 `ERR  KNOWLEDGE_LOSS` rows. Two statements that cannot both
    # be true, in one block, with nothing telling the reader which to believe. The verdict is
    # now printed AFTER the engine call, from its actual result.
    ok "loss test WILL RUN in LINE-level provenance mode (scripts/merge-decide.py --verify-pairs) — verdict below"
  else
    ok "loss test: token fallback — $(grep -c . "${C2N_PACK_IDX:-/dev/null}" 2>/dev/null || echo 0) pack token(s), $(grep -c . "${C2N_REPO_IDX:-/dev/null}" 2>/dev/null || echo 0) project-source identifier(s)"
  fi
  [[ -s "$C2N_REPO_IDX" ]] || warn_msg "C2n: could not index this project's own identifiers — the identifier half of the loss test falls back to an unfiltered set difference (noisier, never quieter)"
  seen_rel=$(mktemp "${TMPDIR:-/tmp}/c2n-seen.XXXXXX")
  kn_checked=0; kn_lost=0; kn_archived=0
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
        # THE DENSEST PROJECT KNOWLEDGE IN THE INSTALL WAS NOT IN THIS LIST. `_extracted-*.md`,
        # `codebase-profile.md`, `_codebase-scan.md` and `GUIDE.md` are the extraction output —
        # entity names, real paths, real conventions, none of it regenerable from a pack. No
        # writer this repo ships touches them today, so this is not a hole in the merge engine;
        # it was a hole in the NET, and a net with a hole in it only tells you about the fish
        # that swam into the other side.
        .claude/GUIDE.md|.claude/codebase-profile.md|.claude/_extracted-*.md|.claude/_codebase-scan.md|.claude/plans/*.md) ;;
        *) continue ;;
      esac
      # Oldest backup wins: first sighting of a path is the pre-run state.
      grep -qxF "$rel" "$seen_rel" 2>/dev/null && continue
      printf '%s\n' "$rel" >> "$seen_rel"
      live="$TARGET/$rel"
      [[ -f "$live" ]] || continue   # whole-file deletion is caught by the census above
      if c2n_twin_archived "$rel" "$bf"; then
        kn_archived=$((kn_archived + 1))
        continue
      fi
      kn_checked=$((kn_checked + 1))
      if [[ "$C2N_LINE_MODE" -eq 1 ]]; then
        # Collected now, adjudicated in ONE engine call after the loop — the provenance corpus
        # costs ~20s to build and must be built once, not once per file.
        printf '%s\t%s\t%s\n' "$rel" "$bf" "$live" >> "$C2N_PAIRS"
      else
        c2n_token_pair "$rel" "$bf" "$live" "${bkdir#$TARGET/}"
      fi
      # An anchor that existed and no longer does means the project block was
      # overwritten wholesale, not merged.
      if grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$bf" 2>/dev/null \
         && ! grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$live" 2>/dev/null; then
        err "KNOWLEDGE_LOSS: $rel carried the project-specific anchor in ${bkdir#$TARGET/} and no longer does — the block was replaced, not merged."
      fi
    done < <(find "$bkdir" -type f -name '*.md' 2>/dev/null | sort)
  done < <(c2n_run_backups)

  # --- the NON-markdown half: hooks and settings ------------------------------------------
  # `.claude/hooks/*.sh` and `.claude/settings*.json` are executable project configuration.
  # A hook path silently dropped from settings.json unregisters behaviour the owner wired up,
  # and the file it names is still sitting on disk — which is exactly what
  # count_resolvable_lost_paths is built to notice. The LINE test is deliberately NOT used
  # here: the pack corpus is markdown, so every line of a JSON file is "unknown origin" to it
  # and the result would be noise, not a signal.
  seen_np=$(mktemp "${TMPDIR:-/tmp}/c2n-np.XXXXXX")
  while IFS= read -r bkdir; do
    bkdir="${bkdir%/}"
    [[ -d "$bkdir" ]] || continue
    [[ -n "$(find "$bkdir" -maxdepth 0 -mmin -1440 2>/dev/null)" ]] || continue
    while IFS= read -r bf; do
      rel="${bf#"$bkdir"/}"
      case "$rel" in .claude/hooks/*|.claude/settings.json|.claude/settings.local.json) ;; *) continue ;; esac
      grep -qxF "$rel" "$seen_np" 2>/dev/null && continue
      printf '%s\n' "$rel" >> "$seen_np"
      live="$TARGET/$rel"
      [[ -f "$live" ]] || continue
      kn_checked=$((kn_checked + 1))
      c2n_token_pair "$rel" "$bf" "$live" "${bkdir#$TARGET/}"
    done < <(find "$bkdir" \( -path '*/.claude/hooks/*' -o -name 'settings.json' -o -name 'settings.local.json' \) -type f 2>/dev/null | sort)
  done < <(c2n_run_backups)
  rm -f "$seen_np"
  # M43 — one engine call for every pair the loop collected.
  if [[ "$C2N_LINE_MODE" -eq 1 && -s "${C2N_PAIRS:-}" ]]; then
    c2n_out=$(mktemp "${TMPDIR:-/tmp}/c2n-out.XXXXXX")
    if python3 "$C2N_ENGINE" --verify-pairs="$C2N_PAIRS" --target="$TARGET" > "$c2n_out" 2>/dev/null; then
      while IFS=$'\t' read -r rel nl nt nr first; do
        [[ -z "$rel" ]] && continue
        # Reported, not failed. A rule import that wire-rule-imports.sh dropped for budget
        # while its rule file is still on disk is a deliberate, already-announced trade —
        # and the standing KNOWLEDGE_LOSS advice ("restore it from the backup") is the exact
        # opposite of what the owner should do. See _budget_evicted_rule in merge-decide.py.
        if [[ "$first" == BUDGET* ]]; then
          warn_msg "RULE_BUDGET: $rel — ${first#BUDGET }"
          continue
        fi
        kn_lost=$((kn_lost + 1))
        err "KNOWLEDGE_LOSS: $rel lost $nl line(s), $nt project token(s) and $nr project-specific region(s) that the pack corpus cannot account for — e.g. $first. Restore it from the backup and merge the pack depth in instead of replacing."
      done < "$c2n_out"
    else
      # C2n USED TO FAIL OPEN HERE, and this is the single most dangerous line the audit ever
      # had. `command -v python3` succeeding set C2N_LINE_MODE=1 permanently, so when the
      # engine call itself then failed — a stubbed python3, a syntax error in the engine, a
      # corrupt provenance cache — the token fallback never ran and this emitted warn_msg.
      # `warn` does not touch the exit code, so audit-setup.sh printed
      # "PASS — Phase 5 audit clean. Safe to report success." over a run whose loss test had
      # not executed at all. REPRODUCED 2026-08-23: python3 stubbed to /usr/bin/false on a
      # fixture the same audit ERRs on with a working python3 — WARN only, no ERR.
      #
      # Two changes, and both are needed. The failure is an err, because a mandatory check
      # that did not run must never read as a check that passed. AND the token test runs over
      # every pair anyway, because "we could not check" is a much weaker answer than the one
      # this script can still produce without the engine.
      err "C2n: the LINE-level provenance check FAILED TO RUN (scripts/merge-decide.py --verify-pairs exited non-zero). This is the mandatory loss test — a run whose loss test did not execute is NOT a clean run. Falling back to the token test below; fix python3/the engine and re-run before trusting this audit."
      while IFS=$'\t' read -r p_rel p_bf p_live; do
        [[ -z "$p_rel" ]] && continue
        c2n_token_pair "$p_rel" "$p_bf" "$p_live" "the pre-run backup"
      done < "$C2N_PAIRS"
    fi
    rm -f "$c2n_out"
  fi
  rm -f "$seen_rel" ${C2N_PACK_IDX:+"$C2N_PACK_IDX"} ${C2N_REPO_IDX:+"$C2N_REPO_IDX"} ${C2N_PAIRS:+"$C2N_PAIRS"}
  # Printed, never silent: an exemption nobody can see is indistinguishable from a blind spot.
  if [[ "$kn_archived" -gt 0 ]]; then
    ok "resolved skill-shape twins: $kn_archived file(s) whose pre-run content is preserved byte-for-byte under .claude/backups/skill-shape-*/resolved-twins/ (verified with cmp, not assumed)"
  fi
  if [[ "$kn_checked" -eq 0 ]]; then
    ok "per-file project knowledge: no backed-up .md files to compare (nothing was overwritten this run)"
  elif [[ "$kn_lost" -eq 0 ]]; then
    ok "per-file project knowledge: $kn_checked backed-up file(s) compared, none lost project paths/identifiers"
  else
    # The counterpart to the mode announcement above: one closing sentence that states the
    # verdict in the same units the ERRs above are counted in, so the block cannot be read as
    # having passed. Not an extra failure — `err` already moved the exit code for each row.
    echo "  ---  loss test VERDICT: $kn_lost of $kn_checked compared file(s) lost content the pack corpus cannot account for (each one an ERR above). The mode line at the top of C2n announced which mechanism ran; THIS is its result."
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
      # Name the phase that can actually fill it, per MODE. Phase 0.2 is skipped in every
      # ENHANCE mode (commands/setup-project.md § STEP ZERO), so pointing an ENHANCE run at
      # Phase 0.2 was pointing it at a step it does not run — the ERR was unresolvable from
      # inside the mode and punished the run for honestly recording migration_layout_detected.
      if [[ "$MODE" == "enhance" ]]; then
        err "_refresh-extract.md § 9 (migration mapping) is <TBD> but migration is in scope. In ENHANCE modes Phase 0.2 does not run — PHASE 2 § 16 owns § 9 (see templates/phases/phase-2-profile.md § 16). Fill it from the §16 findings; 'no mappable V1→V2 pairs yet — <reason>' is a valid answer, '<TBD>' is not."
      else
        err "_refresh-extract.md § 9 (migration mapping) is <TBD> but migration is in scope — Phase 0.2 must fill it."
      fi
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
    # HEADING-PRESENCE FIRST. HISTORY: this check was `grep -q '<TBD>'` on the awk output and
    # nothing else. When the heading is ABSENT the awk prints nothing, `grep -q` on an empty
    # string is false, and the check reported "filled" — so a section that does not exist at
    # all passed identically to one that is fully written. Measured on a live repo: the
    # preflight preserved a stale 4-of-15-section scan file and ALL EIGHT mandatory semantic
    # sections were reported green while none of them existed. A vacuous pass is worse than a
    # failure, because it consumes the gate slot that would have caught the real problem.
    if ! grep -qE "^## .*$section" "$CL/_codebase-scan.md" 2>/dev/null; then
      err "_codebase-scan.md § \"$section\" heading is ABSENT — the file is truncated or was preserved stale. Re-run deep-codebase-scan.sh (a missing section is not a filled one)."
    elif echo "$section_first_line" | grep -q '<TBD>'; then
      err "_codebase-scan.md § \"$section\" is <TBD>"
    elif [[ -z "$section_first_line" ]]; then
      err "_codebase-scan.md § \"$section\" heading exists but has no body"
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

  # Compute LOC from section 5 to gate "non-trivial" check.
  #
  # HISTORY — "the parse produced nothing" and "the repo is genuinely tiny" used to be the
  # SAME answer, 0, and the <1000 branch below reads 0 as "small codebase, threshold relaxed".
  # A live 631-file, 226,080-line repo therefore had this mandatory gate WAIVED, because the
  # preserved scan file had no `## 5.` section for the parse to read. There is now a third
  # state: unparseable. It never relaxes anything — it fails and says which file to rebuild.
  loc_parsed=0
  loc_total=0
  if grep -q '^## 5\.' "$CL/_codebase-scan.md" 2>/dev/null; then
    loc_total=$({ awk '/^## 5\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec' "$CL/_codebase-scan.md" 2>/dev/null || true; } \
      | { grep -oE '[0-9]+ lines' 2>/dev/null || true; } | { grep -oE '^[0-9]+' 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
    loc_total="${loc_total:-0}"
    [[ "$loc_total" -gt 0 ]] && loc_parsed=1
  fi

  if [[ "$loc_parsed" -eq 0 ]]; then
    err "_codebase-scan.md § 5 (lines of code) is absent or unparseable — LOC could not be measured, so the § 15 recommendation floor cannot be gated. This is NOT 'small codebase'. scripts/deep-codebase-scan.sh emits § 5; re-run it rather than preserving the stale file. (§ 15 currently has $recs recommendation(s).)"
  elif [[ "$loc_total" -ge 1000 && "$recs" -lt 3 ]]; then
    err "_codebase-scan.md § 15 has $recs structural recommendations; minimum 3 required (LOC=$loc_total)"
  elif [[ "$loc_total" -lt 1000 ]]; then
    ok "_codebase-scan.md § 15 has $recs recommendations (small codebase measured at $loc_total LOC, threshold relaxed)"
  else
    ok "_codebase-scan.md § 15 has $recs structural recommendations (LOC=$loc_total)"
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
    # ⚠ `| head -N` UNDER `set -o pipefail` IS AN ABORT WAITING FOR A BIG ENOUGH INPUT.
    #
    # head exits after N lines and closes the pipe; the upstream writer takes SIGPIPE; pipefail
    # promotes that to a non-zero pipeline status; `set -e` ends the script. It is invisible
    # whenever the producer finishes before head closes — which is why these survived every
    # macOS run and surfaced on Linux, where the CI log carried the tell verbatim:
    #     head: error writing 'standard output': Broken pipe
    # The audit then stopped mid-run with no summary. `|| true` is correct here because every
    # one of these is DISPLAY TRUNCATION: showing the first N of something already computed.
    key=$(printf '%s' "$line" | grep -oE '`[^`]+/commands/[^`]+\.md`' | head -1 | tr -d '`') || true
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
    key=$(printf '%s' "$line" | grep -oE '`[^`]+/commands/[^`]+\.md`' | head -1 | tr -d '`') || true
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
        err "$add_count adapter file(s) missing + $refresh_count drifted — run: $SCRIPTS_DIR/apply-adapter-sync.sh \"$TARGET\" --apply"
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
      err "$add_count baseline file(s) missing in target — run: $SCRIPTS_DIR/apply-baseline-sync.sh \"$TARGET\" --apply"
    else
      warn_msg "$add_count baseline file(s) missing in target (CREATE mode — first scaffold)"
    fi
    # Show first 5 missing files for context
    echo "$baseline_out" | grep -E '^  ADD ' | head -5 | sed 's/^/    /' || true
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
  PACKS_ROOT="$(framework_path templates/packs)"
  # 🔴 `stat -f %m` MEANS SOMETHING ELSE ON LINUX, AND IT SUCCEEDS.
  #
  # On macOS `-f <fmt>` is the output format, so `stat -f %m` is the mtime. On GNU
  # coreutils `-f` is `--file-system`, so the same call reports the FILESYSTEM and exits
  # 0 — the `||` fallback never fires — printing text that begins `File: `. That string
  # then reached `[[ $m -gt $pack_newest ]]`, where `[[ ]]` evaluates arithmetically and
  # bash reads `File` as a variable name:
  #
  #     audit-setup.sh: line 1088: File: unbound variable
  #
  # `set -u` then killed the audit MID-RUN, at C2f, before C2u and everything after it.
  # Every Linux user of this repo had a Phase 5 audit that stopped a third of the way
  # through, and the only symptom was output that just... ended.
  #
  # Two changes. GNU is tried FIRST — `stat -c` is rejected outright by BSD stat, so the
  # fallback is honest in that direction, while the reverse silently succeeds. And the
  # result is forced numeric before it can reach an arithmetic context, so no future
  # variant of this can turn a string into code.
  _mtime() {
    local t
    t=$(stat -c %Y "$1" 2>/dev/null) || t=$(stat -f %m "$1" 2>/dev/null) || t=""
    case "$t" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$t" ;; esac
  }
  # Same shape: GNU `date -d @<epoch>` first, because BSD `date -r` takes an epoch while
  # GNU `date -r` takes a FILE — and given a number GNU fails, which is the safe direction.
  _iso() {
    date -d "@$1" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -r "$1" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf 'unknown'
  }

  pack_newest=0
  if [[ -d "$PACKS_ROOT" ]]; then
    # find the newest .md file across pack sources (resolves symlinks via -L)
    while IFS= read -r f; do
      m=$(_mtime "$f")
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
      file_mtime=$(_mtime "$f")
      if [[ $file_mtime -lt $pack_newest ]]; then
        # Format both timestamps for the message
        pack_iso=$(_iso "$pack_newest")
        file_iso=$(_iso "$file_mtime")
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
BASELINE_AI="$(framework_path templates/repo-baseline/ai)"
# The seven files whose population is MANDATORY. Unchanged severity: a stub here is an ERR.
FOUNDATIONAL=( architecture stack modules status conventions business-domain _convention-cheatsheet )

# EVERY OTHER baseline-derived ai/ file is now checked too, and the list is DERIVED from
# templates/repo-baseline/ai/ rather than hand-maintained here.
#
# HISTORY — FOUNDATIONAL was a hand-written list of 7 names, and the files that were actually
# shipping as unfilled template were not on it. Measured across two unrelated live projects:
# ai/runtime/context.md was 52% placeholder lines and BYTE-IDENTICAL between a NestJS backend
# and a Vue frontend; ai/competitive-context.md 50%; ai/business-model.md 42% and 100% template
# ("Last updated: <YYYY-MM-DD>", "<Subscription | Usage-based | Transaction fee | ...>");
# ai/runtime/domain-anti-patterns.md 40%; ai/runtime/environment-quirks.md 38%;
# ai/business-flows.md 27%. The gate reported "ok all foundational ai/ files populated" over all
# of it — and STUB_TOKENS below would have matched every one of them, so the regex was never the
# problem. The LIST was. A hand-maintained list of what to check drifts the moment the baseline
# grows a file; deriving it cannot.
#
# Severity is split by how unambiguous the finding is:
#   byte-identical to the baseline  -> ERR. Nobody touched it; there is nothing to argue about.
#   edited but still ≥25% placeholder prose lines -> WARN with the measured density, because a
#   partially-filled file is a judgement call and a second wall is not what this run needs.
SECONDARY_AI=()
if [[ -d "$BASELINE_AI" ]]; then
  while IFS= read -r _bf; do
    _rel="${_bf#"$BASELINE_AI"/}"
    _name="${_rel%.md}"
    case "$_rel" in README.md|*/README.md) continue ;; esac
    # 🔴 A BLANK FORM IS SUPPOSED TO STAY BLANK.
    #
    # `_template.md` is the form you COPY to open a new ADR, runbook, pattern or eval case.
    # Byte-identical to the baseline is the ONLY correct state for it — a filled-in one would
    # mean somebody wrote an ADR into the template instead of into a numbered file. The check
    # that says "shipped, never written" was calling that a defect, and on tenant-portal it
    # produced 3 ERRs (decisions, evals/cases, runbooks) that no action could ever clear:
    # populate them and the next audit is right to complain about the opposite.
    #
    # This repo already draws the line — the ADR census reads `find ai/decisions -name '*.md'
    # -not -name '_*'` — it just was never drawn here. Only `_template.md` is exempt, NOT every
    # `_`-prefixed file: `_decision-index.md`, `_session-digest.md`, `_convention-cheatsheet.md`,
    # `_scorecard.md` and `_index.md` are GENERATED, and an unpopulated one of those is real.
    case "$_rel" in _template.md|*/_template.md) continue ;; esac
    # skip the seven already covered above
    case " ${FOUNDATIONAL[*]} " in *" $_name "*) continue ;; esac
    SECONDARY_AI+=("$_name")
  done < <(find "$BASELINE_AI" -type f -name '*.md' 2>/dev/null | sort)
fi

# Fraction of prose lines carrying a placeholder token, as a whole-number percentage.
# Prose = non-blank, non-heading, non-fence, non-frontmatter lines.
placeholder_density() {
  awk '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm { next }
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    { total++ ; if ($0 ~ /<[A-Za-z0-9_ .,|\/-]*>/) ph++ }
    END { if (total == 0) print 0; else printf "%d\n", (ph * 100) / total }
  ' "$1" 2>/dev/null
}
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
# --- every OTHER baseline-derived ai/ file (derived list; see § SECONDARY_AI above) --------
sec_stub=0; sec_thin=0
for fname in ${SECONDARY_AI[@]+"${SECONDARY_AI[@]}"}; do
  tgt="$TARGET/ai/$fname.md"
  [[ -f "$tgt" ]] || continue          # absent is a coverage question, not a stub question
  base="$BASELINE_AI/$fname.md"
  if [[ -f "$base" ]] && diff -q "$base" "$tgt" >/dev/null 2>&1; then
    C2I_REPORT "UNPOPULATED_STUB: ai/$fname.md is byte-identical to the repo-baseline template — it was shipped, never written"
    sec_stub=$((sec_stub + 1)); continue
  fi
  dens=$(placeholder_density "$tgt"); dens="${dens:-0}"
  if [[ "$dens" -ge 25 ]]; then
    warn_msg "ai/$fname.md is ${dens}% placeholder prose lines — still largely an unfilled template"
    sec_thin=$((sec_thin + 1))
  fi
done
if [[ $stub_count -eq 0 && $sec_stub -eq 0 && $sec_thin -eq 0 ]]; then
  ok "all foundational ai/ files populated (7 mandatory + ${#SECONDARY_AI[@]} baseline-derived checked)"
elif [[ $stub_count -eq 0 && $sec_stub -eq 0 ]]; then
  ok "7 mandatory ai/ files populated; $sec_thin baseline-derived file(s) still thin (WARN above)"
fi
echo ""

# C2w — AN INSTALLED COMMAND'S OWN INSTRUCTIONS MUST RESOLVE
#
# HISTORY — nothing checked this, and the casualty was the single most repo-relevant command in
# one live install. `/tenant-leak-audit` targets that project's actual failure theme (three of
# its last 97 commits are cross-tenant leak fixes) and is broken against the repo it sits in:
# its "How to run" section says to execute `.claude/skills/tenant-leak-scan.sh`, which does not
# exist; three of its seven checks and two of its carve-outs key on `infrastructure/persistence/`
# and `*.orm-entity.ts`, of which the codebase contains ZERO (it uses
# `infrastructure/database/entities/` and `*.entity.ts`, across 111 infrastructure dirs). It is
# also UNANCHORED, so it sits in audit-anchoring.sh's "orphans skipped" bucket and the leak gate
# never looked at it either.
#
# The command is a project-local ORPHAN — no pack owns it, so no pack-side fix can reach it and
# no currency sweep can either. What IS fixable here is the blindness: an installed command that
# tells the user to run a file, and the file is not there, is mechanically detectable. This
# check reads what commands tell the user to EXECUTE and asks whether it exists.
echo "C2w: installed commands' own instructions resolve"
cmd_broken=0; cmd_checked=0
if [[ -d "$TARGET/.claude/commands" ]]; then
  while IFS= read -r cf; do
    [[ -f "$cf" ]] || continue
    crel="${cf#$TARGET/}"
    cmd_checked=$((cmd_checked + 1))
    # Executable references the command instructs the reader to run: a repo-relative path to a
    # .sh / .py / .js inside .claude/ or ai/ or scripts/, whether backticked or on a bare line
    # in a fenced block.
    #
    # THE END GUARD IS LOAD-BEARING. Without `([^A-Za-z0-9]|$)` the alternation `js` matches
    # INSIDE `.json`, so `ai/optimize/_dep-graph.json` was extracted as `ai/optimize/_dep-graph.js`,
    # failed the existence test, and raised a KNOWLEDGE-shaped ERR about a file that had never
    # existed and that nothing ever asked the reader to run. Measured: this was the ONLY new ERR
    # a whole 149-file merge run introduced on capsolah-api (audit fail 38 -> 39), and the pack
    # sentence it fired on explicitly handles the file's absence ("If the graph artifact is
    # absent, record diagram UNVERIFIED"). `grep -o` prints the guard character too, so the sed
    # below strips it from both ends.
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      ref="${ref#./}"
      [[ -e "$TARGET/$ref" ]] && continue
      # A path under templates/ or ~/.claude/ is a FRAMEWORK reference, not a target file.
      case "$ref" in templates/*|~/*|/*) continue ;; esac
      # MATERIALIZE-ON-FIRST-USE IS NOT A DEAD PATH. `/grab-site` ships its whole mirror
      # script inside the command file and tells the reader to "write verbatim to
      # .claude/scripts/grab-site.py", then run it — so the file legitimately does not exist
      # until the command is first used. MEASURED: this check raised a hard ERR on
      # tenant-portal for exactly that, and the printed remedy ("ship the helper") would have
      # duplicated a script the command already carries. A command that CONTAINS the bytes and
      # says where to put them has not made a broken promise.
      # NB `.*`, not `[^\\n]*`: inside an ERE bracket expression `\\n` is the two characters
      # backslash and n, so `[^\\n]*` means "not a backslash and not the letter n", which matches
      # almost nothing in English prose. grep is line-oriented anyway.
      if grep -qiE '(materiali[sz]e|write (it )?verbatim( to)?|writes? (it )?to).*'"$(printf '%s' "${ref##*/}" | sed 's/[.[\*^$]/\\&/g')" "$cf" 2>/dev/null; then
        continue
      fi
      err "$crel instructs the reader to run \`$ref\`, which does not exist in this target. A command whose first instruction is a dead path is worse than no command — the reader trusts it. Either ship the helper, or rewrite the step to something this repo can run."
      cmd_broken=$((cmd_broken + 1))
    done < <({ awk '
                 # Skip the generated anchor block: its provenance line names
                 # `scripts/apply-anchors.sh`, a FRAMEWORK script that lives at ~/.claude/scripts
                 # and is not expected under the target. Reading it here produced one false ERR
                 # per anchored command — caught by an end-to-end smoke test.
                 /^<!-- project-specific:start -->[[:space:]]*$/ { anc=1; next }
                 anc { if (/^<!-- project-specific:end -->[[:space:]]*$/) anc=0; next }
                 { print }
               ' "$cf" 2>/dev/null \
               | { grep -ohE '(^|[[:space:]`(])((\.claude|ai)/[A-Za-z0-9_./-]+\.(sh|py|js|mjs))([^A-Za-z0-9]|$)' 2>/dev/null || true; } \
             ; } | sed -E 's/^[[:space:]`(]+//; s/[^A-Za-z0-9]+$//' | sort -u)
  done < <({ find "$TARGET/.claude/commands" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null || true; } | sort)
fi
if [[ "$cmd_broken" -eq 0 ]]; then
  ok "$cmd_checked installed command(s) — every executable they name resolves"
fi
echo ""

# C2u — INSTALLED RULES ACTUALLY LOAD (M42)
#
# HISTORY — nothing checked this, and the answer on two live repos was "none of them".
# `.claude/rules/README.md` states the mechanism in as many words: "Claude Code does not
# auto-load `.claude/rules/` on its own — the `CLAUDE.md` import is what makes these
# always-on." Neither project's CLAUDE.md carried a single `@.claude/rules/` line, and NO
# script, phase or command in the framework ever wrote one — the imports lived only in
# templates/repo-baseline/CLAUDE.md, a greenfield file that ENHANCE mode never applies
# (apply-baseline-sync.sh correctly classifies an existing CLAUDE.md as KEEP-OURS). Measured:
# 221,560 bytes of always-tier rules in one repo and 99,763 in the other, loading ZERO times
# per turn. Every gate was green over all of it, because every gate asked whether the FILE
# EXISTED and none asked whether anything READ it.
#
# The documented fallback is checked too: a path-scoped rule is loaded by inject-path-rules.sh,
# which is a hook — and that hook was registered in no settings.json at any scope in either
# repo, so the path-scoped tier was equally dead.
# C2v — THE PROFILE CONTRACT THREE PHASES READ.
#
# phase-2-profile.md § 17 calls `repo_shape` / `members` / `is_multi_track` / `track_roots` "the
# contract three later phases read". Phase 2 is LLM-executed, and Phase 4.2's response to a
# missing field was an instruction addressed to an agent — "do NOT default to false … Halt" —
# which is not a check, and was not followed.
#
# 📏 MEASURED on capsolah-api: ZERO occurrences of repo_shape, is_multi_track and track_roots.
# Phase 4.2's scoping branch was therefore never true, the step was skipped in silence, and 14
# of 36 installed rules ended up delivered on no turn. The audit's job is to notice that the
# input a phase depends on was never written — a WARN because the run can still be correct
# (scope-domain-rules.sh no longer needs these fields), and never silence, because a phase
# reading an absent contract is how this was missed for as long as it was.
if [[ -x "$SCRIPTS_DIR/verify-profile-contract.sh" ]]; then
  echo "C2v: profile contract (fields Phase 3/4.0/4.2 read)"
  if pc_out=$("$SCRIPTS_DIR/verify-profile-contract.sh" "$TARGET" --quiet 2>&1); then
    ok "codebase-profile.md carries every field the later phases read"
  else
    # `|| true` is load-bearing under `set -euo pipefail` — the SAME trap this file already
    # documents at c2n_run_backups, made again here one screen away from the note describing
    # it. grep exits 1 when it matches nothing, pipefail promotes that to the substitution,
    # and a bare assignment propagates it, so the audit died at C2v and every check after it
    # — C2u, C2y, C2j, C2t — never ran. Caught by the AUDIT ABORTED banner added earlier
    # today, which is the only reason it took one run instead of an afternoon.
    pc_missing=$({ printf '%s' "$pc_out" | grep -oE 'MISSING[[:space:]]+[a-z_]+' | awk '{print $2}' | tr '\n' ' '; } || true)
    warn_msg "codebase-profile.md is missing the field(s) later phases read: ${pc_missing:-see below}. Phase 4.2 reads is_multi_track to decide rule scoping; absent, that branch never runs. Fix: complete § 17 of phase-2-profile.md in .claude/codebase-profile.md"
  fi
  echo ""
fi

echo "C2u: installed rules are actually loaded (imports wired)"
if [[ -d "$TARGET/.claude/rules" ]]; then
  rule_always=0; rule_scoped=0; rule_unimported=""
  imports_present=0
  [[ -f "$TARGET/CLAUDE.md" ]] && imports_present=$({ grep -c '^@\.claude/rules/' "$TARGET/CLAUDE.md" 2>/dev/null || true; })
  imports_present="${imports_present:-0}"
  for rf in "$TARGET"/.claude/rules/*.md; do
    [[ -e "$rf" ]] || continue
    rb="$(basename "$rf")"
    # README.md and `_`-prefixed records (.claude/rules/_unloaded.md is written by
    # wire-rule-imports.sh) are not rules — counting the ledger as a rule made C2u ERR on
    # the file whose whole purpose is to record why some rules do not load.
    [[ "$rb" == "README.md" || "$rb" == _* ]] && continue
    # path-scoped == `paths:` key in the LEADING frontmatter (same test as check-rule-budget.sh)
    # `globs:` counts (same test as wire-rule-imports.sh / check-rule-budget.sh — it is the
    # key the adapter contract maps `paths:` to, so it is the same declaration).
    if head -1 "$rf" | grep -qE '^---[[:space:]]*$' \
       && awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^(paths|globs):/{f=1} END{exit !f}' "$rf"; then
      rule_scoped=$((rule_scoped + 1)); continue
    fi
    rule_always=$((rule_always + 1))
    grep -qF "@.claude/rules/$rb" "$TARGET/CLAUDE.md" 2>/dev/null \
      || rule_unimported="$rule_unimported $rb"
  done

  if [[ "$rule_always" -gt 0 && "$imports_present" -eq 0 ]]; then
    rbytes=$(cat "$TARGET"/.claude/rules/*.md 2>/dev/null | wc -c | tr -d ' ')
    err "NO rule is loaded: CLAUDE.md carries 0 \`@.claude/rules/\` imports while $rule_always always-tier rule(s) (~$(( ${rbytes:-0} / 4 )) tok) sit on disk. .claude/rules/README.md: 'Claude Code does not auto-load .claude/rules/ on its own — the CLAUDE.md import is what makes these always-on.' Fix: $SCRIPTS_DIR/wire-rule-imports.sh \"$TARGET\" --apply"
  elif [[ -n "$rule_unimported" ]]; then
    # THE MUTUAL UNSATISFIABILITY, and how it is broken. wire-rule-imports.sh DECLINES rules
    # that do not fit the always-loaded token budget and says so in plain words; this check
    # then failed the run for exactly that decision, and the escape hatch it printed
    # (scope-rules.sh → path-scoped tier) was dead too because inject-path-rules.sh was
    # registered in no settings.json. MEASURED: 20 rules on capsolah-api, 4 on tenant-portal,
    # and no reachable state satisfying both steps of the same run.
    #
    # The distinguishing fact is whether the refusal was RECORDED. wire-rule-imports.sh now
    # writes `.claude/rules/_unloaded.md` — next to the rules, with each rule's per-turn cost
    # and both remedies — and regenerates it from the live budget computation on every run, so
    # it cannot rubber-stamp: a rule that later fits, or gains `paths:`/`globs:`, leaves the
    # ledger by itself. A rule listed there is an owned decision (WARN). A rule that is simply
    # absent from CLAUDE.md with no record anywhere is still an oversight (ERR).
    # Fixture: scripts/test-rule-loading.sh § 2.
    unloaded_md="$TARGET/.claude/rules/_unloaded.md"
    recorded=""; unrecorded=""
    for ru in $rule_unimported; do
      if [[ -f "$unloaded_md" ]] && grep -qF "\`.claude/rules/$ru\`" "$unloaded_md" 2>/dev/null; then
        recorded="$recorded $ru"
      else
        unrecorded="$unrecorded $ru"
      fi
    done
    if [[ -n "$unrecorded" ]]; then
      n=$(printf '%s' "$unrecorded" | wc -w | tr -d ' ')
      err "$n always-tier rule(s) are installed, NOT imported by CLAUDE.md, and recorded nowhere, so they never load and nothing says so:$unrecorded. Either import them (wire-rule-imports.sh \"$TARGET\" --apply) or path-scope them (scope-rules.sh) — a rule that is neither is dead weight the reader believes is active."
    fi
    if [[ -n "$recorded" ]]; then
      n=$(printf '%s' "$recorded" | wc -w | tr -d ' ')
      warn_msg "$n always-tier rule(s) do NOT load, by recorded decision in .claude/rules/_unloaded.md (over the always-loaded token budget):$recorded. Not a failure — the refusal is written where a reader will find it, with the per-turn cost. To make one load: scope-rules.sh (free until matched) or wire-rule-imports.sh --budget=N."

    # 🔴 "RECORDED" IS NOT "REACHABLE".
    #
    # The branch above downgrades an unimported rule to a WARN when `_unloaded.md` records
    # it — an owned decision rather than an oversight, which is right as far as it goes. But
    # the ledger's OWN remedy is `scope-rules.sh`, and nothing ever checked whether anyone
    # ran it. A rule that is recorded AND unscoped is still delivered on no turn: not in
    # CLAUDE.md, and carrying no `paths:` for the hook to match. The record documents the
    # loss; it does not undo it.
    #
    # 📏 MEASURED on capsolah-api: 14 of 36 rules in exactly that state — 34,773 tok
    # including backend-principles, security-principles and testing-principles, on a backend
    # project — every one of them dutifully listed in `_unloaded.md`, and the audit's only
    # comment was a WARN saying the decision was recorded. tenant-portal: 4 of 17, including
    # frontend-principles, on a frontend project.
    #
    # So this asks the question the two tiers between them never asked: CAN THIS RULE ARRIVE
    # AT ALL? An ERR, because the answer is no and there is a one-command fix.
    unreachable=""
    for ru in $recorded; do
      rf="$TARGET/.claude/rules/$ru"
      [[ -f "$rf" ]] || continue
      if ! awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$rf" 2>/dev/null | grep -qE '^(paths|globs):'; then
        unreachable="$unreachable $ru"
      fi
    done
    if [[ -n "$unreachable" ]]; then
      n=$(printf '%s' "$unreachable" | wc -w | tr -d ' ')
      err "$n rule(s) are UNREACHABLE — not imported by CLAUDE.md and carrying no \`paths:\`, so they are delivered on NO turn: $(printf '%s' "$unreachable" | cut -c1-140). Being recorded in _unloaded.md documents the loss, it does not undo it. Fix: $SCRIPTS_DIR/scope-domain-rules.sh \"$TARGET\" --apply && $SCRIPTS_DIR/wire-rule-imports.sh \"$TARGET\" --apply"
    fi
    fi
  elif [[ "$rule_always" -gt 0 ]]; then
    ok "$rule_always always-tier rule(s) imported by CLAUDE.md; $rule_scoped path-scoped"
  else
    ok "no always-tier rules installed ($rule_scoped path-scoped)"
  fi

  # The path-scoped tier needs its hook registered or it is equally dead.
  if [[ "$rule_scoped" -gt 0 ]]; then
    if grep -rqF 'inject-path-rules' "$TARGET/.claude/settings.json" "$TARGET/.claude/settings.local.json" 2>/dev/null; then
      ok "inject-path-rules.sh registered — the $rule_scoped path-scoped rule(s) can load"
    else
      warn_msg "$rule_scoped path-scoped rule(s) installed but inject-path-rules.sh is registered in no settings.json — the path-scoped tier is inert too. Register it as a PreToolUse hook, or those rules never load either."
    fi
  fi
fi
echo ""

# C2v — EXTRACTION SUBSTRATE HONESTY (mechanical, not self-policed)
#
# HISTORY — this check did not exist. `grep -c '_extracted-codebase' scripts/audit-setup.sh`
# returned 0 and neither audit script contained the strings [SAMPLED], [inferred:], [found:]
# or files_cited. C2b verified only that the file EXISTS. The extraction skill's own Step 15
# check 7 is described as "arithmetic against numbers the model did not author" — but nothing
# outside the model ever ran that arithmetic, so every honesty rule in a 40 KB skill was on the
# honour system. The proof that the honour system fails was sitting in a live repo: its
# substrate shipped the literal line
#     ## API surface [SAMPLED: 2/242 files] — check-7 FAIL (see ## Coverage)
# a SELF-DECLARED gate failure, and it passed every audit; and its cross-cutting table wrote
# `multi-tenant | **confirmed**` with no ratio when the measured truth was 117/242 = partial.
#
# These are the check-7 rules that are pure arithmetic or pure grep. They are re-run here,
# outside the model, against the file the model wrote.
EXTRACT="$CL/_extracted-codebase.md"
if [[ -f "$EXTRACT" ]]; then
  echo "C2v: extraction substrate honesty (check 7, re-run externally)"
  C2V_ERRS_AT_START=$fail

  # (1) A self-declared failure must never pass. If the author wrote that a check failed,
  #     believe them — this is the exact string that shipped green on a live repo.
  if grep -qiE 'check-?7[[:space:]]+FAIL|EXTRACTION-WEAK' "$EXTRACT" 2>/dev/null; then
    err "_extracted-codebase.md declares its own check-7 / EXTRACTION-WEAK failure in the text. A self-declared gate failure is a failure: $(grep -m1 -iE 'check-?7[[:space:]]+FAIL|EXTRACTION-WEAK' "$EXTRACT" | sed 's/^[[:space:]]*//' | cut -c1-140)"
  fi

  # (2) `## API surface` declares NO cap in the Step 2.5 table, so check 7's `none declared`
  #     bullet requires seen == present. A [SAMPLED] marker on that heading is an honest
  #     report of a floor being breached — and honesty about a breach is not compliance.
  api_head=$(grep -m1 -E '^##[[:space:]]+API surface' "$EXTRACT" 2>/dev/null || true)
  if [[ -n "$api_head" ]] && printf '%s' "$api_head" | grep -q '\[SAMPLED'; then
    err "_extracted-codebase.md § API surface carries a [SAMPLED] marker, but Step 7 declares NO cap — check 7's 'none declared → must be 100%' bullet FAILs a sampled walk here, disclosed or not. Heading: $(printf '%s' "$api_head" | cut -c1-140)"
  fi

  # (3) Step 9 grammar: a `confirmed` verdict on a pervasive property must print
  #     <matched>/<present>, and matched must equal present. `confirmed` with a ratio below
  #     100% is a `partial` mislabelled — the single highest-authority claim in the file.
  while IFS= read -r cline; do
    [[ -z "$cline" ]] && continue
    if ! printf '%s' "$cline" | grep -qE '[0-9]+[[:space:]]*/[[:space:]]*[0-9]+'; then
      err "_extracted-codebase.md: 'confirmed' verdict with NO <matched>/<present> ratio — Step 9's hard rule calls this the same violation as an uncited factual claim: $(printf '%s' "$cline" | sed 's/^[[:space:]]*//' | cut -c1-140)"
      continue
    fi
    m=$(printf '%s' "$cline" | grep -oE '[0-9]+[[:space:]]*/[[:space:]]*[0-9]+' | head -1 | tr -d ' ') || true
    num="${m%%/*}"; den="${m##*/}"
    if [[ -n "$num" && -n "$den" && "$den" -gt 0 && "$num" -ne "$den" ]]; then
      err "_extracted-codebase.md: 'confirmed' printed with ratio $num/$den — below 100% is 'partial' mislabelled (Step 9 + check 7 bullet 6): $(printf '%s' "$cline" | sed 's/^[[:space:]]*//' | cut -c1-140)"
    fi
  done < <(sed -n '/^##[[:space:]]*Cross-cutting concerns/,/^##[[:space:]]/p' "$EXTRACT" 2>/dev/null \
           | { grep -iE 'confirmed' || true; } | { grep -vE '^[[:space:]]*(>|\||-{3,})[[:space:]]*$' || true; })

  # (4) check 7's forbidden-quantifier list, re-run. Inside a [SAMPLED] section a `[found:]`
  #     line may not carry an absolute quantifier. `confirmed` is exempt ONLY when the same
  #     line prints a ratio — see the skill's Step 15 carve-out, which exists because Step 9
  #     mandates that word and the three rules were otherwise unsatisfiable together.
  quant_hits=$(awk '
    /^##[[:space:]]/ { sampled = ($0 ~ /\[SAMPLED/) ; next }
    !sampled { next }
    /\[found:/ {
      line = $0
      low = tolower(line)
      if (low ~ /all |every |always|never|throughout|repo-wide|project-wide|consistently|the codebase /) { print; next }
      if (low ~ /confirmed/ && line !~ /[0-9]+[[:space:]]*\/[[:space:]]*[0-9]+/) { print }
    }
  ' "$EXTRACT" 2>/dev/null | head -5 || true)
  if [[ -n "$quant_hits" ]]; then
    n=$(printf '%s\n' "$quant_hits" | grep -c .)
    err "_extracted-codebase.md: $n [found:] line(s) inside a [SAMPLED] section carry an absolute quantifier — check 7 forbids generalizing beyond the sample with a citation attached. First: $(printf '%s\n' "$quant_hits" | head -1 | sed 's/^[[:space:]]*//' | cut -c1-140)"
  fi

  # (5) A [SAMPLED] marker must carry an auditable ratio, and seen must not exceed present.
  bad_ratio=$(grep -oE '\[SAMPLED:[^]]*\]' "$EXTRACT" 2>/dev/null \
    | awk '{ if ($0 !~ /[0-9]+[[:space:]]*\/[[:space:]]*[0-9]+/) print "no-ratio " $0 }' | head -3 || true)
  if [[ -n "$bad_ratio" ]]; then
    err "_extracted-codebase.md: [SAMPLED] marker without a <seen>/<present> ratio — 'sampled' without a denominator is an adjective, not a disclosure: $(printf '%s\n' "$bad_ratio" | head -1 | cut -c1-140)"
  fi
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    sn="${r%%/*}"; sp="${r##*/}"
    [[ -z "$sn" || -z "$sp" || "$sp" -eq 0 ]] && continue
    if [[ "$sn" -gt "$sp" ]]; then
      err "_extracted-codebase.md: [SAMPLED: $sn/$sp] claims more files seen than present — the census and the marker disagree"
    fi
  done < <(grep -oE '\[SAMPLED:[^]]*\]' "$EXTRACT" 2>/dev/null \
           | grep -oE '[0-9]+[[:space:]]*/[[:space:]]*[0-9]+' | tr -d ' ' || true)

  # (6) `## Coverage` is unconditional per the skill — including at 100%, which it calls the
  #     strongest claim the file can make about its own output.
  grep -qE '^##[[:space:]]+Coverage' "$EXTRACT" 2>/dev/null \
    || err "_extracted-codebase.md has no '## Coverage' section — the skill requires it on EVERY run, including at 100%. Without it no consumer can tell a complete walk from a silent sample."

  # (7) Provenance: a substrate with citations but ZERO provenance markers has not applied the
  #     discipline at all.
  fnd=$({ grep -c '\[found:' "$EXTRACT" 2>/dev/null || true; }); fnd="${fnd:-0}"
  inf=$({ grep -c '\[inferred:' "$EXTRACT" 2>/dev/null || true; }); inf="${inf:-0}"
  unc=$({ grep -c '\[unconfirmed\]' "$EXTRACT" 2>/dev/null || true; }); unc="${unc:-0}"
  if [[ $((fnd + inf + unc)) -eq 0 ]]; then
    err "_extracted-codebase.md carries no [found:] / [inferred:] / [unconfirmed] provenance markers at all — § Provenance discipline was not applied, so no claim in it can be graded"
  else
    ok "provenance markers present ([found:] $fnd, [inferred:] $inf, [unconfirmed] $unc)"
  fi
  # ONE remediation line for the whole check. C2v's findings each say precisely WHAT is wrong
  # and, until now, none of them said what to DO — and unlike every other check in this file,
  # the answer is not a script: `_extracted-codebase.md` has no deterministic producer. A live
  # run collected 13 C2v ERRs, including a self-declared check-7 FAIL the substrate shipped
  # anyway, and the reader was left to infer that the fix is to re-run an LLM skill.
  if [[ ${C2V_ERRS_AT_START:-0} -ne $fail ]]; then
    echo "     Fix: re-run the extraction that wrote this file — skill \`extract-codebase-overview\`"
    echo "          (templates/packs/learning/skills/extract-codebase-overview/SKILL.md), whose"
    echo "          Step 2.5 census and check 7 are the rules re-run above. There is no script to"
    echo "          run: this substrate is LLM-written, which is exactly why it is audited here."
  fi
  echo ""
fi

# C2y — A SHELL PROBE IN AN ARTIFACT MUST NAME A DIRECTORY THAT EXISTS.
#
# THE FAILURE MODE IS SILENT AND IT IS A FALSE NEGATIVE. MEASURED on capsolah-api: 19 live
# artifacts — including `.claude/agents/tenant-isolation-reviewer.md`, the highest-severity
# reviewer that repo owns — issue probes like
#     rg "SELECT.*FROM (orders|products)" src/ | grep -v "tenant_id"
# under the banner "Every hit = BLOCKER candidate". `src/` DOES NOT EXIST in that repo; the
# real top level is apps/, libs/, chrome-extension/. The probe returns zero hits, and a
# zero-hit probe over a missing directory is indistinguishable from a clean result. The run
# that shipped this KNEW the layout — apply-anchors.sh repaired the citation line in these very
# files from `top-level: src/.` to the real dirs — and did not carry the knowledge one line
# down into the embedded commands.
#
# This is PRE-EXISTING owner content and the merge engine is right to preserve it verbatim, so
# the fix is not a rewrite: it is that nothing may report such a probe as clean. The check names
# the file, the line and the directories that DO exist, and leaves the edit to a human.
echo "C2y: shell probes in artifacts cite directories that exist"
c2w_hits=""; c2w_n=0
# The real top-level source directories, computed the same way apply-anchors.sh computes them:
# a top-level dir that holds at least one source file.
c2w_real=""
for d in "$TARGET"/*/; do
  d="${d%/}"; bn="$(basename "$d")"
  case "$bn" in .*|node_modules|dist|build|vendor|coverage|tmp|docs|assets) continue ;; esac
  if find "$d" -maxdepth 3 -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.vue' \
        -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.php' -o -name '*.java' \
        -o -name '*.cs' -o -name '*.rs' -o -name '*.kt' \) 2>/dev/null | head -1 | grep -q .; then
    c2w_real="$c2w_real ${bn}/"
  fi
done
# ⚠ A PROBE IS CODE. THE WORD "grep" IN AN ENGLISH SENTENCE IS NOT A PROBE.
#
# This used to grep whole LINES for `rg|grep|find|ls|fd` and then harvest every `a/b`
# token out of the matched line. Both halves misfire on prose, and artifacts are mostly
# prose. Measured on tenant-portal: of 55 reported probes, 26 came from sentences —
#
#   "Known limit of that grep: it is line-scoped, so a multi-line JSX/template `<input>`…"
#   "…adds a collection form/endpoint, a logger call, an analytics/telemetry event…"
#   "…a new tool/function the model can call, a RAG retrieval…"
#
# — where `JSX/template`, `analytics/telemetry` and `tool/function` are English, not paths,
# and the trigger word was "grep"/"find" used as a normal verb or noun. "find" in
# particular appears in ordinary instructions constantly.
#
# So the unit of judgement is the CODE on the line, not the line: a fenced block, an
# indented block, or the contents of the inline `…` spans. The command word must appear in
# that code, and the paths are harvested only from that code.
#
# 📏 It costs no recall. capsolah-api's real finding — probes over a `src/` that repo does
# not have — went 115 → 117 (two more, because inline spans are now read as one piece of
# code instead of one line of prose), while its total fell 150 → 133. tenant-portal fell
# 55 → 29, and the survivors are genuine: `routes/`, `config/`, `migrations/`, `k8s/`,
# `api/`, `models/` — backend-shaped probes shipped into a Vue frontend, which is exactly
# the silent zero-hit this check exists to catch.
c2y_code_probes() {
  # Text files only; `grep -rIl ''` drops binaries the way `grep -I` used to.
  { grep -rIl '' "$CL/commands" "$CL/agents" "$CL/skills" "$CL/rules" "$TARGET/ai" 2>/dev/null \
      | grep -vE '/backups/' || true; } | sort | while IFS= read -r _file; do
    [[ -f "$_file" ]] || continue
    awk -v F="$_file" '
      /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
      {
        code = ""
        if (fence || $0 ~ /^(    |\t)/) { code = $0 }
        else {
          # every inline `…` span on the line, concatenated: one command may be split
          # across two spans, and a path in one span belongs to a command in another.
          s = $0
          while (match(s, /`[^`]*`/)) {
            code = code " " substr(s, RSTART + 1, RLENGTH - 2)
            s = substr(s, RSTART + RLENGTH)
          }
        }
        if (code == "") next
        if (code ~ /(^|[[:space:](|`"'"'"'])(rg|grep|find|ls|fd)[[:space:]]/) printf "%s:%d\t%s\n", F, NR, code
      }
    ' "$_file"
  done
}

_c2y_self="$(basename "$TARGET")"
while IFS=$'\t' read -r loc code; do
  [[ -z "$loc" ]] && continue
  f="${loc%:*}"; lno="${loc##*:}"
  # Every path-shaped operand of the probe, e.g. `src/`, `src/modules/*/infrastructure/`
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    root="${dir%%/*}"
    [[ -z "$root" ]] && continue
    # only judge a REPO-ROOT-relative first segment, and only when it is plainly a directory
    case "$root" in .|..|\$*|\**|-*|/*) continue ;; esac
    # A path written from the PARENT of this repo — `tenant-portal/src/utils/x.ts` inside
    # tenant-portal — resolves fine for the human who wrote it. Three such hits on that
    # project, and none of them a missing directory.
    [[ "$root" == "$_c2y_self" ]] && continue
    [[ -e "$TARGET/$root" ]] && continue
    c2w_n=$((c2w_n + 1))
    c2w_hits="$c2w_hits"$'\n'"      ${f#$TARGET/}:$lno probes \`$dir\` — no \`$root\` in this repo"
    break
  done < <(printf '%s\n' "$code" | grep -oE '(^|[[:space:]])[A-Za-z0-9_][A-Za-z0-9_.*-]*/[A-Za-z0-9_./*-]*' 2>/dev/null | sed 's/^[[:space:]]*//')
done < <(c2y_code_probes)
if [[ "$c2w_n" -gt 0 ]]; then
  err "$c2w_n shell probe(s) in installed artifacts name a top-level directory that does NOT exist here. A probe over a missing directory returns zero hits, and zero hits reads as CLEAN — this is a false negative, not a broken command. Real top-level source dirs:${c2w_real:- (none detected)}. Edit the probes (they are project-authored content; nothing rewrites them for you):$(printf '%s' "$c2w_hits" | head -12)"
else
  ok "every shell probe in an installed artifact names a directory that exists"
fi
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
  printf '%s\n' "$app_stubs" | sed 's#^#      #' | head -8 || true
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
    # UNIQUENESS, REPORTED NEXT TO COVERAGE — because on its own "100% anchored" is a
    # sentence about file structure that a reader hears as a sentence about content.
    # MEASURED: capsolah-api 195 anchored / 20 distinct bodies / largest identical group 110
    # (56%); tenant-portal 88 / 11 / 57 (65%). audit-anchoring.sh's own report calls that
    # "a global constant wearing a citation costume" — and C2d printed "ok anchoring coverage
    # 100%" in the same run, with the two verdicts never appearing beside each other.
    uniq_line=$(grep -E '^Distinct anchor bodies:' "$ANCHOR_REPORT" 2>/dev/null | head -1 || true)
    top_line=$(grep -E '^Largest identical group:' "$ANCHOR_REPORT" 2>/dev/null | head -1 || true)
    uniq_pct=$(printf '%s' "$uniq_line" | grep -oE '\(([0-9]+)%\)' | grep -oE '[0-9]+' | head -1 || true)
    top_pct=$(printf '%s' "$top_line" | grep -oE '\(([0-9]+)%\)' | grep -oE '[0-9]+' | head -1 || true)
    if [[ -n "$uniq_pct" ]]; then
      if [[ "${top_pct:-0}" -ge 60 ]]; then
        warn_msg "anchor uniqueness ${uniq_pct}% distinct, and ${top_pct}% of anchored artifacts share ONE byte-identical block. Coverage says every artifact has an anchor; this says most of those anchors say the same thing, so the anchoring is structural rather than informative. Re-run apply-anchors.sh --apply (it retro-fits the per-artifact relevance line into blocks written by an earlier release), then deepen with /setup-project --refine."
      else
        ok "anchor uniqueness ${uniq_pct}% distinct (largest identical group ${top_pct:-0}%)"
      fi
    fi
    if [[ -n "$pct" ]]; then
      if [[ "$unanchored" == "0" ]]; then
        ok "anchoring coverage ${pct}% — every pack-derived artifact carries an anchor block"
      elif [[ "$MODE" == "create" ]]; then
        warn_msg "anchoring coverage ${pct}% — ${unanchored} unanchored (CREATE mode; Phase 4.6 may not have run yet — re-run apply-anchors.sh)"
      else
        err "anchoring coverage ${pct}% — ${unanchored} pack-derived artifact(s) lack project anchors. Phase 4.6 must run: $SCRIPTS_DIR/apply-anchors.sh \"$TARGET\" --apply"
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
    # 🔴 `warn_msg`, NOT `warn`. `warn` is the COUNTER (`warn=0`, line 135); the reporter is
    # `warn_msg` (line 166). Calling `warn "..."` runs a command that does not exist — exit
    # 127 — and under `set -e` that ENDS THE AUDIT.
    #
    # 📏 It only fires when audit-adapter-coverage.sh exits non-zero, which is why it survived
    # every local run and killed CI: no adapters are configured there, the script exits 1, and
    # this line — the handler for that exact case — took the whole audit down at C2e, before
    # C2p, C2q, C2r and C2t. The comment four lines above says "Do NOT swallow the exit code"
    # because a dead chain once reported a pass. The handler written to prevent that was itself
    # broken, so the dead chain took the audit with it instead.
    warn_msg "C2e: audit-adapter-coverage.sh exited non-zero — coverage numbers below are STALE or absent, not verified"
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
  printf '%s\n' "$broken_links" | sed "s#^$TARGET/#      #" | head -8 || true
else
  ok "no artifact still carries the un-rewritten \`../../../\` link shape"
fi

# THE HALF THIS CHECK WAS MISSING, and it was the half that mattered. The grep above tests only
# for the OLD path SHAPE. It never asked whether the REWRITTEN target resolves — so a link
# rewritten exactly as the fix instructs, to a snippet that was never deployed into the target,
# passed as clean. MEASURED on capsolah-api after a full run: 41 of 95 relative links under
# .claude/ did not resolve (43%), up from 20 of 61 at HEAD — the run DOUBLED them — and this
# check printed "ok no broken snippet/governance links in deployed artifacts". Top offenders:
# `../templates/snippets/review-action-plan.md` x16, `../templates/snippets/plan-flag.md` x8.
# ROOT CAUSE: templates/snippets/ shipped 11 files and the repo-baseline deployed 4 of them, so
# the rewrite's destination did not exist. Both halves are fixed: the baseline now carries all
# 11, and this check resolves every link instead of pattern-matching one spelling of failure.
c2t_dead=0; c2t_report=""
while IFS= read -r af; do
  [[ -f "$af" ]] || continue
  adir="$(cd "$(dirname "$af")" && pwd -P)"
  while IFS= read -r ln; do
    [[ -z "$ln" ]] && continue
    # strip the markdown wrapper, drop any #anchor, ignore absolute/URL/mailto targets
    tgt="${ln#*](}"; tgt="${tgt%)}"; tgt="${tgt%%#*}"
    [[ -z "$tgt" ]] && continue
    case "$tgt" in http*|mailto:*|/*|\<*) continue ;; esac
    [[ -e "$adir/$tgt" ]] && continue
    c2t_dead=$((c2t_dead + 1))
    c2t_report="$c2t_report"$'\n'"      ${af#$TARGET/} → $tgt"
  done < <(grep -oE '\]\(\.\./[A-Za-z0-9_./-]+\.md(#[A-Za-z0-9_-]+)?\)' "$af" 2>/dev/null | sort -u || true)
done < <(find "$CL/commands" "$CL/agents" "$CL/skills" "$CL/rules" -type f -name '*.md' 2>/dev/null | sort)
if [[ "$c2t_dead" -gt 0 ]]; then
  warn_msg "$c2t_dead relative link(s) under .claude/ do NOT resolve on disk. A rewritten link whose destination was never deployed is exactly as dead as the un-rewritten one — and this check used to pass it. If the target is a framework snippet, re-run apply-baseline-sync.sh --apply (templates/repo-baseline/.claude/templates/snippets/ ships all of them):$(printf '%s' "$c2t_report" | head -12)"
else
  ok "every relative .md link under .claude/ resolves on disk"
fi
echo ""

# Reaching the summary IS completion: every section above has run.
_AUDIT_COMPLETED=1

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
