---
name: k8s-audit
description: Audit a RUNNING Kubernetes cluster for the four things static manifest review cannot see — API versions the cluster is about to stop serving, node/control-plane CIS posture, runtime reality diverging from declared intent, and live utilisation vs requests. Run weekly. Manifest-level safety/security review is `@k8s-reviewer`, not here.
allowed-tools: [Read, Grep, Glob, Bash]
---

# k8s-audit

## Boundary — this skill audits the CLUSTER, not the YAML

`@k8s-reviewer` already owns every check that can be answered by reading a manifest: requests+limits, probes, non-root, read-only root FS, dropped capabilities, `:latest` tags, PDB coherence, NetworkPolicy presence, HPA bounds, RBAC scope. It does it with a field-level standards table, a severity rubric and a `<file:JSONPath>` citation on every finding.

**Do not restate those here.** If a finding can be made from the YAML alone, it belongs to `@k8s-reviewer` and this skill hands it over rather than producing a second, weaker version of it. What is left is the set of questions that require the live cluster, and those are the only four axes below:

| Axis | Why only the cluster can answer it |
|---|---|
| 1. API removals | depends on the cluster's minor and its upgrade path, not on the manifest |
| 2. CIS / node posture | kubelet flags, etcd, API-server config — none of it is in your repo |
| 3. Runtime vs declared | restarts, OOMKills, pending pods, out-of-band drift, expiring certs |
| 4. Live utilisation + cost | requests are declared; *usage* is measured |

## Premise

Every finding cites the concrete tool-output line it fired on: the `kubent` row, the failed `kube-bench` control id, the `kubectl top` figure beside the declared request, the `kubectl get` query and its output. **No cite → no finding.** "Looks over-provisioned" is a vibe; `requests.cpu: 2 / p95 usage 0.08 cores over 7d` is a finding.

## Halt conditions

- Halt on any finding that cannot name the tool line or parsed field it fired on.
- Halt on a utilisation claim without BOTH numbers — the declared request AND the measured usage, with the window they were measured over. A single number proves nothing.
- Halt on a deprecation finding without the cluster's current minor AND the version the API is removed in — "uses a beta API" is not actionable; "removed in the minor you upgrade to next" is.
- Halt on anything `@k8s-reviewer` owns (see Boundary) — hand it over instead of restating it.
- Do not propose auto-fix against a running cluster. Report; humans decide.

## Tools

| Axis | Tool | The citation it produces |
|---|---|---|
| API removals | `kubent` (kube-no-trouble) | the resource + its API version + the removal minor |
| CIS posture | `kube-bench` | the failed control id (e.g. a numbered CIS control) + its remediation text |
| Runtime | `kubectl get`/`describe`/`events`, the GitOps controller's sync status | the field or event line |
| Utilisation + cost | `kubectl top` (metrics-server), `kubectl cost` / OpenCost / Kubecost | the measured series beside the declared request |
| Schema (support only) | `kubeconform -kubernetes-version <minor>` | validation error line |

If a tool is not installed, say so and mark that axis **UNVERIFIED**. Never infer an axis you did not measure.

## Checks

### 1. API versions the cluster is about to stop serving

- Record the control-plane minor first (`kubectl version`) — every finding below is relative to it.
- Kubernetes maintains **only the three most recent minors**, each with roughly a year of patches (https://kubernetes.io/releases/). A cluster outside that window is a finding on its own, at the top of the report, because nothing else in the report is being patched either.
- Run `kubent` and report each hit as: `<resource> · <apiVersion> · removed in <minor> · your next upgrade target is <minor>`. Removal versions are published (https://kubernetes.io/docs/reference/using-api/deprecation-guide/) — cite the guide, do not recall them.
- Include CRDs and third-party controllers. The control plane is rarely what breaks an upgrade; an addon pinned to a removed version is.
- Cross-check the addon fleet: each controller's own supported-minor matrix against the minor you are upgrading to.

### 2. Node + control-plane posture (CIS)

- `kube-bench` against the node roles the cluster actually runs (managed control planes are not yours to benchmark — scope to worker nodes and say so).
- Report failed control ids with their remediation text; suppress the ones the provider owns, naming which.
- This is the only axis where "the manifest is fine" and "the cluster is fine" routinely disagree.

### 3. Runtime reality vs declared intent

Every check here is a comparison between what the repo says and what the cluster is doing:

- **Crash/restart pressure** — containers with a non-zero restart count, and their last termination reason (`OOMKilled` vs `Error` are different findings: the first is a limits problem, the second an app problem).
- **Unschedulable work** — `Pending` pods and the scheduler's reason from the event line (insufficient CPU/memory, no matching node, unbound PVC). A `Pending` pod is an HA claim that is not true.
- **Out-of-band drift** — resources whose live spec differs from git, and resources with no owning GitOps `Application`/`Kustomization` at all. HPA-driven `replicas` drift is expected and is NOT a finding; a changed image or resource block is.
- **Drain blockers** — PDBs whose current `status.disruptionsAllowed` is `0`. That is the runtime version of the PDB trap: the manifest can look coherent and the cluster still cannot be drained today.
- **Certificate + token expiry** — cert-manager `Certificate` resources near renewal failure, and any `Secret`-held certificate with a near expiry. Expiry is a clock fact; it does not appear in a manifest review.
- **Node conditions** — `MemoryPressure` / `DiskPressure` / `PIDPressure` true on any node, and the workloads that will be evicted next.

### 4. Live utilisation + cost

Every row here needs the declared number, the measured number and the window:

- **Over-provisioned requests** — `requests` vs p95 usage from `kubectl top` / the metrics backend. Report the ratio and the reclaimable amount, per workload. The audit's own default threshold: flag at **usage below one quarter of request, sustained over at least seven days**; state the threshold in the report so a reader can disagree with it rather than with you.
- **Under-provisioned requests** — usage at or above request, or a workload being CPU-throttled. This is the finding people forget: it costs latency, not money.
- **Unattached PVCs** — bound to no pod, with size and monthly cost.
- **Internal-only workloads behind an external LoadBalancer** — cite the Service and the fact that its selector serves in-cluster traffic only.
- **Idle Deployments** — zero request rate over the window, cited from the metrics backend rather than inferred from replica count.

## Output

```
K8s audit — cluster <name>

Control plane: v<minor>   (supported window: the three most recent minors — <in / OUT of window>)

BLOCKING:
  ✗ Cluster minor is outside the supported window — no patches are being issued for it.

HIGH:
  ✗ <n> resources on APIs removed in <minor> (kubent): <resource> <apiVersion> → <replacement>
      Upgrade to <minor> fails on these. Migrate before the upgrade window.
  ✗ kube-bench control <id> FAIL on <node role> — <remediation summary>
  ✗ Deployment <name>: <n> restarts, last reason OOMKilled, limit <x> vs peak <y>

MEDIUM:
  ⚠ PDB <name>: status.disruptionsAllowed=0 — no node holding these pods can be drained today
  ⚠ Deployment <name> live spec differs from git at <field> — no owning Application (out-of-band apply)
  ⚠ Deployment <name>: requests.cpu <r>, p95 usage <u> over 7d (below the 1/4 threshold) — reclaimable <amount>
  ⚠ PVC <name> unattached, <size> — <$>/mo
  ⚠ Certificate <name> renews in <n> days and last renewal FAILED

Handed to @k8s-reviewer (manifest-level, not audited here):
  missing limits · probe shape · securityContext · NetworkPolicy presence · RBAC scope

UNVERIFIED (tool absent): <axis> — <tool> not installed.
```

## Rules

- Audit production separately from staging; thresholds differ and mixing them buries the real findings.
- Never auto-fix. Report, cite, let humans decide.
- Every axis is either measured-and-cited or marked UNVERIFIED. There is no third state.
- Blocking findings become a ticket with an owner and a deadline; the API-removal rows get the upgrade window as their deadline.

## Related

- `@k8s-reviewer` — owns everything decidable from the manifest; this skill hands those findings over rather than duplicating them.
- `@kubernetes-architect` — owns the upgrade cadence and addon-matrix policy that axis 1 measures compliance with.
- `network-exposure-audit` — drills network exposure across cloud + cluster (public SGs, public DBs/buckets, exposed metrics ports); the exposure axis is not audited here.
- `dr-audit` — backup + restore posture, including PV snapshots.
