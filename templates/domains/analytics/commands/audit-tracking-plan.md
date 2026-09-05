---
description: Inventory every tracking call-site, match it against the declared tracking plan, and flag drift, PII-in-properties, missing consent-gating, client-sourced identity, missing idempotency, and blocking dispatch — from the real call-sites, never an assumed event set.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-tracking-plan

Diagnose whether the product-analytics instrumentation is typed, consented, PII-safe, server-identified, idempotent, and non-blocking — by inventorying the REAL `track()`/`capture()` call-sites and matching them against the declared tracking plan, not a guess.

## Premise

Real signals only. Cite every emit call-site at `<path:line>` with its exact event name + property keys, the tracking-plan declaration it matches (or "UNDECLARED — drift"), the consent gate it passes through at `<path:line>`, where its identity is sourced (`ctx.session` vs. client payload) at `<path:line>`, its idempotency/dedup key at `<path:line>` (or "MISSING"), and whether dispatch is buffered or `await`-ed. Never narrate an event catalog you didn't extract from source. Read before auditing: locate the tracking plan + the emit facade in source and confirm the vendor SDK boundary BEFORE classifying anything.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the tracking-plan source at `<path:line>` (or "NO PLAN FOUND — every event is ad-hoc drift"), (2) each emit call-site at `<path:line>` with name + property keys, (3) the plan entry it matches or "UNDECLARED", (4) the consent gate at `<path:line>` (or "MISSING — track-before-consent"), (5) the identity source at `<path:line>` (server vs. client), (6) the dedup key for trust-critical events at `<path:line>` (or "MISSING — double-count risk"), and (7) the dispatch shape (buffered vs. `await` on the critical path). If any of these cannot be produced from real source, HALT and say which — never an assumed event set, never an assumed gate.

## What it does

1. **Locate the plan + facade** — find the tracking-plan declaration and the emit facade. Cite `<path:line>`. If there is no typed plan, that is the top finding: every event is ad-hoc.
2. **Inventory every emit call-site** — grep `track(` / `capture(` / `identify(` / vendor SDK calls across the codebase. For each, cite `<path:line>`, the event name (literal or dynamic), and the property keys.
3. **Match against the plan** — each call-site's event + properties must correspond to a declared, typed plan entry. Undeclared name, dynamic/non-literal name, or an open property bag = DRIFT.
4. **Scan properties for PII/secrets** — flag any property key matching the PII denylist (`email`, `phone`, `ssn`, `password`, `token`, `address`, `ip`, raw inputs) on any event sent to a third party.
5. **Check consent-gating coverage** — confirm every emit path reaches the vendor only through the consent gate. A call-site that bypasses the gate (direct vendor SDK call) = track-before-consent BLOCKER.
6. **Check identity source** — confirm `user_id`/`role`/`plan`/`tenant_id` come from the server session, not the event payload. A client-sourced identity = spoofable BLOCKER.
7. **Check idempotency** — for trust-critical events (revenue/conversion/signup/funnel), confirm a stable dedup key. Missing = double-count BLOCKER.
8. **Check blocking dispatch** — flag any `await` directly on a `track()`/`capture()` call (vendor on the critical path).
9. **Check vendor-SDK boundary** — flag raw vendor SDK imports outside the facade module.
10. **Report** — the event inventory vs. plan table, then the BLOCKER/REQUEST findings.

## Flow

```text
locate tracking plan + facade (<path:line>)                  [finding if no typed plan]
  -> inventory every track()/capture()/identify() call-site (<path:line> + name + keys)
  -> match each against the plan                              [DRIFT if undeclared/dynamic/open-bag]
  -> scan properties for PII/secrets                          [BLOCKER if PII off-platform]
  -> assert every emit passes the consent gate               [BLOCKER if track-before-consent]
  -> assert identity from server session, not payload         [BLOCKER if client-sourced]
  -> assert dedup key on trust-critical events                [BLOCKER if missing]
  -> assert non-blocking dispatch (no await on track)          [finding if blocking]
  -> assert vendor SDK only inside the facade                  [finding if leaked]
  -> report: event inventory vs plan + verdicts
```

## Output

```
/audit-tracking-plan — <scope>

Tracking plan:   src/analytics/tracking-plan.ts:12   (5 declared events)   [or: NO PLAN — all ad-hoc]
Emit facade:     src/analytics/analytics.ts:18        [or: vendor SDK called directly — finding]

Event inventory vs plan:
  call-site                                    event              plan?        properties                 verdict
  checkout.service.ts:88   track OrderPlaced    OrderPlaced        declared     orderId,valueMinor,currency OK
  signup.controller.ts:54  track('completed')  'completed'        UNDECLARED   email,fullName,ip           DRIFT + PII
  upgrade.service.ts:31    track Upgraded       Upgraded           declared     userId(from req.body),plan  CLIENT-IDENTITY
  app.tsx:12               analytics.page()     (vendor SDK)       —            —                           PRE-CONSENT

Consent gate:    src/analytics/consent.ts:9   covers facade emits   [or: app.tsx:12 bypasses gate — BLOCKER]
Identity source: ctx.session @ analytics.ts:41 [or: upgrade.service.ts:31 from req.body — BLOCKER]
Idempotency:     OrderPlaced dedupKey @ tracking-plan.ts:30  [or: MISSING on OrderPlaced — BLOCKER double-count]
Dispatch:        buffered sink @ buffered-sink.ts:22  [or: await track @ checkout.ts:88 — finding (blocking)]

Verdict: OK | DRIFT | BLOCKER(consent) | BLOCKER(pii) | BLOCKER(identity) | BLOCKER(double-count)

Top findings:
  - <e.g. signup 'completed' is undeclared AND ships email/ip off-platform; type it + allowlist>
  - <e.g. app.tsx fires analytics.page() before consent; route through the gated facade>
```

## Rules

- READ-ONLY audit. Inventory and classify call-sites; never edit instrumentation, never emit a test event to the vendor.
- Cite-or-halt: real plan, real call-sites, real property keys, real gate, real identity source, real dedup key — or halt naming what's missing.
- An emit path that reaches the vendor without passing the consent gate is a track-before-consent BLOCKER, reported first.
- A PII/secret property key on an event sent off-platform is a BLOCKER — report the key and the destination.
- Identity read from the client payload instead of the server session is a BLOCKER.
- A trust-critical event (revenue/conversion/signup/funnel) with no dedup key is a double-count BLOCKER.
- Never report an event catalog you didn't extract from actual source; a dynamic/non-literal event name is itself a DRIFT finding.

## Cross-references

- `.claude/rules/analytics-tracking-discipline.md` — the hard-rule list this command enforces (typed plan, consent gate, PII allowlist, server identity, idempotency, non-blocking dispatch).
- `ai/patterns/event-tracking.md` — the typed plan + consent gate + allowlist + server identity + dedup key + buffered sink shapes.
- `<agents-path>/analytics-reviewer.md` — review gate that consumes these findings.
