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
3. **`## Adapt to the codebase`** — a per-framework primitive table (Next / Nuxt / SvelteKit / Astro / Angular / plain / CDN). **Required for any skill that emits fixes.** (`ssr-audit` is the current gap — no table.)
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

Current retrofit targets (do not copy their shape): `data-flow-auditor` and `api-contract-sentry` predate this contract — no Premise, no Verdict line. `ui-reviewer` lacks the coverage table. `accessibility-auditor` banner says WCAG 2.1 but audits a 2.2 SC → re-baseline to 2.2 AA.

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
