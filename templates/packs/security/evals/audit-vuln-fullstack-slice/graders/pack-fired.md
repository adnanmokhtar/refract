---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?(?:ci-security-scan|data-exposure-scan|dependency-vuln-check|deps-audit|file-access-scan|iac-scan|injection-scan|llm-trust-scan|logic-race-scan|mcp-server-scan|mobile-security-scan|sast-scan|secret-scan|secret-scan-method|security-audit|security-fix|ssrf-scan|threat-model|threat-model-method|xss-scan)"'
min: 1
arm: with-only
---

A skill or command of the security pack ran: the pack-fired indicator, never part of the score.
