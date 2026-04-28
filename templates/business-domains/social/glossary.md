# Social — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `social`:

**Entity / model names**: `User`, `Post`, `Reaction`, `Like`, `Comment`, `Reply`, `Share`, `Repost`, `Follow`, `Follower`, `Block`, `Mute`, `Notification`, `Feed`, `Timeline`, `Hashtag`, `Tag`, `Mention`, `Report`, `Abuse`, `Moderation`, `Verification`.

**Folder / route names**: `feed/`, `posts/`, `comments/`, `notifications/`, `users/[handle]`, `following/`, `followers/`, `explore/`, `trending/`, `report/`, `moderation/`.

**Dependencies (any language)**: `mediasoup`, `sharp`, `ffmpeg`, `imagemagick`, `algolia`, `meilisearch`, `pusher`, `pubnub`, `socket.io`, `getstream`, `ably`, `firebase-messaging`, `apn`, `web-push`.

**Database schema**: tables for `posts` + `follows` + `reactions` + `comments` is the strongest signal. Presence of `(follower_id, followee_id)` composite key without a marketplace seller table → social, not affiliate.

**Distinguishing from messaging**: social is broadcast (one-to-many) with public/semi-public visibility; messaging is targeted (one-to-one or group) with private semantics. Posts have `visibility` enum; messages have `recipient_id`. If you see `Conversation` + `Participant` → messaging, not social.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `User` | identity + profile | `id, handle, email, phone, display_name, bio, avatar_url, banner_url, verified, suspended_at, deleted_at` | created → active → suspended/deactivated → soft-deleted → purged |
| `Profile` | user-facing presentation | `user_id, bio, links[], pronouns, location, birth_date, visibility (public/private)` | mutable |
| `Post` | unit of content | `id, author_id, content, media_ids[], visibility (public/followers/circle/private), reply_to_id?, repost_of_id?, language, created_at, deleted_at` | draft → published → edited → deleted (soft) → purged |
| `Media` | attached image/video/audio | `id, post_id?, url, mime_type, width, height, duration?, alt_text, moderation_status` | uploaded → scanned → approved/blocked |
| `Reaction` | emoji/like on a post or comment | `id, user_id, target_type (post/comment), target_id, type (like/heart/laugh/sad/angry), created_at` | ephemeral (delete = unreact) |
| `Comment` | reply on a post | `id, post_id, parent_comment_id?, author_id, body, created_at, deleted_at` | published → edited → deleted |
| `Share` / `Repost` | rebroadcast another user's post | `id, user_id, post_id, quote_text?, created_at` | mutable until deleted |
| `Follow` | directed graph edge | `follower_id, followee_id, status (pending/accepted), created_at` | pending (private accounts) → accepted → unfollowed |
| `Block` | hide both directions | `blocker_id, blocked_id, created_at` | active → unblocked |
| `Mute` | hide their content from my feed (one-way, silent) | `muter_id, muted_id, scope (posts/notifications/all), created_at` | active → unmuted |
| `Notification` | event surfaced to recipient | `id, recipient_id, type, actor_id?, target_type, target_id, read_at?, created_at` | unread → read → dismissed |
| `Feed` | derived timeline for a user | not a row — computed (push/pull/hybrid) | recomputed on read or write |
| `Hashtag` | content categorization | `tag (normalized), post_count, last_used_at, blocked` | mutable |
| `Mention` | @user in a post or comment | `source_type, source_id, mentioned_user_id, position` | created with parent |
| `Report` | abuse signal from a user | `id, reporter_id, target_type, target_id, reason, status, reviewer_id?, decision, created_at` | submitted → triaged → actioned/dismissed |
| `Verification` | identity-confirmed badge | `user_id, level (basic/notable/government), verified_at, verified_by, status` | requested → approved/denied → revoked |
| `Strike` | moderation accumulation | `user_id, severity, post_id?, reason, expires_at, created_at` | active → expired |

## Status state machines

**Post:**
```
draft → published → edited → deleted (soft) → purged (hard, after retention window)
            ↓
        flagged → under-review → restored / removed
```

**Follow (private accounts):**
```
none → pending → accepted → unfollowed
              ↓
           rejected
```

**Report:**
```
submitted → auto-triaged → human-review → actioned (remove/strike/ban) → closed
                       ↓
                   dismissed (no violation)
```

**Notification:**
```
created → delivered (push/email/in-app) → read → archived
                                       ↓
                                    dismissed
```

**User account:**
```
active → suspended (temporary) → reinstated
   ↓                ↓
deactivated     banned (permanent) → appeal → reinstated / final
   ↓
soft-deleted (30-day grace) → purged
```

## Vocabulary distinctions (don't conflate)

- **Block** vs **Mute** vs **Restrict** — Block: bidirectional invisibility + cannot DM. Mute: one-way content hiding, target unaware. Restrict (Instagram-style): target's comments require approval; quieter than block.
- **Follow** vs **Subscribe** vs **Friend** — Follow: directed, asymmetric. Subscribe: paid follow tier. Friend: bidirectional (both must accept) — used by Facebook, not Twitter/Instagram.
- **Share** vs **Repost** vs **Quote** — Share: link out to another platform. Repost: rebroadcast intact (Twitter retweet). Quote: repost with own commentary attached.
- **Reaction** vs **Like** — Like is the binary case (boolean per user); Reaction is multi-valued (emoji set). One Reaction row per (user, target) — flipping type updates, doesn't insert.
- **Feed** vs **Timeline** vs **Stream** — Feed: home feed (you + people you follow + algorithm). Timeline: a user's profile feed (their posts only). Stream: real-time event delivery (websocket).
- **Notification** vs **Activity** vs **Inbox** — Notification: surfaced event ("X liked your post"). Activity: log of all events on a target. Inbox: persistent message store (separate domain).
- **Verified** vs **Trusted** vs **Official** — Verified: identity confirmed (legal name match). Trusted: low strike count, high engagement. Official: business/government affiliation.
- **Soft delete** vs **Hard delete** vs **Purge** — Soft: `deleted_at` set, hidden from feeds, recoverable. Hard: row deleted, content gone. Purge: hard delete + media files + cache eviction + search index removal.
- **Mention** vs **Tag** — Mention: @user in body text. Tag: explicit user pin on media (photo tagging) or location tag.

## Multi-tenancy variants

- **Single-instance social network**: one operator, all users on one graph. Most common.
- **Federated** (ActivityPub / Mastodon / fediverse): each instance a tenant, users on instance X follow users on instance Y via federation protocol. Adds federation entities (`Actor`, `Activity`, `Inbox` with HTTP signatures).
- **White-label community platform** (Circle/Discourse/Mighty Networks): each customer = a tenant; users separated; no cross-tenant graph.
- **Embedded social** (comments-as-a-service like Disqus): tenant = host site; user identity may be SSO from tenant or own account.

## Visibility model

- **Public**: world readable, indexable.
- **Followers-only**: visible to confirmed followers (private account).
- **Circle / Close Friends**: visible to a curated subset.
- **Mentioned-only**: visible only to @mentioned users + author (rare).
- **Private** / **Draft**: visible to author only.

Visibility checks must run on EVERY read path — feed, search, profile, share link, embed, API. Single source of truth: `can_see(viewer, post)`.
