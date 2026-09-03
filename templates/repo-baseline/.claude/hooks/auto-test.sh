#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit) — runs the test file matching the
# edited source file. Silent on success (passing tests cost zero tokens); only
# emits output when tests fail. Always exits 0 — never blocks the agent.
#
# OPT-IN: does nothing unless .claude/.auto-test exists (running tests on every
# edit is intrusive during multi-file work, so it is off by default).
#   enable:  touch .claude/.auto-test

set -uo pipefail

[ -f ".claude/.auto-test" ] || exit 0

payload=$(cat)
if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  file_path=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

base=$(basename "$file_path"); ext="${base##*.}"; name="${base%.*}"; dir=$(dirname "$file_path")

# Skip test files themselves, config/style/non-code, and non-testable dirs.
case "$base" in *.test.*|*.spec.*|*_test.*|*_spec.*|test_*|spec_*) exit 0 ;; esac
case "$ext" in json|yaml|yml|toml|ini|cfg|env|md|txt|css|scss|less|svg|png|jpg|ico|html) exit 0 ;; esac
case "$file_path" in */.claude/*|*/public/*|*/static/*|*/assets/*|*/__mocks__/*) exit 0 ;; esac

root="$PWD"; d="$PWD"
while [ "$d" != "/" ]; do
  if [ -f "$d/package.json" ] || [ -f "$d/pyproject.toml" ] || [ -f "$d/Cargo.toml" ] || [ -f "$d/go.mod" ] || [ -d "$d/.git" ]; then root="$d"; break; fi
  d=$(dirname "$d")
done

find_test() {
  local pats=("$name.test.$ext" "$name.spec.$ext" "${name}_test.$ext" "${name}_spec.$ext" "test_$name.$ext")
  for p in "${pats[@]}"; do [ -f "$dir/$p" ] && { echo "$dir/$p"; return; }; done
  for p in "${pats[@]}"; do [ -f "$dir/__tests__/$p" ] && { echo "$dir/__tests__/$p"; return; }; done
  local rel="${dir#$root/}" trel
  for tr in tests test __tests__ spec; do
    trel=$(printf '%s' "$rel" | sed "s|^src/|$tr/|;s|^lib/|$tr/|")
    for p in "${pats[@]}"; do [ -f "$root/$trel/$p" ] && { echo "$root/$trel/$p"; return; }; done
  done
  for p in "${pats[@]}"; do
    local f; f=$(find "$root" -maxdepth 5 -name "$p" -not -path "*/node_modules/*" -not -path "*/.git/*" -print -quit 2>/dev/null)
    [ -n "$f" ] && { echo "$f"; return; }
  done
}

test_file=$(find_test)
[ -z "$test_file" ] && exit 0
rel_test="${test_file#$root/}"

out=""; code=0
case "$ext" in
  js|jsx|ts|tsx|mjs|cjs)
    if   [ -f "$root/node_modules/.bin/vitest" ]; then out=$(cd "$root" && npx vitest run "$rel_test" 2>&1); code=$?
    elif [ -f "$root/node_modules/.bin/jest" ];   then out=$(cd "$root" && npx jest "$rel_test" 2>&1); code=$?
    elif [ -f "$root/node_modules/.bin/mocha" ];  then out=$(cd "$root" && npx mocha "$rel_test" 2>&1); code=$?
    else out=$(cd "$root" && npm test -- "$rel_test" 2>&1); code=$?; fi ;;
  py)
    if command -v pytest >/dev/null 2>&1; then out=$(cd "$root" && pytest "$rel_test" 2>&1); code=$?
    elif command -v python3 >/dev/null 2>&1; then
      # `python3 -m unittest` takes a DOTTED MODULE, not a path — handed `tests/test_a.py` it
      # always errors, so this arm reported a phantom failure on every Python edit where pytest
      # was absent. Convert the path: strip .py, slashes to dots.
      mod=$(printf '%s' "${rel_test%.py}" | tr '/' '.')
      out=$(cd "$root" && python3 -m unittest "$mod" 2>&1); code=$?
    fi ;;
  go) out=$(cd "$dir" && go test ./... 2>&1); code=$? ;;
  rs) out=$(cd "$root" && cargo test 2>&1); code=$? ;;
  *)  exit 0 ;;
esac

if [ "$code" -ne 0 ]; then
  echo "auto-test: failures in $rel_test"
  echo "$out"
fi
exit 0
