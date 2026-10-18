# Offline oracle transcripts

Nothing in this fixture is installed or booted: no `vendor/`, no `node_modules/`, no database. The
files under `runtime/` are what the dynamic oracles WOULD print on this pair, authored to match
the code (the `backend-defects` convention) so the runtime lanes can be scored offline. They are
evidence for a run to cite, never a substitute for re-running the oracle on a real pair.

| File | Oracle | What it shows |
|---|---|---|
| `runtime/v358-route-replay.txt` | V358 differential replay | V1's route list and request corpus replayed against V2 |
| `runtime/v359-authz-matrix.txt` | V359 permission matrix | role × route × tenant, V1 status vs V2 status |
| `runtime/v363-rounding-property.txt` | V363 property run | money functions at .5 boundaries and negatives |
| `runtime/v371-effect-journal.txt` | V371 side-effect journal | mail, queue and audit rows per request, V1 vs V2 |
| `runtime/v375-reconciler-drift.txt` | V375 seeded drift | each seeded drift row and whether the reconciler reported it |
| `runtime/v386-coverage.txt` | V386 V1-pinned set + coverage | the port PR's test diff and line coverage before/after |
| `runtime/v387-v1-branch-coverage.txt` | V387 V1 branch coverage | V1 branches the parity corpus reaches |
| `runtime/ci-parity-log.txt` | V388 CI evidence | the last CI run of the `parity` and `contract` jobs |
