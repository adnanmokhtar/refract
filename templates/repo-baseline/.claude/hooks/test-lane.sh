#!/usr/bin/env bash
# test-lane.sh — one heavy test run per machine at a time; light runs stay parallel.
#
# WHY. Parallel agents each prove their change with the full suite, and a full suite spawns one
# worker per core. Eight of them at once — plus the dev servers each agent booted to exercise its
# change — exhausted 24 GB on a real machine and froze it. Nothing was wrong with any single run;
# the defect was that nothing made them take turns. Writing and editing parallelise well. Full
# suites do not: they compete for the same RAM, and a starved suite is slower than a queued one.
#
# Three modes, one file:
#
#   (no args)  PreToolUse hook on Bash, payload on stdin. Blocks a full-suite or e2e command that
#              is not going through the lane, and says how to re-run it. Light runs pass
#              untouched: one named test file, a type-check, a lint. Exit 2 = block, 0 = allow.
#
#   run <cmd>  Waits for a free slot in the machine-wide lane, runs <cmd>, releases the slot, and
#              exits with <cmd>'s status. Pass ONE quoted string when the command has `&&`, pipes
#              or env assignments; several words are exec'd as-is, keeping their quoting.
#              A green full-suite run records the exact tree it ran on (see `verified`).
#
#   verified <cmd>
#              Exit 0 iff <cmd> already ran green through the lane, from this directory, on
#              exactly the current working tree (HEAD + staged + unstaged + untracked). This is
#              what lets verify-gate.sh accept the agent's own run instead of repeating it.
#
# THE LANE is a directory of mkdir-locks (atomic on every filesystem) shared by every session of
# this user, sandboxed or not: hooks run outside the sandbox, Bash may run inside it, and both must
# see the same lock. A slot whose owner process is gone — killed, crashed, machine slept through
# a timeout — is reclaimed; a live owner is never robbed, however long it runs. Liveness is
# `kill -0`, because `ps` is refused inside the sandbox; the owner's start time is stored too, so
# where `ps` does work a recycled pid cannot hold a slot forever.
#
# FAIL-OPEN, LOUDLY. If the lane directory cannot be written, `run` warns and runs unserialized.
# Refusing would stop every test in the project; running quietly would hide that the protection
# is off. The warning names the directory and the override.
#
# Env:
#   CLAUDE_TEST_LANE_DIR    lane directory (default /tmp/claude-<uid>/test-lane)
#   CLAUDE_TEST_LANE_SLOTS  concurrent heavy runs allowed (default 1; raise on a big machine)
#   CLAUDE_TEST_LANE_WAIT   seconds `run` waits for a slot before giving up with exit 75
#                           (default 0 = wait as long as it takes)
# Opt out per project: create .claude/.no-test-lane

set -uo pipefail

LANE_DIR="${CLAUDE_TEST_LANE_DIR:-/tmp/claude-$(id -u)/test-lane}"
SLOTS="${CLAUDE_TEST_LANE_SLOTS:-1}"
WAIT="${CLAUDE_TEST_LANE_WAIT:-0}"
case "$SLOTS" in ''|*[!0-9]*|0) SLOTS=1 ;; esac
case "$WAIT"  in ''|*[!0-9]*) WAIT=0 ;; esac
EX_BUSY=75
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ── classify: prints `e2e`, `suite`, or nothing (light / not a test run) ──────────────────────
# Split on shell operators, strip env assignments and launchers, then look at the runner and
# whether any argument names a FILE. A directory or a name filter still runs the whole suite's
# workers, so only a file-shaped argument makes a run light. Watch mode never exits, so it is
# never queued: a watcher holding the lane would block every other agent forever.
file_arg() {
  local a
  for a in "$@"; do
    a=${a//\"/}; a=${a//\'/}
    case "$a" in -*|*config*|'') continue ;; esac
    case "$a" in
      *::*|*.test.*|*.spec.*|*_test.*|*_spec.*|test_*.py|*/test_*.py) return 0 ;;
      *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte|*.py|*.rb|*.go|*.rs|*.php|*.ex|*.exs|*.java|*.kt|*.dart|*.swift|*.cs) return 0 ;;
    esac
  done
  return 1
}
# $1 is a glob on purpose (`*...`, `--filter*`), so it stays unquoted in the case pattern.
# shellcheck disable=SC2254
has_arg() { local want="$1" a; shift; for a in "$@"; do case "$a" in $want) return 0 ;; esac; done; return 1; }

classify_segment() {
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) shift ;;
      *=*) shift ;;
      env|time|nice|command|exec|nohup|npx|bunx|dotenv|cross-env) shift ;;
      timeout) shift; [ $# -gt 0 ] && shift ;;
      pnpm|yarn) case "${2:-}" in exec|dlx) shift 2 ;; *) break ;; esac ;;
      uv|poetry|pipenv|hatch|pdm|bundle) case "${2:-}" in run|exec) shift 2 ;; *) break ;; esac ;;
      python|python3|py) if [ "${2:-}" = "-m" ]; then shift 2; else break; fi ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  local runner="${1##*/}" script="" kind=""
  shift
  has_arg '--watch' "$@" && return 0
  has_arg '--watchAll' "$@" && return 0
  case "$runner" in
    npm|pnpm|yarn|bun)
      while [ $# -gt 0 ]; do
        case "$1" in
          --prefix|-C|--dir|--cwd|-w|--workspace|--filter|-F|workspace) shift; [ $# -gt 0 ] && shift ;;
          -*) shift ;;
          *) break ;;
        esac
      done
      case "${1:-}" in
        run|run-script) script="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        test|t|tst)     script="test"; shift ;;
        exec|dlx|x)     shift; classify_segment "$*"; return 0 ;;
        *)              script="${1:-}"; [ $# -gt 0 ] && shift ;;
      esac
      case "$script" in
        ''|*watch*) return 0 ;;
        *e2e*|*playwright*|*cypress*|*integration*) echo e2e; return 0 ;;
        test|tests|t|tst|test:*|test-*|coverage) kind=suite ;;
        # `yarn jest`, `pnpm vitest run`: the "script" is a binary — classify that instead.
        *) classify_segment "$script $*"; return 0 ;;
      esac ;;
    jest|vitest|mocha|ava|jasmine|tap|phpunit|pest|rspec|pytest|py.test) kind=suite ;;
    # Monorepo task runners: the target name says what runs, whatever project or filter follows.
    nx|turbo)
      has_arg '*e2e*' "$@" && { echo e2e; return 0; }
      if has_arg 'test' "$@" || has_arg '*:test' "$@" || has_arg '*#test' "$@" || has_arg '*=*test*' "$@" \
         || has_arg 'test:*' "$@" || has_arg '*,test*' "$@"; then echo suite; fi
      return 0 ;;
    # `ng test` and `karma start` watch unless told otherwise; a watcher would hold the lane forever.
    ng)
      case "${1:-}" in
        e2e)  echo e2e ;;
        test) if has_arg '--watch=false' "$@" || has_arg '--no-watch' "$@"; then kind=suite; shift; else return 0; fi ;;
        *)    return 0 ;;
      esac
      [ "$kind" = suite ] || return 0 ;;
    karma)      has_arg '--single-run' "$@" && echo suite; return 0 ;;
    php)
      if [ "${1:-}" = artisan ] && [ "${2:-}" = test ]; then shift 2
      else case "${1:-}" in *phpunit|*pest) shift ;; *) return 0 ;; esac; fi
      has_arg '--filter*' "$@" && return 0
      kind=suite ;;
    python|python3|py)
      # Django: `manage.py test` runs everything; a dotted label (`orders.tests.test_refund`) narrows it.
      case "${1:-}" in *manage.py) [ "${2:-}" = test ] || return 0 ;; *) return 0 ;; esac
      shift 2
      has_arg '*.*' "$@" && return 0
      kind=suite ;;
    playwright) [ "${1:-}" = test ] && echo e2e; return 0 ;;
    cypress)    [ "${1:-}" = run ]  && echo e2e; return 0 ;;
    wdio|testcafe) echo e2e; return 0 ;;
    detox)      [ "${1:-}" = test ] && echo e2e; return 0 ;;
    go)
      [ "${1:-}" = test ] || return 0
      has_arg '*...' "$@" && echo suite
      return 0 ;;
    cargo)      case "${1:-}" in test|nextest) kind=suite; shift ;; *) return 0 ;; esac ;;
    # Mobile: anything that boots a device or simulator is e2e, whatever file it names.
    flutter)
      case "${1:-}" in
        drive) echo e2e; return 0 ;;
        test)  has_arg 'integration_test*' "$@" && { echo e2e; return 0; }; kind=suite; shift ;;
        *)     return 0 ;;
      esac ;;
    maestro)    [ "${1:-}" = test ] && echo e2e; return 0 ;;
    xcodebuild)
      if has_arg 'test' "$@" || has_arg 'test-without-building' "$@"; then
        has_arg '-only-testing*' "$@" || echo suite
      fi
      return 0 ;;
    fastlane)   if has_arg 'scan' "$@" || has_arg '*test*' "$@"; then echo suite; fi; return 0 ;;
    rails|mix|dart|swift|dotnet)
                [ "${1:-}" = test ] || return 0
                has_arg '--filter*' "$@" && return 0
                kind=suite; shift ;;
    gradle|gradlew)
                has_arg '--tests*' "$@" && return 0
                if has_arg '*connected*Test' "$@" || has_arg '*AndroidTest' "$@"; then echo e2e; return 0; fi
                if has_arg 'test' "$@" || has_arg '*:test' "$@" || has_arg 'check' "$@" || has_arg '*Test' "$@"; then echo suite; fi
                return 0 ;;
    mvn|mvnw)
                has_arg '-Dtest=*' "$@" && return 0
                has_arg '-DskipTests*' "$@" && return 0
                has_arg '-Dmaven.test.skip*' "$@" && return 0
                if has_arg 'test' "$@" || has_arg 'verify' "$@" || has_arg 'package' "$@" || has_arg 'install' "$@"; then echo suite; fi
                return 0 ;;
    *) return 0 ;;
  esac
  [ "$runner" = cargo ] && { [ $# -gt 0 ] && case "$1" in -*) ;; *) return 0 ;; esac; echo suite; return 0; }
  file_arg "$@" && return 0
  echo "$kind"
}

classify() {
  local seg out verdict="" cmd="$1"
  # A heredoc body is data (a README, a CI file, a commit message), not commands to run.
  case "$cmd" in *'<<'*) cmd=${cmd%%$'\n'*} ;; esac
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    out=$(classify_segment "$seg")
    case "$out" in
      e2e)   verdict=e2e ;;
      suite) [ -z "$verdict" ] && verdict=suite ;;
    esac
  done <<EOF
$(printf '%s\n' "$cmd" | tr ';|&' '\n\n\n')
EOF
  [ -n "$verdict" ] && echo "$verdict"
  return 0
}

# ── tree fingerprint + green stamps ──────────────────────────────────────────────────────────
# HEAD, every tracked change (staged or not), and every untracked-not-ignored file's content.
# Read-only: nothing is written to the index or the object store.
fingerprint() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 1
  local untracked
  untracked=$(git ls-files -o --exclude-standard 2>/dev/null)
  {
    git rev-parse HEAD 2>/dev/null || echo no-head
    git diff HEAD --binary 2>/dev/null
    if [ -n "$untracked" ]; then
      printf '%s\n' "$untracked"
      printf '%s\n' "$untracked" | git hash-object --stdin-paths 2>/dev/null
    fi
  } | git hash-object --stdin
}

# `npm test`, `pnpm run test`, `yarn test --silent` are the same run; `bun test` (bun's own
# runner) is not `bun run test`, so it is left alone.
normalize() {
  printf '%s\n' "$1" | tr -s ' \t' '  ' | sed -E \
    -e 's/^ +//; s/ +$//' \
    -e 's/ (--silent|-s|--quiet|-q)( |$)/\2/g' \
    -e 's/^(npm|pnpm|yarn|bun) run test( |$)/pm-test\2/' \
    -e 's/^(npm|pnpm|yarn) test( |$)/pm-test\2/'
}

stamp_file() { git rev-parse --git-path claude-test-lane-green 2>/dev/null; }

# ── lane ────────────────────────────────────────────────────────────────────────────────────
proc_start() { ps -o lstart= -p "$1" 2>/dev/null | tr -s ' '; }
SLOT=""

# Is the owner gone? `kill -0` answers from inside the sandbox too, where `ps` is refused
# outright: a dead pid is "No such process", while a live one we may not signal is "Operation not
# permitted" — alive. Only the first is proof of death; any other failure keeps the slot. When
# `ps` can see the pid, a start time that differs from the recorded one means the pid was recycled.
owner_alive() {
  local pid="$1" started="$2" out now_start
  if ! out=$(LC_ALL=C kill -0 "$pid" 2>&1); then
    printf '%s' "$out" | grep -qi 'no such process' && return 1
  fi
  if [ -n "$started" ]; then
    now_start=$(proc_start "$pid")
    [ -n "$now_start" ] && [ "$now_start" != "$started" ] && return 1
  fi
  return 0
}

slot_is_stale() {
  local slot="$1" pid
  if [ ! -f "$slot/owner" ]; then
    # Created but not yet written. The window is microseconds; a minute means the owner died there.
    [ -n "$(find "$slot" -maxdepth 0 -mmin +1 2>/dev/null)" ]; return
  fi
  pid=$(sed -n 1p "$slot/owner")
  [ -n "$pid" ] || return 1
  ! owner_alive "$pid" "$(sed -n 2p "$slot/owner")"
}

describe_slot() {
  local slot="$1"
  [ -f "$slot/owner" ] || { echo "a run that is still starting"; return; }
  local since cwd cmd now
  since=$(sed -n 3p "$slot/owner"); cwd=$(sed -n 4p "$slot/owner"); cmd=$(sed -n '5,$p' "$slot/owner" | head -c 160)
  now=$(date +%s)
  echo "pid $(sed -n 1p "$slot/owner"), $(( (now - ${since:-$now}) / 60 )) min, in $cwd: $cmd"
}

acquire() {
  local cmd="$1" i slot t0 announced=0 me
  me=$(proc_start $$)
  mkdir -p "$LANE_DIR" 2>/dev/null
  if [ ! -d "$LANE_DIR" ] || [ ! -w "$LANE_DIR" ]; then
    echo "test-lane: WARNING — cannot write $LANE_DIR, so this heavy run is NOT serialized." >&2
    echo "test-lane: point CLAUDE_TEST_LANE_DIR at a directory every session can write." >&2
    return 1
  fi
  t0=$(date +%s)
  while :; do
    i=1
    while [ "$i" -le "$SLOTS" ]; do
      slot="$LANE_DIR/slot-$i"
      if mkdir "$slot" 2>/dev/null; then
        # Written aside and renamed in: a waiter must never read a half-written owner, or it sees a
        # pid with no start time and reclaims a slot whose run is alive.
        { echo $$; echo "$me"; date +%s; pwd; printf '%s\n' "$cmd"; } > "$slot/.owner.$$" \
          && mv "$slot/.owner.$$" "$slot/owner"
        SLOT="$slot"
        [ "$announced" = 1 ] && echo "test-lane: slot free after $(( $(date +%s) - t0 ))s — running." >&2
        return 0
      fi
      if slot_is_stale "$slot"; then
        mv "$slot" "$slot.stale.$$" 2>/dev/null && rm -f "$slot.stale.$$"/owner "$slot.stale.$$"/.owner.* && rmdir "$slot.stale.$$" 2>/dev/null
        continue
      fi
      i=$((i + 1))
    done
    if [ "$announced" = 0 ]; then
      echo "test-lane: waiting — the heavy-test lane is held by $(describe_slot "$LANE_DIR/slot-1")" >&2
      announced=1
    fi
    if [ "$WAIT" -gt 0 ] && [ $(( $(date +%s) - t0 )) -ge "$WAIT" ]; then
      echo "test-lane: gave up after ${WAIT}s; the lane is still held by $(describe_slot "$LANE_DIR/slot-1")" >&2
      return "$EX_BUSY"
    fi
    sleep 1
  done
}

release() {
  [ -n "$SLOT" ] || return 0
  rm -f "$SLOT/owner"; rmdir "$SLOT" 2>/dev/null
  SLOT=""
}

run_lane() {
  [ $# -gt 0 ] || { echo "usage: test-lane.sh run '<command>'" >&2; exit 2; }
  local cmd="$*" rc fp_before="" fp_after="" sf
  trap release EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  acquire "$cmd"; rc=$?
  [ "$rc" = "$EX_BUSY" ] && exit "$EX_BUSY"
  [ "$(classify "$cmd")" = suite ] && fp_before=$(fingerprint 2>/dev/null)
  if [ $# -eq 1 ]; then bash -c "$1"; else "$@"; fi
  rc=$?
  release
  if [ "$rc" = 0 ] && [ -n "$fp_before" ]; then
    fp_after=$(fingerprint 2>/dev/null)
    sf=$(stamp_file)
    # A tree that changed mid-run was not the tree that passed; record nothing.
    if [ "$fp_before" = "$fp_after" ] && [ -n "$sf" ]; then
      { [ -f "$sf" ] && tail -n 9 "$sf"; printf '%s\t%s\t%s\n' "$fp_after" "$(pwd -P)" "$(normalize "$cmd")"; } > "$sf.tmp.$$" \
        && mv "$sf.tmp.$$" "$sf"
    fi
  fi
  exit "$rc"
}

verified() {
  [ $# -gt 0 ] || exit 1
  local sf fp
  sf=$(stamp_file); [ -n "$sf" ] && [ -f "$sf" ] || exit 1
  fp=$(fingerprint 2>/dev/null) || exit 1
  grep -qxF "$(printf '%s\t%s\t%s' "$fp" "$(pwd -P)" "$(normalize "$*")")" "$sf"
}

# ── hook ────────────────────────────────────────────────────────────────────────────────────
hook() {
  [ -f ".claude/.no-test-lane" ] && exit 0
  local payload cmd kind what quoted
  payload=$(cat)
  if command -v jq >/dev/null 2>&1; then
    cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  else
    cmd=$(printf '%s' "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  fi
  [ -z "$cmd" ] && exit 0
  case "$cmd" in *test-lane.sh*) exit 0 ;; esac
  kind=$(classify "$cmd")
  [ -z "$kind" ] && exit 0
  case "$kind" in e2e) what="an e2e run" ;; *) what="a full-suite run" ;; esac
  quoted=$(printf '%s' "$cmd" | sed "s/'/'\\\\''/g")
  {
    echo "Blocked by test-lane: this is $what, and heavy runs take turns — one per machine — so parallel agents cannot exhaust its memory."
    echo "Re-run it through the lane (it waits for a free slot, then runs; same output, same exit code):"
    echo "  \"$SELF\" run '$quoted'"
    echo "Use run_in_background if it may wait or run longer than two minutes."
    echo "Not gated, and still parallel: one named test file, a type-check, a lint. Prefer those while iterating; run the full suite once, before handing over."
    echo "Stop any dev server you started just to verify this change once you have your result."
  } >&2
  exit 2
}

case "${1:-}" in
  run)      shift; run_lane "$@" ;;
  verified) shift; verified "$@" ;;
  classify) shift; classify "$*" ;;
  "")       hook ;;
  *)        echo "usage: test-lane.sh [run '<command>' | verified '<command>' | classify '<command>']" >&2; exit 2 ;;
esac
