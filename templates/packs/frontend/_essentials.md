---
track: frontend
purpose: Client-side UI development — design, implement, and verify pages/components.
essentials:
  agents: [ui-architect, ui-reviewer]
  commands: [add-component, add-page]
  skills: [visual-check, component-playground]
  rules: [frontend-principles]
  ai-patterns: [rendering-strategy, forms]
---

# Frontend — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: ui-architect designs the component/page, ui-reviewer checks the result — the minimum design+review pair.
- commands: add-component and add-page cover the two main UI creation flows; everything else is a specialty.
- skills: visual-check is the only way to actually verify rendered UI — indispensable. The performance-specialist scanners (ssr-audit, lighthouse-ci, bundle-analyze, streaming-ssr, navigation-speed, lcp-audit) ship in standard mode — invoked when a perf/SSR/navigation concern surfaces, not on every minimal scaffold.
- rules: frontend-principles is the single rules file in the pack (its navigation-speed / streaming / instant-loading / bfcache MUSTs back the standard-mode perf skills).
- ai-patterns: rendering-strategy (SSR vs CSR — foundational decision) and forms (most common UI surface with state). rendering-strategy's TTFB-levers block pairs with the standard-mode streaming-ssr skill.
