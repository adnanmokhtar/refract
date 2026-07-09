# DevOps pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

```yaml
- name: devops-architect
  kind: agent
  triggers: { ci_or_dockerfile_detected: true }
  extracts_from: _extracted-codebase.md § Stack (build tools) + .github/workflows scan + Dockerfile if any
  sections: [persona, current_pipeline, deploy_targets, env_strategy, secret_strategy, output_format]
  fallback: _examples/devops-architect.md
  cite_evidence: strict

- name: ci-reviewer
  kind: agent
  triggers: { ci_config_detected: true }
  extracts_from: _extracted-codebase.md (CI config files)
  sections: [persona, pipeline_review_checklist, caching_opportunities, parallelization_check, output_format]
  fallback: _examples/ci-reviewer.md

- name: deployment-engineer
  kind: agent
  triggers: { dockerfile_or_k8s_detected: true }
  extracts_from: _extracted-codebase.md (deploy artifacts)
  sections: [persona, deploy_strategy, rollback_strategy, smoke_tests, output_format]
  fallback: _examples/deployment-engineer.md

- name: cicd-pipeline
  kind: pattern
  triggers: { ci_config_detected: true }
  extracts_from: _extracted-codebase.md (CI config files + scripts)
  sections: [overview, current_stages, project_test_commands, project_build_commands, deploy_gate, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/cicd-pipeline.md

- name: deployment
  kind: pattern
  triggers: { dockerfile_or_k8s_detected: true }
  extracts_from: _extracted-codebase.md (deploy artifacts)
  sections: [overview, target_environment, deploy_unit, rollback_path, observability_during_deploy, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/deployment.md

- name: devops-principles
  kind: rule
  triggers: { ci_or_dockerfile_detected: true }
  extracts_from: _extracted-codebase.md (CI config + secrets handling)
  sections: [project_specific_first, secrets_never_in_repo, ci_must_run_on_pr, deploy_only_from_main, immutable_artifacts]
  mirror_existing: true
  fallback: _examples/devops-principles.md

- name: dockerize
  kind: command
  triggers: { container_target_likely: true }
  fallback: _examples/dockerize.md

- name: add-ci
  kind: command
  triggers: { vcs_detected: true }
  fallback: _examples/add-ci.md

- name: deploy-stage
  kind: command
  triggers: { deploy_target_detected: true }
  extracts_from: _extracted-codebase.md § Deploy (deploy mechanism + target env) + CI config (green-gate)
  sections: [premise, when_to_use, when_not_to_use, prerequisites, optional_flags, phases, halts, hard_rules, cross_references]
  fallback: commands/deploy-stage.md   # no _examples/ stub — fall back to the live source

- name: rollback-deploy
  kind: command
  triggers: { deploy_target_detected: true }
  extracts_from: _extracted-codebase.md § Deploy (deploy mechanism + revision history source)
  sections: [premise, when_to_use, args, what_happens, halts, hard_rules, cross_references]
  fallback: commands/rollback-deploy.md   # no _examples/ stub — fall back to the live source

- name: dockerfile-lint
  kind: skill
  triggers: { dockerfile_detected: true }
  fallback: _examples/dockerfile-lint.md

- name: release-security
  kind: skill
  triggers: { dockerfile_detected: true }
  fallback: _examples/release-security.md

- name: monitor-deploy
  kind: skill
  triggers: { deploy_target_detected: true }
  fallback: skills/monitor-deploy.md
```
