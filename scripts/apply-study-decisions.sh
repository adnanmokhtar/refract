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
  migrated=0; mig_conflicts=0
  while IFS= read -r flat; do
    [[ -f "$flat" ]] || continue
    name="$(basename "$flat" .md)"
    folder="$SKILLS_DIR/$name/SKILL.md"
    if [[ -f "$folder" ]]; then
      echo "  CONFLICT $name — both .claude/skills/$name.md and .claude/skills/$name/SKILL.md exist. Pick the winner by hand, delete the other, then re-run."
      mig_conflicts=$(( mig_conflicts + 1 ))
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
        echo "  SHAPE-SKIP $pack/$kind/$base — already present at ${SHAPE_PATH#$TARGET/}; ADD row is stale (re-run study-existing.sh)."
        skipped=$((skipped + 1)); continue
      fi
      if [[ "$APPLY" -eq 1 ]]; then
        # dirname, not $tgt_dir: an Agent Skills row carries a `<name>/SKILL.md` base, so
        # the per-skill subdir must exist too or the cp fails with ENOENT.
        mkdir -p "$(dirname "$tgt")"
        cp "$pack_src" "$tgt"
        [[ "$kind" == "commands" || "$kind" == "agents" ]] && rewrite_deployed_command_links "$tgt"
        echo "  ADD     $pack/$kind/$base → $(basename "$tgt_dir")/$base"
      else
        echo "  would-ADD $pack/$kind/$base → $(basename "$tgt_dir")/$base"
      fi
      applied=$((applied + 1))
      ;;
    REPLACE-OR-ENHANCE)
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
        [[ "$kind" == "commands" || "$kind" == "agents" ]] && rewrite_deployed_command_links "$tgt"
        echo "  REPLACE $rel  ($rest; backup: $bak_dir/$rel)"
      else
        echo "  would-REPLACE ${tgt#$TARGET/}  ($rest)"
      fi
      applied=$((applied + 1))
      ;;
    MERGE|KEEP-OURS-PLUS-INJECT)
      [[ "$INCLUDE" == *merge* ]] || { listed=$((listed + 1)); continue; }
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
echo ""

if [[ "$APPLY" -eq 1 && "$applied" -gt 0 ]]; then
  echo "Files modified. Backup at: ${bak_dir#$TARGET/}/"
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
if [[ "$SHAPE_CONFLICTS" -gt 0 || "$shape_rc" -ne 0 ]]; then
  echo ""
  echo "HALT: skill-shape conflict — the same skill is registered twice. Fix the duplicate"
  echo "      (keep ONE file per skill name), then re-run. Migration off the legacy flat"
  echo "      shape is: apply-study-decisions.sh \"$TARGET\" --migrate-skill-shape --apply"
  exit 4
fi
exit 0
