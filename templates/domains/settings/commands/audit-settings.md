---
description: Audit the settings/configuration subsystem — store, precedence resolver, typing/validation, secret encryption, cache scope+invalidation, change audit, and write authorization — from real source, never an assumed model.
---

# /audit-settings

Diagnose whether the settings/configuration subsystem is deterministic, typed, secret-safe, cache-safe, and authorized: where settings are stored, how the effective value is resolved across layers, whether values are typed + validated, whether secrets are encrypted, whether the effective-value cache is tenant-scoped + invalidated, whether changes are audited, and whether security-sensitive writes are authorized — from the REAL code, not a guess.

## Premise

Real signals only. Cite the settings store at `<path:line>`, the precedence resolver at `<path:line>` (and state its order), the write-time validation at `<path:line>`, the secret-encryption path at `<path:line>`, the cache key + invalidation at `<path:line>`, the change-audit write at `<path:line>`, and the write-authorization check at `<path:line>` — never narrate a model you didn't read. Read before judging: locate the registry, the resolver, and one read path + one write path in source BEFORE issuing any verdict.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the settings store at `<path:line>`, (2) the precedence model — the resolver at `<path:line>` and its order, OR "AMBIGUOUS — layers merged ad-hoc at call sites" which is itself a finding, (3) the typing + write-validation at `<path:line>` (or "UNTYPED / UNVALIDATED — runtime bomb"), (4) the secret-encryption path at `<path:line>` (or "PLAINTEXT SECRETS — leak"), (5) the cache key + invalidation at `<path:line>` (or "UNSCOPED / NOT-INVALIDATED — cross-tenant leak / stale config"), (6) the change-audit write at `<path:line>` (or "NO AUDIT"), and (7) the write-authorization check at `<path:line>` (or "CLIENT-WRITABLE — privilege escalation"). If any of these cannot be produced from real source, HALT and say which — never an assumed precedence model, never an assumed cache scope.

This command is READ-ONLY. It reads source and configuration; it never writes a setting, never mutates the store, and never decrypts a real secret value — it only confirms the encryption path EXISTS.

## What it does

1. **Locate the store** — where do settings live? A typed registry + a settings table, an untyped JSON blob, scattered env reads, a config service? Cite `<path:line>`. An untyped blob is a finding, not a footnote.
2. **Classify the precedence model** — find the resolver. Is there ONE place that merges `system < org < user`, with a documented total order? Cite `<path:line>` + the order. If layers are merged ad-hoc at call sites (`org.x ?? user.x` sprinkled around), report **AMBIGUOUS — non-deterministic effective value** as a BLOCKER.
3. **Check typing + write validation** — is every key declared with a schema, and is `set` validating against it BEFORE storage? Cite the schema + the validation at `<path:line>`. Untyped column / no write validation = runtime-bomb finding. Flag stringly-typed flags (`=== 'true'`).
4. **Check secret encryption** — are `secret`-visibility settings encrypted at rest and masked on read? Cite the encryption + the masked read at `<path:line>`. A plaintext secret in the table or an API response = BLOCKER.
5. **Check cache scope + invalidation** — is the effective value cached under a key that includes the tenant, and busted on every write? Cite the cache key + the invalidation at `<path:line>`. Unscoped key = cross-tenant leak (BLOCKER); no invalidation = stale config (finding). Cross-ref `<rules-path>/caching.md`.
6. **Check change audit** — is every write recorded (key, old→new redacted, scope, actor, when)? Cite the audit write at `<path:line>`. No audit on `internal`/`secret` settings = finding. Cross-ref `<rules-path>/audit-log.md`.
7. **Check write authorization** — are security-sensitive writes authorized server-side from the auth context? Cite the authz check at `<path:line>`. Client-writable security setting = privilege escalation (BLOCKER). Cross-ref `<rules-path>/auth.md`.
8. **Check defaults + migration** — does every key declare a default, and does a newly-added key ship a migration/backfill so existing rows don't read `undefined`? Cite `<path:line>`.
9. **Report** — store, precedence verdict, typing verdict, secret verdict, cache verdict, audit verdict, authz verdict, defaults verdict, and the top fix.

## Flow

```text
locate store (<path:line>)
  -> classify precedence: ONE resolver (system<org<user) | AMBIGUOUS ad-hoc   [BLOCKER if ambiguous]
  -> assert typed registry + write validation                                 [finding if untyped/unvalidated]
  -> assert secret settings encrypted at rest + masked on read                 [BLOCKER if plaintext]
  -> assert cache key includes tenant + invalidated on write                   [BLOCKER if unscoped; finding if stale]
  -> assert change audit (key, old->new redacted, scope, actor)                [finding if missing]
  -> assert server-side authz on security-sensitive writes                     [BLOCKER if client-writable]
  -> assert default + migration on each key                                    [finding if missing]
  -> report: store + 7 verdicts + top fix
```

## Output

```
/audit-settings — <subsystem> @ <path:line>

Store:           typed registry + settings table  @ settings/core/registry.ts:14   [or: UNTYPED JSON blob — finding]

Precedence:      ONE resolver  system < org < user  @ settings/core/resolver.ts:9   [or: AMBIGUOUS — ad-hoc merges — BLOCKER]
Typing/validate: zod schema, validated on write     @ settings.service.ts:24        [or: UNTYPED / UNVALIDATED — runtime bomb]
Secrets:         encrypted at rest, masked on read   @ settings.service.ts:41        [or: PLAINTEXT — leak — BLOCKER]
Cache scope:     settings:<key>:<tenantId>[:<userId>]@ settings.service.ts:78        [or: UNSCOPED — cross-tenant leak — BLOCKER]
Cache invalidate: busted on every write              @ settings.service.ts:52        [or: NOT INVALIDATED — stale config]
Change audit:    key, old->new redacted, scope, actor@ settings.service.ts:56        [or: NO AUDIT — finding]
Write authz:     writeRequires, server-side          @ settings.service.ts:33        [or: CLIENT-WRITABLE — escalation — BLOCKER]
Defaults/migrate: default + backfill per key          @ migrations/..._add_mfa.ts:4   [or: NO DEFAULT — undefined for existing rows]

Stringly-typed flags: none                                                          [or: `=== 'true'` @ feature.ts:88 — finding]

Verdict: OK | NEEDS-RESOLVER | NEEDS-VALIDATION | NEEDS-ENCRYPTION | NEEDS-CACHE-SCOPE | BLOCKER(<which>)

Top recommendation:
  - <e.g. collapse the ad-hoc merges into one precedence resolver; or add tenant to the cache key + invalidate on write; or encrypt the secret-valued settings>
```

## Rules

- READ-ONLY audit. Never write a setting, never mutate the store, never decrypt a real secret — confirm the encryption path EXISTS, don't exercise it.
- Cite-or-halt: real store, real resolver + order, real validation, real encryption path, real cache key + invalidation, real audit write, real authz check — or halt naming what's missing.
- Always print the precedence verdict first; AMBIGUOUS (ad-hoc layer merges) is a BLOCKER — a non-deterministic effective value, reported before anything else.
- An unscoped cache key is a cross-tenant leak; a plaintext secret is a leak; a client-writable security setting is privilege escalation — each is a BLOCKER, never an aside.
- Never report a precedence model, a cache scope, or an encryption path you didn't read in source.

## Cross-references

- `.claude/rules/settings-config-discipline.md` — the hard-rule list this command enforces (typed registry, one resolver, validate-on-write, encrypt secrets, scoped+invalidated cache, server-side write authz, default+migration, audit).
- `ai/patterns/layered-settings.md` — the typed-registry + precedence-resolver + validate + encrypt + scoped-cache + audit code shapes.
- `<rules-path>/caching.md` — the scoped + invalidated effective-value cache (tenant in the key; bust on write).
- `<rules-path>/audit-log.md` — settings changes are an audited event.
- `<rules-path>/feature-flags.md` — the flags-vs-settings boundary (don't audit a rollout gate as durable config, or churn a durable preference as a flag).
- `<rules-path>/auth.md` — server-side authorization for security-sensitive setting writes.
- `<agents-path>/settings-reviewer.md` — review gate that consumes these findings.
