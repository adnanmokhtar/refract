# Migration discipline — examples & anti-pattern catalogue

> **Pack-side only — this file is NOT installed into projects.** `templates/phases/phase-4.2-apply.md:210-213` copies `references/<name>.md` only when `<name>` equals a **detected framework name**, so no project has ever received `migration-discipline-catalogue.md`, and no tool adapter ships it (`phase-4.8-deep.md:35`). It is here for pack authors and for any adapter bundle that chooses to carry it.
> **Nothing enforceable lives here.** Every tier floor, halt definition, merge gate, threshold, review checklist and anti-pattern → check mapping is in **`ai-patterns/migration-guardrails.md`**, which installs unconditionally (`phase-4.2-apply.md:207`). What remains here is worked examples, rationale and long-form guidance that no halt depends on.
> `migration-discipline-procedures.md` was merged into this file on 2026-08-23 — after the enforceable depth moved out, the 3.4KB remainder (§ Tier rationale, § Should — full guidance) did not justify a second never-installed file.

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


## Named anti-patterns — moved

The 20-name catalogue, each with its fingerprint, its real-world cost and the
`validate-migration-artifacts.sh` check that catches it, now lives in
**`ai-patterns/migration-guardrails.md` § Named anti-patterns** — the names are load-bearing
vocabulary that audits cite, so they have to reach the project. `references/` files install only
for a **detected framework name** (`templates/phases/phase-4.2-apply.md:210-213`);
`ai-patterns/` installs unconditionally.

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

## Tier rationale

> **Why this is tiered (added 2026-04-30 from a Phase 7 incident lesson)**: prior single-floor discipline produced ~95% docs / ~5% code on small features (all 8 artifacts mandatory regardless of feature size). 1-line fixes generated 5-section contracts + 30-fixture parity tests + 12-candidate perf surveys + 7-stage runbooks. The tiered model preserves the F039 anti-Trusted-Summary protections on heavy features while letting trivial features ship in proportion.


## Should — full guidance

- **Slice vertically (full feature) over horizontally (just data layer).** Vertical slices ship value + can be cut over independently. Horizontal slices (port all controllers, then all services, then all repos) leave V2 unusable until the last layer ports.
- **Pick the lowest-risk feature for the first port.** Health checks, read-only endpoints, internal admin tools — they exercise the toolchain without exposing customers to a parity bug. The first port shakes out the parity-test infrastructure, the ledger workflow, the cutover path.
- **Run V1 + V2 in shadow before canary.** Shadow = V2 receives the same input but its output is compared (not served). Catches behavioural drift the parity test suite missed. Run for ≥1 week per high-traffic feature.
- **Anchor perf-uplift candidates to a measurement.** Don't add Redis caching in V2 because "caching is fast." Capture V1's call rate + payload size + cache-hit projection + estimated DB load reduction. The decision file must show the math.
- **Index proactively when V2's query shape differs from V1.** Different `WHERE` clause = different optimal index. Use `EXPLAIN ANALYZE` on V2's query plans against prod-sized data before cutover — see `database/skills/migration-rehearsal/SKILL.md`.
- **Project columns minimally.** V1's `SELECT *` becomes V2's `SELECT id, name, status` if those are all the consumer needs. Less network bandwidth, less ORM hydration, less GC pressure. The contract should list the *consumed* columns, not the *queried* ones.
- **Replace sequential await loops with bounded parallelism.** During port, sequential `for await` patterns in V1 are the highest-leverage perf upgrade — see `backend/rules/concurrency-discipline.md` + `backend/skills/parallelize-independent-ops/SKILL.md`. Always preserves parity (assuming independence).
- **Cap the contract in writing.** A 500-line contract is fine. A 50-page contract means the feature is too big — split it before porting.
- **Run parity tests against a frozen V1 commit.** Pinning the parity oracle prevents "V1 evolved while we ported V2" — the ledger row records the V1 commit hash used.
