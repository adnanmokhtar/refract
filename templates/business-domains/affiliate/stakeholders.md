# Affiliate — stakeholders

Affiliate programs balance three primary interests (affiliate / merchant / network) with adversarial dynamics around fraud + clawbacks. Each stakeholder workflow shapes the platform.

## Affiliate / Publisher

The supply side. Without quality affiliates, no traffic; without trust, no quality affiliates.

### Solo content affiliate
- Blogger, YouTuber, podcaster, newsletter writer.
- Workflow: review product → embed link/coupon → audience clicks → conversion → commission → payout.
- 1-10 active programs typically; modest revenue; high engagement with brand fit.

### Coupon / deal site
- RetailMeNot / Honey / Slickdeals model.
- Aggregator of coupons across many programs.
- Often controversial (passes value vs sources value).
- High volume, low conversion-quality; commission caps common.

### Cashback / loyalty site
- Rakuten / TopCashback / Honey Gold.
- Refunds part of commission to user as cashback.
- Drives repeat purchase but raises CAC dilution questions.
- Compliance with disclosure rules required.

### Influencer
- Instagram / TikTok / YouTube / Twitter creator with audience.
- Affiliate income often secondary to brand-deal income.
- Workflow: link in bio → swipe-up / link sticker.
- Disclosure compliance increasingly platform-enforced.

### Comparison site
- Wirecutter, NerdWallet, finance/insurance/SaaS reviews.
- High conversion intent; high commissions (esp. finance).
- Long-form content + SEO investment.

### Sub-affiliate network operator
- Aggregates downstream affiliates; manages relationships with merchant.
- Master-affiliate gets % of all sub-affiliate commissions.
- Multi-tier compensation.

### Paid traffic affiliate (mediabuyer)
- Buys ads on Google / Meta / TikTok / native; arbitrages to affiliate offers.
- High volume, narrow margins.
- Compliance heavy (TM bidding restrictions, ad-network policies, geo).
- Most fraud-prone segment: incentivized traffic, bots, click farms.

**Universal pain points:**
- "When + how much do I get paid?" — clarity on cycle, threshold, holdback.
- "Why was this conversion rejected?" — transparency on reasons + appeal.
- "Is my commission rate competitive?" — benchmark visibility.
- "Are my links working?" — real-time stats + diagnostic tools.
- "I lost a sale to a coupon code I don't have access to" — coupon attribution policy clarity.
- "Cookie deprecation killed my reporting" — server-side tracking + non-cookie methods.

**KPIs:**
- EPC (Earnings Per Click).
- CR (Conversion Rate).
- Reversal rate (% of conversions clawed back).
- Total earnings.
- Time-to-payment.

## Merchant / Advertiser

The demand side. Funds the program; defines offers + commission; manages affiliate quality.

### Affiliate program manager
- Owns the program day-to-day.
- Recruits affiliates, negotiates commissions, manages payouts.
- Reviews fraud + disputes.
- Reports to marketing leadership.

**Workflows:**
- Daily: monitor performance, review pending applications, respond to top-affiliate inquiries.
- Weekly: analyze top performers, identify under-performers, plan promo periods.
- Monthly: payout cycle, fraud audit, performance review.
- Quarterly: program optimization, terms updates, network negotiations.

**Pain points:**
- "Top 10% of affiliates drive 90% of revenue" — need to identify + retain them.
- "Fraud signals are noisy" — false positives anger legitimate affiliates.
- "Margin erosion from coupon affiliates" — define + enforce coupon policy.
- "Conversion rate is dropping" — diagnose attribution loss vs real performance issue.
- "Tax / 1099 deadline" — annual scramble.

**KPIs:**
- ROAS (Return on Ad Spend) on affiliate channel.
- Affiliate-attributed revenue / total revenue.
- New customer % via affiliates.
- Top-affiliate retention.
- Fraud rate.

### Marketing director
- Strategic view of channel mix.
- Budget allocation across channels (search / social / affiliate / influencer / email).
- Wants attribution clarity to make budget decisions.

### Finance / accounting
- Liability for accrued commissions (balance sheet item).
- Forecasting: pending commission likely to be paid vs clawed back.
- Tax filing (1099, 1042-S, VAT).
- Wants clean exports + accruals reconciliation.

### Legal + compliance
- Reviews program terms.
- Manages disclosure compliance (FTC + ASA + platform).
- Handles disputes that escalate to legal.
- Sanctions + AML compliance.

## Network operator (if affiliate network)

The platform sits between merchants + affiliates; charges take rate.

### Network business team
- Recruits merchants.
- Recruits + activates affiliates.
- Sets network fees.
- Partnership with payment + fraud + KYC providers.

### Network operations
- Payout cycle execution.
- Cross-merchant fraud detection.
- Tax form processing.
- Customer support (both sides).

**KPIs:**
- GMV through network.
- Take rate margin.
- Active merchants / active affiliates.
- Fraud / clawback ratio.
- Net Promoter Score (both sides).

## Anti-fraud team

### Fraud analyst
- Reviews flagged conversions / affiliates daily.
- Investigates patterns (IP clusters, device fingerprints, behavioral).
- Builds + tunes detection rules.
- Decisions: dismiss / clawback / suspend / terminate.

**Pain points:**
- "Manual review doesn't scale" — need automation + risk scoring.
- "Affiliate disputes after termination are emotionally exhausting" — need clear evidence + workflow.
- "Cross-network fraud signals missing" — subscribe to industry blocklists.

### Fraud engineering
- Builds detection models.
- Integrates third-party fraud signals (FraudShield, Forensiq, Anura, DeviceAtlas).
- Maintains rules engine + scoring service.

**KPIs:**
- Fraud detection rate.
- False positive rate.
- Recovered commission $ (clawbacks before paid).
- Mean time to detect.

## Affiliate manager (top-tier affiliates)

Either employed by merchant or by network; relationship-managed approach for high-revenue partners.

**Workflow:**
- Quarterly business reviews with top affiliates.
- Custom commission negotiation.
- Promo period coordination.
- New product launches communicated early.
- Issue escalation point for top partners.

**Pain points:**
- Top affiliates demand exclusive offers / higher commission / advance notice.
- Manager balancing favoritism complaints from non-top affiliates.

## Customer support

Handles non-fraud issues for affiliates: link broken, payment didn't arrive, dashboard slow.

**Workflows:**
- Inbound ticket triage.
- Common: payment status, tax form, link issues, "where's my conversion?"
- Escalation to fraud team, finance, engineering.

## Customer (the end consumer)

Doesn't usually interact with the affiliate platform directly, but their behavior IS the data.

**Implications:**
- "Where's my coupon?" → support ticket if affiliate's coupon broken.
- Privacy concerns: cookie consent surface; data subject access requests.
- May not know they're "tracked" — disclosure compliance protects this.

## Auditor / compliance officer

- Audits payment compliance (KYC, AML, sanctions, tax).
- Audits disclosure compliance (FTC, ASA).
- Reviews dispute handling for legal exposure.
- Episodic: regulator inquiry, due diligence for acquisition.

**Permissions:**
- Read-only across full platform with all access logged.

## Stakeholder-driven feature priorities

When deciding what to build:

| If user complaint is from... | Then priority is... |
|---|---|
| Affiliates: "where's my money?" | Real-time pending earnings + payment history transparency |
| Affiliates: "conversion rejected without reason" | Rejection-reason transparency + appeal flow |
| Merchants: "fraud is eating margin" | Fraud detection + cross-network blocklist + manual review queue |
| Merchants: "can't tell which affiliates are quality" | Cohort LTV reporting + conversion-quality scoring |
| Finance: "month-end reconciliation is hell" | Clean accruals + holdback ledger + accounting integration |
| Compliance: "audit findings on disclosure" | Affiliate disclosure enforcement + policy acknowledgment |
| Top affiliates: "want better terms" | Tier system + custom commission + AM relationship |
| Customer support: "drowning in 'where's my payment' tickets" | Self-serve payment status + automatic notifications |

## Anti-pattern: "merchant is also the affiliate manager + finance + fraud"

Early-stage ecommerce founders try to run their own affiliate program solo. Within 12 months: fraud unmanaged, margin destroyed, top affiliates churn for managed networks.

Build with the assumption that program will be operated by: (1) program manager, (2) finance, (3) fraud team — even if one person plays all three roles initially. Permissions + audit + workflows should already separate concerns.
