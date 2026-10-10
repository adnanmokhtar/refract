# Mobile pack — topic specs (AUTHOR mode)

Schema: see `~/.claude/templates/packs/backend/_topics.md`.

**Fallback convention in this pack: the source IS the fallback.** Every entry points at its own
source file, and that is a decision, not drift. Until 2.0.0 three agents — `mobile-architect`,
`offline-sync-auditor` and `device-performance-auditor` — pointed at `_examples/` abridgements. They
were deleted at 2.0.0: the batch-3 rewrite gave each agent a `## Contract` block, its detector skill
(`offline-sync-scan`, `mobile-perf-scan`) and the Bash and Skill tools to run it, and the
abridgements still routed frame causes to `render-discipline` alone, carried no Contract and held a
tool list that could not run a device — a shorter document that had quietly dropped the
done-condition (`validate-pack-consistency.sh` CLOSING-SIGNAL-LOSS). The reason the source wins is
`phase-4.2-apply.md` § 4.2-AUTHOR step 2: it resolves each topic's `fallback:` field and copies THAT
file VERBATIM, so whatever this column names becomes the artifact the project runs on — and for
mobile the greenfield case is the COMMON case. These files carry dated store gates, cited platform
limits and cite-or-halt detectors; a greenfield mobile project is better served by the whole
artifact than by a summary of it. If you later cut a real `_examples/` abridgement, re-point the
`fallback:` in the same change and keep the Contract block in it.

```yaml
- name: mobile-architect
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + § Modules
  sections: [persona, contract, premise_two_poles, five_powers, halt_conditions, invariants, delegated_floor, modes, pre_flight, method, design_smells, output_format, failure_modes, sources]
  fallback: agents/mobile-architect.md
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
  sections: [persona, contract, premise_two_poles_three_buckets, halt_conditions, invariants, dated_machine_gates, audit_dimensions, output_format, hard_rules, failure_modes, sources]
  fallback: agents/app-store-reviewer.md
  # fallback is the source ON PURPOSE: every figure in it is cited to a fetched URL, so a
  # greenfield project is better served by the whole reviewer than by an abridgement of it.

- name: offline-sync-auditor
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-idioms.md § State management + § Storage + _extracted-codebase.md § Modules
  sections: [persona, contract, premise_two_poles, halt_conditions, invariants, delegated_floor, pre_flight, write_path_trace, failure_catalogue, output_format, hard_rules, failure_modes, sources]
  fallback: agents/offline-sync-auditor.md
  cite_evidence: strict

- name: device-performance-auditor
  kind: agent
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (mobile framework) + ai/runtime/perf-budgets.md (or the project's sibling)
  sections: [persona, contract, premise_two_poles_three_kinds_of_number, four_costs, halt_conditions, invariants, delegated_floor, pre_flight, method, diagnosis_table, output_format, hard_rules, failure_modes, sources]
  fallback: agents/device-performance-auditor.md
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
  # `/add-screen` is a scope-narrowing OVERLAY on the delivery pack's `lane-mobile` skill (since
  # 1.10.0; before that it overlaid this pack's own `/add-feature`, whose procedure was cut into
  # `lane-mobile`). It once restated ~60% of that procedure verbatim while missing every safety
  # mechanism: the reviewer lens set, `@security-auditor`, `@app-store-reviewer`, the BLOCKER halt
  # and the `UNREVIEWED(<axis>)` contract. The sections above are what a SCREEN adds on top; the
  # phases are `lane-mobile`'s and are not re-emitted here.

- name: add-feature
  kind: command
  triggers: { mobile_framework_detected: true }
  sections: [lane_preset_handoff, where_the_procedure_went, missing_orchestrator]   # thin preset of the delivery /add-feature (Phase 4, decision O6); the procedure is delivery/skills/lane-mobile
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

- name: mobile-audit
  kind: command
  triggers: { mobile_framework_detected: true }
  extracts_from: _extracted-codebase.md § Stack (RN / Expo / Flutter / native AND the resolved versions from the lockfile and build files — targetSdk, deployment target, compiler modes gate the rules) + the entry points (navigators, link filters, push handlers, jobs) + CNG + the release artifact + the device harness
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: commands/mobile-audit.md   # the source IS the fallback, as for db-audit and frontend-audit; the fixed class ledger, the two severity axes and the device lane are the contract

- name: mobile-fix
  kind: command
  triggers: { mobile_framework_detected: true }
  fallback: commands/mobile-fix.md   # the source IS the fallback, as for db-fix and frontend-fix; a skeleton would drop the kill recipe, the no-device-no-closure rule, the suppression grep and the STOP lines

- name: app-size-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, halt_conditions, boundaries, measure_toolchain_table, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_7, proof, output, false_positives, when_to_run, related]
  fallback: skills/app-size-scan/SKILL.md
  cite_evidence: strict
  # renamed from bundle-analyze (1.x): the frontend pack ships a skill of that name, so the mobile one
  # installed as bundle-analyze.mobile and bare-name dispatchers reached the wrong skill. Fallback is the
  # source ON PURPOSE: /optimize-bundle reads its toolchain table, and the measured-delta halt is the contract.

- name: native-bridge-audit
  kind: skill
  triggers: { mobile_framework_detected: true, native_bridge_present: true }
  sections: [premise, the_rule, boundaries, inputs_and_outputs, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_7, proof, output, false_positives, when_to_run, halt_conditions, hard_rules, related]
  fallback: skills/native-bridge-audit/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: the RN version table (New Architecture only from 0.82,
  # InteractionManager removed in 0.87) decides whether a hit is a finding, and the both-sides
  # set-difference is the artifact.

- name: platform-conventions-audit
  kind: skill
  triggers: { mobile_framework_detected: true }
  extracts_from: per-platform build configs (Gradle targetSdk, AndroidManifest.xml, res/values themes, Info.plist, app.json) — no _extracted-* section is required; the conventions are inferred from the code
  sections: [premise, the_rule, boundaries, inputs, outputs, lanes, pre_flight_greps, the_3000_hit_path, the_detectors, proof, output, false_positives, when_to_run, halt_conditions, hard_rules, related]
  fallback: skills/platform-conventions-audit/SKILL.md
  cite_evidence: strict
  # 1.x hard-required _extracted-idioms.md § Mobile platforms, which nothing produces, so it halted on
  # every install; the rewrite derives platforms from markers and conventions from the code.

- name: device-harness
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, halt_conditions, when_to_use, inputs, procedure, what_this_harness_cannot_decide, output_format, outputs, hard_rules, failure_modes]
  fallback: skills/device-harness/SKILL.md

- name: mobile-lifecycle-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, the_rule, boundaries, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_7, proof, output, false_positives, when_to_run, halt_conditions, related]
  fallback: skills/mobile-lifecycle-scan/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: the pre-flight script, its version gates and the
  # measured hit counts are the artifact; an abridgement would drop the halt conditions and
  # the "no device means SKIPPED, never PASS" rule that keeps a host-only run honest.

- name: mobile-a11y-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, the_rule, boundaries, lanes, lint_lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_8, proof, output, false_positives, when_to_run, halt_conditions, related]
  fallback: skills/mobile-a11y-scan/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: the lint lane, the pre-flight script with its measured hit
  # counts and the checker versions verified on 2026-10-05 are the artifact; an abridgement would
  # drop the "a checker run, never self-reported labels" proof rule and the SKIPPED-never-PASS halt.

- name: mobile-perf-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, the_rule, boundaries, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_7, proof, output, false_positives, when_to_run, halt_conditions, related]
  fallback: skills/mobile-perf-scan/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: the version gates (React Compiler, strong skipping, FlashList
  # v2, InteractionManager) decide whether a hit is a defect or a decoy, and the release-build,
  # repeated-run measurement rule is what keeps a debug figure out of a finding.

- name: offline-sync-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, the_rule, boundaries, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_6, proof, output, false_positives, when_to_run, halt_conditions, related]
  fallback: skills/offline-sync-scan/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: the pre-flight script and its measured hit counts are the
  # artifact, and the library facts it keys on (TanStack persistence, zustand migrate, axios-retry
  # defaults) are dated; an abridgement would drop the "durable needs a real kill" halt.

- name: store-compliance-scan
  kind: skill
  triggers: { mobile_framework_detected: true }
  sections: [premise, dated_store_gates, the_rule, boundaries, lanes, pre_flight_greps, the_3000_hit_path, scans_for, detectors_1_to_9, proof, output, false_positives, when_to_run, halt_conditions, related]
  fallback: skills/store-compliance-scan/SKILL.md
  cite_evidence: strict
  # fallback is the source ON PURPOSE: it holds the pack's only copy of the dated store-gate table
  # (D-34), each row with its primary page and read date; an abridgement would be a second, staler
  # copy of exactly the facts that move every quarter.

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
