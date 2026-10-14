#!/usr/bin/env python3
"""ds-inventory.py — messaging-scan's F2: every consumer and producer, and the options each one resolves to.

A job's real options rarely sit at the call: they are layered from the library default, the queue's
`defaultJobOptions`, a producer base class that wraps `queue.add`, a subclass override, the call's own
literal, and constants imported from other files. A detector that reads one file judges the wrong
value (WASABI's single-file blindness). This script follows those layers across files and prints, per
row, every policy option with the layer it came from. What it cannot follow it prints as
`UNRESOLVED (<why>)` — a default is never guessed, and a value read from the environment prints as
`env:NAME|<fallback>`.

Lanes: BullMQ / @nestjs/bullmq (`@Processor`, `extends WorkerHost` and base classes, `new Worker`,
`registerQueue` / `new Queue` defaults, `queue.add`, producer wrapper classes), kafkajs
(`consumer.run`, `producer.send`, `kafka.consumer/producer` config), amqplib (`consume`, `prefetch`,
`publish`), sqs-consumer (`Consumer.create`), Celery (`@shared_task` / `@app.task`, `app.conf`), and
Spring (`@KafkaListener`, `@RabbitListener`) as a locate-only lane. Stdlib only. Read-only.

Usage:  ds-inventory.py <repo-root> [--format=tsv|json] [--lane=bullmq,kafkajs,amqplib,sqs,celery,spring]
        ds-inventory.py --self-test
Output: one TSV row per consumer, producer and producer wrapper:
        kind  lane  name  file:line  status  resolved (key=value[source]; …)
        then `# resolved r/n — consumers a/b, producers c/d` and one `# UNRESOLVED` line per shape.
Exit:   0 always after a run (the rows are candidates for the read step, never findings) · 2 usage
"""
import json, os, re, sys, tempfile

SKIP_DIRS = {"node_modules", "dist", "build", "out", "coverage", ".next", ".nuxt", ".output", "generated",
             "__generated__", "test", "tests", "__tests__", "spec", "specs", "e2e", "fixtures", "__fixtures__",
             "mocks", "__mocks__", "testdata", "migrations", "docs", "ai", ".claude", ".git", "venv", ".venv",
             "__pycache__", "vendor", "target"}
SKIP_FILE = re.compile(r"\.(?:spec|test|e2e-spec|fuzz|stories)\.[cm]?[jt]sx?$|\.d\.ts$|\.min\.js$|(?:^|/)(?:test_[^/]*|conftest)\.py$")
TS_EXT = (".ts", ".mts", ".cts", ".js", ".mjs", ".cjs")

# Library defaults — the rows of templates/snippets/broker-semantics.md the verdict must cite.
# Applied only when the package's major is read from a manifest; otherwise the key is UNRESOLVED.
DEFAULTS = {
    "bullmq.worker": {"concurrency": 1, "lockDuration": 30000, "stalledInterval": 30000, "maxStalledCount": 1},
    "bullmq.job": {"attempts": 1, "backoff": "none", "removeOnComplete": "keep", "removeOnFail": "keep"},
    "kafkajs.consumer": {"autoCommit": True, "eachBatchAutoResolve": True, "partitionsConsumedConcurrently": 1,
                         "sessionTimeout": 30000, "rebalanceTimeout": 60000},
    "kafkajs.producer": {"idempotent": False, "acks": -1, "maxInFlightRequests": "unbounded"},
    "amqplib.consume": {"noAck": False, "prefetch": "unbounded"},
    "sqs.consumer": {"batchSize": 1, "waitTimeSeconds": 20, "alwaysAcknowledge": False, "heartbeatInterval": "none"},
    "celery.task": {"acks_late": False, "max_retries": 3, "autoretry_for": "none", "reject_on_worker_lost": False},
}
PKG_OF = {"bullmq": ("bullmq",), "kafkajs": ("kafkajs", "@confluentinc/kafka-javascript"), "amqplib": ("amqplib",),
          "sqs": ("sqs-consumer",), "celery": ("celery",)}
POLICY = {"bullmq.worker": ("concurrency", "lockDuration", "stalledInterval", "maxStalledCount", "skipLockRenewal",
                            "skipStalledCheck", "limiter", "settings.backoffStrategy"),
          "bullmq.job": ("attempts", "backoff", "removeOnComplete", "removeOnFail")}


class Fn(str): pass                       # a function value: code, not data
class Env:                                 # a value read from the environment, with its code fallback
    def __init__(s, name, fb): s.name, s.fb = name, fb
    def __repr__(s): return "env:%s|%s" % (s.name, show(s.fb))
class Run:                                 # a value only known at run time (a parameter, a call result)
    def __init__(s, expr): s.expr = expr
    def __repr__(s): return "runtime(%s)" % short(s.expr)
class Unres:
    def __init__(s, why): s.why = why
    def __repr__(s): return "UNRESOLVED (%s)" % s.why


def short(t, n=48):
    t = re.sub(r"\s+", " ", t).strip()
    return t if len(t) <= n else t[: n - 1] + "…"


def show(v):
    if isinstance(v, dict): return "{" + ", ".join("%s: %s" % (k, show(x)) for k, (x, _) in v.items()) + "}"
    if isinstance(v, Fn): return "fn(%s)" % short(v, 40)
    if isinstance(v, str): return "'%s'" % v
    if v is True: return "true"
    if v is False: return "false"
    if v is None: return "null"
    return repr(v)


# ------------------------------------------------------------------ lexical helpers -----------------
def mask(text, hash_comments=False):
    """Blank out comments (keep strings and newlines) so brackets and regexes see code only."""
    out, i, n = list(text), 0, len(text)
    while i < n:
        c = text[i]
        if c in "'\"`":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            i = j + 1
        elif not hash_comments and text.startswith("//", i):
            j = text.find("\n", i); j = n if j < 0 else j
            out[i:j] = " " * (j - i); i = j
        elif not hash_comments and text.startswith("/*", i):
            j = text.find("*/", i + 2); j = n if j < 0 else j + 2
            out[i:j] = [ch if ch == "\n" else " " for ch in text[i:j]]; i = j
        elif hash_comments and c == "#":
            j = text.find("\n", i); j = n if j < 0 else j
            out[i:j] = " " * (j - i); i = j
        else:
            i += 1
    return "".join(out)


def close_of(s, i):
    """Index of the bracket that closes s[i] (one of ( [ {), skipping strings; -1 if unbalanced."""
    pair = {"(": ")", "[": "]", "{": "}"}
    stack, j, n = [pair[s[i]]], i + 1, len(s)
    while j < n:
        c = s[j]
        if c in "'\"`":
            k = j + 1
            while k < n and s[k] != c:
                k += 2 if s[k] == "\\" else 1
            j = k + 1; continue
        if c in pair: stack.append(pair[c])
        elif c in ")]}":
            if not stack or stack.pop() != c: return -1
            if not stack: return j
        j += 1
    return -1


def split_top(s, sep=","):
    parts, depth, cur, i = [], 0, [], 0
    while i < len(s):
        c = s[i]
        if c in "'\"`":
            k = i + 1
            while k < len(s) and s[k] != c:
                k += 2 if s[k] == "\\" else 1
            cur.append(s[i:k + 1]); i = k + 1; continue
        if c in "([{": depth += 1
        elif c in ")]}": depth -= 1
        if c == sep and depth == 0:
            parts.append("".join(cur)); cur = []
        else:
            cur.append(c)
        i += 1
    if "".join(cur).strip(): parts.append("".join(cur))
    return [p.strip() for p in parts if p.strip()]


def line_of(text, idx): return text.count("\n", 0, idx) + 1


# ------------------------------------------------------------------ TS module index -----------------
RELEVANT = re.compile(r"WorkerHost|@Processor|@InjectQueue|\bQueue\b|\bWorker\b|eachMessage|eachBatch|Consumer\.create|\.consume\(|[pP]roducer|amqp")


class Mod:
    """One TS/JS module. Indexed lazily: most files are only ever asked for one constant."""
    def __init__(self, path, rel, text):
        self.path, self.rel, self.text = path, rel, text
        self._m = self._idx = self._classes = None
        self.relevant = bool(RELEVANT.search(text))

    @property
    def m(self):
        if self._m is None: self._m = mask(self.text)
        return self._m

    def __getattr__(self, name):
        if name in ("consts", "enums", "imports"):
            if self._idx is None:
                self.consts, self.enums, self.imports = {}, {}, {}
                self._idx = True; self.index()
            return self.__dict__[name]
        if name == "classes":
            if self._classes is None:
                self._classes = [] if not self.relevant else self.find_classes()
            return self._classes
        raise AttributeError(name)

    def find_classes(self):
        m, out = self.m, []
        for mt in re.finditer(r"\bclass\s+(\w+)(?:\s*<[^>{]*>)?(?:\s+extends\s+([\w.]+)(?:\s*<[^>{]*>)?)?(?:\s+implements\s+[^{]+)?\s*\{", m):
            b = close_of(m, mt.end() - 1)
            if b > 0: out.append(Cls(self, mt.group(1), mt.group(2), mt.start(), mt.end() - 1, b))
        return out

    def index(self):
        m = self.m
        for mt in re.finditer(r"^(?:export\s+)?(?:const|let)\s+(\w+)\s*(?::[^=\n]+)?=\s*", m, re.M):
            start, depth, j = mt.end(), 0, mt.end()
            while j < len(m):
                c = m[j]
                if c in "'\"`":
                    k = j + 1
                    while k < len(m) and m[k] != c:
                        k += 2 if m[k] == "\\" else 1
                    j = k + 1; continue
                if c in "([{": depth += 1
                elif c in ")]}": depth -= 1
                elif depth == 0 and (c == ";" or (c == "\n" and not re.search(r"[=,(?:+\-*/&|{[]\s*$", m[start:j])
                                                    and not re.match(r"\s*[.?:+\-*/&|]", m[j + 1:j + 40]))):
                    break
                j += 1
            self.consts[mt.group(1)] = (m[start:j].strip(), line_of(m, mt.start()))
        for mt in re.finditer(r"^(?:export\s+)?(?:const\s+)?enum\s+(\w+)\s*\{", m, re.M):
            b = close_of(m, mt.end() - 1); body, auto, vals = m[mt.end():b], 0, {}
            for ent in split_top(body):
                k, _, v = ent.partition("=")
                v = v.strip()
                if not v: vals[k.strip()] = auto; auto += 1
                else:
                    lit = literal(v)
                    vals[k.strip()] = lit if lit is not None else Run(v)
                    if isinstance(lit, int): auto = lit + 1
            self.enums[mt.group(1)] = (vals, line_of(m, mt.start()))
        for mt in re.finditer(r"\bimport\s+(?:type\s+)?([^;]*?)\s+from\s+['\"]([^'\"]+)['\"]", m):
            names, src = mt.group(1), mt.group(2)
            br = re.search(r"\{([^}]*)\}", names)
            if br:
                for part in br.group(1).split(","):
                    part = re.sub(r"^\s*type\s+", "", part).strip()
                    if not part: continue
                    a, _, b = part.partition(" as ")
                    self.imports[(b or a).strip()] = (src, a.strip())
            dflt = re.match(r"\s*(\w+)\s*(?:,|$)", names)
            if dflt: self.imports[dflt.group(1)] = (src, "default")


class Cls:
    def __init__(self, mod, name, base, start, ob, cb):
        self.mod, self.name, self.base, self.start, self.ob, self.cb = mod, name, base, start, ob, cb
        self.line = line_of(mod.m, start)
        self.decos = decorators_before(mod.m, start)
        self.methods = {}
        body = mod.m
        ones = depth_one(body, ob, cb)
        for mt in re.finditer(r"(?:^|\n)[ \t]*((?:@\w+\([^\n]*\)\s*)*)(?:(?:public|protected|private|override|static|readonly|abstract|async)\s+)*(\w+)\s*(?:<[^>()]*>)?\(", body[ob + 1:cb]):
            p = ob + 1 + mt.end() - 1
            if p not in ones or mt.group(2) in ("if", "for", "while", "switch", "catch", "return", "super", "function"):
                continue
            pe = close_of(body, p)
            if pe < 0: continue
            k = re.match(r"\s*(?::\s*[^{;=]+?)?\s*(\{|;)", body[pe + 1:pe + 200])
            if not k: continue
            bstart = pe + 1 + k.start(1)
            bend = close_of(body, bstart) if k.group(1) == "{" else bstart
            params = []
            for prm in split_top(body[p + 1:pe]):
                prm = re.sub(r"@\w+\([^)]*\)\s*", "", prm)
                prm = re.sub(r"^(?:(?:public|protected|private|readonly|override)\s+)+", "", prm)
                nm = re.match(r"(?:\.{3})?(\w+)", prm.strip())
                dv = prm.split("=", 1)[1].strip() if "=" in prm and "=>" not in prm.split("=", 1)[0] else None
                params.append((nm.group(1) if nm else prm.strip(), dv, prm))
            self.methods[mt.group(2)] = {"params": params, "body": (bstart, bend), "line": line_of(body, p),
                                         "decos": mt.group(1), "sig": (p, pe)}

    def body(self, meth): s, e = self.methods[meth]["body"]; return self.mod.m[s:e + 1]


def depth_one(s, ob, cb):
    """Positions inside the class body that sit at brace depth 1 (class members), in one pass."""
    out, d, i = set(), 0, ob
    while i < cb:
        c = s[i]
        if c in "'\"`":
            k = i + 1
            while k < cb and s[k] != c:
                k += 2 if s[k] == "\\" else 1
            i = k + 1; continue
        if c == "{": d += 1
        elif c == "}": d -= 1
        elif c == "(" and d == 1: out.add(i)
        i += 1
    return out


def decorators_before(m, start):
    out, j = [], start
    pre = m[max(0, start - 4000):start]
    off = max(0, start - 4000)
    for mt in re.finditer(r"@(\w+)\(", pre):
        a = off + mt.end() - 1
        b = close_of(m, a)
        if b < 0 or b >= start: continue
        gap = m[b + 1:start]
        gap = re.sub(r"@\w+\((?:[^()]|\([^()]*\))*\)", "", gap)
        if re.fullmatch(r"[\s]*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?", gap):
            out.append((mt.group(1), m[a + 1:b], line_of(m, off + mt.start())))
    return out


def literal(v):
    v = v.strip()
    v = re.sub(r"\s+as\s+const$|\s+satisfies\s+[\w.<>]+$|\s+as\s+[\w.<>\[\]]+$", "", v).strip()
    if re.fullmatch(r"-?\d[\d_]*(?:\.\d+)?", v): return float(v.replace("_", "")) if "." in v else int(v.replace("_", ""))
    if re.fullmatch(r"'[^'\\]*'|\"[^\"\\]*\"|`[^`$\\]*`", v): return v[1:-1]
    return {"true": True, "false": False, "null": None, "undefined": None, "True": True, "False": False, "None": None}.get(v)


# ------------------------------------------------------------------ the resolver --------------------
class Repo:
    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.mods, self.py, self.java, self.pkgs = {}, {}, {}, {}
        for dp, dn, fn in os.walk(self.root):
            dn[:] = [d for d in dn if d not in SKIP_DIRS and not d.startswith(".")]
            for f in fn:
                p = os.path.join(dp, f); rel = os.path.relpath(p, self.root)
                if f == "package.json": self.pkgs[os.path.dirname(p)] = self.read_pkg(p)
                if SKIP_FILE.search(rel): continue
                if f.endswith(TS_EXT):
                    try: self.mods[p] = Mod(p, rel, open(p, encoding="utf-8", errors="replace").read())
                    except (OSError, RecursionError): pass
                elif f.endswith(".py"): self.py[p] = open(p, encoding="utf-8", errors="replace").read()
                elif f.endswith((".java", ".kt")): self.java[p] = open(p, encoding="utf-8", errors="replace").read()
        self.by_class = {}
        for mod in self.relevant():
            for c in mod.classes: self.by_class.setdefault(c.name, []).append(c)

    def relevant(self):
        return [mod for mod in self.mods.values() if mod.relevant]

    @staticmethod
    def read_pkg(p):
        try: d = json.load(open(p, encoding="utf-8"))
        except (OSError, ValueError): return {}
        out = {}
        for k in ("dependencies", "devDependencies", "peerDependencies"):
            out.update(d.get(k) or {})
        return out

    def version(self, path, lane):
        d = os.path.dirname(path)
        while d.startswith(self.root):
            deps = self.pkgs.get(d)
            for pkg in PKG_OF.get(lane, ()):
                if deps and pkg in deps:
                    mj = re.search(r"\d+", deps[pkg])
                    return "%s %s (%s)" % (pkg, deps[pkg], os.path.relpath(os.path.join(d, "package.json"), self.root)), mj and int(mj.group())
            if d == self.root: break
            d = os.path.dirname(d)
        if lane == "celery":
            d = os.path.dirname(path)
            while d.startswith(self.root):
                for f in ("requirements.txt", "requirements/base.txt", "pyproject.toml", "Pipfile"):
                    fp = os.path.join(d, f)
                    if os.path.exists(fp):
                        mt = re.search(r"(?im)^\s*['\"]?celery\b[^\n\d]*(\d+)[\d.]*", open(fp, encoding="utf-8", errors="replace").read())
                        if mt: return "%s (%s)" % (mt.group(0).strip(), os.path.relpath(fp, self.root)), int(mt.group(1))
                if d == self.root: break
                d = os.path.dirname(d)
        return None, None

    def module_for(self, mod, spec):
        if not spec.startswith("."): return None
        base = os.path.normpath(os.path.join(os.path.dirname(mod.path), spec))
        for cand in [base] + [base + e for e in TS_EXT] + [os.path.join(base, "index" + e) for e in TS_EXT]:
            if cand in self.mods: return self.mods[cand]
        if base.endswith(".js") and base[:-3] + ".ts" in self.mods: return self.mods[base[:-3] + ".ts"]
        return None

    def ident(self, mod, name, seen):
        """Resolve a module-scope identifier: local const or enum, then the import's target."""
        key = (mod.path, name)
        if key in seen: return Unres("cycle at %s" % name), ""
        seen = seen | {key}
        if name in mod.consts:
            txt, ln = mod.consts[name]
            v, src = self.expr(mod, txt, seen, None)
            return v, src or "%s:%d" % (mod.rel, ln)
        if name in mod.enums:
            return {k: (val, "%s:%d" % (mod.rel, mod.enums[name][1])) for k, val in mod.enums[name][0].items()}, "%s:%d" % (mod.rel, mod.enums[name][1])
        if name in mod.imports:
            spec, orig = mod.imports[name]
            tgt = self.module_for(mod, spec)
            if tgt is None: return Unres("%s from package %s" % (name, spec) if not spec.startswith(".") else "%s: %s not found" % (name, spec)), ""
            return self.ident(tgt, orig, seen)
        return None, ""

    def expr(self, mod, t, seen=frozenset(), local=None):
        """Evaluate an option expression. Returns (value, source)."""
        t = t.strip().rstrip(",")
        t = re.sub(r"\s+as\s+const\b|\s+satisfies\s+[\w.<>]+|\s+as\s+[\w.<>\[\]|' ]+$", "", t).strip()
        while t.startswith("(") and close_of(t, 0) == len(t) - 1 and "=>" not in t[close_of(t, 0) + 1:]:
            t = t[1:-1].strip()
        lit = literal(t)
        if lit is not None or t in ("null", "undefined"): return lit, ""
        if t.startswith("{") and close_of(t, 0) == len(t) - 1: return self.obj(mod, t, seen, local), ""
        if re.match(r"^(?:async\s+)?(?:\([^()]*\)|\w+)\s*(?::\s*[\w<>\[\]]+\s*)?=>|^function\b", t):
            call = re.search(r"=>\s*(?:\{[^}]*?\b(\w+)\(|(\w+)\()", t)
            return Fn(call and (call.group(1) or call.group(2)) or short(t, 30)), ""
        env = re.match(r"^(?:Number|parseInt|parseFloat)?\(?\s*(?:\w*[Ee]nv\w*)\(\s*['\"](\w+)['\"]\s*(?:,\s*(.+?))?\)\s*\)?$", t, re.S)
        if env:
            fb = self.expr(mod, env.group(2), seen, local)[0] if env.group(2) else None
            return Env(env.group(1), fb), ""
        env = re.match(r"^(?:Number|parseInt|parseFloat)?\(?\s*process\.env\.(\w+)\s*(?:\?\?|\|\|)\s*(.+?)\)?$", t, re.S)
        if env: return Env(env.group(1), self.expr(mod, env.group(2), seen, local)[0]), ""
        mem = re.fullmatch(r"(\w+)((?:\.\w+)+)", t)
        if mem or re.fullmatch(r"\w+", t):
            head = mem.group(1) if mem else t
            if local and head in local: return Run(t), ""
            v, src = self.ident(mod, head, seen)
            if v is None:
                if head in ("this", "job", "input", "opts", "options", "data") or (local is not None): return Run(t), ""
                return Unres("%s not found" % head), ""
            for part in (mem.group(2).split(".")[1:] if mem else []):
                if isinstance(v, dict) and part in v: v, src = v[part][0], v[part][1] or src
                else: return (v if isinstance(v, Unres) else Unres("%s.%s not resolvable" % (head, part))), src
            return v, src
        if re.fullmatch(r"[\w\s.()+\-*/_]+", t) and re.search(r"[+\-*/]", t):
            vals = {}
            for nm in set(re.findall(r"[A-Za-z_]\w*(?:\.\w+)*", t)):
                v, _ = self.expr(mod, nm, seen, local)
                if not isinstance(v, (int, float)) or isinstance(v, bool): return (Run(t) if isinstance(v, (Run, Env)) else Unres("arithmetic on %s" % nm)), ""
                vals[nm] = v
            expr = t
            for nm in sorted(vals, key=len, reverse=True): expr = re.sub(r"\b%s\b" % re.escape(nm), str(vals[nm]), expr)
            expr = expr.replace("_", "")
            if re.fullmatch(r"[\d\s.()+\-*/]+", expr):
                try: return eval(expr, {"__builtins__": {}}), ""
                except Exception: pass
        return Run(t), ""

    def obj(self, mod, t, seen, local, spread_hook=None):
        """Object literal → {key: (value, source)}; spreads merged in order (later wins)."""
        out = {}
        for ent in split_top(t[1:-1]):
            if ent.startswith("..."):
                inner = ent[3:].strip()
                tern = re.match(r"^\(?\s*([\w.!]+)\s*\?\s*(\{.*\})\s*:\s*\{\s*\}\s*\)?$", inner, re.S)
                if tern:
                    for k, (v, s) in self.obj(mod, tern.group(2), seen, local).items(): out[k] = (v, (s or "") + " if %s" % tern.group(1))
                    continue
                if spread_hook and spread_hook(inner, out): continue
                v, src = self.expr(mod, inner, seen, local)
                if isinstance(v, dict): out.update({k: (x, s or src) for k, (x, s) in v.items()})
                else: out["..." + short(inner, 20)] = (v if isinstance(v, (Unres, Run)) else Unres("spread of %s" % short(inner, 20)), src)
                continue
            if ":" in ent and not re.match(r"^\[", ent):
                k, _, v = ent.partition(":")
                k = k.strip().strip("'\"")
                if re.fullmatch(r"\w+\s*\([^)]*\)\s*", k): out[k.split("(")[0]] = (Fn(k), ""); continue
                val, src = self.expr(mod, v, seen, local)
                out[k] = (val, src)
            elif re.fullmatch(r"\w+", ent):
                val, src = self.expr(mod, ent, seen, local)
                out[ent] = (val, src)
            elif re.match(r"(?:async\s+)?\w+\s*\(", ent):
                out[re.match(r"(?:async\s+)?(\w+)", ent).group(1)] = (Fn(ent), "")
        return out


# ------------------------------------------------------------------ rows ----------------------------
def flat(d, pre=""):
    out = {}
    for k, (v, s) in d.items():
        if isinstance(v, dict) and k in ("settings", "deduplication", "limiter") and k != "limiter":
            out.update(flat(v, pre + k + "."))
        else:
            out[pre + k] = (v, s)
    return out


def bad(v): return isinstance(v, Unres)


class Inv:
    def __init__(self, repo):
        self.r, self.rows, self.wrappers = repo, [], {}

    def row(self, kind, lane, name, mod, line, opts, policy_set, dflt_key, extra=None):
        vstr, major = self.r.version(mod.path, lane)
        res, reasons = {}, []
        for k, (v, s) in opts.items():
            res[k] = (v, s)
        if dflt_key:
            for k, dv in DEFAULTS[dflt_key].items():
                if k not in res:
                    res[k] = (dv, "default:%s" % dflt_key) if major else (Unres("default needs the %s version" % lane), "")
        for k, (v, s) in res.items():
            root = k.split(".")[0]
            if k in policy_set or root in policy_set:
                if bad(v): reasons.append("%s: %s" % (k, v.why))
                elif isinstance(v, Run): reasons.append("%s is a runtime value (%s)" % (k, short(v.expr, 30)))
            elif bad(v) and k.startswith("..."): reasons.append("%s: %s" % (k, v.why))
        if extra:
            for k, (v, s) in extra.items(): res[k] = (v, s)
        status = "RESOLVED" if not reasons else "UNRESOLVED (%s)" % "; ".join(reasons[:3])
        self.rows.append({"kind": kind, "lane": lane, "name": name if isinstance(name, str) else show(name),
                          "site": "%s:%d" % (mod.rel, line), "status": status, "version": vstr or "UNREAD",
                          "resolved": res})

    # ---- BullMQ consumers
    def bullmq_consumers(self):
        for mod in self.r.relevant():
            for c in mod.classes:
                proc = [d for d in c.decos if d[0] == "Processor"]
                if not proc and not self.extends(c, "WorkerHost"): continue
                if not proc: continue                        # an abstract base: reported through its subclasses
                args = split_top(proc[0][1])
                qname, _ = self.r.expr(mod, args[0], frozenset()) if args else (Unres("no queue name"), "")
                if args and args[0].startswith("{"):
                    o = self.r.obj(mod, args[0], frozenset(), None); qname = o.get("name", (Unres("no name"), ""))[0]
                    opts = {k: v for k, v in o.items() if k != "name"}
                else:
                    opts = self.r.obj(mod, args[1], frozenset(), None) if len(args) > 1 and args[1].startswith("{") else {}
                owner = self.owner(c, "process")
                extra = {"process-owner": (owner and "%s %s:%d" % (owner.name, owner.mod.rel, owner.methods["process"]["line"]) or Unres("no process()"), "")}
                if owner:
                    body = owner.body("process")
                    dl = re.search(r"\b(withDeadline|withTimeout|AbortSignal\.timeout)\(\s*([^,)]+)", body)
                    extra["deadline"] = (self.deadline(c, owner, dl.group(2).strip()) if dl else "none", "%s %s" % (dl.group(1), owner.name) if dl else "")
                extra["onFailed"] = ("yes" if re.search(r"@OnWorkerEvent\(\s*['\"]failed", mod.m[c.ob:c.cb]) else "no", "")
                self.row("consumer", "bullmq", qname if not isinstance(qname, Unres) else "?", mod, proc[0][2], flat(opts),
                         POLICY["bullmq.worker"], "bullmq.worker", extra)
                if isinstance(qname, Unres): self.rows[-1]["status"] = "UNRESOLVED (queue name: %s)" % qname.why
            for mt in re.finditer(r"\bnew\s+Worker\s*\(", mod.m):
                a = mt.end() - 1; b = close_of(mod.m, a)
                args = split_top(mod.m[a + 1:b]) if b > 0 else []
                if not args: continue
                qn, _ = self.r.expr(mod, args[0], frozenset(), set())
                opts = self.r.obj(mod, args[2], frozenset(), set()) if len(args) > 2 and args[2].startswith("{") else (
                    {"...": (Unres("options %s" % short(args[2], 20)), "")} if len(args) > 2 else {})
                sand = len(args) > 1 and not re.match(r"(?:async\s+)?(?:\(|\w+\s*=>|function)", args[1])
                self.row("consumer", "bullmq", qn, mod, line_of(mod.m, mt.start()), flat(opts), POLICY["bullmq.worker"],
                         "bullmq.worker", {"processor": ("file (sandboxed)" if sand and re.search(r"path\.|['\"`]", args[1]) else short(args[1], 30), "")})

    def extends(self, c, base, depth=0):
        if depth > 8 or not c.base: return False
        if c.base.split(".")[-1] == base: return True
        return any(self.extends(p, base, depth + 1) for p in self.r.by_class.get(c.base.split(".")[-1], []))

    def owner(self, c, meth, depth=0):
        if meth in c.methods and c.methods[meth]["body"][1] > c.methods[meth]["body"][0]: return c
        if depth > 8 or not c.base: return None
        for p in self.r.by_class.get(c.base.split(".")[-1], []):
            o = self.owner(p, meth, depth + 1)
            if o: return o
        return None

    def deadline(self, c, owner, arg):
        m = re.fullmatch(r"this\.(\w+)", arg)
        if not m: return self.r.expr(owner.mod, arg, frozenset(), set())[0]
        ctor = owner.methods.get("constructor")
        if not ctor: return Run(arg)
        idx = [i for i, p in enumerate(ctor["params"]) if p[0] == m.group(1)]
        if not idx: return Run(arg)
        i = idx[0]
        sub = c.methods.get("constructor")
        if sub:
            sup = re.search(r"\bsuper\s*\(", c.body("constructor"))
            if sup:
                s = c.body("constructor"); a = sup.end() - 1; args = split_top(s[a + 1:close_of(s, a)])
                if len(args) > i: return self.r.expr(c.mod, args[i], frozenset(), set())[0]
        dv = ctor["params"][i][1]
        return self.r.expr(owner.mod, dv, frozenset(), set())[0] if dv else Run(arg)

    # ---- BullMQ producers
    def queue_defaults(self):
        qd = {}
        for mod in self.r.relevant():
            for mt in re.finditer(r"BullModule\.registerQueue\w*\s*\(|\bnew\s+Queue\s*\(", mod.m):
                a = mt.end() - 1; b = close_of(mod.m, a)
                if b < 0: continue
                for arg in split_top(mod.m[a + 1:b]):
                    if arg.startswith("{"):
                        o = self.r.obj(mod, arg, frozenset(), None)
                        if "defaultJobOptions" in o and isinstance(o.get("name", (None,))[0], str):
                            qd[o["name"][0]] = (o["defaultJobOptions"][0], "%s:%d" % (mod.rel, line_of(mod.m, mt.start())))
                if mt.group(0).startswith("new"):
                    args = split_top(mod.m[a + 1:b])
                    if len(args) > 1 and args[1].startswith("{"):
                        o = self.r.obj(mod, args[1], frozenset(), None); n, _ = self.r.expr(mod, args[0], frozenset(), None)
                        if "defaultJobOptions" in o and isinstance(n, str):
                            qd[n] = (o["defaultJobOptions"][0], "%s:%d" % (mod.rel, line_of(mod.m, mt.start())))
        return qd

    def bullmq_producers(self):
        qd = self.queue_defaults()
        for mod in self.r.relevant():
            for mt in re.finditer(r"\b(this\.)?(\w+)\.add\s*\(", mod.m):
                recv = mt.group(2)
                if not re.search(r"queue|dlq", recv, re.I) and not re.search(r"\b%s\s*[:=]\s*(?:new\s+)?Queue\b" % recv, mod.m): continue
                a = mt.end() - 1; b = close_of(mod.m, a)
                if b < 0: continue
                args = split_top(mod.m[a + 1:b]); line = line_of(mod.m, mt.start())
                cls, meth = self.enclosing(mod, mt.start())
                local = set(p[0] for p in cls.methods[meth]["params"]) | set(re.findall(r"\b(?:const|let)\s+\{?([^=}]+)", cls.body(meth))) if cls and meth else set()
                local = set(x.strip(" .") for s in local for x in re.split(r"[,:\s]+", s) if x.strip(" ."))
                param_spread = {}

                def hook(inner, out, cls=cls, meth=meth):
                    root = inner.split(".")[0]
                    if cls and meth:
                        src = self.param_root(cls, meth, root)
                        if src is not None:
                            param_spread["idx"] = src; param_spread["at"] = len(out); return True
                    return False
                opts = self.r.obj(mod, args[2], frozenset(), local, hook) if len(args) > 2 and args[2].startswith("{") else {}
                qname = self.queue_name(mod, cls, recv)
                if "idx" in param_spread:
                    keys = list(opts.items()); before = dict(keys[:param_spread["at"]]); after = dict(keys[param_spread["at"]:])
                    self.wrappers[(cls.name, meth)] = {"cls": cls, "idx": param_spread["idx"], "defaults": before, "forced": after, "line": line}
                    self.row("producer-wrapper", "bullmq", "%s.%s → %s" % (cls.name, meth, qname if isinstance(qname, str) else "per subclass"), mod, line,
                             flat({**before, **after}), POLICY["bullmq.job"], None, {"caller-options": ("merged at the spread (keys after it win)", "")})
                    continue
                base = qd.get(qname, ({}, ""))
                layered = {k: (v, s or base[1]) for k, (v, s) in (base[0].items() if isinstance(base[0], dict) else [])}
                layered.update(opts)
                self.row("producer", "bullmq", qname, mod, line, flat(layered), POLICY["bullmq.job"], "bullmq.job")
        self.wrapper_callers(qd)

    def enclosing(self, mod, idx):
        for c in mod.classes:
            if c.ob < idx < c.cb:
                for nm, mm in c.methods.items():
                    if mm["body"][0] <= idx <= mm["body"][1]: return c, nm
                return c, None
        return None, None

    def param_root(self, cls, meth, root):
        params = [p[0] for p in cls.methods[meth]["params"]]
        if root in params: return params.index(root)
        body = cls.body(meth)
        d = re.search(r"\{[^}]*\.\.\.%s\s*\}\s*=\s*(\w+)" % re.escape(root), body)
        if d and d.group(1) in params: return params.index(d.group(1))
        return None

    def queue_name(self, mod, cls, recv):
        decl = re.search(r"@InjectQueue\(\s*([^)]+)\)\s*(?:(?:private|protected|public|readonly)\s+)*%s\b" % re.escape(recv), mod.m)
        if decl: return self.r.expr(mod, decl.group(1), frozenset(), None)[0]
        nq = re.search(r"\b%s\s*=\s*new\s+Queue\s*\(\s*([^,)]+)" % re.escape(recv), mod.m)
        if nq: return self.r.expr(mod, nq.group(1), frozenset(), None)[0]
        return Unres("queue of this.%s is set by the subclass" % recv)

    def wrapper_callers(self, qd):
        """Propagate wrappers to the methods that pass their own parameter into them, then emit one row
        per call of an entry method in a concrete subclass (or one row per subclass when only callers outside
        the class enqueue)."""
        entries = dict(self.wrappers)
        changed = True
        while changed:
            changed = False
            for (cname, wm), w in list(entries.items()):
                for c in self.r.by_class.get(cname, []):
                    for nm, mm in c.methods.items():
                        if (cname, nm) in entries or nm == wm: continue
                        for call in re.finditer(r"\bthis\.%s\s*(?:<[^>()]*>)?\(" % re.escape(wm), c.body(nm)):
                            s = c.body(nm); a = call.end() - 1; args = split_top(s[a + 1:close_of(s, a)])
                            params = [p[0] for p in mm["params"]]
                            if len(args) > w["idx"] and args[w["idx"]] in params:
                                entries[(cname, nm)] = dict(w, idx=params.index(args[w["idx"]]), via=wm); changed = True
        bases = {cn for cn, _ in entries}
        for base in bases:
            for mod in self.r.relevant():
                for c in mod.classes:
                    if not c.base or c.base.split(".")[-1] != base: continue
                    q = re.search(r"@InjectQueue\(\s*([^)]+)\)", mod.m[c.ob:c.cb])
                    qname = self.r.expr(mod, q.group(1), frozenset(), None)[0] if q else Unres("no @InjectQueue")
                    over = {}
                    for nm in c.methods:
                        if (base, nm) in entries and re.search(r"\bsuper\.%s\(" % nm, c.body(nm)):
                            s = c.body(nm); sp = re.search(r"\bsuper\.%s\s*(?:<[^>()]*>)?\(" % nm, s)
                            a = sp.end() - 1; args = split_top(s[a + 1:close_of(s, a)]); i = entries[(base, nm)]["idx"]
                            if len(args) > i and args[i].startswith("{"):
                                o = self.r.obj(mod, args[i], frozenset(), set(p[0] for p in c.methods[nm]["params"]),
                                               lambda inner, out: inner.split(".")[0] in [p[0] for p in c.methods[nm]["params"]])
                                over[nm] = o
                    found = False
                    for nm, mm in c.methods.items():
                        if nm in over: continue
                        for call in re.finditer(r"\bthis\.(\w+)\s*(?:<[^>()]*>)?\(", c.body(nm)):
                            if (base, call.group(1)) not in entries: continue
                            found = True
                            s = c.body(nm); a = call.end() - 1; args = split_top(s[a + 1:close_of(s, a)])
                            w = entries[(base, call.group(1))]; i = w["idx"]
                            lit = args[i] if len(args) > i else None
                            local = set(p[0] for p in mm["params"]) | set(re.findall(r"\b(?:const|let)\s+(\w+)", s))
                            callopts = self.call_opts(mod, lit, local)
                            self.emit_layer(c, mod, mm["line"] + s.count("\n", 0, call.start()), qname, qd, w, over.get(call.group(1), {}), callopts, call.group(1))
                    if not found:
                        self.external_callers(c, base, entries, qname, qd, over)
                        w = entries[(base, next(m for (b2, m) in entries if b2 == base and m not in ("add",)) if any(b2 == base and m != "add" for b2, m in entries) else "add")]
                        ov = next(iter(over.values()), {})
                        self.emit_layer(c, mod, c.line, qname, qd, w, ov, {}, "inherited entry (callers outside the class; through an interface: read them)")

    def external_callers(self, c, base, entries, qname, qd, over):
        """Calls of an entry method on a field typed as this producer class, anywhere in the repo."""
        found = False
        for mod in self.r.relevant():
            for fd in re.finditer(r"(?:private|protected|public|readonly)\s+(?:readonly\s+)?(\w+)\s*:\s*%s\b" % re.escape(c.name), mod.m):
                for call in re.finditer(r"\bthis\.%s\.(\w+)\s*(?:<[^>()]*>)?\(" % re.escape(fd.group(1)), mod.m):
                    if (base, call.group(1)) not in entries: continue
                    found = True
                    a = call.end() - 1; args = split_top(mod.m[a + 1:close_of(mod.m, a)])
                    w = entries[(base, call.group(1))]; i = w["idx"]
                    if call.group(1) in over:                       # the subclass override adds its own layer
                        i = [p[0] for p in c.methods[call.group(1)]["params"]].index(c.methods[call.group(1)]["params"][i][0]) if i < len(c.methods[call.group(1)]["params"]) else i
                    callopts = self.call_opts(mod, args[i] if len(args) > i else None, set())
                    self.emit_layer(c, mod, line_of(mod.m, call.start()), qname, qd, w, over.get(call.group(1), {}), callopts, "%s (external caller)" % call.group(1))
        return found

    def call_opts(self, mod, lit, local):
        if lit is None: return {}
        tern = re.match(r"^([\w.!]+)\s*\?\s*(\{.*\})\s*:\s*(\{.*\})$", lit, re.S)
        if tern:
            a = self.r.obj(mod, tern.group(2), frozenset(), local); b = self.r.obj(mod, tern.group(3), frozenset(), local)
            out = {}
            for k in list(a) + [k for k in b if k not in a]:
                va, vb = a.get(k), b.get(k)
                out[k] = va if va and vb and show(va[0]) == show(vb[0]) else (Run("%s ? … : …" % k), "")
            return out
        if lit.startswith("{"): return self.r.obj(mod, lit, frozenset(), local)
        if lit in ("undefined", "null"): return {}
        return {"...": (Unres("call options %s" % short(lit, 24)), "")}

    def emit_layer(self, c, mod, line, qname, qd, w, override, callopts, entry):
        layers = {}
        base = qd.get(qname, ({}, "")) if isinstance(qname, str) else ({}, "")
        if isinstance(base[0], dict): layers.update({k: (v, s or base[1]) for k, (v, s) in base[0].items()})
        wmod = w["cls"].mod
        layers.update({k: (v, s or "%s:%d" % (wmod.rel, w["line"])) for k, (v, s) in w["defaults"].items()})
        layers.update({k: (v, s or "%s:%d (override)" % (mod.rel, c.line)) for k, (v, s) in override.items()})
        layers.update({k: (v, s or "%s:%d (call)" % (mod.rel, line)) for k, (v, s) in callopts.items()})
        layers.update({k: (v, s or "%s:%d (forced)" % (wmod.rel, w["line"])) for k, (v, s) in w["forced"].items()})
        self.row("producer", "bullmq", qname if isinstance(qname, str) else "?", mod, line, flat(layers),
                 POLICY["bullmq.job"], "bullmq.job", {"class": ("%s via %s" % (c.name, entry), "")})
        if not isinstance(qname, str): self.rows[-1]["status"] = "UNRESOLVED (queue name: %s)" % getattr(qname, "why", qname)

    # ---- kafkajs, amqplib, sqs-consumer (one module each; constants resolved across files)
    def node_other(self):
        for mod in self.r.relevant():
            m = mod.m
            for mt in re.finditer(r"\b(\w+)\.run\s*\(\s*\{", m):
                b = close_of(m, mt.end() - 1)
                o = self.r.obj(mod, m[mt.end() - 1:b + 1], frozenset(), set())
                if not ({"eachMessage", "eachBatch"} & set(o)): continue
                cfg = re.search(r"\b%s\s*=\s*\w+\.consumer\s*\(\s*(\{)" % re.escape(mt.group(1)), m)
                co = self.r.obj(mod, m[cfg.start(1):close_of(m, cfg.start(1)) + 1], frozenset(), set()) if cfg else {}
                opts = {k: v for k, v in {**co, **o}.items() if k not in ("eachMessage", "eachBatch")}
                opts["handler"] = ("eachBatch" if "eachBatch" in o else "eachMessage", "")
                self.row("consumer", "kafkajs", co.get("groupId", (Unres("groupId"), ""))[0] if co else "?", mod, line_of(m, mt.start()),
                         flat(opts), ("autoCommit", "eachBatchAutoResolve", "partitionsConsumedConcurrently", "sessionTimeout"), "kafkajs.consumer")
            for mt in re.finditer(r"\b\w*[pP]roducer\w*\.send(?:Batch)?\s*\(\s*\{", m):
                b = close_of(m, mt.end() - 1); o = self.r.obj(mod, m[mt.end() - 1:b + 1], frozenset(), set())
                cfg = re.search(r"\.producer\s*\(\s*(\{)", m)
                co = self.r.obj(mod, m[cfg.start(1):close_of(m, cfg.start(1)) + 1], frozenset(), set()) if cfg else {}
                if not cfg and "messages" not in o and "topic" not in o: continue
                self.row("producer", "kafkajs", o.get("topic", (Run("?"), ""))[0], mod, line_of(m, mt.start()),
                         flat({k: v for k, v in co.items()}), ("idempotent", "acks", "maxInFlightRequests"), "kafkajs.producer")
            if re.search(r"\bamqp(?:lib|-connection-manager)?\b", m):
                pf = re.search(r"\.prefetch\(\s*(\d+)", m)
                for mt in re.finditer(r"\b\w*(?:[cC]h|[cC]hannel)\.consume\s*\(", m):
                    a = mt.end() - 1; args = split_top(m[a + 1:close_of(m, a)])
                    o = self.r.obj(mod, args[2], frozenset(), set()) if len(args) > 2 and args[2].startswith("{") else {}
                    if pf: o["prefetch"] = (int(pf.group(1)), "%s:%d" % (mod.rel, line_of(m, pf.start())))
                    self.row("consumer", "amqplib", self.r.expr(mod, args[0], frozenset(), set())[0] if args else "?", mod,
                             line_of(m, mt.start()), o, ("noAck", "prefetch"), "amqplib.consume")
            for mt in re.finditer(r"\bConsumer\.create\s*\(\s*\{", m):
                b = close_of(m, mt.end() - 1); o = self.r.obj(mod, m[mt.end() - 1:b + 1], frozenset(), set())
                o = {k: v for k, v in o.items() if not k.startswith("handleMessage") or k == "handleMessageTimeout"}
                self.row("consumer", "sqs", o.pop("queueUrl", (Run("?"), ""))[0], mod, line_of(m, mt.start()), o,
                         ("alwaysAcknowledge", "heartbeatInterval", "visibilityTimeout", "batchSize"), "sqs.consumer")

    # ---- Celery and Spring (locate + same-module constants)
    def python(self):
        conf = {}
        for p, t in self.r.py.items():
            for mt in re.finditer(r"(?m)^\s*(?:CELERY_)?(?:TASK_ACKS_LATE|task_acks_late)\s*=\s*(\w+)|\.conf\.(?:task_acks_late)\s*=\s*(\w+)|task_acks_late\s*=\s*(\w+)", t):
                conf["acks_late"] = (literal(mt.group(1) or mt.group(2) or mt.group(3)), "%s:%d (app conf)" % (os.path.relpath(p, self.r.root), line_of(t, mt.start())))
        for p, t in self.r.py.items():
            m = mask(t, hash_comments=True); rel = os.path.relpath(p, self.r.root)
            consts = {mt.group(1): mt.group(2) for mt in re.finditer(r"(?m)^(\w+)\s*=\s*([^\n]+)", m)}
            for mt in re.finditer(r"@(?:\w+\.)?(?:shared_task|task)\b(\s*\()?", m):
                o = {}
                if mt.group(1):
                    a = mt.end() - 1; b = close_of(m, a)
                    for ent in split_top(m[a + 1:b]):
                        k, _, v = ent.partition("=")
                        v = v.strip()
                        if v in consts: v = consts[v].strip()
                        val = literal(v)
                        o[k.strip()] = (val if val is not None or v == "None" else (v if v.startswith("(") else Unres("%s" % short(v, 20))), "")
                for k, v in conf.items(): o.setdefault(k, v)
                fn = re.search(r"\bdef\s+(\w+)", m[mt.end():mt.end() + 400])
                major = self.r.version(p, "celery")[1]
                res = {k: v for k, v in o.items() if k not in ("bind", "name")}
                fake = type("M", (), {"path": p, "rel": rel})
                self.row("consumer", "celery", fn.group(1) if fn else "?", fake, line_of(m, mt.start()), res,
                         ("acks_late", "max_retries", "autoretry_for", "reject_on_worker_lost"), "celery.task")

    def java(self):
        for p, t in self.r.java.items():
            m = mask(t); rel = os.path.relpath(p, self.r.root)
            for mt in re.finditer(r"@(KafkaListener|RabbitListener|SqsListener|JmsListener)\s*\(([^)]*)\)", m):
                fake = type("M", (), {"path": p, "rel": rel})
                attrs = dict((k.strip(), v.strip()) for k, _, v in (a.partition("=") for a in split_top(mt.group(2))) if _)
                self.row("consumer", "spring", attrs.get("topics") or attrs.get("queues") or attrs.get("value") or short(mt.group(2), 30),
                         fake, line_of(m, mt.start()), {"containerFactory": (attrs.get("containerFactory", "default bean"), "")},
                         ("errorHandler",), None,
                         {"errorHandler": (Unres("container factory / CommonErrorHandler bean: read it (locate-only lane)"), "")})
                self.rows[-1]["status"] = "UNRESOLVED (Spring lane is locate-only: read the container factory and error handler beans)"


def run(argv):
    fmt, lanes, root = "tsv", None, None
    for a in argv:
        if a.startswith("--format="): fmt = a.split("=", 1)[1]
        elif a.startswith("--lane="): lanes = set(a.split("=", 1)[1].split(","))
        elif a.startswith("-"): print("unknown arg: " + a, file=sys.stderr); return 2
        else: root = a
    if not root or not os.path.isdir(root):
        print(__doc__.split("Usage:")[1].split("Exit:")[0].strip(), file=sys.stderr); return 2
    inv = Inv(Repo(root))
    if not lanes or "bullmq" in lanes: inv.bullmq_consumers(); inv.bullmq_producers()
    if not lanes or lanes & {"kafkajs", "amqplib", "sqs"}: inv.node_other()
    if not lanes or "celery" in lanes: inv.python()
    if not lanes or "spring" in lanes: inv.java()
    pair_backoff(inv)
    rows = inv.rows
    if fmt == "json":
        print(json.dumps([dict(r, resolved={k: [show(v) if not isinstance(v, (Unres, Run, Env)) else repr(v), s] for k, (v, s) in r["resolved"].items()}) for r in rows], indent=1))
    else:
        print("kind\tlane\tname\tsite\tstatus\tversion\tresolved")
        for r in rows:
            cells = "; ".join("%s=%s%s" % (k, show(v) if not isinstance(v, (Unres, Run, Env)) else repr(v), " [%s]" % s if s else "")
                              for k, (v, s) in r["resolved"].items())
            print("\t".join([r["kind"], r["lane"], str(r["name"]), r["site"], r["status"], r["version"], cells]))
    cons = [r for r in rows if r["kind"] == "consumer"]; prod = [r for r in rows if r["kind"] == "producer"]
    ok = lambda rs: sum(1 for r in rs if r["status"] == "RESOLVED")
    print("# resolved %d/%d — consumers %d/%d, producers %d/%d, wrappers %d" % (ok(cons + prod), len(cons + prod), ok(cons), len(cons),
          ok(prod), len(prod), sum(1 for r in rows if r["kind"] == "producer-wrapper")))
    shapes = {}
    for r in rows:
        if r["status"] != "RESOLVED": shapes.setdefault(r["status"], []).append(r["site"])
    for c in getattr(inv, "candidates", []): print("# candidate: " + c)
    for st, sites in sorted(shapes.items()):
        print("# %s × %d: %s" % (st, len(sites), ", ".join(sites[:4]) + (" …" if len(sites) > 4 else "")))
    return 0


def pair_backoff(inv):
    """A job with `backoff: { type: 'custom' }` uses the consuming Worker's `settings.backoffStrategy`; BullMQ
    throws `Unknown backoff strategy` when the worker has none (src/classes/backoffs.ts, read 2026-10-14)."""
    strat = {r["name"]: (r["resolved"].get("settings.backoffStrategy"), r["site"]) for r in inv.rows if r["kind"] == "consumer" and r["lane"] == "bullmq"}
    inv.candidates = []
    for r in inv.rows:
        b = r["resolved"].get("backoff")
        if r["kind"] != "producer" or not b or not isinstance(b[0], dict) or b[0].get("type", (None,))[0] != "custom": continue
        att = r["resolved"].get("attempts", (None,))[0]
        s = strat.get(r["name"])
        if att == 1: r["resolved"]["backoff.strategy"] = ("n/a (attempts 1: never retried)", "")
        elif s is None: r["resolved"]["backoff.strategy"] = (Unres("no worker for queue %s in this repo" % r["name"]), ""); r["status"] = "UNRESOLVED (no worker for queue %s in this repo)" % r["name"]
        elif s[0]: r["resolved"]["backoff.strategy"] = (s[0][0], "worker %s" % s[1])
        else:
            r["resolved"]["backoff.strategy"] = ("MISSING", "worker %s sets no backoffStrategy" % s[1])
            inv.candidates.append("%s: custom backoff, attempts %s, worker %s has no backoffStrategy (retry-deadline-scan §3 / messaging-scan §3)" % (r["site"], show(att), s[1]))


# ------------------------------------------------------------------ self-test -----------------------
SELF = {
    "package.json": '{"dependencies": {"bullmq": "^6.3.4", "@nestjs/bullmq": "^11.0.5", "kafkajs": "2.2.4", "amqplib": "2.2.0", "sqs-consumer": "^15.0.0"}}',
    "src/queue/constants.ts": "export enum QueueName { MAIL = 'mail', CHARGE = 'charge' }\nexport const JOB_ATTEMPTS = 3;\n"
                              "export const LIMITER = { max: 50, duration: 1_000 } as const;\n"
                              "export const CONCURRENCY = positiveIntEnv('WORKER_CONCURRENCY', 5);\nexport const BACKOFF = { type: 'custom' } as const;\n",
    "src/queue/base.producer.ts": "import { JOB_ATTEMPTS, BACKOFF } from './constants';\nexport abstract class BaseProducer {\n"
                                  "  protected constructor(protected readonly queue: Queue) {}\n"
                                  "  async enqueue(name: string, data: unknown, key?: string, opts?: JobsOptions) {\n    return this.add(name, data, key, opts);\n  }\n"
                                  "  private async add(name: string, data: unknown, key: string | undefined, opts: JobsOptions | undefined) {\n"
                                  "    const { priority = 1, ...rest } = opts ?? {};\n"
                                  "    return this.queue.add(name, data, { ...(key ? { jobId: key } : {}), removeOnComplete: 1000, attempts: JOB_ATTEMPTS, backoff: BACKOFF, ...rest, priority });\n  }\n}\n",
    "src/queue/mail.producer.ts": "import { QueueName } from './constants';\nimport { BaseProducer } from './base.producer';\n"
                                  "export class MailProducer extends BaseProducer {\n  constructor(@InjectQueue(QueueName.MAIL) queue: Queue) { super(queue); }\n"
                                  "  async send(to: string) {\n    await this.enqueue('send', { to }, to, { attempts: 1 });\n  }\n}\n",
    "src/queue/charge.producer.ts": "import { QueueName } from './constants';\nimport { BaseProducer } from './base.producer';\n"
                                    "export class ChargeProducer extends BaseProducer {\n  constructor(@InjectQueue(QueueName.CHARGE) queue: Queue) { super(queue); }\n"
                                    "  override async enqueue(name: string, data: unknown, key?: string, opts?: JobsOptions) {\n"
                                    "    return super.enqueue(name, data, key, { attempts: 5, ...opts });\n  }\n}\n",
    "src/queue/base.worker.ts": "export abstract class BaseWorker extends WorkerHost {\n  constructor(private readonly deadlineMs: number = 30_000) { super(); }\n"
                                "  async process(job: Job) {\n    await withDeadline(this.deadlineMs, () => this.handle(job));\n  }\n}\n",
    "src/queue/mail.processor.ts": "import { QueueName, CONCURRENCY, LIMITER } from './constants';\n"
                                   "@Processor(QueueName.MAIL, {\n  concurrency: CONCURRENCY,\n  limiter: { ...LIMITER, max: 10 },\n"
                                   "  settings: { backoffStrategy: (n: number) => jittered(n) },\n})\nexport class MailProcessor extends BaseWorker {\n"
                                   "  protected async handle(job: Job) { await this.mailer.send(job.data.to); }\n  @OnWorkerEvent('failed')\n  onFailed() {}\n}\n",
    "src/queue/charge.processor.ts": "import { QueueName } from './constants';\nimport { CONFIG } from '@acme/config';\n"
                                     "@Processor(QueueName.CHARGE, { concurrency: CONFIG.workers, lockDuration: 5000 })\n"
                                     "export class ChargeProcessor extends BaseWorker {\n  constructor() { super(120_000); }\n"
                                     "  protected async handle(job: Job) { await this.psp.charge(job.data); }\n}\n",
    "src/queue/plain.ts": "const reports = new Queue('reports', { connection, defaultJobOptions: { attempts: 4, removeOnFail: true } });\n"
                          "export async function kick() { await reports.add('daily', {}, { delay: 1000 }); }\n"
                          "const w = new Worker('reports', path.join(__dirname, 'render.js'), { connection, maxStalledCount: 3 });\n",
    "src/kafka/pay.ts": "const consumer = kafka.consumer({ groupId: 'payments' });\n"
                        "await consumer.run({ partitionsConsumedConcurrently: 3, eachMessage: async ({ message }) => { await handle(message); } });\n"
                        "const producer = kafka.producer({ idempotent: true });\nawait producer.send({ topic: 'paid', messages: [] });\n",
    "src/amqp/mail.ts": "import amqp from 'amqplib';\nconst ch = await conn.createChannel();\nawait ch.prefetch(10);\n"
                        "await ch.consume('mail', async (msg) => { await send(msg); ch.ack(msg); }, { noAck: false });\n",
    "src/sqs/orders.ts": "const app = Consumer.create({ queueUrl: QUEUE_URL, batchSize: 10, handleMessage: async (m) => { await go(m); return m; } });\n",
    "worker/tasks.py": "from celery import shared_task\nMAX = 7\n@shared_task(bind=True, acks_late=True, max_retries=MAX, autoretry_for=(Exception,))\ndef charge(self, oid):\n    pass\n",
    "src/queue/mail.processor.spec.ts": "@Processor('ignored') export class Ignored extends WorkerHost {}\n",
}
EXPECT = [  # (kind, name, site-suffix, status-prefix, {key: rendered value substring})
    ("consumer", "mail", "mail.processor.ts:2", "RESOLVED", {"concurrency": "env:WORKER_CONCURRENCY|5", "limiter": "max: 10", "lockDuration": "30000",
                                                              "maxStalledCount": "1", "deadline": "30000", "onFailed": "yes", "process-owner": "BaseWorker"}),
    ("consumer", "charge", "charge.processor.ts:3", "UNRESOLVED", {"concurrency": "UNRESOLVED", "lockDuration": "5000", "deadline": "120000"}),
    ("consumer", "reports", "plain.ts:3", "RESOLVED", {"maxStalledCount": "3", "processor": "sandboxed"}),
    ("producer", "mail", "mail.producer.ts:6", "RESOLVED", {"attempts": "1", "removeOnComplete": "1000", "backoff.strategy": "n/a", "jobId": "runtime"}),
    ("producer", "charge", "charge.producer.ts:3", "RESOLVED", {"attempts": "5", "backoff.strategy": "MISSING"}),
    ("producer", "reports", "plain.ts:2", "RESOLVED", {"attempts": "4", "removeOnFail": "true", "delay": "1000"}),
    ("consumer", "payments", "pay.ts:2", "RESOLVED", {"partitionsConsumedConcurrently": "3", "autoCommit": "true"}),
    ("producer", "paid", "pay.ts:4", "RESOLVED", {"idempotent": "true"}),
    ("consumer", "mail", "mail.ts:4", "RESOLVED", {"prefetch": "10", "noAck": "false"}),
    ("consumer", "runtime(QUEUE_URL)", "orders.ts:1", "RESOLVED", {"batchSize": "10", "alwaysAcknowledge": "false"}),
    ("consumer", "charge", "tasks.py:3", "RESOLVED", {"acks_late": "true", "max_retries": "7"}),
]


def self_test():
    d = tempfile.mkdtemp(prefix="ds-inventory-")
    for rel, txt in SELF.items():
        p = os.path.join(d, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w").write(txt)
    open(os.path.join(d, "requirements.txt"), "w").write("celery==5.6.3\n")
    inv = Inv(Repo(d)); inv.bullmq_consumers(); inv.bullmq_producers(); inv.node_other(); inv.python(); inv.java(); pair_backoff(inv)
    fails = 0
    for kind, name, site, st, keys in EXPECT:
        hit = [r for r in inv.rows if r["kind"] == kind and str(r["name"]) == name and r["site"].endswith(site)]
        if not hit:
            fails += 1; print("self-test: missing %s %s at %s; rows: %s" % (kind, name, site, [(r["kind"], r["name"], r["site"]) for r in inv.rows])); continue
        r = hit[0]
        if not r["status"].startswith(st): fails += 1; print("self-test: %s %s status %s, want %s" % (kind, site, r["status"], st))
        for k, want in keys.items():
            got = r["resolved"].get(k)
            txt = (show(got[0]) if not isinstance(got[0], (Unres, Run, Env)) else repr(got[0])) if got else "<absent>"
            if want not in txt: fails += 1; print("self-test: %s %s: %s = %s, want ~%s" % (kind, site, k, txt, want))
    if any("spec" in r["site"] for r in inv.rows): fails += 1; print("self-test: a spec file was inventoried")
    if not any(r["kind"] == "producer-wrapper" for r in inv.rows): fails += 1; print("self-test: the producer wrapper was not found")
    print("self-test:", "PASS (%d expectations)" % len(EXPECT) if not fails else "FAIL (%d)" % fails)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else run(sys.argv[1:]))
