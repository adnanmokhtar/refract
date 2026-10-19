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
#        [--max-cost-usd=5] [--case=<glob>] [--ablation=with-without|none] [--out=<dir>] [--record]
#   bash scripts/run-pack-evals.sh --pack=<pack>|--all --stage-only [--out=<dir>]   # no model call
#
# --model is required for a run: an unpinned model makes a model rollout look like a pack regression.
# --record appends each complete result to benchmarks/results/history.jsonl (benchmarks/history.py
# append-eval; partial results are refused there) and re-renders benchmarks/RESULTS.md.
#
# Every run is a real model call billed to the account in the environment (ANTHROPIC_API_KEY in CI).
# Exit: 0 every pack Δ > 0 · 1 a pack Δ <= 0, no Δ, or a case below threshold · 2 NOT-RUN / partial.
set -uo pipefail

# Resolve the global-install symlink chain first (lint-setup-contracts.sh Rule 10).
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
PACK="" ALL=0 MODEL="" JUDGE="" RUNS=3 COST=5 CASE="" ABL="" OUT="" RECORD=0 STAGE_ONLY=0
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
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "run-pack-evals: unknown argument $a" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || OUT="${TMPDIR:-/tmp}/refract-pack-evals.$$"
mkdir -p "$OUT/stage/templates" || exit 2

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

[ -d "$OUT/stage/templates/snippets" ] || cp -R "$ROOT/templates/snippets" "$OUT/stage/templates/snippets"

stage() {  # stage <pack> -> prints the staged plugin directory
  local p="$1" src="$ROOT/templates/packs/$1" dst="$OUT/stage/templates/packs/$1" ver
  rm -rf "$dst"; mkdir -p "$dst/.claude-plugin"
  for sub in skills commands agents evals; do
    [ -d "$src/$sub" ] && cp -R "$src/$sub" "$dst/$sub"
  done
  rm -rf "$dst/evals/results"
  ver=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version","0.0.0"))' "$src/_version.json" 2>/dev/null || echo 0.0.0)
  printf '{\n  "name": "refract-%s",\n  "version": "%s",\n  "description": "Refract %s pack, staged for claude plugin eval by scripts/run-pack-evals.sh"\n}\n' \
    "$p" "$ver" "$p" > "$dst/.claude-plugin/plugin.json"
  printf '%s\n' "$dst"
}

if [ "$STAGE_ONLY" = 0 ]; then
  [ -n "$MODEL" ] || { echo "run-pack-evals: --model=<id> is required — pin it so a model rollout is not read as a pack regression" >&2; exit 2; }
  command -v claude >/dev/null 2>&1 || { echo "run-pack-evals: NOT-RUN — the claude CLI is not on PATH" >&2; exit 2; }
fi

worst=0
for p in $packs; do
  dir=$(stage "$p")
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
  rc=0; claude plugin eval "$@" >"$OUT/$p.log" 2>&1 || rc=$?
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
      ${JUDGE:+--judge-model="$JUDGE"} || worst=1
  fi
done
exit "$worst"
