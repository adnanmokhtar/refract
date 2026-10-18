# Reachability — deadfeat

symbols: legacyExport
v1_root: v1

| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|------|
| App source (production callers) | no | 0 callers of legacyExport outside its definition (rg -w -F) |
| Downstream tests | no | 0 hits under tests/ |
| Cron / scheduler | no | 0 hits in Console/Kernel.php, routes/console.php |
| Route / API registration | no | 0 hits in routes/ |
| Infra / deploy config | no | 0 hits in *.yml / Dockerfile |
| Production telemetry | n/a | unwired: no access-log export for this service |
