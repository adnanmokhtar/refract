# SaaS B2B — core flows

P1 = without these, workspaces don't work. P2 = required to close enterprise deals. P3 = operational scale + differentiators.

## P1 — must-have for v1

### 1. Signup → workspace creation
The activation gate. If this friction is high, PLG dies.

```
Visitor lands (marketing → signup CTA)
  → enter email + password (or OAuth with Google/Microsoft/GitHub)
  → email verification sent
  → user clicks verification link
  → prompted for workspace details (name, optionally slug)
  → workspace created; user becomes owner (role=owner)
  → onboarding wizard (industry, team size, use case)
  → trial starts (if applicable) or free plan assigned
  → redirect to app with empty state + first-action CTA
```

Key invariants:
- Email uniqueness is GLOBAL for users (one user = one email).
- Workspace slug uniqueness is GLOBAL (for URL routing).
- Trial expiry calculated at creation; changes require explicit admin action.
- First user is always owner; ownership transfer requires explicit workflow later.
- Signup from corporate email domain may trigger workspace-matching suggestion ("Join Acme's existing workspace?") — PLG bottom-up expansion.

### 2. Invite teammates
```
Owner/admin opens Members page → "Invite"
  → enters email(s) + role assignment (bulk invite supported)
  → validates email format + domain (optional: reject personal email domains for some plans)
  → creates Invitation with unique token + expiry (7-14 days standard)
  → sends invite email with accept link
  → invitee clicks link → if logged in: auto-accept + redirect to workspace
  → if not logged in: signup or login → accept → redirect to workspace
  → on accept: Member created, Seat consumed (if seat-limited plan), role assigned
  → invitee receives welcome in-app + notification to inviter
```

Key invariants:
- Invitation token is single-use + TTL-bounded.
- Re-invite before expiry = re-send same token (no duplicate invites).
- Accepting to full workspace (seat cap hit) = block with upsell OR allow-queue.
- Already-member accepting = idempotent no-op.
- Email domain matching SSO-enforced domain = force SSO flow (no password).

### 3. Role + permission assignment
```
Admin opens member → edit → change role
  → role changes are permissioned (can't demote yourself; can't assign role higher than your own)
  → audit log entry
  → permission re-evaluation for active sessions (or lazy on next request)
  → optional notification to affected member
```

Key invariants:
- Last owner cannot be demoted (workspace must have >=1 owner).
- Owner transfer is explicit workflow with confirmation.
- Role changes effective immediately OR session-bounded (design choice); document it.
- System-defined roles (Owner, Admin, Member, Viewer) are not editable; customer-defined roles (custom on enterprise plans) are.

### 4. Plan selection + checkout
```
Trial ending OR upgrade desired → pricing page
  → select plan + billing interval + seat count
  → collect payment method (Stripe Elements; never touch PAN)
  → handle 3DS/SCA if required (provider UI; redirect dance)
  → subscription created; first invoice generated + charged
  → plan features unlocked
  → confirmation email
```

Key invariants:
- Price shown BEFORE payment method entered.
- Tax calculated based on billing address (Stripe Tax / Avalara / TaxJar integration).
- Proration on upgrade mid-period.
- Webhook from payment provider is source-of-truth for subscription state, not your API call response.

### 5. Billing cycle + invoice
```
Period end approaches → usage metered (for metered components) finalized
  → invoice generated with line items (base + per-seat + usage)
  → invoice finalized + attempt to collect (card on file)
  → success → status=paid → email receipt
  → failure → status=past_due → retry schedule (smart retries 3-8 days typical)
  → still failing → dunning escalation (emails to billing contact)
  → terminal failure → workspace marked delinquent → feature degradation or full lockout
```

Key invariants:
- Invoice line items are immutable post-finalization (adjustments via credit note).
- Past_due workspace: grace period before feature restriction (typically 7-14 days).
- Pre-dunning notification before card decline (notify 7d before expiry).
- Recovery: succesful retry → status → active; backlog of access preserved.

### 6. Usage metering + overage handling
```
User action that consumes metered resource (API call, storage, seat-month)
  → event recorded with idempotency_key + occurred_at + quantity
  → aggregated per subscription per period
  → at period end: compute overage vs plan allowance
  → overage charged on next invoice OR blocked in real-time (depends on plan rules)
  → soft limits (warnings) at 80%, 100%; hard limits at 120%+ optional per plan
```

Key invariants:
- Idempotent recording: same event replayed must not double-count. `(workspace_id, event_source_id)` unique.
- Clock-skew tolerance: events near period boundary assigned deterministically (use server time, not client time for billing).
- Backfilled events: late-arriving events within period still count; outside period → adjustment to prior period or drop per policy.

### 7. Cancellation + downgrade
```
Owner initiates cancel → retention flow (offer discount, collect reason, pause option)
  → confirm cancel → cancel_at set to period_end (or immediate per policy)
  → workspace continues in active state until cancel_at
  → at cancel_at: status → cancelled → features restricted → data retained per policy
  → data retention window → hard delete OR export offered
```

Key invariants:
- Downgrades often defer to period end (avoid proration complexity + gaming).
- Cancel_at_period_end preferred over immediate (refunds are ugly; let them use what they paid for).
- Reactivation path: within X days → single click reactivate same subscription.
- Data export on cancel: offer at least JSON/CSV of all workspace data; GDPR-required.

## P2 — enterprise-required

### 8. SSO setup (SAML / OIDC)
```
Admin → Settings → SSO → choose protocol
  → upload IdP metadata XML (SAML) or enter issuer/client_id/client_secret (OIDC)
  → domain verification (DNS TXT record)
  → test login (IdP-initiated or SP-initiated)
  → enable JIT provisioning (auto-create users on first SSO login)
  → enforce SSO for domain (optional; disables password login for domain)
  → configure default role for JIT-provisioned users
```

Key invariants:
- Domain verification via DNS TXT + mandatory before enforce.
- Enforcement must preserve at least one break-glass admin login OR emergency recovery flow.
- SAML SP certificate expiry monitored + alerted.
- IdP certificate rotation supported (upload + rollback window).
- Per-workspace SAML endpoint (unique ACS URL); attribute mapping flexible.

### 9. SCIM provisioning
```
IdP (Okta / Azure AD) configured with workspace's SCIM endpoint + bearer token
  → IdP pushes create/update/deactivate events
  → workspace syncs user + group changes
  → group membership → role mapping in app
  → deprovisioning → member status=suspended + active sessions revoked
```

Key invariants:
- Bearer token scoped to workspace + SCIM only (not API access).
- SCIM "delete" is usually "deactivate" (soft); explicit delete separate.
- Group-to-role mapping configured per workspace.
- SCIM + SSO must be consistent; SCIM dictates lifecycle, SSO handles login.

### 10. Audit log
```
Every security-relevant action emits audit event
  → actor (user id / API key / system), action, resource, before/after state
  → stored append-only
  → viewable in-app with filters
  → exportable (CSV / JSON / SIEM integration like Splunk, Datadog, Panther)
  → retention per plan (30d standard, 1y+ enterprise)
```

Actions to log: auth (login, logout, failed login, MFA, SSO), membership (invite, role change, removal), billing, API key create/use/revoke, data mutations (at minimum settings; granular for sensitive data), admin ops.

### 11. MFA + session management
- MFA options: TOTP (authenticator app), WebAuthn (hardware key, platform), SMS (discouraged but often required as fallback).
- Enforced per workspace (setting), per role (admins must MFA), or by risk (unusual location).
- Session management UI: active sessions with device + IP + last-active; revoke all.
- Step-up auth for sensitive operations (delete workspace, rotate API key, billing change).

### 12. API key + webhook management
```
API key creation → scoped to specific workspace + member
  → scope selection (read / write / per-resource)
  → display once at creation (never again)
  → usage tracking (last_used_at, rate)
  → rotation workflow (create new → migrate → revoke old)

Webhook config → URL + events subscribed + HMAC secret
  → test endpoint (send test event, verify 200)
  → active with retries + DLQ
```

## P3 — scale + differentiator

### 13. Data residency
- Per-workspace region selection (US, EU, AU typically).
- Compliance-bound (GDPR, local data laws).
- Migration between regions is nontrivial (plan for it in v1 if enterprise target).

### 14. Custom roles + granular permissions
- Starter RBAC (3-5 system roles) works for most.
- Enterprise demands custom roles with permission cherry-picking.
- Permission matrix UI.

### 15. White-labeling / custom branding
- Custom domain for app (CNAME + cert auto-provisioned).
- Logo + color in email templates.
- Custom login page.
- Enterprise-only feature typically.

### 16. IP allowlisting
- Limit workspace access to IP ranges.
- Per-workspace config.
- Bypass with break-glass for admins.

### 17. CIAM (customer IAM) for the app's end-users
If the app itself has end-users (not just employees), separate user pool + UI. Compliance boundary different.

## Specific concerns

### Tenant isolation
- Every query: `WHERE workspace_id = current_workspace`.
- Cache keys prefixed with workspace_id.
- Background jobs scoped to workspace.
- Log scrubbing of PII + tenant data.
- Test tenant-leak quarterly (pen-test + automated check).

### Subscription edge cases
- Change plans mid-period: proration math (Stripe handles most but verify).
- Pause subscription (some providers): feature access during pause.
- Trial-to-paid without interruption.
- Fail-open vs fail-closed on billing webhook outage.

### Plan changes that affect limits
- Downgrade to plan with 5 members while workspace has 10 = force removal OR soft-block new invites + grandfather existing.
- Document the policy.

## Webhooks the system must emit (to customer)

- `member.invited`, `member.joined`, `member.removed`, `member.role_changed`.
- `workspace.created`, `workspace.deleted`.
- `subscription.created`, `subscription.updated`, `subscription.canceled`.
- `invoice.finalized`, `invoice.paid`, `invoice.payment_failed`.
- `api_key.created`, `api_key.revoked`.
- Domain events per-product.

## Webhooks the system must consume

- Payment provider (Stripe): `customer.subscription.updated`, `invoice.paid`, `invoice.payment_failed`, `charge.dispute.created`.
- IdP (SCIM): user/group lifecycle.
- Email provider: bounce + complaint events (for deliverability).

## Idempotency-critical endpoints

- `POST /workspaces` — duplicate workspace creation on retry.
- `POST /invitations` — duplicate invite = confusing recipient + seat double-consumption.
- `POST /subscriptions` — duplicate subscription = double-charge.
- `POST /usage-events` — duplicate usage = over-charge.
- Payment provider webhook — same event multiple times.
- SCIM endpoints — idempotent per RFC 7644.
