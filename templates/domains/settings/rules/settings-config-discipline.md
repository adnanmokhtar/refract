---
name: settings-config-discipline
description: Settings & configuration discipline
kind: rule
---

# Settings & configuration discipline

## Hard rule

Every configurable setting MUST be declared in a TYPED registry (key → schema + default + scope + visibility) — there are NO ad-hoc settings, NO stringly-typed flags, NO `JSON.parse(blob)` reads of an untyped column. The effective value of a setting MUST be resolved through ONE deterministic precedence chain — `system default < org/tenant < user` — applied in exactly one resolver; merging layers ad-hoc per call site is FORBIDDEN because it makes the effective value ambiguous and non-deterministic. Every write MUST be validated against the key's schema BEFORE it is stored — a bad stored value is a runtime bomb that detonates on the next read, not at write time. Secret-valued settings (API keys, webhook secrets, SMTP passwords) MUST be encrypted at rest and never returned in plaintext to a client. The effective value MUST be cached UNDER A TENANT-SCOPED KEY and INVALIDATED on every write — an unscoped cache key is a cross-tenant config LEAK; a never-invalidated cache serves stale config forever. Security-sensitive settings MUST be server-authorized on write — a setting that is client-writable without an authorization check is a privilege-escalation vector. Every change MUST be audited (who changed which key, old → new, when, scope), and adding a new key MUST ship a default + a migration path so existing rows don't null-deref.

A settings bug is a silent one: the wrong tenant's config is served, a flag is read as the string `"false"` (truthy), a secret leaks in an API response, or a newly-added key is `undefined` for every existing row. None of these throw at write time — they detonate later, in production, on the read path.

## Must

- **Typed registry, one source of truth**: every setting is declared once — `key`, a schema (zod / json-schema / typed validator), a `default`, a `scope` (`system` | `org` | `user`), and a `visibility` (`public` | `internal` | `secret`). Feature code reads `settings.get(key, ctx)` against the registry — never a raw column, never `JSON.parse` of an untyped blob, never an env var read scattered at the call site.
- **One deterministic precedence resolver**: the effective value is computed in EXACTLY ONE place, applying `system default < org/tenant < user` (lower layers overridden by higher). The precedence order is documented and total — there is no "it depends on the caller." Two call sites resolving the same key for the same context MUST get the same value.
- **Validate on write, against the key's schema**: `settings.set(key, value, ctx)` parses `value` through the key's schema and REJECTS an invalid value at write time. A value that fails the schema never reaches storage. Reads therefore never have to defend against a malformed stored value.
- **Encrypt secret-valued settings at rest**: settings with `visibility: 'secret'` are encrypted (envelope encryption / KMS / app-level AEAD) before storage and decrypted only server-side at point of use. A secret setting is NEVER returned to a client — the API returns a masked placeholder (`"••••last4"`) or omits it.
- **Tenant-scoped, invalidated cache for the effective value**: the resolved effective value is cached under a key that includes the tenant (and user, when user-scoped) — `settings:<key>:<tenantId>[:<userId>]`. EVERY write invalidates the affected cache keys for that exact scope (see `<rules-path>/caching.md`). The cache key NEVER omits the tenant.
- **Server-enforced write authorization**: changing a security-sensitive setting (auth policy, feature gating, billing config, retention, anything that changes who-can-do-what) requires a server-side authorization check on the actor (see `<rules-path>/auth.md`). Authorization is derived from the verified auth context — never from a client-supplied role/scope.
- **Default + migration on every new key**: adding a key ships (1) a `default` in the registry so existing rows resolve cleanly, AND (2) a migration/backfill path where the absence of a stored value is meaningful. A new key is NEVER `undefined` for existing tenants/users.
- **Audit every change**: who changed which key, the old value → new value (secrets redacted), the scope, and when, are written to the audit log (see `<rules-path>/audit-log.md`) on every `set`. A config change with no audit trail is forbidden for any `internal`/`secret` setting.
- **Booleans are booleans, enums are enums**: a flag-shaped setting has a `boolean` schema and is read as a boolean; an enum setting has a closed `enum` schema. No `"true"` / `"false"` / `"1"` strings flowing through `if (setting)`. The schema coerces and validates at the boundary.
- **Read off the hot path through the cache**: a setting read on a request-per-request hot path goes through the scoped cache, not a fresh DB round-trip per request. Resolving settings by hammering the DB on every request is a load bug.

## Must not

- Merge `system` / `org` / `user` layers ad-hoc at a call site (`org.x ?? user.x ?? DEFAULT` sprinkled around) — the precedence becomes whatever each author wrote, and the effective value is non-deterministic.
- Store a setting in an untyped column and read it back with `JSON.parse` / `as any` — a bad stored value (wrong type, missing field) becomes a runtime crash on the read path.
- Store a value without validating it against the key's schema first — write-time validation is the only place to stop a bad value cheaply.
- Store a secret setting (API key, webhook secret, password) in plaintext in the settings table, or return it in plaintext from an API.
- Cache the effective value under a key that omits the tenant — a shared cache key leaks one tenant's config to another. (See `<rules-path>/caching.md`.)
- Cache the effective value with no invalidation on write — the old value is served until the TTL, so a config change "doesn't take" for minutes.
- Let a security-sensitive setting be written from the client with no server-side authorization — that is privilege escalation via the settings endpoint.
- Add a new key with no default and no migration — every existing row reads `undefined`, and behavior silently diverges between rows that have the key set and rows that don't.
- Treat a flag as stringly-typed (`if (settings.get('beta') === 'true')`) — `"false"` is truthy, `"0"` is truthy; one typo and the gate is permanently open.
- Change a setting with no audit entry — there is no way to answer "who turned this off and when."

## Should

- Wrap reads + writes behind a project-internal `<SettingsService>` / `<ConfigStore>` interface so the registry lookup, precedence resolution, validation, encryption, caching, and audit are enforced in ONE place — feature code calls `settings.get` / `settings.set`, never the table.
- Distinguish **settings** from **feature flags** explicitly (see `<rules-path>/feature-flags.md`): feature flags are rollout / targeting / experimentation (often percentage-based, evaluated per-request, frequently churned and removed); settings are durable, user/tenant-chosen configuration that persists. Don't put a kill-switch in the settings table or a tenant preference in the flag system — the lifecycle, audit, and resolution semantics differ.
- Type the effective-config object so feature code gets `config.retentionDays: number`, not `config['retention_days']: unknown` — the registry should generate or back a typed accessor.
- Version the schema of a setting so a stored value written under an old shape can be migrated forward on read (with a one-time backfill), rather than read-time branching forever.
- Emit structured `{ key, scope, tenantId, actorId, oldRedacted, newRedacted }` on every change and alert on changes to security-sensitive keys (auth policy, billing, retention).
- Make the default the safe value: a new gating/security setting defaults to the MORE restrictive option, so an un-set row fails closed, not open.

## Review checklist (PRs touching settings / config / preferences / org or workspace settings)

- [ ] Every new/changed setting is declared in the typed registry with `key` + schema + `default` + `scope` + `visibility`; cite `<path:line>`.
- [ ] The effective value is resolved through the ONE precedence resolver (`system < org < user`), not merged ad-hoc at the call site; cite the resolver at `<path:line>`.
- [ ] Writes are validated against the key's schema before storage; cite the validation at `<path:line>`.
- [ ] Secret-valued settings are encrypted at rest and never returned in plaintext; cite the encryption + the masked read at `<path:line>`.
- [ ] The effective value is cached under a tenant-scoped key and invalidated on write; cite the cache key + invalidation at `<path:line>`.
- [ ] Security-sensitive settings are server-authorized on write from the auth context; cite the authz check at `<path:line>`.
- [ ] A new key ships a default + a migration/backfill; existing rows do not read `undefined`; cite both at `<path:line>`.
- [ ] Every change is audit-logged (key, old→new redacted, scope, actor, when); cite the audit write at `<path:line>`.
- [ ] Flags/enums use a typed schema (boolean/enum), not stringly-typed values; cite the schema at `<path:line>`.
- [ ] Settings read on a hot path go through the scoped cache, not a per-request DB hit; cite the read path at `<path:line>`.

## Anti-patterns

- **Ad-hoc precedence** — `const v = user.theme ?? org.theme ?? 'light'` in one file and `org.theme ?? user.theme ?? 'dark'` in another -> the same key resolves to different values depending on which author you ask. One resolver, one documented order.
- **Untyped blob** — `const cfg = JSON.parse(row.settings_json)` then `cfg.maxSeats + 1` -> a row where `maxSeats` is the string `"10"` yields `"101"`. Typed registry + schema parse on read.
- **No write validation** — `await db.set(key, req.body.value)` stores whatever arrives -> `retentionDays = -1` is read next request and breaks the cleanup job. Validate against the schema at write time.
- **Plaintext secret** — `smtp_password` stored as a plain column and echoed back in `GET /settings` -> the secret is in every admin's browser history and the audit log. Encrypt at rest; mask on read.
- **Unscoped cache key** — `cache.get('settings:theme')` with no tenant -> tenant B sees tenant A's branding. The cache key MUST include the tenant. (See `<rules-path>/caching.md`.)
- **Never-invalidated cache** — effective value cached with a 1h TTL and no bust on write -> an admin disables a feature, it stays on for an hour, and they file a bug. Invalidate the scope's keys on every write.
- **Client-writable security setting** — `PATCH /settings { "role": "admin" }` flows straight to storage with no authz -> privilege escalation through the settings endpoint. Server-authorize every security-sensitive write. (See `<rules-path>/auth.md`.)
- **New key, no default** — ship `requireMfa` with no default -> every existing tenant reads `undefined`, `if (config.requireMfa)` is falsy, MFA is silently off for all of them. Default + migration on every new key, and default security keys to the safe value.
- **Stringly-typed flag** — `if (settings.get('beta_enabled') === 'true')`; someone stores `True` / `1` / `yes` -> the gate is wrong. Boolean schema; read a boolean.
- **Settings/flags confusion** — a percentage-rollout kill-switch lives in the durable settings table (no targeting, audited as a config change, cached) while a tenant's durable timezone lives in the flag system (evaluated per-request, churned, eventually deleted). Keep the boundary. (See `<rules-path>/feature-flags.md`.)
- **DB hammer** — `await db.query('select value from settings where key=$1')` on every request for a value that changes monthly -> the settings table becomes the hottest table in the system. Cache the effective value under a scoped, invalidated key.
- **No audit** — an org's data-retention window is changed from 365 to 7 days and there is no record of who or when -> the deleted data is unrecoverable and unattributable. Audit every change. (See `<rules-path>/audit-log.md`.)

## Enforcement

- `<commands-path>/audit-settings.md` (slash: `/audit-settings`) — cite-or-halt diagnostic that locates the settings store + the precedence resolver at `<path:line>`, classifies the precedence model (or flags AMBIGUOUS), and verifies typing, validation, secret encryption, cache scope + invalidation, change audit, write authorization, and defaults/migration — never an assumed model.
- `<agents-path>/settings-reviewer.md` — review gate hard-failing on no-precedence-model, untyped/unvalidated settings, plaintext secrets, unscoped/non-invalidated caching, client-writable security settings, missing default/migration on a new key, per-request DB reads, missing audit, and stringly-typed flags.
- CI lint MUST reject a settings read that goes to a raw column / `JSON.parse` of an untyped blob instead of the registry accessor (AST heuristic; flag for review).
- CI lint MUST reject a cache key in the settings module that does not include a tenant id token (heuristic; flag for review).
- CI MUST assert that every key in the registry declares a `default` and a `schema` (registry self-validation test).
- CI lint MUST reject `=== 'true'` / `=== 'false'` comparisons on a settings read (stringly-typed flag heuristic).
- TODO: `scripts/validate-settings-registry.sh` to AST-walk the registry and assert every key has schema + default + scope + visibility, every `secret` key has an encryption path, and every write site routes through the validating setter.

## Cross-references

- `<patterns-path>/layered-settings.md` — typed registry + deterministic precedence resolver + write validation + secret encryption + scoped/invalidated cache + audit + default/migration + server-side write authz code shapes.
- `<rules-path>/caching.md` — the scoped + invalidated effective-value cache (tenant in the key; bust on write).
- `<rules-path>/audit-log.md` — settings changes are an audited event; what to record per change.
- `<rules-path>/feature-flags.md` — the flags-vs-settings boundary (flags = rollout/targeting; settings = durable config).
- `<rules-path>/auth.md` — server-side authorization for security-sensitive setting writes.
- `<adr-path>/<NNN>-settings-precedence.md` — ADR pinning the precedence order, the scope model (system/org/user), and the secret-storage mechanism.
