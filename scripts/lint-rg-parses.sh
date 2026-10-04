#!/usr/bin/env bash
# lint-rg-parses.sh — every `rg` an artifact prescribes actually runs: its regex parses and its
# --type names exist.
#
# WHY. A detector grep that ripgrep rejects prints one line to stderr, exits 2 and returns zero
# hits — which an agent reads as "checked, nothing found". Measured on 2026-10-02 across the
# templates: `--type tsx` in four frontend files (ripgrep has no `tsx` type; `ts` already covers
# *.tsx), and a money-as-float probe whose regex had an unopened group, so the BLOCKER it exists to
# find could never fire. None of the existing gates executed a pattern; they only read prose.
#
# HOW. Each `rg` line inside a fenced block (first pipeline segment only) runs in an EMPTY temp
# directory with stdin closed and every array variable bound to `.`. Pattern and type errors are
# raised before any file is read, so an empty tree is enough and nothing in the repo is searched.
# Lines carrying a command substitution or a backtick are skipped — running them would run other
# programs — and counted, so the skip is visible.
#
# Usage:  lint-rg-parses.sh [--repo-root=<dir>]
# Exit:   1 if any prescribed rg fails to parse; 0 otherwise.

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

command -v rg >/dev/null 2>&1 || { echo "rg-parses: SKIPPED — ripgrep not installed"; exit 0; }
cd "$REPO_ROOT" || exit 2
EMPTY="$(mktemp -d "${TMPDIR:-/tmp}/rg-parses.XXXXXX")"
trap 'rm -rf "$EMPTY"' EXIT

git ls-files -z --cached --others --exclude-standard 'templates/*.md' 'templates/**/*.md' 'commands/*.md' \
  | EMPTY="$EMPTY" python3 -c '
import os, re, subprocess, sys
empty = os.environ["EMPTY"]
def first_segment(cmd):
    q = None
    for i, ch in enumerate(cmd):
        if q:
            if ch == q and cmd[i - 1] != "\\":
                q = None
            continue
        if ch in "\x27\x22":
            q = ch
            continue
        if ch in "|;" or cmd.startswith("&&", i) or (ch == "#" and i and cmd[i - 1] == " "):
            return cmd[:i]
        if ch == ">" :
            return cmd[:i - 1] if i and cmd[i - 1] == "2" else cmd[:i]
    return cmd
bad, ran, skipped = 0, 0, 0
for path in sys.stdin.read().split("\0"):
    if not path:
        continue
    try:
        lines = open(path, encoding="utf-8").read().split("\n")
    except OSError:
        continue
    inb = False
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("```"):
            inb = not inb
            continue
        if not inb or not s.startswith("rg ") or s.endswith("\\"):
            continue
        seg = first_segment(s).strip()
        if "$(" in seg or "`" in seg or "<(" in seg:
            skipped += 1
            continue
        # every array expansion becomes `.`; any other $VAR becomes empty (bash default)
        seg = re.sub(r"\"?\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]\}\"?", ".", seg)
        try:
            p = subprocess.run(["bash", "-c", seg], cwd=empty, stdin=subprocess.DEVNULL,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=20)
        except subprocess.TimeoutExpired:
            bad += 1
            print(f"  {path}:{n}: timed out (reads stdin?) — {s[:100]}")
            continue
        ran += 1
        # a literal path absent from the empty tree is expected (IO error); a pattern, type,
        # glob or flag rejection is the defect
        fatal = ("regex parse error", "unrecognized file type", "error parsing glob", "unrecognized flag",
                 "unexpected argument", "invalid value", "requires a value", "PCRE2")
        text = p.stderr
        err = [l for l in text.splitlines() if any(f in l for f in fatal)] or \
              ([l for l in text.splitlines() if l.startswith("error:")] if "regex parse error" in text else [])
        if p.returncode == 2 and err:
            bad += 1
            print(f"  {path}:{n}: {err[0][:110]}\n      {s[:120]}")
if bad:
    print(f"::error::{bad} prescribed rg command(s) fail before searching anything — a detector that errors reads as zero hits")
    sys.exit(1)
print(f"rg-parses: {ran} prescribed rg commands parse ({skipped} with command substitution not executed)")
'
