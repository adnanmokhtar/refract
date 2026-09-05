---
name: audit-funnel-completion
description: Walk a user-facing flow as each role and report drop-off opportunities, missing instrumentation, error-path gaps, and the single highest-leverage fix to lift completion rate. Use when conversion is below target on one funnel (signup, checkout, onboarding, subscription), or as a pre-launch check on a new flow. Single-flow — `check-business-coverage` is the cross-flow, product-level counterpart.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: audit-funnel-completion

A focused funnel audit. Smaller than `@business-auditor` (full feature audit) — this is one flow, end-to-end, with one fix recommendation.

## Premise

Find real issues. Conversion percentages come from the actual analytics tool (Mixpanel / Amplitude / PostHog / GA4) for a stated 30d window — not estimates. Each step cites the event name that fires (or doesn't — that's a finding). Drop-off claims cite the step + the cohort size at each step. The "ONE biggest fix" is grounded in the captured drop-off numbers + a named, investigated cause (email-deliverability dashboard, form abandonment data, etc.).

## Halt conditions

- Refuse to report drop-off without the per-step funnel data captured.
- **Refuse to recommend a fix without naming the step it lifts AND the derivation of any number attached to it.** A lift figure is only reportable in one of three forms: (a) **observed** — this change already ran here or on a sibling flow, cite the experiment/date/cohort; (b) **bounded** — the arithmetic ceiling from the captured funnel ("step 5 loses 2,300 users/30d; recovering even a third of them is +770 activations"), showing the numbers it came from; (c) **unquantified** — name the step, the suspected cause, and the measurement that would settle it, and attach NO number. A point forecast with no derivation ("34% → 55%") is a fabricated number wearing a data costume, and it is the one output of this skill a stakeholder will quote in a planning meeting.
- Halt if the flow shipped < 14 days ago — premature signal.
- Don't propose 10 fixes; one highest-leverage fix only.
- Don't conflate funnel drop-off with churn — different metrics, different windows.

## When to use

- Conversion is below target on a specific funnel (signup, checkout, onboarding, subscription).
- Pre-launch sanity check on a new flow.
- After a copy / UX change to verify drop-off pattern shifted.

## Procedure

### 1. Identify the funnel

Pick ONE flow with a clear start + end:
- Signup: landing → form → email verify → first action → activated.
- Checkout: cart → address → payment → review → confirm → confirmation page.
- Onboarding: welcome → setup → personalize → first task → activated.

For each step, name the event that fires when user completes it. If no event fires, that's a gap.

### 2. Walk it as each role

Each user role hits different paths. For each role:
- Anonymous / unauthenticated.
- New user (first session).
- Returning user.
- Power user (skips intro, uses keyboard).
- Tenant admin.
- Sales / customer-success (if internal-only).

Note where each role drops off OR where the flow forces them through irrelevant steps.

### 3. Read the existing funnel data

If the project has an analytics tool (Mixpanel / Amplitude / PostHog / GA4):
- Pull last 30d funnel data for this flow.
- Per-step conversion rate.
- Drop-off heatmap (which step bleeds the most users).
- Time-to-step (slow step = friction).
- Error-rate per step (failure mode).

If no data: this is the first finding. Ship instrumentation before further analysis.

### 4. Walk the unhappy paths

For each step:
- What if the API call fails?
- What if the user enters wrong data?
- What if the user is in a denied state (card declined, rate-limited, permission missing)?
- What if the user backgrounds the app mid-step?
- What if the user closes browser mid-step?

Note: the unhappy paths are usually where conversion bleeds.

### 5. Surface the ONE biggest opportunity

Don't propose 10 changes. Find the single highest-leverage fix:
- The step with biggest drop-off + a clear cause.
- The error message most users hit + a clear rewrite.
- The form field most users abandon + a clear simplification.

## Output format

```
## Funnel audit — <flow-name>

### Funnel definition
| Step | Event | Definition |
|---|---|---|
| 1. View landing | landing.viewed | First page load |
| 2. Click CTA | landing.cta_clicked | Primary CTA tapped |
| 3. Form filled | signup.form_completed | All required fields entered |
| 4. Submit | signup.form_submitted | POST /api/signup |
| 5. Email verified | signup.email_verified | Verification link clicked |
| 6. Activated | signup.first_action | First meaningful action in app |

### Conversion (last 30d)
| Step | Users | % of previous | % of total |
|---|---|---|---|
| 1 | 10,000 | — | 100% |
| 2 | 4,200 | 42% | 42% |
| 3 | 3,800 | 90% | 38% |
| 4 | 3,500 | 92% | 35% |
| 5 | 1,200 | 34% | 12% |  ← BIGGEST DROP
| 6 | 1,150 | 96% | 11.5% |

### Drop-off analysis

**Step 5 (email verified)** — only 34% conversion from submit → verify. Investigated:

- Email delivery: 98% success rate (the project's email-provider delivery dashboard). Not a delivery problem.
- Email layout: verification link is in the second paragraph, below marketing copy. ← suspect.
- Verification deadline: 24 hours. After 24h, user must re-signup. ← high friction.
- Mobile: link opens browser, not app even when installed (no universal link). ← friction.
- Spam filtering: 12% of test addresses flagged "Verify your email" subject as promo. ← improvable.

### The ONE biggest fix

**Move verification link to top of email, simplify subject line, extend window to 7d.**

Opportunity (bounded, derived from the captured funnel above — NOT a forecast):
  Step 4 → 5 loses 2,300 users / 30d (3,500 submitted, 1,200 verified).
  Step 5 → 6 converts at 96%, so a user recovered at step 5 is ~0.96 activations.
  Ceiling if every lost user were recovered: +2,208 activations / 30d.
  That ceiling is the size of the prize, not a prediction — three causes were
  identified (link placement, 24h window, spam-flagged subject) and none has a
  measured effect size on THIS product.

How the real number gets known: ship the three changes behind one flag, hold
the 30d window and the cohort definition constant, and re-run this skill. The
delta between the two captured funnels IS the lift. Until then the honest line
is "unquantified — expected direction positive".

Effort: 1 day (email template + backend deadline change). Risk: low.

### Other gaps (not blocking; flagged for follow-up)

- Step 2: 42% from view → CTA click. CTA "Get Started" is generic; A/B test "Try Free for 7 Days" vs "See How It Works."
- Step 5 → 6: 96% — looks high, but actually only 11.5% of original visitors complete activation. The funnel is leaky higher up (step 1 → 2).

### Instrumentation gaps

- No event when user starts filling form (step 3 measures completion only). Add `signup.form_started`.
- No event for individual field abandonment (which field do they bail on?).
- No event for verification email re-send.

### Compliance + trust check

- [ ] Privacy policy linked at signup.
- [ ] Terms accepted explicitly (checkbox, not implicit).
- [ ] Email verification can be bypassed for testing? (No — good.)
- [ ] Account deletion path exists? (Yes, in settings — good.)

### Empty / error / disabled state check

- [ ] Form validation messages plain-language. (Mixed — "Email format invalid" is jargon.)
- [ ] Network failure during submit shows retry. (Missing — error is "Something went wrong.")
- [ ] Card declined message includes "try another card" CTA. (Yes — good.)
- [ ] Empty cart at checkout entry has CTA back to product list. (Yes.)
```

## Inputs

- The flow name (or screen path).
- Roles to audit (defaults to all).
- 30d analytics access if available.

## Outputs

- `ai/audits/funnel-<flow>-<date>.md`.
- Optionally: ADR proposed if the fix changes architecture (e.g., switch from email verification to SMS).

## Failure modes

- Audited the happy path; ignored unhappy paths (which is where conversion bleeds).
- Used 30d data when the flow shipped 7d ago — premature signal.
- Confused funnel drop-off with churn (different metrics).
- Proposed 10 fixes; user does none.
- **Attached a point forecast to a fix ("34% → 55%") with no experiment behind it.** It reads as measured, gets quoted in planning as measured, and nothing in the report tells the reader it was invented. Report the bounded ceiling with its arithmetic, or report no number.

## Related

- `@business-auditor` — full feature audit; this skill is one funnel within that.
- `@ux-reviewer` — UX-specific copy + content review.
- `business-completeness.md` rule — what "done" looks like in business terms.
