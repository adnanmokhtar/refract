# ADR-0012 — The sales report's average uses half-even rounding

Status: Accepted (2026-09-10)

`average_daily_total` is a reported statistic, never stored or charged. Finance asked for
half-even to match their spreadsheet. Totals per day are unchanged (sums of stored amounts).
`changes_baseline: ["reports.sales-average"]`.
