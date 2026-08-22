---
track: devops
purpose: CI/CD pipelines, container images, and deployment workflows.
essentials:
  agents: [devops-architect]
  commands: [add-ci, dockerize, deploy-stage, rollback-deploy]
  skills: [dockerfile-lint, monitor-deploy]
  rules: [devops-principles]
  ai-patterns: [deployment]
---

# Devops — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: devops-architect is the broad designer; ci-reviewer and deployment-engineer are specialists kept out of minimal. `/deploy-stage` normally dispatches `@deployment-engineer` to adjudicate its verdict; without it the command self-adjudicates and labels the verdict `[self-adjudicated]`.
- commands: add-ci and dockerize cover the two universal day-one DevOps tasks; deploy-stage and rollback-deploy ship as a **pair** because they are one loop — `/deploy-stage`'s S1 evidence is produced by `/rollback-deploy --dry-run`, so shipping the forward half alone gives a command that can never reach its own GREEN.
- skills: dockerfile-lint catches the most common image issues — high signal, low cost. monitor-deploy is here for the same reason as rollback-deploy: it is the required-output executor behind `/deploy-stage`'s S2 and the recovery confirmation in `/rollback-deploy`, so without it both commands are structurally stuck at INCOMPLETE.
- skills NOT in minimal: `release-security` (the build-artifact integrity gate — image CVE scan, SBOM, digest signing, provenance; the executor the security pack's OWASP A03 check dispatches to) runs at release rather than on every local build, so it is kept out of minimal; install the full pack before the first release. `progressive-delivery` and `gitops-audit` are likewise standard-mode only.
- rules: devops-principles is the single rules file in the pack.
- ai-patterns: deployment is the foundational pattern; cicd-pipeline is more specialized and kept out of minimal.
