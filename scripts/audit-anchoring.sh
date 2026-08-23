#!/usr/bin/env bash
# audit-anchoring.sh — verify pack-derived artifacts are anchored to the target project.
#
# Solves the M25 question: pack templates are generic on purpose. After install,
# every pack-derived artifact in <target>/.claude/{commands,agents,skills,rules}
# (and ai/patterns) is supposed to carry a "## Project-specific (anchored)" block
# populated with facts cited from the codebase scan (path:line). Without that
# block, the artifact is just a generic skeleton and gives no project-aware help.
#
# This script audits per-artifact anchor coverage and writes a report. M25.1 is
# WARN-ONLY (always exit 0). Once M25.3 (apply-anchors.sh) is in place and pack
# templates carry the marker, M25.4 will promote this to REFUSE on missing anchors.
#
# Usage:
#   audit-anchoring.sh <target-repo> [--strict] [--quiet] [--stdout | --report=<path>]
#
# Flags:
#   --strict — exit 1 if any pack-derived artifact lacks an anchor block (or has the
#              block but with zero `path:line` citations). Default = warn-only.
#   --quiet  — suppress per-file output; only print summary + write report.
#   --stdout — READ-ONLY mode (alias: --no-write). Emit the report on stdout and create
#              NOTHING under <target-repo> — not the report, not `.claude/`. This is the
#              only way to audit a repo you are not permitted to modify.
#   --report=<path> — write the report to <path> instead of <target>/.claude/. Same
#              read-only guarantee for <target-repo> when <path> lives outside it.
#              Must use `=`; `--report <path>` is refused rather than silently ignored.
#
# Output:
#   <target>/.claude/_anchoring-audit.md  (per-artifact report)
#     — stdout under --stdout, <path> under --report=<path>
#   stderr summary line
#
# Exit codes:
#   0  — clean, OR warn-only (default) regardless of findings
#   1  — --strict + at least one pack-derived artifact unanchored
#   2  — usage error

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--strict] [--quiet] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
STRICT=0
QUIET=0
SINK_STDOUT=0
REPORT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    --stdout|--no-write) SINK_STDOUT=1; shift ;;
    --report=*) REPORT_OVERRIDE="${1#*=}"; shift ;;
    --report) echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# ── Report sink ───────────────────────────────────────────────────────
# The default sink is a file INSIDE the target, which made merely RUNNING this audit a
# write to the audited repo — so "audit a project I must not modify" was not an operation
# that existed. Observed 2026-08-22: three audit scripts regenerated their reports inside
# a declared read-only target purely because someone ran them to verify a fix; the
# verification WAS the write. --stdout / --report= remove every write under $TARGET,
# `.claude/` included — note the mkdir below creates that directory in a repo that has
# none, so it cannot run in read-only mode either.
REPORT="$TARGET/.claude/_anchoring-audit.md"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/anchoring-audit.XXXXXX")
  trap '[ -n "${REPORT_TMP:-}" ] && rm -f "$REPORT_TMP"; :' EXIT
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# Path resolution per kind — same convention as study-existing.sh / pack-coverage-scan.sh
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

# Build set of "pack-derived" basenames per kind: any basename present in ANY pack
# under templates/packs/<*>/<kind>/<base>. We treat target files matching this set
# as pack-derived (eligible for anchor audit) and skip orphans (project-only).
#
# bash 3.2 has no associative arrays; we use space-delimited strings per kind.
# Dual-form: flat `<kind>/<name>.md` (depth 3) AND Agent Skills dir-form
# `<kind>/<name>/SKILL.md` (depth 4). Both are reduced to the SAME identity — the
# artifact name plus `.md` — so membership below is form-independent: a target still on
# flat form still matches a pack that has moved to dir-form, and vice versa. Without the
# depth-4 branch every pack skill silently drops out of this set and anchoring skips it.
pack_basenames_for_kind() {
  local kind="$1"
  { find -L "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
         -exec basename {} \; 2>/dev/null
    find -L "$PACKS_ROOT" -mindepth 4 -maxdepth 4 -path "*/$kind/*/SKILL.md" \
         -exec sh -c 'for p; do n=$(basename "$(dirname "$p")"); case $n in _*) ;; *) echo "$n.md" ;; esac; done' _ {} + 2>/dev/null
  } | sort -u | tr '\n' ' '
}

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md
# Emits FULL paths; callers derive the dir-relative suffix, which is the real path to the
# artifact. `_*` artifacts are dropped by the caller's existing prefix guard.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# Canonical, form-independent artifact identity: `foo.md` and `foo/SKILL.md` both -> `foo.md`.
artifact_identity() {
  case "$1" in
    */SKILL.md) local d="${1%/SKILL.md}"; echo "${d##*/}.md" ;;
    *)          echo "${1##*/}" ;;
  esac
}

# Citation regex — `path:line` forms that prove the anchor cites the codebase, not
# generic prose. Accepts backticked OR plain. Path must contain a slash AND a real
# source-file extension AND be followed by `:<digits>`.
CITATION_RE='[a-zA-Z0-9._/-]+\.(ts|tsx|js|jsx|mjs|cjs|vue|py|go|rb|php|java|kt|swift|md|yaml|yml|json|toml|sh|env|html|css|scss|sql)[[:space:]]*:[[:space:]]*[0-9]+'

# Placeholder tokens that prove an anchor block is a SKELETON, not a real anchor.
# An anchor block carrying any of these has been left in template state — it cites
# no real project fact. Kept conservative: each token is a literal pack-template
# placeholder that never appears in a genuinely populated block.
PLACEHOLDER_RE='<src/path|<e\.g\.,|<EntityA>|<DetectedBase>|<NNNN>|<term>|<one-line|<YYYY-MM-DD>|<ClassName>|<path/to|<detected'

# --- What counts as a LIVE anchor -------------------------------------------------
# A marker (form 1) or a `## Project-specific` heading (form 2) counts ONLY when it sits
# at column 0 and OUTSIDE any ``` fence. A marker inside a fence is DOCUMENTATION of the
# convention — a skill showing the reader what an anchor block looks like — and an inline
# mention in prose or a table is a pointer, not an anchor.
#
# apply-anchors.sh § has_live_anchor implements the identical test, and the two MUST keep
# agreeing. While that script matched a bare `^<!-- project-specific:start -->$` (fences
# included) and this one's block extractor skipped fences, a file whose only marker was a
# fenced example was "already anchored → skip" to the injector and an empty block to this
# auditor: an unresolvable C2d failure whose printed fix ("re-run apply-anchors.sh") was a
# guaranteed no-op on exactly those files. Measured on a real 8,151-file repo against the
# two learning-pack skills that TEACH the convention (compute-anchor-density,
# apply-pack-adaptation): injector "Injected 0 / Already anchored 234", auditor "2
# unanchored (anchor-too-thin(0-lines))", REFUSED, forever.
has_live_marker() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^<!-- project-specific:start -->[[:space:]]*$/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

has_live_ps_heading() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^##[[:space:]]+Project-specific/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

has_live_anchor() { has_live_marker "$1" || has_live_ps_heading "$1"; }

# Extract just the canonical anchor block body (between the start/end markers) so
# quality checks (line count, placeholder, identifier presence) measure the BLOCK,
# not the whole artifact. Falls back to the `## Project-specific` heading-to-next-H2
# slice for older pack templates that use form 2.
extract_anchor_block() {
  local f="$1"
  # Track fenced-code state and ignore markers/content inside ``` fences — a
  # fenced block is documentation (e.g. a skill that shows what an anchor block
  # looks like), not a live anchor. Without this, example marker blocks inside
  # code fences are mis-read as real anchors and their placeholders / example
  # paths surface as skeleton + cross-project-leak false-positives.
  # Branch on a LIVE marker, not on `grep -qF` anywhere in the file: a form-2 artifact
  # (heading, no markers) that merely SHOWS the markers in a fenced example would take the
  # marker branch, which then fence-skips the example and returns an empty block — the
  # real heading block never read.
  if has_live_marker "$f"; then
    awk '
      /^[[:space:]]*```/ { fence = !fence; next }
      fence { next }
      /^<!-- project-specific:start -->[[:space:]]*$/ { in_b=1; next }
      /^<!-- project-specific:end -->[[:space:]]*$/ { in_b=0; next }
      in_b { print }
    ' "$f" 2>/dev/null
  else
    awk '
      /^[[:space:]]*```/ { fence = !fence; next }
      fence { next }
      /^##[[:space:]]+Project-specific/ { in_b=1; next }
      in_b && /^##[[:space:]]/ { exit }
      in_b { print }
    ' "$f" 2>/dev/null
  fi
}

# Returns 0 if file has anchor block + ≥1 citation in it; else 1, with reason on stderr.
#
# Detects the canonical Phase-4.6 anchor block as established by the existing
# REFINE infrastructure (`apply-pack-adaptation`, `compute-anchor-density`,
# test-refine-fixture.sh). Recognized forms:
#   1. `<!-- project-specific:start --> ... <!-- project-specific:end -->`  (canonical, byte-stable)
#   2. `## Project-specific` heading (any suffix — older pack templates use this)
# Either form satisfies the "has section" check; M25.3 (apply-anchors.sh) writes
# form 1, which REFINE can later rewrite.
check_anchor() {
  local f="$1"
  if has_live_anchor "$f"; then
    : # has section
  elif grep -qF '<!-- project-specific:start -->' "$f" 2>/dev/null \
     || grep -qE '^##[[:space:]]+Project-specific' "$f" 2>/dev/null; then
    # The marker EXISTS in the file but only as documentation — inline in prose, or at
    # column 0 inside a ``` fence (a file that teaches the marker convention by showing
    # it). It is not an anchor this artifact carries. Report it as its own reason rather
    # than letting it fall through to `anchor-too-thin(0-lines)`: "too thin" points the
    # reader at the block's CONTENT, when the actual state is that no block was ever
    # injected — and the fix is the injector, which now (apply-anchors.sh has_live_anchor)
    # sees past the fence and writes one.
    echo "anchor-documented-not-applied"
    return 1
  else
    echo "no-anchor-section"
    return 1
  fi

  # --- Anti-skeleton QUALITY gate (M25.5) -------------------------------------
  # A block that exists but is template boilerplate gives no project help. Measure
  # the BLOCK body, not the whole file: it must have ≥3 substantive lines AND must
  # NOT carry placeholder tokens AND must cite ≥1 real identifier/path.
  local block
  block=$(extract_anchor_block "$f")

  # (a) reject placeholder tokens left in the block
  if printf '%s\n' "$block" | grep -qE "$PLACEHOLDER_RE" 2>/dev/null; then
    echo "anchor-placeholder-skeleton"
    return 1
  fi

  # (b) require ≥3 non-blank, non-comment, substantive lines in the block. A line
  # is "substantive" only if it carries word content (not a bare bullet / marker).
  local substantive
  substantive=$(printf '%s\n' "$block" \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '^[[:space:]]*<!--' \
    | grep -vE '^[[:space:]]*[-*][[:space:]]*$' \
    | grep -cE '[A-Za-z0-9]' 2>/dev/null || true)
  substantive="${substantive:-0}"
  if [[ "$substantive" -lt 3 ]]; then
    echo "anchor-too-thin(${substantive}-lines)"
    return 1
  fi

  # (c) require ≥1 real identifier or path cited anywhere in the file: either a
  # `path:line` citation, OR a backticked path-with-slash, OR a backticked
  # CamelCase / snake_case identifier (proves a real symbol was named).
  if grep -qE "$CITATION_RE" "$f" 2>/dev/null \
     || grep -qE '`[a-zA-Z0-9_./-]+/[a-zA-Z0-9_.-]+`' "$f" 2>/dev/null \
     || grep -qE '`[A-Z][a-zA-Z0-9]+[A-Z][a-zA-Z0-9]*`' "$f" 2>/dev/null \
     || grep -qE '`[a-z]+_[a-z_]+`' "$f" 2>/dev/null; then
    return 0
  else
    echo "anchor-without-citation"
    return 1
  fi
}

# --- Cross-project LEAK scan (M25.6) ------------------------------------------
# Failure mode: a generated artifact "ships another project's class names" — an
# anchor block populated from a DIFFERENT repo's facts (copy-paste, stale cache).
# We flag a high-confidence identifier cited in an anchor block that does NOT
# appear ANYWHERE in the target codebase. Conservative by design (false-positives
# would block legitimate runs): we only consider `path:line` citations and
# backticked paths-with-slash, and we ignore anything that resolves under the
# target (file exists OR string is grep-findable in source).
#
# Builds a one-time corpus of source basenames + a fast grep against the tree.
LEAK_SRC_GREP_DIRS=()
for d in src app lib packages apps services internal pkg components; do
  [[ -d "$TARGET/$d" ]] && LEAK_SRC_GREP_DIRS+=("$TARGET/$d")
done
# Fall back to the whole target (minus deps) if no conventional source root.
[[ ${#LEAK_SRC_GREP_DIRS[@]} -eq 0 ]] && LEAK_SRC_GREP_DIRS=("$TARGET")

# Returns 0 (token exists in target) / 1 (not found → leak candidate).
token_in_target() {
  local tok="$1"
  # Strip a trailing :<line> citation suffix (numeric only) → resolve the file itself.
  # Done BEFORE the slash test so ROOT-level citations (package.json:14, vite.config.ts:97)
  # resolve as files instead of falling through to the identifier grep with the :line glued
  # on (which never matches → the dominant cross-project-leak false-positive).
  local pathpart="$tok"
  [[ "$tok" =~ :[0-9][0-9]*$ ]] && pathpart="${tok%:*}"

  # Absolute path: a cross-repo / sibling-project reference (e.g. the workspace
  # PROJECTS.md). Resolve at its REAL location, not under $TARGET — exists there → a
  # legitimate cross-repo citation, not a leak. A leading-slash token with no file
  # extension is an app ROUTE (/orders/all), not a filesystem path → out of scope.
  if [[ "$pathpart" == /* ]]; then
    [[ -e "$pathpart" ]] && return 0
    [[ "$pathpart" != *.* ]] && return 0
  fi

  # Exact relative path under target — handles root files (package.json) AND nested.
  [[ -e "$TARGET/$pathpart" ]] && return 0

  # Build-output / generated paths are intentionally excluded from the source scan,
  # so a citation under them could never resolve — they are legitimate references to
  # artifacts that exist only after a build, not cross-project leaks.
  case "$pathpart" in
    dist/*|build/*|coverage/*|.next/*|out/*|.nuxt/*|.output/*) return 0 ;;
  esac

  # File-shaped token (has an extension): match by basename anywhere in the tree.
  if [[ "$pathpart" == *.* ]]; then
    local bn="${pathpart##*/}"
    find "$TARGET" -name "$bn" -not -path '*/node_modules/*' -not -path '*/.git/*' \
      -not -path '*/vendor/*' -not -path '*/dist/*' -not -path '*/build/*' \
      2>/dev/null | grep -q . && return 0
    return 1
  fi

  # identifier form: must appear literally in some source file
  grep -rqIF -- "$tok" "${LEAK_SRC_GREP_DIRS[@]}" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
    --exclude-dir=dist --exclude-dir=build 2>/dev/null && return 0
  return 1
}

# Every citation token an anchor block asserts, one per line, for the resolvability test.
#
# HISTORY — this used to be two backtick-only extractors inlined in scan_leaks_in_file, and
# the ONE path apply-anchors.sh emits without backticks is the "top-level:" tail of the
# Cite-able-sources line. A live run shipped "top-level: src/." into 225 artifacts of a repo
# that has no src/ directory, and this audit reported "0 leaks", exit 0 -- the leak gate could
# not see the string its own generator wrote. The third extractor below closes that hole by
# splitting that tail and feeding each entry through the same token_in_target test as any
# other citation. TOPLEVEL placeholder values are emitted separately, tagged, by
# anchor_placeholder_citations, because "cites nothing" is a different defect from "cites
# something that does not exist".
anchor_citation_tokens() {
  local block="$1"
  # Every extractor ends `|| true`. This is load-bearing under `set -euo pipefail`: a grep
  # that matches nothing exits 1, and an unguarded failing pipeline here aborts the whole
  # FUNCTION, so every extractor after the failing one silently never runs. That is how the
  # backticked-path extractor below — which cannot match a `path:line` token, because `:` is
  # outside its character class — was suppressing the CITATION_RE extractor on every block
  # whose only backticked path carried a line number. Independent extractors, independently
  # guarded, is the only shape in which "add a third extractor" is a safe edit.
  printf '%s\n' "$block" | { grep -oE '`[a-zA-Z0-9_./-]+/[a-zA-Z0-9_.-]+`' 2>/dev/null || true; } | tr -d '`'
  printf '%s\n' "$block" | { grep -oE "$CITATION_RE" 2>/dev/null || true; }
  printf '%s\n' "$block" \
    | { grep -oE 'top-level:[^.]*' 2>/dev/null || true; } \
    | sed 's/^top-level:[[:space:]]*//' \
    | tr ',' '\n' \
    | tr -d '`' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s|/*$||' \
    | { grep -vE '^$|^<' || true; }
}

# A "top-level:" value that is a <placeholder> rather than a path. The block asserts a
# Cite-able-sources line while citing nothing -- the anti-skeleton class the placeholder
# regex could not see either, because it lists pack-template tokens and this one is written
# by apply-anchors.sh itself. Echoed as a tagged pseudo-token so it lands in the same leak
# ledger the reader already reads, without being mistaken for a real path.
anchor_placeholder_citations() {
  local block="$1"
  printf '%s\n' "$block" \
    | { grep -oE 'top-level:[[:space:]]*<[^>]*>' 2>/dev/null || true; } \
    | sed 's/^top-level:[[:space:]]*//' \
    | sed 's/^/UNCITED top-level source dir: /'
}

# Scan one artifact's anchor block; echo any high-confidence leaked tokens.
scan_leaks_in_file() {
  local f="$1" block tok
  block=$(extract_anchor_block "$f")
  [[ -z "$block" ]] && return 0
  # high-confidence tokens: backticked path-with-slash, and path:line citations
  while IFS= read -r tok; do
    [[ -z "$tok" ]] && continue
    # skip our own generated paths + universal scaffolds (never "leaks").
    # `scripts/*` covers the round-one floor block's generator-provenance line
    # ("Auto-populated by `scripts/apply-anchors.sh` …") — a setup-internal reference,
    # not a cross-project identifier leak.
    # The bare reference-file citations (`codebase-profile.md:N`, `_codebase-scan.md`,
    # `_extracted-idioms.md`) are emitted by apply-anchors.sh WITHOUT a `.claude/`
    # prefix; they resolve under .claude/ and are setup-internal, not cross-project
    # leaks. Without these patterns the slashless names fall through to the identifier
    # grep and false-positive once per anchored artifact.
    case "$tok" in
      .claude/*|ai/*|templates/*|scripts/*|CLAUDE.md*|AGENTS.md*) continue ;;
      codebase-profile.md*|_codebase-scan.md*|_extracted-idioms.md*) continue ;;
    esac
    if ! token_in_target "$tok"; then
      printf '%s\n' "$tok"
    fi
  done < <(anchor_citation_tokens "$block")
  # Placeholder "top-level:" values bypass token_in_target (they are not paths) but are
  # still an anchor asserting a source it cannot name. Report them in the same ledger.
  anchor_placeholder_citations "$block"
}

UNIQ_TMP=$(mktemp "${TMPDIR:-/tmp}/anchor-uniq.XXXXXX")
trap 'rm -f "$UNIQ_TMP"' EXIT

total_eligible=0
total_anchored=0
total_unanchored=0
total_orphans=0
total_leaks=0
declare -a unanchored_list
declare -a leak_list

{
  printf '# Anchoring audit — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Mode: %s\n\n' "$([[ $STRICT -eq 1 ]] && echo STRICT || echo warn-only)"
  printf '> Each pack-derived artifact (commands/agents/skills/rules/ai-patterns) is supposed to carry a `## Project-specific (anchored)` section with at least one `path:line` citation pointing into the target codebase. Without that, the artifact is generic and gives no project-aware help.\n\n'
  printf -- '---\n\n'

  for kind in commands agents skills rules ai-patterns; do
    tgt_dir=$(target_dir_for_kind "$kind")
    [[ -d "$tgt_dir" ]] || continue

    pack_bases=$(pack_basenames_for_kind "$kind")

    kind_eligible=0
    kind_anchored=0
    kind_unanchored=0
    kind_orphans=0
    kind_rows=""

    while IFS= read -r f; do
      base="${f#"$tgt_dir"/}"
      [[ "$base" == _* ]] && continue

      # Pack-derived? (identity appears in any pack's same kind dir — form-independent,
      # so a dir-form `<name>/SKILL.md` target matches the pack's `<name>.md` identity key)
      if [[ " $pack_bases " != *" $(artifact_identity "$base") "* ]]; then
        kind_orphans=$((kind_orphans + 1))
        total_orphans=$((total_orphans + 1))
        continue
      fi

      kind_eligible=$((kind_eligible + 1))
      total_eligible=$((total_eligible + 1))

      if reason=$(check_anchor "$f"); then
        kind_anchored=$((kind_anchored + 1))
        total_anchored=$((total_anchored + 1))
      else
        kind_unanchored=$((kind_unanchored + 1))
        total_unanchored=$((total_unanchored + 1))
        unanchored_list+=("$kind/$base ($reason)")
        kind_rows+=$'\n'"  - \`$base\` — **$reason**"
      fi

      # UNIQUENESS census (M43). Hash the anchor block's FACT lines so the report can say how
      # many DISTINCT anchors this target actually has. HISTORY: coverage was the only number
      # reported, and coverage cannot distinguish per-artifact anchoring from one global block
      # stamped everywhere — a live repo scored "Coverage: 100% — All pack-derived artifacts
      # are anchored with real project facts" while its 255 anchored files carried only SIX
      # distinct bodies (137 + 88 + 27 byte-identical, then three singletons). The facts were
      # real; they just were not about the artifact. A number nobody computes cannot fail.
      abody=$(extract_anchor_block "$f" | grep -E '^>' 2>/dev/null | shasum 2>/dev/null | cut -c1-12 || true)
      [[ -n "$abody" ]] && printf '%s\n' "$abody" >> "$UNIQ_TMP"

      # LEAK scan (M25.6): high-confidence identifiers/paths not present in target
      while IFS= read -r leaked; do
        [[ -z "$leaked" ]] && continue
        total_leaks=$((total_leaks + 1))
        leak_list+=("$kind/$base → \`$leaked\`")
      done < <(scan_leaks_in_file "$f")
    done < <(enumerate_kind_dir "$tgt_dir")

    [[ $kind_eligible -eq 0 && $kind_orphans -eq 0 ]] && continue

    printf '## %s\n\n' "$kind"
    printf 'eligible (pack-derived): %d / anchored: %d / unanchored: %d / orphans (project-only, skipped): %d\n' \
      "$kind_eligible" "$kind_anchored" "$kind_unanchored" "$kind_orphans"
    if [[ -n "$kind_rows" ]]; then
      printf '\nUnanchored:%b\n' "$kind_rows"
    fi
    printf '\n'
  done

  # Cross-project LEAK findings (M25.6)
  if [[ $total_leaks -gt 0 ]]; then
    printf '## Cross-project leaks (high-confidence)\n\n'
    printf '> These identifiers/paths are cited in an anchor block but do NOT exist anywhere in the target codebase — a sign the block was populated from another project.\n\n'
    for row in "${leak_list[@]}"; do
      printf -- '- %s\n' "$row"
    done
    printf '\n'
  fi

  printf -- '---\n\n## Summary\n\n'
  printf 'Pack-derived artifacts:        **%d**\n' "$total_eligible"
  printf 'Anchored (with citation):      %d\n' "$total_anchored"
  printf 'Unanchored:                    %d\n' "$total_unanchored"
  printf 'Cross-project leaks:           %d\n' "$total_leaks"
  printf 'Orphans (project-only, skipped): %d\n\n' "$total_orphans"
  if [[ $total_eligible -gt 0 ]]; then
    pct=$(( total_anchored * 100 / total_eligible ))
    printf 'Coverage: **%d%%**\n\n' "$pct"
  fi
  # --- Uniqueness: is this per-artifact anchoring, or one block stamped everywhere? ---
  uniq_bodies=$({ sort -u "$UNIQ_TMP" 2>/dev/null || true; } | grep -c . || true)
  uniq_bodies="${uniq_bodies:-0}"
  if [[ $total_anchored -gt 0 ]]; then
    uniq_pct=$(( uniq_bodies * 100 / total_anchored ))
    top_share=$({ sort "$UNIQ_TMP" 2>/dev/null || true; } | uniq -c | sort -rn | head -1 | awk '{print $1+0}')
    top_share="${top_share:-0}"
    top_pct=$(( top_share * 100 / total_anchored ))
    printf 'Distinct anchor bodies:        %d of %d anchored (%d%%)\n' "$uniq_bodies" "$total_anchored" "$uniq_pct"
    printf 'Largest identical group:       %d artifact(s) share one byte-identical block (%d%%)\n\n' "$top_share" "$top_pct"
    if [[ $total_anchored -ge 10 && $top_pct -ge 60 ]]; then
      printf '⚠ **Anchor uniqueness below floor.** %d%% of anchored artifacts carry the SAME block. An anchor that is identical across a caching agent, a saga command and a DLQ skill is a global constant wearing a citation costume — it satisfies every presence check while telling the reader nothing about THIS artifact. `apply-anchors.sh` emits a per-artifact `Where this applies here` / `Relevance UNCONFIRMED` line; if these blocks lack it they predate that change — delete the stale blocks and re-run `apply-anchors.sh %s --apply`.\n\n' "$top_pct" "$TARGET"
    fi
  fi
  if [[ $total_unanchored -eq 0 && $total_leaks -eq 0 ]]; then
    printf '✓ All pack-derived artifacts are anchored with real project facts.\n'
  else
    [[ $total_unanchored -gt 0 ]] && printf '⚠ %d pack-derived artifact(s) lack an anchor block, carry a placeholder skeleton, are too thin (<3 lines), or cite nothing real.\n' "$total_unanchored"
    [[ $total_leaks -gt 0 ]] && printf '⚠ %d cross-project leak(s) — anchor cites a fact absent from the target codebase.\n' "$total_leaks"
    # The remediation MUST be the command that actually clears the finding it follows.
    # `apply-anchors.sh <target>` without `--apply` is a dry run — it prints and writes
    # nothing, so a reader who copies this line sees no change and learns to ignore C2d.
    printf '\nNext: run `apply-anchors.sh %s --apply` (M25.3) to populate from `_codebase-scan.md` + `codebase-profile.md`.\n' "$TARGET"
    printf 'Per reason:\n'
    printf -- '- `no-anchor-section` / `anchor-documented-not-applied` — the injector writes the missing block; re-run the command above. (`anchor-documented-not-applied` means the file MENTIONS the markers, inline or inside a ``` fence, but carries no live block; the injector ignores fenced examples and will inject.)\n'
    printf -- '- `anchor-too-thin(N-lines)` / `anchor-placeholder-skeleton` / `anchor-without-citation` — a live block exists and re-running the injector will NOT touch it (it skips already-anchored files). Deepen it with `/setup-project --refine` (Phase 4.6-DEEP), or fix `%s/.claude/codebase-profile.md` and delete the stale block so the injector rebuilds it.\n' "$TARGET"
  fi
} > "$REPORT"

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

# stderr summary
if [[ $QUIET -eq 0 ]]; then
  echo "Anchoring audit: $total_anchored/$total_eligible anchored, $total_unanchored unanchored, $total_leaks leaks ($total_orphans orphans skipped). Report: $REPORT_LABEL" >&2
fi

UNIQ_FAIL=0
if [[ $total_anchored -ge 10 ]]; then
  _u=$({ sort "$UNIQ_TMP" 2>/dev/null || true; } | uniq -c | sort -rn | head -1 | awk '{print $1+0}')
  _u="${_u:-0}"
  [[ $(( _u * 100 / total_anchored )) -ge 60 ]] && UNIQ_FAIL=1
fi

if [[ $STRICT -eq 1 && ( $total_unanchored -gt 0 || $total_leaks -gt 0 || $UNIQ_FAIL -eq 1 ) ]]; then
  echo "REFUSED — $total_unanchored unanchored/skeleton + $total_leaks cross-project leak(s)$([[ $UNIQ_FAIL -eq 1 ]] && echo " + anchor uniqueness below floor") (--strict)." >&2
  exit 1
fi
exit 0
