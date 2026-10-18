#!/usr/bin/env bash
# tests/migration-guarantees/run.sh — can the migration validator see a guarantee V2 dropped?
#
# WHY THIS EXISTS. A V1→V2 port kept every endpoint, every field and every screen, and dropped
# the unique constraint on users.email. V2 then accepted a second account with an email that
# already existed. The parity validator passed it, for three independent reasons:
#
#   no primitive class counted uniqueness      -> the backend family had 8 classes, none of them
#                                                  a unique constraint or a uniqueness check
#   .php absent from the cited-path extensions -> the Laravel V1 side resolved to nothing, so
#                                                  there was nothing to compare against
#   digits absent from the cited-path regex    -> v1/… and 2020_01_01_… paths were truncated and
#                                                  never found on disk
#   (and the trivial-tier PARITY softening would have turned a 1-count drop into a warning)
#
# Each case below replays that port with a different V2. The assertions are classifications —
# does check_inventory_primitives_match pass or fail, and what does extract_inventory_primitives
# count — never prose.
#
# Usage:  tests/migration-guarantees/run.sh [--quiet]
# Exit:   0 all passed / 1 any failure

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
HERE="$(cd -P "$(dirname "$_ss")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIX="$HERE/fixtures"
VALIDATOR="$ROOT/scripts/validate-migration-artifacts.sh"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

pass=0; fail=0; failed_names=""
ok()  { pass=$((pass+1)); [ "$QUIET" -eq 1 ] || printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { fail=$((fail+1)); failed_names="$failed_names\n  - $1"; printf '  \033[31m✗\033[0m %s\n' "$1"; }

# The validator is a script, not a library: its last line runs main. Sourcing it without that
# line exposes the functions. If the last line ever changes, say so rather than test nothing.
if [ "$(tail -n 1 "$VALIDATOR")" != 'main "$@"' ]; then
  echo "tests/migration-guarantees: $VALIDATOR no longer ends in 'main \"\$@\"' — update how this test loads it" >&2
  exit 1
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
sed '$d' "$VALIDATOR" > "$WORK/validator-lib.sh"

# ── 1. extract_inventory_primitives counts uniqueness in every ORM's spelling ──────────────────
echo "[1] unique_guard — one count per declaration or check, zero for prose"
count_unique() {  # $1=file → unique_guard count
  # set +e: the sourced script turns on errexit + pipefail, and a grep that matches nothing
  # inside the extractor would otherwise end the shell before it prints a count.
  ( cd "$WORK/orm" && bash -c "source '$WORK/validator-lib.sh' --all >/dev/null 2>&1; set +e; extract_inventory_primitives '$1' backend-nestjs" 2>/dev/null ) \
    | awk -F= '$1 == "unique_guard" { print $2 }'
}
# The validator's top-level ledger guard exits before any function is defined unless a ledger
# exists, so the fixtures are read from a scratch copy that has one.
cp -R "$FIX/orm" "$WORK/orm"
mkdir -p "$WORK/orm/ai/migration" && printf '# Migration ledger\n' > "$WORK/orm/ai/migration/ledger.md"
while read -r file want; do
  got="$(count_unique "$file")"
  if [ "$got" = "$want" ]; then ok "$file → $got"; else bad "$file → expected $want, got '${got}'"; fi
done <<'CASES'
schema.prisma 2
user.entity.ts 2
models.py 2
2024_01_01_create_users.php 2
user.rb 2
init.sql 2
marketer-form.tsx 1
noise.ts 0
CASES

# ── 2. check_inventory_primitives_match on the replayed port ───────────────────────────────────
echo "[2] a trivial-tier PARITY audit of the port — V1 is Laravel, V2 is NestJS + Prisma"
run_case() {  # $1=case → exit code of check_inventory_primitives_match
  local d="$WORK/$1"
  mkdir -p "$d/ai/migration/audits"
  cp -R "$FIX/port/v1" "$d/v1"
  cp -R "$FIX/port/cases/$1/." "$d/"
  cp "$FIX/port/audit.md" "$d/ai/migration/audits/users.md"
  printf '# Migration ledger\n' > "$d/ai/migration/ledger.md"
  ( cd "$d" && bash -c "
      source '$WORK/validator-lib.sh' --feature=users >/dev/null 2>&1
      set +e
      PROJECT_KIND=backend-nestjs; V1_ROOT=v1; V2_ROOT=src; AUDITS_DIR=ai/migration/audits; QUIET=1
      check_inventory_primitives_match users F1 trivial >/dev/null 2>&1
      echo \$?" )
}
while read -r case want why; do
  got="$(run_case "$case")"
  if [ "$got" = "$want" ]; then ok "$case → exit $got ($why)"; else bad "$case → expected exit $want, got '$got' ($why)"; fi
done <<'CASES'
lost-constraint 1 V2 dropped the unique email: the incident
constraint-without-conflict-mapping 1 constraint back, but a duplicate is a 500, not a 409 (DATA-2)
restored 0 constraint + conflict mapping balance V1's constraint + pre-check
CASES

# ── 2b. keyed set diff closes the substitution blindness of counts ──────────────────────────────
# V1 guards DELETE /orders/{order}; V2 drops that guard and adds one to GET /orders. auth_guard
# counts 1 = 1, so the count comparator passes — the blindness. With pair-inventory lane TSVs for
# both sides the I-AUTHZ lane is compared as keyed sets and the lost guard fails the row. The TSVs
# are the engine's own output (skills/paired-inventory/scripts/pair-inventory.py, paired mode,
# 2026-10-18) on these trees, with the recorded-V1 header a --record-v1 run writes.
echo "[2b] guard substituted at equal count — counts pass, the paired I-AUTHZ lane fails it"
PIN=1111111111111111111111111111111111111111
run_authz() {  # $1=case $2=v1 tsv ('' = none) $3=v2 tsv ('' = none) → "<exit> <stale-warned 0|1>"
  local d tag
  tag=$(basename "${2:-none}" .tsv); d="$WORK/authz-$1-$tag"
  mkdir -p "$d/ai/migration/audits" "$d/run"
  cp -R "$FIX/port-authz/v1" "$d/v1"
  cp -R "$FIX/port-authz/cases/$1/." "$d/"
  cp "$FIX/port-authz/audit.md" "$d/ai/migration/audits/orders.md"
  printf '# Migration ledger\n\n```yaml\n  - id: F1\n    feature: orders\n    state: done\n    v1_commit_pinned: %s\n```\n' "$PIN" > "$d/ai/migration/ledger.md"
  if [ -n "$2" ]; then mkdir -p "$d/ai/migration/v1-inventory"; cp "$FIX/port-authz/inventory/$2" "$d/ai/migration/v1-inventory/I-AUTHZ.tsv"; fi
  case "$3" in
    '') ;;
    run-*) cp -R "$FIX/port-authz/inventory/$3/." "$d/run/" ;;   # a whole paired run folder (both sides + ledger.txt)
    *) mkdir -p "$d/run/v2"; cp "$FIX/port-authz/inventory/$3" "$d/run/v2/I-AUTHZ.tsv" ;;
  esac
  ( cd "$d" && HOME="$d" bash -c "
      source '$WORK/validator-lib.sh' --feature=orders >/dev/null 2>&1
      set +e
      PROJECT_KIND=backend-nest; V1_ROOT=v1; V2_ROOT=src; AUDITS_DIR=ai/migration/audits; QUIET=0
      PAIR_INVENTORY_DIR=run
      out=\$(check_inventory_primitives_match orders F1 trivial 2>&1); rc=\$?
      case \"\$out\" in *stale-v1-inventory*) st=1 ;; *) st=0 ;; esac
      echo \"\${rc}_\${st}\"" )
}
while read -r case v1 v2 want why; do
  [ "$v1" = "-" ] && v1=""; [ "$v2" = "-" ] && v2=""
  got="$(run_authz "$case" "$v1" "$v2")"
  if [ "$got" = "$want" ]; then ok "$case ${v1:-no-inventory} → '$got' ($why)"; else bad "$case ${v1:-no-inventory} → expected '$want', got '$got' ($why)"; fi
done <<'CASES'
substituted - - 0_0 counts alone tie 1=1: the blindness the keyed lane exists to close
substituted v1-I-AUTHZ.tsv v2-substituted-I-AUTHZ.tsv 1_0 DELETE lost its guard: keyed I-AUTHZ fails the PARITY row
restored v1-I-AUTHZ.tsv v2-restored-I-AUTHZ.tsv 0_0 the guard is back on DELETE: keyed lane passes
substituted v1-I-AUTHZ-stale.tsv v2-substituted-I-AUTHZ.tsv 0_1 V1 record at another sha: lane blocked, counts are the fallback
substituted - run-substituted 1_0 a paired pair-inventory.py run folder (pin read from its ledger.txt) fails it too
CASES

# ── 4. one ledger reader for both documented row forms (D1) ─────────────────────────────────────
# find-and-fix.md § 5 records `- id: <feature>` with `status:`; migration-ledger.md documents
# `  - id: F001` with indented fields and a nested parity_runs list. Eleven checks read only
# `^id: <id>$` + unindented keys: gap parity false-FAILed and the code-reading checks skipped.
echo "[4] ledger rows in the find-and-fix and migration-ledger forms are read, not skipped"
L="$WORK/ledger"; mkdir -p "$L/ai/migration/audits" "$L/src/orders"
printf 'export class OrdersService {\n  list() { return []; }\n}\n' > "$L/src/orders/orders.service.ts"
printf '# Parity audit: orders\n> Verdict: DRIFT\n\nGAP-1 and GAP-2 closed.\n' > "$L/ai/migration/audits/orders.md"
cat > "$L/ai/migration/ledger.md" <<'LEDGER'
# Migration ledger

```yaml
- id: orders
  status: done
  tier: trivial
  v1_commit_pinned: 7a3b9c1
  v2_path: src/orders/orders.service.ts
  audit: ai/migration/audits/orders.md
  gaps_in: 2
  gaps_closed: 2
  notes: "two gaps closed"
```

```yaml
  - id: F001
    feature: report-orders
    state: V2-shadow
    phase: 4
    v2_path: src/reports/orders/handler.ts
    parity_runs:
      - id: 2026-04-26T14:22Z
        result: green
        status: ignored-nested
    gaps_in: 1
    gaps_closed: 1
  - id: F002
    feature: get-user
    state: V1-only
    phase: 2
```
LEDGER
lcall() {  # $1=shell snippet run with the validator loaded in $L → its stdout
  ( cd "$L" && bash -c "source '$WORK/validator-lib.sh' --all >/dev/null 2>&1; set +e; QUIET=0; $1" 2>&1 )
}
disc="$(lcall discover_features)"
case "$disc" in *"orders|orders||done||trivial"*) ok "find-and-fix row discovered with its slug as the feature" ;; *) bad "find-and-fix row not discovered: $disc" ;; esac
case "$disc" in *"F001|report-orders|4|V2-shadow"*) ok "indented F-row discovered; nested status: ignored" ;; *) bad "F001 discovery wrong: $disc" ;; esac
case "$disc" in *2026-04-26T14:22Z*) bad "a parity_runs entry was read as a ledger row" ;; *) ok "parity_runs[].id is not a row" ;; esac
got="$(lcall 'check_gap_count_parity orders orders >/dev/null 2>&1; echo $?')"
[ "$got" = "0" ] && ok "gap parity passes on the find-and-fix form" || bad "gap parity on the find-and-fix form → exit $got"
got="$(lcall 'check_gap_count_parity report-orders F001 >/dev/null 2>&1; echo $?')"
[ "$got" = "0" ] && ok "gap parity reads fields after a nested parity_runs list" || bad "gap parity after parity_runs → exit $got"
got="$(lcall 'check_v2_structure orders orders')"
case "$got" in *"V2 structure clean"*) ok "check_v2_structure runs on the find-and-fix form" ;; *) bad "check_v2_structure did not run: $got" ;; esac
got="$(lcall 'check_ledger_row orders orders done trivial >/dev/null 2>&1; echo $?')"
[ "$got" = "0" ] && ok "a trivial done row needs no contract / plan / parity_tests" || bad "trivial done row rejected → exit $got"
got="$(lcall 'FEATURE=report-orders; discover_features | filter_features')"
case "$got" in F001\|report-orders*) ok "--feature= matches the slug of an F-numbered row" ;; *) bad "--feature=report-orders matched: '$got'" ;; esac

# ── 5. the gate writes nothing into the tree it runs in (D26) ──────────────────────────────────
echo "[5] --self-test runs in \$TMPDIR, never under the repository"
before=$(ls -d "$ROOT"/tmp/migration-selftest.* 2>/dev/null | wc -l | tr -d ' ')
if TMPDIR="$WORK" bash "$VALIDATOR" --self-test >/dev/null 2>&1; then ok "self-test passes"; else bad "self-test failed"; fi
after=$(ls -d "$ROOT"/tmp/migration-selftest.* 2>/dev/null | wc -l | tr -d ' ')
[ "$after" = "$before" ] && ok "no migration-selftest.* directory under the repo" || bad "self-test left $((after - before)) directory(ies) under $ROOT/tmp"

# ── 6. one project kind per ROOT, and mixed counts by file (D15) ────────────────────────────────
echo "[6] project kind per root; mixed picks the family per file"
M="$WORK/mixed"; mkdir -p "$M/ai/migration" "$M/apps/api/src" "$M/apps/web/src"
printf '# Migration ledger\n' > "$M/ai/migration/ledger.md"
printf "import { Controller } from '@nestjs/common';\n" > "$M/apps/api/src/orders.ts"
printf "export const x = 1;\n" > "$M/apps/web/src/orders.ts"
fam() { ( cd "$M" && bash -c "source '$WORK/validator-lib.sh' --all >/dev/null 2>&1; set +e; $1" 2>/dev/null ); }
got="$(fam 'PROJECT_KIND=mixed; family_for_file apps/api/src/orders.ts; family_for_file apps/web/src/orders.ts; family_for_file v1/app/Models/Order.php; family_for_file v1/resources/views/a.blade.php')"
[ "$(echo $got)" = "backend frontend backend frontend" ] && ok "mixed: Nest import → backend, plain TS → frontend, .php → backend, Blade → frontend" || bad "mixed families: $(echo $got)"
got="$(fam 'PROJECT_KIND=mixed; ROOT_PATHS=(apps/api/ apps/web/); ROOT_KINDS=(backend-nest frontend-react); family_for_file apps/web/src/orders.ts; family_for_file apps/api/src/x.ts')"
[ "$(echo $got)" = "frontend backend" ] && ok "roots: each file takes its root's kind" || bad "roots families: $(echo $got)"

# ── 7. a committed tolerance loosening is seen, not only an uncommitted one (D17) ──────────────
echo "[7] tolerance loosened in a commit on the port branch"
G="$WORK/git"; mkdir -p "$G/tests/parity/orders" "$G/ai/migration/audits"
printf '# Migration ledger\n' > "$G/ai/migration/ledger.md"
printf 'fields:\n  total: exact\n' > "$G/tests/parity/orders/tolerance.yaml"
printf '# Parity audit: orders\n> Verdict: PARITY\n' > "$G/ai/migration/audits/orders.md"
gitq() { git -C "$G" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
gitq init -q -b main && gitq add -A && gitq commit -qm base
gitq checkout -qb port && printf 'fields:\n  total: exact\n  created_at: ignore\n' > "$G/tests/parity/orders/tolerance.yaml" && gitq commit -qam loosen
tcall() { ( cd "$G" && bash -c "source '$WORK/validator-lib.sh' --all >/dev/null 2>&1; set +e; QUIET=1; BASE_REF=main; check_tolerance_loosening_adr_evidence orders >/dev/null 2>&1; echo \$?" 2>/dev/null ); }
got="$(tcall)"
[ "$got" = "1" ] && ok "committed loosening with no ADR fails (halt 3)" || bad "committed loosening → exit $got (expected 1)"
printf '# Parity audit: orders\n> Verdict: PARITY\nTolerance loosened per ADR-012.\n' > "$G/ai/migration/audits/orders.md"
got="$(tcall)"
[ "$got" = "0" ] && ok "the same loosening with an ADR cited passes" || bad "loosening with ADR → exit $got (expected 0)"

# ── 3. the setup's own later rewrites are not drift ──────────────────────────────────────────
# retarget-probes.sh rewrites a bare `src/` root, and the scoping pass widens migration-discipline's
# `paths:`. Compared raw, both files re-flagged as MERGE on every refresh and C2k never cleared.
echo "[3] a retargeted probe and a widened paths: block still read as the pack's file"
S="$WORK/study"; mkdir -p "$S/.claude/commands" "$S/.claude/rules" "$S/apps/api"
cp "$ROOT/templates/packs/migration/commands/migrate.md" "$S/.claude/commands/"
cp "$ROOT/templates/packs/migration/rules/migration-discipline.md" "$S/.claude/rules/"
bash "$ROOT/scripts/retarget-probes.sh" "$S" --apply --root=apps/ >/dev/null 2>&1
perl -0pi -e 's{(paths:\n(?:  - [^\n]*\n)+)}{$1  - "apps/**"\n}' "$S/.claude/rules/migration-discipline.md"
if grep -q 'apps/' "$S/.claude/commands/migrate.md" && grep -qF '"apps/**"' "$S/.claude/rules/migration-discipline.md"; then
  bash "$ROOT/scripts/study-existing.sh" "$S" migration >/dev/null 2>&1
  for f in migrate.md migration-discipline.md; do
    row=$(grep -F "\`$f\` —" "$S/.claude/_study-existing-report.md" 2>/dev/null | head -1)
    case "$row" in *IDENTICAL-NO-OP*) ok "$f → IDENTICAL-NO-OP" ;; *) bad "$f → expected IDENTICAL-NO-OP, got: ${row:-no row}" ;; esac
  done
else
  bad "fixture setup: the retarget or the paths widening did not apply"
fi

echo
echo "── tests/migration-guarantees: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  printf "Failed:$failed_names\n"
  exit 1
fi
exit 0
