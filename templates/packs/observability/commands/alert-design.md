---
description: "Design alerts for a service. Uses RED + USE + SLO-based alerts. Avoids the two anti-patterns: alert fatigue + missed pages. Outputs alert definitions + runbook entries."
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /alert-design

## The Premise (read this first, internalize, do not deviate)

**Existing alerts are the truth.** If this repo already ships alerts (in whatever alerting backend the project uses — Prometheus Alertmanager rules, Datadog monitors, Grafana alerts, vendor monitor JSON, etc.), those thresholds, severity tiers, burn sets, and runbook conventions ARE the convention. New alerts MUST match sibling alerts: same severity labels (`page` / `ticket` / `info`), same threshold magnitudes for comparable signals (error-rate, latency, saturation), same burn set (the accepted set in `THR-OBS-BURN` the siblings use — Workbook 3- or 4-tier, Pyrra 14/7/2/1), same annotation keys (`summary`, `runbook_url` — whatever keys the siblings use). Match thresholds and severity tiers to sibling alerts unless data justifies divergence.

**The agent's job is exactly this:**
1. Audit existing alerts first (Phase 1 already requires this — enforce it). Read sibling thresholds, severity labels, windows, annotation shapes.
2. Mirror those shapes for the new alerts. Same severity vocabulary. Same burn set. Same annotation keys.
3. Only deviate when historical data (past incidents, error budget burn rates) justifies a different threshold — and document the rationale inline.

**The agent does NOT:**
- Pick a threshold from a blog post (`> 1% over 5min`) when sibling alerts on the same signal use a multi-window burn-rate.
- Introduce a new severity tier (`critical`, `warn`, `urgent`) when sibling alerts use `page / ticket / info`.
- Pick burn-rate windows (2h / 12h) different from sibling SLO alerts (1h / 6h) without a data-driven reason.
- Write a burn factor from memory or judge one by its literal. The factor is arithmetic (`THR-OBS-BURN`): `budget_fraction × period / long_window`.
- Name a metric, label or selector that resolves in no inventory (precedents § 37).
- Write `ai/runtime/slos.md`. `slo-audit` is its single writer; this command proposes rows and dispatches it (Phase 1).
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
3. **Burn-set parity** — multi-window burn-rate alerts use the sibling's burn set unless data-justified, and every factor and short window passes the `THR-OBS-BURN` arithmetic for the declared objective and period (short = long/12, or the generator set's own). `burn-check.py` decides in Phase 6; a literal never does (precedents § 12).
4. **Runbook link present** — every `severity: page` alert MUST carry the siblings' runbook annotation key (`runbook_url` by default) pointing at an existing or newly-stubbed file. Missing = HALT.

Add the check results to the output block under `Rationale-grep: ✓ | hand-wave halts=<N> | severity-parity ✓ | burn-set-parity ✓`.

Design alerts that fire when something is actually wrong + DON'T fire when nothing is. The two failure modes are equally bad: too many alerts → fatigue → ignored pages → real outages missed; too few → outages happen with no early warning.

## Phases applied

All 7.

## Phase 1 — Understand

Confirm:
- Service / endpoint / job in scope.
- **SLOs / SLAs — and if there are none, this is where they get defined, not where the run stops.** Every alert this command emits burns against an SLO, so an empty `ai/runtime/slos.md` blocks everything downstream. **Propose the rows** — SLI, target with its `origin` (a commitment, or measured behaviour; a burn rule already in the repo implies an objective, `PROPOSED(implied by <file:line>)`), window, owner — and **dispatch the `slo-audit` skill in write mode to write them.** It is the only writer of the registry (`ownership.json` row `obs-slo`) that `alert-design`, `add-telemetry`, `synthetic-monitoring` and `slo.md` all read; this command never edits the file itself. "We don't have any" is an input to this phase, never an exit from it.
- **Versions (gate 3).** Read the Prometheus and Alertmanager versions from a file — the compose image tag, Helm values, the Prometheus CR `spec.version`, the `kube-prometheus-stack` chart pin (`alert-rule-lint` § Adapt) — and print each with its source. A chart installed with no `--version` pins nothing: the major is **unread**. Unread → ask for it (`NEEDS_INPUT`), or run the Phase 6 pair on both promtool majors; a rule whose result differs between them is not ACTIONABLE until the version is pinned or read.
- On-call structure (who pages, what hours, escalation policy, rotation size) — Phase 6's page budget is computed from it.
- Existing alerts — run `alert-rule-lint` on the existing rule, Alertmanager and monitor files first: its rows give the sibling vocabulary (severity, team, runbook key, burn set) and the defects already there. Many will be deletable.
- Backend: the project's alerting + paging stack (e.g., Prometheus Alertmanager / Datadog Monitors / Grafana Alerts / vendor monitor JSON, paging via PagerDuty / Opsgenie / Grafana OnCall / equivalent).

## Phase 2 — Organize

Four alert classes:

1. **Symptom-based (SLO burn)** — alerts on user-facing symptom: error budget burning fast, medium, or slowly.
2. **Cause-based (saturation / errors)** — alerts on resource exhaustion, error spike, queue backup.
3. **Heartbeat / liveness** — service stops emitting metrics → alert.
4. **Blackbox / synthetic** — a scripted probe drives the real user journey from outside and pages on its own route. This is the class that catches "every white-box signal green, nobody can log in", and it is the one most often missing entirely. If the service owns a critical user journey, **dispatch the `synthetic-monitoring` skill** to find the journeys with no probe, no probe-SLO, or a single location — its findings are alerting gaps and belong in this command's output.

The healthiest alert posture is **SLO-burn-rate alerts** (an accepted burn set, below) plus a blackbox page per critical journey plus a small set of cause-based for things SLO can't catch (security events, data integrity, dependency failures).

## Phase 3 — Retrieve

- The SLO rows Phase 1 proposed, and `ai/runtime/slos.md` as `slo-audit` left it.
- Metrics catalog in `ai/runtime/metrics-catalog.md`.
- **The metric inventory** — `alert-rule-lint`'s pre-flight step 2 (names registered in code, translated per precedents § 43) plus recording-rule outputs and exporter defaults. Every selector this command writes must resolve in it; an exporter default is `exporter-default (unverified)` until its exporter is shown deployed.
- The scrape interval of each job the new rules read (`prometheus.yml`, ServiceMonitor `interval`, Alloy) — a rate window must be ≥ `THR-OBS-RATE-WINDOW.min_multiple_of_scrape` × that interval.
- On-call runbook structure if any.
- Past incidents — what fired, what didn't, what should have.

## Phase 4 — Generate

### SLO burn-rate alerts (multi-window, multi-burn-rate)

**One SLO end to end** — registry row, spec, generated rules and the promtool pair — is `/add-slo`, which applies this section to a single SLO; this command keeps the portfolio view. The rule is arithmetic, held in one place (`THR-OBS-BURN`): a tier's factor is
`budget_fraction × period / long_window`, and each tier fires only when **both** windows exceed it —
`error_ratio(long) > factor × (1 − objective) AND error_ratio(short) > factor × (1 − objective)` —
with the short window = long/12, or the generator set's own. For a 30-day period that gives the
Workbook set (derivation in `ai/patterns/slo.md`):

| Tier | Budget spent if sustained | Long window | Confirmation window | Factor (30d) | Severity |
|---|---|---|---|---|---|
| Fast burn | 2% | 1h | 5m | 14.4 | **page** |
| Medium burn | 5% | 6h | 30m | 6 | **page** |
| Slow burn | 10% | 3d | 6h | 1 | **ticket** |

Accepted sets (`THR-OBS-BURN`): this Workbook 3-tier set; the 4-tier variant that adds 3× over
24h/2h as a second ticket (sloth `google-30d`); Pyrra's 14 / 7 / 2 / 1 on windows scaled to the
period. **Mirror the sibling's set.** For a period other than 30 days, recompute each factor from the
formula — on 28 days the fast factor is 13.44 — instead of copying a 30-day literal into a rule it
does not fit (precedents § 12).

Two of these get mis-emitted routinely, and both changes are behavioural:

- **The 6h / 6× tier pages.** It is Google's second *page* tier — 5% of the month's budget in six
  hours is an outage in progress. Emitting it as a ticket means a Saturday regression waits for
  Monday.
- **The tier that tickets is 3d / 1×, and it is the one usually missing.** A leak burning at exactly
  the target rate trips neither page tier *by construction*, so a set with no slow ticket has no
  detector at all for "we will miss the SLO at month-end". Emit it even though it fires rarely — rarely is the
  point.

Generate burn rules from a spec where the repo has a generator (sloth, Pyrra; `ai/patterns/slo.md` §
SLO-as-code). A defect in a generated rule is fixed in the spec and regenerated, never hand-edited
(precedents § 42). A multiwindow burn rule takes no `for` — its short window debounces (precedents §
2).

Match label keys (`severity`, `slo`) and annotation keys (`summary`, `runbook_url`) to sibling alerts.

### Cause-based alerts (limited set)

A cause signal is a **ticket** by default, with a dashboard panel first. A cause pages only when it is
definite and imminent (precedents § 4); a page on CPU, memory or a static disk threshold with no
user-facing signal is `alert-rule-lint` §7 (SY-01).

Page only when:
- **Disk full within hours, projected:** `predict_linear(<filesystem-available metric>[6h], 4 * 3600) < 0`
  for the volume, with a short `for`. Never a static "disk > 80%": that pages for weeks on a volume
  filling slowly and is late on one filling fast. The metric name comes from the inventory
  (node-exporter's `node_filesystem_avail_bytes` is an exporter default — confirm node-exporter is
  deployed).
- A certificate expires before the next business day.
- A replicated store loses quorum.

Ticket when:
- DB connection pool > 90% utilized for 5 min.
- Queue depth > N (where N is the consumer's max throughput × 5 min).
- Memory > 90% on app servers (the orchestrator restarts the pod; the leak is a ticket).
- Disk projected full within days (the same `predict_linear`, a longer horizon).
- Cert expiring in < 14 days.
- Vendor / dependency reports outage.

Don't alert when:
- CPU is high (often misleading; doesn't correlate with user impact).
- One container instance restarted (let the orchestrator handle it; alert only if ALL replicas restart).
- Single error response (statistical noise; SLO-burn handles aggregates).
- Slow query (let APM handle; alert if P95 SLO burns).

### Heartbeat / liveness

- **Absent primary counter → page.** `absent(<primary request counter>{job="<job>"})` with `for: 5m` and an exact `job` — never a regex matcher, which hides a missing target, and never without `for`, which pages on every restart (`alert-rule-lint` §6, AL-17). On a vendor backend, its no-data mechanism (Datadog `notify_no_data`, Grafana `noDataState` set to alert — `alert-rule-lint` §9). Annotation: "service emitting no metrics for 5 min — likely down".
- **Every ratio page gets a traffic-absent sibling** for the same job or denominator (`sum(rate(<total>[5m])) == 0`, with a `for`). At zero traffic a ratio is NaN and stays silent through a total outage (AL-16, precedents § 5).
- **One Watchdog** (`vector(1)`, always firing) routed to an external heartbeat receiver proves the alerting pipeline itself is alive (AL-18).

### Alert hygiene

For every alert:
- **Severity** — page / ticket / info. Page = wake someone. Ticket = handle business hours. Info = context only.
- **Runbook URL** — every PAGE alert has a runbook. Without a runbook, the alert is "panic"; with one, it's "execute steps."
- **Threshold rationale** — why 90% not 80%? Document.
- **Window** — every rate window ≥ 2× the job's scrape interval (`THR-OBS-RATE-WINDOW`; exactly 1× is empty on Prometheus 3).
- **Labels** — `$value` in annotations only, never in labels (AL-06: every new value is a new alert, so `for` never completes). Group-level `labels:` only on a server read as 3.x — 2.x rejects the whole file (precedents § 41).
- **`for` and `keep_firing_for`** — a threshold page carries a `for` under `THR-OBS-ALERT.page_for_max`; `keep_firing_for`, if any, is no longer than `for` (AL-09).
- **Auto-resolution rule** — when does it stop firing?
- **Escalation policy** — who if primary doesn't ack in N min?

## Phase 5 — Update

- `ai/runtime/slos.md` — **not written here.** `slo-audit`, dispatched in write mode in Phase 1, is its single writer; the rows this run proposed reach the registry only through that dispatch.
- `ai/runtime/alerts.md` — alert catalog with severity / runbook / rationale per alert.
- `ai/runbooks/<alert-name>.md` — per-alert runbook. **Dispatch `@incident-responder` to write the body.** It owns live-incident procedure — the mitigation ladder for this failure class, the first three diagnostic queries, the escalation path — which is what turns a file into something executable at 3am. A runbook whose body says "investigate" is an ORPHAN in the ledger below, exactly as if the file were missing.
- Backend config (the project's alerting backend rules — Prometheus rules / Datadog Monitors / Grafana Alerts / vendor monitor JSON) — checked in to repo.
- The promtool rule tests from Phase 6 step 2, committed beside the rules, so CI can run them (the RULES GATE `/obs-audit` checks).

## Phase 6 — Validate

Agent-verified, in this order. Each step's command and result is evidence for the ledger.

1. **Rule gate (T) — dispatch `alert-rule-lint` on every rule, Alertmanager and monitor file this run wrote or touched.** It works on copies in `${TMPDIR}` and returns per-rule rows:
   - `promtool check rules --lint=all --lint-fatal` (exit 1 error, 3 lint) and pint `--offline` with its scratch config;
   - `rule-inventory.py --inventory=<inventory> --prom-major=<major read in Phase 1>`: `for`, runbook and severity, windows against the job's scrape interval, NaN / `absent` / Watchdog, Prometheus-3 breakage;
   - **§4 grounding — the dead-on-arrival check.** Every selector resolves in the inventory (a code registration, a recording rule, or an exporter default marked unverified), and every rule file is matched by a `rule_files` glob or the Prometheus CR `ruleSelector` (AL-22);
   - **§8 routes matrix:** `amtool config routes test --verify.receivers=<the receiver this design names>` for every label set the new rules emit (exit 1 on mismatch; without `--verify.receivers` amtool always exits 0).

   Any H/M/L row on a rule this run wrote halts. A tool that cannot install prints `blocked (lane not installed: <tool>@<ver>)`; `rule-inventory.py` still runs.
2. **Fire / blip pair (T) per page rule** — `promtool test rules` on the copy, with the promtool binary of the server's major (3.15.0 for a 3.x server, 2.55.1 for 2.x). One test must fire at the failure point and one must stay silent at a blip shorter than the rule's `for`; a ratio rule also gets a total-outage test in which its traffic-absent sibling fires (`proof-oracles.md` § Observability, *promtool rule test*, V203 / V204). Take the series, windows and `eval_time` from the rule itself. A test that passes on a mutated threshold proves nothing; rebuild it until it fails there. Its input series are mocked, so it never proves the metric exists (precedents § 16) — step 1's grounding does that.
3. **Burn arithmetic (T)** — `burn-check.py` (`slo-rule-scan` §2, installed under `.claude/skills/slo-rule-scan/scripts/`) on every burn rule, with `--registry=ai/runtime/slos.md` when the registry exists (it ties each existing rule to its SLO row by the row's `alerts` or `rules` cell — `slo-rule-scan` step 2) and `--slo='<alert regex>=<objective>/<period>'` for the rows Phase 1 proposed and the registry does not hold yet (`--slo` overrides a registry row); exit 0. For generated rules, regenerate from the spec into `${TMPDIR}` and diff against the committed output: empty (`slo-rule-scan` § Tool lane).
4. **Behaviour (L) — dispatch the `alert-audit` skill** with step 1's rows (it halts without them). For a rule that replaces or mirrors an existing one, it answers from fire and paging history whether the threshold would have fired during past incidents. Without a reachable backend its rows are `NO-DATA(<source>)`, and a newly added rule has no history at all; that half is printed on the Status line (`behaviour NO-DATA(<source>)`), not inferred.
5. **Page budget** — `THR-OBS-PAGE-BUDGET`: `pages_per_shift ≤ shift_hours / followup_hours_per_page` (defaults 12 h and 6 h, about two pages per shift). Measure the second term from this team's postmortems where they exist and record both inputs in the output block; a default used because none exists prints `default (THR-OBS-PAGE-BUDGET)`. The projected page volume needs fire history: without it, print `projected volume NO-DATA(<source>)`.

### Actionability ledger — REQUIRED OUTPUT ARTIFACT (the run is not done until this table exists)

An alert is production-grade only when it is SLO-linked, provably fires at the failure and stays silent at a blip, reads series that exist, and hands the responder a runbook. Assert each — do NOT declare a count and stop. One row per generated alert:

```
Alert (name)              | Sev    | SLO/SLI it burns        | Window / factor          | Rule gate (lint rows · promtool pair)            | Runbook (file + first action)    | Status
checkout-fast-burn        | page   | checkout.success        | 1h/5m · 14.4 (workbook-3) | 0 rows · fire ✓ blip ✓ (promtool 3.15.0)         | ai/runbooks/… → yes, "flip flag" | ACTIONABLE
checkout-med-burn         | page   | checkout.success        | 6h/30m · 6               | 0 rows · fire ✓ blip ✓                           | ai/runbooks/… → yes, "flip flag" | ACTIONABLE
checkout-slow-burn        | ticket | checkout.success        | 3d/6h · 1                | 0 rows · burn-check exit 0                       | ai/runbooks/… → yes, "open PM"   | ACTIONABLE
checkout-journey-probe    | page   | probe.checkout          | blackbox                 | 0 rows · fire ✓ blip ✓                           | ai/runbooks/… → yes, "check CDN" | ACTIONABLE
data-disk-full-4h         | page   | (cause: precedents § 4) | predict_linear 6h → 4h   | 0 rows · selector exporter-default (unverified)  | ai/runbooks/… → yes, "expand PV" | NO-DATA(prometheus)
db-pool-saturation        | ticket | (cause, dashboard)      | for 5m                   | 0 rows                                           | ai/runbooks/… → yes, "scale pool"| ACTIONABLE
```

Per-row `Status`:
- **ACTIONABLE** — SLO/SLI named (or explicitly a cause ticket, or a cause page that cites precedents § 4); `alert-rule-lint` printed no H/M/L row for it; a page has its promtool pair green on the server's major; every selector grounds in code or a recording rule; and `test -f` on the runbook path succeeds AND its body names a concrete first action. Only ACTIONABLE counts.
- **UNLINKED** — the alert fires on a static threshold with no SLO/SLI behind it, or a `page` alert is cause-based without a precedents § 4 reason. Fix (convert to burn-rate) or demote — not shippable as a page.
- **ORPHAN** — pages into a void: no runbook file on disk, a runbook whose body says "investigate", a rule `alert-rule-lint` §4 shows can never fire (AL-10 resolved nowhere, AL-11, AL-22 never loaded), a page label set the §8 matrix routes to a receiver with no integrations, or no owner label on a catch-all route. Halt.
- **NO-DATA(reason)** — a link only a tool or a live backend can settle is unsettled: promtool could not install, the Prometheus major is unread and the pair disagrees across majors, or a selector grounds only as an exporter default and needs a live `count(<selector>)`. Name what was missing and the settling command. UNVERIFIED is not a pass: any NO-DATA row makes the run INCOMPLETE, exactly like an UNLINKED one. Do not launder it into ACTIONABLE because the other columns were checkable.

Coverage rows (not per-alert, but part of the gate):
- Every SLO the run touches resolves in `ai/runtime/slos.md` (as `slo-audit` wrote it) and has an accepted burn set: its fast tiers page, its slow 1× tier tickets, and `burn-check.py` exits 0.
- Every ratio page has a traffic-absent sibling, and one Watchdog reaches an external heartbeat receiver.
- Every critical user journey has a blackbox page route that does not depend on a white-box condition (`synthetic-monitoring`'s findings). A missing journey probe is an alerting gap, not a nice-to-have.

OPERATOR CHECKLIST (live — NOT auto-passed):
- [ ] Trigger each alert deliberately (toy app, staging) → it fires AND pages the right person.
- [ ] Wait for it to clear → it auto-resolves.

## Phase 7 — Improve

- After each incident: post-mortem reviews alerts fired (false positives? missed?).
- Quarterly: audit alert silence-rate + ack-rate (`alert-audit` with the backend URL). Alerts silenced > 50% are noise; delete.
- Recurring page-and-ack-no-action → alert is informational, not actionable.

## Output format

```
## /alert-design — <service>

Service: <name>
Versions: Prometheus <ver> (<file:line> | UNREAD) · Alertmanager <ver> (<file:line>) · promtool <ver> used for the pairs
SLO definitions: <count> (rows proposed: <n> · slo-audit write mode dispatched: yes/no — <what it wrote to slos.md>)
Page budget: <N>/shift = <shift hours>h ÷ <hours of follow-up per page>h  (source: <postmortem sample | default (THR-OBS-PAGE-BUDGET)>)
Page alerts: <count> (projected <N>/week vs budget <N>/week | projected volume NO-DATA(<source>))
Ticket alerts: <count>
Heartbeat alerts: <count> (traffic-absent siblings <n> · Watchdog → <receiver>)
Blackbox/journey alerts: <count> (uncovered journeys per synthetic-monitoring: <list>)
Runbooks: <count>

Rule gate: alert-rule-lint <k rows on touched files → m on rules this run wrote> · promtool check exit <n> · promtool test exit <n> (<test file>) · routes matrix <k label sets, <m> mismatches> · burn-check exit <n> · regenerate diff <empty | N lines | N/A>
Behaviour: alert-audit <verdicts | NO-DATA(<source>)>

Actionability ledger: <rows> alerts — ACTIONABLE <a> | UNLINKED <u> | ORPHAN <o> | NO-DATA <n>
  <the ledger table above, verbatim, with per-alert evidence>

Alert catalog: ai/runtime/alerts.md
Backend config: <path to rule files / monitors.yaml / etc.>

Status: <see gate below>
```

### Closure gate — COMPLETE only when every alert is actionable, else INCOMPLETE with the unmet alerts named

Compute Status from the ledger, the rule gate and the `alert-audit` result — do NOT hand-write it:

- **`Status: COMPLETE`** — ONLY when every ledger row is `ACTIONABLE`; `alert-rule-lint` printed no H/M/L row on a rule this run wrote; `promtool check rules` exited 0 and every page rule's fire / blip pair is green on the server's major; `burn-check.py` exited 0 and every regenerate diff is empty; every coverage row holds; and the page budget's inputs are recorded. The behavioural half — `alert-audit`'s replay and the volume projection — prints its result or `behaviour NO-DATA(<source>)` on the Status line; at NO-DATA it does not by itself block COMPLETE, but an `alert-audit` DEAD / NOISY / ORPHAN / CAUSE-AS-PAGE verdict on a rule this run touched does, and so does a projection over budget.
- **`Status: INCOMPLETE — unmet: <list>`** — the moment any row is `UNLINKED`, `ORPHAN` or `NO-DATA`, a rule-gate step fails or is blocked, a coverage row fails, or the projection breaches budget. NAME each unmet item and why (e.g., `search-latency — UNLINKED: static p95>500ms, no SLO; convert to burn-rate`; `import-job-failed — ORPHAN: no runbook file`; `checkout-fast-burn — ORPHAN: alert-rule-lint §4 AL-10, http_request_duration_second_bucket resolves in no inventory`; `checkout.success — coverage: no 3d/1× ticket tier, a target-rate leak is undetectable`; `data-disk-full-4h — NO-DATA: node_filesystem_avail_bytes is an exporter default, run promtool query instant <url> 'count(node_filesystem_avail_bytes)'`). A set of alerts that "would fire" but page into a void is INCOMPLETE, and so is a set nobody could verify.

This gate is **[self-policed]** on the Status line, but wired to checkable evidence: the runbook paths (`test -f`), the SLO names (must resolve in `ai/runtime/slos.md`), the `alert-rule-lint` rows, the committed promtool test file and its exit code, and the `burn-check.py` output are all inspectable — `@sre-engineer` / `@observability-reviewer` will BLOCK a COMPLETE whose alerts are unlinked, runbook-less or ungrounded.

## Hard rules

- **Every PAGE has a runbook with a first action.** Without it, page = panic.
- **SLO-based alerts beat threshold-based.** Threshold (e.g., "P95 > 500ms") is symptom-removed; SLO burn rate is user impact.
- **Burn factors come from the arithmetic** (`THR-OBS-BURN`), never from a remembered literal.
- **Every selector resolves in the inventory**, and every page rule has a promtool pair that fails before the rule is right (precedents § 16, § 37).
- **Generated rules are fixed at their spec and regenerated**, never hand-edited (precedents § 42).
- **Page rate within the budget** (`THR-OBS-PAGE-BUDGET`). More = fatigue → real pages ignored. Show the inputs; a quoted number nobody can re-derive gets waived.
- **Auto-resolution defined.** Alerts that "fire and stay fired" rot.
- **No PII / secrets in alert annotations.**

## Failure modes

- Alert fires on every deploy → on-call learns to ignore → real outage missed.
- Threshold set in dev / staging values → never fires in production.
- Runbook missing or outdated.
- Page wakes person; runbook says "investigate" with no first action.
- Alert depends on a metric that wasn't actually instrumented → silently never fires (`alert-rule-lint` §4 catches it before merge; a promtool test with mocked series does not).
- A rate window of one scrape interval → empty on Prometheus 3, so the rule never fires.
- A ratio alert with no traffic-absent sibling → silent through a total outage.
- Escalation policy points at someone who left.

## Related

- `add-telemetry` (and its narrow entry points `add-metrics` / `add-tracing`) — emit the series these alerts burn against.
- `/add-slo` (this pack) — one SLO end to end (registry row through `slo-audit`, spec, generated rules, promtool pair); it applies this command's burn set rather than restating it.
- `slo-audit` skill — **dispatched in write mode in Phase 1** to write the SLO rows this command proposes; it is the only artifact that writes `ai/runtime/slos.md`, which this command, `add-telemetry`, `synthetic-monitoring` and `slo.md` all read.
- `alert-rule-lint` skill (and `rule-inventory.py`) — **dispatched in Phase 1** on the existing alerts and **in Phase 6 step 1** on the generated ones: per-rule lint, selector grounding, rule loading, routes matrix.
- `slo-rule-scan` skill (`burn-check.py`) — Phase 6 step 3: burn arithmetic and regenerate-and-diff.
- `alert-audit` skill — Phase 6 step 4: the behavioural replay against fire and paging history, `NO-DATA` without a backend.
- `synthetic-monitoring` skill — **dispatched in Phase 2** when the service owns a critical user journey; its uncovered-journey findings are alerting gaps this command must close.
- `@incident-responder` agent — **dispatched in Phase 5** to author the runbook bodies, and the agent that executes them during a live page.
- `@sre-engineer` agent — broader SRE concerns and the budget policy; alert-design is one dimension.
- `/obs-audit`, `/obs-fix` — audit the alerting this command produces; close what the audit finds.
- `.claude/rules/observability-principles.md`.
