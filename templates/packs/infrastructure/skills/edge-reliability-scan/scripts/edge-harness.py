#!/usr/bin/env python3
"""edge-harness.py — edge-reliability-scan's H-tier oracle (proof-oracles.md § Edge harness, V282–V287).

An upstream that counts executions, plus two client probes. It runs on 127.0.0.1 behind the
project's OWN proxy config or image (a stock caddy cannot load an xcaddy build: precedents § 49),
never in front of a real service and never against a host the user did not name.

  serve  --port=P [--mode=M] [--idle=S] [--hits=FILE]   the upstream (foreground; stop it with kill)
         M = ok            200 at once
             slow:S        read the body, sleep S seconds, then 200 (the request WAS executed: timeout-after-send)
             bad           502 at once (an upstream answering 5xx)
             reset         read the body, then close with no response (reset after send)
             sse:N:GAP     any GET streams N `data:` events GAP seconds apart (text/event-stream)
         --idle=S          close an idle keep-alive connection after S s (an app keepAliveTimeout)
         GET /__hits       the per-"METHOD path" execution count as JSON (never counted itself)
  hits   --port=P                                  print that JSON
  idle   --url=U --gaps=59,61                      one keep-alive connection: request, idle GAP s, request again;
                                                   prints the second status or the error a proxy would turn into 502
  sse    --url=U [--n=N]                           arrival time of every `data:` line and the spacing between them
  --self-test                                      starts its own upstreams on ephemeral ports, stops them, exits

Stdlib only (python3 -I). Exit: 0 ok · 2 usage · 3 self-test failed.
"""
import http.client, json, socket, sys, threading, time, urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler


def make(mode="ok", idle=None, hits_file=None):
    hits, lock = {}, threading.Lock()

    class H(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        timeout = idle

        def log_message(self, *a):
            pass

        def _send(self, code, body, ctype="text/plain"):
            b = body.encode(); self.send_response(code); self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

        def _run(self):
            if self.path == "/__hits":
                with lock:
                    return self._send(200, json.dumps(hits), "application/json")
            n = int(self.headers.get("Content-Length") or 0)
            if n:
                self.rfile.read(n)
            k = "%s %s" % (self.command, self.path.split("?")[0])
            with lock:
                hits[k] = hits.get(k, 0) + 1
                if hits_file:
                    open(hits_file, "w").write(json.dumps(hits))
            m = mode.split(":")
            if m[0] == "slow":
                time.sleep(float(m[1])); return self._send(200, "executed slowly\n")
            if m[0] == "bad":
                return self._send(502, "bad gateway from upstream\n")
            if m[0] == "reset":
                self.close_connection = True; self.connection.shutdown(socket.SHUT_RDWR); return
            if m[0] == "sse" and self.command == "GET":
                self.send_response(200); self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache"); self.end_headers()
                for i in range(int(m[1])):
                    self.wfile.write(("data: %d %.2f\n\n" % (i, time.time())).encode()); self.wfile.flush(); time.sleep(float(m[2]))
                self.close_connection = True; return
            return self._send(200, "executed\n")

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = _run

    return H, hits


class Quiet(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):  # a peer that hung up (reset mode, a proxy giving up) is expected
        pass


def serve(port, mode="ok", idle=None, hits_file=None, background=False):
    H, hits = make(mode, idle, hits_file)
    srv = Quiet(("127.0.0.1", port), H)
    if background:
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        return srv, hits
    srv.serve_forever()


def idle_probe(url, gaps):
    u = urllib.parse.urlsplit(url); out = []
    for g in gaps:
        c = http.client.HTTPConnection(u.hostname, u.port or 80, timeout=max(g, 1) + 30)
        path = u.path or "/"
        try:
            c.request("GET", path); r = c.getresponse(); r.read(); first = r.status
            time.sleep(g); c.request("GET", path); r = c.getresponse(); r.read()
            out.append((g, first, str(r.status)))
        except Exception as e:  # what an LB that reused this socket would turn into a 502
            out.append((g, first if "first" in dir() else "-", type(e).__name__))
        finally:
            c.close()
    return out


def sse_spacing(url, limit=50, wait=60):
    u = urllib.parse.urlsplit(url)
    c = http.client.HTTPConnection(u.hostname, u.port or 80, timeout=wait); t0, arr = time.time(), []
    c.request("GET", u.path or "/", headers={"Accept": "text/event-stream"}); r = c.getresponse()
    while len(arr) < limit and time.time() - t0 < wait:
        line = r.readline()  # through the response object: a chunked or keep-alive proxy ends the stream here
        if not line:
            break
        if line.startswith(b"data:"):
            arr.append(round(time.time() - t0, 2))
    c.close()
    return arr


def hits_of(port):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=5); c.request("GET", "/__hits")
    return json.loads(c.getresponse().read())


def free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p


def selftest():
    bad, started = 0, []
    def ok(cond, msg):
        nonlocal bad; bad += not cond; print("%s %s" % ("ok  " if cond else "FAIL", msg))
    p = free_port(); srv, _ = serve(p, "ok", background=True); started.append(srv)
    for _ in range(4):
        c = http.client.HTTPConnection("127.0.0.1", p, timeout=5); c.request("POST", "/payments/x", body=b"{}"); c.getresponse().read(); c.close()
    ok(hits_of(p).get("POST /payments/x") == 4, "hit counter: 4 POSTs -> 4 executions (GET /__hits not counted)")
    p2 = free_port(); srv, _ = serve(p2, "slow:1.5", background=True); started.append(srv)
    c = http.client.HTTPConnection("127.0.0.1", p2, timeout=0.5)
    try:
        c.request("POST", "/r", body=b"x"); c.getresponse(); ok(False, "slow mode answers after the client gave up")
    except socket.timeout:
        time.sleep(1.2); ok(hits_of(p2).get("POST /r") == 1, "slow mode: the client timed out, the upstream still executed once")
    p3 = free_port(); srv, _ = serve(p3, "sse:3:0.4", background=True); started.append(srv)
    a = sse_spacing("http://127.0.0.1:%d/events" % p3)
    sp = [round(y - x, 2) for x, y in zip(a, a[1:])]
    ok(len(a) == 3 and all(0.3 <= s <= 0.7 for s in sp), "sse: 3 events at upstream spacing %s (unbuffered direct path)" % sp)
    p4 = free_port(); srv, _ = serve(p4, "ok", idle=0.5, background=True); started.append(srv)
    r = idle_probe("http://127.0.0.1:%d/" % p4, [0.2, 1.0])
    ok(r[0][2] == "200" and r[1][2] != "200", "idle probe: gap 0.2 s reuses the socket (%s); gap 1.0 s past a 0.5 s idle fails (%s)" % (r[0][2], r[1][2]))
    p5 = free_port(); srv, _ = serve(p5, "reset", background=True); started.append(srv)
    c = http.client.HTTPConnection("127.0.0.1", p5, timeout=5)
    try:
        c.request("POST", "/p", body=b"x"); c.getresponse(); ok(False, "reset mode returns no response")
    except Exception as e:
        ok(hits_of(p5).get("POST /p") == 1, "reset mode: executed once, client sees %s" % type(e).__name__)
    for s in started:
        s.shutdown(); s.server_close()
    print("self-test: %d/5 · started and stopped %d upstreams on 127.0.0.1" % (5 - bad, len(started)))
    return 3 if bad else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    kv = dict(x[2:].split("=", 1) for x in a if x.startswith("--") and "=" in x)
    if not a or a[0] in ("-h", "--help"):
        print(__doc__); sys.exit(0 if a else 2)
    if a[0] == "--self-test":
        sys.exit(selftest())
    if a[0] == "serve" and "port" in kv:
        serve(int(kv["port"]), kv.get("mode", "ok"), float(kv["idle"]) if "idle" in kv else None, kv.get("hits"))
    elif a[0] == "hits" and "port" in kv:
        print(json.dumps(hits_of(int(kv["port"]))))
    elif a[0] == "idle" and "url" in kv:
        for g, f, s in idle_probe(kv["url"], [float(x) for x in kv.get("gaps", "59,61").split(",")]):
            print("gap %ss\tfirst %s\tsecond %s" % (g, f, s))
    elif a[0] == "sse" and "url" in kv:
        t = sse_spacing(kv["url"], int(kv.get("n", 50))); print("arrivals %s · spacing %s" % (t, [round(y - x, 2) for x, y in zip(t, t[1:])]))
    else:
        print(__doc__); sys.exit(2)
