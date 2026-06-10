---
name: admin-action
description: "Pattern: Admin action (granular permission, audited, impersonation-safe, blast-radius-bounded)"
kind: ai-pattern
---

# Pattern: Admin action (granular permission, audited, impersonation-safe, blast-radius-bounded)

> **Hard rule** — An admin / back-office action is staff acting ON customer data. It MUST be authorized by a GRANULAR capability (never a blanket `is_admin` boolean), recorded as a tamper-evident audit event (actor + target + before/after + reason) BEFORE the response returns, and — when impersonating — attributed to the REAL staff identity, not the user. Destructive actions require step-up reauth + typed confirmation; high-blast-radius actions require a hard cap and/or maker-checker; cross-tenant reach is an explicit, audited capability, never a silently dropped predicate.

**When to apply**
- Any staff-facing surface that reads or mutates customer/tenant data: support consoles, moderation queues, super-admin panels, billing/refund tools, account-management screens.
- Any "act-as user" / impersonation feature.
- Any bulk / mass operation run by staff (mass-suspend, mass-email, mass-refund, mass-delete).

**When NOT to apply**
- A customer acting on their OWN data through the normal product surface — that's ordinary authz, not admin (still capability-checked, but no impersonation / cross-tenant / staff-attribution machinery).
- A purely internal read-only metric dashboard with no customer-identifying data and no mutation — lighter-weight; still behind SSO + MFA, but the full audited-action wrapper is overhead.
- An automated system/service actor (jobs, webhooks) — those are attributed to the service principal via their own audited path, not a human staff capability.

**Halt conditions / mandatory cites**
- Cite the GRANULAR capability check at `<path:line>`. An `is_admin` / `role === 'admin'` gate = halt (cross-ref `<rules-path>/auth-discipline.md`).
- Cite the audit-event write at `<path:line>` and confirm it commits BEFORE the response (cross-ref `<rules-path>/audit-log-discipline.md`). A mutation with no audit write, or a fire-and-forget audit, = halt.
- Cite the impersonation attribution at `<path:line>`: the real staff actor stamped on every impersonated request, plus banner + scope + expiry. Impersonation attributed to the user = halt.
- Cite the step-up reauth + typed confirmation for any destructive action at `<path:line>`. A bare destructive endpoint = halt.
- Cite the blast-radius cap and/or maker-checker gate for any bulk action at `<path:line>`.
- Cite the explicit cross-tenant capability + its audit at `<path:line>` wherever the tenant predicate is widened. A silently dropped predicate = halt.
- Grep ban: "the admin action is safe / authorized / audited" without file:line for the capability check, the audit write, and (if applicable) the impersonation attribution and the blast-radius gate.

## Why

Admin code inverts the product's usual safety assumptions. The customer surface is high-traffic, well-tested, and self-scoped — each user touches only their own data. The admin surface is low-traffic, thinly tested, and acts across EVERYONE'S data, often across tenant lines, frequently irreversibly. The recurring failure modes:

1. **The god flag** — one `is_admin` boolean unlocks refunds, deletions, impersonation, and cross-tenant reads alike. There is no least privilege and no separation of duties; a compromised or careless low-trust account has full power.
2. **The silent mutation** — staff change customer data and no record says who, what, before/after, or why. Support disputes, incident reviews, and compliance audits have nothing to go on.
3. **Ghost impersonation** — staff act AS a user with no banner and no attribution; the actions look like the customer performed them, destroying the audit trail exactly where it matters most.
4. **The one-click apocalypse** — a delete-tenant / refund-all button with no friction turns a misclick or a hijacked session into catastrophic, irreversible loss.

The pattern: resolve a granular capability, wrap the mutation so the audit event is written before the response, attribute impersonated actions to the staff actor, add step-up + typed confirmation on destructive actions, and bound bulk actions with a cap and/or maker-checker.

> The TypeScript below uses NestJS-style decorators + a `ctx: AdminContext` for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework, the DI mechanism, the audit-log client, the capability store. The SHAPE — resolve a granular capability → run inside an audited wrapper that records before/after + reason before returning → attribute to the real staff actor → gate destructive/bulk/cross-tenant paths — is what's universal.

## Granular capability check (capability-based, NOT a blanket boolean)

```ts
// src/modules/admin/core/capabilities.ts

/** A capability is a fine-grained verb-on-resource grant, NOT a role label. */
export type Capability =
  | 'users.read'        | 'users.impersonate'
  | 'refunds.issue'     | 'refunds.bulk'
  | 'tenants.read'      | 'tenants.delete'
  | 'tenants.cross_tenant_access'           // the EXPLICIT cross-tenant grant
  | 'data.export'       | 'pii.reveal';

export interface AdminContext {
  staffId: string;                 // the REAL staff actor — always present, even while impersonating
  capabilities: ReadonlySet<Capability>;
  impersonating?: ImpersonationGrant;   // set only inside an act-as session
  lastReauthAt: Date;              // for step-up checks
  requestId: string;
}

export class CapabilityError extends Error {
  constructor(public capability: Capability) {
    super(`missing capability: ${capability}`);
  }
}

/** Authorize a SPECIFIC capability. Never `if (ctx.isAdmin)`. */
export function requireCapability(ctx: AdminContext, cap: Capability): void {
  if (!ctx.capabilities.has(cap)) throw new CapabilityError(cap);
  // ^ least privilege: a refunds agent holds `refunds.issue` but NOT `tenants.delete`.
}
```

A blanket `if (user.is_admin)` is forbidden — see `<rules-path>/auth-discipline.md` for how capabilities are granted, and `<rules-path>/admin-backoffice-discipline.md § Must` for the least-privilege rule.

## Audited action wrapper — record actor + target + before/after + reason BEFORE returning

```ts
// src/modules/admin/core/with-admin-action.ts

export interface AdminActionSpec<T> {
  capability: Capability;
  targetType: string;                       // 'tenant' | 'user' | 'invoice' ...
  targetId: string;
  reason: string;                           // required on consequential actions
  /** Captures the entity state for the before/after diff. */
  snapshot: () => Promise<T>;
  /** The actual mutation. Receives nothing; closes over its inputs. */
  apply: () => Promise<void>;
}

/**
 * The ONE place capability + audit + attribution are enforced.
 * Feature code declares the action; it cannot skip the audit or the gate.
 */
export async function withAdminAction<T>(
  ctx: AdminContext,
  spec: AdminActionSpec<T>,
  audit: AuditLog,
): Promise<void> {
  requireCapability(ctx, spec.capability);                 // (1) granular authz

  if (!spec.reason?.trim()) throw new ReasonRequiredError(spec.capability);

  const before = await spec.snapshot();                    // (2) capture before-state
  await spec.apply();                                      // (3) mutate
  const after = await spec.snapshot();                     // (4) capture after-state

  // (5) Write the tamper-evident audit event BEFORE returning. If this throws,
  //     the action fails loudly — there is NO unrecorded admin mutation.
  await audit.record({
    action: `admin.${spec.capability}`,
    actorId: ctx.staffId,                  // the REAL staff actor, ALWAYS
    onBehalfOf: ctx.impersonating?.userId, // attribution chain, if act-as
    targetType: spec.targetType,
    targetId: spec.targetId,
    before, after,                         // before/after diff
    reason: spec.reason,
    requestId: ctx.requestId,
    at: new Date(),
  });
  // see <rules-path>/audit-log-discipline.md for the tamper-evident write contract.
}
```

If the audit write fails, the action fails. There is no path that mutates customer data without an audit row committed first.

## Impersonation / "act-as" — visible banner, scoped + expiring session, real-actor attribution

```ts
// src/modules/admin/impersonation/impersonation.service.ts

export interface ImpersonationGrant {
  staffId: string;          // who is impersonating
  userId: string;           // who is being impersonated
  scope: ReadonlyArray<Capability>;   // narrowed — NOT the user's full power, not the staff's
  expiresAt: Date;          // time-boxed
  sessionId: string;
}

@Injectable()
export class ImpersonationService {
  constructor(private audit: AuditLog, private sessions: SessionStore) {}

  async start(ctx: AdminContext, userId: string, reason: string): Promise<ImpersonationGrant> {
    requireCapability(ctx, 'users.impersonate');           // explicit capability

    const grant: ImpersonationGrant = {
      staffId: ctx.staffId,
      userId,
      scope: ['users.read'],                               // scope-limited, read-mostly by default
      expiresAt: new Date(Date.now() + 15 * 60_000),       // 15-min expiry
      sessionId: crypto.randomUUID(),
    };
    // A SEPARATE short-lived session — never the user's own cookie.
    await this.sessions.createImpersonationSession(grant);

    await this.audit.record({                              // start is itself audited
      action: 'admin.users.impersonate.start',
      actorId: ctx.staffId, onBehalfOf: userId,
      targetType: 'user', targetId: userId, reason,
      requestId: ctx.requestId, at: new Date(),
    });
    return grant;
  }

  async stop(ctx: AdminContext): Promise<void> {
    if (!ctx.impersonating) return;
    await this.sessions.endImpersonationSession(ctx.impersonating.sessionId);
    await this.audit.record({
      action: 'admin.users.impersonate.stop',
      actorId: ctx.staffId, onBehalfOf: ctx.impersonating.userId,
      targetType: 'user', targetId: ctx.impersonating.userId,
      requestId: ctx.requestId, at: new Date(),
    });
  }
}
```

```tsx
// EVERY page rendered inside an impersonation session shows a persistent, unmissable banner.
function ImpersonationBanner({ grant }: { grant: ImpersonationGrant }) {
  return (
    <div role="alert" className="impersonation-banner">  {/* high-contrast, sticky, always visible */}
      You are acting as <strong>{grant.userId}</strong> (staff: {grant.staffId}).
      Expires {formatRelative(grant.expiresAt)}.
      <button onClick={stopImpersonation}>End session</button>
    </div>
  );
}
```

Every impersonated request carries `ctx.staffId`. Actions taken while impersonating are attributed to the staff member (`actorId: ctx.staffId`, `onBehalfOf: userId`) — never recorded as the user. The banner makes the mode impossible to forget; the expiry + scope bound the damage.

## Step-up reauth + typed confirmation for destructive / irreversible actions

```ts
// src/modules/admin/tenants/delete-tenant.handler.ts

const REAUTH_WINDOW_MS = 5 * 60_000;

@Post('/admin/tenants/:id/delete')
async deleteTenant(
  @Param('id') tenantId: string,
  @Body() body: { confirmSlug: string; reason: string },
  @AdminCtx() ctx: AdminContext,
) {
  requireCapability(ctx, 'tenants.delete');

  // (1) Step-up reauth: a fresh re-authentication within the window. NOT just a live session.
  if (Date.now() - ctx.lastReauthAt.getTime() > REAUTH_WINDOW_MS) {
    throw new StepUpRequiredError('tenants.delete');       // client must re-auth (password / WebAuthn / MFA)
  }

  // (2) Typed confirmation naming the EXACT target — a misclick can't pass this.
  const tenant = await this.tenants.findOrThrow(tenantId);
  if (body.confirmSlug !== tenant.slug) {
    throw new ConfirmationMismatchError(tenant.slug);      // staff must type the slug
  }

  await withAdminAction(ctx, {
    capability: 'tenants.delete',
    targetType: 'tenant', targetId: tenantId, reason: body.reason,
    snapshot: () => this.tenants.snapshot(tenantId),
    apply: () => this.tenants.softDelete(tenantId),        // prefer reversible soft-delete + retention
  }, this.audit);

  return { ok: true };
}
```

Step-up reauth (see `<rules-path>/auth-discipline.md`) defeats a hijacked-but-idle session; the typed target confirmation defeats a misclick. Both are required for irreversible actions.

## Dual-control (maker-checker) for high-blast-radius actions

```ts
// src/modules/admin/refunds/bulk-refund.service.ts

@Injectable()
export class BulkRefundService {
  /** MAKER proposes — does NOT execute. */
  async propose(ctx: AdminContext, filter: RefundFilter, reason: string): Promise<RefundProposal> {
    requireCapability(ctx, 'refunds.bulk');
    const targets = await this.refunds.preview(filter);    // resolve the exact target set

    return this.proposals.create({
      kind: 'bulk-refund',
      proposedBy: ctx.staffId,
      filter, reason,
      blastRadius: targets.length,                         // recorded for the checker to weigh
      status: 'pending',
    });
  }

  /** CHECKER (a DIFFERENT actor) approves + executes. */
  async approveAndExecute(ctx: AdminContext, proposalId: string): Promise<void> {
    requireCapability(ctx, 'refunds.bulk_approve');        // a SEPARATE capability
    const proposal = await this.proposals.findOrThrow(proposalId);

    if (proposal.proposedBy === ctx.staffId) {
      throw new SelfApprovalError(proposalId);             // maker !== checker — separation of duties
    }
    await withAdminAction(ctx, {
      capability: 'refunds.bulk_approve',
      targetType: 'refund-proposal', targetId: proposalId, reason: proposal.reason,
      snapshot: () => this.proposals.snapshot(proposalId),
      apply: () => this.executeWithinCap(proposal),
    }, this.audit);
  }
}
```

One person proposes; a different person with the approval capability confirms. The proposal records the blast radius so the checker decides with the number in front of them.

## Blast-radius cap on bulk / mass actions

```ts
// src/modules/admin/core/blast-radius.ts

const CAPS: Record<string, number> = {
  'bulk-refund': 500,
  'mass-suspend': 1_000,
  'mass-email': 5_000,
};

/** A hard ceiling on how many records a single mass action may touch. */
export function enforceBlastRadius(action: string, count: number): void {
  const cap = CAPS[action] ?? 100;                         // conservative default
  if (count > cap) {
    throw new BlastRadiusExceededError(action, count, cap);
    // ^ over the cap: must be split, or escalated to an explicitly-approved batch job.
  }
}

// Used at the point the target set is resolved, BEFORE any mutation runs:
async function executeWithinCap(proposal: RefundProposal) {
  const targets = await this.refunds.resolve(proposal.filter);
  enforceBlastRadius('bulk-refund', targets.length);       // fail-closed if the filter is too broad
  for (const t of targets) await this.refunds.issue(t);
}
```

A fat-fingered filter that resolves to 40,000 records is rejected, not executed. The cap is the difference between "an over-broad filter" and "a catastrophe."

## Cross-tenant reach — explicit capability + audit, never a dropped predicate

```ts
// src/modules/admin/core/scope.ts

/** The default scope is the TARGETED tenant. Widening is an explicit, audited capability. */
export function adminTenantScope(ctx: AdminContext, targetTenantId: string): { tenantId?: string } {
  if (ctx.requestedCrossTenant) {
    requireCapability(ctx, 'tenants.cross_tenant_access'); // explicit grant — NOT a silent omission
    // the audit event (via withAdminAction) records this as a cross-tenant action.
    return {};                                             // no tenant predicate — but only HERE, on purpose
  }
  return { tenantId: targetTenantId };                     // scoped by default
}
```

Admin is the one place cross-tenant action is legitimate (see `<rules-path>/multi-tenancy.md`) — so it is made explicit, capability-gated, and audited, never the silent default of a missing `WHERE tenant_id`.

## Common mistakes

### `is_admin` god flag
`if (user.is_admin) return doAnything()` collapses every action to one gate — no least privilege, no separation of duties. Check a specific capability per action.

### Unaudited mutation
An admin handler updates a record and returns 200 with no audit row. "Who did this and why?" is unanswerable. Wrap in `withAdminAction`; write the event before returning.

### Fire-and-forget audit
`audit.record(...)` without `await`, or after the response is sent. A dropped event = an unrecorded action. The audit write is on the critical path and is awaited before returning.

### Ghost impersonation
"View as user" on the user's own session, no banner, no expiry, actions attributed to the user. Issue a scoped + expiring session, render a banner, attribute every action to `ctx.staffId`.

### Destructive action with no friction
A delete-tenant button that fires on click. Require step-up reauth + a typed target confirmation.

### Uncapped bulk action
"Suspend all matching" with no cap and no second approver. Add `enforceBlastRadius` + maker-checker.

### Self-approval
The same staff member proposes and approves a high-blast-radius action — maker-checker in name only. Enforce `proposedBy !== approver`.

### Silent cross-tenant
Dropping `WHERE tenant_id` "because admins see all." Make it an explicit `tenants.cross_tenant_access` capability that the audit event records.

### PII firehose
A support list view rendering raw SSN / card / password hash inline. Mask by default; reveal per-field behind `pii.reveal`, audited — same discipline as exports (see `<rules-path>/reporting-export-discipline.md`).

## Cross-references

- `<rules-path>/admin-backoffice-discipline.md` — the hard-rule list (granular capability, audit-before-return, impersonation safety, destructive guards, dual-control / blast-radius, explicit cross-tenant, isolation, MFA, PII).
- `<rules-path>/audit-log-discipline.md` — the tamper-evident audit write every admin action depends on; what to record (actor, target, before/after, reason, impersonation chain).
- `<rules-path>/auth-discipline.md` — capability granting, step-up reauth, MFA, individual accounts, and admin session/origin separation.
- `<rules-path>/multi-tenancy.md` — admin is the one place cross-tenant action is allowed; make it an explicit, audited capability.
- `<rules-path>/reporting-export-discipline.md` — admin data views/exports inherit the PII column allowlist + redaction + access-audit discipline.
- `<commands-path>/audit-admin-surface.md` — enumerate + audit every admin action.
- `<agents-path>/admin-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-admin-capability-model.md` — ADR pinning the capability taxonomy, impersonation policy, dual-control thresholds, and isolation model.
