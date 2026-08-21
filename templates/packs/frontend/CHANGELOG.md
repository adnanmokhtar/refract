# frontend pack — changelog

Release history for `templates/packs/frontend/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

The 1.12.2 entry also carries a **Release narrative**: the `_version.json` `summary` string held a
second, independent telling of the release that had grown well past a one-line stamp. It is
preserved below verbatim and unabridged; `summary` now carries a single line for the current
version.

## 1.14.0 — 2026-08-21

Additive, and small enough to state by count so it can be checked against the diff: `agents/` 1/7,
`ai-patterns/` 1/10, `references/` **6/6**, `_examples/` 2/38, plus `_authoring-standard.md`. Nothing under
`skills/`, `commands/` or `rules/` was touched. **`_topics.md` and `_essentials.md` are unchanged, deliberately**
— no artifact was created this release, so there was nothing to register; the one place a new registration was
argued for is under "Deliberately NOT done" with the reason. Two topics, each starting from something the pack
could not previously say.

**What the automated scan cannot decide, said out loud.** `@accessibility-auditor` carried a WCAG 2.2 AA banner
beside an `a11y-scan` skill, and neither file told the reader how little of 2.2 a scan can reach. axe-core ships
exactly one WCAG 2.2 rule — `target-size` (2.5.8) — and Deque's own position is that it "is likely the only rule
for WCAG 2.2 that will be added to axe-core", "because of how few new success criteria in WCAG 2.2 can be
automated without false positives"
([Deque](https://www.deque.com/blog/axe-core-4-5-first-wcag-2-2-support-and-more/)). There is no `wcag2411` /
`wcag257` / `wcag326` / `wcag337` / `wcag338` tag for a run to match on, so **a green `a11y-scan` is not evidence
on five of the six A/AA additions**. The agent now states that, requires each of those lanes to be graded by hand
or marked `n-a` with the reason it is out of scope, and its coverage table gained a target-size / dragging lane
and marks 2.4.11 as manual. Writing `pass` on a lane because the scan was green is the fabrication its own
Premise forbids — the coverage table records what was checked, not what axe skipped.

**Each 2.2 criterion gained its "does not apply" clause**, cited to the matching W3C Understanding page, because
the four false positives they prevent are the ones a WCAG-2.2 checklist reliably produces. 3.2.6 never requires
help to *exist* ("It is not the intent of this success criterion to require authors to provide help or access to
help") — a product with no contact link anywhere is not a finding. 3.3.7 is scoped to one sitting: it "is not
applicable when a user returns after closing a session or navigating away", so a resume-tomorrow wizard is a UX
call while step 4 re-asking what step 1 captured is a conformance failure — and "available for the user to
select" conforms as fully as auto-population, so a "same as billing" checkbox is a complete fix. 3.3.8 *excepts*
object recognition and personal content at AA, so a "select all the buses" CAPTCHA passes it and must not be
filed as a BLOCKER (it fails 3.3.9, which is AAA). 2.4.11 excepts occlusion the user themselves caused, and its
object is the **component**, not the focus ring — a weak-but-present indicator is 2.4.13 Focus Appearance (AAA),
not this. `ai-patterns/forms.md` gained the matching authoring-side entries: the split `maxlength="1"` OTP
control named as an SC 3.3.8 failure unless pasting into the first box distributes across the rest (one
`<input autocomplete="one-time-code">` passes for free), and the 3.3.7 sitting boundary. Both `_examples/`
mirrors (`accessibility-auditor`, `forms`) were updated in the same change so the fallback does not ship the
older advice.

**A miscount in the 1.13.0 entry, corrected in place.** That entry read "the four A/AA additions" and then
enumerated five of them. WCAG 2.2 adds nine success criteria and drops 4.1.1 Parsing as obsolete; **six are A or
AA** — 2.4.11, 2.5.7, 2.5.8 (AA), 3.2.6, 3.3.7 (A), 3.3.8 (AA) — and 2.4.12, 2.4.13, 3.3.9 are AAA
([W3C, What's New in WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/)). The grading was
never wrong: the 1.13.0 agent already checked all six and its coverage table already had a 3.3.8 row. Only the
sentence was, so it now says "six" with 3.3.8 added to the list. Recorded rather than silently patched, because
a changelog edited without a note is the same class of drift as the sentence it fixes.

**References route to the project's own docs instead of restating them.** All six framework references gained a
docs-routing section, and `_authoring-standard.md` §0 gained invariant **8** as the pack-wide statement of the
rule: a `references/<framework>.md` is the *house opinion* (anti-patterns, ownership boundaries, which lever to
pull), not a hand-maintained mirror of an API surface that moves without it. 1.13.0 is the proof — that release
caught this pack's own `nextjs.md` emitting an API Next had removed. Next.js is the one framework that ships its
docs **inside the installed package**, so `references/nextjs.md` now carries a precedence ladder that stops at
the first rung to resolve: `node_modules/next/dist/docs/` (version-matched, no network) → hosted per-page
Markdown → this file. The version boundary was checked against the published packages rather than assumed —
`next@16.2.0` serves `dist/docs/index.md` as `text/markdown`, `next@16.1.0` 404s — and the file states what to do
on either side of it, including the codemod that fetches a matching copy for older majors and the marker-fenced
`AGENTS.md` block Next 16.3 generates. The other five ship no docs in the package, so each routes to that
framework's hosted machine-readable docs — and each states its **own** shape, because the shapes do not converge:
Vue appends `.md` per page, Nuxt uses a `/raw/` **prefix** with major-segmented paths (appending `.md` returns a
404 JSON body), Svelte publishes tiered whole-doc files and no per-page Markdown at all, React's `.md` is raw MDX
served as `text/plain` and it has no `llms-full.txt`, and Angular's appended `.md` returns **HTTP 200 with
`text/html`** — an SPA shell, which is the dangerous one, because a status-code check reports success while
handing back an empty page. The ladder degrades and never halts: no `node_modules` → hosted, no network → the
reference file, which is exactly why the house opinion still has to be written down locally.

**`_authoring-standard.md` §2's retrofit-target list was stale on all four of its claims** and is now re-checked
against the files instead of against itself. `data-flow-auditor` and `ui-reviewer` both carry a Premise, a
`Verdict:` line and a coverage table after the 1.13.0 re-cut; `accessibility-auditor`'s banner reads WCAG 2.2 AA.
`api-contract-sentry` is reclassified as a **class exception rather than a gap** — it emits an impact report and
says so in its own `description` and Premise ("never a pass/fail verdict"), so the verdict-line item does not
apply to it, the way generator agents already swap items 5–6. §1.1.3 already required closing a gap note in the
same change that closes the gap; this is that rule applied to the list one section down.

**Deliberately NOT done, and why.**

- **No `_topics.md` entry for docs routing**, though one was proposed. Frontend `references/` are not in
  `_topics.md` at all — `templates/phases/phase-4.2-apply.md:318` copies `references/<name>.md` verbatim for
  detected frameworks and never runs them through AUTHOR, so an entry would need a `kind:` and a `fallback:` that
  no mechanism consumes. The convention ships *inside* each reference, which is the file that actually travels to
  the project. `_essentials.md` is unchanged for the same reason: it declares no `references:` key, `--minimal`
  copies none, and a reference-local convention has nothing for minimal mode to carry.
- **The five reference version banners still have not been audited**, and this run produced evidence that at
  least two have drifted. While verifying which packages bundle docs, the npm registry's `latest` resolved to
  Angular 22.1.3 against a banner reading "Angular 17+ / 18 / 19", and `nuxt` to 4.5.2 against a gotcha line
  still calling Nuxt 4 a preview. React 19.2.8, Vue 3.5.41 and Svelte 5.56.10 sit inside their `N+`-shaped
  banners, so those remain literally true but equally un-audited. Each reference now records the exact version
  its docs claims were checked against; re-baselining the banners is a currency audit, which is what the routing
  invariant exists to make less load-bearing, and is not this run's remit.
- **`nextjs.md` is still titled "(App Router, 14 / 15)"** while its new section necessarily spans 14 → 16.3. The
  two are consistent — the scope note under the title already concedes the 14/15 framing — but the title is a
  re-baselining decision, not an additive one.

## 1.13.0 — 2026-08-21

Correctness wave, scoped by count so it can be checked against the diff: every directory in the pack was
touched — `agents/` 7/7, `skills/` 14/14, `commands/` 6/7, `ai-patterns/` 9/10, `rules/` 2/3, `references/` 1/6
— plus `_topics.md`, `_authoring-standard.md`, `_essentials.md` and 18 of the 38 `_examples/` fallbacks.
`rules/migration-frontend.md` and five of the six framework references were **not** re-audited; they are listed
under "Deliberately NOT done" rather than left implied. Every currency claim below was verified against a
primary source in this run; where a source could not be opened, the text says so instead of asserting.

**Things the pack was stating falsely.**

- `a11y-scan` claimed WCAG 2.2 AA while configured for 2.1: `withTags` is an allowlist and `wcag22aa`
  was absent, so SC 2.5.8 Target Size — the criterion `@accessibility-auditor` grades — could not be
  surfaced. Tags re-baselined, and the rule is explicitly enabled because Deque's rule reference states
  the WCAG 2.2 rules ship *"disabled by default, until WCAG 2.2 is more widely adopted and required"*.
  **Newly documented trap, read from the axe-core-npm source:** `AxeBuilder.options()` assigns
  `this.option = options` — it REPLACES the object — so `.options()` must precede `.withTags()` or the
  tag list is silently discarded and the default rule set runs. The skill now ships them in that order
  with the reason inline, plus a verification instruction (the axe API docs do not document how
  `runOnly` interacts with a disabled-by-default rule, so the enable is defensive, not asserted).
  `results.incomplete` is now read and reported as its own "Review items" block: an unresolved review
  item is not a pass. The unsourced "~30% of issues" figure is gone rather than replaced — published
  coverage numbers measure different things and the skill now says what is actually true.
- `streaming-ssr` §5 told the agent to emit `export const experimental_ppr = true` +
  `experimental: { ppr: 'incremental' }`. The Next.js 16 release notes list **both** in the Removals
  table, superseded by Cache Components (`cacheComponents: true` + `"use cache"`). The section is now
  version-gated for 16+ vs 15, because the skill runs against repos on both majors, and halts if the
  enable line is emitted without reading the installed major.
- `references/nextjs.md` shipped the same removed API the bullet above bans, in the file the pack's own
  convention makes **authoritative** for framework specifics — and `@ui-architect` was pointed straight at it
  ("confirm against `.claude/references/nextjs.md` and the version in `package.json`"). A reference that emits a
  deleted API is worse than no reference, so the PPR entry is now version-gated exactly as `streaming-ssr` §5 is
  (15: `experimental_ppr`; 16+: Cache Components — `cacheComponents: true` + `"use cache"`), same source, same
  build-failure warning. The file's header now states its scope honestly: it is written against 14 / 15, only the
  one 16 delta above has been re-verified, and anything config-level or route-segment must be checked against the
  installed major before it is emitted.
- `code-splitting`'s Adapt table offered `next/dynamic(..., { ssr: false })` with no caveat; the Next
  docs state it "is not supported in Server Components. You will see an error if you try to use it."
  `references/nextjs.md` carried the same uncaveated line and now carries the same caveat — the reference and the
  pattern have to agree or the agent picks whichever it read last.
- **Three `data-fetching` detector greps did not work, verified by running them against the doc's own
  examples.** Detector 1's `useEffect\([^)]*...` cannot cross the `)` in `useEffect(() =>` (exit 1, zero
  output). Detector 4's literal `\n` makes ripgrep abort (`the literal "\n" is not allowed in a regex`,
  exit 2). Detector 3's `rg -A2 | rg -v "signal"` filters *lines*, so it drops the `signal:` context line
  and reports the correctly-aborted fetch as a hit. All three replaced with multiline / PCRE forms that
  were run against BAD and GOOD fixtures before shipping, each carrying the reason it is written that way.
- `forms.md`'s async-validation example spread `register('sku')` and then re-declared `onChange`,
  overwriting the library's own handler (its `UseFormRegisterReturn` type declares `onChange`), so the
  field never registered a change and submitted empty. Fixed to pass the callback through the register
  options, with the failure explained — it is silent, which is what makes it expensive.
- `lcp-audit`'s Premise justified itself by saying `fetchpriority` "appears nowhere in the current packs"
  and that `frontend-principles` has no hero carve-out. Both had become false. Replaced with the standing
  justification: the rule states the MUST, only a scan can tell you whether a route has zero or three
  high-priority elements.
- `visual-check` named two different session paths in one file (`test/visual/.auth/state.json` in prose,
  `tests/.auth/user.json` in the scaffold, the config and the MCP arg). Canonicalised on the one the
  scaffold actually writes, and the Playwright-MCP contract (session path, gitignored artifact dir,
  blocked-render HALT) is now declared **shared**, with its ui-ux consumers listed — changing it is a
  cross-pack change. `verify-with-playwright` cites that contract instead of inventing a second one.

**Aged advice corrected, with sources.** `rendering-strategy` said "bundle size = time-to-interactive";
TTI was removed from the Lighthouse 10 scored set (its 10% weight moved to CLS, now 25%) — measure TBT in
the lab, INP in the field. Its "pick ONE strategy per route" hard rule contradicted the pack's own
stream-the-shell MUST and predates partial prerendering: the rule is now "declare the route's rendering
contract" with static-shell-plus-dynamic-holes and server-components-plus-islands as first-class rows.
Its blanket "no client-side fetching on server-rendered pages" is narrowed to re-fetching on mount what
the server already rendered — revalidation is required, not forbidden. `forms.md` dropped
`aria-required` beside a native `required` (MDN: `aria-required` is for controls built from non-semantic
elements) and stopped claiming "some browsers ignore `required`" — the real reasons are that it is a UX
signal, not a security control, and that it is inert under the `noValidate` the file's own example sets.

**`ssr-safety` rebuilt** from the pack's only C-grade pattern to the 1.10.0 shape: per-framework Adapt
table, seven numbered BAD/GOOD detectors with greps that were run before shipping, and closure verbs.
Three of its own contradictions are resolved: the hard rule now grades the **DOM tree**, not
"byte-for-byte" (unfalsifiable at review time, and it made the sanctioned suppression primitive look like
a violation); `typeof window` is graded **by position** — the bug is branching the returned markup, not
the expression itself, which the file previously recommended in one section and forbade in two others;
and "NEVER plain `fetch()` in a component setup block" is scoped to *client* components, because
`await fetch()` in an async Server Component is the documented Next.js primitive and Server Components do
not re-run on the client. New detectors for mismatch-suppression-as-cover-up and for an external store
read during SSR without a server snapshot (React documents that omitting `getServerSnapshot` makes server
rendering throw).

**Cross-pack honesty.** Eight unguarded dispatches into other packs (`api-architect`,
`@design-system-guardian`, `/enhance-ui`, `/design-review`, `design-iterate`, `/align-recheck`,
`/bundle-perf`) now name the owning pack and say what happens when it is absent — the axis is graded
inline and labelled, never silently skipped, and a HALT never redirects into a command the project does
not have. `add-feature`'s existing fallback sentence covered agents only; it now covers agents, commands
and skills. Seven hardcoded `../../<pack>/…` paths that 404 on a frontend-only install are replaced by
bare names + pack tags, which `_authoring-standard §0.7` already required. Nine dead references fixed:
`ai/patterns/components.md` (exists nowhere), the non-existent `a11y.md`/`styling.md` rules,
`@bundle-analyzer` (it is a skill, not an agent), `/ssr-audit` and `/i18n-extract` (neither is a command),
and six skills cited as bare `.md` filenames.

**`add-page` was the only build command that re-inlined the universal pre-flight**, and it dropped five of
the seven reads — including `ai/dynamic/feedback-learned.md`, which is how prior corrections reach a run.
It now links the snippet like its two siblings and keeps only the page-specific reads.

**New: `ai-patterns/auth-session-client.md`** — the largest genuine hole in the pack. The client half of a
login session: the storage trade stated as a trade (XSS blast radius vs CSRF surface vs SSR readability,
not a verdict), single-flight refresh and the 401 stampede that reads as "random logouts" under rotating
refresh tokens, logout as a seven-step fan-out rather than a token delete, cross-tab sync, route-guard vs
render-guard with the three-state `unknown` model, and WCAG 2.2 SC 3.3.8 (paste must work, password
managers must not be blocked). Ownership is stated in the second paragraph: token issuance, rotation and
revocation are the backend pack's, and the *test harness's* session is `visual-check`'s — a different
thing wearing the same word. Ships with its `_topics.md` entry, `_examples/` fallback and an explicit
decision to stay out of `--minimal`.

**Registration + contract cleanup.** `refactor`, `component-playground`, `dev-server-start` and
`verify-with-playwright` had no `_topics.md` entry — `component-playground` is shipped by `--minimal`, so
the pack was shipping an unregistered skill AUTHOR mode could neither generate nor fall back to. All four
registered with `_examples/` fallbacks. `component-playground` gained the prior-art halt it was missing
(if `.storybook/` / `.ladle/` / any `*.stories.*` exists, write a story — do not scaffold a second
explorer), an Output block, failure modes and `## Related`. Banned headings removed (`## Limitations`,
`## Rules`, `## When to use`), and `## Related` added to the six scanners that lacked it — including
`seo-audit`, the reverse link `@technical-seo` had been waiting for. `streaming-ssr` gained the
`## Adapt to the codebase` table §1.1.3 requires of a skill that emits fixes.

**Three cheap a11y gaps closed where the failure is authored**, not in a new artifact: `autocomplete` /
SC 1.3.5 and SC 3.3.7 Redundant Entry as detectors in `forms.md`; SPA route-change announcement (focus +
one live region) as `navigation-speed`'s 8th detector, since it is a navigation mechanism with an a11y
consequence; and table semantics (`caption`, `scope`, `aria-sort`) added to `add-crud-page`'s
sibling-shape halt, which generates tables and never asked.

**All seven agents re-cut, plus two of the three rules.** Every agent `description:` was a capability blurb, so
the seven overlapped at the edges and the dispatcher had to guess; each now carries an explicit trigger set plus a named
anti-trigger set pointing at the sibling that owns the case, and every "sibling agents" section became a
*boundary* section that says where one stops. The cross-pack reads are the substantive change: a read of a
`ui-ux` or `performance` pattern is now gated on that pack being co-installed, with a named inline fallback and
a labelled lane in the output (`SKIPPED (ui-ux pack absent)`, `inline (performance pack absent)`,
`UNVERIFIED (backend pack absent)`) — never a silent skip, and never a pattern name printed for a file that was
not opened. Where two agents could file the same finding, one hard link now says which one owns it: a
locale-omitting cache key is `@data-flow-auditor`'s, not a translation gap; a missing `alt` is an a11y BLOCKER
at `@accessibility-auditor` and an image-indexing nit at `@technical-seo`, filed once.

Per agent, the corrections that mattered. `@accessibility-auditor` claimed WCAG 2.2 AA while grading 2.1 — the
banner is only honest if the six A/AA additions are actually graded, so 2.4.11 Focus Not Obscured, 2.5.7
Dragging, 2.5.8 Target Size, 3.2.6 Consistent Help, 3.3.7 Redundant Entry and 3.3.8 Accessible Authentication
are now checks — Redundant Entry
carrying "there is no reliable grep for this" and a manual walk, rather than a grep that would lie; the
folklore that put an `aria-required` beside a native `required` is gone for the same reason it left `forms.md`;
and the grep for `autocomplete` ships with its own limitation written down (line-scoped, so it misses an
`<input>` whose attributes wrap).
`@ui-architect`'s a11y contract said flatly "Touch targets >= 44×44px", **confusing SC 2.5.8 Target Size
(Minimum) — the AA conformance floor, 24×24 — with SC 2.5.5 (Enhanced), which is AAA and is where 44×44 comes
from** (`@accessibility-auditor` already had the two apart; this was the design side out of step with the audit
side). A design that treats the AAA number as the conformance line over-specifies in one place and
under-specifies in another, so the section now names both and requires the design to say which it holds itself
to. `@ui-architect` and `@ui-reviewer` also both stop asserting a Next cache/revalidate API name from memory:
check `references/nextjs.md` and the installed major in `package.json` first, because that surface has moved
across recent majors and a review that gets it wrong files a false BLOCKER.
`@ui-reviewer` gains the client-session lifecycle its new sibling pattern documents (scattered token access, a
logout that clears the token but not the query cache, N concurrent 401s each firing their own refresh) and now
routes token/theme *fixes* to the ui-ux pack instead of applying them. `@technical-seo` states plainly that LLM
crawlers are out of scope — they read the same server HTML, so the SSR check is the whole of what it can
truthfully claim, and robots-level AI-crawler policy is not this agent's.

`rules/frontend-principles.md`: the ~150-LOC split trigger is restated as a smell threshold that says *look*, not
a rule that says *split* — the real test is more than one reason to change; container-vs-presentational is
restated as the server/client boundary where the framework has one (keep the client boundary low in the tree);
and the blanket `any`/`unknown` ban is narrowed, because `strict: true` types every `catch` binding as `unknown`
and the old wording made correct code a violation — `unknown` is now allowed at a parse boundary and must be
narrowed before it reaches a prop or a render. `rules/i18n.md`: the Must-not banning per-element `dir` was
banning the *layout hack* and reading as a ban on per-element direction as such, which made the correct handling
of runtime text look like a violation; it is now scoped to the hack, and a Must plus a checklist row require
`dir="auto"` / `<bdi>` / `dirname` on user- or API-supplied text, because the root `dir` sets the page's base
direction and cannot rescue an Arabic comment inside an English thread ([W3C i18n](https://www.w3.org/International/questions/qa-html-dir)).
`_authoring-standard.md` §1.1.3 named `ssr-audit` as the outstanding "no Adapt table" gap; both it and
`streaming-ssr` have one now, so the parenthetical says so instead of pointing at closed work.

**Deliberately NOT done, and why.**

- `code-splitting`'s barrel-import detector still lists `date-fns` and `rxjs`: the suspicion that modern ESM
  builds tree-shake from the root barrel was not verified in this run, and rewriting a working detector on an
  unverified guess is how detectors rot. Settling it needs a measured bundle diff, not an opinion.
- **`references/angular.md`, `nuxt.md`, `react.md`, `svelte.md` and `vue.md` were not re-audited for currency.**
  `nextjs.md` was, only because a sibling artifact in this same pass proved it was shipping a removed API. The
  other five may carry the same class of staleness and nobody has looked; treat them as unverified until someone
  does, and read the installed major from `package.json` before emitting any version-sensitive API from them.
- **`rules/migration-frontend.md` was not touched.** It is the V1→V2 parity rule wired directly into the
  migration validator (`extract_inventory_primitives`, `check_per_axis_enumeration`), so re-cutting it means
  reading that validator alongside it — a different piece of work from this pass, and one that is wrong to do
  halfway.

## 1.12.2 — 2026-07-12

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

visual-check auth scaffold hardened so `npx playwright test --project=setup` actually works:
auth.setup.ts now loads .env dependency-free (Node doesn't auto-load it like Vite), and the turn-on
documents the playwright.config `setup` project (a *.setup.ts file doesn't match default testMatch →
"No tests found" without it). Also: MCP screenshots must go to a gitignored dir (.playwright-mcp/ /
test-results/), never repo root — no rm -rf cleanup that trips the destructive-command guard.
visual-check now has a browser-binary PREFLIGHT (step 0): a missing Playwright browser errors with
"Executable doesn't exist" — often misread as a session/MCP failure — so the skill halts with the
one-command fix `npx playwright install chromium` instead. detect-mcp.sh surfaces the same as a
REQUIRED turn-on note when a frontend + playwright MCP is recommended. visual-check now ships the
DEPLOYABLE authenticated-render scaffold + the new-project creds flow, so any auth-gated project
gets it from /setup-project rather than hand-writing it. The design: creds are a secret the machine
can never bake, so the work splits — the machine scaffolds everything (tests/auth.setup.ts
login->storageState, gitignore, .env slot, MCP --storage-state wiring, runbook), the human supplies
ONE secret once (E2E_EMAIL/E2E_PASSWORD in gitignored .env). Until the session exists, an auth-gated
render HALTS with the 3-step turn-on (fix from the prior release) instead of building blind.
Includes the parameterized auth.setup.ts (login route + email/password/submit selectors detected per
project) and works for both token-in-localStorage and cookie auth.

## 1.12.0 — 2026-07-10

- visual-check: new 'Setting this up on a new / auth-gated project' section — the machine/human
  split (machine scaffolds the mechanism; human supplies creds once in gitignored .env), a
  deployable parameterized tests/auth.setup.ts (login->storageState, token-in-localStorage or
  cookie), and the 3-step turn-on (creds in .env -> generate storageState -> point the MCP/harness
  at it) that setup surfaces and the blocked-render HALT enforces.

## 1.11.0 — 2026-07-10

- visual-check: new 'Authenticated rendering' section (detect route guard -> reuse storageState or
  login-once-and-persist -> point the MCP/browser at the session, never --isolated-with-no-session
  for gated routes -> assert a surface-unique marker before screenshotting).
- visual-check: new 'Blocked render = HARD HALT' section + halt condition — a
  login-wall/redirect/marker-absent render is a failure to authenticate, HALTs the caller (RENDER
  BLOCKED), is NOT downgraded to SKIPPED, and the login screenshot is never saved as the surface
  baseline.

## 1.10.0 — 2026-07-09

- ai-patterns +5 (4 -> 9): data-fetching, list-virtualization, error-boundaries, code-splitting,
  realtime-client. Each is a full specialist (Hard-rule Premise + cite-or-halt, per-framework Adapt
  table, BAD/GOOD+grep detectors, closure verbs, bidirectional Related). Closes the client-side
  data/rendering gap surfaced comparing a frontend consumer (15 patterns) vs a backend one (63).
- rules/frontend-principles.md: added backing rules — Must (server-state
  cache/dedup/invalidation-on-mutation + request cancellation; error-boundary resilience + global
  onunhandledrejection net) and Should (lazy pairs with Suspense+error-boundary and never the LCP
  path; realtime lifecycle reconnect/heartbeat/re-auth/teardown/dedup). Virtualization +
  code-splitting Musts already present -> linked to the new patterns. +5 review-checklist items.
- registration: _topics.md + _essentials.md list the new patterns; _examples/ abridged snapshots
  added; siblings (rendering-strategy, forms, ssr-safety, navigation-speed, bundle-analyze,
  lcp-audit, @data-flow-auditor) reverse-linked in the same change.

## 1.9.0 — 2026-07-09

- commands: creation-time enforcement of the SEO/image/font MUSTs (parity with the existing
  lcp-audit/nav gates). add-page.md — Phase 4 generates the metadata primitive
  (title/description/canonical/OG/JSON-LD/hreflang) for public routes + content-image/font guidance;
  Phase 6 dispatches seo-audit/@technical-seo + image-optimization + font-optimization.
  add-feature.md — Phase 6 adds a SEO+asset MUST verification that HALTs on a missing
  metadata/image/font MUST on any new public route (admin routes report seo:n/a). add-component.md —
  Phase 4 + Phase 6 gate image-optimization for image-rendering components.
- skills: brought the four non-conformant skills to the authoring standard. ssr-audit gained the ##
  Adapt to the codebase per-framework boundary table (Next/Nuxt/SvelteKit/Remix/Angular) and a
  BAD/GOOD + grep for the previously pattern-less tenant-from-browser-state detector.
  component-playground rewritten framework-adaptive (Vue/React/Svelte/Angular prop+control mapping,
  project-primitive mirroring, Premise + Halt) — was hard-locked to Vue+PrimeVue+fixed paths. Fixed
  generic-source leaks: a11y-scan + visual-check route matrices use project-mapped placeholders, not
  a baked-in shop shape. Fixed image-optimization next/image AVIF over-claim (WebP default, AVIF
  opt-in).

## 1.8.0 — 2026-07-09

- references: added SEO + Fonts sections to react.md (react-helmet-async / Remix meta;
  Fontsource/Fontaine), vue.md (@unhead/vue useHead/useSeoMeta), svelte.md (svelte:head + prerender;
  Fontsource), angular.md (Title/Meta services + NEW SSR & hydration section:
  provideClientHydration, v19 incremental hydration, SSR-required-for-crawlers). Upgraded nuxt.md
  SEO from useSeoMeta-only to Next-level parity (canonical + hreflang via useHead/@nuxtjs/i18n,
  JSON-LD, @nuxtjs/sitemap + @nuxtjs/robots). Closes the four-of-six references with no SEO section
  and three with no font section.
- agents: retrofit the two legacy agents to the house contract. data-flow-auditor gains The Premise
  (cite-or-halt + hand-wave hard-halt + verdict-matches-body), a Verdict line, and a coverage table,
  and is promoted sonnet to opus (cross-tenant cache-leak + hydration reasoning is judgment-heavy).
  api-contract-sentry gains The Premise (verdict/coverage stay N/A for an impact report).
  ui-reviewer gains the missing coverage table and lists the image/font/seo skills.
- accessibility-auditor: re-baselined WCAG 2.1 AA to 2.2 AA (description, checklist header, and
  Target Size labeled — SC 2.5.8 at 24px AA vs SC 2.5.5 at 44px AAA). Cross-links: technical-seo
  back-links @data-flow-auditor + @api-contract-sentry (was 4 of 6 siblings); ui-architect budgets
  image-optimization / font-optimization / seo-audit.

## 1.7.0 — 2026-07-09

- rules/frontend-principles.md: reconciled with the v1.5.0–v1.6.0 specialists. FIXED P0
  self-contradiction — the blanket `loading="lazy"` Should (which lcp-audit named as the
  anti-pattern it exists to catch) is replaced by a MUST that prioritizes the LCP/hero image
  (fetchpriority/priority, never lazy) and lazy-loads only below the fold. ADDED MUSTs for LCP &
  images (format/srcset/dimensions/CLS), fonts (font-display/self-host/preload/size-adjust
  fallback/woff2/variable), and SEO (unique
  title+description/canonical/OG/JSON-LD/hreflang/SSR-not-CSR/sitemap+robots via the project's own
  metadata primitive). Updated the Hard-rule banner, Review checklist (+3 rows), and Enforcement
  (LCP/image/font/SEO skills + Lighthouse SEO/best-practices categories).
- NEW _authoring-standard.md (meta, not shipped to projects) — codifies the quality bar:
  cross-cutting invariants (cite-or-halt, mirror-the-primitive, negotiated ownership boundaries,
  bidirectional cross-links, currency=WCAG 2.2 AA / CWV=LCP·INP·CLS, generic-source,
  cross-pack-refs-must-resolve); the skill contract by class (scanner/runner/utility); the agent
  reviewer/generator house-contract; the shipped coding-rules index; and a new-artifact conformance
  checklist. Names the current retrofit targets (data-flow-auditor + api-contract-sentry lack
  Premise/Verdict; ui-reviewer lacks coverage table; accessibility-auditor WCAG-2.1→2.2 rebaseline;
  ssr-audit lacks Adapt table).
- Cross-link graph repair: added `@technical-seo` to the ## Related sibling lists of all 6
  pre-existing agents (accessibility-auditor, ui-architect, ui-reviewer, data-flow-auditor,
  api-contract-sentry, i18n-auditor) — the new agent was previously invisible to the pack
  (one-directional link).
- Bug fixes surfaced by the review: navigation-speed.md:46 shipped a U+00AD soft-hyphen inside the
  `eagerness` key of its GOOD Speculation-Rules example (copy-paste → invalid key → prerender
  silently never fires) — stripped to clean ASCII. dev-server-start.md referenced a nonexistent
  `dev-server-stop` sibling skill (reworded to inline PID-kill) and mislabeled the `a11y-scan` skill
  as `a11y-audit` (a command); verify-with-playwright.md had the same a11y-audit→a11y-scan slip. All
  repointed.

## 1.6.0 — 2026-07-09

- NEW skill image-optimization (kind:skill, primary_frontend_framework_detected) — static
  image-delivery scanner. Seven detectors: legacy format with no AVIF/WebP path, missing responsive
  srcset/sizes, missing width/height or aspect-ratio (CLS — the biggest lever), missing below-fold
  loading=lazy (and the inverse: lazy on the hero → lcp-audit), raw <img> where the framework
  component exists, oversized source into a small slot, missing LQIP/blur placeholder. Per-framework
  image-primitive table (next/image, NuxtImg, NgOptimizedImage, astro:assets, enhanced-img,
  <picture>, CDN f_auto). Explicitly cedes LCP priority-hints to lcp-audit.
- NEW skill font-optimization (kind:skill, primary_frontend_framework_detected) — static web-font
  scanner. Eight detectors: missing font-display (FOIT), critical font not preloaded,
  render-blocking remote Google Fonts <link> not self-hosted, no size-adjust/ascent-override
  fallback (swap CLS), full unsubset charset, too many families/weights (→ variable font), legacy
  format before woff2 / missing format(), framework primitive not adopted. Per-framework
  font-primitive table (next/font, @nuxt/fonts, Fontsource/Fontaine). Cross-links lcp-audit for
  text-LCP.
- Registered both in _topics.md (with metadata/primitive extraction) and _essentials.md
  standard-mode skill list; fallbacks _examples/image-optimization.md +
  _examples/font-optimization.md. lcp-audit gains a cross-link to both (LCP image →
  image-optimization for format/dimensions; text LCP → font-optimization).

## 1.5.0 — 2026-07-09

- NEW skill seo-audit (kind:skill, primary_frontend_framework_detected) — static technical-SEO
  scanner. Nine detector families: (1) missing/duplicate/weak title+meta-description, (2)
  missing/wrong canonical, (3) missing Open Graph + Twitter cards, (4) missing/invalid JSON-LD
  structured data with a page-type→@type table
  (Article/Product+Offer/BreadcrumbList/Organization+WebSite/FAQPage), (5) accidental noindex /
  robots Disallow (and missing noindex on private/faceted routes), (6) sitemap.xml + robots.txt
  correctness, (7) i18n hreflang reciprocity + x-default, (8) crawlability of CSR-only content (→
  rendering-strategy handoff), (9) semantic/link signals. Adapts to the project's own metadata
  primitive via a per-framework table; never introduces a second mechanism; never invents JSON-LD
  values.
- NEW agent technical-seo (kind:agent, primary_frontend_framework_detected, model:opus) — persona
  review layered over seo-audit's detectors, adding judgment automated scans can't make
  (schema/page-type fit, canonical intent, index/noindex policy). Severity-graded (BLOCKER:
  accidental site-wide noindex / duplicate titles at scale / CSR-only crawl content; REQUEST:
  missing canonical/OG/JSON-LD/hreflang). Cites file:line; hard-halts on hand-wave grep; hands
  crawlability to rendering-strategy.
- Registered both in _topics.md (technical-seo agent with cite_evidence:strict + metadata-primitive
  extraction; seo-audit skill) and _essentials.md standard-mode skill list. Fallbacks:
  _examples/seo-audit.md + _examples/technical-seo.md.

## 1.4.0 — 2026-06-25

- NEW skill navigation-speed (kind:skill, primary_frontend_framework_detected) — the dedicated fast
  page-to-page navigation specialist: detects missing/disabled link & router prefetch, absent
  Speculation Rules on MPA surfaces, bfcache breakers (unload/beforeunload → pagehide; no-store warn
  per Chrome CCNS 2025), missing route loading-UI, full-reload-instead-of-soft-nav,
  scroll-restoration mishandling, and View Transitions for perceived-instant nav. Per-framework
  prefetch-primitive table.
- NEW skill streaming-ssr (kind:skill, ssr_enabled) — fast-SSR execution specialist (sibling to
  correctness-only ssr-audit): finds routes that block TTFB on the slowest query and proposes
  Suspense / loading.tsx / streamed-promise / renderToPipeableStream boundaries + Next 15 PPR
  candidates, each citing the blocking call file:line + latency + expected TTFB delta.
- NEW skill lcp-audit (kind:skill, primary_frontend_framework_detected) — static LCP-resource
  priority-hint scanner: lazy hero images, missing fetchpriority=high, absent preload/preconnect for
  the LCP image, framework image-primitive priority flag missing. (fetchpriority previously appeared
  nowhere in the pack.)
- ssr-audit: NEW '### Client-boundary cost (React Server Components)' scan section — unjustified
  'use client' directives, boundary-leak of server-only modules, push-down candidates.
- lighthouse-ci: default budgets now assert interaction-to-next-paint (warn 200) +
  server-response-time/TTFB (error 600) + bf-cache; dropped the proposed TTI 'interactive' assertion
  (removed from Lighthouse 10 scored set); added lab-can't-field-measure-INP callout (→
  web-vitals-field) and the no-store-is-warn / unload-is-hard bfcache note.
- All six references/<framework>.md (nextjs, nuxt, react, vue, svelte, angular) gained Navigation &
  streaming + Core Web Vitals / Images sections teaching the framework's actual prefetch + streaming +
  LCP-priority primitives.
- frontend-principles: added Must — Navigation speed (prefetch primary links / Speculation Rules),
  Must — Streaming (stream the shell), Must — Instant loading state (layout-stable skeleton), and
  Must-not — bfcache safety.
- rendering-strategy: added a ranked 'TTFB levers' block (parallelize → edge → SWR → 103 Early
  Hints) + a navigation-speed cross-link.
- Creation commands now ENFORCE the new fast-render/nav MUSTs (not just reference them): add-page +
  add-crud-page wire prefetch / instant-loading / streaming / LCP-priority into Phase-4 generate +
  their Sibling-shape mechanical halt (counts toward gap_count_in==gap_count_closed) + a Phase-6
  navigation-speed dispatch; add-crud-page adds list→detail row-prefetch + list/form skeletons +
  virtualization for the hot list↔detail path; add-feature's Phase-6 perf-budget gate now HALTs on a
  missing navigation-speed / streaming / instant-loading MUST on any new route (regardless of spec)
  and routes field INP to web-vitals-field; add-component gates LCP-priority + INP-budget parity for
  hero / heavy-handler components. New '### Skills' Related subsections list the specialists.
- Review-time enforcement (symmetry with create-time): ui-reviewer gained Navigation-speed +
  Core-Web-Vitals (LCP/INP) checklist sections + streaming + RSC client-boundary checks in SSR
  review, reads inp-responsiveness, and lists the four specialist skills for deep audit;
  ui-architect now decides the streaming boundary in §1 Rendering strategy and budgets
  INP/TTFB/navigation + LCP-element priority in §7 + instant layout-stable loading in §8;
  data-flow-auditor cross-links streaming-ssr on SSR render-time waterfalls. Closes the agent gap
  the original review didn't scope.

## 1.3.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares migration-frontend as a rule (kind:rule, gated by
  migration_layout_detected so it only ships when the migration pack is loaded — mirrors
  backend/migration-backend). rules/migration-frontend.md shipped in the pack but was absent from
  the topic list, so /setup-project AUTHOR-mode generation never surfaced it. Fallback points at the
  canonical authored shape (rules/migration-frontend.md).

## 1.2.0 — 2026-06-16

- add-feature: NEW prior-art gate (Phase 1, all tiers) — distinct from the intent gate (which routes
  the request); searches by behavior for an already-shipped page/flow/component and HALTs to the
  user on a near-duplicate.
- add-feature: NEW new-dependency gate (Phase 4, all tiers) — an npm package no sibling imports
  halts for a dependency review (maintenance / license / bundle-size / supply-chain) before it
  lands; replaces the weaker Phase 7 'ADR proposed' afterthought. Added matching invariant.
- add-feature: standard-tier closure-verb row now requires a bundle-size delta check on any new
  shared wrapper / lazy-route / heavy import (was Phase 6, ungated by tier).

## 1.1.1 — 2026-06-13

- add-feature: wired the universal --plan handoff flag (templates/snippets/plan-flag.md).
- add-feature: sibling-shape halt now maps its per-gap closed/still-open/regressed tracking onto the
  shared per-file verdict vocabulary (aligned/drifted/no-siblings) in
  templates/snippets/sibling-shape-halt.md.

## 1.1.0 — 2026-06-10

- add-feature Phase 6: NEW observability sign-off — error tracking covers new routes/components,
  route-level perf signal + analytics events mirror siblings, no console.* as the only failure
  signal; projects with no observability layer report 'observability: none configured' explicitly.
- add-feature Phase 6: NEW release note (heavy tier) — feature flag or flagless-with-rationale,
  rollback path, staging/preview verification.
- add-feature Phase 4: missing-agent fallback — uninstalled reviewers are performed inline against
  their pack/domain checklist, never silently skipped.
- add-feature: 'Phases applied' now tier-scoped (heavy = all 7; trivial/standard run their
  ceremony's subset) — matches the closure-verb table instead of contradicting it.
- _topics.md: add-feature topic entry added (was missing — AUTHOR-mode generation never produced the
  command despite it shipping in the pack).

## 1.0.0 — 2026-04-26

- Initial baseline.
