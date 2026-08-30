---
name: versioning
description: Cross-cutting compatibility rules — every surface with a consumer must be able to change without breaking it
kind: rule
concern: C10
---

# Versioning / Compatibility

## Hard rule

Every surface that has a consumer it does not deploy MUST be able to change without breaking that
consumer. That requires three things and all three are load-bearing: a **declared contract**, a
**breaking-change definition**, and a **path for the old consumer to keep working** while it
migrates. A surface with a contract but no migration path has versioning theatre — the version
number increments and consumers break anyway.

The consumer need not be external. A mobile app the user has not updated, a queue consumer on the
previous deploy, and a cached client bundle are all consumers you do not control.

## Per-surface fingerprints

| Surface | The consumer you do not deploy | Typical finding |
|---|---|---|
| `admin` | saved views, bookmarks, scripts admins wrote | renaming a filter or column silently breaks saved views with no deprecation signal |
| `feature-flags` | every code path reading the flag | a flag's values change meaning (boolean → enum) with old readers still live; removal without a grep for readers |
| `forms` | in-flight drafts and resumable submissions | a schema change orphans drafts saved under the old shape; no version stamp on the draft |
| `import` | the file formats customers already generate | column renamed with no alias period, so every customer's existing template breaks at once |
| `real-time` | connected clients on the previous deploy | message shape changed mid-connection; old clients receive fields they cannot parse and silently drop events |
| `settings` | stored values written under an older schema | a settings key's type changes with no migration, so old rows fail validation on next write |
| `streaming-delivery` | players already holding a manifest | manifest or key-delivery shape changed while sessions are live; players cannot recover mid-playback |
| `webhook` | every receiver you have ever registered | payload field removed with no version negotiation; receivers have no way to pin |

## The breaking-change definition

Record it once, then review against it rather than against taste:

```
BREAKING: removing a field · narrowing a type · adding a required input ·
          changing the meaning of an existing value · tightening validation
NON-BREAKING: adding an optional field · widening a type · adding a new value
              to an open enum (if consumers were told the enum is open)
```

A project that has not written this down has one finding — *the definition is undeclared* — and
every disagreement downstream is a consequence of it, not a separate finding.

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **The uncontrolled consumer** | other services, queue consumers on the old deploy | a cached bundle from before the deploy | the version in the store, plus the one users refuse to update | scripts and CI pipelines calling the command |
| **The migration path** | version the route, dual-write, deprecation headers | serve both shapes until the cache TTL expires | forced-update floor, plus a server that supports N-2 | keep the old flag as an alias with a deprecation warning |
| **The classic miss** | breaking a queue message shape mid-rollout | assuming every client reloaded | a server change that bricks the shipped app | renaming a flag; every CI pipeline breaks at once |

## Closure verbs

`version-the-contract` · `alias-the-old-name` · `dual-write` · `stamp-the-stored-shape` ·
`declare-breaking` · `set-support-floor` · `negotiate-on-connect`
