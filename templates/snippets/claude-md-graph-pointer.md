<!-- Composed into the `id=rule-imports` managed block of a target project's CLAUDE.md by
     scripts/wire-rule-imports.sh, and only when ~/.claude/scripts/build-graph.py is on disk.

     It lives here rather than as a string in that script for a reason the linter is right
     about: `lint-setup-contracts.sh` R13 forbids a runtime string rooting a remediation at a
     literal `~/.claude/scripts/`, because a script's own remediation must point at its resolved
     checkout. This text is not that — it is CONTENT written into another repo, read later by an
     agent working there, for which `~/.claude/scripts/` is the only portable route (the absolute
     checkout path would be wrong for every other machine on the team). Content belongs in a
     template; the rule stays strict for the scripts it is about.

     Four lines is the whole budget: this loads every turn. Details stay in .claude/GUIDE.md. -->

## Before changing a shared file

`python3 ~/.claude/scripts/build-graph.py --corpus=project --repo=. --who-breaks <path>`
answers "what breaks if I change this" from resolved imports, without opening a file —
the total and the per-hop shape first. An empty answer means NO EDGE RESOLVED, never
"safe to change". See `.claude/GUIDE.md` for `--neighbors`, `--path` and `--central`.
