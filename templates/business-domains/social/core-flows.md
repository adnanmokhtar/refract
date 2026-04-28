# Social — core flows

The flows every social product must support. P1 is "without these, you don't have a social product." P2 is "you need these to keep users." P3 is "growth + safety maturity."

## P1 — must-have for v1

### 1. Sign up → onboard → post → see feed
The single most important loop. If posting and feed don't work, no engagement happens.

```
Anonymous user lands
  → sign up (email/phone/SSO) → verify (email link / OTP)
  → onboarding (handle pick, profile photo, suggested follows)
  → home feed renders (mostly empty until they follow people)
  → "Create post" → media upload → text → visibility selector → publish
  → post appears at top of own profile + in feed of followers
  → followers see push notification (if opted in)
  → reactions + comments accrue → notifications back to author
```

Key invariants:
- Handle uniqueness checked at signup (case-insensitive); reserved handles blocked.
- Email/phone verification BEFORE post creation (else spam vector).
- Post creation idempotent on `Idempotency-Key` — accidental double-tap on slow connections is constant on mobile.
- Visibility set BEFORE first follower can be notified — race between insert and notification fanout.
- Author-deletes-immediately-after-post must propagate to followers' caches.

### 2. Follow → unfollow → blocked-state visibility
```
User A → opens user B's profile
  → "Follow" tap (public account: instant; private: pending request)
  → Follow row inserted with status
  → A's home feed now includes B's posts on next refresh
  → A receives notification when B posts (if opted in)
  → A → "Unfollow" → row deleted (or soft-deleted for analytics)
  → B's posts removed from A's feed cache
```

If B blocks A:
- A's existing follow of B → deleted.
- A cannot view B's profile, posts, or any reference (including in mutual friends' replies — see anti-patterns).
- A cannot find B in search.
- A cannot @mention B (or mention is silently broken in display).
- B's notifications from A vanish.

### 3. Feed generation
The defining technical flow. Two strategies + a hybrid:

**Pull (fan-in on read):**
```
User opens feed
  → query: posts WHERE author_id IN (SELECT followee_id FROM follows WHERE follower_id = me)
            AND visibility allows me AND author not blocked-by-me AND I'm not blocked-by-author
            ORDER BY created_at DESC LIMIT 50
  → render
```
Cheap on writes, expensive on reads. Falls over for high-following users.

**Push (fan-out on write):**
```
User publishes post
  → for each follower (potentially 1M+ for celebrities):
       insert into feed_<follower_id> table / Redis sorted set
  → reads are O(1) lookup
```
Cheap on reads, catastrophic on writes for high-degree authors. Storage explosion.

**Hybrid (Twitter pattern):**
- Push for normal users to followers' inboxes.
- Pull for "celebrity" authors (>N followers) — feed merges pulled celeb posts with pushed normal posts at read time.
- Threshold tuned per system; track `follower_count` on user row to switch strategies.

Key invariants:
- Visibility re-checked at read time even if cached (post visibility can change after fanout).
- Blocks re-checked at read time.
- Deleted posts removed from feed within seconds (cache invalidation).
- Pagination: cursor-based on `(created_at, id)` — never `OFFSET` (drift as feed mutates).

### 4. Reactions + comments
```
User taps "like" on post
  → POST /reactions { target_type: 'post', target_id: 123, type: 'like' }
  → upsert (user_id, target_id) — no duplicates per user per target
  → notification to author (debounced — see below)
  → counter increment via async aggregate (don't COUNT(*) on every render)
```

Comments same shape but with body text + nesting (typically max 1-2 levels).

Counter strategy:
- Denormalized `reaction_count` on post row.
- Updated via TypeORM subscriber / DB trigger on insert/delete.
- Reconciled nightly against source of truth.
- For very hot posts: async via queue + batched increments to avoid lock contention.

### 5. Notifications
```
Triggering event (someone reacted/commented/followed/mentioned)
  → notification row inserted
  → delivery channels: in-app (websocket push) + push (FCM/APNS) + email digest (opt-in)
  → debouncing: "10 people liked your post" instead of 10 separate notifications
  → grouping: multiple comments on same post → 1 grouped notification
  → user opens notifications tab → mark read on view
```

Key invariants:
- Debounce window per (recipient, target, event_type) — 5-15 min typical.
- Mute relationship suppresses notifications.
- Block relationship suppresses notifications.
- Self-notifications suppressed (user reacting to own post should not notify self).
- PII never in push payload — see anti-patterns.

## P2 — keep users

### 6. Search (people, posts, hashtags)
- Type-ahead on handle + display name.
- Hashtag pages: posts tagged with #x, sorted by recency or popularity.
- Full-text search on posts (often gated behind verification or premium tier).
- Search respects blocks + mutes + visibility.

### 7. Mentions + tags
- @handle in post body → resolve to user → notify mentioned user.
- Tag friends in photo (coordinates on media).
- Mentioned user can untag self (removes notification + visibility from their tagged-posts page).

### 8. Direct sharing
- Share to DM (separate domain — messaging).
- Copy link (with view permission preserved or stripped).
- Share to other platforms (system share sheet).
- "Forward" / "send to" preserves context (post link + preview).

### 9. Reporting + moderation queue
```
User taps "Report" on post/comment/user
  → reason picker (spam / harassment / hate / illegal / other)
  → optional context text
  → report row inserted with status=submitted
  → auto-triage: if matches known-bad signature (URL blocklist, image hash), auto-action
  → else: routed to moderator queue
  → moderator reviews → action (none/remove/strike/ban) + reason logged
  → reporter notified of decision (no specifics — abuse vector)
  → reportee notified if actioned
  → user with N strikes within window → escalating action (warn / suspend / ban)
```

### 10. Block / mute management
- Block list management UI (view/unblock).
- Mute list with scope filter.
- Bulk-block from a thread (mute everyone in a comment chain).

## P3 — competitive

### 11. Algorithmic feed
- Ranking signals: recency, engagement velocity, author affinity (do you usually like this person), session signals.
- A/B testing framework for feed variants.
- "Why am I seeing this?" transparency (DSA-required in EU).
- Reverse-chrono toggle (DSA + user trust).

### 12. Verification
- Self-serve verification request → identity check (gov ID, domain proof, etc.).
- Tiered: notable (public figure), business, government.
- Revocation path (impersonation evidence).

### 13. Stories / ephemeral content
- 24-hour TTL.
- View tracking (who saw your story).
- Replies turn into DMs (or are inline depending on platform).
- Privacy: close friends list, exclusion list.

### 14. Live video / streaming
- Separate ingest pipeline (RTMP/SRT) → transcoder → CDN.
- Live chat overlay (high message rate; rate-limit + filter).
- Recording + replay.

### 15. Trending / explore
- Hashtag trends (rate of use over baseline).
- Per-region trends (geo).
- Editorial curation layer (manual override for safety).

### 16. Account portability / data export
- Export all user data as ZIP (GDPR + general user trust).
- Migrate followers (where possible — federated) or post archive.

## Idempotency-critical endpoints

- `POST /posts` — accidental double-submit on flaky connection. Idempotency-Key required.
- `POST /reactions` — upsert on (user_id, target_id, type); delete = unreact. Re-tap is a toggle, not a duplicate.
- `POST /follows` — re-following must be a no-op, not duplicate row.
- `POST /reports` — re-reporting same target should not create N rows; coalesce or 409.
- `POST /notifications/mark-read` — idempotent by definition.

## Fanout / write-amplification budgets

- "Normal user" follower threshold: typically <10K — full fanout on publish.
- "Celebrity" threshold: 10K-1M — selective fanout to active users only, lazy-pull for rest.
- "Mega-celebrity": >1M — pure pull at read time.
- Tunable per system; observed in real ops at Twitter/Instagram scale.

## Webhooks the system must produce

- `post.published`, `post.edited`, `post.deleted`.
- `user.signed_up`, `user.deleted`.
- `follow.created`, `follow.deleted`.
- `report.actioned`.
- `moderation.content_removed`.

## Webhooks the system must consume

- Push provider (FCM/APNS): delivery receipts, invalid token cleanup.
- Image moderation provider (Hive, Sightengine, Rekognition): scan results.
- Identity verification provider (Onfido, Persona): verification decisions.
- Email provider: bounce + complaint signals.
