---
name: configuration
description: Cross-cutting configuration rules — same value in every environment, one precedence order, and a named owner for who may change it
kind: rule
concern: C6
---

# Configuration

## Hard rule

Every value that differs between environments MUST be declared in one place, resolved by one
documented precedence order, and validated on write. A value that can be changed at runtime MUST
name who may change it and where the change is recorded. Config that is "just an env var someone
set on the box" is undeclared state, and undeclared state is the reason staging passes and
production does not.

The widest gap in the first matrix build after Data Lifecycle: empty on **18 of 35 surfaces**.
Configuration was reviewed as a deployment topic and almost never as a property of the surface
that reads the value.

## Per-surface fingerprints

| Surface | The value that drifts | Typical finding |
|---|---|---|
| `admin` | which roles are "admin", impersonation on/off | admin allowlist hardcoded in one env and DB-driven in another |
| `analytics` | write keys, sampling rate, consent mode | production key checked into a client bundle; sampling differs silently per environment |
| `audit-log` | retention window, what counts as auditable | the auditable-action list is code in one module and config in another |
| `event-sourced` | snapshot interval, projection replay switches | replay enabled in prod by a flag nobody owns |
| `file-upload` | max size, allowed types, AV on/off | AV scanning disabled in staging, so the prod-only path is never exercised |
| `forms` | captcha thresholds, rate limits, validation strictness | validation strictness diverges from the server's, so staging accepts what prod rejects |
| `i18n` | default locale, fallback chain, enabled locales | enabled-locale list duplicated in build config and runtime config |
| `import` | batch size, partial-failure policy, dry-run default | dry-run defaults differ per environment — the safety net is off exactly where it matters |
| `integrations` | vendor endpoints, credentials, rate budgets | sandbox endpoint left in one environment; per-tenant credentials mixed with a global fallback |
| `ledger` | currency precision, rounding mode | rounding mode set per-deployment; two environments compute different balances from identical input |
| `moderation` | scanner thresholds, auto-action cutoffs | thresholds tuned in prod and never reflected anywhere reviewable |
| `multi-tenant` | per-tenant overrides vs global defaults | precedence between tenant override and global default undocumented, so both orders exist in the code |
| `payment` | PSP keys, webhook secrets, capture mode | test keys reachable from a prod code path; capture-vs-authorize mode differs by environment |
| `public-api` | rate limits, deprecation dates, version pins | documented limits differ from enforced limits |
| `reporting` | replica routing, timeout, row caps | report timeouts differ per environment, so a report that works in staging kills prod |
| `scheduling` | default timezone, business hours, slot length | a default timezone in config, another in the DB, a third in the client |
| `subscriptions` | plan/price ids, trial length, proration mode | price ids hardcoded per environment; trial length in two places that disagree |
| `workflow` | allowed transitions, approval thresholds | the transition table is config in one service and code in another |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where config enters** | env → secret store → DB overrides | build-time `import.meta.env` — baked in, public forever | build flavour + remote config, gated by app-store release cycle | flags → env → config file → defaults |
| **Precedence** | documented order, validated on boot | one order; no runtime mutation of build-time values | remote config must not be able to break a shipped build | flags beat env beats file beats default — and `--help` says so |
| **The classic miss** | a value read directly from `process.env` deep in a service | a secret in the bundle because the prefix made it public | remote config with no kill-switch on a bad value | an undocumented env var that changes behaviour |

> `browser` config is public. A finding there is never "hide the value" — it is "this value must
> not be a secret", and the fix moves the decision server-side.

## Closure verbs

`declare-once` · `document-precedence` · `validate-on-boot` · `move-secret-server-side` ·
`name-the-owner` · `fail-fast-on-missing`
