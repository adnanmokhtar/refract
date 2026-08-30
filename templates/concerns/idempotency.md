---
name: idempotency
description: Cross-cutting replay-safety rules — running it twice must equal running it once, on every surface that can retry
kind: rule
concern: C9
---

# Idempotency

## Hard rule

Any operation that can be delivered, retried, or clicked more than once MUST produce the same
effect as being performed once. The key MUST be derived from business identity — not from the
attempt number, not from a timestamp, not from a random value generated per attempt. A key that
changes on retry is not an idempotency key; it is a duplicate generator with extra steps.

The scale-lens already carries one idempotency detector (#11) scoped to write endpoints. This
concern is the same logic applied to every surface that can replay, which is most of them.

## Per-surface fingerprints

| Surface | The replay source | Typical finding |
|---|---|---|
| `admin` | double-submitted destructive actions | "delete user" fired twice deletes a second, re-created user; impersonation session re-entered leaves two audit trails |
| `ai` | retried LLM calls after timeout | the call times out client-side, succeeds server-side, retries — double-charged tokens and two side effects from one agent turn |
| `audit-log` | at-least-once event delivery into the trail | the same action recorded twice, breaking the hash chain's meaning as a count |
| `caching` | concurrent refill after eviction | stampede fills the same key N times; a fill that writes through to the origin duplicates the write |
| `file-upload` | resumed / retried multipart uploads | the same file stored N times under N keys; the dedup check hashes the request, not the content |
| `i18n` | re-imported catalogs | a re-run import duplicates keys instead of upserting, so the last writer silently wins per key |
| `multi-tenant` | replayed provisioning | tenant onboarding re-run creates a second schema/row set; the first is orphaned and still queryable |
| `settings` | concurrent writes to the same key | last-write-wins on a settings merge loses one of two concurrent changes with no conflict signal |
| `streaming-delivery` | retried key/licence requests | each retry issues a new licence, so revocation must chase N licences instead of one |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **The replay source** | at-least-once queues, client retries, webhook redelivery | double-click, navigation re-fire, offline-queue flush | tap-spam, retry-on-network-recover, background refresh | a re-run of the same command, a shell loop, CI retry |
| **Where the key comes from** | business identity in the request | a submission token minted once per form instance | a client-generated stable id persisted across restarts | a deterministic key from arguments, so `--dry-run` matches the real run |
| **The classic miss** | key derived per attempt | button disabled instead of the request made idempotent | key regenerated on app restart | a command that appends instead of upserting |

## Closure verbs

`derive-stable-key` · `upsert-not-insert` · `record-side-effect` · `dedup-on-content-hash` ·
`single-flight` · `reissue-not-duplicate`

Disabling the button is not a closure. The server must be safe when the button is clicked twice
anyway, because the network will do it for the user eventually.
