#!/usr/bin/env python3
"""gen-baseline-hashes.py — record every version this repo has ever shipped of each baseline file.

WHY. `apply-baseline-sync.sh` cannot tell two situations apart, and they need opposite answers:

    the target file is an OLDER version of ours   → update it; the user never touched it
    the target file was EDITED by the user        → keep it; it is theirs

Both look "different from the current baseline", so the script treated both as user content and
kept them. Measured consequence: a project installed before a fix never receives it. Demonstrated
with the command-injection repair in `notify.sh` — `apply-baseline-sync.sh --apply` printed
`KEEP-OURS` and exited 0 while the vulnerable file stayed exactly as it was.

The `<!-- setup-project:managed -->` region mechanism was meant to cover this. It cannot: ZERO of
the 101 baseline files carry a marker, so that branch has never once executed.

WHAT THIS FIXES IT WITH. Git already knows every version of every baseline file this repo has
published. Recording their hashes turns an undecidable question into a lookup: a target whose
hash appears here is a version WE shipped, so replacing it loses nothing. A target whose hash
appears nowhere was written by someone, and is kept.

Under-recording is the safe direction: an unknown hash is treated as user content and preserved.
Over-recording is not, which is why the list comes from git history rather than from a heuristic.

Usage:  gen-baseline-hashes.py [--check]
        --check  exit 1 if the manifest is stale (for CI)
Output: templates/repo-baseline/.baseline-hashes  (sha256 per historical version, one per line)
"""
import hashlib
import os
import subprocess
import sys

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
os.chdir(ROOT)
BASE = "templates/repo-baseline"
OUT = os.path.join(BASE, ".baseline-hashes")


def historical_hashes(path):
    """Every distinct content hash this path has had, including the current one."""
    commits = subprocess.run(["git", "log", "--format=%H", "--", path],
                             capture_output=True, text=True).stdout.split()
    seen = set()
    for c in commits:
        blob = subprocess.run(["git", "show", "%s:%s" % (c, path)],
                              capture_output=True)
        if blob.returncode == 0:
            seen.add(hashlib.sha256(blob.stdout).hexdigest())
    if os.path.exists(path):
        with open(path, "rb") as fh:
            seen.add(hashlib.sha256(fh.read()).hexdigest())
    return sorted(seen)


def build():
    files = subprocess.check_output(["git", "ls-files", BASE], text=True).split()
    files = [f for f in files if os.path.basename(f) != ".baseline-hashes"]
    lines = [
        "# Every version of every baseline file this repo has shipped, by content hash.",
        "# GENERATED — regenerate with: python3 scripts/gen-baseline-hashes.py",
        "#",
        "# apply-baseline-sync.sh reads this to answer one question it otherwise cannot: is the",
        "# file in the target repo an OLD VERSION OF OURS (update it — the user never touched it)",
        "# or something a HUMAN WROTE (keep it)? A hash listed here is one we published.",
        "#",
        "# Under-recording is safe: an unknown hash is treated as user content and preserved.",
        "# Over-recording is not — which is why this comes from git history, never a heuristic.",
        "#",
        "# FORMAT  <path-relative-to-repo-baseline>  <sha256>",
        "",
    ]
    n = 0
    for f in sorted(files):
        rel = os.path.relpath(f, BASE)
        for h in historical_hashes(f):
            lines.append("%s  %s" % (rel, h))
            n += 1
    return "\n".join(lines) + "\n", len(files), n


def main():
    body, nfiles, nhashes = build()
    if "--check" in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ""
        if cur != body:
            print("FAIL  %s is stale — run: python3 scripts/gen-baseline-hashes.py" % OUT)
            return 1
        print("ok — %d files, %d recorded versions" % (nfiles, nhashes))
        return 0
    with open(OUT, "w") as fh:
        fh.write(body)
    print("wrote %s — %d files, %d recorded versions" % (OUT, nfiles, nhashes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
