#!/usr/bin/env bash
# migration-detect-existing.sh — does V2 already have this feature?
#
# Before /port-feature writes anything, scan the V2 repo for evidence the
# feature is already implemented. The migration ledger is supposed to track
# this, but it drifts; trust the filesystem.
#
# Returns one of three confidence levels (printed to stdout, structured
# report written to <target>/.claude/_migration-detect-<feature>.md):
#
#   none      — nothing in V2 matches; safe to port.
#   partial   — some matches found; manual review required before write.
#   full      — feature is fully present in V2; port would overwrite.
#               Refuse unless --overwrite-v2 is passed by /port-feature.
#
# The script does NOT decide what to do — it gives the orchestrator a
# trusted signal so the user is asked before V2 code is touched.
#
# Usage:
#   migration-detect-existing.sh <v2-target> <feature-slug> [--quiet]
#                                [--stdout | --report=<path>]
#
#   --no-write      READ-ONLY mode. Compute the verdict and write NOTHING under
#                   <v2-target> — not the report, not `.claude/`. This script runs BEFORE
#                   /port-feature writes anything; until now the pre-write safety check
#                   was itself a write. There is deliberately NO `--stdout` here: stdout
#                   carries the verdict token (`none`/`partial`/`full`) that callers read
#                   with $(...), so the report may never be put on it.
#   --report=<path> Write the report to <path> instead. Must use `=`.
#
# Exit codes:
#   0 — clean (regardless of confidence; check stdout for none/partial/full)
#   1 — usage / target missing
#   2 — feature slug invalid

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <v2-target> <feature-slug> [--quiet] [--no-write|--report=<path>]" >&2
  echo "       --no-write = read-only: verdict only, nothing written under <v2-target>." >&2
  exit 1
fi

TARGET="$1"; shift
FEATURE="$1"; shift
QUIET=0
SINK_NOWRITE=0
REPORT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --no-write) SINK_NOWRITE=1; shift ;;
    --stdout) echo "ERR: --stdout is not available here: stdout carries the verdict token that callers read with \$(...). Use --no-write, or --report=<path>." >&2; exit 2 ;;
    --report=*) REPORT_OVERRIDE="${1#*=}"; shift ;;
    # The catch-all below SWALLOWS unknown args, so `--report /tmp/x` would be dropped
    # and the report would land in the target anyway. Refuse the space form explicitly.
    --report) echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *) shift ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }
[[ "$FEATURE" =~ ^[a-z][a-z0-9_-]*$ ]] || { echo "ERR: feature slug must match [a-z][a-z0-9_-]*" >&2; exit 2; }

# Prefer v2_root from ai/migration/_v2-anchors.md over hard-coded src/ (monorepos, Python trees, etc.)
V2_SCAN_ROOT="$TARGET/src"
ANCHORS_FILE="$TARGET/ai/migration/_v2-anchors.md"
if [[ -f "$ANCHORS_FILE" ]]; then
  _vr=$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$ANCHORS_FILE" 2>/dev/null | grep -m1 '^v2_root:' | sed 's/^v2_root:[[:space:]]*//' | tr -d '"' | tr -d "'")
  if [[ -n "$_vr" ]]; then
    _vr="${_vr%/}"
    if [[ "${_vr#/}" != "$_vr" ]]; then
      V2_SCAN_ROOT="$_vr"
    else
      V2_SCAN_ROOT="$TARGET/${_vr#./}"
    fi
  fi
fi
[[ -d "$V2_SCAN_ROOT" ]] || V2_SCAN_ROOT="$TARGET/src"

# ── Report sink ────────────────────────────────────────────────────────────────
# The default sink is a file INSIDE the V2 target, so the "have we already got this
# feature?" probe modified the very repo it was probing.
REPORT="$TARGET/.claude/_migration-detect-$FEATURE.md"
REPORT_TMP=""
if [[ $SINK_NOWRITE -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/migration-detect.XXXXXX")
  trap '[ -n "${REPORT_TMP:-}" ] && rm -f "$REPORT_TMP"; :' EXIT
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(discarded — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# Variants: PascalCase, camelCase, kebab-case from the slug
to_pascal() { echo "$1" | awk -F'[-_]' '{for(i=1;i<=NF;i++) printf "%s", toupper(substr($i,1,1)) substr($i,2); print ""}'; }
to_camel()  { local p; p=$(to_pascal "$1"); echo "$(echo "${p:0:1}" | tr 'A-Z' 'a-z')${p:1}"; }

PASCAL=$(to_pascal "$FEATURE")
CAMEL=$(to_camel "$FEATURE")
KEBAB="$FEATURE"

trace() { [[ $QUIET -eq 0 ]] && echo "  • $*" >&2; }

# Score signals — each one bumps a score; thresholds at the end pick none/partial/full
score=0
matches=()

trace "scanning V2 for feature '$FEATURE' (variants: $PASCAL / $CAMEL / $KEBAB)"

# ---------- Module path ----------
# Score the module-dir signal AT MOST ONCE. A feature can match several candidate
# path layouts (e.g. both src/modules/<kebab>/ and src/<kebab>/), and without a break
# each match added +30 — two layouts alone hit the "full" (≥60) threshold and falsely
# reported "already present". The presence of a module dir is a single +30 signal;
# break after the first non-empty match.
for path in "src/modules/$KEBAB" "src/modules/$CAMEL" "src/features/$KEBAB" \
            "app/$KEBAB" "app/(features)/$KEBAB" "src/$KEBAB"; do
  if [[ -d "$TARGET/$path" ]]; then
    files=$(find "$TARGET/$path" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.vue' -o -name '*.svelte' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.php' \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ $files -gt 0 ]]; then
      matches+=("module-dir: $path/ ($files source files)")
      score=$((score + 30))
      trace "+30 module dir: $path ($files files)"
      break
    fi
  fi
done

# ---------- Service / composable file ----------
service_hits=$(grep -rlE "^(export[[:space:]]+(class|const|function)[[:space:]]+(${PASCAL}Service|use${PASCAL}|${CAMEL}Service))" \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.vue' \
  "$V2_SCAN_ROOT" 2>/dev/null | head -10 || true)
if [[ -n "$service_hits" ]]; then
  count=$(echo "$service_hits" | wc -l | tr -d ' ')
  matches+=("service/composable definitions: $count file(s)")
  score=$((score + 25))
  trace "+25 service/composable: $count files"
  while IFS= read -r f; do
    [[ -n "$f" ]] && matches+=("  - ${f#$TARGET/}")
  done <<<"$(echo "$service_hits" | head -5)"
fi

# ---------- Route registration ----------
route_hits=$(grep -rlE "(path:[[:space:]]*['\"]/${KEBAB}|name:[[:space:]]*['\"]${PASCAL}|component:.*${PASCAL})" \
  --include='*.ts' --include='*.tsx' --include='*.vue' --include='*.js' \
  "$V2_SCAN_ROOT" 2>/dev/null | head -5 || true)
if [[ -n "$route_hits" ]]; then
  count=$(echo "$route_hits" | wc -l | tr -d ' ')
  matches+=("route definitions: $count file(s)")
  score=$((score + 20))
  trace "+20 route registrations: $count files"
fi

# ---------- i18n keys ----------
locale_dirs=$(find "$V2_SCAN_ROOT" "$TARGET/src" -type d \( -name 'locales' -o -name 'i18n' -o -name 'translations' \) 2>/dev/null | head -8)
if [[ -n "$locale_dirs" ]]; then
  i18n_hits=$(grep -rlE "(\"${PASCAL}\\.|\"${CAMEL}\\.|^[[:space:]]+${PASCAL}:|^[[:space:]]+${CAMEL}:)" \
    $locale_dirs 2>/dev/null | head -5 || true)
  if [[ -n "$i18n_hits" ]]; then
    count=$(echo "$i18n_hits" | wc -l | tr -d ' ')
    matches+=("i18n keys: $count locale file(s) reference \`$PASCAL\`/\`$CAMEL\`")
    score=$((score + 15))
    trace "+15 i18n keys: $count files"
  fi
fi

# ---------- Tests ----------
test_hits=$(find "$TARGET" -path '*/node_modules' -prune -o \
  -type f \( -name "${PASCAL}*.spec.*" -o -name "${PASCAL}*.test.*" \
            -o -name "${CAMEL}*.spec.*" -o -name "${CAMEL}*.test.*" \
            -o -name "${KEBAB}*.spec.*" -o -name "${KEBAB}*.test.*" \) -print 2>/dev/null | head -5)
if [[ -n "$test_hits" ]]; then
  count=$(echo "$test_hits" | wc -l | tr -d ' ')
  matches+=("test files: $count")
  score=$((score + 10))
  trace "+10 test files: $count"
fi

# ---------- Verdict ----------
verdict="none"
if [[ $score -ge 60 ]]; then
  verdict="full"
elif [[ $score -ge 20 ]]; then
  verdict="partial"
fi

# ---------- Build report ----------
{
  printf '# Migration detection — feature `%s` in V2\n\n' "$FEATURE"
  printf 'Target: `%s`\n' "$TARGET"
  printf 'Generated by: scripts/migration-detect-existing.sh\n'
  printf 'Confidence: **%s** (score: %d / 100)\n\n' "$verdict" "$score"
  printf -- '---\n\n## Signals matched\n\n'
  if [[ ${#matches[@]} -eq 0 ]]; then
    printf '_No matches — V2 has no detectable evidence of this feature._\n\n'
  else
    for m in "${matches[@]}"; do
      printf -- '- %s\n' "$m"
    done
    printf '\n'
  fi
  printf '## Verdict + recommended action\n\n'
  case "$verdict" in
    none)
      printf '**none** — V2 has no detectable evidence of this feature.\n\n'
      printf '`/port-feature %s` may proceed without overwrite risk.\n' "$FEATURE"
      ;;
    partial)
      printf '**partial** — V2 has some files / references that match.\n\n'
      printf 'STOP. Before porting:\n'
      printf -- '1. Open each matched file above and decide whether it'"'"'s a stub, an obsolete attempt, or a working partial implementation.\n'
      printf -- '2. If working partial → continue developing it; do NOT port from V1 over it. Update the ledger entry to `In-progress` with V2-side authorship.\n'
      printf -- '3. If stub / obsolete → user runs `/port-feature %s --merge-existing` (the agent will surface diffs file-by-file).\n' "$FEATURE"
      printf -- '4. If unsure → run `/compare-v1 %s` to see V1 contract vs V2 partial.\n' "$FEATURE"
      ;;
    full)
      printf '**full** — V2 already implements this feature.\n\n'
      printf '`/port-feature %s` MUST refuse without `--overwrite-v2`.\n\n' "$FEATURE"
      printf 'Right next steps:\n'
      printf -- '1. Update the ledger row for `%s` to `V2-only` (or whatever stage applies — `V2-shadow` if not yet routed, etc.).\n' "$FEATURE"
      printf -- '2. If V2'"'"'s implementation diverges from V1 contract → run `/compare-v1 %s` for parity audit; address findings.\n' "$FEATURE"
      printf -- '3. If you intentionally want to re-port from V1 (rare — usually a regression) → backup V2 first, then `/port-feature %s --overwrite-v2`. The override is logged to `ai/migration/_history.md`.\n' "$FEATURE"
      ;;
  esac
} > "$REPORT"

# --no-write: the report was buffered off-target and is discarded here. The verdict —
# the only thing a caller consumes — is unaffected, and $TARGET is untouched.
if [[ -n "$REPORT_TMP" ]]; then
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

[[ $QUIET -eq 0 ]] && echo "verdict=$verdict score=$score report=$REPORT_LABEL" >&2
echo "$verdict"
exit 0
