#!/usr/bin/env python3
"""cidr-overlap.py — network-exposure-audit: the address plan (§ 2) and the joins § 1 and § 3 need.

Why a walker and not a grep: an overlap is a fact about two allocations in two files (a VPC in one
root, a pod range in a runbook flag), a NACL return path is a fact about two rule lists, and a
subnet inside its own VPC is containment, not a conflict. A pairwise regex pipe reports the
subnet-in-VPC pair as an overlap and cannot tell a pod range from a NetworkPolicy ipBlock.

Usage:  python3 -I cidr-overlap.py <file|dir> ... [plan.json ...]
            reads *.tf, *.tfvars, *.y*ml, *.json (Terraform plan JSON: planned_values; Docker daemon
            "bip"/"base"), and CLI flags in *.md, *.sh, *.bash, Makefile (runbooks are deploy sources)
            [--alloc=<kind>=<cidr> ...]   a range created outside the repo (a provider default VPC, an
                                          on-prem network from a doc), kind vpc|subnet|pods|services|remote|docker
        python3 -I cidr-overlap.py --self-test
Prints: one TSV row per candidate:  §  CLASS  source:line  subject  detail
          §1 N3-NACL-RETURN · N-PEER-ROUTE      §2 N7-OVERLAP · N7-UNRESOLVED
          §3 N8-V6-ROUTE · N8-V6-NACL · N8-V6-SG-EGRESS · N-PRIVDNS
        Allocations (VPC, subnet, pod, service, remote, docker ranges) are compared; references
        (security-group cidr_blocks, NetworkPolicy ipBlock) are not allocations and are never compared.
Stderr: the ledger: files read per type, allocations per kind, unresolved values, peering/TGW/VPN objects.
Exit:   0 ran · 2 usage · 3 self-test failed. Stdlib only; reads files, writes nothing.
"""
import ipaddress, itertools, json, os, re, sys

SKIP_DIRS = {"node_modules", ".git", ".terraform", "vendor", "cdk.out", "test", "tests", "testdata",
             "__tests__", "fixtures", "examples", "example"}
# (resource type[/nested block], attribute) -> allocation kind
ALLOC = {
    ("aws_vpc", "cidr_block"): "vpc", ("aws_vpc", "ipv6_cidr_block"): "vpc",
    ("aws_vpc_ipv4_cidr_block_association", "cidr_block"): "vpc",
    ("aws_subnet", "cidr_block"): "subnet", ("aws_subnet", "ipv6_cidr_block"): "subnet",
    ("google_compute_subnetwork", "ip_cidr_range"): "vpc",           # GCP: subnetworks are the allocations
    ("google_compute_subnetwork/secondary_ip_range", "ip_cidr_range"): "pods",
    ("azurerm_virtual_network", "address_space"): "vpc", ("azurerm_subnet", "address_prefixes"): "subnet",
    ("digitalocean_vpc", "ip_range"): "vpc",
    ("digitalocean_kubernetes_cluster", "cluster_subnet"): "pods",
    ("digitalocean_kubernetes_cluster", "service_subnet"): "services",
    ("aws_eks_cluster/kubernetes_network_config", "service_ipv4_cidr"): "services",
    ("google_container_cluster", "cluster_ipv4_cidr"): "pods",
    ("google_container_cluster/ip_allocation_policy", "cluster_ipv4_cidr_block"): "pods",
    ("google_container_cluster/ip_allocation_policy", "services_ipv4_cidr_block"): "services",
    ("azurerm_kubernetes_cluster/network_profile", "pod_cidr"): "pods",
    ("azurerm_kubernetes_cluster/network_profile", "pod_cidrs"): "pods",
    ("azurerm_kubernetes_cluster/network_profile", "service_cidr"): "services",
    ("azurerm_kubernetes_cluster/network_profile", "service_cidrs"): "services",
    ("azurerm_kubernetes_cluster/network_profile", "docker_bridge_cidr"): "docker",
    ("aws_vpn_connection", "local_ipv4_network_cidr"): "remote",
    ("aws_vpn_connection_route", "destination_cidr_block"): "remote",
    ("azurerm_local_network_gateway", "address_space"): "remote",
}
LINKS = re.compile(r"^(aws_vpc_peering_connection|aws_ec2_transit_gateway_vpc_attachment|aws_vpn_connection|"
                   r"google_compute_network_peering|azurerm_virtual_network_peering|digitalocean_vpc_peering)$")
FLAGS = [(re.compile(r"--(cluster-subnet|pod-network-cidr|cluster-cidr|cluster-ipv4-cidr)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "pods"),
         (re.compile(r"--(service-subnet|service-cidr|service-cluster-ip-range|services-ipv4-cidr)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "services"),
         (re.compile(r"\bvpcs\s+create\b.*--(ip-range)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "vpc"),
         (re.compile(r"\bsubnets\s+create\b.*--(range)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "vpc"),
         (re.compile(r"\bvnet\s+create\b.*--(address-prefixes?)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "vpc"),
         (re.compile(r"\bnetwork\s+create\b.*--(subnet)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "docker"),
         (re.compile(r"--(bip)[= ]+[\"']?([0-9a-fA-F:.]+/\d+)"), "docker")]
YAML_KEYS = re.compile(r"^\s*-?\s*(podSubnet|serviceSubnet|podCIDR|clusterCIDR|serviceClusterIPRange|subnet|cidr)\s*:\s*[\"']?([0-9a-fA-F:.]+/\d+)")
EPHEMERAL = (1024, 32768, 49152, 65535)       # NAT/ELB 1024-65535, Linux 32768-60999, Windows 49152-65535


def net(s):
    try:
        n = ipaddress.ip_network(s.strip().strip('"'), strict=False)
        return None if n.prefixlen == 0 else n
    except ValueError:
        return None


class B:
    def __init__(self, name, labels, line, src):
        self.name, self.labels, self.line, self.src, self.attrs, self.kids = name, labels, line, src, {}, []


def segments(text):
    """HCL text -> (line, segment) with braces and top-level commas split out, comments stripped."""
    out, buf, start, q, br, ln, i = [], "", 1, False, 0, 1, 0
    while i < len(text):
        c = text[i]
        if not q and (c == "#" or text.startswith("//", i)):
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        if not q and text.startswith("/*", i):
            j = text.find("*/", i); seg = text[i:j if j >= 0 else len(text)]; ln += seg.count("\n"); i = (j + 2) if j >= 0 else len(text); continue
        if c == '"' and (i == 0 or text[i - 1] != "\\"):
            q = not q
        if not q and c in "[(":
            br += 1
        elif not q and c in "])":
            br -= 1
        if not q and br == 0 and c in "{},\n":
            if c == "{":
                out.append((start, buf + "{")); buf = ""
            elif c == "}":
                if buf.strip():
                    out.append((start, buf))
                out.append((ln, "}")); buf = ""
            elif buf.strip():
                out.append((start, buf)); buf = ""
            if c == "\n":
                ln += 1
            i += 1; start = ln
            if not buf.strip():
                start = ln
            continue
        if c == "\n":
            ln += 1
        if not buf.strip():
            start = ln
        buf += c; i += 1
    if buf.strip():
        out.append((start, buf))
    return out


def hcl(path, rel):
    root = B("root", [], 0, rel); st = [root]
    for ln, seg in segments(open(path, errors="replace").read()):
        s = seg.strip()
        if s.endswith("{"):
            m = re.match(r'^([\w-]+)((?:\s+"[^"]*")*)\s*=?\s*$', s[:-1].strip())
            b = B(m.group(1) if m else s[:-1].strip(), re.findall(r'"([^"]*)"', m.group(2)) if m else [], ln, rel)
            st[-1].kids.append(b); st.append(b)
        elif s == "}":
            if len(st) > 1:
                st.pop()
        else:
            m = re.match(r"^([\w-]+)\s*=\s*(.+)$", s, re.S)
            if m:
                st[-1].attrs[m.group(1)] = (m.group(2).strip(), ln)
    return root


def plan_blocks(doc, rel):
    """Terraform plan JSON -> the same block shape (one block per resource instance)."""
    root = B("root", [], 0, rel)

    def lit(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(v)
        if isinstance(v, str):
            return '"%s"' % v
        if isinstance(v, list) and all(isinstance(x, str) for x in v):
            return "[" + ", ".join('"%s"' % x for x in v) + "]"
        return None

    def walk(mod):
        for r in mod.get("resources", []):
            if r.get("mode") != "managed":
                continue
            b = B("resource", [r["type"], r.get("address", r["name"])], 0, "plan:" + r.get("address", r["name"]))
            for k, v in (r.get("values") or {}).items():
                if isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
                    for x in v:
                        kid = B(k, [], 0, b.src); kid.attrs = {a: (lit(y), 0) for a, y in x.items() if lit(y) is not None}; b.kids.append(kid)
                elif lit(v) is not None:
                    b.attrs[k] = (lit(v), 0)
            root.kids.append(b)
        for c in mod.get("child_modules", []):
            walk(c)
    walk((doc.get("planned_values") or {}).get("root_module") or {})
    return root


def strs(v):
    return re.findall(r'"([^"]*)"', v or "")


def literal(v):
    return bool(v) and re.fullmatch(r'\s*(\[\s*)?("[^"$]*"\s*,?\s*)+\]?\s*', v) is not None


def resources(root):
    return [b for b in root.kids if b.name == "resource" and b.labels]


def loc(b, ln):
    return b.src if b.src.startswith("plan:") else "%s:%d" % (b.src, ln or b.line)


def run(paths, extra=()):
    rows, allocs, unresolved, files, links = [], [], [], {}, 0
    roots = []

    def add(kind, cidr, src, key):
        n = net(cidr)
        if n is not None:
            allocs.append((kind, n, src, key))

    for e in extra:                                # --alloc=<kind>=<cidr>: a range created outside the repo (a default VPC)
        k, _, c = e.partition("=")
        add(k, c, "--alloc", "stated")
    for p in paths:
        cand = []
        if os.path.isdir(p):
            for d, ds, fs in os.walk(p):
                ds[:] = [x for x in ds if x not in SKIP_DIRS]
                cand += [os.path.join(d, f) for f in fs]
        elif os.path.isfile(p):
            cand.append(p)
        for f in sorted(cand):
            rel = os.path.relpath(f) if not os.path.isabs(p) else f
            base = os.path.basename(f); ext = os.path.splitext(f)[1].lower()
            try:
                if ext in (".tf", ".tfvars"):
                    files["hcl"] = files.get("hcl", 0) + 1; r = hcl(f, rel); roots.append(r)
                    if ext == ".tfvars":
                        for k, (v, ln) in r.attrs.items():
                            if re.search(r"cidr|subnet|ip_range|address_space", k) and literal(v):
                                for s in strs(v):
                                    add(kindof(k), s, "%s:%d" % (rel, ln), k)
                elif ext == ".json":
                    t = open(f, errors="replace").read()
                    if '"planned_values"' in t:
                        files["plan"] = files.get("plan", 0) + 1; roots.append(plan_blocks(json.loads(t), rel))
                    elif re.search(r'"(bip|base)"\s*:\s*"[0-9a-fA-F:.]+/\d+"', t):
                        files["docker"] = files.get("docker", 0) + 1
                        for n, line in enumerate(t.splitlines(), 1):
                            for m in re.finditer(r'"(bip|base)"\s*:\s*"([0-9a-fA-F:.]+/\d+)"', line):
                                add("docker", m.group(2), "%s:%d" % (rel, n), m.group(1))
                elif ext in (".yaml", ".yml"):
                    files["yaml"] = files.get("yaml", 0) + 1; kind = ""; compose = "compose" in base
                    for n, line in enumerate(open(f, errors="replace"), 1):
                        if line.startswith("---"):
                            kind = ""
                        m = re.match(r"^kind:\s*(\w+)", line)
                        if m:
                            kind = m.group(1)
                        m = YAML_KEYS.match(line)
                        if m:
                            k = m.group(1)
                            if k == "cidr" and kind not in ("IPPool",):
                                pass                       # NetworkPolicy ipBlock and other references
                            elif k == "subnet" and not compose:
                                pass
                            else:
                                add({"subnet": "docker", "cidr": "pods"}.get(k, kindof(k)), m.group(2), "%s:%d" % (rel, n), k)
                        flags(line, rel, n, add)
                elif ext in (".md", ".sh", ".bash") or base == "Makefile":
                    files["runbook"] = files.get("runbook", 0) + 1
                    for n, line in enumerate(open(f, errors="replace"), 1):
                        flags(line, rel, n, add)
                        if re.search(r"\b(vpcs|networks)\s+peerings?\s+create\b", line):
                            links += 1
            except (OSError, ValueError) as e:
                print("NOT-READ\t%s\t%s" % (rel, e), file=sys.stderr)

    # --- walk HCL/plan blocks once ---
    nacls, rules, subnets6, routes6, sgs, peers, peer_refs, vpc6 = {}, [], [], 0, [], {}, {}, []
    for r in roots:
        for b in r.kids:
            if b.name == "variable" and b.labels and re.search(r"cidr|subnet|ip_range|address_space", b.labels[0]):
                v, ln = b.attrs.get("default", (None, 0))
                if literal(v):
                    for s in strs(v):
                        add(kindof(b.labels[0]), s, "%s:%d" % (b.src, ln), "var." + b.labels[0])
        for b in resources(r):
            t = b.labels[0]; name = b.labels[1] if len(b.labels) > 1 else "?"
            if LINKS.match(t):
                links += 1
            if t == "aws_vpc_peering_connection":
                peers[name] = b
            for scope, blk in [(t, b)] + [("%s/%s" % (t, k.name), k) for k in b.kids]:
                for a, (v, ln) in blk.attrs.items():
                    kind = ALLOC.get((scope, a))
                    if kind is None:
                        continue
                    if literal(v):
                        for s in strs(v):
                            add(kind, s, loc(b, ln), "%s.%s" % (t, a))
                    elif v and v not in ("null",) and not v.startswith('"'):
                        unresolved.append((loc(b, ln), "%s.%s.%s" % (t, name, a), v[:60]))
            text_refs = " ".join(v for v, _ in b.attrs.values()) + " " + " ".join(v for k in b.kids for v, _ in k.attrs.values())
            for m in re.finditer(r"aws_vpc_peering_connection\.([\w-]+)\.id", text_refs):
                if t in ("aws_route", "aws_route_table"):
                    peer_refs[m.group(1)] = peer_refs.get(m.group(1), 0) + (len([k for k in b.kids if "aws_vpc_peering_connection.%s.id" % m.group(1) in " ".join(v for v, _ in k.attrs.values())]) or 1)
            if t in ("aws_network_acl", "aws_default_network_acl"):
                nacls[name] = (b, [rule(k.attrs, k.name == "egress", b, k.line) for k in b.kids if k.name in ("ingress", "egress")])
            if t == "aws_network_acl_rule":
                m = re.search(r"aws_network_acl\.([\w-]+)\.id", b.attrs.get("network_acl_id", ("", 0))[0])
                rules.append((m.group(1) if m else "?", rule(b.attrs, b.attrs.get("egress", ("false", 0))[0] == "true", b, b.line, std=True)))
            on6 = lambda a: b.attrs.get(a, ("", 0))[0] in ("true",) or (a in b.attrs and literal(b.attrs[a][0]))
            if t == "aws_vpc" and (on6("assign_generated_ipv6_cidr_block") or on6("ipv6_cidr_block")):
                vpc6.append(b)
            if t == "aws_subnet" and (on6("assign_ipv6_address_on_creation") or on6("ipv6_native") or "ipv6_cidr_block" in b.attrs):
                subnets6.append(b)
            if t in ("aws_route", "aws_route_table"):
                vals = [b.attrs.get("destination_ipv6_cidr_block", ("", 0))[0]] + [k.attrs.get("ipv6_cidr_block", ("", 0))[0] for k in b.kids if k.name == "route"]
                routes6 += sum(1 for v in vals if '"::/0"' in v)
            if t == "aws_security_group":
                sgs.append(b)
            if t == "aws_vpc_endpoint":
                ty = b.attrs.get("vpc_endpoint_type", ('"Gateway"', 0))[0]
                if '"Interface"' in ty and b.attrs.get("private_dns_enabled", ("false", 0))[0] != "true":
                    rows.append("3\tN-PRIVDNS\t%s\t%s\tInterface endpoint, private_dns_enabled unset/false (provider default false): the service's default name still resolves to its public endpoint inside the VPC; read which hostname the clients use" % (loc(b, b.line), name))
            if t == "azurerm_private_endpoint" and not any(k.name == "private_dns_zone_group" for k in b.kids):
                rows.append("3\tN-PRIVDNS\t%s\t%s\tno private_dns_zone_group: read where the privatelink zone is linked, or the public name keeps answering publicly" % (loc(b, b.line), name))

    # --- § 1 NACL return path ---
    for acl, r in rules:
        nacls.setdefault(acl, (None, []))[1].append(r)
    for acl, (b, rs) in sorted(nacls.items()):
        if not rs:
            continue
        for r in rs:
            if r["action"] != "allow" or r["net"] is None or (r["from"] >= 1024 and r["to"] == 65535):
                continue
            back = [x for x in rs if x["egress"] != r["egress"]]
            proto = r["proto"] if r["proto"] in ("tcp", "udp") else "tcp"
            bad = [p for p in EPHEMERAL if decide(back, proto, p, r["net"]) != "allow"]
            if bad:
                way = "outbound" if r["egress"] else "inbound"
                rows.append("1\tN3-NACL-RETURN\t%s\t%s\t%s %s %s from/to %s allowed (rule %s) but the %s direction does not allow the reply to ephemeral port(s) %s"
                            % (r["src"], acl, way, proto, r["ports"], r["net"], r["no"], "egress" if not r["egress"] else "ingress", ",".join(map(str, bad))))
    for p, b in sorted(peers.items()):
        k = peer_refs.get(p, 0)
        if k < 2:
            rows.append("1\tN-PEER-ROUTE\t%s\t%s\t%d route(s) name this peering; each side's route table needs a route to the other side's CIDR" % (loc(b, b.line), p, k))

    # --- § 3 IPv6 parity (connectivity half) ---
    if subnets6 or vpc6:
        first = (subnets6 or vpc6)[0]
        if routes6 == 0:
            rows.append("3\tN8-V6-ROUTE\t%s\t%d v6 subnet(s)\tIPv6 is assigned but no route sends ::/0 anywhere (internet or egress-only gateway): v6 connections have no path" % (loc(first, first.line), len(subnets6)))
        for acl, (b, rs) in sorted(nacls.items()):
            if b is not None and rs and not any(x["net"] is not None and x["net"].version == 6 for x in rs):
                rows.append("3\tN8-V6-NACL\t%s\t%s\tcustom NACL with IPv4 rules only on a v6-enabled VPC: v6 traffic hits the implicit deny" % (loc(b, b.line), acl))
        for b in sgs:
            eg = [k for k in b.kids if k.name == "egress"]
            v4all = any('"0.0.0.0/0"' in k.attrs.get("cidr_blocks", ("", 0))[0] for k in eg)
            v6any = any("ipv6_cidr_blocks" in k.attrs for k in eg)
            if v4all and not v6any:
                rows.append("3\tN8-V6-SG-EGRESS\t%s\t%s\tegress allows 0.0.0.0/0 but no IPv6 range: v6 outbound from members is dropped (the intent reads as 'all egress')" % (loc(b, b.line), b.labels[1] if len(b.labels) > 1 else "?"))

    # --- § 2 overlaps ---
    seen = {}
    for a in allocs:
        seen.setdefault((a[0], str(a[1]), a[2]), a)
    al = sorted(seen.values(), key=lambda a: (a[2], str(a[1])))
    for a, b in itertools.combinations(al, 2):
        if a[1].version != b[1].version or a[2] == b[2] or not a[1].overlaps(b[1]):
            continue
        ks = {a[0], b[0]}
        if ks == {"vpc", "subnet"} or ks == {"subnet"}:
            continue
        rel = "equal" if a[1] == b[1] else ("contains" if a[1].supernet_of(b[1]) else ("within" if a[1].subnet_of(b[1]) else "partial"))
        rows.append("2\tN7-OVERLAP\t%s\t%s %s %s\t%s %s at %s (%s) · %s; peering/TGW/VPN objects in scope: %d"
                    % (a[2], a[0], a[1], a[3], b[0], b[1], b[2], b[3], rel, links))
    for src, what, v in unresolved:
        rows.append("2\tN7-UNRESOLVED\t%s\t%s\t= %s (read the tfvars or the plan JSON)" % (src, what, v))
    kinds = {}
    for a in seen.values():
        kinds[a[0]] = kinds.get(a[0], 0) + 1
    print("ledger: files %s · allocations %s · unresolved %d · NACLs %d · peering/TGW/VPN objects %d"
          % (dict(sorted(files.items())), dict(sorted(kinds.items())), len(unresolved), len(nacls), links), file=sys.stderr)
    return rows


def kindof(k):
    k = k.lower()
    for pat, kind in (("docker|bip|bridge", "docker"), ("service", "services"), ("pod|cluster.?(cidr|subnet|ipv4)", "pods"),
                      ("vpn|onprem|on_prem|remote|peer|customer|office", "remote"), ("subnet", "subnet"), ("", "vpc")):
        if re.search(pat, k):
            return kind


def flags(line, rel, n, add):
    for rx, kind in FLAGS:
        for m in rx.finditer(line):
            add(kind, m.group(2), "%s:%d" % (rel, n), "--" + m.group(1))


def rule(attrs, egress, b, ln, std=False):
    g = lambda k, d="": (attrs.get(k, (d, 0))[0] or d).strip('"')
    proto = g("protocol", "-1").lower()
    proto = {"6": "tcp", "17": "udp", "1": "icmp", "all": "-1"}.get(proto, proto)
    fp, tp = g("from_port", "0"), g("to_port", "0")
    fp, tp = (int(fp), int(tp)) if fp.isdigit() and tp.isdigit() else (0, 65535)
    if proto == "-1":
        fp, tp = 0, 65535
    cidr = g("cidr_block") or g("ipv6_cidr_block")
    return {"egress": egress, "proto": proto, "from": fp, "to": tp, "ports": "%d-%d" % (fp, tp) if fp != tp else str(fp),
            "action": g("rule_action" if std else "action", "allow").lower(), "no": int(g("rule_number" if std else "rule_no", "0") or 0)
            if (g("rule_number" if std else "rule_no", "0") or "0").isdigit() else 0,
            "net": ipaddress.ip_network(cidr, strict=False) if cidr and net(cidr) is not None or cidr in ("0.0.0.0/0", "::/0") else None,
            "src": loc(b, ln)}


def decide(rs, proto, port, probe):
    """First-match NACL evaluation for traffic to/from every address of `probe` on `port`."""
    partial = False
    for r in sorted(rs, key=lambda x: x["no"]):
        if r["net"] is None or r["net"].version != probe.version or r["proto"] not in ("-1", proto) or not (r["from"] <= port <= r["to"]):
            continue
        if r["net"] == probe or r["net"].supernet_of(probe):
            return "partial" if partial and r["action"] == "allow" else r["action"]
        if r["net"].overlaps(probe) and r["action"] == "deny":
            partial = True
    return "deny"


FIX = {
    "net.tf": '''
resource "aws_vpc" "a" { cidr_block = "10.0.0.0/16" }
resource "aws_vpc" "b" {
  cidr_block = "10.0.0.0/16"   # S: equal to a, and peered
}
resource "aws_vpc" "c" { cidr_block = var.vpc_c_cidr }
resource "aws_vpc_peering_connection" "ab" {
  vpc_id      = aws_vpc.a.id
  peer_vpc_id = aws_vpc.b.id
}
resource "aws_subnet" "a1" {   # D: a subnet inside its own VPC is containment
  vpc_id                          = aws_vpc.a.id
  cidr_block                      = "10.0.1.0/24"
  assign_ipv6_address_on_creation = true
}
resource "aws_eks_cluster" "k" {
  name = "k"
  kubernetes_network_config {
    service_ipv4_cidr = "10.0.128.0/20"
  }
}
resource "aws_network_acl" "app" {
  vpc_id = aws_vpc.a.id
  ingress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    from_port = 5432
    to_port = 5432
    cidr_block = "10.1.0.0/16"
  }
}
resource "aws_network_acl" "ok" {
  vpc_id = aws_vpc.a.id
  ingress { rule_no = 100, action = "allow", protocol = "tcp", from_port = 443, to_port = 443, cidr_block = "0.0.0.0/0" }
  ingress { rule_no = 110, action = "allow", protocol = "tcp", from_port = 1024, to_port = 65535, cidr_block = "0.0.0.0/0" }
  ingress { rule_no = 120, action = "allow", protocol = "-1", from_port = 0, to_port = 0, ipv6_cidr_block = "::/0" }
  egress { rule_no = 100, action = "allow", protocol = "tcp", from_port = 1024, to_port = 65535, cidr_block = "0.0.0.0/0" }
  egress { rule_no = 110, action = "allow", protocol = "tcp", from_port = 443, to_port = 443, cidr_block = "0.0.0.0/0" }
  egress { rule_no = 120, action = "allow", protocol = "-1", from_port = 0, to_port = 0, ipv6_cidr_block = "::/0" }
}
resource "aws_network_acl" "linux" {
  vpc_id = aws_vpc.a.id
  ingress { rule_no = 100, action = "allow", protocol = "tcp", from_port = 443, to_port = 443, cidr_block = "0.0.0.0/0" }
  egress { rule_no = 100, action = "allow", protocol = "tcp", from_port = 32768, to_port = 65535, cidr_block = "0.0.0.0/0" }
}
resource "aws_security_group" "web" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "dual" {
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.a.id
  service_name      = "com.amazonaws.eu-west-1.sts"
  vpc_endpoint_type = "Interface"
}
resource "aws_vpc_endpoint" "ecr" {
  vpc_id              = aws_vpc.a.id
  service_name        = "com.amazonaws.eu-west-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.a.id
  service_name = "com.amazonaws.eu-west-1.s3"
}
''',
    "ops/runbook.md": "doctl vpcs create --name v --region fra1 --ip-range 10.114.0.0/20\n"
                      "doctl kubernetes cluster create x --cluster-subnet 10.116.0.0/16 --service-subnet 10.114.64.0/19\n",
    "local/kind.yaml": "kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnetworking:\n  podSubnet: 10.0.64.0/18\n",
    "deploy/np.yaml": "kind: NetworkPolicy\nspec:\n  ingress:\n    - from:\n        - ipBlock:\n            cidr: 10.0.0.0/16\n",
    "compose.yaml": "networks:\n  app:\n    ipam:\n      config:\n        - subnet: 172.20.0.0/16\n",
    "plan.json": json.dumps({"planned_values": {"root_module": {"resources": [
        {"mode": "managed", "type": "aws_vpc", "name": "x", "address": "aws_vpc.x", "values": {"cidr_block": "192.168.0.0/16"}},
        {"mode": "managed", "type": "aws_vpc", "name": "y", "address": "module.n.aws_vpc.y", "values": {"cidr_block": "192.168.0.0/20"}}]}}}),
}
WANT = [("1", "N3-NACL-RETURN", "app", "443"), ("1", "N3-NACL-RETURN", "app", "5432"), ("1", "N3-NACL-RETURN", "linux", "1024"),
        ("1", "N-PEER-ROUTE", "ab", "0 route"), ("2", "N7-OVERLAP", "vpc 10.0.0.0/16", "vpc 10.0.0.0/16"),
        ("2", "N7-OVERLAP", "vpc 10.0.0.0/16", "services 10.0.128.0/20"), ("2", "N7-OVERLAP", "", "pods 10.0.64.0/18"),
        ("2", "N7-OVERLAP", "vpc 192.168.0.0/16", "contains"), ("2", "N7-UNRESOLVED", "aws_vpc.c.cidr_block", "var.vpc_c_cidr"),
        ("3", "N8-V6-ROUTE", "", "no route sends ::/0"), ("3", "N8-V6-NACL", "app", ""), ("3", "N8-V6-SG-EGRESS", "web", ""),
        ("3", "N-PRIVDNS", "sts", "")]
QUIET = [("N3-NACL-RETURN", "ok"), ("N8-V6-NACL", "ok"), ("N8-V6-SG-EGRESS", "dual"), ("N-PRIVDNS", "ecr"), ("N-PRIVDNS", "s3"),
         ("N7-OVERLAP", "subnet 10.0.1.0/24"), ("N7-OVERLAP", "10.114.0.0/20"), ("N7-OVERLAP", "10.116.0.0/16"), ("N7-OVERLAP", "172.20.0.0/16")]


def selftest():
    import tempfile
    d = tempfile.mkdtemp()
    for name, body in FIX.items():
        os.makedirs(os.path.dirname(os.path.join(d, name)), exist_ok=True); open(os.path.join(d, name), "w").write(body)
    rows = [r.split("\t") for r in run([d])]
    bad = 0
    for sec, cls, subj, det in WANT:
        ok = any(r[0] == sec and r[1] == cls and subj in (r[3] + " " + r[4]) and det in (r[3] + " " + r[4]) for r in rows)
        bad += not ok; print("%s seed  %s %s %s" % ("ok  " if ok else "FAIL", cls, subj, det))
    for cls, subj in QUIET:
        ok = not any(r[1] == cls and (r[3].startswith(subj) or (cls == "N7-OVERLAP" and subj in r[3] + r[4])) for r in rows)
        bad += not ok; print("%s decoy %s %s" % ("ok  " if ok else "FAIL", cls, subj))
    ok = not any("ipBlock" in r[3] or "np.yaml" in r[2] for r in rows); bad += not ok
    print("%s ipBlock reference never compared" % ("ok  " if ok else "FAIL"))
    n = len(WANT) + len(QUIET) + 1
    print("self-test: %d/%d" % (n - bad, n))
    if bad:
        print("\n".join("\t".join(r) for r in rows))
    return 3 if bad else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] in ("-h", "--help"):
        print(__doc__); sys.exit(0 if a else 2)
    if a[0] == "--self-test":
        sys.exit(selftest())
    for r in run([x for x in a if not x.startswith("--")], [x.split("=", 1)[1] for x in a if x.startswith("--alloc=")]):
        print(r)
