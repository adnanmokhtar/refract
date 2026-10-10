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
  sections: [persona, contract, halt_conditions, detector_dispatch, axis_ownership, sibling_workflow_check, versions_read, generator_closure, output_format]
  fallback: _examples/ci-reviewer.md   # generated-from copy of agents/ci-reviewer.md (COPY-DRIFT gated)

- name: deployment-engineer
  kind: agent
  triggers: { dockerfile_or_k8s_detected: true }
  extracts_from: _extracted-codebase.md (deploy artifacts)
  sections: [persona, contract, halt_conditions, render, detector_dispatch, axis_ownership, deploy_strategy, rollback_strategy, safe_delivery_verdict, output_format]
  fallback: _examples/deployment-engineer.md   # generated-from copy of agents/deployment-engineer.md (COPY-DRIFT gated)

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
  extracts_from: _extracted-codebase.md § Deploy (deploy mechanism + revision-history source + the deploy ledger that records which revisions were healthy)
  sections: [premise, when_to_use, args, what_happens, platform_mapping, halts, hard_rules, output, cross_references]
  fallback: commands/rollback-deploy.md   # no _examples/ stub — fall back to the live source

- name: container-build-scan
  kind: skill
  triggers: { dockerfile_detected: true }   # Dockerfile*, *.dockerfile, Containerfile*, an ignore file, or a build invocation (CI build-push, compose build:, bake)
  extracts_from: _extracted-codebase.md § Deploy (Dockerfiles, build invocations and targets, base images, stack lanes)
  fallback: skills/container-build-scan/SKILL.md   # source-as-fallback; replaces dockerfile-lint; no Dockerfile → every § prints N/A (no Dockerfile)

- name: release-security
  kind: skill
  triggers: { dockerfile_detected: true }
  fallback: _examples/release-security.md

- name: monitor-deploy
  kind: skill
  triggers: { deploy_target_detected: true }
  fallback: skills/monitor-deploy/SKILL.md

- name: progressive-delivery
  kind: skill
  triggers: { deploy_target_detected: true }   # an Argo Rollout/AnalysisTemplate, a Flagger Canary/MetricTemplate, a Kayenta stage, a flag registry, a flag SDK call or a FEATURE_* / public build-time flag
  extracts_from: _extracted-codebase.md § Deploy (rollout objects, flag registries and SDKs, metrics backends)
  fallback: skills/progressive-delivery/SKILL.md   # source-as-fallback; no rollout object and no flag → every § prints N/A

- name: gitops-audit
  kind: skill
  triggers: { k8s_or_gitops_detected: true }   # an Argo Application/ApplicationSet, a Flux Kustomization/HelmRelease or a Fleet GitRepo, or kubectl/helm/argocd/flux in a script or CI file
  extracts_from: _extracted-codebase.md § Deploy (CD targets, the namespaces they own, imperative deploy scripts)
  fallback: skills/gitops-audit/SKILL.md   # source-as-fallback; no GitOps controller → every § prints N/A (no GitOps controller)

- name: pipeline-integrity-scan
  kind: skill
  triggers: { ci_config_detected: true }   # any of the six platforms: GitHub Actions, GitLab CI, CircleCI, Bitbucket, Azure Pipelines, Jenkins
  extracts_from: _extracted-codebase.md (CI config files)
  fallback: skills/pipeline-integrity-scan/SKILL.md   # source-as-fallback; no CI file → every § prints N/A (no CI file)

- name: deploy-safety-scan
  kind: skill
  triggers: { deploy_target_detected: true }   # a CI deploy job, deploy script, manifest/chart, migration runner or service bootstrap
  extracts_from: _extracted-codebase.md § Deploy (deploy units, manifests, migration runner, service roots)
  fallback: skills/deploy-safety-scan/SKILL.md   # source-as-fallback; no deploy unit → §2–§4 print N/A (no deploy unit)

- name: release-integrity-scan
  kind: skill
  triggers: { ci_config_detected: true }   # a publish site (registry push, package publish, release asset), a release trigger or tool, a verify step, or a retention rule
  extracts_from: _extracted-codebase.md § Deploy (release units, registries, release tooling, version sources)
  fallback: skills/release-integrity-scan/SKILL.md   # source-as-fallback; no publish site → §3–§5 print N/A (no publish site)

- name: pipeline-cache-scan
  kind: skill
  triggers: { ci_config_detected: true }   # a cache step (actions/cache, setup-* cache:, GitLab cache:, CircleCI restore_cache, Azure Cache@2), a buildx cache-from/to, or affected detection (nx/turbo/changed-files)
  extracts_from: _extracted-codebase.md (CI config files)
  fallback: skills/pipeline-cache-scan/SKILL.md   # source-as-fallback; no CI file → every § prints N/A (no CI file)

- name: compose-scan
  kind: skill
  triggers: { container_target_likely: true }   # a root compose file, Dockerfile or k8s tree (detect-signals); the skill itself discovers every *compose*.y(a)ml and each invocation that loads it
  extracts_from: _extracted-codebase.md § Deploy (compose files, the invocations that load them, profiles, host env)
  fallback: skills/compose-scan/SKILL.md   # source-as-fallback; no compose file → every § prints N/A (no compose file)
```
