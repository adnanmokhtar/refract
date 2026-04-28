#!/usr/bin/env bash
# test-pack-directory-parity.sh — regression test for the M11 fix.
#
# The M11 bug: a new file landed in templates/packs/<pack>/<kind>/ but
# wasn't registered in the pack's _topics.md manifest. /setup-project --include=<pack>
# read the manifest (not the directory) and reported "no work to do" — the
# new file was invisible.
#
# This test enforces parity between pack directories and _topics.md for packs
# where it matters most. Today: migration. Other packs warned but not failed
# because their conventions vary.
#
# Why _topics.md not _essentials.md:
# _essentials.md is the MINIMAL subset (used by --minimal flag). A pack
# legitimately omits some files from essentials. _topics.md is the
# exhaustive registry used by Phase 4.2-AUTHOR. The bug pattern affects
# _topics.md, not _essentials.md.
#
# Exits 0 if migration pack is clean; 1 if it has gaps. Other packs always warn.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

# Packs where the parity is treated as ERROR. Add to this list when a pack
# starts shipping content that --include=<pack> users rely on.
STRICT_PACKS=("migration")

errors=0
warnings=0

is_strict() {
  local pack="$1"
  for sp in "${STRICT_PACKS[@]}"; do
    [[ "$sp" == "$pack" ]] && return 0
  done
  return 1
}

for pack_dir in "$PACKS_ROOT"/*/; do
  pack="$(basename "$pack_dir")"
  [[ "$pack" == _* ]] && continue

  topics="$pack_dir/_topics.md"
  if [[ ! -f "$topics" ]]; then
    echo "  SKIP $pack: no _topics.md"
    continue
  fi

  for kind in commands agents skills rules ai-patterns; do
    kind_dir="$pack_dir/$kind"
    [[ -d "$kind_dir" ]] || continue

    while IFS= read -r f; do
      base="$(basename "$f" .md)"
      [[ "$base" == _* ]] && continue

      if ! grep -qE "^- name: $base$" "$topics"; then
        if is_strict "$pack"; then
          echo "  ERR  $pack/_topics.md missing entry: $kind/$base"
          errors=$((errors + 1))
        else
          echo "  WARN $pack/_topics.md missing entry: $kind/$base"
          warnings=$((warnings + 1))
        fi
      fi
    done < <(find "$kind_dir" -maxdepth 1 -name '*.md' -not -name '_*' | sort)
  done
done

echo ""
echo "result: $errors errors / $warnings warnings"

if [[ "$errors" -gt 0 ]]; then
  echo ""
  echo "FAIL: strict pack(s) have files in <kind>/ that aren't in _topics.md."
  echo "Fix: open templates/packs/<pack>/_topics.md and add an entry under the"
  echo "matching '# ============ <KIND> ============' section:"
  echo ""
  echo "  - name: <file-base-name>"
  echo "    kind: <command|agent|skill|rule|ai-pattern>"
  echo "    triggers:"
  echo "      always: true"
  echo "    sections: [...]"
  echo "    fallback: commands/<file>.md"
  echo ""
  echo "Without this, /setup-project --include=<pack> can't see the new file."
  exit 1
fi

exit 0
