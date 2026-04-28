# Real estate — compliance + legal

Real estate is regulated by federal + state + MLS contractual layers. Penalties for Fair Housing alone are 7-figure + reputational. License loss = no business.

## Federal — Fair Housing Act (42 U.S.C. § 3601, 1968)

The defining federal statute. Recent enforcement aggressive.

### Protected classes
Race, color, religion, national origin, sex (including sexual orientation + gender identity per Bostock + 2021 HUD guidance), familial status (presence of children), disability.

State + local often add: age, marital status, source of income (Section 8), military status, ancestry.

### What's prohibited
- Refusing to sell/rent.
- Different terms/conditions.
- Discriminatory advertising.
- Steering (directing toward/away from areas based on protected class).
- Blockbusting (inducing sale via class-based fear).
- Disability accommodations refused.
- Algorithmic discrimination (HUD's 2023 guidance + Algorithmic Accountability — applies to AI matching, search ranking, ad targeting).

### Discriminatory language in listings
- "Walking distance to church" (religion proxy).
- "Family-friendly", "perfect for kids" (familial status).
- "Empty nesters", "active adult community" (familial/age).
- "Master bedroom" → use "primary" (cultural shift; not statutory but expected).
- "Exclusive neighborhood", "safe area", "good schools" — racial proxies in case law.
- "English-speaking" (national origin).

Build NLP filter scanning descriptions before publish.

### Steering via search filters
- Don't expose filters that proxy protected classes.
- "Schools rated 8+" — racially correlated; use neutral data with disclaimer.
- Avoid "demographics" filters in any consumer-facing search (often pulled from data partners; remove).
- Don't recommend listings based on user's name, language preference, or zip-code-derived demographic.

### Penalties
- HUD: up to $25,597 per violation (1st), $63,990 (2nd), $127,981 (3rd, 7-year window) — 2024 figures.
- DOJ: civil suits + enforcement.
- Private right of action — actual + punitive damages + attorney's fees.

## Equal Credit Opportunity Act + ECOA / Reg B

- Discrimination in mortgage credit prohibited.
- Affects lender partnerships, pre-qual integrations.
- Adverse action notices required.

## RESPA (Real Estate Settlement Procedures Act, 12 USC 2601)

- **Section 8** — kickbacks for referrals prohibited (between settlement service providers: lenders, title, inspectors, agents).
- Affiliated business arrangements require written disclosure.
- Marketing service agreements (MSAs) heavily scrutinized; CFPB enforcement.
- Co-marketing arrangements need to reflect actual fair-market-value services.

## TILA-RESPA Integrated Disclosure (TRID)

For federally-related mortgage transactions:
- **Loan Estimate** within 3 business days of application.
- **Closing Disclosure** delivered ≥3 business days before consummation.
- Tolerance categories on fee changes; recalculation if exceeded.
- Cure provisions if disclosed wrong.

## Anti-Money Laundering (FinCEN)

- **Geographic Targeting Order (GTO)** — currently covers ≥12 metropolitan areas (Manhattan, Miami, LA, SF, etc.) — title companies must report all-cash residential purchases ≥$300k by legal entities.
- **Beneficial ownership disclosure** (CTA / Corporate Transparency Act 2024).
- 2024 final rule expanding to non-financed transfers in residential real estate by some entities.
- Title agents are reporters; brokers must support data collection.

## Consumer Financial Protection Bureau (CFPB)

- Consumer complaint database scanning real estate agents.
- Lender partnership rules.
- "Mini-Miranda" disclosures on debt collection (rare in resale; common in property management).

## State licensing (real estate commissions)

Each state has a real estate commission with its own rules. Key dimensions vary:

### License requirements
- Pre-license education hours (60-150).
- Continuing education annually (some states).
- Sponsoring broker required.
- Background check.
- Errors & Omissions insurance (required in most).

### Agency relationships
- **Designated agency** (state-dependent): one broker, one agent reps buyer, another agent reps seller.
- **Dual agency** disclosed in writing — illegal in some states (FL real estate practitioners can't be dual agents in residential).
- **Transaction broker** (FL default, CO option) — neutral, non-fiduciary.
- **Customer vs Client** distinction — customer = no fiduciary; client = fiduciary.

### Disclosure obligations
- **Material defects** — disclose known defects to buyer.
- **Stigmatized property** — meth lab, deaths, hauntings — varies by state on disclosure requirement.
- **Lead paint** — federal disclosure for pre-1978 properties.
- **Property condition disclosure form** (state-specific seller-completed form).
- **Megan's Law** notification (state-specific).
- **Natural hazard zones** (CA NHD, FL flood, etc.).

### Advertising
- License # in all advertising (state-varies which formats).
- Brokerage name displayed.
- "Equal Housing Opportunity" required.
- Team names regulated (must clearly identify under brokerage).
- Personal logos vs brokerage logos prominence rules.

## MLS rules (contractual, per MLS)

Each MLS = a private organization with binding rules on members.

### Common MLS requirements
- Listing must enter MLS within 1 business day of marketing (no off-MLS for >1d unless specific exemption).
- Photos of listing only — no plagiarism from other listings.
- Status updates required within 1-2 business days.
- Co-broke compensation offered to buyer brokers (post-NAR settlement August 2024: rules changing — listings DON'T offer compensation in MLS; negotiated outside).
- Display of MLS information governed by IDX/VOW agreement.
- Citations + fines for violations ($100-$5000 typical per).

### NAR Settlement (August 2024) impact
- Buyer's representation written agreement required before showing.
- Broker compensation NO LONGER advertised in MLS.
- Buyer compensation negotiated separately; many models emerging.
- Compliance dates: August 17, 2024.

### IDX/VOW
- IDX = display of other brokers' listings on your site (public).
- VOW = display with sold data + more detail to registered users (with seller opt-in).
- Both have rules on what fields display, attribution, refresh frequency, removal of sold/withdrawn.
- DMCA takedown if non-member uses MLS data.

## Privacy

### CCPA / CPRA (California)
- Brokers/agents capturing California consumer data subject.
- Right to know, delete, opt-out of sale.
- Sensitive personal info category (precise geolocation, ethnicity, health).

### GDPR
- If marketing to EU, consent + DPA.
- Transfer mechanism (SCCs) for US receipt of EU data.

### State-specific privacy
- Texas, Virginia, Colorado, Connecticut, Utah enacted comprehensive laws 2023-2024.
- Real estate often "non-exempt" data.

### TCPA (Telephone Consumer Protection Act)
- SMS to mobile requires prior express written consent.
- Robocall + autodial restrictions.
- Do Not Call list compliance for cold calls.
- Quiet hours (8am-9pm local).
- $500-$1500 per violation.

### CAN-SPAM
- Opt-out within 10 days.
- Sender identification.
- Subject line not misleading.

## Real estate-specific privacy

- **Owner name privacy** — public-record names; some MLSs don't display on consumer-facing.
- **Showing visitor data** — visitor sign-ins → leads. Disclosure that data is collected + shared with seller/agent.
- **Smart-lockbox data** — entry events; tied to agent identity.

## Cybersecurity + wire fraud

- **Wire fraud is THE crime** in real estate — phishing on closing emails redirecting funds.
- $300M+/year FBI estimates.
- DMARC/DKIM/SPF on email domains mandatory for serious operations.
- Out-of-band wire verification scripts at every step.
- Cyber liability insurance pricing reflects industry risk.

## Disability accommodations

- **ADA Title III** — websites serving public must be accessible (case law applies).
- WCAG 2.2 AA target.
- Reasonable accommodation in property showings.

## Property type specific

### Rentals
- **Fair Credit Reporting Act (FCRA)** — tenant screening reports.
- Adverse action notice required if denied based on screening.
- **Local rent control** — varies wildly (NYC, SF, LA, Berkeley, NJ).
- **Source of income** protected class in many cities (Section 8 vouchers).
- **Security deposit limits + return timing** — state law; failure to return triggers penalties (up to 3x in some).

### Commercial
- Less consumer protection; more contract-driven.
- ADA accessibility critical for tenant build-outs.

### New construction
- Builder warranty laws (state-specific).
- Coastal disclosure (FL, NC, SC).
- HOA disclosure documents (CC&Rs).

### Foreign nationals
- **FIRPTA** — withholding 15% on sale by foreign person; title agent withholds.
- **Treaty-based exemptions** filed with IRS Form 8288-B.

## Recordkeeping

- Transaction file: 3-7 years (state-varies).
- Trust accounts (escrow): rigorous segregation + monthly reconciliation; commission audit common.
- Email + SMS records: 3 years typical for marketing audit.
- License renewal + CE: state-managed; agents responsible.

## Common compliance gaps in v1

- Description editor allows "great for families" without flag.
- Search filter "luxury communities" reads as racial proxy.
- AI-generated listing copy producing protected-class language.
- Login required to see crime stats but not gun ownership; app appears to steer.
- TCPA consent UI buried; no version + timestamp captured.
- Lead source attribution lost after first session; ad spend ROI fiction.
- Wire instructions sent in transaction email without warning banner.
- IDX display of sold prices to anonymous users (MLS rules require registration).
- Stale listings flagged sold by manual workflow; no auto-suppress.
- E&O insurance expiry not blocking listing/closing actions.
- Agent license expiry not blocking actions.
- CFPB-flagged lender kickback workflow disguised as "marketing services agreement" without fair-market-value documentation.
- No DMCA takedown procedure for unauthorized listing use by competitors.
- Cookie consent absent for international visitors.
- MLS auto-suppress on expire missing — listings stay live past MLS rules.
- Photo dedup absent — broker uses MLS photos from other agent's listing.
- Co-broke compensation field still in MLS post-NAR settlement.
