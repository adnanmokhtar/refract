# ADR-0007 — Raw HTTP for PDF export streaming

- Status: Accepted
- Date: 2026-01-20

## Decision

`apps/web/src/export/pdf.ts` may import `ky` directly to stream invoice PDFs, because `apiClient`
parses every response as JSON. The import carries `-- ADR-0007` on its `eslint-disable` line. No
other module is covered by this exception.
