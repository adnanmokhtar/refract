# ADR-0010 — Soft-deleted V1 tickets are not migrated

Status: Accepted (2026-09-03)

Support never restores a deleted ticket; retention keeps them in the V1 archive export. The
tickets backfill filters `deleted_at IS NULL` (the excluded count is the V1 `deleted_at IS NOT NULL`
count, logged by the backfill run), so V2 tickets carry no `deleted_at`. `changes_baseline: ["tickets.no-soft-deleted-rows"]`.
