#!/usr/bin/env python3
"""Inject `agent: build` (or `agent: plan` for read-only commands) into every
`.opencode/commands/<name>.md` frontmatter that's missing it. Without this,
OpenCode routes commands to its default mode (Chat / Plan) which doesn't have
write/shell access — so user types /optimize and gets "I would do X, Y, Z"
instead of execution.

Idempotent: skips files that already have `agent:` set.
"""

import re
import sys
from pathlib import Path

DRY_RUN = "--apply" not in sys.argv

TARGETS = [
    Path("/Users/mac/Workspace/Projects/sahlcart/tenant-portal-v2"),
    Path("/Users/mac/Workspace/Projects/sahlcart/claude-v2"),
]

# Same tool-class set as the Kimi subagent script — keep consistent.
AUDIT_ONLY = {
    "audit", "audit-business", "audit-distributed-tx", "audit-iam",
    "a11y-audit", "i18n-audit", "perf-audit", "security-audit", "db-audit",
    "cost-audit", "design-review", "trace-flow", "log-tail", "secret-scan",
    "detect-drift", "compare-v1", "find-module", "threat-model",
    "profile-perf", "dependency-vuln-check", "bundle-perf",
    "check-health", "migration-status", "migration-gate", "migration-doctor",
    "align-status", "align-gate", "review-changes", "review-module",
}
PLAN_ONLY = {
    "migration-plan", "migration-replan", "align-plan", "align-replan",
    "refine-prompt", "draft-phase-adrs", "learn-from-task",
    "analyze-module", "analyze-task", "scaffold-project",
    "refresh-knowledge", "expand-task",
}


def agent_for(name):
    if name in AUDIT_ONLY or name in PLAN_ONLY:
        return "plan"
    return "build"


def patch_frontmatter(text, name):
    """Insert `agent: <value>` line into existing YAML frontmatter. Handles
    closed frontmatter (---...---) AND unclosed frontmatter (just ---...blank line)
    AND files with no frontmatter at all. Skip if `agent:` already present."""
    agent = agent_for(name)

    if not text.startswith("---\n"):
        # No frontmatter at all — add one.
        return f"---\nagent: {agent}\n---\n\n{text}"

    # Try the closed-frontmatter pattern first
    m = re.match(r"^(---\n)(.*?)(\n---\n)", text, re.DOTALL)
    if m:
        fm_open, fm_body, fm_close = m.groups()
        if re.search(r"^agent:\s*\S", fm_body, re.MULTILINE):
            return None  # already has agent:
        new_fm_body = fm_body + f"\nagent: {agent}"
        return fm_open + new_fm_body + fm_close + text[m.end():]

    # Unclosed frontmatter pattern — `---\n` followed by `key: value` lines
    # then a blank line and the markdown body. Detect via:
    # lines after `---` that look like YAML (`key: value` or YAML comment)
    # until a line that doesn't match. The frontmatter ends there.
    lines = text.split("\n")
    if lines[0] != "---":
        return None  # shouldn't happen given startswith check

    yaml_pattern = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*:\s")
    indent_pattern = re.compile(r"^\s+")  # YAML continuation lines (indented)
    fm_end_idx = None
    for i in range(1, len(lines)):
        line = lines[i]
        if line == "---":
            # Found explicit close (shouldn't happen since first regex would match)
            fm_end_idx = i
            break
        if line == "" or line.startswith("#"):
            # Blank line OR markdown heading — frontmatter ended here informally
            fm_end_idx = i
            break
        if not yaml_pattern.match(line) and not indent_pattern.match(line):
            # Non-YAML, non-indented line — frontmatter ended
            fm_end_idx = i
            break

    if fm_end_idx is None:
        return None  # couldn't determine frontmatter end

    fm_body_lines = lines[1:fm_end_idx]
    fm_body = "\n".join(fm_body_lines)

    # Check if agent already set
    if re.search(r"^agent:\s*\S", fm_body, re.MULTILINE):
        return None

    # Reconstruct: ---\n<fm_body>\nagent: X\n---\n<rest>
    rest = "\n".join(lines[fm_end_idx:])
    new_text = f"---\n{fm_body}\nagent: {agent}\n---\n{rest}"
    return new_text


def main():
    print(f"Mode: {'DRY RUN' if DRY_RUN else 'APPLY'}")
    print()

    total_patched = 0
    total_skipped = 0

    for proj in TARGETS:
        cmd_dir = proj / ".opencode" / "commands"
        if not cmd_dir.exists():
            print(f"SKIP {proj.name} — no .opencode/commands/")
            continue

        print(f"=== {proj.name} ===")
        patched = []
        already_ok = []

        for md in sorted(cmd_dir.glob("*.md")):
            name = md.stem
            text = md.read_text(encoding="utf-8")
            patched_text = patch_frontmatter(text, name)

            if patched_text is None:
                already_ok.append(name)
                continue

            if not DRY_RUN:
                md.write_text(patched_text, encoding="utf-8")
            patched.append((name, agent_for(name)))

        print(f"  Patched: {len(patched)}")
        if patched:
            counts = {}
            for n, a in patched:
                counts[a] = counts.get(a, 0) + 1
            print(f"    by agent class: {counts}")
            print(f"    sample: {', '.join(n for n, _ in patched[:5])}{'...' if len(patched) > 5 else ''}")
        print(f"  Already had agent: {len(already_ok)}")
        print()

        total_patched += len(patched)
        total_skipped += len(already_ok)

    print(f"Total: {total_patched} patched, {total_skipped} skipped")
    if DRY_RUN:
        print("\nDRY RUN. Re-run with --apply.")


if __name__ == "__main__":
    main()
