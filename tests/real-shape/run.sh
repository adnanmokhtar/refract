#!/usr/bin/env bash
# tests/real-shape/run.sh — run the SHIPPED artifacts against a project shaped like a real one.
#
# WHY THIS EXISTS. On 2026-08-31 three defects shipped and every one of the 40 gates stayed green
# through all of them. None needed an LLM to find and none was a logic error in the usual sense —
# each was code that was correct about an input that does not occur:
#
#   module-boundaries.sh   compared a facade path literally, so `MAY … only via <facade>` refused
#                          the one import it exists to permit
#   audit-adapter-coverage printed `ok | 1/1 (100%)` for a tool that was never selected
#   a validator fixture    turned on an empty directory that git does not track, so it passed
#                          locally off untracked state and failed the moment CI cloned it
#
# The hook's own 13 fixtures missed the first because the fixture I wrote said:
#
#     import { Money } from "src/shared/index.ts";
#
# THE MEASUREMENT THAT SETTLED IT. 33,474 import specifiers were read out of a real 5.8k-file
# TypeScript monorepo — shapes only, no names and no content. 33,466 of them carry NO extension.
# Eight do. Three end in an explicit `/index`. So the fixture certifying the facade rule was
# pinned to a form occurring 8 times in 33,474, and the form real code uses 100% of the time was
# never exercised. The test was not wrong about its assertion; it was measuring something that
# does not happen.
#
# So this suite's inputs are not invented. Every specifier form below appears with its measured
# share of that corpus, and the fixture project is laid out the way that corpus is laid out —
# apps/<app>/src/, libs/<lib>/src/, a service seven directories deep, and a tools/ script nothing
# imports.
#
#     relative parent   ../x        37.5%
#     bare path         a/b/c       21.8%
#     scoped package    @org/pkg    19.2%
#     relative same-dir ./x         14.1%
#     bare package      pkg          7.4%
#
# WHAT THIS IS NOT. It does not invoke a model. Phase 1 mode detection, Phase 2 extraction and
# Phase 4.6 anchoring stay untested — see tests/setup-project/run.sh, which says so. That half
# needs a real CLI, non-deterministic output and credentials in CI. This is the other half, and
# the reason it is worth having on its own is that all three defects above were plain
# deterministic bugs: they needed realistic SHAPE, not intelligence.
#
# Usage:  tests/real-shape/run.sh [--quiet]
# Exit:   1 if any assertion fails.

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
HERE="$(cd -P "$(dirname "$_ss")" && pwd)"; REPO_ROOT="$(cd -P "$HERE/../.." && pwd)"   # tests/real-shape → tests → repo root; unset _ss _sd
PROJECT="$HERE/project"
HOOK="$REPO_ROOT/templates/repo-baseline/.claude/hooks/module-boundaries.sh"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

pass=0; fail=0
say() { [ $QUIET -eq 0 ] && echo "$@"; return 0; }

# ---- 1. the boundary hook, once per specifier form that actually occurs ----
say "=== module-boundaries against every measured specifier form ==="
hook() {  # hook <label> <want-rc> <file> <specifier>
  local label="$1" want="$2" file="$3" spec="$4" rc out
  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","new_string":"import { X } from \\"%s\\";"}}' "$file" "$spec" \
        | ( cd "$PROJECT" && bash "$HOOK" ) 2>&1); rc=$?
  if [ "$rc" -eq "$want" ]; then
    say "  ok    $label"; pass=$((pass+1))
  else
    echo "  FAIL  $label — wanted rc=$want got rc=$rc"
    [ -n "$out" ] && echo "        $(printf '%s' "$out" | head -1)"
    fail=$((fail+1))
  fi
}

M=apps/master/src/account/service.ts
T=apps/tenant/src/orders/service.ts

# BLOCK — a declared MUST NOT, reached by the two forms that carry 59% of real imports
hook "37.5% ../x     master→tenant  BLOCK" 2 "$M" "../../../tenant/src/orders/service"
hook "21.8% a/b/c    master→tenant  BLOCK" 2 "$M" "apps/tenant/src/orders/service"

# ALLOW — forms that cannot cross a boundary at all
hook "14.1% ./x      same module    allow" 0 "$T" "./dto/create.dto"
hook "19.2% @org/pkg external       allow" 0 "$M" "@nestjs/common"
hook " 7.4% pkg      external       allow" 0 "$M" "fs"

# The facade rule, in the three spellings — the first is 100% of real code
hook "facade: bare directory  (100%)  allow" 0 "$T" "../../../../libs/database/src"
hook "facade: /index          (0.0%)  allow" 0 "$T" "../../../../libs/database/src/index"
hook "facade: /index.ts       (0.0%)  allow" 0 "$T" "../../../../libs/database/src/index.ts"
hook "facade bypassed, deep import   BLOCK" 2 "$T" "../../../../libs/database/src/interfaces/data-access.interface"

# The same tree laid out the way a pnpm workspace declares it: no root tsconfig.json (only the
# base the apps extend), each app's aliases in its OWN tsconfig, and libs/database a workspace
# package whose `exports` name build output. The hook read only <root>/tsconfig.json until
# 2026-10-15, so every case below that blocks walked through as "external". A copy is made so the
# committed project — and the ranker assertions further down — stay exactly as measured.
MONO=$(mktemp -d)
cp -R "$PROJECT/." "$MONO/"
printf 'packages:\n  - apps/*\n  - libs/*\n' > "$MONO/pnpm-workspace.yaml"
echo '{ "compilerOptions": { "strict": true } }' > "$MONO/tsconfig.base.json"
printf '{ "extends": "../../tsconfig.base.json",\n  "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["src/*"], "@tenant/*": ["../tenant/src/*"] } } }\n' \
  > "$MONO/apps/master/tsconfig.json"
printf '{ "extends": "../../tsconfig.base.json", "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["src/*"] } } }\n' \
  > "$MONO/apps/tenant/tsconfig.json"
printf '{ "name": "@org/database", "exports": { ".": { "types": "./dist/index.d.ts" }, "./interfaces/*": { "types": "./dist/interfaces/*.d.ts" } } }\n' \
  > "$MONO/libs/database/package.json"
printf '{ "extends": "../../tsconfig.base.json", "compilerOptions": { "outDir": "./dist", "rootDir": "./src" } }\n' \
  > "$MONO/libs/database/tsconfig.build.json"
echo 'export * from "./interfaces/data-access.interface";' > "$MONO/libs/database/src/index.ts"
PROJECT_SAVED="$PROJECT"; PROJECT="$MONO"
hook "monorepo: per-app @tenant/* master→tenant  BLOCK" 2 "$M" "@tenant/orders/service"
hook "monorepo: per-app @/x stays in its own app allow" 0 "$T" "@/orders/dto/create.dto"
hook "monorepo: @org/pkg workspace root = facade allow" 0 "$T" "@org/database"
hook "monorepo: @org/pkg/deep export bypasses   BLOCK" 2 "$T" "@org/database/interfaces/data-access.interface"
hook "monorepo: @org/pkg not in the workspace   allow" 0 "$T" "@nestjs/common"
PROJECT="$PROJECT_SAVED"; rm -rf "$MONO"

# The same tree with the catalog split per source root and every row written relative to the root
# its heading names — the shape a real NestJS + React monorepo's catalog had (2026-10-15), under
# which no written file mapped to any module. The facade stays repo-relative on purpose: a rule's
# facade is a file path, not a catalog row, and is read as written.
SECT=$(mktemp -d)
cp -R "$PROJECT/." "$SECT/"
cat > "$SECT/ai/modules.md" <<'MDEOF'
# Modules

## Apps (`apps/`)

| Module | Path | Owns |
|---|---|---|
| `master` | `master/src/` | control-plane app |
| `tenant` | `tenant/src/` | per-tenant app |

## Libraries (`libs/`)

| Module | Path | Owns |
|---|---|---|
| `shared` | `shared/src/` | cross-cutting primitives |
| `database` | `database/src/` | data access |

## Module boundaries (which modules MUST NOT import which)

- `master` MUST NOT import from `tenant` — reason: the control plane must not depend on a tenant runtime
- `tenant` MAY import from `database` only via `libs/database/src/index.ts`
MDEOF
PROJECT_SAVED="$PROJECT"; PROJECT="$SECT"
hook "sections: 37.5% ../x   master→tenant  BLOCK" 2 "$M" "../../../tenant/src/orders/service"
hook "sections: 21.8% a/b/c  master→tenant  BLOCK" 2 "$M" "apps/tenant/src/orders/service"
hook "sections: 14.1% ./x    same module    allow" 0 "$T" "./dto/create.dto"
hook "sections: facade bare directory       allow" 0 "$T" "../../../../libs/database/src"
hook "sections: facade bypassed, deep import BLOCK" 2 "$T" "../../../../libs/database/src/interfaces/data-access.interface"
PROJECT="$PROJECT_SAVED"; rm -rf "$SECT"

# ---- 2. the ranker, on a tree whose depths are not uniform ----
say ""
say "=== rank-source-files on a nested layout ==="
if command -v python3 >/dev/null 2>&1; then
  RANK=$(python3 "$REPO_ROOT/scripts/rank-source-files.py" "$PROJECT" --limit 20 --format list 2>/dev/null)
  check() {  # check <label> <test-expr-result>
    if [ "$2" = "0" ]; then say "  ok    $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi
  }
  top=$(printf '%s\n' "$RANK" | head -1)
  [ "$top" = "libs/shared/src/types/query.type.ts" ]; check "most-imported file ranks first (got: ${top:-none})" $?
  printf '%s\n' "$RANK" | grep -q "subscriber.service.ts"; check "a file 7 directories deep is still selected" $?
  last=$(printf '%s\n' "$RANK" | tail -1)
  [ "$last" = "tools/oneoff.ts" ]; check "the file nothing imports ranks last (got: ${last:-none})" $?
  a=$(python3 "$REPO_ROOT/scripts/rank-source-files.py" "$PROJECT" --limit 20 --format list 2>/dev/null)
  # `[ "$a" = "$RANK" ]` is satisfied by two empty strings, which is how this assertion passed
  # while every other one failed. A determinism check that cannot tell "identical" from "both
  # produced nothing" is the same shape of defect this whole suite exists to catch.
  [ -n "$RANK" ] && [ "$a" = "$RANK" ]; check "ranking is deterministic and non-empty" $?
else
  say "  SKIP  rank-source-files (needs python3)"
fi

echo ""
echo "real-shape: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
