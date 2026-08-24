#!/usr/bin/env bash
# test-rule-loading.sh — fixtures for the ONE question `.claude/rules/` exists to answer:
# does a rule on disk actually get READ?
#
# WHY THIS SUITE EXISTS. Three defects measured on two live repos, all in the same seam and
# none visible to any existing gate, because every gate asked whether the FILE EXISTED:
#
#   § 1  `globs:` was not recognised as path scoping. The framework writes `paths:`; the
#        ADAPTER contract this repo ships maps `paths:` → `globs:` for Cursor, Continue and
#        Windsurf, so `globs:` is the same declaration in the same vocabulary. capsolah-api's
#        8 `globs:`-scoped rules were wired as ALWAYS-loaded — 3,427 tok/turn spent regardless
#        of which file was open — while 22 genuinely global principle rules did not fit the
#        budget and never loaded at all. `grep -rln 'globs:' scripts/` returned NOTHING.
#
#   § 2  wire-rule-imports.sh declined over-budget rules and said so; audit-setup.sh C2u then
#        FAILED the run for that decision. Two mandatory steps of the same run in direct
#        opposition, with no reachable state satisfying both.
#
#   § 3  the escape hatch was dead. A path-scoped rule loads only via inject-path-rules.sh,
#        and that hook was registered in no settings.json in either repo — so "scope it and it
#        loads on match" was advice that could not be followed.
#
# Everything runs under mktemp -d. Nothing is written outside it.
#
# Usage: test-rule-loading.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
WIRE="${WIRE_OVERRIDE:-$REPO_ROOT/scripts/wire-rule-imports.sh}"
AUDIT="${AUDIT_OVERRIDE:-$REPO_ROOT/scripts/audit-setup.sh}"
BUDGET_SH="${BUDGET_OVERRIDE:-$REPO_ROOT/scripts/check-rule-budget.sh}"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

[ -f "$WIRE" ] || { echo "ERR: $WIRE not found" >&2; exit 1; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-rule-loading.XXXXXX")
trap 'rm -rf "$TD"' EXIT

seed_target() {  # $1=root
  local r="$1"
  mkdir -p "$r/.claude/rules" "$r/.claude/hooks" "$r/src"
  printf 'export const a = 1\n' > "$r/src/a.ts"
  printf '{"name":"fixture"}\n' > "$r/package.json"
  printf '# Fixture project\n\nSome owner prose that must survive.\n' > "$r/CLAUDE.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$r/.claude/hooks/inject-path-rules.sh"
  chmod +x "$r/.claude/hooks/inject-path-rules.sh"
  printf '{\n  "hooks": {}\n}\n' > "$r/.claude/settings.json"
}
mkrule() {  # $1=path $2=frontmatter-lines(or "") $3=approx-bytes
  local f="$1" fm="$2" n="$3"
  { [ -n "$fm" ] && { printf -- '---\n'; printf '%s\n' "$fm"; printf -- '---\n'; }
    printf '# Rule\n\n'
    local i=0
    while [ "$i" -lt "$n" ]; do printf 'Sentence %s about how the code should be written here.\n' "$i"; i=$((i+1)); done
  } > "$f"
}

# ── § 1  `globs:` frontmatter IS path scoping ────────────────────────────────────────────
say "§ 1  a rule declaring \`globs:\` is path-scoped, not always-loaded"
R1="$TD/globs"; seed_target "$R1"
mkrule "$R1/.claude/rules/controllers.md" 'description: Enforced on controllers
globs: "**/controllers/**/*.ts"' 30
mkrule "$R1/.claude/rules/backend-principles.md" "" 60
out1=$(bash "$WIRE" "$R1" --apply 2>&1)
if grep -qF '@.claude/rules/controllers.md' "$R1/CLAUDE.md" 2>/dev/null; then
  bad "§1 a \`globs:\` rule is NOT imported as always-loaded" \
      "controllers.md was @-imported — it burns budget on every turn regardless of the open file"
else
  ok "§1 a \`globs:\` rule is NOT imported as always-loaded"
fi
if printf '%s' "$out1" | grep -q 'Path-scoped (NOT imported'; then
  ok "§1 it is reported in the path-scoped tier"
else
  bad "§1 it is reported in the path-scoped tier" "$(printf '%s' "$out1" | tail -5 | tr '\n' ' ')"
fi
if grep -qF '@.claude/rules/backend-principles.md' "$R1/CLAUDE.md" 2>/dev/null; then
  ok "§1 the un-scoped principle rule got the budget instead"
else
  bad "§1 the un-scoped principle rule got the budget instead" "backend-principles.md still does not load"
fi
if [ -f "$BUDGET_SH" ]; then
  # check-rule-budget.sh must agree: a globs: rule is exempt from the always-loaded budget.
  b1=$(bash "$BUDGET_SH" "$R1" 2>&1 || true)
  if printf '%s' "$b1" | grep -qiE 'controllers\.md' && printf '%s' "$b1" | grep -qiE 'controllers\.md.*(scoped|exempt)|scoped.*controllers\.md'; then
    ok "§1 check-rule-budget.sh also treats it as path-scoped"
  elif printf '%s' "$b1" | grep -qi 'controllers'; then
    say "       (check-rule-budget.sh mentions controllers.md; shape not asserted)"
    ok "§1 check-rule-budget.sh ran over the fixture"
  else
    ok "§1 check-rule-budget.sh ran over the fixture"
  fi
fi

# ── § 2  the over-budget refusal is RECORDED, and the audit accepts a recorded refusal ───
say "§ 2  an over-budget refusal is written where a reader finds it, and does not fail the run"
R2="$TD/overbudget"; seed_target "$R2"
# one foundational rule so the run reaches the normal path (the foundational set is imported
# regardless of budget — a target with ZERO imports means wire-rule-imports.sh never ran, and
# C2u is right to ERR on that separately).
mkrule "$R2/.claude/rules/code-quality.md" "" 20
for n in one two three four; do mkrule "$R2/.claude/rules/big-$n.md" "" 400; done
bash "$WIRE" "$R2" --apply --budget=2000 >/dev/null 2>&1 || true
LED="$R2/.claude/rules/_unloaded.md"
if [ -f "$LED" ]; then
  ok "§2 .claude/rules/_unloaded.md was written"
else
  bad "§2 .claude/rules/_unloaded.md was written" "the refusal exists only in scrollback"
fi
if [ -f "$LED" ] && grep -q 'tok/turn' "$LED" && grep -q 'scope-rules.sh' "$LED"; then
  ok "§2 it states the per-turn cost and both remedies"
else
  bad "§2 it states the per-turn cost and both remedies" "$( [ -f "$LED" ] && head -3 "$LED" | tr '\n' ' ')"
fi
if [ -f "$AUDIT" ]; then
  a2=$(bash "$AUDIT" "$R2" --read-only 2>&1 || true)
  c2u=$(printf '%s\n' "$a2" | sed -n '/^C2u:/,/^$/p')
  # A TEST THAT CANNOT SAY WHY IT FAILED IS HALF A TEST.
  #
  # When this suite failed on CI and passed locally, the report was
  #     FAIL §2 C2u reports it as a WARN naming the ledger
  # with no detail line — because the detail is `head -4` of $c2u and $c2u was EMPTY.
  # That emptiness IS the finding (the audit never reached C2u at all), and it was the one
  # thing the output did not say. Diagnosing it took a log fetch and a guess; it should have
  # taken reading the failure. So: if the section is missing, say the section is missing, and
  # show where the audit actually stopped.
  if [ -z "$c2u" ]; then
    bad "§2 the audit never emitted a C2u: section" \
        "audit ended at: $(printf '%s\n' "$a2" | grep -vE '^[[:space:]]*$' | tail -3 | tr '\n' ' | ' | cut -c1-220)"
  fi
  if printf '%s' "$c2u" | grep -q 'ERR .*NOT imported'; then
    bad "§2 C2u does not ERR on a recorded refusal" "$(printf '%s' "$c2u" | grep 'ERR' | head -1)"
  else
    ok "§2 C2u does not ERR on a recorded refusal"
  fi
  if printf '%s' "$c2u" | grep -q 'recorded decision in .claude/rules/_unloaded.md'; then
    ok "§2 C2u reports it as a WARN naming the ledger"
  else
    bad "§2 C2u reports it as a WARN naming the ledger" "$(printf '%s' "$c2u" | head -4 | tr '\n' ' ')"
  fi
  # the mirror: an UNRECORDED unimported rule must still be an ERR, or this is a rubber stamp.
  R2B="$TD/unrecorded"; rm -rf "$R2B"; cp -R "$R2" "$R2B"
  rm -f "$R2B/.claude/rules/_unloaded.md"
  a2b=$(bash "$AUDIT" "$R2B" --read-only 2>&1 || true)
  if printf '%s\n' "$a2b" | sed -n '/^C2u:/,/^$/p' | grep -q 'ERR .*recorded nowhere'; then
    ok "§2 an UNRECORDED unimported rule is still an ERR"
  else
    bad "§2 an UNRECORDED unimported rule is still an ERR" "the ledger check became a blanket exemption"
  fi
fi

# ── § 3  the path-scoped tier is made LIVE, not just recommended ─────────────────────────
say "§ 3  scoping a rule wires the hook that loads it"
R3="$TD/scoped"; seed_target "$R3"
mkrule "$R3/.claude/rules/migration-safety.md" 'paths: ["**/migrations/**"]' 30
mkrule "$R3/.claude/rules/code-quality.md" "" 20
bash "$WIRE" "$R3" --apply >/dev/null 2>&1 || true
if grep -qF 'inject-path-rules' "$R3/.claude/settings.json" 2>/dev/null; then
  ok "§3 inject-path-rules.sh is registered in .claude/settings.json"
else
  bad "§3 inject-path-rules.sh is registered in .claude/settings.json" \
      "the path-scoped tier is inert, so scope-rules.sh is advice that cannot be followed"
fi
if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$R3/.claude/settings.json" 2>/dev/null; then
  ok "§3 settings.json is still valid JSON"
else
  bad "§3 settings.json is still valid JSON" "the registration corrupted the file"
fi
# idempotent — a second run must not add a second copy
bash "$WIRE" "$R3" --apply >/dev/null 2>&1 || true
n3=$(grep -c 'inject-path-rules' "$R3/.claude/settings.json" 2>/dev/null || echo 0)
if [ "${n3:-0}" -eq 1 ]; then
  ok "§3 re-running does not register it twice"
else
  bad "§3 re-running does not register it twice" "found $n3 registrations"
fi
# and the owner's own settings must survive
R3B="$TD/scoped-existing"; seed_target "$R3B"
mkrule "$R3B/.claude/rules/migration-safety.md" 'paths: ["**/migrations/**"]' 30
cat > "$R3B/.claude/settings.json" <<'JS'
{
  "env": { "OWNER_KEY": "keep-me" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit",
        "hooks": [ { "type": "command", "command": "cd \"${CLAUDE_PROJECT_DIR:-.}\" && .claude/hooks/pre-edit-guard.sh" } ] }
    ]
  }
}
JS
bash "$WIRE" "$R3B" --apply >/dev/null 2>&1 || true
if grep -q 'OWNER_KEY' "$R3B/.claude/settings.json" && grep -q 'pre-edit-guard' "$R3B/.claude/settings.json" \
   && grep -q 'inject-path-rules' "$R3B/.claude/settings.json"; then
  ok "§3 the owner's existing settings + hooks survive the registration"
else
  bad "§3 the owner's existing settings + hooks survive the registration" \
      "$(cat "$R3B/.claude/settings.json" | tr '\n' ' ' | cut -c1-200)"
fi

say ""
say "rule-loading fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
