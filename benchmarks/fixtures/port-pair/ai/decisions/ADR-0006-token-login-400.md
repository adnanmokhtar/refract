# ADR-0006 — `POST /api/auth/token` answers 400 on a malformed body

Status: Accepted (2026-08-20)

V1 answered 422 with Laravel's `errors` map. The token endpoint is only called by the mobile app,
whose 3.x client treats 400 and 422 alike and shows the generic sign-in error. V2 keeps Nest's
`ValidationPipe` here. `changes_baseline: ["auth.token-validation-status"]`.
