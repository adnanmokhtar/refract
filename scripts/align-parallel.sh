#!/usr/bin/env bash
# align-parallel.sh — drive `/align`-equivalent parallelism on tools that lack native sub-agent
# dispatch. Reads pending rows from the align ledger, runs one tool process per row, and lands
# the results as one commit per row through a single-threaded queue.
#
# Usage:
#   align-parallel.sh --tool=<kimi|qwen|aider|opencode|codex|claude> --parallel=<N> [options]
#   align-parallel.sh --self-test
#
# Options:
#   --ledger=<path>            (default: ai/align/ledger.md)
#   --status=<states>          comma-separated (default: detected,in-progress,halted)
#   --phase=<N>                only rows carrying `phase: N`
#   --ids=<A001,A002>          only these row ids
#   --max-tasks=<N>            cap on candidate rows (ledger order), applied before the overlap check
#   --log-dir=<path>           (default: ai/_parallel-runs/align-<stamp>)
#   --isolation=worktree|serial   (default: worktree; see below)
#   --worktree-root=<dir>      worktree mode: where per-row worktrees go (default: mktemp -d in $TMPDIR)
#   --integrate                worktree mode: cherry-pick accepted rows into the current branch
#   --serialize-overlaps       drop rows whose scope overlaps an earlier row instead of refusing
#   --dry-run                  parse, filter, check scopes, print the plan and prompts; write nothing
#
# Ledger rows are the YAML list form validate-align-artifacts.sh parses (optionally inside a
# ```yaml fence): `- id: A047`, then indented `status:`, `phase:`, and `scope: [a, b]` or a `scope:`
# key followed by `- path` items. A blank line, a fence, or the next `- id:` ends a row.
#
# WHY ISOLATION. Two concurrent `git commit`s on one index race: one worker's `git add` lands in
# the other's commit, and "update the ledger row with a file lock" written into a prompt is not a
# lock — nothing enforces it. So scopes are checked before dispatch (two rows whose scope entries
# are equal, or one a directory prefix of the other, are refused with an OVERLAP line; a row with
# no scope is refused because no scope means no lock), and commits are never made concurrently on
# one index:
#
#   worktree  each row gets `git worktree add -b align-par/<id>-<stamp> <root>/<id> HEAD`; the tool
#             runs there and makes exactly ONE commit (fix + ledger row update). After all workers
#             end, a serial integration queue, in ledger order, accepts a branch only if it has
#             exactly one commit over the base and every file it touches is in the row's scope, the
#             ledger, or <ledger-dir>/halts/<id>.md; anything else is `rejected (<reason>)`.
#             Without --integrate it prints the `git cherry-pick <sha>` commands in order and the
#             cleanup commands; with --integrate it cherry-picks them, and on a conflict aborts
#             that pick and stops. Integrated rows have their worktree and branch removed.
#   serial    workers share the working tree (it must be clean) and are told NOT to commit and NOT
#             to edit the ledger; each writes <log-dir>/records/<id>.yaml. The script's commit queue
#             then, in ledger order, checks every changed path is inside some dispatched row's
#             scope (otherwise nothing is committed, exit 1), stages the row's paths, applies the
#             record's keys to the row's ledger block, and commits `align/<phase>/<id>: <desc>`.
#             The queue is the only writer of the ledger. Note: in this mode each worker's VERIFY
#             step sees the other workers' in-flight edits.
#
# A row with no `phase:` commits as `align/unplanned/<id>: ...`.
# Requires: git, python3 (serial mode), bash 3.2+.
#
# Exit codes:
#   0 — every dispatched row ran and was integrated / committed (or is ready to cherry-pick)
#   1 — a worker failed, a branch was rejected, a cherry-pick conflicted, or a path escaped scope
#   2 — usage error or refusal (overlapping or empty scopes, dirty tree, missing ledger)

set -euo pipefail

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo, so an unresolved
# BASH_SOURCE puts this dir at ~/.claude/scripts and every sibling asset below resolves only
# if it too was linked (see CONTRIBUTING § "Scripts run from two places").
# Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPT_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd

SELF="$SCRIPT_DIR/align-parallel.sh"
FS=$'\036'   # field separator in parsed rows
SS=$'\037'   # separator between scope entries

TOOL=""
PARALLEL=""
LEDGER="ai/align/ledger.md"
STATES="detected,in-progress,halted"
PHASE=""
IDS=""
MAX_TASKS=""
LOG_DIR=""
ISOLATION="worktree"
WT_ROOT=""
INTEGRATE=0
SERIALIZE=0
DRY_RUN=0
SELF_TEST=0

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$SELF"
  exit 2
}

for arg in "$@"; do
  case "$arg" in
    --tool=*)            TOOL="${arg#*=}" ;;
    --parallel=*)        PARALLEL="${arg#*=}" ;;
    --ledger=*)          LEDGER="${arg#*=}" ;;
    --status=*)          STATES="${arg#*=}" ;;
    --phase=*)           PHASE="${arg#*=}" ;;
    --ids=*)             IDS="${arg#*=}" ;;
    --max-tasks=*)       MAX_TASKS="${arg#*=}" ;;
    --log-dir=*)         LOG_DIR="${arg#*=}" ;;
    --isolation=*)       ISOLATION="${arg#*=}" ;;
    --worktree-root=*)   WT_ROOT="${arg#*=}" ;;
    --integrate)         INTEGRATE=1 ;;
    --serialize-overlaps) SERIALIZE=1 ;;
    --dry-run)           DRY_RUN=1 ;;
    --self-test)         SELF_TEST=1 ;;
    -h|--help)           usage ;;
    *) echo "ERR: unknown arg: $arg" >&2; usage ;;
  esac
done

# ---------------------------------------------------------------------------------------------
# apply_record <ledger> <id> <record.yaml> — merge a record's top-level `key: value` lines (and
# their indented continuation lines) into the `- id: <id>` block: replace an existing key line at
# the row's key indent, else append before the block's end. `id` and `description` are not copied.
apply_record() {
  python3 -I - "$1" "$2" "$3" <<'PY'
import re, sys
ledger, rid, rec = sys.argv[1:4]
items = []
with open(rec, encoding="utf-8") as fh:
    for raw in fh.read().splitlines():
        if not raw.strip():
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):(.*)$", raw)
        if m:
            items.append((m.group(1), m.group(2).strip(), []))
        elif raw[:1] in (" ", "\t") and items:
            items[-1][2].append(raw.rstrip())
        elif raw.lstrip().startswith("#"):
            continue
        else:
            sys.exit("record %s: unparseable line: %r" % (rec, raw))
with open(ledger, encoding="utf-8") as fh:
    lines = fh.read().split("\n")
idre = re.compile(r"^\s*-\s+id:\s*" + re.escape(rid) + r"\s*(#.*)?$")
starts = [i for i, l in enumerate(lines) if idre.match(l)]
if len(starts) != 1:
    sys.exit("ledger %s: %d rows with id %s (need exactly 1)" % (ledger, len(starts), rid))
s = starts[0]
def indent(l):
    return len(l) - len(l.lstrip())
def is_end(l):
    return (not l.strip()) or l.lstrip().startswith("```") or re.match(r"^\s*-\s+id:", l)
e = s + 1
while e < len(lines) and not is_end(lines[e]):
    e += 1
ind = indent(lines[s + 1]) if e > s + 1 else indent(lines[s]) + 2
pad = " " * ind
for key, val, cont in items:
    if key in ("id", "description"):
        continue
    new = [pad + key + ":" + (" " + val if val else "")] + [pad + c for c in cont]
    found = None
    for i in range(s + 1, e):
        if indent(lines[i]) == ind and re.match(re.escape(key) + r":(\s|$)", lines[i].lstrip()):
            found = i
            break
    if found is None:
        lines[e:e] = new
        e += len(new)
    else:
        j = found + 1
        while j < e and (indent(lines[j]) > ind or (indent(lines[j]) == ind and lines[j].lstrip().startswith("- "))):
            j += 1
        lines[found:j] = new
        e += len(new) - (j - found)
with open(ledger, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines))
PY
}

# ---------------------------------------------------------------------------------------------
# parse_ledger <file> — one line per row: id FS status FS phase FS scope(SS-joined).
parse_ledger() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unq(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
      return s
    }
    function nocomment(s) { sub(/[ \t]+#.*$/, "", s); return s }
    function addsc(e) { e = unq(e); if (e != "") sc = (sc == "" ? e : sc "\037" e) }
    function emit() {
      if (id != "") print id "\036" st "\036" ph "\036" sc
      id = ""; st = ""; ph = ""; sc = ""; insc = 0; kind = -1
    }
    BEGIN { kind = -1 }
    /^[ \t]*```/ { emit(); next }
    /^[ \t]*-[ \t]+id:[ \t]*[A-Za-z0-9]/ {
      emit(); s = $0; sub(/^[ \t]*-[ \t]+id:[ \t]*/, "", s); id = unq(nocomment(s)); next
    }
    id == "" { next }
    /^[ \t]*$/ { emit(); next }
    {
      line = $0; match(line, /^[ \t]*/); ind = RLENGTH
      if (insc) {
        if (ind >= scind && line ~ /^[ \t]*-[ \t]/) {
          s = line; sub(/^[ \t]*-[ \t]*/, "", s); addsc(nocomment(s)); next
        }
        insc = 0
      }
      if (kind < 0) kind = ind
      if (ind != kind) next
      s = line; sub(/^[ \t]+/, "", s)
      if (s ~ /^status:/) { sub(/^status:/, "", s); st = unq(nocomment(s)); next }
      if (s ~ /^phase:/)  { sub(/^phase:/, "", s);  ph = unq(nocomment(s)); next }
      if (s ~ /^scope:/) {
        sub(/^scope:/, "", s); s = trim(nocomment(s))
        if (s == "") { insc = 1; scind = ind; next }
        if (s ~ /^\[/) {
          sub(/^\[/, "", s); sub(/\][ \t]*$/, "", s)
          n = split(s, parts, ",")
          for (k = 1; k <= n; k++) addsc(parts[k])
        } else addsc(s)
      }
    }
    END { emit() }
  ' "$1"
}

# in_scope <path> <SS-joined normalized scope> — dir entries end in "/".
in_scope() {
  local p="$1" e
  local -a ents
  IFS="$SS" read -r -a ents <<< "$2"
  for e in ${ents[@]+"${ents[@]}"}; do
    case "$e" in
      */) case "$p" in "$e"*) return 0 ;; esac ;;
      *)  [ "$p" = "$e" ] && return 0 ;;
    esac
  done
  return 1
}

row_get() {  # row_get <id> <field 1..4> — from DISPATCH_ROWS
  printf '%s\n' "$DISPATCH_ROWS" | awk -F "$FS" -v id="$1" -v f="$2" '$1 == id { print $f; exit }'
}

# ---------------------------------------------------------------------------------------------
# Self-test: everything below runs in throwaway repos under $TMPDIR.
run_self_test() {
  local ST pass=0 fail=0 failures="" out rc base n f ok
  ST="$(mktemp -d "${TMPDIR:-/tmp}/align-par-selftest.XXXXXX")"
  ST="$(cd -P "$ST" && pwd)"
  # shellcheck disable=SC2064  # expand $ST now: the trap runs after this function returns
  trap "rm -rf '$ST'" EXIT
  mkdir -p "$ST/home"
  export HOME="$ST/home" GIT_CONFIG_NOSYSTEM=1 \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

  check() {  # check <name> <0|1>
    if [ "$2" -eq 1 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); failures="$failures  FAIL $1"$'\n'; fi
  }
  mkrepo() {  # mkrepo <dir>
    mkdir -p "$1/src/sub" "$1/ai/align"
    git -C "$1" init -q -b main
    printf 'a\n' > "$1/src/a.txt"; printf 'b\n' > "$1/src/b.txt"; printf 'c\n' > "$1/src/sub/c.txt"
    printf 'o\n' > "$1/outside.txt"
    cat > "$1/ai/align/ledger.md" <<'LEDGER'
# Align ledger

```yaml
- id: A001
  class: drift
  scope: [src/a.txt]   # the one file
  evidence:
    - src/a.txt:1
  tier: trivial
  status: detected
  phase: 1

- id: A002
  class: drift
  scope:
    - src/b.txt
  evidence:
    - src/b.txt:1
  tier: trivial
  status: in-progress
  phase: 1

- id: A003
  class: drift
  scope: [src/a.txt]
  tier: trivial
  status: halted
  phase: 2

- id: A004
  class: drift
  scope: []
  tier: trivial
  status: detected
  phase: 3

- id: A005
  class: drift
  scope: [src]
  tier: trivial
  status: detected
  phase: 4

- id: A006
  class: drift
  scope: [src/sub/c.txt]
  tier: trivial
  status: verified
  phase: 1
```
LEDGER
    git -C "$1" add -A && git -C "$1" -c user.name=t -c user.email=t@t commit -q -m init
  }
  strun() {  # strun <dir> [env assignments via env] args... → out, rc
    local d="$1"; shift
    if out="$(cd "$d" && ALIGN_PARALLEL_SELFTEST_TOOL=1 bash "$SELF" "$@" 2>&1)"; then rc=0; else rc=$?; fi
  }
  has() { case "$out" in *"$1"*) echo 1 ;; *) echo 0 ;; esac; }
  block_has() {  # block_has <ledger> <id> <line> → 1/0
    awk -v id="$2" -v want="$3" '
      $0 ~ "^- id: " id "$" { inb = 1; next }
      inb && /^[ \t]*$/ { inb = 0 }
      inb && $0 == want { hit = 1 }
      END { print hit ? 1 : 0 }' "$1"
  }

  # (a) the real `- id:` form parses; filters work
  mkrepo "$ST/r1"
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --ids=A001,A002
  check "(a) parse: 6 rows, 2 picked by --ids" "$(( rc == 0 && $(has '(6 rows parsed)') && $(has 'picked     : 2') ))"
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --phase=2
  check "(a) --phase=2 picks only A003" "$(( rc == 0 && $(has 'picked     : 1') && $(has 'dispatch   : A003') ))"
  # (b) shared scope file → OVERLAP, exit 2; --serialize-overlaps defers one
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --ids=A001,A003
  check "(b) overlap refused" "$(( rc == 2 && $(has 'OVERLAP A001 A003: src/a.txt') ))"
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --ids=A001,A003 --serialize-overlaps
  check "(b) --serialize-overlaps defers A003" "$(( rc == 0 && $(has 'A003 deferred (overlap with A001)') && $(has 'dispatch   : A001') ))"
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --ids=A002,A005
  check "(b) directory scope overlaps a file in it" "$(( rc == 2 && $(has 'OVERLAP A002 A005: src/ contains src/b.txt') ))"
  # (c) empty scope refused
  strun "$ST/r1" --tool=selftest --parallel=2 --dry-run --ids=A004
  check "(c) empty scope refused" "$(( rc == 2 && $(has 'A004: empty scope') ))"

  # (d) worktree: two disjoint rows → two branches with one commit each; cherry-pick commands
  base="$(git -C "$ST/r1" rev-parse HEAD)"
  strun "$ST/r1" --tool=selftest --parallel=2 --ids=A001,A002 --worktree-root="$ST/wt1" --log-dir="$ST/log1"
  ok=1
  for f in A001 A002; do
    n="$(git -C "$ST/r1" for-each-ref --format='%(refname)' "refs/heads/align-par/$f-*" | awk 'END { print NR }')"
    [ "$n" -eq 1 ] || ok=0
    n="$(git -C "$ST/r1" rev-list --count "$base..$(git -C "$ST/r1" for-each-ref --format='%(refname)' "refs/heads/align-par/$f-*")" 2>/dev/null || echo 0)"
    [ "$n" -eq 1 ] || ok=0
  done
  n="$(printf '%s\n' "$out" | grep -c '^  git cherry-pick ' || true)"
  check "(d) worktree: 2 branches x 1 commit, 2 cherry-pick lines, HEAD unmoved" \
    "$(( rc == 0 && ok == 1 && n == 2 && $(has 'git worktree remove') ))"
  check "(d) HEAD unmoved without --integrate" "$([ "$(git -C "$ST/r1" rev-parse HEAD)" = "$base" ] && echo 1 || echo 0)"
  # (d) --integrate lands both, in ledger order
  mkrepo "$ST/r2"
  base="$(git -C "$ST/r2" rev-parse HEAD)"
  strun "$ST/r2" --tool=selftest --parallel=2 --ids=A001,A002 --worktree-root="$ST/wt2" --log-dir="$ST/log2" --integrate
  n="$(git -C "$ST/r2" rev-list --count "$base..HEAD")"
  check "(d) --integrate: 2 commits on main in ledger order, ledger rows fixed" "$(( rc == 0 && n == 2 \
    && $(git -C "$ST/r2" log -1 --format=%s HEAD~1 | grep -c '^align/1/A001: ') \
    && $(git -C "$ST/r2" log -1 --format=%s HEAD | grep -c '^align/1/A002: ') \
    && $(block_has "$ST/r2/ai/align/ledger.md" A001 '  status: fixed') \
    && $(block_has "$ST/r2/ai/align/ledger.md" A002 '  status: fixed') ))"
  n="$(git -C "$ST/r2" for-each-ref 'refs/heads/align-par/' | awk 'END { print NR }')"
  check "(d) integrated branches removed" "$(( n == 0 ))"

  # (e) a worker branch that touched a file outside its scope is rejected
  mkrepo "$ST/r3"
  if out="$(cd "$ST/r3" && SELFTEST_ESCAPE=A002 ALIGN_PARALLEL_SELFTEST_TOOL=1 bash "$SELF" --tool=selftest \
        --parallel=2 --ids=A001,A002 --worktree-root="$ST/wt3" --log-dir="$ST/log3" 2>&1)"; then rc=0; else rc=$?; fi
  check "(e) out-of-scope branch rejected, the other kept" \
    "$(( rc == 1 && $(has 'A002 rejected (outside scope: outside.txt)') && $(has 'A001 accepted') ))"

  # (f) serial: two disjoint rows → two commits, each touching only its scope + the ledger
  mkrepo "$ST/r4"
  base="$(git -C "$ST/r4" rev-parse HEAD)"
  strun "$ST/r4" --tool=selftest --parallel=2 --ids=A001,A002 --isolation=serial
  n="$(git -C "$ST/r4" rev-list --count "$base..HEAD")"
  ok=1
  [ "$(git -C "$ST/r4" diff-tree --no-commit-id -r --name-only HEAD~1 | sort | tr '\n' ' ')" = "ai/align/ledger.md src/a.txt " ] || ok=0
  [ "$(git -C "$ST/r4" diff-tree --no-commit-id -r --name-only HEAD | sort | tr '\n' ' ')" = "ai/align/ledger.md src/b.txt " ] || ok=0
  [ "$(git -C "$ST/r4" log -1 --format=%s HEAD~1)" = "align/1/A001: selftest fix A001" ] || ok=0
  check "(f) serial: 2 commits, scope + ledger only, record status applied" "$(( rc == 0 && n == 2 && ok == 1 \
    && $(block_has "$ST/r4/ai/align/ledger.md" A001 '  status: fixed') \
    && $(block_has "$ST/r4/ai/align/ledger.md" A002 '  status: fixed') \
    && $(block_has "$ST/r4/ai/align/ledger.md" A002 '  gaps_closed: 1') ))"
  # (g) serial: a path outside every scope refuses the whole queue
  mkrepo "$ST/r5"
  base="$(git -C "$ST/r5" rev-parse HEAD)"
  if out="$(cd "$ST/r5" && SELFTEST_ESCAPE=A002 ALIGN_PARALLEL_SELFTEST_TOOL=1 bash "$SELF" --tool=selftest \
        --parallel=2 --ids=A001,A002 --isolation=serial 2>&1)"; then rc=0; else rc=$?; fi
  check "(g) serial: out-of-scope path refuses the queue, nothing committed" \
    "$(( rc == 1 && $(has '  outside.txt') && $(git -C "$ST/r5" rev-list --count "$base..HEAD") == 0 ))"

  local total=$((pass + fail))
  if [ "$fail" -eq 0 ]; then
    echo "align-parallel.sh --self-test: $pass/$total OK"
    exit 0
  fi
  printf '%s' "$failures"
  echo "align-parallel.sh --self-test: $pass/$total OK ($fail failed)"
  exit 1
}

[ "$SELF_TEST" -eq 1 ] && run_self_test

# ---------------------------------------------------------------------------------------------
# shellcheck source=./_parallel-tool-config.sh
source "$SCRIPT_DIR/_parallel-tool-config.sh"

if [ "${ALIGN_PARALLEL_SELFTEST_TOOL:-}" = 1 ]; then
  # Test-only tool, defined only when --self-test drives this script. Deterministic: append a line
  # to the row's first scope file; worktree → update the ledger row and commit once; serial →
  # write the record. SELFTEST_ESCAPE=<id> makes that row also edit outside.txt.
  # shellcheck disable=SC2329  # invoked indirectly as "tool_${TOOL}_invoke"
  tool_selftest_invoke() {
    local id="$ALIGN_PAR_ID" f="${ALIGN_PAR_SCOPE%%"$SS"*}"
    printf 'aligned by %s\n' "$id" >> "$f"
    [ "${SELFTEST_ESCAPE:-}" = "$id" ] && printf 'escape\n' >> outside.txt
    if [ "$ALIGN_PAR_MODE" = worktree ]; then
      printf 'status: fixed\ngaps_closed: 1\n' > "$ALIGN_PAR_LOG_DIR/$id.selftest.yaml"
      apply_record "$ALIGN_PAR_LEDGER" "$id" "$ALIGN_PAR_LOG_DIR/$id.selftest.yaml"
      git add -A -- . && git -c user.name=t -c user.email=t@t commit -q -m "align/$ALIGN_PAR_PHASE/$id: selftest"
    else
      printf 'status: fixed\ngaps_closed: 1\nproof_class: EQ\ndescription: selftest fix %s\n' "$id" > "$ALIGN_PAR_RECORD"
    fi
  }
fi

if [ -z "$TOOL" ] || [ -z "$PARALLEL" ]; then usage; fi
case "$PARALLEL" in ''|*[!0-9]*|0*) echo "ERR: --parallel must be a positive integer; got '$PARALLEL'" >&2; exit 2 ;; esac
case "$MAX_TASKS" in '') ;; *[!0-9]*|0*) echo "ERR: --max-tasks must be a positive integer" >&2; exit 2 ;; esac
case "$ISOLATION" in worktree|serial) ;; *) echo "ERR: --isolation must be worktree or serial" >&2; exit 2 ;; esac
if [ "$INTEGRATE" -eq 1 ] && [ "$ISOLATION" != worktree ]; then
  echo "ERR: --integrate applies to --isolation=worktree only (serial mode always commits)" >&2; exit 2
fi
if ! tool_is_supported "$TOOL"; then
  echo "ERR: tool '$TOOL' is not in _parallel-tool-config.sh; add tool_${TOOL}_invoke" >&2; exit 2
fi
if [ ! -f "$LEDGER" ]; then
  echo "ERR: ledger not found: $LEDGER" >&2
  echo "     run /align-scan first to build it." >&2
  exit 2
fi

ORIG_PWD="$(pwd -P)"
LEDGER_ABS="$(cd -P "$(dirname "$LEDGER")" && pwd)/$(basename "$LEDGER")"
if ! REPO_TOP="$(git -C "$(dirname "$LEDGER_ABS")" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "ERR: the ledger is not inside a git repository: $LEDGER_ABS" >&2; exit 2
fi
REPO_TOP="$(cd -P "$REPO_TOP" && pwd)"
LEDGER_REL="${LEDGER_ABS#"$REPO_TOP"/}"
HALTS_DIR="$(dirname "$LEDGER_REL")/halts"
cd "$REPO_TOP"

LOG_DIR="${LOG_DIR:-ai/_parallel-runs/align-$(date +%Y%m%d-%H%M%S)}"
case "$LOG_DIR" in /*) ;; *) LOG_DIR="$ORIG_PWD/$LOG_DIR" ;; esac
LOG_REL=""
case "$LOG_DIR" in "$REPO_TOP"/*) LOG_REL="${LOG_DIR#"$REPO_TOP"/}" ;; esac

# ---- parse, filter, cap ----
ROWS_ALL="$(parse_ledger "$LEDGER_ABS")"
N_ALL="$(printf '%s' "$ROWS_ALL" | awk 'END { print NR }')"
CAND=""
n_cand=0
while IFS="$FS" read -r id st ph sc; do
  [ -n "$id" ] || continue
  case ",$STATES," in *",$st,"*) ;; *) continue ;; esac
  [ -z "$PHASE" ] || [ "$ph" = "$PHASE" ] || continue
  [ -z "$IDS" ] || case ",$IDS," in *",$id,"*) ;; *) continue ;; esac
  [ -z "$MAX_TASKS" ] || [ "$n_cand" -lt "$MAX_TASKS" ] || break
  # normalize scope: strip ./, mark directories with a trailing /
  norm=""
  IFS="$SS" read -r -a ents <<< "$sc"
  for e in ${ents[@]+"${ents[@]}"}; do
    e="${e#./}"
    case "$e" in */) ;; *) [ -d "$REPO_TOP/$e" ] && e="$e/" ;; esac
    norm="${norm:+$norm$SS}$e"
  done
  CAND="${CAND:+$CAND$'\n'}$id$FS$st$FS$ph$FS$norm"
  n_cand=$((n_cand + 1))
done <<< "$ROWS_ALL"

if [ -n "$IDS" ]; then
  missing=""
  for want in $(printf '%s' "$IDS" | tr ',' ' '); do
    printf '%s\n' "$ROWS_ALL" | awk -F "$FS" -v id="$want" '$1 == id { f = 1 } END { exit !f }' || missing="$missing $want"
  done
  [ -z "$missing" ] || echo "NOTE: --ids not found in $LEDGER_REL:$missing"
fi

if [ "$n_cand" -eq 0 ]; then
  echo "INFO: no rows in $LEDGER_REL ($N_ALL rows parsed) match status ($STATES)${PHASE:+, phase $PHASE}${IDS:+, ids $IDS}. Nothing to do."
  [ "$N_ALL" -gt 0 ] || echo "WARN: 0 rows parsed — rows must be '- id: <id>' YAML list items (see align-ledger.md)." >&2
  exit 0
fi

# ---- scope lock: empty scopes and overlaps ----
empty="$(printf '%s\n' "$CAND" | awk -F "$FS" '$4 == "" { print $1 }')"
if [ -n "$empty" ]; then
  for id in $empty; do echo "REFUSED $id: empty scope — no scope means no lock; fill scope: before dispatching it"; done
  exit 2
fi

OVERLAP_OUT="$(printf '%s\n' "$CAND" | awk -F "$FS" -v serialize="$SERIALIZE" '
  function ov(a, b) {
    if (a == b) return a
    if (a ~ /\/$/ && index(b, a) == 1) return a " contains " b
    if (b ~ /\/$/ && index(a, b) == 1) return b " contains " a
    return ""
  }
  function rows_ov(i, j,    x, y, r) {
    for (x = 1; x <= nsc[i]; x++) for (y = 1; y <= nsc[j]; y++) { r = ov(sc[i, x], sc[j, y]); if (r != "") return r }
    return ""
  }
  {
    n++; id[n] = $1; nsc[n] = split($4, tmp, "\037")
    for (k = 1; k <= nsc[n]; k++) sc[n, k] = tmp[k]
  }
  END {
    if (serialize == 1) {
      for (i = 1; i <= n; i++) {
        hit = ""
        for (j = 1; j <= nk && hit == ""; j++) if (rows_ov(kept[j], i) != "") hit = id[kept[j]]
        if (hit == "") { kept[++nk] = i; print "KEEP " id[i] } else print "DEFER " id[i] " " hit
      }
    } else {
      for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) { r = rows_ov(i, j); if (r != "") print "OVERLAP " id[i] " " id[j] ": " r }
    }
  }')"

if [ "$SERIALIZE" -eq 0 ] && [ -n "$OVERLAP_OUT" ]; then
  printf '%s\n' "$OVERLAP_OUT"
  echo "REFUSED: overlapping scopes — two workers would edit the same file. Narrow the rows, run them"
  echo "         in separate runs (--ids=), or pass --serialize-overlaps to dispatch a disjoint subset."
  exit 2
fi

DISPATCH=""; DEFERRED=""
if [ "$SERIALIZE" -eq 1 ]; then
  DISPATCH="$(printf '%s\n' "$OVERLAP_OUT" | awk '$1 == "KEEP" { printf "%s%s", sep, $2; sep = " " }')"
  DEFERRED="$(printf '%s\n' "$OVERLAP_OUT" | awk '$1 == "DEFER" { print "  " $2 " deferred (overlap with " $3 ")" }')"
else
  DISPATCH="$(printf '%s\n' "$CAND" | awk -F "$FS" '{ printf "%s%s", sep, $1; sep = " " }')"
fi
DISPATCH_ROWS="$CAND"
N_DISPATCH="$(echo "$DISPATCH" | wc -w | tr -d ' ')"

# ---- prompts ----
build_prompt() {  # build_prompt <id>
  local id="$1" ph scope_h
  ph="$(row_get "$id" 3)"; ph="${ph:-unplanned}"
  scope_h="$(row_get "$id" 4 | tr "$SS" ',' | sed 's/,/, /g')"
  local common="Read align-discipline.md and align-ledger.md. Run the find-and-align skill on row $id of $LEDGER_REL ONLY: ROUTE (an owner-class row becomes status routed with its fix command, no edit), DETECT (re-run the row's detector_cmd; its oracle quote must still resolve), DECIDE (proof_class EQ, VC or FN; a closure verb from the align-discipline.md vocabulary), FIX (only the matched expression; tests, snapshots and baselines are read-only), VERIFY (align-sweep-gate.py ladder, then lint+typecheck+scoped tests; a VC row stops at pending-approval, never self-approved), RECORD (gaps_in must equal gaps_closed). Edit ONLY these scope files: $scope_h (and $HALTS_DIR/$id.md if the row halts). Do not touch any other ledger row. Halt only on genuine blockers (cross-repo dependency, security regression, ambiguous fix without ADR). Net-lines on structural classes must be <= 0; functional adds must cite an idiom the oracle names."
  if [ "$ISOLATION" = worktree ]; then
    printf '%s' "You are in a dedicated git worktree (branch align-par/$id-$RUNSTAMP); stay in it. $common Make exactly ONE commit in this worktree containing the fix AND the update of ledger row $id, subject 'align/$ph/$id: <description>'. Do not push, merge, rebase, or switch branches. A branch with more or fewer than one commit, or touching any file outside the scope, the ledger and $HALTS_DIR/$id.md, is rejected."
  else
    printf '%s' "You share this working tree with other workers. $common Do NOT run git add, commit, stash, checkout, reset or restore, and do NOT edit $LEDGER_REL — the driver commits for you. When done, write your RECORD as top-level 'key: value' YAML lines to $LOG_DIR/records/$id.yaml: status, gaps_closed, proof_class, proof, halt_reason (as applicable), plus 'description: <one-line commit description>'."
  fi
}

RUNSTAMP="$(date +%Y%m%d%H%M%S)-$$"
echo "Align parallel run:"
echo "  tool       : $TOOL"
if [ "$INTEGRATE" -eq 1 ]; then echo "  isolation  : $ISOLATION (--integrate)"; else echo "  isolation  : $ISOLATION"; fi
echo "  parallel   : $PARALLEL"
echo "  ledger     : $LEDGER_REL ($N_ALL rows parsed)"
echo "  picked     : $N_DISPATCH rows (status in $STATES${PHASE:+; phase $PHASE}${IDS:+; ids $IDS})"
echo "  dispatch   : $DISPATCH"
[ -z "$DEFERRED" ] || printf '%s\n' "$DEFERRED"
echo "  log dir    : $LOG_DIR"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run — first 5 prompts (nothing written, no worktrees created):"
  k=0
  for id in $DISPATCH; do
    k=$((k + 1)); [ "$k" -le 5 ] || break
    [ "$ISOLATION" = worktree ] && echo "  [$id] git worktree add -b align-par/$id-$RUNSTAMP <worktree-root>/$id HEAD"
    echo "  [$id] $(build_prompt "$id")"
  done
  exit 0
fi

# ---- preconditions ----
dirty_paths() {  # changed + untracked paths, excluding the log dir
  git status --porcelain -z --no-renames --untracked-files=all | while IFS= read -r -d '' ent; do
    p="${ent:3}"
    if [ -n "$LOG_REL" ]; then case "$p" in "$LOG_REL"/*) continue ;; esac; fi
    printf '%s\n' "$p"
  done
}
if [ "$ISOLATION" = worktree ]; then
  if ! git ls-files --error-unmatch -- "$LEDGER_REL" >/dev/null 2>&1 || ! git diff --quiet HEAD -- "$LEDGER_REL"; then
    echo "REFUSED: $LEDGER_REL is untracked or has uncommitted changes; worktrees branch from HEAD, so commit it first." >&2
    exit 2
  fi
  if [ "$INTEGRATE" -eq 1 ] && { ! git diff --quiet || ! git diff --cached --quiet; }; then
    echo "REFUSED: --integrate needs a clean index and working tree (tracked files) to cherry-pick into." >&2
    exit 2
  fi
else
  pre="$(dirty_paths)"
  if [ -n "$pre" ]; then
    echo "REFUSED: serial mode needs a clean working tree (changes would be unattributable). Dirty:" >&2
    printf '%s\n' "$pre" | head -20 | sed 's/^/  /' >&2
    exit 2
  fi
fi

mkdir -p "$LOG_DIR"
LOG_DIR="$(cd -P "$LOG_DIR" && pwd)"
case "$LOG_DIR" in "$REPO_TOP"/*) LOG_REL="${LOG_DIR#"$REPO_TOP"/}" ;; esac
[ "$ISOLATION" = serial ] && mkdir -p "$LOG_DIR/records"
BASE="$(git rev-parse HEAD)"

if [ "$ISOLATION" = worktree ]; then
  WT_ROOT="${WT_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/align-par.XXXXXX")}"
  mkdir -p "$WT_ROOT"
  WT_ROOT="$(cd -P "$WT_ROOT" && pwd)"
  for id in $DISPATCH; do
    if ! git worktree add -q -b "align-par/$id-$RUNSTAMP" "$WT_ROOT/$id" HEAD >>"$LOG_DIR/$id.log" 2>&1; then
      echo "ERR: git worktree add failed for $id (see $LOG_DIR/$id.log)" >&2; exit 1
    fi
  done
fi

# ---- fan-out: bash job slots (bash 3.2: no wait -n; each worker drops <id>.rc when done) ----
run_worker() {  # run_worker <id>
  local id="$1" wd rc prompt
  if [ "$ISOLATION" = worktree ]; then wd="$WT_ROOT/$id"; else wd="$REPO_TOP"; fi
  prompt="$(build_prompt "$id")"
  export ALIGN_PAR_ID="$id" ALIGN_PAR_MODE="$ISOLATION" ALIGN_PAR_LEDGER="$LEDGER_REL" \
    ALIGN_PAR_LOG_DIR="$LOG_DIR" ALIGN_PAR_RECORD="$LOG_DIR/records/$id.yaml"
  ALIGN_PAR_SCOPE="$(row_get "$id" 4)"; ALIGN_PAR_PHASE="$(row_get "$id" 3)"
  ALIGN_PAR_PHASE="${ALIGN_PAR_PHASE:-unplanned}"
  export ALIGN_PAR_SCOPE ALIGN_PAR_PHASE
  echo "[$(date +%H:%M:%S)] START $id"
  if (cd "$wd" && "tool_${TOOL}_invoke" "$prompt") >>"$LOG_DIR/$id.log" 2>&1; then rc=0; else rc=$?; fi
  echo "[$(date +%H:%M:%S)] $([ "$rc" -eq 0 ] && echo 'OK   ' || echo 'FAIL ') $id (exit $rc, $LOG_DIR/$id.log)"
  echo "$rc" > "$LOG_DIR/$id.rc"
}
started=0
for id in $DISPATCH; do
  while [ $((started - $(find "$LOG_DIR" -maxdepth 1 -name '*.rc' | awk 'END { print NR }'))) -ge "$PARALLEL" ]; do
    sleep 0.2
  done
  run_worker "$id" &
  started=$((started + 1))
done
wait

STATUS=0
rc_of() { cat "$LOG_DIR/$1.rc" 2>/dev/null || echo 99; }

# ---- worktree: serial integration queue ----
if [ "$ISOLATION" = worktree ]; then
  echo
  echo "Integration queue (ledger order, base $BASE):"
  ACCEPTED=""
  for id in $DISPATCH; do
    br="align-par/$id-$RUNSTAMP"; scope="$(row_get "$id" 4)"; rc="$(rc_of "$id")"
    if [ "$rc" != 0 ]; then echo "  $id rejected (worker exit $rc)"; STATUS=1; continue; fi
    n="$(git rev-list --count "$BASE..$br")"
    if [ "$n" != 1 ]; then echo "  $id rejected ($n commits over base; exactly 1 required)"; STATUS=1; continue; fi
    sha="$(git rev-parse "$br")"
    bad=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ "$f" = "$LEDGER_REL" ] || [ "$f" = "$HALTS_DIR/$id.md" ] || in_scope "$f" "$scope" || bad="${bad:+$bad }$f"
    done <<< "$(git -c core.quotePath=false diff-tree --no-commit-id -r --name-only --no-renames "$sha")"
    if [ -n "$bad" ]; then echo "  $id rejected (outside scope: $bad)"; STATUS=1; continue; fi
    echo "  $id accepted $sha"
    ACCEPTED="${ACCEPTED:+$ACCEPTED }$id:$sha"
  done
  echo
  if [ "$INTEGRATE" -eq 0 ]; then
    if [ -n "$ACCEPTED" ]; then
      echo "Paste to integrate, in this order:"
      for a in $ACCEPTED; do echo "  git cherry-pick ${a#*:}"; done
    fi
    echo "Cleanup when done:"
    for id in $DISPATCH; do echo "  git worktree remove --force '$WT_ROOT/$id' && git branch -D align-par/$id-$RUNSTAMP"; done
  else
    left=""
    for a in $ACCEPTED; do
      id="${a%%:*}"; sha="${a#*:}"
      if [ -n "$left" ]; then left="$left $a"; continue; fi
      if git cherry-pick "$sha" >>"$LOG_DIR/$id.log" 2>&1; then
        echo "  integrated $id -> $(git rev-parse --short HEAD)"
        if git worktree remove "$WT_ROOT/$id" >>"$LOG_DIR/$id.log" 2>&1; then
          git branch -q -D "align-par/$id-$RUNSTAMP" >>"$LOG_DIR/$id.log" 2>&1 || true
        else
          echo "    (worktree kept: $WT_ROOT/$id has untracked files)"
        fi
      else
        git cherry-pick --abort >/dev/null 2>&1 || true
        echo "  CONFLICT $id: cherry-pick of $sha aborted; the queue stopped here."
        left="$a"; STATUS=1
      fi
    done
    if [ -n "$left" ]; then
      echo "Not integrated (resolve, then run in order):"
      for a in $left; do echo "  git cherry-pick ${a#*:}   # ${a%%:*}"; done
    fi
    for id in $DISPATCH; do
      if [ -d "$WT_ROOT/$id" ]; then echo "  cleanup: git worktree remove --force '$WT_ROOT/$id' && git branch -D align-par/$id-$RUNSTAMP"; fi
    done
  fi
  echo
  echo "Logs: $LOG_DIR/"
  exit "$STATUS"
fi

# ---- serial: single-threaded commit queue ----
echo
echo "Commit queue (ledger order):"
CHANGED="$(dirty_paths)"
outside=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  owned=0
  for id in $DISPATCH; do
    if [ "$p" = "$HALTS_DIR/$id.md" ] || in_scope "$p" "$(row_get "$id" 4)"; then owned=1; break; fi
  done
  [ "$owned" -eq 1 ] || outside="$outside  $p"$'\n'
done <<< "$CHANGED"
if [ -n "$outside" ]; then
  echo "REFUSED: paths changed outside every dispatched row's scope — nothing committed:"
  printf '%s' "$outside"
  echo "Inspect with git status / git diff; the tree is left as the workers left it."
  exit 1
fi
for id in $DISPATCH; do
  rc="$(rc_of "$id")"; rec="$LOG_DIR/records/$id.yaml"; scope="$(row_get "$id" 4)"
  if [ "$rc" != 0 ]; then echo "  $id skipped (worker exit $rc; its edits stay uncommitted)"; STATUS=1; continue; fi
  if [ ! -f "$rec" ]; then echo "  $id skipped (no record at $rec)"; STATUS=1; continue; fi
  paths=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$p" = "$HALTS_DIR/$id.md" ] || in_scope "$p" "$scope"; then paths="$paths$p"$'\n'; fi
  done <<< "$CHANGED"
  if [ -n "$paths" ]; then printf '%s' "$paths" | tr '\n' '\0' | xargs -0 git add -A --; fi
  if ! apply_record "$LEDGER_ABS" "$id" "$rec" >>"$LOG_DIR/$id.log" 2>&1; then
    echo "  $id failed (record could not be applied; see $LOG_DIR/$id.log) — queue stopped"
    exit 1
  fi
  git add -- "$LEDGER_REL"
  desc="$(awk '/^description:/ { sub(/^description:[ \t]*/, ""); print; exit }' "$rec")"
  ph="$(row_get "$id" 3)"
  if git commit -q -m "align/${ph:-unplanned}/$id: ${desc:-aligned}" >>"$LOG_DIR/$id.log" 2>&1; then
    echo "  $id committed $(git rev-parse --short HEAD)"
  else
    echo "  $id failed (git commit; see $LOG_DIR/$id.log) — queue stopped"
    exit 1
  fi
done
echo
echo "Logs: $LOG_DIR/"
exit "$STATUS"
