---
track: backend
purpose: Server-side API/service development — design, implement, debug, and test endpoints.
essentials:
  agents: [api-architect, api-reviewer, bug-investigator]
  commands: [add-feature, add-endpoint, fix-bug]
  skills: [endpoint-test, parallelize-independent-ops, api-consistency-audit]
  rules: [backend-principles, concurrency-discipline]
  ai-patterns: [api-contract, error-handling, request-validation, parallel-io, rate-limiting]
---

# Backend — essentials manifest

Files listed above are the minimal subset copied when `/setup-project --minimal` is used. Standard mode copies the entire pack; minimal mode copies only essentials.

Rationale per category (one line each):
- agents: api-architect designs, api-reviewer checks output, bug-investigator covers the most common backend task (debugging) — the minimum trio for design+review+fix.
- commands: add-feature/add-endpoint cover the two main creation flows; fix-bug covers the most frequent maintenance task.
- skills: endpoint-test verifies a controller/DTO works end-to-end — essential after every backend change. parallelize-independent-ops covers the highest-leverage performance refactor (sequential-await → bounded parallel) which LLMs miss by default.
- rules: backend-principles (layering / safety) AND concurrency-discipline (no sequential `await` of independent I/O). Concurrency is non-essential ONLY for synchronous-by-language stacks; on Node.js / Python-async / Go / Java / .NET it's load-bearing.
- ai-patterns: api-contract (request/response shape), error-handling (must-have safety pattern), request-validation (load-bearing inbound safety — boundary validation + writable-field allow-list stops mass-assignment / over-posting and unbounded input; the backend-principles Hard rule (a) floor; minimal mode ships it), parallel-io (cites the project's actual concurrency primitive — without it, agents reach for generic `Promise.all` and miss bounding / cancellation / batch APIs), rate-limiting (load-bearing inbound safety — every public/expensive endpoint needs an enforced 429 limit; minimal mode ships it). conditional-requests (ETag/optimistic-concurrency) and pagination (cursor-first, default+max limit, stable sort — a MUST on every list endpoint) ship in standard mode; response-streaming, async-job-offload, webhook-flow (inbound signature-verify + replay + enqueue-then-ack; outbound signing + retry/DLQ), transaction-boundary (intra-service write-set atomicity + optimistic/pessimistic locking), file-upload (magic-byte validation / size cap / presigned direct-to-storage / uuid keys) and agent-callable-api (description-as-interface, closed input schemas, self-correcting errors, response-size budget, server-side destructive gates, token audience/scoping) are signal-gated (large-result / background-job / webhook / transaction / upload endpoints; an MCP or tool-calling surface for the last) and ship in standard mode. agent-callable-api stays OUT of minimal deliberately — minimal already carries five patterns, and a project with no autonomous caller pays its whole cost for nothing. The `migration-safety` skill (online-safe/reversible migration verifier) is signal-gated on migration files. multi-tenancy is a signal-gated pattern (fires on a multi-tenant signal) — also mirrored under `templates/domains/multi-tenant/`; neither is in the minimal essentials.
