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
- agents: security-auditor is the broad reviewer (OWASP Top 10:2025); auth-reviewer, api-security-reviewer (OWASP API Top 10), tenant-isolation-reviewer, llm-security-reviewer (OWASP LLM Top 10 — for AI/model-calling apps), and data-privacy-reviewer (PII/PHI data-flow + GDPR/PDPL/CCPA — gated on compliance/pii/payment) are signal-gated sub-specialists kept out of minimal.
- commands: security-audit is the single must-have entry point; deeper drills come with the full pack.
- skills: secret-scan catches the most common, highest-impact accident (committed credentials). deps-audit (CVEs, EPSS/KEV-triaged, reachability), threat-model (the STRIDE/LINDDUN primitive `/threat-model` applies), and ssrf-scan (URL-taint detector: user-URL → outbound fetch, metadata-IP/DNS-rebinding, open redirector, + security-specific upload risks) ship in standard mode. **All three scanning skills are dispatched by `/security-audit` Phase 2 by signal** — they are the executors behind its secret / dependency / SSRF buckets. secret-scan and threat-model each pair with a same-named command: the skill is the primitive (detect / classify), the command is the session that closes (rotate, scrub, persist / ADRs, residual risk, re-audit triggers).
- rules: security-principles is the single rules file in the pack.
- ai-patterns: auth-flow is the foundational pattern most apps need to model correctly (its password-hashing parameters are sourced to the OWASP cheat sheet by URL, not hard-coded). zero-trust (boundary → what the caller presents → what the receiver verifies → the probe that proves it) + tenant-isolation (security-lens invariant, the three concrete leak shapes, and an engine-conditional below-app layer; backs @tenant-isolation-reviewer, cross-links backend multi-tenancy for impl) are signal-gated on multi-tenant/payment/compliance. The auditor maps to **OWASP Top 10:2025** (A03 Supply-Chain Failures + A10 Exceptional-Conditions are new; SSRF folded into A01; Injection incl. XSS is A05). Build/release supply-chain execution (image CVE scan / SBOM / signing) is dispatched to the devops pack, not asserted here.
