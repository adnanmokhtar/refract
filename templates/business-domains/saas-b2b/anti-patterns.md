# SaaS B2B — domain-specific anti-patterns

Generic code review misses multi-tenant SaaS specific traps. These are deal-killers, trust-destroyers, or scaling cliffs.

## Tenant isolation

- **Query without `WHERE workspace_id = :current`.** Returns cross-tenant data. Write a linter/test that scans every query for tenant predicate. Automated tenant-leak regression suite mandatory.
- **Cache key without workspace prefix.** `user:123` used by Acme workspace; Beta workspace hits cache; gets Acme's data. Prefix all cache keys with workspace_id.
- **Background job picking workspace from session.** Job executes without session context; defaults to some workspace. Pass workspace_id explicitly through job args.
- **Tenant id mutation allowed.** Updating a record and allowing workspace_id to change = data teleport. Make workspace_id immutable after create.
- **Global search that misses tenant filter.** "Search across all records" pulling from tables without filter = total tenant leak. Audit search paths.
- **Shared Redis without isolation.** Pub/sub channel name doesn't include workspace; events leak. Namespace channels.
- **Shared rate limit counter.** One workspace's heavy usage rate-limits another's. Per-workspace counter.
- **Database connection pool shared + connection session-state leaked (Postgres `SET` used).** Abandon SET-based tenant context for row-level security.
- **"Admin" endpoint that reads any workspace.** Support tool; abused by compromised employee. Audited + break-glass + scoped.
- **Log aggregation without tenant filter on search.** Support engineer helping Acme searches logs, sees Beta's data. Scope log tool access per-customer.

## Invitations

- **Invite link with no expiry.** Email forwarded year later; unauthorized join. TTL 7-14 days.
- **Invite link reusable multiple accepts.** 10 people join on shared link; seat inflation; support chaos. Single-use token OR explicit multi-use link with role restriction.
- **Invite token as guessable integer.** Enumerable; invites guessable. UUIDv4 or random.
- **Invite accept without auth.** Anonymous user hits accept URL; claims membership. Require auth first then match email.
- **Invite email sent without checking target email ownership.** Someone invites `ceo@competitor.com` for access to competitor intel — if competitor has SSO on domain, maybe no issue; else accountable. Verify invitee is not in a collision scenario.
- **Invite resend creates new token; old token still valid.** Two tokens open. Revoke old on resend.
- **Revoked invite's token still works (race).** Cache / session. Check revoked_at on every accept.

## SSO / auth

- **SSO enforced; password reset bypasses.** Reset email sent; user sets password; logs in via password; enforcement bypassed. Reset must route to IdP.
- **SSO enforced; no break-glass.** IdP down 4 hours; no admin access; operations crisis. Break-glass account with strong MFA + rotation + audit.
- **SSO certificate expiry unmonitored.** Cert expires; customer logins fail at midnight; P1 ticket. Monitor + alert 30/7/1 days before.
- **SAML ACS URL reused across customers.** Same endpoint for all; attribute mapping confusion. Per-workspace unique URL.
- **SCIM token with broad scope.** Compromised token accesses app data. SCIM-only scope.
- **SCIM "delete" = DELETE endpoint mapped to hard-delete.** SCIM semantics = deactivate typically. Soft-delete; verify policy.
- **MFA enforcement per workspace; admin can disable for self.** Admin disables; SOC 2 finding. Policy level > individual preference.
- **Session tokens long-lived + no rotation.** Stolen token valid indefinitely. Rotate on sensitive op; short TTL.
- **Passwords in database NOT hashed with slow hash.** bcrypt/argon2/scrypt required; never MD5/SHA1. Use library.
- **JWT secret hardcoded or shared across envs.** Dev leak → prod compromise. Per-env secrets in vault.
- **JWT without expiry or refresh.** Forever-valid tokens; revocation impossible. Short-lived + refresh.

## Permissions / RBAC

- **Permission check client-side only.** Hide UI but API open. Server enforces; client hides.
- **Role check in controller; resource check missing.** User with role=admin in WS1 deletes WS2's resource. Check resource ownership + role.
- **Permissions cached indefinitely.** Role changed; cache not invalidated; stale authz. Invalidate on change.
- **Last-owner demotion allowed.** Workspace orphaned. Block demotion of last owner.
- **Ownership transfer without multi-step confirmation.** Accidental transfer; hard to reverse. Require acceptance from new owner.
- **Custom roles without audit trail.** Who created this dangerous role? No idea. Audit role CRUD.

## Billing

- **Webhook not idempotent.** Stripe retries → 2 subscription records. Event-id dedup.
- **Webhook throws; provider retries; escalates.** Catch + log + ack; reprocess from queue.
- **Subscription state trusted from API call return, not webhook.** Customer's card failed; API returned success; webhook tells real story. Webhook-as-truth.
- **Prorated upgrade charges twice.** Customer upgrades; old sub canceled + charged; new sub created + charged; forgot to credit. Test proration edge cases.
- **Downgrade with unlimited refund.** Churn-then-rejoin gaming. Downgrades defer to period end.
- **Tax computed wrong for customer region.** Compliance + back-tax. Stripe Tax / Avalara / TaxJar integration.
- **Invoice line items mutable after finalization.** Auditor's nightmare. Immutable post-finalize; adjustments via credit notes.
- **Seat counter drifts from member table.** Manual adjustment breaks sync. Event-sourced OR reconciliation job.
- **Trial end without notification.** Customer's card charged out of the blue; chargeback. 7-day + 1-day notice.
- **Dunning sends to owner email only.** Owner vacation; card fails; feature lockout. Billing email contact separate.
- **Payment method removed without replacement.** Delinquent on next bill. Policy: can't remove without replacement unless cancelling.
- **Currency mismatch in upgrade.** USD → EUR plan; exchange rate confused. Normalize.
- **Refund processed outside system.** Accounting drift; reporting wrong. Single refund pathway.

## Usage metering

- **Usage event without idempotency key.** Client retry → double-charge. Require idempotency_key per event.
- **Clock skew between client + server.** Events assigned to wrong period; boundary cases. Use server timestamp for billing period assignment.
- **Late-arriving events assigned to current period.** Prior period closed; event in wrong bucket. Explicit policy: drop, current-period, or prior-period adjustment.
- **Usage aggregation in-memory only.** Server restart loses counts. Persistent + idempotent.
- **Soft limit fires but hard limit doesn't.** User over-uses; bill explodes. Both configured OR clear policy.
- **Unit conversion errors (MB vs GB).** Charged $X for expected $0.01X. Unit tests on math.
- **Throttling applies to allowed usage.** Plan allows 10k calls; customer hitting 9k gets 429s. Throttle only beyond plan.

## API / webhooks

- **API key shown multiple times.** Support reviews + leaked. Show once; hash stored; never retrievable again.
- **API key without prefix.** Can't identify + rotate efficiently. `sk_live_abc...` style.
- **API key full access by default.** Compromised key = full damage. Default-deny + explicit scope selection.
- **Webhook signature using MD5.** Forgeable. HMAC-SHA256 minimum.
- **Webhook without timestamp.** Replay attack. Timestamp + signature + max-age.
- **Webhook without retries.** Customer endpoint flaky; events lost. Exponential backoff + DLQ.
- **Webhook retry storm when customer's endpoint returns 500 for auth reasons.** Auth error needs different handling than transient 500. Retry policy per status code.
- **API rate limit per user but not per workspace.** 1000 users = 1M requests. Per-workspace + per-user.
- **API versioning via header only.** Breaking changes surprise. `/v1/` + `/v2/` path + deprecation headers.

## Audit log

- **Audit log in application DB.** Writer can tamper. Append-only table OR separate log store with write-only credentials.
- **Audit log without IP + UA.** Forensics impossible. Capture both.
- **Audit log without actor.** "Role changed" but who? Actor + actor_type (user/apikey/system).
- **Audit log without before/after state on mutations.** "Updated permissions" — to what? Capture deltas.
- **Audit log lost events under load.** Fire-and-forget; failures silent. Persistent queue OR synchronous write.
- **Audit log retention = operational log retention.** Compliance requires longer. Separate retention policy.
- **Audit log exported without encryption.** SIEM ingestion in clear over internet. TLS + encryption at rest.
- **Impersonation NOT audited.** Support impersonated customer; saw PII; no record. Impersonation = high-signal audit event.

## Multi-workspace users

- **User signs out of one workspace logs out all.** Confusing UX. Scope sessions per workspace OR clear model.
- **Workspace switcher caches permissions for old workspace.** Actions fail with cryptic errors. Invalidate on switch.
- **Notification sent to wrong workspace context.** User in WS1 gets WS2's event. Event routing bugs.

## Data lifecycle

- **Soft-delete leaving data visible in joins.** Archived workspaces returning members in global lookups. Soft-delete filter on every query.
- **Workspace deletion hard-deletes immediately.** Accidental; no recovery; lawsuit. 30-90 day grace.
- **Grace-period deletion scheduler lost.** Workspace deleted forever without "recover" email ever sent. Scheduled job + monitor.
- **Data export on deletion incomplete.** Customer can't take their data. Full export (JSON + tabular) mandatory.
- **Backup retention > deletion policy.** Deleted data recoverable from backup indefinitely. Policy alignment + backup sanitization (crypto-shredding by rotating keys).

## Enterprise features

- **Data residency: "EU" but CDN caches globally.** PII in US edge. Verify full data path.
- **IP allowlist: add-only UI (no remove).** Mistakes create lockout. Proper CRUD with test-connection.
- **Custom domain: cert auto-renewal fails silently.** Customer's domain expires; TLS errors. Monitor + alert.
- **White-label: one customer's branding leaking to another via missed cache key.** Tenant isolation applies to brand too.
- **Custom role UX unclear.** Admin creates role; doesn't understand scope; grants too much. Preview + warnings.

## Performance at scale

- **N+1 queries on member list.** Load member → load user → load role → load permissions × N members. Eager load.
- **Missing index on `(workspace_id, created_at DESC)`.** List queries 30s at scale.
- **Full-table scan on audit log.** Partition by workspace_id + time.
- **Cache without TTL.** Stale data forever.
- **Cache thundering herd on eviction.** Lock + single compute; singleflight pattern.
- **Background job priority single queue.** Noisy tenant starves others. Per-tenant queues OR fair scheduling.

## Support / operations

- **Support impersonation writes allowed.** Accidental data mutation. Read-only by default; write requires step-up + justification.
- **Support ticket with customer data pasted.** PII in ticketing system. Redact.
- **Internal admin tool without MFA.** Employee compromised = prod catastrophe. Mandatory MFA + hardware key.
- **No "customer is at risk" visibility for CS.** Churn surprise. Health score + usage trend dashboards.
- **Feature flag rollout by workspace-id hash; heavy customer hits edge buggy feature.** Canary by usage segment, not random.

## Legal / compliance

- **DPA template absent.** Enterprise deal stalls 2 months.
- **Sub-processor list stale.** Customer discovers; trust damaged.
- **TOS changes without notification.** Customers hit with changed terms; dispute.
- **Auto-renewal without notice per state law.** Some states require 15-45 day notice.
- **Data export self-service absent.** Every GDPR request = engineering ticket.
- **BAA claimed but workflows don't protect PHI accordingly.** Healthcare customer audit fails.

## Onboarding

- **New workspace ships with no templates/examples.** Empty state = abandon. Sample content.
- **Onboarding wizard non-skippable.** Power users frustrated; skip option available.
- **Onboarding checklist never completes.** Items marked done but not cleared. State tracked.
- **Invite flow during onboarding fails silently.** User sends invites; recipients never get email. Confirmation + retry.
