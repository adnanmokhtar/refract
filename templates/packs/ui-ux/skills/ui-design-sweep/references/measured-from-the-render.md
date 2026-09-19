# Measured from the render — two fingerprints the source cannot answer

Sidecar for `ui-design-sweep`. Both fingerprints below are **deepenings of existing verbs**, with
the same status as the framework-control and chart carve-outs in `SKILL.md`: the closed set stays
**19 verbs / 16 axes**. Neither is a 20th verb.

What they share is why they live here rather than in a lint rule: **both are properties of the
rendered box, not of the declaration.** A card's background can be inherited, a shadow can be
flattened away, a control's height can come from padding plus line-height plus a border on a
parent. Reading the source answers none of it. Every threshold below is sampled from a screenshot
or a computed style, and a run without a render harness reports them `NOT RUN`, never `pass`.

---

## A. Floating surface — a deepening of verb 12 `lift-contrast`

### The miss this closes

Every contrast check in the closed set measures something *against* a surface: text on a card, an
icon on a button. **Nothing measured the surface against what it sits on.** A `#ffffff` card on a
`#f8fafc` page is **1.04:1** — it passes every text check, every axe rule and every token audit
while its edges are invisible and the user cannot tell where the element begins. The same shape
recurs on panels, modals, popovers, sticky headers and table row-groups, and it is the most common
*"the sweep ran and the page still looks unfinished"* complaint.

### Fingerprint

A container whose boundary is resolvable by **none** of three cues:

- no border / outline reaching ≥3:1 against the adjacent fill, **AND**
- no elevation cue that survives the render (a shadow left unmeasurable at 100% zoom does not
  count), **AND**
- a surface-pair luminance ratio **< 1.2:1** against the fill immediately outside its edge.

### Calibrated, and the three cues COMBINE

All three must fail before a container is floating; grading one in isolation is a false positive.

Measured on a production RTL admin portal that had this defect and fixed it. Broken, its page→card
step was **1.123:1** with a hairline border and no lift — correctly flagged. Repaired, that step
reads **1.22:1** and its border only **1.252:1**, far below the 3:1 a border needs to carry the job
*alone* — yet the card is unmistakable, because a shadow and a real surface step carry it together.

A rounder 1.5 threshold, or a border bullet graded on its own, would condemn a surface its owners
had already fixed — which is how a sweep teaches its owner to stop reading its findings. The margin
between the two states is why the pair is measured from the render and never eyeballed.

### Procedure

1. **Measure from the RENDER, never the source.** Sample the container's fill and the fill
   immediately outside its edge. Source reading cannot resolve a computed background, an inherited
   surface token or a shadow the browser flattened away.
2. Compute the surface-pair ratio. All three cues absent → floating.
3. Fix with the project's **existing** elevation language, in this priority order: a defined border
   token → an existing shadow / elevation token → a surface-step token (`surface-1` / `surface-2` /
   `--bg-elevated`). **Never invent a new grey** — an undefined value here is `extract-token`'s job
   (verb 2), and inventing one per card is how a project ends up with nine card backgrounds.
4. Apply at the **role**, not the instance — every container of that role in one fix, so half the
   app does not end up bordered and the other half not (a per-instance fix here is the defect
   `consolidate-tokens` exists to prevent). Where the elevation language has no cue to reach for,
   that is a **missing** language, not a failed fix: hand the role to `extract-token` and say so,
   never improvise.

### The fix is the edge, not the ground

That portal's first attempt was to darken the PAGE until the white card separated by brute force.
It bought separation and cost the palette: the ground went from paper to saturated steel, every
rung between page and card turned to mud, and `--primary` fell to **4.35:1** on it — a contrast
test failing on a change made for contrast. Separation is the container's edge and its shadow; the
page is a rung, not a lever, which is why step 3 fixes at the container and never by re-weighting
what sits behind it.

### Verify

Re-render and re-sample the pair. The boundary must be resolvable at 100% zoom **and in dark mode**
— a shadow tuned on a light page routinely vanishes on a dark one, so a light-only verification is
not a verification. Re-check that no text contrast regressed when the surface moved.

**Citation**: WCAG 2.2 SC 1.4.11 (Non-text Contrast — *"boundaries of components needed to identify
them"*, the clause verb 12's button-border bullet reads too narrowly).

---

## B. Control-size disagreement — a deepening of verb 7 `tighten-rhythm`

### The miss this closes

Verb 7 polices spacing against the token grid, and `expand-tap-target` (verb 16) polices a
**minimum** — 24×24, or the stricter platform convention. Between them, nothing asks whether two
controls **standing in the same row agree with each other**. A 38px search input beside a 42px
button passes both: the gaps are on the grid, the target clears the floor, and the row still reads
as broken, because the eye reads the mismatched baselines long before it reads either control.

This is the single most-reported "it looks unfinished" defect that a token audit cannot see, and it
is invisible in source: a control's height is padding + line-height + border, assembled from three
separate declarations that are each individually correct.

### Control CLASS first — the rule that keeps this verb from doing damage

**Equal height is the wrong goal.** A switch is not a short text input, and forcing it to a
40px box to match the field beside it produces a stretched toggle with dead padding — a worse
row than the one the verb was sent to fix. Several control classes carry an **intrinsic** size
that belongs to the control, not to the row:

| Class | Size comes from | Agrees with |
|---|---|---|
| Text-entry — input · select · combobox · date field · textarea (single-row) | the control-height scale | every other text-entry control in the row |
| Action — button · segmented control · dropdown trigger | the control-height scale | every other action control in the row, **and** the text-entry step where the platform pairs them |
| Binary — switch · checkbox · radio | its own intrinsic size (a switch is a fixed track; a checkbox is a square) | other controls **of its own class only** |
| Icon-only — icon button · avatar · badge | a square footprint on its own step | other icon-only controls |

So the verb compares **within a class**, and across classes it checks only that the controls are
**optically aligned** — vertical centres agreeing — never that they are the same height. A switch
at 24px beside a 40px input is correct when their centres line up; it is a finding only when it
sits 6px high in the row for no reason.

### Fingerprint

Within one **rendered control row** — controls that are siblings in the layout and visually
adjacent (a toolbar, a filter bar, a form row, a search + button pair):

- **Same class**, two controls whose rendered border-box heights differ by **≥2px** without both
  snapping to a declared step of that class's size scale; **OR**
- **Same class and same role** (two buttons, two text inputs), heights differing **at all**; **OR**
- **Any two controls, any class**, whose **vertical centres** are offset by ≥2px — the
  cross-class check, and an alignment fault rather than a size fault, with a different repair.

**≥2px, not ≥1px**, because sub-pixel rounding and a 1px border legitimately differ by one device
pixel at some zoom levels, and a gate at 1px would flag a row nobody can see a fault in.

**Not a finding**: controls in *different* visual rows; a deliberately large primary CTA beside
small secondary actions where the size difference is a declared variant; an icon-only button whose
square footprint is its own step; **and any height difference that is purely cross-class** — see
the table above. A declared variant is a decision, and an intrinsic class size is a contract; this
verb only closes *accidental* disagreement inside one class.

### Procedure

1. **Group by row from the RENDER**, not from the markup tree — and a shared vertical position is
   NOT a row. **A true row requires BOTH**: vertical centres within ~6px **and horizontal adjacency**
   (the gap between one control's right edge and the next control's left edge under ~64px, or
   whatever the surface's own gutter is). Either test alone produces garbage.

   **MEASURED, and it was this document's own instruction being violated.** A first implementation
   of this fingerprint grouped by vertical band only, ran against four authenticated admin views,
   and returned eight findings — *every one of them false*. It had paired a sidebar item with a
   panel button that merely sat at the same height, on the opposite side of a 1440px screen. Adding
   the adjacency test took the same four views to **zero findings**, which was the truth: those
   screens are consistent.

   A vertical-band-only implementation does not find control-size defects. It finds page layouts,
   and reports them as defects. Flex and grid children that wrap also land in different visual rows
   while remaining siblings in source, so the markup tree is no substitute either.
2. Sample each control's computed border-box height and vertical centre.
3. **Partition the row by control class** (table above) before comparing anything. Resolve each
   class to its own scale if the project declares one (`--control-h-sm` / `-md` / `-lg`, or the
   component library's `size` prop). Snap the members of one class to one step — the step that
   class's dominant role already uses, not the largest in the row.
3b. Across classes, do **not** touch height. Check centres only, and repair on the row.
4. **No size scale declared?** That is a missing language, not a failed fix. Emit `extract-token`
   (verb 2) for the control-height scale and stop; inventing a height per row is how a project
   acquires eleven button heights.
5. Fix at the **wrapper**, not the instance. A height that disagrees at one call site almost always
   disagrees at every call site of the same pair, and a per-row patch is `consolidate-tokens`'
   anti-pattern wearing a different hat.
6. A centre-offset with agreeing heights is repaired with `align-items` / baseline alignment on the
   row, **never** by padding one control until it looks right — that fix silently changes the
   control's size step and breaks the next row it appears in.

### Verify

Re-render the row at every breakpoint in `§ Breakpoints`. Every control **of one class** reports the
same border-box height (or a declared variant step); controls of different classes keep their own
heights, and **all** vertical centres agree within 1px. A run that equalised a switch to an input's
height has failed this verb, not passed it. Re-run the
tap-target check — snapping DOWN to a smaller step can drop a control under the 24×24 floor, and
that trade is never acceptable: when the two conflict, the floor wins and the row snaps up.

**Citation**: Refactoring UI Ch. 4 (work in a spacing *and sizing* system — the sizing half is the
part verb 7 had left unimplemented); Material 3 *component size classes*; iOS HIG *Controls*.
