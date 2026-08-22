---
track: code-quality
purpose: General code review, refactoring, and pre-commit health gates.
essentials:
  agents: [code-reviewer, refactorer]
  commands: [pre-commit, check-health]
  skills: [dead-branch-scan, architectural-diagnosis, refactoring-sweep, test-shield, smoke-verify, change-brief]
  rules: [quality-principles, engineering-principles]
  ai-patterns: []
---

# Code-quality — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: code-reviewer is the daily reviewer; refactorer covers the most common follow-up action.
- commands: pre-commit is the per-change gate; check-health is the periodic project gate.
- skills: dead-branch-scan flags unreachable code — high-signal cleanup with low risk. test-shield + smoke-verify are the safety pair `/optimize` + `/audit` wire in (coverage gate before a behaviour-preserving fix; boot-check after) — shipped even in minimal installs so the sweeps can't ship un-pinned or non-booting changes. change-brief is the comprehension gate ("if you can't explain the code, it isn't yours" made mechanical — 5-field brief validated by `/pre-commit` + `/review-changes`).
- rules: quality-principles is the per-change discipline; engineering-principles is the project governance layer (both ship together — minimal install is incomplete without governance).
- ai-patterns: none in the minimal subset — both (`module-boundaries`, `ai-assisted-change`) are on-demand depth lifted OUT of the always-loaded rules, so a minimal install pays nothing for them and a standard install gets them. They are not essentials precisely because they are the material that did not need to be resident.
