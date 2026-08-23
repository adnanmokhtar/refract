#!/usr/bin/env bash
# study-existing.sh — per-file deep comparison of target's existing setup vs pack equivalents.
#
# Solves the third bug: the agent runs REFRESH/REFINE/ENHANCE and only ADDS missing files.
# It does NOT compare existing files against pack equivalents to decide what should be
# ENHANCED (deepen/improve), ALIGNED (re-anchor to project), or DELETED (deprecated).
#
# This script does the comparison in shell, applies Appendix C merge matrix
# deterministically, and writes a proposal report. Phase 4 must consume the proposals.
#
# Usage:
#   study-existing.sh <target-repo> [pack1 pack2 ...] [--stdout | --report=<path>]
#
# Output: <target>/.claude/_study-existing-report.md
#   --stdout        READ-ONLY mode (alias: --no-write). Report goes to stdout and NOTHING
#                   is created under <target-repo> — not the report, not `.claude/`.
#                   The only way to study a repo you are not permitted to modify.
#   --report=<path> Write the report to <path> instead. Must use `=`; the space form
#                   `--report <path>` is refused rather than parsed as a pack name.
# Properties: deterministic; idempotent; read-only on the target's actual artifacts —
#   and, under --stdout, read-only on the target FULL STOP.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [pack1 pack2 ...] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# Sink flags are filtered out of "$@" here; everything left is a pack name (read at
# `PACKS=("$@")` below), so the two argument families cannot collide.
SINK_STDOUT=0
REPORT_OVERRIDE=""
_sx_args=()
for _a in ${@+"$@"}; do
  case "$_a" in
    --stdout|--no-write) SINK_STDOUT=1 ;;
    --report=*)          REPORT_OVERRIDE="${_a#*=}" ;;
    --report)            echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *)                   _sx_args+=("$_a") ;;
  esac
done
set -- ${_sx_args[@]+"${_sx_args[@]}"}

# ── Report sink ───────────────────────
# The header above has always promised "read-only on the target's actual artifacts",
# and that was true of the artifacts and false of the repo: the report itself landed
# inside it, and the mkdir created `.claude/` in a target that had none. Observed
# 2026-08-22: this script regenerated its report inside a declared read-only target
# purely because someone ran it to verify a fix — the verification WAS the write.
REPORT="$TARGET/.claude/_study-existing-report.md"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/study-existing-report.XXXXXX")
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# M35 — durable decisions ledger. Rows recorded here are reconciled instead of
# re-proposed on every run (the "95 rows again every refresh" failure mode).
# Refresh's aim: keep what must be kept, change what must change, add the new —
# WITHOUT re-litigating every kept row each run. Verbs encode exactly that:
#   - `pack/kind/file.md` → REJECTED (YYYY-MM-DD) — rationale            (permanent: artifact class is wrong for this project)
#   - `pack/kind/file.md` → KEEP-OURS (YYYY-MM-DD, pack@sha8) — why ours wins   (re-opens when pack source changes)
#   - `pack/kind/file.md` → RESOLVED (YYYY-MM-DD, pack@sha8) — how merged       (re-opens when pack source changes)
#   - `kind/file.md` → KEEP (YYYY-MM-DD) — rationale                     (project-only orphan keeper)
SELF_DIR_PK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LEDGER="$TARGET/.claude/_refresh-decisions.md"
# ---------- PROJECT_KIND applicability filter --------------------------------------------
# See templates/packs/_project-kind.md. A pack artifact may declare `project_kind:` in its
# frontmatter; a row whose declared kind is not one this target HAS is declined, not missing.
# Measured motivation: 49,450 bytes (17.6% of one run's installs) of Core Web Vitals / bundle /
# INP content landed on a NestJS service with zero `.vue` and zero `.tsx` files, because track
# selection is per-folder and had no artifact-level filter.
TARGET_KINDS="$(bash "$SELF_DIR_PK/detect-project-kind.sh" "$TARGET" 2>/dev/null || echo any)"

# Declared kind of a pack artifact ("" when the key is absent → applies to any kind).
artifact_project_kind() {
  awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^project_kind:[[:space:]]*/ {
         sub(/^project_kind:[[:space:]]*/,""); sub(/[[:space:]]*#.*$/,""); gsub(/["'"'"']/,"");
         print; exit }' "$1" 2>/dev/null
}

# 0 = applies here, 1 = declined for project kind. Sets KIND_DECLINE_REASON on a decline.
artifact_applies_to_target() {
  local f="$1" want
  KIND_DECLINE_REASON=""
  want="$(artifact_project_kind "$f")"
  [[ -z "$want" || "$want" == "any" ]] && return 0
  # An undetectable repo matches everything — trading one silent wrong for another is not a fix.
  [[ "$TARGET_KINDS" == "any" ]] && return 0
  case " $TARGET_KINDS " in
    *" $want "*) return 0 ;;
  esac
  KIND_DECLINE_REASON="declares project_kind: $want; this target is [$TARGET_KINDS]"
  return 1
}


# ledger_lookup <key> → prints "VERB|date|sha8|rationale" (sha8 empty unless stamped). Empty if no entry.
#
# SHAPE-INDEPENDENT KEY. HISTORY — the ledger stores one line per `pack/kind/file.md`, and
# the packs migrated their skills from the flat `skills/<name>.md` shape to the canonical
# Agent Skills `skills/<name>/SKILL.md` folder shape. The key changed with the shape, so
# every recorded decision about a skill was ORPHANED: the lookup missed, and the row came
# back as if no human had ever ruled on it. Measured on a live repo: 29 of 35 "Missing" rows
# were folder-shape skills whose flat-shape ledger line said REJECTED — including an entire
# ui-ux skill set the owner declined by name to avoid colliding with their own tooling. The
# ledger's own contract is "REJECTED / KEEP are permanent until a human deletes the line";
# a rename of the file shape is not a human deleting the line.
#
# So the key is normalised to the artifact IDENTITY before lookup, and BOTH spellings are
# tried. A decision recorded under either shape reconciles a row proposed under either shape.
ledger_lookup() {
  local key="$1" line verb ldate sha why alt
  [[ -f "$LEDGER" ]] || return 0
  # The other legal spelling of the same artifact.
  case "$key" in
    */skills/*/SKILL.md) alt="${key%/SKILL.md}.md" ;;
    */skills/*.md)       alt="${key%.md}/SKILL.md" ;;
    skills/*/SKILL.md)   alt="${key%/SKILL.md}.md" ;;
    skills/*.md)         alt="${key%.md}/SKILL.md" ;;
    *)                   alt="" ;;
  esac
  line=$(grep -F "\`$key\`" "$LEDGER" 2>/dev/null | grep -E '→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(' | tail -1 || true)
  if [[ -z "$line" && -n "$alt" ]]; then
    line=$(grep -F "\`$alt\`" "$LEDGER" 2>/dev/null | grep -E '→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(' | tail -1 || true)
  fi
  [[ -z "$line" ]] && return 0
  verb=$(echo "$line" | sed -E 's/^.*→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(.*/\1/')
  ldate=$(echo "$line" | sed -E 's/^.*\(([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  sha=$(echo "$line" | sed -nE 's/^.*pack@([0-9a-f]{8}).*/\1/p')
  why="${line#*— }"   # text after the first " — " separator (byte-safe vs sed multibyte classes)
  printf '%s|%s|%s|%s' "$verb" "$ldate" "$sha" "$why"
}

pack_sha8() { shasum "$1" 2>/dev/null | cut -c1-8; }

# SUBSTANTIVE hash — what a ledger decision is actually ABOUT.
#
# HISTORY. Ledger staleness was keyed on the raw file sha, so ANY edit to a pack file re-opened
# every recorded decision about it. Measured on one consumer repo: **131 previously-settled
# ledger entries auto-re-opened in a single run**, and the mechanism guarantees it repeats — a
# framework release that only reflows prose, fixes a typo, or re-stamps a version line re-opens
# ~131 decisions in EVERY consumer repo, each of which a human then has to re-adjudicate by
# hand. A decision-ledger that resets itself on cosmetic churn is not durable, and the cost is
# paid per repo per release.
#
# So staleness is measured on the content a decision could plausibly turn on: prose and code,
# with frontmatter, the generated anchor block, blank lines, trailing whitespace and pure
# markdown-emphasis churn removed. A pack edit that changes none of that leaves the decision
# standing. `pack_sha8` is kept for the report, so a reader still sees the raw file changed.
pack_substantive_sha8() {
  awk '
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm { if (/^---[[:space:]]*$/) fm=0; next }
    /^<!-- project-specific:start -->[[:space:]]*$/ { anc=1; next }
    anc { if (/^<!-- project-specific:end -->[[:space:]]*$/) anc=0; next }
    { print }
  ' "$1" 2>/dev/null \
    | sed -E 's/[[:space:]]+$//; s/[*_`]//g' \
    | grep -v '^[[:space:]]*$' \
    | shasum 2>/dev/null | cut -c1-8
}

# apply-study-decisions.sh rewrites snippet/governance links on deploy
# (../../../snippets/ → ../templates/snippets/). Compare against the DEPLOYED
# shape, or every applied command re-flags as MERGE forever (false drift).
NORM_TMP=""
normalized_src() {
  local src="$1" kind="$2"
  if [[ "$kind" != "commands" && "$kind" != "agents" ]] || ! command -v perl >/dev/null 2>&1; then
    printf '%s' "$src"; return
  fi
  [[ -z "$NORM_TMP" ]] && NORM_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-norm.XXXXXX")
  local out="$NORM_TMP/$(basename "$src")"
  perl -pe 's{\]\(\.\./\.\./\.\./snippets/}{](../templates/snippets/}g; s{\]\(\.\./\.\./\.\./governance/}{](../templates/governance/}g' "$src" > "$out" 2>/dev/null || { printf '%s' "$src"; return; }
  printf '%s' "$out"
}

# Phase 4.6 (apply-anchors.sh) injects the canonical
# `<!-- project-specific:start --> ... :end -->` block (+ one trailing blank
# line) into every deployed artifact. That block does NOT exist in the pack
# source, so comparing the raw target against the pack counts the anchor as
# ~15 lines of "difference" — a file that is EXACTLY pack-content + anchor then
# re-flags as MERGE on every refresh forever (phantom drift; observed 2026-07-09).
# Strip the anchor block (and the single blank line the injection appends) so the
# comparison sees only the pack-derived content.
STRIP_TMP=""
stripped_target() {
  local tgt="$1"
  if ! grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$tgt" 2>/dev/null; then
    printf '%s' "$tgt"; return
  fi
  [[ -z "$STRIP_TMP" ]] && STRIP_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-strip.XXXXXX")
  local out="$STRIP_TMP/$(basename "$tgt")"
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
    skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) { skip=0; drop_blank=1 } next }
    drop_blank && /^[[:space:]]*$/ { drop_blank=0; next }
    { drop_blank=0; print }
  ' "$tgt" > "$out" 2>/dev/null || { printf '%s' "$tgt"; return; }
  printf '%s' "$out"
}

# ---------- Project-knowledge signal (M36) ------------------------------------
# A SHORTER FILE IS NOT A WORSE FILE. The size ratio measures depth against the
# pack; it cannot see that a target's 54 lines are the ONLY written record of this
# repo's tenant-resolution chain. Observed 2026-08-22 against a real 8,151-file
# project: three hand-authored files were classified REPLACE-OR-ENHANCE on the
# ratio alone and overwritten with generic pack text —
#   ai/patterns/multi-tenancy.md        54/124 = 43%  project identifiers  9 -> 0
#   ai/patterns/error-handling.md      172/387 = 44%  project identifiers 18 -> 0
#   .claude/skills/endpoint-test/SKILL.md 39/152 = 25% project identifiers 2 -> 0
# The destroyed multi-tenancy.md documented a real 6-step `DomainMiddleware`
# chain resolving from `X-Product-Id` / `X-API-Key`; the generic replacement
# asserts a bare tenant header "MUST NOT be a resolution input". Pack prose is
# regenerable from the pack; those identifiers are not regenerable from anything.
# So project knowledge DOMINATES the length heuristic.
#
# TWO MEASURED signals, either of which marks a file unregenerable:
#   1. a real project file path the pack does not contain
#      (`libs/shared/src/services/context.service.ts`,
#      `apps/**/infrastructure/controllers/**/*.ts`);
#   2. project code identifiers the pack does not contain (`DomainMiddleware`,
#      `X-Product-Id`, `CORE_TOKENS.REQUEST_CONTEXT`, `tenant_id`).
# endpoint-test/SKILL.md carried NO anchor and was still pure project knowledge
# (ports 4000/4001, `apps/master/src/`, `bun run start:dev-tenant`) — these two
# signals are what caught it.
#
# THE ANCHOR IS NOT A THIRD SIGNAL. `<!-- project-specific:start -->` is written
# by `scripts/apply-anchors.sh` into EVERY deployed pack artifact (observed on a
# real target: `Already anchored (skipped): 234`), and the block it writes says
# of itself "auto-generated, regenerate with `/setup-project --refine`". A marker
# the framework wrote, holding bytes the framework can rewrite, is not evidence
# that the target holds anything a pack cannot regenerate. It was briefly used as
# a sole trigger and that made REPLACE-OR-ENHANCE unreachable for every anchored
# artifact: a 41-line truncated copy of this 394-line pack file, 0 foreign paths
# and 0 foreign identifiers, was "protected" and became a manual MERGE the C2k
# gate then demanded be closed. `has_anchor` is therefore carried into the reason
# only as CORROBORATION — it is appended to a reason signals 1/2 already earned,
# and never manufactures one. (Its verdict role is elsewhere and unchanged: it
# separates KEEP-OURS-ANCHORED from KEEP-OURS-PLUS-INJECT above ratio 130.)
#
# "Foreign" means present in the target and absent from the pack source — i.e.
# precisely the bytes a replace deletes and no pack can put back. Measuring
# against the pack (rather than an absolute count) is what keeps a genuine
# shallow stub — a truncated copy of the pack itself — unprotected. That
# invariant is only true while the anchor stays out of the trigger set.
KNOW_SRC_EXT='ts|tsx|js|jsx|mjs|cjs|vue|svelte|py|go|rb|php|java|kt|kts|swift|scala|rs|cs|cpp|hpp|ex|exs|dart|sql|prisma|graphql|proto|tf|yaml|yml|json|toml|env|sh|md|css|scss|html'
KNOW_PATH_RE="[A-Za-z0-9_@.*-]+(/[A-Za-z0-9_@.*-]+)+\.($KNOW_SRC_EXT)"
# CamelCase | SCREAMING_SNAKE | snake_case | Header-Case | dotted.member —
# the shapes a code symbol takes and prose does not. Deliberately NOT restricted
# to backticked spans: the path in `Context` (libs/shared/src/services/context.service.ts)
# is unbackticked, and the ServiceLocator identifiers live inside a fenced block.
KNOW_IDENT_RE='[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*|[A-Z][A-Z0-9]*_[A-Z0-9_]+|[a-z][a-z0-9]*_[a-z0-9_]+|[A-Z][A-Za-z0-9]*(-[A-Z][A-Za-z0-9]*)+|[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]+'

# know_tokens <file> <regex> → distinct matches, one per line, LC_ALL=C-sorted
# so `comm` can set-difference them. Same helper name and semantics as
# audit-setup.sh's C2n, so the classifier and the gate agree by construction.
know_tokens() { grep -ohE "$2" "$1" 2>/dev/null | sort -u || true; }

# count_foreign <target> <pack> <regex> → count of DISTINCT matches absent from pack.
# Set difference, not a per-token `grep -qF` over the pack: this runs once per
# compared file on a 23-pack scan (~250 files), and the substring form cost one
# grep process per token — thousands per run.
count_foreign() {
  local tgt="$1" pack="$2" re="$3" n
  n=$(comm -23 <(know_tokens "$tgt" "$re") <(know_tokens "$pack" "$re") | grep -c . || true)
  printf '%s' "${n:-0}"
}

# project_knowledge_reason <target> <pack> <has_anchor> → human-readable reason,
# empty when the target carries nothing the pack could not regenerate.
project_knowledge_reason() {
  local tgt="$1" pack="$2" has_anchor="${3:-0}" fpaths fidents parts=""
  fpaths=$(count_foreign "$tgt" "$pack" "$KNOW_PATH_RE")
  fidents=$(count_foreign "$tgt" "$pack" "$KNOW_IDENT_RE")
  # One real project path is decisive on its own (endpoint-test/SKILL.md had
  # exactly 2 and zero foreign identifiers). Identifiers need 3 so that a stray
  # CamelCase word in an otherwise generic stub does not freeze it.
  [[ "$fpaths" -ge 1 ]] && parts="$fpaths project path(s) absent from pack"
  [[ "$fidents" -ge 3 ]] && parts="${parts:+$parts, }$fidents project identifier(s) absent from pack"
  # Corroboration only — see the M36 note above. `parts` must already be
  # non-empty, so the anchor can never be the reason a file is protected.
  [[ -n "$parts" && "$has_anchor" == "1" ]] && parts="$parts, corroborated by the project-specific anchor"
  printf '%s' "$parts"
}

PACKS=("$@")
if [[ ${#PACKS[@]} -eq 0 ]]; then
  # Auto-detect installed packs from target's codebase-profile.md if present.
  # Fall back to scanning ALL packs (so the report is never empty for projects
  # that don't have a tracks_selected line — the historic bug).
  if [[ -f "$TARGET/.claude/codebase-profile.md" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] && PACKS+=("$p")
    done < <(grep -E '^[[:space:]]*-?[[:space:]]*track:' "$TARGET/.claude/codebase-profile.md" 2>/dev/null \
             | sed -E 's/.*track:[[:space:]]+([a-z0-9-]+).*/\1/' | sort -u)
  fi
  if [[ ${#PACKS[@]} -eq 0 ]]; then
    # No tracks declared — scan ALL packs. The user's project may have
    # commands/agents from packs that aren't recorded in the profile.
    # Try find first; some sandboxes restrict find traversal even when ls
    # works, so fall back to a bash glob if find returns nothing.
    while IFS= read -r d; do
      name="$(basename "$d")"
      [[ "$name" == _* ]] && continue
      PACKS+=("$name")
    done < <(find -L "$PACKS_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    if [[ ${#PACKS[@]} -eq 0 ]]; then
      for d in "$PACKS_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        [[ "$name" == _* ]] && continue
        [[ "$name" == "*" ]] && continue
        PACKS+=("$name")
      done
    fi
  fi
fi
# bash 3.2 (macOS default) treats `${arr[*]}` on an empty array as unbound under
# set -u — guard the trace line so it never crashes the preflight.
if [[ ${#PACKS[@]} -gt 0 ]]; then
  echo "Scanning packs: ${PACKS[*]}" >&2
else
  echo "Scanning packs: (none — neither codebase-profile track: lines nor $PACKS_ROOT scan yielded packs)" >&2
  echo "ERR: cannot proceed with zero packs. Pass packs as args, or check $PACKS_ROOT exists and is readable." >&2
  exit 1
fi

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

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md   (Agent Skills convention; pack skills use this)
# Emits FULL paths so callers can derive the pack-relative suffix (`${p#"$dir"/}`) —
# that suffix is the artifact identity for both forms, and is what keeps source rows,
# union keys and target paths 1:1. `_*`-prefixed artifacts are filtered by the caller's
# existing prefix guard, which sees `_name.md` or `_name/SKILL.md` alike.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# Canonical, form-independent artifact identity:
#   foo.md        -> foo.md
#   foo/SKILL.md  -> foo.md
# Lets the two on-disk forms of the SAME artifact compare equal. Without it, a target
# still on flat form would be misreported as a project-only orphan the moment the pack
# moved to dir-form (and a dir-form target likewise, against an older flat pack).
artifact_identity() {
  case "$1" in
    */SKILL.md) local d="${1%/SKILL.md}"; echo "${d##*/}.md" ;;
    *)          echo "${1##*/}" ;;
  esac
}

# ---------- Shape-aware TARGET resolution (M40) ----------
# `artifact_identity` above already makes the two skill shapes compare equal for
# the ORPHAN pass. The per-row pass did not use it: it resolved the target by
# PATH (`$tgt_dir/$base`), so a pack `skills/<n>/SKILL.md` never looked for the
# project's legacy `skills/<n>.md` and emitted `**ADD**` for a skill that is
# installed. That row is UNCLOSABLE: `apply-study-decisions.sh --apply` correctly
# SHAPE-SKIPs it (copying would create a same-`name:` twin), the next
# regeneration prints the same `**ADD**`, and audit-setup.sh C2k — which gates
# Phase 5 on `Files with action needed: 0` and whose remediation is exactly that
# no-op apply — can never go green. 3 such rows on the observed real target, up
# to 59 on a project that never migrated. `pack-coverage-scan.sh` resolves by
# identity and phase-4.2-apply.md states presence is resolved by identity; this
# is the same resolution, so all three agree.
#
# Sets three globals (no command substitution: a `return 1` inside `$(…)` is
# swallowed by the assignment and this file runs under `set -e`):
#   SHAPE_TGT   full path of the installed artifact, "" when genuinely absent
#   SHAPE_FORM  canonical | legacy-flat | ""
#   SHAPE_TWIN  non-empty ONLY when BOTH shapes exist — a duplicate-`name:` twin
resolve_target_artifact() {  # <kind> <tgt_dir> <pack-relative-base>
  local kind="$1" tgt_dir="$2" base="$3" name folder flat
  SHAPE_TGT=""; SHAPE_FORM=""; SHAPE_TWIN=""

  # Every non-skill kind has exactly one legal shape — resolve by path, as before.
  if [[ "$kind" != "skills" ]]; then
    [[ -f "$tgt_dir/$base" ]] && { SHAPE_TGT="$tgt_dir/$base"; SHAPE_FORM="canonical"; }
    return 0
  fi

  name="$(artifact_identity "$base")"; name="${name%.md}"
  folder="$tgt_dir/$name/SKILL.md"
  flat="$tgt_dir/$name.md"

  if [[ -f "$folder" && -f "$flat" ]]; then
    SHAPE_TGT="$folder"; SHAPE_FORM="canonical"; SHAPE_TWIN="$flat"
  elif [[ -f "$folder" ]]; then
    SHAPE_TGT="$folder"; SHAPE_FORM="canonical"
  elif [[ -f "$flat" ]]; then
    SHAPE_TGT="$flat";   SHAPE_FORM="legacy-flat"
  fi
  return 0
}

# Appendix C decision based on size ratio (target/pack) + byte-identity check.
# Codifies "Same name overlap" rules in shell so the agent can't override.
decide() {
  # 4 args, all REQUIRED. `has_knowledge` used to default to 0, so a future
  # caller that forgot it would silently drop the whole M36 protection and go
  # back to overwriting hand-authored files on the size ratio alone. Fail loud.
  if [[ $# -lt 4 ]]; then
    # Loud on BOTH channels. `exit` inside `$(…)` only kills the subshell (the
    # same bash trap the shape resolver above avoids), so stderr alone could be
    # lost in a piped preflight; the sentinel verdict makes the report itself
    # unusable rather than quietly ratio-only.
    echo "INTERNAL ERROR: decide() needs 4 args (target pack has_anchor has_knowledge), got $#" >&2
    echo "ERROR-DECIDE-ARITY"
    exit 2
  fi
  local target_path="$1" pack_path="$2" has_anchor="$3" has_knowledge="$4"
  local target_size pack_size
  target_size=$(wc -l < "$target_path" | tr -d ' ')
  pack_size=$(wc -l < "$pack_path" | tr -d ' ')

  if [[ "$pack_size" -eq 0 ]]; then echo "ERROR_DIVZERO"; return; fi

  # Byte-identical = no work needed (Phase 4.6 will still anchor project-specific block separately).
  # `diff -q` alone would report the trailing blank the anchor strip may leave; -w -B
  # makes an adopted-then-anchored file compare equal to its pack source (no phantom MERGE).
  if cmp -s "$target_path" "$pack_path" || diff -q -w -B "$target_path" "$pack_path" >/dev/null 2>&1; then
    echo "IDENTICAL-NO-OP"
    return
  fi

  local ratio=$(( target_size * 100 / pack_size ))

  # M36 — PROJECT KNOWLEDGE DOMINATES THE RATIO, and this test is hoisted ABOVE
  # the whole ladder so no future ladder edit can slip past it. REPLACE-OR-ENHANCE
  # is the only verdict below that discards target bytes (apply-study-decisions.sh
  # copies the pack over the file; MERGE and every KEEP-OURS-* verdict are listed
  # for review and never auto-applied). It is never correct for a file whose
  # content the pack cannot regenerate, at ANY ratio. Downgrade to MERGE: still
  # actionable — Phase 4 must bring the pack's depth in — but merged INTO the
  # file rather than pasted OVER it.
  if [[ "$has_knowledge" == "1" && $ratio -lt 50 ]]; then
    echo "MERGE"
    return
  fi

  # DELIBERATE PACK TRIM — the case the ratio ladder below cannot see.
  #
  # HISTORY. The ladder reads "target is bigger than pack" as "target is richer" and keeps the
  # target, permanently. That makes a deliberate SHRINK of a pack rule structurally incapable
  # of reaching any existing project: the smaller the pack gets, the higher the ratio climbs,
  # and the more certainly the fat old copy is preserved. Measured after a rule-shrink
  # programme: all 15 pack rules overlapping one live repo were LARGER on disk than the current
  # pack source — 141,393 B on disk vs 93,406 B in the packs, ~12,000 tokens of shrink stranded
  # — and this engine's own report explained why, twelve times over:
  #     "backend-principles.md — target 102 / pack 70 lines -> KEEP-OURS-ANCHORED"
  # A KEEP-OURS is permanent, so those twelve would never be re-proposed. The mirror failure
  # showed up in the other repo: a rule that had been ENLARGED in the pack sat on disk in its
  # thinner old form and never received the richer version either.
  #
  # The distinguishing fact is not size, it is PROVENANCE. `has_knowledge` is already computed
  # by the caller with the same predicate C2n uses: does the target carry ≥1 resolving project
  # path or ≥3 code identifiers OUTSIDE its anchor block? If it does not, the target is pack
  # prose plus a generated anchor — there is nothing project-specific to protect, and a smaller
  # pack file is a deliberate editorial decision the project has no reason to resist. If it
  # does, the ladder below still protects it, unchanged.
  if [[ "$has_knowledge" != "1" && $ratio -ge 130 ]]; then
    echo "ADOPT-PACK-TRIM"
    return
  fi

  if [[ $ratio -ge 200 ]]; then
    echo "KEEP-OURS-DEEP"
  elif [[ $ratio -ge 130 ]]; then
    # "target deeper but MISSING project-specific anchor → inject" is the whole
    # point of KEEP-OURS-PLUS-INJECT. When the anchor is ALREADY present the
    # inject is a no-op, so this is a non-actionable keeper — flagging it
    # actionable is a false positive (deeper+anchored files re-flagged every run
    # until a ledger row lands; observed 2026-07-14).
    if [[ "$has_anchor" == "1" ]]; then echo "KEEP-OURS-ANCHORED"; else echo "KEEP-OURS-PLUS-INJECT"; fi
  elif [[ $ratio -ge 70 ]]; then
    echo "MERGE"
  elif [[ $ratio -ge 50 ]]; then
    echo "KEEP-OURS-ADD-SIDE-DOC"
  else
    echo "REPLACE-OR-ENHANCE"
  fi
}

# ---------- Build report ----------
{
  printf '# Study-existing report — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/study-existing.sh\n\n'
  printf '> **MANDATORY for REFRESH / REFINE / ENHANCE.** Per-file decisions derived from Appendix C merge matrix. Phase 4 MUST address every row marked REPLACE-OR-ENHANCE / KEEP-OURS-PLUS-INJECT / MERGE before declaring success. Phase 5 audit FAILS the run if any actionable row was silently ignored.\n\n'
  printf -- '---\n\n'

  total_act=0
  total_keep=0
  total_missing=0
  total_orphan=0
  total_ledger=0
  total_reopened=0

  # Union of pack basenames per kind — used after the loop to report each
  # project-only orphan ONCE (previously each orphan re-appeared under every
  # scanned pack: ~80 orphans × ~23 packs = ~1600 noise rows).
  UNION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-union.XXXXXX")
  trap 'rm -rf "$UNION_TMP" ${NORM_TMP:+"$NORM_TMP"} ${REPORT_TMP:+"$REPORT_TMP"}' EXIT

  for pack in "${PACKS[@]}"; do
    pack_dir="$PACKS_ROOT/$pack"
    [[ -d "$pack_dir" ]] || continue

    pack_section=""
    pack_actionable=0

    for kind in commands agents skills rules ai-patterns; do
      kind_dir="$pack_dir/$kind"
      [[ -d "$kind_dir" ]] || continue

      tgt_dir="$(target_dir_for_kind "$kind")"
      [[ -d "$tgt_dir" ]] || continue

      kind_rows=""
      while IFS= read -r src; do
        # Agent Skills dir-form (`<name>/SKILL.md`) keeps its pack-relative suffix, so the
        # report row, the union key and the target path stay 1:1 with the source. Flat
        # `<name>.md` artifacts are unaffected — the suffix IS the basename for them.
        base="${src#"$kind_dir"/}"
        [[ "$base" == _* ]] && continue
        artifact_identity "$base" >> "$UNION_TMP/$kind"
        # Presence is resolved by IDENTITY, not by path — see resolve_target_artifact.
        resolve_target_artifact "$kind" "$tgt_dir" "$base"
        tgt="$SHAPE_TGT"

        # M35: a ledger entry reconciles this row unless the pack source changed
        # since the decision was stamped (content hash, not mtime).
        ledger_entry="$(ledger_lookup "$pack/$kind/$base")"
        if [[ -n "$ledger_entry" ]]; then
          IFS='|' read -r lverb ldate lsha lwhy <<<"$ledger_entry"
          cur_sha="$(pack_substantive_sha8 "$src")"
          cur_raw_sha="$(pack_sha8 "$src")"
          if [[ "$lverb" == "REJECTED" ]]; then
            kind_rows+=$'\n'"  - \`$base\` — → **REJECTED-BY-LEDGER** — $lwhy ($ldate)"
            total_ledger=$(( total_ledger + 1 ))
            continue
          elif [[ "$lverb" == "KEEP-OURS" || "$lverb" == "RESOLVED" ]]; then
            if [[ -n "$lsha" && "$lsha" == "$cur_sha" ]]; then
              kind_rows+=$'\n'"  - \`$base\` — → **${lverb}-BY-LEDGER** — $lwhy ($ldate, pack@$lsha)"
              total_ledger=$(( total_ledger + 1 ))
              continue
            fi
            # Pack source changed since the decision → re-open for re-audit.
            kind_rows+=$'\n'"  - \`$base\` — ledger $lverb ($ldate) is STALE: pack content changed pack@${lsha:-?}→pack@$cur_sha (raw file now $cur_raw_sha) — re-opened below"
            total_reopened=$(( total_reopened + 1 ))
          fi
        fi

        if [[ -n "$tgt" && -f "$tgt" ]]; then
          cmp_src="$(normalized_src "$src" "$kind")"
          # Compare against the anchor-stripped target so the Phase 4.6
          # project-specific block never inflates the diff into phantom MERGE.
          cmp_tgt="$(stripped_target "$tgt")"
          src_lines=$(wc -l < "$cmp_src" | tr -d ' ')
          tgt_lines=$(wc -l < "$cmp_tgt" | tr -d ' ')
          # Anchor presence gates the KEEP-OURS-PLUS-INJECT ("inject the anchor")
          # verdict — a deeper file that already carries the marker needs no inject.
          has_anchor=0
          grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$tgt" 2>/dev/null && has_anchor=1
          # M36 — project knowledge outranks the size ratio. Measured on the
          # anchor-STRIPPED target so the auto-generated block (regenerable by
          # apply-anchors.sh) never counts as hand-authored knowledge; the anchor's
          # mere presence is carried separately as has_anchor.
          know_reason="$(project_knowledge_reason "$cmp_tgt" "$cmp_src" "$has_anchor")"
          has_knowledge=0
          [[ -n "$know_reason" ]] && has_knowledge=1
          decision=$(decide "$cmp_tgt" "$cmp_src" "$has_anchor" "$has_knowledge")
          # Annotate ONLY the rows the protection actually rescued, so the agent
          # reading the report knows this MERGE must not be resolved by replacing.
          # No `**UPPERCASE**` in the note: apply-study-decisions.sh reads the LAST
          # bold-caps token on the row as the decision.
          protected_note=""
          if [[ "$has_knowledge" == "1" && "$src_lines" -gt 0 && "$decision" == "MERGE" \
                && $(( tgt_lines * 100 / src_lines )) -lt 50 ]]; then
            protected_note=" (project-knowledge protected: $know_reason — merge pack depth INTO this file; replacing it destroys knowledge no pack can regenerate)"
          fi
          shape_note=""
          if [[ -n "$SHAPE_TWIN" ]]; then
            shape_note=" (shape conflict: BOTH \`${SHAPE_TGT#"$TARGET"/}\` and \`${SHAPE_TWIN#"$TARGET"/}\` exist — one skill \`name:\`, two registrations; resolve before any write: apply-study-decisions.sh \"\$TARGET\" --migrate-skill-shape --apply)"
          elif [[ "$SHAPE_FORM" == "legacy-flat" ]]; then
            shape_note=" (present on the legacy flat shape \`${SHAPE_TGT#"$TARGET"/}\`; staying flat is legitimate — do not copy the pack file beside it)"
          fi
          kind_rows+=$'\n'"  - \`$base\` — target $tgt_lines / pack $src_lines lines → **$decision**$protected_note$shape_note"

          case "$decision" in
            REPLACE-OR-ENHANCE|KEEP-OURS-PLUS-INJECT|MERGE)
              pack_actionable=$(( pack_actionable + 1 ))
              total_act=$(( total_act + 1 ))
              ;;
            *)
              total_keep=$(( total_keep + 1 ))
              ;;
          esac
        else
          # PROJECT_KIND — see templates/packs/_project-kind.md. An artifact declaring a kind
          # this target does not have is not an ADD row; proposing it is how 49,450 bytes of
          # browser-only content reached a headless API.
          if ! artifact_applies_to_target "$src"; then
            kind_rows+=$'\n'"  - \`$base\` — → **DECLINED-PROJECT-KIND** — $KIND_DECLINE_REASON"
            total_ledger=$(( total_ledger + 1 ))
            continue
          fi
          kind_rows+=$'\n'"  - \`$base\` — target MISSING / pack $(wc -l < "$src" | tr -d ' ') lines → **ADD**"
          pack_actionable=$(( pack_actionable + 1 ))
          total_missing=$(( total_missing + 1 ))
        fi
      done < <(enumerate_kind_dir "$kind_dir")

      [[ -n "$kind_rows" ]] && pack_section+=$'\n\n### '"$kind"$''$kind_rows
    done

    if [[ -n "$pack_section" ]]; then
      printf '## %s' "$pack"
      printf '%b' "$pack_section"
      printf '\n\nactionable in this pack: **%d**\n\n---\n\n' "$pack_actionable"
    fi
  done

  # Project-only orphans — reported ONCE per file across all scanned packs.
  printf '## Project-only files (target has them; no scanned pack does)\n'
  for kind in commands agents skills rules ai-patterns; do
    tgt_dir="$(target_dir_for_kind "$kind")"
    [[ -d "$tgt_dir" ]] || continue
    orphan_rows=""
    while IFS= read -r tgtf; do
      base="${tgtf#"$tgt_dir"/}"
      [[ "$base" == _* ]] && continue
      if [[ ! -f "$UNION_TMP/$kind" ]] || ! grep -qxF "$(artifact_identity "$base")" "$UNION_TMP/$kind"; then
        ledger_entry="$(ledger_lookup "$kind/$base")"
        if [[ -n "$ledger_entry" ]]; then
          IFS='|' read -r lverb ldate lsha lwhy <<<"$ledger_entry"
          orphan_rows+=$'\n'"  - \`$base\` — → **KEEP-BY-LEDGER** — $lwhy ($ldate)"
          total_ledger=$(( total_ledger + 1 ))
        else
          orphan_rows+=$'\n'"  - \`$base\` — target-only (not in pack) → **REVIEW: project-specific keeper OR deprecated upstream**"
          total_orphan=$(( total_orphan + 1 ))
        fi
      fi
    done < <(enumerate_kind_dir "$tgt_dir")
    [[ -n "$orphan_rows" ]] && { printf '\n### %s' "$kind"; printf '%b\n' "$orphan_rows"; }
  done
  printf '\n---\n\n'

  printf '## Decision legend\n\n'
  cat <<'LEGEND'
* ADD — file in pack but not target. Phase 4.2 must copy.
* IDENTICAL-NO-OP — target byte-identical to pack. No structural action; Phase 4.6 still anchors project-specific block.
* REPLACE-OR-ENHANCE — target ≤ 50% of pack size AND carries nothing the pack cannot regenerate. Stub or shallow; replace with pack OR rewrite to pack depth.
* MERGE (project-knowledge protected) — target ≤ 50% of pack size but carries project knowledge: the `<!-- project-specific:start -->` anchor, a real project file path, or ≥3 code identifiers absent from the pack. A SHORTER FILE IS NOT A WORSE FILE — this row must be resolved by merging pack depth INTO the target, never by replacing it. (M36; the ratio-only rule destroyed three such files on 2026-08-22.)
* KEEP-OURS-PLUS-INJECT — target deeper but missing project-specific anchor. Phase 4.6 must inject anchor section into target.
* KEEP-OURS-ANCHORED — target deeper AND already carries the project-specific anchor block. Keeper; no action (the inject KEEP-OURS-PLUS-INJECT would ask for is already done).
* MERGE — sizes comparable; real per-section merge required.
* KEEP-OURS-ADD-SIDE-DOC — target slightly shallower; keep target, add pack as side-doc with different name.
* KEEP-OURS-DEEP — target ≥ 2× pack size; pack adds nothing. No action.
* ADOPT-PACK-TRIM — target is larger than the pack but carries NO project knowledge outside its anchor block, so the size gap is a deliberate pack shrink rather than project depth. Actionable: adopt the smaller pack file (the anchor block is re-injected by Phase 4.6). This verdict exists because the ratio ladder alone reads every shrink as a downgrade and preserves the fat copy forever — measured, 12 rules in one repo.
* REVIEW — file in target but NOT in pack. Could be project-specific (keep) or deprecated upstream (consider deleting). Human judgment required.
* REJECTED-BY-LEDGER / KEEP-OURS-BY-LEDGER / RESOLVED-BY-LEDGER / KEEP-BY-LEDGER — reconciled by `.claude/_refresh-decisions.md`. Not actionable. KEEP-OURS / RESOLVED entries re-open automatically when the pack source changes (pack@sha8 mismatch).

MERGE rows are DECIDED AUTOMATICALLY (M43). `apply-study-decisions.sh --apply` hands every
MERGE / KEEP-OURS-PLUS-INJECT row to `scripts/merge-decide.py`, which classifies it per file
against a provenance corpus built from claude-config's own git history — every distinct line
that ever appeared in any `*.md` at any commit — and picks one of:

* NO-OP    — identical to the pack once the project-specific anchor is set aside.
* OVERRIDE — every line the replace would delete is verbatim historical pack text, so nothing
             is lost that the framework cannot put back. Anchor blocks and bare
             `## Project-specific` sections are carried forward verbatim.
* ENHANCE  — the target is a strict SUBSEQUENCE of the pack: adopting the pack body deletes
             zero target lines.
* ADJUST   — the target has project content, and all of it lives in sections the pack does not
             have. Those sections are kept byte-for-byte and marked; the shared sections take
             the pack version.
* DEFER    — project content sits inside a section the pack also changed. A real merge; a
             human decides. Measured on two live repos: 30 rows of 235.

Every write is backed up, re-read, and ROLLED BACK if one unknown-origin line, project token or
project-specific region went missing. Per-file records land in `.claude/_merge-decisions.md`.
`--conservative` restores the old behaviour of listing MERGE rows and writing nothing.

Recording decisions (M35 — the ONLY sanctioned way to skip an actionable row):

    apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'     # permanent: wrong for this project
    apply-study-decisions.sh <target> --keep-ours='pack/kind/file.md:rationale'  # ours is better than current pack version
    apply-study-decisions.sh <target> --resolve='pack/kind/file.md:note'         # merge/inject performed by hand
    apply-study-decisions.sh <target> --keep='kind/file.md:rationale'            # project-only orphan keeper
LEGEND

  printf '\n## Summary\n\n'
  printf 'Files with action needed: **%d**\n' "$(( total_act + total_missing ))"
  printf '  ADD (missing): %d\n' "$total_missing"
  printf '  ENHANCE / MERGE / INJECT: %d\n' "$total_act"
  printf 'Files to keep as-is: %d\n' "$total_keep"
  printf 'Ledger-reconciled (not re-proposed): %d\n' "$total_ledger"
  printf 'Ledger entries re-opened (pack changed since decision): %d\n' "$total_reopened"
  printf 'Files to review (orphans, deduped): %d\n\n' "$total_orphan"

  if [[ $(( total_act + total_missing )) -eq 0 && "$total_orphan" -eq 0 ]]; then
    printf 'No actionable items. Setup is converged.\n'
  else
    printf '⚠ Phase 4 MUST end every actionable row in one of two states: APPLIED (copy / merge / enhance) or RECORDED in `.claude/_refresh-decisions.md` with rationale. Phase 5 audit (C2k) regenerates this report and refuses success otherwise.\n'
  fi
} > "$REPORT"

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

# Under --stdout the REPORT owns stdout, so the human-facing summary moves to stderr:
# `study-existing.sh <target> --stdout > report.md` must yield a clean report file, not
# one with two summary lines glued to the end. Default mode keeps stdout, unchanged.
say() { if [[ $SINK_STDOUT -eq 1 ]]; then echo "$@" >&2; else echo "$@"; fi; }
say "Study report written: $REPORT_LABEL"
say "Actionable: $(( total_act + total_missing )) | Keep: $total_keep | Ledger: $total_ledger (re-opened: $total_reopened) | Orphans: $total_orphan"
exit 0
