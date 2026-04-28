# Social — feature checklist

The 80%-of-projects-need-this list. Most social v1s ship without trust + safety scaffolding, then learn it the hard way when first abuse incident hits.

Use this in `business-auditor` reviews + as a P1/P2/P3 planning anchor.

## User-facing

### Identity + onboarding
- [ ] Email + phone signup (at least one verified channel before posting).
- [ ] SSO (Apple required on iOS app; Google for web).
- [ ] Handle reservation list (admin, support, help, official names, etc.).
- [ ] Handle change with redirect history (old @handle → new @handle for N days; prevents impersonation by squatting freed handle).
- [ ] Profile photo + banner upload with crop.
- [ ] Bio with link (one outbound link is industry norm; multi-link via "linktree" pattern).
- [ ] Pronouns field (optional, free-text + curated picker).
- [ ] Birth date (gated for age-of-majority compliance — see compliance.md).
- [ ] Email change with re-verification.
- [ ] Account deletion with grace period (typically 30 days).

### Posting + media
- [ ] Text post with character limit shown live.
- [ ] Single image upload + multi-image (carousel).
- [ ] Video upload with size + duration limit + transcoding pipeline.
- [ ] GIF support (giphy/tenor integration or native).
- [ ] Alt text field for images (a11y + indexable).
- [ ] Visibility selector (public/followers/circle).
- [ ] Schedule post for later (P2).
- [ ] Drafts list.
- [ ] Edit post with edit history visible (or replace + indicate "edited").
- [ ] Delete post with confirmation + retention warning.
- [ ] Repost / quote-post UI.
- [ ] Threaded posts (multi-post chains by same author).

### Feed + discovery
- [ ] Home feed with infinite scroll (cursor-based pagination).
- [ ] Pull-to-refresh.
- [ ] Reverse-chrono toggle (algorithmic feed default; user can switch).
- [ ] "New posts above" indicator without auto-jumping (UX).
- [ ] Empty-feed state with suggested follows.
- [ ] Hashtag pages.
- [ ] Trending section (per region + global).
- [ ] Search across people, posts, hashtags.
- [ ] Search filters (date range, language, has-media).
- [ ] Saved posts / bookmarks (private to user).
- [ ] Recently-viewed history (private; for jump-back).

### Engagement
- [ ] Reactions (single emoji or multi-emoji set).
- [ ] Comments with nesting (1-2 levels typical).
- [ ] Comment soft-delete + author/mod-delete.
- [ ] Comment pinning by post author.
- [ ] @mention auto-complete in compose.
- [ ] # hashtag auto-suggestion.
- [ ] Share to DM / link copy / external share sheet.
- [ ] Reaction list on post (who liked).
- [ ] Comment list with sort (newest/most-liked).

### Social graph
- [ ] Follow / unfollow.
- [ ] Follower list + following list (privacy: own visible to self always; others visible per-user policy).
- [ ] Followers/following count on profile.
- [ ] Mutual follows indicator.
- [ ] Suggested follows (collaborative filtering).
- [ ] Find friends (contact import — opt-in, GDPR-compliant).
- [ ] Block / unblock with confirmation.
- [ ] Mute (one-way, silent).
- [ ] Restrict (silent comment-hiding from blocked-but-not-quite).
- [ ] Block list view + bulk unblock.

### Notifications
- [ ] In-app notification list with unread state.
- [ ] Push notifications (FCM + APNS).
- [ ] Email digest (opt-in; daily/weekly).
- [ ] Per-event-type granular controls.
- [ ] Mute conversation (no notifs from a comment thread).
- [ ] Mark-all-read.
- [ ] Notification grouping ("X and N others liked your post").

### Privacy + safety
- [ ] Public/private account toggle.
- [ ] Per-post visibility override.
- [ ] Tag approval (require approval before others can tag me).
- [ ] DM filter (only allow DMs from people I follow / verified / nobody).
- [ ] Content controls (hide sensitive media; gate adult content; strict/moderate/none).
- [ ] Two-factor auth (TOTP + backup codes).
- [ ] Session list with revoke.
- [ ] Login alerts (new device).
- [ ] Account recovery via email + phone + trusted contacts.

### Reporting
- [ ] Report post / comment / user / DM with reason picker.
- [ ] Self-harm-content reporting → routes to crisis resources, not regular moderation.
- [ ] Report status visibility (acknowledged → reviewed → actioned/dismissed).
- [ ] In-app appeal of moderation actions taken against you.

## Operator-facing (admin / moderation)

### Moderation queue
- [ ] Report queue with filters (severity, type, author history).
- [ ] Auto-triage rules (URL blocklist, hash-matched media, slur lists).
- [ ] Reviewer UI with content preview, history, prior reports.
- [ ] Action buttons: dismiss / hide / remove / strike / suspend / ban.
- [ ] Action requires reason + tag (audit trail + appeal evidence).
- [ ] Bulk action for spam waves.
- [ ] Moderator notes per user.
- [ ] Moderator-only view of removed content (with redactions to protect reviewer mental health for severe content).

### User management
- [ ] User search by handle / email / phone / IP.
- [ ] User detail: posts, follows, follows-by, reports against, prior strikes, sessions.
- [ ] Suspend with duration + reason + notify user.
- [ ] Permanent ban with appeal toggle.
- [ ] Shadow ban (limited reach without notice — controversial; document if used).
- [ ] Email/phone block list.
- [ ] IP / device block list.

### Verification
- [ ] Verification request review queue.
- [ ] Identity document review (with GDPR-compliant retention).
- [ ] Approve / deny / request-more-info.
- [ ] Revoke verification.

### Trends + content curation
- [ ] Trending hashtag list with manual override.
- [ ] Hashtag block (cannot be used for trending or search).
- [ ] Editorial featured-content management.
- [ ] Geo-restricted content list (legal compliance per country).

### Reports + analytics
- [ ] DAU / MAU / WAU.
- [ ] Posts per day, reactions per day, comments per day.
- [ ] Retention cohorts.
- [ ] Top creators / top engaged-with content.
- [ ] Report volume by category.
- [ ] Time-to-action SLA on reports.
- [ ] Block / mute rates per user (anomalies = abuse signals).

## Trust + compliance

- [ ] Privacy policy + terms of service + community guidelines + cookie policy.
- [ ] Age gate (COPPA in US, similar in EU/UK; under-13 blocked or parent-approved).
- [ ] DMCA takedown process documented + endpoint.
- [ ] DSA transparency report endpoints (EU — required for VLOPs but good practice).
- [ ] Right-to-erasure handler (GDPR Article 17).
- [ ] Data export (GDPR Article 20).
- [ ] Audit log of admin actions (who suspended whom, when, why).
- [ ] Two-person review for permanent bans.
- [ ] Crisis resources page (suicide hotlines, abuse hotlines) — linked from self-harm reports.

## Operational

- [ ] Push token cleanup on bounce.
- [ ] Image / video moderation pipeline (CSAM detection mandatory).
- [ ] CDN for media with signed URLs that expire.
- [ ] Real-time websocket scaling (sticky sessions or pub/sub backbone).
- [ ] Feed generation backpressure (celebrity post fanout queue depth).
- [ ] Search index update lag SLO.
- [ ] Backup of user data + media (separate retention policies).
- [ ] On-call for moderation incidents (something will go viral wrong on a Saturday).

## Things v1s commonly miss

- Block-leak-via-mutual-friends (A blocks B; A's reply on C's post visible to B in C's thread). See anti-patterns.
- Tag approval (anyone can attach you to anything; reputational damage by association).
- Notification debouncing (10 likes in a minute = 10 push notifs; user mutes app).
- Hashtag squatting (popular tag claimed by spam; no manual override).
- Reserved handle list (users grab @support, @admin, impersonation chaos).
- Handle-change redirect (old handle freed → grabbed by impersonator).
- Deleted-user-content cleanup (orphan posts, comments referencing dead user).
- Account deletion grace period (instant delete = irreversible mistake; 30 days gives recovery).
- DM filter for new accounts / unfollowed senders (spam DM flood).
- Visibility re-check on read (post made public → made private; cached feeds still leak).
- "Why am I seeing this?" affordance (DSA requirement EU; good practice everywhere).
- Two-factor backup codes (users lose phones constantly).
- Push notification PII redaction (lockscreen leaks "Sarah said: ...").
- Self-harm content routing (default moderation queue is wrong for crisis).
- Crisis resources surfaced contextually.
- Audit log on moderation actions (no log = no appeal = lawsuit).
- Reposting respecting visibility of original (private post quoted publicly = privacy breach).

## Things often over-built in v1 (defer until validated)

- Algorithmic feed ML (hand-tuned chronological + light recency weighting works fine for first 100K users).
- Live video.
- Voice rooms / audio social.
- Stories (proven pattern but heavy infra; defer if not core to thesis).
- Federation / ActivityPub (unless that's the differentiator).
- Multi-language UI (English-first if user base is English-first).
- Subscription tiers / paid follows.
- Creator monetization (tipping, ads share).
- Custom emoji / sticker marketplace.
- Voice transcription on video posts.
