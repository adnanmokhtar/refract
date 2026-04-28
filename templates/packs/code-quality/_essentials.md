---
track: code-quality
purpose: General code review, refactoring, and pre-commit health gates.
essentials:
  agents: [code-reviewer, refactorer]
  commands: [pre-commit, check-health]
  skills: [dead-branch-scan]
  rules: [quality-principles]
  ai-patterns: []
---

# Code-quality — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: code-reviewer is the daily reviewer; refactorer covers the most common follow-up action.
- commands: pre-commit is the per-change gate; check-health is the periodic project gate.
- skills: dead-branch-scan flags unreachable code — high-signal cleanup with low risk.
- rules: quality-principles is the single rules file in the pack.
- ai-patterns: none — this is a utility track and the pack ships without ai-patterns.
