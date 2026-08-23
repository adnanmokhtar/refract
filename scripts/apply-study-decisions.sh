#!/usr/bin/env bash
# apply-study-decisions.sh — deterministic enforcer of study-existing decisions.
#
# Reads <target>/.claude/_study-existing-report.md.
# Applies REPLACE-OR-ENHANCE + ADD rows automatically (replace target file from
# pack source). MERGE + KEEP-OURS-PLUS-INJECT rows are LISTED for human review
# (they need partial / managed-section logic that's safer with human eyes).
#
# Solves: agent's Phase 4 was ignoring study-existing actionable rows under
# --include=<pack> narrow-scope interpretation. This script can't be skipped.
#
# Usage:
#   apply-study-decisions.sh <target-repo> [--apply] [--include=replace,add,merge]
#   apply-study-decisions.sh <target-repo> --migrate-skill-shape [--apply]
#   apply-study-decisions.sh <target-repo> --reject='pack/kind/file.md:rationale'     (repeatable)
#                                          --keep-ours='pack/kind/file.md:rationale'
#                                          --resolve='pack/kind/file.md:note'
#                                          --keep='kind/file.md:rationale'
#
# Default mode: dry-run (lists actions; writes nothing).
# --apply executes.
# --include limits which decision classes to apply (default: replace,add).
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
# Exit codes: 0 ok / 1 target not found / 2 usage / 3 study report missing
#             4 skill-shape conflict (duplicate skill name on disk — nothing written)

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--include=replace,add,merge]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
INCLUDE="replace,add"
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
    --include=*)   INCLUDE="${1#--include=}"; shift ;;
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
        echo "  RESOLVE  $name — kept ${winner#$TARGET/}$([[ "$winner" == "$flat" ]] && echo " (migrated to canonical folder shape)"), archived ${loser#$TARGET/}"
        echo "           reason: $why"
        echo "           archived copy: ${mig_bak#$TARGET/}/resolved-twins/"
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
# ---------- Deterministic ADDITIVE merge (--include=merge-additive) -------------------------
#
# HISTORY — the run's real cost was MERGE rows, and NO script performed any of them. One live
# run measured **171 MERGE rows totalling 14,302 changed lines**, all of which the audit then
# REFUSED the run for not doing, while `--include=replace,add` applied 22 ADD rows in 1.77s and
# printed "Listed for human review: 171". The size distribution says the work is not uniform:
# 38 rows were <=20 changed lines, 45 were 21-60, 60 were 61-150 and 28 were >150.
#
# The tractable, provably-safe subset is the ADDITIVE one: `## ` sections the pack has that the
# target does not. Appending those DELETES NOTHING — the target's own prose, its anchor block
# and any hand-written depth are untouched, so the merge cannot lose project knowledge and C2n
# cannot fire on it. Rows where the pack's new material is not section-shaped, or where the two
# files diverge INSIDE a shared section, still go to a human: they need judgement, and pretending
# otherwise is how a "merge" becomes an overwrite.
#
# Off by default. Opt in with --include=merge-additive.
merge_additive_dryrun_count() {   # $1=pack_src $2=target -> 0 if any section would be added
  local src="$1" tgt="$2" n=0 h
  while IFS= read -r h; do
    [[ -z "$h" ]] && continue
    grep -qF "$h" "$tgt" 2>/dev/null || n=$((n + 1))
  done < <({ grep -E '^## ' "$src" 2>/dev/null || true; } | sed 's/^## //' | sort -u)
  MERGE_ADDED="$n"
  [[ "$n" -gt 0 ]]
}

merge_additive() {                # $1=pack_src $2=target  -> 0 merged, 1 nothing to add
  local src="$1" tgt="$2" added=0 h tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/merge-add.XXXXXX")
  cat "$tgt" > "$tmp"
  while IFS= read -r h; do
    [[ -z "$h" ]] && continue
    # Present in the target already (compare on the heading TEXT, not the whole line)?
    grep -qF "$h" "$tgt" 2>/dev/null && continue
    {
      printf '\n<!-- setup-project:merged-from-pack section=%s -->\n' "$(printf '%s' "$h" | tr ' ' '-')"
      awk -v want="$h" '
        index($0, want) && /^## / { on=1; print; next }
        on && /^## / { exit }
        on { print }
      ' "$src"
      printf '<!-- setup-project:merged-from-pack end -->\n'
    } >> "$tmp"
    added=$((added + 1))
  done < <({ grep -E '^## ' "$src" 2>/dev/null || true; } | sed 's/^## //' | sort -u)
  if [[ "$added" -eq 0 ]]; then rm -f "$tmp"; return 1; fi
  cat "$tmp" > "$tgt"; rm -f "$tmp"
  MERGE_ADDED="$added"
  return 0
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
echo ""

# One backup timestamp/dir per run so a single invocation's rollback set lives
# together (the summary below points at exactly one dir).
ts=$(date +%Y%m%d-%H%M%S)
bak_dir="$TARGET/.claude/backups/study-decisions-$ts"

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
  if [[ "$SHAPE_VERDICT" == "twin" ]]; then
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
        echo "  ADD     $pack/$kind/$base → $(basename "$tgt_dir")/$(basename "$tgt")"
      else
        echo "  would-ADD $pack/$kind/$base → $(basename "$tgt_dir")/$(basename "$tgt")"
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
      [[ "$INCLUDE" == *merge* ]] || { listed=$((listed + 1)); continue; }
      # Additive subset only, and only when explicitly asked for. See § merge_additive.
      if [[ "$INCLUDE" == *merge-additive* && "$decision" == "MERGE" && -f "$pack_src" && -f "$tgt" ]]; then
        if [[ "$APPLY" -eq 1 ]]; then
          rel="${tgt#$TARGET/}"
          mkdir -p "$bak_dir/$(dirname "$rel")"
          cp "$tgt" "$bak_dir/$rel"
          if merge_additive "$pack_src" "$tgt"; then
            if [[ "$kind" == "commands" || "$kind" == "agents" ]]; then
              rewrite_deployed_command_links "$tgt"
            else
              rewrite_skill_refs_to_installed_shape "$tgt"
            fi
            echo "  MERGE+  $rel  ($MERGE_ADDED pack section(s) appended, nothing removed; backup: $bak_dir/$rel)"
            applied=$((applied + 1)); continue
          fi
          rm -f "$bak_dir/$rel"
        else
          if merge_additive_dryrun_count "$pack_src" "$tgt"; then
            echo "  would-MERGE+ $pack/$kind/$base  ($MERGE_ADDED pack section(s) the target lacks — additive, nothing removed)"
            applied=$((applied + 1)); continue
          fi
        fi
      fi
      echo "  REVIEW  $pack/$kind/$base  ($decision; manual merge required — not auto-applied)"
      listed=$((listed + 1))
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

echo ""
echo "=== summary ==="
echo "Applied (or would-apply): $applied"
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
  if [[ -d "$bak_dir" ]]; then
    echo "Files modified. Backup at: ${bak_dir#$TARGET/}/"
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
