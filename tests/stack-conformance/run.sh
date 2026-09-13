#!/usr/bin/env bash
# tests/stack-conformance/run.sh — does each detector give the RIGHT ANSWER for each repo shape?
#
# WHY THIS EXISTS. tests/setup-project/ drives apply-pack.sh and asserts the copy + idempotency
# contract. It carries ZERO assertions about what the detectors ANSWER, and its fixtures are three
# files each — enough to exercise shape, never enough to exercise counting. So nothing in this
# repo ever asked "given a Flutter app, does the scanner see Dart?" and the answer was no for as
# long as the scanner existed.
#
# Ten defects shipped through that gap in a single day (2026-09-12/13), every one of them found by
# running the real pipeline against a real repo rather than a fixture, and every one of them a row
# in the matrix below:
#
#   ui-ux gated behind FRONTEND            -> no mobile app ever received the design pack
#   dart absent from 3 extension lists     -> a 436-file Flutter app reported no Dart
#   dotted-suffix detection only           -> Dart's auth_service.dart convention was invisible
#   vue/svelte absent from the LOC counter -> a 339-component app reported 0 Vue lines
#   -not -path "*test*" on the ABS path    -> any repo under a dir containing "test" reported 0 LOC
#   root package.json only (detect-tracks) -> a turbo monorepo got 10 tracks instead of 14
#   root package.json only (detect-mcp)    -> the same repo got no Playwright MCP
#   hidden dirs crowding § 2               -> no source dir in the list the anchorer reads
#
# Each assertion here is of the only kind worth having: a CLASSIFICATION, stable across runs.
# Never assert on prose.
#
# Usage:  tests/stack-conformance/run.sh [--quiet]
# Exit:   0 all passed / 1 any failure

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
HERE="$(cd -P "$(dirname "$_ss")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIX="$HERE/fixtures"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

pass=0; fail=0; failed_names=""
ok()  { pass=$((pass+1)); [ "$QUIET" -eq 1 ] || printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { fail=$((fail+1)); failed_names="$failed_names\n    - $1"; printf '  \033[31m✗\033[0m %s\n      expected: %s\n      got:      %s\n' "$1" "$2" "$3"; }

# assert_contains <label> <needle> <haystack>
assert_contains() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "to contain '$2'" "$(printf '%s' "$3" | tr '\n' ' ' | cut -c1-160)" ;; esac; }
assert_absent()   { case "$3" in *"$2"*) bad "$1" "NOT to contain '$2'" "$(printf '%s' "$3" | tr '\n' ' ' | cut -c1-160)" ;; *) ok "$1" ;; esac; }

tracks_of()  { bash "$ROOT/scripts/detect-tracks.sh" "$1" 2>/dev/null | tr '\n' ' '; }
scan_into()  { bash "$ROOT/scripts/deep-codebase-scan.sh" "$1" --force >/dev/null 2>&1; }
section()    { awk -v s="## $2" -v e="## $3" '$0 ~ "^"s {f=1} $0 ~ "^"e {f=0} f' "$1/.claude/_codebase-scan.md" 2>/dev/null; }

echo "=== stack conformance — detectors vs repo shapes ==="

# ---------------------------------------------------------------- tracks
echo ""
echo "[tracks] which packs does each shape select?"
t_flutter=$(tracks_of "$FIX/flutter-app")
assert_contains "flutter: mobile"                 "mobile"   "$t_flutter"
assert_contains "flutter: ui-ux (was gated behind FRONTEND)" "ui-ux" "$t_flutter"

t_turbo=$(tracks_of "$FIX/turbo-monorepo")
assert_contains "turbo monorepo: frontend from apps/web" "frontend" "$t_turbo"
assert_contains "turbo monorepo: backend from apps/api"  "backend"  "$t_turbo"
assert_contains "turbo monorepo: ui-ux"                  "ui-ux"    "$t_turbo"

t_be=$(tracks_of "$FIX/express-backend")
assert_absent   "backend-only: no ui-ux"  "ui-ux"    "$t_be"
assert_absent   "backend-only: no mobile" "mobile"   "$t_be"

t_nuxt=$(tracks_of "$FIX/nuxt-storefront")
assert_contains "nuxt: frontend"          "frontend" "$t_nuxt"
assert_contains "nuxt: ui-ux"             "ui-ux"    "$t_nuxt"

# ---------------------------------------------------------------- scanner
echo ""
echo "[scan] does the census see the language the project is written in?"
scan_into "$FIX/flutter-app"
assert_contains "flutter: dart in § 1 census"     "dart" "$(section "$FIX/flutter-app" '1\.' '2\.')"
assert_contains "flutter: dart in § 5 LOC"        "dart" "$(section "$FIX/flutter-app" '5\.' '6\.')"
assert_contains "flutter: underscore suffixes seen" "_controller.dart" "$(section "$FIX/flutter-app" '4\.' '5\.')"

scan_into "$FIX/nuxt-storefront"
nuxt_s2=$(section "$FIX/nuxt-storefront" '2\.' '3\.')
assert_contains "nuxt: § 2 lists components/ (hidden dirs must not crowd it)" "components" "$nuxt_s2"
assert_contains "nuxt: § 2 lists pages/"          "pages" "$nuxt_s2"
assert_contains "nuxt: vue counted in § 5 LOC"    "vue"   "$(section "$FIX/nuxt-storefront" '5\.' '6\.')"

scan_into "$FIX/vue-vite-spa"
assert_contains "vue spa: vue in § 5 LOC"         "vue"   "$(section "$FIX/vue-vite-spa" '5\.' '6\.')"

# ---------------------------------------------------------------- path trap
echo ""
echo "[scan] a repo stored under a path containing 'test' still counts its lines"
TRAP="$(mktemp -d "${TMPDIR:-/tmp}/testbed-conformance.XXXXXX")"
cp -R "$FIX/vue-vite-spa" "$TRAP/app" 2>/dev/null
scan_into "$TRAP/app"
assert_contains "path with 'test': LOC is not empty" "vue" "$(section "$TRAP/app" '5\.' '6\.')"
rm -rf "$TRAP"

# ---------------------------------------------------------------- mcp
echo ""
echo "[mcp] is the UI toolchain offered to the shapes that have a UI?"
# detect-mcp.sh prints its recommendation roster on STDERR, so 2>/dev/null silently reduces
# every assertion here to "the output was empty" — which passes an absent-check and fails a
# contains-check, i.e. the exact asymmetry that makes a green suite meaningless. Read both.
mcp_of() { bash "$ROOT/scripts/detect-mcp.sh" "$1" 2>&1 | tr 'A-Z' 'a-z'; }
assert_contains "turbo monorepo: Playwright MCP offered" "playwright" "$(mcp_of "$FIX/turbo-monorepo")"
assert_absent   "backend-only: no Playwright MCP"        "playwright" "$(mcp_of "$FIX/express-backend")"

# ---------------------------------------------------------------- probes
echo ""
echo "[probes] does a monorepo get a search root that exists?"
rp=$(bash "$ROOT/scripts/retarget-probes.sh" "$FIX/nest-monorepo" 2>/dev/null | tr '\n' ' ')
assert_absent "nest monorepo: retargeter does not propose a bare src/ root" "src/  →  src/" "$rp"

echo ""
echo "=== stack-conformance: $pass passed, $fail failed ==="
[ "$fail" -gt 0 ] && { printf 'failed:%b\n' "$failed_names"; exit 1; }
exit 0
