# Restaurant POS — core flows

The flows every POS must support. P1 is "without these you can't run a service." P2 is "without these servers hate the system." P3 is "competitive + scale."

## P1 — must-have for v1

### 1. Seat → take order → fire to kitchen → serve → pay

The core loop. Everything else is support.

```
Host / server: taps empty Table on floorplan
  → creates Ticket with guest_count + server_id + opened_at
  → Table.status = seated
  → Server walks through menu on tablet
  → adds TicketItem rows (menu_item + modifiers + special_instructions + course + seat_no)
  → subtotal recomputes live (including modifier price deltas)
  → Server taps "Send" → items marked status=fired, routed by station_id to KDS / printer
  → Kitchen prepares; bumps item ready on KDS → status=ready → runner announcement
  → Food delivered to table → server taps "served" (or auto-mark on expo bump)
  → Guest requests check → server prints check OR sends to QR-pay
  → Payment captured (cash / card / split) → Ticket.status = closed
  → Table.status = dirty until busser clears
```

Key invariants:
- Ticket is ALWAYS the source of truth. KDS, receipt printer, cash drawer — all derive state from Ticket; they do not own state.
- Fire event is atomic per "Send" — never partially routed to KDS (one item lands, one doesn't).
- Modifier price deltas included in subtotal at add-time AND at payment time (no silent drift — see anti-patterns).
- Every TicketItem carries `seat_no` even in single-seat mode (allows later split-by-seat without re-entry).
- Special instructions route to kitchen with item; printed + displayed prominently.
- Idempotency on "Send" — double-tap must not re-fire a line (duplicate cook = food cost hit + service delay).

### 2. Modify while cooking

Guest changes mind after firing. Kitchen may or may not have started.

```
Server edits TicketItem on tablet
  → if item.status == 'cooking': mark as pending_modification; send modification ticket to station
  → station (on KDS) sees original + requested change, acknowledges (accept / reject)
  → if accept: original item superseded; new item inserted with modification_of_id reference
  → if reject (already plated): server informed; guest either accepts or orders replacement + old item becomes void/comp per policy
  → if item.status == 'fired' but not yet cooking: kitchen can void quietly
  → if item.status == 'new' (not yet fired): edit is free-form
```

Invariants:
- Kitchen ACK is mandatory for modifications of cooking items. Server cannot unilaterally change a dish after fire without confirmation (prevents "hot pan" waste + service miscommunication).
- Audit trail: who modified, when, original, new, reason.

### 3. Course timing (fire sequencing)

A 4-top orders appetizers + mains + dessert. Kitchen must not fire all at once.

```
Server enters all items with course (appetizer/main/dessert)
  → On "Send": only appetizer items fire immediately
  → Main items marked "pending" on KDS (expo sees them as queued)
  → Expo / server taps "Fire mains" when appetizers cleared → main course items fire
  → Same for dessert
  → Expo can "Fire all" override for fast turn tables
```

Invariants:
- Course entity defines `fire_order` (1, 2, 3) and `hold_until_prior_course_ready` flag.
- Bar drinks usually fire instantly (exception — ignore course hold).
- Appetizer + main timing affects both food quality and table turn rate.

### 4. Split bill

Guest(s) request separate checks.

```
Server taps "Split" on Ticket
  → mode selector: by seat / by item / even N-ways / custom amounts
  → system creates N SplitBill records referencing parent Ticket
  → by-seat: each TicketItem's seat_no → goes to that SplitBill
  → by-item: server/guest taps items into buckets
  → even: subtotal / N → N SplitBills of equal amount
  → custom: server types amounts; validator enforces sum == subtotal
  → tax + service charges + tip distributed proportionally OR per rules (often service charge is added to EACH split independently)
  → each SplitBill collects its own Payment
  → Ticket closed when ALL splits paid
```

Invariants:
- Split math must always sum back to the parent ticket's totals. No "lost pennies" — allocate rounding to one split deterministically.
- A split cannot be "uncollected" after paid without a refund + re-open flow.
- Tips calculated on each split's subtotal independently, not on parent (most common rule; document exception per locale).

### 5. Payment + tip

```
Payment method selector: cash / card / gift / house account / voucher / external delivery payment (already settled)
  → amount entry: full ticket OR partial
  → if card: card reader prompt
  → if US card present: tip presets (18/20/22%) + custom on reader screen
  → if card not present (split on tablet): tip entered by server
  → auth → capture (or capture-later for bar tabs)
  → Payment.captured_at set; receipt printed + optionally emailed
  → cash drawer pops on cash payment; change calculated + displayed
```

Key invariants:
- Tip presets calculate consistently — on SUBTOTAL or on TOTAL-INCLUDING-TAX; must match what guest sees. Inconsistency is a common compliance complaint.
- Card tip adjustment window: card authorized for auth_amount, captured later with tip included (day-close). Capture must complete within provider window (Stripe: 7 days; typically done at day-close).
- Cash over-short computed per shift, not per transaction.
- Gift card redemption: split payment (partial gift + remainder card/cash) is the norm.

### 6. Void + Comp (with manager approval)

Void: item removed before payment. Comp: manager gives item free.

```
Void:
  server selects TicketItem → "Void"
  → if item NOT fired: free-form void + reason selector
  → if item fired + cooking: manager PIN required + reason + notify kitchen
  → item.status = voided; reason + actor + approver logged
  → removed from subtotal

Comp:
  server selects TicketItem → "Comp"
  → ALWAYS manager PIN required (or biometric)
  → reason selector: manager_comp / customer_complaint / birthday / training / mistake
  → amount_off or percent_off or full
  → item.status = comp'd (stays on ticket visually, price adjusted, reason visible)
  → subtotal recomputes
```

Invariants:
- Manager approval is ALWAYS logged — actor + target + reason + timestamp + comp amount. No "self-approve" even if server is manager role.
- Comps are reported nightly for P&L analysis; excessive comps by specific servers = training signal (or theft signal).
- Void reasons must be a controlled vocabulary (enum) — free text defeats reporting.

### 7. Print receipt + reprint

```
On payment close: receipt prints to thermal printer + optionally emails / SMS
Reprint: server taps "Reprint" on closed Ticket
  → new print with REPRINT or COPY marking on header
  → Receipt.copy_count increments
  → fiscal printer contexts: MUST emit fiscal-compliant reprint (not a fresh sale)
```

Invariants:
- Reprint clearly marked so it's distinguishable from original by customer + auditor (fraud risk — two "originals" = double-claim).
- Fiscal jurisdictions (Italy, Greece, Brazil, KSA, Romania, Spain): reprint has a distinct fiscal number sequence or explicit "DUPLICATE" marker; failing this = tax fraud exposure.
- Email/SMS receipt: customer opt-in at payment time; email captured optionally.

### 8. End of day — Z report

```
Shift supervisor taps "Close day" (or auto-close at configured time)
  → all open tickets flagged (cannot close day with open tickets → exception: cash drawer)
  → all pending card captures submitted
  → cash drawer reconciled: declared cash / counted cash / over-short
  → tip declaration per server (US FLSA requirement)
  → tip pool computation (if pooled) and distribution record
  → Z report generated: gross sales / net / tax / tips / comps / voids / payment breakdown / top items
  → fiscal printer emits Z-report ticket (fiscal jurisdictions)
  → daily totals locked (day "closed" — no backdated edits)
  → next business day opens
```

Invariants:
- Z report is immutable once emitted (fiscal audit requirement).
- Open tickets at close = manual override with manager log.
- Tip declarations feed payroll — any re-entry of tips post-Z-report requires payroll adjustment paperwork.

## P2 — the things servers will complain about within a week

### 9. Online order integration

Orders from website / delivery app / QR table menu enter the same Ticket queue.

```
External system (storefront / Uber / Doordash / QR) → API
  → create Ticket with channel flag + guest info + optional table reference
  → items fire to kitchen immediately (typically) or after manual "Accept" (if restaurant controls pace)
  → kitchen sees ticket on KDS alongside in-house tickets (visual tag: ONLINE / DELIVERY)
  → when ready: handoff to courier (delivery) or runner (in-dining) or bag area (pickup)
  → payment already settled externally (3rd party) or collected at pickup (phone order)
```

Invariants:
- Channel identity preserved in reporting (dine-in vs online vs QR vs delivery).
- Inventory 86 list shared: if bar runs out of an item, the QR menu + delivery apps reflect it within seconds. Otherwise: customer pays, kitchen rejects, refund loop.
- Tip on delivery: goes to courier (platform policy), not to kitchen — keep books separate.

### 10. Reservations + waitlist

```
Host creates Reservation: name + party_size + time + phone + notes
  → pre-book a Table during a time slot (or not, depending on policy)
  → guests arrive → Reservation.status=seated + Ticket opened
  → no-show: after grace (e.g. 15 min), mark no_show; optional credit card hold fee captured
  → waitlist: no time booked; host adds to list with party_size + phone; SMS when ready
```

### 11. Shift management + clock-in

- Employee clocks in with PIN/biometric → Shift opens.
- Server assigned sections.
- Break clock (paid / unpaid).
- Clock out → declare tips → Shift closes.
- Cannot clock out with open tickets assigned to you — manager override required.

### 12. Kitchen station rules + routing

- Each MenuItem has a station_id.
- Multi-station dishes (plate with hot + cold components): one PRIMARY station + secondary "dependency" items routed there too.
- Bar bar-drinks route immediately regardless of course.
- Station load balancing: expo screen shows backlog depth per station; host/manager can delay new bookings if kitchen backed up.

### 13. Menu availability windows

- Menu items have active_hours (breakfast 7-11, lunch 11-15, dinner 17-22).
- System auto-hides items outside window.
- Manual "override" for special events.

### 14. 86 flow

```
Server / chef marks item 86 on KDS or tablet
  → item vanishes from all order entry screens (POS, QR, kiosk, online)
  → attempted order of 86'd item blocks + shows "out of stock"
  → active until cleared OR until day-close auto-clear
  → optional: reorder alert to inventory system
```

### 15. Refund post-payment

- Manager authority required.
- Refund reason logged.
- Card refund goes to original card (provider channel).
- Partial refund allowed; tracked as Refund record against original Payment.

## P3 — scale + advanced

### 16. Multi-location analytics

- Cross-location reporting: same dish, different margins.
- Central menu catalog with per-location price/availability override.
- Consolidated labor reports.
- Trends: busiest day/hour per location.

### 17. Inventory integration

- Each menu item has recipe; fire event decrements ingredients.
- Low-stock alerts.
- Waste tracking (voids + comps + opened-but-unsold).

### 18. Customer loyalty / membership

- Capture phone/email at payment; credit visits.
- Redeem rewards as auto-comp.

### 19. Reservation platform integration

- OpenTable / Resy / SevenRooms sync: booking → Reservation entity.
- Table turn times feed back to booking system availability.

### 20. Kitchen Display System (KDS) specifics

- Per-station screen with touch ack (bump).
- Color-coded by time since fire (warning at 12 min, critical at 18 min).
- Ticket age visible.
- "Recall" last bumped item (oops, not ready).
- Audio + flashing alert on new incoming ticket.

### 21. Recipe-level allergen filtering

- At POS: "Gluten-free filter" hides/highlights items.
- On menu: allergen icons per dish (gluten, dairy, nuts, shellfish, sesame).
- Warning on special instructions mentioning allergen: kitchen must confirm recipe + substitute.

## Idempotency-critical endpoints

- `POST /tickets/:id/fire` — double-tap on "Send" must not duplicate kitchen orders.
- `POST /tickets/:id/payments` — double-charge risk; idempotency key per payment.
- `POST /tickets/:id/void`, `POST /tickets/:id/comp` — repeated must be no-op (idempotent), log shows one occurrence.
- `POST /kds/tickets/:id/bump` — KDS bumps must not un-bump on double-tap.
- `POST /shifts/:id/close` — closing twice must not double-compute tip pool.

## Concurrency-critical paths

- Two servers edit same Ticket simultaneously: last-write-wins breaks; optimistic lock on `version` column.
- Two payments for same ticket from two terminals: over-collection. First payment locks remaining_due; second is rejected or accepted as overpay (explicit flow).
- Kitchen bump + server modify collision: KDS ACK on modification is the serialization point.
- 86 race: item marked 86 after Guest added it to ticket before send. Validator on fire catches and returns error — server must remove or substitute.

## Webhooks to produce

- `ticket.opened`, `ticket.fired`, `ticket.closed`.
- `payment.captured`, `payment.refunded`.
- `shift.closed`, `day.closed`.
- `item.86ed`, `item.86_cleared`.
- `reservation.booked`, `reservation.seated`, `reservation.no_showed`.

## Webhooks to consume

- Payment provider: `charge.succeeded`, `terminal.reader_disconnected`, `terminal.reader_connected`, `dispute.created`.
- Delivery platforms (Uber Eats / Doordash / Deliveroo): new order, cancellation.
- Reservation platform (OpenTable / Resy): new booking, cancellation, modification.
- Loyalty platform: point balance update.
