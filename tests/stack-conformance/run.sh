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

# ---------------------------------------------------------------- repo shape
echo ""
echo "[shape] does the resolver find the source for every layout?"
# shellcheck source=/dev/null
. "$ROOT/scripts/_repo-shape.sh"
roots_of() { source_roots "$1" 2>/dev/null | tr '\n' ' '; }
assert_contains "flutter: lib/"                       "lib"           "$(roots_of "$FIX/flutter-app")"
assert_contains "vue spa: src/"                       "src"           "$(roots_of "$FIX/vue-vite-spa")"
assert_contains "nuxt: components/ (no src/ at all)"  "components"    "$(roots_of "$FIX/nuxt-storefront")"
assert_absent   "nuxt: never invents a src/"          "src "          "$(roots_of "$FIX/nuxt-storefront")"
assert_contains "turbo monorepo: apps/web/src"        "apps/web/src"  "$(roots_of "$FIX/turbo-monorepo")"
assert_contains "nest monorepo: libs/shared/src"      "libs/shared/src" "$(roots_of "$FIX/nest-monorepo")"
# every path it returns must resolve — a citation the reader cannot open is the defect it ends
shape_unresolved=0
for fx in flutter-app nuxt-storefront vue-vite-spa turbo-monorepo nest-monorepo express-backend; do
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -d "$FIX/$fx/$r" ] || shape_unresolved=$((shape_unresolved + 1))
  done < <(source_roots "$FIX/$fx" 2>/dev/null)
done
assert_contains "every returned root resolves on disk" "0" "$shape_unresolved"

# ---------------------------------------------------------------- probes
echo ""
echo "[probes] does a monorepo get a search root that exists?"
rp=$(bash "$ROOT/scripts/retarget-probes.sh" "$FIX/nest-monorepo" 2>/dev/null | tr '\n' ' ')
assert_absent "nest monorepo: retargeter does not propose a bare src/ root" "src/  →  src/" "$rp"

# ---------------------------------------------------------------- upgrade-dep
echo ""
echo "[upgrade-dep] does the command answer for every shape these fixtures cover?"
# /upgrade-dep is a prompt artifact, so what is checkable is whether its two tables ANSWER for a
# repo shape rather than whether its prose reads well. Three classes, all classification:
#   (a) every manifest these fixtures actually carry has a row in the ecosystem matrix,
#   (b) every shape family has a parity-oracle row, and
#   (c) every PROJECT_KIND and every /command the file names is one this repo really ships.
# (c) is the one that earns its slot: the first draft named a `mobile-flutter` kind that exists
# nowhere in the corpus, which would have routed a Flutter app to an oracle row it never matches.
UD="$ROOT/commands/upgrade-dep.md"

# (a) manifests on disk → matrix rows. Derived from the fixtures, so a NEW ecosystem fixture with
# no matrix row fails here rather than being discovered by a user mid-upgrade.
ud_missing_manifest=""
while IFS= read -r m; do
  [ -n "$m" ] || continue
  grep -qF "\`$m\`" "$UD" || ud_missing_manifest="$ud_missing_manifest $m"
done < <(find "$FIX" -maxdepth 3 \( -name 'package.json' -o -name 'pubspec.yaml' -o -name 'composer.json' \
           -o -name 'pyproject.toml' -o -name 'requirements.txt' -o -name 'go.mod' -o -name 'Gemfile' \
           -o -name 'Cargo.toml' -o -name '*.csproj' -o -name 'Package.swift' \) -exec basename {} \; | sort -u)
# `assert_contains ... ""` can never fail (every string contains the empty string), so the empty
# list is normalised to a sentinel and the sentinel is what is asserted. Caught by mutation: a
# fixture manifest deleted from the matrix left this green until the sentinel landed.
assert_contains "every fixture manifest has an ecosystem row" "none" "${ud_missing_manifest:-none}"

# (b) one oracle row per shape family — mobile / frontend / backend are the three the user-facing
# ask names, and a family with no row is a shape the command cannot verify.
ud_mobile_row="$(grep '^| `mobile-rn`' "$UD" | head -1)"
assert_contains "mobile shape has an oracle row"     "mobile-rn" "$ud_mobile_row"
assert_contains "mobile oracle demands BOTH targets" "Both"      "$ud_mobile_row"
assert_contains "mobile oracle names the iOS half"   "iOS"       "$ud_mobile_row"
assert_contains "mobile oracle names the Android half" "Android" "$ud_mobile_row"
assert_contains "frontend shape has an oracle row"  "frontend-*"  "$(grep -o 'frontend-\*' "$UD" | head -1)"
assert_contains "backend shape has an oracle row"   "backend-*"   "$(grep -o 'backend-\*' "$UD" | head -1)"

# (c) vocabulary: every PROJECT_KIND token the file names must appear elsewhere in the corpus, and
# every /command it routes to must be a real command file.
ud_unknown_kind=""
while IFS= read -r k; do
  [ -n "$k" ] || continue
  case "$k" in *'*') continue ;; esac   # wildcard families are not literal kinds
  grep -qE "$k" "$ROOT/commands/unify-surfaces.md" "$ROOT/commands/polish.md" "$ROOT/commands/audit.md" \
    || ud_unknown_kind="$ud_unknown_kind $k"
done < <(grep -oE 'mobile-[a-z]+|frontend-[a-z*]+|backend-[a-z*]+|data-[a-z*]+|library-[a-z*]+|cli-[a-z*]+' "$UD" | sort -u)
assert_contains "every PROJECT_KIND it names exists in the corpus" "none" "${ud_unknown_kind:-none}"

ud_dangling=""
# Only BACKTICKED slash-commands. A bare /token regex reads `ai/status.md` as a command called
# /status and reports a dangling reference that never existed — the check must not manufacture
# its own findings.
while IFS= read -r c; do
  [ -n "$c" ] || continue
  [ -f "$ROOT/commands/$c.md" ] && continue
  found=0
  for cand in "$ROOT"/templates/packs/*/commands/"$c".md "$ROOT/templates/repo-baseline/.claude/commands/$c.md"; do
    [ -f "$cand" ] && { found=1; break; }
  done
  [ "$found" -eq 1 ] && continue
  ud_dangling="$ud_dangling $c"
done < <(grep -oE '`/[a-z][a-z-]+' "$UD" | sort -u | tr -d '`/')
assert_contains "every /command it routes to resolves" "none" "${ud_dangling:-none}"

echo ""
echo "=== stack-conformance: $pass passed, $fail failed ==="
[ "$fail" -gt 0 ] && { printf 'failed:%b\n' "$failed_names"; exit 1; }
exit 0
