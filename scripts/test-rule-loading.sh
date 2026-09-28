#!/usr/bin/env bash
# test-rule-loading.sh — fixtures for the ONE question `.claude/rules/` exists to answer:
# does a rule on disk actually get READ?
#
# WHY THIS SUITE EXISTS. Three defects measured on two live repos, all in the same seam and
# none visible to any existing gate, because every gate asked whether the FILE EXISTED:
#
#   § 1  `globs:` was not recognised as path scoping. The framework writes `paths:`; the
#        ADAPTER contract this repo ships maps `paths:` → `globs:` for Cursor, Continue and
#        Windsurf, so `globs:` is the same declaration in the same vocabulary. the reference monorepo's
#        8 `globs:`-scoped rules were wired as ALWAYS-loaded — 3,427 tok/turn spent regardless
#        of which file was open — while 22 genuinely global principle rules did not fit the
#        budget and never loaded at all. `grep -rln 'globs:' scripts/` returned NOTHING.
#
#   § 2  over-budget rules were recorded as NOT LOADED in _unloaded.md and the audit ERRed on
#        installs with no imports. Both assumed Claude Code loads only imported rules; it loads
#        every rule without `paths:` (measured 2026-09-28). Now pinned: no false ledger, the real
#        cost reported, no ERR on a healthy install.
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
  # Capture the exit code. `|| true` alone meant a check-rule-budget.sh that ABORTED produced
  # empty output, fell to the else arm, and was reported "ran over the fixture" — all three
  # branches called `ok`, so no outcome of this tool could ever fail this test.
  b1=$(bash "$BUDGET_SH" "$R1" 2>&1); b1_rc=$?
  if [ "$b1_rc" -gt 1 ]; then
    bad "§1 check-rule-budget.sh ran over the fixture" "it exited $b1_rc (crash, not a verdict)"
  fi
  if printf '%s' "$b1" | grep -q 'Path-scoped (exempt'; then
    ok "§1 check-rule-budget.sh classifies path-scoped rules as exempt from the budget"
  else
    bad "§1 check-rule-budget.sh classifies path-scoped rules as exempt" \\
        "its output has no 'Path-scoped (exempt' section — the exemption this rule depends on is gone"
  fi
fi

# ── § 2  an over-budget always-on set is a COST, never a "not loaded" record ─────────────
# Claude Code loads every rule without `paths:` at launch, imported or not (measured with canary
# rules on 2.1.236 — see the header of wire-rule-imports.sh). This section used to assert that
# over-budget rules were recorded in `.claude/rules/_unloaded.md` as NOT LOADED and that the
# audit accepted that record. Both halves were built on the opposite premise: the ledger told
# the model that rules in its own context were absent, and it loaded too. Now: no ledger, a stale
# one is removed, the run states the real cost, and the audit never ERRs on a healthy install.
say "§ 2  an over-budget always-on set is reported as a cost, with no false ledger"
R2="$TD/overbudget"; seed_target "$R2"
mkrule "$R2/.claude/rules/code-quality.md" "" 20
for n in one two three four; do mkrule "$R2/.claude/rules/big-$n.md" "" 400; done
printf '# Rules on disk that do NOT load\n\n| `.claude/rules/big-one.md` | 999 | NOT LOADED |\n' > "$R2/.claude/rules/_unloaded.md"
out2=$(bash "$WIRE" "$R2" --apply --budget=2000 2>&1); rc2=$?
if [ ! -f "$R2/.claude/rules/_unloaded.md" ]; then
  ok "§2 a stale _unloaded.md is removed, and none is written"
else
  bad "§2 a stale _unloaded.md is removed, and none is written" "$(head -2 "$R2/.claude/rules/_unloaded.md" | tr '\n' ' ')"
fi
if printf '%s' "$out2" | grep -q 'loads them at launch whether or not' && printf '%s' "$out2" | grep -q 'scope-rules.sh'; then
  ok "§2 the run states that over-budget rules load anyway, and names path-scoping as the remedy"
else
  bad "§2 the run states that over-budget rules load anyway" "$(printf '%s' "$out2" | grep -A3 'OVER BUDGET' | tr '\n' ' ' | cut -c1-220)"
fi
if [ "$rc2" -eq 3 ]; then
  ok "§2 over budget is still the advisory exit 3"
else
  bad "§2 over budget is still the advisory exit 3" "exit $rc2"
fi
if [ -f "$AUDIT" ]; then
  a2=$(bash "$AUDIT" "$R2" --read-only 2>&1 || true)
  c2u=$(printf '%s\n' "$a2" | sed -n '/^C2u:/,/^$/p')
  # A TEST THAT CANNOT SAY WHY IT FAILED IS HALF A TEST: an empty section means the audit never
  # reached C2u, and that is the thing to report.
  if [ -z "$c2u" ]; then
    bad "§2 the audit never emitted a C2u: section" \
        "audit ended at: $(printf '%s\n' "$a2" | grep -vE '^[[:space:]]*$' | tail -3 | tr '\n' ' | ' | cut -c1-220)"
  fi
  if printf '%s' "$c2u" | grep -q 'ERR'; then
    bad "§2 C2u does not ERR on an over-budget install" "$(printf '%s' "$c2u" | grep 'ERR' | head -1)"
  else
    ok "§2 C2u does not ERR on an over-budget install"
  fi
  if printf '%s' "$c2u" | grep -q 'this is a cost, not a loss'; then
    ok "§2 C2u reports the over-budget set as a cost"
  else
    bad "§2 C2u reports the over-budget set as a cost" "$(printf '%s' "$c2u" | head -4 | tr '\n' ' ')"
  fi
  # a project with NO imports at all is healthy: every rule still loads.
  R2B="$TD/noimports"; rm -rf "$R2B"; cp -R "$R2" "$R2B"
  printf '# Project\n' > "$R2B/CLAUDE.md"
  printf '# Rules on disk that do NOT load\n' > "$R2B/.claude/rules/_unloaded.md"
  a2b=$(bash "$AUDIT" "$R2B" --read-only 2>&1 || true)
  c2ub=$(printf '%s\n' "$a2b" | sed -n '/^C2u:/,/^$/p')
  if printf '%s' "$c2ub" | grep -q 'ERR'; then
    bad "§2 zero @-imports is not an error" "$(printf '%s' "$c2ub" | grep 'ERR' | head -1)"
  else
    ok "§2 zero @-imports is not an error — the rules load anyway"
  fi
  if printf '%s' "$c2ub" | grep -q '_unloaded.md is a stale record'; then
    ok "§2 a stale _unloaded.md is flagged"
  else
    bad "§2 a stale _unloaded.md is flagged" "$(printf '%s' "$c2ub" | head -4 | tr '\n' ' ')"
  fi
fi

# ── § 2b  scope-rules.sh WRITES what inject-path-rules.sh READS ─────────────────────────
# The producer/consumer round trip, asserted as one property, because the two halves lived in
# different files and disagreed for as long as both have existed.
#
# scope-rules.sh wrote a YAML FLOW SEQUENCE — `paths: ["a/**", "b/**"]`. rule_globs() in
# inject-path-rules.sh finds `^paths:` and then reads the `- item` lines beneath it, so on a
# flow sequence it returned NOTHING. wire-rule-imports.sh still saw the `paths:` key and
# correctly dropped the rule from CLAUDE.md, and the hook could not match it, so the rule
# loaded NEVER — both tiers disowned it while the file sat on disk looking configured.
#
# And it is the framework's OWN advice: wire-rule-imports.sh prints this command as the remedy
# for an over-budget rule, and audit-setup.sh repeats it. Following the instruction deleted the
# rule you were trying to keep.
say ""
say "§ 2b scope-rules.sh output is readable by inject-path-rules.sh"
SCOPE="${SCOPE_OVERRIDE:-$REPO_ROOT/scripts/scope-rules.sh}"
HOOK_SRC="${HOOK_OVERRIDE:-$REPO_ROOT/templates/repo-baseline/.claude/hooks/inject-path-rules.sh}"
if [ -f "$SCOPE" ] && [ -f "$HOOK_SRC" ]; then
  R2C="$TD/roundtrip"; mkdir -p "$R2C/.claude/rules"
  printf -- '---\nname: demo\nkind: rule\n---\n\n# Demo\n\nBody.\n' > "$R2C/.claude/rules/demo.md"
  ( cd "$R2C" && bash "$SCOPE" .claude/rules/demo.md "**/payment*/**,**/billing/**" ) >/dev/null 2>&1 || true

  # rule_globs(), lifted from the hook so the test reads what the hook reads — not a copy
  # of it that can drift into agreeing with the writer.
  FNG="$(awk '/^rule_globs\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$HOOK_SRC")"
  if [ -z "$FNG" ]; then
    bad "§2b rule_globs() not found in inject-path-rules.sh" "did it get renamed?"
  else
    eval "$FNG"
    got="$(rule_globs "$R2C/.claude/rules/demo.md" | tr '\n' ' ')"
    if printf '%s' "$got" | grep -q 'payment' && printf '%s' "$got" | grep -q 'billing'; then
      ok "§2b the hook reads back both globs scope-rules.sh wrote"
    else
      bad "§2b the hook cannot read what scope-rules.sh wrote" \
          "rule_globs returned: [${got}] — a scoped rule that no glob matches loads NEVER"
    fi
  fi
  # and the budget side must still treat it as scoped, or it would be double-counted
  if grep -qE '^paths:' "$R2C/.claude/rules/demo.md"; then
    ok "§2b the frontmatter still declares paths: (budget side sees it as scoped)"
  else
    bad "§2b the frontmatter lost its paths: key" ""
  fi
fi

# ── § 2c  the hook reads EVERY glob shape this framework writes ─────────────────────────
# Four shapes are in active use and each one used to produce a rule that loaded never, because
# rule_globs() understood exactly one of them while wire-rule-imports.sh and audit C2u accept
# `^(paths|globs):` and drop ALL of them from the always-loaded imports. Both tiers disowned the
# rule; the file sat on disk looking configured.
#
# 📏 Measured on the reference monorepo: 8 of 9 scoped rules dead — base-classes, cache, controllers,
# database, dtos-mappers, events, module-structure, multi-tenancy — 3,427 tok of PROJECT-SPECIFIC
# rules, the ones extracted from that codebase and the most valuable in the install.
say ""
say "§ 2c every glob shape in use is readable by inject-path-rules.sh"
HOOK_SRC2="${HOOK_OVERRIDE:-$REPO_ROOT/templates/repo-baseline/.claude/hooks/inject-path-rules.sh}"
if [ -f "$HOOK_SRC2" ]; then
  FNG2="$(awk '/^rule_globs\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$HOOK_SRC2")"
  if [ -z "$FNG2" ]; then
    bad "§2c rule_globs() not found in inject-path-rules.sh" "renamed?"
  else
    eval "$FNG2"
    SH="$TD/shapes"; mkdir -p "$SH"
    # 1 — `globs:` inline CSV, mixed quoting: what Phase 4.2 extraction writes.
    printf -- '---\ndescription: d\nglobs: apps/tenant/**/*.ts, "**/context*.ts", "**/x.middleware.ts"\n---\n\nBody\n' > "$SH/a.md"
    # 2 — `paths:` flow sequence: what scope-rules.sh used to write.
    printf -- '---\npaths: ["a/**", "b/**"]\nname: n\n---\n\nBody\n' > "$SH/b.md"
    # 3 — `paths:` block list: the only shape that ever worked.
    printf -- '---\npaths:\n  - "c/**"\n  - "d/**"\nname: n\n---\n\nBody\n' > "$SH/c.md"
    # 4 — `globs:` block list.
    printf -- '---\nglobs:\n  - "e/**"\nname: n\n---\n\nBody\n' > "$SH/d.md"
    # and a rule with NO scoping must still yield nothing, or every always-loaded rule
    # would suddenly look path-scoped and stop being imported.
    printf -- '---\nname: plain\n---\n\nBody\n' > "$SH/e.md"
    for c in "a.md 3 globs-inline-csv" "b.md 2 paths-flow-seq" "c.md 2 paths-block-list" "d.md 1 globs-block-list" "e.md 0 unscoped-yields-nothing"; do
      set -- $c
      got=$(rule_globs "$SH/$1" | grep -c . )
      if [ "$got" = "$2" ]; then ok "§2c $3 -> $got glob(s)"
      else bad "§2c $3" "expected $2 glob(s), got $got — a rule in this shape loads NEVER"; fi
    done
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
n3=$( { grep -c 'inject-path-rules' "$R3/.claude/settings.json" 2>/dev/null || echo 0; } | tail -1 )
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

# ── § 4  the migration base loads wherever its extensions do ─────────────────────────────
# migration-discipline.md shipped scoped to DB-migration dirs while migration-backend.md was
# scoped to the track root, so a port of a service loaded the extension without its base.
say ""
say "§ 4  migration-discipline follows migration-backend/-frontend and the anchors' v2_root"
SCOPE_DOM="${SCOPE_DOM_OVERRIDE:-$REPO_ROOT/scripts/scope-domain-rules.sh}"
if [ -f "$SCOPE_DOM" ]; then
  R4="$TD/migbase"; seed_target "$R4"; mkdir -p "$R4/ai/migration"
  mkrule "$R4/.claude/rules/migration-discipline.md" 'paths:
  - "**/migrations/**"
name: migration-discipline' 10
  mkrule "$R4/.claude/rules/migration-backend.md" 'paths:
  - "apps/api/src/**"
name: migration-backend' 10
  printf -- '---\nv2_root: apps/\nv1_root: ../v1\n---\n' > "$R4/ai/migration/_v2-anchors.md"
  bash "$SCOPE_DOM" "$R4" --apply >/dev/null 2>&1 || true
  fm4=$(awk 'NR==1&&/^---/{d=1;next} d&&/^---/{exit} d' "$R4/.claude/rules/migration-discipline.md")
  if printf '%s' "$fm4" | grep -qF '"apps/api/src/**"' && printf '%s' "$fm4" | grep -qF '"apps/**"' \
     && printf '%s' "$fm4" | grep -qF '"**/migrations/**"'; then
    ok "§4 the base gains its extension's glob and the v2_root, and keeps its own"
  else
    bad "§4 the base gains its extension's glob and the v2_root" "$(printf '%s' "$fm4" | tr '\n' ' ')"
  fi
  bash "$SCOPE_DOM" "$R4" --apply >/dev/null 2>&1 || true
  n4=$(grep -c 'apps/api/src' "$R4/.claude/rules/migration-discipline.md")
  if [ "$n4" -eq 1 ]; then ok "§4 re-running adds nothing"; else bad "§4 re-running adds nothing" "apps/api/src appears $n4 times"; fi
fi

say ""
say "rule-loading fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
