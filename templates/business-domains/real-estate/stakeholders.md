# Real estate — stakeholders

Real estate has unusually adversarial-yet-symbiotic relationships. Same transaction has 6+ parties with different interests; all must coordinate on tight timelines.

## Buyer

The price-paying party. Often the highest-emotional-stakes party.

**Workflows:**
- Define needs (location, budget, beds, baths, must-haves).
- Pre-qualify with lender.
- Search listings.
- Schedule tours.
- Make offers.
- Negotiate.
- Inspections + due diligence.
- Close.
- Move in.

**Pain points:**
- Information asymmetry (sellers + agents know more).
- Multiple-offer anxiety in hot markets.
- Wire fraud fear (justifiably).
- Unclear total cost (closing costs, taxes, insurance, HOA, repairs).
- Speed pressure ("decide today or you'll lose it").
- Coordinating financing + inspection + appraisal + closing.

**KPIs:**
- Time from search to closed.
- Offer-to-acceptance rate.
- Inspection issues caught.
- Closing-cost savings vs estimate.

## Seller

The supply-side counterparty. Often fewer transactions per lifetime than other roles.

**Workflows:**
- Decide to sell.
- Pre-list prep (declutter, repairs, staging, photos).
- Set list price (with agent's CMA).
- Sign listing agreement.
- Manage showings (occupied vs vacant tradeoffs).
- Review offers.
- Negotiate.
- Repair negotiations post-inspection.
- Closing.

**Pain points:**
- Setting price (overpriced + underpriced both costly).
- Showing disruption.
- Days-on-market anxiety.
- Repair demands feel like price renegotiation.
- Net proceeds calculation (after commissions, repairs, closing costs).

**KPIs:**
- Days on market.
- Sold price vs list price ratio.
- Net to seller.
- Multiple offers count.

## Buyer's agent

Represents buyer's interests. Compensation traditionally from listing-side; post-NAR settlement, increasingly negotiated directly with buyer.

**Workflows:**
- Lead intake.
- Pre-qual coordination with lender.
- Search + curate listings.
- Schedule tours.
- Educate buyer on market + process.
- Draft + present offers.
- Negotiate counters.
- Coordinate inspection + appraisal + financing.
- Closing attendance.
- Post-close follow-up + referral cultivation.

**Pain points:**
- Showing time (windshield time + idle time at properties).
- Buyer flakiness (3 months of showings, then ghosts).
- Buyer's-rep agreement adoption (post-NAR settlement).
- Compensation uncertainty (no longer guaranteed in MLS).
- Lender slowness threatens close.
- Multiple-offer scenarios eroding bench depth.

**KPIs:**
- Lead-to-buyer conversion.
- Buyers represented per month/year.
- GCI (gross commission income).
- Time-to-close from lead.
- Repeat + referral business.

**Permissions:**
- Search + save listings.
- Schedule showings.
- Draft offers.
- Receive lockbox access codes.
- View sold-comp data (MLS member).
- Read transaction docs for own deals.

## Listing agent

Represents seller. Often the higher-status agent in a brokerage.

**Workflows:**
- Lead intake (FSBO conversion, expired-listing pursuit, sphere referrals).
- Listing presentation + CMA.
- Sign listing agreement (exclusive right-to-sell typically).
- Pre-list prep coordination (photographer, stager, repairs).
- MLS entry + photo upload.
- Marketing (social, signage, open houses).
- Showing facilitation.
- Receive + present offers.
- Negotiate on seller's behalf.
- Coordinate disclosures + repair negotiations.
- Closing.

**Pain points:**
- Convincing seller on realistic price.
- Photo + listing quality (cheap photos cost listings).
- Showing volume control.
- Multiple-offer chaos.
- Deal-falling-apart-mid-escrow.
- Commission disputes.

**KPIs:**
- Listings taken per month.
- Sold rate of listings.
- Days-on-market average.
- Sold-vs-list-price ratio.
- GCI.

**Permissions:**
- Listing CRUD.
- MLS submission + edit.
- Showing schedule access.
- Offer queue.
- Transaction document creation.

## Designated broker

The licensed broker who supervises agents. Legally responsible for agents' actions.

**Workflows:**
- Onboard new agents (paperwork, training).
- Review every transaction's compliance file.
- Resolve agent disputes.
- Handle complaints (consumer + state).
- Trust account oversight (escrow + commissions).
- Recruit + retain agents.
- Brokerage P&L management.

**Pain points:**
- Compliance review bottleneck.
- Agent training quality.
- Trust account reconciliation pain.
- E&O claims.
- State commission audits.

**KPIs:**
- Brokerage volume + units.
- Compliance audit findings.
- Agent retention.
- Profit per transaction.

**Permissions:**
- All transactions in brokerage.
- Agent file edit.
- Compliance review approval.
- Disbursement authorization.

## Lender / mortgage broker

Provides financing; without lender ready, deal dies.

**Workflows:**
- Pre-qualification (soft check).
- Pre-approval (full underwrite, conditional).
- Loan application post-acceptance.
- Underwriting.
- Appraisal order.
- Title insurance order.
- Closing docs preparation.
- Closing.
- Post-close servicing handoff.

**Pain points:**
- Document collection from borrower (2 years tax, paystubs, bank statements).
- Underwriting condition surprises (employment verification, last-minute credit pulls).
- Appraisal gaps.
- Rate-lock expiry threats.

**Touchpoints with the system:**
- API for pre-qual widget on listing pages.
- Loan-estimate + closing-disclosure delivery.
- Milestone updates back to agent.

## Title company / escrow agent

Holds funds; produces title insurance; coordinates closing.

**Workflows:**
- Title search (look for liens, encumbrances).
- Title commitment to lender.
- Open escrow + receive earnest money.
- Coordinate closing schedule.
- Prepare closing docs.
- Disburse funds.
- Record deed at county.
- Issue title policy.

**Pain points:**
- Wire-fraud target (account-takeover phishing).
- County recording variability.
- Last-minute closing changes.

**Touchpoints:**
- Wire instructions secure delivery.
- Closing disclosure transmittal.
- Recording status updates.

## Inspector

Independent contractor; buyer's agent typically refers.

**Workflows:**
- Schedule.
- 2-3 hour inspection.
- Photo-rich written report (digital delivery).
- Re-inspection after repairs.

**Touchpoints:**
- Report delivery to buyer + buyer's agent.
- Repair-request generation.

## Appraiser

Lender-ordered; independent valuation.

**Workflows:**
- Receive order from lender (post-AMC reform: via Appraisal Management Company, not direct).
- Site visit.
- Comparable sales research.
- Report delivery to lender (with copy to borrower per RESPA).

**Pain:**
- Appraisal-gap drama (value < contract price).
- Reconsideration requests.
- Bias-in-appraisal scrutiny (HUD/PAVE Task Force 2022+).

## Photographer / stager / contractor

Ecosystem providers. Listing agent's network.

**Touchpoints:**
- Booking + scheduling.
- Photo delivery (high-res + web-optimized).
- Invoice + payment.

## MLS organization

Private membership organization; sets rules; provides data.

**Touchpoints:**
- Membership management (per agent).
- Rule enforcement (citations + fines).
- Data feed (RESO Web API).
- Policy updates (post-NAR settlement, ongoing).

## Local jurisdiction (county recorder, assessor, building dept)

Public records; transfer recording; permits.

**Touchpoints:**
- Property records lookup (APN, owner, taxes, permits).
- Deed recording at close.
- Tax assessment data for valuation.

## State real estate commission

Regulator; license granter + suspender.

**Touchpoints:**
- License lookup (verify before deal).
- Complaint process.
- CE tracking (some platforms integrate).

## Consumers' attorneys (in attorney states)

In some states (NY, NJ, MA, etc.) attorneys handle closing instead of title.

**Touchpoints:**
- Document review.
- Title clearance.
- Closing execution.

## Property management (post-close, for investors)

If buyer is investor, property manager takes over.

**Touchpoints:**
- Lease execution.
- Tenant screening.
- Rent collection.
- Maintenance ticketing.

## Moving + service companies (post-close)

Utility transfer, mail forwarding, movers, cleaners, security.

**Touchpoints:**
- Concierge service offerings.
- Lead handoff to partners.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Buyers can't find listings | Search relevance + map UX + filter set |
| Sellers feeling blind | Listing performance dashboard for seller |
| Agents drowning in paperwork | Transaction document automation + e-sign |
| Brokers failing compliance | Required-doc checklist + auto-flag missing |
| Lenders missing milestones | Lender API + status webhook |
| Title companies wire-fraud-anxious | Out-of-band verification UI |
| MLS issuing fines | Real-time MLS rule check on listing entry |

## Anti-pattern: "agent vs consumer feature war"

Real estate platforms fall into either "agent tool that consumers tolerate" or "consumer destination that agents resent". The asymmetry is structural — agents pay (subscriptions + leads); consumers don't. Most successful: own the consumer relationship + license back to agents (Zillow), OR be the agent's tool + private-label consumer experience (Compass, eXp brokerage tools). Mixed models confuse both.
