# performance pack — changelog

Release history for `templates/packs/performance/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.6.0 — 2026-08-22

- **Audit corrections (same release).** `caching-architect` was the only measurement-claiming
  artifact in the pack with no unmeasured branch anywhere in it: its "hit rate … never estimated"
  rule had no failure form, and its layer table had been re-headed with a disclaimer while keeping
  the uncited `<1ms` / `5-50ms` / `1-5ms` cells — disclaiming a number is neither sourcing it nor
  removing it. Those cells are gone, replaced by what determines each figure and the command that
  measures it; the table now also separates user-vantage from server-vantage rows, which is the
  reason those numbers were never comparable in the first place. Added `HIT RATE UNAVAILABLE` and
  `NO READ PATTERN — pre-traffic; cache deferred` branches, and resolved the halt that demanded a
  "hit-rate target" against § Metrics' "No universal target". `inp-responsiveness` (and its fallback)
  now cite web.dev for INP ≤ 200 ms at p75 and MDN for the 50 ms long-task definition.

**A performance pack that prints a number it did not measure is the defect it exists to catch.**
This release removes the remembered figures and replaces each with the command that produces the
reader's own.

- **`@caching-architect`: the layer table ships no latency figures, deliberately.** Across
  deployments they vary by more than an order of magnitude — PoP distribution, VPC topology,
  payload size, serializer — so a number printed there is decoration a reader mistakes for a budget.
  Each row now carries a "how to get *your* number" column instead (DevTools `Size`/`Time`, RUM
  TTFB split by PoP, an APM span around the read, the client's own latency probe run from an app
  host). A new vantage column names the trap the cost column sets: browser and CDN costs are paid
  from the user's position and server costs from the server's, so they were never comparable.
- **Hit rate has no universal target, and an absent hit-rate line is not a pass.** The bar is
  whether the saved backend work exceeds the cache's cost, which the read:write ratio and the miss
  cost decide — 40% on a 900 ms query beats 95% on a 2 ms one. Where the stats are unreachable the
  design prints `HIT RATE UNAVAILABLE — <what is missing>` and ships provisional; substituting an
  estimate or a vendor benchmark is refused, and exposing the stat becomes task 0 of the rollout.
- **A tenant-blind cache key is broken access control, not a caching bug.** It survives a correct
  authorization layer: the guard runs, passes, and the cache returns whatever it stored for whoever
  missed first. Now a HALT, cited to OWASP A01:2025, with the test that proves it (warm as tenant A,
  read as tenant B) — a single-tenant test cannot fail on this.
- **`/profile-perf`: classify before opening the taxonomy.** A taxonomy lists what is *sometimes*
  slow; on a regression the answer is whatever changed, so the diff comes first — deploy range,
  migration, data volume and distribution, query-plan flip — cheapest first, stopping at the first
  that explains the magnitude.
- **`performance-principles`: 6,665 → ~5,840 characters (~1,666 → ~1,459 always-loaded tokens).**
  "Optimize without a profile" (Must not) restated "Profile before optimizing" (Must); they are one
  bullet now. The Frontend / Backend laundry-list bullets are deleted — a list of well-known
  techniques with no decision in it, in a file whose whole cost is that it loads every session.
  Two numbers changed status: `SLO e.g. p95 < 300ms` was a borrowed figure in the file that
  forbids borrowed figures and is now "set it from your own measured p95 and ratchet"; and CPU work
  `> 50ms` is now stated as what it is — fixed in the browser, where a task "whose duration exceeds
  50ms" is a long task by definition (https://w3c.github.io/longtasks/), and *not* a constant on a
  server, where the bound is the endpoint's own latency budget. The depth pointer said
  `../ai-patterns/`, which from the installed `.claude/rules/` resolves to
  `.claude/rules/ai-patterns/`; patterns install to `ai/patterns/`.

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
