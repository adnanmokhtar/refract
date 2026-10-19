| when (ISO) | env | revision | artifact ref | commit | verdict |
|---|---|---|---|---|---|
| 2026-08-20T15:00Z | production | rev 90 | ghcr.io/acme/accounts@sha256:aa31... | 0c7e5d1 | GREEN |
| 2026-08-21T10:02Z | production | rev 91 | ghcr.io/acme/accounts@sha256:41bd... | 6a9f2e0 | RED |
| 2026-08-21T10:15Z | production | rev 90 | ghcr.io/acme/accounts@sha256:aa31... | 0c7e5d1 | RED (rollback did not recover) |
