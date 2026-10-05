#!/usr/bin/env bash
# baseline-capture.sh — record how the code behaves BEFORE anyone edits it.
#
# Usage:
#   baseline-capture.sh register --id=<id> --kind=<kind> --engine=<pack>/<skill> --command='<cmd>'
#                                --scope=<glob>[,<glob>] --artifact=<path> --compare=golden|file|exit|perf
#                                [--harness=<path>,…] [--tolerance=<file>.json] [--cadence=pr|nightly]
#                                [--unit=<u>] [--bench=<name>] [--higher-is-better] [--no-capture]
#   baseline-capture.sh capture  [--out=sha|main [--rebaseline]] [--kinds=quick|cheap|nightly|all|<kind>,…]
#                                [--entries=<id>,…] [--paths=<path>,…] [--run=<run-id>]
#                                [--repeat=3] [--runs=10] [--owner=<who>]
#   baseline-capture.sh list     [--manifest=<file>]
#   baseline-capture.sh validate [--manifest=<file>]
# Exit: 0 ok · 1 an entry's command was red (nothing is recorded for it) · 2 usage / invalid registry
#
# WHY. "Behaviour preserved" is a claim until the behaviour was written down before the edit. This is
# the one way anything gets written down: an engine (characterize, api-snapshot, visual-check,
# lighthouse-ci, profile-endpoint, schema-diff, eval-run, parity-test-generate) REGISTERS an entry in
# the committed registry .claude/baselines/main/manifest.json — what to run, over which paths, where
# the artifact lives — and CAPTURE re-produces entries at the current checkout:
#   --out=sha  (default) a local capture in .claude/baselines/<HEAD sha>/ — what run phase P5 does at
#              the base sha, before the implementer's first edit. Never committed (.gitignore).
#   --out=main write the registry's committed artifacts: an artifact that does not exist yet is
#              created (register's first capture); one that exists is KEPT and only checked, unless
#              --rebaseline says to rewrite it. A rewrite is a behaviour change on record:
#              test-integrity.py fails it unless an acceptance criterion declares it (`changes_baseline`).
#              An engine's own artifact (an OpenAPI baseline, Playwright snapshots, a parity __golden__)
#              is therefore never clobbered by a registration. refract-baselines-main CI captures with
#              --out=sha only — it reports drift, it never re-baselines.
# Each golden/file entry runs --repeat times (3); outputs that differ between identical runs mark the
# entry `nondeterministic` with an owner and an expiry (THR-WAIVER) — quarantined, never silently
# re-baselined (proposal §7 rule 3).
#
# --run=<run-id> captures only the entries whose scope meets the files the run's design.md names
# (§ Interfaces / § Work split paths), which is the P5 scope. The engine is behavior-diff.py: one
# comparator for capture and diff, so the two can never disagree about what "the same" means.
# Bash 3.2 compatible.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$HERE/behavior-diff.py"
die() { echo "baseline-capture: $*" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || die "python3 is required"
[ -f "$ENGINE" ] || die "behavior-diff.py is not installed beside this script — re-run apply-baseline-sync.sh"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"

sub="${1:-}"; [ $# -gt 0 ] && shift
case "$sub" in
  register)
    args=(); capture=1
    for a in "$@"; do
      case "$a" in
        --no-capture) capture=0 ;;
        --higher-is-better) args+=("--higher-is-better=1") ;;
        --id=*|--kind=*|--engine=*|--command=*|--scope=*|--artifact=*|--compare=*|--harness=*|--tolerance=*|--cadence=*|--unit=*|--bench=*) args+=("$a") ;;
        *) die "register: unknown argument $a" ;;
      esac
    done
    ( cd "$ROOT" && python3 "$ENGINE" register ${args[@]+"${args[@]}"} ) || exit $?
    id=""; for a in "$@"; do case "$a" in --id=*) id="${a#--id=}" ;; esac; done
    [ "$capture" = 1 ] || exit 0
    ( cd "$ROOT" && python3 "$ENGINE" capture --out=main --entries="$id" )
    ;;
  capture)
    args=(); run=""
    for a in "$@"; do
      case "$a" in
        --run=*) run="${a#--run=}" ;;
        --out=*|--kinds=*|--entries=*|--paths=*|--repeat=*|--runs=*|--owner=*) args+=("$a") ;;
        --rebaseline) args+=("--rebaseline=1") ;;
        *) die "capture: unknown argument $a" ;;
      esac
    done
    if [ -n "$run" ]; then
      design="$ROOT/ai/runs/$run/design.md"
      [ -f "$design" ] || die "capture --run=$run: ai/runs/$run/design.md does not exist (T1 runs have no design — pass --paths=)"
      # Paths the design names: backticked repo paths with an extension or a trailing slash.
      paths=$(grep -oE '`[A-Za-z0-9_./@-]+(\.[A-Za-z0-9]+|/)`' "$design" | tr -d '`' | sort -u | tr '\n' ',')
      [ -n "$paths" ] || die "capture --run=$run: design.md names no file paths in backticks"
      args+=("--paths=$paths")
    fi
    ( cd "$ROOT" && python3 "$ENGINE" capture ${args[@]+"${args[@]}"} )
    ;;
  list|validate)
    manifest="$ROOT/.claude/baselines/main/manifest.json"
    for a in "$@"; do case "$a" in --manifest=*) manifest="${a#--manifest=}" ;; *) die "$sub: unknown argument $a" ;; esac; done
    [ -f "$manifest" ] || die "no manifest at $manifest"
    if [ "$sub" = validate ]; then
      ( cd "$ROOT" && python3 "$HERE/refract_records.py" validate baseline-manifest "$manifest" )
      exit $?
    fi
    python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
print("%s — %d entr%s @%s" % (sys.argv[1], len(m["entries"]), "y" if len(m["entries"]) == 1 else "ies", m.get("sha")))
for e in m["entries"]:
    q = e.get("nondeterministic")
    print("  %-26s %-16s %-28s %-7s %s%s" % (e["id"], e["kind"], e["engine"], e.get("cadence", "pr"), ",".join(e["scope_paths"])[:60],
                                            "  QUARANTINED until %s (%s)" % (q["expiry"], q["owner"]) if q else ""))
PY
    ;;
  ""|-h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown subcommand '$sub' (register | capture | list | validate)" ;;
esac
