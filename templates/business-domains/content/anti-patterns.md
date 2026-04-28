# Content — domain-specific anti-patterns

Generic CMS/blog code review misses these. They're publishing-specific traps — legal, deliverability, SEO, ethical — that kill trust and traffic.

## Timezones + scheduling

- **`published_at` stores scheduled time, actual publish later.** Scheduled 9:00am; cron runs 9:04am; feeds show 9:00 while analytics logs 9:04. Keep `scheduled_at` + `actual_published_at` separately.
- **Scheduled publish across DST.** Article scheduled Sunday 2am during spring-forward; time doesn't exist; publish never fires or double-fires. Store `timezone` alongside timestamp; re-compute on DST transitions.
- **Timezone UX ambiguous.** "Publish at 5pm" — whose 5pm? Editor assumes local; server assumes UTC. Display TZ explicitly on every datetime input.
- **Embargo lifts early/late.** Cron granularity 5 minutes; scheduled for 9:00:00; lifts at 8:55 or 9:05. Hard-check at request time (if `embargo_until > now`, 404) + let cron be catch-up.

## Revisions

- **Every keystroke = 1 revision row.** 1000 revisions per article; DB bloat; UI unusable. Coalesce within 5-min window + snapshot on explicit save OR publish.
- **Revision revert overwrites current.** History lost. Revert = forward-copy; new revision.
- **Revision diff on HTML shows whitespace/formatting noise.** Useless to editor. Diff on normalized form OR render side-by-side.
- **Published revision not marked.** Can't tell which revision went live when. Flag or separate table.
- **Reverting doesn't re-publish.** Reverts current draft; live article still old version. Explicit republish action.

## Slugs + URLs

- **Slug auto-generated from title on every save.** Title changes, slug changes, URL breaks. Generate once, manual override, lock on publish.
- **Slug collision silently suffixes unique.** Editor thinks they have clean URL; actually `/post-3`. Warn + offer alternatives.
- **Slug change without 301.** SEO + external links dead. Auto-301 on slug change; redirect map.
- **Category slug changes cascade break URLs.** Moving articles between categories breaks URLs. Canonical path choice (flat vs nested) + redirects.
- **Pagination URLs unindexed or indexed as duplicates.** `?page=2` variant + all. Canonical strategy + rel=next/prev (deprecated but still noted).
- **Uppercase vs lowercase in URL.** `/About` + `/about` = duplicate content. Canonicalize.
- **Trailing slash vs no trailing slash.** Both working = duplicate content. 301 to canonical.

## Copy-paste + editor hygiene

- **Copy-paste from Word embeds MS Office CSS garbage.** Breaks layout + bloats HTML. Paste-as-plain or sanitize.
- **Copy-paste from Google Docs includes styles.** Similar. Sanitize.
- **Copy-paste images embeds base64.** Huge HTML + unindexed for SEO. Upload to asset lib + reference.
- **Rich text toolbar allows `<script>`.** XSS in published articles. Allowlist tags.
- **Copy-paste from other articles duplicates content.** Google penalty. Duplicate detection.

## SEO

- **No canonical URLs.** Syndication + tag pages = duplicate content penalty. Canonical tags on all.
- **No structured data.** Missing rich results. Add Article/NewsArticle + BreadcrumbList + Person.
- **Meta description absent.** Google synthesizes; often wrong. Auto-populate from excerpt + allow override.
- **Page title not different from H1.** Title tag IS important. Editable separately.
- **Slug with special chars.** `/article-title-%27s-story` — browser encoding + share friction. Kebab-case; ASCII.
- **Sitemap doesn't rebuild on publish.** New article not indexed for days. Event-driven regen + ping Google.
- **Sitemap includes drafts / unpublished.** Leak + Google confusion. Filter.
- **Feed includes scheduled/draft.** Same leak.
- **No hreflang for multi-language.** Spanish + English versions competing. hreflang alternates.
- **Image alt text auto-generated from filename.** `IMG_4532.jpg` → "IMG 4532". Mandatory alt text prompt.
- **Image alt text stuffed with keywords.** Google penalty + a11y fail. Educate editors.
- **Article URLs with trailing date.** `/2019/10/article-title/` — when republished/updated, URL still says 2019. Choose pattern: date or no date.

## Comments

- **Comment markdown → HTML without sanitization.** XSS trivial. DOMPurify / strict sanitizer.
- **Comment links without `rel=nofollow ugc`.** SEO spam magnet + penalty. Enforce rel attributes.
- **Comment email not verified.** Impersonation trivial. Double-opt-in OR disallow anonymous.
- **Reply notifications not rate-limited.** Harasser triggers 1000 notifications. Rate limit per thread / per user.
- **Blocked IP bypass via VPN.** Account-level + IP + fingerprint + invasive.
- **Comment deleted = hard delete.** Lost thread context; replies orphan. Soft-delete with "comment removed" placeholder.
- **No harassment reporting flow.** Users leave. Report + moderation + escalation path.
- **Editor can't delete without blocking user.** Fine-grained actions missing.
- **Comment preview before post absent.** Typos forever (no edit or limited).

## Newsletter / email

- **Unsubscribe requires login.** Against CAN-SPAM + deliverability. One-click, no login.
- **Unsubscribe button in email leads to 404 or landing page.** Fail + complaint rate spike. Test in every send.
- **List-Unsubscribe header missing.** Gmail/Yahoo 2024 bulk-sender: emails to spam. Required.
- **List-Unsubscribe-Post not set.** Similarly required for one-click.
- **No double opt-in.** Spam complaint rate rises; blacklisted. Default opt-in.
- **No SPF / DKIM / DMARC.** Spam + spoofing. Mandatory for sender domain.
- **Hard bounces not suppressed.** Same bad address retried → ESP reputation tanks. Auto-suppress on hard bounce.
- **Soft bounces retried forever.** Eventually blocklisted. Backoff + threshold-based suppression.
- **Complaint (spam report) not immediately suppressed.** Continuing to email = ESP shutoff. Immediate suppress.
- **Subscriber imported without consent proof.** CASL/GDPR violation. Proof of consent for every subscriber.
- **Preheader text absent.** Inbox preview shows random content (first line of HTML). Explicit preheader.
- **Email renders broken in Outlook.** Outlook uses Word rendering; modern CSS breaks. Table layout + MJML + test.
- **Email too-heavy image-to-text ratio.** Spam filters + a11y + clipping. Mix text + images.
- **Images without alt text in email.** Blocked images = blank space. Alt text fallback.
- **No text/plain version.** MIME multipart required; plain-text fallback. Generate auto.
- **Subject line A/B winner auto-applied; B still sending.** Configuration bug. Atomic switch.
- **From name "noreply".** Poor engagement; consider a person's name for open rate.
- **"No reply" address rejects feedback.** Missed customer signal. Monitor replies.

## DMCA / takedowns

- **No DMCA agent registered.** Safe harbor void. Register with US Copyright Office.
- **Takedown email alias unmonitored.** Claim ages; lawsuit. Dedicated intake + SLA.
- **Automated takedown without verification.** Anyone can DMCA-bomb a competitor. Verify claim + good-faith check.
- **Counter-notice absent.** User's legitimate content removed permanently; safe harbor weakened. Proper counter-notice path.
- **No repeat-infringer policy.** Safe harbor clause broken. Track + terminate offenders.
- **Takedown removes but doesn't notify uploader.** User angry, trust lost. Notify + explain + counter-notice option.
- **Legal hold doesn't prevent hard delete.** Evidence destroyed. Legal hold flag respects deletion.

## Accessibility

- **Alt text "image" or filename.** WCAG fail + SEO waste. Require meaningful alt at upload.
- **Video without captions.** ADA fail + unusable for hard-of-hearing + muted autoplay. Captions mandatory.
- **Color-only indication of info.** Red for urgent, green for success — color-blind fails. Add text label + icon.
- **Link text "click here".** Screen-reader unfriendly. Descriptive link text.
- **Heading hierarchy skipped (H1 then H3).** Screen-reader disorientation. Enforce order.
- **Modal traps focus without escape.** Keyboard users stuck. Focus trap with escape.
- **Low color contrast in themes.** 2.0:1 where 4.5:1 required (WCAG AA for normal text).
- **Time-based auto-content change (carousel).** Cognitive disability fail. Pause/controls.

## Images + media

- **EXIF not stripped.** GPS location of photographer's home leaks. Strip on upload.
- **Asset orphans accumulate.** Uploaded but unused; storage cost; cleanup impossible. Usage tracking + reaper.
- **Asset replacement doesn't invalidate CDN.** Old image cached. Cache invalidation on update.
- **Asset replacement breaks historical revisions.** Old revision now shows new image. Version assets.
- **Hero image rendered at full resolution on mobile.** 5MB on 3G; LCP terrible. Responsive variants.
- **Modern formats (AVIF/WebP) missing fallback.** Old Safari breaks. `<picture>` with fallback.
- **Duplicate image uploads create duplicate files.** 10 copies of same image. Hash dedup.
- **Asset attribution lost.** Legal liability. Mandatory attribution field.
- **Licensed image used past license period.** Copyright claim. Expiry tracking.

## Taxonomy

- **Category hierarchy infinite.** "News > World > Europe > UK > London > ..." — breadcrumbs overflow. Depth limit.
- **Categories + tags semantically overlapping.** Editor confused; inconsistent application. Clear guidelines.
- **Category deletion orphans articles.** Articles lose nav; 404 on category page. Cascade policy.
- **Tag proliferation.** 10,000 tags, 9000 used once. Periodic cleanup + consolidation.
- **Similar tags not merged.** "AI", "artificial-intelligence", "machine-learning" — merge workflow needed.

## Publishing + state transitions

- **Scheduled article edited; schedule not cleared.** Article publishes at old schedule even if post-edit draft. Reset on edit OR explicit confirmation.
- **Publish button in draft state = instant publish.** Accidental publish. Confirm.
- **Unpublish removes from feeds but URL still works.** Confusing; SEO unclear. Return 410 Gone OR 404.
- **Unpublish to retract misinformation without update note.** Reader sees different version; trust lost. Retraction note + correction policy.
- **Article update silent.** Old readers assume stale; trust issue. "Updated on" visible + optional changelog.
- **Scheduled article timezone mismatch.** Editor in PST schedules "9am"; system interprets as EST or UTC. Explicit TZ.

## Search

- **Search results include drafts / unpublished.** Leak. Filter.
- **Search returns archived articles.** Irrelevant to current users. Filter or deprioritize.
- **Search indexer lags 24h.** New article unfindable. Event-driven indexing.
- **Search relevance heavily title-weighted.** Body content ignored; misses obvious matches. Tune.
- **Typo tolerance absent.** "climatechamge" → 0 results. Fuzzy matching.
- **Search UX hides filters on mobile.** Power users frustrated.

## Cache + staleness

- **Cache TTL longer than publish frequency.** New article not visible for 1h. Event-driven invalidation OR short TTL.
- **Stale-while-revalidate without deprecation.** Updated article's old version served indefinitely. Explicit re-fetch on write.
- **Author changes bio; old articles still show old bio.** Acceptable for historical or aggressively cached. Decide.
- **Feed cached too long.** Subscribers see stale newsletter content. Shorter TTL.

## Paywall

- **Paywall HTML in DOM; bypassable by view-source.** Content free despite intent. Server-side gating.
- **Paywall reveals article to crawlers (Googlebot-specific).** Some strategies legit (Google First Click Free, deprecated); if used, document + disclose.
- **Meter cookie-based easily cleared.** User reads unlimited. Server-side meter + fingerprint.
- **Subscription cancellation hard to find.** Consumer protection lawsuits.

## Corrections + retractions

- **Edits to published articles without changelog.** Stealth edits = trust collapse (NYT's "memory-holing" criticism). Changelog + visible correction notice.
- **Retraction = delete.** Readers who linked now 404. Replace content with retraction statement.
- **Correction vs clarification unclear.** Use consistent labeling.
- **Typo fix treated as correction.** Alarm fatigue. Minor vs substantive distinction.

## Sponsored content

- **"Sponsored" label in small gray text.** FTC "clear + conspicuous" fail. Prominent visible label.
- **Sponsored content in search + feeds indistinguishable from editorial.** Violates ad/edit separation. Label in all surfaces.
- **Affiliate links without disclosure.** FTC violation. Disclosure at top.

## Analytics + privacy

- **Full IP stored in analytics.** GDPR requires anonymization. Truncate.
- **Third-party scripts before consent banner.** Cookies set pre-consent. Block until consent.
- **Pixel trackers in email without disclosure.** GDPR + CAN-SPAM.
- **Geolocation stored for readers.** Privacy concern. Aggregate only.
