#!/usr/bin/env bash
# wire-rule-imports.sh — make .claude/rules/ actually LOAD.
#
# THE DEFECT THIS SCRIPT EXISTS FOR
# --------------------------------
# The framework's own docs are unambiguous. `.claude/rules/README.md`:
#
#     Claude Code does not auto-load `.claude/rules/` on its own — the `CLAUDE.md`
#     import is what makes these always-on.
#
# and `templates/repo-baseline/.claude/GUIDE.md` repeats it. The four `@.claude/rules/…`
# import lines existed in exactly ONE place: `templates/repo-baseline/CLAUDE.md`, a
# GREENFIELD file. ENHANCE mode never applies it — `apply-baseline-sync.sh` classifies an
# existing CLAUDE.md as KEEP-OURS and preserves it verbatim, which is correct. So:
#
#     grep -rn '@\.claude/rules' scripts/ templates/phases/ commands/   ->  EMPTY
#
# Nothing in the framework ever wrote an import into a real project's CLAUDE.md. Measured on
# two live repos: 0 import lines in either CLAUDE.md, 221,560 bytes of always-tier rules in
# one and 99,763 in the other, loading ZERO times per turn. Every pack rule the packs ship —
# backend-principles, security-principles, multi-tenancy, testing-principles — was dead weight
# on disk. The documented fallback was dead too: inject-path-rules.sh is registered in no
# settings.json at any scope. And the breakage was silently load-bearing elsewhere: the backend
# `refactor` overlay deliberately OMITS layering and DI guidance on the stated grounds that
# "backend-principles.md is always loaded whenever this command runs" — a sentence that was
# false in both halves.
#
# WHY THIS IS NOT JUST "IMPORT EVERYTHING"
# ----------------------------------------
# Wiring every always-tier rule in that first repo would have cost ~73,595 tokens PER TURN.
# Shipping 0 and shipping 73k are both wrong answers. So this script measures first, imports
# the foundational set unconditionally, and for pack rules imports only what fits the budget —
# naming the overflow and the exact remedy (`scope-rules.sh`, which makes a rule path-scoped
# and therefore free until matched) instead of silently choosing either extreme.
#
# CONTRACT
#   * Writes ONE managed block into <target>/CLAUDE.md. Everything outside the markers is
#     preserved byte-for-byte — this is additive to a KEEP-OURS file, never a rewrite.
#   * Idempotent: re-running replaces the block's contents, never appends a second one.
#   * Never imports a path-scoped rule (it carries `paths:` and is injected on match).
#
# Usage:  wire-rule-imports.sh <target-repo> [--apply] [--budget=<tokens>]
# Exit:   0 wired (or would-wire) within budget
#         1 usage / target error
#         3 wired the foundational set, but pack rules overflow the budget (advisory)

set -uo pipefail
export LC_ALL=C

TARGET=""; APPLY=0; BUDGET="${RULE_BUDGET_TOKENS:-12000}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)    APPLY=1; shift ;;
    --budget=*) BUDGET="${1#--budget=}"; shift ;;
    -h|--help)  sed -n '1,45p' "$0"; exit 0 ;;
    *)          [[ -z "$TARGET" ]] && TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" && -d "$TARGET" ]] || { echo "Usage: $0 <target-repo> [--apply] [--budget=N]" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd -P)"
RULES_DIR="$TARGET/.claude/rules"
CLAUDE_MD="$TARGET/CLAUDE.md"

[[ -d "$RULES_DIR" ]] || { echo "no .claude/rules/ in $TARGET — nothing to wire"; exit 0; }

MARK_OPEN='<!-- setup-project:managed start id=rule-imports -->'
MARK_CLOSE='<!-- setup-project:managed end -->'

# Same two-tier test check-rule-budget.sh uses: a `paths:` key in the leading frontmatter.
is_path_scoped() {
  head -1 "$1" | grep -qE '^---[[:space:]]*$' || return 1
  awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^paths:/{found=1} END{exit !found}' "$1"
}
tok() { echo $(( $(wc -c < "$1") / 4 )); }

# The four the baseline declares foundational. Imported regardless of budget: they ARE the
# budget's floor, and templates/repo-baseline/CLAUDE.md has shipped exactly these since it
# existed.
FOUNDATIONAL="read-before-write read-codebase-deeply think-simplify-surgical code-quality"

declare -a IMPORT_LIST=() OVERFLOW=() SCOPED=()
total=0

# Pass 1 — foundational first, in the baseline's own order.
for name in $FOUNDATIONAL; do
  f="$RULES_DIR/$name.md"
  [[ -f "$f" ]] || continue
  is_path_scoped "$f" && { SCOPED+=("$name.md"); continue; }
  t=$(tok "$f"); total=$((total + t))
  IMPORT_LIST+=("$name.md|$t")
done

# Pass 2 — every other always-tier rule, smallest first so the budget buys the most rules.
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  [[ "$base" == "README.md" ]] && continue
  case " $FOUNDATIONAL " in *" ${base%.md} "*) continue ;; esac
  if is_path_scoped "$f"; then SCOPED+=("$base"); continue; fi
  t=$(tok "$f")
  if [[ $((total + t)) -le "$BUDGET" ]]; then
    total=$((total + t)); IMPORT_LIST+=("$base|$t")
  else
    OVERFLOW+=("$base|$t")
  fi
done < <(for g in "$RULES_DIR"/*.md; do [[ -e "$g" ]] || continue; printf '%s\t%s\n' "$(wc -c < "$g")" "$g"; done | sort -n | cut -f2)

echo "=== wire-rule-imports ==="
echo "Target:  $TARGET"
echo "Mode:    $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Budget:  $BUDGET tok (always-loaded rules)"
echo ""
echo "Will import (always-tier, loads every turn):"
for row in ${IMPORT_LIST[@]+"${IMPORT_LIST[@]}"}; do
  printf '  %-44s ~%5d tok\n' ".claude/rules/${row%%|*}" "${row##*|}"
done
printf '  %-44s ~%5d tok\n' "TOTAL" "$total"

if [[ ${#SCOPED[@]} -gt 0 ]]; then
  echo ""
  echo "Path-scoped (NOT imported — injected on match, free until then): ${#SCOPED[@]}"
fi

rc=0
if [[ ${#OVERFLOW[@]} -gt 0 ]]; then
  ov_tok=0
  for row in "${OVERFLOW[@]}"; do ov_tok=$((ov_tok + ${row##*|})); done
  echo ""
  echo "OVER BUDGET — ${#OVERFLOW[@]} always-tier rule(s), ~$ov_tok tok, NOT imported:"
  for row in "${OVERFLOW[@]}"; do
    printf '  %-44s ~%5d tok\n' ".claude/rules/${row%%|*}" "${row##*|}"
  done
  echo ""
  echo "These rules are on disk and will NOT load. That is a deliberate refusal, not an"
  echo "oversight: importing them costs ~$ov_tok tok on EVERY turn. Make them free instead —"
  echo "  ~/.claude/scripts/scope-rules.sh \".claude/rules/<name>.md\" \"<glob>,<glob>\""
  echo "adds \`paths:\` frontmatter, after which inject-path-rules.sh loads them ONLY when"
  echo "Claude touches matching source. Re-run this script afterwards. Raise --budget only"
  echo "with the per-turn cost above in front of you."
  rc=3
fi

# ---- compose the managed block ----
block="$MARK_OPEN"$'\n'
block+="<!-- Written by scripts/wire-rule-imports.sh. Everything outside these two markers is"$'\n'
block+="     yours and is never touched. Claude Code does not auto-load .claude/rules/ — these"$'\n'
block+="     @-imports are what make them load. Delete a line to stop loading that rule. -->"$'\n'
block+=$'\n'"## Project rules (always-loaded)"$'\n'$'\n'
for row in ${IMPORT_LIST[@]+"${IMPORT_LIST[@]}"}; do
  block+="@.claude/rules/${row%%|*}"$'\n'
done
block+=$'\n'"$MARK_CLOSE"

if [[ "$APPLY" -eq 0 ]]; then
  echo ""
  echo "Dry run — pass --apply to write the block into CLAUDE.md."
  exit $rc
fi

ts=$(date +%Y%m%d-%H%M%S)
if [[ -f "$CLAUDE_MD" ]]; then
  mkdir -p "$TARGET/.claude/backups/rule-imports-$ts"
  cp "$CLAUDE_MD" "$TARGET/.claude/backups/rule-imports-$ts/CLAUDE.md"
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/wire-imports.XXXXXX")
blkfile=$(mktemp "${TMPDIR:-/tmp}/wire-block.XXXXXX")
printf '%s\n' "$block" > "$blkfile"
# The block is passed as a FILE, never through `awk -v`. A multi-line -v assignment is
# escape-processed by awk and silently mangles or empties the output — this exact shortcut
# truncated CLAUDE.md to zero bytes on its first idempotency re-run during development.
if [[ -f "$CLAUDE_MD" ]] && grep -qF "$MARK_OPEN" "$CLAUDE_MD"; then
  # Replace the existing block in place — idempotent, no second copy.
  # NB: the awk variables are `mopen`/`mclose`, NOT `open`/`close`. `close` is an awk BUILT-IN
  # function name; passing `-v close=…` shadows it, and the `close(bf)` call below then makes
  # awk abort with an empty result — which the guard beneath catches, but only after wasting a
  # run. Same family of silent-truncation bug as the `-v blk=` shortcut noted above.
  awk -v mopen="$MARK_OPEN" -v mclose="$MARK_CLOSE" -v bf="$blkfile" '
    index($0, mopen) { while ((getline l < bf) > 0) print l; close(bf); skip=1; next }
    skip { if (index($0, mclose)) skip=0; next }
    { print }
  ' "$CLAUDE_MD" > "$tmp"
  action="UPDATE"
else
  { [[ -f "$CLAUDE_MD" ]] && cat "$CLAUDE_MD"; [[ -f "$CLAUDE_MD" ]] && echo ""; cat "$blkfile"; } > "$tmp"
  action="ADD"
fi
# Refuse to write an empty result over a non-empty file — a belt-and-braces guard on the
# class of bug above, which is silent, total, and only visible on the SECOND run.
if [[ -s "$CLAUDE_MD" && ! -s "$tmp" ]]; then
  echo "  ERR  refusing to write an empty CLAUDE.md (block assembly produced nothing) — target untouched" >&2
  rm -f "$tmp" "$blkfile"
  exit 1
fi
cat "$tmp" > "$CLAUDE_MD"
rm -f "$tmp" "$blkfile"

echo ""
echo "  $action  CLAUDE.md  (managed block id=rule-imports; ${#IMPORT_LIST[@]} import(s), ~$total tok/turn)"
[[ -f "$TARGET/.claude/backups/rule-imports-$ts/CLAUDE.md" ]] && echo "  Backup: .claude/backups/rule-imports-$ts/CLAUDE.md"
exit $rc
