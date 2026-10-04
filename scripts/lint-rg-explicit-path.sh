#!/usr/bin/env bash
# lint-rg-explicit-path.sh — every `rg` an artifact tells an agent to run names what it searches.
#
# WHY. Given no path, ripgrep searches the working directory only when stdin is a terminal or
# /dev/null. When stdin is a pipe — a heredoc, `bash -s`, a hook, some agent shells — it searches
# STDIN instead. Measured on 2026-10-01: the same pre-flight grep returned the repo's hits from an
# interactive shell, zero hits with `echo | rg …`, and hung until the 120 s timeout in a subagent
# shell. Zero hits is the dangerous case: a security detector reports "checked, nothing found" for
# a class it never searched. 57 commands across 10 skill/agent files had the shape, including 31
# that ended in an exclusion array (`"${X[@]}"`) and so looked as if they had a path.
#
# A second rule rides along: a multi-root `$ROOTS` written unquoted is one string in zsh (the macOS
# default shell), so rg searches a single path that does not exist and exits 2 — zero hits again.
# Probes expand it as the array "${ROOTS[@]}".
#
# RULE. A line in a templates/**/*.md file that starts with `rg ` must carry a positional path
# after its pattern (`.`, a directory, `$ROOTS`, …) unless it reads a pipe on purpose (it follows
# `|`), uses `--files` with a path, or takes its pattern from `-e`/`-f` and names a path. A quoted
# array expansion such as `"${X[@]}"` holds flags, not a path, and does not count.
#
# Usage:  lint-rg-explicit-path.sh [--repo-root=<dir>]
# Exit:   1 if any command lacks a path; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$REPO_ROOT" || exit 2

git ls-files -z --cached --others --exclude-standard 'templates/*.md' 'templates/**/*.md' 'commands/*.md' | python3 -c '
import sys, shlex, re
VAL = {"-g","--glob","--iglob","-t","--type","-T","--type-not","-e","--regexp","-A","-B","-C",
       "-m","--max-count","-f","--file","--type-add","-r","--replace","--max-depth","-M",
       "--max-columns","-j","--threads","--sort","--sortr","--engine","--encoding","-E"}
ARRAY = re.compile(r"^\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]\}$")
def missing_path(cmd):
    if cmd.rstrip().endswith("\\"):
        return False                       # continued line: judged by a human, not here
    # cut at the first UNQUOTED pipe, redirect, `&&`, `;` or comment — a quoted `>` is pattern text
    q, end = None, len(cmd)
    for i, ch in enumerate(cmd):
        if q:
            if ch == q and cmd[i - 1] != "\\":
                q = None
            continue
        if ch in "\x27\x22":
            q = ch
            continue
        if ch in "|;>" or cmd.startswith("&&", i) or (ch == "#" and i and cmd[i - 1] == " "):
            end = i - 1 if ch == ">" and i and cmd[i - 1] == "2" else i
            break
    try:
        cut = shlex.split(cmd[:end], posix=True)
    except ValueError:
        return False
    if not cut or cut[0] != "rg":
        return False
    pos, has_e, files = [], False, False
    i = 1
    while i < len(cut):
        t = cut[i]
        if t in ("-e", "--regexp", "-f", "--file"):
            has_e = True
        if t == "--files":
            files = True
        if t in VAL:
            i += 2
            continue
        if t.startswith("-") and t != "-":
            i += 1
            continue
        if not ARRAY.match(t) or re.search(r"ROOT|PATH|DIR", t):
            pos.append(t)                  # "${ROOTS[@]}" holds paths; "${X[@]}" holds flags
        i += 1
    need = 1 if (has_e or files) else 2
    return len(pos) < need
bad = 0
for path in sys.stdin.read().split("\0"):
    if not path:
        continue
    try:
        lines = open(path, encoding="utf-8").read().split("\n")
    except OSError:
        continue
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if not s.startswith("rg "):
            continue
        if missing_path(s):
            bad += 1
            print(f"  {path}:{n}: {s[:120]}")
        elif re.search(r"(?<![{\w])\$ROOTS\b", s):
            bad += 1
            print(f"  {path}:{n}: unquoted $ROOTS — use \"${{ROOTS[@]}}\" (a string does not split in zsh): {s[:90]}")
if bad:
    print(f"::error::{bad} rg command(s) name no search path — add `.` (or the directory) after the pattern; "
          "without one, rg reads stdin under a pipe and returns nothing")
    sys.exit(1)
print("rg-explicit-path: every rg names its search path")
'
