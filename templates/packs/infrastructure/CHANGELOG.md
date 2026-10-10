# infrastructure pack — changelog

Release history for `templates/packs/infrastructure/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 2.0.2 — 2026-10-10

**Seven pre-flight defects the `benchmarks/fixtures/infra-ops` fixture found (its DEFECTS.md § Integrator requests IR-1–IR-7).** Re-measured on a staged copy of the fixture and on the research fixtures: the three missed seeds (IO-ST-09b, IO-ED-17a, IO-ED-17b) now print, the two false PIN-HELM lines are gone, and nothing new prints on the research fixtures.
- `edge-reliability-scan` grep 13a runs with `--hidden` (CI lives in `.github/`), `.git/` and the installed AI-tool trees (`AD`) excluded; grep 13b matched `\b--watch\b`, which can never match (`\b` needs a word character before `-`) — now `(?:^|[\s"'\[,])--watch\b`.
- `iac-state-scan` grep 4 (and grep 5's `workspace select|new`) allows `-chdir=<dir>` between the binary and the subcommand — the usual CI and Makefile form. Every `--hidden` grep excludes `.{claude,opencode,cursor,windsurf,codex,gemini,kiro,roo,agents}/**`: on an installed repo grep 3b read `render.sh`'s own self-test install lines.
- `dr-audit` grep 10: the CNPG awk printed a Cluster with no backup stanza under the NEXT file's name (the `FNR == 1` flush runs after `FILENAME` moved); the file name is kept with the line.
- `k8s-render-scan/scripts/render.sh`: Helm `__src.file` joined the `# Source: <chart name>/…` header to the chart directory's parent, so `k8s/chart` with `name: storefront` cited `k8s/storefront/templates/…`, a path that does not exist. It now drops the chart name and joins the rest to the chart directory; `--self-test` 32/32 (the self-test chart's directory is no longer named after it).
- `k8s-wiring-scan/scripts/wiring.sh`: K-NP-DNS names each isolating NetworkPolicy with its `file:line` (the fix site) beside the workload; `--self-test` 36/36.

## 2.0.1 — 2026-10-10

**E4 and D1 run here only without the security pack.** security `iac-scan` 2.3.3 carries grep 7h (shared cache) and grep 5h (dangling DNS), so `edge-reliability-scan` § 4 and `dns-tls-lifecycle-scan` § 7 no longer run on every install: with the security pack they are skipped and the coverage line names the owner's grep. `dns-tls-lifecycle-scan`'s cmctl lane says `kind-harness.sh` is not built yet and points at the raw commands in `proof-oracles.md` § Scratch cluster.

## 2.0.0 — 2026-10-10

**The infrastructure pack became a set of detectors with one audit, one fix loop and two judges (Track A batch 4).** Before this release, of 179 infrastructure defect classes 8 had a runnable detector, and all 8 were live-cluster-only or broken; the pack's own rules were its biggest noise source. "Requests **and limits** for CPU and memory on every container" was the always-loaded rule's Hard rule, `/k8s-generate` halt #4 and its scorecard, `@k8s-reviewer`'s Blocker and the canonical Deployment in `references/kubernetes.md`, and `@k8s-reviewer` demanded a PDB on a single replica (which blocks every drain). Now every class has one owning skill with a one-script pre-flight (every `rg` names its path; include globs first, exclusions last), a version gate read from files, a tool lane run on copies, a class-coverage block, a refute step and a failing-first oracle at a named tier (T tool, P offline plan, K scratch kind, H edge harness, L live read-only, S static two-ended trace). Major version: new commands and a new judge, `@k8s-reviewer` rebuilt as a judge, `network-exposure-audit` and `dr-audit` rewritten, three `_examples` deleted, and Contracts on every agent.

New detectors (`skills/`), each measured 2026-10-10 on the research fixtures, the benchmark fixtures and a read-only, offline real repo (no context, no profile, no name recorded):
- `k8s-render-scan` § 0–§ 5 with `scripts/render.sh` (bash 3.2 / zsh, `--self-test` 31/31) — the shared first step: one render per environment (Kustomize base and overlays, chart × values file, Argo `valueFiles`), each object tagged `__src` {env, origin, file, line}, `render.err`, a render ledger, the Argo/Flux CD-target map, embedded proxy configs extracted line-preserving, two canaries every tool must read, and `inventory-platform.tsv` (runbook/CI/Makefile `helm` and `kubectl apply` lines with their pins). Then Helm values and behaviour (unused/undefined keys, `lookup`, CRDs, hooks, replicas beside an autoscaler, Helm 4 flags and SSA), Kustomize patches (no-op targets, phantom containers, `commonLabels`), the static GitOps spec and selector mutation base → head (V262–V266). `KUBECONFIG` is an empty scratch file throughout.
- `k8s-availability-scan` § 1–§ 9 with `scripts/availability.sh` — resources (CPU request, memory request, memory limit; **no CPU-limit row**, precedents § 1), probes, PDB drain over the real floor (KEDA `minReplicaCount` and Argo `Rollout` included — the research join's false positive on a KEDA floor of 2 is fixed), HPA/KEDA shape, spread, rollout, shutdown arithmetic (`THR-SHUTDOWN-GRACE`), StatefulSets and platform single points of failure installed by a runbook (V267–V273, `THR-K8S-PROD-FLOOR`).
- `k8s-wiring-scan` § 1–§ 6 with `scripts/wiring.sh` (`--self-test` 35/35) — config propagation, Service/Ingress/route refs and endpoints, NetworkPolicy DNS and dependency paths, Jobs and CronJobs, RBAC wiring (breadth stays security's) (V274–V278).
- `k8s-api-version-scan` § 1–§ 4 with `scripts/apiversion.sh` (`--self-test` 19/19) — removed APIs at the target minor (pluto with `--target-versions`), strict schema and CRDs (kubeconform, objects read = objects rendered, canaries), admission rejection, support status incl. the retired ingress-nginx (V279–V281).
- `iac-state-scan` § 1–§ 6 — backend and locking, state hygiene, pinning incl. **PIN-HELM** for charts installed by runbooks, Argo and Flux, plan discipline, environment isolation, tags and invariants (V244–V245).
- `iac-lifecycle-scan` § 1–§ 7 with `scripts/blocks.awk` (comment-proof absence checks, shared with `iac-state-scan`, `dr-audit`, `serverless-reliability-scan` and `iac-cost-scan`) and `scripts/plan-joins.jq` (offline plan joins) — identity churn, lifecycle misuse, refactor blocks and forget semantics, stateful replacement, imperative escapes, perpetual diff, deletion safety across Terraform, OpenTofu, CFN/SAM, CDK, Pulumi and rendered StorageClasses. Measured on Terraform 1.16.5 and OpenTofu 1.13.1: `destroy = false` under a forced replacement plans `["forget","create"]` (an empty twin) on both engines, and deleting its block plans `delete` on Terraform but `forget` on OpenTofu (V246–V249).
- `serverless-reliability-scan` § 1–§ 9 — caller timeouts, queue visibility (`THR-QUEUE-VISIBILITY`), DLQ paths, partial batch, concurrency ceilings, retry storms, warm capacity, memory, Cloud Run / Azure / Cloudflare consumers (V255–V259).
- `iac-cost-scan` § 1–§ 13 — IaC cost candidates with the quantity contract (`quantity × unit (price key)`), never a `$` without a bill line or a dated pricing page; finops prices them (V260–V261).
- `edge-reliability-scan` § 1–§ 15 with `scripts/edge-locs.py` (nginx inheritance-aware, `--self-test` 26/26) and `scripts/edge-harness.py` (hit counter, SSE spacing, idle-gap probe) — timeout chains, keep-alive, non-idempotent retries (Caddy `lb_retry_match { method POST }` measured: 36 executions for 4 POSTs), re-resolution, streaming, forwarding headers, silent config rejection, HTTP/3 and on-demand TLS, access-log format (V282–V287).
- `dns-tls-lifecycle-scan` § 1–§ 7 with `scripts/certs.jq` — cutover TTLs and the record target's lifecycle, CAA vs the ACME CA (Caddy's LE → ZeroSSL fallback), DNSSEC key custody, the certificate inventory and its expiry signal (`THR-CERT-EXPIRY-ALERT`), issuers per environment, rotation and renewal; dangling DNS is security's, § 7 the tagged fallback (V288).

Rewritten:
- `dr-audit` § 1–§ 12 (was 8 prose detectors whose `grep -rn '<re>' *.tf` read only top-level files, so modules were never seen, and which proved absence by regex): recursive `rg` with explicit paths, the shared `blocks.awk`, backups and retention (`THR-BACKUP-RETENTION`), PITR, HA, growth, upgrade posture, cache-as-store, object versioning (`plan-joins.jq` `BUCKET-NO-VERSIONING` lands in § 7), copies, immutability and writer-can-delete (the backup-destination join against the app's own bucket), RPO/RTO arithmetic against declared objectives, operator backups, restore evidence (`THR-BACKUP-DRILL-AGE`) and destroy-surviving and off-host copies, with the key that decrypts them (`THR-KMS-WINDOW`); the coverage matrix and READY/BLOCK verdict are kept (V250–V254). `_examples/dr-audit.md` is deleted; the source is its fallback.
- `network-exposure-audit` § 1–§ 5 with `scripts/cidr-overlap.py` (`--self-test` 23/23): network **correctness** — NACL return paths, peer routes (N-PEER-ROUTE), NAT zone affinity, path MTU and ICMP, CIDR overlap across VPCs, peerings, VPNs and pod/service ranges, IPv6 parity, private resolution (N-PRIVDNS), declared-vs-running drift — plus the live-exposure **executor lane**, whose rows carry `owner: security`. The declared-exposure checks that duplicated security `iac-scan` are deleted (V289).

Kept, edited:
- `tf-plan-review` is the pre-apply verdict over `iac-lifecycle-scan`'s `plan-joins.jq` rows joined by plan address, reading `actions` (incl. `forget`) and `action_reason`; tfsec and terrascan are gone (trivy config, checkov; a legacy `#tfsec:ignore` is data); `lifecycle destroy = false`, "`validate` passes sensitive outputs" and "checkov HCL ≠ plan" are in; exposure and IAM widening are cited from security `iac-scan` § 4.
- `k8s-audit`: pluto replaces kubent (stale since 2024-08, contacts the ambient context when run bare, exits 0 with findings); a **context halt** — no live command before the user confirms the named context in the session, read-only verbs only; manifest checks hand over to the four detectors.
- `admission-policy`: the same context halt; every proof dry-run goes to a scratch kind cluster through an explicit `KUBECONFIG`, with `kyverno apply` as the offline cross-check.

Judges and agents:
- `@infra-reviewer` (new; `role: judge`, `writes: none`) refutes and judges every non-Kubernetes detector's rows.
- `@k8s-reviewer` is rebuilt as the judge over the four Kubernetes detectors in refute mode. The CPU-limit Blocker, the single-replica-PDB Blocker and the `commonLabels` advice are gone; Helm 4 (SSA by default, `--rollback-on-failure`) is in; the PRODUCTION-GRADE verdict's five controls are re-based on the detectors (identity and privilege routed to security; resources and floor; secrets routed; NetworkPolicy deny vs DNS and paths; reproducible and bounded).
- `@infra-architect` and `@kubernetes-architect` carry a `## Contract` (`role: proposer`); `lint-agent-contract.sh` lists infrastructure as a pack whose agents must have one.

New commands: `/infra-audit` (read-only; render first, every detector, offline lanes, live lanes only on a confirmed context or profile, the class ledger and a three-state verdict) and `/infra-fix` (re-verify, failing-first oracle, fix at the overlay, values file or module the CD target reads, RE-DETECT, full re-scan, sibling sweep, stop lines before any stateful replace, deletion, retention, network or live apply).

Commands, rules, patterns and references brought onto the detectors:
- `rules/infra-principles.md` (always loaded): a CPU request, a memory request and a memory limit — a CPU limit is optional; a PDB only at ≥ 2 replicas counting the autoscaler floor, never on one replica (`THR-K8S-PROD-FLOOR`); declared exposure is security `iac-scan`'s.
- `/k8s-generate`: halt #4 drops the CPU-limit demand; halt #6 and the PDB template follow `THR-K8S-PROD-FLOOR` (`maxUnavailable: 1`); halts #11/#12 read the target minor from files or a confirmed `--context`, never the default context; Phase 6a runs `render.sh`, `k8s-api-version-scan`, `k8s-availability-scan` and `k8s-wiring-scan` on its own output before `@k8s-reviewer`; the scorecard's five rows and the verdict lines match the reviewer's re-based controls.
- `/provision-tier`: `~> 1.16` (Terraform 1.16.5 / OpenTofu 1.13.1 current on 2026-10-10); Phase 6a runs `iac-state-scan`, `iac-lifecycle-scan` (with its offline plan lane), `dr-audit` and `iac-cost-scan` on its own output; the real plan is the user's step; `tf-plan-review` gives the verdict.
- `/cost-audit`: the literal NAT `$0.045/GB` in its template (which its own halt #5 forbids) is replaced by a dated-pricing-page placeholder; IaC candidates come from `iac-cost-scan`; the `$` goes through `@finops-analyst` / `@cost-reviewer` when the finops pack is installed.
- `references/kubernetes.md` (no CPU limit in the canonical Deployment; the single-replica PDB trap), `references/terraform.md` (versions dated 2026-10-10; `destroy = false` and its two measured traps, Tofu `enabled`, ephemeral and write-only arguments, Tofu state encryption, `validate` vs sensitive outputs), `ai-patterns/zero-downtime-deploys.md` (native `preStop.sleep`, GA in 1.34 and validated against the grace period; `exec` sleep is not; `THR-SHUTDOWN-GRACE`), `ai-patterns/multi-region.md` (`dr-audit` § 8/§ 9 and `THR-BACKUP-DRILL-AGE`), `STACK.md` (pluto, trivy config and checkov; tfsec, terrascan and kubent named as dead).

Snippets and governance: `precedents/infrastructure.md` § 1–67 (§ 42–50 from the real-repo run; § 48 now measured on Caddy 2.11.7; § 28 and § 58 refined from the Terraform/OpenTofu runs; § 63 a version passed through a variable or array is a pin until read; § 64–67 remaining vs configured TTL, CDN-terminated probes, Caddy's issuer chain vs CAA, references vs allocations), `proof-oracles.md` § Infrastructure V244–V289, thresholds `THR-SHUTDOWN-GRACE`, `THR-BACKUP-DRILL-AGE`, `THR-BACKUP-RETENTION`, `THR-QUEUE-VISIBILITY`, `THR-KMS-WINDOW`, `THR-CERT-EXPIRY-ALERT`, `THR-DNS-CUTOVER-TTL`, `THR-K8S-PROD-FLOOR` and `THR-SCALE-CEILING`, and 13 `ownership.json` rows (`iac-state` … `network-correctness`) plus the security-owned `shared-cache-leak` and `dangling-dns` rows. `render.sh` resolves a `--version` passed through a variable or an array (`UNREAD(<var>)` when the file does not set it) and fills `__src.line` for Kustomize objects.

`_essentials.md` lists the twelve detectors, `k8s-audit`, `@infra-reviewer`, `/infra-audit` and `/infra-fix`. `_examples/dr-audit.md`, `_examples/k8s-audit.md`, `_examples/admission-policy.md`, `_examples/k8s-generate.md` and `_examples/zero-downtime-deploys.md` are deleted (each carried a defect its source no longer has: CPU limits, kubent, ambient dry-runs, the pre-1.34 `preStop`); `_topics.md` falls back to the sources. `_examples/infra-reviewer.md` and `_examples/k8s-reviewer.md` are generated-from copies of their agents; `_examples/infra-principles.md` carries the same edits as the rule.

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
