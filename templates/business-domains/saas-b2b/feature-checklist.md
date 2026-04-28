# SaaS B2B — feature checklist

The 80%-of-projects-need-this list. B2B SaaS v1s frequently ship missing enterprise-blockers; then sales cycles stall 9 months waiting for retrofit.

## Signup + onboarding

- [ ] Email + password signup.
- [ ] OAuth (Google, Microsoft at minimum; GitHub for dev tools).
- [ ] Email verification before workspace access.
- [ ] Workspace creation wizard (name, slug, optional branding).
- [ ] Slug collision handling (suggest alternatives).
- [ ] Onboarding questionnaire (industry, size, use case — for segmentation).
- [ ] Sample data / template workspace option.
- [ ] Empty-state guidance (first-action CTAs).
- [ ] Invite teammates as onboarding step.
- [ ] Domain match suggestion ("Is your team already on X workspace?").
- [ ] Welcome email with getting-started resources.
- [ ] Onboarding checklist visible until complete.

## Workspace / organization

- [ ] Multi-workspace per user support (workspace switcher).
- [ ] Workspace settings (name, slug, logo, timezone).
- [ ] Custom subdomain option (vanity URL).
- [ ] Primary owner designation.
- [ ] Ownership transfer workflow.
- [ ] Workspace deletion with confirmation + grace period.
- [ ] Data export on deletion.

## Members + roles

- [ ] Invite via email (single + bulk).
- [ ] Invite via shareable link (optional; usually with role restriction).
- [ ] Pending invitation list with re-send + revoke.
- [ ] System roles (Owner, Admin, Member, Viewer minimum).
- [ ] Custom roles (enterprise plans).
- [ ] Role-based permission enforcement on every endpoint.
- [ ] Member search + filter.
- [ ] Member profile edit (admin).
- [ ] Member removal with session revocation.
- [ ] Self-removal (leave workspace).
- [ ] Transfer ownership before leaving if last owner.
- [ ] Suspend member (retains data, no access).
- [ ] Guest / external collaborator role.
- [ ] Seat counter + plan limit enforcement.

## Authentication

- [ ] Password login with complexity policy.
- [ ] Password reset via email token.
- [ ] MFA — TOTP (authenticator app).
- [ ] MFA — WebAuthn (hardware keys + passkeys).
- [ ] MFA — SMS (as fallback, discouraged).
- [ ] MFA enforcement per-workspace.
- [ ] MFA enforcement per-role (admins must MFA).
- [ ] Recovery codes.
- [ ] Session management (active sessions view).
- [ ] Revoke session / revoke all sessions.
- [ ] Device trust (remember device).
- [ ] Suspicious login alerts (new device, location).
- [ ] Account lockout after N failed attempts.

## SSO (enterprise)

- [ ] SAML 2.0 support.
- [ ] OIDC support.
- [ ] Per-workspace SSO config.
- [ ] IdP metadata upload.
- [ ] Domain verification (DNS TXT).
- [ ] SP-initiated + IdP-initiated login.
- [ ] JIT user provisioning.
- [ ] Default role for JIT-provisioned users.
- [ ] Group-to-role mapping.
- [ ] Attribute mapping (first_name, last_name, email).
- [ ] SSO enforcement per domain.
- [ ] Break-glass admin for SSO outage.
- [ ] SAML certificate rotation support.
- [ ] SCIM provisioning (SCIM 2.0).
- [ ] SCIM bearer token rotation.
- [ ] SCIM group membership sync.

## Billing + subscription

- [ ] Pricing page with plan comparison.
- [ ] Plan selection in-app (upgrade/downgrade).
- [ ] Payment method entry (Stripe Elements or equivalent; never touch PAN).
- [ ] Card management (replace, set default, remove).
- [ ] ACH / bank debit (enterprise).
- [ ] Invoice history download (PDF).
- [ ] Billing email separate from admin email.
- [ ] Billing address + tax ID.
- [ ] Tax calculation (Stripe Tax / Avalara / TaxJar).
- [ ] Proration on upgrades.
- [ ] Deferred downgrades (at period end).
- [ ] Trial signup without payment method.
- [ ] Trial conversion (add PM during trial, auto-convert at end).
- [ ] Subscription pause (if offered).
- [ ] Cancel with retention flow (discount, reason capture).
- [ ] Reactivation workflow.
- [ ] Dunning workflow (smart retries + email sequence).
- [ ] Delinquency handling (feature degradation, not surprise lockout).

## Usage + metering

- [ ] Real-time usage dashboard (per-metric, per-period).
- [ ] Usage limits per plan.
- [ ] Soft-limit warnings (80%, 100%).
- [ ] Hard-limit enforcement (depends on plan).
- [ ] Overage billing on next invoice (if applicable).
- [ ] Historical usage charts.
- [ ] Per-metric detail drill-down.
- [ ] Usage export (CSV).
- [ ] Budget alerts (custom thresholds).

## API + integrations

- [ ] API key management (create, revoke, rotate).
- [ ] API key scoping (read / write / resource-specific).
- [ ] API key usage logs.
- [ ] Rate limiting per key + per workspace.
- [ ] API documentation (OpenAPI / Swagger generated).
- [ ] Webhook config (URL, events, secret).
- [ ] Webhook test + replay tool.
- [ ] Webhook delivery logs with retry.
- [ ] OAuth apps (for 3rd-party integrations).
- [ ] Zapier / native integrations list.
- [ ] SDKs (at minimum JS, Python, often Ruby/Go/Java/C#).

## Audit + compliance

- [ ] Audit log viewer with filters (actor, action, date).
- [ ] Audit log export (CSV, JSON).
- [ ] Audit log streaming to SIEM (Splunk, Datadog, Panther).
- [ ] Audit log retention per plan.
- [ ] Data export (GDPR-compliant).
- [ ] Account deletion + data retention policy.
- [ ] Data processing agreement (DPA) template.
- [ ] Sub-processor list public.
- [ ] Privacy policy per jurisdiction.
- [ ] Terms of service acceptance tracking + version history.
- [ ] Cookie consent for marketing site.

## Enterprise controls

- [ ] IP allowlisting per workspace.
- [ ] Session timeout config.
- [ ] Password policy config.
- [ ] Data region selection (US, EU, others).
- [ ] Custom domain with auto-provisioned TLS.
- [ ] Email branding (from, reply-to, logo).
- [ ] Workspace-level data retention.
- [ ] Admin impersonation (support) with audit.
- [ ] Legal hold (data preservation).
- [ ] BAA support (if handling health data).

## Admin + internal

- [ ] Internal admin tool for support (impersonate, view-only).
- [ ] Impersonation always audited.
- [ ] Feature flags per workspace.
- [ ] Manual plan overrides.
- [ ] Credit + discount application.
- [ ] Refund / credit note.
- [ ] Workspace status badge (healthy, past_due, trial, etc.).
- [ ] MRR / ARR / churn dashboards.
- [ ] Cohort analysis (activation, retention, expansion).

## Notifications

- [ ] In-app notification center.
- [ ] Email notification preferences per user.
- [ ] Workspace-level notification policy (when to email vs in-app).
- [ ] Daily / weekly digests option.
- [ ] Mobile push (if native apps).
- [ ] Slack / Teams integration for workspace-wide events.
- [ ] Transactional vs product-update vs marketing separation.

## Localization

- [ ] UI language selector (at least en + 2-3 per market).
- [ ] Per-user language preference.
- [ ] Per-workspace default language.
- [ ] Currency display based on billing region.
- [ ] Date/number formats per locale.
- [ ] RTL support (if Arabic/Hebrew markets).

## Things v1s commonly miss

- **Tenant isolation leaks via cache.** Shared Redis; cache key `user:123` not `ws:abc:user:123`; cross-workspace data bleed. Prefix all keys with workspace_id.
- **Invite link without expiry.** Forwarded email year later → unauthorized access. 7-14 day TTL mandatory.
- **Invite link reusable.** Same link used by 10 people → 10 accounts joining. Single-use token.
- **SSO enforcement without break-glass.** IdP down = whole workspace locked out. Break-glass admin credentials or recovery flow.
- **Password fallback when SSO enforced.** Enforcement bypassed via password reset. Reset must use IdP's flow.
- **MFA bypass on recovery codes without rate limit.** Brute-force codes. Rate limit + lockout.
- **Downgrade doesn't handle over-limit.** Plan allows 5 members; downgraded; 10 members remain active. Policy: force removal OR grandfather + block new.
- **Cancellation doesn't revoke sessions.** User cancelled; still logged in with features. Revoke on cancel_at.
- **Member removal doesn't revoke sessions.** Removed member still authenticated. Immediate revocation required.
- **Audit log without IP + user-agent.** Incident forensics impossible. Both fields mandatory.
- **Audit log without before/after.** "Role changed" but not what. Capture both states for mutations.
- **API key shown repeatedly.** Compromised by support-tool access. Show once at creation; hash stored; prefix visible for identification.
- **API key without expiry option.** Ex-employee's key lives forever. Optional expiry.
- **API key without scopes.** Full-access key for read-only integration. Scoped keys.
- **Webhook without HMAC.** Recipients can't verify source. HMAC + replay protection (timestamp + nonce).
- **Webhook without retry + DLQ.** Transient failures lose events. Exponential backoff + DLQ + alert.
- **SCIM-provisioned user locked at deletion but retains data access.** SCIM dictates membership lifecycle. Integrate fully.
- **SCIM group → role mapping desynced from app.** Customer changes in Okta not reflected. Real-time or frequent sync.
- **Proration on downgrade refunded immediately.** Churn-then-rejoin gaming. Downgrades deferred to period end.
- **Billing email = owner email only.** Owner leaves; billing goes dark. Separate billing contact.
- **Subscription cancelled but card charged next cycle.** Webhook not processed. Webhook-as-truth + reconciliation.
- **Invoice PDF unavailable for failed payments.** Accounting team needs them. Generate PDFs for all statuses.
- **Deleted workspace data recoverable indefinitely.** GDPR + storage cost. 30-90 day grace then true delete.
- **API rate limiting per-user only.** One rogue script hits API; doesn't degrade per-workspace experience. Per-workspace limits.
- **No concept of service account / bot user.** Integration tied to individual employee; employee leaves; integration breaks. Bot users.

## Things often over-built in v1 (defer until validated)

- Custom-role builder (system roles cover 90% of needs).
- Fully configurable permission matrix UI (huge scope; use system RBAC).
- SAML + OIDC + LDAP + Kerberos (pick 1-2; most enterprises use Okta/Azure AD SAML or OIDC).
- White-label with per-tenant theming engine (static variants suffice initially).
- Data residency with real multi-region replication (start US or single region).
- Multi-currency billing (start USD; expand).
- Custom reporting builder (export to CSV; let BI tools do it).
- Marketplace for 3rd-party integrations (partner with Zapier first).
- Per-workspace feature flags UI (internal tool first).
- Complex multi-tenant hierarchies (parent/child orgs, divisions) — enterprise-only; defer.
