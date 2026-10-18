# ADR-0004 — `GET /api/stock/low-stock` becomes `GET /api/stock/alerts`

Status: Accepted (2026-08-11)

Same query, same response shape. The mobile app 3.2 calls `alerts`; V1 clients go through the
façade, which still routes `/api/stock/*` to V1 until the stock read flip. `pair-map.tsv` carries
the rename. `changes_baseline: ["stock.low-stock-path"]`.
