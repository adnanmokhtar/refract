#!/usr/bin/env bash
# Fixture suite for the security-critical baseline hooks.
#
# Each case file is the hook's stdin payload (JSON). The filename encodes the
# expected outcome: "*-block-*" / "*block*" ⇒ hook must exit 2 (deny);
# "*-allow-*" / "*allow*" ⇒ hook must exit 0 (permit). We pipe the payload into
# the matching hook and assert the exit code.
#
# Run: bash tests/hooks/run.sh   (exit 0 = all pass, 1 = a case failed)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS="$REPO_ROOT/templates/repo-baseline/.claude/hooks"
CASES="$REPO_ROOT/tests/hooks/cases"

# Deterministic env: fixed protected branches, dry-run notify, no CWD git deps.
export CLAUDE_PROTECTED_BRANCHES="main,master"
export CLAUDE_NOTIFY_DRYRUN=1

pass=0; fail=0

run_dir() {
  local hook_name="$1" hook="$HOOKS/$1.sh" dir="$CASES/$1"
  [ -d "$dir" ] || return 0
  local f base want got
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      *block*) want=2 ;;
      *allow*) want=0 ;;
      *) echo "SKIP  $hook_name/$base (no block/allow in name)"; continue ;;
    esac
    # Run the hook from a scratch dir so CWD-relative opt-out flags never apply.
    got=0
    ( cd "$(mktemp -d)" && cat "$f" | bash "$hook" >/dev/null 2>&1 ) || got=$?
    if [ "$got" = "$want" ]; then
      pass=$((pass+1))
    else
      fail=$((fail+1))
      echo "FAIL  $hook_name/$base — expected exit $want, got $got"
    fi
  done
}

run_dir guard-destructive
run_dir pre-edit-guard
run_dir secret-scan

# inject-path-rules is context-only (always exit 0); assert on stdout instead of
# exit code. It must run from a dir that actually holds .claude/rules/, so we run
# it inside the repo-baseline. "*nomatch*" ⇒ empty output; "*match*" ⇒ injects the
# scoped rule. (Check nomatch first — "nomatch" contains the substring "match".)
run_inject() {
  local hook="$HOOKS/inject-path-rules.sh" dir="$CASES/inject-path-rules"
  local base_dir="$REPO_ROOT/templates/repo-baseline"
  [ -d "$dir" ] || return 0
  local f base out
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    out=$( cd "$base_dir" && cat "$f" | bash "$hook" 2>/dev/null )
    case "$base" in
      *nomatch*)
        if [ -z "$out" ]; then pass=$((pass+1)); else
          fail=$((fail+1)); echo "FAIL  inject-path-rules/$base — expected no injection, got output"; fi ;;
      *match*)
        if printf '%s' "$out" | grep -q 'migration-safety'; then pass=$((pass+1)); else
          fail=$((fail+1)); echo "FAIL  inject-path-rules/$base — expected migration-safety injection, got none"; fi ;;
      *) echo "SKIP  inject-path-rules/$base (no match/nomatch in name)" ;;
    esac
  done
}
run_inject

# recall-inject is context-only (always exit 0) AND opt-in, so an exit-code assertion
# proves nothing. What is asserted instead: inert without the `.recall` marker; injects a
# seeded memory row with it; silent on an unrelated prompt, on a too-short prompt, and when
# the score floor is raised above every hit. The corpus is built in a scratch project, so
# nothing in this repo is read or written. BM25 idf collapses on a tiny corpus, so the match
# case pins CLAUDE_RECALL_MIN_SCORE — the fixture tests the pipeline, not the tuning.
seed_recall_project() {
  local proj="$1"
  mkdir -p "$proj/ai/failures" "$proj/ai/dynamic" "$proj/.claude/scripts"
  cp "$REPO_ROOT/scripts/pack-search.py" "$REPO_ROOT/scripts/gen-memory-catalog.py" \
     "$proj/.claude/scripts/" 2>/dev/null || return 1
  cat > "$proj/ai/failures/_index.md" <<'FIXEOF'
# Failure catalog (don't-retry index)

## Catalog

### 2026-08-20 — Redis-backed cart cache keyed by user id
What was tried: caching the assembled cart in Redis under a user-id key for checkout.
Why it failed: the key omitted the tenant prefix and leaked across tenants in staging.
What to do instead: prefix every cache key with the tenant id from request context.
Status: ACTIVE (still a trap)

### 2026-07-02 — Bulk insert through the ORM in one transaction
What was tried: a single transaction for a forty-thousand row import.
Why it failed: locks were held long enough to flap the deploy health check.
What to do instead: chunk the import and checkpoint between chunks.
Status: ACTIVE (still a trap)
FIXEOF
  cat > "$proj/ai/dynamic/learnings.md" <<'FIXEOF'
# Learnings

## Log

### 2026-06-20 — Checkout latency traced to the cart repository
Observation: the checkout endpoint issues one query per cart line because lines lazy-load.
Status: RAW

### 2026-05-11 — Search endpoint pagination is offset based
Observation: deep pages scan the whole result set; keyset pagination was proposed.
Status: RAW

### 2026-04-02 — Background jobs share the request logger
Observation: job logs carry a request id that no longer exists.
Status: RAW

### 2026-03-18 — Feature flags are read once at boot
Observation: a flag flip needs a restart, which surprised two engineers.
Status: RAW
FIXEOF
  return 0
}

run_recall() {
  local hook="$HOOKS/recall-inject.sh" dir="$CASES/recall-inject"
  [ -d "$dir" ] || return 0
  if ! command -v jq >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP  recall-inject (needs jq + python3; the hook is a silent no-op without them)"
    return 0
  fi
  local proj; proj=$(mktemp -d)
  seed_recall_project "$proj" || { echo "SKIP  recall-inject (could not seed fixture project)"; return 0; }

  local f base out want_empty score_env
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    want_empty=1
    score_env="1.0"
    case "$base" in
      *nomarker*)  rm -f "$proj/.claude/.recall" ;;
      *highfloor*) touch "$proj/.claude/.recall"; score_env="999" ;;
      *short*|*nomatch*) touch "$proj/.claude/.recall" ;;
      *match*)     touch "$proj/.claude/.recall"; want_empty=0 ;;
      *) echo "SKIP  recall-inject/$base (filename declares no expectation)"; continue ;;
    esac
    out=$( cd "$proj" && CLAUDE_RECALL_MIN_SCORE="$score_env" bash "$hook" < "$f" 2>/dev/null )
    if [ "$want_empty" = 1 ]; then
      if [ -z "$out" ]; then pass=$((pass+1)); else
        fail=$((fail+1)); echo "FAIL  recall-inject/$base — expected no injection, got output"; fi
    else
      if printf '%s' "$out" | grep -q 'ai/failures/_index.md' \
         && printf '%s' "$out" | grep -q '"hookEventName":"UserPromptSubmit"'; then
        pass=$((pass+1))
      else
        fail=$((fail+1)); echo "FAIL  recall-inject/$base — expected a failure-catalog pointer, got: ${out:0:120}"
      fi
    fi
  done
  rm -rf "$proj"
  rm -rf "${TMPDIR:-/tmp}/claude-recall/recall-fixture-"*
}
run_recall

# module-boundaries needs a project that actually declares boundaries, so — like recall-inject
# above — the cases run inside a seeded scratch tree rather than the harness's default scratch
# dir. The three inert paths (opt-out flag, no ai/modules.md, an empty boundaries section) are
# asserted after the case files, because each needs a DIFFERENT project state and so cannot be
# expressed as a payload.
seed_boundaries_project() {
  local proj="$1"
  mkdir -p "$proj/ai" "$proj/.claude"
  cat > "$proj/ai/modules.md" <<'FIXEOF'
# Modules

## Module catalog

| Module | Path | Owns | Public surface | Cross-cuts |
|---|---|---|---|---|
| <name> | `<src/path/>` | <one-line responsibility> | <exported types> | <auth> |
| orders | `src/orders/` | order lifecycle | createOrder | auth |
| billing | `src/billing/` | invoicing | chargeCard | auth |
| shared | `src/shared/` | primitives | Money | — |

## Module boundaries (which modules MUST NOT import which)

- `<module-A>` MUST NOT import from `<module-B>` — reason: <one line>
- `<module-A>` MAY import from `<module-B>` only via `<facade-or-port>`
- `orders` MUST NOT import from `billing` — reason: billing owns money movement; orders asks via events
- `billing` MAY import from `shared` only via `src/shared/index.ts`
FIXEOF
  return 0
}

run_boundaries() {
  local hook="$HOOKS/module-boundaries.sh" dir="$CASES/module-boundaries"
  [ -d "$dir" ] || return 0
  local proj; proj=$(mktemp -d)
  seed_boundaries_project "$proj" || { echo "SKIP  module-boundaries (could not seed)"; return 0; }

  local f base want got
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      *block*) want=2 ;;
      *allow*) want=0 ;;
      *) echo "SKIP  module-boundaries/$base (no block/allow in name)"; continue ;;
    esac
    got=0
    ( cd "$proj" && bash "$hook" < "$f" >/dev/null 2>&1 ) || got=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); else
      fail=$((fail+1))
      echo "FAIL  module-boundaries/$base — expected exit $want, got $got"
    fi
  done

  # The same payload that blocks above must be inert in each of these three states. A blocking
  # hook that cannot be switched off, or that fires on a project which declared no boundaries,
  # is worse than no hook: it gets disabled wholesale and then guards nothing.
  local violation="$dir/02-block-must-not-relative.json"
  assert_inert() {
    local what="$1" rc=0
    ( cd "$proj" && bash "$hook" < "$violation" >/dev/null 2>&1 ) || rc=$?
    if [ "$rc" = 0 ]; then pass=$((pass+1)); else
      fail=$((fail+1)); echo "FAIL  module-boundaries/$what — expected exit 0 (inert), got $rc"
    fi
  }
  : > "$proj/.claude/.no-module-boundaries"; assert_inert "opt-out-flag"
  rm -f "$proj/.claude/.no-module-boundaries"

  mv "$proj/ai/modules.md" "$proj/ai/modules.bak"; assert_inert "no-modules-file"

  grep -v 'MUST NOT import from `billing`' "$proj/ai/modules.bak" \
    | grep -v 'MAY import from `shared`' > "$proj/ai/modules.md"
  assert_inert "no-declared-boundaries"

  rm -rf "$proj"
}
run_boundaries

echo "----"
echo "hooks fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
