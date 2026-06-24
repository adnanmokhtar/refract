#!/usr/bin/env python3
"""One-shot conversion: Kimi command-as-skill → command-as-subagent.

For each project, finds `.kimi/skills/<name>/SKILL.md` whose <name> matches
a command in claude-config's `commands/` or `templates/packs/*/commands/`.
Converts to `.kimi/subagents/<name>.yaml` with an EXECUTE NOW preamble,
then moves the original skill directory to `.kimi/_legacy-skills-backup/`
for easy revert.

True knowledge skills (extract-v1-contract, parity-test-generate, etc.)
that are NOT commands are left alone.
"""

import re
import shutil
import sys
from pathlib import Path

DRY_RUN = "--apply" not in sys.argv

# Source repo = this checkout (scripts/ -> repo root). No hardcoded path.
CLAUDE_CONFIG = Path(__file__).resolve().parent.parent
# Targets: pass one or more consuming-project dirs as CLI args.
#   usage: migrate-kimi-commands-to-subagents.py [--apply] <project-dir> [<project-dir> ...]
TARGETS = [Path(a) for a in sys.argv[1:] if not a.startswith("-")]
if not TARGETS:
    sys.exit("usage: migrate-kimi-commands-to-subagents.py [--apply] <project-dir> [<project-dir> ...]")

AUDIT_ONLY = {
    "audit", "audit-business", "audit-distributed-tx", "audit-iam",
    "a11y-audit", "i18n-audit", "perf-audit", "security-audit", "db-audit",
    "cost-audit", "design-review", "trace-flow", "log-tail", "secret-scan",
    "detect-drift", "compare-v1", "find-module", "threat-model",
    "profile-perf", "dependency-vuln-check", "bundle-perf",
    "check-health", "migration-status", "migration-gate", "migration-doctor",
    "align-status", "align-gate", "review-changes",
}
PLAN_ONLY = {
    "migration-plan", "migration-replan", "align-plan", "align-replan",
    "refine-prompt", "draft-phase-adrs", "learn-from-task",
    "analyze-module", "analyze-task", "scaffold-project",
    "refresh-knowledge", "expand-task",
}


def get_commands():
    cmds = set()
    for p in (CLAUDE_CONFIG / "commands").glob("*.md"):
        if not p.name.startswith("_"):
            cmds.add(p.stem)
    for p in CLAUDE_CONFIG.glob("templates/packs/*/commands/*.md"):
        if not p.name.startswith("_"):
            cmds.add(p.stem)
    # Workspace-baseline commands (migration-doctor, project-map, sync-contract, etc.)
    for p in CLAUDE_CONFIG.glob("templates/workspace-baseline/**/commands/*.md"):
        if not p.name.startswith("_"):
            cmds.add(p.stem)
    return cmds


def tools_for(cmd):
    if cmd in AUDIT_ONLY:
        return ["read"]
    if cmd in PLAN_ONLY:
        return ["read", "write"]
    return ["read", "write", "shell"]


def extract_description(skill_text, cmd):
    """Pull the description: field from frontmatter. Collapse to one line."""
    # Find the description: line and capture until the next field-like prefix
    # or until two consecutive newlines (end of YAML block).
    m = re.search(
        r'^description:\s*(.+?)(?=\n[A-Za-z_][A-Za-z0-9_-]*:\s|\n---\s*\n|\n\s*\n|\Z)',
        skill_text,
        re.MULTILINE | re.DOTALL,
    )
    if m:
        desc = re.sub(r'\s+', ' ', m.group(1).strip())
        if len(desc) > 240:
            desc = desc[:237] + "..."
        return desc
    return f"Run the /{cmd} workflow."


def make_subagent_yaml(cmd, skill_text):
    desc = extract_description(skill_text, cmd)
    desc_safe = desc.replace('\\', '\\\\').replace('"', '\\"')
    tools = tools_for(cmd)

    # Indent the entire skill body for the YAML block scalar (2 spaces).
    indented = "\n".join("  " + line if line else "" for line in skill_text.splitlines())

    tools_yaml = "\n".join(f"  - {t}" for t in tools)

    return f'''description: "Run the /{cmd} workflow. {desc_safe}"

system_prompt: |
  # EXECUTE NOW

  You are the `{cmd}` subagent. When dispatched, do NOT summarise the
  workflow below and ask the user what to do — immediately begin executing
  against the scope passed to you (default: whole repo if no scope given).
  Drive the workflow to completion or to an explicit halt; report results,
  not intent.

  Tool whitelist for this subagent: {", ".join(tools)} — operate within these limits.

  ---

  ## Source workflow (translated from `commands/{cmd}.md`)

{indented}

tools:
{tools_yaml}
'''


def main():
    commands = get_commands()
    print(f"Source repo command set: {len(commands)} commands")
    print(f"Mode: {'DRY RUN (no changes)' if DRY_RUN else 'APPLY (writing changes)'}")
    print()

    grand_converted = 0
    grand_kept = 0

    for target in TARGETS:
        skills_dir = target / ".kimi" / "skills"
        subagents_dir = target / ".kimi" / "subagents"
        backup_dir = target / ".kimi" / "_legacy-skills-backup"

        print(f"=== {target.name} ===")

        if not skills_dir.exists():
            print("  SKIP — no .kimi/skills/")
            continue

        if not DRY_RUN:
            subagents_dir.mkdir(parents=True, exist_ok=True)
            backup_dir.mkdir(parents=True, exist_ok=True)

        converted = []
        kept_as_skill = []

        all_skill_dirs = sorted([d.name for d in skills_dir.iterdir() if d.is_dir()])
        for name in all_skill_dirs:
            skill_md = skills_dir / name / "SKILL.md"
            if not skill_md.exists():
                continue

            if name not in commands:
                kept_as_skill.append(name)
                continue

            skill_text = skill_md.read_text(encoding="utf-8")
            yaml_content = make_subagent_yaml(name, skill_text)
            subagent_path = subagents_dir / f"{name}.yaml"

            if not DRY_RUN:
                subagent_path.write_text(yaml_content, encoding="utf-8")
                # Move original skill directory to backup
                shutil.move(str(skills_dir / name), str(backup_dir / name))

            converted.append(name)

        print(f"  Converted to subagent: {len(converted)}")
        if converted:
            print(f"    {', '.join(converted[:10])}{', ...' if len(converted) > 10 else ''}")
        print(f"  Kept as skill (true reference): {len(kept_as_skill)}")
        if kept_as_skill:
            print(f"    {', '.join(kept_as_skill)}")
        print()

        grand_converted += len(converted)
        grand_kept += len(kept_as_skill)

    print(f"Total: {grand_converted} converted, {grand_kept} kept as skills")
    if DRY_RUN:
        print("\nThis was a DRY RUN. Re-run with --apply to make changes.")


if __name__ == "__main__":
    main()
