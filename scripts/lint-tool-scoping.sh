#!/usr/bin/env bash
# lint-tool-scoping.sh — every agent, skill and command must declare the tools it may use,
# and an advisory agent must not hold a writing tool.
#
# WHY. A subagent with no `tools:` inherits the full tool surface. That shipped 124 agents —
# 55 reviewers, 15 auditors, 17 architects among them — holding Write, Edit and every other
# tool, while their own Output contracts return a report or a design and touch no file. The
# cost is not only blast radius: an agent that CAN edit is an agent that sometimes edits
# instead of reporting, which is the failure this framework's review agents exist to prevent.
#
# Four rules, each one a defect that actually shipped:
#   1. DECLARED     — every agent `tools:`, every SKILL.md / command `allowed-tools:`.
#   2. VOCABULARY   — a tool name outside the known set is a typo that silently grants nothing.
#   3. AGENT FORM   — agent `tools:` must be the comma-STRING form. apply-adapter-sync.sh's
#                     opencode_normalize_agent_frontmatter matches `^tools:[[:space:]]*[A-Za-z]`
#                     to convert it into OpenCode's `tools:\n  read: true` map; a YAML-list
#                     value skips that arm and ships an agent OpenCode rejects at load
#                     (audit-adapter-coverage.sh already scores that file as NOT covered).
#   4. ADVISORY RO  — an agent whose role suffix is advisory (reviewer / auditor / architect /
#                     …) must not declare Write, Edit, MultiEdit or NotebookEdit. Three agents
#                     legitimately append one ledger line; they are named in ADVISORY_WRITE_OK
#                     below with the reason, so the exception is reviewable rather than silent.
#
# Usage:   lint-tool-scoping.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 if any rule is violated; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" 2>/dev/null || { echo "no such repo root: $REPO_ROOT" >&2; exit 2; }

red()   { [ "$QUIET" = 1 ] || printf '\033[31m%s\033[0m\n' "$*"; }
green() { [ "$QUIET" = 1 ] || printf '\033[32m%s\033[0m\n' "$*"; }

ERRORS=0
fail() { red "✗ $*"; ERRORS=$((ERRORS+1)); }

# The tool surface an artifact may name. A name outside this set grants nothing at load
# time and reads as a working restriction — worse than declaring no restriction at all.
KNOWN='Read|Write|Edit|MultiEdit|NotebookEdit|Grep|Glob|Bash|BashOutput|KillShell|Task|Skill|WebFetch|WebSearch|TodoWrite|SlashCommand|AskUserQuestion'

# Role suffixes whose Output contract is a report or a design, never a file.
ADVISORY='reviewer|auditor|architect|analyst|detector|detective|investigator|watcher|finder|sentry|integrity|guardian|arbiter|synthesizer|seo|strategist|planner|modeler|tester|scout|profiler'

# Advisory agents that DO write, each for one narrow reason. Keep this list short and stated.
#   align-gate-auditor      — on PASS appends one line to ai/align/gate-history.md
#   align-ledger-auditor    — same contract for the align ledger
#   pattern-emergence-watcher — appends promoted patterns to the dynamic-pattern index
ADVISORY_WRITE_OK='align-gate-auditor|align-ledger-auditor|pattern-emergence-watcher'

WRITING='Write|Edit|MultiEdit|NotebookEdit'

# Read one frontmatter key's raw value ("" when absent).
fm_value() {
  awk -v k="$2" '
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm && /^---[[:space:]]*$/    { exit }
    fm && index($0, k ":") == 1  { sub("^" k ":[[:space:]]*", ""); print; exit }
  ' "$1"
}

# Every tool name in a value, one per line. Handles "A, B" and "[A, B]".
tool_names() { printf '%s' "$1" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$'; }

check_vocabulary() {  # $1=file $2=value $3=key
  local t
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s' "$t" | grep -qE "^($KNOWN)$" || fail "$1: $3 names an unknown tool '$t'"
  done <<< "$(tool_names "$2")"
}

AGENTS=0; SKILLS=0; CMDS=0

# ── Agents ────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  [ -f "$f" ] || continue
  AGENTS=$((AGENTS+1))
  name="$(basename "$f" .md)"; role="${name##*-}"
  val="$(fm_value "$f" tools)"
  if [ -z "$val" ]; then fail "$f: no \`tools:\` — inherits the full tool surface"; continue; fi
  # Rule 3: the comma-string form is what the OpenCode sync converts.
  case "$val" in
    \[*) fail "$f: \`tools:\` is a YAML list; apply-adapter-sync.sh only converts the comma-string form" ;;
  esac
  check_vocabulary "$f" "$val" "tools:"
  # Rule 4
  if printf '%s' "$role" | grep -qE "^($ADVISORY)$"; then
    if printf '%s' "$val" | grep -qE "(^|[, ])($WRITING)([, ]|$)"; then
      printf '%s' "$name" | grep -qE "^($ADVISORY_WRITE_OK)$" \
        || fail "$f: advisory role '$role' holds a writing tool — it returns a report, not a file"
    fi
  fi
done <<< "$(find . -path ./.git -prune -o -path '*/agents/*.md' -type f -print 2>/dev/null | grep -v '/tests/')"

# ── Skills ────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  [ -f "$f" ] || continue
  SKILLS=$((SKILLS+1))
  val="$(fm_value "$f" allowed-tools)"
  if [ -z "$val" ]; then fail "$f: no \`allowed-tools:\`"; continue; fi
  check_vocabulary "$f" "$val" "allowed-tools:"
done <<< "$(find . -path ./.git -prune -o -name SKILL.md -type f -print 2>/dev/null | grep -v '/tests/')"

# ── Commands ──────────────────────────────────────────────────────────────
while IFS= read -r f; do
  [ -f "$f" ] || continue
  CMDS=$((CMDS+1))
  val="$(fm_value "$f" allowed-tools)"
  if [ -z "$val" ]; then fail "$f: no \`allowed-tools:\`"; continue; fi
  check_vocabulary "$f" "$val" "allowed-tools:"
done <<< "$(find . -path ./.git -prune -o -path '*/commands/*.md' -type f -print 2>/dev/null | grep -v '/tests/')"

if [ "$ERRORS" -eq 0 ]; then
  green "✓ tool scoping: $AGENTS agents, $SKILLS skills, $CMDS commands all declare a scoped tool set"
  exit 0
fi
red "tool-scoping: $ERRORS violation(s)"
exit 1
