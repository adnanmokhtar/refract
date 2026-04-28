# Real estate — feature checklist

The 80%-of-projects-need-this list. Real estate v1s commonly fail compliance audits or alienate agents within months due to gaps below.

## Consumer-facing (buyers + renters)

### Search
- [ ] Map + list view with synchronized selection.
- [ ] Polygon search (draw your area).
- [ ] Filters: price, beds, baths, sqft, lot, year built, days-on-market, status.
- [ ] Filters NOT including protected-class proxies (Fair Housing).
- [ ] Save search with frequency (instant / daily / weekly).
- [ ] Recent search persistence.
- [ ] School zone overlay (use ATTOM, Maponics, GreatSchools — disclose source + non-warranty).
- [ ] Walk Score / transit / bike score (Walk Score API).
- [ ] Commute-time search (drive time from work address).
- [ ] Property type filter (SFR, condo, townhome, multi, land, commercial).
- [ ] Distinguishing for-sale vs for-rent in URLs.

### Listing detail (LDP)
- [ ] Photo gallery with full-screen + swipe.
- [ ] Floor plan + virtual tour (Matterport iframe).
- [ ] Address (with map).
- [ ] Beds/baths/sqft/lot/year/HOA/property tax.
- [ ] List price + price history.
- [ ] Days on market.
- [ ] Description (sanitized — Fair Housing checked).
- [ ] Listing agent + brokerage (per state disclosure rules).
- [ ] Mortgage calculator with estimate.
- [ ] Schools (with neutral data + disclaimer).
- [ ] Comparable sold (gated for registered users).
- [ ] Schedule tour CTA.
- [ ] Save / favorite.
- [ ] Share (URL + email + SMS).
- [ ] Open house listing.
- [ ] Property history (prior sales, prior listings).

### Account
- [ ] Sign up / sign in / reset.
- [ ] OAuth (Google, Apple, Facebook).
- [ ] Saved listings.
- [ ] Saved searches with notification preferences.
- [ ] Communication preferences (email/SMS/push).
- [ ] Data export (GDPR / CCPA).
- [ ] Account deletion.

### Lead-capture
- [ ] Schedule tour: requires phone + email; TCPA consent capture.
- [ ] Contact agent: same.
- [ ] Mortgage pre-qual widget (RESPA-compliant disclosure).

### Notifications
- [ ] New listings matching saved search.
- [ ] Price drops on saved listings.
- [ ] Status changes (back on market, pending, sold).
- [ ] Tour confirmations + reminders.

## Agent-facing (CRM + transaction)

### CRM
- [ ] Contact list with stage, source, last-activity.
- [ ] Filter + segment.
- [ ] Activity timeline per contact.
- [ ] Notes + custom fields.
- [ ] Task management.
- [ ] Drip campaigns (templated email + SMS sequences).
- [ ] Sphere management (life events: birthday, anniversary).
- [ ] Past-client follow-up automation.
- [ ] Round-robin lead assignment.
- [ ] Lead source attribution.
- [ ] Lead-to-close conversion analytics.

### Listing management
- [ ] Listing creation wizard with required-field guidance.
- [ ] Photo upload + ordering + caption.
- [ ] Photo dedup check (against MLS-allowed sources).
- [ ] Description editor with Fair-Housing live-check.
- [ ] Coming Soon vs Active scheduling.
- [ ] MLS sync status.
- [ ] Showing instructions config (lockbox, hours, notice).
- [ ] Open house scheduling.
- [ ] Listing performance (views, saves, shares, tour requests).

### Showing management
- [ ] Showing calendar (per agent + per listing).
- [ ] Block-out times.
- [ ] Auto-confirmation rules.
- [ ] Lockbox integration (Sentrilock, Supra eKey).
- [ ] Feedback request post-showing.
- [ ] Showing history report for sellers.

### Transaction
- [ ] Transaction folder per deal.
- [ ] State-specific document checklist.
- [ ] E-signature integration (status tracking).
- [ ] Milestone timeline (under-contract, inspection, appraisal, financing, closing).
- [ ] Critical-date reminders (contingency expiration, closing date).
- [ ] Wire-fraud warning banners on every wire-instruction interaction.
- [ ] Broker compliance review queue.

### Commission
- [ ] Split per agent.
- [ ] Cap tracking.
- [ ] Referral fee in/out.
- [ ] Disbursement authorization workflow.
- [ ] 1099 / T4A generation.

### Marketing
- [ ] Listing flyer generator (auto from listing data).
- [ ] Social-media post generator.
- [ ] Just-listed/just-sold postcards.
- [ ] Custom landing page per listing (vanity URL).
- [ ] QR code per listing.

### MLS integration
- [ ] RESO Web API client.
- [ ] IDX (Internet Data Exchange) feed handling — for showing other brokerages' listings.
- [ ] VOW (Virtual Office Website) feed for registered users with seller permission.
- [ ] Photo refresh + delta sync.
- [ ] MLS rule compliance (display, attribution, expiry).
- [ ] Multiple-MLS support if agent operates in multiple markets.

## Brokerage / admin-facing

### Office management
- [ ] Agent roster + license tracking.
- [ ] License expiration alerts (state requires current license to operate).
- [ ] Agent onboarding (paperwork + commission agreement + ICA).
- [ ] Office locations.
- [ ] E&O insurance tracking.
- [ ] MLS membership fees + invoice tracking.

### Compliance
- [ ] Designated broker review queue.
- [ ] Required-document checklist per transaction.
- [ ] Audit trail of all transaction edits.
- [ ] Disclosure version tracking.
- [ ] Anti-money-laundering review for cash transactions (FinCEN GTO areas).
- [ ] Fair Housing audit logs.

### Reporting
- [ ] Production by agent (volume + units + GCI).
- [ ] Source ROI (which lead sources convert).
- [ ] Days-to-close by transaction.
- [ ] Brokerage P&L.
- [ ] Listings inventory.

## Compliance + trust

- [ ] Fair Housing language detection (NLP-flagged terms in listings + search).
- [ ] License-number display per state-specific rules (varies; always include in advertising).
- [ ] Equal Housing Opportunity logo display.
- [ ] Privacy policy + Terms.
- [ ] CCPA / GDPR data subject portal.
- [ ] TCPA opt-in capture per channel (SMS distinct from email).
- [ ] CAN-SPAM compliance (one-click unsubscribe).
- [ ] Listings deactivation when MLS expires (respect MLS rules).

## Things v1s commonly miss

- **Photo dedup against other listings.** Agent uploads photos pulled from another brokerage's listing → MLS sees plagiarism → suspension. Fingerprint photos against MLS image hashes; flag uploads matching another listing.
- **Address geocode validation.** Address entered "1234 Main St" → geocoded to wrong city. Validate against parcel boundaries; warn on county mismatch.
- **License expiry guard.** Agent's license expired; system still lets them list. Block listing creation + offer presentation until renewed.
- **TCPA consent timestamps.** Capture is half the work; producing PROOF in a litigation requires log of timestamp, IP, user-agent, exact form text version.
- **Auto-population of Fair-Housing-flagged language.** AI-generated descriptions producing "great for families" → instant violation. Filter at generation + post-edit.
- **Wire instructions emailed without callback CTA.** Wire-fraud is the #1 real-estate cybercrime. Every wire email must say "call the number on file before wiring".
- **Listing photo display without attribution.** MLS rules require listing-agent attribution near photos in IDX displays.
- **VOW vs IDX data confusion.** VOW = registered + seller-opt-in; IDX = public. Showing sold prices to anonymous visitors = MLS violation in most areas.
- **Seller-name display.** Owner names from public records shown on consumer site → violates many MLS rules + privacy expectations.
- **Stale listings shown as active.** Sync lag from MLS → listing showing as active when sold elsewhere → buyer disappointment + ethics complaint.
- **No commute search.** Buyers care about job commute more than ZIP — high-impact filter.
- **No school-zone polygon (only school listing).** "School X" is fuzzy without zone boundary.
- **Mobile photo capture for listings.** Agent in driveway snapping with phone — needs in-app upload + crop + EXIF strip.
- **Lockbox codes not rotating.** Same code used across showings indefinitely → contractor gets in 6 months later.
- **Compliance review can be skipped.** Broker forgets; transaction closes; state audit finds missing forms; brokerage fined.

## Things often over-built in v1 (defer until validated)

- AI-generated property descriptions at scale (start manual; auto-flag fair-housing risk).
- 3D Matterport tours captured in-house (refer to vendors).
- Predictive AVM in-house (use HouseCanary, ATTOM, Quantarium).
- Multi-MLS aggregation (start with 1-2 markets).
- Foreign-language portal (start English; Spanish if Hispanic markets — Coral Gables, Texas).
- iBuyer instant-offer engine (Opendoor/Offerpad scale; start brokerage workflows).
- Cryptocurrency earnest money (compliance maze; offer fiat).
- Drone scheduling (refer to vendors).
- Comprehensive rental management (separate product; ext or partner).
