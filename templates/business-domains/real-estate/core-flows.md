# Real estate — core flows

P1 = without these, you're not in the business. P2 = required to retain agents/brokerages. P3 = differentiator.

## P1 — must-have for v1

### 1. Listing creation + MLS publication
The supply side. No listings = no marketplace.

```
Agent enters new listing
  → property lookup (existing parcel? owner verified?)
  → if new property: create Property + Address (geocoded + validated)
  → upload photos (min 1; portals require 6+; quality flags on low-res)
  → enter listing details (price, beds/baths, description, features, showing instructions)
  → fair-housing compliance check (no protected-class language)
  → status = coming_soon (pre-MLS) or active (live)
  → MLS upload via RESO Web API or local MLS API
  → MLS validates required fields per IDX/VOW data dictionary
  → MLS assigns mls_number (or accepts proposed)
  → listing distributed to portals (IDX feed) + buyer brokerages
  → reports back: listing live with MLS#, photos indexed
```

Key invariants:
- Listing must have valid MLS membership for the listing agent's brokerage.
- Photo deduplication required — copying photos from another listing without authorization = MLS rules violation.
- Coming-soon timer: MLS rules typically require activation within 7-21 days OR removal.
- Price must be specific number (no "Call for price" on residential MLS).
- Geocoded address must match parcel data; mismatch flagged.

### 2. Search + browse
The discovery layer. Performance + relevance = stickiness.

```
Buyer enters search (city + price range + beds + baths)
  → query catalog (Postgres + PostGIS, or Elasticsearch with geo)
  → apply filters: price, beds, baths, sqft, lot, school district, HOA, year built
  → apply geo filter: bounding box, polygon (drawn area), commute time
  → sort: price asc/desc, newest, price-per-sqft, distance
  → paginate
  → return listings + photos + key fields
  → user clicks → listing detail
  → user saves search → email/push alerts on new matches
```

Key invariants:
- Map view + list view both supported; selection in one selects in other.
- Filters MUST NOT include protected-class proxies: "good schools", "safe neighborhood", "family-oriented" — Fair Housing Act risk. Allowed: school zone names, crime statistics from public sources only.
- Stale-listing display — if listing not refreshed within MLS-required interval, mark or remove.
- Status filter defaults to active; toggle for sold (for comps).

### 3. Lead capture
Conversion funnel core.

```
Visitor browses listings (anonymous)
  → engages: schedules tour / requests info / saves search
  → registration prompt (email + phone)
  → lead created with source attribution (listing-id, search-query, referrer)
  → lead routed: round-robin to floor agents OR to listing agent OR to assigned buyer rep
  → CRM creates contact + opportunity
  → notification to agent (push + SMS + email)
  → agent must respond within SLA (often <5 min for paid leads)
  → first-touch logged; subsequent activity tracked
  → lead progresses: contacted → qualified → opportunity → converted/lost
```

Key invariants:
- Lead is NEVER sold to multiple agents simultaneously (race condition + ethics issue).
- Source attribution preserved across sessions (cookies + UTM persistence; account merge if user later signs in).
- TCPA consent captured before SMS; explicit, prior, written, separable from main TOS.

### 4. Showing / tour scheduling
```
Buyer or buyer's agent requests showing on listing
  → check listing showing instructions (appointment-required? lockbox-code? courtesy-call?)
  → check listing agent's availability rules (hours, blackout, notice)
  → check buyer's agent license + MLS membership
  → propose time slot
  → notify listing agent / seller per instructions (some allow auto-confirm)
  → confirmation sent to all parties
  → showing details (entry instructions, lockbox code if access granted) sent at appropriate time (often morning of)
  → post-showing: feedback request to buyer's agent → routed to listing agent
  → no-show tracked (impacts buyer's agent reputation)
```

Key invariants:
- Lockbox codes time-bounded; auto-rotated.
- Showing log preserved (who, when, accompanied or not, feedback).
- Concurrent-showing prevention OR explicit allowance per listing.

### 5. Offer + negotiation
```
Buyer's agent drafts offer (price + terms + contingencies + financing + closing date)
  → buyer reviews + signs (e-signature: DocuSign, Dotloop, Authentisign)
  → submitted to listing agent
  → listing agent presents to seller (legal duty in most states to present ALL offers)
  → seller: accept / reject / counter
  → counter-offer drafted with changes
  → buyer reviews + accepts/rejects/counters
  → loop until acceptance or termination
  → on acceptance: contract executed; transaction created
  → earnest money instructed (wire to escrow agent, NOT to seller)
  → contingency timers start (inspection 7-14d typical; financing 21-30d)
```

Key invariants:
- Listing agent has fiduciary duty to present every offer (or written waiver from seller).
- Multiple-offer disclosure rules vary by state.
- Wire-fraud risk on earnest money — every email about wire instructions must include verbal verification CTA.
- e-Signature platform must comply with ESIGN + UETA + state-specific (some states require notarization for deeds).

### 6. Transaction milestones to close
```
Under contract → inspection scheduled → report → buyer accepts or requests repairs
  → seller responds → resolution (repairs, credit, or termination)
  → appraisal ordered → completed → meets price (or appraisal gap + renegotiation)
  → loan underwriting → conditional approval → final approval (clear-to-close)
  → title search → title insurance → walk-through (24-48h pre-close)
  → closing scheduled → closing disclosure delivered (3-day rule for federally-related)
  → closing: signatures (e-close where allowed), funds wired, deed recorded, keys exchanged
  → commission disbursed
  → MLS status updated to sold
```

Key invariants:
- TRID (TILA-RESPA Integrated Disclosure) — Loan Estimate within 3 business days of application; Closing Disclosure 3 business days before closing.
- Wire instructions verified in person or by callback to known number — never trust email-only.
- Recording at county within state-mandated time; some states require same-day.
- Commission disbursement only after recorded close + escrow agent's authorization.

## P2 — keep agents

### 7. CRM + drip marketing
- Contact management with stage, sources, last-activity.
- Automated drip campaigns by stage (new lead, sphere, past client, anniversary).
- SMS + email integration; TCPA-compliant opt-in/out.

### 8. Document management
- Transaction folder per deal with checklist of required forms (state-specific: purchase contract, disclosures, addenda).
- Version control on amended forms.
- E-signature integration with status tracking.
- Compliance checks before broker review.

### 9. Commission management
- Split structure per agent (60/40, 70/30, 80/20, escalating tiers).
- Cap programs (KW model: agent caps brokerage take after $X annual).
- Referral fee tracking (inbound + outbound).
- Disbursement authorization at close.
- 1099 generation at year-end.

### 10. Compliance review
- Designated broker reviews each transaction for required documents.
- Risk flags (price anomalies, dual representation disclosure, unfamiliar names).
- Audit trail for state real-estate commission inspections.

### 11. Open houses
- Public scheduling; visitor sign-in (paper or app).
- Visitor capture → leads.
- Marketing distribution (Facebook events, email, MLS open-house feed).

### 12. Saved-search alerts + listing alerts
- New matching listings notify buyer.
- Price-change alerts.
- Status-change alerts (e.g., back-on-market).

## P3 — differentiator

### 13. Comparative Market Analysis (CMA)
- Pull comps from MLS sold + active.
- Adjust for differences (sqft, beds, condition).
- Generate report for seller pre-listing or buyer pre-offer.

### 14. Virtual tours + floor plans
- 3D walkthroughs (Matterport, iGuide).
- Floor plan generation from photos (CubiCasa).
- Drone aerials.

### 15. Predictive analytics
- Listing price suggestion (AVM — Automated Valuation Model).
- Time-on-market prediction.
- Likelihood of offer acceptance at price points.

### 16. Mortgage + insurance lead routing
- Pre-qualification widget at lead capture.
- Refer to lender partners (RESPA-compliant disclosures, no kickbacks).

### 17. Rental management add-on
- Application screening (credit, eviction, criminal — FCRA-compliant).
- Lease execution + storage.
- Rent collection.
- Maintenance ticket workflow.

## Idempotency + race conditions

### Lead routing race
Two agents claim the same lead; old "first to call" race produces duplicates and bitter agent fights.
- Atomic claim: `UPDATE leads SET assigned_to=$1 WHERE id=$2 AND assigned_to IS NULL` returning rows-affected.
- If 0 rows, lead taken; show "claimed by another agent" error.

### Offer collision
Multiple offers on hot listing arriving same minute.
- All accepted into the system; presentation to seller in priority order (timestamp + agent rep).
- Seller chooses one; others marked rejected with reason "multiple offers received".

### Listing status race
Listing agent marks pending; buyer's agent's offer (in flight) needs handling.
- Optimistic concurrency on listing version.
- Pending status takes new offers off-table; system blocks/warns.

## Webhooks the system must produce

- `listing.created`, `listing.priced` (price change), `listing.status_changed`, `listing.sold`.
- `lead.created`, `lead.assigned`, `lead.status_changed`.
- `offer.submitted`, `offer.accepted`, `offer.rejected`.
- `transaction.under_contract`, `transaction.closed`, `transaction.terminated`.

## Webhooks the system must consume

- MLS RESO updates (delta sync).
- Lender milestones (loan estimate, conditional approval, clear-to-close).
- Title company status.
- E-signature platform events (sent, viewed, signed, declined).
- Carrier (showing access provider, lockbox events).

## Idempotency-critical endpoints

- `POST /offers` — duplicate submit = duplicate offer presented to seller.
- `POST /listings/:id/sync-mls` — duplicate publishes can violate MLS rules.
- `POST /transactions/:id/close` — finality; repeat must return same state.
- Lead capture webhook from advertising — same form-fill replayed.
