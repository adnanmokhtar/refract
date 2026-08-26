---
name: chart-encoding-audit
description: Audit every chart in a project against the encoding floor — is the mark right for the question, does the scale tell the truth, is the data colour readable without colour vision, does the chart carry its units. Run before shipping a dashboard, after a redesign re-themes existing charts, when a stakeholder misreads a number off a chart, or as a quarterly analytics-surface review. Encoding only — `design-token-audit` owns whether values come from the system and `a11y-quick-check` owns the surrounding page. The rules are not defined here; they are cited from `data-visualization.md`.
kind: skill
pack: ui-ux
---

# Skill: chart-encoding-audit

A re-themed chart passes every existing gate in this pack and can still mislead the person reading it. This skill walks the project's chart surface and asks the question re-theming never asks: is this drawing true.

## Premise

Find real encoding defects, no hand-waves. Every finding cites `<path:line>` of the chart config — the component, the options object, or the spec — and names the concrete defect: a mark that does not answer the question, a truncated value axis, a categorical ramp past its ceiling, a red-vs-green series pair, a missing unit. **"The chart is confusing" is the symptom that prompted the audit, not a finding.** The finding is the encoding decision plus what a reader would conclude wrongly because of it.

**This skill does NOT own the rules.** Mark selection, the three scale families, and the honesty rules all come from [`data-visualization.md`](../../ai-patterns/data-visualization.md). This skill detects and cites — a threshold here that disagrees with that file is drift, and that file wins.

**It also does not own the paint.** Whether a chart matches the design language is `ui-design-sweep § normalize-surface` and the `tokens` axis. A chart can be perfectly on-brand and fail every check below; that is the whole reason this audit exists separately.

## Halt conditions

- Halt on a finding without `<path:line>` for the chart config or spec.
- Halt on a colour-safety verdict that was not **computed** — a contrast ratio, or a simulated colour-vision check naming the tool. "Looks distinguishable to me" is the failure this skill exists to catch, and the auditor is not exempt from it.
- Halt on proposing a data ramp whose values are invented rather than derived from a named perceptual scale or the project's resolved tokens.
- Halt on filing a re-theming finding here. It routes to `ui-design-sweep`; a finding on the wrong oracle is counted twice and fixed by nobody.
- Halt on asserting a chart is wrong without naming the QUESTION it should answer. "Should be a bar chart" is an opinion until the question is on the page.

## When to use

- Before shipping any dashboard, report, or analytics surface.
- **Immediately after `/redesign` or `/art-direct` re-themes existing charts** — re-theming is the moment a wrong mark gets locked in behind a beautiful skin.
- When a stakeholder reads a number off a chart and gets it wrong. That is a reproducible encoding bug, not a training issue.
- Quarterly review of an analytics surface, alongside `design-token-audit`.

## Procedure

### 1. Inventory charts

Search for chart primitives. The families differ per stack; the audit is identical.

| Web | Mobile | Spec-driven |
|---|---|---|
| Recharts `<LineChart>` / `<BarChart>` | `react-native-svg-charts`, Victory Native | Vega / Vega-Lite spec objects |
| Chart.js `new Chart(...)` / `type:` | `fl_chart` (Flutter) | Observable Plot marks |
| ECharts `setOption({ series: [...] })` | Swift Charts `Chart { }` | Metabase / Looker saved questions |
| ApexCharts, Nivo, Visx | Jetpack Compose `Canvas` charts | Any BI layer the app embeds |
| Hand-rolled SVG / `<canvas>` | | |

Per chart, record: **the question it appears to answer**, the mark, the value-axis range, the series count, the colour source, and whether units appear. Hand-rolled SVG counts — it is where the worst offenders hide, because no library default protected it.

### 2. Mark selection

For each chart, write the question the surrounding surface is asking, then check the mark against `data-visualization.md § The chart-selection map`.

- A mark that does not match its row is a finding — cite the row and the mark it prescribes.
- A chart answering **two** questions is a finding: split it, or drop to the question the surface's job actually asks.
- A chart whose question you cannot state from the surface is the strongest finding of the run: nobody knows what it is for, and it is probably decoration billed as insight.

### 3. Encoding honesty

Run each chart against `data-visualization.md § Encoding honesty`. These are mechanical:

| Check | How to detect | Severity |
|---|---|---|
| Bar / column / area baseline is zero | axis `min` set to a non-zero value, or `beginAtZero: false` | **HIGH** — magnitude is multiplied by an arbitrary factor |
| Line axis is zoomed but labelled | axis range present, no range shown to the reader | MEDIUM |
| Area encodes area, not radius | bubble / circle sizing that maps value → radius | **HIGH** |
| Single scale per axis | two y-axes with independent domains and different units | **HIGH** — manufactures a correlation |
| Units present | axis title, value labels, or tile suffix carries the unit + period | MEDIUM |
| Sorted by value | categorical axis in source or alphabetical order where rank is the question | MEDIUM |
| Missing data drawn as missing | `spanGaps: true`, or nulls coerced to `0` before plotting | **HIGH** — invents readings |
| Aspect ratio stable across comparable charts | differing plot ratios for the same series family | LOW |

`spanGaps` and null-to-zero coercion are the two that hide furthest from the chart config — check the data transform, not only the options object.

### 4. Data colour

Against `data-visualization.md § Data colour is not UI colour`.

1. **Where does the colour come from?** If series colours are drawn from the UI accent ramp or brand tokens, that is the finding: the project has no data ramp, and the fix is to add one, not to hand-pick hexes at the call site.
2. **Is the family right?** Sequential for magnitude, diverging only around a *real* midpoint, categorical for identity. A rainbow used as sequential is a finding every time — hue carries no order.
3. **Categorical ceiling.** More than ~8 series is a finding; propose grouping the tail.
4. **Second channel.** Any series set separated by colour alone fails. Simulate a colour-vision deficiency — name the tool and attach the artifact — and check greyscale, which also covers print.
5. **Semantic collision.** A series coloured with the system's destructive or success hue is making a claim; flag it.
6. **Contrast.** Marks a reader must distinguish are UI components: **≥ 3:1** against the plot background under WCAG 2.2. Compute it. Gridlines and non-essential decoration are exempt.
7. **Dark mode.** A ramp tuned on a light plot can invert its perceptual order on a dark one — check both themes, or record that dark is unshipped.

### 5. Labeling

- Legend where direct labels would fit → finding (LOW, high value): direct labels remove the colour-matching round trip entirely.
- Legend order not matching visual series order → finding.
- A value only reachable by hover → finding on any surface that must work on touch or in print.
- A chart with no title, or a title naming the fields where the surface has a finding to state → flag as a deliberate choice to confirm, not an automatic fix.

## Output format

```
## chart-encoding-audit — <surface> — <YYYY-MM-DD>

Inventory: <n> charts across <n> files · <n> hand-rolled · data ramp: <path:line | ABSENT>
Colour-vision check: <tool> — artifact at <path> | NOT RUN (findings in §4 are provisional)

### Mark selection
| chart | <path:line> | question it answers | mark | prescribed | verdict |

### Encoding honesty (HIGH first)
| chart | <path:line> | check failed | what a reader concludes wrongly | fix |

### Data colour
| chart | <path:line> | source | family | ceiling | 2nd channel | contrast | verdict |

### Labeling
| chart | <path:line> | finding | fix |

### Missing infrastructure
<the data ramp, if absent — this is one fix that closes many findings>

Coverage: <n>/<n> charts audited · <n> skipped (<reason>)
```

`NOT RUN` is a real state and must be printed. A colour-vision section that quietly omits the check reads as a pass.

## Inputs

- The chart configs / specs, and the data transform feeding each one.
- The project's resolved token layer — specifically whether a data ramp exists separately from the UI accent ramp.
- `data-visualization.md` — every threshold this skill cites.
- The shipped themes, so dark-mode ramps are checked rather than assumed.

## Outputs

- The finding tables above, ranked HIGH → LOW.
- A single **missing-infrastructure** line when the data ramp is absent, which `design-system-architect` picks up — one fix that closes most of §4.
- Findings that turn out to be re-theming, routed to `ui-design-sweep` rather than reported here.

## Failure modes

- **Auditing the paint.** Reporting "chart does not match the new palette" — that is `normalize-surface`, and filing it here double-counts it.
- **Eyeballing colour safety.** The auditor asserting two hues are distinguishable is the same defect the audit is looking for.
- **Reporting a mark as wrong with no question.** Without the question, mark selection is taste, and the finding will be argued rather than fixed.
- **Missing hand-rolled SVG.** Library configs are greppable; a bespoke `<path d="...">` chart is not, and it is where the truncated axis usually lives.
- **Stopping at the options object.** `spanGaps` and null-coercion live in the data transform.
- **Fixing hexes at the call site** instead of reporting the absent ramp, which leaves every future chart with the same defect.

## Related

### Patterns
- [`data-visualization.md`](../../ai-patterns/data-visualization.md) — owns every rule this skill cites.
- [`axis-catalog.md`](../../ai-patterns/axis-catalog.md) § The companion floor — why a chart-encoding finding is not a 17th axis.
- [`dark-mode.md`](../../ai-patterns/dark-mode.md) — the second set of ramp values.

### Skills
- `design-token-audit` — whether values come from the system; this skill asks whether the drawing is true.
- `a11y-quick-check` — the surrounding page; owns the keyboard and screen-reader lane.
- `ui-design-sweep` § `normalize-surface` — composite-surface completeness, where "the dashboard is missing its period control" belongs.

### Agents
- `design-system-architect` — emits the sequential / diverging / categorical ramps as tokens.
- `ux-reviewer` — receives findings where the misread has a task cost.
