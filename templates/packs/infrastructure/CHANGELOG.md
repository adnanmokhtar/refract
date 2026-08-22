# infrastructure pack — changelog

Release history for `templates/packs/infrastructure/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.5.0 — 2026-08-22

Currency + the four-Kubernetes-artifact split. Every version claim in the pack now traces to a
release page that was fetched, or is replaced by the thing that DETERMINES the answer.

- **kubernetes-architect rewritten from a product catalog into the cluster operating model** (216 →
  181 lines: ~190 lines of vendor catalog deleted, ~150 lines of decision content added). It had
  zero dispatch anywhere in the repo and its
  load-bearing content duplicated infra-architect / k8s-reviewer / deployment-engineer. It now owns
  the one question nothing else answers — "is this workload worth a cluster, and what does the
  cluster cost you?" — plus cluster count, tenancy boundary, edge API, upgrade cadence, mesh yes/no.
  `@infra-architect` § "1. Compute platform decision" now DISPATCHES it on the Kubernetes branch,
  which previously handed off to nothing.
- **k8s-audit narrowed to the four axes only a running cluster can answer** (109 → ~120 lines, but
  ~70 lines of duplicated static checks removed): API removals, CIS/node posture, runtime-vs-declared
  drift, live utilisation. Everything decidable from a manifest is handed to `@k8s-reviewer` with an
  explicit boundary table, instead of being restated without thresholds or citations.
- **infra-architect** owns the platform threshold for the whole install (resolving the contradiction
  with devops `@devops-architect`'s different team-size numbers), and replaces headcount thresholds
  with the five questions that actually decide it.
- **Ingress NGINX retirement + Gateway API.** Added across `references/kubernetes.md`,
  `@k8s-reviewer` §3, `@kubernetes-architect` §4 and `/k8s-generate` halt #12, citing the joint
  Steering + Security Response Committee statement (kubernetes.io/blog/2026/01/29/). Gateway API
  (`gateway.networking.k8s.io/v1`) appeared nowhere in the pack before this release.
- **API versions are resolved, never recalled.** New `/k8s-generate` halt #11 and a matching
  `@k8s-reviewer` invariant: resolve every `apiVersion` from `kubectl api-resources` against the
  target cluster. `references/kubernetes.md` no longer pins a Kubernetes version at all — it cites
  the three-supported-minors policy instead, because any pinned version rots within months.
  Fixed `k8s-audit`'s worked example, which named a removal version that is itself EOL and an API
  shape that has not existed since 2019.
- **Terraform state locking corrected.** `tf-plan-review` and `references/terraform.md` now prescribe
  `use_lockfile` and quote HashiCorp's own deprecation of DynamoDB-based locking. Added the provider
  lock file, `required_version`/`required_providers`, `-detailed-exitcode`, and `moved` / `removed` /
  `import` block semantics (a `removed` block reads like a destroy and is not one).
- **tf-plan-review's flagship example rewritten.** It taught that a major `engine_version` change
  forces an RDS replacement; that is not the mechanism. The skill now refuses to name a replacement
  trigger without quoting the plan's own `replace_paths` entry or `# forces replacement` marker.
  Also corrected the S3 claim: Terraform refuses to destroy a non-empty bucket unless `force_destroy`
  is set, so the finding is the flag.
- **Kyverno `validationFailureAction` moved to the per-rule `validate.failureAction`** in
  `admission-policy`, quoting the deprecation marker in Kyverno's own API type, plus a halt against
  writing any policy field from memory.
- **`kubeval` and `datree` removed from the always-loaded rule** — the first is unmaintained and
  points at `kubeconform`, the second was archived in 2024 after its sponsoring company closed in
  2023. Enforcement tooling moved to `STACK.md § Enforcement tooling`, where churn belongs.
- **`ai-patterns/zero-downtime-deploys`**: the `SET NOT NULL` phase took `ACCESS EXCLUSIVE` and
  scanned the whole table — the exact outage the pattern forbids. Replaced with the
  `CHECK … NOT VALID` → `VALIDATE CONSTRAINT` → `SET NOT NULL` sequence, quoting the PostgreSQL docs.
  Added `CREATE INDEX CONCURRENTLY`, `lock_timeout`, and **the preStop gap** — endpoint removal and
  SIGTERM are issued in parallel, the most common cause of dropped requests during a rolling update,
  previously absent from a pattern named "zero-downtime deploys".
- **`/cost-audit` Phase 3 stopped being a product catalog.** It listed 14 vendor tools under a bare
  `Tools:` header with no criterion for picking among them — a category label, not guidance. It now
  maps the three claims an audit row can make (*this cost $N* / *it is over-provisioned* / *nobody
  asked for this*) to the one source that can settle each, and names what cannot: the console cost
  view aggregates by service and can never yield the resource id the premise demands, so the dollar
  figure comes from the per-resource billing export (AWS CUR breaks down "by product or product
  resource"; GCP's *detailed* usage export adds "granular, resource-level cost data"; Azure's Cost
  and usage details export scopes to the resource group). Adds the reconciliation rule — where a
  recommender and the export disagree the export wins, because "estimated savings" is priced at list
  — FOCUS as the multi-cloud comparison schema, and the Kubernetes node-boundary limit: without a
  container-level allocator, per-namespace chargeback is not measurable and must be reported as
  unavailable rather than apportioned by headcount.
- **`/cost-audit`**: two arithmetic defects fixed (a saving claimed from LENGTHENING log retention,
  which bills per GB-month; and a saving larger than the resource's entire cost), plus three new
  mechanical halts — show the working, never exceed the line item, confirm the direction — and an
  exemplar that satisfies the command's own hand-wave halts instead of violating them five times.
- **`/audit-iam`**: exemplar now enumerates every dead-permission pair instead of saying "23 are
  clearly safe", which its own halt bans. Archived tooling dropped; IAM Access Analyzer's
  unused-access analyzer is now the primary evidence source for the dead-permissions section, and
  permissions boundaries / org guardrails / trust policies are audited as enforcement mechanisms.
- **`/provision-tier`**: three new halts — per-tier state isolation with locking, version constraints
  plus a committed lock file, and a computable worst-case monthly spend before apply (the sibling
  `/k8s-generate` already halted on cost for one service; a whole cloud tier had no such gate).
- **`references/docker.md`**: base image moved off an end-of-life Node major, EOL schedule cited
  rather than a version copied, and a new "Generated + native dependencies" section — the decision a
  real service actually poses (install-time code generation, libc mismatch across stages, what
  `prune --prod` silently deletes) and the one this reference never taught.
- **`multi-region`**: replaced an invented `$10M ARR` threshold with the arithmetic that decides it,
  and replaced the unsourced "1-min RPO" Aurora Global Database claim with what AWS actually
  documents.
- **`references/docker-swarm.md`** reframed to lead with maintenance status: a defensible place to
  stay, a poor place to go, with the specific unmet requirements that signal a move.
- **Fallbacks repaired** — greenfield now receives the mechanisms, not just the rhetoric:
  `_examples/k8s-generate.md` gained the 6a/6b production-grade gate (it shipped the anti-pattern its
  source names — "apply to dev cluster and declare done"); `_examples/k8s-reviewer.md` gained the
  PRODUCTION-GRADE verdict block `/k8s-generate` gates on, plus `## Related`/`Invoked by`;
  `_examples/dr-audit.md` gained all eight detection heuristics and the platform table it had
  dropped; `_examples/network-exposure-audit.md` gained the per-provider command table and the
  false-positives section; `_examples/admission-policy.md` gained the ClusterPolicy YAML that makes a
  generator a generator. All three agent fallbacks now carry their sibling-boundary section.
- **`_essentials.md`**: `k8s-reviewer` added, because `/k8s-generate` gates its done-declaration on
  that agent's verdict — minimal mode previously shipped a command that could only report INCOMPLETE.
  Recorded the general rule: a gated command and its adjudicator travel together.
- **`_topics.md`**: `sections:` added to all five topics whose `fallback: stub-from-sections` carried
  no section list to build a stub from — `multi-region`, `cost-audit`, `provision-tier`, `audit-iam`,
  `tf-plan-review` — so those fallbacks resolved to an empty stub. `k8s-audit` and
  `kubernetes-architect` section lists updated to match their rewrites.
- **`rules/infra-principles.md` shrunk ~1413 → ~976 tokens (-31%)** with no guidance lost: the
  Review checklist restated the Musts, the Enforcement tool list moved to `STACK.md`, four Must-not
  bullets were negative restatements of Musts, and vendor name-lists became the category. Added one
  line — resolve versions from the vendor, not from memory — which is the failure this whole release
  is repairing.

## 1.4.0 — 2026-07-10

- k8s-generate mechanical halt #9: least-privilege in-cluster IAM (no default SA · no wildcard
  RBAC/cluster-admin · automount off · no privileged/hostPath).
- k8s-reviewer: invariants for least-privilege in-cluster IAM (the k8s analog of iam:*) + no
  privilege-escalation surface + bounded worst-case blast radius.

## 1.3.1 — 2026-07-10

- k8s-audit: every check group is now bound to its named tool's parsed output with a cite-or-halt
  (failed kube-bench control id, kubectl cost idle line, securityContext field, kubent line) + a
  no-finding-without-tool-output-citation halt — mirrors tf-plan-review/dr-audit.

## 1.3.0 — 2026-07-10

- skill +1: network-exposure-audit (audits running/declared ingress exposure — 0.0.0.0/0 on
  non-public ports, public DB/cache, missing default-deny NetworkPolicy).

## 1.2.0 — 2026-07-09

- skills +1: dr-audit — audits an EXISTING footprint for backup coverage + PITR + drilled-restore +
  RPO/RTO (the audit-of-state counterpart to provision-tier's creation-time enforcement and
  multi-region's design). Backing MUST in infra-principles.

## 1.1.0 — 2026-07-09

- NEW skills/admission-policy.md (kind:skill) — admission-policy generator. Generates:
  image-signature verification (Kyverno verifyImages keyless / Sigstore ClusterImagePolicy,
  issuer+subject bound to the CI OIDC identity, optional SBOM/SLSA attestation require), Pod
  Security Standards restricted enforcement (non-root/no-priv/drop-caps/RO-rootfs/seccomp),
  supply-chain digest-not-tag gate, egress default-deny reference. Per-engine Adapt table;
  Audit->Enforce rollout guidance; fail-closed default. Verifier counterpart to devops
  release-security (closes sign->verify); enforcement layer between k8s-generate (defaults) and
  k8s-audit (drift). Registered in _topics/_essentials; abridged _examples/admission-policy.md.
