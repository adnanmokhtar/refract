---
track: performance
purpose: Identify and fix performance bottlenecks at the request and query level.
essentials:
  agents: [performance-optimizer]
  commands: [perf-audit]
  skills: [request-path-scan, profile-endpoint]
  rules: [performance-principles]
  ai-patterns: []
---

# Performance — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: performance-optimizer ranks `/perf-audit`'s verified findings by labelled impact — the minimal agent; caching-architect ships in standard mode (cache-design work only) and is kept out of minimal.
- commands: perf-audit is the read-only sweep — the minimal command. perf-fix (closes a report's findings failing-first), profile-perf (one-path deep-dive) and bundle-perf (web bundle / page load) ship in standard mode and are kept out of minimal.
- skills: request-path-scan ships in minimal because it is the detector behind most of `/perf-audit`'s ledger (request path, overload, horizontal scale, queues); memory-growth-scan and caching-scan ship in standard mode, and a minimal run prints their rows `not run (not installed — /setup-project --refresh adds it)`. profile-endpoint targets the most common ask ("why is this endpoint slow?"). The N+1 detector, `n-plus-one-scan`, moved to the database pack, which owns database round trips. `memory-leak-hunt` (heap-diff-over-time leak hunt) ships in standard mode — a specialist invoked only on a monotonically-growing heap, kept out of minimal. `web-vitals-field` (field CWV with attribution) ships in standard mode, frontend-framework-gated — the only path to citing real INP, kept out of minimal.
- rules: performance-principles is the single rules file in the pack (now carries the browser INP-responsiveness MUST + TTFB budget that the standard-mode web-vitals-field + inp-responsiveness artifacts enforce).
- ai-patterns: none essential — `lazy-loading.md` and `inp-responsiveness.md` ship in standard mode and apply only when a frontend framework is detected; minimal mode skips them.
