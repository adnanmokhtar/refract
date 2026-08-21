# Mobile pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

**Fallback convention in this pack: the source IS the fallback, except where an abridgement is
genuinely different.** Two entries point at `_examples/` — `mobile-architect` and
`mobile-principles` — because those two are the artifacts a project rewrites in its own voice, so a
shorter, project-shaped starting point is the right thing to receive. Every other entry points at
its own source file, and that is a decision, not drift. The reason is `phase-4.2-apply.md` step 2:
the fallback is copied VERBATIM and becomes the artifact the project runs on, and for mobile the
greenfield case is the COMMON case. These files carry dated store gates, cited platform limits and
cite-or-halt detectors; an abridgement of one is a shorter document that has quietly dropped a
safety signal, which is exactly what `validate-pack-consistency.sh` check 8b exists to catch. A
greenfield mobile project is better served by the whole artifact than by a summary of it. If you
later cut a real `_examples/` abridgement for one of these, re-point the `fallback:` in the same
change.

```yaml
- name: mobile-architect
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + § Modules
  sections: [persona, premise_two_poles, five_powers, halt_conditions, invariants, delegated_floor, modes, pre_flight, method, design_smells, output_format, failure_modes, sources]
  fallback: _examples/mobile-architect.md
  cite_evidence: strict

- name: mobile-principles
  kind: rule
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Conventions
  sections: [project_specific_first, platform_parity, accessibility_required, performance_budgets, secret_handling_in_mobile, store_compliance]
  mirror_existing: true
  fallback: _examples/mobile-principles.md

- name: render-discipline
  kind: rule
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + _extracted-idioms.md § State management
  sections: [hard_rule, the_8_detectors, per_framework_fingerprints, must, must_not, review_checklist, enforcement]
  mirror_existing: true
  fallback: rules/render-discipline.md
  cite_evidence: strict

- name: app-store-reviewer
  kind: agent
  triggers: { mobile_framework_detected: true }
  sections: [persona, premise_two_poles_three_buckets, halt_conditions, invariants, dated_machine_gates, audit_dimensions, output_format, hard_rules, failure_modes, sources]
  fallback: agents/app-store-reviewer.md
  # fallback is the source ON PURPOSE: every figure in it is cited to a fetched URL, so a
  # greenfield project is better served by the whole reviewer than by an abridgement of it.

- name: add-screen
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  fallback: commands/add-screen.md

- name: add-feature
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, hard_rules]
  fallback: commands/add-feature.md

- name: optimize-bundle
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [understand, organize, retrieve, generate, validate, output_format, hard_rules]
  fallback: commands/optimize-bundle.md

- name: refactor
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [pack_overlay_gates, dispatch, when_not]
  fallback: commands/refactor.md   # self-fallback, NOT `_examples/refactor.md`. That file is a
                                   # six-line usage anecdote — a second genre that shares the
                                   # `_examples/` directory (validate-pack-consistency.sh check 8b
                                   # names it as such and skips it) — and it carries none of the
                                   # three sections declared above. A no-signal install pointed at
                                   # it would receive two bullets about a Dart rename in place of
                                   # the navigation / lifecycle / bundle-size / platform-API gates
                                   # that are the entire reason this overlay exists. Frontend hit
                                   # the identical shape and deleted its anecdote outright
                                   # (frontend/CHANGELOG.md); mobile's is kept as documentation and
                                   # disowned as a fallback here instead. If it ever drifts again,
                                   # delete it rather than re-point this line.

- name: bundle-analyze
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [when_to_use, procedure, inputs, outputs, failure_modes]
  fallback: skills/bundle-analyze/SKILL.md

- name: native-bridge-audit
  kind: skill
  triggers: { mobile_framework_detected: true, native_bridge_present: true }
  sections: [when_to_use, procedure, inputs, outputs, hard_rules]
  fallback: skills/native-bridge-audit/SKILL.md

- name: platform-conventions-audit
  kind: skill
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-idioms.md § "Mobile platforms" + per-platform build configs (Info.plist, AndroidManifest.xml)
  sections: [purpose, when_to_use, inputs, outputs, the_10_detectors, procedure, hard_rules, failure_modes]
  fallback: skills/platform-conventions-audit/SKILL.md
  cite_evidence: strict

- name: device-harness
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, halt_conditions, when_to_use, inputs, procedure, what_this_harness_cannot_decide, output_format, outputs, hard_rules, failure_modes]
  fallback: skills/device-harness/SKILL.md

# The four patterns added at 1.7.0 declare `sources` as a REQUIRED section. Each quotes dated
# platform figures (Android's published background limits, Play's vitals thresholds, the store
# guidelines), and an AUTHOR-mode rewrite that drops the Sources block leaves those numbers standing
# with nothing behind them — which is the exact defect 1.7.0 repaired in five places. Emit it.
- name: app-lifecycle
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [state_machine, execution_windows_are_budgeted, choosing_the_mechanism, state_restoration, seam_with_offline_sync, detectors, closure_verbs, testing, anti_patterns, sources]
  fallback: ai-patterns/app-lifecycle.md

- name: offline-sync
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [problem, decision_tree, components, anti_patterns, testing]
  fallback: ai-patterns/offline-sync.md

- name: native-storage
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [decision_matrix, hard_rules, anti_patterns, encryption_decision_tree, testing]
  fallback: ai-patterns/native-storage.md

- name: deep-linking
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [why, three_layers, routing_pattern, defensive_patterns, testing, anti_patterns]
  fallback: ai-patterns/deep-linking.md

- name: permissions
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [four_state_model, pre_prompt_contract, re_check_on_every_use, degrade_dont_crash, declaration_surface, permissions_under_extra_scrutiny, detectors, closure_verbs, anti_patterns, sources]
  fallback: ai-patterns/permissions.md

- name: push-notifications
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [permission_ux, token_lifecycle, channels_categories, foreground_presentation, receipt_states, detectors]
  fallback: ai-patterns/push-notifications.md

- name: ota-updates
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [native_vs_js_boundary, staged_rollout, mandatory_vs_optional_gating, rollback_path, apply_ux, anti_patterns]
  fallback: ai-patterns/ota-updates.md

- name: mobile-api-contract
  kind: ai-pattern
  triggers: { mobile_framework_detected: true, api_client_present: true }
  sections: [what_breaking_means_for_a_client_you_cannot_redeploy, tolerant_client_parsing, version_negotiation, minimum_supported_version_gate, kill_switches, sunset_protocol, detectors, closure_verbs, anti_patterns, sources]
  fallback: ai-patterns/mobile-api-contract.md

- name: release-pipeline
  kind: ai-pattern
  triggers: { mobile_framework_detected: true }
  sections: [identity_separation, signing_material, dated_store_gates, beta_before_production, staged_rollout_and_halt_criterion, symbols, detectors, closure_verbs, anti_patterns, sources]
  fallback: ai-patterns/release-pipeline.md
```
