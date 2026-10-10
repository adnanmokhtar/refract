#!/usr/bin/env bash
# wiring.sh — k8s-wiring-scan § 1–§ 6: the cross-object joins over k8s-render-scan's render, offline.
#
# Reads what `k8s-render-scan/scripts/render.sh` wrote (never the repo's YAML directly):
#   $SCAN/render-<env>.json        one array per environment; every object carries __src {env, origin, file, line}
#   $SCAN/cd-targets.tsv           Argo / Flux targets (CreateNamespace=true counts as "creates the namespace")
#   $SCAN/inventory-platform.tsv   runbook / CI `helm … --create-namespace -n <ns>` lines (the platform creates it)
# Every join runs INSIDE one environment: a dev overlay's Service never satisfies a prod Deployment.
# Prints one TSV row per candidate:  §  CLASS  env  origin  Kind/ns/name  detail  source-file[:line]
# A class starting `read:` is a prompt for the read step, never a finding by itself.
#
# Namespace rule: an object with no metadata.namespace gets the release / kustomize / kubectl namespace at
# apply time, so "" only ever joins "" (a Service with no namespace never matches a Deployment in `shop`).
#
# Usage:  wiring.sh <scan-dir> [--repo=<repo-root>]   (--repo adds `kubectl create namespace X` lines from
#                                                       runbooks, scripts and CI to the namespaces that exist)
#         wiring.sh --self-test
# Needs:  jq 1.6+. No kubectl, no helm, no cluster, no network. Exit: 0 ran · 2 usage · 4 no render-*.json.
# Shells: bash 3.2 and zsh-safe (no mapfile, no indexed arrays).

set -u
export LC_ALL=C
SCAN=""; REPO=""; SELFTEST=0
for a in "$@"; do
  case "$a" in
    --repo=*) REPO="${a#*=}" ;;
    --self-test) SELFTEST=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *) SCAN="$a" ;;
  esac
done

read -r -d '' JQ <<'JQEOF'
def ns: (.metadata.namespace // "");
def oid: "\(.kind)/\(if ns == "" then "-" else ns end)/\(.metadata.name)";
def srcref: "\(.__src.file // "?")\(if (.__src.line // null) != null then ":\(.__src.line)" else "" end)";
def row($s; $c; $d): [$s, $c, (.__src.env // "?"), (.__src.origin // "?"), oid, $d, srcref] | @tsv;
def iswl: .kind | IN("Deployment","StatefulSet","DaemonSet","ReplicaSet","Job","CronJob","Rollout","Pod");
def longlived: .kind | IN("Deployment","StatefulSet","DaemonSet","ReplicaSet","Rollout");
def tpl: if .kind == "CronJob" then (.spec.jobTemplate.spec.template // {}) elif .kind == "Pod" then {metadata: .metadata, spec: .spec} else (.spec.template // {}) end;
def ps: (tpl.spec // {});
def everyc: (ps.containers // [])[], (ps.initContainers // [])[];
def lab: (tpl.metadata.labels // {});
def has_v($a; $v): any($a[]?; . == $v);
# LabelSelector (matchLabels + matchExpressions); {} or null selects everything, as NetworkPolicy podSelector does.
def lsel($l): (.matchLabels // {}) as $m | (.matchExpressions // []) as $e
  | all($m | to_entries[]; $l[.key] == .value)
  and all($e[]; . as $x | $l[$x.key] as $v
      | if $x.operator == "In" then ($v != null and has_v($x.values; $v))
        elif $x.operator == "NotIn" then ($v == null or (has_v($x.values; $v) | not))
        elif $x.operator == "Exists" then $v != null
        elif $x.operator == "DoesNotExist" then $v == null else false end);
# A Service selector is a plain map; an empty one selects nothing (selector-less Service).
def svcsel($l): (. // {}) as $s | ($s | length) > 0 and all($s | to_entries[]; $l[.key] == .value);
def same_ns($o): ns == ($o | ns);
def isproxy: test("(^|[/_-])(caddy|nginx|openresty|haproxy|envoy|traefik)([:@/_-]|$)");
# ConfigMap / Secret references of a pod template: {t: ConfigMap|Secret, n: name, via: volume|env|projected, vol: volume name}
def cfgrefs: [ (ps.volumes // [])[] | . as $v
      | (if .configMap then {t: "ConfigMap", n: .configMap.name, via: "volume", vol: $v.name} else empty end),
        (if .secret then {t: "Secret", n: .secret.secretName, via: "volume", vol: $v.name} else empty end),
        ((.projected.sources // [])[] | (if .configMap then {t: "ConfigMap", n: .configMap.name, via: "projected", vol: $v.name}
                                          elif .secret then {t: "Secret", n: .secret.name, via: "projected", vol: $v.name} else empty end)) ]
  + [ everyc | (.envFrom // [])[] | (if .configMapRef then {t: "ConfigMap", n: .configMapRef.name, via: "env"} elif .secretRef then {t: "Secret", n: .secretRef.name, via: "env"} else empty end) ]
  + [ everyc | (.env // [])[] | .valueFrom // {} | (if .configMapKeyRef then {t: "ConfigMap", n: .configMapKeyRef.name, via: "env"} elif .secretKeyRef then {t: "Secret", n: .secretKeyRef.name, via: "env"} else empty end) ]
  | map(select(.n != null)) | group_by([.t, .n]) | map(.[0] + {via: (map(.via) | unique | join("+"))});
def annk: ((tpl.metadata.annotations // {}) + (.metadata.annotations // {})) | keys;
def full_roll: any(annk[]; test("^checksum/|config-?hash|confighash|kubectl\\.kubernetes\\.io/restartedAt|reloader\\.stakater\\.com/|configmap\\.reloader|secret\\.reloader|wave\\.pusher\\.com"; "i"));
def partial_roll: [annk[] | select(test("revision|config-?version|config-?generation"; "i"))];
def egress_np($w; $NP): [ $NP[] | select(same_ns($w)) | select((.spec.podSelector // {}) | lsel($w | lab))
  | select(((.spec.policyTypes // []) | index("Egress")) or (.spec.policyTypes == null and .spec.egress != null)) ];
def dns_ok($rules; $proto): any($rules[]; ((.ports // []) | length == 0)
  or any((.ports // [])[]; (((.protocol // "TCP") == $proto)) and ((.port == 53) or (.port == "53") or (.port == "dns") or (.port == "dns-tcp")
      or ((.port | type) == "number" and .endPort != null and .port <= 53 and .endPort >= 53))));
def sa_name: (ps.serviceAccountName // ps.serviceAccount // "default");
def builtin_cr: test("^(cluster-admin|admin|edit|view|system:.*)$");

. as $ALL
| ($ALL | map(select(.kind == "Namespace") | {n: .metadata.name, e: .__src.env})) as $NSOBJ
| ($ALL | map(select(.kind == "ServiceAccount") | {n: .metadata.name, ns: ns, e: .__src.env})) as $SAALL
| ($ALL | group_by(.__src.env)[]) as $E
| ($E | map(select(.kind == "Service"))) as $SVC
| ($E | map(select(.kind == "NetworkPolicy"))) as $NP
| ($E | map(select(iswl))) as $WL
| ($E | map(select(.kind | IN("ConfigMap","Secret")))) as $CFG
| ($E | map(select(.kind == "ServiceAccount"))) as $SA
| ($E | map(select(.kind | IN("RoleBinding","ClusterRoleBinding")))) as $RB
| ($E | map(select(.kind == "Role"))) as $ROLE
| ($E | map(select(.kind == "ClusterRole"))) as $CROLE
| ($E | map(select((.apiVersion // "") | startswith("external-secrets.io/")) | select(.kind == "ExternalSecret"))) as $ES
| (
  # ---------------------------------------------------------------- § 1 config propagation
  ($WL[] | select(longlived) | . as $w | select(full_roll | not) | partial_roll as $p | cfgrefs[] | . as $r
     | ([$CFG[] | select(.kind == $r.t and .metadata.name == $r.n and same_ns($w))] | first) as $obj
     | select(($r.n | test("-[a-z0-9]{10}$")) | not) | select(($obj.immutable // false) != true)
     | ([$w | everyc | select(.image // "" | isproxy) | "\(.image) args=\(((.command // []) + (.args // [])) | join(" ") | if . == "" then "(image default: read its entrypoint for --watch / reload)" else .[0:120] end)"] | join("; ")) as $px
     | $w | row("1"; "K-CONFIG-ROLL"; "\($r.t)/\($r.n) via \($r.via); \(if $obj == null then "not rendered here (external, ESO or platform)" else "rendered" end); control: \(if ($p | length) > 0 then "partial (\($p | join(",")); precedents § 43)" else "none" end)\(if $px != "" then "; proxy \($px)" else "" end)")),
  ($WL[] | . as $w | ([(ps.volumes // [])[] | select(.configMap or .secret or .projected or .downwardAPI) | .name]) as $cv
     | everyc | . as $c | (.volumeMounts // [])[] | . as $m | select((.subPath != null or .subPathExpr != null) and has_v($cv; .name))
     | $w | row("1"; "K-SUBPATH"; "container \($c.name) mounts volume \($m.name) at a subPath; ConfigMap/Secret updates never reach the file")),
  ($ES[] | . as $x | (.spec.target.name // .metadata.name) as $tn | (.spec.refreshInterval // "1h") as $ri | select($ri != "0" and $ri != "0s")
     | $WL[] | select(longlived) | select(same_ns($x)) | . as $w | select(full_roll | not)
     | select(any(cfgrefs[]; .t == "Secret" and .n == $tn and .via == "env"))
     | row("1"; "K-ENV-SECRET-ROTATE"; "env reads Secret/\($tn), refreshed by ExternalSecret/\($x.metadata.name) every \($ri); no restart trigger, so pods keep the old value")),
  # ---------------------------------------------------------------- § 2 service wiring
  ($SVC[] | select(.spec.type != "ExternalName") | select((.spec.selector // {}) | length > 0) | . as $s
     | [$WL[] | select(same_ns($s)) | . as $w | select($s.spec.selector | svcsel($w | lab))] as $m
     | if ($m | length) == 0 then row("2"; "K-SVC-SELECTOR"; "selector \($s.spec.selector | tojson) matches no pod template in this env"),
         ((.spec.ports // [])[] | select((.targetPort | type) == "string") | .targetPort as $tp
          | select([$WL[] | select(same_ns($s)) | everyc | (.ports // [])[] | select(.name == $tp)] | length == 0)
          | $s | row("2"; "K-SVC-PORT"; "targetPort \($tp) is declared by no container in the namespace (the selector matches nothing either)"))
       else ((.spec.ports // [])[] | select((.targetPort | type) == "string") | .targetPort as $tp
         | select([$m[] | everyc | (.ports // [])[] | select(.name == $tp)] | length == 0)
         | $s | row("2"; "K-SVC-PORT"; "targetPort \($tp) is not a named port on any of \($m | map(oid) | join(", "))")) end),
  ($WL[] | . as $w | everyc | . as $c | select((.image // "") == "")
     | $w | row("2"; "K-IMAGE-MISSING"; "container \($c.name // "?") has no image\(if ($w.__src.origin // "") | IN("base","overlay") then " (Kustomize env: same site as k8s-render-scan §3e K-KZ-PHANTOM)" else "" end)")),
  ($E[] | select(.kind == "Ingress") | . as $i
     | ([(.spec.rules // [])[] | (.http.paths // [])[] | .backend] + [(.spec.defaultBackend // .spec.backend // empty)])[]
     | (.service.name // .serviceName) as $sn | (.service.port.number // (if (.servicePort | type) == "number" then .servicePort else null end)) as $pn
     | (.service.port.name // (if (.servicePort | type) == "string" then .servicePort else null end)) as $pname
     | select($sn != null)
     | ([$SVC[] | select(same_ns($i) and .metadata.name == $sn)] | first) as $svc
     | if $svc == null then $i | row("2"; "K-INGRESS-BACKEND"; "backend Service \($sn) is not rendered in this env/namespace")
       elif ($pn != null and ([$svc.spec.ports[]? | select(.port == $pn)] | length) == 0) or ($pname != null and ([$svc.spec.ports[]? | select(.name == $pname)] | length) == 0)
       then $i | row("2"; "K-INGRESS-BACKEND"; "backend \($sn):\($pn // $pname) is not a port of Service/\($sn) (\([$svc.spec.ports[]? | "\(.name // "-")=\(.port)"] | join(",")))")
       else empty end),
  ($E[] | select(.kind | IN("HTTPRoute","GRPCRoute","TLSRoute","TCPRoute","UDPRoute")) | . as $rt
     | ( ((.spec.rules // [])[] | (.backendRefs // [])[] | select((.kind // "Service") == "Service" and (.group // "") == "") | . as $b
          | ($b.namespace // ($rt | ns)) as $bns
          | if $bns != ($rt | ns) then
              select([$E[] | select(.kind == "ReferenceGrant" and ns == $bns) | select(any(.spec.from[]?; .kind == $rt.kind and .namespace == ($rt | ns)))] | length == 0)
              | $rt | row("2"; "K-INGRESS-BACKEND"; "\($rt.kind) backendRef \($bns)/\($b.name) crosses namespaces with no ReferenceGrant in \($bns): ResolvedRefs=False")
            else ([$SVC[] | select(ns == $bns and .metadata.name == $b.name)] | first) as $svc
              | if $svc == null then $rt | row("2"; "K-INGRESS-BACKEND"; "\($rt.kind) backendRef Service \($b.name) is not rendered in this env/namespace")
                elif $b.port != null and ([$svc.spec.ports[]? | select(.port == $b.port)] | length) == 0 then $rt | row("2"; "K-INGRESS-BACKEND"; "\($rt.kind) backendRef \($b.name):\($b.port) is not a port of the Service")
                else empty end end),
        ((.spec.parentRefs // [])[] | select((.kind // "Gateway") == "Gateway") | . as $p | ($p.namespace // ($rt | ns)) as $gns
          | ([$E[] | select(.kind == "Gateway" and ns == $gns and .metadata.name == $p.name)] | first) as $g | select($g != null)
          | [$g.spec.listeners[]? | select($p.sectionName == null or .name == $p.sectionName)] as $ls
          | if ($ls | length) == 0 then $rt | row("2"; "K-ROUTE-PARENT"; "parentRef \($gns)/\($p.name) sectionName \($p.sectionName) names no listener")
            elif all($ls[]; (.allowedRoutes.namespaces.from // "Same") == "Same") and $gns != ($rt | ns)
            then $rt | row("2"; "K-ROUTE-PARENT"; "Gateway \($gns)/\($p.name) admits routes from its own namespace only (allowedRoutes Same): the route is never attached")
            else empty end) )),
  # ---------------------------------------------------------------- § 3 network paths
  ($WL[] | . as $w | egress_np($w; $NP) as $pol | select(($pol | length) > 0) | [$pol[] | (.spec.egress // [])[]] as $rules
     | (dns_ok($rules; "UDP")) as $u | (dns_ok($rules; "TCP")) as $t | select(($u and $t) | not)
     | row("3"; "K-NP-DNS"; "egress-isolated by \($pol | map("\(.metadata.name) (\(srcref))") | join(", ")); port 53 allowed: UDP \($u), TCP \($t)\(if ($u | not) then " (every lookup fails)" else " (truncated answers fall back to TCP and fail)" end)")),
  ($WL[] | . as $w | egress_np($w; $NP) as $pol | select(($pol | length) > 0)
     | [everyc | (.env // [])[] | select(.value != null) | select(.name | test("URL|URI|HOST|ADDR|ENDPOINT|DSN|BROKER|SERVER"; "i")) | "\(.name)=\(.value | .[0:80])"] as $deps
     | select(($deps | length) > 0)
     | row("3"; "read:NP-DEPENDENCY"; "egress-isolated by \($pol | map(.metadata.name) | join(",")); configured dependencies to trace through the egress rules: \($deps | join(" · "))")),
  ($E[] | select((.kind | IN("CiliumNetworkPolicy","CiliumClusterwideNetworkPolicy","GlobalNetworkPolicy"))
         or (.kind == "NetworkPolicy" and ((.apiVersion // "") | startswith("projectcalico.org/"))))
     | row("3"; "read:NP-CNI"; "\(.apiVersion) policy: not modelled by the join; read its egress for port 53 and the configured dependencies")),
  # ---------------------------------------------------------------- § 4 namespaces, ConfigMap size
  ($E | map(select(ns != "" and .kind != "Namespace")) | group_by(ns)[] | . as $g | ($g[0] | ns) as $n
     | select($n | IN("default","kube-system","kube-public","kube-node-lease") | not)
     | select([$E[] | select(.kind == "Namespace" and .metadata.name == $n)] | length == 0)
     | ([$NSOBJ[] | select(.n == $n) | .e] | unique) as $else
     | $g[0] | row("4"; "K-NS-MISSING"; "\($g | length) object(s) in namespace \($n), which this env does not create\(if ($else | length) > 0 then "; created only by env \($else | join(",")) (apply order)" else "" end)")),
  ($CFG[] | (([(.data // {})[] | tostring | utf8bytelength] | add // 0) + ([(.binaryData // {})[] | (length * 3 / 4 | floor)] | add // 0)
             + ([(.data // {}), (.binaryData // {}) | keys[] | utf8bytelength] | add // 0)) as $b
     | select($b > 943718)
     | row("4"; "K-CM-SIZE"; "\(.kind) data is \($b) bytes\(if $b > 1048576 then " (over the 1 MiB object limit: the apply fails)" else " (within 10 % of the 1 MiB limit)" end)")),
  # ---------------------------------------------------------------- § 5 Jobs and CronJobs
  ($E[] | select(.kind == "CronJob") | . as $cj
     | [ (if (.spec.concurrencyPolicy // "Allow") == "Allow" then "concurrencyPolicy \(.spec.concurrencyPolicy // "unset (Allow)")" else empty end),
         (if .spec.startingDeadlineSeconds == null then "startingDeadlineSeconds unset" else empty end),
         (if .spec.jobTemplate.spec.activeDeadlineSeconds == null then "activeDeadlineSeconds unset" else empty end) ] as $miss
     | select(($miss | length) > 0)
     | row("5"; "K-CRON"; "schedule \(.spec.schedule | tojson); \($miss | join("; ")); backoffLimit \(.spec.jobTemplate.spec.backoffLimit // "unset (6)"); runs: \([$cj | everyc | ((.command // []) + (.args // [])) | join(" ") | .[0:80]] | join(" | "))")),
  ($E[] | select(.kind == "Job") | select(.spec.activeDeadlineSeconds == null or (.spec.backoffLimit // 6) > 3)
     | row("5"; "K-JOB"; "activeDeadlineSeconds \(.spec.activeDeadlineSeconds // "unset"); backoffLimit \(.spec.backoffLimit // "unset (6)") (THR-RES-RETRY money_moving max 3); runs: \([everyc | ((.command // []) + (.args // [])) | join(" ") | .[0:80]] | join(" | "))")),
  ($E[] | select(.kind == "CronJob") | select((.spec.schedule // "") | test("(^|\\s)(CRON_)?TZ="))
     | row("5"; "K-CRON-TZ"; "schedule \(.spec.schedule | tojson) carries a TZ prefix: the API server rejects it; use spec.timeZone")),
  ($E[] | select(.kind == "CronJob") | select(.spec.timeZone == null) | select((.spec.schedule // "") | test("^\\s*\\S+\\s+[0-9]") and (test("TZ=") | not))
     | row("5"; "K-CRON-TZ"; "fixed-hour schedule \(.spec.schedule | tojson) with no timeZone: runs in the controller's zone (UTC on managed clusters) — read the intent")),
  ($E[] | select(.kind | IN("Job","CronJob")) | select(ps.restartPolicy == "OnFailure")
     | row("5"; "read:K-JOB-RESTART"; "restartPolicy OnFailure: failures restart the container in place; read backoffLimit and podFailurePolicy against what one run does twice")),
  # ---------------------------------------------------------------- § 6 RBAC and identity wiring
  ($WL[] | . as $w | sa_name as $sa | select($sa != "default")
     | select([$SA[] | select(.metadata.name == $sa and same_ns($w))] | length == 0)
     | ([$SAALL[] | select(.n == $sa and .ns == ($w | ns)) | .e] | unique) as $else
     | row("6"; "K-SA-MISSING"; "serviceAccountName \($sa) is not rendered in this env/namespace\(if ($else | length) > 0 then "; rendered by env \($else | join(","))" else "; read the platform inventory for its owner" end): pods are rejected (serviceaccount not found)")),
  ($RB[] | . as $b | .roleRef as $r
     | if .kind == "ClusterRoleBinding" and $r.kind == "Role" then row("6"; "K-RBAC-DANGLING"; "ClusterRoleBinding roleRef kind Role \($r.name): only a ClusterRole is valid")
       elif $r.kind == "Role" then
         select([$ROLE[] | select(.metadata.name == $r.name and same_ns($b))] | length == 0)
         | ([$ROLE[] | select(.metadata.name == $r.name) | ns] | unique) as $other
         | row("6"; "K-RBAC-DANGLING"; "roleRef Role/\($r.name) is not rendered in the binding's namespace\(if ($other | length) > 0 then "; it exists in \($other | join(",")): a roleRef cannot cross namespaces" else "" end)")
       elif $r.kind == "ClusterRole" then
         select(($r.name | builtin_cr) | not) | select([$CROLE[] | select(.metadata.name == $r.name)] | length == 0)
         | row("6"; "K-RBAC-DANGLING"; "roleRef ClusterRole/\($r.name) is not rendered and is not built in: read the inventory for the chart that creates it")
       else empty end),
  ($RB[] | . as $b | (.subjects // [])[] | select(.kind == "ServiceAccount") | (.namespace // ($b | ns)) as $sns | .name as $sn
     | select($sn != "default") | select([$SA[] | select(.metadata.name == $sn and ns == $sns)] | length == 0)
     | ([$SAALL[] | select(.n == $sn and .ns == $sns) | .e] | unique) as $else
     | $b | row("6"; "K-RBAC-DANGLING"; "subject ServiceAccount \($sns)/\($sn) is not rendered in this env\(if ($else | length) > 0 then "; rendered by env \($else | join(","))" else "" end): the grant reaches no pod")),
  ($WL[] | . as $w | sa_name as $sa | ([$SA[] | select(.metadata.name == $sa and same_ns($w))] | first) as $sao
     | select((if ps.automountServiceAccountToken != null then ps.automountServiceAccountToken else $sao.automountServiceAccountToken end) == false)   # `//` treats false as absent
     | row("6"; "read:AUTOMOUNT-OFF"; "token not mounted (\(if ps.automountServiceAccountToken == false then "pod spec" else "ServiceAccount \($sa)" end)): a finding only if the code or image calls the API (grep 6d)")),
  ($WL[] | . as $w | select([everyc | ((.command // []) + (.args // []) + [(.env // [])[] | "\(.name)=\(.value // "")"]) | join(" ")] | join(" ") | test("leader-elect(ion)?(=true)?(\\s|$)|LEADER_ELECT(ION)?=true"; "i"))
     | select([everyc | ((.command // []) + (.args // [])) | join(" ")] | join(" ") | test("leader-elect(ion)?=false") | not)
     | sa_name as $sa
     | [$RB[] | . as $b | select(any(.subjects[]?; .kind == "ServiceAccount" and .name == $sa and (.namespace // ($b | ns)) == ($w | ns))) | .roleRef + {bns: ($b | ns)}] as $refs
     | [$refs[] | . as $r | ($ROLE + $CROLE)[] | select(.kind == $r.kind and .metadata.name == $r.name and (.kind == "ClusterRole" or ns == $r.bns)) | (.rules // [])[]] as $rules
     | select(any($refs[]; .name | test("^(cluster-admin|admin|edit|system:.*)$")) | not)
     | select(any($rules[]; (has_v(.apiGroups; "coordination.k8s.io") or has_v(.apiGroups; "*")) and (has_v(.resources; "leases") or has_v(.resources; "*"))
                 and (has_v(.verbs; "*") or (has_v(.verbs; "get") and has_v(.verbs; "create") and has_v(.verbs; "update")))) | not)
     | row("6"; "K-RBAC-VERB"; "leader election is on, but ServiceAccount \($sa)'s rendered bindings (\($refs | map("\(.kind)/\(.name)") | join(",") | if . == "" then "none" else . end)) grant no get/create/update on coordination.k8s.io leases"))
  )
JQEOF

# ---------------------------------------------------------------- self-test ----------------------
if [ "$SELFTEST" -eq 1 ]; then
  ME="$0"; SH=bash; [ -n "${ZSH_VERSION:-}" ] && SH=zsh
  T="$(mktemp -d "${TMPDIR:-/tmp}/wiring-selftest.XXXXXX")"; trap 'rm -rf "$T"' EXIT
  cat > "$T/render-prod.json" <<'EOF'
[
 {"apiVersion":"v1","kind":"Namespace","metadata":{"name":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/ns.yaml","line":1}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"api","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/api.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"api"}},"template":{"metadata":{"labels":{"app":"api"}},"spec":{"serviceAccountName":"api-sa",
   "containers":[{"name":"api","image":"r/api@sha256:0","ports":[{"name":"http","containerPort":8080}],
     "env":[{"name":"DATABASE_URL","value":"postgres://db.shop:5432/app"},{"name":"TOKEN","valueFrom":{"secretKeyRef":{"name":"api-token","key":"t"}}}],
     "envFrom":[{"configMapRef":{"name":"api-cfg"}}],"volumeMounts":[{"name":"cfg","mountPath":"/etc/a.ini","subPath":"a.ini"}]}],
   "volumes":[{"name":"cfg","configMap":{"name":"api-cfg"}}]}}}},
 {"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"api-cfg","namespace":"shop"},"data":{"a.ini":"x=1"},"__src":{"env":"prod","origin":"raw","file":"k/api.yaml","line":30}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"web","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/web.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"web"}},"template":{"metadata":{"labels":{"app":"web"},"annotations":{"checksum/config":"abc"}},"spec":{
   "containers":[{"name":"web","image":"r/web@sha256:0","ports":[{"name":"http","containerPort":3000}],"envFrom":[{"configMapRef":{"name":"web-cfg"}}]}]}}}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"edge","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/edge.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"edge"}},"template":{"metadata":{"labels":{"app":"edge"},"annotations":{"example.com/config-revision":"7"}},"spec":{
   "containers":[{"name":"caddy","image":"caddy:2.11","args":["caddy","run","--config","/etc/caddy/Caddyfile"],"volumeMounts":[{"name":"c","mountPath":"/etc/caddy"}]}],
   "volumes":[{"name":"c","configMap":{"name":"edge-conf"}}]}}}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"ctl","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/ctl.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"ctl"}},"template":{"metadata":{"labels":{"app":"ctl"}},"spec":{"serviceAccountName":"ctl","automountServiceAccountToken":false,
   "containers":[{"name":"ctl","image":"r/ctl@sha256:0","args":["--leader-elect"]}]}}}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"cfgd","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/cfgd.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"cfgd"}},"template":{"metadata":{"labels":{"app":"cfgd"}},"spec":{
   "containers":[{"name":"c","image":"r/c@sha256:0","envFrom":[{"configMapRef":{"name":"gen-cfg-5t8f2m9k7b"}},{"configMapRef":{"name":"frozen-v3"}}]}]}}}},
 {"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"frozen-v3","namespace":"shop"},"immutable":true,"data":{"a":"b"},"__src":{"env":"prod","origin":"raw","file":"k/cfgd.yaml","line":20}},
 {"apiVersion":"v1","kind":"ServiceAccount","metadata":{"name":"ctl","namespace":"shop"},"__src":{"env":"prod","origin":"raw","file":"k/ctl.yaml","line":20}},
 {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"RoleBinding","metadata":{"name":"ctl","namespace":"shop"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"ctl-role"},
  "subjects":[{"kind":"ServiceAccount","name":"ctl"},{"kind":"ServiceAccount","name":"ghost","namespace":"shop"}],"__src":{"env":"prod","origin":"raw","file":"k/ctl.yaml","line":25}},
 {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"Role","metadata":{"name":"ctl-role","namespace":"ops"},"rules":[{"apiGroups":["coordination.k8s.io"],"resources":["leases"],"verbs":["get","create","update"]}],"__src":{"env":"prod","origin":"raw","file":"k/ctl.yaml","line":40}},
 {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRoleBinding","metadata":{"name":"view-all"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"view"},
  "subjects":[{"kind":"ServiceAccount","name":"ctl","namespace":"shop"}],"__src":{"env":"prod","origin":"raw","file":"k/ctl.yaml","line":50}},
 {"apiVersion":"v1","kind":"Service","metadata":{"name":"api","namespace":"shop"},"spec":{"selector":{"app":"api"},"ports":[{"port":80,"targetPort":"web"}]},"__src":{"env":"prod","origin":"raw","file":"k/svc.yaml","line":1}},
 {"apiVersion":"v1","kind":"Service","metadata":{"name":"web","namespace":"shop"},"spec":{"selector":{"app":"web"},"ports":[{"name":"http","port":80,"targetPort":"http"}]},"__src":{"env":"prod","origin":"raw","file":"k/svc.yaml","line":10}},
 {"apiVersion":"v1","kind":"Service","metadata":{"name":"lost","namespace":"shop"},"spec":{"selector":{"app":"api-server"},"ports":[{"port":80}]},"__src":{"env":"prod","origin":"raw","file":"k/svc.yaml","line":20}},
 {"apiVersion":"v1","kind":"Service","metadata":{"name":"ext-db","namespace":"shop"},"spec":{"ports":[{"port":5432}]},"__src":{"env":"prod","origin":"raw","file":"k/svc.yaml","line":30}},
 {"apiVersion":"networking.k8s.io/v1","kind":"Ingress","metadata":{"name":"web","namespace":"shop"},"spec":{"rules":[{"http":{"paths":[
   {"path":"/","pathType":"Prefix","backend":{"service":{"name":"web","port":{"number":80}}}},
   {"path":"/api","pathType":"Prefix","backend":{"service":{"name":"api","port":{"number":8080}}}},
   {"path":"/x","pathType":"Prefix","backend":{"service":{"name":"gone","port":{"name":"http"}}}}]}}]},"__src":{"env":"prod","origin":"raw","file":"k/ing.yaml","line":1}},
 {"apiVersion":"gateway.networking.k8s.io/v1","kind":"Gateway","metadata":{"name":"gw","namespace":"infra"},"spec":{"listeners":[{"name":"http","port":80,"protocol":"HTTP"}]},"__src":{"env":"prod","origin":"raw","file":"k/gw.yaml","line":1}},
 {"apiVersion":"gateway.networking.k8s.io/v1","kind":"HTTPRoute","metadata":{"name":"web","namespace":"shop"},"spec":{"parentRefs":[{"name":"gw","namespace":"infra"}],
   "rules":[{"backendRefs":[{"name":"web","port":80},{"name":"pay","namespace":"pay","port":80}]}]},"__src":{"env":"prod","origin":"raw","file":"k/gw.yaml","line":10}},
 {"apiVersion":"networking.k8s.io/v1","kind":"NetworkPolicy","metadata":{"name":"deny","namespace":"shop"},"spec":{"podSelector":{},"policyTypes":["Ingress","Egress"]},"__src":{"env":"prod","origin":"raw","file":"k/np.yaml","line":1}},
 {"apiVersion":"networking.k8s.io/v1","kind":"NetworkPolicy","metadata":{"name":"dns-udp","namespace":"shop"},"spec":{"podSelector":{"matchLabels":{"app":"web"}},"policyTypes":["Egress"],
   "egress":[{"ports":[{"port":53,"protocol":"UDP"}]}]},"__src":{"env":"prod","origin":"raw","file":"k/np.yaml","line":10}},
 {"apiVersion":"networking.k8s.io/v1","kind":"NetworkPolicy","metadata":{"name":"dns-both","namespace":"shop"},"spec":{"podSelector":{"matchExpressions":[{"key":"app","operator":"In","values":["edge","ctl","cfgd"]}]},"policyTypes":["Egress"],
   "egress":[{"to":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"kube-system"}}}],"ports":[{"port":53,"protocol":"UDP"},{"port":53,"protocol":"TCP"}]}]},"__src":{"env":"prod","origin":"raw","file":"k/np.yaml","line":20}},
 {"apiVersion":"batch/v1","kind":"CronJob","metadata":{"name":"invoice","namespace":"shop"},"spec":{"schedule":"0 3 * * *","jobTemplate":{"spec":{"template":{"spec":{"restartPolicy":"Never","containers":[{"name":"i","image":"r/i@sha256:0","args":["send-invoices"]}]}}}}},"__src":{"env":"prod","origin":"raw","file":"k/cron.yaml","line":1}},
 {"apiVersion":"batch/v1","kind":"CronJob","metadata":{"name":"tidy","namespace":"shop"},"spec":{"schedule":"*/10 * * * *","timeZone":"Etc/UTC","concurrencyPolicy":"Forbid","startingDeadlineSeconds":120,
   "jobTemplate":{"spec":{"activeDeadlineSeconds":300,"template":{"spec":{"restartPolicy":"Never","containers":[{"name":"t","image":"r/t@sha256:0"}]}}}}},"__src":{"env":"prod","origin":"raw","file":"k/cron.yaml","line":20}},
 {"apiVersion":"batch/v1","kind":"CronJob","metadata":{"name":"tz","namespace":"shop"},"spec":{"schedule":"CRON_TZ=UTC 0 1 * * *","concurrencyPolicy":"Forbid","startingDeadlineSeconds":60,
   "jobTemplate":{"spec":{"activeDeadlineSeconds":60,"template":{"spec":{"restartPolicy":"Never","containers":[{"name":"t","image":"r/t@sha256:0"}]}}}}},"__src":{"env":"prod","origin":"raw","file":"k/cron.yaml","line":40}},
 {"apiVersion":"batch/v1","kind":"Job","metadata":{"name":"migrate","namespace":"shop"},"spec":{"template":{"spec":{"restartPolicy":"Never","containers":[{"name":"m","image":"r/m@sha256:0","args":["migrate"]}]}}},"__src":{"env":"prod","origin":"raw","file":"k/job.yaml","line":1}},
 {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"lone","namespace":"billing"},"__src":{"env":"prod","origin":"raw","file":"k/lone.yaml","line":1},
  "spec":{"selector":{"matchLabels":{"app":"lone"}},"template":{"metadata":{"labels":{"app":"lone"}},"spec":{"containers":[{"name":"l"}]}}}},
 {"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"big","namespace":"shop"},"data":{"blob":"BIG"},"__src":{"env":"prod","origin":"raw","file":"k/big.yaml","line":1}}
]
EOF
  # a 1.1 MB ConfigMap value, built without a 1 MB literal in this file
  head -c 1100000 /dev/zero | tr '\0' 'a' > "$T/blob"
  jq --rawfile b "$T/blob" 'map(if .metadata.name == "big" then .data.blob = $b else . end)' "$T/render-prod.json" > "$T/x" && mv "$T/x" "$T/render-prod.json"; rm -f "$T/blob"
  printf '[{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"billing"},"__src":{"env":"platform","origin":"raw","file":"p/ns.yaml","line":1}}]\n' > "$T/render-platform.json"
  out="$("$SH" "$ME" "$T")"; rc=$?
  fails=0; checks=0
  has() { checks=$((checks + 1)); if printf '%s\n' "$out" | awk -F'\t' -v c="$2" -v o="$3" -v d="$4" '$2 == c && $5 == o && index($6, d) { f = 1 } END { exit !f }'; then
      printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); fi; }
  hasnt() { checks=$((checks + 1)); if printf '%s\n' "$out" | awk -F'\t' -v c="$2" -v o="$3" '$2 == c && $5 == o { f = 1 } END { exit !f }'; then
      printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); else printf 'PASS  %s\n' "$1"; fi; }
  checks=$((checks + 1)); if [ "$rc" -eq 0 ]; then printf 'PASS  exit 0\n'; else printf 'FAIL  exit %s\n' "$rc"; fails=$((fails + 1)); fi
  has   "§1 CONFIG-ROLL: envFrom ConfigMap with no control"            K-CONFIG-ROLL Deployment/shop/api "ConfigMap/api-cfg via env"
  has   "§1 CONFIG-ROLL: a Secret not rendered is still a consumer"    K-CONFIG-ROLL Deployment/shop/api "Secret/api-token via env; not rendered"
  has   "§1 CONFIG-ROLL: revision annotation = partial (§ 43) + proxy args" K-CONFIG-ROLL Deployment/shop/edge "partial (example.com/config-revision"
  has   "§1 CONFIG-ROLL: the proxy row names the image and its args"   K-CONFIG-ROLL Deployment/shop/edge "proxy caddy:2.11 args=caddy run"
  hasnt "§1 decoy: checksum annotation is a full control"              K-CONFIG-ROLL Deployment/shop/web
  hasnt "§1 decoy: hash-suffixed and immutable ConfigMaps"             K-CONFIG-ROLL Deployment/shop/cfgd
  has   "§1 SUBPATH"                                                   K-SUBPATH Deployment/shop/api "mounts volume cfg at a subPath"
  has   "§2 SVC-SELECTOR: matches nothing"                             K-SVC-SELECTOR Service/shop/lost "matches no pod template"
  has   "§2 SVC-PORT: named targetPort undeclared"                     K-SVC-PORT Service/shop/api "targetPort web"
  hasnt "§2 decoy: selector-less Service"                              K-SVC-SELECTOR Service/shop/ext-db
  hasnt "§2 decoy: Service whose named port exists"                    K-SVC-PORT Service/shop/web
  has   "§2 IMAGE-MISSING"                                             K-IMAGE-MISSING Deployment/billing/lone "has no image"
  has   "§2 INGRESS-BACKEND: Service not rendered"                     K-INGRESS-BACKEND Ingress/shop/web "Service gone is not rendered"
  has   "§2 INGRESS-BACKEND: port not on the Service"                  K-INGRESS-BACKEND Ingress/shop/web "api:8080 is not a port"
  has   "§2 HTTPRoute: cross-namespace backendRef, no ReferenceGrant"  K-INGRESS-BACKEND HTTPRoute/shop/web "no ReferenceGrant in pay"
  has   "§2 HTTPRoute: Gateway admits its own namespace only"          K-ROUTE-PARENT HTTPRoute/shop/web "allowedRoutes Same"
  has   "§3 NP-DNS: default-deny egress, no port 53"                   K-NP-DNS Deployment/shop/api "UDP false, TCP false"
  has   "§3 NP-DNS: UDP only (TCP fallback fails)"                     K-NP-DNS Deployment/shop/web "UDP true, TCP false"
  has   "§3 NP-DNS: the row cites the policy file:line (the fix site)"  K-NP-DNS Deployment/shop/web "dns-udp (k/np.yaml:10)"
  hasnt "§3 decoy: UDP + TCP 53 via matchExpressions"                  K-NP-DNS Deployment/shop/edge
  has   "§3 read: configured dependency under an egress policy"        read:NP-DEPENDENCY Deployment/shop/api "DATABASE_URL=postgres://db.shop:5432"
  has   "§4 NS-MISSING: created only by another env"                   K-NS-MISSING Deployment/billing/lone "created only by env platform"
  hasnt "§4 decoy: namespace rendered in the same env"                 K-NS-MISSING Deployment/shop/api
  has   "§4 CM-SIZE over 1 MiB"                                        K-CM-SIZE ConfigMap/shop/big "over the 1 MiB"
  has   "§5 CRON: Allow + no deadlines"                                K-CRON CronJob/shop/invoice "concurrencyPolicy unset (Allow)"
  hasnt "§5 decoy: CronJob done right"                                 K-CRON CronJob/shop/tidy
  has   "§5 CRON-TZ: CRON_TZ prefix is rejected"                       K-CRON-TZ CronJob/shop/tz "carries a TZ prefix"
  has   "§5 CRON-TZ: fixed hour, no timeZone (read)"                   K-CRON-TZ CronJob/shop/invoice "fixed-hour schedule"
  has   "§5 JOB: no deadline, default backoff 6"                       K-JOB Job/shop/migrate "backoffLimit unset (6)"
  has   "§6 SA-MISSING"                                                K-SA-MISSING Deployment/shop/api "api-sa is not rendered"
  has   "§6 roleRef Role lives in another namespace"                   K-RBAC-DANGLING RoleBinding/shop/ctl "it exists in ops"
  has   "§6 subject ServiceAccount not rendered"                       K-RBAC-DANGLING RoleBinding/shop/ctl "shop/ghost"
  hasnt "§6 decoy: built-in ClusterRole view"                          K-RBAC-DANGLING ClusterRoleBinding/-/view-all
  has   "§6 automount off: a read prompt, not a finding"               read:AUTOMOUNT-OFF Deployment/shop/ctl "pod spec"
  has   "§6 leader election with no lease verbs (the Role is unreachable)" K-RBAC-VERB Deployment/shop/ctl "grant no get/create/update"
  printf '%s\n' "self-test ($SH): $((checks - fails))/$checks passed"
  [ "$fails" -eq 0 ]; exit $?
fi

# ---------------------------------------------------------------- run ----------------------------
[ -n "$SCAN" ] || { printf 'usage: wiring.sh <scan-dir> [--repo=<repo-root>] | --self-test\n' >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'NOT-INSTALLED: jq (brew install jq) — every § is blocked\n' >&2; exit 4; }
FILES="$(find "$SCAN" -maxdepth 1 -name 'render-*.json' 2>/dev/null | sort)"
[ -n "$FILES" ] || { printf 'no render-*.json in %s: run k8s-render-scan/scripts/render.sh first (§ 0)\n' "$SCAN" >&2; exit 4; }

# Namespaces something outside the render creates: CD targets with CreateNamespace=true, inventory lines with
# --create-namespace, and (with --repo) `kubectl create namespace X` lines. Added as synthetic Namespace objects
# tagged to every env, so the § 4 join treats them as existing.
EXTRA_NS="$( { [ -f "$SCAN/inventory-platform.tsv" ] && awk -F'\t' 'NR > 1 && $9 ~ /--create-namespace/ && $8 != "-" { print $8 }' "$SCAN/inventory-platform.tsv"
  [ -f "$SCAN/cd-targets.tsv" ] && awk -F'\t' 'NR > 1 && $8 ~ /CreateNamespace=true/ { n = $7; sub(/^.*\//, "", n); if (n != "-") print n }' "$SCAN/cd-targets.tsv"
  [ -n "$REPO" ] && grep -rhoE --include='*.md' --include='*.sh' --include='*.bash' --include='*.yml' --include='*.yaml' --include=Makefile \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor 'kubectl[[:space:]]+create[[:space:]]+(ns|namespace)[[:space:]]+[a-z0-9-]+' "$REPO" 2>/dev/null | awk '{ print $NF }'
  } | sort -u | tr '\n' ' ')"
ENVS="$(printf '%s\n' "$FILES" | while IFS= read -r f; do b="$(basename "$f" .json)"; printf '%s ' "${b#render-}"; done)"
find "$SCAN" -maxdepth 1 -name 'render-*.json' -exec jq -c '.[]' {} + | jq -s -r --arg extra "$EXTRA_NS" --arg envs "$ENVS" '
  . + [ ($extra | split(" ") | map(select(. != "")))[] as $n | ($envs | split(" ") | map(select(. != "")))[] as $e
                    | {apiVersion: "v1", kind: "Namespace", metadata: {name: $n}, __src: {env: $e, origin: "platform", file: "inventory", line: null}} ]
  | map(select(type == "object" and .kind != null))' | jq -r "$JQ"
