# Restaurant POS — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `restaurant-pos`:

**Entity / model names**: `Menu`, `MenuItem`, `Modifier`, `ModifierGroup`, `Table`, `Server`, `Ticket`, `Order`, `Course`, `Seat`, `KDSTicket`, `Station`, `Tip`, `SplitBill`, `Check`, `Tab`, `Void`, `Comp`, `Reservation`, `EightySix` / `86Item`, `Shift`, `Tender`, `Receipt`, `FiscalReceipt`.

**Folder / route names**: `pos/`, `kds/`, `menu/`, `tables/`, `floorplan/`, `tickets/`, `checks/`, `tips/`, `reservations/`, `kitchen/`, `stations/`, `end-of-day/`, `shifts/`.

**Dependencies (any language)**: `stripe-terminal`, `square-terminal`, `sunmi`, `clover`, `toast-api`, `lightspeed`, `revel`, `escpos`, `node-thermal-printer`, `react-native-bluetooth-escpos-printer`, `star-micronics`, fiscal printer SDKs (Epson FP-81, Custom VKP80), `opentable`, `resy`.

**Database schema**: tables for `tickets` + `ticket_items` + `menu_items` + `tables` + `stations` is the strongest signal. Presence of `modifier_groups` + `modifier_options` joined to line items → full POS, not a delivery-only system.

**Distinguishing from delivery-only**: restaurant-pos has a `Table` entity + `Server` + `Course` timing. Delivery-only has `DeliveryAddress` + `Courier` without physical seating. Mixed stacks (dine-in + delivery) will have both — classify as `restaurant-pos` if dine-in dominates, `on-demand` if delivery does.

**Distinguishing from ecommerce**: restaurants use `ticket`/`check` (open, grow, split, close) as the primary transactional unit — not `order` (placed, paid, fulfilled). If you see an open long-running transactional entity that accretes items over a meal, it's POS.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Menu` | the catalog | `id, name, type (food/drink/bar), active_hours, availability_rules, currency` | draft → active → archived |
| `MenuItem` | sellable dish/drink | `id, menu_id, name, price, station_id, course_id, tax_class, allergens[], prep_time_min, is_alcohol, age_required` | active → 86'd → active / archived |
| `ModifierGroup` | choice set on an item | `id, name, min_select, max_select, required, menu_item_ids[]` | mutable |
| `Modifier` | option inside a group | `id, group_id, name, price_delta, calorie_delta?, is_default` | mutable |
| `Table` | physical seat location | `id, section_id, number, capacity, x, y, shape, status (open/seated/dirty/reserved)` | state machine below |
| `Section` / `Zone` | group of tables for server assignment | `id, name, server_id (current shift)` | mutable |
| `Server` / `Employee` | staff taking orders | `id, pin, role (server/bartender/manager/host), active_shift_id` | clocked-in → on-break → clocked-out |
| `Shift` | server's working session | `id, employee_id, clock_in, clock_out, declared_tips, tip_pool_share` | open → closed |
| `Ticket` / `Check` | an open bill at a table | `id, table_id?, guest_count, server_id, subtotal, tax, tip, total, status, opened_at, closed_at` | open → sent → partial_paid → closed → reprinted |
| `TicketItem` / `LineItem` | a line on a ticket | `ticket_id, menu_item_id, qty, seat_no, course_id, unit_price, modifiers[], special_instructions, status (new/fired/cooking/ready/served/voided/comped)` | state machine below |
| `Course` | meal section | `id, name (appetizer/main/dessert), fire_order, hold_until_prior_course_ready` | ordered → fired → ready → served |
| `Station` | kitchen post | `id, name (grill/cold/saute/fry/expo/bar), printer_id, kds_screen_id` | mutable |
| `KDSTicket` | station's view of ticket items | derived from TicketItems routed to station; `id, station_id, ticket_id, items[], received_at, bumped_at` | new → cooking → ready → bumped |
| `Payment` / `Tender` | money collected against ticket | `id, ticket_id, method (cash/card/gift/house/other), amount, tip_amount, provider_ref, status` | initiated → captured → refunded / voided |
| `SplitBill` | partition of a ticket | `id, parent_ticket_id, guest_no? / seat_ids[] / custom_amount, subtotal, own_payment_id?` | open → paid |
| `Tip` | gratuity | embedded on Payment: `tip_amount`; may also have TipPool entity | collected → allocated → paid_out |
| `Void` | item removed before payment | `id, ticket_item_id, reason, voided_by (server_id), manager_approval_id?, created_at` | created (immutable) |
| `Comp` | manager-authorized free/discounted item | `id, ticket_item_id, reason, amount_off, percent_off?, manager_id, created_at` | created (immutable) |
| `Reservation` | booked table | `id, guest_name, party_size, when, table_id?, status (booked/seated/no-show/cancelled)` | booked → seated (or no_show / cancelled) |
| `EightySix` / `86Entry` | menu item out-of-stock signal | `menu_item_id, declared_by, reason (out-of-stock/quality/end-of-night), active, expires_at?` | active → cleared |
| `Receipt` | printed / emailed proof | `id, ticket_id, payment_id?, is_reprint, fiscal_number?, printed_at, copy_count` | printed → (reprint flag on copies) |
| `Manager` | elevated permission holder | role on Employee; requires PIN/biometric for overrides | |

## Status state machines

**Table:**
```
open (empty) → seated (guests arrive) → ordering → dining → check-requested → paid → dirty → open
                          ↓                          ↓
                       walked (left without paying) — dispute / comp
reserved → held → seated
```

**TicketItem:**
```
new (in cart on server tablet) → fired (sent to KDS) → cooking → ready → served
        ↓                              ↓                  ↓
    voided (before fire)     voided (with kitchen ack)   comp'd (manager)
```

**Ticket:**
```
open → items-added → sent-to-kitchen → partial-payment → closed → reprinted
    ↓                                        ↓
 voided (whole ticket; rare)              split
```

**Payment:**
```
initiated → (auth if card) → captured → settled
                    ↓             ↓
                  voided       refunded (full/partial)
```

**Reservation:**
```
booked → confirmed → seated → (feeds into Ticket lifecycle)
   ↓          ↓
cancelled  no-show (after grace window)
```

**Shift:**
```
clocked-in → on-break → clocked-in → clocked-out → reconciled (declared tips submitted + tip pool computed)
```

## Vocabulary distinctions (don't conflate)

- **Ticket** vs **Check** vs **Tab** — Ticket is kitchen-facing (what to cook); Check is guest-facing (what to pay); Tab is an open bar check tied to a card on file. Same underlying row in many systems; distinct UI.
- **Modifier** vs **Special Instruction** — Modifier is priced + structured (extra cheese +$1); Special instruction is free text (no onions). Instructions do NOT alter price.
- **Course** vs **Station** — Course is timing (appetizer / main); Station is preparation location (grill / cold). An item has one station, belongs to one course. Items on same course fire together regardless of station.
- **Void** vs **Comp** vs **Refund** — Void: removed before payment (no money moved). Comp: manager-approved free/discount (money not charged; tracked for P&L). Refund: post-payment return (money moves back). Never use one for the other — accounting drift.
- **86'd** vs **Out of stock** vs **Archived** — 86'd is an operator flag ("we ran out tonight"); cleared next day or when restock declared. Out of stock is inventory-system truth. Archived is permanent menu removal.
- **Tip** vs **Gratuity** vs **Service Charge** — Tip: discretionary customer payment (taxable income, allocated per tip-pool rules). Gratuity: same as tip in most usage. Service Charge: mandatory fee (party-of-8+) — in US typically NOT tip for FLSA purposes; goes to operator who may redistribute. Critical distinction for payroll + taxes.
- **Split by seat** vs **Split by item** vs **Split evenly** — Seat: tag every item to a guest, pay per guest. Item: each guest picks which items they cover. Even: divide total by N. Different math; UI must let server pick.
- **Reprint** vs **Duplicate** vs **Copy** — Reprint: marked "REPRINT" or "COPY" on the face; fiscally distinct in regulated jurisdictions (Italy, Brazil, KSA). Copy without marking is fraud risk.
- **Bar tab** vs **Dining ticket** — Bar tab stays open long-form, card pre-authorized; dining ticket closes at end of meal. Different expiry logic.
- **Kiosk order** vs **Table order** vs **Online order** vs **QR-from-table** — Channel field on ticket. Routes differently to kitchen (all end at same KDS but printed/displayed with channel tag). QR-from-table typically creates a ticket tied to a table + guest-initiated.

## Multi-tenancy variants

- **Single-location restaurant**: one POS install, one menu, one printer set. Tenant = location.
- **Chain / franchise**: many locations, shared menu template with per-location overrides, per-location reporting + consolidation. `location_id` + `brand_id` on everything.
- **Concept group** (one owner, multiple brands): `brand_id` differs per restaurant though owner identical. Separate menus + KDS + reports per brand.
- **Ghost kitchen / dark kitchen**: no dining room; only delivery orders. Functionally closer to `on-demand`; borrow POS menu + KDS only.

## Device topology (unique to POS)

POS is rare in being multi-device per seat:

- **Server tablet**: enters orders, runs payment.
- **Kitchen printer** (legacy) OR **KDS screen** (modern): receives fired items.
- **Receipt printer** (customer-facing thermal).
- **Fiscal printer** (jurisdiction-mandated: Italy SDI, Brazil NFC-e, Greek tax, KSA ZATCA).
- **Cash drawer**: opens on cash payment or explicit trigger; attached to receipt printer.
- **Card reader**: Stripe Terminal / Square / Clover / Verifone / Ingenico.
- **Customer-facing display** (kiosks + checkout-line): shows items + total.
- **Manager device**: approves overrides (voids, comps, opens register).

Every device must survive LAN outage. Ticket state is authoritative on the server; devices sync on reconnect.
