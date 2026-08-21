---
name: progressive-delivery
description: Audit the two pieces that decouple deploy from release — feature-flag lifecycle (no stale/orphaned/permanent flags, kill-switch on risky flows, flag-config parity across envs) and automated canary ANALYSIS wiring (a canary that promotes/aborts itself on SLO/error metrics, not a human eyeballing a dashboard).
---

# progressive-delivery

A risky change ships behind a flag with a kill-switch and an automated metric gate on its rollout. This skill audits those two mechanisms — nothing else.

## Premise

A flag that lives forever, a canary with no automated analysis/abort, or a risky flow with no kill-switch is forbidden. Every finding cites the real artifact: the flag key + defining file, the grep proving it's never referenced (dead) or hardcoded-on (stale), the AnalysisTemplate/Flagger metric block present or absent, the two env configs whose flag values diverge. "Flag looks stale" without the reference-count grep is not a finding.

**Boundary (this is not a deploy-strategy skill):**
- `@deployment-engineer` owns canary/blue-green as a **deploy STRATEGY** (which one, overhead, rollback command).
- `monitor-deploy` watches **a single deploy's** health window and triggers `/rollback-deploy`.
- **THIS** owns (a) flag lifecycle — stale/orphaned/permanent flags, kill-switch presence, cross-env parity, flag→config coupling; and (b) automated canary ANALYSIS wiring — the metric gate that promotes/aborts without a human.

## When to use

- Before merging a flag-gated change — confirm owner, removal date, kill-switch if risky.
- Quarterly flag-hygiene sweep — hunt dead (0 refs) + stale (permanently on, past window) flags.
- Reviewing a canary rollout — verify the metric gate is real, not a manual `promote` click.

## Scans for

1. **Dead flag** — in registry/config, 0 code references. 2. **Stale flag** — hardcoded on past the removal window. 3. **No removal date / owner**. 4. **Missing kill-switch** on a risky mutation (payments/deletes/migrations) whose only off-path is redeploy. 5. **Canary with no automated gate** — Rollout ramps traffic but has no `analysis`/`metrics` block. 6. **Cross-env flag drift** on boolean release gates. 7. **Flag→config coupling** — a flag that silently rewires config/secrets/routing.

## Detect

```bash
# Dead/stale (config-based): declared key vs reference count.
for key in $(yq '.flags | keys | .[]' flags.yaml 2>/dev/null); do
  echo "$(grep -rIl "$key" src/ api/ | wc -l) refs   $key"; done   # 0 = dead
# Canary gate present? (Argo Rollouts)
for f in $(grep -rl 'kind: Rollout' k8s/); do grep -q 'analysis:' "$f" || echo "NO-GATE: $f"; done
```
For LaunchDarkly/Unleash, pull the registry from the admin API, then run the same reference-count grep.

## Output

```
progressive-delivery audit — <service>
Feature-flag lifecycle (registry: LaunchDarkly, 23 flags):
  ✗ DEAD     checkout_v2_layout    — defined, 0 code references
  ✗ NO-KILL  async_refund_processor — payment mutation, disable = redeploy not flip
  ✓ OK       beta_dashboard        — owner @growth, removal 2026-09, kill-switch present
Automated canary analysis (Argo Rollouts):
  ✗ NO-GATE  payments-api Rollout  — setWeight steps, no AnalysisTemplate → manual promote only
```

## Gotchas

- **Kill-switch ≠ rollback** — monitor-deploy restores the previous revision; a kill-switch flips behavior without redeploy. Don't accept "we can roll back" as a kill-switch.
- **Permanent operational flags** (circuit-breakers, region toggles) are *meant* to live forever — distinguish release flags (temporary) from ops flags.
- A **readiness-only canary check** (pods READY) is not analysis — analysis compares error-rate/latency of the canary subset vs stable.
- Missing kill-switch on a payment/delete/migration flow = block. Canary on a high-blast-radius service with no auto-abort = block.

## Halt conditions

- Refuse to call a flag dead without the reference-count grep across the code tree — no grep, no verdict.
- Refuse to call a canary "no automated gate" without showing the Rollout/Canary spec lacks an `analysis`/`metrics` block.
- Halt if the flag registry is unresolvable (no LD/Unleash access, no config file) — audit what you can grep and say the registry side is unverified; don't guess flag state.
- Missing kill-switch on a payment/delete/migration flow = block. Canary on a high-blast-radius service with no auto-abort = block.
- Don't recommend deleting a flag whose removal you can't prove is safe (out-of-repo consumers) — surface it for owner confirmation instead.

## Related

- `@deployment-engineer` — owns canary/blue-green as a deploy STRATEGY (this owns the flag lifecycle + the canary's automated analysis wiring).
- `monitor-deploy` — watches a single deploy's window (this watches the flag's whole life + the canary's auto-promote/abort logic).
- observability pack `slo` skill — defines the SLO/error-budget metrics the AnalysisTemplate gates on.
