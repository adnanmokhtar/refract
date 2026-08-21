# backend pack — changelog

Release history for `templates/packs/backend/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.15.0 — 2026-08-21

Quality pass, not a volume pass — the target was artifacts that were neither wrong nor missing, but thin:
generic, duplicated, or dispatching at things nobody implements. Scope by count, read off `git diff --stat`
rather than asserted from memory: `agents/` 1 of 5, `commands/` 1 of 9, `rules/` 1 of 3, `ai-patterns/`
1 of 16, `_examples/` 1 of 37, plus `_topics.md`, `_version.json` and this file. **`skills/` (0 of 9),
`references/` (0 of 12), `_essentials.md` and `STACK.md` are untouched.** No file added, none deleted.
`rules/migration-backend.md` is a pack rule and not a repo-baseline rule, so `check-rule-budget.sh` does not
move (~4943 / 6000 either side of this release).

**Changed**

- **`agents/websocket-engineer.md` gains `## Output`** — it was the only agent in the pack with no output
  contract, and four callers depend on what it returns: `agents/api-reviewer.md:76` (ENF-4) hands
  streaming/real-time depth to it by name, and `api-architect.md`, `bug-investigator.md` and
  `endpoint-tester.md` each escalate into it. Four callers, no defined return shape. The new block defines
  the agent against its siblings on the *return*, not only on scope: `api-architect` returns a file list and
  a DTO surface, `api-reviewer` a production-readiness verdict table, `endpoint-tester` PASS / FAIL /
  INCOMPLETE off calls it actually made, `bug-investigator` one root-cause sentence. This one returns a
  protocol design or a protocol review — the only output in the pack that *already-connected clients are
  coupled to*, since a shipped envelope cannot be redeployed out from under a mobile build in the field.
  - Two rows carry the weight. **Mirror source** forces the `<path:line>` of the sibling event the envelope
    copies; without it the file's own first halt condition (§ The Premise) could be skipped silently, because
    nothing downstream could tell. **Capacity** is `MEASURED <n> conns @ <hardware> @ <msg/s>` or the literal
    token `NOT MEASURED`, which is what turns § Scaling's "derive it, never quote it" from advice into
    something a reader can check.
  - Severity vocabulary is closed at **BLOCKER** / **REQUEST** — the two already in use in § Example
    findings — and named as closed, so no third level accretes.

- **`_examples/websocket-engineer.md` — a live fabrication removed from a shipping path.** The AUTHOR-mode
  fallback still read "Practical ceiling: 10-50k connections per Node process", a number with no source
  behind it, in the file `templates/phases/phase-4.2-apply.md` copies verbatim into `.claude/agents/` when
  extraction finds no real-time signal — i.e. exactly the case where a made-up capacity figure does the most
  damage, because there is no local evidence to contradict it. Replaced with the same three measurable limits
  the shipped agent derives (file descriptors · per-connection memory measured against the *container* limit ·
  event-loop headroom under a realistic message rate), ending in `NOT MEASURED` as the honest default. The
  fallback also gains the Premise + halt conditions and the same `## Output` block; it was the only *agent*
  example of the five with no output section at all.
  - Same file: `nhooyr.io/websocket` corrected to `github.com/coder/websocket`. Sourced, not recalled —
    `https://pkg.go.dev/nhooyr.io/websocket` carries "Deprecated: coder now maintains this library at
    https://github.com/coder/websocket", and the GitHub releases API gives v1.8.12 `published_at`
    `2024-08-09` with the body "This release marks the repo's transfer from nhooyr to Coder."

- **`commands/endpoint-test.md` — the tier table stops dispatching into space.** Phase 2 is the one block
  this command genuinely owns, and it was the only broken one. `Standard` promised "mandatory cases + the
  idempotency-replay variant on writes", but idempotency replay is already one of the mandatory five
  (`skills/endpoint-test/SKILL.md` § Procedure step 6; `agents/endpoint-tester.md` § Case selection), so
  Standard added nothing over Trivial while reading as if it did. `Heavy` named `signature-tampered` and
  `replay-with-stale-key`, two cases that appeared nowhere else in `templates/` — neither the skill's
  conditional-case list nor the agent's selection table implements them, so the command was handing the agent
  a scope no artifact could execute.
  - Rewritten so each tier names only cases that exist and points at the file that owns them: Trivial = the
    mandatory five and nothing else; Standard = the five plus every conditional whose signal the contract
    actually declares, selected from the agent's signal → case table (the command does not enumerate them,
    per its own `:17` rule); Heavy = Standard plus the two agent-owned cases with no skill counterpart
    (content negotiation, tenant side-effects) run *unconditionally* rather than signal-gated, on the
    reasoning that on a publicly reachable surface a missing declaration is not evidence of correct behaviour.
  - Signature tampering and stale-key replay are routed out rather than deleted silently: they belong to
    `/simulate-webhook --tamper` in the webhook domain (`templates/domains/webhook/rules/webhook-signature-verification.md`
    § Enforcement), and if that domain is not installed the report must carry
    `signature cases NOT RUN (webhook domain absent)` — the same never-claim-an-axis-that-did-not-run guard
    the pack already uses for missing agents.

- **`rules/migration-backend.md` — a shadow copy of a regex set removed; the file given the axis it owns.**
  The § Stack-aware primitive set table carried a prose paraphrase of the alternations inside
  `scripts/validate-migration-artifacts.sh § extract_inventory_primitives` (`:1211`, called at `:1799-1800`) —
  2749 of 7877 characters, a second source of truth with no gate comparing the two, and nothing an agent
  would ever follow. The **Primitive → Axis** mapping stays, because that IS agent-followable; the regex
  column is gone, replaced by a pointer to the function that owns it and the actual drift threshold read out
  of the script (fires when V1 > 0 and V2 / V1 < 0.7).
  - The fingerprint catalogue (fat controller, raw-SQL concat, `SELECT *` over-fetch, N+1, sync HTTP in the
    hot path, missing tenant filter, controller→DB direct, hand-built `Authorization` header, catch-and-swallow)
    now **leads** the file, and the header states the point of view it lacked: this rule owns the V1→V2 PORT
    axis and nothing else. `backend-principles.md` is what you must do in code you write fresh;
    `concurrency-discipline.md` is the async axis in any code at all; this one is the failure class that exists
    only while transposing an implementation that already shipped — code that was correct in V1's architecture
    and is wrong in V2's, carried across *because it worked*.
  - **Frontmatter now matches the gate.** It declared `applies-to: backend-track, every-code-writing-task-in-backend`
    and `severity: must`, byte-identical to the always-on `backend-principles.md`, while `_topics.md:332`
    ships it only under `migration_layout_detected: true`. Nothing reads those keys (`applies-to` is catalog
    metadata in `scripts/gen-pack-catalog.py:299`; `extends:` is read by nothing), so they were pure
    documentation documenting the opposite of the truth. Now `applies-to: backend-track, v1-to-v2-ports` and
    `severity: must (when a migration layout is detected)`.
  - **New `## DI markers` section closes a dangling cross-pack citation.** `templates/packs/migration/_failure-surface.md:175`
    routes readers to `backend/rules/migration-backend.md § DI markers` for the concrete marker syntax; that
    section did not exist. It does now, and it deliberately refuses to name the syntax — the marker is a
    per-project fact, so the section routes to `_extracted-idioms.md § DI / module wiring` and
    `_extracted-codebase.md § Layering`, and states that missing extraction *is* the finding rather than a
    licence to substitute the framework you saw most recently.
  - `_topics.md` `sections:` updated in lockstep, because this rule is its own AUTHOR-mode fallback
    (`fallback: rules/migration-backend.md`) and a stale section list regenerates the gap.

- **`ai-patterns/parallel-io.md`** — one line. Three `<extracted…>` tokens in § Concurrency caps sit outside
  the degraded-behaviour blockquote, so the `[UNANCHORED]` rule did not reach them and the section said only
  "no guessing". It now extends that rule to the cap cells explicitly: not found ⇒ write `NOT FOUND` and treat
  the workload as `[UNANCHORED]`. An unresolved token in a Cap column is read as a number, which is the same
  leak in a quieter place.

- **`_topics.md`** — the `websocket-engineer` entry gains `output_format` in `sections:` (all four sibling
  agent entries already carried it) and `mirror_existing: true`, which it was alone in lacking; without both,
  AUTHOR mode regenerates precisely the gap this release closed. The `migration-backend` entry's `sections:`
  list is reordered and extended to match the rewritten rule.

**Known, not fixed in this release**

- `validate-pack-consistency.sh` warns that seven shipped backend artifacts have no `- name:` entry in
  `_topics.md`: `ai-patterns/caching-strategy.md` and the `api-snapshot`, `debug-tenant`, `env-diff`,
  `migration-safety`, `module-scaffold`, `parallelize-independent-ops` skills. Left alone on purpose. A topic
  entry carries `triggers:`, and a trigger *gates* generation — registering these with invented triggers
  would risk removing skills from projects that currently receive them unconditionally. Fixing it means
  deciding a real trigger per skill, which is its own pass.
- `_examples/refactor.md` is a six-line usage anecdote with no frontmatter and no dispatch section, yet
  `_topics.md:462` names it the AUTHOR-mode fallback for the `/refactor` overlay — so a project with no DI
  signal receives that anecdote as its `commands/refactor.md`. The same fallback-lagging-the-shipped-artifact
  shape as the websocket example above. The one-line fix is `fallback: commands/refactor.md` (self-fallback,
  the pattern `api-consistency-audit` and `migration-backend` already use), but it was outside this pass's
  brief and is recorded here rather than done quietly.

## 1.14.0 — 2026-08-21

Additive pass. Scope, by count so it can be checked against the diff: `ai-patterns/` 3 of 16 (one of them
new), `skills/` 1 of 9, `_examples/` 2 of 37 (one of them new), plus `_topics.md`, `_essentials.md`,
`_version.json` and this file. **`agents/` (0 of 5), `rules/` (0 of 3), `references/` (0 of 12),
`commands/` (0 of 9) and `STACK.md` are untouched** — checked against `git diff --stat`, not asserted from
memory, because the 1.13.0 entry got exactly this claim wrong and no gate catches it. Nothing was added to
`rules/` on purpose: the repo's `rules/` files are always loaded and share one 6000-token budget with about
1000 tokens of headroom left, so depth belongs in `ai-patterns/`, which loads on demand.

**New**

- **`ai-patterns/agent-callable-api.md`** (+ `_examples/agent-callable-api.md` fallback) — the pack's 16th
  pattern, and the first that treats the *caller* as the variable. Three properties of an autonomous caller
  break assumptions a human-written client silently satisfies: it never re-reads your docs (the description
  text in context this turn is its entire knowledge of the API), it sees no dashboard/changelog/UI, and every
  byte you return is tokenised into a finite billed context that competes with its actual task — so response
  size is a **correctness** budget, not a cost one. The hard rule is five clauses — a description stating the
  anti-trigger and the negative space ("what this tool does *not* return"); an input schema where invalid
  states are unrepresentable rather than merely rejected; errors carrying the correction so the model can
  self-correct; a declared, enforced response budget; and server-side enforcement of every destructive gate —
  plus a section on audience-validated, non-passthrough tokens for a caller that is not a person. Eight
  detectors, ten closure verbs, and a § When NOT to expose an API to agents at all. Sourced against
  Anthropic's tool-use docs (Define tools § Best practices; Writing tools for
  agents; Strict tool use) and the MCP `2025-11-25` specification (execution-vs-protocol errors, the
  `ToolAnnotations` "hints … untrusted" clause, and the authorization `MUST`s), with the prefix-vs-suffix
  namespacing question recorded as **UNKNOWN** because the cited source says the effect is non-trivial but
  never says which direction wins.
  - The pack-internal argument that makes it worth its 246 lines: **this repo already proves the thesis.**
    `templates/canonical-command-template.md:35,42–44` demands a keyword-front-loaded description plus an
    explicit `USE:` / `NOT:` pair for every command, because agent routing accuracy collapses without it. A
    tool description is the same artifact under a different name, routed by the same mechanism, failing the
    same way.
  - Registered signal-gated, never `always: true` — most backends have no agent-callable surface, and
    authoring this into one is the ceremony `_essentials.md` exists to refuse.

**Depth**

- **`api-contract.md` § Resource naming and URL structure**, four additions and one new section. Nesting
  depth gets the rule teams actually ignore (Zalando #147, "⇐ 3 sub-resource (nesting) levels") plus the test
  that decides it — not "is this conceptually inside that", which is true of almost everything, but "can I
  resolve this id *without* the parent's id"; if yes, promote it to a top-level collection and demote the
  parent to a filter. AIP-122's collection-identifier uniqueness rule (`people/xyz/people/abc` is invalid)
  lands as the cheap always-real bug. Zalando #143 and #136 (path-segment identification; no empty or
  trailing segments) are named because both break silently in a route table.
- **The plural rule's real exception is now stated instead of implied.** AIP-122: where there is no plural
  word ("info") or singular and plural coincide ("moose"), the singular is correct and coining an "s" is
  forbidden. `/media`, `/series`, `/analytics`, `/staff` are therefore not drift — which is also why the
  audit refuses to automate the plural check at all (see below).
- **The two doctrines this file cites disagree, and the file now says so.** Zalando #129 mandates kebab-case
  path segments (`^[a-z][a-z\-0-9]*$`) and #130 snake_case query params; Google AIP-122 mandates camelCase
  segments. Both are published MUSTs from serious API programmes and there is no neutral arbitrator, so the
  section records the disagreement in a table, states the property that actually matters (**predictability**;
  the case style is the arbitrary half), sets this pack's default to Zalando's kebab paths with the reason (a
  path segment is a token humans type, log, paste into runbooks and compare case-insensitively), and flags
  the one exception that survives either choice — AIP-136 requires the custom-method verb after the colon to
  be camelCase, so `POST /shipping-addresses/42:markPrimary` is a *correct* camelCase island and a case
  detector that flags it has a bug.
- **`api-contract.md` § Retrofitting — after the fact, consistency beats correctness.** The inversion most
  naming guides never state: on day 900 a half-finished rename is worse than doing nothing. A surface that is
  0% textbook and 100% predictable costs a consumer one lookup ever; one that is 60% correct costs them a
  lookup *per call*, because guessing stops working — which is the exact cost the naming rules exist to
  remove. Four ordered steps (declare the existing convention as canonical including the parts you dislike;
  new endpoints match the canonical, not the textbook; change the convention only as a versioning event; or
  close it in an ADR), and two narrow exceptions that get fixed out of band because they are defects rather
  than taste: a verb path whose method contradicts it (`GET /orders/42/delete` — GET is safe per RFC 9110
  §9.2.1, so crawlers and prefetchers may fire it), and a segment leaking PII or an enumerable id.
- **`api-versioning.md` § Date-pinned (rolling) versions.** The 1.13.0 pass added the strategy *row*; this
  adds the model behind it, because "header versioning with nicer strings" is the wrong reading and two of
  the three parts out of three is worse than `/v1`. Pin at first call, per-request header override with a
  written resolution order, and a chained registry of version-change modules — the property that makes the
  fifteenth version cost the same as the second is that **your handlers only ever know the current shape**;
  an old version is today's response walked backwards through N small functions. The section then states the
  property the whole thing rests on (every transformation is a pure, order-dependent function of the payload
  — no I/O, no DB, no clock) and what Stripe does when that breaks (`has_side_effects` annotations, no-ops in
  the layer, real behaviour scattered elsewhere), reading that as the honest cost line rather than a fix.
  Plus: a per-approach failure-mode table (what each prevents *and* what each creates), the run costs
  (registry never shrinks; per-version conformance suites; caching gets worse — a pinned version is derived
  from the credential, so the only honest cache key is the credential and the shared cache shares nothing;
  webhooks need their own explicit pin), and when it is the wrong choice — chiefly **semantic** breaks, which
  a payload transform cannot express (`firstName`+`lastName` → `name` is recoverable; "`amount` now excludes
  tax" is not).
- **`Date-named is not date-pinned`,** separated because the two get conflated whenever someone points at a
  dated version string. Anthropic requires an `anthropic-version` header on every request with no
  account-level pin and two versions total; GitHub is date-named with a *frozen* `2022-11-28` default; only
  Stripe runs the full pin + override + chain. The cheap half is adoptable without the expensive half, and
  that is the option most teams should take. Also `Option D: version-change chain` under § Implementation
  strategies, stated as a rewrite rather than a refactor from A/B.

**Enforceability**

- **`api-consistency-audit` fingerprint 3b (`resource-naming-drift`) becomes runnable.** Six shell checks
  over a normalised `paths.txt` — verb-in-segment, Zalando #129's published segment regex, a dominance count
  that says which style the surface *actually* uses (run first: a uniformly snake surface has a canonical
  that is not kebab, and the regex check's output is then the wrong list to act on), nesting depth, repeated
  collection segments, and empty/trailing segments. Each carries the reason its naive form is wrong: the
  `/:param` normalisation is deliberately not a bare `:` rule because that eats the `{id}:verb` custom-method
  form and manufactures a phantom finding for every legitimate custom method, and the verb list requires a
  whole segment or a separator/capital because a prefix match flags `/addresses` as "add" and `/settings` as
  "set".
- **A `What grep cannot decide` block ships beside it**, which is the half that keeps the detector honest:
  singular-vs-plural has no check *deliberately* (the moose case — trailing-`s` clustering false-positives on
  every mass noun in the domain, and a domain is mostly mass nouns); whether a segment is a verb or a noun
  (`/documents/7/review`); whether nesting is wrong or merely deep; and what the canonical even is, which
  comes from `api-conventions.md` — and this skill halts without it rather than guessing.
- **The retrofit rule is now binding on the detector, not just advice in the pattern.** When the declared
  canonical disagrees with the textbook the canonical wins and the textbook-correct endpoint is the outlier;
  a detector that pushes a consistently singular surface toward plural is manufacturing drift and spending a
  breaking path rename to do it.
- `api-contract.md` Detector 6 extends to nesting depth and repeated collection segments, and now defers to
  `api-conventions.md` over its own table in an existing codebase.
- `api-versioning.md` **Detector 7 (`pin-default-version`)** — a version-resolution site whose fallback for a
  missing header is "latest" converts every future release into a silent breaking change for every header-less
  caller, which is the failure the scheme was bought to prevent. Fixed default (GitHub) or hard reject
  (Anthropic) are both defensible; "latest" is not. **Detector 8 (`move-version-branch-to-adapter`)** — a
  version conditional below the HTTP adapter, which is the specific way a transformation chain rots, and a
  branch that *cannot* move because it needs state the payload does not carry is a semantic break wearing a
  structural costume. Two matching `## Forbidden` entries: latest-as-default, and date-pinning with no
  per-version conformance suite and no published support window ("not a versioning scheme, an open-ended
  promise to run every shape you have ever shipped, inherited by someone who did not make it").
- **These new verbs are pattern-detector verbs, not `/polish` ledger verbs, and that distinction is load-bearing
  after 1.13.0.** `validate-polish-artifacts.sh`'s closed 15-verb `API_CONSISTENCY_VERBS` set is checked only
  against `closure_verb:` rows in a consuming project's `ai/polish/ledger.md` and `ai/polish/_api-decisions.md`
  — never against pack pattern files, which have always carried their own verbs (`wrap-in-envelope`,
  `fix-brownout-status`, `ship-new-version`). The 1.13.0 fix reads as if every backend verb must live in that
  set; it does not, which is why all 18 gates stay green. `scripts/polish-parallel.sh`'s prompt template lists
  11 of the 15 and is illustrative, not a second vocabulary — it needs no edit either.

**Registration**

- `_topics.md` +`agent-callable-api`, placed with the signal-gated cluster and gated on MCP / tool-calling
  wire shapes rather than a stack. The entry states its own blind spot instead of implying coverage: an
  ordinary HTTP API whose callers have *shifted* from human-written clients to agents leaves no
  distinguishing code shape, so that case is added by hand.
- `_topics.md` `api-versioning` gains a `version_pinning_model` section and header/pin grep shapes. The old
  `grep_evidence` was route-prefix-only (`/v1/`, `/v2/`, `@Version(`, `api_version`, `version_prefix`), and a
  cleanly date-pinned API **has no `/vN` route at all** — so the topic was silent on precisely the scheme its
  new section documents, and would have been skipped on the project that needs it most.
- `_topics.md` `api-contract` gains a `resource_naming` section. Without it, extraction drops the project's
  declared URL shape, and `api-consistency-audit` halts rather than guess a canonical — so the omission
  disabled an enforcement path, not just a section.
- `_essentials.md` names `agent-callable-api` in the standard-mode signal-gated enumeration and states why it
  stays out of minimal.
- **`_examples/api-versioning.md` brownout line corrected to `503` + `Retry-After`** (it still said "410 Gone
  on a percentage of requests"). Not a new claim — the source was fixed in 1.13.0 for a documented reason (a
  probabilistic `410` is cacheable by default, so it can be stored and replayed permanently) and the mirror
  was missed. It is the declared `fallback:` for the topic, so the known-harmful instruction was still
  shipping wherever extraction falls back. The same file also gained the `Date-pinned / rolling` strategy row.

**Known gaps (verified open after this pass)**

- **The six checks in 3b are not executed by any gate.** They are read and run by a skill at use time; nothing
  in this repo proves the `awk`/`sed` hold against a real route table, and a normalisation bug would produce
  confident wrong candidates. A fixture route table plus expected output is the fix, and it does not exist.
- **`_examples/api-contract.md` has no § Resource naming at all** and did not gain one in 1.13.0 either. This
  is not a gate failure — `validate-pack-consistency.sh` treats `_examples/` as deliberately abridged and
  checks source presence only, never content (see its `project_examples_are_abridged` note) — but the mirror
  is now further behind its source than it was.
- **34 of 37 `_examples/` fallbacks remain un-rebased** from 1.13.0's correctness pass. `_examples/error-handling.md`
  still declares the positional `(message, context, cause)` constructor; `_examples/rate-limiting.md` still teaches
  the draft-05 triple; `_examples/api-contract.md` still mandates one fixed envelope where the source records an
  exclusive choice. Two were fixed this pass (`api-versioning`, and `agent-callable-api` ships new); the rest stand.
- **Still no gate compares a CHANGELOG entry's declared scope against the directories the diff touched.** The
  count line at the top of this entry was checked by hand against `git diff --stat`. It would pass unchecked
  if it were wrong.

## 1.13.0 — 2026-08-21

Scope, by count so it can be checked against the diff: every directory in the pack was touched —
`agents/` 5/5, `rules/` 3/3, `references/` 11/12, `ai-patterns/` 12/15, `commands/` 6/9, `skills/` 5/9 — plus
`_topics.md` and 1 of the 36 `_examples/` fallbacks. `references/hexagonal-nestjs.md` is the one reference left
alone deliberately: it delegates the whole HTTP block to `nestjs.md`, so it had nothing to re-base.
`_essentials.md`, `STACK.md` and the other 35 `_examples/` fallbacks are untouched — see Known gaps.

**Correctness**

- **Rate-limit headers re-based on `draft-ietf-httpapi-ratelimit-headers-11` (23 May 2026).** The
  `RateLimit-Limit` / `-Remaining` / `-Reset` triple the pack asserted is draft-05 legacy; the current
  revision defines exactly two fields, `RateLimit-Policy` and `RateLimit`, as RFC 9651 Structured Fields
  with quoted policy names and named parameters (`q`, `w`, `qu`, `pk`, `r`, `t`). `rate-limiting.md` now
  carries the canonical form plus an explicit transition rule: emit the two-field form AND the triple
  while clients migrate, and pin nothing to the draft as settled — it is an I-D (`IESG State: I-D Exists`)
  whose HTTPDIR early review of `-10` came back "Not ready". Added the three RFC 9457 problem types the
  draft registers, including `#temporary-reduced-capacity` (503) for the load-shedding path the pattern
  already prescribed and had no `type` for. **The re-base is pack-wide, not pattern-local** — a header set is
  worthless if one file in the pack still teaches the old one. `rules/backend-principles.md` RES-1 and its
  checklist row, and the `**Rate limiting**` bullet in all 11 stack references that carry one (`hexagonal-nestjs`
  delegates to `nestjs`), now name the two-field form, mark it a DRAFT and not an RFC, and keep the legacy triple
  only as an explicit transition. Each reference keeps its own per-stack footgun — the shared-store-or-`N × limit`
  trap, and which header set that stack's library actually emits — because those are the parts a header rename
  cannot fix.
- **`error-handling.md`: `DomainError` took `(message, context, cause)` positionally**, so every "RIGHT"
  example calling `new X(msg, { cause: e })` landed the raw upstream error in `context` — which the
  reference mapper spreads into the log line. Fixed to a single options object over the ES2022 native
  `cause`. Same file: `traceId` was read verbatim from a client `x-request-id` header (log-forging, and a
  direct contradiction of `backend-principles`); an unmapped `DomainError` defaulted to `400`, so genuine
  faults never entered the 5xx budget (now `500` + `error_unmapped_total`); `ValidationError` mapped to
  `400` against the rule's `422` (now `422`, with `400` reserved for an unparseable body); and the gold
  mapper committed the file's own named mistake of using error codes as i18n keys.
- **`caching-strategy.md`: the stale-while-revalidate example never revalidated** — `async_refresh(key)`
  sat after `return`, and there was no fresh-hit branch at all. Rewritten with the refresh dispatched
  before the return.
- **`api-versioning.md`: brownouts prescribed `410 Gone` on a percentage of requests.** 410 is cacheable
  by default (MDN), so a probabilistic one can be cached and replayed permanently — an outage where a fire
  drill was intended. Now `503` + `Retry-After`, with `410` reserved for the actual removal.
- **`webhook-flow.md` asserted `4xx` = stop retrying as universal HTTP semantics.** It is per-provider:
  Stripe retries any non-2xx for up to three days; others never auto-retry. Replaced with the two
  invariants that ARE universal, and a requirement to cite the provider's actual policy.
- **`multi-tenancy.md` listed a bare `X-Tenant-Id` header in the resolution chain** — the exact vector
  `backend-principles` lists under Must-not. Replaced with an impersonation-claim entry gated on mTLS +
  a `tenant:impersonate` claim + audit logging. Also reconciled the "never pass tenantId as an argument"
  NEVER against the DI rule it contradicted: ambient reads confined to the repository base, explicit
  scope permitted at a service boundary.
- **`async-job-offload.md` returned `200` on an idempotent re-submit** where `backend-principles` API-7
  requires replaying the stored response — i.e. the original `202`. A client branching on the status got
  different behaviour depending on which attempt landed.
- **`response-streaming.md` listed `Transfer-Encoding: chunked` as a general transport.** RFC 9113 §8.2.2
  prohibits connection-specific fields on HTTP/2 (`MUST` treat as `PROTOCOL_ERROR`), so an explicit set is
  a protocol error on H2/H3. Scoped to HTTP/1.1 framing.
- `413 Payload Too Large` → `413 Content Too Large` across `api-contract`, `request-validation`,
  `file-upload` (RFC 9110 §15.5.14 renamed it).
- `commands/add-feature.md` pointed at `payment-idempotency.md` as a pattern; it ships as a **rule** under
  `templates/domains/payment/`. Row now names the real kind and path.
- **`agents/websocket-engineer.md` quoted a single-server connection ceiling.** There is no portable number —
  the ceiling is the minimum of file descriptors, per-connection memory, and event-loop headroom, and it moves
  with every change to per-connection state. The quoted figure was a fabricated measurement of exactly the kind
  this pack blocks everywhere else. Replaced with the three-limit derivation, each measurable on the reader's own
  box, plus the standing rule: any capacity claim in a design must cite the number YOU measured and the hardware
  and message rate you measured it at, and a design under review that carries an uncited one is rejected.
- **`rules/concurrency-discipline.md` shipped a Java example that no longer compiles.** `StructuredTaskScope` is
  still a preview API (JEP 505, "Structured Concurrency (Fifth Preview)", JDK 25) and its shape has changed
  between previews: `open()` is now a static factory taking a `Joiner`, and `join()` returns the Joiner's result
  or throws `StructuredTaskScope.FailedException` — the `scope.join().throwIfFailed()` form the rule taught is
  gone. Corrected, marked as needing `--enable-preview`, and `CompletableFuture` named as the portable choice
  rather than the fallback.
- **`rules/migration-backend.md` put a literal `N` in a `severity: must` fingerprint** — "route handlers with
  > N lines of business logic". An unresolved threshold in a MUST is unenforceable, and there is no
  project-independent line count that means "fat controller". Re-stated as what the logic *is*: branching on
  domain state, computing money / totals / eligibility, or orchestrating more than one repository call.
- `commands/add-endpoint.md` asserted `400` as the invalid-body status in its gate, its e2e test name and its
  Phase-6 ledger — the same `400`-vs-`422` disagreement fixed in `error-handling.md`. Now asserts *the project's
  declared validation-failure status*, so the gate reads the decision instead of restating one side of it.

**Enforceability**

- **`api-consistency-audit` emitted six closure verbs its own consumer rejects.** `validate-polish-artifacts.sh`
  defines a closed 15-verb `API_CONSISTENCY_VERBS` set; detectors 8b–8g emitted verbs outside it, so any
  `/polish` run firing them had its whole artifact rejected. Those six are now **routed observations** that
  emit `routed_to:` and no `closure_verb:` — which is also the honest scope line, since four of them are
  additive capability rather than drift unification. The three disagreeing counts (frontmatter 16, body 21,
  validator 15) are reconciled: 22 fingerprints = 16 closure-verb detectors drawing on the closed 15-verb
  vocabulary + 6 routed observations.
- **`multi-tenancy.md` and `parallel-io.md` were the only two of 15 patterns with no detector block** — so
  the pack's highest-stakes axis was its least enforceable one, and `/polish` could not consume either.
  Both now ship `## Detectors (cite-or-halt)` + closure verbs, derived only from rules those files already
  state. Undecidable detectors are marked `[self-policed]` rather than faked.
- **`commands/analyze-module.md` could stamp a false green.** Phase 4 dispatched six agents, five of which
  ship in other packs, with no not-installed fallback — the only creation/audit command in the pack without
  one. On a backend-only install five axes silently no-op'd and the command still computed "0 blockers →
  ready to extend". Added the pack's standard inline-fallback sentence and a coverage-first verdict:
  any axis neither dispatched nor covered inline forces INCOMPLETE with the axes named.
- **`skills/env-diff` claimed a wire that did not exist** (`Used by @bug-investigator`, zero references in
  that agent). Made true in **both** directions rather than deleted: `/fix-bug` Phase 3 and
  `@bug-investigator`'s new Evidence-gathering § Config drift both route the "works in one environment but not
  another" signal to `env-diff` before the handler is read, and the skill's `## Related` now names those two as
  its only callers, so a rename has a checkable blast radius.
- **`_topics.md` generated two agents nobody could dispatch.** It templated the pack's two central agents as
  `<stack>-architect` / `<stack>-reviewer` ("substitute the detected stack") while all nine commands dispatch the
  literal `api-architect` / `api-reviewer` — so a project that ran AUTHOR mode got a *richer*, stack-specific
  agent that was **unreachable**, and `/add-endpoint`'s production-readiness gate silently fell back to its
  weaker inline review path. Both entries are now canonical names carrying the reason inline; the apply-step no
  longer says "substitute templated names" but "resolve ROLE references, never artifact NAMES — the stack goes in
  the CONTENT". `trace-flow` and `refactor` ship in `commands/` and had no entry at all; both are now registered
  with `_examples/` fallbacks. A preamble states why topic count deliberately differs from file count
  (extraction-only topics carry `fallback: stub-from-sections` and have no shipped counterpart), so the next
  reader does not "reconcile" them away against a directory listing. `validate-pack-consistency.sh` catches the
  unregistered-file case; **nothing catches a topic whose `name:` diverges from the filename other artifacts
  dispatch by**, which is why those two entries now carry a comment.
- **`agents/api-reviewer.md` + (SEC-03) bearer-token validation floor.** Where the service validates a token
  itself rather than receiving an already-verified principal from a gateway, review now requires a pinned key set
  (JWKS re-fetched on unknown `kid` so rotation works), explicitly pinned algorithms (`alg: none` and
  algorithm-confusion rejected), and **both** `aud` and `iss` plus `exp` — with a grep per check and its own
  verdict-table row. A decode-without-verify on a user-reachable path is a BLOCKER, not a REQUEST. Pointer-only
  to the security pack for token lifetime / rotation / revocation depth, because "the security pack wasn't
  installed" is not a reason to ship an unvalidated `aud`.

**Depth**

- `api-contract.md` +§ Resource naming and URL structure — plural collections, kebab-case segments,
  verb-free paths, and the sanctioned `POST /v1/{resource}:verb` custom-method escape hatch
  (Zalando #134/#129/#141; Google AIP-136), plus a `resource-naming-drift` detector in
  `api-consistency-audit` that reuses the in-vocabulary `unify-naming` verb rather than inventing a 16th.
  The pack previously had **one** hit for path-naming doctrine across every agent, rule, pattern, command
  and skill — and it was about directory names.
- `api-contract.md` + the envelope-vs-RFC-9457 decision table. The pack had four incompatible envelope
  descriptions across four files; they are now one recorded, exclusive choice.
- `api-versioning.md` + a date-pinned/rolling strategy row, and the fork condition on the URL-path
  recommendation (Zalando forbids it at MUST level — #115; that has to be a recorded decision, not a
  default). Safe-vs-breaking classification de-duplicated: `api-contract.md` owns the table, this file
  owns what happens after.
- `caching-strategy.md` TTL table gains a why/what-breaks column — a halt condition that says "cite the
  table" is theatre when the table is nine unexplained numbers. Hit-rate "target > 90%" replaced with the
  inequality to compute. Redis-as-store vs Redis-as-cache stated, so the file's own Detector 4 stops firing
  on `backend-principles` PERF-6.
- `parallel-io.md` ships in **minimal** mode and shipped as a half-filled template, with a bare
  `<projectPrimitive>` token inside a fenced code block. Degraded behaviour on empty extraction is now
  specified in a table, the placeholder is valid syntax that fails loudly, and the empty
  "Examples from THIS codebase" heading is gone.
- `skills/endpoint-test` absorbs the conditional cases (rate limit, ETag/`If-None-Match` → 304,
  `202` + `Location` hand-off, streaming terminal marker) and states the triad's ownership split;
  `commands/endpoint-test.md` shrinks to argument resolution + hand-wave halt + escalation routing.
- `commands/refactor.md` cut from four gates to two. Layering, error envelope, DTO stability and "use DI"
  are already MUSTs in the always-loaded rule. What survives is what the universal command cannot know:
  on a backend the **wire is the observable**, so a DTO/route/error-code rename is a contract change
  wearing a refactor's clothes; and the injection style must mirror the sibling, not introduce a second one.
- `skills/api-snapshot` + § What the snapshot does NOT cover. `api-reviewer` ENF-4 exempts streaming
  handlers from `response_model` checks, so a streaming route has nothing for `oasdiff` to compare and
  passes by construction — a false guarantee nobody had written down. Also requires the emitted spec
  version to be recorded and reviewed on its own.
- `rate-limiting.md` + a per-caller-class key dimension for APIs called by autonomous agents as well as
  humans, with an explicit refusal to quote a number for it.
- **All five agents re-cut against each other.** Every `description:` was a capability blurb — it said what the
  agent could do and nothing about when NOT to fire, so the five overlapped at the edges and the dispatcher had
  to guess. Each now carries an explicit trigger set plus a named anti-trigger set that points at the sibling
  that actually owns the case, and each agent's opening paragraph defines it against the other four:
  `api-architect` works before anything exists, `api-reviewer` judges what does, `bug-investigator` explains what
  misbehaves, `endpoint-tester` proves the wire, `websocket-engineer` owns what outlives a request.
  `api-architect` gains a five-lens design rubric (boundary correctness · contract stability · failure shape ·
  cost to change · operability) and a refusal to ship a single-option design where a real fork exists — mirroring
  the closest sibling is now stated as the floor, not the standard. Every agent's sibling section is a *boundary*
  section, and cross-pack pointers are marked pointer-only so depth stays where it is owned.
- **`endpoint-tester` was a second copy of the `endpoint-test` skill** — its own curl commands, its own five-call
  flow, its own results table, all duplicated from the runnable primitive and free to drift from it. Cut to
  selector-plus-verdict: it decides which cases this route needs beyond the mandatory five, drives the skill, and
  returns one consolidated verdict. The instruction is blunt, because this is the failure mode that recurs — "if
  you find yourself writing a curl command or a results table into this agent's output, stop."

**Known gaps (verified open after this pass)**

- **35 of the 36 `_examples/` fallbacks were not re-based**, and three of them now teach something this pass
  fixed at the source. `_examples/error-handling.md` still declares `constructor(message, context, cause)`
  positionally and its own "RIGHT" call sites still pass `{ cause: e }` into the `context` slot — the exact
  provider-error leak corrected above. `_examples/rate-limiting.md` still teaches the legacy triple, plus a
  `RateLimit-Policy: 100;w=60` line that is neither the old form nor the new one (unquoted policy name, no
  `qu`). `_examples/api-contract.md` still mandates one fixed envelope where the source now records an exclusive
  choice between an envelope and RFC 9457. These are COPY-mode last-resort fallbacks — they reach a project only
  when extraction produced nothing — so the blast radius is narrow, but a fallback that teaches a fixed bug is
  worse than no fallback.
- **No gate compares a CHANGELOG entry's declared scope against the directories the diff actually touched.**
  The 1.13.0 entry above was wrong in exactly that way before this correction — it named three directories and
  shipped six — and all 18 gates stayed green through it. `validate-pack-consistency.sh` only checks that a
  heading matching `_version.json`'s version exists.

## 1.12.0 — 2026-07-10

- add-endpoint Phase-6 Production-readiness gate: 7-row floor ledger (edge validation · error
  envelope · txn boundary · idempotency-where-required · no N+1/unbounded · authz-not-authn ·
  log+metric+trace), each MET only with cited evidence or n-a-with-reason, else INCOMPLETE —
  replaces the bare Status: COMPLETE.
- api-reviewer: two new production-floor detectors — AUTHZ (authn-is-not-authorization; BLOCK
  id-scoped handler with authn but no ownership/role check, closed by a 403-denial test not 401) and
  TXN (transaction-boundary-as-unit-of-work); Coverage table becomes an evidence-required verdict
  (MET/UNMET/SKIPPED, no faked pass).

## 1.11.0 — 2026-07-09

- ai-patterns +1: request-validation — inbound-validation strategy (single-boundary
  validate/normalize, writable-field allow-list vs mass-assignment, bounds + content-type/body-size
  limits, 422 field-error contract). Fills the gap between error-handling (envelope) and
  api-contract (evolution). Backing MUST + review-checklist item in backend-principles.

## 1.10.0 — 2026-07-09

- NEW gap specialists: ai-patterns/transaction-boundary.md (intra-service write-set atomicity —
  service owns the boundary, no external I/O in tx, optimistic version-guard vs pessimistic FOR
  UPDATE, deadlock-safe lock ordering; cross-service outbox/saga deferred to distributed-systems; 5
  detectors); ai-patterns/file-upload.md (size cap → 413, magic-byte type validation not header,
  presigned direct-to-storage, stream-not-buffer, uuid keys/path-traversal, malware scan, safe
  serving headers; 6 detectors); skills/migration-safety.md (online-safe/reversible migration
  verifier —
  blocking-index/NOT-NULL-no-backfill/same-deploy-rename/edit-applied/non-reversible-down/in-tx-backfill/FK-without-NOT-VALID;
  per-tool+engine Adapt table; full scanner spine). Registered the 2 patterns in _topics +
  _essentials (signal-gated); abridged _examples for all 3.
- #5 cross-link hygiene: every agent Related now has a ### Skills subsection
  (api-reviewer→api-snapshot/api-consistency-audit;
  bug-investigator→log-tail/debug-tenant/endpoint-test; api-architect→module-scaffold;
  endpoint-tester→endpoint-test; websocket-engineer→none honestly). api-reviewer Output prose
  Areas-reviewed → a 10-row coverage/pass-fail table. bug-investigator model sonnet→opus + its
  WhatsApp/Meta/Claude/Stripe/Twilio example genericized to neutral placeholders. endpoint-tester
  relabeled as the orchestrator of the endpoint-test primitive (dedupe). Boilerplate pattern lists
  curated per agent (api-architect +rate-limiting/async/pagination/conditional; websocket-engineer
  +response-streaming). The 6 skills lacking ## Related
  (api-snapshot/debug-tenant/endpoint-test/env-diff/log-tail/module-scaffold) each got one with the
  orchestrating agent named.
- #6 detector retrofit: the 4 older ai-patterns gained the standardized ## Detectors (cite-or-halt) +
  closure-verbs block, derived from rules they already state — api-contract (bare envelope / ORM
  leak / breaking-field-no-version / unvalidated DTO / changed code), error-handling (raw throw on
  user path / stack-in-body / not-in-single-mapper / catch-log-throw / 500-where-4xx),
  caching-strategy (no-TTL / missing-tenant-prefix / no-stampede-protection /
  cache-correctness-critical), api-versioning (break-in-live-version / overlap-no-deprecation /
  no-sunset-tracking / version-mixing). One section vocabulary across all patterns.

## 1.9.0 — 2026-07-09

- skills/api-consistency-audit.md: brought the flagship scanner to the authoring standard. Renamed ##
  Purpose → ## Premise + added the cite-or-halt statement (finding = <method path> + <file:line> +
  canonical-violated + closure verb, never invented). NEW ## Adapt to the codebase per-framework
  primitive table (NestJS/DRF/FastAPI/Spring/Express/Rails/Laravel — where the
  envelope/error/limiter/ETag/pagination live). NEW ## False positives / gotchas
  (single-consistent-shape-is-not-drift, tier-scoped variation OK, opt-in detectors, declared
  exemptions, ownership-pointers-not-respecify). Renamed ## When to use → ## When to run and ##
  Failure modes → ## Halt conditions (+ added the missing-citation and not-backend halts). Fixed the
  ai-patterns/ → ai/patterns/ deploy-path drift (9 refs) that dangled post-install, unlike every
  sibling.
- rules/backend-principles.md: reconciled with the patterns/agents that enforce concerns the rule
  was silent on. NEW MUSTs — single response envelope (mixing shapes is drift; RFC 9457 error body);
  content negotiation (415 on bad Content-Type, 406 on bad Accept, Vary on negotiated/auth-varied
  responses). NEW SHOULDs — optimistic concurrency (strong ETag + If-Match on contended writes,
  412/428, read If-None-Match→304); N+1 prevention deferred explicitly to database+performance
  (n-plus-one-scan) with the api-reviewer inline floor. NEW ## Related block linking all 11 in-pack
  patterns + concurrency-discipline/migration-backend + the four cross-pack owners. Softened the two
  dangling in-pack ai/patterns/idempotency.md references to the distributed-systems idempotency
  pattern (it does not ship in the backend pack). Two review-checklist rows added.

## 1.8.0 — 2026-07-09

- references: backfilled the "Resilience, streaming & conditional requests" block into the six
  references that shipped none of it. laravel (throttle/RateLimiter::for, SetCacheHeaders ETag,
  response()->eventStream SSE, ShouldQueue → 202, cursorPaginate); dotnet (AddRateLimiter
  partitioned, EntityTagHeaderValue + RowVersion→412,
  IAsyncEnumerable/TypedResults.ServerSentEvents, Channel<T>+BackgroundService→202, EF keyset);
  flask (flask-limiter, Werkzeug make_conditional, stream_with_context, Celery/RQ→202, SQLAlchemy
  keyset); go (x/time/rate, manual ETag/304, http.Flusher/io.Pipe, hibiken/asynq→202, keyset);
  phoenix-elixir (PlugAttack/hammer, Plug.Conn ETag + Ecto optimistic_lock, send_chunked, Oban→202,
  Ecto keyset; Channels/LiveView vs HTTP-streaming noted); hexagonal-nestjs kept lean
  (interface-layer note pointing at nestjs.md + a hexagonal pagination port, no duplication).
- references: added a framework-native Pagination section to the six references that already had the
  resilience block but no pagination — django (DRF CursorPagination), express (hand-wired keyset +
  opaque cursor), fastapi (fastapi-pagination / SQLAlchemy tuple_ keyset), nestjs (nestjs-paginate /
  TypeORM+Prisma keyset), rails (pagy keyset), spring-boot (Pageable/Slice + Spring Data 3.1
  ScrollPosition.keyset). Closes the only axis that was absent across all 12 references while being
  a MUST.

## 1.7.0 — 2026-07-09

- NEW ai-patterns/pagination.md (kind:pattern, always:true) — the pagination specialist.
  Cursor(keyset)-vs-offset decision table, six rules (default+max limit, stable total sort with PK
  tiebreaker, opaque cursor, keyset-predicate-matches-sort, avoid COUNT(*) per page via
  limit+1/hasMore, single-envelope meta), six cite-or-halt detectors (unbounded list / no-cap limit
  / offset-on-hot-table / unstable-sort / count-per-page / envelope-drift) + closure verbs.
  Registered in _topics + _essentials; fallback _examples/pagination.md.
- add-endpoint.md Phase-4 enforcement table: NEW API-8 row — a GET list/collection endpoint applies
  default+hard-max page size, stable sort with unique tiebreaker, cursor for growing tables,
  envelope meta, no COUNT(*) per page; e2e asserts over-cap limit is clamped and pages do not
  drop/repeat rows. Closes the one MUST that was checked only at review time and absent from every
  reference.

## 1.6.0 — 2026-07-09

- NEW ai-patterns/webhook-flow.md (kind:pattern, signal-gated on webhook grep evidence) — the
  backend webhook specialist. Inbound: raw-body-before-parse, timing-safe signature verify,
  replay/timestamp-window + event-id dedupe, ack-fast-process-async, correct 2xx/4xx/5xx semantics.
  Outbound: HMAC signing + rotation, at-least-once + stable event.id, exponential backoff + jitter,
  DLQ + auto-disable dead subscriptions, subscription mgmt + delivery log, no-ordering-guarantee.
  Seven cite-or-halt detectors (BAD/GOOD) + closure verbs. Registered in _topics + _essentials;
  fallback _examples/webhook-flow.md. Un-dangles the webhook-flow / webhook-signature-verification
  references in add-feature.md + trace-flow.md that pointed at a nonexistent artifact.
- NEW ai-patterns/multi-tenancy.md SOURCE — the _topics entry + _examples/multi-tenancy.md existed
  with no backing source (validate-pack-consistency orphan WARN). Authored the canonical pattern
  (overview / resolution_chain / context_propagation / automatic_filtering / manual_bypass_rules /
  testing_isolation / pitfalls), genericized off the example project-name leaks. debug-tenant now
  has a pattern to cite.
- Technical-error + currency fixes: (a) Deprecation:true is invalid under RFC 9745 (a Date
  structured field) — corrected to @<unix-date> in api-versioning.md, agents/api-reviewer.md, and
  _examples/api-versioning.md; api-contract.md was already correct. (b) concurrency-discipline.md
  Enforcement claimed Pyright reportAwaitInsideLoop (nonexistent) and golangci-lint noctx (unrelated
  to await-in-loop) — removed the fabricated mappings (enforcement-theater), kept the valid ESLint
  no-await-in-loop and pointed Python/Go at review convention. (c) websocket-engineer.md
  nhooyr.io/websocket → github.com/coder/websocket (moved 2024). (d) caching-strategy.md MySQL query
  cache (removed in 8.0) reworded. (e) parallelize-independent-ops.md Go loop-var shadow annotated
  as pre-1.22. (f) add-endpoint.md STACK ASSUMPTION frontend leak (Vue3+PrimeVue) → NestJS.
  RateLimit-* confirmed still an IETF draft as of 2026-07 — no change.

## 1.5.0 — 2026-06-25

- NEW ai-pattern rate-limiting.md (RES-1, the single biggest confirmed gap) — server-side inbound
  self-protection: algorithm decision table (fixed/sliding/token-bucket/GCRA), key dimensions
  (per-tenant fairness, never a shared global counter), distributed atomic counter store (Redis Lua
  / CL.THROTTLE, FAIL-OPEN vs FAIL-CLOSED), 429 + Retry-After (RFC 6585 / RFC 9110) + RateLimit-*
  (IETF draft) response contract, quotas vs rate limits, load shedding / 503 admission control,
  cite-or-halt detectors + closure verbs, per-framework limiter table.
- NEW ai-pattern conditional-requests.md (API-1) — HTTP conditional requests + optimistic
  concurrency (entirely absent before): strong/weak ETag, If-None-Match → 304 read revalidation,
  If-Match → 412 / 428 write preconditions mapped to a version column inside the write transaction,
  RFC 9110, detectors + endpoint-tester cases.
- NEW ai-pattern response-streaming.md (PERF-1) — stream unbounded results (NDJSON/SSE/chunked)
  instead of buffering: transport decision table, the mid-stream terminal-error-sentinel rule (no
  5xx after flush), per-stack backpressure, idle/total timeout + disconnect cancellation, keyset
  cursor, LLM token cap+metering, RFC 9112.
- NEW ai-pattern async-job-offload.md (PERF-3) — the 202 Accepted + Location + job-status
  state-machine contract, idempotent submission, result TTL, graceful-shutdown drain; consumer
  mechanics (visibility timeout / DLQ) REFERENCE distributed-systems, not duplicated.
- api-reviewer: added rate-limiting axis, a Contract-evolution BLOCK block (Deprecation RFC 9745 +
  Sunset RFC 8594 + ADR), perf detectors (unbounded buffering / projection / 202-offload), streaming
  caveat, content-negotiation (415/406/Vary), mass-assignment (→forms) + SSRF (→security-auditor
  A10) probes, metric-cardinality + RED-triad + readiness/shutdown checks, External-calls floor
  thickening (→distributed-systems resilience-reviewer).
- add-endpoint: signal table gained rate-limit / async-202 / streaming / bulk-batch /
  conditional-write / over-post-bind / user-supplied-URL-SSRF / sensitive-mutation-audit rows +
  Phase-6 websocket-engineer-on-stream and Deprecation/Sunset-on-breaking-diff dispatch.
- api-consistency-audit: NEW detectors rate-limit-enforcement-missing, etag-conditional-drift /
  optimistic-concurrency-missing, batch-endpoint-contract-drift, field-selection-drift,
  security-header-drift; error-contract canonical shape updated to RFC 9457.
- backend-principles: added Must — rate-limit unauthenticated/expensive endpoints; Must-not —
  request/per-user state in process memory (statelessness for horizontal scale); idempotency
  stored-replay cross-ref; outbound-resilience + observability-DoD Should pointers.
- api-contract: added Bulk/batch (207 Multi-Status), Field-selection/expansion, Response-compression
  (Vary + BREACH/CRIME halt), and Response-shaping/body-size (413) sections.
- error-handling: RFC 7807 → RFC 9457 (+ application/problem+json + stable type URI); 429 row gained
  RateLimit-* emission (IETF draft, not RFC 9239).
- endpoint-tester: conditional-request (304/412/428 + lost-update), content-negotiation (415/406),
  rate-limit (429), and async-202 test cases.
- Framework reference bindings (rate-limiting / conditional-requests / streaming / async-jobs) added
  to nestjs, fastapi, express, django, spring-boot, rails; references/dotnet.md ProblemDetails RFC
  7807 → 9457.

## 1.4.0 — 2026-06-16

- add-feature: NEW prior-art gate (all tiers, before tier selection) — searches by behavior for an
  already-shipped capability and HALTs to the user on a near-duplicate; sibling-mirror copies a
  shape but never catches feature duplication.
- add-feature: NEW new-dependency gate (all tiers, Phase 4) — a package no sibling imports halts for
  a dependency review (maintenance / license / supply-chain / size); decision recorded in PR
  (trivial/standard) or ADR (heavy / auth / crypto / payment / data). Added matching invariant.
- add-feature: standard-tier closure-verb row now requires n-plus-one-scan on any new list/query
  endpoint (was heavy-tier-only); catches slow queries before they ship.
- fix-bug: NEW new-dependency gate (enriched-superset guardrail) — a fix that grows the dependency
  tree halts for a dependency review and re-confirmation that the root cause can't be closed with an
  existing primitive; added invariant + hard rule + Phase 4 Minimal-fix note. Baseline fix-bug left
  minimal by design.
- _examples/add-feature.md + _examples/fix-bug.md regenerated faithfully from their (now-gated)
  command sources.

## 1.3.2 — 2026-06-14

- api-consistency-audit skill: added `name:` frontmatter field (was missing).

## 1.3.1 — 2026-06-13

- add-feature: added the mandatory '## Phases applied' declaration block (canonical line 27) — was
  the lone add-feature variant missing it.
- add-feature + fix-bug: wired the universal --plan handoff flag via templates/snippets/plan-flag.md
  (honours the docs/COMMANDS.md universal-flag contract).
- add-feature: sibling-shape halt now links the shared verdict vocabulary
  (templates/snippets/sibling-shape-halt.md); 'no-siblings-found' → 'no-siblings'.
- fix-bug: added enriched-superset banner naming the repo-baseline as the universal-minimum subset;
  both link the shared invariants in templates/snippets/fix-bug-core.md (failing-test-first +
  similar-bugs ledger).
- _examples/add-feature.md + _examples/fix-bug.md regenerated faithfully from their command sources
  (the stale snapshots contradicted the source — fix-bug example said 'BEFORE fixing'); added
  generated-from headers.

## 1.3.0 — 2026-06-10

- add-feature + _examples/add-feature: rename payment-idempotency-reviewer → payment-reviewer (the
  agent that actually ships in domains/payment/agents/); drops the '(if present)' hedge so payment
  features no longer silently skip specialist review.
- add-feature + _examples/add-feature: missing-agent fallback rule — any dispatched agent not
  installed in the project is performed inline against its pack/domain checklist and noted as
  inline:<agent-name>; never silently skipped. Applied to Phase 2 architects and Phase 6 reviewers.
- add-feature + _examples/add-feature: NEW Release pre-flight (heavy tier) in Phase 6 — feature-flag
  decision, expand→migrate→contract migration ordering, one-sentence rollback path ('cannot roll
  back' requires ADR), staging verification note. Closes the missing release stage in the lifecycle.
- add-feature + _examples/add-feature: hard rules scoped to tier ('never skip phases within your
  tier's ceremony'; Phase 1/2 pauses are heavy-tier only) — removes the contradiction with the
  closure-verbs tiering table.
- add-feature + _examples/add-feature: trivial/standard output template added — runs without
  architects/reviewers no longer report against the heavy-tier template.
- fix-bug / add-endpoint / add-module: payment-reviewer dispatch row added (payment signal parity
  with add-feature) + missing-agent inline fallback rule.

## 1.2.0 — 2026-05-03

- Add rules/migration-backend.md (79 lines): backend audit axes (endpoints / DTOs / auth+permissions
  / validators / side effects / service-layer / error contract / tenant isolation / transaction
  boundaries), stack-aware primitive set covering 13+ frameworks (NestJS / Express / Fastify /
  Laravel / Django / FastAPI / Flask / Rails / Sinatra / Spring / Go / Phoenix / ASP.NET),
  Transposition Trap fingerprints, Phase 3 (Retrieve) backend specifics.
- _topics.md gains migration-backend rule entry (gated by migration_layout_detected trigger).
- Closes drift: 9 cross-references to backend/rules/migration-backend.md across migration + align
  packs now resolve.

## 1.1.0 — 2026-05-03

- Adds api-consistency-audit skill (backs /polish on backend stacks).

## 1.0.0 — 2026-04-26

- Initial backend pack release.
