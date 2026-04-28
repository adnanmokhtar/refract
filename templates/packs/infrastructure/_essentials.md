---
track: infrastructure
purpose: Kubernetes and cloud infrastructure design and review.
essentials:
  agents: [infra-architect]
  commands: [k8s-generate]
  skills: []
  rules: [infra-principles]
  ai-patterns: []
---

# Infrastructure — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: infra-architect is the broad designer; k8s-reviewer and kubernetes-architect are specialists kept out of minimal.
- commands: k8s-generate is the only creation command — the day-one entry point.
- skills: none essential — k8s-audit becomes useful once manifests exist.
- rules: infra-principles is the single rules file in the pack.
- ai-patterns: none essential — zero-downtime-deploys is project-specific and kept out of minimal.
