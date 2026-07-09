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
- skills: profile-endpoint targets the most common ask ("why is this endpoint slow?"); n-plus-one-scan is a sub-skill kept out of minimal. `memory-leak-hunt` (heap-diff-over-time leak hunt) ships in standard mode — a specialist invoked only on a monotonically-growing heap, kept out of minimal. `web-vitals-field` (field CWV with attribution) ships in standard mode, frontend-framework-gated — the only path to citing real INP, kept out of minimal.
- rules: performance-principles is the single rules file in the pack (now carries the browser INP-responsiveness MUST + TTFB budget that the standard-mode web-vitals-field + inp-responsiveness artifacts enforce).
- ai-patterns: none essential — `lazy-loading.md` and `inp-responsiveness.md` ship in standard mode and apply only when a frontend framework is detected; minimal mode skips them.
