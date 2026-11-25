#!/usr/bin/env bash
# tests/test-level/run.sh — pins test-level.py: which stages each word runs, and that the full run
# is never reached unless it was named.
#
#   1. Words → level: nothing said is stage2; «جاهز»/ready, «من غير تيست»/no-test, «تيست كامل»/full;
#      «من غير كومنت» turns comments off; two levels at once is an error; a bare "full" ending a
#      build command's prose is NOT a level; a level word in the middle of the text is not read.
#   2. Plan + run in a scratch repo whose testing.json commands append their stage name to a log:
#      default runs stage2 alone with <base> filled in; ready runs stage1 then stage2 and earns the
#      mark; no-test runs nothing; full runs full alone; a red stage1 skips stage2 and drops the
#      mark; a missing stage drops the mark; no testing.json runs nothing.
#   2b. The mark goes on the commit, never on an untested one: refused after a non-ready or red run,
#      on a dirty tree, on a commit made after the run, and before the push; posted (through a fake
#      gh) on exactly the pushed, tested HEAD.
#   3. "full" never appears in the log of any level but full.
#   4. The level in force lives in the git dir (never in `git status`), and plan follows it.
#   5. gate-check.py's G1 runs the level's stages, not the project's whole suite.
#   6. The project copy and the global copy are byte-identical.
#   7. Control: a wrong expectation must fail — a harness that cannot fail proves nothing.
#
# Usage:  bash tests/test-level/run.sh [--quiet]
# Exit:   0 every check holds · 1 any check failed · 2 a script or git is missing.
set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TL="$ROOT/templates/repo-baseline/.claude/scripts/test-level.py"
GC="$ROOT/templates/repo-baseline/.claude/scripts/gate-check.py"
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1
for f in "$TL" "$GC" "$ROOT/scripts/test-level.py"; do
  [ -f "$f" ] || { echo "test-level test: missing $f"; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "test-level test: git is not on PATH"; exit 2; }
# A CI runner has no git identity, and its hostname has no domain to guess one from, so every
# commit here failed there while passing on a machine with ~/.gitconfig. Name one for this test.
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

WORK="$(mktemp -d "${TMPDIR:-/tmp}/test-level-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); [ $QUIET -eq 1 ] || echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' | head -20; }
expect() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want: $3"$'\n'"got:  $2"; }
field() { python3 -c 'import json,sys; v=json.load(sys.stdin)[sys.argv[1]]; print(json.dumps(v, ensure_ascii=False) if not isinstance(v, str) else v)' "$1"; }

# ── 1. words ──────────────────────────────────────────────────────────────────────────────────
w() { python3 "$TL" words "$@" | field "$WORD_FIELD"; }
WORD_FIELD=level
expect "nothing said → stage2"                 "$(w next --drain)"                   "stage2"
expect "«جاهز» → ready"                         "$(w next --drain جاهز)"               "ready"
expect "ready → ready"                         "$(w next ready)"                      "ready"
expect "«من غير تيست» → no-test"                "$(w next من غير تيست)"                "no-test"
expect "no-test → no-test"                     "$(w next no-test)"                    "no-test"
expect "«تيست كامل» → full"                     "$(w next تيست كامل)"                  "full"
expect "--test=full anywhere → full"           "$(w --test=full next)"                "full"
expect "prose: a bare 'full' is not a level"   "$(w --prose show the address in full)" "stage2"
expect "prose: «تيست كامل» still is"            "$(w --prose fix the filter تيست كامل)" "full"
expect "a level word mid-text is not read"     "$(w --prose make it ready for the demo)" "stage2"
WORD_FIELD=comment
expect "comments on by default"                "$(w next)"                            "true"
expect "«من غير كومنت» → comments off"          "$(w next جاهز من غير كومنت)"         "false"
expect "--no-comment → comments off"           "$(w next --no-comment)"               "false"
WORD_FIELD=rest
expect "the words leave the refs intact"       "$(w next --drain --max=3 جاهز)"       "next --drain --max=3"
python3 "$TL" words next جاهز من غير تيست >/dev/null 2>&1
expect "two levels at once → exit 2"           "$?"                                   "2"

# ── 2–4. plan + run against a scratch repo ───────────────────────────────────────────────────────
R="$WORK/repo"; LOG="$WORK/ran.log"
mkdir -p "$R/.claude" && git -C "$R" init -q && git -C "$R" commit -q --allow-empty -m init
config() {   # config <stage1-cmd|-> <readyStatus|->
  python3 - "$R/.claude/testing.json" "$LOG" "$1" "$2" <<'EOF'
import json, sys
path, log, s1, label = sys.argv[1:]
cfg = {"stage2": "echo stage2 <base> >> %s" % log, "full": "echo full >> %s" % log, "base": "origin/main"}
if s1 != "-": cfg["stage1"] = s1.replace("LOG", log)
if label != "-": cfg["readyStatus"] = label
json.dump(cfg, open(path, "w"))
EOF
}
runlvl() { : > "$LOG"; python3 "$TL" run --repo="$R" --json "$@"; }   # prints the plan JSON, leaves the log
ran() { tr '\n' '|' < "$LOG"; }

config "echo stage1 >> LOG" -
out=$(runlvl); rc=$?
expect "default runs stage2 alone, <base> filled"  "$(ran)"                          "stage2 origin/main|"
expect "default earns no mark"                     "$(echo "$out" | field mark)"     "null"
expect "default exits 0 on green"                  "$rc"                             "0"
out=$(runlvl --level=ready)
expect "ready runs stage1 then stage2"             "$(ran)"                          "stage1|stage2 origin/main|"
expect "ready earns the default mark"              "$(echo "$out" | field mark)"     "tested-locally"
out=$(runlvl --level=no-test)
expect "no-test runs nothing"                      "$(ran)"                          ""
expect "no-test says so in its line"               "$(echo "$out" | field line)"     "tests: none on this machine (no-test)"
out=$(runlvl --level=full)
expect "full runs full alone"                      "$(ran)"                          "full|"
full_seen=0
for lv in stage2 ready no-test; do runlvl --level=$lv >/dev/null; grep -q '^full' "$LOG" && full_seen=1; done
expect "full never runs under another level"       "$full_seen"                      "0"

config "echo stage1 >> LOG; exit 3" "custom-label"
out=$(runlvl --level=ready); rc=$?
expect "a red stage1 skips stage2"                 "$(ran)"                          "stage1|"
expect "a red stage exits 1"                       "$rc"                             "1"
expect "a red stage drops the mark"                "$(echo "$out" | field mark)"     "null"
config - "custom-label"
out=$(runlvl --level=ready)
expect "a missing stage1 drops the mark"           "$(echo "$out" | field mark)"     "null"
config "echo stage1 >> LOG" "custom-label"
out=$(runlvl --level=ready)
expect "readyStatus is the project's"              "$(echo "$out" | field mark)"     "custom-label"

# 2b. the mark — a bare remote and a fake gh that logs what it would post
GHLOG="$WORK/gh.log"; printf '#!/bin/sh\necho "$@" >> %s\n' "$GHLOG" > "$WORK/gh"; chmod +x "$WORK/gh"
export TEST_LEVEL_GH="$WORK/gh"
git init -q --bare "$WORK/remote.git" && git -C "$R" remote add origin "$WORK/remote.git"
printf '.claude/\n' > "$R/.gitignore"; git -C "$R" add .gitignore && git -C "$R" commit -q -m ignore
markrc() { : > "$GHLOG"; python3 "$TL" mark --repo="$R" >/dev/null 2>&1; echo $?; }
config "echo stage1 >> LOG" -
runlvl --level=stage2 >/dev/null
expect "mark refused after a non-ready run"        "$(markrc)"                       "1"
config "echo stage1 >> LOG; exit 3" -
runlvl --level=ready >/dev/null
expect "mark refused after a red ready run"        "$(markrc)"                       "1"
config "echo stage1 >> LOG" -
echo dirty > "$R/work.txt"; runlvl --level=ready >/dev/null
expect "mark refused when the run saw a dirty tree" "$(markrc)"                      "1"
git -C "$R" add work.txt && git -C "$R" commit -q -m work
runlvl --level=ready >/dev/null
expect "mark refused before the push"              "$(markrc)"                       "1"
git -C "$R" push -q origin HEAD:refs/heads/card 2>/dev/null
expect "mark posted on the pushed, tested HEAD"    "$(markrc)"                       "0"
expect "the status names that SHA and the context" "$(grep -c "statuses/$(git -C "$R" rev-parse HEAD) .*context=tested-locally" "$GHLOG")" "1"
echo more > "$R/work.txt"; git -C "$R" commit -qam more; git -C "$R" push -q origin HEAD:refs/heads/card 2>/dev/null
expect "a commit after the run is never marked"    "$(markrc)"                       "1"
expect "nothing posted for it"                     "$(wc -l < "$GHLOG" | tr -d ' ')" "0"
unset TEST_LEVEL_GH

python3 "$TL" set ready --repo="$R"
expect "set → get"                                 "$(python3 "$TL" get --repo="$R")" "ready"
expect "plan follows the level in force"           "$(python3 "$TL" plan --repo="$R" | field level)" "ready"
expect "the level in force is not in git status"   "$(git -C "$R" status --porcelain -- . ':!.claude/testing.json')" ""
python3 "$TL" clear --repo="$R"
expect "clear → back to stage2"                    "$(python3 "$TL" get --repo="$R")" "stage2"

mv "$R/.claude/testing.json" "$WORK/testing.json"
out=$(runlvl --level=full)
expect "no testing.json: not configured"           "$(echo "$out" | field configured)" "false"
expect "no testing.json: nothing runs"             "$(ran)"                          ""
mv "$WORK/testing.json" "$R/.claude/testing.json"

# ── 5. gate-check G1 follows the level ──────────────────────────────────────────────────────────
printf '{"scripts":{"test":"echo whole-suite >> %s"}}\n' "$LOG" > "$R/package.json"
g1() { : > "$LOG"; python3 "$GC" --local --only=G1 --repo="$R" --json --no-evidence 2>/dev/null \
       | sed -n '/^{/,$p' \
       | python3 -c 'import json,sys; print(next(x["verdict"] for x in json.load(sys.stdin)["records"] if x["gate"]=="G1" and x["check"]=="tests"))'; }
expect "G1 by default: PASS on stage2"             "$(g1)"                           "PASS"
expect "G1 by default: the whole suite never ran"  "$(ran)"                          "stage2 origin/main|"
python3 "$TL" set no-test --repo="$R"
expect "G1 under no-test: UNVERIFIED, not PASS"    "$(g1)"                           "UNVERIFIED"
expect "G1 under no-test: nothing ran"             "$(ran)"                          ""
python3 "$TL" clear --repo="$R"

# ── 6. the two copies ─────────────────────────────────────────────────────────────────────────
cmp -s "$TL" "$ROOT/scripts/test-level.py" && ok "project and global copies are identical" \
  || bad "scripts/test-level.py differs from templates/repo-baseline/.claude/scripts/test-level.py"

# ── 7. control ────────────────────────────────────────────────────────────────────────────────
before=$fail
expect "control (must fail)" "$(w next)" "full" >/dev/null 2>&1
if [ $fail -eq $((before + 1)) ]; then fail=$before; ok "control: a wrong expectation fails"
else bad "control: a wrong expectation passed — the harness cannot fail"; fi

echo "test-level: $pass passed, $fail failed"
[ $fail -eq 0 ]
