---
artifact: capability-7-conversational-wizard
purpose: Conversational wizard mode (B22). Real preview, never placeholder.
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🪄 7. Conversational wizard mode (B22)

**Problem solved**: flag-based UX is great for power users but bad for new team members, unfamiliar stacks, or cases where the prompt is sparse and the auto-detected mode is uncertain. Forcing one consolidated mega-question loses nuance.

**Design**:

#### 7.1 Activation

`--wizard` flag explicitly activates. ALSO auto-suggested when:
- CREATE mode + prompt < 50 chars + no README.
- ENHANCE mode + ≥3 `[CONFLICT]` or `[UNKNOWN]` flags after detection.
- User runs `/setup-project` with no prompt + no flag for the first time on a project.

In auto-suggest case: "Your prompt is sparse and the codebase is empty. Run `--wizard` for guided setup? [Y/n]"

#### 7.2 Wizard flow

The 8 Phase-2.y intent facets become 8 wizard steps. Plus 4 setup-meta steps:

| Step | Question | Default offered |
|---|---|---|
| 1 | Mode | Inferred (CREATE / ENHANCE / REFRESH) — confirm or override |
| 2 | Tracks to apply | Auto-detected list, lets user toggle |
| 3 | Business domain | Auto-detected, override if wrong |
| 4 | Mission / one-liner | From README / package.json description |
| 5 | Target users | From README — explicit ask if absent |
| 6 | Business model | From package.json keywords / README |
| 7 | Maturity stage | From README phase / `ai/status.md` |
| 8 | Success KPIs | Always ask |
| 9 | Constraints | Always ask |
| 10 | Anti-goals | Always ask |
| 11 | Tools | Auto-detected adapters, lets user toggle |
| 12 | Confirm + apply | Show full plan, mock outputs, ask Y/N |

Each step:
- Shows what the brain inferred.
- Shows the WHY (why this default makes sense).
- Lets user `[Enter]` to accept, type to override, `[?]` for "what does this affect," `[skip]` to leave as default.
- Shows a mini "this will result in:" preview after each answer.

#### 7.3 Mock output preview before final apply

Step 12 shows a preview of what 5 sample generated files will look like:

```
Step 12 — Confirm + apply

Sample generated files (full preview at .claude/_wizard-preview/):

  CLAUDE.md (first 30 lines)
  ───────────────────────────
  # CLAUDE.md — <project-name>
  ...

  .claude/agents/backend-architect.md (first 30 lines)
  ─────────────────────────────────────────────────────
  ...

  ai/conventions.md (first 30 lines)
  ───────────────────────────────────
  ...

Plan:
  - Mode: ENHANCE-extend (refresh existing setup with new tracks)
  - Tracks: backend, security, code-quality, learning, testing
  - Files to write: 47
  - Files to leave alone: 12
  - Files to backup (REFRESH-prep): 0 (not in REFRESH)

Apply now? [y/n/preview-more]
```

#### 7.4 Wizard adapts to language

`--wizard --lang=ar` → all 12 steps prompt in Arabic with English fallback. See B14 § 6.2 for shape.

#### 7.5 Wizard saves answers for re-use

After apply, wizard answers persist to `.claude/_wizard-answers.yaml`:

```yaml
mode: ENHANCE-extend
business_domain: ecommerce
tracks: [backend, security, code-quality, learning, testing]
mission: "Multi-tenant ecommerce SaaS for Egyptian SMB merchants"
target_users: "Egyptian + Saudi small/medium business merchants"
maturity: paying-customers
constraints: [latency-p99-200ms, multi-currency, RTL-required]
anti_goals: [enterprise-on-prem, white-label-only]
applied_at: 2026-04-25T14:30:00Z
```

Re-running wizard reads these as defaults. So second run is fast — only changed answers need attention.

#### 7.6 Hard rules

- **Wizard NEVER auto-applies.** User MUST type `y` at step 12.
- **Wizard preview MUST show real generated content, not placeholders.** A wizard that previews `<TODO>` is broken.
- **Wizard answers MUST roundtrip with `--refresh`.** A second `/setup-project --refresh --wizard` reads `_wizard-answers.yaml` and pre-fills defaults.

---

