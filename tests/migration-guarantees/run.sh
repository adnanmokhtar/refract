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
