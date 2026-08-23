---
name: audit-failure-modes
description: "Named anti-patterns observed in real V1↔V2 migration audits. Each entry: symptom, why-it-happens, prevention, real-world incident."
kind: example
pack: migration
---

> **STACK ASSUMPTION**: this example uses Vue 3 + PrimeVue + TypeScript syntax for illustration. The rule / pattern / anti-pattern itself is universal; substitute your project's primitives from `_extracted-idioms.md`. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack pack's fingerprint set automatically.


# Audit failure modes — named anti-patterns

> Source: real incidents in production migrations. New entries added when a migration audit ships a regression that traces to a procedural failure (not a one-off bug). Each entry's "Real-world incident" anchors the pattern; the abstraction generalises.

This file is referenced from `migration-discipline.md` § Anti-patterns and from `parity-auditor.md`'s pitfalls list. It exists because the gap between "discipline rule" and "audit shipped that broke parity" is usually one of the patterns below — none of which is "the engineer didn't try."

## 1. The Trusted Summary

**Symptom**: An audit declares two implementations "identical" or "parity-clean" without a per-axis enumeration. The classification is correct in feel but wrong in detail.

**Why it happens**: The executor delegated V1↔V2 comparison to a search/exploration agent (Explore, Grep wrapper, RAG-style retrieval). The agent returned a high-confidence summary like *"V2's form is identical; same 6 fields, same submit endpoint, same redirect."* The executor echoed the summary into the audit file. The agent's summary was based on reading entry-point files only; it never enumerated the form-template's `<input>` / `<button>` elements line by line.

**Why it slipped audit**: The audit file passed file-presence checks; the audit's classification matched the agent's summary; nothing in the toolchain demanded per-axis enumeration.

**Prevention**:
- Use `parity-auditor` agent (or its 10-halt checklist inlined). Generic Explore/search agents are NOT acceptable for AUDIT.
- Enforce per-axis enumeration in `audits/<feature>.md`: every form field listed, every button listed, every query param listed. No `&...`, no "etc.", no "..." in the table body.
- Read the V1 source files yourself for the load-bearing claims — never trust an agent's summary for "are these forms identical?"
- Run `scripts/validate-migration-artifacts.sh` — it greps for hand-wave tokens in audit files.

**Real-world incident**: F039 (geography-mappings) in <frontend-v2>, audited 2026-04-29. Audit declared V1↔V2 parity-clean. User flagged: V1 had an "add new mapping" button + 4 query params V2 didn't render. Both gaps were invisible in the audit because the contract-extraction agent's summary said "form fields identical" and the executor copied that into the audit file without verifying. Root cause: `migration-phase.md`'s soft language ("use the project's audit agent or generic parity-auditor") let the executor substitute a search agent for a verifier.

---

## 2. The Hand-waved Query Param

**Symptom**: An audit's "Endpoints" or "Inputs" axis lists `GET /endpoint?foo=&bar=&...` (note the `&...`) hiding 2-6 unenumerated parameters. V2 sends a subset; the missing params are silent regressions.

**Why it happens**: The contract-extraction step ran a `grep` on V1's list-call construction, found the obvious params, and shorthand'd the rest with `...`. The audit-file consumer copied the shorthand without expanding it.

**Why it slipped audit**: Hand-wave tokens (`&...`, `etc.`, `…`) read as "these are equivalent" to humans. They aren't.

**Prevention**:
- Contract's Inputs section enumerates EVERY query param V1 sends — by reading the V1 service file's call construction line by line.
- Validator script greps audit + contract files for hand-wave tokens; flags any.
- Audit reviewer's checklist: "If you see `...` in any axis row, it MUST be expanded before the audit ships."

**Real-world incident**: F039 — V1 list-call sent `?source_type=&source_name=&internal_entity_type=&order_by=&page=&per_page=`. Audit said `?source_type=&source_name=&...`. Audit declared identical; V2 sent only `?source_type=&source_name=` — 4 missing params. The V1 caller relied on `internal_entity_type` filtering for the filter dropdown. UI broke silently in shadow.

---

## 3. The Optimistic Form Field Match

**Symptom**: An audit declares V1↔V2 form fields "identical" in a table cell without enumerating them. V2 is missing a field, has a wrong type, or has a missing validator.

**Why it happens**: Contract has form fields under "Inputs" but as prose ("submit body"); never enumerated as a per-field table. Audit echoes the prose without enumeration.

**Why it slipped audit**: Field-by-field is tedious; "identical" is one word.

**Prevention**:
- Contract's Inputs section is a per-field table: name, type, validators (declared + inline), default, placeholder, required, hidden-when, disabled-when. NOT prose.
- For frontend features, contract's "Form fields" axis is mandatory per `migration-discipline.md` § Frontend audit axes.
- Audit echoes the table; doesn't summarise.

**Real-world incident**: A different <your-org> feature (not F039 — flagged during the F039 retrospective): V1 had an `is_active` switch + a `keywords` chip-input + a `default_currency` dropdown on a form; V2 dropped `default_currency`. Audit said "form fields identical." Field count matched on the surface (3 fields) — but the names didn't.

---

## 4. The Permission-gate Drop

**Symptom**: V1 hides an action via `v-if="hasPermission('foo.create')"` / `{user.can('foo.create') && ...}`. V2's port renders the action without the gate. **Security regression.**

**Why it happens**: Audit checks "submit endpoint protected" (server-side authz) but doesn't enumerate per-button gates. Server-side authz catches the request; UI showing the button to a user who can't use it is a UX regression that quickly becomes a customer support ticket.

**Why it slipped audit**: "Auth + permissions" axis in the generic 6-axis comparison maps to endpoint authz, not per-element UI gating.

**Prevention**:
- Frontend audit axes (`migration-discipline.md` § Frontend audit axes) enumerate "Per-button permission gates" as its own axis.
- Audit table for any frontend feature has a `Permission gate` column for every UI affordance row.
- Component-level parity test asserts: "given user with permission set X, button Y is/isn't rendered."

**Real-world incident**: Hypothetical, but flagged in F039 retrospective. Whether F039's "add new mapping" button was permission-gated in V1 has not been verified at audit time — the button itself was missing. If V1 had a `hasPermission('mappings.create')` gate and V2 had to re-add it, the gate decision needed to be in the audit.

---

## 5. The Skipped Contract

**Symptom**: An "audit" file exists; a "parity test" exists; the row says `parity_test: passing`. But no contract file exists at `ai/migration/contracts/<feature>.md`. The audit is verifying what the executor *thought* the contract was — not what V1 *actually does*.

**Why it happens**: `/migration-phase` Phase 4a says "Output: `ai/migration/audits/<feature-id>.md`" but doesn't require `contracts/<feature>.md` to exist first. The executor skips the extract-contract step ("V1 is small / I read it once / it's obvious") and writes a thin audit summary instead.

**Why it slipped audit**: `/migration-gate`'s old check was "audit file exists" — file-presence ≠ content. A summary audit passes.

**Prevention**:
- `/migration-gate` (post-fix) checks `contracts/<feature>.md` exists with all 9 sections.
- Validator script enforces the 9-section requirement.
- `/migration-phase` (post-fix) dispatches `/port-feature` per row, which mandates `extract-v1-contract` per `feature-port.md` Phase 1.

**Real-world incident**: All 24 audits in <frontend-v2> Phases 3-5 (Apr 2026). The `contracts/` directory was empty (`.gitkeep`-only) for the entire run; audits were summary-shaped without contracts behind them. F039 surfaced first; the others remain unaudited at proper depth.

---

## 6. The Thin Corpus

**Symptom**: A "parity test" exists with 4-15 hand-written cases. Tests are green. Production reveals divergence on inputs the tests didn't cover.

**Why it happens**: Hand-written cases reflect what the test author *thought* V1 does. Production has 1000s of inputs the author never imagined. Without record-replay or property-based fuzzing, the test set is necessarily a subset of the contract.

**Why it slipped audit**: "Parity tests passing" ≠ "every contract surface has a corresponding assertion." The discipline rule says ≥30 corpus inputs (or record-replay setup); a 7-input file passes the literal "parity_test: passing" flag.

**Prevention**:
- `parity-test-generate` skill mandates ≥30 inputs OR record-replay.
- Validator counts files in `inputs/` and refuses gate if <30 (and no replay setup).
- Property-based tests cover invariants the hand-written cases don't.

**Real-world incident**: Phase 3 auth tests in <frontend-v2> — F001 (login) had 6 cases, F002 (register) had 10, F006 (check-auth) had 7. Each green; each insufficient relative to the discipline floor.

---

## 7. The Stale Plan Reference

**Symptom**: `migration-phase.md`'s plan says feature F042 has a "P1 GAP — build inline edit table or ADR." Audit by inspection of V2 code shows V2 already has inline edit + bulk save. The plan is stale; the audit conscientiously notes the gap as closed-by-inspection. **Time wasted re-deciding.**

**Why it happens**: Plans inherit verdicts from a prior audit cycle ("Mar 2026 audit said dialog-only"). V2 evolved between plan-write time and audit time. The plan didn't get re-checked at audit-start.

**Why it slipped: it didn't slip (the audit caught it). But it cost a full feature-cycle of "is this still a gap?" verification when the plan should have been refreshed first.**

**Prevention**:
- `/migration-replan` between phases or before the next phase if the codebase has shipped meaningful changes since the plan was written.
- Audit step starts with: "verify plan still describes V2's current state; if not, halt + replan."

**Real-world incident**: F042 (shipping-costs) in Phase 5 — plan classified as P1 GAP per Mar 2026 audit; audit-by-inspection in Apr 2026 confirmed V2 already shipped the missing functionality. No code change needed; the plan just hadn't been refreshed.

---

## 8. The Auto-import Trip

**Symptom**: Parity tests for `.vue` (or framework-equivalent) files fail with `useI18n is not defined` / `useRouter is not defined` even though the production code works fine.

**Why it happens**: The project uses an auto-import plugin (`unplugin-auto-import`, Nuxt's `auto-import`, Vite's `vite-plugin-auto-import`) in production. The test config (`vitest.config.ts`, `jest.config.js`) doesn't include the plugin. Auto-imported symbols resolve in production but not in tests.

**Why it slipped audit**: Audits don't run tests; they read source. The test never ran in audit-only mode.

**Prevention**:
- Test config mirrors production plugin chain. Validator script can grep both configs for the auto-import plugin and flag mismatches.
- `parity-test-generate`'s helper "create runner" branch (per `parity-test-generate.md` § 4) writes the test config alongside the test files.

**Real-world incident**: <frontend-v2> Phase 4 — page-level parity tests for F008 (Welcome), F095 (DomainSettings), F090 (Profile), F102 (ErrorPage), F103 (Maintenance) all failed with auto-import errors on first run. Fix: add `unplugin-auto-import/vite` to `vitest.config.ts`. Caught during port-phase test development, not at audit; should have been a `parity-test-generate` precondition.

---

## 9. The defineExpose-Less Page

**Symptom**: Page-level parity test mounts a `<script setup>` page; tries to access internal functions (`saveProfile`, `addDomain`) via `wrapper.vm.X`; gets `undefined`. Tests can't drive page logic without DOM interaction.

**Why it happens**: `<script setup>` doesn't auto-expose internals. Without `defineExpose({...})`, the test has only the rendered DOM as a surface. For pages with inline business logic (vs composable-extracted), DOM-only testing is brittle.

**Prevention**:
- Pages with inline business logic add `defineExpose({...functions...})` (production-safe; only consumed by parent components or — here — tests).
- Better: extract business logic to a composable; test the composable directly (unit-test pattern).
- `migration-discipline.md` § Frontend anti-patterns lists "Per-page inline business logic" as anti-pattern; the fix is composable-extraction.

**Real-world incident**: <frontend-v2> Phase 4 — F090 (Profile) and F095 (DomainSettings) had inline business logic; tests required `defineExpose`. F007 (Dashboard) and F099 (Activity-logs) had composable-extracted logic; tests trivially mounted the composable.

---

## 10. The KeepAlive-onMounted Mismatch

**Symptom**: Page tests assert `onActivated`-fired API calls. Mounting via vanilla `mount()` doesn't fire `onActivated` because Vue's KeepAlive isn't wrapping the component. Tests fail with "expected mock to be called once, was called 0 times."

**Why it happens**: `onActivated` only fires inside `<KeepAlive>`. Test mounts a bare component without the wrapper.

**Prevention**:
- Test wraps the page in `<KeepAlive>`: `mount({ template: '<KeepAlive><Page /></KeepAlive>' })`.
- `parity-test-generate.md`'s frontend recipe documents this for cached pages.

**Real-world incident**: F090 (Profile) in <frontend-v2> — `onActivated(fetchProfile)` test failed; resolved by wrapping in `<KeepAlive>`.

---

## How to add to this file

When a new audit failure surfaces in production:

1. Name the pattern (3-5 words; verb-form preferred — "The X Y").
2. Describe symptom (observable evidence).
3. Trace why it happened (procedural failure, not bug).
4. Identify why audit missed it (which check should have caught it).
5. Document prevention (rule change, validator check, agent halt condition).
6. Anchor with a real-world incident (date, project, feature, what shipped).

Submit as a PR to `templates/packs/migration/_examples/audit-failure-modes.md`. The migration pack's `_version.json` bumps a patch on each addition.
