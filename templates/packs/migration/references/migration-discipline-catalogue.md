# Migration discipline — examples & anti-pattern catalogue

> Companion to `.claude/rules/migration-discipline.md` (the always-loaded core). Loaded on demand during audits and reviews — NOT auto-loaded into every session.
> Rule-only tools: ships alongside the core rule in your adapter bundle.
> Content relocated verbatim from the core rule on 2026-06-07; wording unchanged.

## Examples per concern (parity / scope / perf-uplift / cutover)

### Parity preservation

```text
# ❌ Behavioural drift (silent break)
V1: getUser(missingId) returns null
V2: getUser(missingId) throws NotFoundError

→ Caller code that did `if (user) {...}` now crashes.
→ This is an INTENTIONAL break that requires an ADR + caller-migration plan.
→ It MUST NOT ship in the port PR. The port preserves V1's null-return; the break ships separately on V2 only.

# ✅ Parity-preserving improvement
V1: SELECT * FROM users WHERE id = ?  (returns 47 columns, hydrates 47-field model)
V2: SELECT id, name, email, status FROM users WHERE id = ?  (returns 4-field DTO)

→ External observable: a JSON object with the 4 fields the caller documented (V1's caller never read the other 43).
→ Parity test asserts the 4 fields match V1's response shape.
→ Network + memory + GC win, no contract change.
```

### Scope discipline

```text
# ❌ Mission creep
Port PR title: "Port /reports/orders + add CSV export + cache + pagination"
→ 4 things in 1 PR. Reviewer can't tell which change caused which delta. Rollback is all-or-nothing.

# ✅ Atomic
Port PR 1: "Port /reports/orders (parity-equivalent)" — V2 endpoint shadows V1, parity green.
Perf PR 2: "Add Redis cache to /reports/orders V2" — measurement included, parity tests still green.
Feature PR 3: "Add CSV export to /reports/orders V2" — V1 didn't have this; pure-V2 feature, on V2 only.
Feature PR 4: "Paginate /reports/orders V2 (deprecating non-paginated response)" — ADR + caller migration plan attached.
```

### Migration-time perf uplift (the user's specific concern)

| V1 anti-pattern | V2 with parity-preserving uplift |
|---|---|
| `for (id of ids) const u = await getUser(id)` (10 sequential awaits) | `Promise.all(ids.map(id => limit(() => getUser(id))))` with `pLimit(8)` — bounded parallel |
| 1 query + N follow-ups (`getOrders` then `getCustomer(o.customerId)` per order) | Single JOIN OR `getCustomersByIds(unique(orderCustomerIds))` (batch) |
| `SELECT * FROM users` consumed by template that uses 3 fields | `SELECT id, name, status FROM users` |
| No cache; same lookup repeated per request | Per-request memoisation (request-scoped cache) OR cross-request cache (Redis) with explicit TTL + invalidation rule |
| Missing index on `WHERE created_at > ? AND status = ?` (V2 query shape changed) | New migration adds composite `(status, created_at)` index; rehearse via `migration-rehearsal` |
| `findAll().filter(x => x.active)` | `findWhere({ active: true })` — push the filter to the DB |
| Single 200-row `INSERT` per loop | Batched `INSERT INTO ... VALUES (...), (...), (...)` |
| Synchronous external HTTP in a hot path | Move to background job + return optimistic response (only if contract allows; ADR otherwise) |

Each row in this table is a `perf-uplift-survey` finding. Each finding gets a decision in `ai/migration/perf-decisions/<feature>.md`: applied / deferred / rejected, with: V1 cost (wall-clock + DB load), expected V2 saving, parity-preservation argument.

### Cutover rigor

```text
# ❌ Big-bang cutover
Day 1: Deploy V2; flip env var V2_ENABLED=true; route 100% traffic.
Day 2: Customer reports breakage; rollback requires re-deploy.

# ✅ Progressive cutover
T+0d: Shadow — V1 serves; V2 receives copy of every request; outputs compared offline.
T+7d: Parity-bug fixes from shadow; shadow re-runs clean for 7 days.
T+14d: Canary 1% — V2 serves 1% of traffic. Watch error rate / latency / business KPIs for 24h.
T+15d: 10%. T+16d: 50%. T+17d: 100%.
T+24d: V1 traffic = 0 confirmed via telemetry.
T+38d: Delete V1 (after 14d of zero traffic).
```


## Anti-patterns (named)

- **The Zombie Port** (added 2026-05-02) — porting a V1 feature that has zero callers. The feature is dead code; porting it migrates rot from V1 into V2, inflates V2's surface area, and creates a maintenance burden for code no consumer exercises. The fingerprint: a feature whose 6-axis reachability check (app source / tests / cron / route registration / infra / production telemetry) returns zero callers, yet the migration plan still queues it. The fix: dead V1 code is excluded from the port queue at scan time (halt #11), marked `status: deprecated` with `deprecation_reason: dead-v1-no-callers`, and deleted from V1 directly during V1 retirement — never touches V2. Override only via `--include-dead` + `caller_evidence: <path:line>` proving a missed caller. Real-world cost: every zombie port ships ~50–500 lines of V2 code that exercises no test, has no consumer, and accretes onto V2's maintenance budget. A 200-feature migration with 15% dead code = 30 zombies = ~10K lines of pure waste in V2.
- **The Transposition Trap** — line-by-line copy of V1 into V2. Carries V1's bugs + V1's hidden invariants. The port must be re-derived from the contract AND must follow V2's NEW structure (shared wrappers, conventions, file layout). Concrete fingerprints are stack-specific and live in the per-stack packs:
    - Frontend fingerprints → `frontend/rules/migration-frontend.md § Frontend Transposition Trap fingerprints`
    - Backend fingerprints → `backend/rules/migration-backend.md` (if defined)
    - The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack fingerprint set automatically.

  **Phase 3 of `/port-feature` (Retrieve) MUST list the gold-standard V2 files the executor reads BEFORE writing.** The plan's "V2 patterns I will follow" section names them explicitly. Skipping Phase 3 is the trigger — the executor opens V1, reads it, opens V2's destination directory, and writes by analogy to V1 instead of by analogy to V2's gold standard.
- **The Bundled Cutover** — porting + redesigning + adding features + perf-tuning in one PR. Reviewer cannot localise regressions; rollback is all-or-nothing.
- **The Stale Oracle** — V1 evolves during port; parity tests pass against a moving target. Pin V1's commit; freeze it for the duration of the port.
- **The Silent Break** — V2 changes an output shape, returns a different error type, drops a side effect. Ships unnoticed; long-tail customer issues surface for months.
- **The Test-by-Test Port** — porting V1's unit tests verbatim. Misses production behaviours that V1 has but V1's tests don't cover. Use record-replay against real traffic samples (anonymised).
- **The Eternal Shadow** — V2 lives in shadow indefinitely "until we're sure". The longer V2 stays in shadow, the more divergent it becomes from V1 (which keeps shipping). Set a cutover deadline; if missed, re-baseline parity.
- **The Buried Perf "Improvement"** — an N+1 fix that quietly changes ordering / nullability / ID stability. The "improvement" is a contract break; ships under the port PR; surfaces as a bug 6 weeks later.
- **The V1 Deletion Sprint** — deleting V1 modules en masse "to clean up." A single `import` left in a stale cron job means a silent prod failure when the cron next fires. Delete only when last reference is gone + telemetry confirms zero traffic.
- **The Trusted Summary** — delegating V1↔V2 comparison to a search/exploration agent that returns "looks identical" in confident summary language; the executor echoes that into the audit without verifying claim against source. The audit is a checklist, not a vibe-check; every "identical" claim has a `<path:line>` citation that resolves OR the audit halts. (Canonical real-world incident: a missing add-button + divergent query-param surface both passed audit because the summary said identical. Lesson: trust agents to *find* sources, not to *verify* equivalence; verification reads source line by line.)
- **The Hand-waved Query Param** — audit declares "GET /endpoint?foo=&bar=&..." with `&...` as the trailing surface, hiding 4 unenumerated params. The contract's Inputs section enumerates EVERY param V1 sends. No `&...`, no "etc.", no "and so on" — list them all or halt the contract.
- **The Optimistic Form Field Match** — audit declares V1↔V2 form fields "identical" without enumerating them. Frontend-specific anti-pattern: a missing field, a wrong type, a missing validator passes audit. Contract's Inputs section lists every field on V1's page, V2 must render the union.
- **The Permission-gate Drop** — V1 hides an action via `v-if="hasPermission(...)"` / `{user.can(...) && ...}`; V2's port renders the action without the gate. Per-button audit enumerates every gate; missing gate is a security regression.
- **The Guessed Type** (added 2026-05-01; softened 2026-05-02 for production-stable V1) — the V2 DTO / interface / type is authored by reading V1 caller code (which destructures the response untyped) instead of from V1's authoritative source. When V1 silently returns one field name and V2 types another, the field mismatch produces empty consumer UIs / blank widgets / undefined-everywhere with no error thrown. Fix: derive V2 types from V1's serializer / view template / controller code (the actual contract source) OR from captured API samples. The validator's `check_api_response_sample` halts when `v1_status` is unset or `actively-developed`; warns (does not halt) when `v1_status: production-stable` AND V2 types cite the V1 source location they were derived from in the contract.
- **The Reinvented Wrapper** (added 2026-05-01) — porter authors custom markup / CSS / util / hook for a surface that already has a shared wrapper in the project's gold-standard inventory. Common shapes: a custom field group when a shared field-wrapper exists; a hand-rolled language toggle when a shared translation-input exists; a nested wrapper-inside-wrapper that the host already handles internally (causing double labels / double padding). Root cause: porter never inventoried the shared layer before writing. Fix: the `mapping/<feature>.md` artifact (required at every tier) names the project's shared equivalent for every V1 surface BEFORE code is written. The validator's `check_v2_mapping_doc` halts on missing/empty mapping; the stack-conditional fingerprints in `check_v2_structure` flag the most common reinventions.
- **The Silent Catch** (added 2026-05-01) — port code wraps API calls in `catch { /* fail silent */ }` or empty `catch {}`. Empty UI / blank widgets / missing data become indistinguishable from "operation succeeded with empty result". Bugs hide for weeks because users report "looks empty" not "is erroring". Fix: every catch in port code calls the project's error handler (named in `_extracted-idioms.md`) OR includes a comment + debug log explaining recovery. The validator's `check_v2_structure` flags both swallow patterns.
- **The Wrong Lifecycle Hook on Nested Child** (added 2026-05-01) — port copies a page-level / route-level lifecycle pattern onto a nested child component with different mount semantics. The chosen hook never fires (e.g., a hook that only fires when the framework's route-cache reactivates, chosen for a component that the route-cache never reaches); the child never fetches; the page renders "no data" forever. Fix: nested children that fetch data use the project's standard mount-AND-reactivate hook pair (named in `_extracted-idioms.md`), not just one. The validator's `check_v2_structure` flags the framework-specific shape via `PROJECT_KIND`; per-stack pack rules (e.g., `frontend/rules/migration-frontend.md`) name the concrete hook pairs.
- **The Misplaced i18n / Locale Key** (added 2026-05-01) — code references a translation / locale key path that doesn't resolve in the project's actual locale tree (key was added at the wrong namespace level, or reference predates a key move, or namespace casing differs). The literal key string renders to users instead of the translated text. Fix: i18n key paths must resolve against the actual locale file structure. A future validator addition will grep referenced keys against the resolved locale tree.
- **The Consumer Compensation** (added 2026-05-01) — provider returns wrong field name / missing field / different shape; the consumer "fixes" it locally by mapping fields in the component / job / handler instead of filing a provider ticket. The drift accumulates silently across consumers. Fix: when audit detects provider-shape divergence, mark the row `status: halted` with explicit dependency on the provider fix ticket; do NOT ship a consumer-side workaround.
- **The Auto-import Trip** (added 2026-08-21) — a parity test mounts a leaf component / view template from a project whose *production* build resolves helpers through an auto-import plugin (build-tool plugin, framework auto-import, IDE import-on-resolve), while the *test* config does not load that plugin. Auto-imported helpers (i18n hook, router hook, reactive primitives) resolve in production and not in tests, so the first mount fails with `<helper-name> is not defined`-type errors and the parity suite is red for a reason that has nothing to do with parity. It slips audit because audits read source and never run the tests. Fix: the test config mirrors the production plugin chain — `parity-test-generate` writes the test config alongside the test files rather than after the first red run. Detector: grep the production build config and the test config for the same auto-import plugin and flag a mismatch.


## Structure-vs-behaviour worked examples

    **Worked examples:**
    - V1 has a `?include_archived=true` query param V2 omits → BEHAVIOUR (input axis) → **add it to V2**.
    - V1 returns `null` for missing user; V2 throws → BEHAVIOUR (output axis) → **V2 returns null**.
    - V1 puts logic in a fat controller; V2 has service+repo layers → STRUCTURE → **port logic into V2's service+repo, do not copy the fat controller**.
    - V1 ships a custom date-picker; V2 has a shared `<DateField>` wrapper → STRUCTURE → **use V2's `<DateField>`** (the date semantics it accepts/returns must still match V1 — that's behaviour).
    - V1 has a delete button gated by `permissions.delete`; V2 renders it ungated → BEHAVIOUR (permission gate) → **add the gate to V2**.
    - V1 has tab "Colors" reachable at `/settings/branding/colors`; V2 buries it inside `/settings/branding` as a scroll section → BEHAVIOUR (navigation path) → **expose it as a tab in V2** (it can use V2's tab primitive — that's structure — but the user-clickable leaf must exist).

    **Failure modes this rule names:**
    - **The Transposition Trap**: porter copies V1's *structure* to "preserve behaviour" — wrong; structure is V2's.
    - **The Silent Break**: porter changes V2's *behaviour* to "match V2's structure" — wrong; behaviour is V1's.
    - **The "I made it cleaner"** (variant of Transposition): porter normalises V1's "weird" inputs/outputs to V2's "cleaner" shape — that's a contract break, requires ADR + user_decision_quote.

## Per-tool dispatch + pattern pointers (relocated References detail)

### For tools with command + agent + skill dispatch (Claude Code, OpenCode, partial: Cursor, Copilot)

- `.claude/skills/extract-v1-contract/SKILL.md` — V1-contract-extraction procedure (inlined above).
- `.claude/skills/parity-test-generate/SKILL.md` — parity-test-generation procedure (inlined above).
- `.claude/skills/perf-uplift-survey/SKILL.md` — perf-uplift-survey procedure (inlined above).
- `.claude/agents/migration-architect.md` — strategic per-feature planner.
- `.claude/agents/parity-auditor.md` — pre-cutover audit (Stage A halts inlined as the 10-halt checklist above).
- `.claude/commands/find-and-fix.md` — DEFAULT per-feature loop (detect → decide → fix → verify → record).
- `.claude/commands/port-feature.md` — heavy-tier orchestrator (`--heavy` flag for full ceremony).
- `.claude/commands/migration-phase.md` — phase orchestrator (chains via find-and-fix per row by default).
- `.claude/commands/migration-gate.md` — phase exit verifier (validates the artifact set above).

### Patterns (read by all tools as ai/ knowledge)

- `ai/patterns/feature-port.md` — per-feature lifecycle (six phases per ledger row).
- `ai/patterns/parity-testing.md` — test technique catalogue + tolerance taxonomy.
- `ai/patterns/migration-ledger.md` — state-machine + record format.

### Cross-pack references

- `code-quality/agents/legacy-modernizer.md` — strategic-level migration (sets the feature inventory this rule operates inside).
- `backend/rules/concurrency-discipline.md` — the parallel-I/O bullet (perf-uplift candidate #5) links here.
- `database/skills/migration-rehearsal/SKILL.md` — DB-only migration rehearsal (used during V2 query plan + index changes).
- `frontend/` pack (if loaded) — component / page / a11y testing recipes the parity-test step uses for frontend ports.
- `testing/` pack (if loaded) — golden-master, property-based, record-replay recipes — the parity-test step uses these.

### Validator script (universal, runs from any tool)

- `scripts/validate-migration-artifacts.sh` — validates contract sections, citation resolution, corpus size, tolerance coverage, plan presence, perf-decisions completeness, runbook presence. Runnable from CI / pre-commit / any tool's hook system. Tool-agnostic.

### For rule-only tools (Aider, Codex, Gemini, partial: Cline, Windsurf)

This rule **is** the surface. The 9 contract sections, the 13 hard halts (including the dead-V1-code, UI-state-enumeration and navigation-inventory halts), the 6-axis dead-code check, the frontend axes, the anti-pattern catalogue, and the three procedures (extract / parity-test / perf-uplift) are all inlined above. No skill / agent / command dispatch is required — follow the rule as a checklist.
