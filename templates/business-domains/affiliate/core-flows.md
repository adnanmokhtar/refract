# Affiliate — core flows

The flows every affiliate platform must support. P1 is "without these, you don't have an affiliate platform." P2 is "you need these to scale + retain partners." P3 is "fraud-resistant + competitive."

## P1 — must-have for v1

### 1. Affiliate signup → approval → first link
Without trustworthy supply, no one will run the program.

```
Prospective affiliate fills application
  → required: email, country, payment method, traffic sources, KYC for tax
  → tax form: W-9 (US), W-8BEN (non-US), or local equivalent
  → submit → status=pending
  → merchant/network reviews application
  → checks: prior fraud history (cross-network blocklists), traffic source plausibility, content alignment
  → approve OR reject (with reason)
  → on approval: account active; first tracking link can be generated
  → welcome sequence: terms acknowledgment, payout setup confirmation, link generator tutorial
```

Key invariants:
- Affiliate cannot generate links before approval (else fraud vector).
- Tax form valid before first payable conversion (else IRS lock).
- Payment method verified (micro-deposit / IBAN check / PayPal email confirm) before first payout.
- Fraud blocklist check at signup (email + IP + payment instrument).

### 2. Click tracking → cookie / fingerprint set
The technical backbone of attribution.

```
Visitor clicks tracking link: https://merchant.com/r/abc123?sub1=blog
  → server receives request at /r/[code]
  → look up tracking link by code → resolve to (affiliate_id, offer_id)
  → record click row: ip (anonymized per GDPR), user_agent, referer, sub_ids, fingerprint hash, created_at
  → set first-party cookie: ck_aff=abc123 with TTL = cookie_duration_days
  → 302 redirect to destination URL with click_id appended (?clk=<click_id>)
```

Key invariants:
- Click row written before redirect (fire-and-forget loses data).
- IP recorded but anonymized (last octet zeroed for IPv4, /64 prefix for IPv6) for GDPR.
- Bot detection at click: known bot UAs filtered immediately (don't pollute attribution).
- Rate limiting per IP (prevent click farming).
- Geographic restrictions enforced at click (offer may be country-locked).
- Idempotency: re-click within N seconds from same fingerprint = single click row (or single attribution-eligible click).

### 3. Conversion attribution
The hardest correctness problem in the domain.

```
Conversion event arrives
  → source: server-to-server postback (preferred), pixel, or coupon-code at checkout
  → resolve click_id from: postback param, cookie, fingerprint match, or coupon → affiliate
  → if multiple eligible clicks within attribution window: apply attribution model
       last-click: most recent
       first-click: earliest
       linear: split equally
       position-based: 40/20/40
  → check window: conversion_at − click_at ≤ attribution_window_seconds
  → if no eligible click + no coupon → unattributed (organic; do not record commission)
  → insert conversion row, status=pending
  → compute commission: type * value (% of order_value or flat)
  → insert commission row, status=accrued (in holdback)
  → notify affiliate dashboard (near-real-time pending earnings)
```

Key invariants:
- Attribution model documented per offer + locked at offer creation (changing mid-program = disputes).
- Window enforced strictly (off-by-one = lawsuits about $X commission).
- Idempotency on conversion: same `transaction_id` from advertiser must not double-record.
- Currency normalized at conversion time; store both source and base currency.
- Test conversions flagged + excluded from payouts.

### 4. Holdback + commission approval
Refunds/chargebacks must reverse before payout.

```
Conversion in pending status
  → holdback timer starts (typically 30-60 days for ecom, 7-14 for SaaS)
  → during holdback: refund/chargeback can clawback the commission
  → on holdback expiry: status → approved → payable
  → if refund event arrives during holdback: status → clawed_back; commission removed from accrued
  → if refund event arrives after payable but before paid: status → clawed_back; reversed from current period
  → if refund event arrives after paid: deduct from next payout (negative balance allowed temporarily) or invoice affiliate
```

Key invariants:
- Holdback period documented in offer terms.
- Clawback policy stated upfront (post-paid clawback most contentious).
- Affiliate can see pending vs. payable balance distinct in dashboard.
- Negative balances explicitly handled (don't pay net-positive while net-negative).

### 5. Payout cycle
```
Cycle close (e.g., monthly on 15th, for prior month conversions)
  → aggregate payable commissions per affiliate
  → check minimum payout threshold (often $50 / $100; below = roll forward)
  → check KYC + tax form validity
  → check fraud holds
  → generate payout row (gross, fees, net)
  → execute via payment method (PayPal, Wise, ACH, wire, crypto)
  → on success: payout.status = paid; commissions.status = paid
  → on failure: payout.status = failed; investigate; retry or refund-and-hold
  → notify affiliate
  → emit 1099-NEC at year-end if US affiliate ≥ $600 paid
```

Key invariants:
- Idempotency: re-running cycle close must not double-pay.
- Currency conversion documented + locked.
- Fees disclosed (PayPal fees, currency conversion spread).
- Payout reference (transaction ID) recorded for reconciliation.
- Affiliate sees cycle dashboard with line-item commissions before payout sends.

## P2 — scale + retain partners

### 6. Affiliate dashboard with real-time stats
- Clicks, conversions, conversion rate, EPC (earnings per click), revenue.
- Date range + sub_id slicing.
- Per-link performance.
- Cohort comparisons (this month vs last).
- Export to CSV.

### 7. Link generation + deeplinks
- Per-product / per-page deeplink generator (paste destination URL → get tracking link).
- Bulk-generate via CSV.
- QR code generator.
- Smart link: dynamic destination based on visitor's country / device.

### 8. Coupon-based attribution
- Affiliate-assigned coupon code at signup.
- Code redemption at checkout maps conversion to affiliate without cookie reliance.
- Coupon stacking rules (some merchants allow combining; most don't).
- Coupon expiration + reactivation.

### 9. Multi-tier / sub-affiliate
- Affiliate refers other affiliates → percentage of their downstream commissions.
- Limited tiers (typically 2-3 levels) to prevent pyramid scheme legal issues.
- Tier commission distinct from regular commission.

### 10. Fraud detection + review
```
Fraud signals computed continuously:
  - Click-to-conversion ratio anomaly (too high = self-clicks)
  - IP overlap between affiliate signup and conversion (self-attribution)
  - Velocity: N clicks/sec from one source
  - Bot UA / known proxy ranges
  - Conversion timing: instant conversion (<5sec) suspicious
  - Refund rate per affiliate (high = poor traffic quality)
  - Geographic mismatch (click from VPN, conversion from elsewhere)
  - Device / browser fingerprint repetition
  → score signals, flag for review
  → automatic action above threshold: pause commissions, hold payout
  → manual review by anti-fraud team
  → resolution: dismiss, clawback, suspend affiliate, terminate
```

### 11. Dispute resolution
- Affiliate raises dispute on rejected/clawed conversion.
- Evidence portal: traffic logs, screenshots, claim narrative.
- Merchant + network review.
- Resolution + audit trail.
- Time-bound (often 30 days from rejection).

## P3 — competitive

### 12. Multi-touch attribution + journey reports
- All clicks within attribution window stored.
- Multi-model reports (last vs first vs linear vs position-based — same data, different views).
- Path analytics ("most converting paths").

### 13. Cohort + LTV revshare
- Customer-by-customer: which affiliate brought them, their LTV, recurring commission share.
- Subscription-based programs: % of recurring revenue for N months / forever.
- Cohort decay tracking.

### 14. Creative library + asset distribution
- Banners, social posts, email templates, product images.
- Branded UTM-prepopulated.
- Co-branded landing pages.

### 15. SDK + mobile attribution
- Branch / AppsFlyer / Adjust / Singular integration for mobile installs.
- Deferred deeplinking (click → install → open → land on intended page).
- iOS SKAN compliance + deterministic where consent given.

### 16. Self-serve API for sophisticated partners
- Programmatic link generation.
- Real-time conversion + click data.
- Postback configuration.
- Webhook subscriptions.

## Attribution edge cases (define + document)

- **No referrer (direct nav after copy-paste)**: still attribute via click ID in URL or cookie.
- **Cross-device journey**: click on phone, convert on desktop. Need user-id binding (login event), or accept loss.
- **Multiple affiliates same conversion**: apply attribution model; surface in reports for transparency.
- **Self-clicks**: affiliate clicks their own link + buys. Detect IP / fingerprint / payment-method overlap → reject.
- **Existing customer click**: customer already exists; clicked affiliate link, then converted. Many merchants exclude existing-customer conversions from commission. Define + enforce.
- **Returning user beyond window**: clicked 60 days ago, converts today, window 30 days. No commission.
- **Pre-conversion refund (failed payment)**: refund hits before conversion approved → clawback before paid; clean.
- **Partial refund**: refund $20 of $100 order. Commission proportionally clawed back.
- **Coupon used without click**: organic, customer Googled coupon. Coupon-attribution policy: attribute to coupon owner OR mark organic. Define.

## Idempotency-critical endpoints

- `POST /track/click` — same click ID + same fingerprint within seconds = single click; later identical request = no-op.
- `POST /track/conversion` — same `transaction_id` from advertiser = single conversion row.
- `POST /postbacks/[provider]` — same `event_id` from provider = single processing.
- `POST /payouts/run` — re-run for same period = no double-payment; check existing payout per affiliate per period.
- `POST /commissions/clawback` — re-clawback same conversion = no-op.

## Webhooks the system must produce

- `affiliate.approved`, `affiliate.suspended`.
- `click.recorded` (high-volume; usually batched/streamed).
- `conversion.recorded`, `conversion.approved`, `conversion.clawed_back`.
- `commission.payable`.
- `payout.scheduled`, `payout.paid`, `payout.failed`.
- `fraud.flagged`.

## Webhooks the system must consume

- Advertiser/merchant: order placed (S2S postback) — primary conversion source.
- Payment processor: refund / chargeback events → trigger clawbacks.
- Tax provider: 1099 generation status.
- Payout provider: payment success / failure / dispute.
- MMP (Branch/AppsFlyer): mobile install + post-install events.
