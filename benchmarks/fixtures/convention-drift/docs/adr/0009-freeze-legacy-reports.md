# ADR-0009 — Freeze packages/legacy-reports

- Status: Accepted
- Date: 2026-02-10

## Decision

`packages/legacy-reports` is frozen until 2027-03-31, when the reports rewrite replaces it and the
package is deleted. No convention work happens inside it: it keeps styled-components and its own
literals, and lint ignores it. New code must not import it (`no-legacy-reports-in-new-code` in
`.dependency-cruiser.cjs`).
