# On-demand — compliance + legal

The most regulator-attacked product category of the past decade. Worker classification, dynamic pricing, location privacy, insurance gaps, and consumer-protection laws all converge here. None are theoretical — every major platform has paid 9-figure settlements on at least one of these.

## Worker classification

The cliff every platform has fallen off.

| Region | Default test | What pushes you to "employee" |
|---|---|---|
| **US federal (FLSA)** | "Economic reality" 6-factor test (DOL 2024 rule) | Control over hours, exclusivity, worker investment, integral part of business |
| **California (AB5 / Prop 22)** | ABC test for non-app workers; Prop 22 protects rideshare/delivery if specific benefits provided | Failure to provide Prop 22 minimums (120% min wage, healthcare subsidy) flips to employee |
| **NY (NYC TLC)** | Driver minimum pay rule; deactivation appeal rights | Below minimum per-trip pay; deactivation without cause/appeal |
| **UK (Worker status)** | Pimlico Plumbers + Uber v Aslam — "limb (b) workers" entitled to min wage + holiday pay | Control + dependency on platform |
| **EU (Platform Work Directive 2024)** | Presumption of employment if 5 indicators met (control over price, dress code, performance evaluation, work organization, exclusivity) | Activate even one too rigorously |
| **Spain (Riders Law 2021)** | Algorithmic management transparency + employee status for delivery couriers | Refusing to disclose algorithm criteria |
| **Australia (Fair Work Act 2024)** | "Employee-like" worker category for digital platforms | Misclassification penalties up to AUD $93k per breach |

What this means operationally:
- One label globally is impossible. Your platform IS multi-jurisdiction with different worker statuses per region.
- "Independent contractor" agreements are not a defense; behavior controls.
- Provide benefits (insurance, minimum pay floor) WHERE LAW REQUIRES — voluntarily elsewhere is a classification risk too.

## Background checks + driver fitness

- **US (FCRA)**: written consent before background check; adverse-action notice + dispute window before deactivation based on report.
- **EU (GDPR Art. 10)**: criminal-record checks restricted; need legal basis (often impossible without local law authorization).
- **State variations (US)**: Ban-the-Box laws limit when convictions can be considered; CA Fair Chance Act, NY Article 23-A.
- **License + insurance verification**: must be CURRENT, not just verified-once. Build expiry tracking + automated re-verify on expiry day.
- **Re-checks**: annual re-screening typical; some jurisdictions require it (e.g., NYC TLC re-checks).

## Insurance

The fragmented liability that bankrupts platforms.

Three "periods" of activity (industry-standard taxonomy from rideshare):

- **Period 0**: app off — personal insurance only.
- **Period 1**: app on, no request — partial liability coverage required (typically $50k/$100k/$25k).
- **Period 2**: en route to pickup — full commercial coverage.
- **Period 3**: passenger / item in vehicle — full commercial coverage including UM/UIM.

Platform must:
- Provide period 1+2+3 coverage where personal insurance excludes (most do).
- Verify worker has personal insurance during period 0.
- Block trip acceptance during personal insurance lapse.
- Coordinate with state-required coverage (CA AB2293 for rideshare, similar in NY/NV/etc.).

For deliveries: similar but periods around pickup/dropoff. For home services: occurrence-based GL + worker comp where required.

## Dynamic pricing + surge

- **Anti-gouging laws**: most US states cap price increases (10-25%) during declared emergencies. Surge during a hurricane = automatic violation.
- **Surge cap automation**: monitor declared emergencies via state APIs; auto-cap surge in affected geographies. Don't trust manual ops.
- **Disclosure**: surge multiplier must be visible BEFORE confirmation. Consent confirmed via explicit accept (not just "you can see it on the screen").
- **EU Platform Work Directive**: workers entitled to know how prices are set + how it affects their pay.
- **Spain / Italy**: algorithmic transparency requirements include surge logic.
- **Anti-discrimination**: surge based on customer demographics = illegal in US (Fair Housing, ADA), EU (anti-discrimination directives). Pricing must be on legitimate factors (supply/demand by area, time).

## Pay transparency

- **NYC Local Law 144 (2023)**: AI in employment decisions requires bias audit + candidate notice. Driver-deactivation algorithms within scope.
- **CA SB1162 (2023)**: pay scale disclosure on job postings + pay-data reporting.
- **Colorado Equal Pay Act**: pay transparency in postings.
- **EU Pay Transparency Directive (2024)**: by 2026, full pay-gap reporting.

For platforms: drivers must see how earnings calculate (base + per-mile + per-minute + tip + bonus) — opaque earnings reporting triggers worker disputes + lawsuits.

## Tipping

- **US FLSA tip credit**: doesn't apply to truly-independent contractors but DOES apply if worker reclassified as employee. Don't assume safe.
- **No-tip-pooling between workers + platform**: tip belongs to worker; platform taking % is wage theft if workers are employees.
- **Tip prompts**: dark patterns under regulator scrutiny (FTC + state AGs). Pre-checked default tip = enforcement risk.
- **Disclosure**: tip "encouraged" vs "required" must be unambiguous. Auto-gratuity for groups of N+ requires explicit disclosure pre-confirmation.

## Cancellation + no-show fees

- **EU consumer rights**: cancellation fee permissible if proportionate + disclosed.
- **CA + many US states**: reasonable cancellation policy enforceable; punitive policies may be unconscionable.
- **Credit-card chargebacks**: customer disputes cancellation fees; provider often sides with customer if disclosure was buried.
- **Worker side**: cancellation by platform without compensation = wage theft if worker has been dispatched + traveled.

## Location data + privacy

The most-fined privacy violations of the past 5 years.

- **GDPR + CCPA**: location is sensitive personal data; minimize collection, retention, sharing.
- **Post-trip**: precise location must NOT be retained beyond operational need. Aggregate or coarsen to ~1km grid for analytics.
- **Worker location during off-shift**: collecting violates privacy laws; UK Information Commissioner fined Uber for this in 2024.
- **Sale of location data**: "Do Not Sell" must be honored under CCPA/CPRA.
- **Sharing with law enforcement**: warrant required (Carpenter v US). Document process; don't fast-path subpoenas.
- **Geofencing in marketing**: requires consent; FTC has fined platforms for sending location-based ads without consent.

## Safety

- **In-app SOS / emergency button**: required by NYC TLC, CA, NV, CO. Going wider; assume mandatory.
- **Real-time trip sharing**: customer can share trip with contacts. Some jurisdictions require offering this.
- **Background check standards**: state-mandated for rideshare in most US states; minimum 7 years criminal history.
- **Vehicle inspection**: annual safety + emissions where required by state.
- **Driver fatigue limits**: voluntary in most jurisdictions; California considering hours-of-service rules for drivers; EU has Drivers' Hours Regulation for commercial.
- **Accident reporting**: SR-1 in CA + similar in other states; incident must be reported to platform within 24h, platform reports to insurer + DMV.

## Accessibility

- **ADA Title III (US)**: platforms must provide accessible service — wheelchair-accessible vehicles (WAV) on demand within similar time/price as standard, or pay penalties (NYC has fined Uber/Lyft).
- **Visual + hearing impairments**: app must be screen-reader compatible (WCAG 2.2 AA), support VRS for deaf/HoH users.
- **Service animals**: drivers cannot refuse; platform must train + enforce.
- **Equivalent service**: same pickup time, same fare, same vehicle quality regardless of disability.

## Tax

- **US 1099-NEC + 1099-K**: workers earning $600+ get 1099-NEC (effective 2024); platforms file 1099-K for >$5k payment volume (lowering each year, was $20k pre-2024).
- **EU DAC7 (2023+)**: digital platforms report worker earnings to tax authorities annually.
- **VAT on platform commission**: depends on B2B/B2C + supply place; platforms often deemed-supplier under EU rules.
- **Worker tax info collection**: W-9 (US), TIN/VAT (EU), GST (AU/IN); validate at onboarding.
- **State sales tax** (US): some states tax rideshare directly; platform collects + remits.
- **Tip taxation**: workers responsible for declaring; platform reports if processing tips through the app.

## Anti-trust

- **Most-favored nation clauses**: prohibiting workers from charging less elsewhere = antitrust violation (DOJ + EU concern).
- **Algorithmic price-fixing**: workers all setting price via platform's algorithm has been argued as collusion (no successful enforcement yet but watch).
- **Worker organizing**: NLRA allows for traditional employees; gig workers in gray zone but Seattle, NYC have passed sectoral bargaining ordinances.
- **Acquisition scrutiny**: gig-platform M&A faces strict review (FTC blocked deals 2022-2024).

## Common compliance gaps in v1

- Worker classification stated as "contractor" with no jurisdictional analysis → automatic class-action target.
- No SOS button → state mandate violation in CA / NY / NV / CO.
- Background check missing FCRA-required pre-adverse-action notice.
- Surge pricing with no anti-gouging cap → first emergency = AG investigation.
- Post-trip location retained at GPS precision indefinitely → GDPR + CCPA fines.
- Tip pre-checked at 25% → FTC dark-pattern enforcement.
- Driver-deactivation with no appeal process → NYC TLC / CA Prop 22 violation.
- WAV not offered → ADA lawsuit + state penalties.
- Earnings opaque (drivers can't reconcile pay) → wage-theft claims.
- 1099-NEC threshold not tracked per worker → IRS penalties.
- Algorithm decisions on driver matching/pay not auditable → EU Platform Work Directive violation.
- Background check refresh missed → driving with expired license, platform liable.
