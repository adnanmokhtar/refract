#!/usr/bin/env bash
# retire-merged-agents.sh — migrate an EXISTING install off agents that Phase 6 merged away
# (PLAN.md §6 "Migration of existing installs"). Run by run-preflight.sh on every non-CREATE mode
# (refresh / refine / enhance / upgrade), after the Phase-0 backup and before study-existing.sh, so
# the study sees the post-migration tree.
#
# WHY. A merged agent's template is gone, so nothing in the install pipeline ever touches its
# installed copy again: the old file keeps registering `@<old>` with knowledge that now lives in a
# lens, and — for a name another template still ships (testing's test-engineer → delivery's) — the
# stale copy sits on the name and install-claim.sh's "owner file, keep" rule (c) stops the live
# agent from ever arriving.
#
# THE RULE. For each scripts/_agent-merge-map.json entry with `status: merged` whose `old_name`
# file is in <target>/.claude/agents/:
#   * its `git hash-object` is in the entry's `known_blobs` (an unedited Refract copy) →
#       move it to .claude/backups/retired-agents/<old>.md, then
#       - the name is no longer shipped by any template and `to` differs → write a short stub agent
#         under the old name that says what replaced it (`renamed: @<old> → @<to> (lens <lens>)`),
#         kept for one release so old references resolve; the stub carries `refract:retired-stub`;
#       - the name is still shipped (another pack's live agent of that name) or `to` is the same
#         name → no stub: the live agent installs in its place on this run's copy step;
#   * it is a stub this script wrote (marker) → nothing;
#   * the name is still shipped and the copy matches a current template → nothing (a live agent);
#   * otherwise, if the name is no longer shipped → keep it, report
#       `EDITED retired agent <old>: its knowledge now lives in <lens>; merge your edits there by hand`;
#     if the name is still shipped → keep it (an owner's edit of the live agent; the merge-matrix
#     path owns it), say nothing.
# Every rename / EDITED line is appended once to .claude/_command-variants.md. A run that has
# nothing to do writes nothing (no mtime moves).
#
# Usage:  retire-merged-agents.sh <target-repo> [--apply]     (dry run without --apply)
# Exit:   0 done · 2 usage
set -uo pipefail
export LC_ALL=C
# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF_DIR="$(cd -P "$(dirname "$_ss")" && pwd)"; unset _ss _sd
TEMPLATES="$(cd "$SELF_DIR/.." && pwd)/templates"
MAP="$SELF_DIR/_agent-merge-map.json"

T="${1:-}"; APPLY=0
[ "${2:-}" = "--apply" ] && APPLY=1
[ -n "$T" ] && [ -d "$T" ] || { echo "usage: retire-merged-agents.sh <target-repo> [--apply]" >&2; exit 2; }
A="$T/.claude/agents"
[ -d "$A" ] || exit 0
[ -f "$MAP" ] || { echo "retire-merged-agents: $MAP missing — nothing migrated"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "retire-merged-agents: python3 missing — merged agents NOT migrated (re-run with python3)"; exit 0; }

python3 -I - "$MAP" "$TEMPLATES" "$T" "$APPLY" <<'PY'
import glob, hashlib, json, os, shutil, sys

map_path, templates, target, apply = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
agents_dir = os.path.join(target, ".claude", "agents")
backup_dir = os.path.join(target, ".claude", "backups", "retired-agents")
notes = os.path.join(target, ".claude", "_command-variants.md")
MARK = "refract:retired-stub"


def blob(path):
    data = open(path, "rb").read()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def shipped(name):
    """{blob id: template home} of every template that still ships an agent of this name."""
    pats = ["packs/*/agents/%s.md", "domains/*/agents/%s.md", "repo-baseline/.claude/agents/%s.md"]
    return {blob(p): os.path.relpath(os.path.dirname(os.path.dirname(p)), templates)
            for pat in pats for p in glob.glob(os.path.join(templates, pat % name))}


def lens_installed(lens):
    return ".claude/lenses/" + os.path.basename(lens) if lens else None


def note(line):
    have = open(notes, encoding="utf-8").read().splitlines() if os.path.isfile(notes) else []
    if line in have:
        return
    if apply:
        with open(notes, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")


def stub(old, to, lens):
    via = " with lens `%s`" % lens if lens else ""
    desc = "Retired name: dispatch @%s%s instead. Redirect kept for one release." % (to, " (lens %s)" % lens if lens else "")
    return ("---\nname: %s\ndescription: \"%s\"\ntools: Read\nmodel: haiku\n---\n"
            "<!-- %s to=%s lens=%s — written by retire-merged-agents.sh; removed next minor -->\n\n"
            "# %s (retired)\n\n"
            "Replaced by `@%s`%s (Refract Phase 6 merge; `scripts/_agent-merge-map.json`). Do not review under\n"
            "this name: reply `RETIRED — dispatch @%s%s` and stop. The old copy is in\n"
            "`.claude/backups/retired-agents/%s.md`.\n"
            % (old, desc, MARK, to, lens or "none", old, to, via, to, " with lens: %s" % lens if lens else "", old))


entries = [a for a in json.load(open(map_path, encoding="utf-8"))["agents"] if a.get("status") == "merged"]
by_name = {}
for a in entries:
    by_name.setdefault(a["old_name"], []).append(a)

acted = 0
for name in sorted(by_name):
    f = os.path.join(agents_dir, name + ".md")
    if not os.path.isfile(f):
        continue
    text = open(f, encoding="utf-8", errors="replace").read()
    if MARK in text:
        continue                                            # our own stub
    b = blob(f)
    live = shipped(name)
    if b in live:
        continue                                            # the current template of a still-shipped name
    hit = next((a for a in by_name[name] if b in a.get("known_blobs", [])), None)
    a = hit or by_name[name][0]
    to, lens = a.get("to"), lens_installed(a.get("lens"))
    if hit is None:
        if live:
            continue                                        # an owner's edit of a live agent: not ours
        line = "EDITED retired agent %s: its knowledge now lives in %s; merge your edits there by hand" % (
            name, lens or ("@" + to))
        print(line)
        note("- " + line)
        acted += 1
        continue
    make_stub = not live and to and to != name
    if make_stub:
        line = "renamed: @%s → @%s (lens %s)" % (name, to, lens or "none")
    else:
        line = "retired: @%s (%s copy) — the live @%s (%s) installs in its place when that pack is selected%s" % (
            name, os.path.dirname(os.path.dirname(a["old_path"])).replace("templates/", ""), name,
            ", ".join(sorted(set(live.values()))) or a.get("to_home") or "?",
            "; its knowledge is in %s read by @%s" % (lens, to) if lens and to != name else "")
    acted += 1
    if not apply:
        print("would retire: " + line)
        continue
    os.makedirs(backup_dir, exist_ok=True)
    dest = os.path.join(backup_dir, name + ".md")
    if os.path.exists(dest) and blob(dest) != b:
        dest = os.path.join(backup_dir, "%s.%s.md" % (name, b[:8]))
    if os.path.exists(dest):
        os.remove(f)
    else:
        shutil.move(f, dest)
    if make_stub:
        with open(f, "w", encoding="utf-8") as fh:
            fh.write(stub(name, to, lens))
    print(line)
    note("- " + line)

if acted == 0:
    print("retire-merged-agents: no merged agent installed — nothing to migrate")
elif not apply:
    print("retire-merged-agents: dry run — re-run with --apply to migrate")
PY
