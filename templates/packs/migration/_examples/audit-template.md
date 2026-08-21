---
name: audit-template
description: Concrete template for ai/migration/audits/<feature-id>.md. Copy-paste; fill every section; never hand-wave with `&...` / `etc.` / `…`. Required by /migration-phase + /migration-gate.
kind: example
pack: migration
---

> **STACK ASSUMPTION**: this example uses Vue 3 + PrimeVue + TypeScript syntax for illustration. The rule / pattern / anti-pattern itself is universal; substitute your project's primitives from `_extracted-idioms.md`. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack pack's fingerprint set automatically.


# Audit template — `ai/migration/audits/<feature-id>.md`

> Copy this template verbatim when authoring an audit. Every section is required. Hand-wave tokens (`&...`, `etc.`, `, ...`) are blocked by the validator script.
>
> The 13 hard halts in `migration-discipline.md` § "Per-feature audit — 13 hard halts" are the gate; this file's structure mirrors them. A blank section = halt; a hand-waved enumeration = halt.

```markdown
---
auditor_agent_id: <Agent run ID — REQUIRED. Validator HALTs without it.>
auditor_mode: agent
audit_date: <UTC ISO8601>
v1_commit_pinned: <full SHA, matches ledger row>
v2_commit: <SHA of port branch HEAD>
porter_agent_id: <if known — must differ from auditor_agent_id (A5 second-eyes)>
---

# Audit — <feature-id> — <feature-name>

> Phase: <N> | Audited: <iso-datetime> | Auditor: parity-auditor agent (run ID: <ID>)
> V1 commit pinned: `<sha>` (matches ledger row)
> V2 commit: `<sha>` (HEAD of port branch)
> Mode: audit-only | full | re-audit

## Classification

**parity-clean | divergent (additive) | divergent (parity-preserving) | divergent (intentional-break ADR-NNN) | missing-in-v2**

One paragraph rationale. State what V2 actually does and how it relates to V1's contract. Cite `<path:line>` for any non-obvious claim.

## Per-axis comparison

(Apply the 6 generic axes + frontend axes if applicable. Every cell is enumerated, not summarised. NO `&...`, `etc.`, `, …`.)

### Generic axes

| Axis | V1 | V2 |
|---|---|---|
| Inputs (request body / form / query / headers / file uploads) | <enumerate every input — name, type, validators> | <enumerate identical / divergent — same shape> |
| Outputs (response body / status / emitted event / written file) | <field-by-field; cite `path:line` for shape definition> | <field-by-field> |
| Error contract (status codes, error types, retry semantics) | <enumerate every error path> | <enumerate every error path> |
| Auth + permissions | <route-level + per-action gates> | <route-level + per-action gates> |
| Side effects (DB writes / queue publishes / external HTTP / cache / log fields / metrics) | <enumerate every side effect> | <enumerate every side effect> |
| Performance envelope (p50/p95/p99) | <V1 baseline from telemetry> | <V2 measured or projected> |

### Frontend axes (mandatory when feature is a page / component / route)

| Axis | V1 | V2 |
|---|---|---|
| Form fields (per input element) | name, type, validators, default, placeholder, required, hidden-when, disabled-when — for EVERY field | identical enumeration; flag any drift |
| UI affordances (per button / link / dropdown / modal trigger / file-upload / toggle / copy-button) | label, event handler, permission gate, disabled-when, target route — for EVERY affordance | identical enumeration; flag any missing |
| Templated query params (for list endpoints) | every `?foo=&bar=&baz=&...` param V1's list call sends | every param V2 sends — flag missing or extra |
| Event handlers | every `@click` / `@submit` / `@change` — what it calls, with what args | identical enumeration |
| Per-button permission gates | `v-if="hasPermission(...)"` per button — enumerate every gate | identical or note divergence |
| Accessibility | axe-core baseline result | axe-core current result |
| DOM-equivalent | tolerance class for structural markup | semantic equivalence verified |
| Reactive lifecycle | `onMounted` / `onActivated` / `componentDidMount` / `useEffect([])` choice | same lifecycle hook + matching cache-aware refresh |

## Hard-halt findings

Enumerate which of the 13 hard halts (per `migration-discipline.md` § "Per-feature audit — 13 hard halts") fired (or "none"). Each halt: which check, evidence, specific remediation.

| # | Halt | Status | Evidence | Remediation |
|---|---|---|---|---|
| 1 | Contract complete | PASS / FAIL | <path to contract; section count> | <if FAIL: which sections to add> |
| 2 | Parity tests not thin | PASS / FAIL | <input count; tolerance.yaml present> | <if FAIL: add inputs / record-replay setup> |
| 3 | Parity tests green | PASS / FAIL | <CI run ID + commit> | <if FAIL: list red tests> |
| 4 | Plan exists + matches | PASS / FAIL | <path to plan> | <if FAIL: re-author plan> |
| 5 | Perf-decisions complete | PASS / FAIL | <classification counts; measurements present> | <if FAIL: classify or measure> |
| 6 | No V1 modifications | PASS / FAIL | `git diff --stat <v1-root>/` should be empty | <if FAIL: revert V1 changes> |
| 7 | Ledger drift | PASS / FAIL | <required fields per state per migration-ledger.md> | <if FAIL: populate fields> |
| 8 | Rollback runbook | PASS / FAIL | <path to runbook> | <if FAIL: author runbook> |
| 9 | Scope = one feature row | PASS / FAIL | <PR title + diff scope> | <if FAIL: split PR> |
| 10 | Cutover tested in staging | PASS / FAIL / N/A | <staging deploy log> | <if FAIL: rehearse rollback> |
| 11 | No dead V1 code in port queue | PASS / FAIL | <6-axis reachability result per axis: app-source / tests / cron / routes / infra / telemetry> | <if FAIL: mark ledger row `status: deprecated`, `deprecation_reason: dead-v1-no-callers`; do NOT port> |
| 12 | UI rows enumerate v1_states / v2_states | PASS / FAIL / N/A | <per UI row: `v1_states: [...]` / `v2_states: [...]` / `gap:`> | <if FAIL: enumerate every interaction state; one-line rows halt> |
| 13 | Navigation inventory present (Section 0) | PASS / FAIL / N/A | <Layer A route tree + Layer B per-leaf template grep> | <if FAIL: build the two-layer inventory before per-axis work; Layer-A-only is incomplete> |

> **Tier gating** (per `parity-auditor.md` § tier-gated halts): halts 1, 2, 4, 5, 8 are artifact-existence checks gated by the row's `tier:`. Halts 3, 6, 7, 9, 10, 11, 12, 13 apply across **all** tiers — they are structural facts, not artifact ceremony. Trivial = 3, 6, 7, 9, 10, 11, 12, 13. Standard = that set + 1 + 2 + 4. Heavy = all 13.

## Tenant-isolation gate (if multi-tenant project)

PASS / FAIL.

For each `migration-discipline.md` § Multi-tenancy invariant:
- No new `localStorage.*` outside `secureStorage`/`tokenProvider`: <PASS/FAIL + evidence>
- No manual `Authorization` headers: <PASS/FAIL + evidence>
- No `tenant_id` in client-built bodies: <PASS/FAIL + evidence>
- Every cache registers a logout-clear hook: <PASS/FAIL + evidence>

If any FAIL → silent break; halt cutover.

## V1 oracle

- `<v1-path>` — entry point.
- `<v1-supporting-files>` — call graph.
- `<v1-service-or-store>` — data layer.
- Cite specific lines for the load-bearing claims.

## V2 destination

- `<v2-path>` — page / component / module.
- `<v2-composables-or-services>` — V2's primitives.
- Cite specific lines.

## Gaps

For each gap (or "none"):
1. **<gap name>** — <specific divergence>. <V1 evidence: path:line>. <V2 evidence: path:line>. <Severity: high / medium / low>. <Action: port + reconcile / ADR + accept / parking-lot>.

## Decision recommended

1. <Specific next action: pin V1 commit; build parity test; fix V2 to address gap; etc.>
2. <Validation: parity test corpus expectations; tolerance.yaml entries to add>
3. <Coordination items: API team confirmation, ADR authoring, etc.>

## ADR references

- <ADR-NNN: title> — <how it relates to this feature>
- (or "None")

## Notes

<Anything material to future readers — context the per-axis tables don't capture, dependencies on other features, lessons learned during the audit.>
```

## Anti-templates (do NOT do these)

These shapes pass file-presence checks but FAIL content-quality checks. The validator script flags them.

❌ **Hand-waved axis enumeration:**
```markdown
| Endpoint (list) | `GET /endpoint?foo=&bar=&...` | identical |
```
The `&...` and `identical` together mean nothing was actually compared. Validator flags `&...`.

❌ **Trusted-summary classification without per-axis enumeration:**
```markdown
## Classification
parity-clean — V2 form is identical to V1.
```
Without the per-axis table, "identical" is the trusted summary anti-pattern. Validator flags audit files lacking the per-axis section.

❌ **Skipped frontend axes for a frontend feature:**
```markdown
## Per-axis comparison
| Axis | V1 | V2 |
|---|---|---|
| Inputs | ... | ... |
| Outputs | ... | ... |
```
A frontend feature without enumerated form fields, UI affordances, query params, etc. fails the frontend-axes check. Validator flags audit files for frontend features missing the Frontend axes section.

❌ **Hard-halt findings = "all PASS" without evidence:**
```markdown
## Hard-halt findings
All 10 halts PASS.
```
Each halt requires evidence. Validator demands per-halt rows in the table.

## How the validator enforces this template

`scripts/validate-migration-artifacts.sh` greps audit files for:

- Required section headers (Classification / Per-axis comparison / Hard-halt findings / Tenant-isolation gate / Decision recommended)
- Hand-wave tokens (`&...`, `etc.`, `…`) — flags as warning, escalates to error under `--strict`
- For frontend features (detected via the contract's V1 path being a `.vue` / `.tsx` / `.jsx` file under `src/`), demands the Frontend axes section

If any check fails, the script lists the failure with file:line and exits non-zero.

## Cross-references

- `parity-auditor.md` — the agent that produces this audit (Stage A).
- `migration-discipline.md` § "Per-feature audit — 13 hard halts" — the checklist this template structures.
- `migration-discipline.md` § "Frontend audit axes" — when the Frontend axes section is mandatory.
- `audit-failure-modes.md` — the named anti-patterns this template's structure prevents.
