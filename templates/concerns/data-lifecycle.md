---
name: data-lifecycle
description: Cross-cutting retention and deletion rules — how long data lives on each surface, and who deletes it
kind: rule
concern: C11
---

# Data Lifecycle / Retention

## Hard rule

Every store of data MUST have a **named owner, a stated lifetime, and a mechanism that enforces
that lifetime**. Data with no stated lifetime is retained forever by default, and forever is the
one retention policy that is never deliberately chosen — it is what happens when nobody decides.
A surface that writes data and cannot answer *"how long does this live and who deletes it"* has a
finding, regardless of whether anything has gone wrong yet.

This is distinct from **C7 Compliance**, which asks *which regime binds this data*. Lifecycle asks
the mechanical question underneath it: is there code that actually removes the data, and does it
run. A GDPR policy document with no deletion job is a compliance claim with a lifecycle gap.

## Why this concern had no home

Measured, not asserted: `Data Lifecycle` was empty on **13 of 35 surfaces** in the first matrix
build — the widest gap by `severity × surfaces` of any of the 12 concerns. Retention was reviewed
where a domain happened to mention it (`compliance`, `audit-log`, `data-pipeline`) and nowhere
else, because a concern with no file cannot ship a detector.

## Per-surface fingerprints

Universal logic, concrete shape per surface. Rows are the surfaces the first matrix build found
empty for this concern.

| Surface | What to look for | Typical finding |
|---|---|---|
| `analytics` | event tables / warehouse loads with no TTL or partition-drop job | raw event rows retained indefinitely; PII in events outlives the consent that permitted it |
| `ab-testing` | assignment + exposure tables written per user per experiment | exposure logs for concluded experiments never dropped; assignment table grows unbounded |
| `ai` | prompt / completion / embedding logs, eval traces | prompts persisted verbatim with user content and no retention window; embeddings outlive the source row they were derived from |
| `feature-flags` | per-user targeting records, flag evaluation logs | evaluation logs unbounded; targeting lists retain users deleted elsewhere |
| `forms` | draft / partial submissions, uploaded attachments | abandoned drafts never expire; attachments orphaned when the submission is deleted |
| `i18n` | translation memory, user-submitted locale content | superseded catalog versions accumulate; no policy for user-contributed strings |
| `media-processing` | source uploads, derived renditions, thumbnails | derivatives survive deletion of the original — the classic orphan; EXIF-bearing originals kept after the stripped copy is served |
| `multi-tenant` | per-tenant data on offboarding | no tenant-deletion path at all, or one that misses the 125 entity files outside tenant scope; "deleted" tenant rows still queryable |
| `notifications` | delivery logs, message bodies, device tokens | message bodies retained with full content; stale device tokens never pruned |
| `public-api` | request/response logs, API-key usage records, webhook delivery history | request bodies logged and retained; revoked keys' usage history kept indefinitely |
| `scheduling` | past appointments, cancelled slots, recurrence expansions | materialised recurrence rows expand without bound into the future and are never trimmed in the past |
| `search` | indexed documents, query logs | index retains documents deleted from the source of truth — the deletion-lag leak; query logs retain user text |
| `webhook` | inbound payload archive, delivery attempt history | full payloads retained for replay long past the replay window |
| `_database` | soft-delete columns, archive tables, orphan rows | `deleted_at` set and never hard-deleted; archive tables with no drop policy; rows orphaned by a missing cascade |

**N/A with reason** — surfaces where this concern has no meaningful fingerprint:

| Surface | Reason |
|---|---|
| `rate-limiting` | counters are inherently windowed; the TTL *is* the mechanism |
| `caching` | bounded TTL is already a hard rule of the `caching` domain — reviewing it here double-counts |

## Per-`project_kind` rendering

Phase 5. The concern's *logic* is universal; the *fingerprint* adapts to the shape of the project,
exactly as the 13 scale-lens detectors in [`commands/audit.md`](../../commands/audit.md) already
do. Columns are the closed set from [`packs/_project-kind.md`](../packs/_project-kind.md) —
`browser | server | mobile | cli`, never the `frontend-*` / `backend-*` prose families, which
nothing emits.
| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where data outlives its purpose** | tables, object storage, log sinks, warehouse loads | `localStorage` / `IndexedDB` / service-worker caches never evicted | on-device SQLite, cached media, keychain entries surviving logout | temp files, `~/.cache`, credential files written on first run |
| **Deletion mechanism** | scheduled job / partition drop / cascade | explicit `clear()` on logout and on version change | `onLogout` wipe + OS-level backup exclusion | documented `--purge`; XDG-correct paths so the OS can reclaim |
| **The classic miss** | soft-delete set, hard-delete never written | user "logs out", their data stays in the browser | app uninstall leaves cloud-backed copies | cache grows unbounded; no size cap, no eviction |

> `cli` is not N/A here. A CLI that writes a credential file with no documented lifetime has the
> same finding as a service with no retention job — smaller blast radius, identical shape.

## Closure verbs

`declare-retention` · `add-expiry-job` · `cascade-delete` · `prune-orphans` · `partition-drop` ·
`redact-in-place` · `document-owner`

Every fix names the **owner** and the **lifetime**, and ships the mechanism that enforces it. A
retention policy added to a document with no scheduled job is not a closure — it is the finding
restated.
