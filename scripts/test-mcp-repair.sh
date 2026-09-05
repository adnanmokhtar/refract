#!/usr/bin/env bash
# test-mcp-repair.sh — the one flag allowed to delete from a user's .mcp.json must delete
# exactly the entries that cannot work, and nothing else.
#
# WHY. detect-mcp.sh's contract is additive-only: your keys always win, and a key it wrote
# once is never edited. `--repair-placeholders` is the single exception, so it carries the
# whole risk of that contract. It removes only entries whose `args` contain a `<TODO: …>`
# string — emitted by an earlier version of this script, unable to start (`npx -y
# "<TODO: install X>"` resolves to nothing), and never a choice anyone made. Measured across
# five production repos: two carried one.
#
# A flag that deletes needs a guard that says what it may not delete. Four cases:
#   REMOVES     a `<TODO: …>` entry goes, with the flag
#   KEEPS       the same entry stays, WITHOUT the flag (the default must not change)
#   SPARES      a user's own real entry is never touched, flag or not
#   REFUSES     the flag without --apply is an error, not a silent read-only run
#
# Usage:  test-mcp-repair.sh [--repo-root=<dir>]
# Exit:   1 if any case fails; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"
REPO_ROOT="$(cd -P "$SELF_DIR/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

DETECT="$REPO_ROOT/scripts/detect-mcp.sh"
[ -f "$DETECT" ] || { echo "no detect-mcp.sh under $REPO_ROOT — nothing to test"; exit 0; }

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
FAILED=0
fail() { red "  ✗ $*"; FAILED=$((FAILED+1)); }
pass() { green "  ✓ $*"; }

TD="$(mktemp -d "${TMPDIR:-/tmp}/test-mcp-repair.XXXXXX")"
trap 'rm -rf "$TD"' EXIT

seed() {  # $1=dir — a project with one placeholder entry and one entry the user owns
  mkdir -p "$1"
  printf '{"dependencies":{"vue":"^3"}}\n' > "$1/package.json"
  cat > "$1/.mcp.json" <<'J'
{
  "mcpServers": {
    "docker": {"command": "npx", "args": ["-y", "<TODO: install docker-mcp and replace this>"]},
    "mine":   {"command": "npx", "args": ["-y", "a-server-the-user-chose"]}
  }
}
J
}
keys() { python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["mcpServers"]))' "$1/.mcp.json" 2>/dev/null; }

A="$TD/with-flag"; seed "$A"
bash "$DETECT" "$A" --apply --repair-placeholders >"$TD/a.log" 2>&1
case " $(keys "$A") " in
  *" docker "*) fail "REMOVES — the <TODO: …> entry survived --repair-placeholders" ;;
  *)            pass "REMOVES — the unrunnable entry is gone" ;;
esac
case " $(keys "$A") " in
  *" mine "*) pass "SPARES — the user's own entry is untouched" ;;
  *)          fail "SPARES — it deleted an entry the user owns" ;;
esac

B="$TD/no-flag"; seed "$B"
bash "$DETECT" "$B" --apply >"$TD/b.log" 2>&1
case " $(keys "$B") " in
  *" docker "*) pass "KEEPS — without the flag the default is unchanged" ;;
  *)            fail "KEEPS — a placeholder was deleted WITHOUT the flag being passed" ;;
esac

C="$TD/refuse"; seed "$C"
if bash "$DETECT" "$C" --repair-placeholders >"$TD/c.log" 2>&1; then
  fail "REFUSES — the flag was accepted without --apply"
else
  grep -q "requires --apply" "$TD/c.log" \
    && pass "REFUSES — the flag without --apply errors, and says why" \
    || fail "REFUSES — it failed, but not with the documented reason"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then green "mcp-repair: 4 passed, 0 failed"; exit 0; fi
red "mcp-repair: $FAILED failed"; exit 1
