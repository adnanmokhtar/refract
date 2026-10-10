# Infrastructure pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: infra-architect
  kind: agent
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md § Stack (infra files) + deployment artifacts
  sections: [persona, current_topology, scaling_strategy, network_strategy, secret_strategy, output_format]
  fallback: _examples/infra-architect.md
  cite_evidence: strict

- name: kubernetes-architect
  kind: agent
  triggers: { k8s_detected: true }
  extracts_from: _extracted-codebase.md (k8s manifests + cluster version + ingressclass/gateway CRDs)
  sections: [persona, scope_boundary, cluster_topology, tenancy_boundary, edge_api_choice, upgrade_cadence, mesh_decision, output_format]
  fallback: _examples/kubernetes-architect.md

- name: k8s-reviewer
  kind: agent
  triggers: { k8s_detected: true }
  extracts_from: _extracted-codebase.md (k8s manifests)
  sections: [persona, manifest_review_checklist, output_format]
  fallback: _examples/k8s-reviewer.md

- name: zero-downtime-deploys
  kind: pattern
  triggers: { dockerfile_or_k8s_detected: true }
  extracts_from: _extracted-codebase.md (deploy artifacts) + _extracted-codebase.md § "Data model" (migrations may need pre-deploy)
  sections: [overview, deploy_strategy_in_use, db_migration_compatibility, rollback_path, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/zero-downtime-deploys.md

- name: infra-principles
  kind: rule
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  extracts_from: _extracted-codebase.md (infra files)
  sections: [project_specific_first, immutable_infra, idempotent_provisioning, secret_management, observability_in_infra]
  mirror_existing: true
  fallback: _examples/infra-principles.md

- name: k8s-generate
  kind: command
  triggers: { container_target_likely: true }
  fallback: _examples/k8s-generate.md

- name: k8s-render-scan
  kind: skill
  triggers:
    k8s_detected: true
    OR_grep_evidence: "^kind:\\s*Kustomization|^apiVersion:\\s*v2$|helm\\s+(upgrade|install|template)\\b|argoproj\\.io/|fluxcd\\.io/"   # a runbook-installed chart or an Argo/Flux object is a render root even with no manifest in the repo
  extracts_from: _extracted-codebase.md § Infra (Kustomize roots, charts and values files, CD targets, Helm major and target Kubernetes minor)
  fallback: skills/k8s-render-scan/SKILL.md

- name: k8s-availability-scan
  kind: skill
  triggers:
    k8s_detected: true
    OR_grep_evidence: "^kind:\\s*(Deployment|StatefulSet|DaemonSet|PodDisruptionBudget|HorizontalPodAutoscaler|ScaledObject|Rollout)\\b|helm\\s+(upgrade|install)\\b"   # a runbook-installed controller is a § 9 platform row even with no workload in the repo
  extracts_from: _extracted-codebase.md § Infra (k8s-render-scan § 0 render per env, the platform inventory, target minor, node pools, the app's drain constant)
  fallback: skills/k8s-availability-scan/SKILL.md

- name: k8s-audit
  kind: skill
  triggers: { k8s_detected: true }
  sections: [boundary, premise, halt_conditions, tools, checks, output, rules]
  fallback: _examples/k8s-audit.md

- name: network-exposure-audit
  kind: skill
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  fallback: _examples/network-exposure-audit.md

- name: admission-policy
  kind: skill
  triggers: { grep_evidence: "kyverno|gatekeeper|ClusterImagePolicy|ValidatingAdmissionPolicy|cosign|policy-controller|PodSecurity" }
  extracts_from: _extracted-codebase.md § "Infra" (admission engine + registry + CI OIDC identity)
  fallback: _examples/admission-policy.md

- name: multi-region
  kind: pattern
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  sections: [overview, when_to_apply, when_not_to_apply, halt_conditions, justification_arithmetic, architectures, per_tier_recommendations, dr_drill_cadence, anti_patterns]
  fallback: stub-from-sections

- name: cost-audit
  kind: command
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  sections: [premise, mechanical_halts, when_to_use, cost_classes, retrieve_tools, output_format, hard_rules, what_to_do_next, failure_modes]
  fallback: stub-from-sections

- name: provision-tier
  kind: command
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  sections: [premise, mechanical_halts, when_to_use, tier_surface_areas, generate_the_iac, static_gates, operator_checklist, output_format, hard_rules, failure_modes]
  fallback: stub-from-sections

- name: audit-iam
  kind: command
  triggers: { dockerfile_or_k8s_or_terraform_detected: true }
  sections: [premise, mechanical_halts, when_to_use, concerns_audited, provider_primitives, enforcement_mechanisms, output_format, hard_rules, what_to_do_next, failure_modes]
  fallback: stub-from-sections

- name: tf-plan-review
  kind: skill
  triggers: { terraform_detected: true }
  sections: [premise, halt_conditions, when_to_use, run_the_plan, categorize_changes, high_risk_patterns, safety_mechanisms, cross_reference, output_format, failure_modes]
  fallback: stub-from-sections

- name: dr-audit
  kind: skill
  triggers: { stateful_store_detected: true }
  extracts_from: _extracted-codebase.md § Infrastructure (stateful stores + backup config) + terraform state
  sections: [premise, ownership_boundary, when_to_run, adapt_to_codebase, scans_for, output_format, false_positives, halt_conditions]
  mirror_existing: true
  fallback: _examples/dr-audit.md
```
