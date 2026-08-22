---
track: infrastructure
purpose: Kubernetes and cloud infrastructure design and review.
essentials:
  agents: [infra-architect, k8s-reviewer]
  commands: [k8s-generate]
  skills: []
  rules: [infra-principles]
  ai-patterns: []
---

# Infrastructure — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: infra-architect is the broad designer. **k8s-reviewer is here because `/k8s-generate` Phase 6 gates its done-declaration on that agent's PRODUCTION-GRADE verdict** — shipping the command without its adjudicator means minimal mode can only ever report INCOMPLETE, so a gated command and its gate travel together.
- agents (excluded): kubernetes-architect designs the cluster operating model — it matters once there IS a cluster, not on day one, and `infra-architect` hands off to it when the pack is installed in full.
- commands: k8s-generate is the only creation command — the day-one entry point.
- skills: none essential — k8s-audit needs a running cluster; admission-policy (signature verification + Pod Security enforcement, the verifier for devops release-security's signed images) becomes useful once manifests exist; dr-audit / network-exposure-audit / tf-plan-review audit a footprint that does not exist yet in minimal mode.
- rules: infra-principles is the single rules file in the pack.
- ai-patterns: none essential — zero-downtime-deploys and multi-region are project-specific and kept out of minimal.

**Rule for editing this file:** if a command listed under `commands:` gates its own completion on an agent or skill, that agent or skill belongs in this manifest too. Otherwise minimal mode ships a gate whose adjudicator is absent, which reads as a broken command rather than a reduced one.
