#!/usr/bin/env bash
# delegate-relay.sh — dispatch ONE bounded coding task to a DIFFERENT AI coding CLI,
# then hand the diff back for a human to review and commit.
#
# The mechanical half of `/delegate` (see commands/delegate.md for the judgement half).
#
# WHAT IT DOES
#   1. Preflights: real git work tree, NOT the relay's own repo, clean-or-declared-dirty,
#      target CLI on PATH.
#   2. Composes a bounded brief (caller's text + gate commands + a non-removable
#      no-commit clause) and launches the CLI headlessly against the working tree.
#   3. Watchdogs the run, kills the process tree on timeout, and still writes a result.
#   4. Diffs the tree against a pre-run fingerprint and captures `delegate.diff`.
#   5. Emits `result.json` (contract `delegate-relay.result.v1`): status, exit code,
#      files touched, what got committed if anything did, the tri-state read-only
#      tripwire, and a session id when the CLI exposed one.
#
# WHAT IT NEVER DOES
#   Commit. Push. Stage on your behalf. Move HEAD. Land anything.
#   Its own git calls all go through git_ro(), which hard-refuses any subcommand outside a
#   read-only allowlist — with one stated exception, the self-locate probe, which has to
#   run `-C` somewhere other than $REPO and is a bare `rev-parse --show-toplevel`.
#   The implementer is additionally pushed at a PATH-shimmed `git`
#   that refuses the history-writing subcommands and both alias routes around them — still
#   a SPEED BUMP, NOT A BOUNDARY: `/usr/bin/git`, a libgit2 binding, or a subshell that
#   rebuilds PATH walks straight past it. The brief's no-commit clause and the human's
#   review are the real control.
#
# WHEN THE IMPLEMENTER COMMITS ANYWAY
#   The deliverable is always taken against the PRE-RUN HEAD, never against HEAD. An
#   implementer that commits moves HEAD onto its own work, and `git diff HEAD` would then
#   return nothing — the worst possible answer, because an empty diff reads exactly like a
#   harmless no-op. Diffing the pre-run HEAD keeps the work visible in `delegate.diff` and
#   in `touchedFiles`; `git.commits` names what landed; the run is still `failed` with
#   violations: ["implementer-moved-head"]. Loud, not silent.
#
# NEVER AGAINST ITS OWN REPOSITORY
#   Refused by default (exit 6). An implementer that commits inside the relay's own clone
#   commits the relay's own evidence: the artifact directory sits in that tree, and one
#   `git add -A` sweeps brief, logs and shim into the same commit. Exercise the relay
#   against a throwaway repo (CONTRIBUTING.md §2, "Exercising the relay") — or, if you
#   really mean it, pass --allow-self and read `selfTarget: true` in the result.
#
# READ-ONLY IS TRI-STATE ON PURPOSE
#   `readOnly.enforcement` ∈ not-requested | enforced | unverified | unenforceable
#   `readOnly.violation`   ∈ true | false | null
#   A `--read-only` run is REFUSED (exit 5) when the CLI documents no read-only mode, or
#   when its own `--help` no longer advertises the flag this profile would pass. The
#   violation tripwire covers git-visible paths inside the repo ONLY: ignored files,
#   $HOME writes, network calls and perfectly-reverted edits are outside it. `false` is
#   never a guarantee that nothing was written — touchedFiles and the diff are.
#
# IMPLEMENTER FLAGS were read from vendor docs + amElnagdy/delegate-skills (MIT) on
# 2026-08-20. CLIs move. Anything this file gets wrong for your installed version is a
# one-line fix in impl_profile()/impl_argv() — same contract as _parallel-tool-config.sh.
# Divergence worth knowing: _parallel-tool-config.sh drives kimi with
# `--headless --prompt`; this relay uses `-p`, which is what the current docs show.
#
# USAGE
#   delegate-relay.sh --implementer=<name> [--brief=<file>] [flags]
#   delegate-relay.sh --list
#   ... brief on stdin when --brief is omitted.
#
# FLAGS
#   --implementer=<name>  claude | codex | cursor-agent | opencode | aider | cline |
#                         gemini | kimi | qwen | copilot
#   --brief=<file>        Brief file. Omitted → read stdin.
#   --repo=<dir>          Target repo (default: $PWD).
#   --out=<dir>           Artifact dir (default: <repo>/.claude/delegate/<ts>-<impl>).
#   --gate=<cmd>          A real gate command; repeatable; appended to the brief.
#   --files=<globs>       In-scope paths, recorded in the brief. NOT a permission boundary.
#   --model=<name>        Model to pin (required for opencode; optional elsewhere).
#   --session=<id>        Resume a prior session (only where the resume shape is verified).
#   --read-only           Request the CLI's native read-only / plan mode.
#   --accept-unenforced   Allow a --read-only run whose enforcement is unverified/unenforceable.
#   --allow-dirty         Proceed with a dirty tree (baseline is fingerprinted first).
#   --allow-self          Target the relay's own repository anyway. Default: refused (6).
#   --timeout=<dur>       Watchdog: 900 | 45s | 30m | 2h. Default 30m. 0 disables.
#   --no-commit-shim      Do not put the refusing `git` shim on the implementer's PATH.
#   --dry-run             Print the resolved plan and exit; launch nothing.
#   --list                Print implementer availability and exit.
#   --quiet | -q          Only the result path on stdout.
#   -h | --help           This header.
#
# EXIT CODES
#   0  relay ran; implementer exited 0; result.json written
#   1  relay ran; implementer failed / timed out / moved HEAD; result.json written
#   2  usage error (no result written)
#   3  target CLI not installed / not runnable
#   4  git preflight failed (not a work tree, or dirty without --allow-dirty)
#   5  --read-only refused: this CLI cannot be shown to enforce it
#   6  self-target refused: --repo is the relay's own repo and --allow-self was not passed
#   9  internal guard tripped (a non-read-only git subcommand was attempted)
#
# bash 3.2 / BSD-userland safe: no associative arrays, no mapfile, no ${x,,}, no timeout(1).

set -euo pipefail
export LC_ALL=C

ORIG_PWD="$PWD"          # --brief / --out resolve against the invocation cwd, not the repo
RELAY_VERSION="1.1.0"
CONTRACT="delegate-relay.result.v1"
KNOWN_IMPLEMENTERS="claude codex cursor-agent opencode aider cline gemini kimi qwen copilot"

# ---------------------------------------------------------------------------
# args
# ---------------------------------------------------------------------------
IMPL=""
BRIEF_IN=""
REPO="$PWD"
OUT=""
FILES=""
MODEL=""
SESSION=""
READ_ONLY=0
ACCEPT_UNENFORCED=0
ALLOW_DIRTY=0
ALLOW_SELF=0
SELF_TARGET=false
TIMEOUT_SPEC="30m"
COMMIT_SHIM=1
DRY_RUN=0
DO_LIST=0
QUIET=0
GATES=""            # newline-joined; bash 3.2 has no nested arrays

# Prints the header block — every comment line after the shebang, stopping at the first
# line that is not one. A line range would go stale the next time the header grows.
usage() { awk 'NR == 1 { next } /^#/ { print; next } { exit }' "$0"; exit "${1:-2}"; }
die()   { echo "delegate-relay: $1" >&2; exit "${2:-2}"; }   # $1 only — $* would print the exit code
say()   { [ "$QUIET" -eq 1 ] || echo "$*"; }

for arg in "$@"; do
  case "$arg" in
    --implementer=*)     IMPL="${arg#*=}" ;;
    --brief=*)           BRIEF_IN="${arg#*=}" ;;
    --repo=*)            REPO="${arg#*=}" ;;
    --out=*)             OUT="${arg#*=}" ;;
    --gate=*)            GATES="${GATES}${arg#*=}
" ;;
    --files=*)           FILES="${arg#*=}" ;;
    --model=*)           MODEL="${arg#*=}" ;;
    --session=*)         SESSION="${arg#*=}" ;;
    --timeout=*)         TIMEOUT_SPEC="${arg#*=}" ;;
    --read-only)         READ_ONLY=1 ;;
    --accept-unenforced) ACCEPT_UNENFORCED=1 ;;
    --allow-dirty)       ALLOW_DIRTY=1 ;;
    --allow-self)        ALLOW_SELF=1 ;;
    --no-commit-shim)    COMMIT_SHIM=0 ;;
    --dry-run)           DRY_RUN=1 ;;
    --list)              DO_LIST=1 ;;
    --quiet|-q)          QUIET=1 ;;
    -h|--help)           usage 0 ;;
    *) die "unknown arg: $arg" 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# read-only git guard (invariant 2, self-policed)
#   EVERY git call in this script goes through here — no `command git` call sites remain
#   outside it, so the allowlist is the whole story rather than most of it.
#   `config` and `symbolic-ref` were dropped: both are write-capable (`config --global`,
#   `symbolic-ref HEAD refs/heads/x`) and neither was ever called. `log` was added so a
#   commit the implementer made can be NAMED rather than merely detected.
#   Residual, stated rather than hidden: `hash-object -w` would write an object. The relay
#   never passes -w, and the guard reads subcommands, not their flags.
# ---------------------------------------------------------------------------
GIT_RO_ALLOWED="rev-parse status diff log ls-files hash-object cat-file"

git_ro() {
  local sub="$1"
  case " $GIT_RO_ALLOWED " in
    *" $sub "*) ;;
    *) echo "delegate-relay: INTERNAL GUARD — refused non-read-only git subcommand '$sub'." >&2
       echo "                the relay never commits; that is the reviewer's job." >&2
       exit 9 ;;
  esac
  command git -C "$REPO" "$@"
}

# ---------------------------------------------------------------------------
# JSON helpers (no jq dependency)
# ---------------------------------------------------------------------------
# stdin -> escaped JSON string body (no surrounding quotes). Control chars stripped.
json_escape_stream() {
  tr -d '\000-\010\013\014\016-\037' \
  | awk '{ gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\r/,""); gsub(/\t/,"\\t");
           if (NR > 1) printf "\\n"; printf "%s", $0 }'
}
json_str() { printf '%s' "$1" | json_escape_stream; }

# newline-separated stdin -> JSON array body
json_array_stream() {
  awk 'NF || $0 != "" { gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); gsub(/\t/,"\\t");
       if (n++) printf ", "; printf "\"%s\"", $0 }'
}

# ---------------------------------------------------------------------------
# implementer profiles
#   P_BIN            binary to look for on PATH
#   P_VERSION_ARGV   how to ask it its version
#   P_BRIEF_CHANNEL  stdin | arg
#   P_RO_CLASS       native | none
#   P_RO_PROBE       token that must appear in `--help` for read-only to count as enforced
#   P_WRITE_PROBE    token that should appear in `--help` for the autonomy flags
#   P_RESUME         --resume | --session | codex-exec-resume | ""   ("" = relay-unsupported)
#   P_NEEDS_MODEL    1 when the CLI has no safe default model
# ---------------------------------------------------------------------------
impl_profile() {
  P_BIN=""; P_VERSION_ARGV="--version"; P_BRIEF_CHANNEL="arg"
  P_RO_CLASS="none"; P_RO_PROBE=""; P_WRITE_PROBE=""; P_RESUME=""; P_NEEDS_MODEL=0
  case "$1" in
    claude)
      P_BIN="claude"; P_BRIEF_CHANNEL="stdin"
      P_RO_CLASS="native"; P_RO_PROBE="permission-mode"; P_WRITE_PROBE="permission-mode"
      P_RESUME="--resume" ;;
    codex)
      P_BIN="codex"
      P_RO_CLASS="native"; P_RO_PROBE="sandbox"; P_WRITE_PROBE="sandbox"
      P_RESUME="codex-exec-resume" ;;
    cursor-agent)
      P_BIN="cursor-agent"
      P_RO_CLASS="native"; P_RO_PROBE="--plan"; P_WRITE_PROBE="--force"
      P_RESUME="--resume" ;;
    opencode)
      P_BIN="opencode"
      P_RO_CLASS="native"; P_RO_PROBE="--agent"; P_WRITE_PROBE="--agent"
      P_NEEDS_MODEL=1 ;;
    aider)
      P_BIN="aider"
      P_RO_CLASS="native"; P_RO_PROBE="--dry-run"; P_WRITE_PROBE="--yes-always" ;;
    cline)
      P_BIN="cline"; P_BRIEF_CHANNEL="stdin"
      P_RO_CLASS="native"; P_RO_PROBE="--plan"; P_WRITE_PROBE="--auto-approve" ;;
    gemini)
      P_BIN="gemini"
      P_RO_CLASS="native"; P_RO_PROBE="approval-mode"; P_WRITE_PROBE="approval-mode"
      P_RESUME="--resume" ;;
    kimi)
      P_BIN="kimi"
      P_RO_CLASS="none" ;;
    qwen)
      P_BIN="qwen"
      P_RO_CLASS="native"; P_RO_PROBE="approval-mode"; P_WRITE_PROBE="approval-mode" ;;
    copilot)
      P_BIN="copilot"; P_VERSION_ARGV="version"
      P_RO_CLASS="native"; P_RO_PROBE="--mode"; P_WRITE_PROBE="--allow-all-tools"
      P_RESUME="--resume" ;;
    *) return 1 ;;
  esac
  return 0
}

# The brief is an argv element for arg-channel CLIs. It is multi-line and long, so it is
# NEVER echoed or serialised inline — the file on disk is the artifact.
argv_display() {
  if [ -n "${BRIEF_TEXT:-}" ] && [ "$1" = "$BRIEF_TEXT" ]; then
    printf '<brief.md: %s bytes>' "$(printf '%s' "$BRIEF_TEXT" | wc -c | tr -d ' ')"
  else
    printf '%s' "$1"
  fi
}

# Builds the global ARGV array. Reads: IMPL, MODE, BRIEF_TEXT, MODEL, SESSION, DROP_WRITE_FLAGS.
impl_argv() {
  local ro=0
  [ "$MODE" = "read-only" ] && ro=1
  ARGV=()
  case "$IMPL" in
    claude)
      ARGV=("$P_BIN" -p --output-format json)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --permission-mode plan)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --permission-mode acceptEdits); fi
      [ -n "$MODEL" ]   && ARGV=("${ARGV[@]}" --model "$MODEL")
      [ -n "$SESSION" ] && ARGV=("${ARGV[@]}" --resume "$SESSION")
      ;;
    codex)
      ARGV=("$P_BIN" exec)
      [ -n "$SESSION" ] && ARGV=("${ARGV[@]}" resume "$SESSION")
      ARGV=("${ARGV[@]}" --json)
      if [ "$DROP_WRITE_FLAGS" -eq 0 ]; then
        if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --sandbox read-only)
        else ARGV=("${ARGV[@]}" --sandbox workspace-write); fi
      fi
      [ -n "$MODEL" ] && ARGV=("${ARGV[@]}" --model "$MODEL")
      ARGV=("${ARGV[@]}" "$BRIEF_TEXT")
      ;;
    cursor-agent)
      ARGV=("$P_BIN" -p --output-format json --trust)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --plan)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --force); fi
      [ -n "$MODEL" ]   && ARGV=("${ARGV[@]}" --model "$MODEL")
      [ -n "$SESSION" ] && ARGV=("${ARGV[@]}" --resume "$SESSION")
      ARGV=("${ARGV[@]}" "$BRIEF_TEXT")
      ;;
    opencode)
      ARGV=("$P_BIN" run --model "$MODEL")
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --agent plan)
      else ARGV=("${ARGV[@]}" --agent build); fi
      ARGV=("${ARGV[@]}" "$BRIEF_TEXT")
      ;;
    aider)
      ARGV=("$P_BIN" --message "$BRIEF_TEXT" --no-stream
            --no-auto-commits --no-dirty-commits
            --no-suggest-shell-commands --no-detect-urls)
      [ "$DROP_WRITE_FLAGS" -eq 0 ] && ARGV=("${ARGV[@]}" --yes-always)
      [ "$ro" -eq 1 ] && ARGV=("${ARGV[@]}" --dry-run)
      [ -n "$MODEL" ] && ARGV=("${ARGV[@]}" --model "$MODEL")
      ;;
    cline)
      ARGV=("$P_BIN" --json -v)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --plan --auto-approve false)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --auto-approve true); fi
      [ -n "$MODEL" ] && ARGV=("${ARGV[@]}" --model "$MODEL")
      ;;
    gemini)
      ARGV=("$P_BIN" --output-format json)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --approval-mode plan)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --approval-mode yolo); fi
      [ -n "$MODEL" ]   && ARGV=("${ARGV[@]}" --model "$MODEL")
      [ -n "$SESSION" ] && ARGV=("${ARGV[@]}" --resume "$SESSION")
      ARGV=("${ARGV[@]}" -p "$BRIEF_TEXT")
      ;;
    kimi)
      ARGV=("$P_BIN" -p "$BRIEF_TEXT")
      ;;
    qwen)
      ARGV=("$P_BIN" --output-format json)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --approval-mode plan)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --approval-mode yolo); fi
      [ -n "$MODEL" ] && ARGV=("${ARGV[@]}" --model "$MODEL")
      ARGV=("${ARGV[@]}" -p "$BRIEF_TEXT")
      ;;
    copilot)
      ARGV=("$P_BIN" -p "$BRIEF_TEXT" --output-format json --no-color)
      if [ "$ro" -eq 1 ]; then ARGV=("${ARGV[@]}" --mode plan)
      elif [ "$DROP_WRITE_FLAGS" -eq 0 ]; then ARGV=("${ARGV[@]}" --allow-all-tools); fi
      [ -n "$MODEL" ] && ARGV=("${ARGV[@]}" --model "$MODEL")
      ;;
  esac
  return 0   # a trailing `[ ] && ...` must never leak a non-zero status under set -e
}

# ---------------------------------------------------------------------------
# bounded execution — no timeout(1) (absent on stock macOS); own watchdog + pgroup kill
#   run_bounded <secs> <stdout> <stderr> <stdin-or-/dev/null> -- argv...
#   sets: RUN_RC, RUN_TIMED_OUT, RUN_SECONDS
# ---------------------------------------------------------------------------
run_bounded() {
  local secs="$1" o="$2" e="$3" i="$4"; shift 4
  [ "${1:-}" = "--" ] && shift
  local t0 pid waited rc
  t0=$(date +%s); RUN_TIMED_OUT=0; rc=0
  set +e
  set -m                                  # own process group per job → killable tree
  "$@" <"$i" >"$o" 2>"$e" &
  pid=$!
  set +m
  # Job control makes the shell print its own "[1]+ Terminated" notice when it reaps a
  # killed child. That is shell chatter, not the run's stderr (which goes to $e), so the
  # relay's own stderr is muted for the supervision window only.
  exec 9>&2 2>/dev/null
  waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$secs" -gt 0 ] && [ "$waited" -ge "$secs" ]; then
      RUN_TIMED_OUT=1
      kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      sleep 3
      kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"; rc=$?
  exec 2>&9 9>&-
  set -e
  RUN_RC=$rc
  RUN_SECONDS=$(( $(date +%s) - t0 ))
}

parse_duration() {
  local d="$1" n=""
  case "$d" in
    *h) n="${d%h}"; case "$n" in ''|*[!0-9]*) d="" ;; *) echo $(( n * 3600 )); return 0 ;; esac ;;
    *m) n="${d%m}"; case "$n" in ''|*[!0-9]*) d="" ;; *) echo $(( n * 60 ));   return 0 ;; esac ;;
    *s) n="${d%s}"; case "$n" in ''|*[!0-9]*) d="" ;; *) echo "$n";            return 0 ;; esac ;;
    ''|*[!0-9]*) d="" ;;
    *) echo "$d"; return 0 ;;
  esac
  die "bad --timeout: '$1' (use 900 | 45s | 30m | 2h; 0 disables the watchdog)" 2
}

# ---------------------------------------------------------------------------
# --list
# ---------------------------------------------------------------------------
if [ "$DO_LIST" -eq 1 ]; then
  printf '%-14s %-10s %-14s %s\n' IMPLEMENTER INSTALLED READ-ONLY PATH
  for name in $KNOWN_IMPLEMENTERS; do
    impl_profile "$name"
    p="$(command -v "$P_BIN" 2>/dev/null || true)"
    if [ -n "$p" ]; then inst="yes"; else inst="no"; p="-"; fi
    if [ "$P_RO_CLASS" = "native" ]; then ro="native"; else ro="NONE"; fi
    printf '%-14s %-10s %-14s %s\n' "$name" "$inst" "$ro" "$p"
  done
  echo
  echo "read-only 'native' = the CLI documents a mode; the relay still probes --help at dispatch"
  echo "and reports 'unverified' rather than claiming an enforcement it could not confirm."
  exit 0
fi

# ---------------------------------------------------------------------------
# preflight
# ---------------------------------------------------------------------------
[ -n "$IMPL" ] || die "missing --implementer (try --list)" 2
impl_profile "$IMPL" || die "unknown implementer '$IMPL'. Known: $KNOWN_IMPLEMENTERS" 2

check_implementer() {
  IMPL_PATH="$(command -v "$P_BIN" 2>/dev/null || true)"
  [ -n "$IMPL_PATH" ] || die "'$P_BIN' is not on PATH — install/authenticate it, or pick another implementer (--list)." 3
  # shellcheck disable=SC2086  # P_VERSION_ARGV is a flag list; word-splitting is intended
  IMPL_VERSION="$("$P_BIN" $P_VERSION_ARGV 2>/dev/null | head -1 || true)"
  [ -n "$IMPL_VERSION" ] || IMPL_VERSION="unknown"
}

check_git_state() {
  git_ro rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not a git work tree: $REPO — the diff IS the deliverable, so a repo is required." 4
  REPO="$(git_ro rev-parse --show-toplevel)"
  HEAD_BEFORE="$(git_ro rev-parse HEAD 2>/dev/null || echo "")"
  [ -n "$HEAD_BEFORE" ] || die "repo has no commits yet: $REPO — cannot compute a reviewable diff." 4
  BRANCH="$(git_ro rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  DIRTY_AT_START=0
  [ -n "$(git_ro status --porcelain -uall 2>/dev/null || true)" ] && DIRTY_AT_START=1
  if [ "$DIRTY_AT_START" -eq 1 ] && [ "$ALLOW_DIRTY" -eq 0 ]; then
    die "working tree is dirty — 'what did the implementer touch' becomes unanswerable.
                Commit/stash it yourself, or pass --allow-dirty to fingerprint the existing dirt first." 4
  fi
}

# Where this script really lives, with symlinks dereferenced. `dirname "$0"` is not enough:
# scripts/ is symlinked into ~/.claude, so an invocation through the symlink reports a
# directory that is not a work tree at all — and a self-target guard that no-ops under a
# symlink no-ops exactly where it is most needed. No `readlink -f`: BSD readlink has no -f.
self_dir() {
  local src="$0" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  (cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)
}

# Refuse to delegate against the repository this relay lives in.
#   A warning would be worthless: the run is headless with a 30-minute watchdog, and nobody
#   is reading stderr at the moment an implementer decides to commit. A refusal with no
#   override would be worse than it looks — exercising the relay is a recurring, legitimate
#   need, and a tool that cannot be exercised safely gets exercised unsafely. So: refuse,
#   name the safe alternative, and keep one explicit door.
#   Narrow by construction: this stops the relay eating its own evidence. Every other
#   failure mode it guards happens identically in your repo, which is why the diff base,
#   the artifact self-ignore and the commit surfacing are not conditional on it.
check_self_target() {
  local self_top
  # The one git call that cannot go through git_ro(): git_ro pins `-C "$REPO"`, and the
  # whole question here is what toplevel a DIFFERENT directory belongs to. Read-only.
  self_top="$(command git -C "$(self_dir)" rev-parse --show-toplevel 2>/dev/null || echo "")"
  [ -n "$self_top" ] || return 0
  [ "$self_top" = "$REPO" ] || return 0
  SELF_TARGET=true
  [ "$ALLOW_SELF" -eq 0 ] || return 0
  die "refusing to delegate against the relay's own repository: $REPO
                An implementer that commits here commits the relay's own evidence — the
                artifact dir lives in this tree, and one 'git add -A' sweeps it in.
                Exercise the relay against a throwaway repo instead:
                  SB=\"\$(mktemp -d)\"; git -C \"\$SB\" init -q   # see CONTRIBUTING.md §2
                Pass --allow-self if you genuinely meant this repository." 6
}

[ -n "$MODEL" ] || [ "$P_NEEDS_MODEL" -eq 0 ] \
  || die "--model is required for '$IMPL' (it has no safe default model)." 2
[ -z "$SESSION" ] || [ -n "$P_RESUME" ] \
  || die "--session is not supported for '$IMPL' by this relay: its resume flag shape is unverified.
                Guessing one produces a silent fresh run that looks like a resume. Start a new run instead." 2

abs_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$ORIG_PWD" "$1" ;; esac; }

check_git_state
check_self_target        # after check_git_state: $REPO must be the resolved toplevel first
[ -z "$BRIEF_IN" ] || BRIEF_IN="$(abs_path "$BRIEF_IN")"
[ -z "$OUT" ]      || OUT="$(abs_path "$OUT")"
# Everything downstream — version probe, --help probe, the dispatch itself — runs with the
# repo as cwd. A CLI that writes relative to cwd then writes into the tree being reviewed,
# where the fingerprint can see it, instead of into the caller's directory.
cd "$REPO"
check_implementer

# ---- read-only tri-state -------------------------------------------------
HELP_TEXT=""
HELP_PROBE="skipped"
RO_ENFORCEMENT="not-requested"
NOTES=""
DROP_WRITE_FLAGS=0
add_note() { NOTES="${NOTES}$1
"; }

probe_help() {
  local tmp_o tmp_e
  tmp_o="$(mktemp)"; tmp_e="$(mktemp)"
  run_bounded 20 "$tmp_o" "$tmp_e" /dev/null -- "$P_BIN" --help || true
  HELP_TEXT="$(cat "$tmp_o" "$tmp_e" 2>/dev/null || true)"
  rm -f "$tmp_o" "$tmp_e"
}

if [ "$READ_ONLY" -eq 1 ]; then
  if [ "$P_RO_CLASS" = "none" ]; then
    RO_ENFORCEMENT="unenforceable"
    HELP_PROBE="skipped"
  else
    probe_help
    if [ -z "$HELP_TEXT" ]; then
      RO_ENFORCEMENT="unverified"; HELP_PROBE="unavailable"
      add_note "read-only: '$P_BIN --help' produced no output, so the flag could not be confirmed."
    elif printf '%s' "$HELP_TEXT" | grep -qF -- "$P_RO_PROBE"; then
      RO_ENFORCEMENT="enforced"; HELP_PROBE="hit"
    else
      RO_ENFORCEMENT="unverified"; HELP_PROBE="miss"
      add_note "read-only: installed '$P_BIN' does not advertise '$P_RO_PROBE' in --help (version drift or a wrapper)."
    fi
  fi
  if [ "$RO_ENFORCEMENT" != "enforced" ] && [ "$ACCEPT_UNENFORCED" -eq 0 ]; then
    die "--read-only refused: enforcement is '$RO_ENFORCEMENT' for '$IMPL'.
                This relay does not claim a guarantee the CLI cannot provide.
                Either pick an implementer with a native read-only mode (--list),
                or re-run with --accept-unenforced and review the git tripwire instead." 5
  fi
  [ "$RO_ENFORCEMENT" = "enforced" ] \
    || add_note "read-only run accepted as best-effort: the git tripwire is the only signal."
  MODE="read-only"
else
  MODE="write"
  if [ -n "$P_WRITE_PROBE" ]; then
    probe_help
    if [ -n "$HELP_TEXT" ]; then
      if printf '%s' "$HELP_TEXT" | grep -qF -- "$P_WRITE_PROBE"; then
        HELP_PROBE="hit"
      else
        HELP_PROBE="miss"
        add_note "autonomy: installed '$P_BIN' does not advertise '$P_WRITE_PROBE' in --help; the flag is still passed so the CLI fails loudly rather than silently."
      fi
    else
      HELP_PROBE="unavailable"
    fi
  fi
fi

TIMEOUT_SECS="$(parse_duration "$TIMEOUT_SPEC")"

# ---------------------------------------------------------------------------
# artifact dir + brief
# ---------------------------------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ -z "$OUT" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    # A dry run is documented as safe anywhere, and writing the composed brief into the
    # target repo made that false: it dirtied the tree, and the NEXT run then died at
    # exit 4 with an error telling the caller to commit. That is the exact pressure that
    # produces a `git add -A`. Dry runs stage themselves outside the repo.
    OUT="${TMPDIR:-/tmp}/delegate-dryrun-$STAMP-$IMPL"
  else
    OUT="$REPO/.claude/delegate/$STAMP-$IMPL"
  fi
fi
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
# When the artifact dir lives inside the target repo (the default), its own files would
# otherwise show up as untracked work the implementer did. Filter them out everywhere.
OUT_REL=""
case "$OUT/" in
  "$REPO"/*) OUT_REL="${OUT#"$REPO"/}/" ;;
esac
# ...and make the directory ignore ITSELF. Filtering only protected the relay's own
# reporting; it did nothing about `git add -A`, which is how a stub committing one scratch
# file swept 51 files — brief, logs, shim and all — into the implementer's commit. One
# line closes three things: the sweep, the dirty tree that made the next run refuse, and
# "the relay handed back a diff of its own stdout.log".
[ -z "$OUT_REL" ] || printf '*\n' > "$OUT/.gitignore"
BRIEF_FILE="$OUT/brief.md"
STDOUT_LOG="$OUT/stdout.log"
STDERR_LOG="$OUT/stderr.log"
DIFF_FILE="$OUT/delegate.diff"
RESULT_JSON="$OUT/result.json"
SHIM_LOG="$OUT/shim-denials.log"

RAW_BRIEF="$OUT/brief.input"
if [ -n "$BRIEF_IN" ]; then
  [ -f "$BRIEF_IN" ] || die "brief file not found: $BRIEF_IN" 2
  cat "$BRIEF_IN" > "$RAW_BRIEF"
elif [ ! -t 0 ]; then
  cat > "$RAW_BRIEF"
else
  die "no brief: pass --brief=<file> or pipe one on stdin." 2
fi
[ -s "$RAW_BRIEF" ] || die "brief is empty — an unbounded brief returns an unreviewable diff." 2

{
  cat "$RAW_BRIEF"
  echo
  echo "---"
  echo
  echo "## Working tree"
  echo
  echo "Repository: $REPO (branch \`$BRANCH\`, HEAD \`$HEAD_BEFORE\`)"
  [ -n "$FILES" ] && { echo; echo "In-scope paths: \`$FILES\`. This is scoping for review, not a permission boundary."; }
  if [ -n "$GATES" ]; then
    echo
    echo "## Gates — run these and report the real output"
    echo
    printf '%s' "$GATES" | while IFS= read -r g; do [ -n "$g" ] && echo "- \`$g\`"; done
    echo
    echo "Do not edit a test to make a gate pass. If a gate cannot pass, say so and stop."
  fi
  echo
  echo "## Report contract"
  echo
  echo "End your run with: what you changed (by file), what you could NOT do, and what you are unsure about."
  echo "Your report is a claim; the reviewer re-runs every gate."
  echo
  echo "## Non-negotiable — do not commit"
  echo
  echo "Do NOT run \`git commit\`, \`git push\`, \`git rebase\`, \`git merge\`, \`git reset\`,"
  echo "\`git checkout\`, \`git restore\`, \`git stash\`, \`git clean\`, or anything else that moves HEAD,"
  echo "rewrites history, or discards working-tree changes. Leave every change in the working tree."
  echo "A human reviews the diff and commits it. That decision is not yours."
} > "$BRIEF_FILE"

BRIEF_TEXT="$(cat "$BRIEF_FILE")"
impl_argv

# ---------------------------------------------------------------------------
# dry run
# ---------------------------------------------------------------------------
print_plan() {
  echo "implementer:   $IMPL ($IMPL_VERSION) → $IMPL_PATH"
  echo "mode:          $MODE"
  echo "read-only:     enforcement=$RO_ENFORCEMENT helpProbe=$HELP_PROBE"
  echo "repo:          $REPO (branch $BRANCH, HEAD $HEAD_BEFORE, dirty=$DIRTY_AT_START)"
  if [ "$SELF_TARGET" = true ]; then
    echo "self-target:   YES — this is the relay's own repository, allowed by --allow-self"
  fi
  echo "brief:         $BRIEF_FILE ($(wc -l < "$BRIEF_FILE" | tr -d ' ') lines)"
  echo "timeout:       ${TIMEOUT_SECS}s"
  echo "commit shim:   $([ "$COMMIT_SHIM" -eq 1 ] && echo enabled || echo disabled)"
  echo "out:           $OUT"
  printf 'argv:         '
  for a in "${ARGV[@]}"; do printf ' [%s]' "$(argv_display "$a")"; done
  echo
}

if [ "$DRY_RUN" -eq 1 ]; then
  print_plan
  echo
  echo "dry run — nothing launched, nothing edited, nothing committed."
  exit 0
fi

# ---------------------------------------------------------------------------
# baseline fingerprint
#   snapshot <outfile>  →  "<xy>\t<hash>\t<path>" per non-clean path, sorted by path.
#   Sets FP_INCOMPLETE=1 when a path could not be hashed (submodule, unreadable, dir).
# ---------------------------------------------------------------------------
FP_INCOMPLETE=0
snapshot() {
  local out="$1" xy p h
  : > "$out"
  while IFS= read -r -d '' rec; do
    xy="$(printf '%s' "$rec" | cut -c1-2)"
    p="$(printf '%s' "$rec" | cut -c4-)"
    case "$xy" in
      R*|C*) IFS= read -r -d '' _origin || true ;;   # rename/copy source record
    esac
    [ -n "$p" ] || continue
    if [ -n "$OUT_REL" ]; then
      case "$p" in "$OUT_REL"*) continue ;; esac   # relay artifacts are not the implementer's work
    fi
    if [ -f "$REPO/$p" ] && [ ! -L "$REPO/$p" ]; then
      h="$(git_ro hash-object -- "$p" 2>/dev/null || echo "")"
      [ -n "$h" ] || { h="unhashable"; FP_INCOMPLETE=1; }
    elif [ -e "$REPO/$p" ] || [ -L "$REPO/$p" ]; then
      h="nonregular"; FP_INCOMPLETE=1
    else
      h="absent"
    fi
    printf '%s\t%s\t%s\n' "$xy" "$h" "$p" >> "$out"
  done < <(git_ro status --porcelain=v1 -uall -z 2>/dev/null || true)
  LC_ALL=C sort -t"$(printf '\t')" -k3,3 -o "$out" "$out"
}

# Drop any path under the artifact dir. Prefix match, never a regex: $OUT_REL is a real
# path and a `.` in it must not match a character class.
strip_out_rel() {
  [ -n "$OUT_REL" ] || { cat; return 0; }
  awk -v p="$OUT_REL" 'index($0, p) != 1'
}

# Everything reviewable is measured from the PRE-RUN HEAD, never from HEAD: an implementer
# that committed has moved HEAD onto its own work, and `git diff HEAD` then reports an
# empty tree. `:(exclude)` needs git >= 2.13; where the pathspec magic is rejected git
# exits non-zero before writing output, so the plain form runs instead — and the artifact
# dir is self-ignored anyway, so both paths agree.
diff_since_base() {
  if [ -n "$OUT_REL" ]; then
    git_ro diff "$@" "$DIFF_BASE" -- . ":(exclude)${OUT_REL}*" 2>/dev/null && return 0
  fi
  git_ro diff "$@" "$DIFF_BASE" -- . 2>/dev/null || true
}

[ -z "$OUT_REL" ] || add_note "relay artifacts are written inside the repo at '$OUT_REL' and ignore themselves ('${OUT_REL}.gitignore' holds a single '*'), so they stay out of touchedFiles, out of the diff, out of git status, and out of any 'git add -A' the implementer runs. Artifact files from an OLDER run that are already tracked are not covered by that — untrack those yourself."
snapshot "$OUT/baseline.tsv"
cut -f2,3 "$OUT/baseline.tsv" | LC_ALL=C sort > "$OUT/baseline.keys"

# ---------------------------------------------------------------------------
# commit shim — a speed bump on the implementer's PATH, not a boundary
# ---------------------------------------------------------------------------
RUN_PATH="$PATH"
if [ "$COMMIT_SHIM" -eq 1 ]; then
  mkdir -p "$OUT/shim"
  cat > "$OUT/shim/git" <<SHIM
#!/bin/sh
# delegate-relay git shim. Refuses the subcommands that would land the deliverable or
# destroy it, plus the two alias routes around them: a config-injected alias
# (git -c alias.x=commit x) and an alias the caller already has in ~/.gitconfig. Both
# were reachable by accident, not by malice, which is why they are closed.
# STILL A SPEED BUMP, NOT A BOUNDARY — /usr/bin/git, a libgit2/pygit2/dulwich binding,
# or any subshell that rebuilds PATH walks straight past it, and \`gh\`/\`hub\` are not
# shimmed at all. The brief's no-commit clause is the real instruction; this only makes
# the naive path noisy and logged.
# Deliberately NOT denied: \`add\` (tools stage in order to diff), \`fetch\`-less reads,
# \`submodule\` (its status form is ordinary inspection), and a bare \`branch\` listing.
REAL_GIT="$(command -v git)"
DENY="commit push am rebase merge pull fetch reset checkout switch restore stash cherry-pick revert tag update-ref filter-branch filter-repo clean gc prune reflog worktree rm mv notes replace commit-tree"
LOG="$SHIM_LOG"

refuse() {
  echo "delegate-relay: 'git \$1' is refused for this run — the reviewer commits, not you." >&2
  echo "\$(date -u +%Y-%m-%dT%H:%M:%SZ) git \$1" >> "\$LOG"
  exit 1
}
denied() {
  for d in \$DENY; do [ "\$1" = "\$d" ] && return 0; done
  return 1
}

# 1. An alias injected on this very command line never reaches config, so it cannot be
#    looked up — refuse the injection itself.
prev=""
for a in "\$@"; do
  case "\$a" in
    alias.*)                              [ "\$prev" = "-c" ] && refuse "-c \$a" ;;
    -calias.*|--config-env=alias.*|--config=alias.*) refuse "\$a" ;;
  esac
  prev="\$a"
done

# 2. First non-flag token is the subcommand; global flags that take a value are skipped.
sub=""
skip=0
for a in "\$@"; do
  if [ "\$skip" = "1" ]; then skip=0; continue; fi
  case "\$a" in
    -C|-c|--git-dir|--work-tree|--namespace|--exec-path|--config-env) skip=1 ;;
    -*) ;;
    *) sub="\$a"; break ;;
  esac
done
[ -n "\$sub" ] && denied "\$sub" && refuse "\$sub"

# 3. A pre-existing alias resolves to a real subcommand — check what it expands to.
if [ -n "\$sub" ]; then
  exp="\$("\$REAL_GIT" config --get "alias.\$sub" 2>/dev/null)" || exp=""
  if [ -n "\$exp" ]; then
    first="\${exp%% *}"
    first="\${first#!}"
    denied "\$first" && refuse "\$sub (alias for: \$exp)"
  fi
fi

# 4. \`git branch\` lists; \`git branch -D/-f/-m\` rewrites refs.
if [ "\$sub" = "branch" ]; then
  for a in "\$@"; do
    case "\$a" in
      -d|-D|-m|-M|-f|--delete|--force|--move) refuse "branch \$a" ;;
    esac
  done
fi

exec "\$REAL_GIT" "\$@"
SHIM
  chmod +x "$OUT/shim/git"
  RUN_PATH="$OUT/shim:$PATH"
fi

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------
say "$(print_plan)"
say ""
say "dispatching — the relay blocks until '$IMPL' exits or the watchdog fires."

STDIN_SRC="/dev/null"
[ "$P_BRIEF_CHANNEL" = "stdin" ] && STDIN_SRC="$BRIEF_FILE"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OLD_PATH="$PATH"
cd "$REPO"          # already true; re-asserted so the launch cwd is unambiguous
PATH="$RUN_PATH"
run_bounded "$TIMEOUT_SECS" "$STDOUT_LOG" "$STDERR_LOG" "$STDIN_SRC" -- "${ARGV[@]}"
PATH="$OLD_PATH"
FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

EXIT_CODE="$RUN_RC"
TIMED_OUT="$RUN_TIMED_OUT"
SIGNAL="null"
if [ "$EXIT_CODE" -gt 128 ]; then
  case "$EXIT_CODE" in
    137) SIGNAL='"SIGKILL"' ;;
    143) SIGNAL='"SIGTERM"' ;;
    130) SIGNAL='"SIGINT"' ;;
    *)   SIGNAL="\"signal-$((EXIT_CODE - 128))\"" ;;
  esac
fi

# ---------------------------------------------------------------------------
# post-run: HEAD first, then delta, then diff
#   HEAD is read BEFORE the delta because it decides what the delta has to be measured
#   against. A committing implementer empties `git status`, so a status-only delta goes
#   blank at exactly the moment the invariant broke.
# ---------------------------------------------------------------------------
HEAD_AFTER="$(git_ro rev-parse HEAD 2>/dev/null || echo "")"
HEAD_MOVED=false
[ "$HEAD_AFTER" = "$HEAD_BEFORE" ] || HEAD_MOVED=true
STAGED_AT_END=false
[ -z "$(git_ro diff --cached --name-only 2>/dev/null || true)" ] || STAGED_AT_END=true
DIFF_BASE="$HEAD_BEFORE"

# What the implementer committed, named rather than merely detected. An empty range with
# HEAD_MOVED=true is itself a finding: history was rewritten or checked out, not appended.
COMMITS_FILE="$OUT/commits.txt"
COMMIT_FILES="$OUT/committed-files.txt"
: > "$COMMITS_FILE"
: > "$COMMIT_FILES"
COMMITS_AHEAD=0
if [ "$HEAD_MOVED" = true ]; then
  git_ro log --oneline --no-decorate "$HEAD_BEFORE..$HEAD_AFTER" > "$COMMITS_FILE" 2>/dev/null || : > "$COMMITS_FILE"
  COMMITS_AHEAD="$(wc -l < "$COMMITS_FILE" | tr -d ' ')"
  git_ro diff --name-only "$HEAD_BEFORE" "$HEAD_AFTER" 2>/dev/null | strip_out_rel > "$COMMIT_FILES" || : > "$COMMIT_FILES"
fi

snapshot "$OUT/after.tsv"
cut -f2,3 "$OUT/after.tsv" | LC_ALL=C sort > "$OUT/after.keys"

# touchedFiles = (working-tree delta since the baseline fingerprint) ∪ (what got committed).
# The first half alone reads as `[]` the moment the implementer commits everything; the
# union is what makes "it committed my deliverable" survive as a file list.
LC_ALL=C comm -3 "$OUT/baseline.keys" "$OUT/after.keys" \
  | sed 's/^	//' | cut -f2- | LC_ALL=C sort -u > "$OUT/touched.worktree"
cat "$OUT/touched.worktree" "$COMMIT_FILES" \
  | awk 'NF' | strip_out_rel | LC_ALL=C sort -u > "$OUT/touched.txt"
TOUCHED_COUNT="$(wc -l < "$OUT/touched.txt" | tr -d ' ')"

# tracked changes vs the PRE-RUN HEAD, then each untracked file as a /dev/null diff
{
  diff_since_base
  awk -F'\t' '$1 ~ /^\?\?/ { print $3 }' "$OUT/after.tsv" | while IFS= read -r u; do
    [ -f "$REPO/$u" ] || continue
    git_ro diff --no-index --no-color -- /dev/null "$u" 2>/dev/null || true
  done
} > "$DIFF_FILE"
DIFF_LINES="$(wc -l < "$DIFF_FILE" | tr -d ' ')"

# ---- read-only violation tripwire (tri-state) ----
RO_VIOLATION="null"
if [ "$READ_ONLY" -eq 1 ]; then
  if [ "$FP_INCOMPLETE" -eq 1 ]; then
    RO_VIOLATION="null"
    add_note "read-only tripwire: baseline coverage incomplete (a path could not be fingerprinted), so violation stays null rather than false."
  elif [ "$TOUCHED_COUNT" -gt 0 ] || [ "$HEAD_MOVED" = true ]; then
    RO_VIOLATION="true"
  else
    RO_VIOLATION="false"
  fi
fi

SHIM_DENIALS=0
[ -f "$SHIM_LOG" ] && SHIM_DENIALS="$(wc -l < "$SHIM_LOG" | tr -d ' ')"
[ "$SHIM_DENIALS" -gt 0 ] && add_note "the implementer attempted $SHIM_DENIALS history-writing git command(s); the shim refused them. See $SHIM_LOG. The diff still needs the same review — an attempted commit is a signal about the run, not a verdict on the code." 

# ---- violations + status ----
VIOLATIONS=""
if [ "$HEAD_MOVED" = true ]; then
  VIOLATIONS="${VIOLATIONS}implementer-moved-head
"
  # Never let a HEAD move go out with only a flag on it. The field everyone reads is
  # touchedFiles; the field that says a commit happened is git.headMoved; and a reader who
  # resolves that contradiction the wrong way concludes "nothing happened".
  add_note "HEAD moved: the implementer committed $COMMITS_AHEAD commit(s) — see $COMMITS_FILE and git.commits. touchedFiles and the diff are taken against the PRE-RUN HEAD ($HEAD_BEFORE), so the work is still shown here; it is also already in history. The relay landed nothing: 'git reset --soft $HEAD_BEFORE' returns it to the working tree if you want to review it as a diff. That is your call, not the relay's."
  if [ "$COMMITS_AHEAD" -eq 0 ]; then
    add_note "HEAD moved but no commit is ahead of the pre-run HEAD — history was rewritten, reset, or checked out rather than appended. What the implementer did is NOT reconstructable from '$HEAD_BEFORE..$HEAD_AFTER'; read 'git reflog' before concluding anything."
  fi
  if [ "$TOUCHED_COUNT" -eq 0 ]; then
    add_note "HEAD moved and the delta is still empty: the work is not in the tree and not in the commit range either. Treat this as lost-until-proven-otherwise, not as a no-op."
  fi
fi
[ "$RO_VIOLATION" = "true" ] && VIOLATIONS="${VIOLATIONS}read-only-run-changed-the-tree
"
if [ "$EXIT_CODE" -eq 0 ] && [ "$MODE" = "write" ] && [ "$TOUCHED_COUNT" -eq 0 ] && [ "$HEAD_MOVED" = false ]; then
  VIOLATIONS="${VIOLATIONS}exit-zero-with-empty-diff
"
  add_note "exit 0 with an empty diff usually means a headless permission refusal, not 'nothing needed doing'. Read stdout.log before believing the no-op."
fi

if [ "$TIMED_OUT" -eq 1 ]; then STATUS="timeout"
elif [ -n "$VIOLATIONS" ]; then STATUS="failed"
elif [ "$EXIT_CODE" -eq 0 ]; then STATUS="completed"
else STATUS="failed"; fi

# ---- session id: generic scan, never invented ----
SESSION_ID=""
SESSION_SRC="null"
if [ -s "$STDOUT_LOG" ]; then
  SESSION_ID="$(grep -oE '"(session_?[iI]d|thread_?[iI]d|chat_?[iI]d|conversation_?[iI]d)"[[:space:]]*:[[:space:]]*"[^"]+"' "$STDOUT_LOG" 2>/dev/null \
                | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' || true)"
  [ -n "$SESSION_ID" ] && SESSION_SRC='"stdout-json-scan"'
fi
RESUME_HINT="null"
if [ -n "$SESSION_ID" ] && [ -n "$P_RESUME" ]; then
  RESUME_HINT="\"$(json_str "$0 --implementer=$IMPL --repo=$REPO --session=$SESSION_ID --brief=<delta-brief>")\""
fi

FINAL_MESSAGE="$(tail -c 4000 "$STDOUT_LOG" 2>/dev/null | json_escape_stream || true)"

# ---------------------------------------------------------------------------
# result.json — contract delegate-relay.result.v1
# ---------------------------------------------------------------------------
{
  printf '{\n'
  printf '  "contract": "%s",\n' "$CONTRACT"
  printf '  "relay": "scripts/delegate-relay.sh",\n'
  printf '  "relayVersion": "%s",\n' "$RELAY_VERSION"
  printf '  "startedAt": "%s",\n' "$STARTED_AT"
  printf '  "finishedAt": "%s",\n' "$FINISHED_AT"
  printf '  "durationSeconds": %s,\n' "$RUN_SECONDS"
  printf '  "implementer": "%s",\n' "$(json_str "$IMPL")"
  printf '  "implementerPath": "%s",\n' "$(json_str "$IMPL_PATH")"
  printf '  "implementerVersion": "%s",\n' "$(json_str "$IMPL_VERSION")"
  printf '  "mode": "%s",\n' "$MODE"
  printf '  "argv": ['
  for a in "${ARGV[@]}"; do argv_display "$a"; printf '\n'; done | json_array_stream
  printf '],\n'
  printf '  "status": "%s",\n' "$STATUS"
  printf '  "exitCode": %s,\n' "$EXIT_CODE"
  printf '  "signal": %s,\n' "$SIGNAL"
  printf '  "timedOut": %s,\n' "$([ "$TIMED_OUT" -eq 1 ] && echo true || echo false)"
  printf '  "repo": "%s",\n' "$(json_str "$REPO")"
  printf '  "selfTarget": %s,\n' "$SELF_TARGET"
  printf '  "git": {\n'
  printf '    "branch": "%s",\n' "$(json_str "$BRANCH")"
  printf '    "headBefore": "%s",\n' "$HEAD_BEFORE"
  printf '    "headAfter": "%s",\n' "$HEAD_AFTER"
  printf '    "headMoved": %s,\n' "$HEAD_MOVED"
  printf '    "diffBase": "%s",\n' "$DIFF_BASE"
  printf '    "commitsAhead": %s,\n' "$COMMITS_AHEAD"
  printf '    "commits": ['
  json_array_stream < "$COMMITS_FILE"
  printf '],\n'
  printf '    "committedFiles": ['
  json_array_stream < "$COMMIT_FILES"
  printf '],\n'
  printf '    "dirtyAtStart": %s,\n' "$([ "$DIRTY_AT_START" -eq 1 ] && echo true || echo false)"
  printf '    "stagedAtEnd": %s,\n' "$STAGED_AT_END"
  printf '    "fingerprintComplete": %s\n' "$([ "$FP_INCOMPLETE" -eq 1 ] && echo false || echo true)"
  printf '  },\n'
  printf '  "touchedCount": %s,\n' "$TOUCHED_COUNT"
  printf '  "touchedFiles": ['
  json_array_stream < "$OUT/touched.txt"
  printf '],\n'
  printf '  "readOnly": {\n'
  printf '    "requested": %s,\n' "$([ "$READ_ONLY" -eq 1 ] && echo true || echo false)"
  printf '    "enforcement": "%s",\n' "$RO_ENFORCEMENT"
  printf '    "helpProbe": "%s",\n' "$HELP_PROBE"
  printf '    "violation": %s,\n' "$RO_VIOLATION"
  # shellcheck disable=SC2016  # "$HOME" here is JSON prose, not a shell expansion
  printf '    "coverage": "git-visible paths inside the repo only; ignored files, $HOME writes, network calls and perfectly-reverted edits are outside this claim"\n'
  printf '  },\n'
  printf '  "commitShim": "%s",\n' "$([ "$COMMIT_SHIM" -eq 1 ] && echo enabled || echo disabled)"
  printf '  "shimDenials": %s,\n' "$SHIM_DENIALS"
  printf '  "sessionId": %s,\n' "$([ -n "$SESSION_ID" ] && printf '"%s"' "$(json_str "$SESSION_ID")" || echo null)"
  printf '  "sessionIdSource": %s,\n' "$SESSION_SRC"
  printf '  "resumeHint": %s,\n' "$RESUME_HINT"
  printf '  "gates": ['
  printf '%s' "$GATES" | json_array_stream
  printf '],\n'
  printf '  "violations": ['
  printf '%s' "$VIOLATIONS" | json_array_stream
  printf '],\n'
  printf '  "notes": ['
  printf '%s' "$NOTES" | json_array_stream
  printf '],\n'
  printf '  "artifacts": {\n'
  printf '    "brief": "%s",\n' "$(json_str "$BRIEF_FILE")"
  printf '    "diff": "%s",\n' "$(json_str "$DIFF_FILE")"
  printf '    "diffLines": %s,\n' "$DIFF_LINES"
  printf '    "commits": "%s",\n' "$(json_str "$COMMITS_FILE")"
  printf '    "stdout": "%s",\n' "$(json_str "$STDOUT_LOG")"
  printf '    "stderr": "%s"\n' "$(json_str "$STDERR_LOG")"
  printf '  },\n'
  printf '  "finalMessage": "%s",\n' "$FINAL_MESSAGE"
  # `committed` is the RELAY's own statement about the RELAY. It is not a claim that
  # nothing was committed — git.headMoved is the field that answers that question.
  printf '  "committed": false,\n'
  printf '  "landedBy": null\n'
  printf '}\n'
} > "$RESULT_JSON"

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
if [ "$QUIET" -eq 1 ]; then
  echo "$RESULT_JSON"
else
  echo
  echo "status:        $STATUS · exit $EXIT_CODE · ${RUN_SECONDS}s"
  echo "HEAD:          $HEAD_AFTER $([ "$HEAD_MOVED" = true ] && echo '(MOVED — the implementer committed; that decision was not its to make)' || echo '(unchanged)')"
  if [ "$HEAD_MOVED" = true ]; then
    echo "commits:       $COMMITS_AHEAD ahead of the pre-run HEAD ($COMMITS_FILE)"
    [ "$COMMITS_AHEAD" -gt 0 ] && sed 's/^/                 /' "$COMMITS_FILE"
    echo "               the diff and touched list below are taken against the PRE-RUN HEAD,"
    echo "               so the work is still shown — and also already in history. To review"
    echo "               it as a diff instead, YOU run:  git reset --soft $HEAD_BEFORE"
  fi
  echo "touched:       $TOUCHED_COUNT file(s)"
  [ "$TOUCHED_COUNT" -gt 0 ] && sed 's/^/                 /' "$OUT/touched.txt"
  echo "read-only:     enforcement=$RO_ENFORCEMENT violation=$RO_VIOLATION"
  [ "$SHIM_DENIALS" -gt 0 ] && echo "shim denials:  $SHIM_DENIALS (see $SHIM_LOG)"
  [ -n "$SESSION_ID" ] && echo "session:       $SESSION_ID"
  echo "diff:          $DIFF_FILE ($DIFF_LINES lines)"
  echo "result:        $RESULT_JSON"
  echo
  # "Nothing was committed" is only true when nothing was. Saying it over a moved HEAD is
  # the same lie `committed: false` used to tell next to `headMoved: true`.
  if [ "$HEAD_MOVED" = true ]; then
    echo "The relay committed nothing — the implementer did. Re-run the gates yourself, read"
    echo "the whole diff, and decide what happens to those $COMMITS_AHEAD commit(s). Not the relay's call."
  else
    echo "Nothing was committed. Re-run the gates yourself, read the whole diff, then commit."
  fi
fi

[ "$STATUS" = "completed" ] && exit 0
exit 1
