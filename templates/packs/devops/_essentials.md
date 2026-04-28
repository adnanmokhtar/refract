---
track: devops
purpose: CI/CD pipelines, container images, and deployment workflows.
essentials:
  agents: [devops-architect]
  commands: [add-ci, dockerize]
  skills: [dockerfile-lint]
  rules: [devops-principles]
  ai-patterns: [deployment]
---

# Devops — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: devops-architect is the broad designer; ci-reviewer and deployment-engineer are specialists kept out of minimal.
- commands: add-ci and dockerize cover the two universal day-one DevOps tasks.
- skills: dockerfile-lint catches the most common image issues — high signal, low cost.
- rules: devops-principles is the single rules file in the pack.
- ai-patterns: deployment is the foundational pattern; cicd-pipeline is more specialized and kept out of minimal.
