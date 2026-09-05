---
description: "Design alerts for a service. Uses RED + USE + SLO-based alerts. Avoids the two anti-patterns: alert fatigue + missed pages. Outputs alert definitions + runbook entries."
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /alert-design

## The Premise (read this first, internalize, do not deviate)

**Existing alerts are the truth.** If this repo already ships alerts (in whatever alerting backend the project uses — Prometheus Alertmanager rules, Datadog monitors, Grafana alerts, vendor monitor JSON, etc.), those thresholds, severity tiers, burn-rate windows, and runbook conventions ARE the convention. New alerts MUST match sibling alerts: same severity labels (`page` / `ticket` / `info`), same threshold magnitudes for comparable signals (error-rate, latency, saturation), same multi-window burn-rate windows (1h fast / 6h slow), same annotation keys (`summary`, `runbook`). Match thresholds and severity tiers to sibling alerts unless data justifies divergence.

**The agent's job is exactly this:**
1. Audit existing alerts first (Phase 1 already requires this — enforce it). Read sibling thresholds, severity labels, windows, annotation shapes.
2. Mirror those shapes for the new alerts. Same severity vocabulary. Same window pairs. Same annotation keys.
3. Only deviate when historical data (past incidents, error budget burn rates) justifies a different threshold — and document the rationale inline.

**The agent does NOT:**
- Pick a threshold from a blog post (`> 1% over 5min`) when sibling alerts on the same signal use a multi-window burn-rate.
- Introduce a new severity tier (`critical`, `warn`, `urgent`) when sibling alerts use `page / ticket / info`.
- Pick burn-rate windows (2h / 12h) different from sibling SLO alerts (1h / 6h) without a data-driven reason.
- Draft an ADR mid-run to legitimize a new convention. **Sibling wins. Match it.**

**Closure verb (default): match-sibling-thresholds.** Auto-apply parity edits silently; batch into the end-of-run summary. Only halt on the three escalation triggers below.

**Escalation triggers (halt and ask):**
- No sibling alerts exist (greenfield alerting — user picks the convention).
- The new signal genuinely has no comparable sibling (novel domain — user picks threshold).
- Historical data (past incidents) shows sibling threshold would have missed a real outage — surface evidence and propose divergence.

That's it. Everything else is silent sibling-parity emission.

## Mechanical halt — hand-wave grep on rationale

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds alert-specific tokens + sibling parity checks.

Before finishing Phase 4, every alert MUST have an inline rationale tied to either (a) a sibling threshold or (b) historical data. Run these checks. Any failure = HALT, surface, do not advance:

1. **Hand-wave grep** — scan generated alert annotations + rationale notes for hand-wave phrases: `"reasonable"`, `"sensible default"`, `"industry standard"`, `"common practice"`, `"typical value"`, `"seems right"`, `"should be enough"`. Any match = HALT. Replace with either a sibling-threshold citation (`matches alert <name>`) or a data citation (`based on P95 over last 30d = X ms`).
2. **Severity tier parity** — every alert uses a severity label that already exists in sibling alerts. New tier = HALT.
3. **Window parity** — multi-window burn-rate alerts use the same window pairs as sibling SLO alerts unless data-justified, and every confirmation window is 1/12 of its long window.
4. **Runbook link present** — every `severity: page` alert MUST have a `runbook:` annotation pointing at an existing or newly-stubbed file. Missing = HALT.

Add the check results to the output block under `Rationale-grep: ✓ | hand-wave halts=<N> | severity-parity ✓ | window-parity ✓`.

Design alerts that fire when something is actually wrong + DON'T fire when nothing is. The two failure modes are equally bad: too many alerts → fatigue → ignored pages → real outages missed; too few → outages happen with no early warning.

## Phases applied

All 7.

## Phase 1 — Understand

Confirm:
- Service / endpoint / job in scope.
- **SLOs / SLAs — and if there are none, this is where they get defined, not where the run stops.** Every alert this command emits burns against an SLO, so an empty `ai/runtime/slos.md` blocks everything downstream. **Dispatch the `slo-audit` skill** — its "when to run" explicitly covers *defining a service's first SLOs*, and it is the only artifact in the pack that populates the registry that `alert-design`, `add-telemetry`, `synthetic-monitoring` and `slo.md` all read. Come back from it with an SLI, a target, a window and an owner per critical path, written to the registry. "We don't have any" is an input to this phase, never an exit from it.
- On-call structure (who pages, what hours, escalation policy, rotation size) — Phase 6's page budget is computed from it.
- Existing alerts (audit them — many will be deletable).
- Backend: the project's alerting + paging stack (e.g., Prometheus Alertmanager / Datadog Monitors / Grafana Alerts / vendor monitor JSON, paging via PagerDuty / Opsgenie / Grafana OnCall / equivalent).

## Phase 2 — Organize

Four alert classes:

1. **Symptom-based (SLO burn)** — alerts on user-facing symptom: error budget burning fast, medium, or slowly.
2. **Cause-based (saturation / errors)** — alerts on resource exhaustion, error spike, queue backup.
3. **Heartbeat / liveness** — service stops emitting metrics → alert.
4. **Blackbox / synthetic** — a scripted probe drives the real user journey from outside and pages on its own route. This is the class that catches "every white-box signal green, nobody can log in", and it is the one most often missing entirely. If the service owns a critical user journey, **dispatch the `synthetic-monitoring` skill** to find the journeys with no probe, no probe-SLO, or a single location — its findings are alerting gaps and belong in this command's output.

The healthiest alert posture is **SLO-burn-rate alerts** (the three tiers below) plus a blackbox page per critical journey plus a small set of cause-based for things SLO can't catch (security events, data integrity, dependency failures).

## Phase 3 — Retrieve

- Existing SLO definitions in `ai/runtime/slos.md` if any.
- Metrics catalog in `ai/runtime/metrics-catalog.md`.
- On-call runbook structure if any.
- Past incidents — what fired, what didn't, what should have.

## Phase 4 — Generate

### SLO burn-rate alerts (Google SRE multi-window pattern — three tiers)

For an SLO of "99.9% of HTTP requests succeed in 30 days" the error budget is 0.1% of requests, and
the canonical alert set is **three** tiers, not two (SRE Workbook Table 5-8; derivation in
`ai/patterns/slo.md`):

| Tier | Budget spent if sustained | Long window | Confirmation window | Multiplier | Severity |
|---|---|---|---|---|---|
| Fast burn | 2% | 1h | 5m | **14.4×** | **page** |
| Medium burn | 5% | 6h | 30m | **6×** | **page** |
| Slow burn | 10% | 3d | 6h | **1×** | **ticket** |

Express each in the project's alerting backend syntax. All three compute `error_rate = errors /
total` over the long window AND the confirmation window and compare both to `(1 − SLO) ×
multiplier`; annotations carry `summary` and `runbook` pointing at `ai/runbooks/<feature>-*.md`.

Two of these get mis-emitted routinely, and both changes are behavioural:

- **The 6h / 6× tier pages.** It is Google's second *page* tier — 5% of the month's budget in six
  hours is an outage in progress. Emitting it as a ticket means a Saturday regression waits for
  Monday.
- **The tier that tickets is 3d / 1×, and it is the one usually missing.** A leak burning at exactly
  the target rate trips neither page tier *by construction*, so a two-tier alert set has no detector
  at all for "we will miss the SLO at month-end". Emit it even though it fires rarely — rarely is the
  point.

Write **14.4**, not 14: the rounded value is a different threshold and it propagates into generated
rules. Confirmation window = 1/12 of the long window, which is how you derive a pair this table
doesn't list.

Match label keys (`severity`, `slo`) and annotation keys (`summary`, `runbook`) to sibling alerts.

### Cause-based alerts (limited set)

Alert when:
- DB connection pool > 90% utilized for 5 min.
- Queue depth > N (where N is the consumer's max throughput × 5 min).
- Memory > 90% on app servers.
- Disk > 80% on data nodes.
- Cert expiring in < 14 days.
- Vendor / dependency reports outage.

Don't alert when:
- CPU is high (often misleading; doesn't correlate with user impact).
- One container instance restarted (let the orchestrator handle it; alert only if ALL replicas restart).
- Single error response (statistical noise; SLO-burn handles aggregates).
- Slow query (let APM handle; alert if P95 SLO burns).

### Heartbeat / liveness

Configure the project's alerting backend to fire `severity: page` when the service stops emitting its primary request counter for 5 minutes (e.g., Prometheus `absent(...)`, Datadog `no data`, etc.). Annotation: "service emitting no metrics for 5 min — likely down".

### Alert hygiene

For every alert:
- **Severity** — page / ticket / info. Page = wake someone. Ticket = handle business hours. Info = context only.
- **Runbook URL** — every PAGE alert has a runbook. Without a runbook, the alert is "panic"; with one, it's "execute steps."
- **Threshold rationale** — why 90% not 80%? Document.
- **Auto-resolution rule** — when does it stop firing?
- **Escalation policy** — who if primary doesn't ack in N min?

## Phase 5 — Update

- `ai/runtime/slos.md` — SLO definitions (written here, read by everything else in the pack).
- `ai/runtime/alerts.md` — alert catalog with severity / runbook / rationale per alert.
- `ai/runbooks/<alert-name>.md` — per-alert runbook. **Dispatch `@incident-responder` to write the body.** It owns live-incident procedure — the mitigation ladder for this failure class, the first three diagnostic queries, the escalation path — which is what turns a file into something executable at 3am. A runbook whose body says "investigate" is an ORPHAN in the ledger below, exactly as if the file were missing.
- Backend config (the project's alerting backend rules — Prometheus rules / Datadog Monitors / Grafana Alerts / vendor monitor JSON) — checked in to repo.

## Phase 6 — Validate

Agent-verified:
- **Dispatch the `alert-audit` skill** on the generated alerts for the historical-replay check: it queries the alerting backend + paging history to answer "would this threshold have fired during past incidents?" and flags dead-on-arrival rules (query references an uninstrumented metric), missing runbooks/owners, and cause-vs-symptom misclassification. Findings halt before completion. This is the executor for the "would this have fired" gate — the agent does NOT eyeball it.
- Verify alert volume against a **derived** page budget, not a quoted one. Google's figure is a maximum of **2 incidents per 12-hour on-call shift**, and the derivation is what makes it portable: one incident costs roughly **6 hours** of real work (triage, mitigation, root-cause, postmortem, follow-up fix), so two fills a shift. Compute yours:

  ```
  pages per shift ≤ shift length (hours) / hours of real follow-up per page
  ```

  Measure the second term from this team's own postmortems. Record the computed budget and its two
  inputs in the output block — a run halts on this number, and a number nobody can re-derive when the
  rotation size or the incident cost changes is a number that gets ignored the first time it is
  inconvenient. (For a 12h shift at 6h/incident that is 2 per shift; over a weekly rotation of 14
  shifts, ~5/week — which is where the folk figure comes from, and it stops being right the moment
  either input changes.)

### Actionability ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

An alert is production-grade only when it is SLO-linked, would have caught a real incident (not fire on noise), and hands the responder a runbook. Assert each — do NOT declare a count and stop. One row per generated alert:

```
Alert (name)              | Sev    | SLO/SLI it burns   | Window   | Dead-on-arrival? (alert-audit) | Runbook (file + first action) | Status
checkout-fast-burn        | page   | checkout.success   | 1h/14.4× | no (query hits live series)     | ai/runbooks/… → yes, "flip flag" | ACTIONABLE
checkout-med-burn         | page   | checkout.success   | 6h/6×    | no                              | ai/runbooks/… → yes, "flip flag" | ACTIONABLE
checkout-slow-burn        | ticket | checkout.success   | 3d/1×    | no                              | ai/runbooks/… → yes, "open PM"   | ACTIONABLE
checkout-journey-probe    | page   | probe.checkout     | blackbox | no                              | ai/runbooks/… → yes, "check CDN" | ACTIONABLE
db-pool-saturation        | ticket | (cause, dashboard) | for 5m   | no                              | ai/runbooks/… → yes, "scale pool"| ACTIONABLE
```

Per-row `Status`:
- **ACTIONABLE** — SLO/SLI named (or explicitly a cause-based ticket, not a page), `alert-audit` says not-dead, and `test -f` on the runbook path succeeds AND its body names a concrete first action. Only ACTIONABLE counts.
- **UNLINKED** — the alert fires on a static threshold with no SLO/SLI behind it, or a `page` alert is cause-based. Fix (convert to burn-rate) or demote — not shippable as a page.
- **ORPHAN** — no runbook file on disk, a runbook whose body says "investigate", or `alert-audit` flagged it dead-on-arrival / no owner. Halt.
- **NO-DATA(reason)** — `alert-audit` could not reach the alerting backend or paging history from this environment, so dead-on-arrival is unverified for this row. Name what was unreachable. UNVERIFIED is not a pass: any NO-DATA row makes the run INCOMPLETE, exactly like an UNLINKED one. Do not launder it into ACTIONABLE because the other three columns were checkable.

Coverage rows (not per-alert, but part of the gate):
- Every SLO in `slos.md` has all **three** burn tiers, and the 6h/6× tier is labelled `page`.
- Every critical user journey has a blackbox page route that does not depend on a white-box condition (`synthetic-monitoring`'s findings). A missing journey probe is an alerting gap, not a nice-to-have.

OPERATOR CHECKLIST (live — NOT auto-passed):
- [ ] Trigger each alert deliberately (toy app, staging) → it fires AND pages the right person.
- [ ] Wait for it to clear → it auto-resolves.

## Phase 7 — Improve

- After each incident: post-mortem reviews alerts fired (false positives? missed?).
- Quarterly: audit alert silence-rate + ack-rate. Alerts silenced > 50% are noise; delete.
- Recurring page-and-ack-no-action → alert is informational, not actionable.

## Output format

```
## /alert-design — <service>

Service: <name>
SLO definitions: <count> (slo-audit dispatched: yes/no — <what it wrote to slos.md>)
Page budget: <N>/shift = <shift hours>h ÷ <hours of follow-up per page>h  (source: <postmortem sample>)
Page alerts: <count> (projected <N>/week vs budget <N>/week)
Ticket alerts: <count>
Heartbeat alerts: <count>
Blackbox/journey alerts: <count> (uncovered journeys per synthetic-monitoring: <list>)
Runbooks: <count>

Actionability ledger: <rows> alerts — ACTIONABLE <a> | UNLINKED <u> | ORPHAN <o> | NO-DATA <n>
  <the ledger table above, verbatim, with per-alert evidence>

Alert catalog: ai/runtime/alerts.md
Backend config: <path to monitors.yaml / etc.>
Alert volume estimate (based on past 30d data): <P/T/I per week>

Status: <see gate below>
```

### Closure gate — COMPLETE only when every alert is actionable, else INCOMPLETE with the unmet alerts named

Compute Status from the ledger + the `alert-audit` result — do NOT hand-write it:

- **`Status: COMPLETE`** — ONLY when every ledger row is `ACTIONABLE`, `alert-audit` returned zero dead/noisy-above-budget/runbook-less/owner-less/cause-as-page findings **and no NO-DATA rows**, every SLO carries all three burn tiers with the 6h tier as a page, every critical journey has an independent blackbox page route, and the projected page volume is within the **derived** budget. Nothing else.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is `UNLINKED`, `ORPHAN` or `NO-DATA`, `alert-audit` has an open finding, a coverage row fails, or the volume projection breaches budget. NAME each unmet item and why (e.g., `search-latency — UNLINKED: static p95>500ms, no SLO; convert to burn-rate`; `import-job-failed — ORPHAN: no runbook file`; `checkout.success — coverage: no 3d/1× ticket tier, a target-rate leak is undetectable`; `db-pool-saturation — NO-DATA: alerting backend unreachable, dead-on-arrival unverified`). A set of alerts that "would fire" but page into a void is INCOMPLETE, and so is a set nobody could verify.

This gate is **[self-policed]** on the Status line, but wired to checkable evidence: the runbook paths (`test -f`), the SLO names (must resolve in `ai/runtime/slos.md`), and the `alert-audit` findings are all inspectable — `@sre-engineer` / `@observability-reviewer` will BLOCK a COMPLETE whose alerts are unlinked or runbook-less.

## Hard rules

- **Every PAGE has a runbook with a first action.** Without it, page = panic.
- **SLO-based alerts beat threshold-based.** Threshold (e.g., "P95 > 500ms") is symptom-removed; SLO burn rate is user impact.
- **Page rate within the derived budget** (`shift hours ÷ hours of follow-up per page`). More = fatigue → real pages ignored. Show the arithmetic; a quoted number nobody can re-derive gets waived.
- **Auto-resolution defined.** Alerts that "fire and stay fired" rot.
- **No PII / secrets in alert annotations.**

## Failure modes

- Alert fires on every deploy → on-call learns to ignore → real outage missed.
- Threshold set in dev / staging values → never fires in production.
- Runbook missing or outdated.
- Page wakes person; runbook says "investigate" with no first action.
- Alert depends on a metric that wasn't actually instrumented → silently never fires.
- Escalation policy points at someone who left.

## Related

- `add-telemetry` (and its narrow entry points `add-metrics` / `add-tracing`) — emit the series these alerts burn against.
- `slo-audit` skill — **dispatched in Phase 1** to define or re-verify the SLOs every alert here burns against; it is the only artifact that writes `ai/runtime/slos.md`, which this command, `add-telemetry`, `synthetic-monitoring` and `slo.md` all read.
- `alert-audit` skill — dispatched in Phase 6 for the historical-replay "would this have fired" check + dead/noisy/orphaned vetting.
- `synthetic-monitoring` skill — **dispatched in Phase 2** when the service owns a critical user journey; its uncovered-journey findings are alerting gaps this command must close.
- `@incident-responder` agent — **dispatched in Phase 5** to author the runbook bodies, and the agent that executes them during a live page.
- `@sre-engineer` agent — broader SRE concerns; alert-design is one dimension.
- `.claude/rules/observability-principles.md`.
