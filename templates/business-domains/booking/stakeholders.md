# Booking — stakeholders

Booking systems serve a small business AND its customers; sometimes a multi-location chain or marketplace adds a third (the platform operator). Verticals shape the dominant stakeholder concerns.

## Customer / Client / Patient

The end-user booking the appointment.

**Workflows:**
- Discover (search, recommendation, walk-by).
- Choose service + provider + time.
- Book (form, pay, confirm).
- Wait (reminders, prep).
- Show up (or no-show / reschedule / cancel).
- Receive service.
- Pay any remainder.
- Re-book (return).

**Pain points the system must solve:**
- "When can I actually get in?" — real-time availability, not "call to confirm."
- "Will I forget?" — reminders that work (right channel, right time).
- "What if I need to change?" — self-service reschedule + cancel without phone tag.
- "How much will it cost if I cancel late?" — clear policy upfront.
- "Is this my time or theirs?" — TZ clarity.
- "Can I bring my kid?" — service notes, additional attendee logic.
- "Did they get my appointment request?" — instant confirmation.

**Sub-types differ in expectations:**

### Restaurant diner
- Cares about: same-day availability, party size, special occasion notes.
- Pain: deposit holds for parties of 6+, blacklisted for one no-show.

### Salon / spa client
- Cares about: their preferred stylist, allergy notes, retail at checkout.
- Pain: stylist leaves the salon and migrates to another → recapture friction.

### Patient (medical / dental)
- Cares about: insurance, intake forms, privacy, prescription handling.
- Pain: long forms, opaque billing, schedule available only weeks out.

### Fitness class attendee
- Cares about: class capacity (popular classes book out), waitlist auto-roll.
- Pain: cancellation fees feel punitive when life intervenes.

### Co-working desk / room
- Cares about: amenities, predictability, immediate confirmation.

### Service trade (plumber, cleaner)
- Cares about: arrival window accuracy, communication day-of.

**KPIs:**
- Time to first available slot (frustration with weeks-out availability).
- No-show rate.
- Repeat booking rate.
- Cancel rate.
- NPS / CSAT.

## Provider / Staff (the service-deliverer)

The person whose calendar is being booked. Their satisfaction = retention of the business's #1 asset.

### Solo practitioner (independent therapist, freelance hairstylist)
- Wants: clean calendar, easy block-out, low admin overhead, mobile.
- Pain: clients booking outside set hours, double-booking from external calendars, late cancellations destroying day.

### Salon / clinic staff member
- Wants: their shift schedule + their bookings clearly, ability to mark walk-ins, commission tracking visible.
- Pain: management changing their schedule without notice, customers requesting them then cancelling repeatedly.

### Restaurant host / front-of-house
- Wants: floor map view + booking overlay, walk-in queue management, party-size accommodation.

### Healthcare provider
- Wants: pre-appointment intake completed, allergy/contraindication flags visible, smooth handoff with billing.
- Pain: regulatory burden on every UI flow.

**Universal provider pain:**
- Schedule conflicts surfaced too late (after customer arrives).
- Customers no-showing without consequence.
- Last-minute changes by managers/clients.
- Buffer time between bookings ignored — back-to-back stress.

**KPIs (per provider):**
- Utilization (% of available time booked).
- Repeat-customer ratio.
- Cancellation rate.
- Average rating (if rated).
- Earnings (if commission-based).

## Operator / Business owner

Multi-role at small businesses (often the founder + receptionist + accountant). Larger operations have dedicated roles.

### Owner / manager
- Wants: revenue trend, utilization, top customers, top services.
- Glances daily; drills into anomalies.

### Receptionist / front-desk
- Wants: today's calendar, walk-in entry, customer lookup, payment, refund.
- Heaviest user.

### Marketing
- Wants: customer segmentation, win-back campaigns, promo codes, review aggregation.

### Accountant
- Wants: reconciliation reports, tax exports, refund register.

### Multi-location admin (chain)
- Wants: per-location reporting, staff scheduling across locations, cross-location booking option.

**Pain points:**
- Reporting that exists "but I can't trust it" (duplicates, missed walk-ins, manual edits not captured).
- Calendar going out of sync with reality after walk-ins / phone bookings.
- Reminder failures that look like customer no-shows.
- Cancellation policy enforcement is ambiguous (operators reluctant to enforce; customers exploit).

## Platform operator (SaaS booking platform)

For multi-tenant booking platforms (Calendly / Cal.com / SimplyBook / Booksy):

- Tenant onboarding + churn metrics.
- Plan upgrades / billing.
- Vertical-specific features (Booksy verticals = hair, nails, barber).
- Multi-currency / multi-language.
- Marketplace flow (consumer-facing aggregation across tenants).
- Trust + safety (low-quality businesses, fraud).
- Compliance per jurisdiction.

## Marketplace consumer (aggregator side — Booksy, Fresha, OpenTable, Mindbody)

- Wants: one app to find anything (haircut, massage, table tonight).
- Pain points: reviews biased / paid, real-time availability lying.
- Marketplace operator collects fees; sometimes commission, sometimes subscription.

## Calendar provider (Google Calendar / Outlook)

- Their API is your sync source-of-truth.
- Pain: rate limits, eventual consistency, OAuth refresh tokens expiring.
- Two-way sync collisions need conflict-resolution rules.

## SMS / Communication provider (Twilio / MessageBird / WhatsApp)

- Reminder delivery success rate = your no-show rate (proxy).
- Pain: per-country reachability, opt-in compliance, sender reputation.
- HIPAA-mode option for healthcare verticals.

## Payment provider (Stripe / Square / Adyen)

- Same shape as ecommerce.
- Specific concerns: pre-auth (hold) vs charge, refund partial-vs-full, deposit tracking.
- Card-on-file for no-show fees requires explicit consent flow.

## Insurance partner (healthcare)

- Insurance verification at booking.
- Coverage / deductible info.
- Claim filing post-visit (often outside booking system but linked).

## Regulators

### Healthcare
- HHS OCR (HIPAA enforcement).
- State medical boards.

### Consumer protection
- FTC.
- State AGs (state subscription / cancellation laws).
- ACL / EU Commission.

### Communications
- FCC (TCPA).
- CRTC (CASL).
- ICO (UK / GDPR ePrivacy).

### Tax
- IRS / state revenue / HMRC / EU tax authorities.

### Accessibility
- DOJ (ADA), state AG, EU EAA, AODA.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Customers no-showing → operator angry | Reminder cadence improvement, deposit policy, cancellation fee enforcement |
| Customers showing up wrong time | Time zone display fix, calendar export ICS |
| Providers double-booked | Soft-hold + transactional booking + buffer enforcement |
| Customers calling because system said unavailable | External calendar sync, walk-in capture |
| Owner can't see numbers | Reports + dashboard |
| Receptionist clicking too much | Workflow shortcuts, walk-in flow, search-by-anything |
| Marketing can't run campaigns | Customer segmentation + email/SMS integration |
| Patients lost in intake | Pre-arrival forms + reminder with link |
| Compliance officer worried | HIPAA mode, audit log, BAA-eligible vendor stack |

## Anti-pattern: "the calendar is the product"

Building a beautiful calendar UI without the policy + payment + reminder layers leaves the business worse off than a paper book. Bookings flow → policies enforce → reminders save no-shows → payments protect → calendar shows reality. The calendar is the visible 10%; the rest is the value.

## Anti-pattern: "let the receptionist sort it out"

Manual operations cover for missing automation: walk-ins not captured, walk-outs not refunded, late cancels not charged, reminders not sent. Receptionist becomes the human glue + leaves + business breaks. Build for the long-tail receptionist.

## Anti-pattern: "we'll add SMS later"

In bookings, SMS isn't a nice-to-have. It cuts no-shows by 30-50%. Email-only = leaving 40% of revenue on the table for high-volume verticals (salon, dental, massage).
