# PricingTaxMismatch — page

Fired:    2026-06-30T10:36:00Z (orders with tax_total = 0 in a VAT country, ratio above threshold)
Service:  pricing (TypeScript, OpenFeature + flagd)
Symptom:  EU orders priced with zero VAT from 10:31 to 11:04; pricing CPU up 40 %
Scope:    every tenant; the `new-pricing-engine` flag is OFF for all tenants in flagd
