#!/usr/bin/env bash
# run-pack-evals.sh — run a pack's evals/ suite under `claude plugin eval`, with the pack loaded and
# without it (the no-plugin baseline arm), and say whether the pack earned its place (Δ > 0, spec § 8.8).
#
# A pack is not a plugin on disk: it has skills/, commands/ and agents/ but no manifest, and
# `claude plugin eval` needs `.claude-plugin/plugin.json` (code.claude.com/docs/en/plugin-evals,
# fetched 2026-10-19). So the pack is STAGED: its skills/commands/agents/evals are copied to
# <out>/stage/templates/packs/<pack>/ beside a copy of templates/snippets/ (the skills' relative
# links still resolve) with a generated manifest `refract-<pack>`. The repository is never written.
#
#   bash scripts/run-pack-evals.sh --pack=<pack>|--all --model=<id> [--judge-model=<id>] [--runs=3]
#        [--max-cost-usd=5] [--out=<dir>] [--record] [--stop-at-utilization=0.95] [--bash]
#   bash scripts/run-pack-evals.sh … --case=<glob> [--ablation=with-without|none]   # one plain run, as before
#   bash scripts/run-pack-evals.sh --pack=<pack>|--all --stage-only [--out=<dir>]   # no model call
#
# THE LANES (default, no --case). Per pack, three `claude plugin eval` runs, one after another:
#   ask    the hard case (audit-<fixture>-slice; delivery spec-<fixture>-slice), --ablation with-without:
#          the plain ask with the pack and without it → ask with / without / Δ and the skill-fired rate
#   cmd    cmd-<fixture>-slice, --ablation none: the same slice and graders behind /refract-<pack>:<audit
#          command> → cmd score, and cmd Δ = cmd score − ask WITHOUT (the command against the bare model)
#   stays  stays-out-of-unrelated-asks, --ablation with-without (the pack must not fire on a foreign ask)
# --max-cost-usd is the pack's budget across its lanes: each lane gets what the earlier ones left.
# The lanes are combined into <out>/<pack>.json (benchmarks/history.py combine-lanes, refract/pack-lanes/v1).
#
# USAGE LIMITS. After every lane, benchmarks/history.py limit-check reads the result, each run's trace and the
# CLI log: a run that ended on a usage / rate-limit error, a `rejected` rate_limit_event, or a limit warning
# STOPS the whole run at once (exit 3) — later lanes and packs never start. So does a reported window
# utilization at or above --stop-at-utilization (default 0.95): a plan's weekly limit is never pushed through.
#
# --bash grants Bash to BOTH arms, so a pack's runnable detectors (pre-flight rg, the stdlib scripts under
# skills/<x>/scripts/) can run. Only the STAGED copy changes, never the repository's cases:
#   - every case's `allowed_tools` gets Bash, and every lane passes `--allow-tools Bash`;
#   - Bash runs under Claude Code's OS sandbox (code.claude.com/docs/en/plugin-evals § Grant tools, fetched
#     2026-10-20: writes confined to the workspace, the HOME DIRECTORY UNREADABLE, network off), so the plugin
#     is staged under $TMPDIR, not under --out (which may sit in ~), and PATH entries under $HOME are dropped
#     for the run (a python3 from a venv in ~ cannot start there); on macOS the developer dir's real git goes
#     before the /usr/bin xcrun shim, which cannot run in the sandbox;
#   - the installed path a skill prints for its own script (`.claude/skills/<skill>/scripts/…`, where the
#     installer puts it) is rewritten to the staged plugin's absolute `…/skills/<skill>/scripts`, and so are the
#     two other shapes that locate one (`find .claude/skills -path '*/<skill>/scripts/…'`, `${KS:-.claude/skills}`)
#     — in a run the workspace holds no .claude/skills/; the plugin directory does.
# History rows get `variant: "bash"` (benchmarks/history.py) and RESULTS.md shows them beside the no-Bash rows.
#
# --model is required for a run: an unpinned model makes a model rollout look like a pack regression.
# --record appends each complete result to benchmarks/results/history.jsonl (benchmarks/history.py
# append-eval; partial results and limit-hit runs are refused there) and re-renders benchmarks/RESULTS.md.
#
# Every run is a real model call billed to the account in the environment (ANTHROPIC_API_KEY in CI).
# Exit (lanes): 0 every pack cmd Δ > 0 · 1 a pack cmd Δ <= 0 or missing · 2 NOT-RUN / partial ·
#               3 stopped on a usage / rate limit (or the utilization ceiling).
# Exit (--case): 0 every pack Δ > 0 · 1 a pack Δ <= 0, no Δ, or a case below threshold · 2 NOT-RUN / partial.
set -uo pipefail

# Resolve the global-install symlink chain first (lint-setup-contracts.sh Rule 10).
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
PACK="" ALL=0 MODEL="" JUDGE="" RUNS=3 COST=5 CASE="" ABL="" OUT="" RECORD=0 STAGE_ONLY=0 UTIL_STOP=0.95 BASH_GRANT=0
for a in "$@"; do
  case "$a" in
    --pack=*) PACK="${a#*=}" ;;
    --all) ALL=1 ;;
    --model=*) MODEL="${a#*=}" ;;
    --judge-model=*) JUDGE="${a#*=}" ;;
    --runs=*) RUNS="${a#*=}" ;;
    --max-cost-usd=*) COST="${a#*=}" ;;
    --case=*) CASE="${a#*=}" ;;
    --ablation=*) ABL="${a#*=}" ;;
    --out=*) OUT="${a#*=}" ;;
    --record) RECORD=1 ;;
    --stage-only) STAGE_ONLY=1 ;;
    --stop-at-utilization=*) UTIL_STOP="${a#*=}" ;;
    --bash) BASH_GRANT=1 ;;
    -h|--help) sed -n '2,50p' "$0"; exit 0 ;;
    *) echo "run-pack-evals: unknown argument $a" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || OUT="${TMPDIR:-/tmp}/refract-pack-evals.$$"
STAGE="$OUT/stage" RUN_PATH="$PATH"
if [ "$BASH_GRANT" = 1 ]; then
  # The run's sandbox cannot read $HOME: stage where it can, and keep ~ out of the run's PATH.
  _t="${TMPDIR:-/tmp}"; STAGE="${_t%/}/refract-pack-evals-stage.$$"; unset _t
  case "$STAGE/" in "${HOME%/}"/*) echo "run-pack-evals: --bash needs a TMPDIR outside \$HOME (the run's sandbox cannot read ~); got $STAGE" >&2; exit 2 ;; esac
  RUN_PATH=$(printf '%s\n' "$PATH" | tr ':' '\n' | awk -v h="${HOME%/}" 'length($0) && index($0, h "/") != 1 && $0 != h' | paste -sd: -)
  # macOS: /usr/bin/git is an xcrun shim that fails in the sandbox ("couldn't create cache file … xcode-select:
  # Failed to locate 'git'", measured in the 2026-10-20 pilot) — put the developer dir's real binaries before it.
  _dev=$(xcode-select -p 2>/dev/null) || _dev=""
  if [ -n "$_dev" ] && [ -x "$_dev/usr/bin/git" ]; then
    RUN_PATH=$(printf '%s\n' "$RUN_PATH" | tr ':' '\n' | awk -v d="$_dev/usr/bin" '$0 == "/usr/bin" && !s { print d; s = 1 } { print }' | paste -sd: -)
  fi
  unset _dev
  [ "$STAGE_ONLY" = 1 ] || trap 'rm -rf "${STAGE:?}"' EXIT
fi
mkdir -p "$OUT" "$STAGE/templates" || exit 2

packs=""
if [ "$ALL" = 1 ]; then
  for d in "$ROOT"/templates/packs/*/evals; do
    [ -d "$d" ] || continue
    p="${d%/evals}"; packs="$packs ${p##*/}"
  done
elif [ -n "$PACK" ]; then
  [ -d "$ROOT/templates/packs/$PACK/evals" ] || { echo "run-pack-evals: templates/packs/$PACK has no evals/ suite" >&2; exit 2; }
  packs="$PACK"
else
  echo "run-pack-evals: name --pack=<pack> or --all" >&2; exit 2
fi

[ -d "$STAGE/templates/snippets" ] || cp -R "$ROOT/templates/snippets" "$STAGE/templates/snippets"

stage() {  # stage <pack> -> prints the staged plugin directory
  local p="$1" src="$ROOT/templates/packs/$1" dst="$STAGE/templates/packs/$1" ver
  rm -rf "$dst"; mkdir -p "$dst/.claude-plugin"
  for sub in skills commands agents evals; do
    [ -d "$src/$sub" ] && cp -R "$src/$sub" "$dst/$sub"
  done
  rm -rf "$dst/evals/results"
  ver=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version","0.0.0"))' "$src/_version.json" 2>/dev/null || echo 0.0.0)
  printf '{\n  "name": "refract-%s",\n  "version": "%s",\n  "description": "Refract %s pack, staged for claude plugin eval by scripts/run-pack-evals.sh"\n}\n' \
    "$p" "$ver" "$p" > "$dst/.claude-plugin/plugin.json"
  if [ "$BASH_GRANT" = 1 ]; then
    python3 - "$dst" >&2 <<'PY' || return 1
import os, re, sys
dst = sys.argv[1]
sk = os.path.join(dst, "skills")
skills = set(os.listdir(sk)) if os.path.isdir(sk) else set()
tools = re.compile(r"^(\s*allowed_tools:\s*\[)([^\]]*)\]", re.M)
installed = re.compile(r"\.claude/skills/([A-Za-z0-9_-]+)/scripts\b")
# the two other shapes a skill uses to locate its scripts: a find over the skills root, and a skills-root default
find_root = re.compile(r"(\bfind\s+)\.claude/skills\b")
var_root = re.compile(r"(\$\{\w+:-)\.claude/skills\}")
n_tools = n_paths = 0


def add_bash(m):
    items = [t.strip() for t in m.group(2).split(",") if t.strip()]
    return m.group(1) + ", ".join(items + ([] if "Bash" in items else ["Bash"])) + "]"


def to_staged(m):
    return "%s/skills/%s/scripts" % (dst, m.group(1)) if m.group(1) in skills else m.group(0)


for root, _, files in os.walk(dst):
    for f in files:
        path = os.path.join(root, f)
        top = os.path.relpath(path, dst).split(os.sep)[0]
        if top == "evals" and f in ("prompt.md", "case.yaml"):
            rx, fn = tools, add_bash
        elif top in ("skills", "commands", "agents") and f.endswith(".md"):
            rx, fn = installed, to_staged
        else:
            continue
        text = open(path, encoding="utf-8").read()
        new, k = rx.subn(fn, text)
        if top != "evals":
            new, k2 = find_root.subn(lambda m: m.group(1) + dst + "/skills", new)
            new, k3 = var_root.subn(lambda m: m.group(1) + dst + "/skills}", new)
            k += k2 + k3
        if new != text:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new)
        if top == "evals":
            n_tools += k
        else:
            n_paths += k
print("        staged with Bash: %d case(s) granted Bash, %d installed script path(s) pointed at the staged plugin"
      % (n_tools, n_paths))
PY
  fi
  printf '%s\n' "$dst"
}

if [ "$STAGE_ONLY" = 0 ]; then
  [ -n "$MODEL" ] || { echo "run-pack-evals: --model=<id> is required — pin it so a model rollout is not read as a pack regression" >&2; exit 2; }
  command -v claude >/dev/null 2>&1 || { echo "run-pack-evals: NOT-RUN — the claude CLI is not on PATH" >&2; exit 2; }
fi
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo claude)   # resolved before RUN_PATH drops the ~ entries

HIST="$ROOT/benchmarks/history.py"
VARIANT=""; [ "$BASH_GRANT" = 1 ] && VARIANT=bash

# lane <pack> <staged dir> <lane> <case glob> <ablation> <budget usd> -> 0 ran · 3 limit hit · 4 utilization ceiling
lane() {
  local p="$1" dir="$2" ln="$3" glob="$4" abl="$5" budget="$6" rc=0 lrc=0 u
  mkdir -p "$OUT/$p"
  set -- "$dir" --trust-plugin --scaffold --json "$OUT/$p/$ln.json" --model "$MODEL" --runs "$RUNS" --threshold 0 \
         --max-cost-usd "$budget" --no-publish --output-dir "$OUT/$p/$ln" --case "$glob" --ablation "$abl" --keep-temp
  # --keep-temp: each run's trace.jsonl must outlive the run — limit-check reads its rate_limit_event lines
  [ -n "$JUDGE" ] && set -- "$@" --judge-model "$JUDGE"
  [ "$BASH_GRANT" = 1 ] && set -- "$@" --allow-tools Bash
  rm -f "$OUT/$p/$ln.json"
  PATH="$RUN_PATH" "$CLAUDE_BIN" plugin eval "$@" >"$OUT/$p/$ln.log" 2>&1 || rc=$?
  python3 "$HIST" limit-check --eval-json="$OUT/$p/$ln.json" --log="$OUT/$p/$ln.log" >"$OUT/$p/$ln.limit" 2>&1 || lrc=$?
  u=$(sed -n 's/^utilization //p' "$OUT/$p/$ln.limit")
  echo "        $p/$ln: claude plugin eval exit $rc · utilization ${u:-unreported}"
  if [ "$lrc" = 3 ]; then sed -n 's/^LIMIT /        LIMIT /p' "$OUT/$p/$ln.limit"; return 3; fi
  if python3 - "$UTIL_STOP" "$u" <<'PY'
import sys
stop, u = float(sys.argv[1]), sys.argv[2]
vals = [float(x.split("=")[1]) for x in u.split() if "=" in x]
sys.exit(0 if vals and max(vals) >= stop else 1)
PY
  then echo "        $p/$ln: a usage window is at or above --stop-at-utilization=$UTIL_STOP"; return 4; fi
  return 0
}

spent() {  # spent <json>... -> list-price USD those results report
  python3 - "$@" <<'PY'
import json, os, sys
t = 0.0
for f in sys.argv[1:]:
    if os.path.isfile(f) and os.path.getsize(f):
        try:
            t += json.load(open(f)).get("costUsd") or 0
        except ValueError:
            pass
print("%.4f" % t)
PY
}

done_packs=""
worst=0
for p in $packs; do
  dir=$(stage "$p")
  if [ "$STAGE_ONLY" = 0 ] && [ -z "$CASE" ]; then
    hard=""
    for k in audit spec; do
      for c in "$dir"/evals/"$k"-*; do [ -d "$c" ] && hard="$k-*"; done
      [ -n "$hard" ] && break
    done
    [ -n "$hard" ] || { echo "NOT-RUN $p — no audit-*/spec-* hard case in evals/"; [ "$worst" -lt 2 ] && worst=2; continue; }
    stop=0
    for spec in "ask|$hard|with-without" "cmd|cmd-*|none" "stays|stays-*|with-without"; do
      ln="${spec%%|*}"; rest="${spec#*|}"; glob="${rest%%|*}"; abl="${rest#*|}"
      left=$(python3 -c 'import sys; print("%.4f" % (float(sys.argv[1]) - float(sys.argv[2])))' "$COST" \
             "$(spent "$OUT/$p/ask.json" "$OUT/$p/cmd.json" "$OUT/$p/stays.json")")
      if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > 0 else 1)' "$left"; then
        lane "$p" "$dir" "$ln" "$glob" "$abl" "$left"; lrc=$?
      else
        echo "        $p/$ln: NOT-RUN — the pack's \$$COST budget is spent"; rm -f "$OUT/$p/$ln.json"; lrc=0
      fi
      if [ "$lrc" -ge 3 ]; then stop=$lrc; break; fi
    done
    cat "$OUT/$p"/ask.log "$OUT/$p"/cmd.log "$OUT/$p"/stays.log >"$OUT/$p.log" 2>/dev/null
    if [ "$stop" != 0 ]; then
      echo "STOPPED $p — $( [ "$stop" = 3 ] && echo 'a run hit a usage / rate limit' || echo 'usage window at the utilization ceiling' ). Packs completed before it:${done_packs:- none}"
      exit 3
    fi
    if [ ! -s "$OUT/$p/ask.json" ]; then
      echo "NOT-RUN $p — the ask lane left no result (see $OUT/$p/ask.log)"; tail -3 "$OUT/$p/ask.log" | sed 's/^/        /'
      [ "$worst" -lt 2 ] && worst=2; continue
    fi
    summary=$(python3 "$HIST" combine-lanes --pack="$p" --ask="$OUT/$p/ask.json" --stays="$OUT/$p/stays.json" \
              --cmd="$OUT/$p/cmd.json" --out="$OUT/$p.json" ${VARIANT:+--variant="$VARIANT"}) || { echo "NOT-RUN $p — combine-lanes failed"; worst=2; continue; }
    verdict=$(python3 - "$summary" <<'PY'
import json, sys
s = json.loads(sys.argv[1])
f = lambda x, sg=False: "—" if x is None else ("%+.2f" % x if sg else "%.2f" % x)
tag = "PARTIAL" if s["partial"] else ("PASS" if (s["cmd_delta"] or 0) > 0 and s["cmd_delta"] is not None else "FAIL")
sh = s.get("shell") or {}
print("%s ask %s/%s Δ%s · cmd %s Δ%s · skill fired %s · stays %s · cost $%.2f%s%s" % (
    tag, f(s["ask_with"]), f(s["ask_without"]), f(s["ask_delta"], True), f(s["cmd_score"]), f(s["cmd_delta"], True),
    "—" if s["skill_fired"] is None else "%d%%" % round(100 * s["skill_fired"]), f(s["stays_score"]), s["cost_usd"],
    (" · pack scripts ran in %s/%s pack runs, pre-flight rg in %s" % (sh.get("script_runs"), sh.get("pack_runs"),
     sh.get("preflight_runs"))) if sh else "",
    (" (%s)" % s["partial_reason"]) if s["partial"] else ""))
PY
)
    echo "${verdict%% *}  $p  ${verdict#* }  (report: $OUT/$p)"
    case "$verdict" in
      PASS*) ;;
      FAIL*) [ "$worst" -lt 1 ] && worst=1 ;;
      *) worst=2 ;;
    esac
    if [ "$RECORD" = 1 ] && [ "${verdict%% *}" != PARTIAL ]; then
      python3 "$HIST" append-eval --from-eval-json="$OUT/$p.json" --pack="$p" --model="$MODEL" \
        ${JUDGE:+--judge-model="$JUDGE"} ${VARIANT:+--variant="$VARIANT"} || worst=1
    fi
    done_packs="$done_packs $p"
    continue
  fi
  if [ "$STAGE_ONLY" = 1 ]; then
    if command -v claude >/dev/null 2>&1; then
      if claude plugin validate "$dir" >"$OUT/$p.validate.log" 2>&1; then echo "STAGED  $p  $dir (claude plugin validate: ok)"
      else echo "STAGED  $p  $dir (claude plugin validate FAILED — $OUT/$p.validate.log)"; worst=1; fi
    else
      echo "STAGED  $p  $dir (claude CLI absent: not validated)"
    fi
    continue
  fi
  # --scaffold: every case's stage-resources.sh copies its resources/ into the empty workspace —
  # context.add_dirs alone grants read access but places nothing where the prompt says the code is
  # (measured 2026-10-19 on 2.1.292: without it the agent reported "directory does not exist").
  set -- "$dir" --trust-plugin --scaffold --json "$OUT/$p.json" --model "$MODEL" --runs "$RUNS" --threshold 0 \
         --max-cost-usd "$COST" --no-publish --output-dir "$OUT/$p"
  [ -n "$JUDGE" ] && set -- "$@" --judge-model "$JUDGE"
  [ -n "$CASE" ] && set -- "$@" --case "$CASE"
  [ -n "$ABL" ] && set -- "$@" --ablation "$ABL"
  [ "$BASH_GRANT" = 1 ] && set -- "$@" --keep-temp --allow-tools Bash   # keep each trace: did the scripts run?
  rc=0; PATH="$RUN_PATH" "$CLAUDE_BIN" plugin eval "$@" >"$OUT/$p.log" 2>&1 || rc=$?
  if [ ! -s "$OUT/$p.json" ]; then
    echo "NOT-RUN $p — claude plugin eval exit $rc, no result (see $OUT/$p.log)"; tail -3 "$OUT/$p.log" | sed 's/^/        /'
    [ "$worst" -lt 2 ] && worst=2; continue
  fi
  verdict=$(python3 - "$OUT/$p.json" "$rc" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2]); a = d.get("aggregates") or {}
delta, score = a.get("meanDelta"), a.get("overallScore")
if d.get("partial"):
    print("PARTIAL %s" % d.get("partialReason")); sys.exit()
tag = "PASS" if (delta is not None and delta > 0 and rc == 0) else "FAIL"
print("%s score=%s delta=%s cases=%s/%s cost=$%s claude=%s" % (tag, score, delta, a.get("casesPassed"), a.get("casesTotal"),
      d.get("costUsd"), d.get("claudeVersion")))
PY
)
  echo "${verdict%% *}  $p  ${verdict#* }  (report: $OUT/$p)"
  case "$verdict" in
    PASS*) ;;
    FAIL*) [ "$worst" -lt 1 ] && worst=1 ;;
    *) worst=2 ;;
  esac
  if [ "$RECORD" = 1 ] && [ "${verdict%% *}" != PARTIAL ]; then
    python3 "$ROOT/benchmarks/history.py" append-eval --from-eval-json="$OUT/$p.json" --pack="$p" --model="$MODEL" \
      ${JUDGE:+--judge-model="$JUDGE"} ${VARIANT:+--variant="$VARIANT"} || worst=1
  fi
done
exit "$worst"
