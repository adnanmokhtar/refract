# Social — stakeholders

Each stakeholder has different needs from the same system. Social platforms differ from ecommerce in that the same person plays multiple roles (poster, viewer, reporter) — and a small number of bad actors create disproportionate operational load.

## End user (the participant)

The reason the system exists. Engagement = retention = network effect.

**Workflows:**
- Discover: see content from followed users + recommended (feed) + search/explore.
- Consume: scroll, react, comment, share, save.
- Create: post text/media; reply; quote-share.
- Connect: follow, find friends, build network.
- Communicate: comment threads, DMs (separate domain, but interlinked).
- Manage identity: profile, privacy, notifications, blocks.
- Self-protect: report, mute, block, restrict, leave.

**Pain points the system must solve:**
- "Is this person real?" — verification badges, mutual signals.
- "How do I get rid of this?" — block/mute/unfollow must be obvious + frictionless.
- "Did they see my content?" — view counts, read receipts (where applicable + privacy-respecting).
- "I made a mistake" — edit/delete with grace.
- "My account got hacked" — recovery + session revocation.
- "Push is annoying" — granular notification controls.

**KPIs:**
- DAU / MAU / WAU.
- Time spent / session length (controversial — overuse harms user goodwill).
- Posts created / week.
- Repeat-day rate (sticky = product-market fit).
- Net Promoter Score (NPS).
- 1-day / 7-day / 30-day retention.

## Creator / power user (top 1-5%)

Drives most content viewed, sets cultural tone, has outsized support burden.

**Workflows:**
- Schedule + publish (multi-platform tools).
- Track engagement (analytics dashboard).
- Respond to comments + DMs at volume.
- Manage harassment + spam.
- Monetize (subscriptions, tips, ad share, brand deals).

**Pain points:**
- "Comment section is unusable" — tools to filter/block by keyword + sort + assign moderators.
- "I can't keep up with DMs" — auto-replies, message filtering.
- "My content reach dropped" — algorithm transparency + analytics.
- "Impersonators" — verification + impersonation reporting fast track.
- "Tax forms are a mess" — clean payout reporting + 1099 generation.

**Permissions implications:**
- Creators may want delegated access (assistant manages comments without password).
- "Account" vs "Page" distinction (Facebook pattern): creator's brand page with multiple admins, separate from personal profile.

**KPIs:**
- Followers gained / lost.
- Engagement rate (interactions / impressions).
- Earnings (if monetization enabled).

## Moderator (paid + volunteer)

The frontline of trust + safety. Heaviest UI users by hours; their tooling determines moderation quality.

### In-house moderator
- Reviews queued reports.
- Makes action decisions with reason + evidence.
- Escalates ambiguous cases to senior moderators or legal.
- Mental health risk — exposure to severe content (CSAM, gore, suicide imagery).

**Workflow:**
- Pull next item from queue (ideally not chronologically — surface highest-risk first).
- Review content + context + reporter history + reportee history.
- Apply policy (decision tree / labels).
- Action: dismiss / hide / remove / strike / suspend / ban.
- Audit-logged with reason + classification tag.

**Pain points:**
- Context switching across content types is exhausting (text, image, video, livestream).
- Borderline cases dominate; clear-violations are easy.
- No "undo" → over-cautious removals → false positives → user appeals → workload loops.
- Wellness: secondary trauma from severe content. Required: rotation, counseling, blurred-by-default UI for severe categories.

**Permissions:**
- Read content + report queue + user history.
- Action within scope (some actions admin-only — permanent ban, IP block, account purge).
- Cannot action friends/family (conflict of interest).
- Cannot action accounts you've previously interacted with publicly.

### Senior moderator / policy team
- Writes + maintains community guidelines.
- Reviews moderator decisions for consistency (sample audits).
- Handles novel cases, sets precedents.
- Liaises with trust + safety leadership + legal.

### External / outsourced moderation
- Common at scale (BPOs in Philippines, Kenya, India).
- Same tooling as in-house but different access scope (no billing, no PII outside review context).
- Specific contractual data-handling requirements.
- Wellness obligations under regional labor law.

**KPIs (moderation team):**
- Reports actioned / hour / moderator.
- Inter-rater reliability (do 2 mods reach same decision?).
- Time-to-action P50 / P95 / P99.
- Appeal-overturn rate (high = inconsistency or over-action).
- User-perception scores (do users feel safe?).

## Trust + safety lead

Strategy + escalation path for moderation.

**Workflows:**
- Set policies (community guidelines).
- Manage external relationships (NCMEC, law enforcement, civil-society groups).
- Handle PR-sensitive incidents (viral abuse case).
- Coordinate cross-functional (engineering, legal, comms) on incidents.

**Tools needed:**
- Cross-cutting search (find all content matching pattern X).
- Mass-action tools (suspend N accounts at once during coordinated abuse).
- Trend detection (sudden spike of reports against keyword Y).

**KPIs:**
- Mean time to detect coordinated abuse.
- Mean time to action.
- Press incidents per quarter.
- DSA / Online Safety compliance posture.

## Customer support

Handles non-moderation user issues: account access, billing, "I lost my account", verification questions.

**Workflows:**
- Inbound ticket triage.
- Account recovery (knowledge-based / ID-document verification).
- Refund (for paid features) — see ecommerce stakeholders.
- Escalate moderation appeals to T&S team.

**Pain points:**
- Account recovery is a fraud vector — trade-off between user friction + impersonator risk.
- Locked-out creators with revenue-dependency = high-pressure tickets.
- Cannot access user's data (privacy) → friction in resolving.

## Engineering team

### Feed / recommendations engineer
- Optimizes ranking signals.
- A/B tests ranking variants.
- Investigates "why am I seeing this" + "I should be seeing more of X" complaints.

### Trust + safety engineer
- Builds detection models (CSAM, spam, hate speech).
- Integrates third-party tooling (Hive, Thorn, PhotoDNA).
- Maintains review tooling.

### Platform / infra
- Scales fanout (celebrity post problem).
- Manages real-time delivery (websocket fleet).
- Owns CDN + media pipelines.

## Advertiser (if ads-monetized)

- Targets audiences (granular interest + demographic).
- Bids on inventory.
- Measures performance.
- Compliance with brand-safety standards (GARM, MRC).

**Pain points:**
- Brand safety: ads next to objectionable content = PR fire.
- Measurement (post-iOS-14 + post-third-party-cookie complications).

**Tooling needed:**
- Self-serve ads manager.
- Audience builder.
- Reporting + attribution.
- Brand-safety controls (block adjacent content categories).

## Researcher / journalist (DSA Article 40)

- DSA Article 40: VLOPs must provide vetted researchers access to data for risk research.
- Workflow: vetting + scoped data access via API.
- Privacy-preserving query layer (no individual-user query without further authorization).

## Government / law enforcement

- Subpoenas + court orders for user data.
- Emergency requests (imminent harm).
- Transparency report aggregation.

**Tooling needed:**
- Lawful-request portal with verification.
- Templated production formats per jurisdiction.
- Internal escalation + legal review of every request.
- Refusal path documented (overbroad / non-compliant requests).

**KPI (transparency):**
- Number of requests received + complied with + rejected, published per DSA + NetzDG + similar.

## Auditor / compliance officer

- Audits moderation decisions for consistency + policy compliance.
- Audits data handling (right-to-erasure SLA, data export delivery).
- Reviews access logs (mod accessing user data without case open = red flag).

**Permissions:**
- Read-only across full platform with all access logged.

## Stakeholder-driven feature priorities

When deciding what to build:

| If user complaint is from... | Then priority is... |
|---|---|
| End users overwhelmed by notifications | Granular notification settings + debouncing |
| Moderators burning out | Better queue prioritization + content-blurring UI + batch action |
| Creators losing reach inexplicably | Algorithmic transparency + analytics |
| Customer support drowning | Self-serve account recovery + clearer help docs |
| Press covering abuse | Trust + safety investment + transparency reports |
| Regulators issuing fines | Compliance automation + audit logging + lawful-request workflow |
| Advertisers leaving over brand safety | Content categorization + ad placement controls |

## Anti-pattern: "engineering by power-user feedback"

Power users + creators are vocal but represent <5% of users. Optimizing only for them = losing the silent majority. Always cross-check with normal-user analytics before shipping power-user-requested features.
