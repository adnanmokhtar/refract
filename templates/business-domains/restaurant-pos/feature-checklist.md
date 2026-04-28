# Restaurant POS — feature checklist

The 80%-of-projects-need-this list. Restaurant POS v1s commonly ship as "glorified order form" — missing shift management, split bills, or kitchen timing, then discover on opening night that service falls apart.

Use this in `business-auditor` reviews + as a P1/P2/P3 planning anchor.

## Server-facing (the tablet in hand)

### Order entry
- [ ] Floor plan view with live table status (open / seated / check-requested / dirty / reserved).
- [ ] Touch-optimized item browse — big buttons, category tabs, search.
- [ ] Quick-add for top 10 items (configurable).
- [ ] Modifier picker with required/optional + min/max selection rules.
- [ ] Special instruction free-text field per item (no onions, extra well done, birthday, etc.).
- [ ] Seat number assignment per item (even single-seat — needed for later split).
- [ ] Course assignment per item with visual grouping.
- [ ] Send to kitchen with station-based routing preview.
- [ ] Hold + send-later per item (for wine-with-main, etc.).
- [ ] Modify after fire (with kitchen ack loop).

### Ticket management
- [ ] Open a new ticket from table tap.
- [ ] Multiple open tickets per server visible in list.
- [ ] Transfer ticket to another server (shift change).
- [ ] Merge two tickets (late arrival joins).
- [ ] Split ticket: by seat / by item / even / custom amounts.
- [ ] Add items mid-meal without re-firing appetizer course.
- [ ] Recall closed ticket (within window — manager PIN).
- [ ] Print guest check at table (non-payment preview).

### Payment + tip
- [ ] Cash payment with change calculation.
- [ ] Card payment via EMV chip + contactless.
- [ ] Tip presets (18/20/22/25%) + custom amount.
- [ ] Tip on subtotal OR total — configurable + displayed consistently.
- [ ] Split payment: card + cash mix, multi-card.
- [ ] Gift card redemption with balance lookup.
- [ ] House account charge (staff meals, comped guests with tracking).
- [ ] Receipt print + email + SMS options.
- [ ] Customer-facing display shows total before card insert (price transparency).
- [ ] Bar tab open (card pre-auth) + close flow.

### Void + comp
- [ ] Void before fire (no approval — informational log).
- [ ] Void after fire (manager PIN + reason).
- [ ] Comp item (always manager PIN + reason + amount).
- [ ] Comp whole ticket (escalated approval).
- [ ] Reason selector (controlled vocabulary, not free text).
- [ ] Audit log showing server + manager + reason per void/comp.

### Shift + clock
- [ ] Clock in with PIN or biometric.
- [ ] Break start/end (paid/unpaid).
- [ ] Section assignment visible.
- [ ] Current tip total running sum.
- [ ] Open tickets warning before clock-out.
- [ ] Clock out → declare tips → sign-off.
- [ ] Per-shift earnings summary.

## Kitchen-facing (KDS)

### Station screen
- [ ] Incoming tickets sorted by fire-time oldest first.
- [ ] Per-item timer (time since fire).
- [ ] Color escalation (green < 8 min, yellow 8-12, red > 12).
- [ ] Audio + visual alert on new ticket.
- [ ] Bump item (individual) + bump full ticket.
- [ ] Recall last bumped (oops).
- [ ] Special instruction highlighted in contrasting color.
- [ ] Course pending indicator (main queued behind appetizer).
- [ ] Modification incoming → ack/reject.
- [ ] 86 declaration from KDS (pushed to all order entry points).

### Expo screen
- [ ] All open tickets at glance with plate-status per item.
- [ ] "Fire next course" button per ticket.
- [ ] Table map linkage (see which table each ticket is for).
- [ ] Runner assignment (who's bringing it out).
- [ ] Complete ticket = all items served.

### Station config
- [ ] Stations (cold / hot / grill / saute / fry / expo / bar) mapped to items.
- [ ] Printer OR KDS per station (or both).
- [ ] Station capacity + backlog depth visible to manager.

## Host-facing

### Floor plan
- [ ] Drag-drop table editor for floor layout.
- [ ] Multi-section support (patio, bar, private room).
- [ ] Merge / split tables for large parties.
- [ ] Table status colors match server view.

### Reservations + waitlist
- [ ] Book reservation: name + party + time + phone + notes + preferences (high chair, allergies).
- [ ] Reservation grid by time slot + table.
- [ ] SMS confirmation + reminder.
- [ ] No-show handling with grace window + optional hold fee.
- [ ] Walk-in waitlist: party + phone + estimated wait.
- [ ] SMS when ready.
- [ ] Turn-time estimate per table (data-driven).

## Manager-facing

### Live ops
- [ ] Live sales dashboard (current day).
- [ ] Open tickets list with server + table + duration.
- [ ] Approval queue (pending voids / comps / price overrides).
- [ ] Alerts: item running low, ticket aging beyond threshold, table over average turn.
- [ ] Remote shift close (if away from physical drawer).

### Menu management
- [ ] Menu CRUD: items, modifier groups, categories.
- [ ] Price scheduling (happy hour, prix fixe, lunch/dinner pricing).
- [ ] 86 / unhide management.
- [ ] Allergen tagging per item.
- [ ] Per-location overrides (for chains).
- [ ] Menu availability windows (breakfast/lunch/dinner).
- [ ] Image upload per item (customer display).
- [ ] Taxonomy + search terms.

### Employee management
- [ ] Employee CRUD with role (server, host, bartender, cook, manager).
- [ ] PIN reset.
- [ ] Permissions matrix per role.
- [ ] Timesheet review + edit (with audit).
- [ ] Tip pool rules config (house pool / server-only / by-hours / by-sales).
- [ ] Labor cost vs sales % live.

### Reports + Z-report
- [ ] Daily Z report (fiscal-compliant where required).
- [ ] Sales by category / item / server / section / hour.
- [ ] Void + comp report by server + reason.
- [ ] Tip declaration vs card tip reconciliation.
- [ ] Labor hours vs sales $ (labor cost %).
- [ ] Weekly / monthly / custom range with export (CSV + PDF).
- [ ] Top-selling items.
- [ ] Slowest-moving items (86 candidates).
- [ ] Guest count trends.

### End-of-day
- [ ] Close shift per server with cash reconciliation.
- [ ] Declare tips + submit.
- [ ] Tip pool computation + distribution record.
- [ ] Close day with aggregate totals.
- [ ] Z report output (fiscal ticket + digital).
- [ ] Pending card captures submitted.
- [ ] Open ticket warning with override.

## Customer-facing (optional)

### QR from table
- [ ] Scan QR → menu with prices.
- [ ] Add to ticket tied to table_id.
- [ ] Fire on guest tap (auto-accept or server-accept mode).
- [ ] Live check view throughout meal.
- [ ] Pay at end via phone (Apple Pay / Google Pay / card).
- [ ] Tip on phone with presets.

### Online ordering + delivery
- [ ] Web menu with hours + availability.
- [ ] Cart + checkout + payment.
- [ ] Pickup vs delivery toggle (delivery handled by 3rd party or in-house courier).
- [ ] Order status updates (received → preparing → ready → out for delivery / ready for pickup).
- [ ] Kitchen sees order with CHANNEL tag.

### Kiosk
- [ ] Self-order terminal with accessibility (wheelchair height, screen reader support).
- [ ] Menu grid + modifier flow.
- [ ] Payment integration (card + tap).
- [ ] Printed receipt + order number for counter pickup.

## Trust + compliance

- [ ] PCI DSS for payment flows (tokenization, no PAN storage).
- [ ] Allergen disclosure on menu (required in EU by Food Information Regulation 1169/2011).
- [ ] Alcohol age verification at POS for alcoholic items.
- [ ] Tip pool law compliance (US FLSA tip credit rules; UK Tipping Act 2023 if applicable).
- [ ] Fiscal receipt compliance (Italy SDI, Brazil NFC-e, KSA ZATCA, Spain Veri*factu 2026).
- [ ] Right to delete customer profile (loyalty + reservations) — GDPR.
- [ ] Receipt copy / reprint clearly marked.
- [ ] Audit log of manager overrides (voids, comps, price changes, tip adjustments).

## Operational

- [ ] Offline mode: ticket entry + payment queueing when LAN drops.
- [ ] Sync resolution on reconnect (conflict detection + manager review for duplicates).
- [ ] Printer failover (receipt printer out → prompt to reprint to alternate).
- [ ] Card reader failover (one down → cash-only mode with warning).
- [ ] Daily backup of all tickets + audits.
- [ ] Update rollout protection: POS cannot auto-update during business hours (lost sales = lawsuits).
- [ ] Monitoring on KDS screen health (blank screen = lost orders).

## Things v1s commonly miss

- Split bill by seat (frontend pitches "even split" as MVP; real guests split by item or seat more often than even).
- Tip on SUBTOTAL vs TOTAL inconsistency between receipt, printer, and card reader screen (customer complaint magnet).
- Manager approval required for void AFTER fire — without it, servers hide comp'd food behind voids + inventory drifts.
- Course timing — all items fire at once → appetizers + mains arrive together → guest unhappy + kitchen chaos.
- Kitchen ack on modification — server changes item after fire, kitchen already plated, waste.
- 86 list not synced to QR / online menu → customer orders unavailable item.
- Receipt REPRINT / COPY marking absent → fiscal fraud exposure (Italy / Brazil / KSA).
- Clock-out with open tickets → server walks away, ticket orphans, next shift inherits confusion.
- Tip pool math visible only in accountant's spreadsheet — staff questions always end in arguments.
- Change calculator for cash (kids working the register get this wrong faster than you'd expect).
- No offline mode — router dies mid-service, restaurant shuts down.
- Device battery for wireless tablets not monitored — dead tablet mid-service.
- Reservation no-show fee not captured (card hold at booking) → chronic no-shows.
- Alcohol age check absent in alcohol-serving items → bar takes the heat.
- Labor law: minors clock-in validation (US states have strict under-16 hours limits).
- Translation of menu (kitchen staff may not read English; prep notes need kitchen-language).
- Calorie + allergen data on consumer menu (NYC, California, EU mandate).

## Things often over-built in v1 (defer until validated)

- AI menu recommendations.
- Predictive ordering ("likely this guest wants a refill").
- Facial recognition for loyalty / age check.
- Drone delivery integration.
- Multi-language customer app (start English + local primary language only).
- Inventory system with recipe-level ingredient tracking (ship with SKU-level + layer recipe later).
- Kitchen robotics integration.
- Voice ordering / AI drive-thru.
- NFT loyalty / crypto payment.
