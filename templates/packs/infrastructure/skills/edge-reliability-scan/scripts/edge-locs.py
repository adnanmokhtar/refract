#!/usr/bin/env python3
"""edge-locs.py — edge-reliability-scan: nginx config -> per-location EFFECTIVE directives -> class rows.

Why a parser and not a regex: nginx inherits most directives http -> server -> location, and an
array directive (proxy_set_header, add_header) is inherited only when the level defines none of
its own. A location-level regex cannot see a `resolver` set at http level (false positive), and a
file-level "has resolver?" check is satisfied by a sibling location (false negative, measured on
the research fixture). This walks the block tree and reads the value each location really gets.

Usage:  python3 -I edge-locs.py [--nginx-version=1.27.4] <file|dir> ...    (dirs: *.conf, *.nginx,
            *.conf.template, nginx*.conf*; k8s-render-scan's $SCAN/embedded/src/*.conf map back to
            their source: embedded/src/deploy__k8s__edge.yaml.conf:107 is deploy/k8s/edge.yaml:107)
        python3 -I edge-locs.py --self-test
Prints: one TSV row per inventory line or candidate:  §  CLASS  source:line  location  detail
        HOP rows are the § 1 hop-table input, not candidates. A `sec:` class is security-owned
        (route it; list it as `security-class (owner pack not installed)` without the pack).
Stderr: the ledger: files read, nginx files, Caddy/other files skipped, includes unread, locations.
Exit:   0 ran · 2 usage · 3 self-test failed. Stdlib only; reads files, writes nothing.
"""
import glob, os, re, sys

DEF = {"proxy_read_timeout": "60s", "proxy_send_timeout": "60s", "proxy_connect_timeout": "60s",
       "keepalive_timeout": "75s", "client_max_body_size": "1m", "proxy_buffering": "on",
       "proxy_next_upstream": "error timeout", "gzip_proxied": "off", "limit_req_status": "503"}
SLOW = re.compile(r"report|export|download|import|upload|pdf|csv|xlsx|backup|batch|sync|bulk", re.I)
STREAM = re.compile(r"(^|[/_.-])(events?|stream\w*|sse|subscribe\w*|live|notif\w*|long-?poll)([/_.$-]|$)", re.I)
WS = re.compile(r"(^|[/_.-])(ws|wss|websockets?|socket\.io|sockets?|realtime|cable|hubs?|subscriptions|graphql-ws)([/_.$-]|$)", re.I)
UPLOAD = re.compile(r"upload|import|files|media|attach|avatar|document|image", re.I)
HEALTH = re.compile(r"health|ready|live\b|metrics|status|ping|/assets|/static", re.I)
CONTENT = re.compile(r"\$(request|request_uri|args|query_string|arg_\w+|http_authorization|http_cookie|http_x_api_key|request_body)\b")
IP = re.compile(r"^(\d{1,3}(\.\d{1,3}){3}|\[[0-9a-f:]+\]|localhost|unix:.*)$", re.I)
COMBINED = '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'


class D:
    def __init__(self, name, args, line, parent, file):
        self.name, self.args, self.line, self.parent, self.file, self.kids = name, args, line, parent, file, None


def tokens(text):
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c.isspace():
            i += 1; continue
        if c == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c in ";{}":
            yield c, line, True; i += 1; continue
        start, buf = line, []
        while i < n:
            c = text[i]
            if c in "\"'":
                q, i = c, i + 1
                while i < n and text[i] != q:
                    if text[i] == "\\" and i + 1 < n:
                        buf.append(text[i + 1]); i += 2; continue
                    line += text[i] == "\n"; buf.append(text[i]); i += 1
                i += 1; continue
            if c.isspace() or c == ";" or c == "}":
                break
            if c == "{":
                if buf and buf[-1] == "$":
                    j = text.find("}", i); buf.append(text[i:j + 1]); i = j + 1; continue
                break
            buf.append(c); i += 1
        yield "".join(buf), start, False


def parse(text, file, root=None, depth=0, led=None):
    root = root or D("main", [], 0, None, file)
    root.kids = root.kids if root.kids is not None else []
    stack, cur, cl = [root], [], 0
    for tok, ln, sp in tokens(text):
        if not sp:
            cl = cl if cur else ln; cur.append(tok); continue
        if tok == ";" and cur:
            d = D(cur[0], cur[1:], cl, stack[-1], file); stack[-1].kids.append(d)
            if d.name == "include" and d.args and depth < 4:
                for p in sorted(glob.glob(d.args[0] if os.path.isabs(d.args[0]) else os.path.join(os.path.dirname(file), d.args[0]))):
                    led["include"] += 1; parse(open(p, errors="replace").read(), p, stack[-1], depth + 1, led)
                if not glob.glob(d.args[0] if os.path.isabs(d.args[0]) else os.path.join(os.path.dirname(file), d.args[0])):
                    led["unread"].append("%s:%d %s" % (file, cl, d.args[0]))
        elif tok == "{":
            d = D(cur[0] if cur else "", cur[1:], cl or ln, stack[-1], file); d.kids = []
            stack[-1].kids.append(d); stack.append(d)
        elif tok == "}" and len(stack) > 1:
            stack.pop()
        cur = []
    return root


def walk(n):
    for k in n.kids or []:
        yield k
        if k.kids is not None:
            yield from walk(k)


def eff(node, name):
    """The directives `name` this node really gets: its own, else the nearest ancestor's (nginx inheritance)."""
    n = node
    while n is not None:
        ds = [k for k in (n.kids or []) if k.name == name]
        if ds:
            return ds, n is node
        n = n.parent
    return [], False


def val(node, name):
    ds, own = eff(node, name)
    return (" ".join(ds[-1].args), "set" if ds else "default") if ds else (DEF.get(name, "unset"), "default")


def secs(v):
    m = re.match(r"^(\d+)(ms|s|m|h|d)?$", v or "")
    return None if not m else int(m.group(1)) * {"ms": 0.001, "s": 1, None: 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)]


def headers(node):
    return {d.args[0].lower(): " ".join(d.args[1:]) for d in eff(node, "proxy_set_header")[0] if d.args}


def anc(node, name):
    n = node.parent
    while n is not None and n.name != name:
        n = n.parent
    return n


def src(file, line):
    m = re.search(r"embedded/src/(.+)\.conf$", file)
    return "%s:%d" % (m.group(1).replace("__", "/") if m else file, line)


def scan(root, ver, out):
    ups = {d.args[0]: d for d in walk(root) if d.name == "upstream" and d.args}
    nums = re.findall(r"\d+", ver or "")[:3]
    gated = len(nums) >= 2 and tuple(int(x) for x in nums) >= (1, 29, 7)
    def row(s, c, d, loc, det):
        out.append("%s\t%s\t%s\t%s\t%s" % (s, c, src(d.file, d.line), loc, det))
    fmts = {d.args[0]: " ".join(d.args[1:]) for d in walk(root) if d.name == "log_format" and d.args}
    real_ip = any(d.name in ("set_real_ip_from", "real_ip_header") for d in walk(root))
    servers_done, logs_done = set(), set()
    for L in [d for d in walk(root) if d.name == "location"]:
        loc = " ".join(L.args)
        pp = [k for k in walk(L) if k.name in ("proxy_pass", "grpc_pass") and anc(k, "location") is L]
        srv = anc(L, "server")
        if HEALTH.search(loc) and eff(L, "access_log")[0][-1:] != [] and eff(L, "access_log")[0][-1].args[:1] != ["off"]:
            row("15", "E6-HEALTH-LOGGED", L, loc, "health/static route logged (access_log %s)" % " ".join(eff(L, "access_log")[0][-1].args))
        elif HEALTH.search(loc) and not eff(L, "access_log")[0] and pp:
            row("15", "E6-HEALTH-LOGGED", L, loc, "health/static route logged by the default access_log")
        if not pp:
            continue
        tgt = pp[0].args[0] if pp[0].args else ""
        m = re.match(r"^(\w+)://([^/:]+)(:\d+)?", tgt)
        host = m.group(2) if m else tgt
        rd, rds = val(L, "proxy_read_timeout"); body, _ = val(L, "client_max_body_size"); buf, _ = val(L, "proxy_buffering")
        h = headers(L); up = ups.get(host)
        row("1", "HOP", L, loc, "proxy_pass %s · read=%s(%s) send=%s connect=%s · body=%s · buffering=%s · pool=%s" % (
            tgt, rd, rds, val(L, "proxy_send_timeout")[0], val(L, "proxy_connect_timeout")[0], body, buf,
            "keepalive" if up and any(k.name == "keepalive" for k in up.kids) else "none"))
        r = secs(rd)
        if r is not None and r < 60:
            row("1", "E1-SHORT", L, loc, "proxy_read_timeout %s below the 60 s default: read the slowest legitimate request on this route" % rd)
        elif SLOW.search(loc) and rds == "default":
            row("1", "E1-SLOW-ROUTE", L, loc, "slow-route name on the 60 s default read timeout: read the route's p99")
        if up and any(k.name == "keepalive" for k in up.kids) and not gated and "upgrade" not in h and (
                val(L, "proxy_http_version")[0] != "1.1" or h.get("connection", None) not in ("", '""')):
            row("2", "E10-POOL-UNUSED", L, loc, "upstream %s keeps a pool but this location sends %s%s (nginx < 1.29.7 only; version %s)" % (
                host, "HTTP/" + (val(L, "proxy_http_version")[0] if val(L, "proxy_http_version")[1] == "set" else "1.0"),
                "" if "connection" in h else ", no Connection \"\"", ver or "unread"))
        if "non_idempotent" in val(L, "proxy_next_upstream")[0].split():
            row("3", "E3-NONIDEMPOTENT", L, loc, "proxy_next_upstream %s: a POST is re-sent to the next server" % val(L, "proxy_next_upstream")[0])
        pc = val(L, "proxy_cache")[0]
        if pc not in ("unset", "off"):
            guard = " ".join(val(L, n)[0] for n in ("proxy_no_cache", "proxy_cache_bypass", "proxy_cache_key"))
            if not re.search(r"\$(http_authorization|cookie_\w+|http_cookie)", guard):
                row("4", "sec:E4-CACHE-NO-IDENTITY", L, loc, "proxy_cache %s with no Authorization/cookie bypass or key" % pc)
            ig = val(L, "proxy_ignore_headers")[0]
            if re.search(r"Set-Cookie|Cache-Control|Vary|Expires", ig):
                row("4", "sec:E4-IGNORE-HEADERS", L, loc, "proxy_ignore_headers %s removes the origin's cache guard" % ig)
        if "$" in host and not re.fullmatch(r"\$(request_uri|uri|is_args|args)", host) and not eff(L, "resolver")[0]:
            row("5", "E7-NO-RESOLVER", L, loc, "variable target %s with no resolver at any level: 502 at runtime" % tgt)
        elif "$" not in host and not up and not IP.match(host) and "." in host:
            row("5", "E7-STATIC-NAME", L, loc, "%s resolved once at start%s" % (host, " (ClusterIP Service name? precedent 32)" if re.search(r"\.svc(\.|$)", host) else ""))
        if STREAM.search(loc) and buf != "off":
            row("6", "E8-BUFFERED", L, loc, "streaming route behind proxy_buffering %s (does the app send X-Accel-Buffering: no?)" % buf)
        if WS.search(loc):
            if "upgrade" not in h:
                row("6", "E9-NO-UPGRADE", L, loc, "WebSocket route forwards no Upgrade/Connection headers")
            if r is not None and r <= 60:
                row("6", "E9-IDLE-CUT", L, loc, "WebSocket idle cut at proxy_read_timeout %s unless the app heartbeats faster" % rd)
        tls = srv is not None and any(k.name == "ssl_certificate" or (k.name == "listen" and ("ssl" in k.args or "quic" in k.args or any(a == "443" or a.endswith(":443") for a in k.args))) for k in srv.kids)
        if tls and "x-forwarded-proto" not in h:
            row("7", "E11-NO-PROTO", L, loc, "TLS ends here and X-Forwarded-Proto is not set: an upstream https redirect loops")
        if h.get("x-forwarded-for", "").strip() == "$http_x_forwarded_for":
            row("7", "sec:E11-XFF-CLIENT", L, loc, "X-Forwarded-For taken from the client (client-IP trust: security iac-scan 7e)")
        if h.get("host", "").strip() == "$http_host":
            row("7", "E11-HOST-CLIENT", L, loc, "Host forwarded from the client header (redirects and absolute URLs follow it)")
        if body.strip() == "0":
            row("8", "sec:E12-BODY-UNBOUNDED", L, loc, "client_max_body_size 0 (security iac-scan § 6)")
        elif UPLOAD.search(loc) and val(L, "client_max_body_size")[1] == "default":
            row("8", "E12-BODY-DEFAULT", L, loc, "upload-like route on the 1m body default: read the app's own cap")
        for lr in eff(L, "limit_req")[0]:
            if not any(a.startswith("burst=") for a in lr.args):
                row("9", "E13-NO-BURST", L, loc, "limit_req %s with no burst: a browser's parallel requests are rejected" % " ".join(lr.args))
            if val(L, "limit_req_status")[1] == "default":
                row("9", "E13-503", L, loc, "limit_req rejects with 503 (clients and CDNs read an outage), not 429")
        if srv is not None and id(srv) not in servers_done:
            servers_done.add(id(srv)); ka = val(srv, "keepalive_timeout")
            row("2", "HOP-CLIENT-KA", srv, "server", "keepalive_timeout %s (%s): must exceed the idle timeout of the LB in front" % ka)
            if (secs(ka[0].split()[0]) or 75) < 60:
                row("2", "E2-CLIENT-KA", srv, "server", "keepalive_timeout %s below a 60 s LB idle (ALB default): random 502 at low traffic" % ka[0])
            if val(srv, "gzip")[0] == "on":
                if "application/json" not in val(srv, "gzip_types")[0]:
                    row("11", "E15-JSON", srv, "server", "gzip on without application/json in gzip_types")
                if val(srv, "gzip_proxied")[0] == "off":
                    row("11", "E15-PROXIED", srv, "server", "gzip_proxied off: requests through a CDN (Via) get uncompressed bodies")
        al = eff(L, "access_log")[0]
        for a in al or [None]:
            if a is not None and a.args[:1] == ["off"]:
                continue
            fmt = (a.args[1] if a is not None and len(a.args) > 1 else "combined")
            key = (fmt, id(a)); text = fmts.get(fmt, COMBINED if fmt == "combined" else "")
            if key in logs_done:
                continue
            logs_done.add(key); site = a or srv or L; where = "%s-level" % site.parent.name if a is not None else "default log"
            if "$request_id" not in text:
                row("15", "E21-NO-ID", site, where, "access_log format %s carries no $request_id" % fmt)
            if "$upstream_response_time" not in text:
                row("15", "E21-NO-UPSTREAM-TIME", site, where, "access_log format %s carries no $upstream_response_time" % fmt)
            if CONTENT.search(text):
                row("15", "sec:E5-LOG-CONTENT", site, where, "format %s logs %s (content: security data-exposure-scan § 6)" % (fmt, ",".join(sorted(set(CONTENT.findall(text))))))
        if "$request_id" in " ".join(fmts.values()) and "x-request-id" not in h:
            row("15", "E21-NOT-FORWARDED", L, loc, "the log mints $request_id but this location does not forward X-Request-Id")
    for name, u in ups.items():
        srvs = [k for k in u.kids if k.name == "server"]
        if len(srvs) > 1 and all("max_fails=0" in k.args for k in srvs):
            row("10", "E14-NO-EJECT", u, "upstream " + name, "every server max_fails=0: a dead server keeps its share")
        for k in srvs:
            hst = re.sub(r":\d+$", "", k.args[0]) if k.args else ""
            if not IP.match(hst) and "." in hst and "resolve" not in k.args:
                row("5", "E7-STATIC-NAME", k, "upstream " + name, "%s resolved once at start, no resolve param%s" % (hst, " (ClusterIP? precedent 32)" if re.search(r"\.svc(\.|$)", hst) else ""))
    for z in [d for d in walk(root) if d.name == "limit_req_zone"]:
        if z.args and z.args[0] == "$binary_remote_addr" and not real_ip:
            row("9", "E13-PEER-KEY", z, "http", "zone keyed on the peer address with no real_ip config: behind an LB/CDN every user shares one bucket")
    if any(WS.search(" ".join(d.args)) or STREAM.search(" ".join(d.args)) for d in walk(root) if d.name == "location") and not eff(root, "worker_shutdown_timeout")[0]:
        out.append("12\tE16-NO-SHUTDOWN-TIMEOUT\t%s\tmain\tlong-lived streams with no worker_shutdown_timeout: old workers outlive every reload" % src(root.file, 1))


def nginxish(text):
    """nginx, not a Caddyfile: most non-comment lines end in ; { or } (a Caddyfile's never end in ;)."""
    ls = [l.split("#", 1)[0].strip() for l in text.splitlines()]
    ls = [l for l in ls if l]
    semi = sum(l.endswith(";") for l in ls)
    return any(";" in l for l in ls) and (semi + sum(l.endswith(("{", "}")) for l in ls)) >= 0.6 * len(ls)


def run(paths, ver):
    led = {"files": 0, "nginx": 0, "skipped": [], "include": 0, "unread": [], "locations": 0}
    out, files = [], []
    for p in paths:
        if os.path.isdir(p):
            for dp, dn, fn in os.walk(p):
                dn[:] = [d for d in dn if d not in ("node_modules", ".git", "vendor", "test", "tests", "testdata", "__tests__", "examples", "example")]
                files += [os.path.join(dp, f) for f in fn if re.search(r"(\.conf|\.nginx|\.conf\.template)$|^nginx.*\.conf", f)]
        elif os.path.isfile(p):
            files.append(p)
        else:
            sys.stderr.write("edge-locs: path not found, NOT-READ: %s\n" % p)
    for f in sorted(set(files)):
        led["files"] += 1
        text = open(f, errors="replace").read()
        if not nginxish(text):
            led["skipped"].append(f); continue
        led["nginx"] += 1; root = parse(text, f, led=led)
        led["locations"] += sum(1 for d in walk(root) if d.name == "location"); scan(root, ver, out)
    sys.stderr.write("edge-locs ledger: %d files read · %d nginx · %d skipped (not nginx: Caddy/other) · %d includes read · %d unread · %d locations\n" % (
        led["files"], led["nginx"], len(led["skipped"]), led["include"], len(led["unread"]), led["locations"]))
    for u in led["unread"]:
        sys.stderr.write("  include NOT-READ: %s\n" % u)
    return out


FIX = r"""
worker_processes 1; events {}
http {
  log_format leaky '$remote_addr "$request_uri" auth="$http_authorization" $status';
  access_log /tmp/a.log leaky;
  keepalive_timeout 30s;
  resolver 10.0.0.2 valid=30s;
  upstream app { server 127.0.0.1:8080; keepalive 16; }
  upstream pool { server 10.0.0.5 max_fails=0; server 10.0.0.6 max_fails=0; }
  limit_req_zone $binary_remote_addr zone=z:10m rate=5r/s;
  server { listen 443 ssl; ssl_certificate /c.pem;
    proxy_set_header X-Forwarded-Proto https;
    location /reports/ { proxy_read_timeout 30s; proxy_pass http://app; }
    location /payments/ { proxy_next_upstream error timeout non_idempotent; proxy_pass http://pool; }
    location /catalog/ { proxy_next_upstream error timeout; proxy_pass http://pool; }
    location /api/me { proxy_cache c; proxy_ignore_headers Set-Cookie; proxy_pass http://pool; }
    location /api/pub { proxy_cache c; proxy_no_cache $http_authorization; proxy_cache_bypass $http_authorization; proxy_pass http://pool; }
    location /svc/ { set $b "orders.internal"; proxy_pass http://$b:8080; }
    location /events { proxy_pass http://pool; }
    location /stream { proxy_buffering off; proxy_pass http://pool; }
    location /ws { proxy_read_timeout 1h; proxy_pass http://pool; }
    location /ws2 { proxy_read_timeout 1h; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_pass http://pool; }
    location /login { limit_req zone=z; proxy_set_header X-Forwarded-For $http_x_forwarded_for; proxy_pass http://pool; }
    location /upload { proxy_pass http://pool; }
    location /ext { proxy_pass https://api.vendor.example.com; }
    location /k8s { proxy_pass http://api.shop.svc.cluster.local; }
  }
}
"""
WANT = [("1", "E1-SHORT", "/reports/"), ("2", "E2-CLIENT-KA", "server"), ("2", "E10-POOL-UNUSED", "/reports/"),
        ("3", "E3-NONIDEMPOTENT", "/payments/"), ("4", "sec:E4-IGNORE-HEADERS", "/api/me"), ("4", "sec:E4-CACHE-NO-IDENTITY", "/api/me"),
        ("6", "E8-BUFFERED", "/events"), ("6", "E9-NO-UPGRADE", "/ws"), ("7", "sec:E11-XFF-CLIENT", "/login"),
        ("8", "E12-BODY-DEFAULT", "/upload"), ("9", "E13-NO-BURST", "/login"), ("9", "E13-PEER-KEY", "http"),
        ("10", "E14-NO-EJECT", "upstream pool"), ("15", "sec:E5-LOG-CONTENT", "http-level"), ("15", "E21-NO-ID", "http-level"),
        ("5", "E7-STATIC-NAME", "/ext"), ("12", "E16-NO-SHUTDOWN-TIMEOUT", "main")]
QUIET = [("E3-NONIDEMPOTENT", "/catalog/"), ("sec:E4-CACHE-NO-IDENTITY", "/api/pub"), ("E7-NO-RESOLVER", "/svc/"),
         ("E8-BUFFERED", "/stream"), ("E9-NO-UPGRADE", "/ws2"), ("E11-NO-PROTO", "/reports/"), ("E9-IDLE-CUT", "/ws")]


def selftest():
    import tempfile
    d = tempfile.mkdtemp(); f = os.path.join(d, "nginx.conf"); open(f, "w").write(FIX)
    rows = [r.split("\t") for r in run([f], "1.27.4")]
    have = {(r[0], r[1], r[3]) for r in rows}; bad = 0
    for w in WANT:
        ok = w in have; bad += not ok; print("%s seed  %s %s" % ("ok  " if ok else "FAIL", w[1], w[2]))
    for c, l in QUIET:
        ok = not any(r[1] == c and r[3] == l for r in rows); bad += not ok; print("%s decoy %s %s" % ("ok  " if ok else "FAIL", c, l))
    k8s = [r for r in rows if r[3] == "/k8s"]
    ok = any("precedent 32" in r[4] for r in k8s); bad += not ok; print("%s ClusterIP name carries precedent 32" % ("ok  " if ok else "FAIL"))
    gated = [r for r in run([f], "1.29.7") if "E10-POOL-UNUSED" in r]
    ok = not gated; bad += not ok; print("%s E10 suppressed on nginx 1.29.7" % ("ok  " if ok else "FAIL"))
    print("self-test: %d/%d" % (len(WANT) + len(QUIET) + 2 - bad, len(WANT) + len(QUIET) + 2))
    return 3 if bad else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] in ("-h", "--help"):
        print(__doc__); sys.exit(0 if a else 2)
    if a[0] == "--self-test":
        sys.exit(selftest())
    v = next((x.split("=", 1)[1] for x in a if x.startswith("--nginx-version=")), None)
    for r in run([x for x in a if not x.startswith("--")], v):
        print(r)
