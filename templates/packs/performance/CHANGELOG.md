# performance pack — changelog

Release history for `templates/packs/performance/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.5.0 — 2026-07-10

- perf-audit Phase 6 four-gate production-grade gate (measured-not-asserted with an adjective
  grep-smell · beats-the-budget · profiled hotspot · no neighbor regression).
- performance-optimizer Guardrail matrix (7 fix classes × the neighbor metric each can regress × how
  to re-measure); profile-perf coherence pass. (verify NEEDS_FIX → fixed.)

## 1.4.0 — 2026-07-10

- skill +1: memory-leak-hunt (heap-diff-over-time leak-hunt discipline; the over-time counterpart to
  profile-endpoint's snapshot).

## 1.3.0 — 2026-07-09

- skills +1: load-test — designs+runs a load/stress/soak/spike/breakpoint campaign against a
  pre-declared SLA gate on a prod-parity env (open-vs-closed model, coordinated-omission trap).
  Distinct from profile-endpoint (single subject) and distributed-systems capacity-planner
  (analytical). Backing SHOULD in performance-principles.

## 1.2.1 — 2026-06-26

- performance-optimizer agent: added a reciprocal boundary route — a CPU-loop hotspot whose fix is a
  complexity-CLASS change (accidental-`O(n²)` membership scan → `O(n)`, exponential/unmemoized
  recursion → memoized, wrong container) is out of this agent's lane and routes to the new
  algorithms pack (`/analyze-complexity` to derive+rank, `/design-algorithm` to redesign;
  algorithm-designer owns the complexity proof); the agent keeps the measured constant-factor tune.
  Makes the algorithms pack's 'shared CPU-loop surface, arbitrated by asymptotic-vs-constant-factor'
  boundary real on the performance side (rendered-not-asserted), matching the refactorer + /optimize
  routes. Added a carve-out note in the Backend CPU taxonomy, a Hard rule, and an algorithm-designer
  entry under Related.

## 1.2.0 — 2026-06-25

- NEW skill web-vitals-field (kind:skill, primary_frontend_framework_detected) — field Core Web
  Vitals with attribution: wires web-vitals/attribution (onINP/onLCP/onCLS/onTTFB), reads the
  responsible element + sub-part (INP inputDelay/processingDuration/presentationDelay +
  longAnimationFrameEntries; LCP timeToFirstByte/resourceLoadDelay/resourceLoadDuration), and
  cross-checks the CrUX p75. The only way to cite the headline CWV (INP) to a file:line.
- NEW ai-pattern inp-responsiveness (kind:pattern, primary_frontend_framework_detected) — keep
  per-interaction main-thread work under the INP budget: diagnose the dominant sub-part, break long
  tasks with scheduler.yield()/isInputPending, defer non-urgent updates with
  startTransition/useDeferredValue, attribute the blocking script via the Long Animation Frames API.
- lazy-loading: NEW 'Hydration scheduling (interactive islands)' tier — Astro
  client:load/idle/visible/media/only scheduling + Qwik resumability; image-priority line now
  cross-refs references/<framework>.md § CWV/Images + lcp-audit.
- bundle-perf: Phase-2 Hydration axis routes TTFB-dominated SSR server-think-time to /streaming-ssr
  (vs backend latency → /profile-perf); NEW Navigation-timing axis (hard + soft nav, ≤500ms
  route-change-to-paint budget); failing INP now attributed to the longest LoAF script + routed to
  inp-responsiveness; generic image-priority mentions anchored to references/<framework>.md.
- performance-principles: added Must — browser input responsiveness (INP budget + scheduler.yield +
  transition primitive), extended the CWV CI-budget line with TTFB < 600ms, added Should — soft-nav
  timing (gated 'where available').
- perf-audit: routing table + Related now point web-frontend page-load to the nav-timing-aware
  bundle-perf, authoritative field INP / real-user CWV to the web-vitals-field skill (Lighthouse lab
  INP is a synthetic proxy), and page-to-page navigation work to the navigation-speed skill.
