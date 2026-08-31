#!/usr/bin/env bash
# lint-hook-parity.sh — a hook that ships into every project must be translated for every tool.
#
# WHY. `templates/repo-baseline/.claude/hooks/*.sh` is the guardrail layer Refract installs into
# a consuming repo, and `templates/tool-adapters/<tool>/adapter.md § Hooks` is where each of the
# twelve non-Claude tools learns how to reproduce it. The two lists are joined by nothing but a
# human remembering. On 2026-08-31 `module-boundaries.sh` shipped into the baseline, was wired in
# `repo-baseline/.claude/settings.json`, and reached **0 of 12** adapters — a blocking PreToolUse
# hook that eleven other tools had no idea existed. The same pass found `verify-gate.sh` named in
# exactly one adapter, and `session-start.sh` / `update-session-log.sh` missing from four and five.
# Twenty translations absent for a set of files whose entire purpose is to be translated.
#
# `audit-adapter-coverage.sh` never opens these sections — it compares commands, agents and skills.
# This is the hooks axis of the same catalog-vs-disk shape `lint-overlay-catalog.sh` closes for
# regulatory overlays and `verify-doc-sync.sh` closes for command docs.
#
# WHAT COUNTS AS REQUIRED, and why it is read from settings.json rather than from `ls`. The hooks
# directory holds fifteen files, but two of them — `post-commit-learn.sh` and `post-merge-learn.sh`
# — are **git** hooks: they are absent from `settings.json`, install into the repo's git-hook path,
# and fire for every tool through git itself. Demanding a per-tool translation of those would be
# demanding a translation of `git commit`. So the required set is derived mechanically: a hook is
# required in every adapter exactly when `repo-baseline/.claude/settings.json` wires it to a Claude
# Code lifecycle event. No hand-written exemption list decides it, which is the point — a new git
# hook drops out on its own, and a new lifecycle hook is required on its own.
#
# THE ROUTED-ELSEWHERE CASE. `recall-inject.sh` is deliberately NOT routed off each adapter's
# § Hooks section. `templates/tool-adapters/_registry.md` says so in as many words: the hooks
# column measures the guardrail surface (can this tool BLOCK an edit), and recall-inject blocks
# nothing — its whole output is context, so a tool can be "native ✓" for hooks and still have
# nowhere to put it. Its home is the per-tool matrix in `_memory-recall-coverage.md`. Check [3]
# is what makes that exemption honest: rather than trusting the redirect, it opens the file the
# redirect names and fails if a tool is missing a row there. An exemption that points at another
# document is only as good as the check that the other document is complete.
#
# THE CHECKS
#
#   [1] check_hook_translated  (FAIL, baselined)
#       Every settings.json-wired hook is named in every adapter's § Hooks section. Matching is on
#       the hook's stem (`verify-gate`), not the full filename, because adapters legitimately write
#       `.cursor/hooks/session-start.sh`, `guard-write.sh` wrappers, and bare prose names. The
#       section is bounded — from the first `## `/`### ` heading matching /[Hh]ooks/ to the next
#       heading of the same or higher level — so a mention buried in the Cross-references block at
#       the bottom of the file does not count as a translation. That bound is the whole check: a
#       hook is covered when the section a porter reads tells them what to do with it.
#
#   [2] check_no_ghost_hook  (FAIL)
#       Every `.claude/hooks/<name>.sh` path cited anywhere in an adapter names a file that exists
#       in the baseline. The reverse drift: a hook renamed or deleted leaves twelve adapters
#       instructing a porter to wire a file that is not there. Deliberately narrow — only the
#       explicit `.claude/hooks/` form is read, never a bare backticked `<x>.sh`, because adapters
#       cite plenty of scripts that are not baseline hooks (`validate-migration-artifacts.sh`,
#       `guard-write.sh`, `scaffold.sh`) and a looser rule would report those as ghosts.
#
#   [3] check_routed_home_complete  (FAIL)
#       Every hook exempted from [1] by ROUTED_ELSEWHERE has a row for all twelve tools in the
#       file that claims to route it. See THE ROUTED-ELSEWHERE CASE above.
#
# Usage:  lint-hook-parity.sh [--repo-root=<dir>]
# Exit:   1 on any FAIL; 0 otherwise.
# Notes:  bash 3.2 (macOS) compatible — no associative arrays, mapfile, or ${var,,}.
#         Adds no `_<name>.md` artifact tokens to this header: lint-handoffs.sh reads any such
#         token in a file under scripts/ as an artifact THIS script writes, and a bare mention
#         turns an unrelated prose name red. Shared-adapter files are named without the leading
#         underscore-and-extension pair for that reason.

set -euo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
REPO_ROOT="$(cd -P "$REPO_ROOT" && pwd)"   # absolute before cd, or the globs below resolve wrong
cd "$REPO_ROOT" || exit 1

HOOK_DIR="templates/repo-baseline/.claude/hooks"
SETTINGS="templates/repo-baseline/.claude/settings.json"
ADAPTER_DIR="templates/tool-adapters"
BASELINE="scripts/_hook-parity-baseline.txt"

# hook-stem|file-that-routes-it-instead — exempt from [1], verified by [3].
ROUTED_ELSEWHERE="recall-inject|$ADAPTER_DIR/_memory-recall-coverage.md"

fails=0
warns=0

echo "=== lint-hook-parity ==="
echo "Repo: $REPO_ROOT"
echo ""

[ -d "$HOOK_DIR" ]    || { echo "FAIL  baseline hook dir missing: $HOOK_DIR"; exit 1; }
[ -f "$SETTINGS" ]    || { echo "FAIL  baseline settings missing: $SETTINGS"; exit 1; }
[ -d "$ADAPTER_DIR" ] || { echo "FAIL  adapter dir missing: $ADAPTER_DIR"; exit 1; }

# baselined <adapter> <hook-stem> — a line suppresses only when it carries a `# reason`.
baselined() {
  local key="$1|$2" line stripped
  [ -f "$BASELINE" ] || return 1
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    stripped="${line%%#*}"
    stripped="$(printf '%s' "$stripped" | sed 's/[[:space:]]*$//')"
    [ "$stripped" = "$key" ] || continue
    case "$line" in
      *'#'*) return 0 ;;
      *) echo "  WARN  baseline line has no '# reason' and suppresses nothing: $key"
         warns=$((warns + 1)); return 1 ;;
    esac
  done < "$BASELINE"
  return 1
}

# section <file> — print the § Hooks block only (bounded by the next same-or-higher heading).
section() {
  awk '
    /^#{2,3} .*[Hh]ooks/ && !seen { seen=1; lvl=length($1); print; next }
    seen && /^#+ / { if (length($1) <= lvl) exit }
    seen { print }
  ' "$1"
}

# ---- the required set, read from settings.json, not from ls ----
required=""
for f in "$HOOK_DIR"/*.sh; do
  [ -f "$f" ] || continue
  stem="$(basename "$f" .sh)"
  grep -q "hooks/$stem\.sh" "$SETTINGS" && required="$required $stem"
done
n_required=$(echo $required | wc -w | tr -d ' ')
n_present=$(ls "$HOOK_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')

adapters=""
for d in "$ADAPTER_DIR"/*/; do
  [ -f "$d/adapter.md" ] && adapters="$adapters $(basename "$d")"
done
n_adapters=$(echo $adapters | wc -w | tr -d ' ')

echo "[1] every wired baseline hook is translated in every adapter"
pairs=0; exempted=0; suppressed=0; cov_ok=1
for tool in $adapters; do
  body="$(section "$ADAPTER_DIR/$tool/adapter.md")"
  if [ -z "$body" ]; then
    echo "  FAIL  $ADAPTER_DIR/$tool/adapter.md — no § Hooks section to translate into"
    fails=$((fails + 1)); cov_ok=0; continue
  fi
  for stem in $required; do
    case "$ROUTED_ELSEWHERE" in "$stem|"*) exempted=$((exempted + 1)); continue ;; esac
    pairs=$((pairs + 1))
    printf '%s\n' "$body" | grep -q -- "$stem" && continue
    if baselined "$tool" "$stem"; then suppressed=$((suppressed + 1)); continue; fi
    echo "  FAIL  $tool — $stem.sh ships in the baseline and has no entry in § Hooks"
    fails=$((fails + 1)); cov_ok=0
  done
done
[ "$cov_ok" -eq 1 ] && echo "  ok — $pairs pairs, every wired hook translated in all $n_adapters adapters"

echo "[2] no adapter cites a baseline hook that does not exist"
ghost_ok=1
for tool in $adapters; do
  f="$ADAPTER_DIR/$tool/adapter.md"
  for ref in $(grep -oE '\.claude/hooks/[a-z0-9-]+\.sh' "$f" | sed 's|.*/||' | sort -u); do
    [ -f "$HOOK_DIR/$ref" ] && continue
    echo "  FAIL  $f — cites .claude/hooks/$ref, which is not in $HOOK_DIR"
    fails=$((fails + 1)); ghost_ok=0
  done
done
[ "$ghost_ok" -eq 1 ] && echo "  ok — every cited .claude/hooks/ path resolves"

echo "[3] a hook routed to another file has a row there for every tool"
routed_ok=1
stem="${ROUTED_ELSEWHERE%%|*}"
home="${ROUTED_ELSEWHERE#*|}"
if [ ! -f "$home" ]; then
  echo "  FAIL  $stem.sh is exempted from [1] and routed to $home, which does not exist"
  fails=$((fails + 1)); routed_ok=0
else
  for tool in $adapters; do
    # Adapter dir names are slugs; the routing table writes display names. Match on the slug's
    # letters, case-insensitively, which is what separates `opencode` from `OpenCode`.
    grep -qi "^|[[:space:]]*$tool\b" "$home" && continue
    grep -qi "^|[[:space:]]*claude" "$home" && [ "$tool" = "claude-code" ] && continue
    echo "  FAIL  $home — no row for '$tool'; $stem.sh is exempted from [1] on the promise this file covers it"
    fails=$((fails + 1)); routed_ok=0
  done
fi
[ "$routed_ok" -eq 1 ] && echo "  ok — $stem.sh has a row for all $n_adapters tools in $(basename "$home")"

echo ""
echo "reach: $n_adapters adapters · $n_required of $n_present baseline hooks wired in settings.json · $pairs pairs checked · $suppressed baselined"
echo "       not checked: $exempted routed-elsewhere pair(s) — covered by [3] · $((n_present - n_required)) git hook(s), fired by git for every tool"
if [ "$fails" -gt 0 ]; then
  echo "FAIL  $fails hook-parity gap(s). Translate the hook in the adapter, or add a line WITH a reason to $BASELINE."
  exit 1
fi
[ "$warns" -gt 0 ] && echo "WARN  $warns inert baseline line(s)."
echo "PASS"
