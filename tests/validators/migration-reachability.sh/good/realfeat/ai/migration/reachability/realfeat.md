# Reachability — realfeat
| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|------|
| App source (production callers) | yes | api/routes.py:142 |
| Downstream tests | no | 0 hits in tests/ |
| Cron / scheduler | no | 0 hits in config/cron/ |
| Route / API registration | yes | api/routes.py:142 |
| Infra / deploy config | no | not in deploy/ |
| Production telemetry | n/a | unwired: no access-log export for this service |
