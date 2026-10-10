---
track: devops
purpose: CI/CD pipelines, container images, and deployment workflows.
essentials:
  agents: [devops-architect, ci-reviewer, deployment-engineer]
  commands: [add-ci, dockerize, deploy-stage, rollback-deploy, devops-audit, devops-fix]
  skills: [pipeline-integrity-scan, pipeline-cache-scan, release-integrity-scan, deploy-safety-scan, container-build-scan, compose-scan, progressive-delivery, gitops-audit, release-security, monitor-deploy]
  rules: [devops-principles]
  ai-patterns: [deployment]
---

# Devops — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: `devops-architect` is the broad designer (proposer). **`ci-reviewer` and `deployment-engineer` are the two judges `/devops-audit` hands every detector row to** (pipeline and cache rows to `@ci-reviewer`; release, deploy, container, compose, delivery and GitOps rows to `@deployment-engineer`), and `/devops-fix` has them judge each proposed fix; without them both commands fall back to `@verifier`, which minimal mode should not need. `/deploy-stage` also dispatches `@deployment-engineer` to adjudicate its Safe-Delivery verdict; without it the verdict is labelled `[self-adjudicated]`.
- commands: `add-ci` and `dockerize` are the two day-one generators. `deploy-stage` and `rollback-deploy` ship as a **pair** because they are one loop — `/deploy-stage`'s S1 evidence is produced by `/rollback-deploy --dry-run`, so shipping the forward half alone gives a command that can never reach its own GREEN. `devops-audit` is the pack's audit and `devops-fix` the loop that closes its findings (failing-first oracle, `ci-graph.py --diff-guard` on every workflow change), so a minimal install can find and fix what the two generators emit.
- skills: **the eight detectors**, because `/devops-audit` dispatches every one on a whole-repo run (a detector whose surface is absent prints `N/A` in its own coverage block; it is never skipped), and `/add-ci` Phase 6 and `/dockerize` Phase 6 run `pipeline-integrity-scan` and `container-build-scan` on their own output: `pipeline-integrity-scan` (masked gates, lost exit status, the required-check join, deploy gating), `pipeline-cache-scan`, `release-integrity-scan`, `deploy-safety-scan`, `container-build-scan`, `compose-scan`, `progressive-delivery` (flags and the canary gate) and `gitops-audit` (out-of-band apply and live drift). `release-security` because `release-integrity-scan` §5 executes through it whenever a built image or a registry is reachable. `monitor-deploy` because it is the required-output executor behind `/deploy-stage`'s S2 and the recovery confirmation in `/rollback-deploy`; without it both commands are structurally stuck at INCOMPLETE.
- scripts (repo baseline, not this pack): every detector and both commands call `.claude/scripts/ci-graph.py`, which ships with the baseline in every mode.
- rules: `devops-principles` is the single rules file in the pack.
- ai-patterns: `deployment` is the foundational pattern; `cicd-pipeline` is more specialized and kept out of minimal.

**Rule for editing this file:** if a command listed under `commands:` gates its own completion on an agent or skill, that agent or skill belongs in this manifest too. Otherwise minimal mode ships a gate whose adjudicator is absent, which reads as a broken command rather than a reduced one.
