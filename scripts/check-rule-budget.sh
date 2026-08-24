#!/usr/bin/env bash
# check-rule-budget.sh — guard the ALWAYS-LOADED rule budget.
#
# Two-tier rule model (see templates/repo-baseline/.claude/rules/README.md):
#   • always-loaded — no `paths:` frontmatter; @-imported by the project CLAUDE.md,
#                     so it costs tokens EVERY session. This is what we budget.
#   • path-scoped   — carries `paths:` frontmatter; injected on-match by
#                     inject-path-rules.sh. Exempt from the budget (near-zero cost).
#
# Fails (exit 1) if the always-loaded set exceeds the budget. The point is not a
# hard 1200-token diet (we deliberately always-load 4 rich foundational rules) —
# it is to force any NEW rule to justify always-loading, or carry `paths:` and be
# path-scoped instead. Token estimate = chars / 4.
#
# Budget override: RULE_BUDGET_TOKENS=<n> bash scripts/check-rule-budget.sh

set -uo pipefail

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
BASE="$REPO_ROOT/templates/repo-baseline"
RULES_DIR="$BASE/.claude/rules"
BUDGET="${RULE_BUDGET_TOKENS:-6000}"

# --target=<repo> — measure a REAL project's always-load surface instead of the framework's.
#
# HISTORY — every number this programme optimised was a measurement of `templates/`, never of a
# project. This script had NO target parameter at all; it budgeted templates/repo-baseline
# exclusively. The headline "~29,287 tokens" attributed to a live repo reconstructs exactly from
# this script's own advisory note (4,943 baseline + 24,344 pack) — a PROJECTION of what a project
# WOULD load if the imports existed, published as if it were a measurement. Nothing anywhere
# measured a target, which is why nothing ever noticed that the true figure was ~18,205 tokens
# and contained NO RULES AT ALL, because no rule was imported (see scripts/wire-rule-imports.sh).
# --target answers the question that was actually being asked.
TARGET_REPO=""
for a in "$@"; do case "$a" in --target=*) TARGET_REPO="${a#--target=}" ;; esac; done

[ -d "$RULES_DIR" ] || { echo "no rules dir at $RULES_DIR"; exit 0; }

is_path_scoped() {
  # frontmatter must start on line 1 and contain a top-level `paths:` key
  head -1 "$1" | grep -qE '^---[[:space:]]*$' || return 1
  # `globs:` counts as a path-scoping declaration too — it is the key the adapter contract
  # maps `paths:` to for Cursor/Continue/Windsurf, so a rule authored against that vocabulary
  # is path-scoped. See wire-rule-imports.sh is_path_scoped for the measured cost of not
  # recognising it. Fixture: scripts/test-rule-loading.sh § 1.
  awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^(paths|globs):/{found=1} END{exit !found}' "$1"
}

tok() { echo $(( $(wc -c < "$1") / 4 )); }

# ---------- --target mode: what a REAL project loads every turn ----------------------------
if [ -n "$TARGET_REPO" ]; then
  [ -d "$TARGET_REPO" ] || { echo "no such target: $TARGET_REPO" >&2; exit 2; }
  TARGET_REPO="$(cd "$TARGET_REPO" && pwd -P)"
  echo "=== always-load surface — MEASURED, target: $TARGET_REPO ==="
  echo ""
  t_total=0

  if [ -f "$TARGET_REPO/CLAUDE.md" ]; then
    t=$(tok "$TARGET_REPO/CLAUDE.md"); t_total=$((t_total + t))
    printf "  %-46s ~%6d tok\n" "CLAUDE.md" "$t"
  else
    printf "  %-46s %s\n" "CLAUDE.md" "ABSENT"
  fi

  # Rules count ONLY when CLAUDE.md imports them. This is the whole point: a rule on disk that
  # nothing imports costs zero tokens AND delivers zero guidance, and the old script could not
  # tell that state from a working one.
  r_imported=0; r_ondisk=0; r_bytes_unloaded=0
  for f in "$TARGET_REPO"/.claude/rules/*.md; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); case "$b" in README.md|_*) continue ;; esac
    is_path_scoped "$f" && continue
    r_ondisk=$((r_ondisk + 1))
    if grep -qF "@.claude/rules/$b" "$TARGET_REPO/CLAUDE.md" 2>/dev/null; then
      t=$(tok "$f"); t_total=$((t_total + t)); r_imported=$((r_imported + 1))
      printf "  %-46s ~%6d tok\n" ".claude/rules/$b" "$t"
    else
      r_bytes_unloaded=$((r_bytes_unloaded + $(tok "$f")))
    fi
  done

  # Frontmatter descriptions of commands / agents / skills are surfaced to the model as a
  # listing on every turn, so they are part of the always-load surface even though no rule
  # mentions them.
  desc_tok() {
    local dir="$1" n=0
    [ -d "$dir" ] || { echo 0; return; }
    n=$( { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
           find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null; } \
         | while IFS= read -r f; do
             awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^(name|description):/{print}' "$f"
           done | wc -c )
    echo $(( ${n:-0} / 4 ))
  }
  for pair in "commands:.claude/commands" "agents:.claude/agents" "skills:.claude/skills"; do
    label="${pair%%:*}"; sub="${pair##*:}"
    t=$(desc_tok "$TARGET_REPO/$sub"); t_total=$((t_total + t))
    printf "  %-46s ~%6d tok\n" "$sub/ (name+description listing)" "$t"
  done

  echo "  ----------------------------------------------------------"
  printf "  %-46s ~%6d tok / turn\n" "MEASURED ALWAYS-LOAD TOTAL" "$t_total"
  echo ""
  printf "  always-tier rules on disk: %d   imported (loading): %d   INERT: %d (~%d tok of guidance nobody receives)\n" \
    "$r_ondisk" "$r_imported" "$((r_ondisk - r_imported))" "$r_bytes_unloaded"
  if [ "$r_ondisk" -gt 0 ] && [ "$r_imported" -eq 0 ]; then
    echo ""
    echo "::error::every always-tier rule in this target is INERT — CLAUDE.md imports none of them."
    echo "  Fix: bash scripts/wire-rule-imports.sh \"$TARGET_REPO\" --apply"
    exit 1
  fi
  echo ""
  echo "OK — measured. (This is a measurement of the TARGET. The framework-side budget is the run with no --target.)"
  exit 0
fi


total=0
echo "Always-loaded (budgeted):"
# CLAUDE.md is always loaded and pulls the @-imports.
if [ -f "$BASE/CLAUDE.md" ]; then
  t=$(tok "$BASE/CLAUDE.md"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" "CLAUDE.md" "$t"
fi
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in README.md|_*) continue ;; esac
  if is_path_scoped "$f"; then continue; fi
  t=$(tok "$f"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" ".claude/rules/$base" "$t"
done

echo "Path-scoped (exempt — injected on match):"
any_scoped=0
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in README.md|_*) continue ;; esac
  if is_path_scoped "$f"; then
    any_scoped=1
    printf "  %-40s ~%5d tok  (free until matched)\n" ".claude/rules/$base" "$(tok "$f")"
  fi
done
[ "$any_scoped" = 0 ] && echo "  (none)"

echo "------------------------------------------------"
printf "baseline always-loaded: ~%d tokens   (budget: %d)\n" "$total" "$BUDGET"

# ── Pack rules (added 2026-08-22) ────────────────────────────────────────────
# Until now this gate read ONLY templates/repo-baseline/.claude/rules and reported
# "OK — within budget" while being blind to every templates/packs/<pack>/rules/ file.
# Those are not free: phase-4.2-apply.md path-scopes pack rules ONLY when the project
# is multi-track, so a SINGLE-track project always-loads them unscoped. Measured on a
# real 11-track project (capsolah-api): ~24,344 tokens of pack rules on top of the
# ~4,943 baseline — roughly 5x the declared cap, reported as OK.
#
# The baseline number above is still the gate's hard budget: it is the floor every
# project pays regardless of packs. The pack accounting below is a RATCHET, because
# failing the whole repo on today's totals would turn CI red with no path to green.
# Per-pack sizes are recorded in scripts/_rule-budget-baseline.txt. A pack may not
# GROW past its recorded size, and a pack with no record must come in under
# PACK_RULE_CAP. Shrinking is always allowed and should be followed by re-recording.
PACKS_DIR="$REPO_ROOT/templates/packs"
PACK_BASELINE="$REPO_ROOT/scripts/_rule-budget-baseline.txt"
PACK_CAP="${PACK_RULE_CAP:-2500}"
pack_total=0
pack_fail=0
pack_rows=""

if [ -d "$PACKS_DIR" ]; then
  for d in "$PACKS_DIR"/*/; do
    [ -d "${d}rules" ] || continue
    pack=$(basename "$d")
    pt=0
    for f in "${d}rules"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      # A pack rule with `paths:` frontmatter is scoped in EVERY mode, so it is free.
      is_path_scoped "$f" && continue
      pt=$((pt + $(tok "$f")))
    done
    [ "$pt" -eq 0 ] && continue
    pack_total=$((pack_total + pt))
    recorded=""
    [ -f "$PACK_BASELINE" ] && recorded=$(awk -v p="$pack" '$1==p {print $2}' "$PACK_BASELINE" | head -1)
    if [ -n "$recorded" ]; then
      if [ "$pt" -gt "$recorded" ]; then
        pack_rows="${pack_rows}  GREW   ${pack}: ~${pt} tok (recorded ~${recorded}) — a pack rule may not grow; trim it or move depth to ai-patterns/\n"
        pack_fail=1
      elif [ "$pt" -lt "$recorded" ]; then
        pack_rows="${pack_rows}  shrank ${pack}: ~${pt} tok (was ~${recorded}) — re-record with --record\n"
      fi
    elif [ "$pt" -gt "$PACK_CAP" ]; then
      pack_rows="${pack_rows}  OVER   ${pack}: ~${pt} tok (cap ${PACK_CAP}, unrecorded) — trim it, or record it deliberately with --record\n"
      pack_fail=1
    fi
  done
fi

if [ "${1:-}" = "--record" ]; then
  : > "$PACK_BASELINE"
  {
    echo "# Per-pack always-loaded rule cost, in ~tokens. Regenerate: bash scripts/check-rule-budget.sh --record"
    echo "# A pack may not GROW past its recorded size. Shrinking is always allowed — re-record after."
  } >> "$PACK_BASELINE"
  for d in "$PACKS_DIR"/*/; do
    [ -d "${d}rules" ] || continue
    pack=$(basename "$d"); pt=0
    for f in "${d}rules"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      is_path_scoped "$f" && continue
      pt=$((pt + $(tok "$f")))
    done
    [ "$pt" -gt 0 ] && printf '%s %s\n' "$pack" "$pt" >> "$PACK_BASELINE"
  done
  echo "recorded per-pack rule sizes → $PACK_BASELINE"
  exit 0
fi

echo ""
echo "Pack rules (NOT in the baseline budget — always-loaded on a single-track project):"
printf "  %d packs ship rules, ~%d tokens combined\n" \
  "$(ls -d "$PACKS_DIR"/*/rules 2>/dev/null | wc -l | tr -d ' ')" "$pack_total"
if [ -n "$pack_rows" ]; then printf "%b" "$pack_rows"; else echo "  all packs at or below their recorded size"; fi
echo "  NOTE: a project loads only the packs it installs. A real 11-track project measured"
echo "        ~24,344 pack tokens on top of the ~${total} baseline. The baseline budget below"
echo "        is the floor, not the total."

echo "------------------------------------------------"
if [ "$total" -gt "$BUDGET" ]; then
  echo "::error::baseline always-loaded rule content (~${total} tok) exceeds the ${BUDGET}-token budget."
  echo "Trim a foundational rule, or give the new rule \`paths:\` frontmatter so it becomes path-scoped."
  exit 1
fi
if [ "$pack_fail" -eq 1 ]; then
  echo "::error::a pack's always-loaded rule cost grew, or an unrecorded pack exceeds the ${PACK_CAP}-token cap."
  exit 1
fi
echo "OK — baseline within budget; no pack rule grew."
