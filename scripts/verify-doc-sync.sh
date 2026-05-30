#!/usr/bin/env bash
# verify-doc-sync.sh — enforce the manual 7-surface sync chain mechanically:
#   (1) every pack has _essentials.md + _topics.md + _version.json
#   (2) every real command file (root + packs) is referenced in docs/COMMANDS.md or docs/REFERENCE.md
#   (3) every command-like `/token` in the docs that has NO backing command file (dangling ref)
# (1)+(2) are FAIL (CI-blocking); (3) is WARN (example invocations are hard to distinguish from
# genuine dangling refs, so it surfaces for human review rather than failing the build).
#
# Usage:  verify-doc-sync.sh [--repo-root=<dir>] [--strict]   (--strict promotes WARN→FAIL)
# Exit:   1 on any FAIL (or any WARN under --strict); 0 otherwise.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --strict) STRICT=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1

COMMANDS_DOC="docs/COMMANDS.md"
REFERENCE_DOC="docs/REFERENCE.md"
fail=0
warn=0

# ---- (1) pack sync-file completeness ----
echo "[1] pack sync-file completeness (_essentials / _topics / _version)"
for d in templates/packs/*/; do
  [ -d "$d" ] || continue   # no-packs fixture / nullglob-off literal guard
  p=$(basename "$d")
  for req in _essentials.md _topics.md _version.json; do
    [ -f "$d$req" ] || { echo "  FAIL  pack '$p' missing $req"; fail=$((fail + 1)); }
  done
done
[ "$fail" -eq 0 ] && echo "  ok — all packs carry the 3 sync files"

# ---- (2) every real command documented ----
echo "[2] command → docs coverage"
DOCS_BLOB="$( { [ -f "$COMMANDS_DOC" ] && cat "$COMMANDS_DOC"; [ -f "$REFERENCE_DOC" ] && cat "$REFERENCE_DOC"; } 2>/dev/null )"
# Real command names: root commands/ + every pack commands/ (dedup; ignore _* helpers).
REAL_CMDS="$( { ls commands/*.md 2>/dev/null; find templates/packs/*/commands -name '*.md' 2>/dev/null; \
                ls templates/repo-baseline/.claude/commands/*.md 2>/dev/null; } \
              | xargs -n1 basename 2>/dev/null | sed 's/\.md$//' | grep -vE '^_' | sort -u || true )"
missing_doc=0
for c in $REAL_CMDS; do
  # Documented if the doc blob mentions `/<name>` as a whole token.
  grep -qE "/${c}([^a-z0-9-]|$)" <<<"$DOCS_BLOB" || { echo "  FAIL  /$c is a real command but NOT in COMMANDS.md/REFERENCE.md"; missing_doc=$((missing_doc + 1)); }
done
fail=$((fail + missing_doc))
[ "$missing_doc" -eq 0 ] && echo "  ok — every command is documented"

# ---- (3) dangling /token refs in docs (WARN) ----
echo "[3] docs → command backing (dangling refs)"
# Only BACKTICK-wrapped `/command` tokens are real invocations — this excludes path segments
# (e.g. `templates/governance/core-discipline.md`) that a bare `/foo` regex would false-match.
DOC_TOKENS="$(grep -rhoE '`/[a-z][a-z0-9]+(-[a-z0-9]+)*' "$COMMANDS_DOC" "$REFERENCE_DOC" 2>/dev/null \
              | sed 's#^`/##' | sort -u || true)"
dangling=0
for t in $DOC_TOKENS; do
  # Backed if a command file of that exact name exists.
  if [ -f "commands/$t.md" ] || [ -f "templates/repo-baseline/.claude/commands/$t.md" ] \
     || find templates/packs/*/commands -name "$t.md" 2>/dev/null | grep -q .; then
    continue
  fi
  # Skip if it's an example invocation = a real command name followed by '-<args>'.
  is_example=0
  for c in $REAL_CMDS; do
    case "$t" in "$c"-*) is_example=1; break ;; esac
  done
  [ "$is_example" -eq 1 ] && continue
  echo "  WARN  /$t referenced in docs but no backing command file (dangling ref or undocumented example)"
  dangling=$((dangling + 1))
done
warn=$((warn + dangling))
[ "$dangling" -eq 0 ] && echo "  ok — no dangling command refs"

echo ""
echo "doc-sync: FAIL=$fail WARN=$warn"
if [ "$fail" -gt 0 ] || { [ "$STRICT" -eq 1 ] && [ "$warn" -gt 0 ]; }; then
  exit 1
fi
exit 0
