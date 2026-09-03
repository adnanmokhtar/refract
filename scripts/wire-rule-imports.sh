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

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
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

# Same two-tier test check-rule-budget.sh and audit-setup.sh C2u use: a path-scoping key in
# the leading frontmatter.
#
# `globs:` COUNTS. The framework writes `paths:`, but the ADAPTER contract maps a rule's
# `paths:` to `globs:` for Cursor, Continue and Windsurf — so `globs:` is the same declaration
# in the vocabulary this repo already ships, and a project whose rules were authored against
# that vocabulary was being read as if it had declared nothing. MEASURED on the reference monorepo: 8
# rules declaring `globs: "**/controllers/**/*.ts"` and the like were wired as ALWAYS-loaded,
# spending 3,427 tok of a 12,000 tok budget on every turn regardless of which file was open,
# while 22 genuinely global principle rules (backend-principles, security-principles,
# testing-principles, quality-principles …) did not fit and never loaded at all — and the
# audit then failed the run for exactly that. `grep -rln 'globs:' scripts/` returned nothing:
# no script in the framework had ever looked for the key its own adapters emit.
# Fixture: scripts/test-rule-loading.sh § 1.
is_path_scoped() {
  head -1 "$1" | grep -qE '^---[[:space:]]*$' || return 1
  awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^(paths|globs):/{found=1} END{exit !found}' "$1"
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
  # README.md and `_`-prefixed records (e.g. _unloaded.md, written below) are not rules.
  [[ "$base" == "README.md" || "$base" == _* ]] && continue
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
  echo "  $SELF_DIR/scope-rules.sh \".claude/rules/<name>.md\" \"<glob>,<glob>\""
  echo "adds \`paths:\` frontmatter, after which inject-path-rules.sh loads them ONLY when"
  echo "Claude touches matching source. Re-run this script afterwards. Raise --budget only"
  echo "with the per-turn cost above in front of you."
  rc=3
fi

# ---- the refusal LEDGER -----------------------------------------------------------------
#
# THE DEADLOCK THIS BREAKS. This script declines over-budget rules and says so in plain words.
# audit-setup.sh C2u then FAILS the run for exactly that decision — "N always-tier rule(s) are
# installed but NOT imported by CLAUDE.md, so they never load" — and the escape hatch it printed
# was dead too, because a path-scoped rule needs inject-path-rules.sh registered and that hook
# was registered in no settings.json in either live repo. Two mandatory steps of the same run,
# in direct opposition, with no reachable state that satisfies both: 20 rules on the reference monorepo,
# 4 on the sibling repo, and /setup-project unable to exit 0 either way.
#
# A refusal a reader can FIND is a different object from a refusal that is only a line of
# scrollback. This writes the decision to `.claude/rules/_unloaded.md` — next to the rules it
# is about — with the per-rule token cost and both remedies. C2u reads that file: a rule
# recorded there is a WARN (an owned decision), a rule that is simply missing from CLAUDE.md
# with no record is still an ERR (an oversight). The ledger is REGENERATED from the live budget
# computation on every run, so it cannot rubber-stamp: scope a rule, or raise the budget, and
# the rule leaves the ledger by itself. Fixture: scripts/test-rule-loading.sh § 2.
UNLOADED_MD="$RULES_DIR/_unloaded.md"
if [[ "$APPLY" -eq 1 ]]; then
  if [[ ${#OVERFLOW[@]} -gt 0 ]]; then
    {
      printf '# Rules on disk that do NOT load

'
      printf '<!-- Written by scripts/wire-rule-imports.sh. Regenerated on every run: a rule that
'
      printf '     later fits the budget, or gains `paths:`/`globs:` frontmatter, disappears from this
'
      printf '     list by itself. Do not hand-edit — edit the rules or the budget. -->

'
      printf 'The always-loaded import budget is **%s tok/turn**. %d rule(s) below it did not fit, so
' "$BUDGET" "${#OVERFLOW[@]}"
      printf 'CLAUDE.md does not `@`-import them and **Claude never reads them**. This is a recorded
'
      printf 'decision, not an oversight — but it is a decision, and these are the words it costs:

'
      printf '| rule | ~tok/turn if imported | status |
|---|---:|---|
'
      for row in "${OVERFLOW[@]}"; do
        printf '| `.claude/rules/%s` | %s | NOT LOADED |
' "${row%%|*}" "${row##*|}"
      done
      printf '
Total withheld: **~%d tok/turn** across %d rule(s).

' "$ov_tok" "${#OVERFLOW[@]}"
      printf 'Two ways to make one of them load:

'
      printf '1. **Path-scope it** (free until matched) —
'
      printf '   `scripts/scope-rules.sh ".claude/rules/<name>.md" "<glob>,<glob>"`, then re-run
'
      printf '   `scripts/wire-rule-imports.sh <target> --apply`. Requires `.claude/hooks/inject-path-rules.sh`
'
      printf '   to be registered as a PreToolUse hook — this script registers it for you when the hook
'
      printf '   file is present.
'
      printf '2. **Raise the budget** — `scripts/wire-rule-imports.sh <target> --apply --budget=N`,
'
      printf '   with the per-turn cost in the table above in front of you.
'
    } > "$UNLOADED_MD"
    echo ""
    echo "  RECORD  .claude/rules/_unloaded.md  (${#OVERFLOW[@]} rule(s), ~$ov_tok tok/turn withheld)"
  elif [[ -f "$UNLOADED_MD" ]]; then
    rm -f "$UNLOADED_MD"
    echo ""
    echo "  CLEAR   .claude/rules/_unloaded.md  (every always-tier rule now loads)"
  fi
fi

# ---- make the path-scoped tier actually LIVE --------------------------------------------
#
# The documented escape hatch above is a lie unless inject-path-rules.sh is registered. It was
# registered in no settings.json in either live repo, so "path-scope it and it loads on match"
# was advice that could not be followed — and audit-setup.sh C2u printed the WARN proving it in
# the same run that printed the advice. Scoping a rule into a tier that does not run is worse
# than leaving it unloaded, because the reader believes the opposite.
# Fixture: scripts/test-rule-loading.sh § 3.
HOOK_REL='.claude/hooks/inject-path-rules.sh'
SETTINGS="$TARGET/.claude/settings.json"
if [[ ${#SCOPED[@]} -gt 0 && -f "$TARGET/$HOOK_REL" ]]; then
  if grep -qF 'inject-path-rules' "$SETTINGS" 2>/dev/null \
     || grep -qF 'inject-path-rules' "$TARGET/.claude/settings.local.json" 2>/dev/null; then
    :
  elif [[ "$APPLY" -eq 1 ]] && command -v python3 >/dev/null 2>&1; then
    if python3 - "$SETTINGS" "$HOOK_REL" <<'PYHOOK'
import json, os, sys
path, hook = sys.argv[1], sys.argv[2]
cmd = 'cd "${CLAUDE_PROJECT_DIR:-.}" && ' + hook
data = {}
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        sys.exit(2)          # never overwrite a settings.json we could not parse
    if not isinstance(data, dict):
        sys.exit(2)
hooks = data.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])
if not isinstance(pre, list):
    sys.exit(2)
target = None
for entry in pre:
    if isinstance(entry, dict) and entry.get("matcher") == "Edit|Write|MultiEdit":
        target = entry
        break
if target is None:
    target = {"matcher": "Edit|Write|MultiEdit", "hooks": []}
    pre.append(target)
lst = target.setdefault("hooks", [])
if any(isinstance(h, dict) and "inject-path-rules" in str(h.get("command", "")) for h in lst):
    sys.exit(1)              # already there — nothing to do
lst.append({"type": "command", "command": cmd})
os.makedirs(os.path.dirname(path), exist_ok=True)
if os.path.exists(path):
    import shutil, time
    bdir = os.path.join(os.path.dirname(path), "backups", "rule-imports-" + time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(bdir, exist_ok=True)
    shutil.copy2(path, os.path.join(bdir, "settings.json"))
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYHOOK
    then
      echo "  WIRE    .claude/settings.json  (PreToolUse Edit|Write|MultiEdit → $HOOK_REL)"
      echo "          ${#SCOPED[@]} path-scoped rule(s) can now load on match. Without this the"
      echo "          path-scoped tier is inert and \`scope-rules.sh\` is advice that cannot be followed."
    else
      rcp=$?
      [[ "$rcp" -eq 2 ]] && echo "  WARN    could not register $HOOK_REL in .claude/settings.json (unreadable or unexpected shape) — the ${#SCOPED[@]} path-scoped rule(s) will NOT load. Register it as a PreToolUse hook by hand."
    fi
  else
    echo "  NOTE    ${#SCOPED[@]} path-scoped rule(s) need $HOOK_REL registered as a PreToolUse hook"
    echo "          or they never load. Pass --apply and this script registers it."
  fi
elif [[ ${#SCOPED[@]} -gt 0 ]]; then
  echo "  WARN    ${#SCOPED[@]} path-scoped rule(s) installed but $HOOK_REL is not on disk — the"
  echo "          path-scoped tier cannot run, so those rules never load by any route."
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
# `mv`, not `cat >`. The redirect TRUNCATES CLAUDE.md and then refills it, so an interruption
# between the two leaves a partial or empty file — the user's whole project entry point. `$tmp` is
# already complete one line above, so a rename is both atomic and simpler.
mv "$tmp" "$CLAUDE_MD"
rm -f "$tmp" "$blkfile"

echo ""
echo "  $action  CLAUDE.md  (managed block id=rule-imports; ${#IMPORT_LIST[@]} import(s), ~$total tok/turn)"
[[ -f "$TARGET/.claude/backups/rule-imports-$ts/CLAUDE.md" ]] && echo "  Backup: .claude/backups/rule-imports-$ts/CLAUDE.md"
exit $rc
