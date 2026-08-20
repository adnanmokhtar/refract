#!/usr/bin/env bash
# run.sh — stage a benchmark fixture, print the exact command to run against it, and
# score the findings that come back.
#
# The loop is deliberately half-manual. Every command this repo ships is an agent
# workflow, so the scan itself has to happen inside an interactive agent session — this
# script cannot run it and does not pretend to. It does the two halves that CAN be made
# reproducible: staging a byte-identical copy of the fixture (minus the answer key), and
# scoring whatever the agent reported against the seeded defect list.
#
# Usage:
#   run.sh --list                          # fixtures, target commands, defect counts
#   run.sh --fixture=<name>                # stage + print the exact command to run
#   run.sh --fixture=<name> --score=<file> # score a findings file against the answer key
#   run.sh --verify [--fixture=<name>]     # re-check every anchor line (fixture drift gate)
#
# Flags:
#   --fixture=<name>   fixture under benchmarks/fixtures/
#   --score=<file>     findings file to score; forwards to score.py
#   --workdir=<dir>    stage here instead of a fresh mktemp dir
#   --git              git-init the staged copy with one commit, so plan/build modes
#                      that want a clean tree have one. Off by default; the scan modes
#                      this harness measures are read-only.
#   --list             list fixtures and exit
#   --verify           verify anchors and exit
#   --keep             print the staging dir and skip the cleanup hint
#   -h | --help        this text
#
# Anything after `--` is forwarded verbatim to score.py (e.g. `-- --model="..." --row`).
#
# Exit codes:
#   0  ok
#   1  a fixture is missing / anchors drifted / scoring failed
#   2  usage error

set -euo pipefail
export LC_ALL=C

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$BENCH_DIR/fixtures"
SCORER="$BENCH_DIR/score.py"

FIXTURE=""
SCORE_FILE=""
WORKDIR=""
DO_LIST=0
DO_VERIFY=0
DO_GIT=0
KEEP=0
PASSTHROUGH=()

usage() { sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

die() { printf 'run.sh: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture=*) FIXTURE="${1#*=}"; shift ;;
    --score=*)   SCORE_FILE="${1#*=}"; shift ;;
    --workdir=*) WORKDIR="${1#*=}"; shift ;;
    --list)      DO_LIST=1; shift ;;
    --verify)    DO_VERIFY=1; shift ;;
    --git)       DO_GIT=1; shift ;;
    --keep)      KEEP=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    --)          shift; PASSTHROUGH=("$@"); break ;;
    *)           printf 'run.sh: unknown arg: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -d "$FIXTURES_DIR" ]] || die "no fixtures directory at $FIXTURES_DIR"
command -v python3 >/dev/null 2>&1 || die "python3 not on PATH (score.py needs it; stdlib only)"

# --- helpers ---------------------------------------------------------------

fixture_names() {
  local d
  for d in "$FIXTURES_DIR"/*/; do
    [[ -f "$d/DEFECTS.md" ]] && basename "$d"
  done
}

# The command a fixture is built to exercise = the most frequent `command:` in its key.
fixture_command() {
  grep -hE '^command:' "$FIXTURES_DIR/$1/DEFECTS.md" \
    | sed 's/^command:[[:space:]]*//' | sort | uniq -c | sort -rn | head -1 \
    | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//'
}

fixture_count() { grep -c '^```defect' "$FIXTURES_DIR/$1/DEFECTS.md" || true; }

fixture_blurb() {
  sed -n 's/^Fixture shape: //p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1
}

# Read-only invocation per command. Flags are the ones the command files document:
#   /audit   --plan-only   (commands/audit.md — scan + rank, no edits)
#   /align   --plan        (commands/align.md — universal handoff flag, exits before any edit)
#   /roadmap (bare)        (commands/roadmap.md — read-only by default)
# We measure DETECTION, so every invocation must stop before it starts fixing.
fixture_invocation() {
  case "$1" in
    /audit)   echo "/audit --plan-only" ;;
    /align)   echo "/align --plan" ;;
    /roadmap) echo "/roadmap" ;;
    *)        echo "$1" ;;
  esac
}

require_fixture() {
  [[ -n "$FIXTURE" ]] || { printf 'run.sh: --fixture=<name> is required\n\n' >&2; usage >&2; exit 2; }
  [[ -f "$FIXTURES_DIR/$FIXTURE/DEFECTS.md" ]] \
    || die "no fixture '$FIXTURE'. Known: $(fixture_names | tr '\n' ' ')"
}

# --- --list ----------------------------------------------------------------

if [[ "$DO_LIST" -eq 1 ]]; then
  printf '\n%-18s %-10s %-8s %s\n' "FIXTURE" "COMMAND" "SEEDED" "SHAPE"
  printf '%-18s %-10s %-8s %s\n' "------------------" "----------" "--------" "-----"
  while IFS= read -r name; do
    printf '%-18s %-10s %-8s %s\n' \
      "$name" "$(fixture_command "$name")" "$(fixture_count "$name")" "$(fixture_blurb "$name")"
  done < <(fixture_names)
  printf '\nStage one with:  bash benchmarks/run.sh --fixture=<name>\n\n'
  exit 0
fi

# --- --verify --------------------------------------------------------------

if [[ "$DO_VERIFY" -eq 1 ]]; then
  rc=0
  if [[ -n "$FIXTURE" ]]; then
    require_fixture
    python3 "$SCORER" --fixture="$FIXTURE" --verify || rc=1
  else
    while IFS= read -r name; do
      python3 "$SCORER" --fixture="$name" --verify || rc=1
    done < <(fixture_names)
  fi
  exit "$rc"
fi

require_fixture

# --- scoring mode ----------------------------------------------------------

if [[ -n "$SCORE_FILE" ]]; then
  [[ -f "$SCORE_FILE" ]] || die "no such findings file: $SCORE_FILE"
  # Default --command to the fixture's target so a results row names the command it
  # measured; an explicit --command in the passthrough still wins.
  CMD_ARG=()
  if [[ " ${PASSTHROUGH[*]:-} " != *" --command"* ]]; then
    CMD_ARG=(--command="$(fixture_command "$FIXTURE")")
  fi
  exec python3 "$SCORER" --fixture="$FIXTURE" --findings="$SCORE_FILE" \
       ${CMD_ARG+"${CMD_ARG[@]}"} ${PASSTHROUGH+"${PASSTHROUGH[@]}"}
fi

# --- staging mode ----------------------------------------------------------

if [[ -z "$WORKDIR" ]]; then
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/refract-bench.XXXXXX")"
else
  mkdir -p "$WORKDIR"
fi

TARGET="$WORKDIR/$FIXTURE"
FINDINGS="$WORKDIR/findings-$FIXTURE.md"

rm -rf "$TARGET"
mkdir -p "$TARGET"

# Copy everything EXCEPT the answer key. An agent that reads DEFECTS.md scores 100% and
# the number means nothing, so this exclusion is the single most load-bearing line here.
( cd "$FIXTURES_DIR/$FIXTURE" && tar --exclude='DEFECTS.md' -cf - . ) | ( cd "$TARGET" && tar -xf - )

if [[ -e "$TARGET/DEFECTS.md" ]]; then
  die "INTERNAL: the answer key leaked into the staged copy at $TARGET — refusing to continue"
fi

if [[ "$DO_GIT" -eq 1 ]]; then
  git -C "$TARGET" init -q
  git -C "$TARGET" add -A
  git -C "$TARGET" -c user.email=bench@localhost -c user.name=bench commit -qm "fixture baseline" || true
fi

CMD="$(fixture_command "$FIXTURE")"
INVOKE="$(fixture_invocation "$CMD")"
SEEDED="$(fixture_count "$FIXTURE")"

# The instructions are an HTML comment because they contain an example path:line, and
# score.py strips comment blocks before parsing. Anything outside them is read as findings.
cat > "$FINDINGS" <<EOF
<!--
Findings — $FIXTURE — $INVOKE

Record the model id, the build/version and the date BEFORE you paste anything:

  model:         <model id — the exact string, not "Claude" or "GPT">
  model version: <build / snapshot / release date>
  date:          $(date +%Y-%m-%d)

One finding per line. Each line needs a path (path:line is better) and a short
description in the AGENT'S OWN WORDS. Rewriting the wording to make it match the answer
key scores your paraphrase, not the run.

    src/some/file.js:42 — short description of what the agent said is wrong

Paste everything the run reported, including findings you think are wrong. Findings that
map to no seeded defect are reported as UNMATCHED and are not counted against the score.

Keep this file. A published row whose evidence was deleted cannot be audited.
-->

EOF

cat <<EOF

  fixture     $FIXTURE  —  $SEEDED seeded defects, target $CMD
  workdir     $TARGET
  findings    $FINDINGS

  1. Open an agent session whose working directory is the staged copy:

       cd "$TARGET"

  2. Run exactly this, and nothing else, in that session:

       $INVOKE

     Do not add scope hints, do not name a file, do not tell it what to look for.
     Any steer you give it is a steer you cannot report in the results table.

  3. Paste every reported finding into:

       $FINDINGS

  4. Score it:

       python3 benchmarks/score.py --fixture=$FIXTURE \\
         --findings="$FINDINGS" \\
         --model="<model id>" --model-version="<build>" --date=$(date +%Y-%m-%d) --row

     Add the printed row to benchmarks/RESULTS.md. A row without a model id is not
     reproducible and score.py will refuse to print one.

EOF

if [[ "$KEEP" -eq 0 ]]; then
  printf '  Staged under %s — delete it when you are done.\n\n' "$WORKDIR"
fi
