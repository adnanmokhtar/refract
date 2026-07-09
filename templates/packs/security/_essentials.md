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
- ai-patterns: auth-flow is the foundational pattern most apps need to model correctly. zero-trust + tenant-isolation (security-lens invariant + review methodology; backs @tenant-isolation-reviewer, cross-links backend multi-tenancy for impl) are signal-gated on multi-tenant/payment/compliance. The auditor maps to **OWASP Top 10:2025** (A03 Supply-Chain Failures + A10 Exceptional-Conditions are new; SSRF folded into A01; Injection incl. XSS is A05). Build/release supply-chain execution (image CVE scan / SBOM / signing) is dispatched to the devops pack, not asserted here.
