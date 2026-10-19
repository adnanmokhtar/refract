---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?(?:add-metrics|add-slo|add-telemetry|add-tracing|alert-audit|alert-design|alert-rule-lint|error-tracking-scan|investigate-incident|log-signal-scan|metric-hygiene-scan|obs-audit|obs-fix|postmortem|slo-audit|slo-rule-scan|synthetic-monitoring|telemetry-config-scan|trace-propagation-scan)"'
min: 1
arm: with-only
---

A skill or command of the observability pack ran: the pack-fired indicator, never part of the score.
