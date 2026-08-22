---
name: slo-audit
description: Audit SLOs against reality — whether they are being met, whether budgets are burning, and whether targets are too lax or too ambitious; reports per-SLO with a verdict and recommended action. Run quarterly, after a significant incident, before raising or lowering a target, and when defining a service's first SLOs. Judges the targets — `alert-audit` judges the alerts built on them.
---

# Skill: slo-audit

## Premise

Find real issues. Every verdict cites the achieved %, the budget remaining, and the window it was measured over. Numbers come from the observability backend's SLO endpoint or dashboard — not estimates. Each SLO is named from `ai/runtime/slos.md`; incidents are named with their ID; vendor or service called out by name. "Recommend raise to 99.5%" requires both 90d data backing it AND a named stakeholder for the buy-in.

**This skill runs where the code is, and the measurements are somewhere else.** An agent invoked in a repository usually cannot reach a production TSDB, a vendor SLO API, or a paging history. That is the normal case, not the exception — so it has a first-class output (`NO-DATA`), and the failure this skill exists to prevent is filling the table with plausible numbers instead of using it. Every other verdict is a claim about attainment; you may not make one you did not measure.

## Halt conditions

- **A verdict with an empty evidence cell is fabricated.** Every row carries the exact query / API call run AND what came back. No evidence → the row is `NO-DATA`, not a guess and not a blank.
- Refuse to verdict an SLO without 90d of measurements captured — record `NO-DATA(<what was unreachable>)` and continue to the next SLO. Do not skip the row silently; a missing row reads as "no SLO", which is a different and much worse finding.
- Refuse to call an SLO "TOO LAX" without showing achieved >> target consistently.
- Halt on hand-waves like "feels under-promised" — cite the trend or drop the recommendation.
- Don't propose tightening without naming the stakeholder who must sign off.
- An adjective where a number belongs ("attainment looks healthy") is not a verdict. Produce the percentage or produce `NO-DATA`.
- **Never write a registry target with an empty `origin`.** A number with neither a commitment nor
  a measurement behind it is `PROPOSED(<what would settle it>)`, not a target — writing it as one
  hands every downstream alert a threshold nobody agreed to.

## When to run

A periodic audit of SLOs (Service Level Objectives):
- Quarterly review of all SLOs.
- After a significant incident (did the SLO catch it? was it too lax?).
- Before raising / lowering an SLO target.
- When defining first SLOs for a service.

## Procedure

### 1. Inventory SLOs — or define them, when the registry is empty

Read `ai/runtime/slos.md`. Per SLO, capture:
- **Statement** — "99.9% of API requests return non-5xx within 30 days."
- **SLI** — Service Level Indicator (the thing measured).
- **Target** — the percentage / threshold.
- **Window** — rolling 30 days standard.
- **Owner** — team / person.
- **Origin** — vendor SLA? Customer-promised? Engineering aspiration?

**If the file is missing or holds no entries, this run creates it — that is not an error path, it is
the bootstrap.** Three artifacts route registry *creation* here (`/alert-design` Phase 1,
`synthetic-monitoring`'s probe-SLO finding, `add-telemetry`) and none of them will invent a target,
so a run that stops at "this project has no SLOs" strands all three permanently. Write the file,
then audit what you wrote.

A first target is the one number in this skill you cannot look up, and it has exactly two defensible
sources:

| Where the target comes from | When it applies | What you write |
|---|---|---|
| **An existing commitment** — a customer contract, a published SLA, a vendor SLA you resell | The number is already promised to someone outside the team | The promised figure verbatim, `origin:` naming the document. Not this skill's to negotiate |
| **Measured recent behaviour** — attainment over the last 90d on that SLI, rounded *down* to a level the service already clears | No commitment exists — the common case | The achieved figure minus headroom, `origin:` carrying the query. A target the service has never met is an outage report on a schedule, not an objective |

If neither resolves — no commitment, and no reachable history — still write the entry, with the SLI,
window and owner filled in and `target: PROPOSED(<what would settle it>)`, and give it a `NO-DATA`
row in step 3. An entry that names the SLI and its owner but not yet its number is useful: it tells
the next run exactly what to measure. **A round number chosen because it looks like an SLO is the
fabrication this step exists to prevent** — `99.9%` is a claim that the service may be down 43
minutes a month, and nobody in this run has agreed to that.

Every entry carries `sli`, `target`, `window`, `owner`, `origin`. Missing `owner` or `origin` and it
is not done: `owner` is who receives the burn-rate page `/alert-design` will build on this row, and
`origin` is what stops next quarter's audit from re-deriving the number from memory.

### 2. Pull last 90 days of measurement

Tools (use whichever the project's observability stack provides):
- Self-hosted: Prometheus / a TSDB + a dashboard tool → SLO dashboard; Sloth or similar SLO generator.
- Vendor-managed SLO products (Datadog SLO, New Relic SLO, Grafana Cloud SLO, Cloud-vendor service monitoring, Honeycomb SLO, etc.).

For each SLO, compute:
- Achieved % over last 30 days.
- Achieved % over last 90 days (trend).
- Error budget remaining.
- Burn rate trend (linear / accelerating / plateau).

### 3. Verdict per SLO

Pick exactly one, no synonyms. Six of the seven are claims about attainment and each requires the measurement in the row's evidence cell; the seventh is what you use when you could not measure.

| Verdict | Criteria | Recommendation |
|---|---|---|
| **GREEN** | Achieved > target consistently for 90d, error budget > 50% remaining | Hold OR consider tightening (raise target if business benefits) |
| **YELLOW** | Achieved ≈ target; burn rate occasionally spikes | Monitor; investigate burn-rate spikes for systemic issue |
| **RED** | Achieved < target OR error budget exhausted | Stop feature work; fix root causes |
| **TOO LAX** | Achieved >> target consistently for 90d, no incidents | Raise target |
| **TOO TIGHT** | Achieved << target despite engineering effort, target was aspirational | Lower target with stakeholder agreement OR invest in reliability |
| **STALE** | The SLO **is** measurable from here and the series has no fresh samples (> 7 days) — a property of the instrumentation | Fix instrumentation OR remove SLO |
| **NO-DATA(reason)** | *You* could not reach the measurement — backend unreachable from this environment, no credentials, no SLO endpoint, vendor API not queryable. A property of the audit, not of the SLO. | Name what was unreachable and the one command that would close it. Re-run where the backend is reachable. |

**`STALE` and `NO-DATA` are not interchangeable and the distinction is the whole point.** STALE says *the service stopped emitting* — that is a finding about the system, and someone must fix instrumentation. NO-DATA says *I could not look* — that is a finding about this run, and it obliges nobody to change any code. Reporting NO-DATA as STALE invents a production defect; reporting STALE as NO-DATA hides one.

**A NO-DATA row is UNVERIFIED, not a pass.** Any NO-DATA row downgrades the whole audit to `INCOMPLETE` (see the closure gate below) — it never rounds to GREEN, and an SLO you could not measure is never evidence that things are fine.

### 4. Cross-correlate with incidents

For each incident in last 90 days:
- Did an SLO catch it? Lead time?
- Did it consume error budget? How much?
- Was the SLO definition right (right SLI? right window?)?
- If multiple SLOs exist on the same service, did they all signal? Or was one redundant?

### 5. Output report

The inventory table is a **ledger**: one row per SLO, and the `Evidence` column carries the query or
API call that was actually run plus what it returned. Never write a verdict without filling that
cell. The shape below is illustrative — the numbers in it are placeholders, and a run that
reproduces them without having queried anything is the exact fabrication this skill exists to stop.

```
## SLO audit — <service> — <date>

### SLO inventory (5 active) — ledger

| SLO | Target | Window | Achieved 30d | Budget remaining | Evidence (query run → observed) | Verdict |
|---|---|---|---|---|---|---|
| API availability | 99.9% | 30d | 99.93% | 70% | `slo_errors:ratio_rate30d{slo="api"}` → 0.0007 | GREEN |
| API latency P95 | < 500ms | 30d | 480ms | 60% | latency-SLI good/valid ratio 30d → 0.9962 | GREEN |
| Order placement success | 99.5% | 30d | 99.2% | EXHAUSTED | vendor SLO API `orders.success` → 99.2%, budget 0 on d14 | **RED** |
| Email delivery | 99% | 30d | 99.95% | 95% | `slo_errors:ratio_rate30d{slo="email"}` → 0.0005 | TOO LAX |
| Background-job completion | 99% | 7d | — | — | backend unreachable from this environment (no TSDB endpoint configured) | **NO-DATA(backend unreachable)** |

Audit status: INCOMPLETE — unmeasured: background-job completion (no TSDB endpoint reachable
from this environment; re-run where `<query endpoint>` resolves).

### Trend analysis

**Order placement success — RED:**
- 99.5% target; 99.2% achieved.
- Error budget exhausted on day 14 of 30.
- Cause: vendor `payments-vendor-X` outages on 3 days.
- Action: investigate retry / fallback strategy; consider dual-vendor; raise vendor concern.
- Pause feature work on order-placement until budget recovers (current SRE policy).

**Email delivery — TOO LAX:**
- 99% target; 99.95% achieved consistently for 6 months.
- Suggest raising target to 99.5% to reflect actual reliability.
- Stakeholder sign-off needed (potential customer commitment).

**Background-job completion — NO-DATA(backend unreachable):**
- Declared in `ai/runtime/slos.md` with a 99% target on a 7-day window; not verdicted.
- The measurement was not attempted-and-failed on the SLO's merits — it was unreachable: no query
  endpoint resolves from this environment. That is a fact about this run, not about the service.
- Close it with: re-run where `<query endpoint>` resolves, or paste the backend's SLO export.
- Separately, and independent of the data: a 7-day window can miss slow degradation. Recommend a
  30-day window alongside it. (This recommendation is about the SLO's *definition*, which is
  readable from the registry — it needs no attainment data, which is why it survives a NO-DATA row.)

### Incidents catch-rate

Last 90 days: 4 incidents.
- INC-1014: API latency spike — caught by latency SLO at T+12 min.
- INC-1015: Order placement failure — caught by success SLO at T+8 min. Error budget exhausted same day.
- INC-1016: Email backlog — NOT caught by SLO; reached customer support ticket. SLO too lax (4h latency tolerated; should be 30min).
- INC-1017: Database failover — caught by API availability at T+3 min.

Catch rate: 3/4 = 75%. Improve email-delivery SLO to capture missed class.

### Recommended changes

| # | Change | Reason | Effort |
|---|---|---|---|
| 1 | Order placement: pause feature work; investigate vendor strategy | Budget exhausted | sprint |
| 2 | Email delivery: raise target 99% → 99.5% | TOO LAX consistent | 1 day (stakeholder) |
| 3 | Add 30-day window on background-job SLO | Catch slow degradation | 1 hour |
| 4 | Add email-delivery latency SLO (P95 < 30 min) | Existing SLO missed INC-1016 | 1 day |
| 5 | Decommission unused SLO `legacy-api-availability` | Service deprecated | 30 min |
```

### Closure gate — COMPLETE only when every SLO was measured

Compute the audit status from the ledger — do not hand-write it:

- **`COMPLETE`** — every row carries a measurement in its evidence cell and a verdict from the six
  attainment verdicts. Nothing else earns COMPLETE.
- **`INCOMPLETE — unmeasured: <list>`** — the moment any row is `NO-DATA`. Name each unmeasured SLO,
  what was unreachable, and the one command that would close it. An audit that verdicted four of
  five SLOs is a useful audit and an INCOMPLETE one; those are not in tension.

This gate is **[self-policed]** — no shell forces the status line — but it is wired to a checkable
artifact: the evidence column is inspectable, and `@sre-engineer` / `@observability-reviewer` will
BLOCK a COMPLETE whose rows carry verdicts with empty evidence.

## Inputs

- `ai/runtime/slos.md` — read, and written back (see Outputs). **May be absent**: that routes to
  step 1's define branch, never to a halt.
- 90 days of metrics from observability backend.
- Incident log if available.

## Outputs

- `ai/audits/slo-audit-<date>.md`.
- `ai/runtime/slos.md` — **created** when step 1 finds no registry, and **updated** when a
  recommended change to a target, window or owner is accepted. This skill is the pack's only writer
  of that file; `alert-design`, `add-telemetry`, `synthetic-monitoring` and `ai/patterns/slo.md`
  only read it.

## False positives / gotchas

- Audited only the last 7 days → missed slow-burn issues.
- Treated GREEN SLOs as "no work needed" → missed that they're TOO LAX (silent under-promise).
- Compared SLOs without their windows aligned → comparing apples to oranges.
- Recommended raising target without stakeholder buy-in.
- Dismissed a missed incident as "out of scope" when really it indicated SLO gap.
- **Filled the achieved-% column from the target column** because the backend was unreachable — the fabrication this skill's `NO-DATA` verdict exists to make unnecessary. An illustrative table is a shape, not a set of numbers to reproduce.
- Reported `STALE` when the truth was `NO-DATA` — that invents an instrumentation defect and sends someone to fix a service that is fine.
- Dropped an unmeasurable SLO's row entirely instead of marking it `NO-DATA` — a missing row reads as "this service has no SLO", a different and worse finding than "I could not measure it".

## Related

### Invoked by
- `/alert-design` Phase 1 — dispatched to define or re-verify the SLOs every alert that command emits will burn against. This skill is the only artifact in the pack that **writes** `ai/runtime/slos.md`; `alert-design`, `add-telemetry`, `synthetic-monitoring` and `ai/patterns/slo.md` all read it. An empty registry blocks all four, which is why "we don't have any SLOs" routes here rather than ending the run.
- Directly, for the quarterly review and post-incident target re-examination.

### Skills
- `alert-audit` — sibling audit; this audit's SLO definitions feed its burn-rate coverage check.

### Commands
- `alert-design` — uses SLO definitions.
- `add-metrics` — provides SLI data.

### Agents
- `@sre-engineer` — broader SRE work.
- `@incident-responder` — uses SLO context during incidents.

### Patterns
- `ai/patterns/slo.md`
- `ai/patterns/metrics.md`
