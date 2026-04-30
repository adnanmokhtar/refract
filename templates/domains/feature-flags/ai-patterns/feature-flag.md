---
name: feature-flag
description: Pattern: Feature flags (lifecycle + SDK + cleanup)
kind: ai-pattern
---

# Pattern: Feature flags (lifecycle + SDK + cleanup)

> **Hard rule** — Every flag has owner + sunset date + a default that is the SAFE behaviour when the SDK fails; eval is wrapped in try/catch returning the default; flags are NEVER used for authorization, compliance, or tenant isolation.

**When to apply**
- Gradual rollout, A/B experiment, kill-switch, regional behaviour toggle, tenant-scoped beta.
- Decoupling deploy from release for a risky migration.
- Operational rollback toggle for a new code path running in parallel with legacy.

**When NOT to apply**
- Authorization or permission gates — use roles/policies; SDK failure must not unlock or lock data.
- Compliance/regulatory gating (EU vs non-EU, age gates) — use region/account config, not a remote toggle.
- Per-tenant plan config — that's data, not a flag; live in the DB with a typed plan model.

**Halt conditions / mandatory cites**
- Cite the `FlagService` interface + adapter at `<path:line>`. Direct vendor SDK calls in feature code = halt.
- Cite the try/catch + default return at `<path:line>`. Unhandled SDK throw = halt.
- Cite the flag owner + sunset metadata (dashboard or `flags.yaml`) at `<path:line>`. No sunset = halt.
- Cite the cleanup PR pattern (dead branch removal) at `<path:line>` for any flag at 100% > 7 days. Drift between code flags and dashboard = halt.
- Grep ban: "the flag protects this" without a file:line showing eval site + default + owner.

## Why

Flags decouple deploy from release. A flag is the right tool for: gradual rollout, A/B experiment, kill-switch, tenant-scoped beta, regional behavior toggle.

A flag is the WRONG tool for: authorization, compliance gating, tenant isolation, security controls. Each of those degrades dangerously when the SDK fails.

## SDK choice

| Use | Pick |
|---|---|
| Multi-tenant SaaS, percentage rollout, A/B experiments | LaunchDarkly (server SDK with local cache) |
| Open-source self-host, simple boolean rollout | Unleash |
| Vendor-neutral, swap providers later | OpenFeature (spec) + provider adapter |
| Static-site-friendly, edge eval | GrowthBook (CDN-cached config) |
| Tiny scope (<10 flags), no $ for vendor | `flags.yaml` in repo + reload-on-write |
| Per-tenant config tied to plan (not "rollout") | DB `feature_flags` table — this is config, not flags |

Pick ONE and stick to it. Mixing SDKs = double bills + double drift.

## Flag service contract

Wrap the chosen SDK behind a single interface — vendor lock-in becomes a 1-file refactor.

```ts
// src/modules/flags/core/interfaces/flag-service.interface.ts
export interface FlagService {
  isOn(key: string, opts: { context?: FlagContext; default: boolean }): boolean;
  variant<T extends string>(key: string, opts: { context?: FlagContext; default: T }): T;
  exposed(key: string, variant: string, context: FlagContext): void;   // analytics event
}

export type FlagContext = {
  tenantId?: string;
  userId?: string;
  email?: string;     // only if needed for targeting; never log
  attributes?: Record<string, string | number | boolean>;
};
```

Adapter implementation (LaunchDarkly):

```ts
// src/modules/flags/infrastructure/launchdarkly.flag-service.ts
@Injectable()
export class LaunchDarklyFlagService implements FlagService {
  constructor(@Inject('LD_CLIENT') private client: LDClient, private analytics: Analytics) {}

  isOn(key: string, { context, default: def }: { context?: FlagContext; default: boolean }): boolean {
    try {
      return this.client.boolVariation(key, this.toLDContext(context), def);
    } catch (e) {
      logger.warn({ key, err: e.message }, 'flag_eval_failed');
      return def;
    }
  }

  variant<T extends string>(key: string, { context, default: def }: { context?: FlagContext; default: T }): T {
    try {
      return this.client.stringVariation(key, this.toLDContext(context), def) as T;
    } catch (e) {
      logger.warn({ key, err: e.message }, 'flag_eval_failed');
      return def;
    }
  }

  exposed(key: string, variant: string, context: FlagContext): void {
    this.analytics.track('flag.exposed', { key, variant, ...context, ts: new Date().toISOString() });
  }

  private toLDContext(c?: FlagContext): LDContext {
    if (!c) return { kind: 'user', key: 'anonymous' };
    return {
      kind: 'multi',
      tenant: c.tenantId ? { kind: 'tenant', key: c.tenantId } : undefined,
      user:   c.userId   ? { kind: 'user', key: c.userId, email: c.email } : { kind: 'user', key: 'anonymous' },
    };
  }
}
```

Note the try/catch wraps every eval — SDK throw = log + default. Never propagate.

## Per-request memoization

Evaluate once, reuse. Middleware attaches a flag map to the request:

```ts
// src/modules/flags/infrastructure/flag.middleware.ts
@Injectable()
export class FlagMiddleware implements NestMiddleware {
  constructor(@Inject(FLAG_SERVICE) private flags: FlagService) {}

  use(req: FastifyRequest, _res: FastifyReply, next: () => void) {
    const ctx = { tenantId: TenantContext.get()?.tenantId, userId: req.user?.id };
    const cache = new Map<string, unknown>();
    req.flags = {
      isOn: (key: string, def: boolean) => {
        if (!cache.has(key)) cache.set(key, this.flags.isOn(key, { context: ctx, default: def }));
        return cache.get(key) as boolean;
      },
      variant: <T extends string>(key: string, def: T) => {
        if (!cache.has(key)) cache.set(key, this.flags.variant(key, { context: ctx, default: def }));
        return cache.get(key) as T;
      },
    };
    next();
  }
}
```

Now downstream code uses `req.flags.isOn('x', false)` — same eval, free reuse.

## Lifecycle (introduce → ship → remove)

```
Day 0  — Create flag in dashboard. owner=@ali, sunset=+30d, default OFF, rollout 0%.
Day 0  — PR with code branched on flag. Merge.
Day 1  — Rollout 1%. Watch error rate, p95, business KPI for 1h.
Day 2  — Rollout 5%. Same checks.
Day 3  — Rollout 25%. Same.
Day 4  — Rollout 50%. Same.
Day 5  — Rollout 100%. Same.
Day 12 — 100% stable for 7d. Open cleanup PR.
Day 14 — Cleanup PR merged: dead branch deleted, flag wrapper removed.
Day 15 — Delete flag from provider dashboard.
```

Cleanup PR diff is satisfying:

```diff
- if (req.flags.isOn('checkout.new-cart.v2', false)) {
-   return this.cartV2.add(item);
- }
- return this.cartV1.add(item);
+ return this.cartV2.add(item);
```

## A/B experiment with exposure

Variant flags need an EXPOSURE event when the user actually sees the variant — different from eval (eval may happen and not affect the user).

```ts
const variant = req.flags.variant<'control' | 'discount-10' | 'discount-20'>(
  'checkout.discount-test',
  'control',
);

const totals = applyDiscount(cart, variant);

// User WILL see the discounted total → log exposure
this.flags.exposed('checkout.discount-test', variant, { tenantId, userId });
```

Analytics joins exposure to conversion → measure variant lift.

## Kill-switch flag

Operational rollback toggle. Default-ON-with-fast-OFF. Watched separately:

```ts
// New payment provider migration. Default ON. Flip OFF if it breaks.
if (!req.flags.isOn('payments.stripe-2024-api', true)) {
  return this.legacyStripeClient.charge(req);
}
return this.stripeClient.charge(req);
```

When the alert fires:
1. Flip to OFF in dashboard (one click).
2. Traffic shifts to legacy code path within seconds (server SDK polls config every ~30s).
3. Investigate. Fix. Flip back.

Document kill-switches in `ai/runbooks/incident-response.md` with their flag keys.

## Anti-patterns

- Flag eval inside a row-iteration loop. Each call hits SDK cache or wire — multiplied by row count.
- Default-fallback differs from OFF variant ("when SDK is down, behave like new code") — silent reversal at the worst time.
- Flag key reused for new feature. Historical eval data + A/B exposure events lose meaning.
- Both branches do the same thing. Flag is dead. Delete it.
- Flag as auth gate. SDK fails closed → real users locked out. Or fails open → unauthenticated access. Use roles + permissions.
- Flag as compliance control. EU/non-EU behavior differs by region config, not by toggle.
- Flag without sunset date. Lives forever, accrues debt forever.
- 50 flags in code, dashboard shows 8 active. Drift. Run `/flag-audit`.
- Server SDK key in client bundle. Anyone can read flag values + targeting rules.
