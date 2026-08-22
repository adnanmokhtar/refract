# Mobile pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

**Fallback convention in this pack: the source IS the fallback, except where an abridgement is
genuinely different.** Three entries point at `_examples/` — `mobile-architect`,
`offline-sync-auditor` and `device-performance-auditor` — because those are the artifacts a project
rewrites in its own voice, against its own entities, screens and device list, so a shorter,
project-shaped starting point is the right thing to receive. Every other entry points at its own
source file, and that is a decision, not drift. The test is whether the abridgement would differ:
where it would not, a second copy is only a second place for a correction to fail to land.

The two auditor abridgements are cut against the copied-verbatim rule stated further down this
paragraph rather than around it, and the claim is countable file against file: each keeps **every** halt condition
(11 for `offline-sync-auditor`, 14 for `device-performance-auditor`), **every** invariant (9 each),
both named failure poles, **every row** of the delegated-floor table (9 and 10 rows), and every
platform figure with the URL that publishes it — including `device-performance-auditor`'s § Sources
and its "Deliberately absent" list, which is the safety signal in that file. What is shortened is
the worked prose around the diagnosis tables, the explanatory tail of each § Failure modes bullet,
and the § Related pointer list — the part a project replaces with its own screens and device
classes on first contact. Exactly one § Failure modes bullet per file is dropped outright, and only
because its substance is stated elsewhere in the same abridgement: `reachability-as-truth` survives
as a § Failure catalogue row, and "a metric with no budget is a finding, not a blank" survives as an
output-section heading. Nothing dropped is a number, a citation, a halt, or a boundary. The reason is `phase-4.2-apply.md`
§ 4.2-AUTHOR step 2: it resolves each topic's `fallback:` field and copies THAT file VERBATIM, so
whatever this column names becomes the artifact the project runs on — and for mobile the greenfield
case is the COMMON case. These files carry dated store gates, cited platform limits and
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
  sections: [project_specific_first, platform_parity, accessibility_required, performance_budgets, secret_handling_in_mobile, store_compliance, where_the_depth_lives]
  mirror_existing: true
  fallback: rules/mobile-principles.md
  # fallback is the source ON PURPOSE. The `_examples/` abridgement was deleted at 1.9.0: it stood
  # at 96% of the source (71 vs 74 lines, 4 trivial elisions) and the `_examples/` premise below —
  # "the artifacts a project rewrites in its own voice, against its own entities" — was fiction for
  # a near-verbatim copy. What it actually created was a second lockstep-update site for 8 source
  # URLs and a per-platform permission-denial model, and the copy was still asserting the iOS
  # one-shot model for Android after the source was corrected. `render-discipline` has always
  # self-fallbacked for the same reason.

- name: render-discipline
  kind: rule
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + _extracted-idioms.md § State management
  sections: [hard_rule, the_8_detectors, where_the_fingerprint_lives, must, must_not, enforcement]
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

- name: offline-sync-auditor
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-idioms.md § State management + § Storage + _extracted-codebase.md § Modules
  sections: [persona, premise_two_poles, halt_conditions, invariants, delegated_floor, pre_flight, write_path_trace, failure_catalogue, output_format, hard_rules, failure_modes, sources]
  fallback: _examples/offline-sync-auditor.md
  cite_evidence: strict

- name: device-performance-auditor
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + ai/runtime/perf-budgets.md (or the project's sibling)
  sections: [persona, premise_two_poles_three_kinds_of_number, four_costs, halt_conditions, invariants, delegated_floor, pre_flight, method, diagnosis_table, output_format, hard_rules, failure_modes, sources]
  fallback: _examples/device-performance-auditor.md
  cite_evidence: strict
  # `sources` is REQUIRED, for the same reason the 1.7.0 patterns declare it: this agent is the one
  # artifact in the pack that quotes Android vitals figures for startup, frames, memory and wake
  # locks. An AUTHOR-mode rewrite that drops § Sources leaves six numbers standing with nothing
  # behind them, and drops the "Deliberately absent" list that is what stops the next pass from
  # inventing an Apple launch target to balance the table.

- name: add-screen
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [pack_overlay, scope, screen_scoped_mirror_axes, tier, sensitive_entity_gate, phase_2_screen_design, phase_3_reads, deep_link_registration, phase_6_validation, output_format]
  fallback: commands/add-screen.md
  # `/add-screen` became a scope-narrowing OVERLAY on this pack's `/add-feature` at 1.9.0 — the
  # same shape `commands/refactor.md` already uses. It previously restated ~60% of `/add-feature`
  # verbatim while missing every safety mechanism that command has: the reviewer precondition
  # table, `@security-auditor`, `@app-store-reviewer`, the BLOCKER halt rule and the
  # agent-not-installed fallback. A Heavy tier defined by "biometric / Keychain / secrets touch"
  # dispatched no security review at all. The sections above are what a SCREEN adds on top; the
  # seven phases are `/add-feature`'s and are not re-emitted here.

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
  fallback: commands/refactor.md   # self-fallback. `_examples/refactor.md` was deleted at 1.9.0:
                                   # it was a six-line usage anecdote about a Dart rename carrying
                                   # none of the three sections declared above, so a no-signal
                                   # install pointed at it would have received that in place of the
                                   # navigation / lifecycle / bundle-size / platform-API gates that
                                   # are the whole reason this overlay exists. Its own disownment
                                   # comment cost more than the file. Frontend deleted its
                                   # equivalent outright; mobile now matches.

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
