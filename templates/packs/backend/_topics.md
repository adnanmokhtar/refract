# Backend pack — topic specs (AUTHOR mode)

This file is the **nucleus** for the backend track. When `/setup-project` Phase 4.2 runs in AUTHOR mode (extraction signal exists from Phase 2), generators read these topic specs + the project's `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md` to author content in the project's own voice.

When extraction has no signal for a topic (true greenfield, or base class with <3 extenders), generator falls back to copying the corresponding template in `_examples/` (literal copy + path injection — same as old COPY mode).

> **Class names in this file are roles, not literals.** Triggers and `extracts_from:` pointers refer to roles like `<repository-base>`, `<service-base>`, `<controller-base>`, `<mapper-base>`. Phase 4.2-AUTHOR substitutes each role with the actual class name found in `.claude/_extracted-codebase.md` for THIS project. Hardcoding a specific V1 / NestJS / Django / Rails / etc. class name in this file would silently miss in projects where that exact class doesn't exist — that's the leak failure mode.

---

## Topic schema

Each topic declares:
- `name` — slug used as filename (`ai/patterns/<name>.md` or `.claude/agents/<name>.md` or `.claude/rules/<name>.md`).
- `kind` — one of `pattern` / `agent` / `rule` / `skill` / `command` / `convention`.
- `triggers` — what evidence in `.claude/_extracted-codebase.md` activates this topic. If no triggers match, the topic is SKIPPED for this project. Use ROLE-shaped patterns (`Repository`, `Service`, `Controller`, `Mapper`) — never hardcode a project-specific class name.
- `extracts_from` — which idiom block in `.claude/_extracted-idioms.md` (or section in `_extracted-codebase.md`) supplies the content. Use ROLE references (`<role:repository-base>`) — Phase 4.2-AUTHOR resolves them to the actual class name from extraction.
- `sections` — required H2 sections in the output, in order. Generator must emit each (omit only when extraction yielded zero signal for that section).
- `mirror_existing` — `true` (default) → if `ai/patterns/<name>.md` already exists, mirror its section order + voice (extractor Step 5.5).
- `fallback` — path to `_examples/<name>.md` for COPY-mode fallback when extraction is empty.
- `cite_evidence` — `strict` (default; every claim cites file:line) or `lenient` (allow generic prose for sections genuinely not extractable).

---

## Topics

```yaml
# ============ PATTERNS (ai/patterns/<name>.md) ============

- name: data-access
  kind: pattern
  triggers:
    role_detected: repository-base   # Phase 2.5 marks any base class with ≥3 extenders that plays the repository role (data access, persistence, query encapsulation) regardless of class name
    OR_grep_evidence: "(class|interface) +\\w*(Repository|Repo|DAO) +(extends|implements)"   # generic shapes; project-specific class names come from extraction, not this regex
  extracts_from: _extracted-idioms.md § <role:repository-base>   # whichever class in this codebase plays that role
  sections: [overview, type_parameters, constructor_surface, class_configuration, public_protocol, automatic_behaviors, escape_hatches, examples_from_codebase, pitfalls, when_not_to_use, related]
  mirror_existing: true
  fallback: stub-from-sections   # no `_examples/data-access.md` ships; AUTHOR-mode is required (extraction must succeed) — falls back to a sectioned stub if it doesn't, per phase-4.2-apply.md § 4.2-AUTHOR step 2
  cite_evidence: strict

- name: base-service
  kind: pattern
  triggers:
    role_detected: service-base   # base class with ≥3 extenders that plays the service / use-case / interactor role
    OR_grep_evidence: "(class|interface) +\\w*(Service|UseCase|Interactor|ApplicationService|Handler) +(extends|implements)"
  extracts_from: _extracted-idioms.md § <role:service-base>
  sections: [overview, key_methods, configuration_properties, constructor, create_flow, update_flow, delete_flow, override_hooks, collaborators, pitfalls, when_not_to_use, related]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/base-service.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md
  cite_evidence: strict

- name: controller
  kind: pattern
  triggers:
    role_detected: controller-base   # base class / decorator pattern playing the HTTP entry-point role; OR none if the project uses functional handlers
    OR_grep_evidence: "(class|interface) +\\w*(Controller|RestController|Resource|View|Endpoint) +(extends|implements)|@(Controller|RestController|RequestMapping|router\\.)"
    OR_codebase_section: "API surface"
  extracts_from: _extracted-codebase.md § API surface + _extracted-idioms.md § <role:controller-base> (if any)
  sections: [overview, structure, response_envelope, error_mapping, auth_decorators, request_validation, examples, pitfalls, related]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/controller.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md
  cite_evidence: strict

- name: mapper
  kind: pattern
  triggers:
    role_detected: mapper-base   # only fires if the project actually uses an explicit mapper / serializer / transformer base; OMITTED entirely if mapping is inline or framework-native
    OR_grep_evidence: "(class|interface) +\\w*(Mapper|Transformer|Serializer|Adapter) +(extends|implements)"
  extracts_from: _extracted-idioms.md § <role:mapper-base> + _extracted-codebase.md § Modules (sample mapper files, if any)
  sections: [overview, type_parameters, methods, when_to_inject_dependencies, examples, pitfalls, related]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/mapper.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: dto-validation
  kind: pattern
  triggers:
    grep_evidence: "@IsString\\(\\)|@IsNotEmpty\\(\\)|class-validator|pydantic|marshmallow"
  extracts_from: _extracted-codebase.md § Conventions + sample DTOs
  sections: [overview, decorator_conventions, nested_validation, translation_dtos, error_messages, examples, pitfalls]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/dto-validation.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: error-handling
  kind: pattern
  triggers:
    grep_evidence: "extends.*Exception|extends.*Error|HttpException|class.*Error\\("
  extracts_from: _extracted-codebase.md § "Error handling" (auto-detected base error class) + sample exception files
  sections: [overview, error_class_hierarchy, http_mapping, i18n_in_errors, when_to_create_new_exception, examples, pitfalls]
  mirror_existing: true
  fallback: _examples/error-handling.md

- name: multi-tenancy
  kind: pattern
  triggers:
    signal_confirmed: multi-tenant
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § multi-tenant + tenant resolution code
  sections: [overview, resolution_chain, context_propagation, automatic_filtering, manual_bypass_rules, testing_isolation, pitfalls]
  mirror_existing: true
  fallback: _examples/multi-tenancy.md

- name: caching
  kind: pattern
  triggers:
    grep_evidence: "@Cacheable|cache\\.(get|set)|getOrSet|Cache::|redis|memcached|fastcache|cachetools"   # generic cache-API shapes across stacks; Phase 2 fills in the actual cache lib name
  extracts_from: _extracted-codebase.md (cache layer detection) + sample usages
  sections: [overview, key_construction, ttl_strategy, tenant_aware_keys, invalidation_via_subscribers, what_not_to_cache, pitfalls]
  mirror_existing: true
  fallback: _examples/caching-strategy.md

- name: api-versioning
  kind: pattern
  triggers:
    grep_evidence: "/v1/|/v2/|@Version\\(|api_version|version_prefix"
  extracts_from: _extracted-codebase.md § "API surface" (route prefix analysis)
  sections: [overview, version_prefix_strategy, deprecation_path, breaking_change_rules, examples]
  mirror_existing: true
  fallback: _examples/api-versioning.md

- name: api-contract
  kind: pattern
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § "API surface" + sample controller + DTOs
  sections: [overview, dto_in_out_split, response_envelope, status_code_conventions, idempotency, pagination, examples]
  mirror_existing: true
  fallback: _examples/api-contract.md

- name: request-validation
  kind: pattern
  triggers:
    always: true                                                   # every handler reading attacker-controlled input needs boundary validation + a writable-field allow-list
  extracts_from: _extracted-codebase.md § "API surface" (handlers + write paths) + § Conventions (validation lib) + sample DTOs + _extracted-idioms.md (boundary/allow-list primitive)
  sections: [overview, validate_at_boundary, validate_normalize_authorize_order, mass_assignment_allow_list, bounds, content_type_body_size_limits, error_to_field_contract, adapt, detectors, related]
  mirror_existing: true
  fallback: _examples/request-validation.md

- name: rate-limiting
  kind: pattern
  triggers:
    always: true                                                   # every public/expensive API needs inbound self-protection
  extracts_from: _extracted-codebase.md § "API surface" (public/expensive endpoints) + _extracted-idioms.md (limiter lib if any) + cache/Redis config
  sections: [overview, algorithm_choice, key_dimension, distributed_store, response_contract, load_shedding, detectors, examples]
  mirror_existing: true
  fallback: _examples/rate-limiting.md

- name: conditional-requests
  kind: pattern
  triggers:
    always: true                                                   # REST resource design — applies wherever mutable resources exist
  extracts_from: _extracted-codebase.md § "API surface" (mutable resources + version/updated_at/row_version columns)
  sections: [overview, etag_generation, read_revalidation, write_optimistic_concurrency, status_codes, detectors, examples]
  mirror_existing: true
  fallback: _examples/conditional-requests.md

- name: pagination
  kind: pattern
  triggers:
    always: true                                                   # every list/collection endpoint paginates (backend-principles MUST)
  extracts_from: _extracted-codebase.md § "API surface" (list endpoints + sort/filter columns + existing pagination primitive)
  sections: [overview, cursor_vs_offset, rules, detectors, closure_verbs, examples]
  mirror_existing: true
  fallback: _examples/pagination.md

- name: response-streaming
  kind: pattern
  triggers:
    grep_evidence: "StreamingResponse|StreamableFile|StreamingHttpResponse|ActionController::Live|StreamingResponseBody|text/event-stream|application/x-ndjson|http\\.Flusher|@Sse\\(|res\\.write\\(|/export|/download|/report"
  extracts_from: _extracted-codebase.md § "API surface" (export/report/large-result endpoints) + _extracted-idioms.md (streaming primitive)
  sections: [overview, transport_choice, mid_stream_errors, backpressure, lifecycle, detectors, examples]
  mirror_existing: true
  fallback: _examples/response-streaming.md

- name: async-job-offload
  kind: pattern
  triggers:
    grep_evidence: "BullMQ|Sidekiq|Celery|ActiveJob|Hangfire|@Async|asynq|Dramatiq|\\bRQ\\b|202|Accepted|/jobs/|enqueue|ShouldQueue"
  extracts_from: _extracted-codebase.md § "API surface" (slow/expensive endpoints) + _extracted-idioms.md (job runner/queue) + § "Background jobs"
  sections: [overview, http_contract, job_status_state_machine, idempotent_submission, result_ttl, detectors, examples]
  mirror_existing: true
  fallback: _examples/async-job-offload.md

- name: webhook-flow
  kind: pattern
  triggers:
    grep_evidence: "webhook|x-signature|x-hub-signature|stripe-signature|svix|verifyHmac|timingSafeEqual|compare_digest|raw_post|rawBody|event\\.id"
  extracts_from: _extracted-codebase.md § "API surface" (webhook endpoints + signature verification + outbound delivery/retry) + _extracted-idioms.md (queue for enqueue-then-ack)
  sections: [overview, inbound, outbound, detectors, closure_verbs, examples]
  mirror_existing: true
  fallback: _examples/webhook-flow.md

- name: transaction-boundary
  kind: pattern
  triggers:
    grep_evidence: "@Transactional|db\\.transaction|beginTransaction|Ecto\\.Multi|unit_of_work|SELECT .*FOR UPDATE|BEGIN;|session\\.begin|with_transaction|row_version|@Version|lock_version"
  extracts_from: _extracted-codebase.md § "Data access" (transaction primitive + ORM + locking) + _extracted-idioms.md (unit-of-work / repository shape)
  sections: [overview, rules, detectors, closure_verbs, examples]
  mirror_existing: true
  fallback: _examples/transaction-boundary.md

- name: file-upload
  kind: pattern
  triggers:
    grep_evidence: "multipart/form-data|createReadStream|UploadFile|MultipartFile|CarrierWave|ActiveStorage|presigned|putObject|multer|busboy|formidable|StreamedResponse.*upload|magic.?bytes|file-type"
  extracts_from: _extracted-codebase.md § "API surface" (upload endpoints + storage adapter) + _extracted-idioms.md (object-storage / presigned flow)
  sections: [overview, rules, detectors, closure_verbs, examples]
  mirror_existing: true
  fallback: _examples/file-upload.md

- name: parallel-io
  kind: pattern
  triggers:
    # Fires for any backend on a language that has a non-blocking I/O model.
    # Phase 2.5 extracts the project's concurrency primitive into _extracted-idioms.md § Concurrency.
    runtime_supports_async: true                                    # Node.js / Python-async / Go / Java 21+ / .NET / Kotlin / Rust-tokio / Elixir
    OR_grep_evidence: "Promise\\.all|Promise\\.allSettled|Bluebird\\.map|p-limit|asyncio\\.gather|asyncio\\.Semaphore|errgroup|CompletableFuture|Parallel\\.ForEachAsync|StructuredTaskScope|pmap|Task\\.async_stream"
  extracts_from: _extracted-idioms.md § Concurrency + _extracted-codebase.md § "Performance hot paths" + sample bounded-fanout helper (if any) + DB pool config
  sections:
    - project_specific_first   # the primitive in use, project helper, observed caps, cancellation primitive, tracing wrapper, where-it-lives
    - overview
    - when_to_use_decision_table
    - project_shipped_helper
    - recipes
    - decision_parallel_vs_batch_vs_sequential
    - concurrency_caps
    - tracing_observability
    - pitfalls
    - when_not_to_use
    - examples_from_codebase
    - related
  mirror_existing: true
  fallback: _examples/parallel-io.md
  cite_evidence: strict

# ============ AGENTS (.claude/agents/<name>.md) ============

- name: <stack>-architect           # name templated from detected stack: nestjs-architect, django-architect, etc.
  kind: agent
  triggers:
    primary_framework_detected: true
  extracts_from: _extracted-codebase.md (stack + conventions + base classes) + _extracted-idioms.md (all)
  sections: [persona, when_to_invoke, preflight_reading, methodology, output_format, verification, pitfalls]
  mirror_existing: false   # generated agent name embeds the stack — overwriting an existing one is correct
  fallback: _examples/api-architect.md   # generic api-architect as last resort

- name: <stack>-reviewer            # nestjs-reviewer, django-reviewer, etc.
  kind: agent
  triggers:
    primary_framework_detected: true
  extracts_from: _extracted-codebase.md + _extracted-idioms.md (all)
  sections: [persona, when_to_invoke, review_checklist_per_layer, signal_specific_checks, output_format]
  fallback: _examples/api-reviewer.md

- name: bug-investigator
  kind: agent
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Modules + § Tests + § Anti-patterns
  sections: [persona, methodology, layer_walk_path, log_grep_strategy, common_root_causes_in_this_codebase, output_format]
  mirror_existing: true
  fallback: _examples/bug-investigator.md

- name: endpoint-tester
  kind: agent
  triggers:
    api_surface_detected: true
  extracts_from: _extracted-codebase.md § "API surface" + sample DTOs
  sections: [persona, dev_server_targets, request_construction, response_verification, dto_shape_check, output_format]
  mirror_existing: true
  fallback: _examples/endpoint-tester.md

- name: websocket-engineer
  kind: agent
  triggers:
    signal_confirmed: real-time
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" § real-time + WS handler files
  sections: [persona, gateway_pattern, auth_at_handshake, room_strategy, message_contracts, scaling_concerns]
  fallback: _examples/websocket-engineer.md

# ============ RULES (.claude/rules/<name>.md) ============

- name: backend-principles
  kind: rule
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Conventions + § Anti-patterns + _extracted-idioms.md (all)
  sections: [project_specific_first, layer_responsibilities, must_use, must_not_use, naming, observability_requirements]
  mirror_existing: true
  fallback: _examples/backend-principles.md

- name: migration-backend
  kind: rule
  triggers:
    migration_layout_detected: true   # only ships when migration pack is loaded
  extracts_from: _extracted-codebase.md § Stack + § Layering + _extracted-idioms.md (full)
  sections: [stack_assumption, backend_audit_axes, stack_aware_primitive_set, transposition_trap_fingerprints, phase_3_retrieve_specifics, cross_references]
  mirror_existing: true
  fallback: rules/migration-backend.md   # canonical authored shape; AUTHOR mode anchors stack-aware substitutions to project

- name: database
  kind: rule
  triggers:
    orm_detected: true
  extracts_from: _extracted-codebase.md § "Data model" + _extracted-idioms.md § (repo base class)
  sections: [project_specific_first, queries_through_repository, never_inject_dataSource, parameterized_queries, soft_delete_filter, tenant_filter, examples_anti_patterns]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/database-rules.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: dtos-mappers
  kind: rule
  triggers:
    dto_pattern_detected: true
  extracts_from: _extracted-codebase.md § Conventions + sample DTOs + Mapper idiom
  sections: [project_specific_first, dto_validation_decorators_in_use, mapper_dependencies, no_business_logic_in_dto_mapper, translation_dto_shape, examples]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/dtos-mappers-rules.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: controllers
  kind: rule
  triggers:
    controller_pattern_detected: true
  extracts_from: _extracted-codebase.md § "API surface"
  sections: [project_specific_first, response_envelope_in_use, auth_decorators_required, request_types_constraint, no_business_logic, examples]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/controllers-rules.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: events
  kind: rule
  triggers:
    grep_evidence: "EventEmitter|@EventPattern|emit\\(|@OnEvent|publish\\(|@EventHandler|@MessagePattern|django\\.dispatch|signals\\.send|ActiveSupport::Notifications"   # generic event/messaging shapes across stacks; project-specific class names come from extraction
  extracts_from: _extracted-codebase.md § "Cross-cutting concerns" + sample event handlers
  sections: [project_specific_first, intra_app_vs_cross_app, payload_constraints, handler_isolation, payload_security, testing]
  mirror_existing: true
  fallback: stub-from-sections   # no _examples/events-rules.md ships; AUTHOR-mode required, sectioned-stub fallback per phase-4.2-apply.md

- name: concurrency-discipline
  kind: rule
  triggers:
    # Always-on for backends on non-blocking-I/O runtimes; the rule is what prevents the
    # most common LLM-authored backend perf failure (sequential await of independent calls).
    runtime_supports_async: true
    OR_grep_evidence: "async (function|def)|async \\w+ \\(|func .* \\(ctx context\\.Context"
  extracts_from: _extracted-idioms.md § Concurrency + _extracted-codebase.md § "Performance hot paths" + DB pool config + 3rd-party client config
  sections: [project_specific_first, must, must_not, should, examples_per_stack, review_checklist, anti_patterns_named]
  mirror_existing: true
  fallback: _examples/concurrency-discipline.md
  cite_evidence: strict

# ============ COMMANDS (.claude/commands/<name>.md) ============
# Commands inherit canonical 7-phase structure; AUTHOR mode customizes the Retrieve / Generate / Validate phases per project.

- name: add-module
  kind: command
  triggers:
    module_per_feature_layout: true
  extracts_from: _extracted-codebase.md § Modules + § Conventions + _extracted-idioms.md (full layer set)
  sections: [understand, organize, retrieve, generate, update, validate, improve, output_format, failure_modes]
  mirror_existing: true
  fallback: _examples/add-module.md

- name: add-endpoint
  kind: command
  triggers:
    api_surface_detected: true
  extracts_from: _extracted-codebase.md § "API surface" + sample controller + DTOs
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-endpoint.md

- name: add-feature
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md § Modules + § Architecture
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/add-feature.md

- name: fix-bug
  kind: command
  triggers:
    always: true
  extracts_from: _extracted-codebase.md (full) + bug-investigator agent
  sections: [understand, organize, retrieve, generate, update, validate, improve]
  fallback: _examples/fix-bug.md

- name: endpoint-test
  kind: command
  triggers:
    api_surface_detected: true
  extracts_from: _extracted-codebase.md § "API surface" + dev server start command (from package.json scripts)
  sections: [understand, organize, retrieve, generate, validate]
  fallback: _examples/endpoint-test.md

- name: api-consistency-audit
  kind: skill
  triggers:
    api_surface_detected: true
  extracts_from: _extracted-idioms.md § "API conventions" + ai/api-conventions.md + OpenAPI spec
  sections: [purpose, when_to_use, inputs, outputs, the_15_detectors, procedure, hard_rules, failure_modes]
  fallback: skills/api-consistency-audit/SKILL.md
  cite_evidence: strict

- name: log-tail
  kind: command
  triggers:
    logger_lib_detected: true
  extracts_from: _extracted-codebase.md (logger lib + log file paths)
  sections: [understand, retrieve]
  fallback: _examples/log-tail.md

- name: analyze-module
  kind: command
  triggers:
    module_per_feature_layout: true
  extracts_from: _extracted-codebase.md § Modules
  sections: [understand, organize, retrieve, generate]
  fallback: _examples/analyze-module.md
```

---

## How generators consume this file

For each topic where `triggers` evaluate true against `.claude/_extracted-codebase.md`:

1. Substitute templated names (e.g., `<stack>-architect` → `nestjs-architect` if stack=NestJS).
2. If `mirror_existing: true` AND target file exists → read it; capture section order + voice; author inside that skeleton.
3. Read the `extracts_from` source (idiom block or codebase section).
4. For each section in `sections`, author content using extracted facts. Cite `<path>:<line>` for every claim if `cite_evidence: strict`.
5. If extraction yields no signal for a section → omit the section (don't pad). Add a `<!-- TODO: re-author from extraction once <reason> -->` comment.
6. If extraction yields no signal for the WHOLE topic → fall back to `cp <fallback> <target>` + Phase 4.6 path injection.
7. After write: lint output for forbidden patterns (generic prose without project context, missing citations in strict mode, contradictions with `_extracted-codebase.md`).

## Pack-author maintenance contract

When adding a new topic to this pack:
- Choose `triggers` so the topic activates ONLY when relevant (no false positives).
- Place a `_examples/<name>.md` template (the fallback) — must be ≥100 lines (depth floor enforced by Phase 4.0 preflight).
- The `sections` list is the topic's CONTRACT — generators won't invent new sections; they ONLY fill in the listed ones.
- Document in this file's commit message: which extraction signal feeds this topic, and what the fallback template represents.

## Why this file exists

Without `_topics.md`, the backend pack ships only literal templates. Phase 4.2 (COPY mode) drops them into the project unchanged + injects paths. Output reads as generic regardless of how rich the codebase is.

With `_topics.md` + Phase 2.5 extraction + Phase 4.2-AUTHOR, the same backend pack produces project-specific output for mature codebases (rich base classes + many extenders) AND falls back to generic templates for greenfield. Same pack, two modes — driven by codebase evidence.
