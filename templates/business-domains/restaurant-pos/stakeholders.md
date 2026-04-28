# Restaurant POS — stakeholders

Restaurant POS is unique in being high-frequency, high-stakes, mixed-skill — the same terminal is used by a 19-year-old on their second shift and a 30-year veteran server mid-rush. Optimize for speed on core actions, robustness on edge paths, and zero cognitive load during rush.

## Server / waiter (primary power user)

The person with the tablet. Takes orders, fires to kitchen, collects payment. They touch the POS every 2-3 minutes for 6+ hours. Their speed = table turn = revenue.

**Workflows:**
- Greet + seat guests (or assigned by host).
- Open ticket on floor plan.
- Take appetizer round → fire.
- Take main + drink order → fire (bar drinks go immediately, mains on course).
- Check in mid-meal, add refills / desserts.
- Present check.
- Process payment + tip.
- Close ticket + move to next turn.

**Pain points:**
- "Finding the dish in the menu" — bad search + hidden items = slow service.
- "Wrong modifier picked" — tap-happy on small screens + noisy environments.
- "Fired the wrong course" — fire-button near "send-all" is a bug factory.
- "Card reader timeout" — guest waiting, server standing, no status.
- "Split this 4 ways" — MVP POS can only even-split; real parties split oddly.
- "Kitchen not responding" — is it broken or backed up? No signal = anxiety.
- "Missed my tip" — card tips visible only at day close, mistakes caught too late.

**Permissions:**
- Create / edit own tickets on assigned section.
- Fire to kitchen.
- Void before fire; void after fire = manager approval.
- Comp = always manager approval.
- Transfer ticket to another server.
- Own shift data.

**KPIs:**
- Tables served / shift.
- Average turn time (seat → paid).
- Average check size (upsell performance).
- Void + comp rate (low = healthy).
- Tip % (proxy for service quality).

**UX principles:**
- Big tap targets (thumb size minimum).
- Zero multi-tap menus (one tap, one result).
- Undo within 5 sec on destructive actions.
- Confirm only on irreversible (comp, void post-fire, close ticket).
- Loud visual feedback on fire confirmation.
- Offline mode that doesn't panic the server — queue silently, reconcile later.

## Bartender

Similar to server but stationary at bar. Shorter tickets, faster turn, higher volume.

**Specific needs:**
- Quick-tap drink menu (top 50 cocktails + 30 beers + 30 wines = 99% of volume).
- Batch build (3 margaritas at once = one ticket, three items).
- Bar tab open with card pre-auth → multiple rounds → close.
- Speed-pour recipe integration (pour tracker + inventory).

**Pain points:**
- "Pre-auth releases before close" — card on file expires, tab reopened day-of-week later = lost money.
- "Slow during rush" — bar rush is 2-hour sprint; every extra second compounds.
- "Blind to kitchen" — bar orders for food go to kitchen; needs to see if food is ready.

## Kitchen staff (line cook, expo)

Reads KDS. Cooks. Bumps item when ready. Expo coordinates plating + runner.

**Workflows:**
- See new ticket on station screen with audio cue.
- Read items + modifiers + special instructions.
- Cook to order.
- Tap "ready" on item when plated.
- Expo verifies full ticket ready → runner takes.
- 86 an item → tap from KDS → pushes to POS + online.

**Pain points:**
- "Screen too small" — hood vapor, distance, small text = misread orders.
- "No ack on modification" — server changes an already-cooked dish, kitchen sees it too late, waste.
- "Ticket age not visible" — oldest-first is not obvious; some systems sort by fire-time but display alphabetically.
- "Expo can't see station backlog" — overloaded station invisible to expo, delays.

**Permissions:**
- Read-only to ticket text + modifiers + instructions.
- Bump item / recall item.
- Declare 86.
- Cannot see prices (food cost conversation happens elsewhere).
- Cannot modify tickets directly.

**UX principles:**
- Large text (readable from 2m through steam).
- Station-specific (cold station doesn't see hot ticket items).
- Color for age + priority.
- Audio cue for new ticket + modification.
- One-tap bump; recall window 10 sec.

## Host / maître d'

First contact. Manages floor plan, reservations, waitlist.

**Workflows:**
- Take reservations via phone or integration feed.
- Arrive guests: check in reservation or walk-in.
- Seat at table; open ticket or delegate to server.
- Waitlist management + SMS when ready.
- Balance server sections (new party goes to server with most capacity).

**Pain points:**
- "Guest says they have a reservation but it's not here" — cross-platform reservation reconciliation.
- "Table turning slower than expected" — need visibility into current meal phase per table.
- "Double-booked a table" — reservation + walk-in collision.
- "Server over-sectioned" — assigning without knowing section's current load.

**Permissions:**
- Floor plan edit / assign.
- Reservation CRUD.
- Open ticket for server (without taking order).
- Read-only on ticket + payment (no edit).

## Manager

Oversees service. Approves exceptions. Runs reports. Handles crises.

**Workflows:**
- Pre-shift: staff scheduling + menu review + 86 check.
- During service: roam, support staff, approve voids/comps, handle guest complaints.
- Post-shift: reconcile cash drawers, validate tip declarations, review voids/comps.
- Day close: Z report, pending captures, tip pool distribution.
- Weekly: labor cost, food cost, top items, staff performance.

**Pain points:**
- "Approval queue constant interruption" — manager pulled from floor every 5 min for PIN entry.
- "Void reasons meaningless" — free-text "mistake" gives no insight.
- "Cash drawer over-short without cause" — hard to investigate without camera + log correlation.
- "Labor + food cost lag 3 days" — reports generated too slowly to act on.
- "Tip pool disputes" — staff thinks calculation is wrong; no transparent audit.

**Permissions:**
- Everything servers can do.
- Approve voids after fire, comps, price overrides.
- Void whole tickets.
- Cash drawer open (non-sale reason).
- Refund post-payment.
- Edit menu (price + 86 + availability).
- Employee management (PIN reset, schedule).
- Read reports.
- Close shift (others) + day close.

**Anti-patterns:**
- "Manager PIN = 1234" — every employee knows it; approvals meaningless.
- Must have rotation or biometric backup.

## Owner / operator

Looks at numbers. Rarely at POS terminal. Uses manager dashboard or back-office app.

**Wants:**
- Revenue per day / week / month / YoY.
- Food cost % + labor cost % (targets ~30 + ~30 for most models).
- Top-performing items + dogs.
- Customer count trends.
- Reservation fill rate.
- Online vs in-house mix.
- Comp + void as % of sales.

**Pain points:**
- "Can't see real-time numbers remotely" — has to call manager for current day's tally.
- "Report exports are messy" — accountant complains monthly.
- "Hard to compare locations" (chain) — separate reports, manual Excel merge.

## Accountant / bookkeeper

Episodic but high-stakes.

**Wants:**
- Daily sales + tax + tip totals exported.
- Sales tax liability per period + jurisdiction.
- Payroll export (hours + tip declarations).
- Reconciliation with card processor statements.
- 1099 for contractors (delivery drivers if in-house).
- Annual Form 8027 (large food/beverage establishments — tip allocation).

**Pain points:**
- "Raw CSV dump with cryptic column names" — interpretation burden.
- "Card processor payout ≠ POS total" — timing (multi-day capture lag) + fees not broken out + chargebacks interleaved.
- "Tip pool math opaque" — redo manually to verify.

## Kitchen manager / chef

Manages food cost, recipes, supplier orders.

**Wants:**
- Item sales counts (drives prep + purchasing).
- Recipe + ingredient consumption (from POS fire events).
- Waste tracking (voids, comps, opened-but-unsold).
- 86 frequency (what runs out too early → re-order or re-portion).

## Customer (the diner)

Not a primary POS user, but experiences POS via receipts, QR pay, online order.

**Touchpoints:**
- Online / QR menu → expects current prices + availability.
- QR pay at table → expects quick + secure.
- Receipt → expects clear itemization + tip option + contact for disputes.
- Email / SMS receipt → expects not to be marketing-spammed.

**Pain points:**
- "Menu online doesn't match what I can actually order" (86 mismatch).
- "Tip prompt makes me feel awkward" (tip presets on low-service counter pickup = controversial).
- "Can't find my receipt from 3 weeks ago" — receipt copy request process.
- "Charged twice" (split-bill misclick or auth+capture confusion).

## Delivery courier (if in-house delivery)

If the restaurant dispatches its own drivers (vs 3rd-party), this is the on-demand domain overlap.

**Pain points (touching POS):**
- "Order status confusing" — POS says "ready for delivery" but not when it's actually ready.
- "Tip on delivery" — customer tips in app; courier paid via different system; reconciliation needed.

## 3rd-party delivery platform (Uber Eats, Doordash, Grubhub, Deliveroo, Glovo)

Not a user — an API peer.

**Interactions:**
- Receive orders via webhook → POS inserts ticket with channel flag.
- Update status → POS pushes accept / ready / completed.
- Menu sync → POS source of truth, platform catalog derived.

**Pain points:**
- "Platform menu out of date" — sync lag = customer orders 86'd item.
- "Platform payment reconciliation" — platform pays weekly net of fees; POS must record gross + fee + net per order for bookkeeping.

## Stakeholder-driven feature priorities

| If the complaint is from... | Then priority is... |
|---|---|
| Servers "It's slow during rush" | UI optimization, offline mode, fewer taps per order |
| Kitchen "We can't read the modifications" | KDS font size, color cues, modification ack loop |
| Manager "Voids are out of control" | Controlled reason vocabulary, void/comp dashboard, server-level reports |
| Accountant "Month close takes 3 days" | Report automation, clean export, card processor reconciliation |
| Owner "I'm flying blind" | Real-time dashboard accessible remotely |
| Guests "My check is wrong" | Itemization clarity, split-bill robustness, tip math transparency |
| Staff "Tip pool is unfair" | Pool algorithm visibility + audit log + dispute workflow |
| Regulators "Failed inspection" | Fiscal compliance, allergen data on customer menus, age-check on alcohol |

## Anti-pattern: "the owner uses the POS"

Common: owner designs the POS around their own workflow (which is 80% admin, 20% emergency-server-cover). Real operators are servers during rush. Design for the 19-year-old server on their second shift, not the owner watching reports from a booth. If the 19-year-old server has to ask twice, it's broken.
