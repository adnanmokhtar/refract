# Affiliate — domain-specific anti-patterns

Generic code review (DRY, SRP, etc.) misses these. They're traps you only learn when commission liability balloons, fraudsters drain margin, or affiliates riot on Twitter.

## Tracking + attribution

- **Click counted multiple times.** No IP / UA / fingerprint dedupe → curious user clicking 5 times = 5 clicks. Rate-limit + dedupe within (link_id, fingerprint, window).
- **Self-attribution loop.** Affiliate clicks own link from own browser, then converts. No detection → commission paid to self. Compare click IP / device / payment-method-on-conversion to affiliate signup IP / device.
- **Existing-customer commission.** Customer who has bought 10 times Googles a coupon → affiliate gets commission for inevitable purchase. Define + enforce existing-customer exclusion (typically: customer with order in last 12 months excluded).
- **Cross-device journey lost.** Customer clicks affiliate link on phone, returns to desktop, buys. No login binding → unattributed. Bind click_id to user_id at signup/login event; resolve at conversion.
- **Attribution model not documented.** Last-click vs first-click vs linear — affiliates dispute. Document in offer terms; enforce consistently; never silent-change.
- **Attribution model changed mid-program.** Conversions before change calculated one way, after another → angry affiliates + lawsuits. Apply changes to new conversions only; grandfather existing.
- **Window enforced as days, not seconds.** "30 days" interpreted as 30 calendar days, but conversion at 30d 23h ambiguous. Enforce as seconds; document precisely.
- **Cookie set on shared device.** Family laptop; one click; everyone's purchase attributed. Combine with login fingerprint to disambiguate where possible.
- **Coupon attribution priority undefined.** Customer clicks affiliate A's link, then uses affiliate B's coupon at checkout. Who gets credit? Define: typically coupon wins (more recent intent), but document.
- **Coupon attribution to organic traffic.** Customer never clicked any link, found coupon via Google → coupon owner gets commission for organic. Define: attribute or organic-mark; cap at offer terms.
- **Postback received but click not found.** Network had issue; click row missing. Conversion attributed to "unknown affiliate" → either commissioned to none (bug) or to a default (worse). Reconcile + log.

## Commission + payouts

- **Commission paid before holdback expires.** Refund hits day 45; commission already paid; clawback impossible without affiliate cooperation. ENFORCE holdback in payout query (`status = 'payable' AND holdback_until < now()`).
- **Holdback period too short for product type.** Subscription with 60-day refund window + 30-day holdback → most refunds hit after payout. Match holdback to refund window.
- **Holdback not reset on order modification.** Customer modifies order, value changes, original conversion record stale. Re-evaluate commission on order events.
- **Negative balance paid as positive.** Affiliate has $200 in clawbacks + $300 in payable → net $100 paid; system pays $300 instead. Net always; if total < 0, hold + invoice.
- **Currency conversion at payout vs accrual.** Conversion in USD at $1=€0.92, payout in EUR when $1=€0.85 → discrepancy. Document FX policy: lock at conversion vs payout time; affiliates need consistency.
- **PayPal fees deducted silently.** $100 commission paid as $96.50 with no breakdown → affiliate confusion. Show fees explicitly + offer alternative methods (Wise often cheaper).
- **Minimum payout threshold not communicated.** $50 minimum but affiliate has $30 → no payout, no notice → "where's my money?" tickets. Show next-cycle status + threshold prominently.
- **Threshold balance rolls forever.** Affiliate accumulates $40 for 5 years; never paid. Annual cleanup or aged-balance forced payout.
- **Tax form expired.** Affiliate's W-9 / W-8 from 3 years ago; IRS rules require periodic renewal. Track + prompt renewal before payout block.
- **1099 not issued for $600+.** IRS audit liability. Automate generation + e-file before Jan 31.
- **Backup withholding not applied when W-9 missing.** Should withhold 24% if no valid TIN. Otherwise IRS holds platform liable.
- **Payout method change without re-verification.** Account takeover → attacker changes payout email → next payout drained. Re-verify on method change (email confirm to original method; cooling period).

## Fraud + abuse

- **No fraud detection until first incident.** "We'll add it later" — first sophisticated affiliate ring drains $50K before detection. Day-one fraud rules: velocity caps, IP / fingerprint dedupe, geo mismatch, proxy detection.
- **Bot traffic counted as click.** Curl + wget + crawler UAs not filtered → inflated click count → low CR → affiliate looks fraudulent → terminated for engineering bug. Maintain known-bot UA list + verify Googlebot via reverse DNS.
- **Click farm signature missed.** Same fingerprint, different IPs (residential proxy network), distributed timing. Pattern detection: device entropy, behavioral fingerprint, mouse movement.
- **Incentivized traffic on non-incentive offer.** Affiliate runs "click here for prizes" against an offer that prohibits incentivized traffic → conversions but customers churn. Cohort LTV reveals; offer terms must enforce.
- **Cookie stuffing not detected.** Affiliate sets affiliate cookie on every visitor without click action (iframe / image hack). Audit click-to-impression ratios; FTC + criminal exposure for affiliate.
- **Trademark bidding violation.** Affiliate bids on merchant brand keywords in Google Ads → cannibalizes merchant's organic + paid; violates terms. Use BrandVerity / Trademark Watcher; clawback + warn + terminate.
- **Coupon code distribution outside terms.** Affiliate posts "exclusive" coupon to public deal site → leaks to all traffic. Monitor coupon redemption sources.
- **Cross-network blocklist not subscribed.** Repeat fraudsters move from network to network. Industry blocklists (Forensiq, Anura, FraudShield) catch them.
- **Affiliate's traffic sources not monitored over time.** Approved with "I run a blog" → 6 months later running paid ads against terms. Periodic re-verification.
- **Sanctions screening absent.** Payout to OFAC-sanctioned individual / entity → federal crime. Screen at signup + every payout.

## Disputes + appeals

- **No appeal process for terminated affiliates.** Legitimate affiliate falsely flagged → terminated → no recourse → public outrage → reputation damage. Mandatory appeal flow with human review.
- **Dispute resolution untimed.** Affiliate disputes a clawback → 6 months later, no response. Set SLA + escalation.
- **Evidence not preserved.** Affiliate disputes; system can't show original click data because retention policy purged it. Preserve full conversion + click trail through dispute window.
- **Manual override not audit-logged.** Manager grants commission outside system → no audit → fraud or favoritism. Log with reason; require approval threshold.
- **Bulk-decision tool used without review.** "Approve all pending" button used to clear queue without per-conversion check → bad-faith conversions paid out. Bulk action requires sample review.

## Reporting + dashboards

- **Real-time stats not real-time.** Hourly batch updates; affiliate sees 0 clicks while link works → distrust + duplicate test clicks pollute data. Stream events; tolerate seconds-of-lag worst case.
- **Pending vs payable conflated.** Affiliate sees $1000 "earned" → expects payout → only $100 payable. Distinct columns + tooltip explaining.
- **Reports lag accruals.** Conversion happened 2 days ago, not in report yet → affiliate dispute. Pipeline lag SLA + status indicator.
- **Currency display inconsistent.** Dashboard shows USD; payout in EUR; tax form in EUR equivalent of USD at different rate → trust collapse. Single currency display + breakdown.
- **Date-range timezone confusion.** Reports in UTC, affiliate in PST → "today" mismatch. Display affiliate's preferred timezone + indicate.
- **Sub-ID slicing missing.** Affiliate can't see which campaign / banner converted → can't optimize → leaves for network that supports it.
- **Test conversions pollute reports.** QA test orders show as commission. Test mode flag + filter from financial reports + dashboards.

## Coupons

- **Coupon stacking with sale.** 30% sale + 20% affiliate code + commission on full price → margin destroyed. Define stacking rules + commission on net-of-discount.
- **Coupon usage limit unenforced.** "First 100 uses" code but no counter → unlimited use → unbudgeted commission. Atomic decrement + cap.
- **Coupon expired but still attributing.** Code disabled at checkout but affiliate still credited via cookie → double issue. Coupon disable cascades to attribution.
- **Coupon ownership ambiguity.** Code shared across affiliates → cannot distinguish source. One code = one affiliate; vanity codes per partner.
- **Coupon attribution overrides last-click silently.** Affiliate A drove click; affiliate B's coupon used; A loses; A doesn't know why. Surface attribution decision + reason in conversion record.

## Postbacks + integrations

- **Postback handler not idempotent.** Provider retries identical event → double conversion → double commission. Dedupe on `event_id` from provider.
- **Postback handler that throws fails ack.** Provider escalates retry → handler keeps throwing → cascading load. Catch + log + ack; reprocess from queue.
- **Postback signature not verified.** Anyone can POST a fake conversion. Verify HMAC signature with shared secret per integration.
- **Postback with unencrypted PII.** Customer email in postback URL → in proxy logs + crawler logs. Hash or omit.
- **Webhook configuration without test mode.** Affiliate / merchant configures wrong URL → conversions silently lost → discovered weeks later. Test mode + verify before activation.
- **Mobile install attribution mis-deduped.** Same install fired twice through different MMPs (Branch + AppsFlyer) → double commission. Dedupe across sources by install fingerprint.

## Privacy + cookie compliance

- **Cookie set before consent.** Tracking cookie set at click landing → GDPR violation. Server-side click recording before cookie; cookie only after consent.
- **IP stored unhashed long-term.** GDPR personal data; minimize. Hash or anonymize after attribution complete.
- **No deletion process for click data.** Right to erasure ignored. Deletion endpoint + propagation through analytics + reports.
- **Cross-border data transfer without SCCs.** EU clicks routed to US warehouses without legal basis → Schrems II violation.
- **"Strictly necessary" cookie classification mis-applied.** Tracking cookie labeled essential; user can't opt out. Misclassification penalty.
- **Affiliates' email addresses sold or shared without consent.** Sub-affiliate marketplaces + secondary uses violate GDPR purpose-limitation.

## Operational

- **Click endpoint slow.** > 200ms 302 redirect → user perception of broken link → drop-off → conversion loss. <50ms p99 target; CDN'd if possible.
- **Click row written async after redirect.** "Fire and forget" to queue → queue full → clicks lost. Synchronous write before redirect; tail-loss acceptable only with replay capability.
- **Daily reconciliation absent.** Conversions vs postbacks vs commissions diverge → no detection until quarterly close. Daily reconciliation job + alerts on drift.
- **Single point of failure on conversion recording.** DB outage = conversion permanently lost. Queue + retry + dead-letter.
- **Payout cron runs on every node.** Cluster of 3 → potentially 3x payouts. Leader election or distributed lock.
- **Test mode bleeds into production.** Test conversions appear in real reports + commissions. Strict separation; flag-based exclusion.
- **No monitoring on EPC drop.** Affiliates see falling EPC; merchant doesn't notice; trust erodes silently. Alert on cohort EPC degradation.
- **Tracking domain SSL expired.** Click endpoint serves SSL error → all affiliates' traffic dies for hours. Automated cert renewal + monitoring.
