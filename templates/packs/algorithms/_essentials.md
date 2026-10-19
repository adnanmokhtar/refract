---
track: algorithms
purpose: Algorithm design + algorithmic defect audit — choose the right algorithm/data structure for the input scale and prove it; find super-linear work, unbounded recursion, broken input contracts, biased draws, geodesy and float-stability defects with caps resolved and counted proof; close them failing-first.
essentials:
  agents: [algorithm-designer]
  commands: [analyze-complexity, design-algorithm]
  skills: [complexity-derivation, complexity-scan]
  rules: [algorithm-principles]
  ai-patterns: []
---

# Algorithms — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials. This pack is small and cohesive — the essentials are nearly the whole pack.

Rationale per category (one line each):
- agents: `algorithm-designer` is the whole specialist — design mode (problem → proven algorithm), judge mode (refutes detector rows under `/analyze-complexity`) and review mode; it writes nothing.
- commands: `analyze-complexity` is the read-only whole-repo audit (all three detectors, class ledger, verdict); `design-algorithm` is the design entry and, with `--from-audit`, the failing-first fixer. Both drive the one agent.
- skills: `complexity-derivation` is the derivation engine every mode runs on; `complexity-scan` (with `scripts/algo-sites.py`) is essential because every repo loops over data — super-linear work, recursion depth, cycles and loop progress are the classes any codebase can carry. `algorithm-contract-scan` (sortedness, stability, key collapse, draws, geodesy) and `numeric-stability-scan` (gated on numeric code and sketches) are **standard**, not essential: their surfaces are domain-dependent, and a minimal install's audit prints their classes `not run (detector not installed)`, which keeps its verdict at `CLEAN-UNVERIFIED`.
- rules: `algorithm-principles` is the always-on discipline (budget-from-scale, derive-don't-guess, prove-correctness, proven-primitive) — shipped even in minimal installs.
- ai-patterns: `numerical-methods` and `sublinear-structures` are signal-gated (numeric libraries and anchored calls; sketch libraries and commands); kept out of minimal.
