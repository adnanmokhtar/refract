# LedgerPostingFailures — page

Fired:    2026-10-19T00:03:00Z (ledger posting error ratio above 14.4 x budget)
Service:  billing (Go 1.23) -> ledger (mTLS, internal)
Symptom:  every ledger call fails from 00:00:03 UTC; billing retries queue up
Scope:    all tenants; web storefront unaffected except checkout confirmation
Context:  the web storefront was deployed at 23:41 UTC the previous evening
