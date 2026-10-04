# Project rules

The five foundational rules below load every session on their own — Claude Code loads every
`.claude/rules/*.md` without `paths:` at launch, whether or not this file names it. The imports
list the always-on set so it can be reviewed in one place; removing a line here unloads nothing.
Enforcement is mechanical where it can be: the hooks in `.claude/settings.json`, the Stop gate
(`.claude/scripts/gate-check.py` via `verify-gate.sh`), and the `refract-gates` CI job when
`/setup-project` installed one (shadow mode until a gate earns block). The rest is review —
each rule's `## Enforcement` says which.

@.claude/rules/read-before-write.md
@.claude/rules/read-codebase-deeply.md
@.claude/rules/think-simplify-surgical.md
@.claude/rules/code-quality.md
@.claude/rules/engineering-baseline.md

Session bootstrap: read `ai/_session-digest.md` first (Tier 1). See `.claude/GUIDE.md`
for the full `.claude/` surface.
