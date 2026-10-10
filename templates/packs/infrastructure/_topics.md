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
  # the judge of the four k8s detectors' rows (k8s-render-scan, k8s-availability-scan, k8s-wiring-scan,
  # k8s-api-version-scan) and the PRODUCTION-GRADE verdict /k8s-generate gates on.
  triggers: { k8s_detected: true }
  extracts_from: _extracted-codebase.md § Infra (Kustomize roots, charts and values files, CD targets, runbook install lines, target minor, Helm major) + the sibling manifest per kind
  sections: [persona, contract, premise, halt_conditions, detector_dispatch, axis_ownership, sibling_divergence_check, production_grade_verdict, output_format]
  fallback: _examples/k8s-reviewer.md   # generated-from copy of agents/k8s-reviewer.md (COPY-DRIFT gated)

- name: infra-reviewer
  kind: agent
  # the judge of the non-Kubernetes detectors' rows: iac-state-scan, iac-lifecycle-scan, dr-audit,
  # serverless-reliability-scan, iac-cost-scan, edge-reliability-scan, dns-tls-lifecycle-scan, network-exposure-audit.
  triggers:
    dockerfile_or_k8s_or_terraform_detected: true
    OR_grep_evidence: "^\\s*(proxy_pass|reverse_proxy)\\b|AWSTemplateFormatVersion|aws-cdk-lib|@pulumi/|\\b(pg_dump|mysqldump|velero)\\b|\\b(doctl|gcloud|az|hcloud)\\s+\\S+(\\s+\\S+)?\\s+create\\b"   # a proxy config, a CFN/CDK/Pulumi program, a backup job or a runbook create line
  extracts_from: _extracted-codebase.md § Infra (IaC roots and the env each deploys, CI apply jobs and runbook deploy lines, stateful stores, functions and queues, proxy/LB/CDN configs, DNS and certificates) + the sibling module per resource kind
  sections: [persona, contract, premise, halt_conditions, detector_dispatch, axis_ownership, single_owner_per_site, evidence_closure, output_format]
  fallback: _examples/infra-reviewer.md   # generated-from copy of agents/infra-reviewer.md (COPY-DRIFT gated)

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

- name: k8s-wiring-scan
  kind: skill
  triggers:
    k8s_detected: true
    OR_grep_evidence: "^kind:\\s*(Service|Ingress|HTTPRoute|NetworkPolicy|CronJob|Job|RoleBinding|ClusterRoleBinding|ServiceAccount)\\b"
  extracts_from: _extracted-codebase.md § Infra (k8s-render-scan § 0 render per env, CD targets, the platform inventory, CNI, Reloader/ESO presence)
  fallback: skills/k8s-wiring-scan/SKILL.md

- name: k8s-api-version-scan
  kind: skill
  triggers:
    k8s_detected: true
    OR_grep_evidence: "^apiVersion:\\s*\\S+/v\\d+(alpha|beta)\\d+|kind:\\s*(CustomResourceDefinition|ClusterPolicy|ValidatingAdmissionPolicy)\\b|pod-security\\.kubernetes\\.io/enforce|kubernetes\\s+cluster\\s+create"   # a beta API, a CRD, a policy or a cluster-create line
  extracts_from: _extracted-codebase.md § Infra (k8s-render-scan § 0 render, the target minor(s) from runbooks/IaC/CI, policy engines, the platform inventory)
  fallback: skills/k8s-api-version-scan/SKILL.md

- name: edge-reliability-scan
  kind: skill
  triggers:
    dockerfile_or_k8s_or_terraform_detected: true
    OR_grep_evidence: "^\\s*(proxy_pass|reverse_proxy|upstream)\\b|^(FROM|\\s*image:)\\s*\\S*(nginx|caddy|traefik|haproxy|envoy)|nginx\\.ingress\\.kubernetes\\.io/|\\b(origin_read_timeout|idle_timeout|keepAliveTimeout)\\b"   # a proxy config, a proxy image, an ingress annotation, an LB/CDN or app-server timeout
  extracts_from: _extracted-codebase.md § Infra (proxy configs incl. k8s-render-scan § 0 embedded/, proxy image tags, LB/CDN IaC, app-server timeout settings, the route classes that stream, upload or run long)
  fallback: skills/edge-reliability-scan/SKILL.md

- name: serverless-reliability-scan
  kind: skill
  triggers:
    terraform_detected: true
    OR_grep_evidence: "resource\\s+\"(aws_lambda_function|aws_sqs_queue|aws_lambda_event_source_mapping|google_cloud_run_v2_service|google_cloudfunctions2_function|azurerm_(linux|windows)_function_app)\"|AWS::(Serverless::Function|Lambda::Function|SQS::Queue)|\\[\\[queues\\.consumers\\]\\]|\"functionTimeout\""   # a function, a queue consumer, a SAM template, a wrangler consumer or an Azure host.json
  extracts_from: _extracted-codebase.md § Infra (functions and their triggers per engine, queues and redrive, API Gateway integrations, Cloud Run / Azure / Cloudflare consumer settings, the downstream each function calls)
  fallback: skills/serverless-reliability-scan/SKILL.md

- name: iac-cost-scan
  kind: skill
  triggers:
    dockerfile_or_k8s_or_terraform_detected: true
    OR_grep_evidence: "resource\\s+\"(aws_nat_gateway|aws_ebs_volume|aws_eip|aws_cloudwatch_log_group|aws_autoscaling_group|aws_dynamodb_table|google_cloud_run_v2_service)\"|^\\s*(maxReplicas|maxReplicaCount):|\\b(doctl|gcloud|az|hcloud)\\s+\\S+(\\s+\\S+)?\\s+create\\b"   # an always-on resource, a log sink, an autoscaler ceiling or a runbook create line
  extracts_from: _extracted-codebase.md § Infra (IaC roots and their environments, runbook create lines with size slugs and node counts, autoscaler ceilings from k8s-render-scan § 0, installed finops pack)
  fallback: skills/iac-cost-scan/SKILL.md

- name: k8s-audit
  kind: skill
  triggers: { k8s_detected: true }
  sections: [boundary, premise, halt_conditions, tools, checks, output, rules]
  fallback: _examples/k8s-audit.md

- name: network-exposure-audit
  kind: skill
  triggers:
    terraform_detected: true
    OR_grep_evidence: "resource\\s+\"(aws_(vpc|subnet|network_acl|route_table|vpc_endpoint|vpc_peering_connection)|google_compute_(network|subnetwork)|azurerm_(virtual_network|private_endpoint)|digitalocean_(vpc|kubernetes_cluster))\"|--(cluster-subnet|service-subnet|pod-network-cidr|service-cidr)\\b|^\\s*(podSubnet|serviceSubnet):"   # a declared network, endpoint or peering, or a cluster's pod/service range set by a runbook or kind/kubeadm config
  extracts_from: _extracted-codebase.md § Infra (VPCs, subnets, NACLs, routes, NAT, endpoints, peering/TGW/VPN; cluster pod and service ranges incl. runbook create lines; IPv6 switches; managed-service hostnames)
  fallback: skills/network-exposure-audit/SKILL.md

- name: dns-tls-lifecycle-scan
  kind: skill
  triggers:
    dockerfile_or_k8s_or_terraform_detected: true
    OR_grep_evidence: "resource\\s+\"(aws_route53_(zone|record)|cloudflare_(record|dns_record)|google_dns_record_set|azurerm_dns_\\w+_record|digitalocean_record|aws_acm_certificate)\"|^kind:\\s*(Certificate|ClusterIssuer|Issuer)\\b|cert-manager\\.io/|^\\s*(on_demand_tls|acme_ca)\\b|\\bcertResolver\\b|^\\s*ssl_certificate\\s"   # a DNS record, a certificate or issuer, an ACME-capable proxy, or a hand-placed certificate file
  extracts_from: _extracted-codebase.md § Infra (DNS zones and records incl. runbook record lines, certificate sources per env, ACME CA and solver, CAA and DNSSEC resources, expiry alert rules and probes)
  fallback: skills/dns-tls-lifecycle-scan/SKILL.md

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

- name: iac-lifecycle-scan
  kind: skill
  triggers:
    terraform_detected: true
    OR_grep_evidence: "AWSTemplateFormatVersion|Transform:\\s*AWS::Serverless|aws-cdk-lib|@pulumi/|RemovalPolicy\\.|reclaimPolicy:\\s*Delete"   # a CFN/SAM template, a CDK or Pulumi program, or a Delete reclaim policy
  extracts_from: _extracted-codebase.md § Infra (IaC roots and the env each deploys, engine and provider versions, module defaults that reach prod, stateful resources, committed or CI plan JSON)
  fallback: skills/iac-lifecycle-scan/SKILL.md

- name: iac-state-scan
  kind: skill
  triggers:
    terraform_detected: true
    OR_grep_evidence: "^\\s*backend\\s+\"|remote_state\\s*\\{|Pulumi\\.ya?ml|helm\\s+(upgrade|install)\\b|targetRevision:|kind:\\s*HelmRelease"   # a backend, Terragrunt, Pulumi, or a chart installed by a runbook, CI, Argo or Flux (PIN-HELM)
  extracts_from: _extracted-codebase.md § Infra (backends and lock settings, version pins and lock files, CI plan/apply steps, workspaces per env, k8s-render-scan § 0 platform inventory)
  fallback: skills/iac-state-scan/SKILL.md

- name: dr-audit
  kind: skill
  triggers:
    stateful_store_detected: true
    OR_grep_evidence: "\\b(pg_dump|mysqldump|velero|pgbackrest|wal-g|restic|borg)\\b|backup_retention_period|point_in_time_recovery|postgresql\\.cnpg\\.io/|doctl\\s+databases\\s+create"   # a backup job, a retention attribute, an operator Postgres or a runbook-created managed store
  extracts_from: _extracted-codebase.md § Infra (stateful stores from IaC, renders and runbook create lines; backup jobs and their destinations; the app's file bucket; declared RPO/RTO; restore drill records)
  fallback: skills/dr-audit/SKILL.md
```
