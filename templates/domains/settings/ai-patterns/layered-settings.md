---
name: layered-settings
description: "Pattern: Layered settings (typed schema, precedence-resolved, validated, cache-safe)"
kind: ai-pattern
---

# Pattern: Layered settings (typed schema, precedence-resolved, validated, cache-safe)

> **Hard rule** — Every setting is declared in a TYPED registry (key → schema + default + scope + visibility); the effective value is resolved through ONE deterministic precedence chain (`system default < org/tenant < user`); writes are VALIDATED against the key's schema before storage; secret-valued settings are ENCRYPTED at rest and never returned in plaintext; the effective value is cached under a TENANT-SCOPED key and INVALIDATED on every write; security-sensitive writes are SERVER-AUTHORIZED from the auth context; and every change is AUDITED. Adding a key ships a default + migration so existing rows never read `undefined`.

**When to apply**
- Any multi-tenant product where configuration is layered — a platform default, an org/workspace policy, and a per-user preference — and the effective value is the merge of those layers.
- Settings whose wrong value is dangerous: retention windows, auth/MFA policy, billing limits, integration secrets, anything that gates who-can-do-what.
- Configuration that is read frequently (per request) and changed rarely — the read path must be cached and tenant-safe.

**When NOT to apply**
- A single global, deploy-time constant that no tenant can override — that's an env var / config file, not a layered setting.
- Feature flags for rollout / targeting / experimentation — use the flag system (percentage rollout, per-request targeting, churned-and-removed lifecycle). Settings are durable, user-chosen config. See `<rules-path>/feature-flags.md` for the boundary.
- A one-off, never-cached admin toggle read once at boot — the full registry + cache machinery is overhead.

**Halt conditions / mandatory cites**
- Cite the typed registry (key → schema + default + scope + visibility) at `<path:line>`. Settings read from a raw column / untyped `JSON.parse` = halt.
- Cite the ONE precedence resolver at `<path:line>` and state its order. Layers merged ad-hoc at call sites = halt (ambiguous effective value).
- Cite the write-time schema validation at `<path:line>`. A `set` that stores an unvalidated value = halt.
- Cite the encryption of `secret` settings + the masked read at `<path:line>`. A plaintext secret in the settings table or an API response = halt.
- Cite the tenant-scoped cache key + the invalidation on write at `<path:line>`. An unscoped key (cross-tenant leak) or no invalidation (stale config) = halt.
- Cite the server-side authorization on security-sensitive writes at `<path:line>`, and the audit write at `<path:line>`.
- Cite the `default` + migration/backfill for any newly-added key at `<path:line>`.
- Grep ban: "settings are typed / scoped / safe" without file:line for the registry, the resolver, the write validation, the cache key + invalidation, and the audit write.

## Why

Settings look trivial — a key, a value, a table — and that's exactly why they rot. The failures are all silent and all on the read path:

1. **Ambiguous effective value** — three layers (system / org / user) merged ad-hoc at each call site means the same key resolves differently depending on which author wrote which merge. There is no single answer to "what is this tenant's value." The fix is ONE resolver with a total, documented precedence order.
2. **A bad stored value is a runtime bomb** — an untyped column accepts `retentionDays = "-1"`; nothing fails at write time; the next read crashes the cleanup job. Validation belongs at the write boundary, against the key's schema, so storage only ever holds valid values.
3. **Cross-tenant leak / stale config via the cache** — the effective value is cached for speed, but an unscoped cache key serves tenant A's config to tenant B, and a never-invalidated key serves last hour's value after a change. The cache key carries the tenant; every write busts the scope.
4. **Privilege escalation + secret leak** — a security-sensitive setting written from the client with no authz is escalation through the settings endpoint; a secret stored plaintext leaks in every API response and audit row.
5. **`undefined` for existing rows** — a new key with no default reads `undefined` for every existing tenant, and `if (config.requireMfa)` silently evaluates false.

The pattern: a typed registry, one precedence resolver, validate-on-write, encrypt secrets, a tenant-scoped + invalidated cache, server-side write authz, and an audit entry on every change.

## The registry (one typed source of truth)

```ts
// src/modules/settings/core/registry.ts
import { z } from 'zod';

export type Scope = 'system' | 'org' | 'user';
export type Visibility = 'public' | 'internal' | 'secret';

export interface SettingDef<T> {
  key: string;
  schema: z.ZodType<T>;        // validates on write AND parses on read
  default: T;                  // resolves cleanly for rows that never set it
  scope: Scope;                // the HIGHEST layer allowed to set this key
  visibility: Visibility;      // 'secret' => encrypted at rest, masked on read
  /** Security-sensitive writes require this permission, server-side. */
  writeRequires?: Permission;
}

// The ONE place a setting is declared. No raw columns, no JSON.parse of an untyped blob.
export const REGISTRY = {
  'ui.theme': {
    key: 'ui.theme', scope: 'user', visibility: 'public',
    schema: z.enum(['light', 'dark', 'system']), default: 'system',
  } satisfies SettingDef<'light' | 'dark' | 'system'>,

  'security.requireMfa': {
    key: 'security.requireMfa', scope: 'org', visibility: 'internal',
    schema: z.boolean(), default: true,            // SAFE default: un-set org fails CLOSED
    writeRequires: 'org:security:write',           // server-authorized write
  } satisfies SettingDef<boolean>,

  'retention.days': {
    key: 'retention.days', scope: 'org', visibility: 'internal',
    schema: z.number().int().min(1).max(3650), default: 365,
    writeRequires: 'org:compliance:write',
  } satisfies SettingDef<number>,

  'integrations.stripeSecretKey': {
    key: 'integrations.stripeSecretKey', scope: 'org', visibility: 'secret',  // encrypted at rest
    schema: z.string().min(1), default: '',
    writeRequires: 'org:billing:write',
  } satisfies SettingDef<string>,
} as const;

export type SettingKey = keyof typeof REGISTRY;
export type ValueOf<K extends SettingKey> = z.infer<(typeof REGISTRY)[K]['schema']>;
```

Feature code reads `settings.get('retention.days', ctx)` and gets a `number`, not `unknown`. A flag is a `z.boolean()`, an enum is a closed `z.enum([...])` — never a stringly-typed `"true"`.

## The precedence resolver (ONE deterministic chain)

```ts
// src/modules/settings/core/resolver.ts

/**
 * The ONE place layers are merged. Precedence is TOTAL and documented:
 *   system default  <  org/tenant override  <  user override
 * Higher layers win. Two callers resolving the same key for the same context
 * MUST get the same value. No ad-hoc `org.x ?? user.x` at call sites — ever.
 */
export function resolveEffective<K extends SettingKey>(
  def: SettingDef<ValueOf<K>>,
  layers: { system: ValueOf<K>; org?: ValueOf<K>; user?: ValueOf<K> },
): ValueOf<K> {
  // Only consider a layer if the def's scope permits it to set this key.
  const order: Scope[] = ['system', 'org', 'user'];
  let value = layers.system;                       // always the registry default at the bottom
  for (const scope of order) {
    if (scopeRank(scope) > scopeRank(def.scope)) break;  // a user can't override an org-scoped key
    const candidate = scope === 'org' ? layers.org : scope === 'user' ? layers.user : layers.system;
    if (candidate !== undefined) value = candidate;       // higher present layer wins
  }
  return value;
}

const scopeRank = (s: Scope) => ({ system: 0, org: 1, user: 2 }[s]);
```

The precedence is `system < org < user`, applied once. An `org`-scoped key (like `security.requireMfa`) can be set at the org layer but NOT overridden per-user — the resolver enforces the scope ceiling, so a user can't weaken an org security policy.

## Validate on write + encrypt secrets + authorize + audit + invalidate

```ts
// src/modules/settings/settings.service.ts

export class SettingsService {
  constructor(
    private store: SettingsStore,
    private crypto: Encryptor,        // KMS / envelope / app-level AEAD
    private cache: Cache,
    private audit: AuditLog,
    private authz: Authorizer,
  ) {}

  async set<K extends SettingKey>(
    key: K, rawValue: unknown, scopeId: ScopeId, ctx: AuthContext,
  ): Promise<void> {
    const def = REGISTRY[key] as SettingDef<ValueOf<K>>;

    // 1. VALIDATE against the key's schema BEFORE storage. A bad value never lands.
    const parsed = def.schema.safeParse(rawValue);
    if (!parsed.success) throw new InvalidSettingError(key, parsed.error);   // rejected at write time
    const value = parsed.data;

    // 2. SERVER-SIDE AUTHORIZATION for security-sensitive writes — from the auth context, not the client.
    if (def.writeRequires) {
      await this.authz.require(ctx, def.writeRequires, scopeId);   // throws if the actor lacks it
    }
    if (scopeRankOf(scopeId) > scopeRank(def.scope)) {
      throw new ScopeViolationError(key, def.scope);               // can't set above the key's scope
    }

    // 3. ENCRYPT secret-valued settings at rest. Plaintext secrets never touch the table.
    const stored = def.visibility === 'secret'
      ? await this.crypto.encrypt(String(value))
      : value;

    const previous = await this.store.read(key, scopeId);          // for the audit diff
    await this.store.write(key, scopeId, stored, def.visibility);

    // 4. INVALIDATE the tenant-scoped cache for this exact scope. Stale config is never served.
    await this.invalidate(key, scopeId);

    // 5. AUDIT every change — secrets redacted. (see <rules-path>/audit-log.md)
    await this.audit.record({
      action: 'settings.change', key, scopeId, actorId: ctx.userId, tenantId: ctx.tenantId,
      oldValue: redact(def, previous), newValue: redact(def, value), at: new Date(),
    });
  }

  /** READ — through the tenant-scoped cache, resolved through the ONE precedence chain. */
  async get<K extends SettingKey>(key: K, ctx: AuthContext): Promise<ValueOf<K>> {
    const def = REGISTRY[key] as SettingDef<ValueOf<K>>;
    const cacheKey = this.cacheKey(key, ctx);                      // tenant (+ user) IN the key
    const cached = await this.cache.get<ValueOf<K>>(cacheKey);
    if (cached !== undefined) return cached;

    // Read each layer's stored value (decrypting secrets server-side only), then resolve.
    const system = def.default;                                   // registry default — never undefined
    const org = await this.readLayer(def, { scope: 'org', id: ctx.tenantId });
    const user = def.scope === 'user'
      ? await this.readLayer(def, { scope: 'user', id: ctx.userId })
      : undefined;

    const value = resolveEffective(def, { system, org, user });   // the ONE resolver
    await this.cache.set(cacheKey, value, { ttlSeconds: 300 });    // cached; busted on every write
    return value;
  }

  /** Tenant-scoped cache key. NEVER omits the tenant — an unscoped key is a cross-tenant leak. */
  private cacheKey(key: SettingKey, ctx: AuthContext): string {
    const def = REGISTRY[key];
    return def.scope === 'user'
      ? `settings:${key}:${ctx.tenantId}:${ctx.userId}`           // user-scoped => user in the key
      : `settings:${key}:${ctx.tenantId}`;                        // tenant ALWAYS present
  }

  private async invalidate(key: SettingKey, scopeId: ScopeId): Promise<void> {
    // Bust the exact scope's keys. (see <rules-path>/caching.md for the invalidation contract)
    await this.cache.deleteByPrefix(`settings:${key}:${scopeId.tenantId}`);
  }

  private async readLayer<T>(def: SettingDef<T>, layer: { scope: Scope; id: string }): Promise<T | undefined> {
    const raw = await this.store.read(def.key, layer);
    if (raw === undefined) return undefined;
    const plain = def.visibility === 'secret' ? await this.crypto.decrypt(String(raw)) : raw;
    return def.schema.parse(plain);          // parse on read too — defend against legacy bad rows
  }
}

/** Secrets are NEVER surfaced in plaintext — audit logs and API responses get a mask. */
function redact<T>(def: SettingDef<T>, value: T | undefined): unknown {
  if (value === undefined) return undefined;
  return def.visibility === 'secret' ? maskSecret(String(value)) : value;   // "••••last4"
}
```

Validation is at the write boundary, secrets are encrypted, security writes are authorized from the auth context, the cache key carries the tenant, every write invalidates and audits. The read path resolves through the one precedence chain and is served from a tenant-scoped cache.

## Masked read for the API (never echo a secret)

```ts
// src/modules/settings/settings.controller.ts

@Get('/settings/:key')
async readForClient(@Param('key') key: SettingKey, @Ctx() ctx: AuthContext) {
  const def = REGISTRY[key];
  if (def.visibility === 'secret') {
    // Never return the plaintext secret. Return presence + a masked tail only.
    const present = await this.settings.isSet(key, ctx);
    return { key, set: present, value: present ? '••••••••' : null };
  }
  return { key, value: await this.settings.get(key, ctx) };
}
```

A secret setting returns `set: true` + a mask — never the plaintext. The plaintext is decrypted only server-side at point of use.

## Adding a key: default + migration (no undefined for existing rows)

```ts
// 1. Declare the key WITH a default in the registry (above). Existing rows resolve to the default.
//    For a security/gating key, the default is the SAFE option so un-set rows fail closed.

// 2. If absence must be made explicit (e.g. you need a stored row per tenant), backfill it.
// migrations/2026_06_11_add_require_mfa.ts
export async function up(db: Db) {
  // Backfill every existing org with the safe default so behavior is uniform, not divergent.
  await db.exec(`
    INSERT INTO settings (tenant_id, key, value, visibility)
    SELECT id, 'security.requireMfa', 'true', 'internal' FROM organizations
    ON CONFLICT (tenant_id, key) DO NOTHING
  `);
}
```

A new key is never `undefined` for an existing tenant — it resolves to the registry default, and (where presence matters) a migration backfills it. Security/gating keys default to the restrictive value.

## Settings vs. feature flags (keep the boundary)

```text
FEATURE FLAG                          SETTING
- rollout / targeting / experiment    - durable user/tenant configuration
- percentage / cohort / per-request   - resolved by precedence (system<org<user)
- short-lived, churned, deleted       - long-lived, audited, migrated
- evaluated in the flag system        - resolved in the SettingsService + cache
```

A kill-switch or a 10%-rollout gate is a flag. A tenant's timezone, retention window, or theme is a setting. Don't store a rollout gate in the settings table (it has no targeting, and it'll be audited + cached as durable config), and don't put a durable tenant preference in the flag system (it'll be churned and deleted). See `<rules-path>/feature-flags.md`.

## Common mistakes

### Ad-hoc precedence
`org.x ?? user.x ?? DEFAULT` in one file, `user.x ?? org.x` in another → the same key resolves differently per author. One resolver, one documented `system < org < user` order, scope ceiling enforced.

### Untyped blob
`const cfg = JSON.parse(row.settings_json); cfg.maxSeats + 1` → a `"10"` string yields `"101"`. Typed registry; `schema.parse` on read and write.

### No write validation
`await store.write(key, req.body.value)` stores `retentionDays = -1` → the next read breaks the cleanup job. Validate against the schema at write time; reject before storage.

### Plaintext secret
`stripeSecretKey` stored as a plain column and echoed in `GET /settings` → the secret is in every admin's browser and the audit log. Encrypt at rest; mask on read; decrypt only server-side.

### Unscoped cache key
`cache.get('settings:theme')` with no tenant → tenant B sees tenant A's config. The key MUST include the tenant. See `<rules-path>/caching.md`.

### Never-invalidated cache
Effective value cached with a TTL and no bust on write → an admin changes a setting and it "doesn't take" until the TTL expires. Invalidate the scope on every write.

### Client-writable security setting
`PATCH /settings { role: 'admin' }` → storage with no authz → privilege escalation. Server-authorize every `writeRequires` key from the auth context. See `<rules-path>/auth.md`.

### New key, no default
Ship `requireMfa` with no default → every existing org reads `undefined`, MFA silently off. Default + migration on every new key; security keys default to safe.

### DB hammer on the hot path
`select value from settings where key=$1` per request for a monthly-changing value → the settings table is the hottest in the system. Serve the effective value from a scoped, invalidated cache.

### Stringly-typed flag
`if (settings.get('beta') === 'true')`; someone stores `True` / `1` → the gate is wrong. Boolean/enum schema; read a typed value.

### No audit
An org's retention window goes 365 → 7 with no record of who or when → unrecoverable, unattributable data loss. Audit every change. See `<rules-path>/audit-log.md`.

## Cross-references

- `<rules-path>/settings-config-discipline.md` — the hard-rule list (typed registry, one resolver, validate-on-write, encrypt secrets, scoped+invalidated cache, server-side write authz, default+migration, audit).
- `<rules-path>/caching.md` — the tenant-scoped + invalidated effective-value cache (tenant in the key; bust on write).
- `<rules-path>/audit-log.md` — settings changes are an audited event; what to record per change (key, old→new redacted, scope, actor).
- `<rules-path>/feature-flags.md` — the flags-vs-settings boundary (flags = rollout/targeting; settings = durable config).
- `<rules-path>/auth.md` — server-side authorization for security-sensitive setting writes.
- `<commands-path>/audit-settings.md` — cite-or-halt diagnostic for the settings store, resolver, validation, secrets, cache, authz, and audit.
- `<agents-path>/settings-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-settings-precedence.md` — ADR pinning the precedence order, scope model, and secret-storage mechanism.
