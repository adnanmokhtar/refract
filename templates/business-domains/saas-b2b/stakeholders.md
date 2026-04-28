# SaaS B2B — stakeholders

B2B SaaS has layered buying (user ≠ champion ≠ economic buyer ≠ IT ≠ security ≠ procurement). Each has veto power in enterprise. Build for all.

## End user (the daily user)

Uses the product to do their job. Often the earliest adopter in PLG motion.

**Workflows:**
- Sign up or be invited.
- Learn the product.
- Use daily (ideally).
- Advocate internally if product delivers.
- Churn when product is too confusing or misaligned.

**Pain points:**
- Steep learning curve.
- Poor mobile UX (users are mobile-first now).
- Slow load times.
- Missing integrations with their stack.
- Forced context switches (email → app → email).
- Unclear what they can/can't do (permission confusion).

**KPIs:**
- Time-to-first-value.
- DAU / WAU / MAU.
- Feature adoption depth.
- NPS.
- Task completion time.

**Permissions:**
- Depends on role; baseline member.
- Self-service profile + preferences.
- Invite teammates (often restricted by plan).

## Champion / team lead (the advocate)

Early evangelist inside the customer organization. Convinces others to adopt.

**Workflows:**
- Pilot with small team.
- Measure value.
- Evangelize to adjacent teams.
- Budget advocate with their manager.
- Introduce to procurement.
- Custom reports or dashboards to prove ROI.

**Pain points:**
- Need ROI data to justify expansion.
- Want enterprise features without enterprise price (yet).
- Frustrated when approvals slow their momentum.
- Need champion-friendly admin: share settings + reports with peers.

**KPIs:**
- Team adoption rate.
- Usage/volume growth.
- Team NPS.
- Customer reference value.

**Permissions:**
- Admin on their workspace (or team).
- Manage invitations.
- Create content + configure.

## Economic buyer (the budget holder)

VP or director; signs the contract.

**Workflows:**
- Evaluates ROI case.
- Negotiates pricing.
- Approves budget.
- Reviews quarterly (usage, value).
- Renews or churns at end of term.

**Pain points:**
- Budget pressure + alternative options.
- Unclear ROI.
- Shelfware (unused seats).
- Surprise overages.
- Auto-renewal friction.

**KPIs:**
- Spend vs value (ROI).
- Contract term.
- Expansion opportunity.

**What they need:**
- Executive dashboards.
- Usage reports.
- Cost visibility.
- Vendor stability signals.

## IT / admin (the configurator)

Deploys, manages, supports the product inside the customer organization.

**Workflows:**
- Procure + provision.
- Configure SSO + SCIM.
- Set policy (who can do what).
- Onboard new users.
- Offboard departing users.
- Troubleshoot user issues (password reset, access).
- Manage integrations.
- Audit log review.
- Incident response (if breach).

**Pain points:**
- Bad admin UX (hard to find settings).
- Missing enterprise controls (SSO, SCIM, IP allowlist).
- Audit log gaps.
- Support ticket volume for user issues.
- Integrations that break.
- Password-reset flood.

**KPIs:**
- Ticket volume per 100 users.
- Time to provision user.
- Time to deprovision (security metric).
- Integration uptime.

**Permissions:**
- Workspace admin.
- SSO + security config.
- Audit log read.
- User management.

## Security / CISO / risk

The gatekeeper. Reviews before purchase; can kill deal.

**Workflows:**
- Security questionnaire completion.
- Penetration test review.
- SOC 2 / ISO review.
- Sub-processor review.
- DPA negotiation.
- Ongoing vendor risk management.
- Incident response if vendor breached.

**Pain points:**
- Incomplete questionnaires (50-300 questions).
- No SOC 2 (deal blocker in enterprise).
- Missing audit events.
- Unclear data residency.
- Sub-processor changes without notice.

**KPIs:**
- Vendor risk score.
- Time to complete review.
- Incidents attributed to vendor.

**What they need:**
- Trust center (SOC 2, ISO, DPA, sub-processors, security whitepaper).
- Audit log export to SIEM.
- Breach notification commitment + SLA.
- Insurance certificates.

## Procurement

The process layer. Often adversarial; negotiates on behalf of buyer.

**Workflows:**
- RFP issuance.
- Vendor comparison.
- Contract negotiation.
- Pricing pushback.
- Legal review coordination.
- PO issuance.
- Invoice-to-payment.
- Renewal negotiation.

**Pain points:**
- Contracts with unfavorable terms (auto-renewal, caps).
- Complex pricing (seats + usage + add-ons).
- Mid-term changes not in contract.
- PO / invoice mismatch.
- Budget processes vs urgency.

**What they need:**
- Flexible contracting.
- Annual billing + net-30 payment (vs card only).
- Line-item invoices.
- Standard MSA available.
- Enterprise procurement workflow (not self-serve credit card).

## Legal

Reviews contracts.

**Workflows:**
- MSA review.
- DPA review.
- BAA (if healthcare).
- Order form review.
- Amendments negotiation.

**Pain points:**
- Non-negotiable ToS (want MSA for enterprise).
- Liability caps too low.
- Indemnity too narrow.
- Data terms unclear.
- Governing law / jurisdiction.

**What they need:**
- Standard MSA template + negotiation flexibility.
- DPA template (GDPR/CCPA).
- BAA if applicable.
- Clear liability + indemnity.
- Audit rights.

## Finance / accounting (customer side)

Pays the bills + reconciles.

**Workflows:**
- Invoice receipt + validation.
- Payment processing.
- Accrual accounting.
- Budget vs actual tracking.
- Cancellation accounting.

**Pain:**
- Invoices don't match contract.
- Missing PO on invoices.
- Mid-cycle charges (overages).
- No historical invoice access.
- Currency issues for international buyers.

## SaaS company — sales

Internal; closes deals.

**Workflows:**
- Prospect outreach + qualify.
- Discovery call.
- Demo.
- Trial setup.
- Negotiate contract.
- Close.
- Handoff to CS.

**KPIs:**
- Pipeline, win rate, ACV, sales cycle.

**What they need from product:**
- Demo workspace.
- Trial provisioning.
- POC / POV framework.
- Sales enablement (ROI calculator, case studies).

## SaaS company — customer success (CS)

Internal; retains + expands.

**Workflows:**
- Onboarding (kickoff, training, adoption plan).
- QBR (quarterly business review).
- Usage monitoring + intervention.
- Advocate for customer internally.
- Renewal + expansion.

**Pain points:**
- Low-touch account books too large.
- Usage data inadequate.
- Low engagement → churn surprise.
- Feature request handling.

**What they need:**
- Customer health score.
- Usage dashboards per customer.
- Intervention workflows (at-risk alerts).
- Expansion signals.

## SaaS company — support

Internal; resolves issues.

**Workflows:**
- Ticket response.
- Impersonate customer (read-only or with consent).
- Reproduce bugs.
- Escalate to engineering.
- Document for KB.

**What they need:**
- Impersonation tool (audited).
- Customer context on tickets (plan, usage, member role).
- Status page for known issues.
- Internal KB.

## SaaS company — product + engineering

Internal; builds.

**Pain:**
- Roadmap vs enterprise ad-hoc asks.
- Tenant isolation complexity.
- Scaling multi-tenant databases.
- Feature-flag sprawl.

## SaaS company — finance

Internal; recognizes revenue + manages.

**Workflows:**
- Revenue recognition (ASC 606, IFRS 15).
- Deferred vs recognized revenue.
- Churn + retention metrics.
- Billing reconciliation.
- Tax compliance (multi-state, international).

**Pain:**
- Complex billing (seats + usage + discounts + credits).
- Revenue leakage (underbilled).
- Tax jurisdiction complexity.
- Currency revaluation.

## Auditor (external)

Reviews SOC 2 / ISO.

**Workflows:**
- Evidence collection.
- Sample testing.
- Walkthroughs.
- Remediation tracking.
- Report issuance.

## Partner ecosystem

### Integration partners
- Native integrations (Zapier, Make, custom).
- API consumers.
- OAuth app ecosystem.

### Referral partners
- Resellers (volume discount, deal registration).
- Affiliate programs.

## Data subject (end user of customer)

If your SaaS processes data about customer's end-users (e.g., CRM with leads):
- DSAR (data subject access requests) routed via customer.
- You provide customer-controller tooling.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| End users | UX polish + mobile + in-app learning |
| IT admins | SSO, SCIM, audit log, admin UI |
| Security reviewers | SOC 2, trust center, compliance answers |
| Procurement | Annual billing, net-30, MSA, PO support |
| Finance (customer) | Clear invoices, historical access, export |
| CS (internal) | Customer health score, usage analytics |
| Sales (internal) | Trial + demo provisioning, POV tools |
| Finance (internal) | Rev rec, billing reconciliation, multi-currency |

## Anti-pattern: "self-serve everywhere vs sales-led contradiction"

Many B2B SaaS try both motions poorly. PLG patterns (instant signup, no gates) conflict with enterprise patterns (procurement, security review, manual provisioning). Decide: does the customer swipe a card or negotiate a contract? Different product surfaces: self-serve billing + plan UI vs enterprise contract + order form. Trying to do both half-way leads to a messy middle.
