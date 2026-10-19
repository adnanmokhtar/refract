#!/usr/bin/env python3
"""ownership-guard.py — one writer per artifact: artifact-ownership.sh's engine (PreToolUse Edit|Write|MultiEdit).

Usage:  ownership-guard.py guard < <hook JSON>         (what artifact-ownership.sh runs)
        ownership-guard.py who <path> [--agent=<agent_type>]   (dry run: would this write be allowed?)
        ownership-guard.py roles                       (print the effective role → globs map)
Exit:   0 allowed · 2 denied (stderr names the rule and the right owner; Claude Code feeds it back)
        1 usage error

WHY. A run's artifacts are checked by someone other than their author (templates/snippets/
run-ledger.md § 2): requirements by the requirements-reviewer, design by the architecture-reviewer,
the contract by plan-critic and the lock. That only means something if the author is who the table
says. A product-analyst that "helpfully" edits the code, an implementer that adjusts design.md to
match what it built, or an orchestrator that writes the requirements itself and then dispatches a
reviewer to agree with them, all collapse author and judge into one. Claude Code puts the
subagent's `agent_type` in every hook input fired inside it (absent = the main session), so the
writer column becomes a rule.

THE RULES (role → writable globs; a `!glob` entry excludes):
  known role         may write ONLY its globs (product-analyst, architect, test-engineer, ux-designer,
                     doc-writer, platform-engineer — DEFAULT_ROLES below), with or without a run.
  judge              writes nothing: verifier, requirements-reviewer, architecture-reviewer,
                     plan-critic, test-reviewer, and any agent_type ending in -reviewer / -auditor.
                     (Their records are written by persist-*.sh hooks, not by a tool.)
  any other agent    (implementer, general-purpose, pack agents) may write anything EXCEPT the
                     role-owned and orchestrator-owned files of a run (ai/runs/*/requirements.md …
                     run.json, ledger.md, plan.md, handoff.json) and .claude/holdouts/**.
  main session       unrestricted at T1 or with no open run. While an OPEN run (ai/runs/*/run.json
                     status "open") is T2 or T3: (a) no role-owned run artifact and no holdout — those
                     are dispatched to their owner; (b) while that run is in P6, no source either —
                     only ai/**, docs/**, .claude/plans/**, *.md at the repo root and CHANGELOG*; the
                     orchestrator dispatches @implementer one plan.md task at a time.
  `my-plugin:architect` and `architect` are the same role (refract_records.agent_base).

PROJECT OVERRIDE: .claude/artifact-ownership.json, same shape as the defaults —
  {"roles": {"<role>": ["<glob>", "!<glob>", …]}, "judges": ["<agent_type>", …]}
A role listed there REPLACES that role's default globs; a judge listed there is added. Globs are
risk-tier.py's (`**/` any depth, `*` one segment, a glob without `/` matches the file name anywhere).

HONEST LIMITS:
  * Tool-path only, like test-lock.sh: a Bash write (`echo > design.md`) is not seen here. The
    record that counts is the artifact's author in .claude/evidence/edits.jsonl and the reviewer's
    check of who wrote what; gate-check.py and CI are the backstop.
  * No python3 → artifact-ownership.sh allows the write with a one-line note (fail OPEN): this guard
    protects a process, not a secret, and a hard block on every edit for a missing interpreter would
    get the hook removed.
  * "Open run" is read from run.json at the moment of the edit; an orchestrator that leaves a run
    open across unrelated work keeps the T2+ restrictions on — close or abandon it.
"""
import fnmatch
import glob as globmod
import importlib.util
import json
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import refract_records as rr
except ImportError:
    rr = None

TEST_GLOBS = ["**/test/**", "**/tests/**", "**/__tests__/**", "**/spec/**", "**/*.test.*", "**/*.spec.*",
              "**/*_test.*", "**/test_*.py", "e2e/**", "cypress/**", "playwright/**", "integration_test/**",
              "**/androidTest/**", "**/*Tests/**"]
DEFAULT_ROLES = {
    "product-analyst": ["ai/runs/*/requirements.md", "ai/runs/*/quality-attributes.md", "ai/product/**"],
    "architect": ["ai/runs/*/design.md", "ai/runs/*/quality-attributes.md", "ai/runs/*/threat-model.md",
                  "ai/decisions/**", "ai/runtime/perf-budgets.md"],
    "test-engineer": ["ai/runs/*/test-plan.md", "ai/runs/*/acceptance.json", ".claude/holdouts/**"] + TEST_GLOBS,
    "ux-designer": ["ai/runs/*/ux.md", "ai/design/**"],
    "doc-writer": ["docs/**", "CHANGELOG*", "README*", "CONTRIBUTING*", "mkdocs.yml", "mkdocs.yaml",
                   "docusaurus.config.*", "sidebars.*", "SUMMARY.md", "ai/**", "!ai/runs/**"],
    "platform-engineer": [".github/**", ".gitlab-ci.yml", "infra/**", "terraform/**", "k8s/**", "helm/**",
                          "Dockerfile*", "docker-compose*", "ai/runtime/**", "ai/runs/*/release.md"],
}
DEFAULT_JUDGES = ["verifier", "requirements-reviewer", "architecture-reviewer", "plan-critic", "test-reviewer"]
# run artifact → its owner (the name a deny message tells the orchestrator to dispatch)
ROLE_OWNED = {"requirements.md": "product-analyst", "quality-attributes.md": "product-analyst (draft) / architect",
              "ux.md": "ux-designer", "design.md": "architect", "threat-model.md": "architect",
              "test-plan.md": "test-engineer", "acceptance.json": "test-engineer"}
ORCH_OWNED = {"run.json": "the orchestrator (main session)", "ledger.md": "the orchestrator (main session)",
              "plan.md": "the orchestrator (main session)", "handoff.json": "precompact-handoff.sh (hook)"}
MAIN_P6_ALLOWED = ["ai/**", "docs/**", ".claude/plans/**", "CHANGELOG*"]


def _glob_match():
    try:
        spec = importlib.util.spec_from_file_location("risk_tier", os.path.join(HERE, "risk-tier.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.glob_match
    except Exception:                                    # risk-tier.py absent: fnmatch (no ** semantics)
        return lambda g, p: fnmatch.fnmatch(p if "/" in g else os.path.basename(p), g)


glob_match = _glob_match()


def agent_base(t):
    return rr.agent_base(t) if rr else (t or "").rsplit(":", 1)[-1]


def matches(globs, rel):
    pos = [g for g in globs if not g.startswith("!")]
    neg = [g[1:] for g in globs if g.startswith("!")]
    return any(glob_match(g, rel) for g in pos) and not any(glob_match(g, rel) for g in neg)


def load_config(repo):
    roles = {k: list(v) for k, v in DEFAULT_ROLES.items()}
    judges = list(DEFAULT_JUDGES)
    p = os.path.join(repo, ".claude", "artifact-ownership.json")
    if os.path.isfile(p):
        try:
            with open(p, encoding="utf-8") as fh:
                cfg = json.load(fh)
            for k, v in (cfg.get("roles") or {}).items():
                if isinstance(v, list):
                    roles[k] = [str(x) for x in v]
            judges += [str(x) for x in cfg.get("judges") or []]
        except (ValueError, AttributeError) as e:
            print("artifact-ownership: .claude/artifact-ownership.json ignored (%s) — defaults apply" % e, file=sys.stderr)
    return roles, judges


def is_judge(role, judges):
    return role in judges or role.endswith("-reviewer") or role.endswith("-auditor")


def run_file(rel):
    """ai/runs/<id>/<name> → name (top level of a run dir only), else None."""
    parts = rel.split("/")
    return parts[3] if len(parts) == 4 and parts[0] == "ai" and parts[1] == "runs" else None


def open_runs(repo):
    out = []
    for p in sorted(globmod.glob(os.path.join(repo, "ai", "runs", "*", "run.json"))):
        try:
            with open(p, encoding="utf-8") as fh:
                r = json.load(fh)
        except (OSError, ValueError):
            continue
        if isinstance(r, dict) and r.get("status") == "open":
            out.append({"run_id": r.get("run_id") or os.path.basename(os.path.dirname(p)),
                        "tier": r.get("tier"), "phase": r.get("phase")})
    return out


def deny(msg):
    print("Blocked by artifact-ownership: " + msg, file=sys.stderr)
    return 2


def decide(repo, rel, agent_type):
    roles, judges = load_config(repo)
    role = agent_base(agent_type)
    name = run_file(rel)
    if role:
        if is_judge(role, judges):
            return deny("`%s` is a judge — a judge writes nothing; its JSON record is persisted by a SubagentStop "
                        "hook. Return your findings in your final message." % role)
        if role in roles:
            if matches(roles[role], rel):
                return 0
            owner = ROLE_OWNED.get(name) or ORCH_OWNED.get(name)
            return deny("@%s writes only %s; %s is outside its role%s. Return NEEDS_INPUT naming the change instead."
                        % (role, ", ".join(roles[role][:6]) + (" …" if len(roles[role]) > 6 else ""), rel,
                           " (it belongs to %s)" % owner if owner else ""))
        if name in ROLE_OWNED or name in ORCH_OWNED:
            owner = ROLE_OWNED.get(name) or ORCH_OWNED[name]
            return deny("%s is written only by %s (one writer per artifact — run-ledger.md § 2). If it is wrong, "
                        "report SPEC_CONFLICT with the line and the evidence." % (rel, owner))
        if glob_match(".claude/holdouts/**", rel):
            return deny("%s is a holdout acceptance test — only @test-engineer writes holdouts, and the builder "
                        "never sees them." % rel)
        return 0
    # the main session
    hot = [r for r in open_runs(repo) if r.get("tier") in ("T2", "T3")]
    if not hot:
        return 0
    if name in ROLE_OWNED:
        return deny("run %s is %s and open — the orchestrator does not write %s; dispatch @%s with a delegation "
                    "brief (one writer per artifact)." % (hot[0]["run_id"], hot[0]["tier"], rel,
                                                          ROLE_OWNED[name].split(" ")[0]))
    if glob_match(".claude/holdouts/**", rel):
        return deny("run %s is %s and open — holdouts are written by @test-engineer only." % (hot[0]["run_id"], hot[0]["tier"]))
    p6 = [r for r in hot if r.get("phase") == "P6"]
    if p6:
        if matches(MAIN_P6_ALLOWED, rel) or ("/" not in rel and rel.endswith(".md")):
            return 0
        return deny("T2+ P6: the orchestrator never edits source; dispatch @implementer (one task from plan.md). "
                    "Run %s (%s) is in P6; %s is source." % (p6[0]["run_id"], p6[0]["tier"], rel))
    return 0


HOLDOUT_READERS = {"test-engineer", "verifier"}


def read_guard(hook):
    """Holdouts stay out of the builder's view (proposal §5.2): a subagent other than the test-engineer
    that writes them and the verifier that runs them may not Read, Grep or Glob .claude/holdouts/.
    The main session is not restricted here (it never builds at T3, where holdouts exist)."""
    agent = agent_base(hook.get("agent_type") or "")
    if not agent or agent in HOLDOUT_READERS:
        return 0
    ti = hook.get("tool_input") or {}
    probe = " ".join(str(ti.get(k) or "") for k in ("file_path", "path", "pattern", "glob"))
    if ".claude/holdouts" in probe or probe.strip().startswith("holdouts/"):
        return deny("@%s may not read .claude/holdouts/ — holdout acceptance tests are kept out of the builder's "
                    "view and run only by @verifier at P12. Build to acceptance.json and design.md § Interfaces." % agent)
    return 0


def rel_path(repo, path):
    ab = os.path.abspath(os.path.join(repo, path) if not os.path.isabs(path) else path)
    real_repo, real = os.path.realpath(repo), os.path.realpath(ab)
    if not (real == real_repo or real.startswith(real_repo + os.sep)):
        return None
    return os.path.relpath(real, real_repo).replace(os.sep, "/")


def toplevel():
    if rr:
        return rr.toplevel(".")
    return os.path.abspath(".")


def main(argv):
    if not argv:
        print(__doc__.split("\n\n")[0] + "\n" + __doc__.split("\n\n")[1], file=sys.stderr)
        return 1
    repo = toplevel()
    if not repo:
        return 0 if argv[0] == "guard" else 1
    if argv[0] == "guard":
        try:
            hook = json.loads(sys.stdin.read() or "{}")
        except ValueError:
            return 0
        if hook.get("tool_name") in ("Read", "Grep", "Glob"):
            return read_guard(hook)
        if hook.get("tool_name") not in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
            return 0
        ti = hook.get("tool_input") or {}
        path = ti.get("file_path") or ti.get("notebook_path") or ""
        rel = rel_path(repo, path) if path else None
        if not rel:
            return 0
        return decide(repo, rel, hook.get("agent_type") or "")
    if argv[0] == "who" and len(argv) >= 2:
        agent = next((a.split("=", 1)[1] for a in argv[2:] if a.startswith("--agent=")), "")
        rel = rel_path(repo, argv[1])
        rc = decide(repo, rel, agent) if rel else 0
        print("%s: %s for %s" % (argv[1], "allowed" if rc == 0 else "DENIED", agent or "the main session"))
        return rc
    if argv[0] == "roles":
        roles, judges = load_config(repo)
        print(json.dumps({"roles": roles, "judges": judges}, indent=2))
        return 0
    print("ownership-guard: unknown command %s" % argv[0], file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
