# Restaurant POS — domain-specific anti-patterns

Generic code review (DRY, SRP) misses these. They're traps you only hit during a Saturday rush, an audit, or a chargeback dispute.

## Order entry + firing

- **Re-fire on double-tap "Send".** Server taps Send, network slow, no feedback, taps again → kitchen sees order twice → cooks twice → food cost + service delay. Idempotency-key per send action; visible "Fired" state immediately on tap with optimistic UI.
- **Modification after fire without kitchen ack.** Server changes "medium" to "well-done" after fire. Steak already at medium. Server didn't know. Guest gets wrong food OR kitchen pulls + redoes silently (waste). Kitchen MUST acknowledge modifications to fired items; auto-ack only for not-yet-cooking items.
- **Course timing ignored.** All items fire at once → appetizer + main + dessert hit kitchen simultaneously → mains plated while guest still on app → cold food. Course entity with `fire_order` enforced at fire time.
- **Special instruction not propagated to kitchen.** "Allergic to peanuts" entered on tablet, not displayed on KDS — kitchen prepares with peanut sauce. Fatal. Special instructions PROMINENT on KDS, not buried in a tooltip.
- **86 list out of sync between POS, KDS, online menu, QR.** Bartender 86s tonic water; QR menu still shows it; online order comes in; bar can't fulfill; refund. Single 86 source of truth; subscribe everywhere.
- **86 not auto-cleared at day open OR not cleared at restock.** Item stays "out of stock" on tomorrow's menu after delivery arrives. Either auto-clear at day-close OR notify chef in morning to review 86 list.
- **Modifier price not added to subtotal.** "Add bacon +$2" displayed as +$2 but subtotal omits the $2. Lost revenue, often invisible until accountant catches it. Recompute subtotal on every modifier change with explicit modifier price aggregation.
- **Special instructions stored as free text only.** Kitchen reads "no nuts" 12 times a night, builds blindness. Allergen flags must be STRUCTURED data triggering kitchen workflow (alert sound, color-coded label), not just text.

## Tickets + tables

- **Table left "seated" after guest leaves.** Server forgot to close ticket. Next host can't seat new party there. Status drift. Auto-prompt server when no payment + no activity in 90 min; automated stale-ticket sweep nightly.
- **Two servers editing same ticket simultaneously.** Both add items, last-write-wins drops one set. Optimistic lock on ticket version; conflict resolution UI.
- **Ticket transferred to wrong server.** Server B sees ticket on screen, doesn't know it's not theirs, takes payment with wrong shift attribution. Confirm on transfer + visible ownership; transfer reason logged.
- **Bar tab pre-auth expires mid-night.** Card pre-authed at 7pm for $50; tab grows to $200 by midnight; pre-auth lapsed at 11pm; close fails; guest already left. Pre-auth top-up at thresholds + warn server.
- **Ticket merged but tip not redistributed.** Late arrival joins; tickets merged; tip math now incorrect (tipped on smaller subtotal originally). Recompute tip on merged subtotal at close.
- **Reopening a closed ticket.** Manager reopens for a forgotten item; payment already settled; reopen-fire-recapture math is brittle. Define reopen flow as a NEW ticket with reference + reverse-payment, not edit-in-place.

## Split bills

- **Even split rounding loses pennies.** $33.34 / 3 = $11.11 per (sums $33.33). One penny disappears. Allocate rounding to first/last split deterministically; never just floor.
- **Split by item leaves orphans.** Item not assigned to any guest = silent loss. Validator: every item must be in exactly one split.
- **Tip on split distorts when one guest doesn't tip.** Guest A tips 20%, B tips 0; tip pool gets B's 0 weighted in. Tip allocated per-split independently to each payment.
- **Pre-tip vs post-tip subtotal confusion.** Card reader prompts tip on $30, receipt shows tip on $33 (with tax). Inconsistent, complaints. Pick one (typically subtotal) + display + apply consistently.
- **Service charge applied per-split AND on parent.** Charge double-applied. Define rule: service charge sums on parent OR splits (not both).

## Payments

- **No idempotency on payment endpoint.** Server taps "Charge" twice on slow network → double-charge → chargeback. Idempotency-Key required per payment attempt.
- **Authorization without capture window monitoring.** Card authed at 8pm, capture at 1am day-close → fine. But if day-close skipped (closing manager forgot), auth expires, card not captured, money lost. Monitor pending auths + alert if approaching expiry.
- **Tip adjustment after capture.** Tip added to receipt at table after card already captured = no path to charge tip. Capture must happen AFTER tip is finalized (auth at swipe, capture at day-close with tip).
- **Refund issued via processor dashboard, not POS.** Manager refunds via Stripe dashboard; POS DB doesn't know; reports are wrong; reconciliation broken. Refund flow ALWAYS through POS UI calling processor.
- **Cash payment + drawer not opened.** Software bug; server pockets cash; no drawer event. Drawer-open should be enforced on cash tender (and explicit "no-cash transaction" flag for digital-only days).
- **Gift card balance fetched once at auth, redeemed without re-check.** Customer uses gift card across multiple checks in parallel; double-spends. Balance lock at redeem, not at view.
- **Failed card capture without retry.** Auth succeeded (customer's card debited / hold); capture failed; we don't retry → hold expires → money lost. Retry capture with backoff + alert on final failure + manual close in book.
- **Currency assumed.** Multi-region chain. Mexican location's POS configured in MXN but report rolls up assuming USD → totals look 20x off. Currency on every monetary field; convert at report time with stored rates.

## Voids + comps

- **Void without manager approval after fire.** Server hides waste by voiding cooked food; kitchen prepared, sat, dumped; never appears in inventory shrinkage report. Manager PIN mandatory on post-fire void.
- **Comp without reason.** "Comp" with no reason in audit → useless for analysis. Required reason from controlled list; free-text optional supplement.
- **Self-approve manager overrides.** Server with manager role taps Void → approves themselves. Block: actor != approver. Two-person rule for high-value comps.
- **Comp totals undercount in P&L.** Reported as "discount" instead of "comp," accountant treats as price adjustment, food cost analysis distorted. Comps tracked separately; aggregated daily.
- **Void of a paid item.** Item paid for, voided in error → ticket goes negative; refund needed but not triggered. Void only allowed pre-payment; post-payment requires refund flow.
- **Bulk void abuse.** Server voids entire ticket "by accident" right after large no-tip table; pockets cash. Manager review + approval per individual void; no bulk void shortcut.

## Receipts + fiscal

- **Reprint without REPRINT mark.** Two "originals" exist. Customer claims double-charge with two receipts (both with same number). In Italy / Brazil / KSA / Greece this is fiscal fraud exposure. Reprint marker mandatory + visible.
- **Fiscal printer offline → quietly drop fiscal record.** Sale completes but no fiscal record transmitted; tax authority sees mismatch on audit. Block sale OR queue with retries + alert; never silently skip fiscal.
- **Z report run before all payments captured.** Pending auth captures roll into next day; Z report doesn't match accounting. Capture all pending before Z; block Z if any uncapturable.
- **Backdated edits after Z.** Manager edits a ticket from yesterday; Z report no longer matches reality. Z is immutable once emitted; corrections via adjustment entry on current day only.
- **Receipt without VAT line in EU jurisdictions.** B2B customer can't reclaim. Required by VAT directive; per-line tax breakdown.
- **Email receipt opting customer into marketing without consent.** Order receipt → marketing list automatically → CAN-SPAM / GDPR violation. Receipt = transactional; marketing requires separate explicit consent.

## Tips

- **Tip on subtotal vs tip on total inconsistent across surfaces.** Card reader screen shows tip on $25 (subtotal), receipt shows tip on $27 (incl. tax). Customer screenshots both, complains. Pick one + apply everywhere — usually subtotal in US, total in EU/UK.
- **Mandatory service charge labeled "tip" on receipt.** IRS treats service charges as wages, not tips. Mislabeling = payroll tax issue + employee complaints (because service charge typically doesn't go to server 100%).
- **Tip pool computation undocumented.** Staff dispute monthly. Pool algorithm + inputs (hours, sales, role weights) visible in employee app + audit log.
- **Cash tip not declared.** Server takes cash tip; doesn't declare; payroll under-reports income. POS prompts cash tip declaration at clock-out; mismatched declarations flag for manager.
- **Tip pool includes BOH where it shouldn't.** US: if tip credit taken, BOH cannot be in pool (FLSA violation). UK: under 2024 Tipping Act, must be fair allocation by written policy.
- **Tip auto-added on small parties.** "Auto-grat 18% on parties of 6+" applied to a 5-top because counter miscount. Always show + allow guest dispute pre-payment.

## KDS + kitchen

- **KDS bump without verification kitchen actually touched it.** Idle screen displays "ready" because random touch event. Use confirm flow on bump (or large bump button + small recall window).
- **Recall window too short.** Mistakenly bumped → 2 sec recall window not enough during rush. 10-15 sec; or "undo" on adjacent KDS for runner to use.
- **Single KDS for all stations.** All stations see all items → cold station looks at hot items, scrolls past, misses cold item. Per-station view; expo only sees all.
- **No alert on stale ticket.** Ticket sits 25 min, no one notices. Color escalation + audio at thresholds.
- **Modification ack ignored.** Kitchen taps "ack" reflexively without reading; server thinks change registered. Ack should require reading the change (e.g., text appears, button delayed 2 sec).
- **KDS screen frozen → no warning.** Network drop → screen displays last state forever; orders pile up unseen. Heartbeat + visual stale indicator if no update in 60 sec.
- **Printer-based kitchen (legacy) without redundant ribbon / paper alert.** Paper out → tickets print blank → kitchen has no orders → service collapse. Monitor paper level + redundant printers per station.

## Reservations + waitlist

- **No-show without grace.** Reservation marked no-show 1 minute late; party walking in the door. 15-min grace standard.
- **No-show without hold fee.** Chronic no-shows; revenue lost. Card hold at booking + capture if no-show after grace.
- **Reservation table held too long.** Reserved table held an hour past arrival time = lost capacity. Auto-release after grace.
- **Waitlist SMS gone wrong.** Wrong number → no notification → guest stands outside; we lose to next restaurant. Confirm phone at intake + send confirmation message they can reply to.
- **Double-book same table.** Reservation system + walk-in host don't share state. Single floor plan source of truth.

## Multi-location + chain

- **Menu prices override at HQ overwrite local change.** Local manager changed price; HQ pushes update; local change reverted. Override hierarchy explicit; conflict warned before apply.
- **Tax rates not updated per location.** Same SKU at two locations in different counties; tax rate drifted; reports wrong. Tax engine per location with override capability.
- **Card processor account confusion.** All locations on same merchant account; chargebacks misallocated; deposits commingled. Per-location MID (Merchant ID).
- **Reports rolled up assuming all locations are same currency / timezone.** International chain → midnight-cut at HQ time vs local time → days don't align. Local-time day boundaries, currency-aware aggregation.

## Online + delivery

- **Online order with item that's 86'd in-store.** Customer pays, kitchen rejects, refund + complaint. Real-time 86 sync; or grace period with refund-on-reject UX.
- **3rd-party platform cancellation not propagated.** Doordash cancels; restaurant cooks anyway; food sits. Webhook handler for cancel events; visible alert on KDS.
- **Online order tip not credited correctly.** Tip in 3rd-party app goes to courier, not server; in-house delivery tip should go to driver — but POS treats it as server tip. Channel-aware tip allocation.
- **Delivery payment reconciliation broken.** 3rd-party platform pays weekly net; POS records full sale; can't tie payouts to orders. Daily settlement file from each platform + matching to POS orders.
- **Channel mix invisible in reports.** Mostly delivery via Uber but reports show "all channels" lumped → manager doesn't notice in-house dying. Per-channel revenue + margin breakdown.

## Inventory + 86

- **Inventory decrement at fire vs at served vs at paid — inconsistent.** Multi-step inconsistency causes inventory to drift. Pick one event (typically "fire") + log it consistently.
- **Voided items still decrement inventory.** Cooked then voided is correct (inventory consumed); voided pre-fire should NOT decrement. State-aware decrement.
- **Comp items not in waste report.** Comp'd food was prepared = inventory used + revenue not collected; should appear in food cost waste analysis. Tag comp items in waste report.
- **86 from inventory threshold incorrect on shared items.** Bun 86 because qty 0 — but 8 burgers in walk-in. Inventory unit (bun) ≠ menu item unit (burger). Recipe-aware availability.

## Labor + clock

- **Clock-out without closing tickets.** Server walks; tickets orphaned; next shift inherits. Block clock-out with open tickets unless manager override (logged).
- **Break not enforced (CA + others).** Shift > 5 hr; no meal break; payroll exposure. Auto-prompt break at 4 hr; auto-clock break at 5 hr if not started.
- **Minor (under-18) scheduled past legal hours.** State law violation. Schedule validator + clock-in block.
- **Shift split with no tip pool reset.** Server clocks out at 4pm, back at 6pm; tip pool needs separate handling per shift segment vs combined day. Define per location + document.
- **Tip declaration mid-shift.** Server declares tips at break, never re-declares at end. Single declaration at clock-out only; no partial.

## Operational

- **Network drop kills service.** No offline mode; kitchen blind; payment dead; restaurant shuts down. Local-first architecture: ticket + KDS + payment runs on LAN even with no internet; sync on reconnect.
- **Auto-update during business hours.** POS reboots mid-rush. Block updates within configured business hours; explicit manager-trigger for updates.
- **Backup not tested.** Hardware fails; restore takes 6 hours; closed for night. Quarterly restore drill.
- **PIN reuse "1234" / "0000".** Manager approval meaningless. Enforce min length + complexity OR biometric.
- **Cash drawer over-short investigation impossible.** No camera correlation, no per-tx audit, drawer count opaque. Per-shift cash count + log + camera time-stamp linkage for investigation.
- **Database row growth unmanaged.** Tickets table at 50M rows; floorplan render slow. Archive closed tickets > 90 days to historical table.
- **Menu image storage in DB.** Megabytes per item; queries slow. CDN + URL reference.
- **Server tablet battery dead mid-shift.** Tablet just plain dies; server cannot work. Battery monitoring + alerts + spare device protocol.

## UX + design

- **Tap targets too small.** Greasy fingers, busy environment, sweat → mistaps. 48px minimum for production paths.
- **Confirmation dialog overuse.** Every action prompts "Are you sure?" → server taps through reflexively → confirmations meaningless. Confirm only on irreversible (close ticket, void post-fire, comp, end of day).
- **Color as only signal.** Red = urgent only — colorblind staff miss it. Add icon + text label too.
- **Alphabetical sort instead of fire-time sort on KDS.** Newest first or oldest first must match cooking order (typically oldest first); alphabetical is meaningless.
- **No undo on destructive action.** Server taps "Cancel ticket" → ticket gone → no recovery. 10-second undo banner.
- **Modal blocks rest of UI.** Manager approval modal blocks everything; server can't see waiting guest. Side panel or sticky banner instead.
