---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?(?:add-ci|compose-scan|container-build-scan|deploy-safety-scan|devops-audit|devops-fix|dockerize|gitops-audit|monitor-deploy|pipeline-cache-scan|pipeline-integrity-scan|progressive-delivery|release-integrity-scan|release-security)"'
min: 1
arm: with-only
---

A skill or command of the devops pack ran: the pack-fired indicator, never part of the score.
