#!/usr/bin/env python3
"""run-handoff.py — the typed handoff a run leaves before a compaction (precompact-handoff.sh's engine).

Usage:  run-handoff.py write < <PreCompact hook JSON>    (what precompact-handoff.sh runs)
Exit:   ALWAYS 0. A PreCompact hook that exits 2 BLOCKS the compaction (measured, Claude Code
        2.1.236), and a session that cannot compact is worse than one that compacts without a
        handoff — every failure here degrades to "no handoff", never to a blocked session.

WHY. A compaction replaces the conversation with a model-written summary, and the summary keeps
what the summariser thought mattered. A delivery run's state — which run, which tier, which phase,
what is still open, what the next move is — lives in files, so a script can write it exactly and
the summariser can be told what to keep. Claude Code joins every successful PreCompact hook's
trimmed STDOUT into the summariser's custom instructions (D7, measured on 2.1.236): this prints a
short "preserve" brief there, and writes the full record next to the run.

WRITES, for each OPEN run (ai/runs/*/run.json status "open"): ai/runs/<run>/handoff.json —
  {"schema":"refract/handoff/v1","run_id","at","trigger","intent","tier","phase","phases":{P:state},
   "loops","files_changed":[≤50, vs the merge-base + untracked, ai/runs/ and .claude/evidence/
   excluded],"open":[ledger.md ### Open lines],"plan":[ledger.md ## Plan lines],"next"}
`next` = the first phase the run's tier requires (.claude/templates/governance/tiers.json) that is
neither done nor skipped (P3 only with a frontend or mobile lane). With no open run: .claude/evidence/handoff.json with intent
"(no open run)", the branch and files_changed. session-start.sh prints the newest handoff back
when the session restarts with source "compact".

HONEST LIMITS:
  * A malformed run.json is skipped (no handoff for it); the summary is then all there is.
  * The brief is capped at 1,200 characters; the summariser may still drop parts of it. The
    handoff.json on disk is the record — session-start.sh re-prints it after the compaction.
"""
import datetime
import glob
import json
import os
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import refract_records as rr
except ImportError:
    rr = None

EXCLUDED = ("ai/runs/", ".claude/evidence/", ".claude/locks/")
CAP = 1200


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def git(repo, *args):
    try:
        r = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True, stdin=subprocess.DEVNULL)
        return r.stdout if r.returncode == 0 else None
    except OSError:
        return None


def files_changed(repo):
    if rr is None:
        return []
    try:
        paths = rr.touched(repo, rr.resolve_base(repo))
    except Exception:
        return []
    return [p for p in paths if not p.startswith(EXCLUDED)][:50]


def section(lines, heading, level):
    """Non-empty lines under `<level> heading` until the next heading of the same or higher level."""
    out, on = [], False
    for l in lines:
        s = l.strip()
        if s.startswith("#"):
            lvl = len(s) - len(s.lstrip("#"))
            if on and lvl <= level:
                break
            if lvl == level and s[lvl:].strip().lower().startswith(heading.lower()):
                on = True
                continue
            if on:
                continue
        elif on and s:
            out.append(s.lstrip("-* ").strip()[:200])
    return out[:10]


def load_tiers(repo):
    for p in (os.path.join(repo, ".claude", "templates", "governance", "tiers.json"),
              os.path.join(HERE, "..", "templates", "governance", "tiers.json")):
        try:
            with open(p, encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, ValueError):
            continue
    return {}


def next_phase(run, tiers):
    want = ((tiers.get("tiers") or {}).get(run.get("tier") or "") or {}).get("phases") or []
    states = run.get("phases") or {}
    skipped = {s.get("phase") for s in run.get("skips") or [] if isinstance(s, dict)}
    ui = bool(set(run.get("lanes") or []) & {"frontend", "mobile"})
    for p in want:
        if (states.get(p) or {}).get("state") in ("done", "skipped") or p in skipped:
            continue
        if p == "P3" and not ui:                            # tiers.json: P3 runs for a UI lane only
            continue
        name = ((tiers.get("phases") or {}).get(p) or {}).get("name", "")
        return ("%s %s" % (p, name)).strip()
    return "every phase the tier requires is done — close the run (outcome)"


def write(repo, hook):
    trigger = hook.get("trigger") or "unknown"
    tiers = load_tiers(repo)
    changed = files_changed(repo)
    briefs = []
    for p in sorted(glob.glob(os.path.join(repo, "ai", "runs", "*", "run.json"))):
        try:
            with open(p, encoding="utf-8") as fh:
                run = json.load(fh)
            if not isinstance(run, dict) or run.get("status") != "open":
                continue
            d = os.path.dirname(p)
            ledger = []
            lp = os.path.join(d, "ledger.md")
            if os.path.isfile(lp):
                with open(lp, encoding="utf-8", errors="replace") as fh:
                    ledger = fh.read().splitlines()
            h = {"schema": "refract/handoff/v1", "run_id": run.get("run_id") or os.path.basename(d), "at": now(),
                 "trigger": trigger, "intent": (run.get("request") or {}).get("text") or "",
                 "tier": run.get("tier"), "phase": run.get("phase"),
                 "phases": {k: (v or {}).get("state") for k, v in (run.get("phases") or {}).items()},
                 "loops": run.get("loops") or {}, "files_changed": changed,
                 "open": section(ledger, "Open", 3), "plan": section(ledger, "Plan", 2),
                 "next": next_phase(run, tiers)}
            out = os.path.join(d, "handoff.json")
            tmp = "%s.tmp.%d" % (out, os.getpid())
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(h, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
            os.replace(tmp, out)
            briefs.append(h)
        except Exception:                                   # one bad run never blocks the compaction
            continue
    if not briefs:
        ev = os.path.join(repo, ".claude", "evidence")
        try:
            if rr:
                ev = rr.evidence_dir(repo)
            else:
                os.makedirs(ev, exist_ok=True)
            branch = (git(repo, "branch", "--show-current") or "").strip() or "detached"
            h = {"schema": "refract/handoff/v1", "run_id": None, "at": now(), "trigger": trigger,
                 "intent": "(no open run)", "branch": branch, "files_changed": changed}
            with open(os.path.join(ev, "handoff.json"), "w", encoding="utf-8") as fh:
                json.dump(h, fh, indent=2)
                fh.write("\n")
        except Exception:
            return
        if changed:
            print(("Preserve for the continuation: no open delivery run; branch %s; files changed: %s"
                   % (branch, ", ".join(changed[:15])))[:CAP])
        return
    parts = []
    for h in briefs:
        s = "run %s (%s, phase %s); intent: %s; next: %s" % (h["run_id"], h["tier"], h["phase"], h["intent"][:160], h["next"])
        if h["open"]:
            s += "; open: " + " | ".join(h["open"][:3])
        if h["plan"]:
            s += "; plan: " + " | ".join(h["plan"][:3])
        parts.append(s)
    files = "; files: " + ", ".join(changed[:15]) if changed else ""
    brief = "Preserve for the continuation: " + " || ".join(parts) + files + \
        " — the full record is ai/runs/<run>/handoff.json; the run's state lives in run.json and ledger.md."
    print(brief[:CAP])


def main(argv):
    try:
        if argv[:1] != ["write"]:
            print("usage: run-handoff.py write < <PreCompact hook JSON>", file=sys.stderr)
            return 0
        raw = sys.stdin.read() if not sys.stdin.isatty() else ""
        try:
            hook = json.loads(raw or "{}")
        except ValueError:
            hook = {}
        repo = (rr.toplevel(".") if rr else None) or os.path.abspath(".")
        write(repo, hook if isinstance(hook, dict) else {})
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
