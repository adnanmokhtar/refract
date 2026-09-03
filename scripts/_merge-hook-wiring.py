#!/usr/bin/env python3
"""_merge-hook-wiring.py — add MISSING baseline hook entries to a target settings.json.

Additive only. Called by apply-baseline-sync.sh --apply --wire-hooks.

The file being edited holds the user's permissions and their own hook entries, so the rules are
narrow on purpose:

  * a hook already referenced by BASENAME is left alone, however they wrote the command. A project
    wiring `bash .claude/hooks/post-edit-check.sh` where we ship
    `cd "${CLAUDE_PROJECT_DIR:-.}" && .claude/hooks/post-edit-check.sh` keeps its own form; matching
    on the full string would have added a second entry and run the hook twice.
  * nothing outside `hooks` is read or written — `permissions` is copied through untouched.
  * a matcher group is reused when one with the same matcher already exists, so events do not
    accumulate near-duplicate groups on repeated runs.
  * the write is atomic (temp file + replace), so an interrupted run cannot truncate settings.json.

Exit 0 on success (including "nothing to add"), 1 on any failure — the caller then leaves the file
alone rather than guessing.
"""
import json
import os
import re
import sys
import tempfile

HOOK_RE = re.compile(r"\.claude/hooks/([a-z0-9-]+\.sh)")


def basenames(cmd):
    return set(HOOK_RE.findall(cmd or ""))


def wired_in(settings):
    """Every hook basename the target already references, across every event."""
    seen = set()
    for groups in (settings.get("hooks") or {}).values():
        for g in groups or []:
            for e in g.get("hooks") or []:
                seen |= basenames(e.get("command"))
    return seen


def main():
    if len(sys.argv) != 3:
        print("usage: _merge-hook-wiring.py <baseline-settings> <target-settings>", file=sys.stderr)
        return 1
    base_path, tgt_path = sys.argv[1], sys.argv[2]
    try:
        with open(base_path) as f:
            base = json.load(f)
        with open(tgt_path) as f:
            tgt = json.load(f)
    except (OSError, ValueError) as exc:
        print(f"cannot read settings: {exc}", file=sys.stderr)
        return 1

    have = wired_in(tgt)
    tgt_hooks = tgt.setdefault("hooks", {})
    added = 0

    for event, groups in (base.get("hooks") or {}).items():
        for g in groups or []:
            matcher = g.get("matcher")
            for entry in g.get("hooks") or []:
                names = basenames(entry.get("command"))
                if not names or names & have:
                    continue
                dest_groups = tgt_hooks.setdefault(event, [])
                target_group = next(
                    (x for x in dest_groups if x.get("matcher") == matcher), None
                )
                if target_group is None:
                    target_group = {"hooks": []}
                    if matcher is not None:
                        target_group["matcher"] = matcher
                    dest_groups.append(target_group)
                target_group.setdefault("hooks", []).append(dict(entry))
                have |= names
                added += 1

    if added == 0:
        return 0

    d = os.path.dirname(os.path.abspath(tgt_path))
    fd, tmp = tempfile.mkstemp(dir=d, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(tgt, f, indent=2)
            f.write("\n")
        os.replace(tmp, tgt_path)
    except OSError as exc:
        os.path.exists(tmp) and os.unlink(tmp)
        print(f"write failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
