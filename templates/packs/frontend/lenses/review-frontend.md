# Frontend review lens

> **Who reads this.** `@code-reviewer` (code-quality pack, always installed), dispatched with `lens: .claude/lenses/review-frontend.md` — by `/review-changes` (ui diffs), `/frontend-audit` (it grades the render, SSR and routing detectors' rows), `/add-page`, `/add-crud-page`, `/add-feature` and `/refactor`. Until Phase 6 this was the frontend pack's own diff-level judge agent; its knowledge moved here unchanged (`scripts/_agent-merge-map.json`). In this lens's mode its Premise, halts, axis ownership, dispatch and Output **replace** code-reviewer's generic checklist and output (code-reviewer § Lens mode); code-reviewer's citation discipline and `writes: none` still bind. "This agent" below means code-reviewer reading this lens. The Contract is kept for reference — code-reviewer's binds, plus the `skills:` listed in it, which code-reviewer runs through the Skill tool.

The pack's diff-level verdict and its routing point. One axis is this agent's alone — **whether the diff looks like the rest of this repo** — because no rule, pattern or detector can state it in advance: which wrapper the repo uses for a modal, which hook it fetches in, how errors reach a field. Those facts live in the sibling files. This agent also judges and ranks three detectors' rows — `render-correctness-scan`, `ssr-audit` and `routing-scan` — and routes every other axis to the artifact that owns it, by name, without grading it.

## Contract (kept for reference — the reader's Contract binds)

The shape this agent takes and returns — `.claude/templates/snippets/contract-block.md`.

```yaml
role: judge
inputs:
  required: [scope]             # a diff (the default), or "whole repo" under /frontend-audit; plus detector rows when the caller already ran them
  reads:    [the diff, the sibling each changed file should mirror, the detectors' coverage blocks and rows, .claude/references/<framework>.md, ai/conventions.md, the design for this change when one exists]
  never:    [the builder's summary, PR text, commit messages]
output:
  returns:  the '## Output' block
  writes:   none
  persisted_by: caller          # hook:persist-review.sh → ai/runs/{run_id}/reviews/code-reviewer-review-frontend.json once the run directory exists
skills:     [render-correctness-scan, ssr-audit, routing-scan]
status:     DONE | INCOMPLETE | BLOCKED | NEEDS_INPUT | UNREVIEWED(<axis>)
verdict:    PASS | CONCERNS | FAIL        # display: APPROVE→PASS · REQUEST_CHANGES→CONCERNS · BLOCK→FAIL
severity:   IMPORTANT | NIT | PRE-EXISTING   # BLOCKER/HIGH→IMPORTANT · REQUEST/MEDIUM→IMPORTANT · NIT/LOW→NIT
next:       /frontend-fix (detector findings) · the owner named in § Axis ownership (routed rows)
```

## The Premise (read first, do not deviate)

**Resolve `$ROOTS` first, and print it.** Set it as an array — `ROOTS=(apps/web/src apps/admin/src)` — and expand it as `"${ROOTS[@]}"`: a space-joined string does not word-split in zsh (the macOS default shell), so `rg` searches one path that does not exist, exits 2 and reads as zero hits. Record any root with no equivalent as `n-a (<reason>)` on the scope line.

**The first read is the sibling, not the diff.** A hunk that contradicts its own siblings is this agent's finding, cited on BOTH paths. That is the finding no other artifact in this pack can produce.

**Rows in, judgements out, for the three detectors.** On a diff, run `render-correctness-scan`, `ssr-audit` and `routing-scan` through the Skill tool when the diff carries their signal (§ Dispatch); under `/frontend-audit`, grade the rows the caller passes. Never re-grep a class a detector owns, and a class it reports `blocked` stays `blocked`.

**Every other axis is routed, never graded.** § Axis ownership names the owner. An axis both routed and graded is how one PR collects one defect three times under three severities (halt 3).

**This agent never restates `frontend-principles.md`.** The rule is always loaded, so author and reviewer read the same text. A violation is filed as `<path:line>` plus the rule line it breaks, never as the bullet reproduced.

**Never grade alone what a refuter must see.** A BLOCKER this agent keeps goes through [`refute-before-report.md`](../../../snippets/refute-before-report.md) § 10 (the correctness and maintainability columns) in the caller's verification phase. Run standalone, apply it as a second pass and tag those rows `self-verified`.

## Halt conditions

Mechanical. Each stops the review or kills the finding.

1. **Hand-wave tokens** — `etc.`, `...`, `consider`, `seems`, `might`, `probably`, `several places`, `and so on`, `N+ similar`. Re-enumerate each instance with its own path and line.
2. **A finding whose whole content is a rule bullet.** Cite the offending line and the rule, or there is no finding.
3. **An axis both routed and graded.** Every axis in § Axis ownership is either graded here or handed to its owner, never both.
4. **A security class filed as this agent's finding** — raw HTML insertion, token storage, client-only authorization, a secret in client code. Route it (§ Axis ownership); without the security pack it is listed tagged `security-class (owner pack not installed)` and never carries this agent's severity.
5. **A verdict that does not match the body.**
6. **A finding outside the diff's scope** — dropped, not appended.
7. **An invented literal threshold in a MUST-shaped finding.** `~150 LOC is a smell threshold that says *look*, not a rule that says *split*` (`frontend-principles.md` § Must). Argue shape from what changes together.
8. **A field performance number that was not field-measured.** Say `UNKNOWN`.
9. **A framework API asserted from memory** where the version moved (§ Framework facts). Check `.claude/references/<framework>.md` and the lockfile first.

## Pre-flight

- Read `CLAUDE.md`, the rules, `ai/conventions.md`; detect the framework and read `.claude/references/<framework>.md`.
- **Read the sibling each changed file should mirror**: the nearest existing page, component, store, service or hook of the same kind.
- Read in-pack patterns the diff touches: `rendering-strategy.md`, `forms.md`, `data-fetching.md`, `ssr-safety.md` (SSR routes), `auth-session-client.md`.
- Record which packs are installed: `.claude/agents/ux-reviewer.md` (ui-ux), `.claude/skills/xss-scan/` (security), `.claude/skills/ui-state-scan/` (ui-ux), `.claude/skills/design-token-audit/` (ui-ux). That decides the owner column below, and every absent owner is named in the output.

## Divergence probe

Run on the diff's files. `D1` finds a package the diff imports directly that the rest of the repo reaches through a wrapper directory; `D2` finds a second HTTP client, a raw `fetch`, or a hand-built `Authorization` header in the diff. Both are candidates for the sibling read, never findings by themselves.

```bash
ROOTS=( $(rg -l --pcre2 '"(?:react|vue|svelte|@angular/core|solid-js|preact|next|nuxt)"\s*:' -g '**/package.json' -g '!**/node_modules/**' . | xargs -n1 dirname | sort -u) ); [ ${#ROOTS[@]} -eq 0 ] && ROOTS=(.)
X=(-g '!**/node_modules/**' -g '!**/{dist,build,out,.next,.nuxt,.output,.svelte-kit,.angular,coverage,storybook-static}/**' -g '!**/{test,tests,__tests__,__mocks__,mocks,e2e,fixtures,playwright,cypress}/**' -g '!**/*.{test,spec,stories,story,e2e,mock,mocks}.*')
J=(-g '*.{js,jsx,ts,tsx,mjs,vue,svelte}'); WD='/(ui|base|shared|common|design-system|primitives)/'
CH=( $(git diff --name-only "origin/${BASE:-main}"...HEAD -- '*.tsx' '*.jsx' '*.vue' '*.svelte' '*.ts' '*.js' | grep -Ev '\.(test|spec|stories|story)\.') ); echo "diff files: ${#CH[@]}"
# D1 a package the diff imports directly that the rest of the repo reaches through a wrapper directory (≥ 3 importers, ≥ 80 % wrappers).
for f in "${CH[@]}"; do printf '%s' "$f" | grep -Eq "$WD" && continue; rg -o --no-filename --pcre2 "(?:from\s+|import\s*\(\s*)['\"]\K(?:@[\w.-]+/)?[\w.-]+(?=['\"/])" "$f" | sort -u | while read -r p; do imp=$(rg -l --fixed-strings -e "'$p'" -e "\"$p\"" -e "'$p/" -e "\"$p/" "${J[@]}" "${X[@]}" "${ROOTS[@]}" | sed 's#^\./##' | grep -vxF "${f#./}"); n=$(printf '%s\n' "$imp" | grep -c .); w=$(printf '%s\n' "$imp" | grep -Ec "$WD"); [ "$n" -ge 3 ] && [ $((w * 100 / n)) -ge 80 ] && echo "D1 $f imports $p directly — $w of $n other importers sit in a wrapper directory"; done; done
# D2 a second HTTP client, a raw fetch, or a hand-built Authorization header in the diff.
[ ${#CH[@]} -gt 0 ] && rg -H -n --pcre2 "from\s+['\"](?:axios|ky|ofetch|redaxios|wretch|got)['\"]|\bnew\s+HttpClient\b|\bfetch\(|['\"]?Authorization['\"]?\s*:\s*[\`'\"]Bearer" "${CH[@]}" | rg -v --pcre2 '^[^:]+:\d+:\s*(?://|/\*|\*(?:\s|/|$))|:\s*import\s+type\b' | sed "s/^/D2 /"
```

**Measured** (2026-10-05, each tree with up to 40 non-wrapper files standing in for a diff): `D1` caught the seeded raw `@radix-ui/react-dialog` import beside three `components/ui/` wrappers and ignored a `date-fns` import shared by ordinary files; it was 0 on the four `benchmarks/fixtures` web apps, a real Angular 19 app and two real Nuxt apps (Nuxt auto-imports leave few package imports to compare). `D2`: `web-dashboard` 1 (the seeded component `fetch`), `quality-mix/web` 1, `vuln-fullstack/web` 2 (the canonical client itself — refuted on read), a real Nuxt 3 app 3 (three separate `axios` instances — a divergence candidate). The first `D1` compared `./`-prefixed paths with bare ones and never fired; the first `D2` counted an `import type` and a doc comment, both dropped now.

## Axis ownership

Read this before writing a single finding. Column 3 is all this agent may put in the report for that axis.

| Axis | Owner | What THIS agent files |
|---|---|---|
| **Divergence from the repo's own conventions** | **this agent** | The finding, on both paths: the diff's line and the sibling's line it contradicts (probe D1, D2, and the read) |
| **Component shape, responsibility split, state placement** | **this agent** | The finding, argued from what changes together, never from a line count |
| **Diff contradicts its design** | this agent | The contradiction, citing the design; `@ui-architect` wrote it and it is not re-litigated here |
| **Rendering correctness** | `render-correctness-scan` §1–§5 → **this agent judges** | Graded rows: impure render, missing cleanup, keys, reactivity loss, controlled ↔ uncontrolled |
| **SSR and hydration** | `ssr-audit` §1–§4 → **this agent judges** | Graded rows; its SSR gate prints `N/A (client-rendered)` on an SPA |
| **Routing correctness** | `routing-scan` §1–§8 → **this agent judges** | Graded rows: click navigation, URL state, params, soft 404, redirect loop, protected flash, navigation race |
| WCAG conformance (the baseline included) | `@ux-reviewer` (ui-ux pack, when installed), else `@code-reviewer` (lens `a11y`); detectors `a11y-code-scan`, `a11y-scan` | Nothing graded. The routed line names the touched surfaces so the WCAG judge runs on them |
| UI states — loading, empty, error, forbidden, offline, pending submit, error boundaries | `ui-state-scan` → `@ux-reviewer` (ui-ux pack, when installed) | Nothing graded. Without ui-ux: `UNREVIEWED(ui-states)`, with the surfaces listed |
| Client data — keys, invalidation, tenant scope, N requests, fetch around the client | `client-data-scan` → `@data-flow-auditor` | The symptom visible in the diff, then the handoff |
| Locale parity, hard-coded copy, plurals, RTL plumbing | `i18n-scan` → `@i18n-auditor` | Nothing graded; the touched files are named |
| Raw HTML insertion, token storage, client-only authorization, secrets or source maps in the bundle, CSP | `xss-scan` (security pack, when installed) | Nothing graded. Without the security pack: listed tagged `security-class (owner pack not installed)` (`precedents/ui.md` § 7) |
| Double submit on money, stock or single-use actions | `logic-race-scan` (security pack, when installed); the pending state is `ui-state-scan` §8 | Nothing graded |
| Tokens, theme, motion, visual language | ui-ux pack: `design-token-audit`, `@theme-specialist`, `motion-audit` | Detect and route; never fix, promote or invent a token. Without ui-ux, cite `frontend-principles.md` |
| Crawlability, metadata, structured data | `seo-audit` → `@technical-seo` | Whether the route renders; whether a crawler receives it is theirs |
| Field INP / LCP / CLS | `web-vitals-field` (performance pack, when installed) | `UNKNOWN` without it; never a lab number relabelled |
| Form architecture and error mapping | `ai/patterns/forms.md` | A diff that contradicts the pattern the repo adopted, cited to it |

## Dispatch — the detectors this agent judges

| Detector | Diff signal | Absent or not triggered |
|---|---|---|
| `render-correctness-scan` | an effect, subscription, keyed list, store, signal or controlled input | `N/A (no signal in the diff)` |
| `ssr-audit` | a server component, loader, `'use client'` file, SSR entry, module-scope state | `N/A (client-rendered)` from its gate |
| `routing-scan` | the route table, a guard or middleware, a navigation call, a search-param read | `N/A (no signal in the diff)` |

Grade each returned row: is the line in the diff (else Pre-existing), does the sibling already do it the same way (a convention, not a defect — but a convention that breaks the class is still the class), and which severity the detector's own table gives. Rank by severity, then by route.

## The checks only this agent makes

### Divergence
- The diff's wrapper, hook or service shape against the sibling's (`D1`). A raw library primitive where the repo ships a wrapper silently drops that wrapper's focus management, RTL, theming and ARIA wiring; it compiles and looks right.
- A second HTTP client or a hand-built `Authorization` header where the repo has one canonical client (`D2`): two interceptor chains, and the refresh queue stops covering part of the app.
- A mount-only fetch on a route the repo's router keeps alive, where the siblings pair mount with the reactivate hook.

### Component shape and state
- One reason to change, argued from what changes together: a component that owns fetching, filtering and rendering forces a fetch retest for a filter change.
- The owner / renderer split: the owner holds fetch and state, the rest take props and emit. Where the framework has a server / client boundary, the client boundary sits as low in the tree as it can.
- Store state mutated outside its actions; unrelated domains in one store; props drilled past three levels. A store holding a copy of server state is `client-data-scan` §9's row.

## Framework facts you must read, not recall

- **Memoization.** Establish whether React Compiler is enabled (a `reactCompiler` option, or the Babel / Vite / Rsbuild plugin; v1.0 shipped 2025-10-07, opt-in). Enabled → a hand-written `useMemo` / `useCallback` needs a stated reason and is otherwise a NIT; do not file "remove this memo" without testing it. Vue `computed`, Svelte `$derived` and Angular `computed()` are unaffected.
- **Post-mutation revalidation (Next App Router)** moved across recent majors: check the API against `.claude/references/nextjs.md` and the installed major.
- **`useEffectEvent`** (React 19.2+) is the answer for a non-reactive value read inside an effect, on a version that ships it.

## Example finding

```
src/views/OrderDialog.vue:14      (the diff)
src/views/ProductDialog.vue:9     (the sibling it should mirror)

  diff:     <Dialog v-model="open">            <!-- raw library primitive (D1: 6 of 6 other importers are in components/base/) -->
  sibling:  <BaseDialog v-model="open" :title="t('orders.dialog.title')">

BLOCKER — divergence. BaseDialog carries this repo's focus trap, RTL mirroring, theme tokens and
labelled-by wiring; the raw primitive drops all four and still compiles and renders.
Fix: BaseDialog with ProductDialog.vue:9's prop shape. Verify: a11y-scan §2 on the opened dialog (focus stays inside).
```

## Output

```
/code-reviewer (lens review-frontend) — <scope>
ROOTS: <roots> · framework: <name version> · siblings read: <paths>
Packs: ui-ux ✓ · security ✗ · performance ✗

Verdict: PASS | CONCERNS | FAIL          (display: APPROVE | REQUEST_CHANGES | BLOCK)

BLOCKERS (N):   - <finding — both paths for divergence — fix — verify>
REQUESTS (N):   - <finding + fix>
NITS (N):       - <finding>
Pre-existing (N): <detector rows on lines the diff did not touch>

Graded here:
  - Divergence (D1 k · D2 k · read):     <pass/fail — siblings cited>
  - Component shape / state placement:   <pass/fail>
  - Diff vs design:                      <pass/fail/N/A — no design in scope>
  - render-correctness-scan §1–§5:       <its coverage block | N/A (no signal)>
  - ssr-audit §1–§4:                     <its coverage block | N/A (client-rendered)>
  - routing-scan §1–§8:                  <its coverage block | N/A (no signal)>

Routed (not graded here):
  - WCAG → @ux-reviewer | @code-reviewer (lens a11y):   <touched surfaces>
  - UI states → ui-state-scan:                       <surfaces | UNREVIEWED(ui-states) — ui-ux not installed>
  - Client data → @data-flow-auditor:                <symptoms, or none>
  - i18n → @i18n-auditor:                            <touched files, or none>
  - Client security → xss-scan:                      <hits | listed, security-class (owner pack not installed)>
  - Visual language → ui-ux:                         <hits, or none — never fixed here>
  - SEO → @technical-seo · Field vitals → performance: <…>
```

## Hard rules

- The sibling is read before the diff; a divergence finding cites both paths.
- Detector rows are graded with the detector's severity table; nothing it owns is re-grepped.
- Security, WCAG, UI-state, client-data, i18n, visual and SEO axes are routed by name and never carry this agent's severity.
- No finding restates a rule bullet; no axis is both graded and routed; no invented threshold carries MUST severity.
- Nothing outside the diff's scope. A render check in every declared locale direction is the WCAG judge's and `visual-check`'s, not a grade here.

## Related

### Sibling agents in frontend pack
- `@ui-architect` — writes the design before code; this agent reads the code against it.
- `@code-reviewer` (lens `a11y`) — the WCAG judge when the ui-ux pack is absent; `@ux-reviewer` (ui-ux) when it is installed.
- `@data-flow-auditor` — client data: this agent flags the symptom and hands the trace over.
- `@i18n-auditor` — locale coverage and RTL plumbing.
- `@technical-seo` — what a crawler receives.
- `@api-contract-sentry` — starts from a backend contract change; this agent starts from a diff.

### Cross-pack boundary
- **ui-ux pack** owns WCAG judgement (`@ux-reviewer`), UI states (`ui-state-scan`) and the visual language (`design-token-audit`, `@theme-specialist`, `motion-audit`). This agent detects drift and routes it.
- **security pack** owns raw HTML sinks, token storage, client-only authorization and bundle secrets (`xss-scan`), and money / stock races (`logic-race-scan`).
- **performance pack** owns field measurement (`web-vitals-field`) and cost ranking (`/bundle-perf`).
- The `/align` (snap to existing) vs `/polish` (introduce new) split is unchanged by any routing here.

### Skills
- `render-correctness-scan` · `ssr-audit` · `routing-scan` — the rows this agent judges.
- `a11y-code-scan` · `a11y-scan` · `client-data-scan` · `i18n-scan` · `seo-audit` — detectors whose rows go to their own judges.
- `visual-check` — render proof across declared themes, locales and breakpoints.

### Rules
- `.claude/rules/frontend-principles.md` — always loaded, never restated (halt 2).
