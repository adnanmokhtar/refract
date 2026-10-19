# Changelog

All notable changes to Tallyhook are documented in this file. The format follows Keep a
Changelog 1.1.0, and the project uses semantic versioning.

## [Unreleased]

### Added

- `tallyhook export --from <date>` limits an export to recent orders.
- Monthly report totals include refunds as negative lines.

### Fixed

- Webhook retries add jitter, so a burst of failures no longer retries in lockstep.

## [1.5.0] - 2026-05-25

### Added

- Cursor-based listing for `GET /v1/orders`, with `cursor` and `limit` query fields.
- `GET /v1/reports/monthly`, with CSV output.

### Changed

- Order totals are stored as integer minor units.

## [1.4.0] - 2026-05-04

### Added

- Invoice PDFs are stored in the invoice bucket and served from `GET /v1/invoices/{id}/pdf`.
- `tallyhook import --dry-run` validates a file without writing anything.

### Fixed

- `POST /v1/orders/{id}/cancel` answers 409 for an order that is already cancelled.

## [1.2.0] - 2026-03-02

### Added

- Webhook endpoints can be listed and registered through the API.

### Removed

- The `tallyhook import --skip-validation` option; every import is validated.

## [1.3.0] - 2026-04-14

### Added

- The `tallyhook` CLI ships inside the API image.

## [1.1.0] - 03/02/2026

### Added

- Invoices can be fetched as JSON.

## [1.0.0] - 2026-01-12

### Added

- Orders: create, fetch and cancel.
- Invoices, numbered per merchant and never reused.
- API keys, one per merchant, rotated from the dashboard.
- Signed webhook deliveries for `order.paid` and `invoice.issued`.
- The first operator CLI, `tallyhook`, with an `import` command.
- `tallyhook import --skip-validation` imports rows without the schema check, for trusted files.
- Docker Compose services for Postgres and Redis.

[unreleased]: https://git.example.com/tallyhook/tallyhook/compare/v1.5.0...HEAD
[1.5.0]: https://git.example.com/tallyhook/tallyhook/compare/v1.4.0...v1.5.0
[1.4.0]: https://git.example.com/tallyhook/tallyhook/compare/v1.3.0...v1.4.0
[1.3.0]: https://git.example.com/tallyhook/tallyhook/compare/v1.2.0...v1.3.0
[1.2.0]: https://git.example.com/tallyhook/tallyhook/compare/v1.1.0...v1.2.0
[1.1.0]: https://git.example.com/tallyhook/tallyhook/compare/v1.0.0...v1.1.0
[1.0.0]: https://git.example.com/tallyhook/tallyhook/releases/tag/v1.0.0
