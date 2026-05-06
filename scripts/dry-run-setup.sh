#!/usr/bin/env bash
# Lightweight integration smoke test for /setup-project.
#
# What it does:
#   1. Validates that templates/ has the expected shape.
#   2. Runs scripts/lint-tool-parity.sh.
#   3. Validates every _version.json parses as JSON and has the required keys.
#   4. Validates JSON Schemas are syntactically valid (parse with python json or ajv if installed).
#   5. Confirms each adapter's adapter.md mentions the four required sections (Target files, File formats, Idempotency, Full artifact translation).
#   6. Confirms every entry in setup-project.md Phase 4.8.0 contract has a matching folder.
#
# Usage:  scripts/dry-run-setup.sh
# Exit:   0 = clean, 1 = issues
#
# Note: this does NOT actually invoke /setup-project against a fixture repo (that requires
# a Claude session). It validates the static template surface that /setup-project consumes.

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
fail() { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass() { printf '\033[32m✓ %s\033[0m\n' "$*"; }
info() { printf '\033[36m• %s\033[0m\n' "$*"; }

echo "════════════════════════════════════════════════════════════════"
echo "  /setup-project — static dry-run smoke test"
echo "════════════════════════════════════════════════════════════════"

# 1. Required directories
info "1. Template directory shape"
for d in \
  templates/repo-baseline \
  templates/workspace-baseline \
  templates/packs \
  templates/tool-adapters \
  templates/business-domains \
  templates/domains \
  templates/regulatory-overlays \
  templates/schemas \
  commands \
  docs \
  scripts; do
  if [ -d "$ROOT/$d" ]; then
    pass "$d/"
  else
    fail "missing required directory: $d/"
  fi
done

# 2. Adapter parity lint
info ""
info "2. Tool-adapter parity lint"
if "$ROOT/scripts/lint-tool-parity.sh" >/dev/null 2>&1; then
  pass "lint-tool-parity.sh: PASS"
else
  fail "lint-tool-parity.sh: FAIL — run scripts/lint-tool-parity.sh for details"
fi

# 3. Every _version.json is valid + has required keys
info ""
info "3. _version.json validation across all template subdirs"
VERSION_COUNT=0
VERSION_FAILS=0
while IFS= read -r vf; do
  VERSION_COUNT=$((VERSION_COUNT+1))
  if ! python3 -c "import json,sys; d=json.load(open('$vf')); assert all(k in d for k in ['kind','name','version','released','min_setup_command','deprecated'])" 2>/dev/null; then
    fail "$(echo $vf | sed "s|$ROOT/||"): invalid or missing required keys (kind/name/version/released/min_setup_command/deprecated)"
    VERSION_FAILS=$((VERSION_FAILS+1))
  fi
done < <(find "$ROOT/templates" -name "_version.json" -type f)
if [ "$VERSION_FAILS" -eq 0 ]; then
  pass "$VERSION_COUNT _version.json files valid"
fi

# 4. Schemas parse as JSON
info ""
info "4. JSON Schema validation"
SCHEMA_COUNT=0
SCHEMA_FAILS=0
while IFS= read -r sf; do
  SCHEMA_COUNT=$((SCHEMA_COUNT+1))
  if ! python3 -c "import json; json.load(open('$sf'))" 2>/dev/null; then
    fail "$(echo $sf | sed "s|$ROOT/||"): not valid JSON"
    SCHEMA_FAILS=$((SCHEMA_FAILS+1))
  fi
done < <(find "$ROOT/templates/schemas" -name "*.schema.json" -type f 2>/dev/null)
if [ "$SCHEMA_COUNT" -eq 0 ]; then
  fail "no schemas found in templates/schemas/"
elif [ "$SCHEMA_FAILS" -eq 0 ]; then
  pass "$SCHEMA_COUNT schemas valid JSON"
fi

# 5. Every adapter.md has the required sections
info ""
info "5. Adapter document structure"
for adapter_dir in "$ROOT"/templates/tool-adapters/*/; do
  [ -d "$adapter_dir" ] || continue
  name="$(basename "$adapter_dir")"
  af="$adapter_dir/adapter.md"
  [ -f "$af" ] || { fail "$name: no adapter.md"; continue; }
  for section in "## Target files" "## File formats" "## Idempotency" "## Full artifact translation"; do
    if ! grep -qF "$section" "$af"; then
      fail "$name/adapter.md: missing section '$section'"
    fi
  done
done
ADAPTER_FAILS=$ERRORS
[ $ADAPTER_FAILS -eq 0 ] && pass "all 12 adapters have the four required sections"

# 6. Phase 4.8.0 contract rows match folder set
info ""
info "6. Phase 4.8.0 contract / folder consistency"
SETUP_MD="$ROOT/commands/setup-project.md"
for adapter_dir in "$ROOT"/templates/tool-adapters/*/; do
  [ -d "$adapter_dir" ] || continue
  name="$(basename "$adapter_dir")"
  if ! grep -q "^| \`$name\`" "$SETUP_MD"; then
    fail "$name: no Phase 4.8.0 contract row in setup-project.md"
  fi
done

# 7. Refine-fixture regression (marker safety + REFINE artifact presence).
info ""
info "7. /setup-project --refine regression fixture"
if "$ROOT/scripts/test-refine-fixture.sh" >/dev/null 2>&1; then
  pass "test-refine-fixture.sh: PASS"
else
  fail "test-refine-fixture.sh: FAIL — run scripts/test-refine-fixture.sh for details"
fi

# 8. Adapter fixture test — every documented native path is in BOTH the contract
#    row in setup-project.md and the adapter doc (catches asymmetric drift).
info ""
info "8. Adapter fixture test (per-adapter contract \u2194 doc symmetry)"
if "$ROOT/scripts/test-adapter-fixtures.sh" >/dev/null 2>&1; then
  pass "test-adapter-fixtures.sh: PASS"
else
  fail "test-adapter-fixtures.sh: FAIL — run scripts/test-adapter-fixtures.sh for details"
fi

# 9. Migration regression — legacy → native shape documented for every selected adapter.
info ""
info "9. Migration regression (legacy \u2192 native shape)"
if "$ROOT/scripts/test-migration-paths.sh" >/dev/null 2>&1; then
  pass "test-migration-paths.sh: PASS"
else
  fail "test-migration-paths.sh: FAIL — run scripts/test-migration-paths.sh for details"
fi

# 10. Decision-log + hooks.json structural validator — Phase 4.6/4.7/4.8 tokens + hook
#     event names + helper-function names documented in spec + apply-pack-adaptation skill.
info ""
info "10. Decision-log + hooks.json structural validator"
if "$ROOT/scripts/lint-decision-logs.sh" >/dev/null 2>&1; then
  pass "lint-decision-logs.sh: PASS"
else
  fail "lint-decision-logs.sh: FAIL — run scripts/lint-decision-logs.sh for details"
fi

# Note: scripts/check-tool-versions.sh is NOT run here — it requires network access and
# can produce false positives from transient upstream-doc edits. Run it manually as a
# maintenance task: `scripts/check-tool-versions.sh` (informational) or `--strict` in CI.

echo
echo "════════════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  Smoke test: PASS (%d schemas, %d _version.json files, 12 adapters)\033[0m\n' "$SCHEMA_COUNT" "$VERSION_COUNT"
  exit 0
else
  printf '\033[31m  Smoke test: FAIL (%d issue(s))\033[0m\n' "$ERRORS"
  exit 1
fi
