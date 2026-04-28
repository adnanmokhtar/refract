# ai/audits/

Dated, point-in-time audit artifacts. Read for historical context; don't edit them after they ship — they're snapshots.

## What goes here

- `tenant-isolation-YYYY-MM-DD.md` — adversarial cross-tenant tests + findings.
- `security-YYYY-MM-DD.md` — output of a `/security-audit` run.
- `dep-audit-YYYY-MM-DD.md` — output of `/deps-audit` (vulns, outdated, unused, bundle impact).
- `perf-snapshot-YYYY-MM-DD.md` — load-test results, baseline numbers.
- `i18n-coverage-YYYY-MM-DD.md` — translation gaps.
- `a11y-audit-YYYY-MM-DD.md` — WCAG 2.2 conformance report.
- `coverage-gap-YYYY-MM-DD.md` — which modules have <X% test coverage.
- `business-domain-audit-YYYY-MM-DD.md` — output of `business-auditor` agent (missing cycles, broken flows, incomplete impl).
- `tech-debt-YYYY-MM-DD.md` — backlog of debt items with cost estimates.

## How to use

- After running an audit command/agent, save the output here with today's date.
- Reference the most recent audit from `ai/status.md` ("Last security audit: 2026-04-24, see audits/").
- Quarterly: review prior audits to track whether issues were closed or rotted.
- After a major release: snapshot a fresh audit so you have a "v1.0 baseline" to compare future audits against.

## Naming convention

- ISO date in filename: `<audit-type>-YYYY-MM-DD.md`.
- Multiple audits same day: append `-N` (e.g., `-2`).
- Re-run of same audit: NEW file, don't overwrite. History matters.

## Lifecycle

- Keep audit files indefinitely while they fit in repo size budget.
- Beyond ~50 files: archive older ones to a separate repo or cloud storage; leave a manifest here.

## Empty?

This folder is empty until the first audit runs. Trigger one with the right command for your stack:
- `/security-audit`
- `/tenant-leak-audit`
- `/deps-audit`
- `/coverage-gap`
- `/business-audit`
