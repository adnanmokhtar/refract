#!/usr/bin/env bash
# lint-import-edges.sh — an `imported-by:` line must name a file that actually imports it.
#
# WHY. 41 files in templates/ and commands/ open with a frontmatter line naming who consumes
# them:
#
#     imported-by: commands/setup-project.md, /setup-project-health.
#
# That line is the repo's only machine-readable back-edge — the answer to "I am about to change
# this file, who breaks?" — and until now nothing read it. `grep -rn imported-by scripts/`
# returned zero. It was written by hand, copied between mirrored files, and never re-checked
# when a consumer was renamed or a load path moved.
#
# This is the same shape lint-handoffs.sh closes for section anchors and skill inputs (File A
# states a property OF named artifact B; the property is decidable by opening B; nothing opens
# B) — applied to the one edge that points BACKWARD. lint-handoffs.sh checks what a file says
# about a file it cites. This checks what a file says about a file that cites IT, which no
# forward-looking gate can see: the claim lives in the target, and the evidence lives in a file
# the target never names as a dependency.
#
# THE TWO CHECKS
#
#   [1] check_importer_exists  (FAIL)
#       Every repo-path an `imported-by:` line names resolves on disk. A claim naming a deleted
#       or renamed consumer is a dead back-edge and points impact analysis at nothing.
#
#   [2] check_edge_holds  (FAIL, baselined)
#       The named importer must actually reference the claiming file. First run over the whole
#       tree: 41 claim lines → 49 resolvable targets → 39 direct, 8 through one intermediate,
#       2 not at all. Both were the same defect — templates/observability.md and
#       templates/phases/phase-5-checklist.md each named /setup-project-health as a consumer of
#       a file that command loads nowhere. Pulling that thread found three more statements of
#       the same edge that this gate cannot see, because they are prose rather than
#       `imported-by:` lines: templates/import-tiers.md:25, its Tier-audit section (crediting
#       /setup-project-health with a "C7" tier-budget check it does not have, in a numbering
#       scheme it does not use), and templates/observability.md's claim that telemetry "is
#       consumed by /setup-project-health (rolls up to drift signals)". The command has ten
#       checks, none of which opens that per-run history log at all. All five were repaired rather than
#       baselined; scripts/_import-edge-baseline.txt is empty and an empty ratchet is the
#       intended steady state. Anything new is a hard FAIL.
#
#       Note what that ratio means for the gate's own worth: of five false statements about one
#       command, it mechanically caught two. The other three were found by hand, following the
#       two it caught. A back-edge gate is a thread to pull, not a proof of consistency.
#
# HOW A REFERENCE IS RECOGNISED, and why it is not a substring match. The first draft of this
# gate matched basenames and reported 20 findings. Most were false: commands/audit.md mentions
# `ai/observability.md` — the file written into the CONSUMING project — which shares a basename
# with templates/observability.md and is a different artifact entirely. So a bare basename never
# counts. What counts is how this repo actually writes a reference:
#
#   full path      `templates/snippets/plan-flag.md`                    (frontmatter imports)
#   two-segment    `../../../snippets/sibling-shape-halt.md`            (relative markdown links)
#   same-dir base  `from: conventions.md` in templates/tracks/<t>/      (YAML emit blocks)
#   one hop        setup-project.md → templates/capabilities.md → templates/capabilities/N-*.md
#
# The one hop is not a loophole; it is what `imported-by:` means under a tiered loader. The
# orchestrator imports the index, the index imports the seven capability files, and each of
# those correctly names the orchestrator as its consumer. Rejecting that would demand every
# leaf name its parent instead of its root, which is the opposite of what the line is for.
# Indirect resolutions are counted and printed, never silently folded into the direct total.
#
# WHAT IT DOES NOT CHECK, on purpose — 11 claim fragments are prose, not paths:
# "every phase that loads files", "Phase 4 (Apply)", "every operational command (optimize /
# refactor / …)". They are undecidable without resolving English to a file set, so they are
# skipped and DISCLOSED in the reach line rather than guessed at. Two more fragments are
# negated mentions — "there is no root commands/learn-from-task.md" is a disclosure that a path
# does NOT exist, not a claim that it imports anything — and the 4 claim lines inside
# templates/repo-baseline/ are skipped as well: those files are verbatim mirrors of a canonical
# snippet and carry its `imported-by:` line unchanged, so the claim describes the original, not
# the copy. None of the three skips is a pass; all three are printed.
#
# Usage:  lint-import-edges.sh [--repo-root=<dir>] [--quiet]
# Exit:   1 on any FAIL; 0 otherwise.
# Notes:  bash 3.2 (macOS) compatible — no associative arrays, mapfile, or ${var,,}.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

QUIET=0
EMIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    --emit-edges=*) EMIT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1

BASELINE="scripts/_import-edge-baseline.txt"
ROOTS_RE='(templates|commands|docs|scripts)/'
# A fragment disclosing that a path does NOT exist is not a claim about it. Without this,
# templates/snippets/learning-sink.md — which says in so many words "there is no root
# commands/learn-from-task.md" — is read as claiming that very file imports it.
NEGATION_RE='there is no|there are no|no root|not yet|never |instead of'
MIRROR='templates/repo-baseline/'

fails=0; warns=0
direct=0; indirect=0; suppressed=0
skipped_prose=0; skipped_mirror=0; skipped_negated=0
claim_lines=0; targets=0

say() { [ $QUIET -eq 0 ] && echo "$@"; return 0; }

# An edge is emitted ONLY where this gate has just PROVEN it: the importer names the target,
# directly or via one hop. A baselined claim is one this gate could NOT verify, so it is counted
# in the reach line and deliberately withheld here — whoever consumes this stream must never
# receive an edge weaker than the one CI enforces.
# Columns: kind, importer, imported, via (empty when direct).
emit() { [ -n "$EMIT" ] && printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}" >> "$EMIT"; return 0; }
[ -n "$EMIT" ] && : > "$EMIT"

# expand_braces <token> — templates/packs/{backend,frontend}/x.md → one line per alternative.
# No eval: the token comes from repo prose.
expand_braces() {
  local t="$1" pre rest alts post a
  case "$t" in
    *\{*\}*)
      pre="${t%%\{*}"; rest="${t#*\{}"; alts="${rest%%\}*}"; post="${rest#*\}}"
      local IFS=,
      for a in $alts; do expand_braces "$pre$a$post"; done
      ;;
    *) echo "$t" ;;
  esac
}

# refs <importer> <target> — does <importer> reference <target> the way this repo writes
# references? Full path, two-segment tail, or same-directory basename. Never a bare basename
# across directories (see the audit.md / ai/observability.md false positive in the header).
refs() {
  local imp="$1" tgt="$2" tail base
  if grep -qF -- "$tgt" "$imp" 2>/dev/null; then return 0; fi
  tail=$(echo "$tgt" | awk -F/ '{ if (NF>=2) print $(NF-1)"/"$NF; else print $NF }')
  if grep -qF -- "$tail" "$imp" 2>/dev/null; then return 0; fi
  if [ "$(dirname "$imp")" = "$(dirname "$tgt")" ]; then
    base=$(basename "$tgt")
    if grep -qF -- "$base" "$imp" 2>/dev/null; then return 0; fi
  fi
  return 1
}

# refs_hop2 <importer> <target> — importer → intermediate → target. Prints the intermediate.
refs_hop2() {
  local imp="$1" tgt="$2" mid
  for mid in $(grep -oE "${ROOTS_RE}[A-Za-z0-9_./-]*\.md" "$imp" 2>/dev/null | sort -u); do
    [ -f "$mid" ] || continue
    [ "$mid" = "$imp" ] && continue
    [ "$mid" = "$tgt" ] && continue
    if refs "$mid" "$tgt"; then echo "$mid"; return 0; fi
  done
  return 1
}

# baselined <src> <importer> — a line suppresses only when it carries a `# reason`.
baselined() {
  local key="$1|$2" line
  [ -f "$BASELINE" ] || return 1
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in
      "$key"*)
        case "$line" in
          *"#"*) return 0 ;;                       # has a reason → suppresses
          *) warns=$((warns+1))
             echo "WARN  baseline line has no '# reason' and suppresses nothing: $key"
             return 1 ;;
        esac ;;
    esac
  done < "$BASELINE"
  return 1
}

echo "=== lint-import-edges ==="
echo "Repo: $REPO_ROOT"
echo ""

CLAIMS=$(grep -rn '^imported-by:' --include='*.md' templates commands 2>/dev/null | sort)
claim_lines=$(printf '%s\n' "$CLAIMS" | grep -c '^' )
if [ -z "$CLAIMS" ]; then
  echo "FAIL  no 'imported-by:' lines found — the population this gate reads is empty"
  exit 1
fi

say "[1] every named importer resolves on disk"
say "[2] every named importer actually references the claiming file"
say ""

# One pass over the claim lines, emitting a flat record stream. The fragment split runs inside a
# pipe (its own subshell), so it cannot own the counters — it reports, and the consumer below
# counts. That separation is deliberate: bash 3.2 has no way to carry a counter back out.
# A `case` pattern's `)` terminates a `$( )` command substitution in bash 3.2, so this stream
# goes through a temp file rather than a substitution. Same reason the counters live in the
# consumer: neither construct survives being nested here.
RECORDS=$(mktemp "${TMPDIR:-/tmp}/import-edges.XXXXXX") || exit 2   # full template: BSD and GNU -t disagree
trap 'rm -f "$RECORDS"' EXIT
{
  while IFS= read -r entry; do
    src="${entry%%:*}"; rest="${entry#*:}"; ln="${rest%%:*}"; claim="${rest#*:}"
    claim="${claim#imported-by:}"
    case "$src" in "$MIRROR"*) echo "SKIP-MIRROR"; continue ;; esac
    prot=$(printf '%s' "$claim" | awk '
      { out=""; depth=0
        for (i=1; i<=length($0); i++) { c=substr($0,i,1)
          if (c=="{") depth++
          else if (c=="}") depth--
          else if (c=="," && depth>0) c="\001"
          out=out c }
        print out }')
    # printf '%s\n', not '%s': an unterminated final line is silently dropped by `read`, which
    # costs the last fragment of every claim and the whole of any claim that has only one.
    printf '%s\n' "$prot" | sed 's/ + /,/g' | tr ',' '\n' | while IFS= read -r frag; do
      frag=$(printf '%s' "$frag" | tr '\001' ',' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -n "$frag" ] || continue
      if printf '%s' "$frag" | grep -qE "$NEGATION_RE"; then echo "SKIP-NEGATED"; continue; fi
      toks=$(printf '%s' "$frag" | grep -oE "${ROOTS_RE}[A-Za-z0-9_.{},/-]*\.md" || true)
      tgts=""
      if [ -n "$toks" ]; then
        for t in $toks; do tgts="$tgts $(expand_braces "$t" | tr '\n' ' ')"; done
      else
        for s in $(printf '%s' "$frag" | grep -oE '/[a-z][a-z0-9-]+' | tr -d '/' || true); do
          [ -f "commands/$s.md" ] && tgts="$tgts commands/$s.md"
        done
      fi
      if [ -z "$(printf '%s' "$tgts" | tr -d '[:space:]')" ]; then echo "SKIP-PROSE"; continue; fi
      for tgt in $tgts; do echo "TARGET|$src|$ln|$tgt"; done
    done
  done <<EOF2
$CLAIMS
EOF2
} > "$RECORDS"

while IFS= read -r r; do
  case "$r" in
    SKIP-MIRROR)  skipped_mirror=$((skipped_mirror+1)); continue ;;
    SKIP-PROSE)   skipped_prose=$((skipped_prose+1));   continue ;;
    SKIP-NEGATED) skipped_negated=$((skipped_negated+1)); continue ;;
    TARGET\|*) : ;;
    *) continue ;;
  esac
  src=$(printf '%s' "$r" | cut -d'|' -f2)
  ln=$(printf '%s' "$r" | cut -d'|' -f3)
  tgt=$(printf '%s' "$r" | cut -d'|' -f4)
  targets=$((targets+1))

  if [ ! -f "$tgt" ]; then
    if baselined "$src" "$tgt"; then
      suppressed=$((suppressed+1))
      say "  base  $src:$ln  names $tgt (missing) — baselined"
    else
      echo "FAIL  [1] $src:$ln  names an importer that does not exist: $tgt"
      fails=$((fails+1))
    fi
    continue
  fi

  if refs "$tgt" "$src"; then
    direct=$((direct+1))
    emit import "$tgt" "$src" ""
    say "  ok    $src  ←  $tgt"
    continue
  fi

  mid=$(refs_hop2 "$tgt" "$src")
  if [ -n "$mid" ]; then
    indirect=$((indirect+1))
    emit import "$tgt" "$src" "$mid"
    say "  hop   $src  ←  $tgt  (via $mid)"
    continue
  fi

  if baselined "$src" "$tgt"; then
    suppressed=$((suppressed+1))
    say "  base  $src  ←  $tgt  — baselined"
  else
    echo "FAIL  [2] $src:$ln  claims $tgt imports it, but $tgt never references $src"
    fails=$((fails+1))
  fi
done < "$RECORDS"

echo ""
echo "reach: $claim_lines claim lines · $targets resolvable targets · $direct direct · $indirect via one hop · $suppressed baselined"
echo "       not checked: $skipped_prose prose fragments · $skipped_mirror repo-baseline mirrors · $skipped_negated negated mentions"

if [ $fails -gt 0 ]; then
  echo ""
  echo "FAIL  $fails broken back-edge(s). Fix the claim, or add a line WITH a reason to $BASELINE."
  exit 1
fi
[ $warns -gt 0 ] && echo "WARN  $warns inert baseline line(s)."
echo "PASS  every checked back-edge holds."
exit 0
