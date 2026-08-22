---
name: k8s-audit
description: Audit a RUNNING Kubernetes cluster for the four things static manifest review cannot see — API versions the cluster is about to stop serving, node/control-plane CIS posture, runtime reality diverging from declared intent, and live utilisation vs requests. Run weekly. Manifest-level safety/security review is `@k8s-reviewer`, not here.
---

# k8s-audit

## Boundary — this skill audits the CLUSTER, not the YAML

`@k8s-reviewer` already owns every check answerable from a manifest: requests+limits, probes, non-root, read-only root FS, dropped capabilities, `:latest` tags, PDB coherence, NetworkPolicy presence, HPA bounds, RBAC scope — with a field-level standards table, a severity rubric and a `<file:JSONPath>` citation per finding. **Do not restate those here.** Hand them over. What remains is the set of questions that need the live cluster:

1. **API removals** — depends on the cluster's minor and its upgrade path, not on the manifest.
2. **CIS / node posture** — kubelet flags, etcd, API-server config; none of it is in your repo.
3. **Runtime vs declared** — restarts, OOMKills, pending pods, out-of-band drift, expiring certs.
4. **Live utilisation + cost** — requests are declared; usage is measured.

## Premise

Every finding cites the concrete tool-output line it fired on: the `kubent` row, the failed `kube-bench` control id, the `kubectl top` figure beside the declared request, the `kubectl get` query and its output. **No cite → no finding.** "Looks over-provisioned" is a vibe; the declared request beside the measured p95 is a finding.

## Halt conditions

- Halt on any finding that cannot name the tool line or parsed field it fired on.
- Halt on a utilisation claim without BOTH numbers — declared request AND measured usage — plus the window they were measured over.
- Halt on a deprecation finding without the cluster's current minor AND the minor the API is removed in. "Uses a beta API" is not actionable.
- Halt on anything `@k8s-reviewer` owns — hand it over instead of restating it.
- Do not propose auto-fix against a running cluster.

## Tools

`kubent` (API removals) · `kube-bench` (CIS control ids) · `kubectl get`/`describe`/`events` + the GitOps controller's sync status (runtime) · `kubectl top` with `kubectl cost` / OpenCost / Kubecost (utilisation + cost) · `kubeconform -kubernetes-version <minor>` for schema support. A tool that is not installed makes its axis **UNVERIFIED** — never infer an axis you did not measure.

## Checks

**1. API versions the cluster is about to stop serving.** Record the control-plane minor first (`kubectl version`); every finding is relative to it. Kubernetes maintains only the three most recent minors, roughly a year of patches each (https://kubernetes.io/releases/) — a cluster outside that window is the report's top finding, because nothing else in it is being patched either. Report each `kubent` hit as `<resource> · <apiVersion> · removed in <minor> · next upgrade target <minor>`, citing the published removal guide (https://kubernetes.io/docs/reference/using-api/deprecation-guide/) rather than recalling versions. Include CRDs and third-party controllers — an addon pinned to a removed version breaks upgrades far more often than the control plane does.

**2. Node + control-plane posture.** `kube-bench` against the node roles the cluster actually runs; a managed control plane is not yours to benchmark, so scope to workers and say so. Report failed control ids with remediation text, suppressing provider-owned ones by name.

**3. Runtime reality vs declared intent.** Restart counts with their last termination reason (`OOMKilled` is a limits problem, `Error` is an app problem) · `Pending` pods with the scheduler's reason from the event line — a Pending pod is an HA claim that is not true · live specs differing from git, and resources with no owning GitOps Application at all (HPA-driven replica drift is expected and is NOT a finding; a changed image or resource block is) · PDBs whose `status.disruptionsAllowed` is `0`, the runtime version of the PDB trap · certificates near a failed renewal · nodes reporting `MemoryPressure` / `DiskPressure` / `PIDPressure` and what gets evicted next.

**4. Live utilisation + cost.** Every row needs the declared number, the measured number and the window. Over-provisioned requests — flag at usage below one quarter of request sustained over at least seven days, and state that threshold in the report so a reader can argue with the threshold rather than with you. Under-provisioned requests and CPU throttling — the finding people forget, because it costs latency rather than money. Unattached PVCs with size and monthly cost. Internal-only workloads behind an external LoadBalancer. Idle Deployments, cited from the metrics backend rather than inferred from replica count.

## Output

```
K8s audit — cluster <name>

Control plane: v<minor>   (supported window: the three most recent minors — <in / OUT of window>)

BLOCKING:
  ✗ Cluster minor is outside the supported window — no patches are being issued for it.

HIGH:
  ✗ <n> resources on APIs removed in <minor> (kubent): <resource> <apiVersion> → <replacement>
  ✗ kube-bench control <id> FAIL on <node role> — <remediation summary>
  ✗ Deployment <name>: <n> restarts, last reason OOMKilled, limit <x> vs peak <y>

MEDIUM:
  ⚠ PDB <name>: status.disruptionsAllowed=0 — no node holding these pods can be drained today
  ⚠ Deployment <name> live spec differs from git at <field> — no owning Application
  ⚠ Deployment <name>: requests.cpu <r>, p95 usage <u> over 7d — reclaimable <amount>
  ⚠ PVC <name> unattached, <size> — <$>/mo
  ⚠ Certificate <name> renews in <n> days and last renewal FAILED

Handed to @k8s-reviewer (manifest-level, not audited here):
  missing limits · probe shape · securityContext · NetworkPolicy presence · RBAC scope

UNVERIFIED (tool absent): <axis> — <tool> not installed.
```

## Rules

- Audit production separately from staging; mixing thresholds buries the real findings.
- Never auto-fix. Report, cite, let humans decide.
- Every axis is either measured-and-cited or marked UNVERIFIED. There is no third state.
- Blocking findings become a ticket with an owner and a deadline; API-removal rows take the upgrade window as their deadline.

## Related

- `@k8s-reviewer` — owns everything decidable from the manifest; this skill hands those findings over.
- `@kubernetes-architect` — owns the upgrade cadence and addon-matrix policy that axis 1 measures compliance with.
- `network-exposure-audit` — drills network exposure across cloud + cluster; not audited here.
- `dr-audit` — backup + restore posture, including PV snapshots.
