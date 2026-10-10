# Precedents — Infrastructure (IaC state and lifecycle, deletion safety, data durability, serverless, IaC cost, Kubernetes, edge, DNS/TLS, network)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in an **infrastructure** class: with no attacker involved, a declared or rendered
configuration takes the system down, loses its data, executes a request twice, or bills without
bound. The oracles that prove them are in [`proof-oracles.md`](../proof-oracles.md) § Infrastructure
(V244–V289). The detectors are `iac-state-scan`, `iac-lifecycle-scan`, `dr-audit`,
`serverless-reliability-scan`, `iac-cost-scan`, `k8s-render-scan`, `k8s-availability-scan`,
`k8s-wiring-scan`, `k8s-api-version-scan`, `edge-reliability-scan`, `dns-tls-lifecycle-scan` and
`network-exposure-audit` (infrastructure pack). `@k8s-reviewer` judges the four Kubernetes
detectors; `@infra-reviewer` judges the rest; without them, `@verifier` in refute mode.

**An attacker-path claim is not an infrastructure claim.** "An attacker or an unintended principal
reaches data, code or privilege" — declared exposure (public bucket, `0.0.0.0/0` / `::/0` ingress,
public DB, IMDSv1, TLS floor, IAM wildcards), NetworkPolicy width including ipBlock CIDRs, egress-all
(N2), RBAC privilege breadth, a shared cache serving one user's response to another (E4), dangling
DNS / takeover (D1), a wildcard key in N stores (D8), plaintext internal hops (D9), DB TLS not
enforced (DATA-06), secret values in state (TF-02), mutable tags including registry tag mutability —
goes through [`finding-verification.md`](../finding-verification.md) to the security pack (`iac-scan`,
`/security-live-scan`) when it is installed. Without it, the row is tagged `security-class (owner
pack not installed)` and listed, never graded as security would grade it. The pipeline's own
semantics go to devops, a signal that fails on-call to observability, latency cost to performance,
money magnitude to finops (`iac-cost-scan` emits quantity arithmetic; finops prices it).

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so) unless the
flip evidence is shown with a `file:line`, a plan value or a recorded oracle run. Numbers are stable:
detectors cite `precedents/infrastructure.md § <n>`.

Index: the claim and the gates · Kubernetes § 1–15 · IaC, data and serverless § 16–29 · edge, DNS
and DR § 30–41 · real-repo precedents § 42–50 · tools and versions § 51–62 · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value is not a
finding.

> When **[the disruption that really happens: a node drain, an AZ loss, a scale event, a `destroy`,
> a rollout, a config edit, a poison message, an IP rotation, a cert renewal, a slow request]**,
> **[the object or resource at file:line — or the plan address, or the rendered object with its
> source tag]** produces **[an outage / data loss / a duplicate side effect / cost with the quantity
> arithmetic written out]** instead of **[the expected behaviour]**, proven by **[the oracle and its
> tier]**.

**The proof rule.** A grep hit is a candidate; a `k8s-ops.jq` row, a plan-JSON join or a
`blocks.awk` absence is a structural fact about the files. The class oracle in `proof-oracles.md`
§ Infrastructure at its tier is the proof: T (a tool on files), P (the offline plan JSON), K (a
scratch kind cluster), H (the edge harness), L (a live read-only describe on a context or profile
the user confirmed in this session) or S (a static two-ended trace that includes the provider
default). An L-tier row with no confirmed target prints `NO-DATA(<target>)` and stays
**Unconfirmed**; a K-tier row with no docker prints `blocked (no docker)` with the command written
out. Neither is ever `checked`. A dollar figure appears only when a bill line or a dated pricing page
is cited in the row.

## Reading the seven gates for infrastructure

| Gate | Infrastructure |
|---|---|
| 1 Reachability | Which environment, workspace, overlay, values file or stack **is deployed**: the CD target (Argo `Application`, Flux `Kustomization`, the deploy job, Atlantis project), or the runbook the team deploys with. A runbook `helm upgrade --install` is in scope (§ 45) |
| 2 Trigger | The disruption occurs: drain, AZ loss, scale event, destroy, rollout, config edit, poison message, IP rotation, cert renewal, a request slower than the shortest hop |
| 3 Version | TF/Tofu minor from `required_version`, provider majors from `.terraform.lock.hcl`; the target Kubernetes minor (Argo destination, `kubeVersion`, CI `--kube-version`, the runbook's cluster version); the Helm major from CI; controller versions from image tags or chart pins (nginx, Caddy, Traefik, ingress controller, cert-manager, KEDA, Argo CD, Flux). **Never from memory**: no version found → the version-gated rows are Unconfirmed with the probe written out |
| 4 Existing control | LimitRange, Reloader, a hash suffix, a module default, an org SCP or budget, Argo `RespectIgnoreDifferences`, a mesh drain, an app idempotency key, a KEDA or HPA floor, a managed-service default (managed PITR, managed etcd) |
| 5 Impact | Outage, data loss, duplicate side effect, cross-user data (then it is security's), or cost with `quantity × unit (price key)` written out. "Best practice" alone fails here |
| 6 Proof | The oracle fired failing-first at its tier (above), **or** a static-fact two-ended trace: the config value **and** the provider or chart default it overrides |
| 7 Environment | Dev, preview or ephemeral → latent or Hardening (§ 7, § 16, § 18); a partial control lowers severity (§ 43); documented temporary sizing is `accepted-risk` (§ 47) |

## Not a finding — Kubernetes

1. **No CPU limit is not a finding** when CPU requests are set; memory limit = memory request is the recommended shape. *Flips back:* a noisy batch neighbour with unsized requests on shared nodes; CPU-manager static pinning, where Guaranteed QoS needs limit = request.
2. **Memory limit absent** is low–medium only where the namespace has no LimitRange `default` for memory. *Flips back:* no LimitRange, and the workload is served in prod.
3. **Probes on Jobs and CronJobs are not applicable** (kube-linter `no-liveness-probe` on them is noise). *Flips back:* a long-running worker disguised as a Job (hours, no `activeDeadlineSeconds`).
4. **A PDB on a DaemonSet is meaningless** (`drain --ignore-daemonsets` skips its pods); a DaemonSet without a PDB or spread is expected.
5. **`replicas: 1` on a leader-elected singleton or controller is intended**, with `Recreate` and no PDB. *Flips back:* the app serves requests and has no leader election in code.
6. **An HPA-managed Deployment with `replicas` omitted is correct.** kube-linter and polaris reading it as 1 replica are wrong. *Flips back:* no HPA (or KEDA `ScaledObject`) targets it in that environment's render.
7. **Single-replica dev and preview overlays are not HA findings**; severity follows the environment the render came from. *Flips back:* that overlay is the CD target for prod.
8. **A zone topology-spread constraint on a single-zone cluster is meaningless**; host spread is the requirement. *Flips back:* multi-zone node pools exist.
9. **The `imagePullPolicy: Always` demand is noise for digest-pinned images.** *Flips back:* the image is tag-pinned and the registry allows re-push — then it is security 4j, not infra.
10. **`job-ttl-seconds-after-finished` on CronJob-owned Jobs is noise** when `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` are set.
11. **Identical liveness and readiness probes that are both shallow process checks** are low, not high. *Flips back:* readiness checks a dependency, so liveness copying it restarts on a dependency outage (`route → performance request-path-scan §15`).
12. **A removed apiVersion behind a `Capabilities.APIVersions.Has` or `semverCompare` guard** renders only on old clusters and is not a finding for the target minor. *Flips back:* the guard is inverted, or the render passed `--api-versions` that includes the old group.
13. **A ConfigMap with no checksum annotation but with Reloader, `immutable: true` plus a versioned name, or a kustomize hash suffix** is controlled. *Flips back:* Reloader is not installed in the target cluster.
14. **Argo CD `ignoreDifferences` on `/spec/replicas` plus `RespectIgnoreDifferences=true`** clears K-GITOPS-REPLICAS. *Flips back:* `ignoreDifferences` alone — the diff is hidden, and a sync still resets the replicas.
15. **A `LoadBalancer` Service for the ingress controller is intended.**

## Not a finding — IaC, data and serverless

16. **Multi-AZ, cross-region replication, CMK-everywhere and 365-day retention on dev, test or preview are Hardening.** Environment evidence comes from the directory, workspace, variable name, `Env` tag or account id.
17. **CKV_AWS_144 (cross-region replication on every bucket) is noise** unless the declared topology or RPO needs a cross-region copy — then it is DATA-10, owned by `dr-audit` § 8.
18. **`skip_final_snapshot = true`, retention 0 and no deletion protection are correct on an ephemeral environment** (a TTL tag, per-PR naming, a destroy job in CI, a `ci-` / `preview-` directory). *Flips back:* the same module default reaches prod — the module default leaking into prod is the finding.
19. **A Lambda DLQ (`dead_letter_config`) on an SQS-polled function is meaningless** — it applies to asynchronous invocation; for an event-source mapping the DLQ belongs on the source queue (SLS-03). *Flips back:* the function is also invoked asynchronously (S3, SNS, EventBridge).
20. **SQS "unencrypted" without a CMK is noise for this domain** (SSE-SQS is the default on new queues); whether a CMK is required is security's call.
21. **A read replica, Multi-AZ or cross-region replication is not a backup.** They replicate `DROP`. DATA-03 never satisfies DATA-01 or DATA-02.
22. **A static instance size or `memory_size` is never a cost finding** without a recommender id, a p95 utilisation and a bill line. It is a candidate for `/cost-audit` or finops.
23. **NAT per AZ in prod is intended** (AZ-failure isolation). *Flips back:* non-prod, or VPC endpoints or a regional NAT gateway would carry the same traffic.
24. **Lambda `timeout > 900` is valid on Lambda Managed Instances** (up to 90 minutes), and **an API Gateway integration timeout above 29 s is valid on a Regional or private REST API with the raised quota** (`L-E5AE38E3`). Read `capacity_provider_config` and Service Quotas first. *Flips back:* edge-optimized REST, HTTP API, or the quota is not raised.
25. **`ignore_changes` on autoscaler-mutated fields is correct** (`desired_capacity`, `desired_count`, an ECS `task_definition` under CodeDeploy). `ignore_changes = all` is the finding.
26. **`count = var.x ? 1 : 0` is not index churn.** Only `count` over a collection is TF-05.
27. **A module tag pin (`?ref=v1.2.0`) passes CKV_TF_2 but is mutable.** It is Hardening unless the repo's own policy demands a SHA.
28. **A plan "destroy" from a `removed` block or `lifecycle { destroy = false }` is not data loss.** It is an orphan that keeps billing (TF-07). `moved` is neither.
29. **Caches and derived stores with a documented rebuild path are exempt** from DATA-01, DATA-02 and DEL-01. *Flips back:* the store holds the only copy (then DEL-03 still applies), or the "cache" is the queue or session store of record.

## Not a finding — edge, DNS and DR

30. **SSE on ingress-nginx without a buffering annotation is Refuted** (`proxy-buffering` is off by default). **SSE on Caddy without `flush_interval -1` is Refuted** (Caddy flushes `text/event-stream` immediately).
31. **"Caddy logs the Authorization header" is Refuted** unless `log_credentials` is set (redacted by default). The **query string is logged** — that half is security `data-exposure-scan` § 6.
32. **`proxy_pass` to a ClusterIP `*.svc.cluster.local` name without a `resolver` is Refuted** (the ClusterIP is stable). *Flips back:* a headless or ExternalName Service, or a name outside the cluster.
33. **The upstream `keepalive` + `proxy_http_version 1.1` demand is version-gated**: it is the default since nginx 1.29.7. Read the image tag before reporting E10.
34. **gixy `weak_ssl_tls` / `hsts_header` on a plain-HTTP listener is noise.** gixy `missing_resolver` on a variable target is a real defect (a runtime 502) with the wrong stated reason.
35. **A POST retry under the default `proxy_next_upstream error timeout` is Refuted** — nginx does not re-send a non-idempotent request once it was sent (1.9.13+). The Traefik retry middleware on POST is Refuted unless `retryNonIdempotentMethod: true`.
36. **A missing CAA record is LOW; DNSSEC off is LOW.** A CAA/ACME-CA mismatch and DNSSEC whose KSK key can be deleted are high.
37. **No etcd backup on EKS, GKE or AKS is Refuted** (managed control plane). **Velero `snapshotVolumes: false` in a namespace with no PVs is Refuted.**
38. **S3 Object Lock in governance mode is not immutable** (a principal with the bypass permission and header can delete). Only compliance mode, or a locked vault, satisfies R4.
39. **A literal CNAME to CloudFront or an ELB is not a takeover** (those targets are not claimable). It is hygiene only, if dangling.
40. **"`nginx -t` passed" and "the Traefik deploy succeeded" prove nothing** about retries, cache, buffering, variable upstreams or dynamic routes: a Traefik dynamic-file typo leaves the process up and every route in that file 404.
41. **`0.0.0.0/0` egress on a default security group is noise** unless policy or the data class requires egress control — and then it is security's (N2).

## Real-repo precedents (batch-4 eval, measured 2026-10-10)

42. **The replica floor includes KEDA `ScaledObject.minReplicaCount` (default 0) and Argo `Rollout`.** A PDB, spread or HPA join that reads only HPA `minReplicas` and `spec.replicas` is wrong both ways: a false positive on a KEDA floor of 2 (measured), and a false negative on `minReplicaCount: 0` behind a PDB.
43. **A hand-bumped revision annotation** (`*/config-revision`, `config-version`) **is a partial control for K-CONFIG-ROLL**: low, unless the ConfigMap is an operational lever edited without a template change (an IP blocklist, a feature switch), which stays medium. Reloader, a hash suffix or a checksum annotation is a full control.
44. **"No spread" is a placement-guarantee gap, not "all replicas on one node".** With no cluster-level default, kube-scheduler applies soft defaults: hostname `maxSkew: 3` and zone `maxSkew: 5`, both `ScheduleAnyway` (kubernetes.io, *Pod Topology Spread Constraints*, "Built-in default constraints", fetched 2026-10-10). K-SPREAD is low unless a PDB, an SLO or a zone-loss requirement needs a guarantee. *Flips back:* the cluster's scheduler profile sets `defaultingType: List` with empty `defaultConstraints`.
45. **A component installed by a runbook, a Makefile or an Argo `Application` is in scope.** Its chart defaults are its config: replicas, PDB and version. An unpinned install is PIN-HELM; a request-path component on chart-default 1 replica is K-PLATFORM-SPOF.
46. **The app's drain time may be a code constant**; an env-only read misses it. Take devops `deploy-safety-scan` § 5's number, or read the constant, before judging `THR-SHUTDOWN-GRACE`.
47. **Documented temporary sizing** (a single replica with a written exit condition, such as "delete this patch at launch") is Hardening with an `accepted-risk (<file:line>)` tag until the condition is met. *Flips back:* prod traffic has started (the launch date passed, a prod DNS record points at it).
48. **Caddy `lb_try_duration` without `lb_retry_match` retries only safe cases** (dial failures, and GET after send) — not E3 [K?: prove with `edge-harness.py` on the fixture before a skill asserts it]. *Flips back:* `lb_retry_match` includes a write method.
49. **Stock `caddy adapt` / `caddy validate` on a config built with `xcaddy` plugins fails `module not registered`**, and an absolute `import` fails until rewritten to the extracted copy (both measured). Either is NOT-RUN, never a config error: the edge lane runs the project's own image.
50. **kube-score `container-image-pull-policy` and the polaris pull-policy checks on SHA-tagged images are noise for infra**; tag mutability is security 4j.

## Tools and versions — read at audit time

51. **Scanner silence is not a pass.** 20 of 39 Terraform seeds and 9 of 26 Kubernetes seeds passed every scanner, and checkov/trivy read no nginx, Caddy, Traefik or compose. Coverage per class comes from the detector's grep, join or oracle, never from the scanner count.
52. **A plan-based scan and an HCL scan disagree**: checkov's log-retention and Lambda-concurrency checks fire on HCL and pass on plan JSON, because the provider fills in `0` and `-1`. Every RAN row states which input it read: HCL, plan or synth.
53. **A tool that read fewer objects than were rendered is NOT-RUN for the difference.** kube-linter silently drops removed apiVersions and YAML-1.1-mangled objects; kubeconform `-ignore-missing-schemas` turns a removed API into `skipped` with exit 0; polaris omits non-workload kinds; kubent exits 0 with findings. The two canaries (a removed-API PDB and a `name: n` ConfigMap, which YAML 1.1 reads as `"false"`) ride every run.
54. **Tool defaults target old clusters**: kube-score assumes v1.18 and pluto v1.25 unless `--kubernetes-version` / `--target-versions` is passed with the minor read under gate 3.
55. **kubent is stale (0.7.3, 2024-08) and, without flags, contacts the ambient cluster.** Use pluto `--target-versions`; a live read names its context and runs only after the user confirms it in this session.
56. **`helm template --dry-run=server` and `kubectl … --dry-run=server` contact the current context.** Every dry-run and runtime oracle runs with an explicit `--kubeconfig` / `KUBECONFIG` to a scratch kind cluster; the ambient context is never relied on.
57. **tfsec, terrascan and regula are archived or superseded** (tfsec: "move to trivy"; terrascan archived 2025-11-20; regula 2024-09-03). Read a legacy `#tfsec:ignore` as data, never run the tool.
58. **`terraform validate` passes sensitive outputs and the deprecated `dynamodb_table` lock backend.** A validate PASS says nothing about TF-01 or TF-11; `terraform test` fails first with "Output refers to sensitive values".
59. **Unset `deletion_protection` reads as null, not false**, in `terraform test` and plan JSON: assert `== true`, never `!= false`. TF 1.14+ ignores `prevent_destroy` during test cleanup, so cleanup never proves a guard; a forced replacement that fails `plan` ("Instance cannot be destroyed") does.
60. **Helm 4 applies server-side by default for new installs**, so a chart that renders `replicas` for an HPA target **fails** the upgrade with a field-manager conflict (Helm 3 silently reset it); `--atomic` became `--rollback-on-failure`. Read the Helm major from CI before reporting K-HELM-FLAGS or K-HELM-SSA.
61. **The native `preStop` `sleep` action is GA in 1.34 and validated** (`sleep ≥ terminationGracePeriodSeconds` is rejected by the API server); **`exec: [sleep, N]` is not validated** — only arithmetic catches it (`THR-SHUTDOWN-GRACE`).
62. **Dated support facts are inputs, re-read at audit time**: Kubernetes 1.34 reaches EOL 2026-10-27 (supported 1.34–1.37 on 2026-10-10); ingress-nginx is retired (last release v1.15.1, 2026-03-19); cert-manager ≥ 1.18 defaults `privateKey.rotationPolicy` to `Always`; Terraform 1.16 / OpenTofu 1.12 add `lifecycle { destroy = false }` (forget, not destroy); TLS lifetimes follow `THR-CERT-EXPIRY-ALERT`. A row that cites one names its source date.

## Rationalizations to reject (infrastructure)

**Wrongly accepting:** "kube-score / kube-linter / checkov flagged it" (which check, on which
deployed render, and is the class this pack's?) · "every container needs a CPU limit" (§ 1) · "add
a PDB to the single-replica service" (it blocks every drain) · "no spread means one node" (§ 44) ·
"multi-AZ on the preview stack" (§ 16) · "the NAT per AZ costs too much" in prod (§ 23) · "the
instance is oversized" with no recommender id or bill line (§ 22) · "SSE needs a buffering
annotation" (§ 30) · "it saves $X" with no bill line or dated pricing page.

**Wrongly dismissing:** "`nginx -t` passed" (§ 40) · "the scanners are clean" (§ 51) · "kubeconform
validated everything" (with `-ignore-missing-schemas`, or on fewer objects than rendered) · "we have
Multi-AZ, so we have backups" (§ 21) · "Object Lock is on" (governance mode, § 38) · "the PDB only
says `minAvailable: 1`" (on one replica, or above the KEDA floor) · "the controller is just a chart
default" (§ 45) · "the drain fits" (read the code constant, § 46) · "the restore was tested" (with
no new target, counts, duration or date — `THR-BACKUP-DRILL-AGE`) · "the plan only shows an update"
(read `replace_paths`; a `-/+` on a stateful type is TF-08).

---

Sources: the infrastructure research catalog (2026-10-10) § 4 (precedents 1–41) and its notes —
A § 6–§ 8 (AWS provider defaults from the provider docs, the measured `terraform test` /
offline-plan oracles, checkov 3.3.26 / trivy 0.75.0 / kics 2.1.20 / tflint 0.64.0 runs), B § 2,
§ 5 and § 9 (Kubernetes release and deprecation pages, measured kind v0.33.0 / node v1.37.0
oracles, the scanner bake-off), C § 2, § 4 and § 5 (nginx, ingress-nginx, Caddy, Traefik and
can-i-take-over-xyz documentation, measured nginx and Caddy runs) — and the batch-4 infrastructure
eval (2026-10-10) § 3.5 and § 3.7 (precedents 42–50 from a read-only, offline real-repo run;
kustomize 5.8.3, kubeconform 0.8.0, pluto 5.24.4, kube-score 1.20.0, kube-linter 0.8.3, caddy
2.11.7). Precedent 44 was checked against kubernetes.io on 2026-10-10. Paraphrased; no text
reproduced beyond short quoted identifiers.
