#!/usr/bin/env bash
# lint-workflow-yaml.sh — every .github/workflows/*.yml must actually PARSE as YAML.
#
# WHY. On 2026-08-24 the badge on the README read `quality-gates.yml failing` for three
# consecutive commits, and nothing in the repo could say why: every gate passed locally,
# and the run page listed no failed step. It listed none because no step ever ran. One
# step name was
#
#     - name: Rule loading (globs: scoping, recorded refusal, live path-scoped tier)
#
# and `globs: ` — a colon followed by a space inside an unquoted scalar — makes YAML read
# the rest as a nested mapping. GitHub rejected the whole FILE, so the 37 gates it defines
# did not execute. Three commits went out with the entire suite silently not running.
#
# That is the worst version of this repo's recurring shape: not a check that dispatches
# into empty space, but every check at once, while the badge is the only thing that says
# so and says it in one word.
#
# The local gate suite is the only place this can be caught, BY CONSTRUCTION — a CI job
# that validates the workflow cannot run when the workflow is what is broken. So this is
# deliberately a local-first gate that also runs in CI once the file is valid again.
#
# Usage: lint-workflow-yaml.sh [--quiet]
# Exit:  0 all workflows parse / 1 one does not / 2 no YAML parser available
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

# Whichever parser this machine has. NEVER silently skip: a parser-less run that printed
# "ok" would be the same blind pass the missing gate already cost three commits.
PARSER=""
if python3 -c 'import yaml' >/dev/null 2>&1; then PARSER=python
elif command -v ruby >/dev/null 2>&1 && ruby -ryaml -e '' >/dev/null 2>&1; then PARSER=ruby
else
  echo "ERR: no YAML parser (need python3 with pyyaml, or ruby). Install one:" >&2
  echo "     pip3 install pyyaml   # or use a machine with ruby on PATH" >&2
  exit 2
fi

fail=0 n=0
for f in "$REPO_ROOT"/.github/workflows/*.yml "$REPO_ROOT"/.github/workflows/*.yaml; do
  [ -f "$f" ] || continue
  n=$((n + 1))
  rel="${f#"$REPO_ROOT"/}"
  case "$PARSER" in
    python) err=$(python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$f" 2>&1) ;;
    # `rescue` rather than letting it raise: an uncaught Psych error prints a five-frame
    # stack trace whose first line happens to match the grep below, so the report showed
    # the interpreter's path instead of "mapping values are not allowed ... line 179".
    ruby)   err=$(ruby -ryaml -e 'begin; YAML.load_file(ARGV[0]); rescue => e; warn e.message; exit 1; end' "$f" 2>&1) ;;
  esac
  if [ $? -eq 0 ]; then
    say "  ok   $rel parses"
  else
    fail=$((fail + 1))
    printf '  FAIL %s does NOT parse — GitHub will reject the file and run NOTHING\n' "$rel"
    printf '       %s\n' "$(printf '%s' "$err" | grep -iE 'line|column|mapping|expected' | head -1 \
                               | sed 's#^([^)]*)[[:space:]]*:*[[:space:]]*##' | cut -c1-160)"
    printf '       A step name containing `: ` must be quoted. That is the one that bit us.\n'
  fi
done

[ "$n" -eq 0 ] && { echo "ERR: no workflow files found under .github/workflows/" >&2; exit 1; }
say ""
if [ "$fail" -eq 0 ]; then say "  $n workflow file(s) parse ($PARSER)"; else printf '  %d of %d workflow file(s) are invalid\n' "$fail" "$n"; fi
[ "$fail" -eq 0 ]
