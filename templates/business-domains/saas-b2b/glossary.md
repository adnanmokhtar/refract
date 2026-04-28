# SaaS B2B — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `saas-b2b` (multi-tenant B2B SaaS):

**Entity / model names**: `Workspace`, `Organization`, `Tenant`, `Account`, `Team`, `Member`, `Invitation`, `Role`, `Permission`, `Plan`, `Subscription`, `Seat`, `Usage`, `UsageRecord`, `Invoice`, `ApiKey`, `AuditLog`, `Webhook`, `SSO`, `SAMLConfig`, `OIDCConfig`, `Domain`.

**Folder / route names**: `workspaces/`, `orgs/`, `teams/`, `billing/`, `members/`, `invitations/`, `settings/`, `admin/`, `audit-log/`, `/workspace/[slug]`, `/org/:id/members`, `/settings/billing`, `/admin/sso`.

**Dependencies**: `stripe`, `stripe-billing`, `chargebee`, `paddle`, `recurly`, `metronome`, `orb`, `lago`, `workos`, `auth0`, `clerk`, `okta`, `propelauth`, `frontegg`, `boxyhq`, `pingfederate`, `saml2-js`, `@node-saml`, `passport-saml`, `openid-client`, `oauth4webapi`.

**Database schema**: tables for `workspaces`/`organizations` + `workspace_members` + `subscriptions` + `plans` is the strongest signal. Presence of `workspace_id` or `tenant_id` columns on nearly every table near-conclusive.

**Distinguishing variants**:
- **PLG (Product-Led Growth)** — self-service signup, freemium, expansion.
- **Enterprise sales-led** — manual provisioning, contracts, procurement cycles.
- **Mixed / hybrid** — PLG bottom-up + enterprise top-down.
- **Horizontal** — general-purpose (Slack, Notion, Linear).
- **Vertical** — industry-specific (Toast, ServiceTitan, Procore).

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Workspace` / `Organization` | tenant boundary | `id, slug, name, plan_id, billing_email, trial_ends_at, created_at, status (active/trial/delinquent/cancelled), primary_domain` | created → trial → active → cancelled / deleted |
| `Member` / `WorkspaceMember` | user within a workspace | `workspace_id, user_id, role_id, invited_by, joined_at, status (active/invited/suspended/removed)` | invited → active → suspended → removed |
| `User` | auth identity (can be member of N workspaces) | `id, email, email_verified, name, mfa_enabled, sso_subject?, last_login_at` | pending_verification → active → deactivated |
| `Invitation` | pending membership | `id, workspace_id, email, role_id, token, expires_at, sent_by, accepted_at, revoked_at` | pending → accepted / expired / revoked |
| `Role` | permission bundle | `id, workspace_id?, name, is_system, permissions[]` | created (system-defined or custom) |
| `Permission` | atomic capability | `key (e.g. "project.create"), description, category` | static definition |
| `Plan` | billing tier | `id, name, slug, interval (monthly/yearly), base_price, currency, limits{}, features[], is_public` | draft → published → archived |
| `Subscription` | workspace's current plan | `id, workspace_id, plan_id, status, current_period_start, current_period_end, cancel_at, canceled_at, trial_end, quantity (seats)` | trialing → active → past_due → canceled / incomplete |
| `Seat` | billable user slot | `subscription_id, member_id, added_at, removed_at` | filled → vacated (proration on remove) |
| `UsageRecord` | metered-billing event | `id, workspace_id, subscription_id, metric (api_calls/storage_gb/etc), quantity, occurred_at, idempotency_key` | recorded; aggregated at period close |
| `Invoice` | bill issued | `id, workspace_id, subscription_id, number, period_start, period_end, subtotal, tax, total, status, due_at, paid_at, hosted_url` | draft → open → paid / past_due / void / uncollectible |
| `PaymentMethod` | saved payment | `id, workspace_id, type (card/ach/sepa), last4, brand, exp_month, exp_year, is_default, provider_token` | active → expired → removed |
| `ApiKey` | programmatic access | `id, workspace_id, member_id?, prefix, hash, scopes[], last_used_at, expires_at, revoked_at` | active → rotated → revoked |
| `AuditLog` | activity event | `id, workspace_id, actor_id, actor_type (user/apikey/system), action, resource_type, resource_id, before_state?, after_state?, ip, user_agent, created_at` | append-only |
| `Webhook` | outbound HTTP notification | `id, workspace_id, url, events[], secret, active, last_success_at, last_failure_at, disabled_reason` | active → paused → disabled |
| `WebhookDelivery` | individual webhook POST | `id, webhook_id, event_id, attempt, status_code, response_body_snippet, attempted_at, succeeded_at` | pending → delivered / failed / abandoned |
| `SSOConfig` | SAML/OIDC setup | `workspace_id, protocol (saml/oidc), idp_metadata, enforced, jit_provisioning, default_role_id, domain_verified[]` | draft → active → disabled |
| `SCIMConfig` | directory provisioning | `workspace_id, bearer_token_hash, base_url, last_sync_at, user_count, group_count` | active → disabled |
| `Domain` | verified email domain | `workspace_id, domain, verification_method (dns/file), verified_at, enforces_sso` | pending → verified → unverified |

## Status state machines

**Workspace subscription:**
```
trial → active → past_due → active (repaired) → cancelled
          ↓                          ↓
       incomplete (setup intent failed)
          ↓
    trial_ended (no payment method) → cancelled
```

**Invitation:**
```
pending → accepted → member becomes active
   ↓
 expired (TTL, typically 7-14 days)
   ↓
 revoked (by admin)
```

**Member:**
```
invited → active → suspended → active (reactivated)
              ↓         ↓
            removed   removed
```

**Invoice:**
```
draft → open → paid
          ↓
       past_due → collections → uncollectible / paid
          ↓
        void (cancelled before collection)
```

**Plan transition (upgrade/downgrade):**
```
active on plan A → change initiated → proration computed → active on plan B
                                                               ↓
                                                     (downgrade may defer to period end)
```

## Vocabulary distinctions (don't conflate)

- **Workspace** vs **Organization** vs **Tenant** vs **Account** — largely synonymous; pick one term per product and use consistently. "Account" is confusing because users also have accounts.
- **User** vs **Member** — User = global auth identity; Member = user's relationship to a specific workspace. One user can be a member of many workspaces with different roles.
- **Role** vs **Permission** — Role = named bundle (Admin, Member, Viewer); Permission = atomic capability (`project.delete`). Roles contain permissions.
- **Seat** vs **Member** — Member is a user in workspace; Seat is a BILLABLE slot. Guest/viewer members often don't consume seats.
- **Plan** vs **Subscription** — Plan = product offering (Pro $29/mo); Subscription = workspace's active plan instance (Acme Co. on Pro, seat count 12, period 2024-11 to 2024-12).
- **Trial** vs **Freemium** — Trial = time-limited full/partial access; Freemium = permanent free tier with limits.
- **Upgrade** vs **Downgrade** — Upgrade typically prorated immediately; downgrade often deferred to period end (to avoid churn-refund and expansion-loss games).
- **Churn** vs **Cancellation** vs **Expiration** — Churn = lost subscription; Cancellation = user-initiated; Expiration = card failed or trial ended without conversion.
- **MRR** vs **ARR** vs **GMV** — MRR = Monthly Recurring Revenue; ARR = Annual (12× MRR typically); GMV = Gross Merchandise Value (for marketplace-style SaaS).
- **Expansion** vs **Contraction** — added seats/tier = expansion; reduced = contraction. Net Revenue Retention = expansion - contraction - churn.
- **SSO-enforced** vs **SSO-available** — Enforced = password login disabled for workspace; Available = user can choose. Enforcement is the enterprise requirement.
- **JIT provisioning** vs **SCIM** — JIT = create user on first SSO login; SCIM = IdP pushes user lifecycle events (create/update/deactivate).
- **Impersonation** vs **Delegation** — Impersonation = support-acting-as-user (audited); Delegation = user grants another temporary access.

## Multi-tenancy variants

- **Pooled (shared DB, tenant_id column)**: most common; efficient; care with query filters. `WHERE tenant_id = :current` on every query.
- **Siloed (DB-per-tenant)**: strong isolation; enterprise requirement; ops complexity (migration per tenant, cost scaling).
- **Bridge (shared DB, per-tenant schema)**: Postgres schema per tenant; middle ground.
- **Hybrid** — tiered: free/small on pooled, enterprise on siloed.
- **Data residency requirement** — tenant's data in specific region; impacts architecture (per-region pools) or forces siloed.
