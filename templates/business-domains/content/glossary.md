# Content — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `content` (CMS / publishing / blog / news / newsletter):

**Entity / model names**: `Article`, `Post`, `Page`, `Author`, `Editor`, `Category`, `Tag`, `Comment`, `Revision`, `Subscriber`, `Newsletter`, `Asset`, `Media`, `Publication`, `Issue`, `Series`, `Section`.

**Folder / route names**: `articles/`, `posts/`, `categories/`, `tags/`, `authors/`, `editorial/`, `cms/`, `/[category]/[slug]`, `/author/[handle]`, `/tag/[name]`, `/feed.xml`, `/sitemap.xml`, `/admin/posts`, `/admin/revisions`.

**Dependencies**: `wordpress`, `ghost`, `strapi`, `sanity`, `contentful`, `prismic`, `payloadcms`, `directus`, `keystone`, `tiptap`, `slate`, `lexical`, `prosemirror`, `@tiptap/core`, `markdown-it`, `remark`, `rehype`, `unified`, `sharp`, `cloudinary`, `imgix`, `feed` (RSS), `sitemap`, `@sanity/block-content-to-html`.

**Database schema**: tables for `articles`/`posts` + `authors` + `categories` + `tags` + `revisions` is the strongest signal. Presence of `slug` + `published_at` + `status` columns near-conclusive.

**Distinguishing variants**:
- **Blog / personal** — single author, small catalog, SEO-driven.
- **News / publishing** — multi-author, editorial workflow, high volume, time-sensitive.
- **Newsletter / substack-style** — email-first, paid subscriptions, mixed web + inbox.
- **Documentation / knowledge base** — versioning, navigation hierarchy, search-critical.
- **Marketing site CMS** — landing pages, marketing pages, content-managed by non-devs.
- **Headless CMS** — content API + frontend agnostic.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Article` / `Post` | a unit of published content | `id, slug, title, excerpt, body (markdown/html/json), status, author_id, category_id, tags[], published_at, updated_at, scheduled_at, embargo_until, canonical_url, seo_title, seo_description, hero_asset_id` | draft → in_review → scheduled → published → updated → archived / unpublished |
| `Revision` | snapshot of article state | `article_id, version, author_id, body, title, created_at, comment, published_in_revision?` | append-only |
| `Author` | content creator | `id, user_id, display_name, handle, bio, avatar_asset_id, social_links{}, role (author/contributor/staff), pen_name?` | active → inactive |
| `Editor` | reviewer / approver | `id, user_id, scope (category/all), permissions[]` | active → removed |
| `Category` | primary taxonomy | `id, slug, name, parent_id, description, seo_title, seo_description, order` | created → merged / archived |
| `Tag` | secondary taxonomy | `id, slug, name, description` | created; many-to-many with article |
| `Comment` | reader response | `id, article_id, parent_id, author_name, author_email, body, status (pending/approved/spam/trash), created_at, ip, user_agent` | pending → approved / spam / trash |
| `Subscriber` | email list member | `id, email, status (pending/confirmed/unsubscribed/bounced/complained), source, subscribed_at, confirmed_at, unsubscribed_at, tags[], preferences{}` | pending → confirmed → unsubscribed |
| `Newsletter` | scheduled email | `id, subject, preheader, content_html, content_text, sender_name, sender_email, scheduled_at, sent_at, recipient_count, article_ids[]` | draft → scheduled → sending → sent |
| `NewsletterSend` | per-recipient delivery | `newsletter_id, subscriber_id, delivered_at, opened_at, clicked_at, bounced_reason, complained_at, unsubscribed_at` | pending → delivered → opened/clicked/bounced/complained |
| `Asset` / `Media` | uploaded file | `id, type (image/video/audio/document), original_url, variants[], mime, size_bytes, width, height, duration_seconds, alt_text, caption, copyright, uploaded_by, uploaded_at` | uploaded → processing → ready |
| `AssetVariant` | transformed version | `asset_id, format, width, height, url, purpose (thumb/hero/social)` | auto-generated |
| `Publication` / `Site` | top-level container | `id, name, domain, locale, tagline, default_author_id, brand_assets[]` | persistent |
| `Issue` | grouped publication unit (magazine-style) | `id, publication_id, number, title, publish_date, article_ids[]` | draft → published |
| `Series` | multi-part article sequence | `id, title, slug, article_ids[] (ordered)` | active |
| `Collection` | ad-hoc grouping | `id, title, slug, article_ids[], curation_order` | active |
| `SubscriberSegment` | targeted group | `id, name, criteria (query-like), count, last_computed_at` | refreshable |
| `Webhook` | outbound notification | `id, url, events[], secret, active` | active → disabled |
| `Takedown` | DMCA / legal request | `id, article_id?, asset_id?, claimant, reason, status, counter_notice?, filed_at, resolved_at` | received → investigating → removed / counter_noticed / denied |
| `Embargo` | time-boxed content restriction | `article_id, release_at, released_at?` | active → released |

## Status state machines

**Article:**
```
draft → in_review → scheduled → published → updated
           ↓           ↓            ↓
        rejected    cancelled   unpublished / archived
                                     ↓
                                  redacted (legal)
```

**Comment:**
```
pending → approved → published
   ↓         ↓
 spam     reported → removed
   ↓
 trash
```

**Subscriber:**
```
pending (double opt-in) → confirmed → active
                                         ↓
                                      unsubscribed
                                         ↓
                                    complained / bounced (hard) → suppressed
```

**Newsletter:**
```
draft → scheduled → sending → sent
          ↓           ↓
       cancelled   paused → resumed
```

**Asset:**
```
uploaded → processing (variants, EXIF strip, virus scan) → ready
               ↓                                              ↓
            failed                                        deleted
```

## Vocabulary distinctions (don't conflate)

- **Article** vs **Page** vs **Post** — Article = time-relevant content with author + publish date; Page = evergreen (About, Contact); Post = colloquial, often synonymous with Article. Pages and Articles often share infrastructure but have different editorial treatment.
- **Draft** vs **In Review** vs **Scheduled** vs **Published** — Draft = writer-editable; In Review = editor-gated; Scheduled = published_at is in future; Published = live.
- **Unpublished** vs **Archived** vs **Deleted** — Unpublished = hidden but content preserved; Archived = explicit retirement with canonical behavior; Deleted = gone (soft or hard).
- **Revision** vs **Version** — Revision = historical snapshot (every save); Version = intentional labeled release (used in docs). CMS "revisions" usually = our revision.
- **Author** vs **Contributor** vs **Editor** vs **Publisher** — Author = wrote the piece; Contributor = limited rights (draft only); Editor = approves + publishes; Publisher = top-level legal + brand.
- **Category** vs **Tag** vs **Section** vs **Topic** — Category = primary, usually 1-per-article, parent taxonomy; Tag = many, free-form; Section = editorial grouping (World, Sports); Topic = semantic (AI, Climate).
- **Slug** vs **Permalink** vs **Canonical URL** — Slug = URL-friendly identifier; Permalink = full URL; Canonical URL = the URL search engines should treat as authoritative (affects SEO with syndicated/duplicate content).
- **Published at** vs **Scheduled at** vs **Created at** vs **Updated at** — Created = DB insert; Scheduled = intended publish future-time; Published = went live (actual time OR scheduled = published if passed); Updated = last edit.
- **Soft publish** vs **Embargo** — Soft = visible to editors + reviewers before public; Embargo = external constraint (PR, legal) holding release.
- **Hero image** vs **Featured image** vs **Social card** vs **Thumbnail** — different roles, different sizes, different aspect ratios.
- **Subscribers** vs **Members** vs **Customers** — Subscribers = opt-in email list (free); Members = registered users (may be free or paid); Customers = paid.
- **Hard bounce** vs **Soft bounce** vs **Complaint** — Hard = permanent (bad address); Soft = transient (inbox full); Complaint = spam report → must suppress.
- **Open rate** vs **Click rate** vs **CTOR** — Open = %opened of delivered; CTR = %clicked of delivered; CTOR (click-to-open) = %clicked of opened.

## Multi-tenancy variants

- **Single publication**: one site. Tenant boundary = none.
- **Multi-site CMS**: one operator, many publications (Condé Nast model with Vogue + Wired + GQ). `publication_id` on every entity.
- **SaaS CMS (Ghost, Substack, Medium)**: many independent publishers on one platform; strict tenant boundary.
- **Network** (Vox, BuzzFeed): shared editorial tech + brand-isolated publishing.
- **Syndication / wire**: content originates in one publication, distributes to many; licensing + canonical-URL rules apply.
