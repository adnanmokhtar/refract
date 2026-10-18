# Migration ledger — Norrow Supply portal (V1 Laravel 11 → V2 NestJS 11 + React)

V1 has no history in this repository: the pin is the git tree hash of `v1/` (`git write-tree`
over `v1/` alone), the same value every `v1-inventory/*.tsv` header records as `sha`.

```yaml
features:
  - id: F001
    feature: orders
    state: V2-canary
    tier: standard
    owner: orders-team@norrow.example
    v1_path: v1/app/Http/Controllers/OrderController.php
    v2_path: v2/apps/api/src/orders/orders.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    contract: ai/migration/contracts/orders.md
    parity_tests: v2/apps/api/test/parity/orders.parity.spec.ts
    cutover_mechanism: strangler
    cutover_progress: 100%
    related_adrs:
      - ADR-0011
    changes_baseline: ["orders.number-source"]
    gaps_in: 4
    gaps_closed: 4
    notes: |
      Reads on V2 since 2.3.0; writes flip in 2.4.0 (deploy/cutover/plan.yaml). The validation
      test (StoreOrderValidationTest) is not ported yet.

  - id: F002
    feature: invoices
    state: V2-canary
    tier: standard
    owner: billing-team@norrow.example
    v1_path: v1/app/Http/Controllers/InvoiceController.php
    v2_path: v2/apps/api/src/invoices/invoices.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    contract: ai/migration/contracts/invoices.md
    parity_tests: v2/apps/api/test/parity/invoices.parity.spec.ts
    cutover_mechanism: strangler
    cutover_progress: 50%
    related_adrs:
      - ADR-0014
    changes_baseline: []
    gaps_in: 3
    gaps_closed: 3
    notes: |
      Reads only on V2 (façade routes GET/HEAD); issuing stays on V1 until the write flip.

  - id: F003
    feature: tickets
    state: V2-only
    tier: standard
    owner: support-team@norrow.example
    v1_path: v1/app/Http/Controllers/TicketController.php
    v2_path: v2/apps/api/src/tickets/tickets.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    contract: ai/migration/contracts/tickets.md
    parity_tests: v2/apps/api/test/parity/tickets.parity.spec.ts
    cutover_mechanism: strangler
    cutover_progress: 100%
    related_adrs:
      - ADR-0007
      - ADR-0008
      - ADR-0010
    changes_baseline: ["tickets.id-shape-for-new-tickets", "tickets.status-merged", "tickets.no-soft-deleted-rows"]
    gaps_in: 5
    gaps_closed: 5
    notes: |
      Every method on V2 since 2.3.0.

  - id: F004
    feature: wallets
    state: V2-shadow
    tier: heavy
    owner: billing-team@norrow.example
    v1_path: v1/app/Http/Controllers/WalletController.php
    v2_path: v2/apps/api/src/wallets/wallets.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    parity_tests: v2/apps/api/test/parity/wallets.parity.spec.ts
    cutover_mechanism: shadow-read
    cutover_progress: 0%
    related_adrs: []
    changes_baseline: []
    notes: |
      Money path: CDC with a declared 30 s lag (deploy/cdc/wallets-cdc.yaml).

  - id: F005
    feature: stock
    state: In-progress
    tier: standard
    owner: orders-team@norrow.example
    v1_path: v1/app/Http/Controllers/StockController.php
    v2_path: v2/apps/api/src/inventory/stock.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    related_adrs:
      - ADR-0004
    changes_baseline: ["stock.low-stock-path"]
    notes: |
      Façade still routes /api/stock to V1.

  - id: F006
    feature: reports
    state: In-progress
    tier: trivial
    owner: data-team@norrow.example
    v1_path: v1/app/Http/Controllers/ReportController.php
    v2_path: v2/apps/api/src/reports/reports.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    related_adrs:
      - ADR-0012
      - ADR-0013
    changes_baseline: ["reports.sales-average"]

  - id: F007
    feature: users-admin
    state: In-progress
    tier: standard
    owner: platform@norrow.example
    v1_path: v1/app/Http/Controllers/Admin/UserController.php
    v2_path: v2/apps/api/src/users/users.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8

  - id: F008
    feature: auth-token
    state: In-progress
    tier: trivial
    owner: platform@norrow.example
    v1_path: v1/app/Http/Controllers/AuthController.php
    v2_path: v2/apps/api/src/auth/auth.controller.ts
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    related_adrs:
      - ADR-0006
    changes_baseline: ["auth.token-validation-status"]

  - id: F009
    feature: reports-legacy-aging
    state: deprecated
    v1_path: v1/routes/api.php
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
    deprecated_at: 2026-09-03T09:00:00Z
    deprecated_by: data-team@norrow.example
    deprecation_adr: ADR-0009
    deprecation_reason: |
      Zero callers on all six reachability axes for 120 days (ADR-0009).
    tenant_impact: low

  - id: F010
    feature: portal-ui
    state: V2-shadow
    tier: standard
    owner: web-team@norrow.example
    v1_path: v1/resources/views
    v2_path: v2/apps/web/src
    v1_commit_pinned: 61cb5c927438bcbf4b971b17938abe99c70b70f8
```
