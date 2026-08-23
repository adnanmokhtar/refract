# security pack — changelog

Release history for `templates/packs/security/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.8.1 — 2026-08-23

**`_examples/data-privacy-reviewer.md` carried the boundary as unlabelled prose.**
Its `## Related` did describe each sibling's ownership, but with no boundary marker and none of the
three cross-pack splits its source states explicitly: `threat-model` is DESIGN-time (LINDDUN cards
before the component exists) while this agent is REVIEW-time on existing code;
`database/data-retention-pii` owns the storage mechanics (classification, TTL/purge,
erasure-vs-FK-cascade, at-rest encryption) while this agent owns the code data-FLOW and the
regulatory article mapping; `observability/audit-logging` owns the log schema and is *also* a
secondary PII store this agent must sweep. Both bullets are now labelled `**Boundary:**` /
`**Cross-pack boundary:**` and carry those splits.

Held mechanically from now on by `validate-pack-consistency.sh` check 8b `BOUNDARY-LOSS`.

## 1.8.0 — 2026-08-22

- **CSRF: the pattern names the control that actually holds, and why the popular one does not.**
  `ai/patterns/auth-flow.md` gains a `## CSRF` section scoped to cookie-authenticated
  state-changing requests. Two controls qualify — a synchronizer token or a *signed*, session-bound
  double-submit — and the naive double-submit is called out as bypassable "by an attacker who can
  write cookies on the target domain (e.g., via a vulnerable sibling subdomain, DNS takeover, or
  plaintext-HTTP cookie injection on a non-`__Host-` cookie)", which on subdomain-per-tenant SaaS
  is the ordinary deployment rather than an exotic precondition. `SameSite` and `Origin` are stated
  as defence-in-depth, quoting OWASP that `SameSite` "does not replace a proper CSRF defense in most
  deployments", with the reason: the `Lax` default only blocks unsafe methods and its scope is the
  registrable domain, so it does not separate sibling subdomains. Sourced to the OWASP *Cross-Site
  Request Forgery Prevention Cheat Sheet*.
- **`security-principles`: 7,480 → ~6,650 characters (~1,870 → ~1,661 always-loaded tokens),
  clearing the debt left when this file *grew* by 77 characters under a release that was asked to
  shrink it.** The CSRF bullet no longer restates the `Origin`/`Referer` defence-in-depth point the
  Must-not section already makes; the transport and header bullets are one; and the HSTS number
  stopped being folklore — `max-age >= 31536000` is the HSTS preload list's stated minimum
  (https://hstspreload.org), and the bullet now also names `preload` itself, without which the
  header does nothing on the first visit, which is the visit an attacker wants.

## 1.7.0 — 2026-08-22

Quality pass over the four commands, four skills and three ai-patterns (1.6.0 covered the agents +
the rule). Same question throughout: if a developer relies on this, do they produce better work
than without it? Every external claim below was fetched at the URL cited in the artifact.

FIXED (wrong specifics — each re-fetched, not recalled)
- **deps-audit's CRITICAL exemplar named the wrong package, class and fix version.** It shipped
  `axios@0.21.4 CVE-2024-28849 SSRF Fixed: 1.7.4`. CVE-2024-28849 is **follow-redirects**, and the
  flaw is that it *"only clears authorization header during cross-domain redirect, but keep the
  proxy-authentication header which contains credentials too"*, fixed in **1.15.6**
  (nvd.nist.gov/vuln/detail/CVE-2024-28849). Three wrong facts in the row a developer copies.
- **CVE-2021-23337 was mislabelled in three places and self-contradicting in one file.**
  NVD: *"Lodash versions prior to 4.17.21 are vulnerable to Command Injection via the template
  function."* The skill and `/dependency-vuln-check:9` both said "prototype pollution"; the same
  command's table at :111 said "High (RCE)" — a different label 100 lines below its own, under a
  mechanical halt (`finding.cve_id == advisory.id`) that the example itself failed. Both files now
  carry the class from the record, and both halt blocks now say so explicitly.
  (node-forge CVE-2022-24771 → 1.3.0 and semver CVE-2022-25883 → 5.7.2/6.3.1/7.5.2 were re-fetched
  and were correct; node-forge's class is stated more precisely.)
- **gitleaks `detect` / `protect` were deprecated in v8.19.0** — still functional, hidden from
  `--help`. The skill shipped `gitleaks protect --staged`. Now `gitleaks git --staged` /
  `gitleaks dir .` / `gitleaks git . --log-opts=…`, verified against the flag registrations in the
  tool's own `cmd/git.go` (`--staged`: "scan staged commits (good for pre-commit)").
- **The dangling dispatch, closed from the other side.** ssrf-scan claimed three times that
  `@security-auditor` dispatches it; that agent contains zero occurrences of "ssrf-scan", and
  `/security-audit` — the pack's entry point — dispatched six agents and **zero skills** while its
  Phase 4 buckets promised secret, dependency and SSRF coverage. Rather than delete the claim,
  Phase 2 now dispatches all three skills by signal, and the skills' inbound references were
  re-pointed to the caller that actually exists. `/secret-scan` and `/dependency-vuln-check` now
  name the skills they orchestrate; neither did.
- **zero-trust contradicted itself on the owner's most important control** — "row-level tenant
  isolation at the DB" was Tier 1 (do first) at :90 and "row-level security in DB" was Tier 3
  (mature) at :104. These are two different controls: *the app cannot forget the filter* (tier 1,
  universally available) and *the engine refuses the row even if the app forgot* (tier 3, only on
  engines that have it). Both now stated, with the distinction called out.
- **The engine-conditional fix, propagated.** `tenant-isolation.md:19` named Postgres RLS inside a
  universal pattern and its fallback dropped even the "where the DB supports it" hedge. The layer
  is now a capability table, and its grading rule is aligned verbatim in intent with
  `@tenant-isolation-reviewer § Grading layer 2` so the two cannot diverge: engine supports a
  mechanism and the project declined it → HIGH; engine supports none → MEDIUM as an accepted limit
  with named compensating controls. `/security-audit`'s DEPTH rule carries the same carve-out, so a
  run on an engine without the feature can still reach a clean GO.
- **Two worked examples failed their own halt conditions.** The threat-model skill halts on
  "mitigations recorded as prose … without a ticket id or `<path:line>`" and then showed six
  mitigations that were all prose. `/threat-model`'s three threat tables did the same. Every row
  now carries persona + `<path:line>` + EXISTS/PARTIAL/MISSING, which is what the halts demand.
- Fallback drift repaired: `_examples/security-audit.md` dispatched 2 of the 6 reviewers (no
  api-security, data-privacy or llm-security), pointed Phase 3 at a `payment-integration.md` the
  source had removed, and carried stack-specific wording (`createQueryBuilder`,
  `eslint-disable security/*`) the source had deliberately genericised.
  `_examples/auth-flow.md` had no passkeys/WebAuthn section at all while the source calls passkeys
  the phishing-resistant baseline. `_examples/threat-model.md` named PostgreSQL and Stripe where
  the source is engine- and vendor-neutral.
- `_topics.md`: `dependency-vuln-check` declared `fallback: stub-from-sections` with **no
  `sections:` list**, so a no-signal project received an empty skeleton. It now declares the source
  as its own fallback (the shape phase-4.2-apply.md step 2 provides for). ssrf-scan's trigger regex
  gained the redirect tokens its new detector needs.

IMPROVED (correct, but not yet doing its job)
- **The two skill/command pairs were judged separately, and they came out differently.**
  *secret-scan* is a deliberate split — near-zero overlap, skill = detection primitive, command =
  remediation orchestrator — so both were kept and the missing wiring between them was added.
  *threat-model* was duplication: the six STRIDE letters appeared in both files 15 lines apart, and
  the command copied the skill's three halt conditions verbatim while labelling them an "import".
  The skill stays the dispatchable primitive; the command's copy is gone. Phase 2 now owns what the
  skill cannot — enumerating the data-flow legs — and adds the one halt that is a property of the
  document rather than a row: **a leg with no rows at all was not analysed.**
- **Both scanning skills now say how to read their output, not just how to run the tool.** A man
  page is a C. deps-audit § Reading the output: reachability is the reader's job everywhere except
  Go, because `govulncheck` alone does call-graph analysis ("prioritizing vulnerabilities in
  functions that your code is actually calling", go.dev/blog/govulncheck); "fix available" may be a
  major bump; severity is the advisory's blast radius, not yours; and `npm audit`'s exit code is
  governed by `--audit-level`, so a job that never fails is usually a threshold. secret-scan
  § Reading the output: exit `1` means **leaks *or* errors**, so CI must gate on the report body;
  the finding fields in the order that decides everything (`RuleID` → confirmation vs suspicion,
  `Commit` → already-shipped, `Author`/`Date` → the log window to audit); and a five-row table of
  what to DO per class, all of which start with rotate.
- **tenant-isolation now carries what a leak looks like, not only where one could be.** Three
  shapes with code: the query that left the scoped path (and its write-path twin, an IDOR that
  mutates — with the affected-rows assertion as the fix), the cache key without the tenant prefix
  (plus the three variants that pass a naive review: in-process memos, invalidation paths, derived
  caches), and the background job that lost its tenant context (where the danger is not the crash
  but the *fallback* to "all tenants"). Two new detectors: context lost across an async boundary,
  and a below-app layer that is claimed but inert — a policy the connecting role bypasses, a view
  whose base table is still granted, a pool not re-bound per tenant.
- **ssrf-scan ships instruments, not intentions** — five pre-flight `rg` commands (every one of
  them executed against a fixture before shipping), each tied to the detector it feeds, with two
  written as set differences so the *absence* of a hit is the finding. New detector 7, the open
  redirector: the same tainted URL with a browser-side sink, in scope because OAuth 2.1 makes it a
  client obligation — *"Clients MUST NOT expose URLs that forward the user's browser to arbitrary
  URIs obtained from a query parameter ('open redirector')… Open redirectors can enable
  exfiltration of authorization codes and access tokens"* (§ 2.3.1,
  datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-13). `@auth-reviewer` reached the same gap
  independently in 1.6.0, so the boundary is drawn by *shape* rather than by ownership: that agent
  audits the auth surface (login-return, post-logout, OAuth callback) where the redirector chains
  into code exfiltration; grep 5 here sweeps **every** redirect sink app-wide, including the ones
  no auth review reaches — an unsubscribe link, a legacy `?dest=` shortener — and hands auth-path
  hits back rather than re-deriving the chain.
- **auth-flow stopped naming algorithms and started naming parameters.** "Prefer argon2id, bcrypt
  cost ≥12" is not a control — m/t/p is. The numbers now come from the OWASP Password Storage
  Cheat Sheet **by URL**, with the instruction to re-read it at implementation time because the
  values move, and with bcrypt's **72-byte input limit** stated as the correctness trap it is: past
  72 bytes the tail of a passphrase is silently ignored and two different passwords verify against
  one hash.
- **zero-trust: 149 lines → 75.** The vendor catalogue (Istio, Linkerd, SPIFFE, Vault, OPA,
  Kyverno, Boundary, cosign), "Common mistakes" and "Threat models zero trust defends" are gone —
  all three were lists any competent engineer already has. What replaced them is a boundary table
  with a column that did not exist: **the probe that proves the check is real.** A boundary with no
  third column is aspirational. It was a deletion candidate; the cascade is what saved it — seven
  inbound references, five of them in the backend and code-quality packs, i.e. outside this pack
  entirely. Rewriting cost less than orphaning five files in two packs that were finished yesterday.
- **`/dependency-vuln-check`: 225 → 205 lines** with the fabricated exemplars replaced by cited
  ones. The aggregate-metrics block and the P0/P1/P2 effort table are gone (both restate any
  dependency dashboard), the CVE tables gained a **reachability** column because the scanner cannot
  supply it, version drift is reported only where it changes security posture, and the run now ends
  with the canonical `## What to do next` contract the pack's other two audit commands already use.
- `/security-audit` Phase 6 gained the two scans the external benchmark showed nothing in either
  pack owned: **interpolation that parameter binding cannot cover** (sort direction/column, table
  and column identifiers, `LIMIT`/`OFFSET` are not bindable in most drivers, so a fully
  parameterised codebase still concatenates them — the control is an identifier allow-list, not an
  escape function), and **traversal on the file-*serving* path** (the store side is the backend
  `file-upload` contract; `GET …?file=` is a different sink, and the assertion is that the
  *resolved* path is inside the intended root, not that `..` was stripped).

NOT DONE, DELIBERATELY
- No CVE, cipher, parameter or edition number was written from recall. Where a value moves with
  time — password-hashing parameters, ASVS chapter numbers — the artifact cites the source by URL
  and says to re-read it, rather than freezing a number that will be wrong later. ASVS references
  in `/threat-model` now name **5.0.0 (released 2025-05-30)** and forbid citing pre-5.0 chapter
  numbers from memory.
- zero-trust was **not** deleted despite grading lowest. See above: the deletion cascade reached
  two packs this pass does not own.


CORRECTED IN AUDIT (defects found in this release before it shipped)
- **The CSRF bullet in the always-loaded rule offered only the two mechanisms OWASP now rejects.**
  It read "double-submit cookie or `SameSite=Strict` + `Origin` check". The cheat sheet warns the
  naive double-submit "is bypassable by an attacker who can write cookies on the target domain" and
  that `SameSite` "does not replace a proper CSRF defense in most deployments"
  (cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).
  Neither the synchronizer token nor the *signed* double-submit appeared anywhere in the pack. On a
  subdomain-per-tenant SaaS the sibling-subdomain bypass is the ordinary case. Fixed in the rule,
  its fallback, and `auth-reviewer` + fallback. `Must not`'s "never trust `Origin`" line contradicted
  the fix and now distinguishes sufficient-control from defence-in-depth.
- **Probe C was silently false-negative on the dominant JS/TS spelling.** The client-tenant-id probe
  lacked `-i` (unlike the `x-tenant` line beneath it), so `[_-]?id` matched `tenant_id` and
  `tenantid` but not `tenantId`. Verified against a fixture: 2 of 5 cases matched before, 5 of 5
  after. The Output block printed `C client-tenant-id <n>` — a fabricated clean signal on the finding
  the agent calls a standalone BLOCKER. Both files now carry `-i`, plus a new halt: a zero-hit probe
  recorded without naming the vocabulary it searched is an unrun probe, not a passed one, and the
  output line now carries `(vocab: <terms>)`.
- **The "Numbering note" explained an inconsistency instead of removing it.** The pattern called the
  below-app control item 3 of seven; the reviewer called it "layer 2". Rather than document the
  clash, the vocabulary is unified — everything now says "the below-app layer", which is also
  self-describing where "layer 2" was not — and the note is deleted (30 sites across 6 files).
- Rule payback: the CSRF correction costs ~19 tokens net in `security-principles.md`, offset by
  trimming three padded example lists (package-manager auditors, CSPRNG APIs, CI tool names) that
  restated what the surrounding sentence already said.

## 1.6.0 — 2026-08-22

Quality pass over the six agents + the always-loaded rule. Fixes first, then the improvements that
make a reviewer produce better work than a competent engineer would without it.

FIXED (wrong specifics — each traced to a fetched source)
- llm-security-reviewer + its fallback: remapped to the **OWASP Top 10 for LLM Applications 2026**
  (released August 2026). Eight of ten IDs moved — Supply Chain 03→04, Data & Model Poisoning
  04→05, Improper Output Handling 05→10, Excessive Agency 06→03, System Prompt Leakage 07→08 AND
  renamed **Hidden Context Exposure**, Vector & Embedding 08→09, Misinformation 09→07, Unbounded
  Consumption 10→06. The pack had "LLM05 Improper Output Handling — the #1 code-security sink" as a
  HALT-backed claim; that class is now last. Two real coverage gaps closed with the renumber:
  **cross-modal prompt injection** (instructions carried in an image/audio input, invisible to any
  body filter) under LLM01, and Hidden Context Exposure's broadening beyond the system prompt to
  **retrieved policy text and tool/function schemas** in the context window. New halt: citing a
  2025 LLM number.
- api-security-reviewer:105 shipped `hasP` whose `P` was U+0420 CYRILLIC CAPITAL LETTER ER (bytes `d0 a0`), not ASCII `P` (`50`) —
  inside the API5 BFLA inverse-filter grep, so `hasPermission` never matched and every route
  guarded by it was reported as an unguarded admin function. False positives inside the exact check
  API5 exists for. Pack now has zero non-ASCII letters anywhere.
- security-auditor:162 cited "OWASP: A03 Injection" 91 lines below its own header declaring
  Injection is A05:2025 (A03:2025 is Software Supply Chain Failures). Both worked examples now
  carry explicit `A0X:2025` numbers, and citing a 2021 number is called out as tripping the file's
  own halt condition.
- security-auditor:71 asserted the 2025 edition was "finalized Jan 2026" — sourcing puts the
  announcement in Nov 2025 and a final in Jan 2026, so the date is dropped for the canonical URL.
  A09's label corrected to "Security Logging and **Alerting** Failures" (the 2025 rename; its
  bullets were already right).
- **The permanent-NO-GO bug.** tenant-isolation-reviewer graded "no RLS backstop" as an
  unqualified HIGH and escalated any HIGH to NO-GO, so on an engine with no native row-level
  security the run could never reach a clean GO and no fix existed. Replaced by § Grading layer 2:
  the second layer is graded against what the engine can actually enforce (native row policies /
  definer's-rights view with base-table grants revoked / per-tenant DB role / schema-per-tenant),
  MEDIUM-with-compensating-controls where none is available, and a new halt forbids grading it
  before naming the engine's real ceiling. Same correction applied to security-auditor's tenant row.
- `_examples/security-auditor.md` — the GREENFIELD fallback — carried the **2021** checklist under a
  banner claiming 2025 (A02 Cryptographic Failures, A03 Injection, A05 Misconfiguration, A06
  Vulnerable Components, A10 SSRF) and its example finding cited A03 for SQL injection. Fully
  remapped to the verified 2025 list; its Output block still offered "GO with conditions" while the
  section above defined the three-state verdict.
- Both `_examples/security-auditor.md` and `_examples/auth-reviewer.md` shipped with **no
  `## Related` section at all** — a greenfield project received reviewers that did not know their
  five siblings existed, in a pack whose value rests on six overlapping reviewers staying in lane.
- `_examples/security-principles.md` was four Musts behind its source (output encoding,
  mass-assignment allow-list, magic-byte upload validation, PII data-flow) and kept stack-specific
  wording the source had deliberately genericized.

ADDED
- **`_examples/tenant-isolation-reviewer.md`** — the topic declared `fallback: stub-from-sections`
  with a section list carrying no premise, no halt conditions and no siblings, so on greenfield the
  highest-value reviewer in this pack materialised stripped of its discipline. `_topics.md` now
  points at a real 160-line fallback.
- tenant-isolation-reviewer gains a "Probe kit" — it was the only reviewer in the pack with zero
  executable commands (its sibling api-security-reviewer ships 18). Six probes: an
  `information_schema` schema-coverage query that finds tenant-data tables with no tenant column at
  all — the one finding no code grep can produce, and the instrument its own "new tables since the
  last review" duty had always lacked — plus new-tables-since-ref, tenant-id-from-client-input,
  escape-hatch, unprefixed-cache-key, and jobs/consumers.
- auth-reviewer: a pre-flight grep block (it had none), and the **client-side open-redirector
  obligation** from OAuth 2.1 § 2.3.1 — the pack enforced the server-side exact-redirect-URI rule
  and never the client half, which is what actually exfiltrates authorization codes.
- security-auditor A01: path traversal (CWE-22) and open redirect (CWE-601) rows — both mapped
  under A01:2025 and both previously uncovered anywhere in the pack; the only path-traversal
  mention delegated to backend `file-upload`, which covers the store path only.
- **The parameterization carve-out** (rule + security-auditor A05): bind parameters cannot carry a
  table/column identifier, a sort column, `ASC`/`DESC` or `LIMIT`/`OFFSET`, so "parameterized
  queries only" is impossible to follow on every `?sort=` endpoint. Server-side allow-list map,
  cited to the OWASP SQL Injection Prevention Cheat Sheet.
- Rule: CSPRNG for tokens/session ids/nonces (present only in the auditor, absent from the
  always-loaded file that governs the developer writing the reset-token generator); password
  **parameters** (Argon2id m/t/p, bcrypt work factor) cited to the OWASP Password Storage Cheat
  Sheet by URL rather than a hard-coded number that would drift; indirect XSS *sources*
  (`postMessage`, WebSocket frames, third-party API fields, storage read-back); business-flow
  ordering and anti-automation.
- Skills wired into the agents that claimed them: security-auditor now names `ssrf-scan`,
  `deps-audit`, `secret-scan`, `threat-model` — `ssrf-scan` claimed an inbound
  `@security-auditor` dispatch three times against zero occurrences. api-security-reviewer's API7
  now dispatches `ssrf-scan` instead of paraphrasing it. `threat-model` disambiguated (skill for the
  STRIDE pass, command for the persisted artifact).

REMOVED
- rules/security-principles.md: the "Review checklist" section (11 boxes, each restating a Must 30
  lines above) and the "Enforcement" section (CI-runner configuration, which `/security-audit` and
  `/dependency-vuln-check` already own), plus the opening blockquote that restated four Musts a
  second time — roughly 2,470 characters of pure restatement out of an always-loaded file the
  budget gate cannot see. Both sections are gone from the fallback too.
- auth-reviewer's "Attack surface" section: four of its seven subsections restated the AuthN/AuthZ
  checklists above them verbatim (brute force, session fixation, IDOR, JWT confusion). Kept what is
  unique, added step-up bypass.

## 1.5.0 — 2026-07-10

- security-audit Mitigation-Verification Gate (Phase 4): each mitigation is probe-verified with a
  three-state verdict (VERIFIED / UNVERIFIED / EXPOSED) — 'this looks protected' is banned; no bare
  checkmarks.
- security-auditor Premise gains the defense-side symmetry: a mitigation you READ is not a
  mitigation you PROVED.

## 1.4.1 — 2026-07-10

- security-audit now dispatches ALL SIX specialist reviewers by grep signal (api-security-reviewer
  on API routes/serializers, data-privacy-reviewer on PII/logger/analytics/DSAR paths,
  llm-security-reviewer on prompt/tool/RAG/model-output sinks) — was 3 of 6; NO-GO now triggers on a
  blocker in ANY dispatched reviewer + dispatched-but-missing = incomplete. threat-model: removed
  the unbacked @security-auditor sign-off; enforcement honestly deferred to a follow-up
  /security-audit.

## 1.4.0 — 2026-07-09

- agents +1: data-privacy-reviewer (opus) — audits code for PII/PHI data-flow
  (collection->store->log->third-party egress), DSAR/right-to-erasure implementability, cross-border
  transfer + consent, mapped to the configured regime (GDPR/PDPL/CCPA) with article-cite discipline.
  Design-time LINDDUN stays with threat-model; storage mechanics with database/data-retention-pii.
  Backing MUST + sibling Related reverse-links.

## 1.3.0 — 2026-07-09

- NEW skills/ssrf-scan.md (kind:skill) — SSRF-egress scanner. Six detectors (user-URL-to-fetch no
  allow-list / no internal+metadata range block / hostname-not-resolved-IP DNS-rebinding /
  redirect-to-denied-host / dangerous schemes / IMDSv1). Per-stack Adapt table
  (Node/Python/Go/Java/Ruby/PHP sinks). Upload-egress note deferring inbound to backend file-upload
  while owning the security-specific SVG-XSS/polyglot/image-parser-CVE risks. Full scanner spine.
  Registered in _topics/_essentials; abridged _examples/ssrf-scan.md. Closes review gap #4.

## 1.2.0 — 2026-07-09

- NEW agents/api-security-reviewer.md (kind:agent, model:opus, api_surface_detected) — OWASP API
  Security Top 10:2023 reviewer. All 10 categories with concrete rg detectors + a GraphQL subsection
  (depth/complexity limits, prod introspection, batching, resolver authz). BOLA (API1) + both BOPLA
  modes (API3) graded BLOCKER. Full contract: Premise cite-or-halt + hand-wave hard-halt +
  verdict-matches-body, Pre-flight, checklist, graded findings, Verdict + API1..API10 coverage
  table, Hard rules, Related with negotiated boundaries (@tenant-isolation-reviewer owns the tenant
  boundary, this owns per-object ownership; complements @security-auditor web-app A01). Abridged
  _examples/api-security-reviewer.md.
- NEW agents/llm-security-reviewer.md (kind:agent, model:opus, llm_usage_detected) — OWASP Top 10
  for LLM Apps (2025) reviewer, high-value for this LLM-heavy repo. Domain Premise clause: model
  output + retrieved/tool content are UNTRUSTED input. All 10 classes (LLM01..LLM10) with detectors
  — undelimited RAG chunk in prompt (LLM01), completion → innerHTML/eval/SQL sink (LLM05 BLOCKER),
  write/delete/payment tool with no confirmation gate (LLM06 BLOCKER), missing max_tokens/cost cap +
  unbounded agent loop (LLM10). Cross-links security-auditor 2025 (LLM05→A05/A10, LLM06→A01).
  Abridged mirror.
- Registration + bidirectional cross-links: both agents added to _topics + _essentials;
  @api-security-reviewer + @llm-security-reviewer back-linked into the ## Related of
  security-auditor, auth-reviewer, and tenant-isolation-reviewer (bidirectional-links rule).

## 1.1.0 — 2026-07-09

- security-auditor.md: full OWASP Top 10:2025 remap of the checklist (was hardwired to 2021 — every
  finding cited a wrong class). SSRF absorbed into A01; A02 Security Misconfiguration; NEW A03
  Software Supply Chain Failures; A04 Crypto (alg:none/confusion, argon2id); A05 Injection now
  includes reflected/stored/DOM XSS with the framework sinks (the total gap D2); A06 Insecure
  Design; A07 Auth (OAuth 2.1, passkeys, DPoP); A08 Integrity; A09 Logging; NEW A10 Mishandling of
  Exceptional Conditions (fail-closed). Added BOLA/BFLA to A01, EPSS/KEV to A03. Supply-chain tail
  rewritten from assert-passed to dispatch-and-verify (image scan/SBOM/cosign executed by devops;
  report MISSING if no producer) — closes the enforcement-theater the review flagged.
- Currency + coverage: deps-audit schema-aware parser (npm7 .vulnerabilities / pnpm .advisories /
  osv-scanner) + EPSS/KEV triage; auth-reviewer OAuth 2.1 + WebAuthn ceremony detector + Related
  @tenant-isolation-reviewer + Skills subsection; auth-flow bcrypt<12 + passkey flow + Related;
  zero-trust Related; security-principles NEW MUSTs (XSS/output-encoding, mass-assignment,
  file-upload) + checklist rows; secret-scan +github_pat_/xox*/hf_/SG./Twilio/npm_ prefixes;
  threat-model LINDDUN + heading fixes; dependency-vuln-check EPSS/KEV/OSV. Heading drift (When to
  use->When to run) cleared pack-wide.
- NEW ai-patterns/tenant-isolation.md (security-lens invariant + 7 isolation layers + assume-breach
  review methodology + 6 detectors) — resolves the dangling ref from the flagship
  @tenant-isolation-reviewer + security-audit command; registered in _topics/_essentials;
  cross-links backend multi-tenancy for the impl shape. payment-integration dangling ref repointed
  (owned by backend/domain). _examples/{auth-reviewer,security-auditor} regain the condensed
  Premise+Halt spine so fallback-generated agents keep cite-or-halt.
