---
track: frontend
purpose: Client-side UI development — design, implement, and verify pages/components.
essentials:
  agents: [ui-architect, ui-reviewer]
  commands: [add-component, add-page]
  skills: [visual-check, component-playground]
  rules: [frontend-principles]
  ai-patterns: [rendering-strategy, forms, data-fetching]
---

# Frontend — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: ui-architect designs the component/page, ui-reviewer checks the result — the minimum design+review pair.
- commands: add-component and add-page cover the two main UI creation flows; everything else is a specialty.
- skills: visual-check is the only way to actually verify rendered UI — indispensable. The performance-specialist scanners (ssr-audit, lighthouse-ci, bundle-analyze, streaming-ssr, navigation-speed, lcp-audit, image-optimization, font-optimization) plus seo-audit (technical-SEO scanner, paired with the technical-seo agent) ship in standard mode — invoked when a perf / SSR / navigation / asset / SEO concern surfaces, not on every minimal scaffold. Asset split: lcp-audit owns LCP priority-hints; image-optimization owns format/dimensions/responsive/lazy; font-optimization owns font-display/preload/swap-CLS.
- rules: the pack ships three — `frontend-principles`, `i18n`, `migration-frontend` — and only `frontend-principles` is minimal, because only it is unconditional (its navigation-speed / streaming / instant-loading / bfcache MUSTs back the standard-mode perf skills). `i18n` gates on `i18n_lib_detected` and `migration-frontend` on `migration_layout_detected`; a single-locale app and a greenfield app would each be handed a rule that governs nothing, so both ship in standard mode instead. That trigger, not a headcount, is the reason.
- ai-patterns: rendering-strategy (SSR vs CSR — foundational decision), forms (most common UI surface with state), and data-fetching (server-state cache/dedup/invalidation — every app fetches remote data). rendering-strategy's TTFB-levers block pairs with the standard-mode streaming-ssr skill. The five client-data/rendering/session specialists — list-virtualization, error-boundaries, code-splitting, realtime-client, auth-session-client — ship in standard mode, invoked when a large-list / resilience / bundle / realtime / login concern surfaces (not on every minimal scaffold). auth-session-client is deliberately NOT minimal: an app without a login never needs it, and an app with one needs it read in full rather than skimmed.
