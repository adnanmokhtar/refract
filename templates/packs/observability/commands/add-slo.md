---
description: "Define one SLO as code: registry row, OpenSLO/Sloth spec, recording rules, multiwindow burn alerts, promtool test."
kind: command
pack: observability
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /add-slo

## The Premise (read this first, do not deviate)

**One SLO, end to end, or nothing.** An objective in a wiki is a poster; an SLO exists when four
artifacts agree: a registry row in `ai/runtime/slos.md` (SLI, target, window, owner, origin), a spec
in version control (OpenSLO, Sloth or Pyrra — the repo's generator), the recording and burn-rate
rules generated from that spec, and a promtool test proving the page tier fires on a fast burn and
only the ticket tier fires on a slow leak. This command writes all four for one service journey, in
the shapes the repo already uses.

**Mirror before you invent.** If the repo already ships SLOs, its generator, burn set, label keys
(`severity`, `slo`) and annotation keys (`summary`, `runbook_url`) are the convention. The burn set
is `/alert-design` § Phase 4 "SLO burn-rate alerts" (the arithmetic held in `THR-OBS-BURN`); this
command applies it to one SLO and never restates a different one.

**Never invent the target.** A first objective comes from a commitment or from measured behaviour,
exactly as `slo-audit` step 1 defines; otherwise the row is written `PROPOSED(<what would settle it>)`
with an owner who must confirm. `99.9 %` chosen because it looks like an SLO is the fabrication.

Boundaries: the *portfolio* of alerts for a service — cause-based pages, synthetic probes, hygiene,
the actionability ledger across every alert — is `/alert-design`. Auditing existing SLOs is
`/obs-audit` (`slo-rule-scan`, `slo-audit --no-write`). Fixing a broken burn rule is `/obs-fix`.

## When to use

- A service or journey with no SLO (`slo-rule-scan` §1 SLO-01 lists one; `/release` G-R6 refused).
- A new user-facing journey shipped by `/add-feature` whose `release.md` names an SLO that does not exist.

## Inputs

```
/add-slo <service> "<journey>"            # e.g. /add-slo checkout "place an order"
/add-slo <service> --sli=availability|latency|freshness|correctness
/add-slo <service> --period=30d           # default: the sibling SLOs' period, else 30d
```

## Phase 1 — Understand: what users feel, and what the repo already does

1. **The journey and its SLI** — pick from `ai/patterns/slo.md` § SLI menu: the symptom the user
   feels, as a **good-events / valid-events ratio**, never a raw percentile and never a cause signal
   (CPU, pool, queue depth). Latency is "requests under T", with T a registered bucket edge.
2. **Ground every series.** The SLI's metric names and labels must exist: registered in code, a
   recording-rule output, or an exporter default. Run `alert-rule-lint`'s
   `scripts/rule-inventory.py <files> --check=selectors --inventory=<names>` (observability pack; read
   its count first — an empty inventory grounds nothing). An ungrounded SLI is `/add-metrics` first.
3. **Error definition.** 5xx and timeouts are bad; 4xx the client caused are not (`slo-rule-scan` §4
   SLO-06, precedents § 13). Measure where users are: an edge that sees requests the app never does
   moves the SLI there (`slo-rule-scan` §4).
4. **What exists** — run `slo-rule-scan`'s pre-flight (its 0a–0c greps): specs, generator markers,
   vendor SLOs, the registry, a budget policy. The first spec found names the generator lane below.

## Phase 2 — Organize: the lane

| Repo already has | Spec this command writes | Rules come from |
|---|---|---|
| Sloth (`version: prometheus/v1`, or a `PrometheusServiceLevel` CRD) | a Sloth SLO entry | `sloth generate`, committed with its generated marker |
| Pyrra (`ServiceLevelObjective`, `pyrra.dev/`) | a Pyrra `ServiceLevelObjective` | Pyrra's generator / operator |
| OpenSLO (`apiVersion: openslo/…`) | an OpenSLO `SLO` (+ `SLI`) — the portable source of truth | the generator the repo pairs with it; with none, a Sloth spec beside it (state which in the registry row) |
| Vendor SLOs (`datadog_service_level_objective`, `honeycombio_slo`, `newrelic_service_level`, Grafana SLO) | the vendor resource in the repo's IaC | the vendor's own burn alerts; the promtool lane is N/A (say so) |
| Nothing | Sloth on a Prometheus stack (`ai/patterns/slo.md` § SLO-as-code: the pragmatic default) | `sloth generate` |

Generated rules are never hand-edited; a defect is fixed in the spec and regenerated (precedents § 42).

## Phase 3 — Retrieve: target, window, burn set

- **Target and origin**: `slo-audit` step 1 — a commitment (quote the document) or measured
  behaviour (90-day attainment rounded down, the query cited), else `PROPOSED(…)`.
- **Window**: the siblings' period, else rolling 30 days. It must fit the TSDB retention
  (`slo-rule-scan` §6 SLO-10) or name the long-term store that holds it.
- **Burn set**: the sibling's accepted set, else the Workbook 3-tier set — fast 1h/5m and medium
  6h/30m **page**, slow 3d/6h **ticket** — with every factor recomputed for the period
  (`budget_fraction × period / long_window`; 13.44 on 28 days, never a copied 14.4).

## Phase 4 — Generate

1. **The registry row.** Propose it — `name`, statement, `sli`, `target`, `window`, `owner` (a named
   person), `origin`, `spec` (path), `alerts` (the generated alert names, so `burn-check.py
   --registry` ties rule to row) — and **dispatch `slo-audit` in write mode** to write it.
   `slo-audit` is the single writer of `ai/runtime/slos.md` (`ownership.json` row `obs-slo`); this
   command never edits that file itself.
2. **The spec**, beside the sibling specs (never a guessed directory). Sloth example:

   ```yaml
   version: "prometheus/v1"
   service: "checkout"
   labels: { team: "payments" }
   slos:
     - name: "place-order-availability"
       objective: 99.9
       description: "Orders placed without a server-side error, 30d rolling."
       sli:
         events:
           error_query: sum(rate(http_requests_total{job="checkout",route="/orders",code=~"5.."}[{{.window}}]))
           total_query: sum(rate(http_requests_total{job="checkout",route="/orders"}[{{.window}}]))
       alerting:
         name: CheckoutPlaceOrderBurn
         labels: { slo: "place-order-availability" }
         annotations: { runbook_url: "ai/runbooks/alert-checkout-place-order-burn.md" }
         page_alert: { labels: { severity: page } }
         ticket_alert: { labels: { severity: ticket } }
   ```
3. **Generate** the recording and burn-rate rules with the repo's own generate flags, into the rules
   directory the siblings use; commit the output with the generator's marker.
4. **The promtool test pair, failing first.** Write `<rules dir>/tests/<slo>.test.yml` with two
   `alert_rule_test` groups fed synthetic series: (a) a fast burn (error ratio at 20× budget for 1h)
   must fire the page alert; (b) a slow leak (error ratio at 1.2× budget for 3d) must fire the ticket
   alert and **not** the page. Run it **before** step 3's rules are in place (or against the rules
   with the objective deliberately wrong) and record that it fails; then run it green. A test that
   passes on the unfixed rule proves nothing (`slo-rule-scan` § Proof).
5. **The runbook body** for the generated alerts: dispatch `@incident-responder` (its § Authoring a
   runbook) to write `ai/runbooks/alert-<name>.md` — symptom, blast-radius query, mitigation ladder,
   known false positives, escalation. A body whose first action is "investigate" is a missing runbook.

## Phase 5 — Update

- `ai/runtime/slos.md` — through `slo-audit` write mode only.
- The spec, the generated rules, the promtool test, the runbook — at the sibling paths.
- `ai/_history.md` — `<iso> add-slo <service>/<slo> → <status>`.

## Phase 6 — Validate: each step run, or NOT-RUN with the reason

```bash
"$SLOTH" validate -i <spec dir>; echo "sloth validate exit $?"              # or: pyrra / oslo validate -f <file>
python3 .claude/skills/slo-rule-scan/scripts/burn-check.py <generated rules> --spec=<spec> --registry=ai/runtime/slos.md --format=text; echo "burn-check exit $?"
command -v promtool >/dev/null && { promtool check rules <generated rules>; promtool test rules <rules dir>/tests/<slo>.test.yml; }
```

| Check | PASS | Otherwise |
|---|---|---|
| Spec validates | the generator's `validate` exits 0 | `NOT-RUN (<tool> not installed)` — install the version `slo-rule-scan` § Tool lane pins, in a scratch dir |
| Regenerate = committed | regenerating from the spec into `${TMPDIR}` and `diff -u` against the committed rules is empty | the drift is the defect |
| Burn arithmetic | `burn-check.py` exit 0 for the new rules, tied to the registry row | its row, verbatim |
| promtool | `check rules` and `test rules` exit 0, **and** the recorded failing-first run exited non-zero | `NOT-RUN (promtool not installed)` — never PASS; the run is `INCOMPLETE` until it runs |
| Selectors grounded | `rule-inventory.py --check=selectors` reports no UNGROUNDED series | the SLI reads a series that does not exist |
| Registry row | written by `slo-audit`, with `owner` and `origin`; a `PROPOSED` target names who confirms it | not done |
| Runbook | `test -f` succeeds and the body names a concrete first action | `ORPHAN` |

**Status: `COMPLETE`** only when every row passes. A `NOT-RUN` row makes it
`INCOMPLETE — unverified: <check> NOT-RUN (<reason>)`; a `PROPOSED` target makes it
`COMPLETE — target PROPOSED (owner <name> to confirm)`.

## Output

```
## /add-slo checkout "place an order"

Lane: Sloth (deploy/slo/sloth/ — 3 sibling specs, Workbook 3-tier set, 30d)
SLI: availability — good = non-5xx on route /orders (grounded: http_requests_total, 41 series in the inventory)
Target: 99.9 % / 30d — origin: measured 99.94 % over 90d (query cited), owner Dana Reyes
Registry: slo-audit write mode → ai/runtime/slos.md row place-order-availability
Spec: deploy/slo/sloth/checkout.yml · rules: deploy/prometheus/rules/generated/checkout-slo.rules.yml (sloth marker)
Alerts: CheckoutPlaceOrderBurn page 1h/5m 14.4 · page 6h/30m 6 · ticket 3d/6h 1
Checks: sloth validate exit 0 · regenerate diff empty · burn-check exit 0 · promtool test: red first (exit 1, rules absent), then exit 0
        selectors 0 UNGROUNDED · runbook ai/runbooks/alert-checkout-place-order-burn.md (first action: check pool saturation panel)
Status: COMPLETE
```

## Halt conditions

- The SLI reads a series that exists nowhere → stop; `/add-metrics` first.
- A latency threshold that is not a registered bucket edge (`slo-rule-scan` §5 SLO-07) → stop; fix the buckets or the threshold.
- Asked to write `ai/runtime/slos.md` directly → refuse; it is `slo-audit`'s.
- A target with no commitment and no data → write it `PROPOSED`, never a round number.

## Related

- `/alert-design` (this pack) — the alert portfolio and the burn-set statement this command applies.
- `slo-audit` (single writer of `ai/runtime/slos.md`), `slo-rule-scan` (`burn-check.py`, Tool lane, Proof), `alert-rule-lint` (`rule-inventory.py`) — this pack's skills.
- `@incident-responder` — the runbook body. `@sre-engineer` — the error-budget policy (`ai/reliability/error-budget-policy.md`).
- `/release` (devops pack) — reads the SLO as its step analysis (G-R6).
- `ai/patterns/slo.md` — SLI menu, burn arithmetic, SLO-as-code.
