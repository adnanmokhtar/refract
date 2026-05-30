# Reachability — realfeat
| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|------|
| Cron / scheduled job | no | 0 hits in config/cron/ |
| Queue consumer | no | 0 subscribers in events/ |
| HTTP route / RPC | yes | api/routes.py:142 |
| Admin tool / internal | n/a | no admin surface |
| Deploy hook / migration runner | no | not in deploy/ |
| Runbook / on-call doc | n/a | no runbook references it |
