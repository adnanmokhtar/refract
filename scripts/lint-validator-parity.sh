#!/usr/bin/env bash
# lint-validator-parity.sh — fail when a rule/doc cites a `check_*` validator as a LIVE
# gate-halt that no script actually defines (the "false guarantee" bug class — a contract
# stated in the doc, never enforced in the script that runs). This is the meta-linter that
# turns findings #1/#2/#14/#15/#16/#36/#37/#38 into a red build and stops doc↔script drift.
#
# A citation is EXEMPT (honest) when its line carries a disclosure qualifier:
#   (planned) | (agent-side …) | not script-enforced | not yet (implemented|shipped) | until v<N> | PLANNED
# So `check_oracle_drift (:524, (planned))` is fine; `check_security_assertion_present` stated
# in unqualified present tense is a FAIL.
#
# Usage:   lint-validator-parity.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 if any cited-as-enforcing validator is undefined; 0 otherwise.

set -euo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1

QUALIFIER='[Pp]lanned|\(agent-side|agent-side until|not script[ -]enforced|not[ -]yet (implemented|shipped)|until v[0-9]|no external validator|[Ss]elf-policed|there is no .?check_|not (a|an) (script|validator|external)|agent-enforced|AGENT-enforced'

# 1. DEFINED — every check_* function defined in any shell script.
# `|| true` so set -e doesn't abort when a path is absent (find/grep on a missing dir
# returns non-zero — happens on minimal repos / test fixtures).
DEFINED="$(grep -rhoE '^[[:space:]]*check_[a-z0-9_]+\(\)' scripts/*.sh 2>/dev/null \
          | grep -oE 'check_[a-z0-9_]+' | sort -u || true)"

# 2. CITATION surfaces — the rule/doc/phase/command files that promise gate behaviour.
# Newline list (repo paths are space-free); bash 3.2 has no mapfile.
# Includes docs/ + pack-command mirrors + README so false "check_X enforces this" guarantees
# stated there are linted too (not just rules/governance/phases/top-level commands). README.md
# is a single file (not a dir), appended after the find so its absence can't abort the find.
SURFACES="$(find templates/packs/*/rules templates/packs/*/commands templates/governance templates/phases commands docs \
              -name '*.md' 2>/dev/null || true)"
[ -f README.md ] && SURFACES="$SURFACES
README.md"

# 3. Distinct cited names.
CITED="$(grep -rhoE 'check_[a-z0-9_]+' $SURFACES 2>/dev/null | sort -u || true)"

n_cited=$(grep -c . <<<"$CITED" || echo 0)
n_defined=$(grep -c . <<<"$DEFINED" || echo 0)
dangling=0
dangling_names=""

for name in $CITED; do
  grep -qxF "$name" <<<"$DEFINED" && continue   # defined somewhere → honest
  # Undefined. List UNQUALIFIED citing lines (qualified ones are honest disclosures).
  unq_lines="$(grep -rnE "\\b${name}\\b" $SURFACES 2>/dev/null | grep -vE "$QUALIFIER" || true)"
  if [[ -n "$unq_lines" ]]; then
    dangling=$((dangling + 1))
    dangling_names+=" $name"
    if [[ $QUIET -eq 0 ]]; then
      echo "FAIL  $name — cited as a live gate-halt but DEFINED IN NO SCRIPT:"
      while IFS= read -r l; do echo "        ${l:0:160}"; done <<<"$unq_lines"
    fi
  fi
done

echo ""
echo "validator-parity: cited=$n_cited defined=$n_defined dangling(unqualified)=$dangling"
if [[ $dangling -gt 0 ]]; then
  echo "Dangling validators:${dangling_names}"
  echo "→ Implement each in the relevant scripts/validate-*.sh|audit-*.sh, OR tag the citation '(planned)'/'(agent-side — not script-enforced)' to make the guarantee honest."
  exit 1
fi
echo "OK — every cited validator is either defined or honestly disclosed."
exit 0
