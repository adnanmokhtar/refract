#!/usr/bin/env bash
# lint-phase-dag.sh — a phase's declared `inputs:` must have a declared producer.
#
# WHY. Every file under templates/phases/ opens with a machine-readable contract:
#
#     inputs:  [.claude/<extraction artifact>, .claude/<deep-extract artifact>, …]
#     outputs: [rewritten Project-specific blocks (managed markers preserved); …]
#     applies-to-modes: [REFINE]
#
# Those three lines are the pipeline's only declared wiring — which phase hands what to which,
# and under which mode. Before this gate, `grep -rn 'outputs:' scripts/` matched exactly one
# script, and that one only greps for the word. Nothing had ever joined an input to an output.
#
# What that let through, measured at the commit this landed: phase-2-profile.md:16 states in
# prose that Phase 2 produces four extraction artifacts under `.claude/` — naming each one —
# and its own `outputs:` line named none of them, saying `deep-extraction (REFINE only)`
# instead. Three of the four are consumed BY NAME in a later phase's `inputs:`. So the declared
# graph could not answer "who writes this file" for the artifacts the REFINE path is built on,
# while the prose two lines below the frontmatter answered it plainly. The frontmatter is what
# a loader would read.
#
# (This header deliberately names no artifact file. lint-handoffs.sh treats any `_<name>.md`
# token appearing in a script as a file that script WRITES, so documenting a filename here
# would enter it into that gate's writer set and shift its nearest-name matching. Two of its
# baselined findings stopped reproducing, and one unrelated prose name went red, when an
# earlier draft of this comment spelled the four out.)
#
# THE TWO CHECKS
#
#   [1] check_declared_producer  (FAIL)
#       Every FILE-shaped `inputs:` entry names a file some phase declares in `outputs:`.
#       Matched on basename, because the two sides legitimately spell the path differently
#       (a bare path as an output, the same path suffixed `previous version` as an input).
#
#   [2] check_mode_reachability  (FAIL)
#       The producing phases' `applies-to-modes` must cover the consuming phase's. A file
#       written only under REFINE and consumed by a phase declaring `[all]` is a hole that
#       opens only in the modes nobody tests by hand. EXEMPT: an input carrying its own inline
#       qualifier — `extracted-idioms (AUTHOR only)`, `… (REFINE only)`, `… when <x>` — which
#       is the author disclosing the conditionality rather than asserting it away.
#
# WHAT IS NOT CHECKED, and why. Roughly two thirds of all declared entries are VOCABULARY, not
# files: `mode`, `selected-tracks`, `approved-plan`, `phase-4-outputs`, `hard-rules`. Joining
# those would mean deciding that Phase 3's output `plan.md` satisfies Phase 4's input
# `approved-plan`, and that Phase 2's `detected-tracks` satisfies Phase 4's `selected-tracks` —
# judgements about English, not about the tree. A gate that guesses there reports drift on every
# honest rename. They are counted and disclosed in the reach line instead.
#
# Ordering is NOT checked either: phase-5.5-quality legitimately consumes its own PRIOR run's
# output, so "the producer must come earlier" is false as stated and would fire on correct code.
#
# Usage:  lint-phase-dag.sh [--repo-root=<dir>] [--quiet]
# Exit:   1 on any FAIL; 0 otherwise.
# Notes:  bash 3.2 (macOS) compatible. Parsing is Python (stdlib only) because the entry lists
#         carry commas inside parentheses — `(per-artifact density score: name, path, signal,
#         total)` is ONE entry — and a `tr ',' '\n'` split tears it into four.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
# Absolute BEFORE the cd: the path is handed to python below, and a relative --repo-root
# would resolve against the new CWD and silently glob an empty tree — a gate that finds
# no phases prints PASS.
REPO_ROOT="$(cd -P "$REPO_ROOT" 2>/dev/null && pwd)" || { echo "FAIL  no such repo root"; exit 2; }
cd "$REPO_ROOT" || exit 1

command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not available"; exit 1; }

python3 - "$REPO_ROOT" "$QUIET" <<'PY'
import os, re, sys, glob

ROOT, QUIET = sys.argv[1], sys.argv[2] == "1"
ALL_MODES = {"CREATE", "ENHANCE", "REFRESH", "REFINE", "UPGRADE"}
FILE_RE = re.compile(r'\.?[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:md|json|jsonl)')
# A parenthetical the author used to disclose that the input is conditional.
QUALIFIER_RE = re.compile(r'\((?=[^)]*\b(?:only|when|if|optional)\b)[^)]*\)', re.I)


def split_entries(raw):
    """Split `a, b (x, y), c` on top-level commas and semicolons only."""
    out, buf, depth = [], "", 0
    for ch in raw:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch in ",;" and depth <= 0:
            out.append(buf.strip()); buf = ""
        else:
            buf += ch
    if buf.strip():
        out.append(buf.strip())
    return [e for e in out if e]


def frontmatter(path):
    fm, started = [], False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("---"):
                if started:
                    break
                started = True
                continue
            if started:
                fm.append(line.rstrip("\n"))
    return fm


def field(fm, key):
    for i, line in enumerate(fm):
        if line.startswith(key + ":"):
            val = line[len(key) + 1:]
            val = val.split("#", 1)[0] if key == "applies-to-modes" else val
            return val.strip()
    return None


def bracketed(val):
    if val is None:
        return None
    m = re.search(r'\[(.*)\]', val, re.S)
    return m.group(1) if m else val


phases = []
for path in sorted(glob.glob(os.path.join(ROOT, "templates/phases/phase-*.md"))):
    rel = os.path.relpath(path, ROOT)
    fm = frontmatter(path)
    ins, outs = field(fm, "inputs"), field(fm, "outputs")
    if ins is None and outs is None:
        continue
    modes_raw = bracketed(field(fm, "applies-to-modes")) or "all"
    modes = set()
    for tok in re.split(r'[,\s]+', modes_raw):
        tok = tok.strip().strip("[]").upper()
        if tok in ALL_MODES:
            modes.add(tok)
        elif tok == "ALL":
            modes |= ALL_MODES
    if not modes:
        modes = set(ALL_MODES)
    phases.append({
        "file": rel,
        "modes": modes,
        "inputs": split_entries(bracketed(ins) or ""),
        "outputs": split_entries(bracketed(outs) or ""),
    })

# basename -> set of modes that can produce it. An output carrying its own mode qualifier —
# `deep-extraction (REFINE only)` — narrows to that mode rather than inheriting the whole
# phase's. Without this narrowing check [2] can never fire: every REFINE-only artifact would
# read as produced in all of its phase's modes, which is the exact over-claim being hunted.
produced = {}
for p in phases:
    for entry in p["outputs"]:
        named = {m for m in ALL_MODES if re.search(r'\(\s*%s[^)]*\bonly\b' % m, entry, re.I)}
        modes = (p["modes"] & named) if named else p["modes"]
        for f in FILE_RE.findall(entry):
            produced.setdefault(os.path.basename(f), set()).update(modes)

fails, checked, vocab = [], 0, 0
for p in phases:
    for entry in p["inputs"]:
        files = FILE_RE.findall(entry)
        if not files:
            vocab += 1
            continue
        for f in files:
            base = os.path.basename(f)
            checked += 1
            if base not in produced:
                fails.append("FAIL  [1] %s declares input `%s` — no phase declares it in outputs:"
                             % (p["file"], f))
                continue
            if QUALIFIER_RE.search(entry):
                continue
            missing = p["modes"] - produced[base]
            if missing:
                fails.append("FAIL  [2] %s runs in %s and consumes `%s`, produced only in %s — "
                             "unreachable in %s"
                             % (p["file"], ",".join(sorted(p["modes"])), f,
                                ",".join(sorted(produced[base])), ",".join(sorted(missing))))

print("=== lint-phase-dag ===")
print("Repo: %s\n" % ROOT)
if not QUIET:
    print("[1] every file-shaped input has a phase that declares producing it")
    print("[2] the producer's modes cover the consumer's modes\n")
for line in fails:
    print(line)
print("\nreach: %d phases with a declared contract · %d file-shaped inputs checked · "
      "%d distinct produced files" % (len(phases), checked, len(produced)))
print("       not checked: %d vocabulary inputs (`mode`, `approved-plan`, `phase-4-outputs`, …)"
      % vocab)
if fails:
    print("\nFAIL  %d broken link(s) in the declared phase graph." % len(fails))
    sys.exit(1)
print("PASS  every declared file input has a declared producer, reachable in every consuming mode.")
PY
