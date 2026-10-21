# Studio creative direction — the `/art-direct --studio` procedure

> **What this is**: the procedure [`/art-direct --studio`](../commands/art-direct.md) follows when the ask is to **impress** — "make it beautiful", "premium", "award-level", "like a top studio would", «أبهرني», «فخم», «بمستوى استوديو عالمي». Six steps, each ending in a written artefact and a STOP check, then a craft-pitfalls list learned on a real run.
>
> **What this is NOT**: a replacement for the usability floor, the parity gate or the coverage gate in `/art-direct`. Those still apply. This lane changes what the run aims at and who judges it.

## Why this lane exists (measured, 2026-10)

A real website job: the homepage of a 38-year B2B travel-management firm, bilingual AR/EN, Arabic first.

- **The normal flow produced hygiene, not impression.** It ran `/design-review` → `/design-first` → `/art-direct --reimagine` (three directions). Every direction was clean: axe 0, AA computed, CLS ≤ 0.055, headline in 0.33 s on slow 4G, 701–784 words without JavaScript. On `design-score` they summed 25, 25 and 24 of 26. The owner rejected all three as "different, not the best a heavyweight creative would do". Three shallow directions, each graded by the agent that built it, cleared every gate and impressed nobody.
- **A studio process worked.** It wrote a strategy brief from assumptions, studied 17 reachable reference sites, picked ONE concept and went deep, built it with the guardrails as constraints, then sent screenshots only to an independent critic. Scores (Design / Creativity / Usability / Content): **7 / 7 / 6 / 7 → 7.5 / 7.5 / 6.5 / 7.5 → 8 / 8 / 7 / 7.5**. Round 3 verdict: "would impress a C-level client: yes; looks like a top studio: yes, just". The guardrails held while the craft went up: CLS 0.003, axe 0 across 10 viewports × 2 locales, 830 words without JS, 305 KB first load on slow 4G.

So the two questions are separate. `design-score` answers "is it clean?". Only an independent critic who sees the page as a jury would answers "is it impressive?" ([`design-score/SKILL.md § What the score measures`](../skills/design-score/SKILL.md)).

## The run directory

Every artefact lives under `.claude/artifacts/art-direct/<iso>/studio/`. Each step's STOP check tests that the file exists and has every required field filled. A missing artefact HALTs the run at that step. "I did the study in my head" fails the check.

| Step | Artefact | STOP if missing |
|---|---|---|
| 1 Strategy | `01-strategy-brief.md` | audience (decides / uses / influences), the one feeling, positioning vs ≥ 2 named competitor types, tone per language, ONE big idea with its signature moment and page arc |
| 2 References | `02-reference-study.md` + `ref/` frames | ≥ 12 sites captured and dated, each with a "wow" line and an "avoid" line; the 10-rule craft bar |
| 3 Concept | `03-concept.md` + `board/board.html` + one `board-<locale>.png` per locale | one direction; signature moment; type system; colour; photo grade; motion choreography + reduced-motion fallback |
| 4 Build | `04-guardrails.md` (measured) | every budget row has a measured number, not a target |
| 5 Critic | `crit/r<N>/` per round: `brief.md`, frames, crops, `verdict.md`, `fixes.md` | a verdict file for every round that ran |
| 6 Owner notes | `05-owner-notes.md` | big idea, scores per round, numbers, what is still below a top studio, the real assets that would lift it |

## Step 1 — Strategy brief (`01-strategy-brief.md`)

One page. Read `ai/project-goals.md` and `ai/users-and-personas.md` when they exist. When the owner cannot answer, **write it from assumptions about the business type**. Head the page `assumptions made from the business type (owner unavailable)` and mark each assumed fact. This file then becomes the named concept oracle that `creative-director` accepts in place of an absent goals file (`concept oracle: 01-strategy-brief.md`).

1. **Audience.** Who decides (and what they are measured on), who uses it daily, and who influences. For premium B2B the influencer is usually the executive who judges the site on a phone in 5 seconds.
2. **The one feeling.** One phrase the page must feel like. Name it as a scene, not an adjective list: "being received at a private terminal at night", not "premium, trustworthy, modern".
3. **Positioning.** What the global or category leaders' sites all do (measure it: capture three of them). Then say where this client cannot win and where it can. Premium usually means **more crafted and more senior**, not more technical.
4. **Tone per language.** Write each language to the same idea, never word for word. Name the verbs the copy uses and the hype words it bans.
5. **ONE big idea.** Draft up to three in one line each, then pick one. The idea must have:
   - a **visual system** (what the brand's colour, shapes and motion stand for inside the idea);
   - a **signature moment**: the one thing people describe after leaving;
   - a **page arc**: the idea carries the page from the first screen to the last, and the close echoes the opening;
   - **a line** per language.

   Mine the client's own material first: its name, its city, its history, its founding year, its logo. The idea that fails the logo-swap test (it could belong to no one else) is the one to keep.

STOP: no big idea with a signature moment and an arc → do not start the reference study.

## Step 2 — Reference study (`02-reference-study.md`)

**≥ 12 reachable sites**, captured the same day, dated. Capture each in headless Chrome at 1440×900 with three frames per site: on load, +900 px, +2300 px. Save the frames under `ref/`. A site that walls the headless browser, times out or renders only its loader is **listed and not scored**; it does not count toward the 12.

Draw them from five pools so the study is not a moodboard of one taste:

| Pool | Why it is in the study |
|---|---|
| The category's global leaders | to measure what is generic, and avoid it |
| The sector's premium tier (e.g. private aviation for travel) | the ceiling inside the sector |
| Adjacent premium sectors (hospitality, luxury retail, private banking) | how restraint, grade and type read as luxury |
| Regional premium brands in the same script and culture | proof that the local script can lead the composition |
| Award-level studio work (Site-of-the-Day regulars, top agencies) | the craft and motion ceiling |

One row per site: `# · site (date) · what creates the wow · avoid`. Every "wow" names something visible in a frame. "Feels premium" names nothing.

Then **distil a 10-rule craft bar**: ten rules this page must meet, each checkable from a screenshot. The measured run used these. Rewrite them per product, keep ten, and keep each one testable:

1. One image, one idea per screen. No collage, no carousel in the hero.
2. Scale contrast is the luxury signal: display type ≈ 9× body (8–10vw on desktop), set tight; everything else small and quiet.
3. One grade for every photo, so stock reads as one shoot.
4. One signature graphic that is **data-true** and owned by this client (a map, a timeline, a product), not decoration.
5. The primary script leads. In a bilingual site with Arabic first, Arabic is composed, not translated.
6. Motion has choreography: one staged entrance, one scroll-scrubbed transformation, line reveals. Nothing loops for attention. All of it off under reduced motion.
7. First paint is content: HTML text plus a poster image. No loader, no blank hero waiting for video or JS.
8. Section colour follows the narrative arc. It is not alternating stripes.
9. One action colour, reachable in the header at every width. The premium accent is never a button.
10. Details hold the premium: hairline rules, tabular figures, real focus states, no broken alt, and no placeholder pretending to be real.

STOP: fewer than 12 scored rows, an undated study, or no craft bar → do not write the concept.

## Step 3 — Concept and moodboard (`03-concept.md`, `board/`)

**ONE direction, deep.** This lane replaces `creative-director`'s three-direction Diverge step. Three shallow directions are what failed. The concept file holds:

- **Story in one breath.** The big idea as the visitor experiences it, from the first screen to the last.
- **Signature moment.** What happens, frame by frame. How it is built (canvas, SVG, WebGL, CSS). Its data source when it shows real data. What the reduced-motion visitor sees instead: the final frame as a still, plus its captions as a list.
- **Typography with character.**
  - A display face with a reason to be here: heritage, place or the logo. Used only at display sizes.
  - A text face that is crisp at body size.
  - At most one accent face, subset to the glyphs it sets.
  - Bilingual with Arabic: pair an Arabic display face with an Arabic text face. Neither is the Latin face's fallback. Arabic body ≥ 17 px (the run used 18 px at line-height 1.9). Every label ≥ 13 px in both scripts. Never letter-space Arabic.
  - **Numerals rule, written once:** Arabic-Indic or Western digits in Arabic display copy. Western digits in data (times, phone numbers, coordinates), isolated with `dir="ltr"` / `<bdi>`. Tabular figures for anything that counts or ticks.
- **Colour.** Base, depth, action (one colour, buttons only), the premium accent (never a button) and the light sections, each a hex value with its job.
- **One-shoot photo grade.** One grade applied offline to every image (shadow tint, highlight tint, saturation, lifted blacks), plus any CSS grain or vignette. Name the crops per breakpoint. List every image that is still ungraded; there should be none.
- **Motion choreography.** The entrance sequence, the scroll-driven moments with their progress ranges, and the micro-interactions. Durations follow [`motion.md`](../ai-patterns/motion.md). Every moment has its reduced-motion form.

The **moodboard** is one HTML board (`board/board.html`): type specimens in every script, the palette, the graded image set side by side, and the signature moment's key frames. Render it to `board-<locale>.png` for each locale. **This board is the approval gate.** The owner approves the concept by looking at it. Under `--canvas`, the board is drawn with `design-canvas` at `$SOURCE=independent`.

STOP: more than one direction, no reduced-motion form for the signature moment, no Arabic face when Arabic is a shipped locale, or no board render → do not build.

## Step 4 — Build, with guardrails as guardrails (`04-guardrails.md`)

The guardrails are the floor the build may not break, **not the goal**. A page that only meets them is the v5 failure again. Measure each row in a real browser and record the number:

| Guardrail | Default budget | How it is measured |
|---|---|---|
| LCP, mobile, slow 4G, every locale | ≤ 2.5 s | Chrome trace or PerformanceObserver per locale |
| CLS, every locale | ≤ 0.1 | same |
| Headline visible, slow 4G | ≤ 1 s | first paint containing the H1 text |
| First-load transfer at 390 px | ≤ 500 KB | network log, no scroll |
| axe (WCAG 2.2 AA) | 0 violations | every capture viewport × every locale |
| Contrast | AA, computed for every pair and state | computed ratios, never a swatch claim |
| Horizontal scroll | none from 360 to 1920 px | `scrollWidth ≤ clientWidth` at 360, 390, 768, 1024, 1440, 1920 |
| CMS-ready content | news / events / lists read from one structured block, with empty and error states | test switches such as `?feed=empty` and `?feed=error` |
| No-JS copy | every heading and the core copy present with JS off | word count with JS disabled > 0, all H1–H2 present |
| Reduced motion | no pinning, no scrubbing, final frames shown | emulate `prefers-reduced-motion: reduce` and capture |

In a repo, the build runs `/art-direct`'s own chain: `design-system-architect` → `/redesign` → `/polish`. For an independent surface with no frontend repo, it authors a standalone page into a folder ([`art-direct.md § Studio lane`](../commands/art-direct.md)). Either way, the guardrails are re-measured after every critic round, because fixes break budgets.

STOP: any row unmeasured or over budget → fix it before the critic sees anything. A critic is not asked to judge a page that fails the floor.

## Step 5 — The independent critic loop (`crit/r<N>/`)

**Who.** A fresh-context sub-agent, a new one each round, dispatched through `Task`. It sees **only**:

- the strategy brief (01);
- the capture pack (below);
- from round 2 on, its own previous `verdict.md`, so it can check its fixes.

It never sees the builder's reasoning, the concept file, `fixes.md`, the code or this procedure. A critic that reads the builder's explanation grades the explanation.

**The capture pack**, rebuilt from scratch every round:

1. **Page frames.** One frame per viewport height down the whole page, at 1440×900 and 390×844 in every locale, plus 768×1024 and 1920×1080 in the primary locale. Tile them into contact sheets, 2 columns on desktop and up to 6 on mobile.
2. **Signature scroll sequence.** The pinned moment captured at fixed progress points (0, 0.15, 0.30, 0.45, 0.62, 0.85, 1). Use the same points every round so the rounds compare.
3. **1:1 crops.** Body text, the smallest label, the signature graphic's labels, the primary CTA and any protected frame, cropped at device scale 1. A downscaled contact sheet makes 18 px body text read as small. Crops are how the critic judges size.
4. Optional **facts sheet**: measured numbers only (font sizes, contrast ratios, guardrail results). No intent, no reasoning.

**The critic prompt** (pass it verbatim, with the brief and the pack attached):

```text
You are an award jury member and an executive creative director at a top studio.
You see a website ONLY through these screenshots, scroll sequences and 1:1 crops,
plus the client's strategy brief. You know nothing about how it was built.
Judge it the way a jury and a demanding client would: is it beautiful, is it
memorable, does it say this client and no other, does it work?

Return exactly:
- Design 1-10 · Creativity 1-10 · Usability 1-10 · Content 1-10 (halves allowed), one line each citing frames
- Would this impress <the target executive named in the brief>? yes / no, and why in one line
- Does this look like the work of a top studio? yes / no, and why in one line
- The 5 biggest weaknesses, ranked, each with: the frame it shows in, and a concrete fix
- The 2-3 strongest frames, which must not be lost in the next round
- If a previous verdict is attached: which of its weaknesses are fixed, partly fixed, not fixed
Judge type size from the 1:1 crops, never from the contact sheets.
Do not soften. A score of 8 means you would put it in front of a jury.
```

**The loop.**

- **Exit** when all four scores are ≥ 8 **and** both answers are `yes`.
- **Maximum 3 rounds.** After round 3 the run stops whatever the scores are, and reports the gap honestly. The measured run ended at 8 / 8 / 7 / 7.5: it was reported as two axes short of the bar, never as passing.
- **Between rounds** the builder writes `fixes.md`: each weakness, the change made, and the frame that shows it. Fix in rank order. Re-measure the guardrails.
- **Protect the strongest frames.** Every frame the critic named as strongest is re-captured at the same position next round and compared. If a fix degraded one, revert that fix and find another way. In the measured run, round fixes that touched the signature moment were the ones that risked it.
- **Record every round.** `verdict.md` keeps the critic's output verbatim. Scores go into the owner notes per round. Never keep only the last one.

STOP: a round with no `verdict.md`, a critic that saw the builder's reasoning, or an exit claimed below the bar → the loop is invalid. Re-run that round with a fresh critic.

## Step 6 — Owner notes (`05-owner-notes.md`)

Written for the client, in the client's primary language, short. Include:

1. **The big idea and the signature moment**, in their own words.
2. **Why it will impress**: the first five seconds, what is data-true, and what competitors' sites do instead.
3. **Craft decisions**: the faces and why, the numerals rule, the colours, the details.
4. **Critic scores per round** in a table with both yes/no answers. List what was fixed each round and what remains unfixed.
5. **The numbers**: every guardrail, against the previous version when there was one.
6. **What real assets would lift it further.** This list is often the most valuable part:
   - a commissioned shoot list (places, the team's real faces, the client's real events, vehicles or aircraft with local registrations);
   - 8–12 s of video for the opening;
   - client logos and one real testimonial, each with written permission;
   - the real figures, addresses and accreditations that are still marked sample;
   - real data for the signature graphic.
7. **Honest gap.** In what ways it is still below a top studio (stock versus a commissioned shoot, 2D versus WebGL depth, client-rendered locales, no human screen-reader or 200 % zoom pass yet).

## Craft pitfalls (learned on the measured run, generalized)

Check each before the critic sees the page. Each one cost a critic round or a point.

| # | Pitfall | How it shows | Fix |
|---|---|---|---|
| 1 | Animating `top` / `left` / `height` | CLS spikes during the entrance or a pinned moment | animate `transform` and `opacity` only; reserve the box |
| 2 | RTL motion direction | marquee, progress fill or slide-in runs the Latin way in Arabic | flip with logical properties and a `[dir=rtl]` sign on every `translateX`; capture RTL separately |
| 3 | Retouched patches | a removed registration, logo or sign shows as a smear in a 1:1 crop | swap the photo or crop the area out; never patch |
| 4 | Frosted header over photos and light sections | `backdrop-filter` smears the photo, then turns muddy over light sections | solid header over light sections; frosted glass only over dark, calm areas, if at all |
| 5 | Bidi-flipped numerals | English shows "+60", Arabic shows "60+" in the wrong place | write "60+" in English; isolate numerals with `<bdi>` / `dir="ltr"` |
| 6 | Wrapping data | coordinates, dates or a label wrap to 2–3 lines on mobile | `white-space: nowrap`, a shorter form, or a smaller tabular size ≥ 13 px |
| 7 | Labels drowning in a dot field | city or point labels lost in map dots | text halo, dim the dots near a label, label ≥ 13 px (14–17 px worked) |
| 8 | Critic misreads type size | "body copy looks small" when it is 18 px | send 1:1 crops; judge size only from them |
| 9 | Empty pinned frames | a progress point of the signature sequence shows nothing | capture every progress point; no frame may be blank or a lone fragment |
| 10 | Mid-motion artefacts | particles or streaks read as scratches halfway through | fewer, tapered, each heading toward its destination; capture mid-transition |
| 11 | The headline fades during a transition | the scene changes and the H1 dims to unreadable | the headline stays legible from the first frame to the last |
| 12 | Empty screens after a pinned moment | a full viewport of flat colour before the next section | measure the gap after every pinned section; hand the motion off straight into content |
| 13 | The last third forgets the idea | news, offices and the form are tidy but carry nothing of the concept | the idea returns at the close, e.g. the route ends at the submit button |
| 14 | Placeholder noise | a "Sample" tag on every line | one tag per card or block |
| 15 | Off-grade images | one or two photos keep a green or blue cast and break "one shoot" | grade every image; check the whole set side by side |
| 16 | Stock with foreign identifiers | an aircraft, car or sign with another country's registration | pick images with no legible registration, or crop it out; list local ones in the shoot list |
| 17 | Invented proof | made-up clients, awards, accreditations, testimonials or dated news | never invent; mark every unverified fact as sample; verify claimed accreditations from the client's own public source |
| 18 | Duplicate live data | two clocks that show the same time | show what differs: open / closed status plus local time |
| 19 | Late first paint in the second locale | the default locale paints fast, the other paints after JS (1.8 s measured) | render each locale on the server (separate URLs, `hreflang`) in production |
| 20 | Builder grades its own work | three directions graded by the builder all score high | the critic is a fresh sub-agent; the builder never scores impression |

## Halt conditions

- An artefact from the run-directory table is missing or has an empty required field at its step → HALT at that step. Never skip ahead.
- More than one direction reaches Step 4 → HALT; studio is one concept, deep.
- The critic received the builder's reasoning, the concept file or the code → that round is void; re-run it with a fresh critic.
- The run reports `studio bar met` with any score < 8 or either answer `no` → refuse. Report the measured gap instead.
- A guardrail regressed after a critic fix and was not re-measured → HALT before the next round.
- Any invented client, award, accreditation or testimonial on the page → HALT. Remove it or mark it sample.
