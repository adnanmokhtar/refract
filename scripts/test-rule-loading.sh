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
# And the Phase 3 contract (one truth per fact; context on a budget):
#   § 4b the migration trio's scoping is no longer inverted — an extension never loads where
#        its base does not, at source or after per-project narrowing;
#   § 5  every pack/domain rule ships a sound `paths:` at source, or sits on the always-on
#        allowlist with its reason; § 5b the scopers replace only an unedited pack default;
#   § 6  check-rule-budget.sh --target counts what Claude Code loads, not what CLAUDE.md imports.
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
  # check-rule-budget.sh's framework mode still prints its path-scoped tier. (It no longer counts
  # a `globs:`-only rule as exempt — Claude Code reads `paths:` only; § 6 pins the --target side.)
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
  c2x=$(printf '%s\n' "$a2" | sed -n '/^C2x:/,/^$/p')
  if printf '%s' "$c2x" | grep -q '  ok   CLAUDE.md within'; then
    ok "§2 C2x passes a short CLAUDE.md"
  else
    bad "§2 C2x passes a short CLAUDE.md" "$(printf '%s' "$c2x" | head -3 | tr '\n' ' ')"
  fi
  # a project with NO imports at all is healthy: every rule still loads. Its CLAUDE.md is 201
  # lines, which C2x — and only C2x — must fail.
  R2B="$TD/noimports"; rm -rf "$R2B"; cp -R "$R2" "$R2B"
  { printf '# Project\n'; i=2; while [ "$i" -le 201 ]; do printf 'Line %s of owner prose.\n' "$i"; i=$((i+1)); done; } > "$R2B/CLAUDE.md"
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
  c2xb=$(printf '%s\n' "$a2b" | sed -n '/^C2x:/,/^$/p')
  if printf '%s' "$c2xb" | grep -q 'ERR  CLAUDE.md is 201 lines'; then
    ok "§2 C2x fails a 201-line CLAUDE.md (an ERR, not a WARN)"
  else
    bad "§2 C2x fails a 201-line CLAUDE.md" "$(printf '%s' "$c2xb" | head -3 | tr '\n' ' ')"
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

# ── § 4b  the migration trio at source, and its per-project narrowing ────────────────────
# The scoping used to be INVERTED: the base shipped scoped to schema-migration dirs while its
# extensions shipped with no `paths:` (every session) — so during a port the extensions loaded and
# the philosophy they extend did not. At source the three now share one pack-default list; per
# project the extensions narrow to v2_root and the base to its dirs + every extension glob.
say ""
say "§ 4b the migration trio: one source list, narrowed per project, never inverted"
HOOK_SRC4="${HOOK_OVERRIDE:-$REPO_ROOT/templates/repo-baseline/.claude/hooks/inject-path-rules.sh}"
eval "$(awk '/^rule_globs\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$HOOK_SRC4")"
MB="$REPO_ROOT/templates/packs/backend/rules/migration-backend.md"
MF="$REPO_ROOT/templates/packs/frontend/rules/migration-frontend.md"
MD="$REPO_ROOT/templates/packs/migration/rules/migration-discipline.md"
if [ -f "$SCOPE_DOM" ] && [ -f "$MB" ] && [ -f "$MF" ] && [ -f "$MD" ]; then
  base_g=$(rule_globs "$MD"); miss=""
  for ext in "$MB" "$MF"; do
    [ -n "$(rule_globs "$ext")" ] || miss="$miss $(basename "$ext"):no-paths"
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      printf '%s\n' "$base_g" | grep -qxF "$g" || miss="$miss $(basename "$ext"):$g"
    done <<< "$(rule_globs "$ext")"
  done
  if [ -z "$miss" ]; then ok "§4b at source every extension glob is in the base's list"
  else bad "§4b at source an extension loads where its base does not" "$miss"; fi

  R4B="$TD/migtrio"; seed_target "$R4B"; mkdir -p "$R4B/ai/migration"
  cp "$MB" "$MF" "$MD" "$R4B/.claude/rules/"
  bash "$SCOPE_DOM" "$R4B" --apply >/dev/null 2>&1 || true
  if grep -q '^paths-origin: pack-default-' "$R4B/.claude/rules/migration-backend.md" \
     && grep -q '^paths-origin: pack-default-' "$R4B/.claude/rules/migration-discipline.md"; then
    ok "§4b nothing project-specific known (no anchors) -> the broad defaults stay"
  else
    bad "§4b with no anchors the defaults were rewritten" "$(head -4 "$R4B/.claude/rules/migration-discipline.md" | tr '\n' ' ')"
  fi
  printf -- '---\nv2_root: apps/\nv1_root: ../v1\n---\n' > "$R4B/ai/migration/_v2-anchors.md"
  bash "$SCOPE_DOM" "$R4B" --apply >/dev/null 2>&1 || true
  ext_now=$(rule_globs "$R4B/.claude/rules/migration-backend.md" | tr '\n' ' ')
  base_now=$(rule_globs "$R4B/.claude/rules/migration-discipline.md" | tr '\n' ' ')
  if [ "$ext_now" = "apps/** ai/migration/** " ]; then ok "§4b an extension at its pack default narrows to v2_root + the port artifacts"
  else bad "§4b an extension at its pack default narrows to v2_root" "got: $ext_now"; fi
  case "$base_now" in
    *'**/migrations/**'*'ai/migration/**'*'apps/**'*)
      case "$base_now" in
        *'**/*.'*) bad "§4b the base narrows to dirs + extension globs + v2_root" "kept the broad source globs: $base_now" ;;
        *) ok "§4b the base narrows to its dirs + the extension globs + v2_root" ;;
      esac ;;
    *) bad "§4b the base narrows to its dirs + the extension globs + v2_root" "got: $base_now" ;;
  esac
  if grep -q '^paths-origin:' "$R4B/.claude/rules/"migration-*.md; then
    bad "§4b a narrowed block keeps no pack-default marker" "$(grep -l '^paths-origin:' "$R4B/.claude/rules/"migration-*.md | tr '\n' ' ')"
  else ok "§4b a narrowed block keeps no pack-default marker (it is the project's now)"; fi
  snap=$(cat "$R4B/.claude/rules/"migration-*.md | shasum)
  bash "$SCOPE_DOM" "$R4B" --apply >/dev/null 2>&1 || true
  if [ "$snap" = "$(cat "$R4B/.claude/rules/"migration-*.md | shasum)" ]; then ok "§4b re-running changes nothing"
  else bad "§4b re-running changes nothing" "a second run rewrote a migration rule"; fi

  R4C="$TD/miginverted"; seed_target "$R4C"
  cp "$MD" "$R4C/.claude/rules/"; mkrule "$R4C/.claude/rules/migration-backend.md" 'name: migration-backend' 10
  out4c=$(bash "$SCOPE_DOM" "$R4C" 2>&1)
  if printf '%s' "$out4c" | grep -q 'INVERTED migration-backend.md'; then ok "§4b an unscoped extension beside a scoped base is reported INVERTED"
  else bad "§4b an unscoped extension beside a scoped base is reported INVERTED" "$(printf '%s' "$out4c" | head -3 | tr '\n' ' ')"; fi
fi

# ── § 5  pack + domain rules carry a SOUND `paths:` at source ────────────────────────────
# Every pack rule and domain rule gets `paths:` at source unless its truth is universal for the
# projects that install it. The default is deliberately broad — the source + config file shapes
# of every stack the registry knows — because a glob that matches no file in a real project makes
# the rule load NEVER. It is marked `paths-origin: pack-default-<sha8>` so the install-time
# scopers (scope-rules.sh, scope-domain-rules.sh, Phase 4.2's track roots) may REPLACE it, and the
# hash makes an owner's edit of the globs read as the owner's: never replaced.
#
# THE ALWAYS-ON ALLOWLIST — pack rules that stay unscoped, and why:
#   align-discipline.md       how an opt-in alignment sweep is CONDUCTED (scope creep, trusted
#                             summaries); governs the run before any file is read
#   business-completeness.md  "done is the completed cycle" — every feature, plan and review
#   doc-principles.md         always-applied pack; "docs change in the same PR as the code" binds
#                             every code change, not a file class
#   finops-principles.md      "every design states its cost" — design-time, before files exist
#   product-principles.md     briefs, requirements, success definitions — conversation-first
#   security-principles.md    always-applied pack; code, config, CI and IaC alike — a glob missed
#                             here is a security miss, so it is not worth the saved tokens
# The code-quality and testing packs are owned by their track and are not asserted here yet.
say ""
say "§ 5  pack + domain rules carry a sound source paths: (or are on the always-on allowlist)"
ALLOW=" align-discipline.md business-completeness.md doc-principles.md finops-principles.md product-principles.md security-principles.md "
eval "$(awk '/^glob_to_re\(\) \{$/{f=1} f{print} f&&/^\}$/{exit}' "$HOOK_SRC4")"
SAMPLES="src/index.ts app/models/user.rb api/main.py cmd/server/main.go lib/main.dart src/App.vue src/main/java/App.java"
_sha8() { if command -v shasum >/dev/null 2>&1; then shasum; else sha1sum; fi | cut -c1-8; }
n5=0; unscoped=""; allow_scoped=""; shape=""; hash_bad=""; dead=""
for f in "$REPO_ROOT"/templates/packs/*/rules/*.md "$REPO_ROOT"/templates/domains/*/rules/*.md; do
  [ -f "$f" ] || continue
  case "$f" in */packs/testing/*|*/packs/code-quality/*) continue ;; esac
  b=$(basename "$f"); n5=$((n5+1))
  has=0; awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^paths:/{x=1} END{exit !x}' "$f" && has=1
  case "$ALLOW" in
    *" $b "*) [ "$has" = 1 ] && allow_scoped="$allow_scoped $b"; continue ;;
  esac
  [ "$has" = 1 ] || { unscoped="$unscoped $b"; continue; }
  ng=$(rule_globs "$f" | grep -c .)
  nl=$(awk '/^---[[:space:]]*$/{d++; if(d==2)exit; next} d==1&&/^paths:/{p=1;next} d==1&&p&&/^  - "/{n++;next} d==1&&p{p=0} END{print n+0}' "$f")
  [ "$ng" -ge 1 ] && [ "$ng" = "$nl" ] || shape="$shape $b($ng/$nl)"
  want=$(awk '/^---[[:space:]]*$/{d++; if(d==2)exit; next} d==1&&/^paths-origin: pack-default-/{sub(/^paths-origin: pack-default-/,""); print; exit}' "$f")
  [ -n "$want" ] && [ "$want" = "$(rule_globs "$f" | _sha8)" ] || hash_bad="$hash_bad $b"
  for s in $SAMPLES; do
    hit=0
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      printf '%s' "$s" | grep -qE "$(glob_to_re "$g")" && { hit=1; break; }
    done <<< "$(rule_globs "$f")"
    [ "$hit" = 1 ] || { dead="$dead $b:$s"; break; }
  done
done
if [ -z "$unscoped" ]; then ok "§5 all $n5 pack/domain rules are scoped at source or on the allowlist"
else bad "§5 a rule ships with no paths: and is not on the always-on allowlist" "$unscoped"; fi
if [ -z "$allow_scoped" ]; then ok "§5 the allowlist is truthful (no allowlisted rule carries paths:)"
else bad "§5 an allowlisted rule carries paths: — take it off ALLOW" "$allow_scoped"; fi
if [ -z "$shape" ]; then ok "§5 every source paths: is a block list the hook reads in full"
else bad "§5 a source paths: the hook cannot read in full (globs read/list lines)" "$shape"; fi
if [ -z "$hash_bad" ]; then ok "§5 every source default carries a pack-default marker whose hash matches its globs"
else bad "§5 marker missing or stale — recompute: rule_globs <file> | shasum | cut -c1-8" "$hash_bad"; fi
if [ -z "$dead" ]; then ok "§5 every source default matches a source file of every stack (ts rb py go dart vue java)"
else bad "§5 a source default matches no file of some stack — it would load NEVER there" "$dead"; fi

# ── § 5b  the install-time scopers replace a pack default, and nothing else ──────────────
say ""
say "§ 5b scope-rules.sh / scope-domain-rules.sh replace a pack default, never an owner's paths:"
PAY="$REPO_ROOT/templates/domains/payment/rules/payment-idempotency.md"
SRCH="$REPO_ROOT/templates/domains/search/rules/search-discipline.md"
if [ -f "$SCOPE" ] && [ -f "$PAY" ] && [ -f "$SRCH" ]; then
  R5="$TD/srcdefault"; mkdir -p "$R5/.claude/rules"
  cp "$PAY" "$R5/.claude/rules/"
  ( cd "$R5" && bash "$SCOPE" .claude/rules/payment-idempotency.md "apps/pay/**" ) >/dev/null 2>&1 || true
  g5=$(rule_globs "$R5/.claude/rules/payment-idempotency.md" | tr '\n' ' ')
  if [ "$g5" = "apps/pay/** " ] && ! grep -q '^paths-origin:' "$R5/.claude/rules/payment-idempotency.md"; then
    ok "§5b a pack default is replaced by the project's glob, marker dropped, hook reads it"
  else bad "§5b a pack default is replaced by the project's glob" "rule_globs: [$g5]"; fi
  ( cd "$R5" && bash "$SCOPE" .claude/rules/payment-idempotency.md "zzz/**" ) >/dev/null 2>&1 || true
  if [ "$(rule_globs "$R5/.claude/rules/payment-idempotency.md" | tr '\n' ' ')" = "apps/pay/** " ]; then
    ok "§5b once replaced it is the project's: a second pass leaves it"
  else bad "§5b a second pass re-scoped a project block" "$(rule_globs "$R5/.claude/rules/payment-idempotency.md" | tr '\n' ' ')"; fi
  printf -- '---\npaths:\n  - "lib/**"\nname: own\n---\n\nBody\n' > "$R5/.claude/rules/own.md"
  cp "$PAY" "$R5/.claude/rules/edited.md"
  perl -0pi -e 's{"\*\*/\*\.\{sql,prisma,graphql,gql,proto\}"}{"services/**"}' "$R5/.claude/rules/edited.md"
  s_own=$(shasum < "$R5/.claude/rules/own.md"); s_ed=$(shasum < "$R5/.claude/rules/edited.md")
  ( cd "$R5" && bash "$SCOPE" .claude/rules/own.md "zzz/**"; bash "$SCOPE" .claude/rules/edited.md "zzz/**" ) >/dev/null 2>&1 || true
  if [ "$s_own" = "$(shasum < "$R5/.claude/rules/own.md")" ]; then ok "§5b an owner-written paths: (no marker) is never touched"
  else bad "§5b an owner-written paths: was rewritten" "$(head -4 "$R5/.claude/rules/own.md" | tr '\n' ' ')"; fi
  if [ "$s_ed" = "$(shasum < "$R5/.claude/rules/edited.md")" ]; then ok "§5b a pack default the owner EDITED (hash mismatch) is never touched"
  else bad "§5b an edited pack default was replaced" "the marker alone licensed the overwrite"; fi

  R5D="$TD/srcdomain"; seed_target "$R5D"
  cp "$PAY" "$SRCH" "$R5D/.claude/rules/"
  cat > "$R5D/.claude/_extracted-codebase.md" <<'MAP'
| # | repo | module | path | kind | files |
|---|---|---|---|---|---|
| 1 | app | payments | `apps/api/src/payments` | module | 12 |
| 2 | app | users | `apps/api/src/users` | module | 9 |
| 3 | app | orders | `apps/api/src/orders` | module | 14 |
| 4 | app | catalog | `apps/api/src/catalog` | module | 7 |
MAP
  out5d=$(bash "$SCOPE_DOM" "$R5D" --apply 2>&1)
  if [ "$(rule_globs "$R5D/.claude/rules/payment-idempotency.md" | tr '\n' ' ')" = "apps/api/src/payments/** " ]; then
    ok "§5b a domain rule at its pack default is narrowed to its module"
  else bad "§5b a domain rule at its pack default is narrowed to its module" "$(printf '%s' "$out5d" | grep payment | head -2 | tr '\n' ' ')"; fi
  if grep -q '^paths-origin: pack-default-' "$R5D/.claude/rules/search-discipline.md" \
     && printf '%s' "$out5d" | grep -q 'search-discipline.md.*keeps its pack-default paths:'; then
    ok "§5b a domain rule with no module keeps its broad default (never a glob matching nothing)"
  else bad "§5b a domain rule with no module keeps its broad default" "$(printf '%s' "$out5d" | grep search | head -2 | tr '\n' ' ')"; fi
fi

# ── § 6  check-rule-budget.sh --target measures the platform's loading model ─────────────
# Its first version counted a rule only when CLAUDE.md @-imported it, failed an install that
# imported none as "INERT", treated `globs:` as scoping, skipped README.md / `_*.md`, and counted
# the skills listing as raw frontmatter bytes. Each is pinned here.
say ""
say "§ 6  check-rule-budget.sh --target counts what Claude Code actually loads"
if [ -f "$BUDGET_SH" ]; then
  R6="$TD/target"; seed_target "$R6"
  mkdir -p "$R6/docs" "$R6/.claude/rules/nested" "$R6/.claude/commands" "$R6/.claude/skills/delta" "$R6/.claude/agents"
  printf '# P\n\n@.claude/rules/imported.md\n@docs/guide.md\nNot an import: `@not-an-import.md`\n' > "$R6/CLAUDE.md"
  printf 'x\n' > "$R6/not-an-import.md"
  printf '# Guide\n\n@deep.md\n' > "$R6/docs/guide.md"
  printf '# Deep\n\nThe second hop.\n' > "$R6/docs/deep.md"
  mkrule "$R6/.claude/rules/imported.md" "" 10
  mkrule "$R6/.claude/rules/unimported.md" "" 80
  mkrule "$R6/.claude/rules/README.md" "" 5
  mkrule "$R6/.claude/rules/_notes.md" "" 5
  mkrule "$R6/.claude/rules/nested/sub.md" "" 5
  mkrule "$R6/.claude/rules/globonly.md" 'globs: "src/**"' 10
  mkrule "$R6/.claude/rules/scoped.md" 'paths:
  - "src/**"' 10
  d100=$(awk 'BEGIN{for(i=0;i<100;i++) printf "a"}'); d2000=$(awk 'BEGIN{for(i=0;i<2000;i++) printf "b"}')
  printf -- '---\ndescription: %s\n---\n\nBody\n' "$d100" > "$R6/.claude/commands/alpha.md"
  printf -- '---\ndescription: hidden one\ndisable-model-invocation: true\n---\n\nBody\n' > "$R6/.claude/commands/beta.md"
  printf -- '---\ndescription: shown by name only\n---\n\nBody\n' > "$R6/.claude/commands/gamma.md"
  printf -- '---\nname: delta\ndescription: %s\n---\n\nBody\n' "$d2000" > "$R6/.claude/skills/delta/SKILL.md"
  printf -- '---\nname: a1\ndescription: An agent.\n---\n\nBody\n' > "$R6/.claude/agents/a1.md"
  printf '{\n  "skillOverrides": { "gamma": "name-only" }\n}\n' > "$R6/.claude/settings.json"
  o6=$(bash "$BUDGET_SH" --target="$R6" 2>&1); rc6=$?
  sec_always=$(printf '%s\n' "$o6" | sed -n '/without paths:/,/^$/p')
  sec_globs=$(printf '%s\n' "$o6" | sed -n '/globs: only — not scoped by Claude Code/,/^$/p')
  if [ "$rc6" -eq 0 ] && ! printf '%s' "$o6" | grep -qE 'INERT|::error::'; then ok "§6 measures and exits 0 — no INERT verdict"
  else bad "§6 measures and exits 0 — no INERT verdict" "rc=$rc6 $(printf '%s' "$o6" | grep -E 'INERT|error' | head -1)"; fi
  m6=""
  for r in unimported.md README.md _notes.md nested/sub.md; do
    printf '%s' "$sec_always" | grep -qF ".claude/rules/$r " || m6="$m6 $r"
  done
  if [ -z "$m6" ]; then ok "§6 an unimported rule, README.md, _notes.md and a nested rule all count as loaded"
  else bad "§6 a rule Claude Code loads was not counted" "$m6"; fi
  if printf '%s' "$sec_always" | grep -q 'imported.md .*counted once'; then ok "§6 a rule both imported and in rules/ is counted once"
  else bad "§6 a rule both imported and in rules/ is counted once" "$(printf '%s' "$sec_always" | grep 'imported.md' | head -1)"; fi
  if printf '%s' "$sec_globs" | grep -q 'globonly.md' && ! printf '%s' "$sec_always" | grep -q 'globonly.md'; then
    ok "§6 a globs:-only rule is reported separately, as loaded"
  else bad "§6 a globs:-only rule is reported separately, as loaded" "$(printf '%s' "$o6" | grep globonly | head -1)"; fi
  if printf '%s' "$o6" | grep -q 'docs/deep.md.*@-import 2' && ! printf '%s' "$o6" | grep -q 'not-an-import'; then
    ok "§6 @-imports are followed past the first hop, and a code span is not an import"
  else bad "§6 @-imports are followed past the first hop" "$(printf '%s' "$o6" | grep -E 'docs/|not-an' | tr '\n' ' ')"; fi
  # listing: delta 5+4+1536 (cap), alpha 5+4+100, gamma name-only 5+2, beta hidden; 2 newlines
  if printf '%s' "$o6" | grep -q '(1663 chars of a 8000-char budget)'; then
    ok "§6 the listing uses the platform formula (cap, name-only override, disable-model-invocation)"
  else bad "§6 the listing uses the platform formula" "$(printf '%s' "$o6" | grep 'listing as the model' | head -1)"; fi
  o6b=$(SLASH_COMMAND_TOOL_CHAR_BUDGET=600 bash "$BUDGET_SH" --target="$R6" 2>&1)
  if printf '%s' "$o6b" | grep -q '1 description(s) truncated to the name' && printf '%s' "$o6b" | grep -qE '^    delta$'; then
    ok "§6 over the listing budget, the truncated-to-name entries are named"
  else bad "§6 over the listing budget, the truncated-to-name entries are named" "$(printf '%s' "$o6b" | grep -A1 'OVER BUDGET' | tr '\n' ' ')"; fi
  bash "$BUDGET_SH" --target="$R6" --budget=1 >/dev/null 2>&1; rc6c=$?
  if [ "$rc6c" -eq 1 ]; then ok "§6 --budget=<tok> fails a surface over it"
  else bad "§6 --budget=<tok> fails a surface over it" "exit $rc6c"; fi
fi

say ""
say "rule-loading fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
