#!/usr/bin/env bash
# _extraction-fingerprint.sh — the content fingerprint of a target's extraction substrate.
#
# Sourced by audit-setup.sh (to test a KNOWLEDGE-CURRENT ledger entry) and by
# apply-study-decisions.sh (to stamp one). Both must compute it identically, which is
# why it lives here rather than being written twice.
#
# WHY CONTENT AND NOT MTIME. audit-setup.sh's STALE_KNOWLEDGE check compares mtimes, and
# an mtime answers "was this file written?" when the question is "did what it says change?".
# Measured across four real repos after a detector fix unlocked packs that had been wrongly
# excluded: two repos had a byte-identical substrate, and the entire delta in the other two
# was four `- track:` lines — a list of which PACKS are installed, which is tooling, never a
# fact about the code. All four had all six knowledge files flagged, demanding a rewrite of
# roughly 4,000 lines of accurate, expensively-derived analysis. A fingerprint over content
# cannot make that mistake, and it cannot be reset by merely touching a file.
#
# WHAT IS IN IT. The files ai/ knowledge is actually derived from:
#   - codebase-profile.md   MINUS its `- track:` roster (see above)
#   - _extracted-idioms.md
#   - _extracted-business.md
#   - _codebase-scan.md     sections 8-15 only — the model-written analysis. Sections 1-7
#                           are a mechanical census that no knowledge file reads.
# Missing files contribute nothing rather than failing: a target that never had one is not
# the same as one whose file changed.
#
# Usage:  extraction_fingerprint <target-repo>   -> prints 8 hex chars, or nothing on failure.

extraction_fingerprint() {
  local target="$1" c="" f
  [[ -n "$target" && -d "$target/.claude" ]] || return 0

  f="$target/.claude/codebase-profile.md"
  [[ -f "$f" ]] && c+=$(grep -v '^- track:' "$f" 2>/dev/null)

  for f in "$target/.claude/_extracted-idioms.md" "$target/.claude/_extracted-business.md"; do
    [[ -f "$f" ]] && c+=$(cat "$f" 2>/dev/null)
  done

  f="$target/.claude/_codebase-scan.md"
  if [[ -f "$f" ]] && grep -q '^## 8\.' "$f" 2>/dev/null; then
    c+=$(sed -n '/^## 8\./,$p' "$f" 2>/dev/null)
  fi

  [[ -n "$c" ]] || return 0
  printf '%s' "$c" | shasum -a 256 2>/dev/null | cut -c1-8
}
