# Content — core flows

P1 = without these, publication can't operate. P2 = required to retain audience + authors. P3 = competitive.

## P1 — must-have for v1

### 1. Draft → review → schedule → publish
The editorial workflow. Quality control + legal gate before public.

```
Author starts new article (draft status)
  → writes in editor (rich text / markdown / block-based)
  → attaches assets (hero, inline images, embeds)
  → fills metadata (title, slug, category, tags, excerpt, SEO fields)
  → saves → revision created automatically
  → submits for review → status = in_review
  → editor receives notification
  → editor reviews → suggests changes (inline comments) OR approves
  → author revises → back to in_review loop until approved
  → editor schedules → published_at = future time; status = scheduled
  → (or publishes now → status = published)
  → at scheduled time: cron / worker publishes → SEO/RSS/sitemap/caches updated → notification to subscribers
```

Key invariants:
- Revision per save (every save creates new row; storage-conscious variants may diff).
- Status transitions gated by role (author → in_review; editor → scheduled/published).
- Published article edits DO NOT rewrite history — create new revision, keep audit trail.
- Slug uniqueness within publication; auto-generate from title, allow override.
- Scheduled publish respects timezone (store UTC; display in publication TZ + user TZ).
- Embargo lift fires at release_at; any earlier access blocked.

### 2. Version history + revert
```
Editor views revision history of article
  → sees list (timestamp, author, comment)
  → diff between any two revisions (text diff + structural)
  → revert to revision N → creates new revision from revision N's content; does NOT overwrite history
  → new revision author = person who reverted
```

Key invariants:
- History immutable (revisions append-only).
- Revert = copy-forward; never delete intermediate revisions.
- Published revisions flagged; reverting to unpublished revision keeps current status separate.

### 3. Taxonomy management
- Categories hierarchical (World > Europe > UK).
- Tags flat + many-per-article.
- Category reassignment of articles.
- Tag merge (combine synonyms).
- Category archive without breaking articles (article survives; navigation redirects).
- Tag/category pages with pagination.

### 4. Asset management + processing
```
Author uploads image
  → file streamed to object storage (S3 / R2 / GCS)
  → virus scan
  → EXIF strip (privacy — location, camera data, copyright metadata)
  → generate variants (thumb, small, medium, large, social-cards, retina variants)
  → return URL(s) + asset_id
  → author embeds in article
  → required: alt text prompt (a11y + SEO)
  → required: attribution / source / copyright (legal)
```

Key invariants:
- Alt text prompt is non-dismissable for hero images; warning for inline.
- Duplicate detection (hash) offers reuse of existing asset.
- Video processed with HLS/DASH variants; poster frame auto-extracted.
- Image formats: serve AVIF/WebP with JPEG/PNG fallback.

### 5. Reading (public site)
```
Visitor requests article URL
  → route resolution (category/slug or flat slug)
  → article fetched (published only; drafts 404 for public, preview for auth'd editors)
  → render with metadata (title, description, og:*)
  → structured data (Article / NewsArticle schema.org JSON-LD)
  → canonical URL set
  → related articles computed
  → comments loaded (if enabled)
  → analytics event fired (pageview)
```

### 6. RSS / Atom feeds + sitemaps
- `/feed.xml` (RSS 2.0 or Atom).
- `/sitemap.xml` + `/sitemap-[category].xml` for large sites.
- Rebuilt on publish / update / delete.
- Feed reader User-Agents common; cache aggressively.
- Feed content = full or excerpt depending on strategy.

### 7. Newsletter subscription + send
```
Visitor submits email → pending Subscriber
  → double opt-in: confirmation email sent
  → subscriber clicks confirm link → status = confirmed
  → newsletter compose → pick articles → preview → test send → schedule/send
  → ESP (SendGrid/Mailgun/SES/Postmark/Resend) delivers
  → per-recipient events (delivered, opened, clicked, bounced, complained, unsubscribed) tracked
  → unsubscribe link honored; one-click (per Gmail/Yahoo 2024 requirements for bulk senders)
```

Key invariants:
- Double opt-in default (GDPR + deliverability).
- Unsubscribe must be 1 click (no login, no preferences page to skip).
- Bounce handling: hard bounce → suppress permanently; soft bounce → retry schedule.
- Complaints → immediate suppress.
- DKIM + SPF + DMARC configured for sender domain (deliverability critical).
- List-Unsubscribe header + List-Unsubscribe-Post: List-Unsubscribe=One-Click (RFC 8058).

### 8. Comment moderation
```
Commenter submits (auth'd or guest) → spam check (Akismet / manual rules / Disqus) → status
  → pending: queued for editor
  → approved automatically if reputable (returning commenter, approved history)
  → spam: trash OR hidden
  → editor reviews queue → approve / spam / trash
  → published comments displayed (threaded or flat)
  → commenter notifications (reply, moderation decision)
```

## P2 — retain audience + authors

### 9. Comment threading + reactions
- Threaded replies (limit depth to 2-3 to avoid chaos).
- Upvote / heart / like reactions.
- Author/editor highlighted replies.
- Report abuse flow.
- Rate limit per IP (spam prevention).

### 10. Subscriber segments + personalization
- Segment by: category interest, open history, signup source, engagement tier.
- Targeted newsletters.
- Dynamic content blocks (render different per segment).

### 11. Search
- Full-text search across articles (Postgres FTS / Elasticsearch / Algolia / Meilisearch / Typesense).
- Typo tolerance.
- Filters: category, author, date range, tags.
- Search analytics (what readers look for; guides content strategy).

### 12. Related content + recommendations
- Editorial picks (manual).
- Algorithmic (co-read, content similarity, user history).
- "Continue reading" modules.
- Tag-based or category-based related.

### 13. SEO optimization
- Per-article meta (title, description, OG image).
- Structured data (Article, NewsArticle, BreadcrumbList, Person).
- Canonical URLs.
- 301s on slug/URL changes.
- Sitemap with lastmod + priority.
- Robots.txt per environment.
- Image alt text audit.
- Core Web Vitals (LCP, CLS, INP) budget.

### 14. Author profiles + bylines
- Author page with bio, photo, article feed.
- Author archives per category.
- Co-authors (many-to-many on article).
- Author follow (subscribe to an author specifically).

### 15. Paywall / paid subscriptions (if applicable)
- Article access tiers (free / members / premium).
- Meter (N free articles per month).
- Paywall strategies (soft — preview, hard — login required).
- Stripe integration for recurring subscriptions.
- Member-only content sections.

### 16. Analytics
- Pageviews per article / author / category.
- Engagement time (scroll depth, time on page).
- Social shares.
- Newsletter performance.
- Subscriber growth + churn.

## P3 — differentiator

### 17. Collaboration (real-time multi-author)
- Google-Docs-style simultaneous editing.
- Presence indicators.
- Comments + suggestions.
- Operational transforms or CRDTs (Yjs).

### 18. AI-assisted writing
- Headlines suggestion.
- Summary generation.
- SEO meta auto-fill.
- Image generation (disclosed + ethical limits).
- Fact-check / citation assistance.
- Translation.

### 19. Multi-language content
- Per-language article versions.
- hreflang tags.
- Translation workflow (source → translator → editor).
- Language-aware sitemaps.

### 20. Syndication + partnerships
- Outbound: license content to partners; canonical URLs preserve SEO authority.
- Inbound: embed partner content with attribution.
- Content API for partners.

## Specific concerns

### Publishing race
Two editors publish simultaneously; concurrent status transitions; second's mutation wins or fails confusingly. Optimistic concurrency control (version column) + clear error.

### Slug collision
Article A slug "hello-world"; Article B drafted with same; collision on publish. Auto-suffix (`hello-world-2`); warn to editor.

### Timezone confusion at scheduled publish
Editor sets 5pm EST; stored as UTC; cron runs UTC; if DST change mid-schedule, off by an hour. Store explicit timezone + UTC; recompute UTC if TZ settings change.

### Orphaned assets
Assets uploaded but article never published; never referenced; storage leak. Orphan cleanup job (90 days unused).

### Version history explosion
Every keystroke-saved draft → 1000 revisions per article → DB bloat. Coalesce edits within time window (5 min) OR snapshot on explicit save.

## Webhooks the system must emit

- `article.published`, `article.updated`, `article.unpublished`.
- `comment.created`, `comment.approved`, `comment.reported`.
- `subscriber.confirmed`, `subscriber.unsubscribed`.
- `newsletter.sent`, `newsletter.bounced`, `newsletter.complained`.
- `takedown.received`, `takedown.removed`.

## Webhooks the system must consume

- ESP events (delivered, opened, clicked, bounced, complained, unsubscribed).
- Comment spam service (Akismet) verdict.
- Payment provider (for paid subscriptions).
- Social share counts (if aggregating).
- Search indexing completion.

## Idempotency-critical endpoints

- `POST /articles` — duplicate drafts on retry.
- `POST /newsletters/:id/send` — double-send = double-email to subscribers (deliverability death).
- `POST /comments` — spam bots replay; duplicate comment prevention.
- `POST /subscribers` — same email multiple times should merge, not duplicate.
- Webhook handler (ESP events) — at-least-once delivery.
