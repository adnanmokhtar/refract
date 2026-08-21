# Frontend pack — authoring standard

The quality bar every artifact in this pack must clear. Derived from the reference exemplars (`skills/lcp-audit/SKILL.md`, `skills/seo-audit/SKILL.md`, `agents/accessibility-auditor.md`, `agents/technical-seo.md`) and the shipped coding-rules file (`rules/frontend-principles.md`). Read this before adding or editing a skill, agent, rule, pattern, reference, or command.

This file is **meta** (how the pack is authored). It is not shipped into target projects — `frontend-principles.md` is the shipped coding-rules standard; the two must stay reconciled (a skill/agent that enforces X implies a MUST/SHOULD for X in the rule).

---

## 0. Cross-cutting invariants (apply to every artifact)

1. **Cite-or-halt.** Every finding cites `<file:line>` + the matched pattern + the fix. A claim without a citation is "a vibe, not a finding." State this verbatim.
2. **Mirror the project's own primitive; never impose a second mechanism.** Detect what the codebase already uses (image component, font loader, metadata API, i18n lib) and route fixes through it. This is the single biggest differentiator between a strong artifact and a generic template.
3. **Negotiated ownership boundaries.** When two artifacts touch the same surface, each states what it owns and disclaims the rest — in prose AND in Halt conditions. Reference model: `lcp-audit` (LCP *priority*) ↔ `image-optimization` (format/dimensions/loading) ↔ `font-optimization` (loading/swap-CLS).
4. **Bidirectional cross-links.** Adding an artifact means updating the siblings' `## Related` sections in the *same* change. A one-directional link is drift (this is exactly how `@technical-seo` was initially left invisible to the other six agents).
5. **Currency with reasoning.** Keep CWV thresholds, framework API names, WCAG version, and Lighthouse audit ids accurate — and state *why* inline where it matters (gold standard: `lighthouse-ci` explains why lab-INP ≠ field-INP and why TTI was dropped). Baseline: **WCAG 2.2 AA**, Core Web Vitals = **LCP / INP / CLS**.
6. **Generic source — no project names.** Route matrices and examples use illustrative placeholders, never a baked-in shop/app shape (`/products`, `/checkout` hardcoded is a leak). See the repo-wide generic-source rule.
7. **References may be cross-pack, but must resolve.** `web-vitals-field` / `inp-responsiveness` live in the *performance* pack; `motion` / `rtl` / `design-systems` / `theming` in *ui-ux*; `caching-strategy` in *backend*. Referencing them is fine when those packs co-install — reference by bare name, don't hardcode a relative `../../<pack>/…` path that dangles when the pack is absent.
8. **Route to the installed docs; do not restate them.** A `references/<framework>.md` carries the *house opinion* — the anti-patterns, the ownership boundaries, which lever to pull. It does not restate the framework's API surface from memory: a hand-maintained snapshot drifts, and this pack has proved that on itself (1.13.0 caught `references/nextjs.md` shipping an API the framework had removed). Where a framework ships docs **inside the installed package**, that copy is version-matched to `package.json` and outranks the reference file — today only Next does, and `references/nextjs.md` owns the version boundary and the generated-`AGENTS.md` mechanics. Where it does not, route to the hosted machine-readable docs; their URL shape and even their existence differ per framework, so each reference opens with its own docs-routing section (`## Machine-readable docs`, or for Next the local-copy ladder) rather than assuming one convention holds. The ladder must **degrade, never halt**: no `node_modules` → hosted; no network → the reference file, which is why the house opinion still has to be written down here. Where the docs and the reference disagree about an API, the docs win and the reference is stale — say so in the diff instead of quietly emitting the older call.

---

## 1. Skills — three classes, one spine

Not every skill is a static scanner. Hold each to the parts of the contract that apply to its class.

| Class | Examples | Required sections |
|---|---|---|
| **Scanner** (emits cited fixes) | lcp-audit, seo-audit, image-optimization, font-optimization, navigation-speed, streaming-ssr, ssr-audit | ALL of §1.1 |
| **Runner** (drives a tool) | lighthouse-ci, bundle-analyze, a11y-scan, visual-check | Premise · Prerequisites/Procedure · Output · gotchas · Halt (no `Adapt`/`Scans for`) |
| **Utility / generator** | dev-server-start, verify-with-playwright, component-playground | Premise · Procedure · Failure-modes · Halt (+ per-framework mapping if it generates code) |

### 1.1 Scanner contract (the full spine)

1. **Frontmatter** — `name` + a **specific** `description` that names the detectors, not vague ("turns 'optimize X' prose into cited detectors"), plus which sibling it sits beside.
2. **`## Premise`** — names the failure mode + states cite-or-halt + "X without the cited element is not a finding."
3. **`## Adapt to the codebase`** — a per-framework primitive table (Next / Nuxt / SvelteKit / Astro / Angular / plain / CDN). **Required for any skill that emits fixes.** (No current gap: `ssr-audit` and `streaming-ssr` both carry one as of 1.13.0. When a retrofit lands, delete the gap note in the same change — a stale target list is drift, and this file is the only place that catches it.)
4. **`## Scans for`** — numbered detectors, each a **BAD/GOOD code example AND a grep/heuristic**. No rule stated without a way to match it.
5. **`## Output`** — a literal report with `file:line` + a closure verb (`report-with-fix` / `halt-handoff`).
6. **`## False positives / gotchas`** — encodes the carve-outs so the next scan doesn't re-flag them (lazy-below-fold is correct; self-canonical is correct; `font-display: optional` is deliberate).
7. **`## When to run`.**
8. **`## Halt conditions`** — refuse a finding without its citation; refuse a second mechanism; hand off out-of-scope work by name.

Section headings are the contract — use `When to run` / `False positives / gotchas` (not `When to use` / `Limitations` / `Rules`) so the pack is greppable by a single section vocabulary.

---

## 2. Agents — the reviewer house contract

A conformant **reviewer** agent has, in order:

1. **Frontmatter** — `name` + `description` + `model`. Judgment-heavy reviewers (cross-tenant reasoning, hydration root-causing, schema/index policy, a11y, SEO) = **`opus`**. Purely mechanical grep/taxonomy scanners may be `sonnet` — but the choice is deliberate.
2. **`## The Premise (read first, do not deviate)`** — states verbatim: (a) every finding cites `<path:line>` + a 1-line real excerpt or it's a vibe; (b) **hard-halt on the hand-wave token grep** (`etc.` / `…` / `consider` / `seems` / `might` / `probably` / `N+ similar`) — re-enumerate each instance; (c) **the verdict line must match the body**. Domain agents may add a 4th clause (technical-seo: "the crawler reads server HTML"; i18n: "coverage stats reconcile with the BLOCKERS list").
3. **`## Pre-flight`** — reads the real rules/patterns and mirrors the project's primitive. Patterns named here must exist (in this pack or a co-installed one).
4. **`## Checklist`** — categorized, greppable, ships the actual `rg` commands.
5. **`## Example findings`** — graded **BLOCKER / REQUEST / NIT**, each with file:line + Impact + Fix (fix in the project's own primitive).
6. **`## Output`** — `Verdict: APPROVE | REQUEST_CHANGES | BLOCK` **plus a coverage/pass-fail table** + a "Patterns consulted" line.
7. **`## Hard rules`** — map each defect class to a severity tier.
8. **`## Related`** — **all sibling agents** (kept in sync), a **Skills** subsection (only skills that exist), the **actual** patterns the agent reads, and the rule.

**Generator** agents (`ui-architect`) swap items 5–6 for a design-doc output + anti-patterns list, but keep 1–4, 7–8 and the "cite 2–3 sibling files or halt before designing" discipline.

**No outstanding retrofit targets as of 1.14.0** — the four this line used to name have closed or been reclassified, each re-checked against the file rather than against this list. `data-flow-auditor` and `ui-reviewer` carry a Premise, a `Verdict:` line and a coverage table after the 1.13.0 re-cut; `accessibility-auditor`'s banner reads WCAG 2.2 AA and all six A/AA additions are graded. `api-contract-sentry` is a **class exception, not a gap**: it emits an impact report and says so in its own `description` and Premise ("never a pass/fail verdict"), so item 6's verdict line does not apply to it — an impact-report agent still owes items 1–4 and 7–8, and an under-listing report is the failure mode its Premise hard-halts on. Put a target back here the moment one appears: a gap list nobody re-checks reads as "all clear" while the gap is still open, which is exactly how the WCAG line above survived its own fix.

---

## 3. Coding-rules + best-practices standard (shipped)

The MUST/SHOULD set the pack enforces lives in **`rules/frontend-principles.md`** — that file is the source of truth; this section is the index. Every skill/agent must have a backing MUST/SHOULD there (if it enforces a concern the rule is silent on, the rule is stale — fix it in the same change).

Axes the rule MUST cover (all present as of the v1.7.0 reconciliation):
- **Component & state** — typed props/emits/slots, container/presentational split, data-fetch in hook/composable/service, domain stores, one styling system, design tokens.
- **Accessibility (WCAG 2.2 AA)** — semantic HTML, labelled inputs, icon-button `aria-label`, visible focus, keyboard reachability, no a11y regressions.
- **i18n** — every string a key in every locale, typed dynamic keys, RTL logical properties, ICU plurals, `Intl`, **hreflang** for localized indexable routes.
- **Navigation & rendering** — prefetch primary links, stream the shell, layout-stable skeleton, bfcache-safe, one rendering strategy per route.
- **LCP & images** — LCP image eager + prioritized, **never lazy**; content images: modern format, `srcset`/`sizes`, explicit dimensions (CLS), lazy below the fold.
- **Fonts** — `font-display`, self-host, preload the critical font (`crossorigin`), size-adjusted fallback (swap-CLS), woff2-first, variable font ≥3 weights.
- **SEO** — public/indexable routes: unique title+description, canonical, OG/Twitter, page-appropriate JSON-LD (visible content only), correct `noindex`, sitemap+robots; SEO routes SSR/SSG/prerendered, never CSR-only.
- **Observability & bundle** — error tracking + route-level web-vitals/RUM, bundle-size budget gate, virtualize lists >100, lazy-load routes + heavy deps.

---

## 4. Conformance checklist for a new artifact

- [ ] Correct class contract (§1 skill / §2 agent) — all required sections present with the house headings.
- [ ] Cite-or-halt Premise; Halt conditions enforce it.
- [ ] `## Adapt` per-framework table if it emits fixes (skills) / mirrors the project primitive (agents).
- [ ] Detectors are BAD/GOOD + grep; no rule without a matcher.
- [ ] Ownership boundary with overlapping siblings stated in prose + Halt.
- [ ] `## Related` lists all siblings; **the reverse links were added to those siblings in this same change.**
- [ ] A backing MUST/SHOULD exists in `frontend-principles.md` (add it if the concern is new).
- [ ] Registered in `_topics.md` + `_essentials.md`; `_version.json` bumped with a changelog entry; abridged `_examples/<name>.md` added.
- [ ] `docs/COMMANDS.md` updated; no dangling cross-refs; no hardcoded project names; no non-ASCII in code examples.
