# Fintech — feature checklist

What every fintech v1 needs. Most v1s underbuild compliance + over-build product features; the ratio is usually wrong.

## Customer-facing

### Onboarding
- [ ] Email + phone verification (OTP).
- [ ] KYC document upload (resumable, mobile camera).
- [ ] Liveness / selfie verification.
- [ ] Business KYB flow (separate; with UBO collection).
- [ ] Address verification.
- [ ] PEP / sanctions disclosure (self-declaration form).
- [ ] Saved drafts so users complete in multiple sessions.
- [ ] Status tracking: "in review," "approved," "needs more info" with action steps.
- [ ] Rejection reason in clear language (translate provider error codes).

### Account
- [ ] Account dashboard with available + posted + pending balance distinct.
- [ ] Transaction list with filter (date, type, amount, merchant).
- [ ] Transaction detail (counterparty, FX, fees, status timeline).
- [ ] Statement download (PDF, CSV) per period.
- [ ] Tax document download (1099-INT, etc.) annually.
- [ ] Profile management (limits, KYC level, preferences).
- [ ] Multi-account view (if user has multiple accounts).

### Money movement
- [ ] Deposit via card / ACH / wire / external bank pull.
- [ ] Withdrawal to verified external bank.
- [ ] P2P transfer (in-platform).
- [ ] Beneficiary management (add, verify, edit, delete).
- [ ] Recurring / scheduled transfers.
- [ ] Multi-currency transfer with FX quote.
- [ ] Limits visibility (today's remaining, monthly remaining).
- [ ] Step-up auth on high-amount or risky transactions (3DS, OTP, biometric).

### Cards (if issuing)
- [ ] View virtual card details (PAN/CVV via PCI-compliant reveal).
- [ ] Physical card order + tracking.
- [ ] Activate physical card.
- [ ] Freeze / unfreeze card.
- [ ] Set per-tx and daily limits.
- [ ] Block specific MCC (gambling, ATM, online).
- [ ] Block specific countries.
- [ ] Replace lost / stolen.
- [ ] Add to Apple Pay / Google Pay (push provisioning).

### Disputes / support
- [ ] File dispute on transaction.
- [ ] Track dispute status.
- [ ] Provisional credit messaging (Reg E for US cards).
- [ ] Contact support (in-app, with context).
- [ ] Submit documents for review (chargeback evidence, KYC re-verify).

### Security
- [ ] 2FA (TOTP, SMS, biometric) — MANDATORY for fintech.
- [ ] Session management (active sessions, revoke).
- [ ] Login alerts on new device.
- [ ] Transaction alerts.
- [ ] Step-up auth on sensitive actions (add beneficiary, change limit, withdraw above threshold).
- [ ] Password requirements + breach-list check (HIBP).
- [ ] Account lockout on brute force.

### Notifications
- [ ] Push + email + SMS preferences per event type.
- [ ] Transaction notifications (per-tx, summary).
- [ ] Statement-ready notifications.
- [ ] Limit-approaching alerts.
- [ ] Failed-transaction alerts.

## Compliance / Operator-facing

### KYC review (manual queue)
- [ ] In-progress applications.
- [ ] Document review interface.
- [ ] Sanctions hits queue.
- [ ] PEP escalations.
- [ ] Approve / reject with reason + audit log.
- [ ] Periodic re-verification queue.

### AML monitoring
- [ ] Alert dashboard with severity + age.
- [ ] Rule configuration (velocity thresholds, country lists).
- [ ] Case management: assign, investigate, resolve.
- [ ] SAR filing workflow with attachment + audit.
- [ ] CTR generation ($10k+ US cash).
- [ ] Pattern visualization (graph of related accounts).
- [ ] Watchlist sync (OFAC, EU, UN, country-specific).

### Account operations
- [ ] User search by email / phone / id.
- [ ] User detail: KYC, accounts, transactions, devices, sessions.
- [ ] Freeze / unfreeze account with reason.
- [ ] Close account with offboarding flow.
- [ ] Place legal hold.
- [ ] Override limit (with approval workflow).
- [ ] Force-logout sessions.

### Transaction operations
- [ ] Transaction lookup by ID / external reference.
- [ ] Initiate refund (within authority limits).
- [ ] Place / release hold.
- [ ] Reverse transaction (with audit + approval).
- [ ] Bulk actions (rare; needs approval gate).

### Reporting / regulatory
- [ ] BSA / AML reports.
- [ ] CTR + SAR exports.
- [ ] 1099 series annual generation.
- [ ] Regulatory exam exports (transaction history, customer info).
- [ ] Tax / fiscal exports per jurisdiction.

### Reconciliation
- [ ] Daily reconciliation: ledger vs bank vs card network.
- [ ] Exception list: unmatched, mismatched, suspended.
- [ ] Suspense account view + clearing workflow.
- [ ] Manual journal entry with multi-eyes approval.
- [ ] Reversal entry with linked original.

### Disputes (operator)
- [ ] Dispute queue with deadlines.
- [ ] Evidence collection interface.
- [ ] Network case file generation.
- [ ] Outcome tracking + impact on customer balance.

## Trust + compliance

- [ ] HTTPS site-wide; TLS 1.2+ minimum, prefer 1.3.
- [ ] Privacy + terms + AML disclosures + fee schedule pages.
- [ ] Cookie banner.
- [ ] PCI-DSS compliance (provider-hosted card fields ONLY; no PANs touch your servers).
- [ ] PCI-DSS scope reduction: tokenization for stored cards.
- [ ] SOC 2 Type II — auditor-required by enterprise customers.
- [ ] ISO 27001 — common for EU customers.
- [ ] Annual penetration test + remediation.
- [ ] Incident response plan + runbook.
- [ ] Data retention + deletion per regulatory floor.
- [ ] GDPR / CCPA data subject rights with carve-outs for AML / financial records.
- [ ] Audit log (immutable) of every privileged action.
- [ ] Encryption at rest (DB, backups) + in transit.
- [ ] Key management (HSM or KMS).
- [ ] Background checks for employees with privileged access.

## Operational

- [ ] Multi-region deployment (or DR site at min).
- [ ] RTO + RPO documented.
- [ ] Backup + tested restore.
- [ ] Status page.
- [ ] Webhook idempotent handlers.
- [ ] Outbox pattern for events.
- [ ] Reconciliation jobs hourly + daily.
- [ ] Anomaly detection on aggregate metrics.
- [ ] Rate limit on all endpoints.
- [ ] API versioning.
- [ ] Customer support tooling.

## Things v1s commonly miss

- Double-entry ledger absent — single `balance` column updated per tx; corruption inevitable; reconciliation impossible.
- Idempotency keys not enforced at DB layer — concurrent retries double-post.
- KYC re-verification absent — passport expires, account stays active, sanctions miss.
- Sanctions screening at onboarding only — daily delta missed; AML violation.
- AML alert closed without rationale — regulator finds zero audit trail; fines.
- Provisional credit on disputes (Reg E) — US debit card customers entitled within 10 business days; v1s skip; lawsuits.
- Hold release on cancel — hold sits forever; available balance wrong.
- Float math — `amount * rate` produces $1234.5600000001; ledger drifts; reconciliation breaks.
- FX rate stale — quote 30 sec old applied; arbitrage opportunity for users; loss.
- Failed transfer not refunded — provider returned funds, customer balance not restored; complaints.
- Statement timestamps in operator TZ vs customer TZ — confusion + tax-period misclassification.
- Transaction descriptions raw provider strings — "ACH-CR-12345-CUST" instead of "Deposit from Bank of America."
- Account closure leaves orphan transactions — close-then-statement breaks.
- Daily limit enforced but per-tx limit absent — single $50k withdrawal sneaks under daily cap of "5 transactions."
- KYC documents stored in S3 unencrypted — first audit fail.
- Webhook handlers not idempotent — provider retries → double-post → multi-million reconciliation crater.
- No reconciliation job — drift undetected for months.
- Backup never restored — DR test reveals 2-hour RTO is actually 24 hours.

## Things often over-built in v1

- Investing / brokerage features (different regulatory regime — start narrow).
- Crypto integrations (compounds compliance burden).
- Lending (different risk + capital requirements).
- Multi-currency unless serving cross-border explicitly.
- "Open Banking" aggregation unless core to use case.
- Mobile native app (responsive web works for v1; mobile follows).
- AI fraud detection (rule-based works; ML later).
- Premium / tiered subscription (after PMF).
- White-label B2B variant (after consumer works).
- Real-time settlement (most rails are batch; mismatched expectation).
