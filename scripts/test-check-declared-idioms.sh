#!/usr/bin/env bash
# test-check-declared-idioms.sh — pin check-declared-idioms.sh on the cases that decide a run.
#
# The check is the only proof that a unit built on purpose (fewer than three users, so below the
# extraction threshold) survives a /setup-project run. A check that passes with the row dropped
# brings back the loop it exists for: the command that halted for the unit halts again. So every
# fixture asserts the exit code AND the line the person reads.
#
# Usage: test-check-declared-idioms.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
CHECK="$REPO_ROOT/scripts/check-declared-idioms.sh"
STUB="$REPO_ROOT/templates/repo-baseline/ai/declared-idioms.md"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

TD="$(mktemp -d "${TMPDIR:-/tmp}/declared-idioms.XXXXXX")"
trap 'rm -rf "$TD"' EXIT
pass=0; failn=0

# expect <name> <want-exit> <want-substring> <project-dir>
expect() {
  local name="$1" want="$2" needle="$3" dir="$4" out rc
  out="$(bash "$CHECK" "$dir" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ] && printf '%s' "$out" | grep -qF -- "$needle"; then
    pass=$((pass + 1)); [ "$QUIET" = 1 ] || echo "  ok   $name"
  else
    failn=$((failn + 1)); echo "  FAIL $name — exit $rc (want $want), output: $out"
  fi
}

mk() { mkdir -p "$TD/$1/ai" "$TD/$1/.claude"; printf '%s\n' "$TD/$1"; }
row() { printf '| %s | %s | role | /add-component | 2026-11-28 |\n' "$1" "$2"; }

# 1. no declared file → nothing to keep
p="$(mk none)"; printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "no ai/declared-idioms.md passes" 0 "none (no ai/declared-idioms.md)" "$p"

# 2. the shipped baseline stub has a header and a separator and no row
p="$(mk stub)"; cp "$STUB" "$p/ai/declared-idioms.md"; printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "the baseline stub reads as 0 rows" 0 "0 rows" "$p"

# 3. a declared wrapper the extraction named → kept
p="$(mk kept)"; { cat "$STUB"; row wrapper '`src/ui/AppDialog.vue`'; } > "$p/ai/declared-idioms.md"
printf '## Wrappers\n- AppDialog (src/ui/AppDialog.vue) — modal wrapper — 1 usage site [declared: ai/declared-idioms.md]\n' > "$p/.claude/_extracted-idioms.md"
expect "a declared path the extraction named passes (backticks trimmed)" 0 "1/1 kept" "$p"

# 4. the regeneration dropped it → fail, naming the path
p="$(mk dropped)"; { cat "$STUB"; row wrapper 'src/ui/AppDialog.vue'; row tokens 'src/theme/tokens.css'; } > "$p/ai/declared-idioms.md"
printf '## Tokens\n- source: src/theme/tokens.css [declared: ai/declared-idioms.md]\n### Color\n- --color-primary = #0a58ca [found: src/theme/tokens.css:3]\n' > "$p/.claude/_extracted-idioms.md"
expect "a dropped declared path fails and is named" 1 "declared idiom dropped: src/ui/AppDialog.vue" "$p"
expect "the count names how many of how many" 1 "1 of 2 dropped" "$p"

# 5. declared rows but no idioms file at all → fail
p="$(mk noidioms)"; { cat "$STUB"; row composable 'src/composables/useCan.ts'; } > "$p/ai/declared-idioms.md"
expect "declared rows with no _extracted-idioms.md fail" 1 "_extracted-idioms.md is missing" "$p"

# 6. the unit was deleted from disk: Phase 2.5 records it under Strategy → kept, for the person to remove
p="$(mk gone)"; { cat "$STUB"; row service 'src/lib/locale.ts'; } > "$p/ai/declared-idioms.md"
printf '## Strategy\n- declared but missing: src/lib/locale.ts\n' > "$p/.claude/_extracted-idioms.md"
expect "a declared-but-missing line counts as kept" 0 "1/1 kept" "$p"

# 7. the path survives only in a provenance marker, its Wrappers row gone → dropped
p="$(mk provenance)"; { cat "$STUB"; row wrapper 'src/ui/AppDialog.vue'; } > "$p/ai/declared-idioms.md"
printf '## Conventions\n- Dialogs: one modal wrapper [found: src/ui/AppDialog.vue:1]\n' > "$p/.claude/_extracted-idioms.md"
expect "a path left only in a [found:] marker is dropped" 1 "declared idiom dropped: src/ui/AppDialog.vue" "$p"

# 8. "declared but missing" while the file is still on disk → fail
p="$(mk notmissing)"; { cat "$STUB"; row service 'src/lib/locale.ts'; } > "$p/ai/declared-idioms.md"
mkdir -p "$p/src/lib"; : > "$p/src/lib/locale.ts"
printf '## Strategy\n- declared but missing: src/lib/locale.ts\n' > "$p/.claude/_extracted-idioms.md"
expect "declared-but-missing for a file on disk fails" 1 "marked missing but on disk: src/lib/locale.ts" "$p"

# 9. the declared path is only a substring of another kept path → dropped
p="$(mk substring)"; { cat "$STUB"; row wrapper 'src/ui/AppDialog.vue'; } > "$p/ai/declared-idioms.md"
printf '## Wrappers\n- AppDialogOld (src/ui/AppDialog.vue.bak) — 1 usage site [declared: ai/declared-idioms.md]\n' > "$p/.claude/_extracted-idioms.md"
expect "a path that is only a substring of another is dropped" 1 "declared idiom dropped: src/ui/AppDialog.vue" "$p"

# 10. a tokens row is kept by its source line in ## Tokens
p="$(mk tokens)"; { cat "$STUB"; row tokens 'src/theme/tokens.css'; } > "$p/ai/declared-idioms.md"
printf '## Tokens\n- source: src/theme/tokens.css [declared: ai/declared-idioms.md]\n### Color\n- --color-primary = #0a58ca [found: src/theme/tokens.css:3]\n' > "$p/.claude/_extracted-idioms.md"
expect "a tokens row is kept by its source line" 0 "1/1 kept" "$p"

# 11. a capitalised header is still the header, not a dropped row
p="$(mk header)"; printf '| Kind | Path | Role | Declared by | Date |\n|---|---|---|---|---|\n' > "$p/ai/declared-idioms.md"
printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "a capitalised header reads as 0 rows" 0 "0 rows" "$p"

# 12. a row written as a bullet would read as no row and pass with the unit dropped → fail
p="$(mk bullet)"; { cat "$STUB"; printf -- '- wrapper | src/ui/AppDialog.vue | modal\n'; } > "$p/ai/declared-idioms.md"
printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "a bullet row fails as not a table row" 1 "not a table row" "$p"

# 13. an unknown kind (an ability is data, not a unit) → fail
p="$(mk kind)"; { cat "$STUB"; row ability 'packages/ui/src/can/permissions.ts'; } > "$p/ai/declared-idioms.md"
printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "an unknown kind fails" 1 "unknown kind: 'ability'" "$p"

# 14. an empty kind cell must fail, not collapse into "0/0 kept"
p="$(mk emptykind)"; { cat "$STUB"; printf '|  | src/ui/AppDialog.vue | modal | /add-component | 2026-11-28 |\n'; } > "$p/ai/declared-idioms.md"
printf '# idioms\n' > "$p/.claude/_extracted-idioms.md"
expect "an empty kind fails" 1 "unknown kind: ''" "$p"

# 15. the missing line written without its bullet still counts (the file really is gone)
p="$(mk nobullet)"; { cat "$STUB"; row service 'src/lib/locale.ts'; } > "$p/ai/declared-idioms.md"
printf '## Strategy\ndeclared but missing: src/lib/locale.ts\n' > "$p/.claude/_extracted-idioms.md"
expect "a bullet-less declared-but-missing line counts" 0 "1/1 kept" "$p"

# 16. usage
out="$(bash "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then pass=$((pass + 1)); [ "$QUIET" = 1 ] || echo "  ok   no target is a usage error"; else failn=$((failn + 1)); echo "  FAIL no target — exit $rc (want 2)"; fi

echo ""
echo "check-declared-idioms fixtures: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
