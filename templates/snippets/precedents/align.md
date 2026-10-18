# Precedents — Align (declared conventions: oracle, tokens, wrappers, imports, naming, layout, suppressions, ratchets, sweeps)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 and § 10
(the maintainability / conventions column) for every candidate in an **align** class AL-01…AL-34:
the project **declares** a convention (a lint rule at `error`, a written rule, an ADR, a glossary,
a token set, a named wrapper) and a live site does not follow it. Align never invents the
convention and never picks a winner by counting. The oracles that prove a row are in
[`proof-oracles.md`](../proof-oracles.md) § Align (V389–V408). The detectors are
`convention-oracle` (AL-01–04, with `oracle-map.py`), `wrapper-adoption-scan` (AL-11, 13, 14, 15,
22), `naming-layout-scan` (AL-16–19, with `name-check.py`) and `convention-ratchet-scan` (AL-29–32)
(align pack). `align-sweep-gate.py` (under `find-and-align`) owns the sweep classes AL-33 and AL-34.
`align-detect` dispatches them, `/align-scan` audits, and `/align` closes rows through
`find-and-align`.

**Owned elsewhere.** Align reports *the declared convention is not followed*. Where a domain pack
has a detector for the class itself, that pack grades it, and align is at most the **closer** for an
exact-equivalence (EQ) row whose oracle is T1 or T2. A neighbour that sees the same site lists it as
corroboration, deduped by `file:line`. Without the owner's pack, the row prints
`N/A (owner pack <x> not installed)`; align never grades it in the owner's place. The splits:
- Design tokens AL-05–10 and AL-12 are ui-ux `design-token-audit` (`token-map.py` lives there); align closes the EQ rows.
- Layer direction and cross-module private imports (AL-20/21) are code-quality `architectural-diagnosis` §1–§2; align closes only a mechanical re-route through a public surface the oracle names, and rework goes to `/optimize`.
- A copy that diverged from the named helper (AL-13 diverged) is code-quality `duplication-scan` → `/quality-fix`.
- Envelope, casing and pagination (AL-23–25) are backend `edge-error-scan` / `api-consistency-audit` / `http-contract-scan`; `/backend-fix` closes a declared contract, `/polish` introduces one.
- Hard-coded copy and key drift (AL-26/27) are frontend `i18n-scan` §1–§2; align closes only an EQ-key row (§ 31).
- A dropped a11y convention (AL-28) is frontend `a11y-code-scan`; align closes it only as an AL-15 required-prop row.
- Security, performance, database and error-handling rows are never align's; their owners' fix commands close them.

Each entry names when a pattern that *looks* like drift is not, and the evidence that flips it back.
A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the flip
evidence is shown with a `file:line`, an oracle row from `oracle-map.py`, a config line or a recorded
tool run. Numbers are stable, and § n is the research catalog's P-n: detectors cite
`precedents/align.md § <n>`.

Index: the claim, the tiers and the gates · oracle § 1–3 · tokens § 4–7 · wrappers and boundaries
§ 8–12 · names, copy and wire names § 13–15 · frozen code, context and stale docs § 16–18 · run
hygiene § 19–20 · exempt contexts and per-area targets § 21–24 · legacy and reasons § 25–26 ·
batch-6 additions § 27–31 · rationalizations.

## The claim, restated

§ 10 of the protocol takes this shape here. A candidate that fits it with no quoted oracle is not a
finding: it is dropped and counted under AL-01.

> At **[the site, path:line, live code]**, the code does **[the shape: the literal, the raw import,
> the name, the placement, the suppression]**, while **[the oracle: rule id at `error` in the
> resolved config of that file, or a doc path:line, quoted]** declares **[the other shape]** for
> that scope. No documented exception covers it (this file), and it is proven by **[the V-number]**.

**The oracle tiers** (`convention-oracle` § 0 builds them once per run):

| Tier | Source | Produces |
|---|---|---|
| T1 enforced | a rule at `error` in the resolved config for the file, in a package CI actually lints | a Finding (§ 2) |
| T2 written, human | `ai/conventions.md` outside `refine-enriched` markers, ADRs, CONTRIBUTING, DS docs, `ai/glossary.md`, idioms the user confirmed | a Finding, plus AL-03 when no T1 rule backs it |
| T2g written, generated | lines inside `refine-enriched` markers, `[found:]` / `[inferred:]` facts, anything setup wrote from counts | a proposal: Unconfirmed with one ratification probe per rule (§ 28) |
| T3 migration direction | `@deprecated`, a bridge package, a "use X" ban message, an ADR "new code uses X" | T1/T2 when written; a proposal when only observed |
| T4 majority | counts of shapes | never a Finding (§ 1) |
| Contested | `[CONTESTED: A n/N, B m/N]`, rows under `## Unsettled conventions` | AL-02 only (§ 29) |

## Reading the seven gates for align

| Gate | Align |
|---|---|
| 1 Reachability | The site is live code: imported, routed, rendered or built. Dead code goes to code-quality `dead-code-scan`, not alignment |
| 2 Trigger | The next change will meet it: the site is copied, it is in a file added recently, or a sibling already follows the oracle |
| 3 Version | The tool and plugin versions come from the lockfile. ESLint 10.0.0 (2026-02-06) removed eslintrc, so an `.eslintrc*` beside a flat config on ESLint ≥ 10 is dead config (AL-31), not an oracle. TypeScript 7.0 (2026-07-08) ships no programmatic API: typed rules and ts-morph are `NOT RUN` without a `@typescript/typescript6` alias. eslint-plugin-boundaries v7 renamed `rules` to `policies`, and unicorn v65 made `filename-case` check directories; a count jump after either bump is a rebaseline (§ 3), not new drift |
| 4 No existing control | The formatter does not own it (§ 19); no reasoned suppression, ADR exception, `allow` entry or baseline row covers it (§ 3); the wrapper does not already provide it |
| 5 Real impact | A declared convention is not followed at a live site; the next change copies it. Style no rule declares fails here (§ 1) |
| 6 Proof | **The oracle line quoted + the site**: `rg -n -F "<quote>" <oracle file>` ≥ 1, or the rule id at `error` in the resolved config, plus the site `path:line`. A fix adds the V-number of its verb |
| 7 Deployment | — |

## The oracle

1. **(P-01) Majority is not an oracle.** A shape held by most sites but named by no enforced rule and no written convention is AL-02 (a report), never a Finding, even at 95%. The evidence floor (≥ 30 sites and ≥ 0.75 share, sampled from the newest files) only decides between `proposed canonical — ratify?` and `undetermined — ask`; both produce 0 ledger rows. When naming shapes are counted, a one-word lowercase stem (`orders.ts`) fits kebab and camel alike and votes for neither (`name-check.py`'s census, measured 2026-10-18). *Flips back:* a human ratifies the proposal into `ai/conventions.md` outside the generated markers.
2. **(P-02) The config is an oracle even without prose.** A rule at `error` in the resolved config of that file is a declared convention, quoted by rule id and config path. A rule at `warn`, `off`, or in a package no CI job lints is declared but not enforced: AL-03 against the doc, not a Finding at the site. *Read:* the resolved config for one file per package, and `rg --hidden` over `.github/workflows` (rg skips dot-directories otherwise).
3. **(P-03) A reasoned exception is not a finding.** These are documented exceptions:
   - a suppression whose description cites an ADR, a ticket, or the design system's exception prefix (a `polaris:`-style tag);
   - an Nx `allow` entry or an import-linter `ignore_imports` entry;
   - a dependency-cruiser known violation, an ArchUnit freeze entry or an ESLint bulk-suppression count.

   They are reported only under AL-30, and only if they **grew**. *Flips back:* the ADR or ticket id resolves to nothing, or the reason is boilerplate (§ 26).

## Design tokens (ui-ux owns detection; align closes EQ rows)

4. **(P-04) Token definitions are the source, not drift:** DTCG JSON, `@theme`, `:root { --… }`, `[data-theme]` blocks, SCSS token maps, theme TS objects and Style Dictionary output.
5. **(P-05) Values tokens do not cover by design:** `0`, `auto`, `100%`, `1px` hairlines (unless a border-width token exists), `transparent`, `inherit`, `currentColor`, `none`, layout percentages, `calc()` of tokens, `aspect-ratio`. Fixed layout geometry is § 30.
6. **(P-06) Contexts that cannot use tokens:** HTML email (§ 21), SVG illustration and brand-asset fills, canvas, WebGL and chart scales (§ 22), print stylesheets, PDF generators, OG-image renderers, native config colours (`AndroidManifest`, `Info.plist`), and third-party widget overrides that target vendor class names.
7. **(P-07) A literal with no exact token is not a mechanical fix** (AL-06). Snapping changes pixels and is a design decision. It is `report-flagged`; it closes only as a visible change with a recorded approval (V407), or through `/polish` when the scale lacks the step. Never auto-fixed, never under `--safe-only`.

## Wrappers and boundaries

8. **(P-08) The wrapper's own implementation may import the raw primitive,** and so may its stories, tests and adapters, and any module the oracle names as the integration layer (the API-core module may construct the HTTP client).
9. **(P-09) A raw primitive used for a capability the wrapper does not expose is a wrapper gap,** routed to `/unify-surfaces`, not drift. *Read:* the wrapper's prop types or exports; the gap is the missing prop, cited.
10. **(P-10) Composition roots and DI wiring may cross layers:** `main.ts`, `app.module.ts`, `container.ts`, Django `settings.py`, Spring `@Configuration`. Layer and import rules exempt them.
11. **(P-11) Tests may import internals** of the unit under test, unless the oracle forbids it in so many words.
12. **(P-12) Type-only imports do not violate runtime layer or wrapper rules** (`import type`, an all-type specifier list), unless the rule says type edges count (`allowTypeImports: false`, `dependencyTypesNot` without `type-only`).

## Names, copy and wire names

13. **(P-13) Framework-mandated names override naming conventions:** `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `route.ts` under `app/`, `+page.svelte`, `[id].tsx`, `$param.tsx`, `_app`, `__init__.py`, `conftest.py`, `index.*` barrels, Vue SFC `App.vue`, timestamped migrations, `Dockerfile`, `Makefile`, Go `_test.go`.
14. **(P-14) Not user-visible, so not i18n drift:** log and telemetry messages, exception messages users never see, enum and discriminant values, test ids, CSS class names, URLs and route paths, feature-flag keys, analytics event names, brand and product names, units formatted through ICU.
15. **(P-15) Externally fixed names are contract, not alignment:** JSON wire fields (`@Expose({ name })`, `@JsonProperty`, `alias=`), DB columns (`db_column`), env vars, third-party callback names, generated clients, protobuf and GraphQL generated types. A rename there routes to `/refactor` with an ADR. *Read:* the decorator or mapping before calling a name drift.

## Frozen code, context and stale docs

16. **(P-16) Generated, vendored and frozen code is out of scope:** `*.gen.*`, `__generated__`, `vendor/`, `third_party/`, lockfiles, compiled assets, `dist/`, snapshot files, and packages an ADR marks frozen or scheduled for deletion. *Flips back:* the ADR's deletion date has passed; the old shape there is then AL-32 residue.
17. **(P-17) Context-split shapes are not drift:** server vs client components, edge vs node runtime, React Native `StyleSheet` vs web CSS, a CLI package vs the web app, a versioned public API (`/v1`) frozen by ADR, a wrapper rule scoped to client code while the site is server code. *Read:* the rule's `files` / scope glob and the site's runtime.
18. **(P-18) A stale document loses to a consistent, current codebase** (AL-04). When ≥ 80% of sites and ≥ 90% of files added in the last 6 months follow the other shape, the row is "doc stale", routed to a doc update, and the code is not rewritten. Both numbers are triage cut-offs. Without history the row is `AL-04 candidate (history-blind)`. *Flips back:* the newest files follow the doc (a migration toward it, AL-32).

## Run hygiene

19. **(P-19) The formatter owns formatting.** Whitespace, quotes, import order and trailing commas are never align rows when Prettier, Biome, Ruff format or gofmt is configured, and an align commit that changes them is AL-34.
20. **(P-20) A clean scan with a skipped detector is not clean.** A class whose tool is absent, whose oracle is missing, whose rule matched 0 files (V399), whose `rg` exited 2, or whose exclusion list matched an absolute path instead of a root-relative one, is `NOT RUN (<reason>)` or `blocked (<reason>)`, never zero. Measured 2026-10-18: a prototype that excluded `/fixtures/` returned 0 on every fixture because the fixture roots themselves sit under `benchmarks/fixtures/`.

## Exempt contexts and per-area targets

21. **(P-21) Email is exempt from token variables.** CSS custom properties have about 45% estimated support across email clients, and Gmail supports `var()` but not declarations (caniemail, tested 2020-02-25). Inline literals are required.
22. **(P-22) Data-viz palettes are their own token family.** Carbon keeps a separate ordered categorical palette for neighbour contrast. A chart colour that matches no UI token is not drift when a chart palette is declared; when none is declared, it is `/polish`.
23. **(P-23) Brand gradients and decorative art with no matching token stay literal;** adding a token is a design decision. A real HEX → OKLCH token migration (raystack/apsara PR #757, 2026-04-30) left callout and badge gradients, icon SVG fills, a third-party colour picker whose library lacked OKLCH, and likely-dead legacy CSS untokenised, each with a stated reason. Dead CSS routes to code-quality `dead-code-scan`, not alignment.
24. **(P-24) Per-area targets, not 100%.** Almost no screen is pure design system; Productboard (2021) sets a coverage threshold per screen. An area at or above its declared threshold has no adoption finding, but each AL-05 or AL-11 site with an exact replacement still counts.

## Legacy and reasons

25. **(P-25) Matching surrounding non-conformant code is a stated legitimate reason** (PEP 8; the Google style guide lets existing non-conformant code be matched locally). A file *uniformly* in the old style, in a module the oracle has not scheduled for migration, is AL-32 residue under a ratchet, not an IMPORTANT finding. A *mixed* file is a finding.
26. **(P-26) Copy-pasted boilerplate reasons do not count.** The same reason string on more than 5 disables of one rule is reported as an AL-29 cluster for human review; Polaris reviewers named this risk when they required reasons. The threshold is a triage cut-off.

## Batch-6 additions (eval 2026-10-18)

27. **(P-27) A cross-family value match is not exact.** A literal that equals a token of another property family has no EQ replacement: it is AL-06, `report-flagged`. Measured 2026-10-18 on the `web-dashboard` fixture: `padding: 13px` equals `--font-size-sm`, and `token-map.py` classes it a cross-family match (`xfam=`), not EXACT (its classes are EXACT, NEAREST, NONE and EXEMPT). EQ needs the same value in every shipped theme, within one property family, with exactly one semantic candidate (`token-map.py --lookup <value> --family <f>`). Several candidates in one family is AL-06 too, unless the token map is context-keyed, and a context-keyed split is allowed only by role: text, background, border, graphic, shadow, padding, margin or gap.
28. **(P-28) A generated convention line is a proposal until a human ratifies it.** `/setup-project` writes detected conventions (Phase 2's sampled shapes) into `ai/conventions.md` inside `refine-enriched` markers (`phase-4.7-deep.md`). Such a line is T2g: every site of that rule is **Unconfirmed** behind one ratification probe ("confirm `ai/conventions.md:<n>`"), never N Findings. *Flips back:* the same rule appears outside the markers, in an ADR, or at `error` in the resolved config.
29. **(P-29) A contested category is AL-02 even when a document elsewhere names a side.** A `[CONTESTED: …]` row in `_extracted-codebase.md` or a row under `## Unsettled conventions` makes the category a live split. Hook file naming contested there, while the generated block names camelCase, is AL-02, not AL-16. *Flips back:* a human resolves the split (the row leaves the contested set) and writes the winner as T2 or T1.
30. **(P-30) Fixed layout geometry is not token drift unless a size-token family exists.** `width`, `min-width`, `max-width`, `height` and `grid-template-*` values in px are layout decisions. Measured 2026-10-18 by `token-map.py`: layout geometry is the bulk of the NONE class, 24 of 34 non-exempt literal sites across the `web-dashboard`, `quality-mix`, `a11y-states` and `frontend-correctness` fixtures (the eval's earlier prototype found 11 of 15 non-token px values on five roots). *Flips back:* the token source declares a size or container family and the value matches one of its tokens exactly.
31. **(P-31) An i18n literal is EQ only when it equals an existing catalog value and the key resolves in every locale.** "Save" where `common.save` = "Save" in the source locale, under the namespace the convention names, with the key present in every shipped catalog, is an EQ row align may close (V405). New copy ("Archive order", no key) is the owner's: frontend `i18n-scan` §1 → `/frontend-fix`. Template keys with a constant prefix resolve through `catalog-parity.py`'s template-head reading, not by exact string.

## Real-repo additions (2026-10-18)

Measured on a real NestJS + React monorepo (pnpm, turbo, ESLint 10 flat config with a local plugin), read-only.

32. **(P-32) A rule's own narrowing is part of the oracle.** `importNames` / `importNamePattern` (and their `allow` forms) ban only those names; a `!x` entry of a `group` re-includes x (gitignore order); `allowTypeImports` lets types through; an ESLint `paths` name matches that exact specifier, never its subpaths. A hit outside the narrowing is not a site. Measured 2026-10-18: a `fetch*` rule on `@/**` read as "every import" printed 2,740 false AL-22 rows, and a `!…/vocab` re-include 21 more; both 0 after `oracle-map.py` carried the narrowing into `wrappers.tsv`. *Read:* the rule entry itself, not only its group.
33. **(P-33) CI that lints through a task runner still lints.** `pnpm run lint` → `turbo run lint` (or `pnpm -r`, `nx run-many -t`, `--filter <pkg>`) runs each package's own `lint` script in its directory. Read the package script before calling a rule `T1-noci`. Measured 2026-10-18: 31 false `T1-noci` rows (25 rules, 6 of them a plugin's rule map read as config), 0 after the expansion. *Flips back:* the package has no such script, or its script lints a narrower path than the rule's scope (`ci=partial`).
34. **(P-34) A base that is HEAD, or a history that is one day, is no history.** On the default branch the merge-base is HEAD, so a ratchet compared with it cannot grow: `AL-30: NOT RUN (BASE == HEAD)`, never "no growth". A tree where ≥ 90% of the files share one first-add date is an import or a squash: `history-blind`, and "the newest 20 files" is not computed. Measured 2026-10-18: 13,255 of 13,617 files first added on one day.
35. **(P-35) A ratchet may live in a test, and a structural spec is enforcement.** A `const CEILING = 130` or a `'domain -> domain': 40` map in an `*-only-falls.spec.ts`, or a project's own `*-baseline.json`, is a baseline file (AL-30 when it rises; a reasoned `// +1: <why>` raise is Unconfirmed until the oracle says whether that is its declared path). A test that reads the source tree and asserts a shape, run by CI, enforces the doc rule it asserts: that rule is not AL-03. Measured 2026-10-18: 8 ceiling rises across 2 ratchet specs, invisible to the baseline glob before.
36. **(P-36) `-- see above` is a reason; prose that names a directive is not a directive.** A disable whose reason points up takes the comment above it (or the last reason given in the file), and clusters (§ 26) group the resolved reason, not the words `see above`. A config comment that writes `` `eslint-disable-next-line <rule> -- <why>` `` as advice is no directive. Measured 2026-10-18: 68 back-references resolved; 5 prose rows (2 of them "reasonless") gone.

## Rationalizations to reject (align)

**Wrongly accepting (finder side):**
- "It's obviously the team's style." Which oracle line says so (§ 1)?
- "The token is close enough." Then it is AL-06 (§ 7).
- "It's the same number." In which property family (§ 27)?
- "The doc says camelCase." Is that line inside `refine-enriched` markers (§ 28), or is the category contested (§ 29)?
- "I'll fix the formatting while I'm here." That is AL-34 (§ 19).
- "The test needed updating for the new token." The snapshot changed, so the swap was not exact (V394, V408).
- "Most files already do it this way, so the doc is wrong." That needs § 18's numbers, and a human decides.
- "The rule found nothing, so the code is clean." Did it match any files (§ 20, V399)?

**Wrongly dismissing (verifier side):**
- "It's legacy." Legacy is in scope unless § 16 or § 25 applies.
- "There's an eslint-disable." Only a reasoned one counts (§ 3, § 26).
- "It's only a test file." Tests are in scope for naming and layout unless § 11 or § 13 applies.
- "The wrapper can't do that." Show the missing prop; otherwise it is AL-11, not a gap (§ 9).
- "It's just a warning in the config." A declared rule at `warn` is AL-03, not nothing (§ 2).

---

Sources: the align research catalog (2026-10-18) § 4, which gives P-01…P-26 and both
rationalization lists, its tool notes (ESLint 10.0.0 dated 2026-02-06, TypeScript 7.0 dated
2026-07-08, the eslint-plugin-boundaries v7 and unicorn v65 rule changes, ESLint bulk suppressions)
and its evidence notes (PEP 8; the Google style guide on existing non-conformant code; caniemail's
CSS-variables row, tested 2020-02-25; the Carbon data-viz palettes; raystack/apsara PR #757,
2026-04-30; Productboard's adoption post, 2021-06-30; Shopify Polaris PR #7589, 2022-11-03). The
batch-6 align eval (2026-10-18) § 3.1–§ 3.2 and § 4.11 add § 27–31, the tier table and the
measured fixture counts, and § 5 sets the owner splits. Semgrep registry rules, Trail of Bits rules,
Moderne-licensed OpenRewrite modules and the GPL-3.0 golangci-lint and depguard may be recommended
for the user's own run; none is vendored. Paraphrased; no text is reproduced beyond short quoted
identifiers.
