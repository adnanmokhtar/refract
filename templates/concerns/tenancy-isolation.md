---
name: tenancy-isolation
description: Cross-cutting tenant-scoping rules — every read and write carries the tenant anchor, on every surface
kind: rule
concern: C12
---

# Tenancy Isolation

**Conditional — fires only when the `multi-tenant` signal is present.** When it does, it cuts
every surface.

## Hard rule

Every read and every write MUST carry the tenant anchor, and the anchor MUST be derived from the
authenticated context — never from client input. A query that *can* be written without the anchor
eventually will be. The enforcement point is a project decision; having the enforcement be
"developers remember" is the finding.

## The denominator rule

Isolation coverage is a **ratio, not a boolean**. `§ 11` records it as
`multi-tenant: partial 117/242` — and 117/242 is the review, not the label. Every cell on a
tenant-bearing surface reports against that denominator: *isolation covers 117 entity files;
here are the other 125*. A cell that reports "isolation present" with no ratio has restated the
label and reviewed nothing, which is the exact failure
[`phase-2-profile.md`](../phases/phase-2-profile.md) records as *"the demotion was cosmetic."*

## Per-surface fingerprints

| Surface | Where the anchor goes missing | Typical finding |
|---|---|---|
| `event-sourced` | the event payload, and the projection that reads it | events store the tenant, projections rebuild without filtering by it — a replay cross-populates |
| `i18n` | per-tenant overrides of shared catalogs | one tenant's custom strings served to another; override lookup falls back globally |
| `moderation` | the queue and the reviewer's scope | moderators see reports across tenants; ban applied globally from a single-tenant report |
| `payment` | the PSP customer/account mapping | one PSP account for all tenants, so refunds and disputes cannot be attributed; webhook maps to the wrong tenant |
| `scheduling` | availability and conflict detection | slot conflicts computed across tenants, leaking booked times; calendar invites expose other tenants' attendees |
| `streaming-delivery` | the signing key and the entitlement check | one signing key for all tenants — a valid URL from tenant A plays tenant B's asset |
| `subscriptions` | the plan/entitlement lookup | entitlements resolved by user id alone, so a user in two tenants gets the union of both plans |
| `workflow` | the transition guard | state machines transition on a row fetched without scope; approval by a foreign-tenant actor |

**N/A with reason**

| Surface | Reason |
|---|---|
| `rate-limiting` | keys are already required to be tenant-scoped by the `rate-limiting` domain's own rule |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where the anchor lives** | authenticated context → repository filter | never client state; the server derives it | never device state; survives account switch | the credential profile in use |
| **The classic miss** | one query in a job or report without the filter | tenant id in a URL param the client can edit | cached tenant data survives switching accounts | a profile flag defaulting to the last-used tenant |

> `browser` and `mobile` are never the enforcement point. A finding there reads "the server
> accepts a client-supplied tenant", never "scope it on the client".

## Closure verbs

`scope-at-repository` · `derive-anchor-from-context` · `partition-signing-key` ·
`filter-on-projection` · `report-the-ratio`
