# ADR-0017 — Portal pages and the API fallback live in the V2 SPA and the Nest catch-all

Status: Accepted (2026-09-20)

V1 rendered the portal with Blade routes in `routes/web.php` (`/`, `/orders`, `/orders/new`, `/wallet`,
`/wallet/statements`, `/tickets/{ticket}`) and answered unknown API paths with `Route::fallback`. V2 serves
the same pages from the React SPA (`v2/apps/web/src/routes.tsx`, same paths) and unknown API paths from
`NotFoundFilter` (404 `{ "message": "Not Found." }`). They are not API routes of `v2/apps/api`, so the
route lane maps them away; their parity is checked by the UI axis (parity-auditor Section 0).
