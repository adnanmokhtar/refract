#!/usr/bin/env bash
# availability.sh — k8s-availability-scan § 1–§ 9: the class joins over k8s-render-scan's render, offline.
#
# Reads what `k8s-render-scan/scripts/render.sh` wrote (never the repo's YAML directly):
#   $SCAN/render-<env>.json      one array per environment; every object carries __src {env, origin, file, line}
#   $SCAN/inventory-platform.tsv runbook / CI / Makefile `helm` lines (§ 9 platform components)
#   $SCAN/base/render-<env>.json the base-branch render k8s-render-scan § 5 wrote, when present (§ 8 K-STS-VCT)
# Prints one TSV row per candidate:  §  CLASS  env  origin  Kind/ns/name  detail  source-file[:line]
# A row is a CANDIDATE. The skill's read step and refute-before-report decide what it is.
#
# The replica FLOOR every join uses (precedents/infrastructure.md § 42, THR-K8S-PROD-FLOOR):
#   KEDA ScaledObject minReplicaCount (default 0) > HPA minReplicas (default 1) > Rollout/Deployment/StatefulSet
#   spec.replicas (default 1). For PDB arithmetic the floor is max(floor, 1): a KEDA-activated target runs >= 1 pod.
#   The research join read only HPA + spec.replicas and reported a KEDA floor of 2 as a 1-replica PDB block (a
#   measured false positive on a real repo); its mirror image, minReplicaCount 0 behind minAvailable 1, was missed.
#
# Usage:  availability.sh <scan-dir> [--repo=<repo-root>]     (--repo lets § 9 read the runbook line's --set keys)
#         availability.sh --self-test
# Needs:  jq 1.6+. No kubectl, no helm, no cluster, no network. Exit: 0 ran · 2 usage · 4 no render-*.json.
# Shells: bash 3.2 and zsh-safe (no mapfile, no indexed arrays).

set -u
export LC_ALL=C
SCAN=""; REPO=""; SELFTEST=0
for a in "$@"; do
  case "$a" in
    --repo=*) REPO="${a#*=}" ;;
    --self-test) SELFTEST=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *) SCAN="$a" ;;
  esac
done

read -r -d '' JQ <<'JQEOF'
def ns: (.metadata.namespace // "");
def oid: "\(.kind)/\(if ns == "" then "-" else ns end)/\(.metadata.name)";
def srcref: "\(.__src.file // "?")\(if (.__src.line // null) != null then ":\(.__src.line)" else "" end)";
def iswl: .kind | IN("Deployment","StatefulSet","DaemonSet","ReplicaSet","Job","CronJob","Rollout","Pod");
def isjob: .kind | IN("Job","CronJob");
def tpl: if .kind == "CronJob" then (.spec.jobTemplate.spec.template // {}) elif .kind == "Pod" then {metadata: .metadata, spec: .spec} else (.spec.template // {}) end;
def ps: (tpl.spec // {});
def mains: (ps.containers // [])[];
def sidecars: (ps.initContainers // [])[] | select(.restartPolicy == "Always");
def everyc: (ps.containers // [])[], (ps.initContainers // [])[];
def lab: (tpl.metadata.labels // {});
def has_v($a; $v): any($a[]?; . == $v);
def lsel($l): (.matchLabels // {}) as $m | (.matchExpressions // []) as $e
  | all($m | to_entries[]; $l[.key] == .value)
  and all($e[]; . as $x | $l[$x.key] as $v
      | if $x.operator == "In" then ($v != null and has_v($x.values; $v))
        elif $x.operator == "NotIn" then ($v == null or (has_v($x.values; $v) | not))
        elif $x.operator == "Exists" then $v != null
        elif $x.operator == "DoesNotExist" then $v == null else false end);
# int-or-percent scaled against n; $up rounds up (PDB, maxSurge), else down (Deployment maxUnavailable)
def scaled($n; $up): if . == null then null elif type == "number" then .
  else (tostring) as $s | if ($s | endswith("%")) then (($s | rtrimstr("%") | tonumber) * $n / 100) | (if $up then ceil else floor end)
  else ($s | tonumber? // null) end end;
def qty: if . == null then null else [ (tostring | capture("^(?<n>[0-9.eE+]+)(?<u>[a-zA-Z]*)$")) as $c
  | ($c.n | tonumber) * ({"": 1, "m": 0.001, "k": 1e3, "K": 1e3, "M": 1e6, "G": 1e9, "T": 1e12, "Ki": 1024, "Mi": 1048576, "Gi": 1073741824, "Ti": 1099511627776}[$c.u] // 0) ] | .[0] end;
def req($r): (.resources.requests[$r] // .resources.limits[$r]);   # the API defaults a request to its limit
def handler: if . == null then null else {httpGet: (.httpGet | if . then {path, port} else null end), tcp: .tcpSocket.port, exec: .exec.command, grpc: .grpc} end;
def secs($name): (tostring) as $v | ($v | capture("^(?<n>[0-9.]+)\\s*(?<u>ms|s|m)?$")? // null) as $c
  | if $c == null then null else ($c.n | tonumber) as $n
    | if $c.u == "ms" or ($c.u == null and ($name | test("(_|^)MS$|MILLIS"; "i"))) then $n / 1000 elif $c.u == "m" then $n * 60 else $n end end;
def emit($sec; $cls; $o; $d): "\($sec)\t\($cls)\t\($o.__src.env // "?")\t\($o.__src.origin // "?")\t\($o | oid)\t\($d)\t\($o | srcref)";

map(select(type == "object" and .kind != null)) as $D
| ($D | map(select(.kind == "Service" and ((.spec.selector // {}) | length) > 0))) as $SVC
| ($D | map(select(.kind == "PodDisruptionBudget"))) as $PDB
| ($D | map(select(.kind == "HorizontalPodAutoscaler" or .kind == "ScaledObject"))) as $AS
| ($D | map(select(.kind == "LimitRange"))) as $LR
| ($D | map(select(.kind == "PersistentVolumeClaim"))) as $PVC
| ($D | map(select(.kind == "VerticalPodAutoscaler"))) as $VPA
| ($D | map(select(.kind == "ResourceQuota"))) as $RQ
| ($D | map(select(iswl))) as $W
| def asfor($w): [ $AS[] | select(ns == ($w | ns) and .spec.scaleTargetRef.name == $w.metadata.name
      and (.spec.scaleTargetRef.kind // "Deployment") == $w.kind) ];
  def fl($w): asfor($w) as $a
    | if ($a | length) > 0 then ($a[0] | if .kind == "ScaledObject"
          then {by: "KEDA ScaledObject/\(.metadata.name) minReplicaCount \(.spec.minReplicaCount // "unset → 0")", min: (.spec.minReplicaCount // 0), auto: true}
          else {by: "HPA/\(.metadata.name) minReplicas \(.spec.minReplicas // "unset → 1")", min: (.spec.minReplicas // 1), auto: true} end)
      elif ($w.kind | IN("Deployment","StatefulSet","ReplicaSet","Rollout")) then {by: "spec.replicas \($w.spec.replicas // "unset → 1")", min: ($w.spec.replicas // 1), auto: false}
      else {by: $w.kind, min: null, auto: false} end;
  def served($w): ($w | lab) as $l | ($w | isjob | not) and any($SVC[]; ns == ($w | ns) and all(.spec.selector | to_entries[]; $l[.key] == .value));
  def pdbs($w): ($w | lab) as $l | [ $PDB[] | select(ns == ($w | ns) and .spec.selector != null and (.spec.selector | lsel($l))) ];
  def svcports($w): ($w | lab) as $l | [ $SVC[] | select(ns == ($w | ns) and all(.spec.selector | to_entries[]; $l[.key] == .value)) | .spec.ports[]?.targetPort ];
(
# § 1 resources and QoS — no CPU-limit row, ever (precedents § 1)
  ( $W[] | . as $w | everyc | . as $c
    | [ (if ($c | req("cpu")) == null then "requests.cpu" else empty end), (if ($c | req("memory")) == null then "requests.memory" else empty end),
        (if $c.resources.limits.memory == null then "limits.memory" else empty end) ] as $miss
    | select(($miss | length) > 0)
    | ([ $LR[] | select(ns == ($w | ns)) | .spec.limits[]? | select(.type == "Container") | ((.defaultRequest // {}) + (.default // {})) | keys[] ] | unique) as $lrk
    | emit("1"; "K-RES-MISSING"; $w; "container \($c.name)\(if ((($w|ps).initContainers // []) | any(.name == $c.name)) then " (init/sidecar)" else "" end): missing \($miss | join(", "))\(if ($lrk | length) > 0 then "; LimitRange in ns fills \($lrk | join(",")) (gate 4)" else "" end)") ),
  ( $W[] | . as $w | everyc | select(.resources.limits.memory != null and .resources.requests.memory != null)
    | ((.resources.limits.memory | qty) / ((.resources.requests.memory | qty) // 1)) as $x | select($x > 1)
    | emit("1"; "K-MEM-OVERCOMMIT"; $w; "container \(.name): memory request \(.resources.requests.memory) < limit \(.resources.limits.memory) (x\($x * 100 | round / 100))") ),
  ( $RQ[] | . as $q | select(((.spec.hard // {}) | keys | any(test("^(requests\\.|limits\\.)?(cpu|memory)$")))
      and ([ $LR[] | select(ns == ($q | ns)) ] | length) == 0)
    | emit("1"; "K-QUOTA-SHAPE"; $q; "ResourceQuota on \((.spec.hard | keys | map(select(test("cpu|memory"))) | join(","))) and no LimitRange in the namespace: a pod missing that field is rejected at admission") ),
  ( ([ $W[] | select(ps.priorityClassName != null) ] | length) as $np | select($np > 0)
    | $W[] | . as $w | select(served($w) and ps.priorityClassName == null and ((fl($w).min // 0) >= 2))
    | emit("1"; "K-PRIORITY"; $w; "served, floor \(fl($w).min), no priorityClassName while \($np) workload(s) in this render set one") ),

# § 2 probes (presence, shape, timings). Handler semantics → observability; liveness on a dependency → performance §15
  ( $W[] | . as $w | select(isjob | not) | (mains, sidecars) | select(.livenessProbe != null and .readinessProbe != null)
    | select((.livenessProbe | handler) == (.readinessProbe | handler))
    | emit("2"; "K-PROBE-SAME"; $w; "container \(.name): liveness and readiness call the same handler \(.livenessProbe | handler | tojson)\(if .livenessProbe == .readinessProbe then " (timings identical)" else " (timings differ)" end)") ),
  ( $W[] | . as $w | (mains, sidecars) | select(.livenessProbe != null)
    | select((.livenessProbe.httpGet.path // "" | test("db|database|deps|depend|deep|full|redis|cache|upstream|ready|readiness|check-?all"; "i"))
      or ((.livenessProbe.exec.command // []) | join(" ") | test("pg_isready|mysqladmin|redis-cli|mongosh|curl|wget|\\bnc\\b"; "i")))
    | emit("2"; "route:K-PROBE-DEEP"; $w; "container \(.name): liveness \(.livenessProbe.httpGet.path // (.livenessProbe.exec.command | join(" "))) — route → performance request-path-scan §15 (not graded here)") ),
  ( $W[] | . as $w | select(served($w)) | mains | select(.readinessProbe == null)
    | emit("2"; "K-READINESS-MISSING"; $w; "container \(.name) is behind a Service and has no readinessProbe") ),
  ( $W[] | . as $w | select(isjob | not) | (mains, sidecars) | select(.livenessProbe != null and .startupProbe == null and (.livenessProbe.initialDelaySeconds // 0) >= 30)
    | emit("2"; "K-PROBE-STARTUP"; $w; "container \(.name): liveness initialDelaySeconds \(.livenessProbe.initialDelaySeconds) and no startupProbe") ),
  ( $W[] | . as $w | (mains, sidecars) | . as $c | ("livenessProbe", "readinessProbe", "startupProbe") as $p
    | select($c[$p].exec != null and ($c[$p].timeoutSeconds // 1) <= 1)
    | select(($c[$p].exec.command // []) | join(" ") | test("^((/bin/)?(sh|bash) -c )?(cat|test|ls|true|stat|\\[) "; "x") | not)
    | emit("2"; "K-PROBE-EXEC-TIMEOUT"; $w; "container \($c.name): \($p) exec `\($c[$p].exec.command | join(" "))` with timeoutSeconds \($c[$p].timeoutSeconds // "unset (1 s)")") ),
  ( $W[] | . as $w | (mains, sidecars) | . as $c | ("livenessProbe", "readinessProbe", "startupProbe") as $p
    | select($c[$p].grpc != null and (($c[$p].grpc.port | type) != "number"))
    | emit("2"; "K-PROBE-GRPC"; $w; "container \($c.name): \($p) grpc.port \($c[$p].grpc.port | tojson) is not a number (named ports are not supported for grpc probes)") ),
  ( $W[] | . as $w | select(isjob) | select((if .kind == "CronJob" then .spec.jobTemplate.spec else .spec end).activeDeadlineSeconds == null)
    | mains | select(((.command // []) + (.args // [])) | join(" ") | test("worker|consume|listen|serve|--watch|while true|sleep infinity"; "i"))
    | emit("2"; "K-PROBE-JOB"; $w; "container \(.name) looks long-running (\(((.command // []) + (.args // [])) | join(" ") | .[0:80])) in a Job with no activeDeadlineSeconds (precedents § 3 flip)") ),

# § 3 PDB drain over the corrected floor (THR-K8S-PROD-FLOOR, precedents § 4, § 42)
  ( $PDB[] | . as $p
    | [ $W[] | select(ns == ($p | ns)) | . as $w | select($p.spec.selector != null and ($p.spec.selector | lsel($w | lab))) ] as $all
    | [ $all[] | select(.kind | IN("Deployment","StatefulSet","ReplicaSet","Rollout")) ] as $m
    | if ($all | length) == 0 then emit("3"; "K-PDB-ORPHAN"; $p; "selector \($p.spec.selector | tojson) matches no rendered pod template (operator-created pods? read)")
      elif ($m | length) == 0 then empty
      else ([ $m[] | fl(.) ]) as $F | ([ $F[] | ([.min, 1] | max) ] | add) as $floor
        | (if $p.spec.maxUnavailable != null then (($p.spec.maxUnavailable | scaled($floor; true)) as $mu | if $mu <= 0 then "maxUnavailable \($p.spec.maxUnavailable) allows 0" else empty end)
           elif $p.spec.minAvailable != null then (($p.spec.minAvailable | scaled($floor; true)) as $ma | if $ma >= $floor then "minAvailable \($p.spec.minAvailable) = \($ma) of a floor of \($floor)" else empty end)
           else empty end) as $why
        | emit("3"; (if any($F[]; .auto) then "K-HPA-PDB" else "K-PDB-BLOCK" end); $p; "\($why): disruptionsAllowed 0 at the floor, every drain gets 429 — targets \($m | map(oid) | join(",")); floor from \($F | map(.by) | join("; "))")
      end ),
  ( $PDB[] | . as $p | select(.spec.unhealthyPodEvictionPolicy != "AlwaysAllow")
    | select(any($W[]; ns == ($p | ns) and (.kind | IN("Deployment","StatefulSet","ReplicaSet","Rollout")) and . as $w | ($p.spec.selector != null and ($p.spec.selector | lsel($w | lab)))))
    | emit("3"; "K-PDB-UNHEALTHY"; $p; "unhealthyPodEvictionPolicy \(.spec.unhealthyPodEvictionPolicy // "unset (IfHealthyBudget)"): a crash-looping pod blocks the drain") ),
  ( $PDB[] | select(.apiVersion == "policy/v1beta1" or (.spec.selector == {}))
    | emit("3"; "K-PDB-API"; .; if .apiVersion == "policy/v1beta1" then "policy/v1beta1 (removed in 1.25; the apply fails — one finding, credited to k8s-api-version-scan §1)" else "selector {}: under policy/v1 it selects every pod in the namespace (v1beta1 selected none)" end) ),
  ( $W[] | . as $w | select((.kind | IN("Deployment","StatefulSet","ReplicaSet","Rollout")) and served($w) and ((fl($w).min // 0) >= 2) and (pdbs($w) | length) == 0)
    | emit("3"; "K-PDB-MISSING"; $w; "served, floor \(fl($w).min) (\(fl($w).by)), no PodDisruptionBudget selects it: one drain can evict every replica") ),

# § 4 autoscaling — HPA and KEDA ScaledObject (THR-K8S-PROD-FLOOR, THR-SCALE-CEILING)
  ( $AS[] | . as $a | [ $D[] | select(.kind == ($a.spec.scaleTargetRef.kind // "Deployment") and .metadata.name == $a.spec.scaleTargetRef.name and ns == ($a | ns)) ] as $t
    | ( ($t[] | select(.spec.replicas != null)
          | emit("4"; "K-HPA-REPLICAS"; .; "spec.replicas \(.spec.replicas) rendered while \($a.kind)/\($a.metadata.name) owns the count\(if (.__src.origin // "") == "raw" then "" else " — origin \(.__src.origin): graded by k8s-render-scan §2/§3f/§4a, not here" end)")),
        ( (if $a.kind == "ScaledObject" then [ $a.spec.triggers[]? | select(.type == "cpu" or .type == "memory") | .type ]   # KEDA needs the request whatever metricType says
           elif $a.spec.metrics == null then ["cpu"]
           else [ $a.spec.metrics[] | select((.type == "Resource" and .resource.target.type == "Utilization") or (.type == "ContainerResource" and .containerResource.target.type == "Utilization")) | (.resource.name // .containerResource.name) ] end) as $rs
          | $t[] | . as $w | $rs[] as $r | (mains, sidecars) | select(req($r) == null)
          | emit("4"; "K-HPA-NOREQ"; $a; "\($r) \(if $a.kind == "ScaledObject" then "trigger" else "Utilization" end)\(if $a.kind == "HorizontalPodAutoscaler" and $a.spec.metrics == null then " (metrics unset → CPU 80 %)" else "" end) but container \(.name) of \($w | oid) has no \($r) request: ScalingActive=False, it never scales") ),
        ( $t[] | . as $w | served($w) as $sv
          | ($a | if .kind == "ScaledObject" then {min: (.spec.minReplicaCount // 0), max: (.spec.maxReplicaCount // 100), maxset: (.spec.maxReplicaCount != null)} else {min: (.spec.minReplicas // 1), max: .spec.maxReplicas, maxset: true} end) as $b
          | ( (if $b.min == $b.max then emit("4"; "K-HPA-MINMAX"; $a; "min \($b.min) == max \($b.max): autoscaling is off and the max is paid always") else empty end),
              (if $sv and $b.min == 0 and $a.kind == "ScaledObject" then emit("4"; "K-KEDA-ZERO"; $a; "minReplicaCount \($a.spec.minReplicaCount // "unset → 0") on a workload a Service selects: the first request after idle meets zero endpoints") else empty end),
              (if $sv and $b.min >= 1 and $b.min < 2 then emit("4"; "K-HPA-MINMAX"; $a; "served floor \($b.min) < THR-K8S-PROD-FLOOR served_prod_min_replicas 2 (prod env only — read)") else empty end),
              (if ($b.maxset | not) then emit("4"; "K-HPA-MINMAX"; $a; "maxReplicaCount unset → KEDA default 100: THR-SCALE-CEILING wants the max written (max × unit → iac-cost-scan)") else empty end) ) ),
        ( select($a.kind == "HorizontalPodAutoscaler" and ($a.spec.metrics // []) != [] and all($a.spec.metrics[]; .type == "Resource" and .resource.name == "memory"))
          | emit("4"; "K-HPA-BEHAVIOR"; $a; "memory-only scaling: memory rarely falls after scale-up, so it scales up and never back down") ) ) ),
  ( $VPA[] | . as $v | select(((.spec.updatePolicy.updateMode // "Auto") | IN("Off", "Initial")) | not)
    | $AS[] | select(.spec.scaleTargetRef.name == $v.spec.targetRef.name and ns == ($v | ns))
    | select(.kind == "ScaledObject" and any(.spec.triggers[]?; .type == "cpu" or .type == "memory")
        or .kind == "HorizontalPodAutoscaler" and (.spec.metrics == null or any(.spec.metrics[]; .type == "Resource" or .type == "ContainerResource")))
    | emit("4"; "K-HPA-VPA"; $v; "updateMode \($v.spec.updatePolicy.updateMode // "unset → Auto") on \($v.spec.targetRef.name), which \(.kind)/\(.metadata.name) scales on CPU/memory: the two fight") ),

# § 5 spread (precedents § 8, § 44: the scheduler's soft defaults exist; this is a guarantee gap, not one-node placement)
  ( $W[] | . as $w | select((.kind | IN("Deployment","StatefulSet","Rollout")) and ((fl($w).min // 0) >= 2))
    | (ps.topologySpreadConstraints // []) as $tsc | (ps.affinity.podAntiAffinity // null) as $aa
    | ( (if ($tsc | length) == 0 and $aa == null then emit("5"; "K-SPREAD"; $w; "floor \(fl($w).min), served=\(served($w)), no topologySpreadConstraints or podAntiAffinity; PDB \(if (pdbs($w) | length) > 0 then "present (it assumes spread)" else "absent" end)") else empty end),
        ( $tsc[] | select(.whenUnsatisfiable == "DoNotSchedule" and (.topologyKey | test("zone")) and .minDomains == null)
          | emit("5"; "K-SPREAD-HARD"; $w; "zone spread DoNotSchedule with no minDomains: a zone loss or a short node pool leaves pods Pending") ),
        ( ($aa.requiredDuringSchedulingIgnoredDuringExecution // [])[] | select(.topologyKey == "kubernetes.io/hostname")
          | emit("5"; "K-SPREAD-HARD"; $w; "required hostname anti-affinity: floor \(fl($w).min) + surge needs that many schedulable nodes, or the rollout strands (read the node count)") ),
        ( $tsc[] | select(.whenUnsatisfiable == "DoNotSchedule" and ((.matchLabelKeys // []) | index("pod-template-hash")) == null)
          | emit("5"; "K-SPREAD-ROLLOUT"; $w; "topologySpreadConstraint on \(.topologyKey) DoNotSchedule without matchLabelKeys [pod-template-hash]: old and new ReplicaSets count together, so a rollout can leave new pods Pending") ) ) ),

# § 6 rollout shape (precedents § 5, § 9, § 50)
  ( $W[] | . as $w | select(.kind == "Deployment" and (.spec.strategy.type // "RollingUpdate") == "RollingUpdate")
    | ([fl($w).min, 1] | max) as $r
    | (.spec.strategy.rollingUpdate.maxUnavailable // "25%" | scaled($r; false)) as $mu
    | (.spec.strategy.rollingUpdate.maxSurge // "25%" | scaled($r; true)) as $ms
    | ( (if $mu == 0 and $ms == 0 then emit("6"; "K-ROLLOUT-SHAPE"; $w; "maxSurge 0 and maxUnavailable 0: rejected by the API server") else empty end),
        (if $mu >= $r then emit("6"; "K-ROLLOUT-SHAPE"; $w; "maxUnavailable \(.spec.strategy.rollingUpdate.maxUnavailable) = \($mu) of \($r) replica(s): every rollout takes the service to 0 ready") else empty end),
        ( (ps.volumes // [])[] | .persistentVolumeClaim.claimName // empty | . as $cn | select($ms > 0)
          | select(any($PVC[]; .metadata.name == $cn and ns == ($w | ns) and ((.spec.accessModes // []) | any(. == "ReadWriteOnce" or . == "ReadWriteOncePod"))))
          | emit("6"; "K-RWO-ROLLING"; $w; "RollingUpdate with maxSurge \($ms) and RWO claim \($cn): the surge pod cannot attach on another node (Multi-Attach until progressDeadlineSeconds)") ),
        ( select($r == 1 and $ms > 0 and ((.metadata.name + " " + ([mains | ((.command // []) + (.args // [])) | join(" ")] | join(" "))) | test("schedul|cron|singleton|leader|primary|writer"; "i"))
            and (([mains | ((.command // []) + (.args // [])) | join(" ")] | join(" ")) | test("leader-?elect"; "i") | not))
          | emit("6"; "K-STATEFUL-RECREATE"; $w; "1 replica under RollingUpdate with surge \($ms): old and new pod run together; a singleton writer with no leader election writes twice (read the code)") ) ) ),
  ( $W[] | . as $w | select(.kind | IN("Deployment","Rollout"))
    | (.spec.progressDeadlineSeconds // 600) as $pd
    | ([ mains | select(.startupProbe != null) | .startupProbe | ((.initialDelaySeconds // 0) + (.failureThreshold // 3) * (.periodSeconds // 10)) ] | max // 0) as $sb
    | select($sb >= $pd or (.spec.minReadySeconds // 0) >= $pd)
    | emit("6"; "K-ROLLOUT-DEADLINE"; $w; "progressDeadlineSeconds \($pd) ≤ startup budget \($sb) s / minReadySeconds \(.spec.minReadySeconds // 0): a healthy slow start is reported as a failed rollout") ),
  ( $W[] | select((.kind | IN("Deployment","StatefulSet","DaemonSet","Rollout")) and .spec.revisionHistoryLimit == 0)
    | emit("6"; "K-HISTORY"; .; "revisionHistoryLimit 0: `kubectl rollout undo` has nothing to return to") ),
  ( $W[] | . as $w | select(.kind == "DaemonSet")
    | ( (if (.spec.updateStrategy.type // "RollingUpdate") == "OnDelete" then emit("6"; "K-DS-UPDATE"; $w; "updateStrategy OnDelete: a template change never rolls out") else empty end),
        (if ((.spec.updateStrategy.rollingUpdate.maxSurge // 0) | tostring) != "0" and ((.spec.updateStrategy.rollingUpdate.maxSurge // 0) | tostring) != "0%"
            and any(everyc; any(.ports[]?; .hostPort != null)) then emit("6"; "K-DS-UPDATE"; $w; "maxSurge \(.spec.updateStrategy.rollingUpdate.maxSurge) with a hostPort: the surge pod cannot bind the port on the same node [K?: prove on kind, V271]") else empty end),
        (if ((.spec.updateStrategy.rollingUpdate.maxUnavailable // 1) | tostring | test("^([5-9][0-9]|100)%$")) then emit("6"; "K-DS-UPDATE"; $w; "maxUnavailable \(.spec.updateStrategy.rollingUpdate.maxUnavailable) on a per-node agent: half the nodes lose it at once") else empty end) ) ),
  ( $W[] | . as $w | select(.kind == "StatefulSet")
    | ( (if .spec.podManagementPolicy == "Parallel" and (.metadata.name | test("etcd|zookeeper|zk|kafka|consul|raft|vault|nats|rabbit|elastic|opensearch|cassandra"; "i")) then emit("6"; "K-STS-PODMGMT"; $w; "podManagementPolicy Parallel on a quorum store: members bootstrap at once") else empty end),
        (if (.spec.updateStrategy.type // "RollingUpdate") == "OnDelete" then emit("6"; "K-STS-PODMGMT"; $w; "updateStrategy OnDelete: a template change never rolls out") else empty end) ) ),
  ( $W[] | . as $w | select((.kind | IN("Deployment","StatefulSet","DaemonSet","ReplicaSet","Rollout")) and .spec.selector != null and .spec.workloadRef == null)
    | select(.spec.selector | lsel($w | lab) | not)
    | emit("6"; "K-SELECTOR-TEMPLATE"; $w; "selector \(.spec.selector | tojson) is not satisfied by template labels \(lab | tojson): the API server rejects it") ),
  ( $W[] | . as $w | everyc | select(.image != null and (.image | contains("@sha256:") | not))
    | (.image | split("/") | last | if contains(":") then split(":") | last else "latest" end) as $tag
    | select($tag == "latest" and (.imagePullPolicy == "IfNotPresent" or .imagePullPolicy == "Never")) | .imagePullPolicy as $pp
    | emit("6"; "route:K-PULLPOLICY"; $w; "container \(.name): :latest (or no tag) with an explicit \($pp) — each node keeps whichever build it pulled first; the mutable tag itself is security iac-scan 4j (precedents § 9, § 50)") ),

# § 7 shutdown timing — THR-SHUTDOWN-GRACE: preStop_s + app_drain_s + 5 ≤ terminationGracePeriodSeconds (precedents § 46, § 61)
  ( $W[] | . as $w | select((isjob | not) and .kind != "Pod")
    | (ps.terminationGracePeriodSeconds // 30) as $g | served($w) as $sv | svcports($w) as $tp
    | mains | . as $c
    | select((($c.ports // []) | length) == 0 or ($tp | length) == 0 or any($c.ports[]; . as $pt | any($tp[]; . == $pt.name or . == $pt.containerPort)))
    | ($c.lifecycle.preStop // null) as $pre
    | (if $pre == null then {s: 0, how: "none"} elif $pre.sleep != null then {s: $pre.sleep.seconds, how: "native sleep"}
       elif $pre.exec != null then ((($pre.exec.command // []) | join(" ") | capture("sleep\\s+(?<n>[0-9]+)")? | .n | tonumber) // null) as $n
         | (if $n != null then {s: $n, how: "exec sleep"} else {s: null, how: "exec (read the command)"} end)
       else {s: null, how: "httpGet (read the handler)"} end) as $P
    | ([ ($c.env // [])[] | select(.value != null and (.name | test("SHUTDOWN|DRAIN|GRACE|TERMINAT|STOP"; "i")) and (.name | test("TIMEOUT|SEC|_S$|MS$|PERIOD|DELAY|WAIT"; "i")))
         | . as $e | {n: $e.name, s: ($e.value | secs($e.name))} | select(.s != null) ] | max_by(.s) // null) as $E
    | ( (if $sv and $pre == null and $w.kind != "DaemonSet" then emit("7"; "K-SHUTDOWN-PRESTOP"; $w; "container \($c.name): served, no preStop — endpoint removal races SIGTERM (grace \($g) s)") else empty end),
        (if $sv and $pre == null and $w.kind == "DaemonSet" then emit("7"; "K-SHUTDOWN-PRESTOP"; $w; "container \($c.name): DaemonSet behind a Service, no preStop (grace \($g) s) — read: does the LB drain the node first?") else empty end),
        (if $P.how == "exec sleep" and $P.s >= $g then emit("7"; "K-SHUTDOWN-GRACE"; $w; "container \($c.name): exec sleep \($P.s) ≥ grace \($g): unvalidated, SIGKILL lands inside the sleep") else empty end),
        (if $P.how == "native sleep" and $P.s >= $g then emit("7"; "K-SHUTDOWN-GRACE"; $w; "container \($c.name): native sleep \($P.s) ≥ grace \($g): the API server rejects the object") else empty end),
        (if $E != null and $P.s != null and ($P.s + $E.s + 5) > $g then emit("7"; "K-SHUTDOWN-GRACE"; $w; "container \($c.name): preStop \($P.s) (\($P.how)) + \($E.n) \($E.s) + 5 = \($P.s + $E.s + 5) > grace \($g)") else empty end),
        (if $sv or ($w.kind | IN("Deployment","StatefulSet","Rollout")) then emit("7"; "ctx:SHUTDOWN"; $w; "container \($c.name): served=\($sv) preStop=\($P.s // "?") (\($P.how)) drain=\(if $E then "\($E.s) (\($E.n))" else "not in the manifest: read the code constant (devops deploy-safety-scan §5)" end) grace=\($g)") else empty end) ) ),
  ( $W[] | . as $w | select(((ps.containers // []) | length) >= 2)
    | (ps.containers // [])[] | select(.image != null and (.image | test("envoy|istio/proxy|linkerd.*proxy|cloud-?sql-proxy|alloydb-auth-proxy|fluent-?bit|fluentd|opentelemetry-collector|otel/|timberio/vector|vault-agent|oauth2-proxy|pgbouncer"; "i")))
    | emit("7"; "K-SIDECAR-ORDER"; $w; "sidecar \(.name) (\(.image | split("@")[0])) in containers, not a native sidecar (initContainers restartPolicy Always): \(if ($w | isjob) then "the Job never completes while it runs" else "it stops with the app on SIGTERM, so egress or logs die mid-drain" end)") ),

# § 8 StatefulSet
  ( $W[] | . as $w | select(.kind == "StatefulSet" and .spec.serviceName != null and .spec.serviceName != "")
    | select(any($D[]; .kind == "Service" and .metadata.name == $w.spec.serviceName and ns == ($w | ns) and .spec.clusterIP == "None") | not)
    | emit("8"; "K-STS-SVC"; $w; "serviceName \(.spec.serviceName) has no headless Service in this render (another chart or operator? read)") ),
  ( $W[] | select(.kind == "StatefulSet" and (.spec.volumeClaimTemplates // []) != [])
    | (.spec.persistentVolumeClaimRetentionPolicy // {}) as $rp
    | if ($rp.whenDeleted == "Delete" or $rp.whenScaled == "Delete") then emit("8"; "K-STS-PVC-RETENTION"; .; "whenDeleted \($rp.whenDeleted // "Retain") / whenScaled \($rp.whenScaled // "Retain"): deleting or scaling down deletes the claims")
      elif $rp == {} then emit("8"; "info:K-STS-PVC-RETENTION"; .; "unset (Retain/Retain): claims outlive the set; state the intent") else empty end )
)
JQEOF

# § 9 platform components: request-path charts installed outside the render (precedents § 45).
platform() { # $1 inventory tsv, $2 repo root (optional)
  awk -F'\t' 'NR > 1 && $2 == "helm" && $5 ~ /(ingress-nginx|nginx-ingress|traefik|contour|envoy-gateway|gateway-helm|kong|haproxy|istio|gateway|cert-manager|keda|metrics-server|prometheus-adapter|coredns|cilium)/' "$1" |
  while IFS="$(printf '\t')" read -r fl tool verb rel chart ver vals nsp flags; do
    f="${fl%:*}"; ln="${fl##*:}"; setk="-"
    if [ -n "$2" ] && [ -f "$2/$f" ]; then
      setk="$(awk -v s="$ln" 'NR >= s { print; if ($0 !~ /\\[[:space:]]*$/) exit }' "$2/$f" | grep -oE -- '--set(-string)?[ =][^ ]+' | sed -E 's/^--set(-string)?[ =]//' | tr '\n' ' ')"
      [ -n "$setk" ] || setk="-"
    fi
    rk="$(printf '%s' "$setk" | grep -oiE '[A-Za-z.]*(replicaCount|replicas|autoscaling\.enabled|minReplicas|podDisruptionBudget[A-Za-z.]*|pdb[A-Za-z.]*)=[^ ]+' | tr '\n' ' ')"
    vk="-"
    if [ -n "$2" ] && [ "$vals" != "-" ]; then
      for v in $(printf '%s' "$vals" | tr ',' ' '); do [ -f "$2/$v" ] && vk="$(grep -nE '^\s*(replicaCount|replicas|minReplicas|podDisruptionBudget|pdb)\s*:' "$2/$v" | head -3 | tr '\n' ' ')"; done
    fi
    if [ -z "$rk" ] && { [ "$vk" = "-" ] || [ -z "$vk" ]; }; then
      printf '9\tK-PLATFORM-SPOF\tplatform\tinventory\t%s/%s/%s\tchart %s %s: no replica or PDB setting on the install line (--set: %s) → the chart default decides; %s\t%s\n' \
        "helm" "$nsp" "$rel" "$chart" "$ver" "$setk" "$( [ "$ver" = UNPINNED ] && echo 'UNPINNED: default unknowable → Unconfirmed (V245)' || echo "read: helm show values $chart --version $ver")" "$fl"
    else
      printf '9\tctx:PLATFORM\tplatform\tinventory\t%s/%s/%s\tchart %s %s sets %s%s\t%s\n' "helm" "$nsp" "$rel" "$chart" "$ver" "${rk:-}" "$( [ "$vk" = - ] || printf 'values: %s' "$vk")" "$fl"
    fi
  done
}

# § 8 K-STS-VCT: volumeClaimTemplates changed between the base-branch render and head ([K?] mutability on 1.35+).
vct() { # $1 scan dir
  [ -d "$1/base" ] || return 0
  find "$1/base" -maxdepth 1 -name 'render-*.json' -exec jq -c '.[] | select(.kind == "StatefulSet") | {k: "\(.metadata.namespace // "-")/\(.metadata.name)", v: .spec.volumeClaimTemplates}' {} + > "$1/.vct-base" 2>/dev/null
  find "$1" -maxdepth 1 -name 'render-*.json' -exec jq -r --slurpfile B "$1/.vct-base" '.[] | select(.kind == "StatefulSet") | "\(.metadata.namespace // "-")/\(.metadata.name)" as $k
    | .spec.volumeClaimTemplates as $v | ($B | map(select(.k == $k)) | .[0]) as $b | select($b != null and $b.v != $v)
    | "8\tK-STS-VCT\t\(.__src.env)\t\(.__src.origin)\tStatefulSet/\($k)\tvolumeClaimTemplates changed base → head: existing claims are not resized by the template [K?: 1.35+ mutability, prove on kind]\t\(.__src.file)"' {} +
}

run() { # $1 scan dir, $2 repo
  n=0
  for f in "$1"/render-*.json; do
    [ -f "$f" ] || continue; n=$((n + 1))
    jq -r "$JQ" "$f" || printf 'ERROR\tjq failed\t%s\n' "$f" >&2
  done
  [ "$n" -gt 0 ] || { printf 'no render-*.json in %s — run k8s-render-scan § 0 (render.sh) first\n' "$1" >&2; return 4; }
  vct "$1"
  [ -f "$1/inventory-platform.tsv" ] && platform "$1/inventory-platform.tsv" "$2"
  return 0
}

# ---------------------------------------------------------------- self-test ----------------------
if [ "$SELFTEST" -eq 1 ]; then
  T="$(mktemp -d "${TMPDIR:-/tmp}/avail-selftest.XXXXXX")"; trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/repo/ops"
  cat > "$T/render-prod.json" <<'EOF'
[
{"kind":"Service","apiVersion":"v1","metadata":{"name":"api","namespace":"p"},"spec":{"selector":{"app":"api"},"ports":[{"port":80,"targetPort":"http"}]},"__src":{"env":"prod","origin":"raw","file":"k/api.yaml"}},
{"kind":"Deployment","apiVersion":"apps/v1","metadata":{"name":"api","namespace":"p"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"api"}},"template":{"metadata":{"labels":{"app":"api"}},"spec":{"terminationGracePeriodSeconds":30,"containers":[{"name":"api","image":"r/api:v1","ports":[{"name":"http","containerPort":8080}],"env":[{"name":"SHUTDOWN_DRAIN_SECONDS","value":"60"}],"livenessProbe":{"httpGet":{"path":"/healthz","port":"http"}},"readinessProbe":{"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":5},"resources":{"requests":{"memory":"128Mi"},"limits":{"memory":"512Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/api.yaml"}},
{"kind":"PodDisruptionBudget","apiVersion":"policy/v1","metadata":{"name":"api","namespace":"p"},"spec":{"minAvailable":1,"selector":{"matchLabels":{"app":"api"}}},"__src":{"env":"prod","origin":"raw","file":"k/api.yaml"}},
{"kind":"Service","apiVersion":"v1","metadata":{"name":"q","namespace":"p"},"spec":{"selector":{"app":"q"},"ports":[{"port":80,"targetPort":8080}]},"__src":{"env":"prod","origin":"raw","file":"k/q.yaml"}},
{"kind":"Deployment","apiVersion":"apps/v1","metadata":{"name":"q","namespace":"p"},"spec":{"selector":{"matchLabels":{"app":"q"}},"template":{"metadata":{"labels":{"app":"q"}},"spec":{"containers":[{"name":"q","image":"r/q@sha256:00","ports":[{"containerPort":8080}],"lifecycle":{"preStop":{"exec":{"command":["sleep","40"]}}},"readinessProbe":{"tcpSocket":{"port":8080}},"resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"memory":"64Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/q.yaml"}},
{"kind":"ScaledObject","apiVersion":"keda.sh/v1alpha1","metadata":{"name":"q","namespace":"p"},"spec":{"scaleTargetRef":{"name":"q"},"minReplicaCount":1,"maxReplicaCount":4,"triggers":[{"type":"cpu","metadata":{"value":"60"}}]},"__src":{"env":"prod","origin":"raw","file":"k/q.yaml"}},
{"kind":"PodDisruptionBudget","apiVersion":"policy/v1","metadata":{"name":"q","namespace":"p"},"spec":{"minAvailable":1,"selector":{"matchLabels":{"app":"q"}}},"__src":{"env":"prod","origin":"raw","file":"k/q.yaml"}},
{"kind":"Deployment","apiVersion":"apps/v1","metadata":{"name":"worker","namespace":"p"},"spec":{"selector":{"matchLabels":{"app":"worker"}},"template":{"metadata":{"labels":{"app":"worker"}},"spec":{"terminationGracePeriodSeconds":45,"containers":[{"name":"w","image":"r/w:0123abcd","imagePullPolicy":"IfNotPresent","env":[{"name":"DRAIN_TIMEOUT_MS","value":"30000"}],"lifecycle":{"preStop":{"sleep":{"seconds":10}}},"resources":{"limits":{"cpu":"1","memory":"256Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/w.yaml"}},
{"kind":"ScaledObject","apiVersion":"keda.sh/v1alpha1","metadata":{"name":"worker","namespace":"p"},"spec":{"scaleTargetRef":{"name":"worker"},"minReplicaCount":2,"maxReplicaCount":6,"triggers":[{"type":"prometheus"}]},"__src":{"env":"prod","origin":"raw","file":"k/w.yaml"}},
{"kind":"PodDisruptionBudget","apiVersion":"policy/v1","metadata":{"name":"worker","namespace":"p"},"spec":{"minAvailable":1,"unhealthyPodEvictionPolicy":"AlwaysAllow","selector":{"matchLabels":{"app":"worker"}}},"__src":{"env":"prod","origin":"raw","file":"k/w.yaml"}},
{"kind":"DaemonSet","apiVersion":"apps/v1","metadata":{"name":"agent","namespace":"p"},"spec":{"selector":{"matchLabels":{"app":"agent"}},"template":{"metadata":{"labels":{"app":"agent"}},"spec":{"containers":[{"name":"a","image":"r/a","imagePullPolicy":"IfNotPresent","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"32Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/a.yaml"}},
{"kind":"PodDisruptionBudget","apiVersion":"policy/v1","metadata":{"name":"agent","namespace":"p"},"spec":{"maxUnavailable":0,"selector":{"matchLabels":{"app":"agent"}}},"__src":{"env":"prod","origin":"raw","file":"k/a.yaml"}},
{"kind":"Deployment","apiVersion":"apps/v1","metadata":{"name":"sched","namespace":"p"},"spec":{"replicas":1,"revisionHistoryLimit":0,"strategy":{"type":"Recreate"},"selector":{"matchLabels":{"app":"sched"}},"template":{"metadata":{"labels":{"app":"sched"}},"spec":{"containers":[{"name":"s","image":"r/s@sha256:22","args":["--leader-elect=true"],"resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"32Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/s.yaml"}},
{"kind":"HorizontalPodAutoscaler","apiVersion":"autoscaling/v2","metadata":{"name":"web","namespace":"p"},"spec":{"scaleTargetRef":{"apiVersion":"apps/v1","kind":"Deployment","name":"web"},"minReplicas":2,"maxReplicas":6,"metrics":[{"type":"Resource","resource":{"name":"cpu","target":{"type":"Utilization","averageUtilization":70}}}]},"__src":{"env":"prod","origin":"raw","file":"k/web.yaml"}},
{"kind":"Deployment","apiVersion":"apps/v1","metadata":{"name":"web","namespace":"p"},"spec":{"replicas":3,"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":0}},"selector":{"matchLabels":{"app":"web"}},"template":{"metadata":{"labels":{"app":"webx"}},"spec":{"containers":[{"name":"web","image":"r/web@sha256:33","resources":{"requests":{"memory":"64Mi"},"limits":{"memory":"64Mi"}}},{"name":"proxy","image":"envoyproxy/envoy:v1.31","resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"32Mi"}}}]}}},"__src":{"env":"prod","origin":"raw","file":"k/web.yaml"}},
{"kind":"StatefulSet","apiVersion":"apps/v1","metadata":{"name":"pg","namespace":"p"},"spec":{"serviceName":"pg-headless","selector":{"matchLabels":{"app":"pg"}},"template":{"metadata":{"labels":{"app":"pg"}},"spec":{"containers":[{"name":"pg","image":"postgres@sha256:44","resources":{"requests":{"cpu":"100m","memory":"1Gi"},"limits":{"memory":"1Gi"}}}]}},"volumeClaimTemplates":[{"metadata":{"name":"d"},"spec":{"accessModes":["ReadWriteOnce"]}}],"persistentVolumeClaimRetentionPolicy":{"whenDeleted":"Delete"}},"__src":{"env":"prod","origin":"raw","file":"k/pg.yaml"}}
]
EOF
  printf 'file:line\ttool\tverb\trelease\tchart\tversion\tvalues\tnamespace\tflags\nops/p.md:2\thelm\tupgrade\tingress-nginx\tingress-nginx/ingress-nginx\tUNPINNED\t-\tingress-nginx\t--install set=1\nops/p.md:4\thelm\tupgrade\tcert-manager\tjetstack/cert-manager\tv1.19.1\t-\tcert-manager\t--install set=2\n' > "$T/inventory-platform.tsv"
  printf '# runbook\nhelm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \\\n  --set controller.allowSnippetAnnotations=false\nhelm upgrade --install cert-manager jetstack/cert-manager --version v1.19.1 --set replicaCount=2 --set webhook.replicaCount=2\n' > "$T/repo/ops/p.md"
  OUTP="$(run "$T" "$T/repo")"; fail=0
  want() { printf '%s\n' "$OUTP" | grep -qE "$1" || { printf 'FAIL want: %s\n' "$1"; fail=1; }; }
  nope() { ! printf '%s\n' "$OUTP" | grep -qE "$1" || { printf 'FAIL decoy fired: %s\n' "$1"; fail=1; }; }
  want $'^3\tK-PDB-BLOCK\tprod\traw\tPodDisruptionBudget/p/api\t'                      # single replica + PDB
  want $'^3\tK-HPA-PDB\tprod\traw\tPodDisruptionBudget/p/q\t.*KEDA ScaledObject/q minReplicaCount 1'   # KEDA floor 1
  nope $'PodDisruptionBudget/p/worker\t.*(BLOCK|PDB)'                                   # decoy: KEDA floor 2 vs minAvailable 1
  nope $'K-PDB-(BLOCK|ORPHAN)\tprod\traw\tPodDisruptionBudget/p/agent'                  # decoy: PDB on a DaemonSet (§ 4)
  want $'^7\tK-SHUTDOWN-GRACE\tprod\traw\tDeployment/p/api\t.*0 \\(none\\) \\+ SHUTDOWN_DRAIN_SECONDS 60'
  want $'^7\tK-SHUTDOWN-GRACE\tprod\traw\tDeployment/p/q\t.*exec sleep 40'
  nope $'K-SHUTDOWN-GRACE\tprod\traw\tDeployment/p/worker'                              # decoy: 10 + 30 + 5 = 45
  want $'^7\tK-SHUTDOWN-PRESTOP\tprod\traw\tDeployment/p/api'
  want $'^2\tK-PROBE-SAME\tprod\traw\tDeployment/p/api\t.*timings differ'
  want $'^1\tK-RES-MISSING\tprod\traw\tDeployment/p/api\t.*requests.cpu'
  nope $'K-RES-MISSING\tprod\traw\tDeployment/p/(q|worker|sched)'                       # decoys: no CPU limit; limits-only (request = limit)
  want $'^1\tK-MEM-OVERCOMMIT\tprod\traw\tDeployment/p/api'
  want $'^4\tK-HPA-REPLICAS\tprod\traw\tDeployment/p/web'
  want $'^4\tK-HPA-NOREQ\tprod\traw\tHorizontalPodAutoscaler/p/web\t.*container web'
  want $'^4\tK-HPA-MINMAX\tprod\traw\tScaledObject/p/q\t.*served floor 1'
  want $'^6\tK-ROLLOUT-SHAPE\tprod\traw\tDeployment/p/web\t.*maxSurge 0 and maxUnavailable 0'
  want $'^6\tK-SELECTOR-TEMPLATE\tprod\traw\tDeployment/p/web'
  want $'^6\tK-HISTORY\tprod\traw\tDeployment/p/sched'
  nope $'K-STATEFUL-RECREATE\tprod\traw\tDeployment/p/sched'                            # decoy: leader-elected singleton, Recreate (§ 5)
  want $'^6\troute:K-PULLPOLICY\tprod\traw\tDaemonSet/p/agent\t.*IfNotPresent'
  want $'^5\tK-SPREAD\tprod\traw\tDeployment/p/worker\t.*floor 2'
  nope $'K-PULLPOLICY\tprod\traw\tDeployment/p/worker'                                  # decoy: SHA tag + IfNotPresent (§ 50)
  want $'^7\tK-SIDECAR-ORDER\tprod\traw\tDeployment/p/web'
  want $'^8\tK-STS-SVC\tprod\traw\tStatefulSet/p/pg'
  want $'^8\tK-STS-PVC-RETENTION\tprod\traw\tStatefulSet/p/pg\t.*whenDeleted Delete'
  want $'^9\tK-PLATFORM-SPOF\tplatform\tinventory\thelm/ingress-nginx/ingress-nginx\t.*UNPINNED'
  want $'^9\tctx:PLATFORM\tplatform\tinventory\thelm/cert-manager/cert-manager\t.*replicaCount=2'
  nope $'K-PROBE-(SAME|EXEC|STARTUP)\tprod\traw\t(Deployment/p/q|DaemonSet)'
  rows="$(printf '%s\n' "$OUTP" | grep -cE $'^[1-9]\t' || true)"
  if [ "$fail" -eq 0 ]; then printf 'self-test: PASS (%s rows; seeds hit, decoys quiet: KEDA floor 2, DaemonSet PDB, no CPU limit, limits-only, 10+30+5=45, leader-elected Recreate, SHA tag)\n' "$rows"; exit 0; fi
  printf '%s\n' "$OUTP" >&2; exit 1
fi

[ -n "$SCAN" ] || { sed -n '2,20p' "$0" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo 'NOT-INSTALLED: jq (brew install jq) — § 1–§ 8 are blocked' >&2; exit 4; }
printf '§\tclass\tenv\torigin\tobject\tdetail\tsource\n'
run "$SCAN" "$REPO"
