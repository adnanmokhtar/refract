#!/usr/bin/env python3
"""standards-check.py — deterministic checks behind the engineering baseline.

Usage:  standards-check.py <target-repo> [--changed=<git-ref>] [--check=ID[,ID]] [--quiet]
Exit:   0  every finding is MET or allow-listed
        1  at least one finding is open
        2  usage error

The engineering baseline (templates/governance/engineering-baseline/) names each standard and
the evidence that closes it; the standards gate asks the model for that evidence. This script
is the half that does not depend on the model remembering: it reads the code and says which
rows are open.

CHECK natural-key-unique (baseline DATA-1)
------------------------------------------
Every column that is a natural key — email, username, login, handle, phone, slug, sku — on a
table that holds identities or catalogue rows must carry a DATABASE-level unique constraint:
declared on the entity / model, or created by a migration, alone or inside a composite key
(tenant_id, email), or on a normalised sibling column (phone_key, email_normalized, lower(email)).

WHY. A V1→V2 port kept every endpoint, field and screen of a marketers module and dropped the
guarantee that one e-mail makes one marketer: V1 checked before inserting and its auth layer
enforced the rest; V2 had neither a constraint nor a serialized check, and three fast saves
produced three marketers on one address. The rule demanding a unique constraint was loaded the
whole time. A model can forget a rule; a scan of the schema cannot.

What is read: entity/model declarations (MikroORM / TypeORM decorators, Prisma models, Django
models, Sequelize / Mongoose object schemas) and every unique constraint a migration or SQL file
creates (raw SQL — including SQL inside addSql()/query() — Knex, Laravel, Rails). Tables that
are logs, events, messages, snapshots or line items are skipped: an e-mail on an audit row is a
copy, not a key.

Allow-list: `.claude/standards-check.allow`, one line per accepted exception —
    DATA-1 customers.email — guest checkouts share an address; the key is the phone
An allow-listed finding is reported, never hidden, and never fails the run.
"""
import os
import re
import sys

NATURAL = {
    "email", "emailaddress", "username", "login", "handle",
    "phone", "phonenumber", "mobile", "mobilenumber", "slug", "sku",
}
SKIP_TABLE = re.compile(
    r"(^|_)(logs?|events?|messages?|notifications?|audits?|audit_log|history|histories|"
    r"snapshots?|items|lines|attempts?|otps?|sessions?|tokens?|outbox|jobs?|webhooks?|"
    r"deliveries|receipts?|edits?|imports?|exports?|reports?|metrics?|stats?)($|_)")
SKIP_DIRS = {"node_modules", ".git", "dist", "build", "vendor", "coverage", ".next", ".nuxt",
             ".turbo", ".claude", "ai", "__pycache__", ".venv", "venv", "tmp", ".playwright-mcp"}
EXTS = (".ts", ".js", ".mjs", ".cjs", ".py", ".rb", ".php", ".sql", ".prisma")


def norm(name):
    """email_address / emailAddress / "email" -> emailaddress"""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def snake(name):
    return re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", name).lower()


def split_cols(s):
    """Column names in a key list — `"tenant_id", lower(btrim("email"))` -> [tenant_id, email].
    A function-wrapped entry names its innermost identifier, whatever the nesting."""
    out, depth, cur = [], 0, ""
    for ch in s:                                     # split on top-level commas only
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    cols = []
    for part in out:
        ids = re.findall(r"[\"'`\[]?(\w+)[\"'`\]]?\s*\)*\s*(?:asc|desc)?\s*$", part.strip(), re.I)
        if ids:
            cols.append(ids[-1])
    return cols


class Scan:
    def __init__(self, root):
        self.root = root
        self.columns = []           # (table, column, file, line)
        self.uniques = {}           # table -> set of normalised column names covered by a unique

    def add_unique(self, table, cols):
        table = snake(table.strip("\"'`[]")).split(".")[-1]
        s = self.uniques.setdefault(table, set())
        for c in cols:
            s.add(norm(c))

    def add_col(self, table, col, path, text, pos):
        line = text.count("\n", 0, pos) + 1
        self.columns.append((snake(table).split(".")[-1], col, path, line))

    # ── entity / model declarations ──────────────────────────────────────────────────────
    def ts_entities(self, path, t):
        for em in re.finditer(r"@Entity\s*\(([^)]*)\)", t):
            arg = em.group(1)
            nm = (re.search(r"tableName\s*:\s*['\"`]([^'\"`]+)", arg)
                  or re.search(r"name\s*:\s*['\"`]([^'\"`]+)", arg)
                  or re.search(r"^\s*['\"`]([^'\"`]+)", arg))
            start = em.end()
            nxt = t.find("@Entity", start)
            body = t[start: nxt if nxt != -1 else len(t)]
            cm = re.search(r"class\s+(\w+)", body)
            table = nm.group(1) if nm else (snake(re.sub(r"(Entity|Model|Orm)$", "", cm.group(1))) + "s"
                                             if cm else None)
            if not table:
                continue
            # class-level @Unique / @Index({unique:true}) — the text between @Entity and `class`
            head = body[: cm.start()] if cm else ""
            for um in re.finditer(r"@Unique\s*\(\s*(\{[^}]*\}|\[[^\]]*\])", head):
                self.add_unique(table, re.findall(r"['\"`](\w+)['\"`]", um.group(1)))
            for im in re.finditer(r"@Index\s*\(([^)]*)\)", head):
                if re.search(r"unique\s*:\s*true", im.group(1)):
                    self.add_unique(table, re.findall(r"['\"`](\w+)['\"`]", im.group(1)))
            for pm in re.finditer(r"@(Property|Column|PrimaryColumn|Field)\s*\(([^)]*)\)\s*"
                                  r"(?:@\w+\([^)]*\)\s*)*(?:/\*\*[\s\S]*?\*/\s*)?(?:readonly\s+)?(\w+)[!?]?\s*[:=]", body):
                col = pm.group(3)
                if re.search(r"unique\s*:\s*true", pm.group(2)):
                    self.add_unique(table, [col])
                if norm(col) in NATURAL:
                    self.add_col(table, col, path, t, start + pm.start(3))
            # property-level @Unique() on its own line above the property
            for pm in re.finditer(r"@Unique\s*\(\s*\)\s*(?:@\w+\([^)]*\)\s*)*(\w+)[!?]?\s*:", body):
                self.add_unique(table, [pm.group(1)])

    def prisma(self, path, t):
        for mm in re.finditer(r"(?m)^model\s+(\w+)\s*\{([\s\S]*?)^\}", t):
            model, body = mm.group(1), mm.group(2)
            mapm = re.search(r"@@map\(\s*\"([^\"]+)\"", body)
            table = mapm.group(1) if mapm else snake(model)
            for fm in re.finditer(r"(?m)^\s*(\w+)\s+\w+[?\[\]]*\s*(.*)$", body):
                col, attrs = fm.group(1), fm.group(2)
                if col.startswith("@@"):
                    continue
                if re.search(r"@unique\b|@id\b", attrs):
                    self.add_unique(table, [col])
                if norm(col) in NATURAL:
                    self.add_col(table, col, path, t, mm.start(2) + fm.start(1))
            for um in re.finditer(r"@@(unique|id)\s*\(\s*(?:fields\s*:\s*)?\[([^\]]*)\]", body):
                self.add_unique(table, re.findall(r"\w+", um.group(2)))

    def django(self, path, t):
        for cm in re.finditer(r"(?m)^class\s+(\w+)\s*\([^)]*Model[^)]*\)\s*:", t):
            start = cm.end()
            nxt = re.search(r"(?m)^class\s+\w+", t[start:])
            body = t[start: start + nxt.start() if nxt else len(t)]
            dbt = re.search(r"db_table\s*=\s*['\"]([^'\"]+)", body)
            table = dbt.group(1) if dbt else snake(cm.group(1)) + "s"
            for fm in re.finditer(r"(?m)^\s+(\w+)\s*=\s*models\.\w+\(([^)]*)\)", body):
                col = fm.group(1)
                if re.search(r"unique\s*=\s*True|primary_key\s*=\s*True", fm.group(2)):
                    self.add_unique(table, [col])
                if norm(col) in NATURAL:
                    self.add_col(table, col, path, t, start + fm.start(1))
            for um in re.finditer(r"UniqueConstraint\s*\([^)]*fields\s*=\s*[\[(]([^\])]*)", body):
                self.add_unique(table, re.findall(r"['\"](\w+)['\"]", um.group(1)))
            for um in re.finditer(r"unique_together\s*=\s*([\[(][\s\S]*?[\])])\s*$", body, re.M):
                self.add_unique(table, re.findall(r"['\"](\w+)['\"]", um.group(1)))

    def object_schemas(self, path, t):
        # Sequelize define('name', {...}) / Model.init({...}, {tableName}) and Mongoose new Schema({...})
        for dm in re.finditer(r"\.define\(\s*['\"`](\w+)['\"`]\s*,\s*\{", t):
            self._object_body(dm.group(1), path, t, dm.end())
        for sm in re.finditer(r"(?:const|let|var)\s+(\w+)\s*=\s*new\s+(?:mongoose\.)?Schema\s*\(\s*\{", t):
            name = re.sub(r"Schema$", "", sm.group(1))
            mm = re.search(r"model\(\s*['\"`](\w+)['\"`]\s*,\s*%s\b" % re.escape(sm.group(1)), t)
            table = snake(mm.group(1)) + "s" if mm else snake(name) + "s"
            self._object_body(table, path, t, sm.end())

    def _object_body(self, table, path, t, pos):
        depth, i = 1, pos
        while i < len(t) and depth:
            depth += {"{": 1, "}": -1}.get(t[i], 0)
            i += 1
        body = t[pos:i]
        for fm in re.finditer(r"(?m)^\s*(\w+)\s*:\s*(\{[^{}]*\}|[\w.]+)", body):
            col, spec = fm.group(1), fm.group(2)
            if re.search(r"unique\s*:\s*true", spec):
                self.add_unique(table, [col])
            if norm(col) in NATURAL:
                self.add_col(table, col, path, t, pos + fm.start(1))

    # ── unique constraints created by migrations / SQL ───────────────────────────────────
    def sql_uniques(self, t):
        q = r"[\"'`\[]?"
        ident = r"[\"'`\[]?([\w.]+)[\"'`\]]?"
        for m in re.finditer(r"create\s+unique\s+index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?"
                             r"\S+\s+on\s+(?:only\s+)?" + ident + r"(?:\s+using\s+\w+)?\s*\(([^;]*?)\)\s*(?:where|;|\"|'|`|$)",
                             t, re.I | re.M):
            self.add_unique(m.group(1), split_cols(m.group(2)))
        for m in re.finditer(r"alter\s+table\s+(?:only\s+)?" + ident + r"\s+add\s+(?:constraint\s+\S+\s+)?unique\s*"
                             r"(?:\s+index\s+\S+\s*)?\(([^)]*)\)", t, re.I):
            self.add_unique(m.group(1), split_cols(m.group(2)))
        for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?" + ident + r"\s*\(", t, re.I):
            depth, i = 1, m.end()
            while i < len(t) and depth:
                depth += {"(": 1, ")": -1}.get(t[i], 0)
                i += 1
            body = t[m.end(): i - 1]
            for um in re.finditer(r"unique\s*\(([^)]*)\)", body, re.I):
                self.add_unique(m.group(1), split_cols(um.group(1)))
            for line in body.split(","):
                cm = re.match(r"\s*" + q + r"(\w+)" + q + r"\s+\w+[^,]*\bunique\b", line, re.I)
                if cm:
                    self.add_unique(m.group(1), [cm.group(1)])

    def sql_tables(self, path, t):
        """Columns straight from CREATE TABLE, for projects with no entity layer."""
        for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?[\"'`\[]?([\w.]+)[\"'`\]]?\s*\(", t, re.I):
            depth, i = 1, m.end()
            while i < len(t) and depth:
                depth += {"(": 1, ")": -1}.get(t[i], 0)
                i += 1
            body = t[m.end(): i - 1]
            for cm in re.finditer(r"(?m)^\s*[\"'`\[]?(\w+)[\"'`\]]?\s+(?:varchar|text|character|citext|string|char)", body, re.I):
                if norm(cm.group(1)) in NATURAL:
                    self.add_col(m.group(1), cm.group(1), path, t, m.end() + cm.start(1))

    def laravel(self, t):
        for m in re.finditer(r"Schema::(?:create|table)\(\s*['\"](\w+)['\"]", t):
            nxt = t.find("Schema::", m.end())
            body = t[m.end(): nxt if nxt != -1 else len(t)]
            for um in re.finditer(r"\$table->\w+\(\s*['\"](\w+)['\"][^;]*->unique\(\)", body):
                self.add_unique(m.group(1), [um.group(1)])
            for um in re.finditer(r"\$table->unique\(\s*(\[[^\]]*\]|['\"]\w+['\"])", body):
                self.add_unique(m.group(1), re.findall(r"['\"](\w+)['\"]", um.group(1)))

    def laravel_cols(self, path, t):
        for m in re.finditer(r"Schema::create\(\s*['\"](\w+)['\"]", t):
            nxt = t.find("Schema::", m.end())
            body = t[m.end(): nxt if nxt != -1 else len(t)]
            for cm in re.finditer(r"\$table->(?:string|text|char)\(\s*['\"](\w+)['\"]", body):
                if norm(cm.group(1)) in NATURAL:
                    self.add_col(m.group(1), cm.group(1), path, t, m.end() + cm.start(1))

    def rails(self, path, t):
        for m in re.finditer(r"create_table\s+[\"':](\w+)", t):
            nxt = re.search(r"create_table\s", t[m.end():])
            body = t[m.end(): m.end() + nxt.start() if nxt else len(t)]
            for cm in re.finditer(r"t\.(?:string|text|citext)\s+[\"':](\w+)", body):
                if norm(cm.group(1)) in NATURAL:
                    self.add_col(m.group(1), cm.group(1), path, t, m.end() + cm.start(1))
            for im in re.finditer(r"t\.index\s+\[([^\]]*)\][^\n]*unique:\s*true", body):
                self.add_unique(m.group(1), re.findall(r"\w+", im.group(1)))
        for im in re.finditer(r"add_index\s+[\"':](\w+)\s*,\s*(\[[^\]]*\]|[\"':]\w+)[^\n]*unique:\s*true", t):
            self.add_unique(im.group(1), re.findall(r"\w+", im.group(2)))

    def knex(self, t):
        for m in re.finditer(r"(?:createTable|alterTable|table)\(\s*['\"`](\w+)['\"`]", t):
            nxt = re.search(r"(?:createTable|alterTable)\(", t[m.end():])
            body = t[m.end(): m.end() + nxt.start() if nxt else len(t)]
            for um in re.finditer(r"\.\w+\(\s*['\"`](\w+)['\"`][^;\n]*\.unique\(\)", body):
                self.add_unique(m.group(1), [um.group(1)])
            for um in re.finditer(r"\w+\.unique\(\s*(\[[^\]]*\]|['\"`]\w+['\"`])", body):
                self.add_unique(m.group(1), re.findall(r"['\"`](\w+)['\"`]", um.group(1)))

    def run(self):
        for dp, dns, fns in os.walk(self.root):
            dns[:] = [d for d in dns if d not in SKIP_DIRS]
            for fn in fns:
                if not fn.endswith(EXTS) or re.search(r"\.(spec|test)\.", fn):
                    continue
                p = os.path.join(dp, fn)
                try:
                    t = open(p, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                rel = os.path.relpath(p, self.root)
                if fn.endswith((".ts", ".js", ".mjs", ".cjs")):
                    if "@Entity" in t:
                        self.ts_entities(rel, t)
                    if ".define(" in t or "Schema(" in t:
                        self.object_schemas(rel, t)
                    self.knex(t)
                elif fn.endswith(".prisma"):
                    self.prisma(rel, t)
                elif fn.endswith(".py"):
                    if "models." in t:
                        self.django(rel, t)
                elif fn.endswith(".php"):
                    self.laravel(t)
                    self.laravel_cols(rel, t)
                elif fn.endswith(".rb"):
                    self.rails(rel, t)
                if re.search(r"unique", t, re.I):
                    self.sql_uniques(t)
                if fn.endswith(".sql"):
                    self.sql_tables(rel, t)


def covered(scan, table, col):
    u = scan.uniques.get(table, set())
    c = norm(col)
    if c in u:
        return True
    # a unique on a normalised sibling guarantees the column: phone_key, email_normalized, …
    return any(x in u for x in (c + "key", c + "normalized", "normalized" + c, c + "lower",
                                c + "canonical", "canonical" + c, c + "hash"))


# ── the other checks: one pass over the tree, each check a small classifier ──────────────────
TEST_PATH = re.compile(r"(^|/)(tests?|__tests__|spec|specs|e2e|cypress|playwright|fixtures|__mocks__|mocks?)(/|$)"
                       r"|\.(spec|test|e2e|stories)\.")
TOOL_PATH = re.compile(r"(^|/)(scripts?|seeds?|migrations?|tools?|bin|deploy)(/|$)|\.config\.")
SERVER_PATH = re.compile(r"(^|/)(api|server|backend|services|workers?|functions|lambdas?)(/|$)")
WEB_PATH = re.compile(r"(^|/)(web|frontend|client|mobile|admin-ui|dashboard|www|site)/(src|app|lib)/")
SERVER_IMPORT = re.compile(r"from\s+['\"](@nestjs/|express|fastify|koa|hono)|require\(['\"](express|fastify|koa)"
                           r"|^\s*(from|import)\s+(django|fastapi|flask)\b", re.M)
WEB_EXT = (".tsx", ".jsx", ".vue", ".svelte")
MONEY = re.compile(r"(?i)^(\w*_)?(price|amount|total|balance|cost|fee|fees|salary|revenue|commission|"
                   r"discount|tax|subtotal|credit|debit|payout|wage|refund|charge)s?(_\w*)?$|"
                   r"^[a-z]+(Price|Amount|Total|Balance|Cost|Fee|Salary|Revenue|Commission|Discount|Tax|"
                   r"Subtotal|Credit|Debit|Payout|Refund|Charge)s?$")
PRESENCE = {
    "OBS-4": ("health / readiness endpoint",
              re.compile(r"['\"`/](health|healthz|readyz|livez|readiness|liveness)\b|TerminusModule|@nestjs/terminus|"
                         r"HealthCheck|health_check", re.I)),
    "RES-5": ("graceful shutdown",
              re.compile(r"enableShutdownHooks|process\.on\(\s*['\"]SIG(TERM|INT)|onApplicationShutdown|"
                         r"beforeApplicationShutdown|signal\.signal\(\s*signal\.SIG|lightship|stoppable|"
                         r"http-terminator|graceful", re.I)),
    "RES-1": ("rate limiting",
              re.compile(r"ThrottlerModule|@Throttle\b|ThrottlerGuard|express-rate-limit|rateLimit\(|"
                         r"rate-limiter-flexible|RateLimiter|slowapi|django_ratelimit|Rack::Attack|RateLimit", re.I)),
    "SEC-05": ("config validated at boot",
               re.compile(r"validationSchema|envSchema|cleanEnv\(|envalid|pydantic_settings|BaseSettings\b|"
                          r"ConfigModule\.forRoot\(\{[\s\S]{0,400}?valid|z\.object\([\s\S]{0,400}?process\.env|"
                          r"parse\(\s*process\.env\s*\)|validateEnv|validateConfig", re.I)),
}


def strip_code(t, fn, keep_strings=False):
    """Blank out comments (and, unless keep_strings, string / template literals), keeping every
    newline so line numbers survive. A `fetch(` in a doc comment or a code-sample string is not a
    call — MEASURED on a real repo: every RES-3, OBS-5 and WEB-3 hit before this was one of those."""
    hash_lang = fn.endswith((".py", ".rb"))
    out, i, n = [], 0, len(t)
    blank = lambda s: "".join(ch if ch == "\n" else " " for ch in s)
    while i < n:
        c = t[i]
        if hash_lang and c == "#":
            j = t.find("\n", i); j = n if j == -1 else j
            out.append(blank(t[i:j])); i = j; continue
        if not hash_lang and t.startswith("//", i) and not t[max(0, i - 1)] == ":":
            j = t.find("\n", i); j = n if j == -1 else j
            out.append(blank(t[i:j])); i = j; continue
        if not hash_lang and t.startswith("/*", i):
            j = t.find("*/", i + 2); j = n if j == -1 else j + 2
            out.append(blank(t[i:j])); i = j; continue
        if hash_lang and (t.startswith('"""', i) or t.startswith("'''", i)):
            q = t[i:i + 3]; j = t.find(q, i + 3); j = n if j == -1 else j + 3
            out.append(t[i:j] if keep_strings else blank(t[i:j])); i = j; continue
        if c in "'\"`":
            j = i + 1
            while j < n and t[j] != c:
                if t[j] == "\\":
                    j += 1
                elif c != "`" and t[j] == "\n":
                    break
                j += 1
            j = min(j + 1, n)
            out.append(t[i:j] if keep_strings else c + blank(t[i + 1:j - 1]) + (t[j - 1] if j - 1 > i else ""))
            i = j; continue
        out.append(c); i += 1
    return "".join(out)


def walk(root):
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for fn in fns:
            if not fn.endswith(EXTS + WEB_EXT):
                continue
            p = os.path.join(dp, fn)
            try:
                t = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            yield os.path.relpath(p, root).replace(os.sep, "/"), fn, t


def line_of(t, pos):
    return t.count("\n", 0, pos) + 1


def other_checks(root):
    """-> list of (id, status, key, where, message)"""
    out, presence_hit, has_server = [], {}, False
    for rel, fn, t in walk(root):
        is_test = bool(TEST_PATH.search(rel))
        is_tool = bool(TOOL_PATH.search(rel))
        # a web app's own `src/api/` or `shared/api/` folder is client code, not a server
        is_client = bool(WEB_PATH.search(rel)) or bool(re.search(r"from\s+['\"](react|vue|svelte|@angular/core)['\"]", t))
        is_server = not is_test and not is_client and not fn.endswith(WEB_EXT) and (
            bool(SERVER_PATH.search(rel)) or bool(SERVER_IMPORT.search(t)))
        is_component = fn.endswith(WEB_EXT) and not is_test
        code = strip_code(t, fn)                      # no comments, no string bodies
        code_s = strip_code(t, fn, keep_strings=True)  # no comments; strings kept (class names)

        # QG-7 — a focused test silently skips every other test in the file
        if is_test:
            for m in re.finditer(r"\b(?:it|test|describe|context)\.only\s*\(|(?<![\w.])f(?:it|describe)\s*\(", code):
                out.append(("QG-7", "OPEN", rel, "%s:%d" % (rel, line_of(t, m.start())),
                            "focused test (`.only` / fit / fdescribe) — every other test here is skipped"))

        if is_server and not is_tool:
            has_server = True
            # OBS-5 — the project logger, not stdout
            logs = [m for m in re.finditer(r"\bconsole\.(log|debug|info)\s*\(", code)]
            if logs:
                out.append(("OBS-5", "OPEN", rel, "%s:%d" % (rel, line_of(t, logs[0].start())),
                            "%d console.log/debug/info call(s) in server code — use the project logger" % len(logs)))
            # RES-3 — an outbound call with no timeout anywhere in the file
            call = re.search(r"(?<![\w.$])fetch\s*\(|\baxios(?:\.create|\.(?:get|post|put|patch|delete|request))?\s*\(|"
                             r"\bgot(?:\.\w+)?\s*\(|\bky(?:\.\w+)?\s*\(|\bhttps?\.request\s*\(|\bundici\.request\s*\(|"
                             r"\brequests\.(?:get|post|put|patch|delete|request)\s*\(|\bhttpx\.(?:get|post|put|patch|delete|request|Client)\s*\(|"
                             r"\burlopen\s*\(", code)
            if call and not re.search(r"timeout|AbortSignal|signal\s*:", code_s, re.I):
                out.append(("RES-3", "OPEN", rel, "%s:%d" % (rel, line_of(t, call.start())),
                            "outbound call with no timeout in this file"))
            for pid, (_, rx) in PRESENCE.items():
                if pid not in presence_hit:
                    m = rx.search(code_s)
                    if m:
                        presence_hit[pid] = "%s:%d" % (rel, line_of(t, m.start()))
            if "SEC-05" not in presence_hit and re.search(r"(^|/)(env|config)[._-]?(schema|validation|validator|vars)?\.\w+$|"
                                                         r"(^|/)config/env[^/]*$", rel) \
                    and re.search(r"z\.object\(|Joi\.object\(|@Is[A-Z]\w*\(|BaseSettings|cleanEnv\(|t\.Object\(", code):
                presence_hit["SEC-05"] = rel

        if is_component and not re.search(r"(^|/)(hooks?|services?|api|queries|lib)(/|$)|/use[A-Z]\w*\.", rel):
            # WEB-3 — remote data through the project's client + query cache, never in a component body
            f = re.search(r"(?<![\w.$])fetch\s*\(|\baxios\.(?:get|post|put|patch|delete|request)\s*\(|\$fetch\s*\(", code)
            if f:
                out.append(("WEB-3", "OPEN", rel, "%s:%d" % (rel, line_of(t, f.start())),
                            "direct fetch/axios in a component — move it into a hook / service on the query cache"))
            # WEB-2 — colours from tokens, not literals
            if not re.search(r"(^|/)(theme|tokens?|design-system|palette|colors?)(/|\.|$)", rel, re.I):
                cols = re.findall(r"(?<=['\"\s:(\[,])#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?=['\"\s;),\]])|\brgba?\(\s*\d", code_s)
                if len(cols) >= 3:
                    out.append(("WEB-2", "OPEN", rel, rel,
                                "%d hard-coded colour literal(s) in a component — use design tokens" % len(cols)))

        # DATA-9 — money is DECIMAL or integer minor units, never float
        for m in re.finditer(r"@(?:Property|Column)\s*\(\s*\{[^}]*type\s*:\s*['\"](float|double|real)['\"][^}]*\}\s*\)\s*"
                             r"(?:@\w+\([^)]*\)\s*)*(\w+)[!?]?\s*[:=]", t):
            if MONEY.search(m.group(2)):
                out.append(("DATA-9", "OPEN", "%s.%s" % (rel, m.group(2)), "%s:%d" % (rel, line_of(t, m.start(2))),
                            "money column `%s` typed %s" % (m.group(2), m.group(1))))
        for m in re.finditer(r"(?m)^\s*(\w+)\s+Float\b", t) if fn.endswith(".prisma") else ():
            if MONEY.search(m.group(1)):
                out.append(("DATA-9", "OPEN", "%s.%s" % (rel, m.group(1)), "%s:%d" % (rel, line_of(t, m.start(1))),
                            "money field `%s` typed Float" % m.group(1)))
        for m in re.finditer(r"(\w+)\s*=\s*models\.FloatField\(", t) if fn.endswith(".py") else ():
            if MONEY.search(m.group(1)):
                out.append(("DATA-9", "OPEN", "%s.%s" % (rel, m.group(1)), "%s:%d" % (rel, line_of(t, m.start(1))),
                            "money field `%s` is a FloatField" % m.group(1)))
        if fn.endswith(".sql") or "addSql" in t or "queryRunner.query" in t:
            for m in re.finditer(r"[\"`]?(\w+)[\"`]?\s+(float|double precision|double|real)\b", t, re.I):
                if MONEY.search(m.group(1)):
                    out.append(("DATA-9", "OPEN", "%s.%s" % (rel, m.group(1)), "%s:%d" % (rel, line_of(t, m.start(1))),
                                "money column `%s` typed %s" % (m.group(1), m.group(2))))

    if has_server:
        for pid, (what, _) in PRESENCE.items():
            if pid in presence_hit:
                out.append((pid, "MET", "project", presence_hit[pid], what))
            else:
                out.append((pid, "OPEN", "project", "-", "no %s found anywhere in server code" % what))
    # QG-13 — CI blocks on tests + lint (+ typecheck where the stack has one)
    ci = []
    for d in (".github/workflows",):
        dd = os.path.join(root, d)
        if os.path.isdir(dd):
            ci += [os.path.join(dd, f) for f in os.listdir(dd) if f.endswith((".yml", ".yaml"))]
    for f in (".gitlab-ci.yml", "bitbucket-pipelines.yml", ".circleci/config.yml", "azure-pipelines.yml"):
        if os.path.isfile(os.path.join(root, f)):
            ci.append(os.path.join(root, f))
    body = "\n".join(open(f, encoding="utf-8", errors="replace").read() for f in ci)
    need = [(k, rx) for k, rx in (("tests", r"\btest\b|jest|vitest|pytest|go test|rspec|phpunit"),
                                  ("lint", r"\blint\b|eslint|ruff|flake8|golangci|rubocop|phpcs"),
                                  ("typecheck", r"typecheck|tsc\b|mypy|pyright"))]
    missing = [k for k, rx in need if not re.search(rx, body, re.I)]
    if not ci:
        out.append(("QG-13", "OPEN", "project", "-", "no CI workflow — nothing blocks a merge"))
    elif missing:
        out.append(("QG-13", "OPEN", "project", os.path.relpath(ci[0], root),
                    "CI runs but never " + ", ".join(missing)))
    else:
        out.append(("QG-13", "MET", "project", os.path.relpath(ci[0], root), "CI runs tests, lint and typecheck"))
    return out


def load_allow(root):
    """`.claude/standards-check.allow`:  <ID> <key> — reason   (key: table.column, a path, or `project`)"""
    p = os.path.join(root, ".claude", "standards-check.allow")
    allow = {}
    if os.path.isfile(p):
        for line in open(p, encoding="utf-8", errors="replace"):
            m = re.match(r"\s*([A-Z]+-\d+)\s+(\S+)\s*(?:[—-]+\s*(.*))?$", line.rstrip())
            if m:
                allow[(m.group(1), m.group(2))] = (m.group(3) or "").strip()
    return allow


def natural_key_findings(root):
    scan = Scan(root)
    scan.run()
    out, seen = [], set()
    for table, col, path, line in sorted(scan.columns):
        key = (table, norm(col))
        if key in seen:
            continue
        seen.add(key)
        if SKIP_TABLE.search(table) or table.startswith("order_"):
            continue
        name = "%s.%s" % (table, snake(col))
        where = "%s:%d" % (path, line)
        if covered(scan, table, col):
            out.append(("DATA-1", "MET", name, where, "unique"))
        else:
            out.append(("DATA-1", "OPEN", name, where,
                        "no unique constraint on the entity, in a composite key, or in any migration"))
    return out


CHECKS = {
    "DATA-1": "natural keys unique in the database", "DATA-9": "money is never float",
    "QG-7": "no focused tests", "QG-13": "CI blocks on tests + lint + typecheck",
    "RES-3": "outbound calls carry a timeout", "OBS-5": "server code logs through the logger",
    "WEB-3": "no fetch in a component body", "WEB-2": "colours come from tokens",
    "OBS-4": "health / readiness endpoint", "RES-5": "graceful shutdown",
    "RES-1": "rate limiting", "SEC-05": "config validated at boot",
}


def changed_files(root, ref):
    """Files this change touched: committed since <ref>, staged, unstaged, and untracked."""
    import subprocess
    def git(*a):
        r = subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(r.stderr.strip() or "git %s failed" % " ".join(a))
        return [l for l in r.stdout.splitlines() if l.strip()]
    return set(git("diff", "--name-only", ref)) | set(git("ls-files", "--others", "--exclude-standard"))


def scope_to_change(rows, root, files):
    """Keep the per-file rows whose file this change touched. A DATA-1 row also stays when a changed
    file names its table (a migration altering it). Project-level rows leave: they are the
    `Project baseline:` line, not this change's ledger."""
    texts = []
    for f in files:
        p = os.path.join(root, f)
        if f.endswith(EXTS + WEB_EXT) and os.path.isfile(p):
            texts.append(open(p, encoding="utf-8", errors="replace").read())
    kept = []
    for r in rows:
        if r[2] == "project":
            continue
        path = r[3].split(":", 1)[0]
        if path in files:
            kept.append(r)
        elif r[0] == "DATA-1":
            table = r[2].split(".", 1)[0]
            if any(re.search(r"[\"'`]%s[\"'`]" % re.escape(table), t) for t in texts):
                kept.append(r)
    return kept


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    quiet = "--quiet" in argv
    only = next((a.split("=", 1)[1].split(",") for a in argv if a.startswith("--check=")), None)
    ref = next((a.split("=", 1)[1] for a in argv if a.startswith("--changed=")), None)
    if len(args) != 1 or not os.path.isdir(args[0]):
        print("usage: standards-check.py <target-repo> [--changed=<git-ref>] [--check=ID[,ID]] [--quiet]",
              file=sys.stderr)
        return 2
    root = os.path.abspath(args[0])
    allow = load_allow(root)
    rows = natural_key_findings(root) + other_checks(root)
    if only:
        rows = [r for r in rows if r[0] in only]
    scope = ""
    if ref:
        try:
            files = changed_files(root, ref)
        except RuntimeError as e:
            print("standards-check: --changed=%s: %s" % (ref, e), file=sys.stderr)
            return 2
        rows = scope_to_change(rows, root, files)
        scope = " — scoped to %d file(s) changed since %s" % (len(files), ref)

    print("standards-check — %s%s" % (root, scope))
    open_n = 0
    for cid in CHECKS:
        rs = [r for r in rows if r[0] == cid]
        if not rs:
            if (only is None or cid in only) and not ref:
                print("\n[%s] %s — clean (ran, nothing found)" % (cid, CHECKS[cid]))
            continue
        o = [r for r in rs if r[1] == "OPEN" and (cid, r[2]) not in allow]
        a = [r for r in rs if r[1] == "OPEN" and (cid, r[2]) in allow]
        met = [r for r in rs if r[1] == "MET"]
        open_n += len(o)
        print("\n[%s] %s — %d OPEN · %d MET · %d allowed" % (cid, CHECKS[cid], len(o), len(met), len(a)))
        for r in o:
            print("  OPEN     %-44s %s — %s" % (r[2], r[3], r[4]))
        for r in a:
            print("  ALLOWED  %-44s %s — %s" % (r[2], r[3], allow[(cid, r[2])] or "(no reason given)"))
        if not quiet:
            for r in met:
                print("  MET      %-44s %s" % (r[2], r[3]))
    print("\nsummary: %d OPEN finding(s) across %d check(s)" % (open_n, len(CHECKS)))
    if open_n:
        print("close each OPEN row in code, or record why it does not apply in .claude/standards-check.allow"
              " as `<ID> <key> — reason`")
    return 1 if open_n else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
