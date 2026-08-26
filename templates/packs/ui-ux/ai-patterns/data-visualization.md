---
name: data-visualization
description: "Pattern: Data visualization — the chart-encoding floor: mark selection from the data question, the three data-colour scale families, and the encoding-honesty rules a re-themed chart still fails"
kind: ai-pattern
pack: ui-ux
---

# Pattern: Data visualization (the chart-encoding floor)

> **Hard rule** — A chart is chosen by the QUESTION its data answers (§ The chart-selection map), not by what the library renders prettily. Data colour comes from a **scale family** (sequential / diverging / categorical), never from the UI accent ramp. Bars start at zero. Every chart carries its units. A chart that encodes a magnitude by area, hides a truncated axis, or separates two series by red-vs-green alone is a **finding**, not a style preference.

**The failure this prevents:** the pack already makes a chart *match the design language* — `/redesign` Phase 3 and `ui-design-sweep § normalize-surface` both catch a library-default chart dropped into an art-directed page. Nothing checked whether the chart was the RIGHT chart, honestly encoded, and readable by the ~8% of men with a red-green colour deficiency. A perfectly re-themed pie chart with nine slices, a truncated y-axis and a Reds-vs-Greens legend passes every existing gate in this pack and still misleads the person reading it. Re-theming is the paint; this file is the drawing.

**When to apply**
- Any surface that renders a chart, sparkline, gauge, heatmap, or metric tile with a trend.
- `/redesign` and `/art-direct` when a direction re-themes an existing dashboard — re-theming is the moment a wrong mark gets locked in behind a beautiful skin.
- `design-system-architect` when the token layer must carry data colour (it is a SEPARATE ramp; see § Data colour is not UI colour).

**When NOT to apply**
- A number rendered as text. A single value is a metric tile, and its floor is the composite-surface completeness floor, not this one.
- Decorative illustration that resembles a chart but encodes nothing — that is `creative-director`'s plane, and it must be labelled decorative so nobody reads a value off it.

**Halt conditions / mandatory cites**
- A chart type chosen with no stated data QUESTION — halt. Name the question first (§ The chart-selection map); the mark follows from it.
- A bar / column / area chart whose value axis does not include zero — halt. Length and area encode magnitude; truncating the baseline multiplies the apparent difference by an arbitrary factor.
- A categorical series set separated by colour alone, with no second channel (shape, pattern, direct label, position) — halt.
- Data colour taken from the UI accent ramp or from brand tokens — halt. Cite the data ramp as `<path:line>`; if none exists, that is the finding.
- A dual-axis chart with two independent scales — halt unless the two series share a unit. Two arbitrary scales manufacture a correlation the data does not contain.
- A contrast or colour-safety claim asserted without a computed check — halt. Same rule as everywhere else in this pack: computed, never a swatch claim.

## The chart-selection map

The question is the input. Pick the row, then the mark.

| The question the reader is asking | Mark | Use instead when | Never |
|---|---|---|---|
| **How did this change over time?** | Line | Few points and the individual values matter → column | Pie; a line over a categorical axis (time order is what makes a line legible) |
| **How do these categories compare?** | Bar, sorted by value | Category labels are long → horizontal bar | Radar; a bar chart in original alphabetical order when rank is the question |
| **What is the part-of-whole split?** | Stacked bar, or bar of the parts | ≤ 4 slices AND precision does not matter → pie is acceptable | Pie past ~5 slices; donut with a legend and no direct labels; nested pies |
| **How is this distributed?** | Histogram, or box plot across groups | Sample is small enough to show every point → strip / beeswarm | Bar chart of means with no spread — it hides the shape entirely |
| **Do these two measures relate?** | Scatter | A third dimension matters → size or colour (never both) | Dual-axis line (see the halt above) |
| **Where does this sit against a target?** | Bullet, or bar with a target rule | One value, glanceable → metric tile with a delta | Gauge / speedometer — huge area for one number, and the arc distorts it |
| **Where are the hot spots across two dimensions?** | Heatmap with a sequential scale | Cells are few → labelled table | Rainbow colour scale (see § Data colour is not UI colour) |
| **How does the total flow or drop between stages?** | Funnel, or a stepped bar | Stages branch → Sankey | A funnel drawn as a 3D cone; a funnel whose widths are not proportional |
| **What is the trend, in a table cell or beside a number?** | Sparkline, with min/max/last marked | The exact values matter → the table column itself | Sparkline with an axis; sparkline as the only representation of a critical value |

**Two questions is two charts.** A chart answering "how did this change AND how do the categories compare" answers neither well. Split it, or pick the question the surface's job actually asks.

## Data colour is not UI colour

This is the single most common cause of a chart that is beautiful and unreadable. The UI accent ramp exists to make ONE thing stand out. A data ramp exists to make N things **comparable**. They are different problems and the tokens must be separate.

| Family | Encodes | Shape | Rule |
|---|---|---|---|
| **Sequential** | Magnitude, one direction (low → high) | One hue, monotonically increasing lightness | Lightness must be perceptually even — a ramp built by mixing with white is not. Never a rainbow: hue carries no order, so readers cannot rank the steps. |
| **Diverging** | Distance from a **meaningful** midpoint (zero, target, baseline) | Two hues meeting at a neutral centre | The midpoint must be real. A diverging scale centred on the data mean invents a "normal" nobody agreed on. |
| **Categorical** | Identity, no order | Distinct hues, similar lightness | **Ceiling ~8.** Past that, adjacent hues stop being distinguishable — group the tail into "Other" or change the mark. Never let a categorical ramp imply ranking by getting darker. |

**Colour is never the only channel.** Roughly 8% of men and 0.5% of women have a colour-vision deficiency, deuteranomaly (red-green) being the most common — so red-vs-green as the sole difference between two series is unreadable for a large minority and unreadable for everyone in greyscale print. Add a second channel: direct labels, dash pattern, shape, or position.

**Semantic colour still means what it means.** If the design system says red is destructive and green is positive, a chart that colours "Region A" red is making a claim it did not intend. Reserve the semantic hues for semantic use, and take series colours from the categorical ramp.

**Contrast applies to charts too.** A data mark against its plot background is a UI component under WCAG 2.2 — **≥ 3:1**. Gridlines, axis rules and non-essential decoration are exempt; the marks a reader must distinguish are not. Compute it; do not eyeball a swatch.

## Encoding honesty

The rules that separate a chart from a persuasion device. Each is a finding when broken, with the fix beside it.

| Rule | Why | The fix |
|---|---|---|
| **Bars start at zero** | Bar length IS the value. A truncated baseline scales the visual difference arbitrarily. | Extend the axis to zero, or switch to a mark that encodes position rather than length (line, dot plot). |
| **Lines need not start at zero — but must say so** | For a trend, resolution matters more than absolute magnitude. | Keep the zoomed axis; label the axis range explicitly so the zoom is visible. |
| **Area encodes area, not radius** | Doubling a circle's radius quadruples its area; readers read area. | Scale by area, or use a mark that encodes by length. |
| **One scale per axis** | Two independent y-scales let the author choose the correlation. | Two charts sharing an x-axis (small multiples), or index both series to a common baseline. |
| **Aspect ratio is an argument** | The same series looks flat or volatile depending on the plot's shape. | Pick a ratio where the meaningful slopes read near 45°, and keep it stable across comparable charts. |
| **Every chart carries its units** | "Revenue: 4.2" is unusable. | Units in the axis title or the value labels — and state the currency, the period, and whether it is cumulative. |
| **Sorted, unless the axis has an inherent order** | Alphabetical bars hide the ranking that is usually the point. | Sort by value descending. Time, and ordinal scales such as sizes, keep their own order. |
| **Missing data is drawn as missing** | Interpolating across a gap invents readings. | Break the line, or mark the gap; never let a straight segment imply data that was not collected. |

## Labeling

- **Direct labels beat a legend.** A legend makes the reader look away and match colours from memory; a label at the end of the line does not. Use a legend when direct labels would collide, and then order it to match the visual order of the series, not alphabetically.
- **Label what matters, not everything.** On a sparkline: first, last, min, max. On a bar chart people will read values off: every bar. On a dense scatter: none, and let the tooltip carry it.
- **A tooltip is not a label.** Anything a touch user or a printed page must convey is on the chart itself. Tooltips add precision; they never carry the primary reading.
- **The title states the finding, not the fields.** "Revenue fell 12% after the June price change" beats "Revenue by month". If the surface cannot claim a finding, the neutral title is correct — but the choice should be deliberate.

## The chart-encoding floor (a companion floor — NOT a 17th axis)

This file is a **third floor**, parallel to the two in [`axis-catalog.md`](axis-catalog.md), and it does not change the `16 axes / 19 verbs` counts:

1. The **per-element usability floor** — the 16 axes.
2. The **per-surface completeness floor** — does a dashboard carry its table-stakes affordances (`ui-design-sweep § normalize-surface`).
3. **This one — the per-chart encoding floor.** Is the mark right, the scale honest, the colour readable.

A chart re-themed to the design language satisfies the `tokens` axis and can still fail all three of this file's halts. They are different oracles: `tokens` asks *does this value come from the system*, this floor asks *does this drawing tell the truth*. File a chart-encoding finding under this floor by name; never widen the closed axis set to fit it.

## Common mistakes

- **Re-theming a wrong chart.** The most expensive one: a direction lands, the pie is recoloured to the new palette, and nine-slice pie is now permanent because it looks intentional.
- **Reaching for the accent ramp** because it is what the token file offers. That is the finding, not the workaround — the data ramp is missing and should be added.
- **A rainbow sequential scale.** Hue is not ordered. Readers cannot say which of two rainbow steps is larger without the legend, every time.
- **A diverging scale with an invented midpoint** — centred on the mean, so "below average" is drawn in alarm red.
- **Twelve categorical series**, six of which are visually identical, with a legend the reader must traverse for each one.
- **Dual axes to make two series "line up."** If they share no unit, the alignment is an authoring choice presented as a result.
- **Gauges for a single number.** Maximum area, minimum information, and the arc distorts the value's position.
- **A chart with no units, shipped because the team knows what the number means.** The next reader does not.

## Cross-references

- [`axis-catalog.md`](axis-catalog.md) § The companion floor — the architecture this floor parallels; read it before filing a chart finding, so it lands on the right oracle.
- `chart-encoding-audit` (skill) — the runnable audit for this floor.
- [`dark-mode.md`](dark-mode.md) — data ramps need a second set of values in dark; a sequential scale tuned for a white plot inverts its perceptual order on a dark one.
- `design-system-architect` (agent) — owns emitting the sequential / diverging / categorical ramps as tokens, separate from the UI accent ramp.
- `ui-design-sweep` § `normalize-surface` — the composite-surface completeness floor, which is where "the dashboard is missing its period control" belongs.
