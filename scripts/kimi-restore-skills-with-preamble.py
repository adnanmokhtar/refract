#!/usr/bin/env python3
"""Restore command-as-skill files from backup AND inject EXECUTE NOW preamble.

Pairs with migrate-kimi-commands-to-subagents.py:
- Subagents (already created) handle natural-language dispatch
- Skills (restored here, with imperative preamble) handle direct /skill:<name> invocation

Both primitives get the same EXECUTE NOW preamble so loading the skill OR
dispatching the subagent produces autonomous execution, not a stalled "what now?".
"""

import shutil
import sys
from pathlib import Path

DRY_RUN = "--apply" not in sys.argv

# Targets: pass one or more consuming-project dirs as CLI args.
#   usage: kimi-restore-skills-with-preamble.py [--apply] <project-dir> [<project-dir> ...]
TARGETS = [Path(a) for a in sys.argv[1:] if not a.startswith("-")]
if not TARGETS:
    sys.exit("usage: kimi-restore-skills-with-preamble.py [--apply] <project-dir> [<project-dir> ...]")


def make_preamble(name):
    return f"""<!-- EXECUTE NOW preamble — injected by migrate-kimi-commands. Do not edit this block. -->
> **Direct-invoke directive (read first when this skill loads, e.g. via `/skill:{name}`):**
>
> You are executing the `{name}` workflow. When this skill is loaded into context — by
> any means (`/skill:{name}`, agent dispatch, description match, or main agent request) —
> do NOT summarise the workflow below and ask the user what to do. Immediately begin
> executing against the scope the user named (default: the whole project if no scope given).
> Drive to completion or to an explicit halt; report results, not intent.
>
> This applies BEFORE the rest of the document. The body below is the workflow you execute.
<!-- /EXECUTE NOW preamble -->

"""


def inject_preamble(content, name):
    """Inject the preamble right after the YAML frontmatter (if present) or at the very top."""
    preamble = make_preamble(name)

    lines = content.splitlines(keepends=True)

    # Detect frontmatter: starts with --- on line 1
    if lines and lines[0].strip() == "---":
        # Find the closing ---
        for i, line in enumerate(lines[1:], 1):
            if line.strip() == "---":
                # Insert preamble after this line
                before = "".join(lines[: i + 1])
                after = "".join(lines[i + 1 :])
                # Add a blank line after frontmatter close if not already there
                if not after.startswith("\n"):
                    return before + "\n" + preamble + after
                return before + preamble + after.lstrip("\n")

        # Frontmatter never closed — treat whole thing as no-frontmatter
        return preamble + content

    # No frontmatter — preamble goes at the top
    return preamble + content


def main():
    print(f"Mode: {'DRY RUN' if DRY_RUN else 'APPLY'}")
    print()

    total_restored = 0

    for target in TARGETS:
        backup_dir = target / ".kimi" / "_legacy-skills-backup"
        skills_dir = target / ".kimi" / "skills"

        if not backup_dir.exists():
            print(f"SKIP {target.name} — no backup dir")
            continue

        print(f"=== {target.name} ===")

        if not DRY_RUN:
            skills_dir.mkdir(parents=True, exist_ok=True)

        restored = []

        for backup_subdir in sorted(backup_dir.iterdir()):
            if not backup_subdir.is_dir():
                continue
            name = backup_subdir.name
            skill_md_src = backup_subdir / "SKILL.md"
            if not skill_md_src.exists():
                continue

            dest_dir = skills_dir / name
            dest_md = dest_dir / "SKILL.md"

            original = skill_md_src.read_text(encoding="utf-8")
            patched = inject_preamble(original, name)

            if not DRY_RUN:
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest_md.write_text(patched, encoding="utf-8")
                # Copy any auxiliary files (scripts/, references/, assets/) - none expected
                for extra in backup_subdir.iterdir():
                    if extra.name == "SKILL.md":
                        continue
                    if extra.is_dir():
                        shutil.copytree(extra, dest_dir / extra.name, dirs_exist_ok=True)
                    else:
                        shutil.copy2(extra, dest_dir / extra.name)

            restored.append(name)

        print(f"  Restored with preamble: {len(restored)}")
        if restored:
            print(f"    {', '.join(restored[:8])}{', ...' if len(restored) > 8 else ''}")
        print()

        total_restored += len(restored)

    print(f"Total restored across all projects: {total_restored}")
    if DRY_RUN:
        print("\nDRY RUN. Re-run with --apply to write.")


if __name__ == "__main__":
    main()
