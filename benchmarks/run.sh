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
#   run.sh --fixture=<name>                # stage + print the exact command(s) to run
#   run.sh --fixture=<name> --score=<file> # score a findings file against the answer key
#
# A key can also declare, on its `Stage with:` line:
#   --diff      the fixture holds base/ and change/: base/ is committed, change/ is laid over it as
#               the uncommitted change (new files `git add -N`), so a diff review sees one diff
#   --baseline  install Refract's repo-baseline guard layer (.claude/ hooks, scripts, schemas,
#               agents, settings.json, gates.json, templates/) into the staged copy
# and `Lock: <run-id>` (lock-acceptance.sh runs on the shipped contract, the lock is committed) and
# `Invocation: <exact command>` (what to type, when the bare command name is not enough).
#
# A key may also declare `Kind:`:
#   Kind: routing   (routing) nothing is copied: staging writes asks.txt — case id + ask, never the
#                   labels — and an answers file; score with --score=<answers file>.
#   Kind: outcome   (feature-refund) the run BUILDS; holdout/, solution/ and wrong/ are hidden like
#                   DEFECTS.md. Staged twice: the feature run (Invocation:) and the T0 control
#                   (Invocation-T0:), each in its own copy; score with --score=<staged copy>.
#
# A fixture whose key targets two commands (slow-marketplace: /db-audit and /perf-audit) is
# staged once per command, each in its own copy with its own findings file, and each run is
# scored against its own command's defects — two results rows. The command is read from the
# findings file's header, or given as `-- --command=<cmd>`.
#   run.sh --verify [--fixture=<name>]     # re-check every anchor line (fixture drift gate)
#
# Flags:
#   --fixture=<name>   fixture under benchmarks/fixtures/
#   --score=<file>     findings file to score; forwards to score.py
#   --workdir=<dir>    stage here instead of a fresh mktemp dir
#   --git              git-init the staged copy with one commit, so plan/build modes
#                      that want a clean tree have one. Off by default; the scan modes
#                      this harness measures are read-only. A key that declares
#                      `Stage with: --git` turns it on for that fixture.
#   --no-lock          (fixtures with a `Lock:` line) the CONTROL run: stage without the acceptance
#                      lock and with .claude/.no-test-lock, so the same task runs unguarded
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
NO_LOCK=0
KEEP=0
PASSTHROUGH=()

usage() { sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

die() { printf 'run.sh: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture=*) FIXTURE="${1#*=}"; shift ;;
    --score=*)   SCORE_FILE="${1#*=}"; shift ;;
    --workdir=*) WORKDIR="${1#*=}"; shift ;;
    --list)      DO_LIST=1; shift ;;
    --verify)    DO_VERIFY=1; shift ;;
    --git)       DO_GIT=1; shift ;;
    --no-lock)   NO_LOCK=1; shift ;;
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

# Every command a fixture's key targets, most frequent first. Only ```defect blocks count:
# a decoy names the command whose run it probes, never a command of its own.
fixture_commands() {
  awk '/^```defect/ { d = 1; next } /^```/ { d = 0 }
       d && /^command:/ { sub(/^command:[[:space:]]*/, ""); print }' "$FIXTURES_DIR/$1/DEFECTS.md" \
    | sort | uniq -c | sort -rn | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//'
}

# The command a fixture is built to exercise = the most frequent `command:` in its key.
fixture_command() { fixture_commands "$1" | head -1; }

fixture_command_count() { fixture_commands "$1" | wc -l | tr -d ' '; }

# Staging flags the key asks for ("Stage with: --git"). Only --git is recognised.
fixture_wants_git() { grep -qE '^Stage with:.*--git' "$FIXTURES_DIR/$1/DEFECTS.md"; }

fixture_wants_diff()     { grep -qE '^Stage with:.*--diff' "$FIXTURES_DIR/$1/DEFECTS.md"; }
fixture_wants_baseline() { grep -qE '^Stage with:.*--baseline' "$FIXTURES_DIR/$1/DEFECTS.md"; }
fixture_lock_run()       { sed -n 's/^Lock:[[:space:]]*//p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1; }
fixture_invocation_override() { sed -n 's/^Invocation:[[:space:]]*//p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1; }
BASELINE_DIR="$(cd "$BENCH_DIR/.." && pwd)/templates/repo-baseline"

fixture_kind() { sed -n 's/^Kind:[[:space:]]*//p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1 | tr 'A-Z' 'a-z'; }
fixture_invocation_t0() { sed -n 's/^Invocation-T0:[[:space:]]*//p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1; }

# A routing key's items are ```route blocks, not ```defect blocks.
fixture_count() {
  if [[ "$(fixture_kind "$1")" == "routing" ]]; then
    grep -c '^```route' "$FIXTURES_DIR/$1/DEFECTS.md" || true
  else
    grep -c '^```defect' "$FIXTURES_DIR/$1/DEFECTS.md" || true
  fi
}

# Never staged, besides DEFECTS.md: an outcome fixture's hidden acceptance, reference and seeded-wrong code.
HIDDEN_DIRS="holdout solution wrong"

# Known-safe look-alikes a correct run must NOT report (score.py § DECOYS). Most fixtures have none.
fixture_decoys() {
  if [[ "$(fixture_kind "$1")" == "routing" ]]; then
    grep -c '^decoy:' "$FIXTURES_DIR/$1/DEFECTS.md" || true   # deliberately hard asks
  else
    grep -c '^```decoy' "$FIXTURES_DIR/$1/DEFECTS.md" || true
  fi
}

fixture_blurb() {
  sed -n 's/^Fixture shape: //p' "$FIXTURES_DIR/$1/DEFECTS.md" | head -1
}

# Read-only invocation per command. Flags are the ones the command files document:
#   /audit   --plan-only   (commands/audit.md — scan + rank, no edits)
#   /align   --plan        (commands/align.md — universal handoff flag, exits before any edit)
#   /roadmap (bare)        (commands/roadmap.md — read-only by default)
#   /security-audit (bare) (templates/packs/security/commands/security-audit.md — a read-only
#                          audit; the staged copy has no diff against a base branch, so it
#                          runs the whole-repo pass that dispatches every detector skill)
#   /db-audit (bare)       (templates/packs/database/commands/db-audit.md — read-only; no diff
#                          means the whole-repo static lane dispatches every database
#                          detector; with no database reachable, each live row prints `not run`)
#   /perf-audit (bare)     (templates/packs/performance/commands/perf-audit.md — read-only; no
#                          diff and no argument means the whole-repo dispatch of every installed
#                          performance detector, plus the database ones when that pack is installed)
#   /test-audit --whole-repo    (templates/packs/testing/commands/test-audit.md — read-only; a
#                          whole-repo run dispatches every testing detector; the staged copy has no
#                          base branch, and the flag says so instead of leaving the diff lookup to fail)
#   /quality-audit --whole-repo (templates/packs/code-quality/commands/quality-audit.md — read-only;
#                          the same, for every code-quality detector; /quality-fix is never invoked)
# We measure DETECTION, so every invocation must stop before it starts fixing.
fixture_invocation() {
  local ov
  ov="$(fixture_invocation_override "$FIXTURE")"
  [[ -n "$ov" ]] && { echo "$ov"; return; }
  case "$1" in
    /audit)          echo "/audit --plan-only" ;;
    /align)          echo "/align --plan" ;;
    /roadmap)        echo "/roadmap" ;;
    /security-audit) echo "/security-audit" ;;
    /db-audit)       echo "/db-audit" ;;
    /perf-audit)     echo "/perf-audit" ;;
    /test-audit)     echo "/test-audit --whole-repo" ;;
    /quality-audit)  echo "/quality-audit --whole-repo" ;;
    *)               echo "$1" ;;
  esac
}

require_fixture() {
  [[ -n "$FIXTURE" ]] || { printf 'run.sh: --fixture=<name> is required\n\n' >&2; usage >&2; exit 2; }
  [[ -f "$FIXTURES_DIR/$FIXTURE/DEFECTS.md" ]] \
    || die "no fixture '$FIXTURE'. Known: $(fixture_names | tr '\n' ' ')"
}

# --- --list ----------------------------------------------------------------

if [[ "$DO_LIST" -eq 1 ]]; then
  printf '\n%-18s %-26s %-8s %-7s %s\n' "FIXTURE" "COMMAND" "SEEDED" "DECOYS" "SHAPE"
  printf '%-18s %-26s %-8s %-7s %s\n' "------------------" "--------------------------" "--------" "-------" "-----"
  while IFS= read -r name; do
    if [[ "$(fixture_kind "$name")" == "routing" ]]; then
      cmds="/do --route-only"
    else
      cmds="$(fixture_commands "$name" | paste -s -d '+' - | sed 's/+/ + /g')"
    fi
    printf '%-18s %-26s %-8s %-7s %s\n' \
      "$name" "$cmds" \
      "$(fixture_count "$name")" "$(fixture_decoys "$name")" "$(fixture_blurb "$name")"
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

if [[ -n "$SCORE_FILE" && "$(fixture_kind "$FIXTURE")" == "routing" ]]; then
  [[ -f "$SCORE_FILE" ]] || die "no such answers file: $SCORE_FILE"
  exec python3 "$SCORER" --fixture="$FIXTURE" --routes="$SCORE_FILE" ${PASSTHROUGH+"${PASSTHROUGH[@]}"}
fi
if [[ -n "$SCORE_FILE" && "$(fixture_kind "$FIXTURE")" == "outcome" ]]; then
  [[ -d "$SCORE_FILE" ]] || die "an outcome fixture scores the staged copy the run worked in: --score=<dir> (-- --scenario=t0 for the control)"
  exec python3 "$SCORER" --fixture="$FIXTURE" --outcome="$SCORE_FILE" ${PASSTHROUGH+"${PASSTHROUGH[@]}"}
fi
if [[ -n "$SCORE_FILE" ]]; then
  [[ -f "$SCORE_FILE" ]] || die "no such findings file: $SCORE_FILE"
  # Default --command to the fixture's target so a results row names the command it
  # measured; an explicit --command in the passthrough still wins. A two-command fixture
  # takes it from the findings file's header ("Findings — <fixture> — <invocation>"),
  # which staging wrote; a file without that header must say which run it holds.
  CMD_ARG=()
  if [[ " ${PASSTHROUGH[*]:-} " != *" --command"* ]]; then
    if [[ "$(fixture_command_count "$FIXTURE")" -gt 1 ]]; then
      RUN_CMD="$(sed -n 's/^Findings — [^ ]* — \(\/[a-z-]*\).*/\1/p' "$SCORE_FILE" | head -1)"
      if [[ -z "$RUN_CMD" ]] || ! fixture_commands "$FIXTURE" | grep -qxF "$RUN_CMD"; then
        die "$FIXTURE targets $(fixture_commands "$FIXTURE" | paste -s -d ' ' -); say which run this file holds: -- --command=<one of them>"
      fi
      CMD_ARG=(--command="$RUN_CMD")
    else
      CMD_ARG=(--command="$(fixture_command "$FIXTURE")")
    fi
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

if [[ "$DO_GIT" -eq 0 ]] && fixture_wants_git "$FIXTURE"; then
  DO_GIT=1
  GIT_NOTE="  (git-initialised: the key says \"Stage with: --git\")"
else
  GIT_NOTE=""
fi

SEEDED="$(fixture_count "$FIXTURE")"
DECOYS="$(fixture_decoys "$FIXTURE")"
DECOY_NOTE=""
[[ "$DECOYS" -gt 0 ]] && DECOY_NOTE=" + $DECOYS decoys"
NCMD="$(fixture_command_count "$FIXTURE")"

# One staged copy + one findings file per command. A single-command fixture keeps the
# historical layout ($WORKDIR/<fixture>, findings-<fixture>.md); a two-command fixture gets
# $WORKDIR/<command>/<fixture> and findings-<fixture>-<command>.md, so neither run can read
# the other's report (the second audit would otherwise consume the first one's ai/audits/).
stage_one() {
  local cmd="$1" target="$2" findings="$3"
  rm -rf "$target"
  mkdir -p "$target"

  # Copy everything EXCEPT the answer key. An agent that reads DEFECTS.md scores 100% and
  # the number means nothing, so this exclusion is the single most load-bearing line here.
  # A --diff fixture stages base/ now and lays change/ over it after the base commit below.
  if fixture_wants_diff "$FIXTURE"; then
    ( cd "$FIXTURES_DIR/$FIXTURE/base" && tar -cf - . ) | ( cd "$target" && tar -xf - )
  else
    local hidden_args=() h
    for h in $HIDDEN_DIRS; do
      [[ -d "$FIXTURES_DIR/$FIXTURE/$h" ]] && hidden_args+=(--exclude="./$h")
    done
    ( cd "$FIXTURES_DIR/$FIXTURE" && tar --exclude='DEFECTS.md' ${hidden_args+"${hidden_args[@]}"} -cf - . ) | ( cd "$target" && tar -xf - )
  fi
  if fixture_wants_baseline "$FIXTURE"; then
    mkdir -p "$target/.claude"
    local part
    for part in hooks scripts schemas agents templates settings.json gates.json; do
      [[ -e "$BASELINE_DIR/.claude/$part" ]] && cp -R "$BASELINE_DIR/.claude/$part" "$target/.claude/"
    done
    [[ "$NO_LOCK" -eq 1 ]] && : > "$target/.claude/.no-test-lock"
  fi

  if [[ -e "$target/DEFECTS.md" ]]; then
    die "INTERNAL: the answer key leaked into the staged copy at $target — refusing to continue"
  fi
  local hd
  for hd in $HIDDEN_DIRS; do
    if [[ -d "$FIXTURES_DIR/$FIXTURE/$hd" && -e "$target/$hd" ]]; then
      die "INTERNAL: hidden $hd/ leaked into the staged copy at $target — refusing to continue"
    fi
  done
  if [[ -n "$(find "$target" -name '*.holdout.test.js' -print | head -1)" ]]; then
    die "INTERNAL: a holdout test leaked into the staged copy at $target — refusing to continue"
  fi

  if [[ "$DO_GIT" -eq 1 ]]; then
    git -C "$target" init -q
    git -C "$target" add -A
    git -C "$target" -c user.email=bench@localhost -c user.name=bench commit -qm "fixture baseline" || true
    local lock_run
    lock_run="$(fixture_lock_run "$FIXTURE")"
    if [[ -n "$lock_run" && "$NO_LOCK" -eq 0 ]]; then
      ( cd "$target" && bash .claude/scripts/lock-acceptance.sh "$lock_run" >/dev/null ) \
        || die "could not lock $lock_run in the staged copy — the fixture's contract or tests drifted"
      git -C "$target" add -A
      git -C "$target" -c user.email=bench@localhost -c user.name=bench commit -qm "lock acceptance contract $lock_run" || true
    fi
    if fixture_wants_diff "$FIXTURE"; then
      ( cd "$FIXTURES_DIR/$FIXTURE/change" && tar -cf - . ) | ( cd "$target" && tar -xf - )
      git -C "$target" add -N .
    fi
  fi

  local invoke
  invoke="$(fixture_invocation "$cmd")"

  # An outcome run reports nothing to match: its score is read from the copy itself (no findings file).
  [[ -n "$findings" ]] || return 0

  # The instructions are an HTML comment because they contain an example path:line, and
  # score.py strips comment blocks before parsing. Anything outside them is read as findings.
  cat > "$findings" <<EOF
<!--
Findings — $FIXTURE — $invoke

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
}

KIND="$(fixture_kind "$FIXTURE")"

if [[ "$KIND" == "routing" ]]; then
  # Nothing to copy: the asks are the fixture. asks.txt carries id + ask only — the labels stay in
  # DEFECTS.md, which never leaves benchmarks/fixtures/.
  TARGET="$WORKDIR/$FIXTURE"
  ANSWERS="$WORKDIR/routes-$FIXTURE.txt"
  mkdir -p "$TARGET"
  python3 "$SCORER" --fixture="$FIXTURE" --asks > "$TARGET/asks.txt"
  if grep -qE '(^|[[:space:]])(command|tier|why|trigger|decoy):' "$TARGET/asks.txt"; then
    die "INTERNAL: a label leaked into $TARGET/asks.txt — refusing to continue"
  fi
  cat > "$ANSWERS" <<EOF
# Routes — $FIXTURE — /do --route-only
# model:         <model id — the exact string>
# model version: <build / snapshot / release date>
# date:          $(date +%Y-%m-%d)
#
# One line per case, exactly as /do --route-only printed it, prefixed with the case id:
#   RT-001 ROUTE /add-feature T3
# Lines starting with # are ignored. A case with no line is scored as a miss.
EOF
  cat <<EOF

  fixture     $FIXTURE  —  $SEEDED labelled asks ($DECOYS deliberately hard), target /do --route-only
  asks        $TARGET/asks.txt   (case id <TAB> ask — no labels)
  answers     $ANSWERS

  1. Open an agent session in a repo where Refract is installed (the router needs the installed
     command set — this repo's own checkout works).

  2. For EACH line of asks.txt run exactly this, in a fresh session or after /clear, so no earlier
     ask steers the next one:

       /do --route-only "<ask>"

     It prints one line, ROUTE /<command> <tier>. Do not rephrase the ask, do not add context.

  3. Append "<case id> <that line>" to the answers file, e.g.  RT-001 ROUTE /add-feature T3

  4. Score it:

       python3 benchmarks/score.py --fixture=$FIXTURE --routes="$ANSWERS" \\
         --model="<model id>" --model-version="<build>" --date=$(date +%Y-%m-%d) --row

     Gate (Phase 4): command accuracy >= 90%, tier accuracy >= 85%, 0 under-tiered T3 cases.

EOF
  if [[ "$KEEP" -eq 0 ]]; then
    printf '  Staged under %s — delete it when you are done.\n\n' "$WORKDIR"
  fi
  exit 0
fi

if [[ "$KIND" == "outcome" ]]; then
  # Two runs, two copies, two sessions: the feature run and the T0 control. Each copy is staged by
  # stage_one (answer key, holdout/, solution/ and wrong/ excluded; leak check), git + baseline.
  CMD="$(fixture_command "$FIXTURE")"
  INVOKE="$(fixture_invocation "$CMD")"
  INVOKE_T0="$(fixture_invocation_t0 "$FIXTURE")"
  T_FEAT="$WORKDIR/feature/$FIXTURE"
  T_ZERO="$WORKDIR/t0/$FIXTURE"
  stage_one "$CMD" "$T_FEAT" ""
  stage_one "$CMD" "$T_ZERO" ""
  cat <<EOF

  fixture     $FIXTURE  —  $SEEDED traps, scored on hidden holdouts and the run directory$GIT_NOTE

  ── run 1 of 2: the feature run ───────────────────────────────────────────

  workdir     $T_FEAT

  1. Open a NEW agent session whose working directory is this copy:   cd "$T_FEAT"
  2. Type exactly this, and nothing else:

       $INVOKE

     Answer the run's approval gates (H1, H2) as a product owner would — approve, or ask for a
     change in your own words; never name a convention, a test or a trap. Record what you
     answered in the results row's notes.
  3. When the run ends, score the copy it left behind:

       python3 benchmarks/score.py --fixture=$FIXTURE --outcome="$T_FEAT" \\
         --model="<model id>" --model-version="<build>" --date=$(date +%Y-%m-%d) --row

  ── run 2 of 2: the T0 control ────────────────────────────────────────────

  workdir     $T_ZERO

  1. Open a SECOND, fresh agent session in this copy:   cd "$T_ZERO"
  2. Type exactly this, and nothing else:

       $INVOKE_T0

  3. Score it (no ai/runs/ allowed, only the typo line changed):

       python3 benchmarks/score.py --fixture=$FIXTURE --outcome="$T_ZERO" --scenario=t0

  The holdouts, the reference solution and the seeded-wrong overlays are in neither copy.

EOF
  if [[ "$KEEP" -eq 0 ]]; then
    printf '  Staged under %s — delete it when you are done.\n\n' "$WORKDIR"
  fi
  exit 0
fi

if [[ "$NCMD" -le 1 ]]; then
  CMD="$(fixture_command "$FIXTURE")"
  INVOKE="$(fixture_invocation "$CMD")"
  TARGET="$WORKDIR/$FIXTURE"
  FINDINGS="$WORKDIR/findings-$FIXTURE.md"
  stage_one "$CMD" "$TARGET" "$FINDINGS"

  cat <<EOF

  fixture     $FIXTURE  —  $SEEDED seeded defects${DECOY_NOTE}, target $CMD
  workdir     $TARGET$GIT_NOTE
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
else
  cat <<EOF

  fixture     $FIXTURE  —  $SEEDED seeded defects${DECOY_NOTE}, $NCMD target commands
              ($(fixture_commands "$FIXTURE" | paste -s -d ' ' -)): one staged copy, one session and one
              results row per command.$GIT_NOTE
EOF
  n=0
  while IFS= read -r CMD; do
    n=$((n + 1))
    SLUG="${CMD#/}"
    INVOKE="$(fixture_invocation "$CMD")"
    TARGET="$WORKDIR/$SLUG/$FIXTURE"
    FINDINGS="$WORKDIR/findings-$FIXTURE-$SLUG.md"
    stage_one "$CMD" "$TARGET" "$FINDINGS"
    cat <<EOF

  ── run $n of $NCMD: $CMD ────────────────────────────────────────────────

  workdir     $TARGET
  findings    $FINDINGS

  1. Open a NEW agent session whose working directory is this copy:

       cd "$TARGET"

  2. Run exactly this, and nothing else, in that session:

       $INVOKE

     Do not add scope hints, do not name a file, do not tell it what to look for.

  3. Paste every reported finding into the findings file above.

  4. Score it against $CMD's defects (and its decoys only):

       python3 benchmarks/score.py --fixture=$FIXTURE --command=$CMD \\
         --findings="$FINDINGS" \\
         --model="<model id>" --model-version="<build>" --date=$(date +%Y-%m-%d) --row
EOF
  done < <(fixture_commands "$FIXTURE")
  cat <<EOF

  Each run is its own row in benchmarks/RESULTS.md. A finding one run makes about the other
  command's classes is UNMATCHED in that row, never credited; concatenate both findings
  files and score with no --command to see the union.

EOF
fi

if [[ "$KEEP" -eq 0 ]]; then
  printf '  Staged under %s — delete it when you are done.\n\n' "$WORKDIR"
fi
