---
track: infrastructure
purpose: Kubernetes, IaC and edge infrastructure design, review, audit and fix.
essentials:
  agents: [infra-architect, k8s-reviewer, infra-reviewer]
  commands: [k8s-generate, infra-audit, infra-fix]
  skills: [k8s-render-scan, k8s-availability-scan, k8s-wiring-scan, k8s-api-version-scan, iac-state-scan, iac-lifecycle-scan, dr-audit, serverless-reliability-scan, iac-cost-scan, edge-reliability-scan, dns-tls-lifecycle-scan, network-exposure-audit, k8s-audit]
  rules: [infra-principles]
  ai-patterns: []
---

# Infrastructure — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `infra-architect` is the broad designer. **`k8s-reviewer` is here because `/k8s-generate` Phase 6 gates its done-declaration on its PRODUCTION-GRADE verdict**, and it judges the four Kubernetes detectors' rows for `/infra-audit`. **`infra-reviewer`** judges every non-Kubernetes detector's rows (state, lifecycle, DR, serverless, cost candidates, edge, DNS/TLS, network); without it `/infra-audit` falls back to `@verifier`, which minimal mode should not need.
- agents (excluded): `kubernetes-architect` designs the cluster operating model — it matters once there IS a cluster, and `infra-architect` hands off to it when the pack is installed in full.
- commands: `k8s-generate` is the creation entry point; `infra-audit` is the pack's audit and `infra-fix` the loop that closes its findings, so a minimal install can find and fix what it generates. `provision-tier`, `cost-audit` and `audit-iam` are standard-mode only.
- skills: the twelve detectors, because `/infra-audit` dispatches every one on a whole-repo run (`k8s-render-scan` first: its render and platform inventory feed the other three Kubernetes detectors, `iac-state-scan` and `dns-tls-lifecycle-scan`), and `/k8s-generate` Phase 6a runs the four Kubernetes detectors on its own output. `iac-lifecycle-scan` ships `blocks.awk` and `plan-joins.jq`, which `iac-state-scan`, `dr-audit`, `serverless-reliability-scan` and `iac-cost-scan` call, so it is never dropped while they ship. `k8s-audit` because `/infra-audit`'s live row dispatches it behind its context halt. `tf-plan-review` (a saved plan's verdict) and `admission-policy` (a generator) are standard-mode only.
- rules: `infra-principles` is the single rules file in the pack.
- ai-patterns: none essential — `zero-downtime-deploys` and `multi-region` are project-specific and kept out of minimal.

**Rule for editing this file:** if a command listed under `commands:` gates its own completion on an agent or skill, that agent or skill belongs in this manifest too. Otherwise minimal mode ships a gate whose adjudicator is absent, which reads as a broken command rather than a reduced one.
