# Booking — feature checklist

What every booking system needs. Most v1s leak revenue at no-shows + double-bookings + reminder failures.

## Customer-facing

### Discovery + search
- [ ] Search by service + date range + (optional) preferred provider.
- [ ] Provider profiles with photo, bio, services, ratings.
- [ ] Service pages with description, duration, price, deposit info.
- [ ] Real-time availability (no "call to confirm" friction).
- [ ] "First available" shortcut.
- [ ] Filter by service attribute (men's cut, kids' service, COVID-vax-status, language spoken).
- [ ] Multi-location search (chains).

### Booking flow
- [ ] Slot picker showing customer's local TZ explicitly.
- [ ] Soft-hold on slot during checkout.
- [ ] Account-optional checkout (guest with email + phone).
- [ ] Add-on / upsell at booking (extra service, retail).
- [ ] Coupon / promo code.
- [ ] Deposit / full prepayment / pay-on-arrival options.
- [ ] Confirmation page with booking ID + ICS download + add-to-calendar.
- [ ] Mobile-optimized (most bookings on phone).

### Pre-arrival
- [ ] Confirmation email immediate.
- [ ] Reminder cadence: 24h email + 2h SMS (configurable).
- [ ] Add to calendar (Google, Apple, Outlook ICS).
- [ ] Map / directions for in-person.
- [ ] Joining link for virtual.
- [ ] Pre-appointment forms (intake, questionnaire) — completed before arrival.
- [ ] Reschedule self-service (signed link, no login).
- [ ] Cancel self-service.

### Post-appointment
- [ ] Receipt.
- [ ] Review prompt.
- [ ] Re-book CTA ("Schedule next visit?").
- [ ] No-show acknowledgment + offer to reschedule.

### Account
- [ ] Sign in / saved profile.
- [ ] Booking history with status.
- [ ] Saved payment methods.
- [ ] Saved providers / favorites.
- [ ] Notification preferences.
- [ ] Time zone setting + override.

## Operator / Provider-facing

### Calendar
- [ ] Day / week / month calendar views.
- [ ] Color-coded by service/provider/status.
- [ ] Drag-to-reschedule with conflict detection.
- [ ] Click empty slot to create manual booking.
- [ ] Block out time (vacation, lunch, sick) with reason.
- [ ] Multi-provider overlay view.
- [ ] Mobile responsive (providers check from phone).

### Booking management
- [ ] List view with filter (date, status, provider, service).
- [ ] Booking detail: customer info, history, notes, payment, reminders sent.
- [ ] Edit booking (limited; with audit).
- [ ] Mark arrived / completed / no-show.
- [ ] Send custom reminder.
- [ ] Process refund.
- [ ] Add internal note (visible to staff).

### Customer / patient management
- [ ] Search customer by name / phone / email.
- [ ] Customer detail with booking history, notes, prefs, payment, no-show count.
- [ ] Add note / tag / preferences.
- [ ] Block customer (history of bad behavior, repeat no-shows).
- [ ] Merge duplicate profiles.

### Provider / staff management
- [ ] Provider CRUD with photo, bio, services, working hours.
- [ ] Per-provider working hours per day-of-week.
- [ ] Time-off / vacation calendar.
- [ ] Service assignment (which providers offer which).
- [ ] Capacity (1 for individual, N for class instructor).
- [ ] Per-provider commission (if applicable).

### Service catalog
- [ ] Service CRUD with name, description, duration, buffer, price, deposit, color.
- [ ] Categories.
- [ ] Add-on services.
- [ ] Service active/inactive.

### Settings
- [ ] Working hours of business.
- [ ] Holidays / closures.
- [ ] Booking lead time (min advance notice).
- [ ] Booking horizon (max days out).
- [ ] Cancellation policy (window + fee).
- [ ] No-show policy.
- [ ] Reminder cadence.
- [ ] Email + SMS templates.
- [ ] Branding (logo, color, business name).

### Reports
- [ ] Bookings today / week / month.
- [ ] Revenue today / week / month.
- [ ] Utilization (booked hours / available hours per provider).
- [ ] No-show rate.
- [ ] Cancellation rate.
- [ ] Average booking value.
- [ ] Top services.
- [ ] Customer lifetime value.
- [ ] New vs returning customers.

### Marketing
- [ ] Email campaign builder.
- [ ] Customer segments (e.g. inactive 90 days).
- [ ] Win-back automation.
- [ ] Birthday / anniversary triggers.
- [ ] Promo code CRUD.

### Integrations
- [ ] Google Calendar / Outlook 2-way sync.
- [ ] iCal feed (read-only) for personal calendars.
- [ ] Stripe / payment provider.
- [ ] SMS provider (Twilio, MessageBird).
- [ ] Email provider (SendGrid, SES).
- [ ] Zoom / Meet (auto-create meeting link for virtual).
- [ ] POS for retail add-ons.
- [ ] CRM sync.

## Trust + compliance

- [ ] HTTPS site-wide.
- [ ] Privacy policy + terms + cancellation policy + no-show policy pages.
- [ ] Cookie banner.
- [ ] HIPAA mode for healthcare (encryption + audit log + BAA-eligible vendors).
- [ ] PCI-DSS via provider.
- [ ] GDPR data export + delete.
- [ ] Cancellation policy disclosed at booking + in confirmation + at cancel.
- [ ] Late-fee disclosure pre-charge.
- [ ] Payment authorization vs charge clarity (cards stored = explicit consent).
- [ ] SMS opt-in compliance (TCPA, GDPR consent).

## Operational

- [ ] Reminder worker idempotent + at-least-once delivery.
- [ ] Soft-hold sweeper cron.
- [ ] Calendar-sync worker handling conflicts.
- [ ] Webhook idempotent for payment + calendar.
- [ ] Status page during peak hours.
- [ ] Backup of bookings + customer data.
- [ ] DR for SMS provider outage (multi-provider fallback).

## Things v1s commonly miss

- Time zone display — bookings shown in UTC or operator TZ to customers in different TZ → confused customer = no-show.
- Soft-hold during checkout — race conditions with two simultaneous bookers; one gets confirmed first, other gets confirmed against the same slot, then someone gets surprise-cancelled.
- Reminder cancellation on booking cancel — cancelled customer still gets "see you tomorrow" reminder = bad look.
- Cancellation policy enforcement — policy in T&Cs, not enforced in code; operators eat costs.
- Cancellation link in email — customers reply "cancel" to no-reply address; goes nowhere; no-show.
- DST handling on recurring bookings — clients arrive at wrong time twice a year.
- Capacity for classes — bug allows 21 in 20-cap class; instructor furious.
- Buffer time around bookings — back-to-back without prep = stressed providers + late starts.
- Walk-in handling — provider's calendar diverges from system reality.
- Phone number verification — typo in phone number = reminders fail silently.
- Multi-resource conflict — booking takes Room A but another booking takes Room A simultaneously because system only checked staff.
- Dependent provider services — Service requires Stylist X who is on vacation; system still shows the service available.
- Prepayment + cancel timing — customer paid; cancellation policy unclear; chargebacks.
- Holiday handling — system books Christmas day because nobody set it as closed.
- "Out of hours" emergency contact — booking system is the only contact channel; ops want a way to reach out manually.
- Accessibility for the booking form — keyboard nav broken; screen-reader users cannot book.

## Things often over-built in v1

- Live chat with provider before booking.
- Provider matching algorithm (start with manual selection or "first available").
- Marketplace-of-providers if you're a single business.
- Mobile native app (responsive web works; PWA enough).
- AI no-show prediction.
- Dynamic pricing.
- Loyalty program.
- Multi-language UI (unless explicitly serving multilingual market).
- Recurring billing for memberships (build after first 50 customers).
