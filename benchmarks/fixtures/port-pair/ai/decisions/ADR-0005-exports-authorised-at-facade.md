# ADR-0005 — Export downloads are authorised by the façade

Status: Accepted (2026-08-11)

V1 served `/exports/{file}` behind `auth` + `signed`. V2 has no download route: nginx serves the
files and asks `GET /api/internal/authz/export` (session + signature + expiry) through
`auth_request` first. Same callers, same checks, one hop earlier.
