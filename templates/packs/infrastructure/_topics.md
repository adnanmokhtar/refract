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
  extracts_from: _extracted-codebase.md (k8s manifests)
  sections: [persona, namespace_strategy, resource_limits, hpa_strategy, ingress_strategy, output_format]
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

- name: k8s-audit
  kind: skill
  triggers: { k8s_detected: true }
  fallback: _examples/k8s-audit.md
```
