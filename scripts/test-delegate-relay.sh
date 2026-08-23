#!/usr/bin/env bash
# test-delegate-relay.sh — regression fixture for scripts/delegate-relay.sh.
#
# The relay's whole promise is "the diff is the deliverable and nothing lands without a
# human". Three ways that promise failed silently, all reproduced here as cases:
#
#   1. SELF-TARGET   — pointed at its own repository, the relay dispatched an implementer
#                      into the tree holding its own evidence. Now refused (exit 6) unless
#                      --allow-self is passed. Case 7 proves both directions, including
#                      through a symlink, because scripts/ is symlinked into ~/.claude and
#                      a guard that no-ops under a symlink no-ops where it matters most.
#   2. SILENT COMMIT — an implementer that committed emptied `git status` and moved HEAD,
#                      so a status-delta of `touchedFiles` and a `git diff HEAD` both came
#                      back empty. The worst failure mode: an empty diff reads exactly like
#                      a harmless no-op. Case 2 is the regression test — the work must
#                      still be listed, still be in the diff, and the commits must be named.
#   3. ARTIFACT SWEEP— the artifact dir lives inside the target repo, so `git add -A` swept
#                      brief, logs and shim into the implementer's commit, and its own
#                      untracked files then dirtied the tree so the NEXT run refused with
#                      "commit/stash it yourself". Cases 5 and 6 pin the self-ignore.
#
# Case 8 is the counterweight to case 2: the commit-derived half of `touchedFiles` must not
# start attributing a caller's PRE-EXISTING dirt to the implementer. Case 9 asserts the
# relay's own read-only git guard has no dead write-capable permissions left in it.
#
# ISOLATION IS THE POINT. Every case builds its own repo under `mktemp -d`, with a
# throwaway $HOME and stub implementers on a prepended PATH. The harness REFUSES to run if
# a sandbox path escapes the temp dir or collides with this checkout — a test for a
# test-isolation bug that could reproduce the bug is not a test. Nothing here writes to,
# commits in, or points the relay at this repository.
#
# Real CLIs are never launched. The stub is named `kimi` because that profile is the
# cheapest to satisfy: P_RO_CLASS="none" and no write probe, so the relay only calls
# `kimi --version` before dispatch.
#
# Usage: scripts/test-delegate-relay.sh [--repo-root=<dir>] [--keep]
# Exit:  0 = every case passed, 1 = at least one failure.

set -o pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) ROOT="${1#*=}"; shift ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

RELAY="$ROOT/scripts/delegate-relay.sh"
[ -f "$RELAY" ] || { echo "relay not found: $RELAY" >&2; exit 2; }

ERRORS=0
fail() { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass() { printf '\033[32m✓ %s\033[0m\n' "$*"; }
info() { printf '\033[36m• %s\033[0m\n' "$*"; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/delegate-relay-test.XXXXXX")"
trap '[ "$KEEP" -eq 1 ] || rm -rf "$WORK"' EXIT

# ───────────────── isolation guard (runs before anything is created) ─────────────────
# A path that is not under the temp root, or that is inside this checkout, aborts the run
# outright. This is the assertion the incident would have failed.
TMPROOT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
WORK_P="$(cd "$WORK" && pwd -P)"
ROOT_P="$(cd "$ROOT" && pwd -P)"
case "$WORK_P/" in
  "$TMPROOT"/*) ;;
  *) echo "REFUSING TO RUN: sandbox '$WORK_P' is not under '$TMPROOT'." >&2; exit 2 ;;
esac
case "$WORK_P/" in
  "$ROOT_P"/*) echo "REFUSING TO RUN: sandbox is inside the repo under test." >&2; exit 2 ;;
esac

REAL_GIT="$(command -v git)"
[ -n "$REAL_GIT" ] || { echo "git not on PATH" >&2; exit 2; }

export HOME="$WORK/home"
mkdir -p "$HOME" "$WORK/bin" "$WORK/repos"
cat > "$HOME/.gitconfig" <<'GITCONFIG'
[user]
	name = Delegate Relay Fixture
	email = fixture@example.invalid
[init]
	defaultBranch = main
[alias]
	ci = commit
GITCONFIG

echo "================================================================"
echo "  delegate-relay — isolation + commit-visibility fixture"
echo "================================================================"
info "sandbox: $WORK_P   (repo under test: $ROOT_P — never targeted)"

# ───────────────── the stub implementer ─────────────────
# One stub, switched by $DELEGATE_CASE, which the relay passes through to the child.
# `git` inside it resolves to the relay's PATH shim; "$DELEGATE_REAL_GIT" deliberately
# does not — that is the absolute-path bypass the shim's own header admits to.
cat > "$WORK/bin/kimi" <<'STUB'
#!/bin/sh
# stub implementer — a fixture, never a real CLI.
case "${1:-}" in --version|version) echo "kimi-stub 9.9.9"; exit 0 ;; esac
G="$DELEGATE_REAL_GIT"
case "${DELEGATE_CASE:-}" in
  edit)
    printf 'alpha\n' > a.txt
    printf 'beta\n' >> file.txt
    echo "edited two files; left them in the working tree"
    ;;
  commit-abs)
    printf 'alpha\n' > a.txt
    printf 'beta\n' >> file.txt
    "$G" add a.txt file.txt
    "$G" commit -q -m "implementer landed it"
    echo "done, I landed it"
    ;;
  commit-shimmed)
    printf 'alpha\n' > a.txt
    git add a.txt
    git commit -q -m "implementer landed it" || echo "shim refused my commit"
    ;;
  alias)
    printf 'alpha\n' > a.txt
    git add a.txt
    git -c alias.zz=commit zz -q -m "landed via injected alias" || echo "injected alias refused"
    git ci -q -m "landed via configured alias" || echo "configured alias refused"
    ;;
  sweep)
    printf 'alpha\n' > a.txt
    git add -A
    "$G" commit -q -m "implementer landed it, and everything else it could see"
    ;;
  noop)
    echo "nothing to do"
    ;;
esac
exit 0
STUB
chmod +x "$WORK/bin/kimi"
export DELEGATE_REAL_GIT="$REAL_GIT"

printf 'Add a greeting to a.txt and append one line to file.txt.\nDo not commit.\n' > "$WORK/brief.md"

# ───────────────── helpers ─────────────────
# new_sandbox <name> → prints a fresh single-commit repo path under $WORK/repos.
new_sandbox() {
  local d="$WORK/repos/$1"
  mkdir -p "$d"
  "$REAL_GIT" -C "$d" init -q
  printf 'seed\n' > "$d/file.txt"
  "$REAL_GIT" -C "$d" add file.txt
  "$REAL_GIT" -C "$d" -c commit.gpgsign=false commit -q -m "seed"
  printf '%s' "$d"
}

# run_relay <case> <repo> [extra flags…] → RC, OUTDIR, RELAY_OUT
run_relay() {
  local c="$1" repo="$2"; shift 2
  RELAY_OUT="$(DELEGATE_CASE="$c" PATH="$WORK/bin:$PATH" \
    bash "$RELAY" --implementer=kimi --repo="$repo" --brief="$WORK/brief.md" \
                  --timeout=60 --quiet "$@" 2>"$WORK/relay.err")"
  RC=$?
  OUTDIR="$(dirname "$RELAY_OUT")"
  return 0
}

json_has()  { grep -qF -- "$2" "$1/result.json"; }
say_status() { printf '      %s\n' "$*"; }

# assert <label> <condition-rc> [detail…]
check() { if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1"; shift 2; [ $# -eq 0 ] || say_status "$*"; fi; }

# Every case ends here: the sandbox must still be a sandbox, and this repo untouched.
assert_isolated() {
  local repo="$1" top
  top="$("$REAL_GIT" -C "$repo" rev-parse --show-toplevel)"
  case "$top/" in
    "$TMPROOT"/*) pass "isolation: work stayed in $top" ;;
    *) fail "isolation: sandbox resolved outside the temp root ($top)" ;;
  esac
}

# ───────────────── 1. clean run: two files, no commit ─────────────────
info ""
info "1. Implementer edits two files and does not commit (the ordinary path)"
R1="$(new_sandbox clean)"
run_relay edit "$R1"
check "exit 0" "$([ "$RC" -eq 0 ] && echo 0 || echo 1)" "got exit $RC · $(head -3 "$WORK/relay.err")"
check "touchedCount == 2" "$(grep -q '"touchedCount": 2,' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(grep '"touched' "$OUTDIR/result.json")"
check "touchedFiles lists a.txt and file.txt" \
      "$(json_has "$OUTDIR" '"a.txt"' && json_has "$OUTDIR" '"file.txt"' && echo 0 || echo 1)"
check "delegate.diff carries both hunks" \
      "$(grep -q '+++ b/a.txt' "$OUTDIR/delegate.diff" && grep -q '+++ b/file.txt' "$OUTDIR/delegate.diff" && echo 0 || echo 1)"
check "violations: []" "$(grep -q '"violations": \[\],' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(grep '"violations"' "$OUTDIR/result.json")"
check "headMoved: false" "$(json_has "$OUTDIR" '"headMoved": false' && echo 0 || echo 1)"
check "selfTarget: false" "$(json_has "$OUTDIR" '"selfTarget": false' && echo 0 || echo 1)"
assert_isolated "$R1"

# ───────────────── 2. THE REGRESSION: implementer commits via an absolute path ─────────────────
info ""
info "2. Implementer commits behind the shim's back (the silent-empty-diff regression)"
R2="$(new_sandbox committed)"
run_relay commit-abs "$R2"
check "exit 1 (a moved HEAD is a failed run)" "$([ "$RC" -eq 1 ] && echo 0 || echo 1)" "got exit $RC"
check "headMoved: true" "$(json_has "$OUTDIR" '"headMoved": true' && echo 0 || echo 1)"
check "violations contains implementer-moved-head" \
      "$(json_has "$OUTDIR" 'implementer-moved-head' && echo 0 || echo 1)"
check "touchedFiles SURVIVES the commit (a.txt + file.txt still listed)" \
      "$(json_has "$OUTDIR" '"a.txt"' && json_has "$OUTDIR" '"file.txt"' && echo 0 || echo 1)" \
      "$(grep '"touchedFiles"' "$OUTDIR/result.json")"
check "touchedCount == 2 (not the empty set a status-delta returns)" \
      "$(grep -q '"touchedCount": 2,' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(grep '"touchedCount"' "$OUTDIR/result.json")"
check "delegate.diff STILL carries both hunks (diffed against the pre-run HEAD)" \
      "$(grep -q '+++ b/a.txt' "$OUTDIR/delegate.diff" && grep -q '+++ b/file.txt' "$OUTDIR/delegate.diff" && echo 0 || echo 1)" \
      "diff is $(wc -l < "$OUTDIR/delegate.diff" | tr -d ' ') lines"
check "delegate.diff is NOT a diff of the relay's own artifacts" \
      "$(grep -q '\.claude/delegate' "$OUTDIR/delegate.diff" && echo 1 || echo 0)"
check "git.commitsAhead == 1 and git.commits names it" \
      "$(json_has "$OUTDIR" '"commitsAhead": 1' && json_has "$OUTDIR" 'implementer landed it' && echo 0 || echo 1)" \
      "$(grep -A1 '"commitsAhead"' "$OUTDIR/result.json" | head -2)"
check "commits.txt written" "$([ -s "$OUTDIR/commits.txt" ] && echo 0 || echo 1)"
check "notes explain the moved HEAD and name the recovery command" \
      "$(json_has "$OUTDIR" 'git reset --soft' && echo 0 || echo 1)"
assert_isolated "$R2"

# The human-readable half of the same claim. `committed: false` and "Nothing was committed"
# are statements about the RELAY; printing the second one over a moved HEAD is the lie that
# made the JSON contradiction readable as a no-op.
R2B="$(new_sandbox committed-summary)"
SUMMARY="$(DELEGATE_CASE=commit-abs PATH="$WORK/bin:$PATH" bash "$RELAY" --implementer=kimi \
           --repo="$R2B" --brief="$WORK/brief.md" --timeout=60 2>&1)"
check "the summary does NOT print 'Nothing was committed' over a moved HEAD" \
      "$(printf '%s' "$SUMMARY" | grep -q 'Nothing was committed' && echo 1 || echo 0)"
check "the summary names the commit count and the recovery command" \
      "$(printf '%s' "$SUMMARY" | grep -q '^commits:' && printf '%s' "$SUMMARY" | grep -q 'git reset --soft' && echo 0 || echo 1)" \
      "$(printf '%s' "$SUMMARY" | grep -A2 'HEAD:' | head -4)"
assert_isolated "$R2B"

# ───────────────── 3. the naive path: the shim refuses ─────────────────
info ""
info "3. Implementer runs a plain 'git commit' (the shim's actual job)"
R3="$(new_sandbox shimmed)"
run_relay commit-shimmed "$R3"
check "headMoved: false — nothing landed" "$(json_has "$OUTDIR" '"headMoved": false' && echo 0 || echo 1)"
check "shimDenials >= 1" "$(grep -qE '"shimDenials": [1-9]' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(grep '"shimDenials"' "$OUTDIR/result.json")"
check "shim-denials.log records the attempt" \
      "$([ -s "$OUTDIR/shim-denials.log" ] && grep -q 'git commit' "$OUTDIR/shim-denials.log" && echo 0 || echo 1)"
assert_isolated "$R3"

# ───────────────── 4. both alias routes around the shim ─────────────────
info ""
info "4. Implementer reaches for commit through an alias (injected, then configured)"
R4="$(new_sandbox aliased)"
run_relay alias "$R4"
check "headMoved: false — neither alias landed a commit" \
      "$(json_has "$OUTDIR" '"headMoved": false' && echo 0 || echo 1)" \
      "$(grep '"head' "$OUTDIR/result.json")"
check "shimDenials == 2 (git -c alias.zz=commit AND ~/.gitconfig 'ci')" \
      "$(grep -q '"shimDenials": 2,' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(cat "$OUTDIR/shim-denials.log" 2>/dev/null)"
assert_isolated "$R4"

# ───────────────── 5. `git add -A` must not sweep the artifact dir ─────────────────
info ""
info "5. Implementer runs 'git add -A' then commits (the 51-file sweep)"
R5="$(new_sandbox swept)"
run_relay sweep "$R5"
SWEPT="$("$REAL_GIT" -C "$R5" show --pretty=format: --name-only HEAD)"
check "the commit contains a.txt" "$(printf '%s' "$SWEPT" | grep -q '^a\.txt$' && echo 0 || echo 1)"
check "the commit contains NO .claude/delegate path (artifact dir ignores itself)" \
      "$(printf '%s' "$SWEPT" | grep -q '\.claude/delegate' && echo 1 || echo 0)" \
      "$(printf '%s' "$SWEPT" | tr '\n' ' ')"
check "the artifact dir carries its own .gitignore" \
      "$([ "$(cat "$OUTDIR/.gitignore" 2>/dev/null)" = "*" ] && echo 0 || echo 1)"
assert_isolated "$R5"

# ───────────────── 6. --dry-run is safe anywhere, twice in a row ─────────────────
info ""
info "6. Two consecutive --dry-run runs leave the target repo untouched"
R6="$(new_sandbox dryrun)"
DRY1_OUT="$(PATH="$WORK/bin:$PATH" bash "$RELAY" --implementer=kimi --repo="$R6" \
             --brief="$WORK/brief.md" --dry-run 2>"$WORK/dry1.err")"; DRY1=$?
STATUS_AFTER_1="$("$REAL_GIT" -C "$R6" status --porcelain -uall)"
DRY2_OUT="$(PATH="$WORK/bin:$PATH" bash "$RELAY" --implementer=kimi --repo="$R6" \
             --brief="$WORK/brief.md" --dry-run 2>"$WORK/dry2.err")"; DRY2=$?
STATUS_AFTER_2="$("$REAL_GIT" -C "$R6" status --porcelain -uall)"
check "first --dry-run exits 0" "$([ "$DRY1" -eq 0 ] && echo 0 || echo 1)" "$(head -2 "$WORK/dry1.err")"
check "repo is still clean after it (nothing written into the tree)" \
      "$([ -z "$STATUS_AFTER_1" ] && echo 0 || echo 1)" "$STATUS_AFTER_1"
check "second --dry-run exits 0, not 4 ('working tree is dirty')" \
      "$([ "$DRY2" -eq 0 ] && echo 0 || echo 1)" "$(head -2 "$WORK/dry2.err")"
check "repo is still clean after both" "$([ -z "$STATUS_AFTER_2" ] && echo 0 || echo 1)" "$STATUS_AFTER_2"
check "no .claude/ directory was created in the target repo" \
      "$([ -d "$R6/.claude" ] && echo 1 || echo 0)"
check "the plan still names the composed brief" \
      "$(printf '%s' "$DRY1_OUT" | grep -q 'brief:' && echo 0 || echo 1)"
assert_isolated "$R6"

# ───────────────── 7. self-target: refused by default, opt-out honoured ─────────────────
info ""
info "7. A relay pointed at the repository it lives in"
SELF="$WORK/repos/self"
mkdir -p "$SELF/scripts"
cp "$RELAY" "$SELF/scripts/delegate-relay.sh"
"$REAL_GIT" -C "$SELF" init -q
printf 'seed\n' > "$SELF/file.txt"
"$REAL_GIT" -C "$SELF" add file.txt scripts/delegate-relay.sh
"$REAL_GIT" -C "$SELF" -c commit.gpgsign=false commit -q -m "seed"

SELF_ERR="$WORK/self.err"
PATH="$WORK/bin:$PATH" bash "$SELF/scripts/delegate-relay.sh" --implementer=kimi \
  --repo="$SELF" --brief="$WORK/brief.md" --quiet >/dev/null 2>"$SELF_ERR"; SRC=$?
check "exit 6 without --allow-self" "$([ "$SRC" -eq 6 ] && echo 0 || echo 1)" "got exit $SRC · $(head -1 "$SELF_ERR")"
check "the refusal names the safe alternative, not just the override" \
      "$(grep -q 'throwaway repo' "$SELF_ERR" && grep -q -- '--allow-self' "$SELF_ERR" && echo 0 || echo 1)" \
      "$(head -2 "$SELF_ERR")"
check "nothing was written into the repo it refused" \
      "$([ -z "$("$REAL_GIT" -C "$SELF" status --porcelain -uall)" ] && echo 0 || echo 1)"

# …and through a symlink, which is how the relay is actually invoked: scripts/ is
# symlinked into ~/.claude, where dirname "$0" is not a work tree at all. A guard that
# does not dereference silently passes here — the one place it must not.
mkdir -p "$HOME/.claude/scripts"
ln -sf "$SELF/scripts/delegate-relay.sh" "$HOME/.claude/scripts/delegate-relay.sh"
PATH="$WORK/bin:$PATH" bash "$HOME/.claude/scripts/delegate-relay.sh" --implementer=kimi \
  --repo="$SELF" --brief="$WORK/brief.md" --quiet >/dev/null 2>"$WORK/self-link.err"; SLRC=$?
check "exit 6 through a symlinked invocation too" "$([ "$SLRC" -eq 6 ] && echo 0 || echo 1)" \
      "got exit $SLRC · $(head -1 "$WORK/self-link.err")"

RELAY_OUT="$(DELEGATE_CASE=edit PATH="$WORK/bin:$PATH" \
  bash "$SELF/scripts/delegate-relay.sh" --implementer=kimi --repo="$SELF" \
       --brief="$WORK/brief.md" --timeout=60 --allow-self --quiet 2>"$WORK/self-allow.err")"; ARC=$?
OUTDIR="$(dirname "$RELAY_OUT")"
check "--allow-self runs the dispatch" "$([ "$ARC" -eq 0 ] && echo 0 || echo 1)" \
      "got exit $ARC · $(head -2 "$WORK/self-allow.err")"
check "result.json records selfTarget: true" \
      "$([ -f "$OUTDIR/result.json" ] && json_has "$OUTDIR" '"selfTarget": true' && echo 0 || echo 1)"
assert_isolated "$SELF"

# ───────────────── 8. a dirty baseline still yields a true delta ─────────────────
info ""
info "8. --allow-dirty: pre-existing dirt must not be reported as the implementer's work"
R8="$(new_sandbox dirty)"
printf 'pre-existing scratch\n' > "$R8/stale.txt"
run_relay edit "$R8" --allow-dirty
check "exit 0" "$([ "$RC" -eq 0 ] && echo 0 || echo 1)" "got exit $RC · $(head -2 "$WORK/relay.err")"
check "touchedCount == 2 (the union with committed files did not inflate the delta)" \
      "$(grep -q '"touchedCount": 2,' "$OUTDIR/result.json" && echo 0 || echo 1)" \
      "$(grep '"touchedFiles"' "$OUTDIR/result.json")"
check "stale.txt is NOT attributed to the implementer" \
      "$(json_has "$OUTDIR" '"stale.txt"' && echo 1 || echo 0)"
check "dirtyAtStart: true" "$(json_has "$OUTDIR" '"dirtyAtStart": true' && echo 0 || echo 1)"
assert_isolated "$R8"

# ───────────────── 9. the guard the relay polices on itself ─────────────────
info ""
info "9. Internal guard + preflight refusals"
NOTREPO="$WORK/not-a-repo"; mkdir -p "$NOTREPO"
PATH="$WORK/bin:$PATH" bash "$RELAY" --implementer=kimi --repo="$NOTREPO" \
  --brief="$WORK/brief.md" >/dev/null 2>"$WORK/notrepo.err"; NRC=$?
check "exit 4 on a directory that is not a work tree" "$([ "$NRC" -eq 4 ] && echo 0 || echo 1)" "got exit $NRC"
check "git_ro allowlist holds no write-capable dead permissions" \
      "$(grep -q '^GIT_RO_ALLOWED="rev-parse status diff log ls-files hash-object cat-file"$' "$RELAY" && echo 0 || echo 1)" \
      "$(grep '^GIT_RO_ALLOWED=' "$RELAY")"
# Only two `command git` call sites may exist: git_ro's own body, and the self-locate probe
# that must ask about a directory other than $REPO. Anything else is an unguarded call site
# — no live bug today, but the header's coverage claim would stop being true.
BYPASS="$(grep -n 'command git' "$RELAY" \
          | grep -v '^[0-9]*:[[:space:]]*#' \
          | grep -vF 'command git -C "$REPO" "$@"' \
          | grep -vF 'command git -C "$(self_dir)" rev-parse --show-toplevel')"
check "no git call site bypasses git_ro (beyond git_ro itself + the self-locate probe)" \
      "$([ -z "$BYPASS" ] && echo 0 || echo 1)" "$BYPASS"

# ───────────────── verdict ─────────────────
echo ""
echo "================================================================"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  delegate-relay: ALL CHECKS PASS\033[0m\n'
  echo "================================================================"
  exit 0
fi
printf '\033[31m  delegate-relay: %d FAILURE(S)\033[0m\n' "$ERRORS"
echo "================================================================"
exit 1
