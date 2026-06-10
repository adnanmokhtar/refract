---
name: admin-backoffice-discipline
description: Admin / back-office discipline
kind: rule
---

# Admin / back-office discipline

## Hard rule

An admin / back-office surface is staff acting ON customer data — the highest-blast-radius, lowest-traffic, least-tested code in the product. EVERY admin action MUST be (1) authorized by a GRANULAR capability, never a blanket `is_admin` / `role === 'admin'` boolean; (2) recorded as a tamper-evident audit event (actor + target + before/after + reason) BEFORE the response is returned — see `<rules-path>/audit-log-discipline.md`; (3) attributed to the REAL staff identity even when impersonating a user. Impersonation ("act-as") MUST show a visible banner, be scope-limited, and expire. Destructive / irreversible actions (delete tenant, wipe data, refund-all) MUST require step-up reauth + typed confirmation. High-blast-radius bulk actions MUST have a hard cap AND/OR maker-checker (dual control). Admin is the ONE place cross-tenant action is legitimate — so it MUST be explicit, capability-gated, and audited, NEVER the silent default. The admin surface MUST be isolated (separate auth / session / MFA / network) from the customer app.

An admin bug is not a 500 — it is staff with un-attributable god access silently mutating, exposing, or destroying customer data across tenant lines. Trust dies there.

## Must

- **Capability per action, not a role flag**: every admin action checks a specific capability (`refunds.issue`, `tenants.delete`, `users.impersonate`) resolved from the actor's grants — least-privilege and separation-of-duties. A blanket `is_admin` boolean that unlocks everything is FORBIDDEN. Read-only support staff cannot mutate; a refunds agent cannot delete tenants.
- **Every action is an audited event, written BEFORE the response**: the audit record (actor id, capability, target tenant + entity, before/after diff, reason, request id, impersonation chain) is committed to the tamper-evident audit log (see `<rules-path>/audit-log-discipline.md`) BEFORE the mutation's result is returned. If the audit write fails, the action fails — no silent, unrecorded mutation.
- **Impersonation is loud, scoped, expiring, and attributed**: "act-as a user" renders a persistent banner in the UI, issues a SEPARATE short-lived session scoped to the impersonated user, and stamps EVERY impersonated request with the real staff actor. Actions taken while impersonating are attributed to the staff member, never to the user. Impersonation start/stop are themselves audited.
- **Step-up reauth + typed confirmation for destructive actions**: irreversible / catastrophic actions (delete tenant, purge data, refund-all, disable account) require a fresh re-authentication (password / WebAuthn / MFA within the last few minutes — see `<rules-path>/auth-discipline.md`) AND a typed confirmation that names the exact target ("type the tenant slug to confirm"). A bare button is FORBIDDEN.
- **Dual-control or a cap on high-blast-radius actions**: any action that touches many records at once (mass-delete, mass-email, mass-refund, bulk-suspend) is gated by a hard blast-radius cap AND/OR maker-checker — one staff member proposes, a DIFFERENT staff member with the approval capability confirms. One person cannot unilaterally nuke thousands of records.
- **Cross-tenant action is explicit, capability-gated, and audited**: admin code may legitimately reach across tenants, but it MUST do so through an explicit, separately-authorized capability (`tenants.cross_tenant_access`) that is recorded in the audit event — NEVER by silently omitting the tenant predicate (see `<rules-path>/multi-tenancy.md`). The default scope is still the targeted tenant.
- **Admin surface is isolated**: admin runs on a separate origin / session / cookie from the customer app, behind SSO + mandatory MFA, ideally network-restricted (VPN / allowlist). A customer-side XSS or CSRF MUST NOT reach an admin capability.
- **MFA + individual accounts**: every staff actor authenticates with MFA on a personal, named account. Shared admin logins are FORBIDDEN — they make every action un-attributable.
- **PII exposure is justified, masked, and audited**: admin views of sensitive data follow the same column allowlist + redaction + access-audit discipline as exports (see reporting's PII-in-export rule under `<rules-path>/`). Default to masked; reveal on an explicit, audited, capability-gated action — never bulk-expose raw PII in a list view.
- **Reason capture on consequential actions**: destructive, cross-tenant, and impersonation actions require a reason string, stored in the audit event, so the "why" survives the person.
- **Admin actions go through a wrapper, not raw mutations**: the capability check + audit write + impersonation attribution + reason capture are enforced in ONE `withAdminAction(...)` wrapper, so feature code declares the action — it cannot accidentally skip the audit or the capability gate.

## Must not

- Gate an admin action on `if (user.is_admin)` / `role === 'admin'` — one flag = everything; no least privilege, no separation of duties.
- Mutate customer data in an admin handler without writing an audit event first (or with a fire-and-forget audit that can be lost).
- Impersonate a user with no banner, no expiry, no scope, or by attributing the impersonated actions to the user instead of the staff actor.
- Expose a delete-tenant / wipe / refund-all behind a plain button with no step-up reauth and no typed confirmation.
- Offer a bulk action with no cap and no dual-control — one misclick or one compromised session mass-destroys.
- Drop the tenant predicate "because admins can see everything" — silent cross-tenant reach is a leak waiting to happen; make it an explicit, audited capability.
- Run the admin surface on the same session / cookie / origin as the customer app, or without MFA, or on a shared login.
- `SELECT *` a customer record into an admin list view, exposing raw PII (ssn, full card, password hash, internal cost) with no mask and no access audit.
- Trust a tenant id / target id from the request body to decide scope or authorization — derive authorization from the actor's capabilities and the audited target.

## Should

- Express admin actions as a declarative registry (capability, target type, destructive?, cross-tenant?, dual-control?, blast-radius cap) so the guards are DERIVED, not hand-written per endpoint.
- Render every admin mutation behind a confirmation surface that echoes the resolved target + the diff that will be applied, so staff see exactly what they are about to change.
- Time-box and rate-limit impersonation sessions; auto-end on inactivity; show the impersonated user a "a support agent accessed your account" record where appropriate.
- Default admin list/detail views to MASKED PII with a per-field "reveal" action that is itself capability-gated and audited.
- Emit structured `{ actorId, capability, tenantId, targetId, impersonating, durationMs, blastRadius }` per admin action; alert on cross-tenant actions, mass actions near the cap, and any action with a missing audit write.
- Keep an "admin action replay" / activity feed per tenant and per staff actor, sourced from the audit log, for support and incident review.

## Review checklist (PRs touching admin / back-office / support-console / impersonation / super-admin surfaces)

- [ ] Every admin action checks a GRANULAR capability at `<path:line>` — not `is_admin` / `role === 'admin'`.
- [ ] Every admin mutation writes a tamper-evident audit event (actor + target + before/after + reason) BEFORE returning; cite the write at `<path:line>`.
- [ ] Impersonation has a visible banner, a scoped + expiring session, and attributes every action to the real staff actor; start/stop are audited.
- [ ] Destructive / irreversible actions require step-up reauth + typed target confirmation; cite both at `<path:line>`.
- [ ] High-blast-radius bulk actions have a hard cap AND/OR maker-checker by a different actor; cite the cap / approval gate at `<path:line>`.
- [ ] Cross-tenant reach is via an explicit capability and is recorded in the audit event — not a silently dropped tenant predicate.
- [ ] Admin surface is isolated (separate session/origin, MFA, no shared accounts).
- [ ] PII in admin views is masked by default; reveal is capability-gated + audited; no `SELECT *` into a list.
- [ ] The capability check + audit write + attribution go through the shared admin-action wrapper, not ad-hoc per handler.

## Anti-patterns

- **`is_admin` god flag** — `if (user.is_admin) return doAnything()`. A read-only support intern and a super-admin share one gate. Capability per action; least privilege; separation of duties.
- **Silent mutation** — an admin handler updates / deletes a customer record and returns 200 with no audit row. Six months later "who refunded this and why?" has no answer. Write the audited event BEFORE the response.
- **Ghost impersonation** — staff "view as user" with the user's own session, no banner, no expiry; the refund the agent issued looks like the customer did it. Loud banner, scoped + expiring session, every action attributed to the staff actor.
- **One-click apocalypse** — a "Delete tenant" button that fires on click. A misclick or a hijacked session wipes a customer. Step-up reauth + type-the-slug confirmation.
- **Unbounded bulk** — "Suspend all matching users" with no cap and no second approver suspends 40,000 accounts from one fat-fingered filter. Cap the blast radius; require maker-checker.
- **Silent cross-tenant** — an admin query drops `WHERE tenant_id = ?` "because admins see all," and a list leaks across tenants with no record it happened. Explicit cross-tenant capability + audit.
- **Shared admin login** — everyone uses `admin@company.com`; the audit log says "admin did it" for every action. Named accounts + MFA, so every action attributes to a person.
- **Admin on the customer session** — the back office shares the customer app's cookie and origin; a stored XSS in the customer app calls an admin endpoint. Isolate session, origin, MFA, network.
- **PII firehose** — the support console lists customers with full SSN, card number, and password hash inline. Mask by default; reveal per-field, capability-gated + audited.
- **Trust-the-body authorization** — `if (req.body.allowCrossTenant) skipScope()`. Authorization comes from the actor's capabilities, never a request flag.

## Enforcement

- `<commands-path>/audit-admin-surface.md` (slash: `/audit-admin-surface`) — enumerates every admin endpoint/action at `<path:line>` and checks authorization granularity, audit coverage, impersonation safety, destructive-action guards, cross-tenant reach, mass-action blast-radius, and PII exposure — cite-or-halt, never an assumed map.
- `<agents-path>/admin-reviewer.md` — review gate hard-failing on `is_admin` gates, unaudited admin mutations, unsafe impersonation, unguarded destructive actions, uncapped bulk actions, silent cross-tenant reach, shared/MFA-less admin access, and unmasked PII firehoses.
- CI lint MUST reject `is_admin` / `role === 'admin'` used as an authorization gate in admin handlers (heuristic; require a capability check instead).
- CI lint MUST reject an admin mutation handler that does not call the `withAdminAction` wrapper / audit write (AST heuristic; flag for review).
- CI lint MUST reject admin queries that omit a tenant predicate without an explicit cross-tenant capability annotation.
- TODO: `scripts/validate-admin-actions.sh` to AST-walk admin handlers and assert each one resolves a capability, writes an audit event before returning, attributes impersonated actions to the staff actor, and declares its destructive / cross-tenant / blast-radius flags.

## Cross-references

- `<patterns-path>/admin-action.md` — capability check + audited action wrapper + impersonation attribution + step-up/typed-confirm + dual-control + blast-radius cap code shapes.
- `<rules-path>/audit-log-discipline.md` — every admin action is a tamper-evident, audited event; what to record (actor, target, before/after, reason, impersonation chain).
- `<rules-path>/auth-discipline.md` — capability/authZ granularity, step-up reauth, MFA, individual accounts, and admin session/origin separation.
- `<rules-path>/multi-tenancy.md` — admin is the one place cross-tenant action is allowed; make it an explicit, audited capability rather than a dropped predicate.
- `<rules-path>/reporting-export-discipline.md` — admin data views/exports inherit the PII column allowlist + redaction + access-audit discipline.
- `<commands-path>/audit-admin-surface.md` — admin-surface diagnostic.
- `<agents-path>/admin-reviewer.md` — review gate.
- `<adr-path>/<NNN>-admin-capability-model.md` — ADR pinning the capability taxonomy, impersonation policy, dual-control thresholds, and admin isolation model.
