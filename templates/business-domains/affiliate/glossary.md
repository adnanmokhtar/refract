# Affiliate — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `affiliate`:

**Entity / model names**: `Affiliate`, `Partner`, `Publisher`, `Program`, `Offer`, `Campaign`, `Link`, `TrackingCode`, `Click`, `Lead`, `Conversion`, `Attribution`, `Commission`, `Payout`, `Settlement`, `Referral`, `Coupon`, `Postback`.

**Folder / route names**: `affiliates/`, `partners/`, `publishers/`, `tracking/`, `clicks/`, `conversions/`, `commissions/`, `payouts/`, `/r/[code]`, `/track`, `/postback`, `/click`.

**Dependencies (any language)**: `tune` / `everflow` / `cake` / `affise` / `hasoffers` SDKs, `branch.io`, `appsflyer`, `adjust`, `singular`, `kochava`, `tapfiliate`, `refersion`, `impact`, `partnerstack`, `awin`, `cj`.

**Database schema**: tables for `clicks` + `conversions` + `commissions` + `payouts` keyed on a `tracking_code` is the strongest signal. Presence of `(click_id, conversion_id)` join with `attribution_window_seconds` → affiliate.

**Distinguishing from referral**: referral is consumer-to-consumer ("invite a friend, both get $10"), often once per relationship, simpler payouts. Affiliate is professional-publisher-to-merchant with continuous commissioning, fraud risk, and payout schedules.

**Distinguishing from ad networks**: ad networks pay per impression / click (CPM / CPC). Affiliate networks pay per conversion / sale (CPA / RevShare). If the system pays before any conversion event → ad network, not affiliate.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Affiliate` / `Partner` | a publisher account | `id, email, company_name, contact_name, tax_id, country, payment_method, status, joined_at` | applied → approved → active → suspended → terminated |
| `Program` | merchant's offer suite | `id, merchant_id, name, default_commission_rate, attribution_window_seconds, default_cookie_duration_days, status` | draft → active → paused → archived |
| `Offer` | specific promotion within a program | `id, program_id, name, commission_type (percent/flat/tiered), commission_value, payout_basis (sale/lead/install), terms, geo_restrictions, status` | active → paused → archived |
| `TrackingLink` | unique URL with affiliate's identifier | `id, affiliate_id, offer_id, code, destination_url, custom_params (sub_id_1..5), created_at` | active → expired |
| `Click` | recorded click on tracking link | `id, link_id, affiliate_id, offer_id, ip, user_agent, referer, sub_ids[], created_at, fingerprint` | recorded → attributed → expired |
| `Lead` | pre-conversion event (form fill, signup) | `id, click_id?, offer_id, email_hash?, payload, created_at` | recorded → qualified → converted |
| `Conversion` | revenue event tied back to a click | `id, click_id?, offer_id, order_value, currency, transaction_id, status (pending/approved/rejected/clawed_back), conversion_at` | pending → approved (after review window) → paid (or rejected/clawed_back) |
| `Attribution` | logic linking click(s) to conversion | not always its own row; rules: last-click / first-click / linear / position-based | computed at conversion time |
| `Commission` | money owed for a conversion | `id, conversion_id, affiliate_id, amount, currency, status (accrued/holdback/payable/paid/clawed_back)` | accrued → holdback → payable → paid |
| `Payout` | aggregated commissions paid out | `id, affiliate_id, period_start, period_end, gross_amount, fees, net_amount, currency, method, reference, status, paid_at` | scheduled → processing → paid → failed |
| `FraudSignal` | detection event flagging suspicious activity | `id, signal_type, source_id (click/conversion/affiliate), severity, evidence, action_taken, created_at` | new → reviewed → actioned |
| `Coupon` | discount code attributable to an affiliate | `code, offer_id, affiliate_id?, attribution_priority, type, value` | active → expired |
| `Postback` | server-to-server conversion notification | `id, source (advertiser_postback/network_inbound), payload, signature, processed_at` | received → processed → reconciled |
| `Approval` | merchant gate on affiliates | `id, affiliate_id, program_id, status, reviewer_id, reason, decided_at` | pending → approved/rejected |

## Status state machines

**Affiliate:**
```
applied → approved → active → suspended (temporary) → reinstated
                        ↓                    ↓
                   terminated (permanent) ← failed_kyc / fraud
```

**Conversion:**
```
recorded → pending (in holdback / review window) → approved → paid
              ↓                                       ↓
          rejected (no attribution / fraud)       clawed_back (refund / chargeback / fraud)
```

**Commission:**
```
accrued → holdback (pending review) → payable → batched → paid
                                                ↓
                                          held (KYC pending / threshold not met)
                                                ↓
                                          clawed_back
```

**Payout:**
```
scheduled → processing → paid
                ↓
            failed (retry) → re-scheduled OR cancelled (manual review)
```

## Vocabulary distinctions (don't conflate)

- **Click** vs **Lead** vs **Conversion** — Click: link tap. Lead: pre-revenue event (signup, form fill). Conversion: revenue-bearing event (sale, install, qualified lead).
- **CPA** vs **CPL** vs **CPS** vs **RevShare** — CPA: cost per acquisition (flat per conversion). CPL: cost per lead. CPS: cost per sale (% of order value). RevShare: ongoing % of customer's lifetime value.
- **Last-click** vs **First-click** vs **Multi-touch** attribution — Last-click: 100% credit to most recent click within window. First-click: 100% to original click. Linear: equal split across touches. Position-based: 40/20/40 (first/middle/last).
- **Attribution window** vs **Cookie duration** — Attribution window: max time between click and conversion to attribute. Cookie duration: how long the tracking cookie persists (often same number; not always).
- **Holdback period** vs **Lock period** — Holdback: time conversion sits in pending before payable (allows refund/chargeback to settle). Lock: minimum payout threshold not met → wait for next period.
- **Clawback** vs **Reversal** vs **Rejection** — Clawback: previously-approved commission removed (refund/chargeback). Reversal: payment failed; reversed before sent. Rejection: never approved (fraud, no attribution).
- **Sub-ID** / **Sub-Affiliate ID** — affiliate's internal identifier passed through tracking link (`sub1=campaign1&sub2=banner3`); allows affiliate to slice their own performance.
- **Postback** vs **Pixel** — Postback: server-to-server notification with conversion data. Pixel: client-side image/script that fires on conversion page (less reliable; ad-blockable).
- **MMP** (Mobile Measurement Partner) — Branch / AppsFlyer / Adjust; SDK-based attribution for mobile installs.
- **Coupon attribution** vs **Link attribution** — Coupon: code at checkout maps to affiliate (works without click tracking). Link: click ID stored in cookie maps to conversion. Coupon attribution often takes priority over link in dispute.

## Multi-tenancy variants

- **Single-merchant program**: one merchant runs their own affiliate program (Refersion, Tapfiliate). Tenant boundary = none.
- **Affiliate network**: many merchants + many publishers, network in middle (CJ, Awin, Impact). Tenant boundary = `network_id`; merchants and affiliates are sub-entities; ledgers per merchant.
- **SaaS affiliate platform**: white-label network deployed for many networks. Tenant = network. Common in B2B affiliate tooling.

## Tracking mechanisms (in order of reliability)

1. **Server-to-server postback with click ID**: most reliable; ad-block-immune; first-party.
2. **Coupon code at checkout**: reliable; ad-block-immune; doesn't require cookie; loses click context.
3. **First-party cookie (1P)**: post-ITP/ETP; ~7 days max in Safari; resilient elsewhere.
4. **First-party fingerprinting + IP**: probabilistic; gray area for GDPR consent.
5. **Third-party cookie (3P)**: deprecated in Chrome 2024+, dead in Safari/Firefox.
6. **Last-resort fingerprinting (UA + IP + screen)**: weakest; ad-block tools target it.

The shift to server-side + first-party tracking + coupon attribution is the dominant industry trend.
