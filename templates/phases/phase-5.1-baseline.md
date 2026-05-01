---
phase: 5
sub-phase: "5.1"
name: baseline-and-inventory
applies-to-modes: [all]
inputs: [phase-4-outputs, expected-baseline-file-list, planned-emit-list]
outputs: [missing-baseline-list, inventory-diff-report]
exit-criteria: every required baseline file present (rule A19); inventory diff matches plan
imported-by: templates/phases/phase-5-verify.md
contains-sub-sections: [5.1 baseline, 5.2 inventory diff (was conflated as "5.1+5.2"), 5.8 surface uncertainty]
---

### Required-baseline check

Beyond per-track minimums, verify the baseline list defined in Phase 4.0 ("Required baseline files"). Same retry-then-halt pattern: if missing, retry the baseline copy, then halt if still failing.

### Inventory diff

Diff Phase 4.2.a pre-flight inventory (expected file list) against actual file system state:
- **Missing files**: in pre-flight, not on disk. Trigger retry.
- **Extra files**: on disk, not in pre-flight. Investigate (intentional generation? silent extra?).
- **Match**: report total file count + GO.

**5.8 Surface uncertainty**:
- Every `[INFERRED]`, `[UNKNOWN]`, `[CONFLICT]` from Phase 2 + 3 surfaces in the final report under "Open questions / decisions blocked".
- Every `_UNKNOWN_` placeholder in `ai/project-goals.md` etc. surfaces here too.
- These are not bugs — they're explicit deferrals the user must resolve.

**Report**:
```
✅ <project-name> — <mode>
📍 <cwd>
🏗  <shape>

Detected stack: <...>
Detected signals: <...>

Applied:
  Tracks: <list with file counts>
  References: <list>
  Domain tooling: <list>
  Tool adapters: <list — e.g. "claude-code, cursor, aider">

Generated (new agents saved to packs for reuse):
  <list>

Skipped (filter + merge):
  <summary with counts>

Knowledge base:
  <created / updated / left-alone counts>

Tool configs written (per adapter, full artifact translation):
  claude-code: .claude/ (rules: N, commands: X, agents: A, skills: S, hooks: H), CLAUDE.md
  <tool-N>:    <rules: <n> · commands: <x> · agents: <a> · skills: <s> · hooks fallback: git+docs>

Parity disclosure: ai/references/tool-parity.md (what's native vs translated vs not-possible per tool)

Next steps:
  1. <concrete — "cd api && pnpm install" or similar>
  2. Review ai/runbooks/phase-1-mvp-plan.md Day 1
  3. git init + initial commit
  4. (Optional) Customize CLAUDE.md section X

Outstanding questions / flags:
  <anything the user needs to decide>
```

