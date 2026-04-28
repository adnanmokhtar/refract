# Affiliate — feature checklist

The 80%-of-projects-need-this list. Affiliate v1s commonly ship without fraud detection, holdback enforcement, or proper tax handling — then watch margins evaporate and IRS letters arrive.

Use this in `business-auditor` reviews + as a P1/P2/P3 planning anchor.

## Affiliate-facing (publisher portal)

### Onboarding
- [ ] Application form with required fields: contact, country, traffic sources, website(s), audience size.
- [ ] Tax form upload (W-9 US, W-8BEN non-US, local equivalent).
- [ ] Payment method setup (PayPal email, Wise, IBAN, ACH, crypto wallet).
- [ ] Identity verification (KYC) — increasingly required for crypto / high-volume.
- [ ] Acceptance of program terms (versioned + audit-logged).
- [ ] Welcome / orientation flow.
- [ ] Approval status visibility ("pending review", "additional info needed").

### Link generation
- [ ] Default tracking link per program/offer.
- [ ] Custom deeplink generator (paste destination → get tracking link).
- [ ] Sub-IDs (5 sub-fields typical) for self-segmentation (sub1=campaign, sub2=banner_position, etc.).
- [ ] QR code download.
- [ ] Bulk link generator (CSV in / CSV out).
- [ ] Smart links (geo / device routing built into one link).

### Coupon codes
- [ ] Personal coupon code at signup (vanity option: AFFNAME20).
- [ ] Coupon details: discount value, expiry, usage limit, geo, product restrictions.
- [ ] Coupon performance breakdown (uses, conversions, revenue).

### Performance dashboard
- [ ] Real-time clicks + conversions + revenue.
- [ ] EPC (earnings per click), CR (conversion rate).
- [ ] Date range filter.
- [ ] Sub-ID breakdown.
- [ ] Per-link performance.
- [ ] Per-offer performance.
- [ ] Pending vs approved vs paid commission split.
- [ ] Payment history.
- [ ] Export to CSV / Excel.

### Earnings + payments
- [ ] Current cycle accrued earnings.
- [ ] Pending (in holdback) clearly distinct from payable.
- [ ] Next payout date + minimum threshold visibility.
- [ ] Payment method change (with re-verification).
- [ ] Past payouts list with reference numbers.
- [ ] Tax form download (1099 at year-end for US affiliates).
- [ ] Negative balance handling visible (clawbacks visible separately).

### Creative library
- [ ] Banner downloads (multiple sizes).
- [ ] Email templates (HTML + plain).
- [ ] Social media graphics + copy snippets.
- [ ] Product feeds (CSV / XML / API) for content sites.
- [ ] Co-branded landing pages.
- [ ] Video assets / B-roll.

### Communications
- [ ] In-portal announcements (new offers, promo periods).
- [ ] Email digest (weekly performance summary).
- [ ] Promo notifications (commission boost periods).
- [ ] Direct messaging with merchant manager (or ticketing).

### Disputes + appeals
- [ ] Dispute UI for rejected conversions.
- [ ] Evidence upload.
- [ ] Status tracking (submitted → under review → resolved).
- [ ] Appeal of suspension / termination.

## Merchant-facing (advertiser portal)

### Program management
- [ ] Create program with: name, default commission, attribution window, cookie duration, payout terms.
- [ ] Multiple offers within program (different products, different commission tiers).
- [ ] Pause / resume / archive offer.
- [ ] Program landing page for affiliate recruitment.
- [ ] Program terms versioning.

### Affiliate management
- [ ] Application review queue.
- [ ] Approval / rejection with reason.
- [ ] Affiliate list with filters (status, country, performance).
- [ ] Per-affiliate detail: traffic sources, performance, fraud signals, communications history.
- [ ] Suspend / reinstate / terminate affiliate.
- [ ] Bulk actions.

### Conversion review
- [ ] Pending conversions queue.
- [ ] Bulk approve / reject.
- [ ] Per-conversion detail: click source, customer journey, fraud score.
- [ ] Manual conversion entry (offline orders attributed to affiliate).
- [ ] Adjustment / clawback UI.

### Commission management
- [ ] Tier overrides per affiliate (negotiated rates for top performers).
- [ ] Bonus / promo pricing (boost commission for date range).
- [ ] Per-product commission overrides.
- [ ] Recurring commission (subscription products) configuration.

### Reporting
- [ ] Top affiliates by revenue / conversions / EPC.
- [ ] Top offers / products / SKUs.
- [ ] Cohort analytics (acquisition source LTV).
- [ ] Refund / clawback rate per affiliate (quality signal).
- [ ] Commission liability (accrued + pending) — accounting-critical.
- [ ] Export to CSV / accounting integration.

### Fraud + risk
- [ ] Fraud signal dashboard with top flagged affiliates.
- [ ] Per-conversion fraud score visibility.
- [ ] Blocklist management (IPs, emails, payment instruments, fingerprints).
- [ ] Cross-network fraud blocklist subscription (FraudShield / Forensiq / Anura).
- [ ] Audit trail of moderation actions.

### Settings + integrations
- [ ] Postback URL configuration (advertiser → network for conversion notifications).
- [ ] Webhook subscriptions for events.
- [ ] API key management.
- [ ] Tracking pixel / SDK download for site / app installation.
- [ ] White-label customization (if SaaS).

## Network / platform-facing (if affiliate network)

- [ ] Merchant onboarding + KYC + contract management.
- [ ] Cross-merchant affiliate discovery (browse programs).
- [ ] Network-wide commissions ledger.
- [ ] Marketplace settings (network take rate, transparency).
- [ ] Compliance team workflow (escalations, regulator inquiries).

## Trust + compliance

- [ ] FTC disclosure guidance (affiliate must include "as an affiliate I earn..." or platform-mandated badge).
- [ ] GDPR consent for cookies (banner blocking until accept; click can still server-side-record).
- [ ] Tax form storage (encrypted, restricted access).
- [ ] 1099-NEC generation + e-file (US, year-end, ≥$600).
- [ ] AML / sanctions screening (high-volume payouts).
- [ ] OFAC sanctions list check at signup + per payout.
- [ ] Privacy policy detailing data handling on click + conversion.
- [ ] Data Processing Agreement (DPA) with affiliates as data processors.
- [ ] Audit log of all admin actions (commission overrides, manual conversions, terminations).

## Operational

- [ ] Click endpoint < 50ms p99 (in-band redirect must not slow user).
- [ ] Conversion postback retry on transient failure (provider-side).
- [ ] Idempotent processing of all postbacks.
- [ ] Click tracking ingestion at 10K+ qps for active networks.
- [ ] Daily reconciliation: postbacks vs. attributed conversions vs. accrued commissions.
- [ ] Currency rate cache + manual override capability.
- [ ] Backup of conversion ledger (financial source of truth).
- [ ] DR plan (financial data downtime = direct revenue loss).
- [ ] On-call for payout cycle days.

## Things v1s commonly miss

- Fraud detection until fraud is already happening (clawback nightmare; affiliates churn).
- Holdback enforcement (commissions paid before refund window closes; never recoverable).
- Idempotent conversion postback handling (one merchant retry = double commission).
- Self-attribution detection (affiliate clicks own link + buys; not flagged).
- Existing-customer exclusion (every customer who Googles for coupon code triggers commission; margin destroyed).
- Tax form requirement before first payout (IRS audit liability).
- 1099 generation (manual emails to affiliates at year-end; messy + non-compliant).
- Multi-currency handling at payout (lost in conversion spread; no transparency).
- Negative balance handling (clawbacks paid out as positive next month; double-loss).
- Cross-device attribution (most modern conversions are cross-device; uncaptured).
- Coupon attribution priority unclear (when click + coupon both apply, who wins?).
- Affiliate dashboard latency (real-time stats not real-time; affiliates lose trust).
- Test conversions polluting production reports (commissioned).
- No dispute resolution path (rejected affiliates loud on Twitter / forums).
- Attribution model not documented in TOS (lawsuits over $X commission).
- Ban appeals not handled (legitimate affiliates terminated by mistake; reputation damage).

## Things often over-built in v1 (defer until validated)

- Multi-touch attribution UI (last-click works for 90% of programs).
- Mobile SDK + deferred deeplinking (web-only is fine until you have an app).
- Influencer-specific tooling (link-in-bio, tracker-of-trackers).
- Programmatic API for partners (most affiliates use the dashboard).
- White-label network (build single-merchant first; multi-tenant is 5x complexity).
- Crypto payouts (ACH + PayPal cover 95% of affiliates).
- Tier-based gamification (gold/platinum status).
- AI-generated creative (link-in-bio is enough at v1).
- Co-branded landing pages (affiliates use direct deeplinks until volume justifies).
- Recurring revshare with cohort decay modeling (flat % works initially).
