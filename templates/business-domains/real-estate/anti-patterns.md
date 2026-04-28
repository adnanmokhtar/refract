# Real estate — domain-specific anti-patterns

Generic SaaS code review misses these. They're industry-specific traps that result in license suspension, MLS expulsion, Fair Housing lawsuits, or wire-fraud losses.

## Fair Housing traps

- **NLP-generated descriptions including "perfect for families".** AI-assisted listing copy → familial-status violation. Filter generation prompts AND post-generation scan; manual override requires acknowledged disclaimer.
- **Search filter "luxury area".** Reads as racial proxy in case law. Audit filter set with FH lens before launch.
- **Recommended-listings algorithm using user demographics.** Ad-targeting model trained on race/ethnicity proxies → steering. Build with neutral-features-only training set + adversarial debiasing.
- **Walking-distance-to-X language ("close to synagogues").** Religion proxy. Use neutral "1.2 mi to nearest place of worship" or remove.
- **School ratings as primary filter.** "8+ schools only" → racially correlated. Show school zone NAME (informational); no rating-based filter; disclaimer with data source.
- **Landlord screening criteria like "no Section 8".** Source-of-income discrimination in many cities (NYC, CA, NJ statewide; many cities). Block this filter or warn at config.
- **Image cropping "removing the family photo on the wall".** Trivial example of cleaning out occupancy signals — but be cautious about systematic removal of disability indicators (ramps, grab bars).
- **Steering via "neighborhood character" descriptions.** "Quiet, established neighborhood" → coded language. Keep listing descriptions to physical attributes.

## Wire fraud

- **Wire instructions in plain email.** Phishing impersonators substitute their account; closing funds gone. NEVER deliver wire instructions via email alone; in-app secure messaging or verified-call only.
- **No callback verification UI/script.** Buyer wires from email; loses $400k. Mandatory checklist: "Did you call the title company at the number on file?".
- **Stale wire-info banner.** Never tell buyers "use the same wires as last time" — banner each transaction with verification CTA.
- **Mortgage payoff amount via email to seller.** Same impersonation vector. Secure portal delivery only.
- **Email domain look-alike (titlecompany-co.com vs titlecompany.com).** Implement DMARC reject + SPF + DKIM; warn users about look-alike sender addresses.
- **No fraud insurance education in onboarding.** Customer wired $300k in clear; no recovery; brand damage. Educate at signup + at each wire prompt.

## MLS rule violations

- **Listing in marketing collateral before MLS.** Off-MLS marketing window violates "Clear Cooperation Policy" (NAR rule, MLS-enforced) — must be in MLS within 1 business day.
- **Photos copied from another agent's listing.** Plagiarism citation; fine up to $5k; suspension. Hash-fingerprint photos against MLS image database; block uploads matching another listing.
- **Status not updated within MLS deadline.** Pending status for sold property; days-on-market clock manipulated; misleading. Auto-flag stale-status listings.
- **IDX-displayed sold prices to anonymous visitors.** Most MLSs require registration (VOW) for sold data. Distinguish IDX (public, active+pending) from VOW (registered, with sold).
- **Auto-pulled data displayed without attribution.** MLS rules require attribution near photos + at listing footer. Static template missing the fields.
- **Stale listings shown post-expiry.** MLS rules + buyer disappointment. Real-time sync + auto-suppress on status change.
- **Co-broke compensation in MLS post-NAR settlement (Aug 2024).** Removed from MLS feeds; lingering in your data → rules violation. Audit + remove field.
- **Owner names from public records on consumer site.** Many MLSs prohibit even though data is public. Strip from consumer LDP.

## License + credentials

- **Agent license expired; system allows listing.** Unlicensed practice; transaction void; commissioner action. Daily license validation against state DRE/REC; block actions on expire.
- **DEA expired prescribers... wait, that's healthcare.** For RE: E&O insurance expired; broker still operating; audit failure. Track + block.
- **Out-of-state agent listing in-state property.** Reciprocity rules per-state. Validate license-state vs property-state.
- **Designated broker not assigned.** Solo agent listing without supervising broker. Block at brokerage onboarding.

## Listing data integrity

- **Address geocoded to wrong city.** "1234 Oak St, Springfield" matches 12 places. Validate with parcel boundaries; warn on county mismatch.
- **APN missing or wrong.** Cross-references to public records broken; wrong tax data shown. Validate APN format per county.
- **Square footage from agent vs assessor mismatch.** Agent inflates; assessor stale. Show both with source attribution.
- **Photos not in chronological order with renovation.** Old kitchen photo on renovated property → buyer expectation gap.
- **Coming-Soon listing kept indefinitely.** MLS rules require activation within window. Auto-transition.
- **Listing description in HTML rich text with auto-linking.** Phone numbers becoming click-to-call to attacker numbers. Strip + sanitize.
- **EXIF data on photos preserved.** GPS coordinates of photographer's home accidentally embedded. Strip EXIF on upload.

## Lead handling

- **Lead "sold" to multiple agents simultaneously.** Race condition; agents fight; duplicate consumer outreach. Atomic claim; if claimed, show "claimed by another agent".
- **TCPA consent not captured.** SMS sent without proof of consent; class-action fodder. Capture: timestamp, IP, UA, exact form text version.
- **TCPA consent broad ("agree to receive communications").** Must be: (a) prior written, (b) for SMS specifically, (c) describing the technology (autodial), (d) without conditioning service on consent.
- **Lead source attribution lost on second visit.** First-touch source overwritten; ROI fiction. Persist UTM + referrer; merge on auth.
- **Lead reassignment without notification.** Buyer talks to agent A; agent B calls them next week; confusion. Notify buyer of agent change.
- **Cold-calling DNC list ignored.** Federal + state DNC lists; $40k+ fines. Cross-check before calling.
- **Robocalling without prior consent.** Strict TCPA; auto-dialer prohibited without consent.

## Offer + transaction

- **Listing agent withholds offers from seller.** Fiduciary duty to present all offers (or written waiver). System should make all offers visible to seller (in agent's portal at minimum).
- **Multiple offers without proper disclosure.** State rules vary; auditor-level disclosure of multiple offers must be tracked.
- **Counter-offer reset of contingencies inadvertent.** Counter-offer creates new contract; old timers may reset. Show effective dates clearly.
- **Earnest money instruction to seller's account.** Earnest goes to escrow; not seller. Code path enforces escrow account only.
- **E-signature without authentication.** Consumer-grade DocuSign sufficient most cases; deeds in some states need notarization (Remote Online Notarization in 48 states + DC).
- **Closing disclosure delivered late.** Federal 3-day rule violation. Auto-track delivery timestamp; alert if breaching.
- **Repair credit applied to wrong line.** Net-to-seller miscalculated. Closing-disclosure validation.
- **Commission split miscalculated.** Wrong cap, wrong tier, wrong referral fee. Disbursement validation step.

## Showings + access

- **Lockbox code static.** Same code months; ex-contractor reuses. Rotate per showing or per period.
- **Showing log not preserved.** Theft incident; can't reconstruct who was in the property when.
- **Concurrent showings without listing-agent approval.** Two buyers at same time; awkward for sellers. Block by default; allow per listing config.
- **Tenant-occupied property showing without 24h notice.** State law violation. Notice tracking + delay enforcement.

## Privacy + ethics

- **Owner contact info from public records used for cold-call campaigns.** Anti-solicitation rules in many states. Don't aggregate + outreach.
- **Off-market property speculative listings.** "We have a buyer for your house" without genuine buyer; deceptive. Don't generate.
- **Showing data shared with other prospects.** Buyer A's interest signals leaked to buyer B. Tenant boundaries on lead data.
- **Lead data sold to lenders without disclosure.** RESPA Section 8 + privacy disclosure. Consent-gated + explicit.

## Search + discovery

- **Map only shows X listings due to viewport limit.** "Why is my listing not on the map?" Display limits clearly OR cluster.
- **Polygon search excludes school district edge cases.** Boundary properties lose visibility. Use precise polygon data.
- **Saved-search alerts spamming.** New listing in search → instant email; user gets 50/day. Frequency cap + bundling.
- **Photo-first sort hides text-only listings.** Some legitimate listings don't have photos (estate, off-market, foreclosure). Don't filter, deprioritize.
- **Sold listings showing as recommendations.** "You might like" pulls sold properties; user clicks; disappointment.

## Commission + financial

- **Commission split paid to wrong agent on team transfers.** Agent moved teams mid-deal; split not updated. Lock split at contract date.
- **Referral fee not 1099'd.** IRS issue at year-end. Auto-flag + track.
- **Trust account commingling.** Brokerage operating funds + escrow funds in one account = state violation, license suspension. Hard separation.
- **Disbursement before close confirmed.** Commission paid; deal falls apart; can't claw back. Disbursement only after recorded close + escrow authorization.

## Operational

- **Photo storage costs exploding.** 50 photos × 10MB × 100k listings → archive policy missing. Cold-storage tier for sold/expired.
- **MLS feed sync gaps during outages.** Agents see stale data; bad decisions. Status indicators on UI.
- **DST (daylight saving) breaking showing schedules.** Times stored in local time without TZ; spring/fall confusion. Always store UTC + display tz.
- **Listing migration to new MLS losing data.** Agent moves brokerage; listing must be re-entered; history lost. Allow data export + parallel-MLS-membership scenarios.
- **Vendor referral kickbacks.** Lender, inspector, title kickbacks → RESPA Section 8 violation. Document arrangements as bona-fide marketing services with FMV; CFPB-audit-ready.

## Branding + display

- **Brokerage name hidden on agent's vanity site.** State rule: brokerage must be displayed prominently. Footer + header presence.
- **Equal Housing Opportunity logo missing on consumer pages.** Required disclosure + symbol.
- **Photo watermarks of competing brokerage on syndicated content.** MLS attribution rules.
- **Team name larger than brokerage name.** Many states prohibit; team name must include brokerage.

## International / cross-border

- **FIRPTA withholding missed on foreign seller.** Title agent failure; IRS comes after them. System flag if seller country ≠ US.
- **Foreign-buyer KYC.** AML obligations for cash transactions in GTO areas; beneficial-ownership reporting (CTA 2024).
