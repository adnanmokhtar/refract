---
track: algorithms
purpose: Algorithm design + complexity analysis — choose the right algorithm/data structure for the input scale, derive and prove complexity, and find the asymptotic defects (accidental-quadratic, wrong-container) that profiling shows as "slow" but never explains.
essentials:
  agents: [algorithm-designer]
  commands: [analyze-complexity, design-algorithm]
  skills: [complexity-derivation]
  rules: [algorithm-principles]
  ai-patterns: []
---

# Algorithms — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials. This pack is small and cohesive — the essentials are nearly the whole pack.

Rationale per category (one line each):
- agents: `algorithm-designer` is the whole specialist — it owns both modes (design + analysis), the complexity derivation, and the correctness discipline.
- commands: `analyze-complexity` is the daily entry (derive + rank wins on existing code); `design-algorithm` is the design entry (problem → proven, implemented algorithm). Both drive the one agent.
- skills: `complexity-derivation` is the shared engine both commands run on — without it, the cite-or-halt complexity discipline has no mechanical procedure.
- rules: `algorithm-principles` is the always-on discipline (budget-from-scale, derive-don't-guess, prove-correctness, proven-primitive, asymptotic-hot-only) — shipped even in minimal installs so the lane stays clean against `performance-optimizer`.
- ai-patterns: none — this is a reasoning/utility track and the pack ships without ai-patterns.
