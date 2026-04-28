---
track: frontend
purpose: Client-side UI development — design, implement, and verify pages/components.
essentials:
  agents: [ui-architect, ui-reviewer]
  commands: [add-component, add-page]
  skills: [visual-check]
  rules: [frontend-principles]
  ai-patterns: [rendering-strategy, forms]
---

# Frontend — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: ui-architect designs the component/page, ui-reviewer checks the result — the minimum design+review pair.
- commands: add-component and add-page cover the two main UI creation flows; everything else is a specialty.
- skills: visual-check is the only way to actually verify rendered UI — indispensable.
- rules: frontend-principles is the single rules file in the pack.
- ai-patterns: rendering-strategy (SSR vs CSR — foundational decision) and forms (most common UI surface with state).
