# Content — feature checklist

The 80%-of-projects-need-this list. Content platforms often ship polished editors but fail on boring operational concerns — deliverability, a11y, SEO, takedown process.

## Reader-facing (public site)

### Navigation + discovery
- [ ] Homepage with editorial curation (hero, sections, latest).
- [ ] Category pages with pagination.
- [ ] Tag pages with pagination.
- [ ] Author pages with bio + article feed.
- [ ] Archive pages (by year/month if volume supports).
- [ ] Search with autocomplete + filters.
- [ ] Related-content modules on article pages.
- [ ] Popular / trending articles.
- [ ] "Continue reading" cross-sells.
- [ ] Breadcrumbs (category → article).

### Article reading
- [ ] Mobile-first typography.
- [ ] Reading progress indicator (optional).
- [ ] Estimated read time.
- [ ] Byline + publish/update dates.
- [ ] Responsive hero image.
- [ ] Table of contents for long-form.
- [ ] Inline citations / footnotes.
- [ ] Print stylesheet.
- [ ] Share buttons (native Web Share API; avoid heavy 3P scripts).
- [ ] Save-for-later (bookmark).
- [ ] Copy-link helper.

### Engagement
- [ ] Comment submission (auth or guest per policy).
- [ ] Comment threading + reactions.
- [ ] Rate/react to article (clap / heart).
- [ ] Newsletter signup (inline + footer + modal).
- [ ] Follow author.

### Accessibility
- [ ] WCAG 2.2 AA compliance.
- [ ] Alt text on all meaningful images (required at upload).
- [ ] Semantic HTML (headings, landmarks).
- [ ] Keyboard navigation.
- [ ] Skip-to-content link.
- [ ] Transcript/captions for audio/video.
- [ ] High-contrast mode support.

### Performance
- [ ] Core Web Vitals budget (LCP < 2.5s, CLS < 0.1, INP < 200ms).
- [ ] Responsive images (srcset + sizes).
- [ ] Modern formats (AVIF/WebP with fallback).
- [ ] Lazy-load below-fold.
- [ ] Static generation or ISR for articles.
- [ ] CDN-cached HTML.

### SEO
- [ ] Per-article meta (title, description, canonical).
- [ ] Structured data (Article, NewsArticle, BreadcrumbList, Person, Organization).
- [ ] OpenGraph + Twitter cards.
- [ ] XML sitemap.
- [ ] RSS/Atom feed.
- [ ] Robots.txt.
- [ ] hreflang for multi-language.
- [ ] 301 redirects on URL changes.
- [ ] No duplicate content (canonical URLs).

## Author / editor-facing (CMS)

### Editor
- [ ] Rich text / block / markdown editor (pick one convention).
- [ ] Image insertion with drag-drop.
- [ ] Video embed (YouTube, Vimeo, native).
- [ ] Embed oembed handlers (Twitter, Instagram, Spotify).
- [ ] Code blocks with syntax highlighting.
- [ ] Tables.
- [ ] Quotes / callouts.
- [ ] Internal links (to other articles) with autocomplete.
- [ ] External link with rel=noopener/nofollow options.
- [ ] Footnotes.
- [ ] Spellcheck.
- [ ] Word count + read-time estimate.
- [ ] Distraction-free mode.
- [ ] Autosave every N seconds.
- [ ] Dirty-state warning on navigation.
- [ ] Drag-and-drop section reorder.

### Metadata + SEO panel
- [ ] Slug with manual override.
- [ ] SEO title + description (with preview).
- [ ] Social card image (with preview per network).
- [ ] Category selection.
- [ ] Tags with autocomplete.
- [ ] Author assignment (including co-authors).
- [ ] Publish date + time picker.
- [ ] Timezone picker.
- [ ] Canonical URL override (for syndicated content).
- [ ] Noindex toggle (for unpublished/internal).
- [ ] Embargo until.
- [ ] Featured flag.

### Workflow
- [ ] Status dropdown (draft, in review, scheduled, published).
- [ ] Submit for review action.
- [ ] Approve / reject with feedback.
- [ ] Schedule publish.
- [ ] Unpublish.
- [ ] Archive.
- [ ] Clone article.
- [ ] Transfer author.

### Revisions
- [ ] Revision list with timestamp + author.
- [ ] Diff between revisions.
- [ ] Restore revision.
- [ ] Compare with live.

### Media library
- [ ] Upload single + bulk.
- [ ] Folder organization.
- [ ] Search by filename, alt text, caption.
- [ ] Duplicate detection (hash).
- [ ] Crop + focal-point for responsive.
- [ ] Replace asset (propagates to usages).
- [ ] Usage tracking (where is this image used?).
- [ ] Delete with usage warning.
- [ ] Attribution + copyright fields.

### Author management
- [ ] Profile edit (bio, avatar, social links).
- [ ] Multiple pen names.
- [ ] Author stats (article count, views, engagement).
- [ ] Author role + permissions.

### Comment moderation
- [ ] Queue with filter (pending, reported).
- [ ] Bulk actions (approve all, spam all from IP).
- [ ] Approved-commenter list (auto-approve future).
- [ ] Blocked-commenter list / IP ban.
- [ ] Auto-moderation rules (link count, keyword).
- [ ] Manual spam marking feeds trainer.
- [ ] Reply as author (highlighted).

### Newsletter
- [ ] Subscriber list view with search + filter + segment.
- [ ] Bulk import (with CAN-SPAM / GDPR consent attestation).
- [ ] Bulk export.
- [ ] Double opt-in toggle.
- [ ] Welcome email / automation.
- [ ] Newsletter composer (HTML + text).
- [ ] Drag-drop block builder.
- [ ] Article-pull macros (auto-populate latest).
- [ ] Subject line + preheader with preview.
- [ ] A/B testing on subject lines.
- [ ] Segmentation + targeting.
- [ ] Schedule + send.
- [ ] Test send.
- [ ] Send statistics (delivered, opened, clicked, bounced, unsubscribed, complained).
- [ ] Clickmap / link analytics.
- [ ] Bounce + complaint handling (auto-suppress).
- [ ] Unsubscribe page + reason capture.

### Taxonomy
- [ ] Category CRUD.
- [ ] Category nesting.
- [ ] Tag CRUD.
- [ ] Tag merge.
- [ ] Category/tag analytics (popularity).

### Analytics
- [ ] Article-level views + engagement.
- [ ] Author scorecard.
- [ ] Category performance.
- [ ] Referral sources.
- [ ] Device + geo breakdown.
- [ ] Newsletter metrics.

## Legal / trust

- [ ] DMCA takedown contact page + process.
- [ ] Editorial standards page.
- [ ] Masthead / about us with editorial team.
- [ ] Corrections + retractions log.
- [ ] Disclosure of sponsored content.
- [ ] Cookie consent.
- [ ] Privacy policy.
- [ ] Terms of service.
- [ ] Copyright notice in footer.

## Admin / ops

- [ ] User + role management (Author, Contributor, Editor, Administrator, Subscriber).
- [ ] Plugin / extension manager (if extensible).
- [ ] Backup / export (WXR / JSON / DB dump).
- [ ] Site settings (title, tagline, locale, timezone).
- [ ] SMTP / ESP configuration.
- [ ] Domain + TLS.
- [ ] Cache management.
- [ ] Redirects manager (301/302 table).
- [ ] Image optimization settings.

## Things v1s commonly miss

- **Published_at = scheduled time vs actual time confusion.** Author schedules for 9am; system publishes at 9:04 (cron); feeds show 9am. Track both; display published_at (scheduled) for UX + actual publication moment for analytics.
- **Revision history without diff.** "Revision by Sarah at 3pm" — what did she change? Diff UI (text + structural).
- **Comment body markdown allows XSS.** Markdown → HTML without sanitization; `<script>` injected. Sanitize (DOMPurify / sanitize-html) with strict allowlist.
- **DMCA takedown without process.** Claimant emails; sits in inbox; lawsuit. Dedicated form + workflow + counter-notice support + 10-14 day response.
- **Unsubscribe broken or pointing to wrong list.** Complaint rates spike; ESP reputation burns. Test unsub flow in every send + one-click per RFC 8058.
- **Image alt text not required.** Author rushes; alt missing; a11y + SEO fail. Non-dismissable prompt OR save-block.
- **No canonical URLs.** Duplicate content penalty from syndication + tag/category + pagination URLs. Canonical tags on all.
- **301 redirects on slug change absent.** SEO juice lost; external links break. Auto-create 301 when slug changes.
- **Scheduled publish not respecting DST transitions.** Article scheduled for Sunday 2am during spring-forward; never publishes OR double-publishes. Store TZ separately; re-resolve at cron time.
- **Embargo releases a minute early due to cron granularity.** PR partner breaks exclusive. Precise timer + hard check at request time.
- **Newsletter rendering breaks in Outlook.** Modern CSS; Outlook uses Word rendering engine; layout broken. MJML or tested framework + test across clients.
- **Preview (draft article) URL leaks + indexed.** Draft accessible via guessable URL; Google indexes; editors horrified. Preview URL needs auth + noindex.
- **Orphan assets accumulate.** 10 years of unused uploads; storage cost; cleanup impossible. Orphan reaper + usage tracking.
- **Content versioning doesn't include asset versioning.** Revision references asset v1; asset replaced with v2; historical revision now shows wrong image. Asset immutability or explicit version linking.
- **Sitemap not updated on publish.** Google crawls old sitemap; new article not indexed. Event-driven sitemap regen.
- **Feed includes drafts or scheduled.** Public feed leak of embargoed content. Filter published_at <= now.
- **List-Unsubscribe header missing.** Gmail/Yahoo 2024 bulk-sender rules: emails to spam. Required for >5k/day senders.
- **Article category soft-deleted; articles orphaned.** Category page 404; articles still visible but category link broken. Cascade policy.
- **No author-level control for comments.** Can't block harasser commenter; only IP block (VPN defeats). Account-level ban + IP range.
- **Published article edits don't mark as updated.** Readers see stale content; trust lost when surprised by old article misinformation. "Updated on" visible + changelog (for corrections).
- **Language/locale per article missing.** Multi-language site treating all as same; hreflang missing; SEO penalty. Article-level locale + hreflang alternates.
- **Preview mode across devices broken.** Author tests on desktop; mobile different. Preview URL works everywhere.
- **Copy-paste from Word pastes styled MS garbage.** Editor must clean on paste.

## Things often over-built in v1 (defer until validated)

- Full multi-language with translation workflow (start single-language).
- Complex paywall meter variations (fixed-N free articles; iterate later).
- AI assistant features at scale (start with headline + summary suggestions).
- Real-time collaboration (unless multi-author is core; start with save-locks).
- Granular permission matrix (system roles cover 90%).
- Custom post types / content models (start with articles + pages).
- Comprehensive in-house analytics (use Fathom, Plausible, Google Analytics 4).
- Mobile apps (web-first; apps later).
- Syndication partner network (manual per-partner for first 10).
- Full member-only content sections (gate specific articles or newsletters first).
