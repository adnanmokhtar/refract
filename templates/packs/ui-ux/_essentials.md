---
track: ui-ux
purpose: Design-system architecture, UX review, and visual/interaction quality.
essentials:
  agents: [design-system-architect, ux-reviewer]
  commands: [design-review]
  skills: [design-token-audit, motion-audit, a11y-quick-check]
  rules: [ui-principles]
  ai-patterns: []
---

# Ui-ux — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: design-system-architect designs, ux-reviewer audits — the minimum design+review pair; design-system-guardian and theme-specialist are specialists kept out of minimal.
- commands: design-review is the only command in the pack — the universal entry point.
- skills: design-token-audit, motion-audit, a11y-quick-check — three short audits the design-review command depends on; all ship in the pack.
- rules: ui-principles is the single rules file in the pack.
- ai-patterns: none essential — dark-mode/motion/rtl/theming/design-systems are all project-specific decisions (full set ships in standard mode).
