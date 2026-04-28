# Social — domain-specific anti-patterns

Generic code review (DRY, SRP, etc.) misses these. They're traps you only learn from harassment incidents, viral abuse, or regulator visits.

## Feed + fanout

- **Naive fan-out on write for high-degree users.** Celebrity with 5M followers posts → 5M inserts blocking the publish path → write storm + cache thrashing. Use threshold-based hybrid: fan out below N followers, pull-on-read above. Track follower count on user row to dispatch correctly.
- **Fan-out before commit.** Post inserted, fanout dispatched, commit fails → followers see ghost post that doesn't exist. Fan out from a post-commit event (outbox pattern).
- **Visibility cached at fanout time.** Post made public → followers see it → author flips to private. Cached feed entries still leak. Re-check visibility on read OR invalidate fanout caches on visibility change.
- **OFFSET pagination on feed.** Feed mutates between page loads → page 2 has duplicates from page 1 + skips items. Use cursor on `(created_at, id)`.
- **Cold-start empty feed.** New user has no follows; empty feed; bounces. Curate "starter pack" of recommended follows + show explore tab as default until they have N follows.
- **Algorithmic feed without reverse-chrono escape hatch.** DSA requires it; users want it; trust collapses without it.
- **Recommendations not respecting blocks.** "People you may know" suggests user you blocked. Block list filtered into all recommendation pipelines.

## Privacy + visibility

- **Block leak via mutual visibility.** User A blocks B. A replies on C's post. C is followed by both. B sees A's reply. Block must apply across all read paths — feed, search, profile, comment threads, mention auto-complete, mutual-friend lists, notifications. Document the matrix; test it.
- **Mute leaking via notification.** A muted B but still notified when B comments on A's post. Define mute scope clearly.
- **Private account post quoted publicly.** Public user quote-tweets a private account's post. Quote must respect source visibility — strip content if quoter cannot resolve the original at render time.
- **Followers list visible to non-followers of private account.** Private account = profile content private + followers list private (typical norm). Reveal selectively.
- **Tag visibility on private posts.** Tagged user sees post in their tagged-photos page even if they don't follow author. Document policy + comply consistently.
- **DM history exposed via account-recovery path.** "Recover account" sends DMs to an attacker email. Recovery must require MFA or significant friction for accounts with sensitive data.
- **Address book uploaded without retention limit.** "Find friends" feature stores entire phonebook indefinitely. GDPR data minimization violation; delete after match attempt.
- **Read receipts on by default for DMs.** Toggle defaults to "more visible." Privacy-preserving default = off, opt-in.

## Notifications

- **PII in push notification body.** Lockscreen shows "Sarah said: Here's my address: 123 Main St". Truncate + redact in transit; load full content only when app is opened with biometric.
- **No debounce.** 50 likes in 30 seconds = 50 push notifications + 50 in-app banners. Group by (recipient, target, event_type) within window.
- **Self-notification.** User reacts to own post → user notified about own action. Filter actor == recipient at insertion.
- **Notification storm on viral post.** Post goes viral → millions of notifications fanned out → push infrastructure cap → other notifications drop. Rate-cap per user; tail-drop or aggregate.
- **Tagged notification spamming.** Bad actor tags user in 100 posts an hour. Rate-limit tagging + tag-approval setting.
- **Push delivery without consent.** First notification sent before user allowed it. Enforce consent flow before any push.
- **Bouncing tokens not pruned.** Invalid push tokens accumulate → eventual quota exhaustion. FCM/APNS bounce → mark token invalid → retry next sign-in.

## Moderation + reports

- **Silent shadow-ban with no audit.** User's posts not appearing in feed; user doesn't know; angry. Either inform user OR don't shadow-ban. Document policy.
- **Reports pile up; no SLA.** Hate content lives 3 weeks → screenshots → news → fire. Set tiered SLA by severity; prioritize CSAM + violence + self-harm.
- **Auto-action without review on first report.** One bad-faith report removes content. Threshold reports OR human review for consequential actions.
- **Self-harm reports going to spam queue.** Crisis category routes to general moderation → buried. Specialized routing + crisis resources surfaced to reporter.
- **Reportee notified of reporter identity.** Retaliation. Reports anonymous to reportee; reasons aggregate ("multiple users reported").
- **Blocked-user content visible to mods only.** Mods need full context including blocked content.
- **No appeal.** User suspended; can't argue; sues. Required by DSA + general due process.
- **Mod actions not audit-logged.** Inconsistent moderation; no defense against discrimination claims; no internal QA possible.
- **Mod can action friends.** Conflict of interest; tampering. Block actions on accounts mods previously interacted with publicly.

## Account + identity

- **Handle change frees old handle immediately.** Squatter grabs `@elonmusk` after Elon switches handles → impersonation. Reserve old handle for redirects + N-day cooldown.
- **Reserved handle list missing.** Bad actors grab `@admin`, `@support`, `@official_help`. Maintain blocklist + verify-only handles.
- **Email changed without re-verification.** Account hijacker changes email + locks out original owner. Re-verify both old + new email.
- **Phone-only recovery.** SIM-swap attack → account takeover. Combine with email + recent device + activity questions.
- **Account deletion instant + irreversible.** Heat-of-moment deletion + remorse. 30-day grace period + recovery during window.
- **Deleted user content not handled.** Posts orphaned, mentions of deleted user broken, comments referencing them point to a 404. Decide: anonymize-in-place vs cascade-delete vs hide-but-keep — and apply consistently.
- **Verification documents stored permanently.** GDPR violation; delete after verification or pseudonymize.
- **Suspension without TTL on data export.** Suspended user can't export their data; GDPR right-to-portability blocked.

## Posting + content

- **Edit history hidden when consequential.** User edits post after viral spread; original content gone. Show edited indicator + (optionally) edit history.
- **Slug / URL changes break links.** Username in URL changes → all old URLs 404. Redirect old URLs.
- **Hashtag pages indexable + unmoderated.** `/tags/extremist-slogan` indexed by Google, drives traffic, abuse compounds. Either gate hashtag pages from search engines or moderate them.
- **Mention auto-complete leaks blocked users.** Type `@s` and see Sarah whom you blocked. Filter blocks + unfollow + private from suggestions.
- **Mention without rate limit.** Spammer mentions 1000 users in 1 hour. Rate-limit mentions per user per hour.
- **Reposting without quote-context fingerprint.** Original post deleted → repost shows phantom content or "post unavailable". Decide: keep snapshot of repost target OR cascade-delete reposts on original delete.
- **Image upload without server-side validation of mime type.** EXE renamed to JPG → distributed → users phished. Validate magic bytes server-side.
- **Image upload without dimension cap.** 50MP image uploaded → renderer OOM on client + bandwidth bill. Reject or auto-downscale.

## Reactions + comments

- **Reaction insert without dedupe.** User taps like 5 times → 5 reaction rows → count shows 5. Upsert on `(user_id, target_id)`; type update if differs.
- **Reaction count via `COUNT(*)` per render.** Hot post → DB CPU pegged. Denormalize counter on target; reconcile periodically.
- **Counter increment under contention.** Hot post → row lock contention. Use Redis counter with periodic flush; or sharded counter; or async event aggregation.
- **Comment depth unlimited.** Recursive UI overflow + tree-traversal slow. Cap at 1-2 levels.
- **Comment from blocked user appears.** Block applies to feed but not to comment threads on shared posts. Apply consistently.
- **Spam-comment bot with rate limit per user but not per IP.** Botnet bypasses easily. Rate limit per user + IP + device.
- **Like-spam from new accounts.** Inflation of celebrity engagement metrics. New-account engagement weighted lower OR rate-capped.

## Search

- **Search returns blocked / private content.** ElasticSearch index doesn't filter visibility per query. Apply visibility filter at query time, including blocks.
- **Search index lag.** New posts not searchable for 10 minutes. Real-time index ingestion or document the lag in UX.
- **Hashtag normalization mismatch.** `#Coffee` and `#coffee` separate buckets. Lowercase normalize + strip diacritics before storage.
- **Search query log retained with PII.** GDPR + competitive risk. Hash queries + retain limited window.

## CSAM / illegal content

- **CSAM detection only on reported content.** Hosting unreported CSAM = federal crime (US 18 USC 2258A). Hash-scan all media on upload via PhotoDNA/NeuralHash.
- **CSAM detected then deleted.** Evidence destroyed. Preserve + report to NCMEC + suspend uploader, then expunge.
- **NCMEC report not filed.** Mandatory in US. Cyber tipline integration is table stakes.
- **CSAM hashes shared with non-eligible third parties.** Restricted distribution; only NCMEC + law enforcement.

## Trust + safety analytics

- **Engagement-only metric optimization.** "Time spent" optimized → outrage content amplified → retention long-term collapses. Multi-metric balanced scorecard.
- **Recommendation rabbit holes.** Algorithm pushes more extreme content within session. Audit + diversification injection.
- **Coordinated inauthentic behavior undetected.** 1000 fresh accounts following same target. Anomaly detection on signup velocity, IP clustering, action patterns.

## Internationalization

- **Hard-coded English UI.** Globally usable platforms always run RTL + non-Latin scripts; test with Arabic + Hebrew + Tamil.
- **Date formats hard-coded as MDY.** Non-US users confused.
- **Banned content lists English-only.** Detection misses non-English variations (homoglyph attacks, leetspeak in non-English scripts).
- **Geo-blocking via simple country check.** Country lookup wrong for VPN / proxy users; bypassable. Combine signals.
- **No language detection on posts.** Discovery + recommendations cross-pollinate languages users don't read.

## Accessibility

- **No alt-text encouragement.** Most images get no alt-text. Prompt + auto-generate suggestions.
- **No captions on video.** Inaccessible to deaf users + non-native speakers in noise. Auto-caption + editable.
- **Modals trap keyboard focus poorly.** Tab cycles outside modal. Test with screen reader.
- **Color-only state communication.** Like button color change for "liked" state — invisible to colorblind. Add icon variation or label.

## Operational

- **Backup of media inconsistent with DB.** DB references media that's been pruned from backup → broken posts on restore. Backup + retention coordinated.
- **Right-to-erasure not propagated to caches/CDN.** User deletes account; image still served from CDN for hours/days. Invalidate CDN on delete.
- **Right-to-erasure not propagated to backups.** Strict GDPR reading: backups must also delete on next rotation OR documented exception with justification.
- **Real-time websocket reconnect storms.** Brief outage → millions of clients reconnect simultaneously → second outage. Jittered reconnect + backoff.
- **Single moderation queue.** All content types lumped → severe content delayed behind low-severity backlog. Tiered queues by severity.
- **Mod tooling on production data without redaction.** Mods see PII unrelated to case. Need-to-know access + audit log.
- **Test posts visible in production search.** QA's "asdf test post" indexed. Test mode flag + filter from search + feed.
