#!/usr/bin/env bash
# apply-study-decisions.sh — deterministic enforcer of study-existing decisions.
#
# Reads <target>/.claude/_study-existing-report.md and CLOSES every row it can, by itself.
#
#   ADD                              -> copy the pack file (shape- and variant-aware)
#   REPLACE-OR-ENHANCE / ADOPT-TRIM  -> replace from pack source, after a backup
#   MERGE / KEEP-OURS-PLUS-INJECT    -> handed to scripts/merge-decide.py, which decides
#                                       NO-OP / OVERRIDE / ENHANCE / ADJUST / DEFER per file
#   KEEP-OURS-* / IDENTICAL-NO-OP    -> nothing to do
#
# WHY THE MERGE ROWS ARE NO LONGER "LISTED FOR HUMAN REVIEW". They were, and the measurement
# is why they are not: one live run produced 235 MERGE rows across two repos and printed
# "Listed for human review: 171". Nothing in the framework could close one except a person, so
# the files stayed stale and the audit refused the run for not doing work it gave nobody a way
# to do. Measured over those same 235 rows, 204 are closable with a per-line proof that nothing
# is lost and 30 genuinely need a human. See scripts/merge-decide.py for the proof and
# scripts/test-merge-decide.sh for the fixtures that watch its safety nets catch a bad write.
#
# Solves: agent's Phase 4 was ignoring study-existing actionable rows under
# --include=<pack> narrow-scope interpretation. This script can't be skipped.
#
# Usage:
#   apply-study-decisions.sh <target-repo> [--apply] [--include=replace,add,auto-merge]
#   apply-study-decisions.sh <target-repo> [--apply] --conservative   # pre-engine behaviour
#   apply-study-decisions.sh <target-repo> --migrate-skill-shape [--apply]
#   apply-study-decisions.sh <target-repo> --reject='pack/kind/file.md:rationale'     (repeatable)
#                                          --keep-ours='pack/kind/file.md:rationale'
#                                          --resolve='pack/kind/file.md:note'
#                                          --keep='kind/file.md:rationale'
#
# Default mode: dry-run (lists actions; writes nothing).
# --apply executes.
# --include limits which decision classes to apply (default: replace,add,auto-merge).
#   add            copy files the target does not have
#   replace        REPLACE-OR-ENHANCE / ADOPT-PACK-TRIM rows
#   auto-merge     MERGE rows, decided per file by scripts/merge-decide.py  [DEFAULT]
#   merge-additive MERGE rows, append-only: pack `## ` sections the target lacks, nothing
#                  deleted. Kept for callers contracted to append-only semantics; it closes
#                  strictly fewer rows than auto-merge because a pack change below H2 or
#                  inside a shared section is not section-shaped.
#   merge          list MERGE rows for a human and write nothing (the pre-2026-08 behaviour)
# --conservative is the shorthand for --include=replace,add: no automatic merges at all.
#
# M35 ledger flags append durable decisions to <target>/.claude/_refresh-decisions.md:
#   --reject     permanent skip (artifact class is wrong for this project; never re-proposed)
#   --keep-ours  target file beats the CURRENT pack version (stamped pack@sha8; re-opens when pack changes)
#   --resolve    a MERGE / KEEP-OURS-PLUS-INJECT row was merged by hand (stamped pack@sha8; re-opens when pack changes)
#   --keep       project-only orphan is a keeper (key has no pack segment: kind/file.md)
# These are the ONLY sanctioned way to close an actionable row without applying it.
# audit-setup.sh C2k refuses success on rows that are neither applied nor recorded.
#
# ---------------------------------------------------------------------------
# SKILL SHAPE — the framework's ONE position, and the guard that enforces it (M40)
# ---------------------------------------------------------------------------
# A skill has TWO legal on-disk shapes and exactly ONE identity (the <name>):
#   CANONICAL  .claude/skills/<name>/SKILL.md   — Agent Skills folder form. Packs
#                                                 ship this; new installs get it.
#   LEGACY     .claude/skills/<name>.md         — flat form, pre-Apr-2026 installs.
# This script WRITES, so it is the last thing standing between a shape mismatch and
# a duplicate skill. Observed 2026-08-22 on an 8,151-file target: the coverage scan
# reported 56 flat-form skills as "Missing", every row arrived here as an ADD, and
# `--apply` created 56 folder-form twins — 112 files, 56 duplicated `name:` values,
# both registered, neither authoritative. So:
#   * ADD resolves the target by IDENTITY, not by path. An artifact already present
#     in EITHER shape is never re-copied under the other name.
#   * REPLACE-OR-ENHANCE rewrites the shape that is actually installed — replacing a
#     flat file in place keeps it flat; it never spawns a folder beside it.
#   * check_skill_shape_twin() refuses any write that would put both shapes of one
#     name on disk, and check_skill_name_uniqueness() re-checks the whole skills dir
#     by frontmatter `name:` after the run. Either finding exits 4.
# Migration is explicit, one-way, and backed up — never a side effect of an apply:
#   apply-study-decisions.sh <target> --migrate-skill-shape [--apply]
#
# Exit codes — the CALLER'S CONTRACT. The full table, with the orchestrator's required action
# per code, is templates/phases/phase-4.0-preflight.md § "Exit-code contract"; it is ratcheted
# by scripts/lint-setup-contracts.sh Rule 11, so a new non-zero exit here fails the build until
# that table names it. Read this list as "what happened", the table as "what to do next".
#
#   0  ok
#   1  target not found
#   2  usage
#   3  TWO distinct conditions, and NEITHER means "stop the run":
#        (a) the study report is missing — prints `ERR: study report not found`, writes
#            NOTHING, and sends you back to Phase 3;
#        (b) the merge engine refused, rolled back or aborted at least one row — FILES DID
#            LAND (the engine's `Files written:` line is the count), each verified after its
#            write and backed up first; the unclosed rows are DEFER in
#            `.claude/_merge-decisions.md` and THEIR files are untouched.
#      Case (b) is the safety net working, not a fault. The orchestrator CONTINUES to Phase 4.1
#      and Phase 4.6 — a runner that aborts here leaves the target with pack content applied,
#      no rule imports and no anchors, which is strictly worse than either finishing or never
#      starting. MEASURED: one live run produced exit 3 from a single by-design refusal
#      ("Refused or rolled back: 1") with 154 files already written.
#   4  skill-shape conflict blocked a row this run wanted to write — NOTHING written.
#      Run the printed `--resolve-shape-conflicts --apply` remedy, then re-run.
#   6  auto-merge requested but the merge decision engine cannot run — NOTHING written. Not a
#      degradation: the caller asked for merges and would otherwise have got an exit-0 run that
#      merged nothing. `--conservative` is the opt-out.

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
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--include=replace,add,merge]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
# DEFAULT CHANGED 2026-08-23. The owner's requirement is that setup decides for itself —
# "the setup must decide what to do enhance change or override ... if replace is safe do it".
# `--conservative` (or an explicit --include=) restores the old listing behaviour.
INCLUDE="replace,add,auto-merge"
INCLUDE_EXPLICIT=0
MIGRATE_SHAPE=0
declare -a LEDGER_OPS=()   # "VERB|key|rationale"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)       APPLY=1; shift ;;
    --migrate-skill-shape) MIGRATE_SHAPE=1; shift ;;
    # The scripted exit from a both-shapes-on-disk twin. Content-aware: keeps whichever
    # twin carries more project knowledge, archives the other. See § twin_score.
    --resolve-shape-conflicts) MIGRATE_SHAPE=1; RESOLVE_TWINS=1; shift ;;
    # Restores the pre-fix behaviour: ANY duplicate `name:` anywhere under .claude/skills/
    # fails the whole run, even when it blocked no row. Off by default because that shape
    # deadlocked a live repo for four months.
    --strict-shape) STRICT_SHAPE=1; shift ;;
    --include=*)   INCLUDE="${1#--include=}"; INCLUDE_EXPLICIT=1; shift ;;
    # The documented way back to "list every MERGE row and write nothing".
    --conservative) INCLUDE="replace,add"; INCLUDE_EXPLICIT=1; shift ;;
    --reject=*)    LEDGER_OPS+=("REJECTED|${1#--reject=}"); shift ;;
    --keep-ours=*) LEDGER_OPS+=("KEEP-OURS|${1#--keep-ours=}"); shift ;;
    --resolve=*)   LEDGER_OPS+=("RESOLVED|${1#--resolve=}"); shift ;;
    --keep=*)      LEDGER_OPS+=("KEEP|${1#--keep=}"); shift ;;
    *)             echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# ---------- M35 ledger mode: record decisions, then exit ----------
LEDGER="$TARGET/.claude/_refresh-decisions.md"
if [[ ${#LEDGER_OPS[@]} -gt 0 ]]; then
  mkdir -p "$(dirname "$LEDGER")"
  if [[ ! -f "$LEDGER" ]]; then
    cat > "$LEDGER" <<'HDR'
# Refresh decisions ledger (M35)

Durable per-file decisions from /setup-project refresh runs. study-existing.sh
reconciles rows recorded here instead of re-proposing them every run.
KEEP-OURS / RESOLVED entries re-open automatically when the pack source changes
(pack@sha8 mismatch). REJECTED / KEEP are permanent until a human deletes the line.

Append via: apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'
(or --keep-ours= / --resolve= / --keep=). Manual edits are fine — keep the line shape.

---
HDR
  fi
  today=$(date +%Y-%m-%d)
  recorded=0
  for op in "${LEDGER_OPS[@]}"; do
    verb="${op%%|*}"; rest="${op#*|}"
    key="${rest%%:*}"; why="${rest#*:}"
    if [[ -z "$key" || -z "$why" || "$key" == "$why" ]]; then
      echo "  ERR malformed ledger op (need key:rationale): $rest" >&2; continue
    fi
    stamp="($today)"
    if [[ "$verb" == "KEEP-OURS" || "$verb" == "RESOLVED" ]]; then
      pack_src="$REPO_ROOT/templates/packs/$key"
      if [[ -f "$pack_src" ]]; then
        sha=$(shasum "$pack_src" | cut -c1-8)
        stamp="($today, pack@$sha)"
      else
        echo "  WARN pack source not found for $key — stamping without pack@sha (entry will hold until manually removed)" >&2
      fi
    fi
    # Replace any prior entry for the same key (last-write-wins, one line per key)
    if grep -qF "\`$key\`" "$LEDGER" 2>/dev/null; then
      grep -vF "\`$key\`" "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
    fi
    printf -- '- `%s` → %s %s — %s\n' "$key" "$verb" "$stamp" "$why" >> "$LEDGER"
    echo "  RECORDED $verb $key — $why"
    recorded=$((recorded + 1))
  done
  echo ""
  echo "$recorded decision(s) recorded in ${LEDGER#$TARGET/}. Re-run study-existing.sh to see them reconciled."
  exit 0
fi

# ---------- M40 skill-shape: identity resolution + the two guards ----------
SKILLS_DIR="$TARGET/.claude/skills"
SHAPE_CONFLICTS=0
RESOLVE_TWINS=${RESOLVE_TWINS:-0}
STRICT_SHAPE=${STRICT_SHAPE:-0}

# Artifact identity: the NAME, stripped of whichever shape carries it.
#   <name>/SKILL.md → <name>        <name>.md → <name>
artifact_identity() {
  local base="$1"
  if [[ "$base" == */SKILL.md ]]; then printf '%s' "${base%/SKILL.md}"; else printf '%s' "${base%.md}"; fi
}

# check_skill_shape_twin — the pre-write guard. Resolves ONE pack artifact against the
# target by identity and reports which shape (if any) already carries it. Sets:
#   SHAPE_VERDICT  absent | canonical | legacy-flat | twin
#   SHAPE_PATH     the installed file to act on ("" when absent)
#   SHAPE_OTHER    the second file, set only for `twin`
# `twin` means both shapes of one name are already on disk: two registrations of the
# same `name:`. Callers MUST refuse to write and let the run exit 4 — never "fix" it by
# adding a third file. Non-skill kinds have one legal shape and short-circuit.
check_skill_shape_twin() {
  local kind="$1" tgt_dir="$2" base="$3"
  SHAPE_VERDICT="absent"; SHAPE_PATH=""; SHAPE_OTHER=""

  if [[ "$kind" != "skills" ]]; then
    if [[ -f "$tgt_dir/$base" ]]; then SHAPE_VERDICT="canonical"; SHAPE_PATH="$tgt_dir/$base"; fi
    return 0
  fi

  local name folder flat
  name="$(artifact_identity "$base")"
  folder="$tgt_dir/$name/SKILL.md"
  flat="$tgt_dir/$name.md"

  if [[ -f "$folder" && -f "$flat" ]]; then
    SHAPE_VERDICT="twin"; SHAPE_PATH="$folder"; SHAPE_OTHER="$flat"
  elif [[ -f "$folder" ]]; then
    SHAPE_VERDICT="canonical";   SHAPE_PATH="$folder"
  elif [[ -f "$flat" ]]; then
    SHAPE_VERDICT="legacy-flat"; SHAPE_PATH="$flat"
  fi
  return 0
}

# row_would_write — does THIS loop write a file for this decision, given --include?
#
# The distinction is what separates a blocking twin from a noisy one. MERGE and
# KEEP-OURS-PLUS-INJECT are handed to scripts/merge-decide.py, which resolves the installed
# shape itself and rewrites THAT file — it never creates a third copy, so a twin cannot block
# it. KEEP-OURS-*, IDENTICAL-NO-OP and the ledger verdicts write nothing at all. Only ADD and
# the two REPLACE verdicts put bytes on disk from here.
row_would_write() {
  case "$1" in
    ADD)                                  [[ "$INCLUDE" == *add* ]] ;;
    ADOPT-PACK-TRIM|REPLACE-OR-ENHANCE)   [[ "$INCLUDE" == *replace* ]] ;;
    *)                                    return 1 ;;
  esac
}

# check_skill_name_uniqueness — the post-write guard. The twin check above is keyed on
# the FILENAME; this one is keyed on what the tool actually loads, the frontmatter
# `name:`. It catches a duplicate registration whose two files are not filename twins
# (`threat-model.md` + `threat-modeling/SKILL.md`, both declaring `name: threat-model`),
# which no path comparison can see. Skills with no `name:` are skipped — a missing
# `name:` is a different defect and must not be scored as a collision with another
# missing one. Prints every colliding pair; returns 1 when any collision exists.
check_skill_name_uniqueness() {
  local dir="${1:-$SKILLS_DIR}"
  [[ -d "$dir" ]] || return 0
  local dupes
  dupes="$(
    { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
      find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null
    } | sort | while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      # frontmatter only: first block between the leading `---` fences
      n="$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} /^name:[[:space:]]*/ {sub(/^name:[[:space:]]*/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}' "$f")"
      [[ -n "$n" ]] && printf '%s\t%s\n' "$n" "$f"
    done | sort | awk -F'\t' '{ if ($1==prev) { if (!shown[$1]++) print prevline; print $0 } prev=$1; prevline=$0 }'
  )"
  [[ -z "$dupes" ]] && return 0
  echo "  ERR duplicate skill \`name:\` — the tool registers the same skill twice:" >&2
  printf '%s\n' "$dupes" | while IFS=$'\t' read -r n f; do
    echo "       name: $n   ← ${f#$TARGET/}" >&2
  done
  return 1
}

# ---------- Content-aware twin resolution -------------------------------------------
#
# HISTORY — the both-shapes-on-disk state used to have NO scripted exit. --migrate-skill-shape
# printed "Pick the winner by hand, delete the other, then re-run" and exited 4; the main
# apply path exited 4 on the same names; and the Phase 5 audit then ERRed demanding the apply
# that could not run. Measured on a live repo: 3 twins committed 2026-04-19 blocked EVERY
# /setup-project run for four months, and not one pack file was installed or refreshed in
# that time. A gate with no reachable green state is not a gate, it is a wall.
#
# The remediation text was ALSO inverted. It said "keep the canonical folder form, delete the
# flat twin", and the run report that followed it picked the winner by BYTE SIZE. Reading the
# actual twins showed the opposite for 2 of 3: the small folder files were hand-curated
# project knowledge citing real source paths, and the large flat files were generic pack text
# whose bulk was boilerplate anchor block (41% in one case). Byte size is an actively
# misleading proxy here.
#
# So the winner is decided by PROJECT KNOWLEDGE, measured the same way study-existing.sh and
# audit-setup.sh § C2n measure it: path tokens that resolve in this target, plus code
# identifiers, both counted OUTSIDE the anchor block (an anchor is generated, so counting it
# would score the generator's boilerplate as project knowledge — exactly the inversion above).
# Ties fall to the file that differs from the pack source, then to the newer mtime.
#
# The loser is never deleted. It is archived under .claude/backups/ and its path is printed,
# so a wrong call is recoverable and reviewable.

TWIN_SRC_EXT='ts|tsx|js|jsx|mjs|cjs|vue|py|go|rb|php|java|kt|swift|scala|rs|cs|sql|graphql|proto|yaml|yml|json|toml|md|sh'
TWIN_PATH_RE="[A-Za-z0-9_@.*-]+(/[A-Za-z0-9_@.*-]+)+\.($TWIN_SRC_EXT)"
TWIN_IDENT_RE='[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*|[A-Z][A-Z0-9]*_[A-Z0-9_]+|[a-z][a-z0-9]*_[a-z0-9_]+'

# Body tokens of a file, anchor block excluded.
twin_tokens() {
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
    skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) skip=0; next }
    { print }
  ' "$1" 2>/dev/null | { grep -ohE "$2" 2>/dev/null || true; } | sort -u
}

# Project-knowledge score: resolvable path citations weigh 3, identifiers weigh 1.
# A path that does NOT resolve in this target scores 0 — generic pack prose naming
# `src/foo/bar.ts` on a repo with no src/ must not out-score a real citation.
twin_score() {
  local f="$1" score=0 tok
  while IFS= read -r tok; do
    [[ -z "$tok" ]] && continue
    if [[ -e "$TARGET/$tok" || -e "$TARGET/.claude/$tok" ]]; then
      score=$(( score + 3 ))
    else
      local bn="${tok##*/}"
      if find "$TARGET" -name "$bn" -not -path '*/node_modules/*' -not -path '*/.git/*' \
           -not -path '*/.claude/backups/*' 2>/dev/null | grep -q .; then
        score=$(( score + 3 ))
      fi
    fi
  done < <(twin_tokens "$f" "$TWIN_PATH_RE")
  local idents
  idents=$(twin_tokens "$f" "$TWIN_IDENT_RE" | grep -c . || true)
  printf '%s\n' "$(( score + ${idents:-0} ))"
}

# ---- what the ARCHIVED twin knew and the KEPT twin does not ------------------------------
#
# THE MEASURED LOSS THIS CLOSES. tenant-portal's `visual-check` skill existed in both shapes.
# The FLAT twin scored 15 on project knowledge and won; the FOLDER twin scored 2 and was
# archived. The folder twin was the one that said
#     1. Check dev server on :5173 (`curl -s http://localhost:5173 …`)
# and tenant-portal is a Vite app with no port override, so 5173 is the truth. The kept twin
# was then overridden with pack text and now says `default http://localhost:3000`. visual-check
# is the harness every UI verification runs through, so a wrong port makes the render fail or
# silently grade the wrong thing. twin_score COULD NOT SEE THE FACT: `5173` is neither a path
# token nor a CamelCase identifier, so the resolver was choosing correctly on the evidence it
# had and losing the one number that mattered anyway.
#
# The bytes were archived under .claude/backups/, which is one rolled-up `?? .claude/backups/`
# line in git status and one `git clean -fd` from gone. Archiving is not preserving.
#
# So the loser's project FACTS are carried forward into the winner, under a heading the merge
# engine already protects verbatim (`## Project-specific …` — see merge-decide.py
# PROJECT_HEADING / compose_override), which is what makes them survive the OVERRIDE that
# comes after this step. Salience is deliberately narrow: a line qualifies only if it names a
# port/URL, a path that RESOLVES in this target, or a runnable command. Generic pack prose
# does not qualify, so the winner does not accrete the loser's boilerplate.
# Fixture: scripts/test-merge-decide.sh § 18.
TWIN_FACT_RE='https?://|localhost|127\.0\.0\.1|:[0-9]{4,5}\b|`(npm|pnpm|yarn|npx|bun|make|curl|docker|composer|poetry|pytest|go|cargo) '

twin_unique_facts() {  # $1=loser $2=winner  → verbatim lines the winner does not carry
  local loser="$1" winner="$2" line trimmed
  local wnorm; wnorm=$(mktemp "${TMPDIR:-/tmp}/twin-win.XXXXXX")
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$winner" 2>/dev/null | grep -v '^$' | sort -u > "$wnorm"
  while IFS= read -r line; do
    trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$trimmed" ]] && continue
    case "$trimmed" in '```'*) continue ;; esac          # never emit a half-open fence
    grep -qxF -- "$trimmed" "$wnorm" && continue          # the winner already says it
    if printf '%s' "$line" | grep -qE "$TWIN_FACT_RE"; then
      printf '%s\n' "$line"; continue
    fi
    # a path citation that RESOLVES here is a fact about this repo; one that does not is prose
    local tok found=0
    while IFS= read -r tok; do
      [[ -z "$tok" ]] && continue
      if [[ -e "$TARGET/$tok" || -e "$TARGET/.claude/$tok" ]]; then found=1; break; fi
    done < <(printf '%s\n' "$line" | { grep -ohE "$TWIN_PATH_RE" 2>/dev/null || true; })
    [[ "$found" -eq 1 ]] && printf '%s\n' "$line"
  done < <(awk '
      /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
      skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) skip=0; next }
      { print }
    ' "$loser" 2>/dev/null)
  rm -f "$wnorm"
}

# Is this file byte-identical to any pack source shipping the same skill name?
# A twin that still matches the pack verbatim carries no project edits and loses ties.
twin_matches_pack() {
  local f="$1" name="$2" p
  while IFS= read -r p; do
    [[ -f "$p" ]] || continue
    cmp -s "$f" "$p" && return 0
  done < <( { find -L "$PACKS_ROOT" -maxdepth 3 -path "*/skills/$name.md" 2>/dev/null
              find -L "$PACKS_ROOT" -maxdepth 4 -path "*/skills/$name/SKILL.md" 2>/dev/null; } )
  return 1
}

# ---------- --migrate-skill-shape: the ONE sanctioned way off the legacy shape ----------
# Moves .claude/skills/<name>.md → .claude/skills/<name>/SKILL.md. A MOVE, never a copy:
# a copy is exactly the duplicate this whole section exists to prevent. Refuses any name
# that already has both shapes (that state needs a human to pick a winner).
if [[ "$MIGRATE_SHAPE" -eq 1 ]]; then
  echo "=== apply-study-decisions — skill-shape migration (M40) ==="
  echo "Target: $TARGET"
  echo "Mode:   $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
  echo "From:   .claude/skills/<name>.md        (legacy flat)"
  echo "To:     .claude/skills/<name>/SKILL.md  (canonical Agent Skills folder form)"
  echo ""
  if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "  (no .claude/skills/ in target — nothing to migrate)"
    exit 0
  fi
  mig_ts=$(date +%Y%m%d-%H%M%S)
  mig_bak="$TARGET/.claude/backups/skill-shape-$mig_ts"
  migrated=0; mig_conflicts=0; mig_resolved=0
  while IFS= read -r flat; do
    [[ -f "$flat" ]] || continue
    name="$(basename "$flat" .md)"
    folder="$SKILLS_DIR/$name/SKILL.md"
    if [[ -f "$folder" ]]; then
      if [[ "$RESOLVE_TWINS" -ne 1 ]]; then
        echo "  CONFLICT $name — both .claude/skills/$name.md and .claude/skills/$name/SKILL.md exist."
        echo "           Scripted resolution: apply-study-decisions.sh \"$TARGET\" --resolve-shape-conflicts --apply"
        echo "           (keeps whichever twin carries more PROJECT KNOWLEDGE — resolvable path"
        echo "            citations + code identifiers, anchor block excluded — and archives the"
        echo "            other under .claude/backups/. Do NOT pick by byte size: measured on a"
        echo "            live repo the LARGER twin was generic pack text, 41% of it boilerplate"
        echo "            anchor block, and the smaller one held the hand-written project detail.)"
        mig_conflicts=$(( mig_conflicts + 1 ))
        continue
      fi
      # --- content-aware resolution -------------------------------------------------
      sc_flat=$(twin_score "$flat")
      sc_fold=$(twin_score "$folder")
      winner=""; loser=""; why=""
      if [[ "$sc_fold" -gt "$sc_flat" ]]; then
        winner="$folder"; loser="$flat"; why="folder twin scores $sc_fold vs flat $sc_flat on project knowledge"
      elif [[ "$sc_flat" -gt "$sc_fold" ]]; then
        winner="$flat"; loser="$folder"; why="flat twin scores $sc_flat vs folder $sc_fold on project knowledge"
      elif twin_matches_pack "$folder" "$name" && ! twin_matches_pack "$flat" "$name"; then
        winner="$flat"; loser="$folder"; why="tied at $sc_flat; folder twin is byte-identical to the pack source (no project edits)"
      elif twin_matches_pack "$flat" "$name" && ! twin_matches_pack "$folder" "$name"; then
        winner="$folder"; loser="$flat"; why="tied at $sc_fold; flat twin is byte-identical to the pack source (no project edits)"
      elif [[ "$flat" -nt "$folder" ]]; then
        winner="$flat"; loser="$folder"; why="tied at $sc_flat and neither matches the pack; flat twin is newer"
      else
        winner="$folder"; loser="$flat"; why="tied at $sc_fold and neither matches the pack; folder twin is newer or same age"
      fi
      if [[ "$APPLY" -eq 1 ]]; then
        mkdir -p "$mig_bak/resolved-twins"
        cp "$loser" "$mig_bak/resolved-twins/$name.$([[ "$loser" == "$flat" ]] && echo flat || echo folder).md"
        rm -f "$loser"
        [[ "$loser" == "$folder" ]] && rmdir "$SKILLS_DIR/$name" 2>/dev/null || true
        if [[ "$winner" == "$flat" ]]; then
          mkdir -p "$SKILLS_DIR/$name"
          mv "$flat" "$folder"
        fi
        # CARRY THE LOSER'S PROJECT FACTS ACROSS, don't just archive them. The winner has
        # already been moved to its final path above, so `_kept_path` is where the block goes.
        twinshape=$([[ "$loser" == "$flat" ]] && echo flat || echo folder)
        _arch="$mig_bak/resolved-twins/$name.$twinshape.md"
        _kept_path="$folder"
        _facts=$(twin_unique_facts "$_arch" "$_kept_path" | head -40)
        _nfacts=$(printf '%s' "$_facts" | grep -c . || true)
        if [[ "${_nfacts:-0}" -gt 0 ]]; then
          {
            printf '\n## Project-specific (recovered from the archived %s twin)\n\n' "$twinshape"
            printf '<!-- Written by scripts/apply-study-decisions.sh --resolve-shape-conflicts.\n'
            printf '     This skill existed in BOTH shapes. The other shape stated the fact(s)\n'
            printf '     below and the kept shape does not, so they are carried here instead of\n'
            printf '     being archived out of sight — a fact only recoverable from\n'
            printf '     .claude/backups/ is one `git clean -fd` from gone. Verify each against\n'
            printf '     the codebase and delete any that are stale.\n'
            printf '     Archived copy: %s -->\n\n' "${_arch#$TARGET/}"
            printf '%s\n' "$_facts"
          } >> "$_kept_path"
        fi
        echo "  RESOLVE  $name — kept ${winner#$TARGET/}$([[ "$winner" == "$flat" ]] && echo " (migrated to canonical folder shape)"), archived ${loser#$TARGET/}"
        echo "           reason: $why"
        echo "           archived copy: ${mig_bak#$TARGET/}/resolved-twins/"
        if [[ "${_nfacts:-0}" -gt 0 ]]; then
          echo "           CARRIED FORWARD $_nfacts project fact(s) the kept twin did not state, into"
          echo "           \`## Project-specific (recovered from the archived $twinshape twin)\` at the end of"
          echo "           ${_kept_path#$TARGET/} — the merge engine protects that heading verbatim, so they"
          echo "           survive the OVERRIDE that follows. First:"
          printf '%s\n' "$_facts" | head -3 | sed 's/^/                 /'
        fi
        # SAY WHAT WENT WITH IT. This resolver optimises for project knowledge and is right to,
        # but the twin it archives is often the PACK version — and the pack version is where the
        # hardening lives. MEASURED: component-playground kept a 1,617-byte project twin over a
        # 6,694-byte pack twin (correctly — the kept file cites three real project paths the
        # other does not), and the archived copy took `## Halt conditions` with it, including
        # "halt if no dev-only gating is applied". Nothing was destroyed; nothing said it had
        # gone either. A resolution reported as clean, that quietly drops a halt condition, is
        # a resolution the reader cannot review.
        _lost_sections=$(comm -23 \
          <(grep -oE '^##+[[:space:]]+.*' "$mig_bak/resolved-twins/$name.$([[ "$loser" == "$flat" ]] && echo flat || echo folder).md" 2>/dev/null | sed 's/[[:space:]]*$//' | sort -u) \
          <(grep -oE '^##+[[:space:]]+.*' "$([[ "$winner" == "$flat" ]] && echo "$folder" || echo "$winner")" 2>/dev/null | sed 's/[[:space:]]*$//' | sort -u) \
          2>/dev/null | head -6 || true)
        if [[ -n "$_lost_sections" ]]; then
          echo "           NOTE the archived twin carried section(s) the kept file does not:"
          printf '                 %s\n' $(printf '%s\n' "$_lost_sections" | sed 's/^#*[[:space:]]*//' | tr ' ' '~')  | tr '~' ' '
          echo "                 Review the archived copy before relying on the kept one; if any of"
          echo "                 those are halt conditions or safety scaffolding, port them across."
        fi
      else
        echo "  would-RESOLVE $name — keep ${winner#$TARGET/}, archive ${loser#$TARGET/}"
        echo "           reason: $why"
      fi
      mig_resolved=$(( mig_resolved + 1 ))
      continue
    fi
    if [[ "$APPLY" -eq 1 ]]; then
      mkdir -p "$mig_bak"
      cp "$flat" "$mig_bak/$name.md"
      mkdir -p "$SKILLS_DIR/$name"
      mv "$flat" "$folder"
      echo "  MIGRATE  .claude/skills/$name.md → .claude/skills/$name/SKILL.md"
    else
      echo "  would-MIGRATE .claude/skills/$name.md → .claude/skills/$name/SKILL.md"
    fi
    migrated=$(( migrated + 1 ))
  done < <(find "$SKILLS_DIR" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null | sort)

  echo ""
  echo "=== summary ==="
  echo "Migrated (or would-migrate): $migrated"
  echo "Conflicts (both shapes on disk, untouched): $mig_conflicts"
  echo "Twins resolved content-aware:               $mig_resolved"
  if [[ "$APPLY" -eq 1 && "$migrated" -gt 0 ]]; then
    echo "Backup of every moved file: ${mig_bak#$TARGET/}/"
    echo ""
    echo "Next: re-run scripts/pack-coverage-scan.sh so the report reflects the new shape,"
    echo "      then re-run the adapter sync (adapters project skills by name, not by path)."
  fi
  [[ "$APPLY" -eq 0 ]] && echo "" && echo "Dry run — pass --apply to execute."
  if ! check_skill_name_uniqueness; then
    echo ""
    echo "HALT: duplicate skill \`name:\` on disk (see above). Resolve before any further apply."
    exit 4
  fi
  [[ "$mig_conflicts" -gt 0 ]] && exit 4
  exit 0
fi

# Pack commands use ../../../snippets/ + ../../../governance/ (valid under templates/packs/.../commands/).
# Targets receive files under .claude/commands/ — rewrite so links resolve to .claude/templates/{snippets,governance}/.
rewrite_deployed_command_links() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if command -v perl >/dev/null 2>&1; then
    perl -i -pe 's{\]\(\.\./\.\./\.\./snippets/}{](../templates/snippets/}g; s{\]\(\.\./\.\./\.\./governance/}{](../templates/governance/}g' "$f"
  else
    echo "  WARN perl missing — cannot rewrite snippet/governance links in ${f#$TARGET/}" >&2
  fi
  rewrite_skill_refs_to_installed_shape "$f"
}

# Rewrite every `skills/<name>/SKILL.md` cross-reference to the shape ACTUALLY INSTALLED here.
#
# HISTORY — this is the defect that made the C2k/C2n gate conflict worse than a gate conflict.
# Pack cross-references hardcode the canonical folder shape (`skills/<name>/SKILL.md`) while the
# framework knowingly tolerates legacy flat-shape skills in the same repo — one live target held
# 59 flat vs 11 folder. Applying the mandated MERGE of the observability pack's dashboards.md
# therefore rewrote a reference to `skills/alert-audit.md` (EXISTS, 8,477 B) into
# `skills/alert-audit/SKILL.md` (ABSENT). The gate that flagged it was RIGHT; the run report
# recorded it as a false positive; and the true reading is worse than either — DOING THE
# MANDATED WORK DEGRADED THE TARGET. Blast radius measured in that one repo: 59 dangling
# folder-shape refs where only a flat twin exists, across 10 files, with 166 MERGE rows still
# outstanding to add more.
#
# So the pack keeps writing the canonical form (it is right about the canon), and the DEPLOY
# step reconciles it with what this particular target has on disk. Only rewrites a reference
# whose canonical target is absent AND whose flat twin is present — never invents a link.
rewrite_skill_refs_to_installed_shape() {
  local f="$1" name changed=0
  [[ -f "$f" ]] || return 0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    [[ -f "$TARGET/.claude/skills/$name/SKILL.md" ]] && continue    # canonical resolves — leave it
    [[ -f "$TARGET/.claude/skills/$name.md" ]] || continue          # no flat twin either — not ours to fix
    if command -v perl >/dev/null 2>&1; then
      perl -i -pe "s{skills/\Q$name\E/SKILL\.md}{skills/$name.md}g" "$f"
    else
      sed -i.bak "s|skills/$name/SKILL\.md|skills/$name.md|g" "$f" && rm -f "$f.bak"
    fi
    changed=$((changed + 1))
  done < <({ grep -oE 'skills/[A-Za-z0-9_-]+/SKILL\.md' "$f" 2>/dev/null || true; } \
           | sed -E 's|^skills/||; s|/SKILL\.md$||' | sort -u)
  [[ "$changed" -gt 0 ]] && echo "  shape-fix ${f#$TARGET/} — $changed skill cross-reference(s) rewritten to the flat shape installed here"
  return 0
}

# ---------- M41 on the ENHANCE path: cross-pack command-name collisions ---------------------
#
# HISTORY — M41's collision-aware copy loop existed ONLY in the CREATE-path bash of
# templates/phases/phase-4.2-apply.md. This script is what actually runs in ENHANCE mode, and
# it had no variant logic at all: `grep -n 'variant|_command-variants|M41'` returned EMPTY here
# and in pack-coverage-scan.sh. So on the path most consumer repos take, the loss the CREATE
# path is careful to prevent happened silently every run.
#
# The collision is real and deliberate: `refactor.md` ships in backend, code-quality, frontend
# and mobile; `add-feature.md` in backend, frontend and mobile. They are DIFFERENT commands.
# Measured on a live repo: two refactor variants were selected, the study report emitted two
# contradictory rows for ONE target file (a 39-line pack and a 66-line pack), the last one
# applied won, and the installed file carried only "## Pack overlay — code-quality" while the
# backend overlay was gone. `.claude/_command-variants.md` — the audit trail the design
# promises — existed in NEITHER live project, and no `.<track>.md` file existed anywhere.
#
# Same rule as the CREATE path: first pack to claim a name owns the bare `<name>.md`; every
# later variant lands beside it as `<name>.<pack>.md` and the collision is recorded.
# ---------- MERGE rows: handed to the decision engine ---------------------------------------
#
# HISTORY — the run's real cost was MERGE rows, and NO script performed any of them. One live
# run measured 235 MERGE rows across two repos, all of which the audit then REFUSED the run for
# not doing, while `--include=replace,add` applied 22 ADD rows in 1.77s and printed "Listed for
# human review: 171". The owner is one person running a real SaaS; those hand-merges were never
# going to happen, so in practice the files stayed stale forever.
#
# THE ADDITIVE SUBSET USED TO LIVE HERE, in bash, as `merge_additive()`. It appended the `## `
# sections the pack had and the target lacked — provably lossless, and genuinely useful, but it
# closed 12 of 235 rows and it appended at end-of-file, which left the row dirty enough that the
# NEXT run re-classified and rewrote it. Both properties are now the engine's, which subsumes
# the additive merge as one of four verbs and keeps `--include=merge-additive` working by
# routing it to `--additive-only`. There is deliberately ONE implementation of that merge; the
# bash copy was deleted rather than left to drift, and lint-setup-contracts.sh Rule 8 fails the
# build if a second one reappears here.
#
# The engine is invoked ONCE per run, not once per row: it builds a provenance corpus from
# claude-config's git history (~145k canonical lines, cached by HEAD sha) and that cost must be
# paid once. It backs up before every write, re-reads what it wrote, and rolls back any file
# that lost a line whose origin the corpus could not prove.
MERGE_ENGINE="$REPO_ROOT/scripts/merge-decide.py"

# THE THREE REASONS THE ENGINE MIGHT NOT RUN ARE NOT THE SAME REASON.
#
# This used to be one predicate returning 1 for all three, which made "the user asked for
# --conservative" indistinguishable from "the mandatory engine is not on disk". Measured
# consequence on two live repos: 238 MERGE rows — the entire payload of a seven-batch
# programme — printed `WARN … will be listed, not decided`, once per row, and the script
# exited 0. Phase 4 reported success having performed none of its headline work; only the
# Phase-5 audit caught it, 190 seconds later, and the remedy it printed was the flag that was
# already in effect. A hard contract (M23/M43) must not degrade silently into a no-op.
#
# So the state is computed ONCE, before any row is processed, and it is a THREE-valued answer:
#   on      — run the engine
#   off     — the operator turned it off (--conservative / explicit --include without
#             auto-merge). Listing rows is the requested behaviour. Exit 0.
#   broken  — auto-merge IS requested and the engine cannot run. This is an environment
#             fault, not a decision. HALT (exit 6) before writing anything.
MERGE_ENGINE_STATE=""
MERGE_ENGINE_WHY=""

resolve_merge_engine_state() {
  case ",$INCLUDE," in
    *,auto-merge,*|*,merge-additive,*) ;;
    *) MERGE_ENGINE_STATE="off"
       MERGE_ENGINE_WHY="--include has no auto-merge (conservative by request)"
       return 0 ;;
  esac
  if [[ ! -f "$MERGE_ENGINE" ]]; then
    MERGE_ENGINE_STATE="broken"
    MERGE_ENGINE_WHY="the engine is not on disk at $MERGE_ENGINE"
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    MERGE_ENGINE_STATE="broken"
    MERGE_ENGINE_WHY="python3 is not on PATH, and the engine is a python3 program"
    return 0
  fi
  MERGE_ENGINE_STATE="on"
  MERGE_ENGINE_WHY="scripts/merge-decide.py"
  return 0
}

# 0 = the engine should handle MERGE rows this run. Callable per row; says nothing, because
# the one thing worth saying was already said once in the header.
merge_engine_enabled() {
  [[ "$MERGE_ENGINE_STATE" == "on" ]]
}

run_merge_engine() {
  local -a args=("$TARGET")
  [[ "$APPLY" -eq 1 ]] && args+=(--apply)
  case ",$INCLUDE," in
    *,merge-additive,*) args+=(--additive-only) ;;
  esac
  echo ""
  echo "=== MERGE rows → scripts/merge-decide.py ==="
  python3 "$MERGE_ENGINE" "${args[@]}"
  return $?
}

VARIANTS_LOG="$TARGET/.claude/_command-variants.md"
declare -a CMD_OWNER=()          # "name.md|pack" rows, in claim order
VARIANT_PATH=""
VARIANT_NOTE=""
variants_written=0

# Resolve where a commands row should actually be written.
# Sets VARIANT_PATH (where to write) and VARIANT_NOTE (non-empty only when it diverged).
#
# NB: this MUST set globals rather than echo through `$( )`. The owner table is a bash array,
# and a command substitution runs in a SUBSHELL — the `CMD_OWNER+=(…)` claim would be discarded
# the instant the function returned, so every row would look unclaimed and the collision would
# never be seen. That is precisely how the first draft of this fix silently did nothing.
resolve_variant_path() {         # $1=kind $2=tgt_dir $3=base $4=pack $5=pack_src
  local kind="$1" tgt_dir="$2" base="$3" pack="$4" src="$5" owner row
  VARIANT_NOTE=""
  VARIANT_PATH="$tgt_dir/$base"
  [[ "$kind" == "commands" ]] || return 0
  owner=""
  for row in ${CMD_OWNER[@]+"${CMD_OWNER[@]}"}; do
    [[ "${row%%|*}" == "$base" ]] && { owner="${row##*|}"; break; }
  done
  if [[ -z "$owner" ]]; then
    CMD_OWNER+=("$base|$pack")
    return 0
  fi
  [[ "$owner" == "$pack" ]] && return 0
  # Identical bytes are not a collision — two packs shipping the same file.
  if [[ -f "$tgt_dir/$base" ]] && cmp -s "$src" "$tgt_dir/$base"; then return 0; fi
  VARIANT_NOTE="'$base' was claimed by pack '$owner' earlier this run; '$pack' variant installed beside it, NOT over it"
  VARIANT_PATH="$tgt_dir/${base%.md}.$pack.md"
  return 0
}

record_variant() {               # $1=base $2=pack $3=variant path
  [[ -z "${VARIANT_NOTE:-}" ]] && return 0
  variants_written=$((variants_written + 1))
  [[ "$APPLY" -eq 1 ]] || return 0
  if [[ ! -f "$VARIANTS_LOG" ]]; then
    {
      printf '# Command variants — cross-pack name collisions\n\n'
      printf 'Several command names are shipped by more than one pack as deliberately different\n'
      printf 'commands. The first pack to claim a name owns the bare `<name>.md`; later variants\n'
      printf 'are installed as `<name>.<pack>.md` so nothing is silently overwritten.\n\n'
      printf 'Written by scripts/apply-study-decisions.sh (M41).\n\n'
    } > "$VARIANTS_LOG"
  fi
  printf -- '- `%s` — `%s` variant installed as `%s`; the bare name belongs to the pack applied first.\n' \
    "$1" "$2" "$(basename "$3")" >> "$VARIANTS_LOG"
}

REPORT="$TARGET/.claude/_study-existing-report.md"
[[ -f "$REPORT" ]] || { echo "ERR: study report not found at $REPORT — run scripts/study-existing.sh first" >&2; exit 3; }

# Helper: resolve target path relative to TARGET root for a given kind + base
target_dir_for_kind() {
  case "$1" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$1" ;;
  esac
}

# Parse the report: rows look like
#   - `<base.md>` — target X / pack Y lines → **DECISION**
#   - `<base.md>` — target MISSING / pack Y lines → **ADD**
# Inside ## <pack> section, ### <kind> sub-sections.

current_pack=""
current_kind=""
applied=0
listed=0
delegated=0
skipped=0
ledgered=0
errors=0

declare -a actions  # array of "decision|pack|kind|base|reason"

while IFS= read -r line; do
  # Pack header: "## migration"
  if [[ "$line" =~ ^##\ ([a-z0-9-]+)$ ]]; then
    current_pack="${BASH_REMATCH[1]}"
    continue
  fi
  # Kind header: "### commands" / "### agents" etc.
  if [[ "$line" =~ ^###\ ([a-z-]+)$ ]]; then
    current_kind="${BASH_REMATCH[1]}"
    continue
  fi
  # Row: starts with "  - `<file>` "
  if [[ "$line" =~ ^[[:space:]]+-[[:space:]]\`([^\`]+)\`[[:space:]]+—[[:space:]](.*)$ ]]; then
    base="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    [[ -z "$current_pack" || -z "$current_kind" ]] && continue
    [[ "$current_pack" == "Decision legend" || "$current_kind" == "" ]] && continue

    # Extract decision (last **WORD-WORD** in rest). REVIEW rows contain
    # `**REVIEW: ...**` which won't match the strict pattern — that's fine,
    # we want to skip them. Use `|| true` so grep's exit-1 doesn't trip
    # `set -e` + `pipefail` and kill the whole script.
    decision=$(echo "$rest" | grep -oE '\*\*[A-Z-]+\*\*' | tail -1 | tr -d '*' || true)
    [[ -z "$decision" ]] && continue

    actions+=("$decision|$current_pack|$current_kind|$base|$rest")
  fi
done <<<"$(cat "$REPORT")"

echo "=== apply-study-decisions ==="
echo "Target:  $TARGET"
echo "Mode:    $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Include: $INCLUDE"
echo "Rows:    ${#actions[@]}"

# Say what the merge engine is going to do BEFORE the rows scroll past, once, and halt here
# rather than 168 rows later if it cannot do it. `Engine:` is the line to grep for in a log.
resolve_merge_engine_state
echo "Engine:  $MERGE_ENGINE_STATE — $MERGE_ENGINE_WHY"
if [[ "$MERGE_ENGINE_STATE" == "broken" ]]; then
  _merge_rows=0
  for a in "${actions[@]:-}"; do [[ "${a%%|*}" == "MERGE" ]] && _merge_rows=$(( _merge_rows + 1 )); done
  echo "" >&2
  echo "HALT: auto-merge was requested and the merge decision engine cannot run." >&2
  echo "      Reason: $MERGE_ENGINE_WHY" >&2
  echo "      $_merge_rows MERGE row(s) in this report would be listed instead of decided, and" >&2
  echo "      this script would exit 0 having done none of the work Phase 4 exists to do." >&2
  echo "" >&2
  if [[ ! -f "$MERGE_ENGINE" ]]; then
    echo "      The engine ships with this framework at scripts/merge-decide.py. If that file" >&2
    echo "      exists in your checkout, this script was invoked with a \$REPO_ROOT that is not" >&2
    echo "      the checkout — re-run it by its real path, or re-link the global install:" >&2
    echo "        bash $REPO_ROOT/scripts/sync-to-global.sh --apply" >&2
  else
    echo "      Install python3, or accept conservative behaviour explicitly:" >&2
  fi
  echo "" >&2
  echo "      To proceed WITHOUT the engine — every MERGE row listed for a human, nothing" >&2
  echo "      merged — say so, and this halt turns into the listing you asked for:" >&2
  echo "        $0 \"$TARGET\" --conservative$([[ $APPLY -eq 1 ]] && echo ' --apply')" >&2
  exit 6
fi
echo ""

# One backup timestamp/dir per run so a single invocation's rollback set lives
# together (the summary below points at exactly one dir).
ts=$(date +%Y%m%d-%H%M%S)
bak_dir="$TARGET/.claude/backups/study-decisions-$ts"

# ---------- M40 PREFLIGHT: a blocking twin halts BEFORE the first byte is written --------
#
# HISTORY, measured 2026-08-23 on tenant-portal. The twin check lived INSIDE the write loop,
# so a run wrote 35 ADD rows and 54 engine merges — 89 files — and THEN exited 4 on three
# skills that were already in both shapes before the run started. Two things were wrong with
# that and they compound:
#
#   * ORDER. `exit 4` after a successful mutation is the worst possible signal. A phase runner
#     that reads non-zero as "nothing happened" is wrong about 89 files, and a `set -e` caller
#     aborts its pipeline with the repo already rewritten. Exit 4 now means NOTHING WAS
#     WRITTEN, which is a contract a caller can act on.
#   * BLAME. All three rows were MERGE rows. MERGE goes to the engine, which resolves the
#     installed shape itself and rewrote neither twin (it deferred all three on their own
#     merits). The loop refused rows it was never going to write, and failed the run over it.
#     A twin that blocks no write is a WARN with a named remedy — the duplicate `name:` is
#     real and worth fixing, but it is not this run's failure.
declare -a twin_blocking=() twin_idle=()
for action in "${actions[@]:-}"; do
  [[ -z "$action" ]] && continue
  IFS='|' read -r pf_decision pf_pack pf_kind pf_base pf_rest <<<"$action"
  [[ "$pf_kind" == "skills" ]] || continue
  check_skill_shape_twin "$pf_kind" "$(target_dir_for_kind "$pf_kind")" "$pf_base"
  [[ "$SHAPE_VERDICT" == "twin" ]] || continue
  if row_would_write "$pf_decision"; then
    twin_blocking+=("$pf_pack/$pf_kind/$pf_base|${SHAPE_PATH#$TARGET/}|${SHAPE_OTHER#$TARGET/}")
  else
    twin_idle+=("$pf_pack/$pf_kind/$pf_base ($pf_decision)|${SHAPE_PATH#$TARGET/}|${SHAPE_OTHER#$TARGET/}")
  fi
done
if [[ ${#twin_blocking[@]} -gt 0 ]]; then
  echo "HALT: a skill-shape conflict blocks ${#twin_blocking[@]} row(s) this run would write."
  for t in "${twin_blocking[@]}"; do
    IFS='|' read -r t_key t_a t_b <<<"$t"
    echo "  ERR $t_key — already installed in BOTH shapes: $t_a and $t_b. One skill \`name:\`,"
    echo "      two registrations; writing a third copy would make it worse."
  done
  echo ""
  echo "      NOTHING HAS BEEN WRITTEN. Resolve, then re-run. The scripted resolution is"
  echo "      content-aware — it keeps whichever twin carries more PROJECT KNOWLEDGE and"
  echo "      archives the other under .claude/backups/ (do NOT pick by byte size):"
  echo "        apply-study-decisions.sh \"$TARGET\" --resolve-shape-conflicts --apply"
  exit 4
fi
if [[ ${#twin_idle[@]} -gt 0 ]]; then
  echo "WARN: ${#twin_idle[@]} skill(s) are installed in BOTH shapes (duplicate \`name:\`). No row"
  echo "      this run writes touches them, so the run continues; fix them before one does:"
  for t in "${twin_idle[@]}"; do
    IFS='|' read -r t_key t_a t_b <<<"$t"
    echo "        $t_key — $t_a  +  $t_b"
  done
  echo "        apply-study-decisions.sh \"$TARGET\" --resolve-shape-conflicts --apply"
  if [[ "$STRICT_SHAPE" -eq 1 ]]; then
    echo ""
    echo "HALT: --strict-shape was passed — treating an idle twin as fatal. Nothing written."
    exit 4
  fi
  echo ""
fi

# Apply per action
if [[ ${#actions[@]} -eq 0 ]]; then
  echo "  (no actionable rows parsed from report — either nothing to do, or report is malformed)"
fi
for action in "${actions[@]:-}"; do
  [[ -z "$action" ]] && continue
  IFS='|' read -r decision pack kind base rest <<<"$action"
  pack_src="$PACKS_ROOT/$pack/$kind/$base"
  tgt_dir=$(target_dir_for_kind "$kind")

  # M40: resolve the target by IDENTITY, not by path. `tgt` is the file that ALREADY
  # carries this artifact in whichever shape the project uses; only when nothing
  # carries it does `tgt` fall back to the pack's own (canonical) shape.
  check_skill_shape_twin "$kind" "$tgt_dir" "$base"
  tgt="${SHAPE_PATH:-$tgt_dir/$base}"
  # Belt and braces: the preflight above already halted on a twin that blocks a write, so
  # reaching here with one means the row set changed under us. A twin that blocks nothing was
  # reported by the preflight and falls through — MERGE rows still reach the engine, which
  # rewrites the installed shape and never adds a third file.
  if [[ "$SHAPE_VERDICT" == "twin" ]] && row_would_write "$decision"; then
    echo "  ERR $pack/$kind/$base — already installed in BOTH shapes: ${SHAPE_PATH#$TARGET/} and ${SHAPE_OTHER#$TARGET/}. Duplicate \`name:\`; refusing to write a third copy. Delete the wrong one, then re-run."
    SHAPE_CONFLICTS=$((SHAPE_CONFLICTS + 1))
    errors=$((errors + 1))
    continue
  fi

  case "$decision" in
    ADD)
      [[ "$INCLUDE" == *add* ]] || { listed=$((listed + 1)); continue; }
      [[ -f "$pack_src" ]] || { echo "  SKIP $pack/$kind/$base — pack source missing"; skipped=$((skipped + 1)); continue; }
      # An ADD row for an artifact the target already carries under its OTHER legal
      # shape is not an add — it is the 56-duplicate bug arriving one row at a time.
      if [[ "$SHAPE_VERDICT" == "legacy-flat" ]]; then
        echo "  SHAPE-SKIP $pack/$kind/$base — already installed as ${SHAPE_PATH#$TARGET/} (legacy flat shape of the same skill). Copying the pack file would create a same-\`name:\` twin. Migrate instead: apply-study-decisions.sh \"$TARGET\" --migrate-skill-shape --apply"
        skipped=$((skipped + 1)); continue
      fi
      if [[ "$SHAPE_VERDICT" == "canonical" ]]; then
        # M41 — for COMMANDS this "already present" may be a cross-pack collision rather than a
        # stale row: a different pack claimed the bare name earlier in THIS run, and this pack's
        # command is a genuinely different file. That is the case the CREATE path installs as a
        # variant and this path used to discard as stale, silently. Fall through to the variant
        # resolver; a same-pack or byte-identical hit still short-circuits below.
        if [[ "$kind" == "commands" ]]; then
          resolve_variant_path "$kind" "$tgt_dir" "$base" "$pack" "$pack_src"; tgt="$VARIANT_PATH"
          if [[ -z "${VARIANT_NOTE:-}" ]]; then
            echo "  SHAPE-SKIP $pack/$kind/$base — already present at ${SHAPE_PATH#$TARGET/}; ADD row is stale (re-run study-existing.sh)."
            skipped=$((skipped + 1)); continue
          fi
        else
          echo "  SHAPE-SKIP $pack/$kind/$base — already present at ${SHAPE_PATH#$TARGET/}; ADD row is stale (re-run study-existing.sh)."
          skipped=$((skipped + 1)); continue
        fi
      fi
      # M41 — a second pack's command of the same name becomes a variant, never an overwrite.
      # (For commands the canonical branch above may already have resolved it; resolving twice
      # is harmless because the owner table short-circuits on the same pack.)
      if [[ "$kind" != "commands" || -z "${VARIANT_NOTE:-}" ]]; then
        resolve_variant_path "$kind" "$tgt_dir" "$base" "$pack" "$pack_src"; tgt="$VARIANT_PATH"
      fi
      if [[ -n "${VARIANT_NOTE:-}" ]]; then
        echo "  cmd-variant: $VARIANT_NOTE"
        record_variant "$base" "$pack" "$tgt"
      fi
      if [[ "$APPLY" -eq 1 ]]; then
        # dirname, not $tgt_dir: an Agent Skills row carries a `<name>/SKILL.md` base, so
        # the per-skill subdir must exist too or the cp fails with ENOENT.
        mkdir -p "$(dirname "$tgt")"
        cp "$pack_src" "$tgt"
        if [[ "$kind" == "commands" || "$kind" == "agents" ]]; then
          rewrite_deployed_command_links "$tgt"
        else
          # ai-patterns / rules / skills carry skill cross-refs too — the live breakage was in
          # ai/patterns/dashboards.md, which is none of commands or agents.
          rewrite_skill_refs_to_installed_shape "$tgt"
        fi
        echo "  ADD     $pack/$kind/$base → ${tgt#$TARGET/}"
      else
        # The DESTINATION, relative to the target repo — not `basename dir/basename file`,
        # which collapsed all 29 folder-form skill ADDs to the single string
        # `skills/SKILL.md` and read exactly like the 56-duplicate bug this file exists to
        # prevent. The writes were always correct; the display was not.
        echo "  would-ADD $pack/$kind/$base → ${tgt#$TARGET/}"
      fi
      applied=$((applied + 1))
      ;;
    ADOPT-PACK-TRIM|REPLACE-OR-ENHANCE)
      # ADOPT-PACK-TRIM shares REPLACE's write path deliberately: both replace the target from
      # the pack source, both back up first, and both are gated behind --include=replace. The
      # verdicts differ in WHY (see study-existing.sh § decide), not in what the writer does.
      [[ "$INCLUDE" == *replace* ]] || { listed=$((listed + 1)); continue; }
      [[ -f "$pack_src" ]] || { echo "  SKIP $pack/$kind/$base — pack source missing"; skipped=$((skipped + 1)); continue; }
      [[ -f "$tgt" ]] || { echo "  SKIP $pack/$kind/$base — target missing (was ADD before report; now ADD instead of REPLACE)"; skipped=$((skipped + 1)); continue; }

      # ---- THE REPLACE PATH HAD NO INVARIANT AT ALL --------------------------------------
      # `cp pack_src tgt` and the file is gone. The merge engine has three legs and a
      # read-back; this had none, and the study report's `target N lines` measurement is
      # taken BEFORE anything else in the run touches the file.
      #
      # MEASURED, and it is a real loss, not a hypothetical. tenant-portal:
      # `--resolve-shape-conflicts` correctly resolved the design-iterate twin, keeping the
      # 98-line FLAT file (project anchor + `## Project-specific` block, score 7) over the
      # 35-line generic folder file (score 0), and migrated it into the folder shape. The
      # report row, written when the target WAS the 35-line generic file, then said
      # `target 35 / pack 83 → REPLACE-OR-ENHANCE`, and this path copied the 83-line pack file
      # over the 98-line one. Result on disk: anchor block gone, `## Project-specific` block
      # gone, `src/services/index.ts`, `src/api_urls.ts` and two more resolving project paths
      # gone. The content-aware twin resolver had just finished proving that file was the one
      # worth keeping.
      #
      # A target carrying a project region the pack source does not have is NOT a blind-replace
      # candidate. It is a merge, and there is a verified merge engine two hundred lines below.
      if grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$tgt" 2>/dev/null \
         && ! grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$pack_src" 2>/dev/null; then
        tgt_has_region=1
      elif grep -qiE '^##[[:space:]]+project-specific' "$tgt" 2>/dev/null \
         && ! grep -qiE '^##[[:space:]]+project-specific' "$pack_src" 2>/dev/null; then
        tgt_has_region=1
      else
        tgt_has_region=0
      fi
      if [[ "$tgt_has_region" -eq 1 ]]; then
        if merge_engine_enabled; then
          echo "  ENGINE  $pack/$kind/$base — the installed file carries a project-specific block the pack source does not."
          echo "          A blind REPLACE would delete it, so this row goes to scripts/merge-decide.py,"
          echo "          which composes it under the invariant and rolls back anything that loses a line."
          delegated=$((delegated + 1))
        else
          # Say WHY, from the state we computed, not from the one cause out of three that
          # this branch used to assume. The old text always blamed the --include list and
          # always prescribed `--include=replace,add,auto-merge` — which on the run that
          # exposed it was already the default, already printed in the header two lines
          # above, and already in effect. The user was sent in a circle.
          echo "  REFUSED $pack/$kind/$base — the installed file carries a project-specific block the pack"
          echo "          source does not, and the merge engine is not running: $MERGE_ENGINE_WHY."
          echo "          Replacing it would delete that block, so this row stays open."
          if [[ "$MERGE_ENGINE_STATE" == "off" ]]; then
            echo "          To let the engine decide it: re-run without --conservative."
          fi
          listed=$((listed + 1))
        fi
        continue
      fi

      # Backup the existing file before replace (safety net). ts/bak_dir are
      # hoisted above the loop so all of this run's backups share one dir.
      # NOTE (M40): $tgt is the shape the project ACTUALLY carries. Replacing a
      # legacy flat skill rewrites `.claude/skills/<name>.md` in place; it never
      # creates `<name>/SKILL.md` beside it. Shape migration is --migrate-skill-shape.
      if [[ "$APPLY" -eq 1 ]]; then
        mkdir -p "$bak_dir"
        rel="${tgt#$TARGET/}"
        bak_path="$bak_dir/$rel"
        mkdir -p "$(dirname "$bak_path")"
        cp "$tgt" "$bak_path"

        mkdir -p "$(dirname "$tgt")"
        cp "$pack_src" "$tgt"
        if [[ "$kind" == "commands" || "$kind" == "agents" ]]; then
          rewrite_deployed_command_links "$tgt"
        else
          rewrite_skill_refs_to_installed_shape "$tgt"
        fi
        echo "  REPLACE $rel  ($rest; backup: $bak_dir/$rel)"
      else
        echo "  would-REPLACE ${tgt#$TARGET/}  ($rest)"
      fi
      applied=$((applied + 1))
      ;;
    MERGE|KEEP-OURS-PLUS-INJECT)
      # Decided per file by the engine, once, after this loop — see § MERGE rows. Counted
      # here so the summary distinguishes "handed to the engine" from "nobody looked at it".
      if merge_engine_enabled; then
        delegated=$((delegated + 1))
      elif [[ "$INCLUDE" == *merge* ]]; then
        echo "  REVIEW  $pack/$kind/$base  ($decision; manual merge required — not auto-applied)"
        listed=$((listed + 1))
      else
        listed=$((listed + 1))
      fi
      ;;
    KEEP-OURS-DEEP|KEEP-OURS-ANCHORED|KEEP-OURS-ADD-SIDE-DOC|IDENTICAL-NO-OP)
      # No action needed
      ;;
    REJECTED-BY-LEDGER|KEEP-OURS-BY-LEDGER|RESOLVED-BY-LEDGER|KEEP-BY-LEDGER)
      # M35: reconciled by the decisions ledger — nothing to do
      ledgered=$((ledgered + 1))
      ;;
    *)
      # Unknown decision; warn
      echo "  WARN unknown decision '$decision' for $pack/$kind/$base"
      ;;
  esac
done

# The engine runs ONCE, after every ADD/REPLACE row has landed, so a file it merges is the
# file this run actually installed. Its own exit code 3 (a write was refused or rolled back)
# is propagated: a run that could not keep its invariant must not report success.
ENGINE_RC=0
if [[ "$delegated" -gt 0 ]] && merge_engine_enabled; then
  run_merge_engine || ENGINE_RC=$?
fi

echo ""
echo "=== summary ==="
echo "Applied (or would-apply): $applied"
echo "MERGE rows → engine:      $delegated"
echo "Listed for human review:  $listed"
echo "Ledger-reconciled:        $ledgered"
echo "Skipped (source missing / already installed in another shape): $skipped"
echo "Skill-shape conflicts (refused): $SHAPE_CONFLICTS"
echo "Command variants installed (M41):  $variants_written"
echo ""

if [[ "$APPLY" -eq 1 && "$applied" -gt 0 ]]; then
  # Only announce a backup that EXISTS. HISTORY: this printed off the `applied` counter, but
  # a pure-ADD run creates no backup (there was no prior file to save), so the message named a
  # directory that had never been created and a user trying to roll back found nothing there.
  # BOTH writers are named. HISTORY: this reported off `$bak_dir` alone and printed "No backup
  # taken — every applied row was an ADD of a file that did not exist" on a run where the merge
  # engine had taken 54 backups and named its own directory four lines earlier. A rollback
  # message that denies the existence of the backups is worse than none.
  eng_bak=$(ls -1dt "$TARGET/.claude/backups/merge-decide-"* 2>/dev/null | head -1 || true)
  if [[ -d "$bak_dir" ]]; then
    echo "Files modified. Backup at: ${bak_dir#$TARGET/}/"
  elif [[ -n "$eng_bak" && -d "$eng_bak" ]]; then
    echo "Files modified. This script's own rows were all ADDs of files that did not exist, so it"
    echo "took no backup; the merge engine backed up every file IT rewrote at ${eng_bak#$TARGET/}/"
  else
    echo "Files modified. No backup taken — every applied row was an ADD of a file that did not exist."
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Run /setup-project anchoring (Phase 4.6) to inject project-specific blocks into the replaced files."
  echo "  2. Re-run scripts/audit-setup.sh to verify Phase 5 audit passes."
fi

[[ "$APPLY" -eq 0 ]] && echo "Dry run — pass --apply to execute."

# M40 post-write guard — filename twins are caught above; this catches a duplicate
# registration whose two files are NOT filename twins. Runs on every invocation,
# dry-run included, so the condition is reported before anyone writes.
shape_rc=0
check_skill_name_uniqueness || shape_rc=1

# ANY non-zero engine exit halts, not just 3. HISTORY: this tested `-eq 3` alone, so an
# engine that CRASHED (uncaught PermissionError on a read-only target — measured 2026-08-23)
# left the wrapper printing its summary and exiting 0. A green run over a partially rewritten
# tree is the single worst outcome this script can produce: it is indistinguishable from a
# good one, so nobody looks. The engine's own contract is 0 = clean, everything else = red.
if [[ "$ENGINE_RC" -eq 3 ]]; then
  echo ""
  echo "HALT (exit 3): the merge engine refused, rolled back or could not complete at least one"
  echo "      write. UNLIKE EXIT 4, THIS DOES NOT MEAN NOTHING HAPPENED — the engine's own"
  echo "      \"Files written\" line above is the count that DID land, and every one of those was"
  echo "      verified after its write and backed up first. What exit 3 means is that at least"
  echo "      one row could not be closed safely:"
  echo "        * refused / rolled back — the composed result would have lost project knowledge."
  echo "          Those rows are DEFER in .claude/_merge-decisions.md; their files are unchanged."
  echo "        * aborted — the run stopped early. The record names the rows that DID complete."
  echo "      Read .claude/_merge-decisions.md, then re-run once the named rows are dealt with."
  echo ""
  echo "      ORCHESTRATOR: this is NOT a stop. CONTINUE to Phase 4.1 (wire-rule-imports.sh) and"
  echo "      Phase 4.6 (apply-anchors.sh). Aborting here leaves the target with pack content"
  echo "      applied, no rule imports and no anchor blocks — strictly worse than either"
  echo "      finishing or never starting. Contract: templates/phases/phase-4.0-preflight.md"
  echo "      § \"Exit-code contract\"."
  exit 3
elif [[ "$ENGINE_RC" -ne 0 ]]; then
  echo ""
  echo "HALT: the merge engine exited $ENGINE_RC (not 0 and not 3). Treat this run as INCOMPLETE:"
  echo "      the engine may have written some files before failing. Check"
  echo "      .claude/_merge-decisions.md and .claude/backups/merge-decide-*/ before re-running."
  exit "$ENGINE_RC"
fi

# HISTORY — this used to be `if SHAPE_CONFLICTS>0 OR shape_rc!=0 then exit 4`, and the second
# half of that condition is a WHOLE-DIRECTORY scan. Any pre-existing duplicate `name:` under
# .claude/skills/ therefore failed the entire run, including every row that had nothing to do
# with it. Measured on a live repo: 3 twins committed 2026-04-19 made this exit 4 on every
# invocation, the printed remedy (--migrate-skill-shape) exited 4 on the same 3 names, and the
# Phase 5 audit then ERRed demanding the apply that could not run — a closed loop that
# installed ZERO pack files for four months. Blast radius is now proportional to blame:
#
#   * SHAPE_CONFLICTS > 0 — a twin BLOCKED A ROW THIS RUN WANTED TO WRITE. Still exit 4;
#     the work genuinely could not be done and reporting success would be a lie.
#   * shape_rc != 0 alone — a pre-existing duplicate that blocked nothing. Loud WARN naming
#     the scripted remedy, and the rows that DID apply are kept. --strict-shape restores the
#     old hard fail for callers that want it.
if [[ "$SHAPE_CONFLICTS" -gt 0 ]]; then
  echo ""
  echo "HALT: a skill-shape conflict blocked $SHAPE_CONFLICTS row(s) this run wanted to write."
  echo "      Resolve them, then re-run. The scripted resolution is content-aware:"
  echo "        apply-study-decisions.sh \"$TARGET\" --resolve-shape-conflicts --apply"
  echo "      It keeps whichever twin carries more project knowledge and archives the other"
  echo "      under .claude/backups/ — do NOT pick by byte size (see § twin_score)."
  exit 4
fi
if [[ "$shape_rc" -ne 0 ]]; then
  echo ""
  echo "WARN: .claude/skills/ carries a duplicate \`name:\` (listed above) that blocked NO row"
  echo "      this run. The rows above were applied. Resolve the duplicate before it does block"
  echo "      one — the scripted, content-aware resolution is:"
  echo "        apply-study-decisions.sh \"$TARGET\" --resolve-shape-conflicts --apply"
  if [[ "$STRICT_SHAPE" -eq 1 ]]; then
    echo ""
    echo "HALT: --strict-shape was passed — treating the pre-existing duplicate as fatal."
    exit 4
  fi
fi
exit 0
