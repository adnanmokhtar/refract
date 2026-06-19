---
track: performance
purpose: Identify and fix performance bottlenecks at the request and query level.
essentials:
  agents: [performance-optimizer]
  commands: [perf-audit]
  skills: [profile-endpoint]
  rules: [performance-principles]
  ai-patterns: []
---

# Performance — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: performance-optimizer is the universal entry point and the minimal agent; caching-architect ships in standard mode (cache-strategy work only) and is kept out of minimal.
- commands: perf-audit is the broad ranked-findings sweep — the minimal command; profile-perf (one-path deep-dive) and bundle-perf (web bundle / Core Web Vitals) ship in standard mode and are kept out of minimal.
- skills: profile-endpoint targets the most common ask ("why is this endpoint slow?"); n-plus-one-scan is a sub-skill kept out of minimal.
- rules: performance-principles is the single rules file in the pack.
- ai-patterns: none essential — `lazy-loading.md` ships in standard mode and applies only when a frontend framework is detected; minimal mode skips it.
