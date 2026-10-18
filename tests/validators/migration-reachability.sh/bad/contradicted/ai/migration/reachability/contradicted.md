# Reachability — contradicted

symbols: legacyExport
v1_root: v1

| Axis | Reachable from V1? | Evidence (path:line or job name) |
|------|--------------------|------|
| App source (production callers) | no | no callers found |
| Downstream tests | no | none |
| Cron / scheduler | no | none |
| Route / API registration | no | "nothing routes to it" — but routes/web.php:2 does |
| Infra / deploy config | no | none |
| Production telemetry | n/a | unwired |
