---
track: security
purpose: Security review, secret hygiene, auth/authorization correctness.
essentials:
  agents: [security-auditor]
  commands: [security-audit]
  skills: [secret-scan]
  rules: [security-principles]
  ai-patterns: [auth-flow]
---

# Security — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: security-auditor is the broad reviewer; auth-reviewer is a sub-specialty kept out of minimal.
- commands: security-audit is the single must-have entry point; deeper drills come with the full pack.
- skills: secret-scan catches the most common, highest-impact accident (committed credentials).
- rules: security-principles is the single rules file in the pack.
- ai-patterns: auth-flow is the foundational pattern most apps need to model correctly.
