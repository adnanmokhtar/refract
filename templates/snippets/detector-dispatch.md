---
purpose: How a whole-repo audit command decides a detector is installed, loads it, and runs it with or without a shell. One rule for both install shapes (copied into `.claude/skills/`, or loaded as a plugin).
imported-by: every pack's whole-repo audit command (Phase 2 dispatch) and commands/audit.md.
---

# Detector dispatch — load the detector, then run it or read it

A pack reaches a project in one of two shapes: **copied** (`.claude/skills/<name>/SKILL.md`) or
**loaded as a plugin** (the skill is listed as `<plugin>:<name>`, e.g. `refract-database:transaction-scan`,
and lives in the plugin's own directory; `.claude/skills/<name>/` does not exist). Both are installed.

1. **Installed** = the Skill tool lists the skill, bare (`<name>`) or namespaced (`<plugin>:<name>`),
   **or** `.claude/skills/<name>/SKILL.md` exists. Only when both fail is it `not run (not installed)`.
   A shell probe of `.claude/skills/` that prints `absent` settles nothing on its own.
2. **Load each in-scope detector** with the Skill tool — in scope means its signal is present (the
   command's dispatch table) or the run is whole-repo and its surface exists. A detector whose surface
   is absent is `N/A (<reason>)` and is not loaded.
3. **With a shell**, run its pre-flight and bundled scripts at the path the skill states, resolved
   against the skill's **base directory** — the Skill tool prints it when the skill loads. Never assume
   `.claude/skills/<name>/`: a command line written `.claude/skills/<name>/scripts/x` means
   `<base directory>/scripts/x`. A sub-agent handed a detector gets the skill name and that base
   directory, never the bare path.
4. **Without a shell**, apply the loaded detector by hand: its *Read the code* questions and its
   BAD/GOOD blocks against every in-scope file, with its finding condition and severity rule unchanged.
   Its ledger row reads `checked (manual)` and names the scripts that did not run — never
   `not installed`, never `not run` for a detector that was loaded and read.
5. **Load only in-scope detectors.** Loading every skill a pack ships costs context and finds nothing
   the in-scope set would not.

Ledger states: `checked` (scripts ran) · `checked (manual)` (loaded, applied by hand) ·
`N/A (<reason>)` (surface absent) · `not run (not installed)` (rule 1 failed both ways).
