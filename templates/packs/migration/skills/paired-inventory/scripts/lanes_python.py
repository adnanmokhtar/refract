"""lanes_python.py — Django and FastAPI lanes for pair-inventory.py.

Every lane in this module is `partial`: no paired fixture calibrates these stacks yet, so each candidate they
produce is tagged `partial`. Reads are static (rg listing through the core's H, masked text); nothing is imported
or executed. Shared readers, the k8s CronJob reader and the I-MONEY lane come from lanes_common.py (loaded by path).

What each stack reads
  django   the ROOT_URLCONF tree (path/re_path/include, DRF routers with ViewSet actions and @action);
           permission_classes + REST_FRAMEWORK defaults, login_required/permission_required/LoginRequiredMixin,
           LoginRequiredMiddleware; TextChoices/IntegerChoices/Enum; DRF exception defaults and APIException
           subclasses; post_save/post_delete receivers, HistoricalRecords; Celery beat, APScheduler; default
           managers / safedelete; TIME_ZONE, LANGUAGE_CODE, PAGE_SIZE. An undecorated function view is one `ANY` row.
  fastapi  APIRouter/FastAPI prefixes, include_router (prefix, dependencies); path-param types; Depends/Security
           (scopes) -> I-AUTHZ; Pydantic body models -> I-RULES; Enum; exception_handler; handler-body effects;
           Celery beat / APScheduler; TZ from Dockerfile / .env. api_route with no methods= is GET (FastAPI's default).
  both: k8s CronJobs (I-SCHED), rounding on money paths (I-MONEY).
What it cannot see: routes built dynamically or through helpers in another file, inherited permission_classes
beyond project base classes, effects one call away from a view or receiver, Django validation (I-RULES is a gap
for django), ORM scopes for FastAPI, DDL (I-SCHEMA is a gap). What cannot be read is '?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading lanes_common must not drop __pycache__ into a repo
_spec = importlib.util.spec_from_file_location('lanes_common', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lanes_common.py'))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

SCHED_DROP, TENANT, _R, _args, _blocks, _constraint, _dirs, _errkey = C.SCHED_DROP, C.TENANT, C._R, C._args, C._blocks, C._constraint, C._dirs, C._errkey
_funcs, _guard, _k8s, _kinds, _kw, _lit, _lits, _merged, _pydep = C._funcs, C._guard, C._k8s, C._kinds, C._kw, C._lit, C._lits, C._merged, C._pydep
_route_side, _row, _src, _status, _t, env_conf = C._route_side, C._row, C._src, C._status, C._t, C.env_conf


def _decos(c, s):
    """The decorator/annotation lines directly above index s (a line start)."""
    a = s
    while a > 0:
        ls = c.rfind('\n', 0, a - 1) + 1
        st = c[ls:a - 1].strip()
        if not st or not (st.startswith('@') or st[0] in ')]}"\'' or st.endswith((',', '(', '['))):
            break
        a = ls
    return c[a:s]


# ---------------------------------------------------------------- python: shared
def _py(h, ctx):
    if 'pyfiles' not in ctx:
        ctx['pyfiles'] = _src(h, ctx, ['*.py'])
    return ctx['pyfiles']


def _pyindex(h, ctx):
    """{name: (rel, block)} for every class/def in the stack's .py files (first wins)."""
    if 'pyix' not in ctx:
        ix = {}
        for rel in _py(h, ctx):
            for b in _blocks(h, rel, 'py'):
                ix.setdefault(b[1], (rel, b))
        ctx['pyix'] = ix
    return ctx['pyix']


def _bases(h, rel, b):
    c = _t(h, rel, 'py')[2]
    x = re.match(r'class\s+\w+\s*\(([^)]*)\)', c[b[2]:b[3]])
    return [n.split('.')[-1] for n in re.findall(r'[\w.]+', x.group(1))] if x else []


def _methods(h, rel, cls):
    return dict((b[1], b) for b in _blocks(h, rel, 'py') if b[0] == 'def' and b[6] == cls)


def _py_enums(h, ctx):
    if 'pyenum' in ctx:
        return ctx['pyenum']
    out = {}
    for rel in _py(h, ctx):
        t, m, c = _t(h, rel, 'py')
        if not re.search(r'Enum|Choices', m):
            continue
        for b in _blocks(h, rel, 'py'):
            bs = _bases(h, rel, b) if b[0] == 'class' else []
            if not set(bs) & {'Enum', 'IntEnum', 'StrEnum', 'IntFlag', 'TextChoices', 'IntegerChoices', 'Choices'}:
                continue
            names, vals = [], []
            for x in re.finditer(r'^[ \t]+([A-Z][A-Z0-9_]*)[ \t]*=[ \t]*([^\n]+)', m[b[3]:b[4]], re.M):
                v = c[b[3] + x.start(2):b[3] + x.end(2)].strip()
                lv = re.match(r'[rbu]?(["\'])(.*?)\1', v)
                nv = re.match(r'-?\d+(?:\.\d+)?\b', v)
                auto = 'auto()' in v and 'StrEnum' in bs
                names.append(x.group(1))
                vals.append(lv.group(2) if lv else nv.group(0) if nv else x.group(1).lower() if auto else '?')
            name = b[1] if not b[6] or b[1].startswith(b[6]) else b[6] + b[1]
            out[b[1]] = (name, names, vals, rel, b[2])
    ctx['pyenum'] = out
    return out


def py_enum(root, h, ctx):
    return [_row(h, 'type:' + h.ident(n, strip=('enum', 'choices', 'type', 'schema')),
                 {'values': '?' if '?' in v else ','.join(sorted(set(v))), 'names': ','.join(ns)}, rel, i)
            for n, ns, v, rel, i in _py_enums(h, ctx).values()]


def _py_exc_classes(h, ctx, out):
    for name, (rel, b) in _pyindex(h, ctx).items():
        if b[0] == 'class' and any(re.search(r'Exception|Error', x) for x in _bases(h, rel, b)):
            st = _status(_t(h, rel, 'py')[2][b[3]:b[4]])
            if st:
                out.setdefault(_errkey(h, name), _row(h, _errkey(h, name), {'status': ','.join(sorted(st)), 'envelope': name}, rel, b[2]))


def py_err(root, h, ctx):
    out = {}
    for rel in _py(h, ctx):
        t, m, c = _t(h, rel, 'py')
        for x in re.finditer(r'@\w+\.exception_handler\(\s*([\w.]+)\s*\)|\badd_exception_handler\(\s*([\w.]+)\s*,\s*(\w+)', m):
            if x.group(1):
                d = re.compile(r'def\s+(\w+)').search(m, x.end())
                body = [f for f in _funcs(h, rel, 'py') if d and f[1] <= d.start() + 6 and f[3] > d.start()]
            else:
                body = [f for f in _funcs(h, rel, 'py') if f[0] == x.group(3)]
            st = _status(c[body[0][2]:body[0][3]]) if body else set()
            k = _errkey(h, x.group(1) or x.group(2))
            out[k] = _row(h, k, {'status': ','.join(sorted(st)) or '?', 'envelope': 'handler'}, rel, x.start())
    _py_exc_classes(h, ctx, out)
    if ctx['stack'] == 'fastapi':
        out.setdefault('validation', {'key': 'validation', 'attrs': {'status': '422', 'envelope': 'FastAPI default {"detail": [...]}'},
                                      'at': '-', 'excerpt': 'RequestValidationError (framework default)'})
    else:
        S = _dj_settings(h, ctx)
        rf = S.get('REST_FRAMEWORK', ('', 0, ''))[2]
        custom = re.search(r'["\']EXCEPTION_HANDLER["\']\s*:', rf)
        drf = 'rest_framework' in S.get('INSTALLED_APPS', ('', 0, ''))[2]
        q = lambda v: '?' if custom else v
        dft = [('not_found', '404', 'Http404 / NotFound')]
        if drf:
            dft += [('validation', q('400'), 'DRF ValidationError'), ('forbidden', q('403'), 'DRF PermissionDenied'),
                    ('unauthenticated', q(_drf_unauth(h, ctx, rf)), 'DRF NotAuthenticated')]
        for k, v, env in dft:
            out.setdefault(k, {'key': k, 'attrs': {'status': v, 'envelope': env}, 'at': '-', 'excerpt': env + ' (framework default)'})
        if custom:
            ctx.setdefault('notes', []).append('django: custom EXCEPTION_HANDLER — DRF default statuses read as ?')
    return list(out.values())


def _pymodel_fields(h, ctx, models, name, pre, depth, out):
    if depth > 3 or name not in models:
        return
    rel, b = models[name]
    for base in _bases(h, rel, b):
        _pymodel_fields(h, ctx, models, base, pre, depth + 1, out)
    t, m, c = _t(h, rel, 'py')
    enums = _py_enums(h, ctx)
    for x in re.finditer(r'^([ \t]+)(\w+)[ \t]*:', m[b[3]:b[4]], re.M):
        s = b[3] + x.end()
        if len(x.group(1)) <= b[5] or x.group(2) in ('model_config', 'Config'):
            continue
        j, d = s, 0
        while j < len(m) and not (d == 0 and m[j] in '=\n'):
            d += m[j] in '([{'
            d -= m[j] in ')]}'
            j += 1
        ann, dflt = c[s:j].strip(), None
        if j < len(m) and m[j] == '=':
            k, d = j + 1, 0
            while k < len(m) and not (d == 0 and m[k] == '\n'):
                d += m[k] in '([{'
                d -= m[k] in ')]}'
                k += 1
            dflt = c[j + 1:k].strip()
        ids = [i.split('.')[-1] for i in re.findall(r'[A-Za-z_][\w.]*', ann)
               if i.split('.')[-1] not in ('Annotated', 'Optional', 'Union', 'None', 'Field', 'typing')]
        base = ids[0] if ids else '?'
        null = bool(re.search(r'\bOptional\[|\|\s*None\b|\bNone\s*\|', ann))
        spec = ann + ' ' + (dflt or '')
        fld = re.search(r'\bField\(([^\n]*)', dflt or '')
        if dflt is None or dflt == '...' or (fld and re.match(r'\s*(?:\.\.\.|\)|[a-z_]+\s*=)', fld.group(1))
                                            and not re.search(r'\bdefault(?:_factory)?\s*=', fld.group(1))):
            pres = 'required' if (not null or dflt is not None or ctx.get('pyd') == '2') else ('optional' if ctx.get('pyd') == '1' else '?')
        else:
            pres = 'optional'
        kw = lambda n: re.search(r'\b%s\s*=\s*(-?[\d.]+)' % n, spec)
        mx, mn = kw('max_length') or kw('max_items') or kw('le'), kw('min_length') or kw('min_items') or kw('ge')
        rx = re.search(r'\b(?:pattern|regex)\s*=\s*r?["\']([^"\']*)', spec)
        ins = _lits(re.search(r'Literal\[([^\]]*)\]', ann).group(1)) if 'Literal[' in ann else enums.get(base, (0, 0, []))[2]
        typ = 'object' if base in models else ('string' if base in enums else PYTYPE.get(base, '?'))
        a = {'presence': pres, 'nullable': 'yes' if null else 'no', 'type': typ, 'format': FMT.get(base, ''),
             'max': mx.group(1) if mx else ('?' if kw('lt') else ''), 'min': mn.group(1) if mn else ('?' if kw('gt') else ''),
             'in': ','.join(sorted(set(ins))), 'regex': rx.group(1) if rx else ''}
        out.append((pre + x.group(2), a))
        if base in models:
            _pymodel_fields(h, ctx, models, base, pre + x.group(2) + '.', depth + 1, out)
        elif typ == 'array' and len(ids) > 1 and ids[1] in models:
            _pymodel_fields(h, ctx, models, ids[1], pre + x.group(2) + '.*.', depth + 1, out)


PYTYPE = dict([(k, 'string') for k in ('str', 'EmailStr', 'UUID', 'UUID4', 'HttpUrl', 'AnyUrl', 'AnyHttpUrl', 'constr', 'Literal',
                                       'StrictStr', 'SecretStr')] + [(k, 'int') for k in ('int', 'conint', 'StrictInt', 'PositiveInt')]
              + [(k, 'number') for k in ('float', 'Decimal', 'confloat', 'condecimal')] + [('bool', 'bool'), ('StrictBool', 'bool')]
              + [(k, 'array') for k in ('list', 'List', 'set', 'Set', 'tuple', 'Tuple', 'Sequence', 'conlist')]
              + [(k, 'object') for k in ('dict', 'Dict')] + [(k, 'date') for k in ('date', 'datetime')] + [('UploadFile', 'file')])
FMT = {'EmailStr': 'email', 'UUID': 'uuid', 'UUID4': 'uuid', 'HttpUrl': 'url', 'AnyUrl': 'url', 'AnyHttpUrl': 'url'}


# ---------------------------------------------------------------- fastapi
def _scan_fastapi(h, ctx):
    routers, incs, raw, imports, models = {}, [], [], {}, {}
    files = _py(h, ctx)
    for rel in files:
        t, m, c = _t(h, rel, 'py')
        if 'pydantic' in m or 'BaseModel' in m:
            for b in _blocks(h, rel, 'py'):
                if b[0] == 'class':
                    models[b[1]] = (rel, b)
        if not re.search(r'APIRouter|FastAPI|include_router', m):
            continue
        im = imports.setdefault(rel, {})
        for x in re.finditer(r'^from\s+([.\w]+)\s+import\s+(\([^)]*\)|[^\n]+)', c, re.M):
            for y in re.finditer(r'(\w+)(?:\s+as\s+(\w+))?', x.group(2)):
                im[y.group(2) or y.group(1)] = (x.group(1), y.group(1))
        for x in re.finditer(r'^(\w+)\s*(?::[^=\n]+)?=\s*(?:fastapi\.)?(APIRouter|FastAPI)\(', m, re.M):
            sp = _args(h, m, x.end() - 1)
            routers[(rel, x.group(1))] = (_lit(_kw(c, m, sp, 'prefix')) or '', _kw(c, m, sp, 'dependencies') or '')
        for x in re.finditer(r'^[ \t]*(\w+)\.include_router\(', m, re.M):
            sp = _args(h, m, x.end() - 1)
            if sp:
                incs.append(((rel, x.group(1)), rel, c[sp[0][0]:sp[0][1]].strip(), _lit(_kw(c, m, sp, 'prefix')) or '',
                             _kw(c, m, sp, 'dependencies') or ''))
        for x in re.finditer(r'^[ \t]*@(\w+)\.(get|post|put|patch|delete|options|head|api_route)\(', m, re.M):
            raw.append((rel, x))
    pd = [_pydep(h.read(f), 'pydantic') for f in h.files([(d + '/' if d else '') + '**/' + g for d in _dirs(h, ctx)
                                                       for g in ('requirements*.txt', 'pyproject.toml', 'poetry.lock')])]
    ctx['pyd'] = next((v[0] for v in pd if v), '')

    def resolve(rel, expr):
        head, _, var = expr.rpartition('.')
        mod = None
        if head:
            mod = '.'.join(x for x in imports.get(rel, {}).get(head, ('', head)) if x)
        elif expr in imports.get(rel, {}):
            mod, var = imports[rel][expr]
        else:
            return (rel, expr)
        tail = mod.strip('.').replace('.', '/')
        for (r, v) in routers:
            p = r[:-12] if r.endswith('/__init__.py') else r[:-3]
            if v == var and (p == tail or p.endswith('/' + tail) or tail.endswith('/' + os.path.basename(p))):
                return (r, v)
        return None

    parents = {}
    for parent, rel, expr, pre, deps in incs:
        k = resolve(rel, expr)
        if k:
            parents.setdefault(k, []).append((parent, pre, deps))

    def chain(k, seen=()):
        own = routers.get(k, ('', ''))
        if k not in parents or k in seen:
            return [(own[0], own[1])]
        return [(pp + pre + own[0], pd2 + deps + own[1]) for parent, pre, deps in parents[k]
                for pp, pd2 in chain(parent, seen + (k,))]
    mw_auth = any(re.search(r'add_middleware\(\s*\w*(?:Auth|Session|JWT)', _t(h, f, 'py')[1]) for f in files)
    out = []
    for rel, x in raw:
        t, m, c = _t(h, rel, 'py')
        sp = _args(h, m, x.end() - 1)
        path = (_lit(c[sp[0][0]:sp[0][1]]) if sp and not re.match(r'\s*\w+\s*=', m[sp[0][0]:sp[0][1]]) else None)
        path = path if path is not None else (_lit(_kw(c, m, sp, 'path')) or '')
        verb = x.group(2)
        meths = [l.upper() for l in _lits(_kw(c, m, sp, 'methods') or '')] or ['GET'] if verb == 'api_route' else [verb.upper()]
        d = re.compile(r'(?:async[ \t]+)?def[ \t]+(\w+)[ \t]*\(').search(m, h.close(m, x.end() - 1))
        if not d:
            h.unparse('I-ROUTES', rel, t, x.start(), 'decorator without def')
            continue
        fb = [f for f in _funcs(h, rel, 'py') if f[0] == d.group(1) and f[1] <= d.start() <= f[2]]
        pnames = re.findall(r'\{(\w+)', path)
        types, deps, model = {}, [], None
        for s, e in _args(h, m, d.end() - 1):
            p = c[s:e].strip()
            y = re.match(r'(\w+)\s*(?::\s*([^=]+))?(?:=\s*(.*))?$', p, re.S)
            if not y:
                continue
            ann, dflt = (y.group(2) or '').strip(), (y.group(3) or '').strip()
            if y.group(1) in pnames:
                types[y.group(1)] = 'int' if re.search(r'\bint\b', ann) else 'uuid' if 'UUID' in ann else 're' if re.search(r'pattern|regex', dflt) else ''
            for z in re.finditer(r'\b(Depends|Security)\(\s*([\w.]*)', dflt + ' ' + ann):
                a = (dflt + ' ' + ann).find('(', z.end() - 1)
                inner = (dflt + ' ' + ann)[z.end():] if a < 0 else (dflt + ' ' + ann)[z.end():z.end() + 200]
                sc = re.search(r'scopes\s*=\s*\[([^\]]*)\]', inner)
                nm = z.group(2) or (re.findall(r'\w+', ann) or ['?'])[0]
                deps.append((nm + (' Security' if z.group(1) == 'Security' else ''), _lits(sc.group(1)) if sc else _lits(inner.split(')')[0]), False))
            ids = [i for i in re.findall(r'\w+', ann) if i not in ('Annotated', 'Optional', 'List', 'list', 'None', 'Body')]
            if not deps or 'Depends' not in dflt + ann:
                if ids and ids[0] in models and y.group(1) not in pnames:
                    model = ids[0]
        rdeps = _kw(c, m, sp, 'dependencies') or ''
        for pre, cdeps in chain((rel, x.group(1))):
            gd = []
            for z in re.finditer(r'\b(Depends|Security)\(\s*([\w.]+)([^)]*)', cdeps + ' ' + rdeps):
                sc = re.search(r'scopes\s*=\s*\[([^\]]*)', z.group(3))
                gd.append((z.group(2) + (' Security' if z.group(1) == 'Security' else ''), _lits(sc.group(1) if sc else z.group(3)), True))
            az = _guard(h, gd + deps, known_none=not mw_auth)
            rules = []
            if model:
                _pymodel_fields(h, ctx, models, model, '', 0, rules)
            for meth in meths:
                out.append(_R(meth, pre + path, rel, x.start(), handler=d.group(1), con=_constraint(path, types), az=az,
                              body=(rel, 'py', fb[0][2], fb[0][3]) if fb else None, rules=rules))
    return out


# ---------------------------------------------------------------- django
def _dj_settings(h, ctx):
    if 'djs' in ctx:
        return ctx['djs']
    S = {}
    for rel in _py(h, ctx):
        if not re.search(r'(^|/)settings(/|\w*\.py$)', rel):
            continue
        t, m, c = _t(h, rel, 'py')
        for x in re.finditer(r'^([A-Z][A-Z0-9_]+)\s*=\s*', m, re.M):
            j = x.end()
            e = h.close(m, j) + 1 if m[j:j + 1] in '[({' else (m.find('\n', j) if m.find('\n', j) >= 0 else len(m))
            S.setdefault(x.group(1), (rel, x.start(), c[j:e]))
    ctx['djs'] = S
    return S


def _drf_unauth(h, ctx, rf):
    x = re.search(r'["\']DEFAULT_AUTHENTICATION_CLASSES["\']\s*:\s*[\[(]\s*["\']([\w.]+)', rf)
    first = x.group(1).split('.')[-1] if x else 'SessionAuthentication'
    if first == 'SessionAuthentication':
        return '403'
    if re.match(r'(Basic|Token|JWT|JSONWebToken|OAuth2?|Knox)', first):
        return '401'
    ix = _pyindex(h, ctx).get(first)
    if not ix:
        return '?'
    return '401' if 'authenticate_header' in _methods(h, ix[0], first) else '403'


GENERIC = {'ListAPIView': 'G', 'CreateAPIView': 'P', 'RetrieveAPIView': 'G', 'DestroyAPIView': 'D', 'UpdateAPIView': 'UA',
           'ListCreateAPIView': 'GP', 'RetrieveUpdateAPIView': 'GUA', 'RetrieveDestroyAPIView': 'GD',
           'RetrieveUpdateDestroyAPIView': 'GUAD', 'ListView': 'G', 'DetailView': 'G', 'TemplateView': 'G',
           'CreateView': 'GP', 'UpdateView': 'GP', 'DeleteView': 'GP', 'FormView': 'GP'}
VSB = {'ModelViewSet': ('list', 'create', 'retrieve', 'update', 'partial_update', 'destroy'), 'ReadOnlyModelViewSet': ('list', 'retrieve'),
       'ListModelMixin': ('list',), 'CreateModelMixin': ('create',), 'RetrieveModelMixin': ('retrieve',),
       'UpdateModelMixin': ('update', 'partial_update'), 'DestroyModelMixin': ('destroy',)}
VSACT = {'list': ('GET', 0), 'create': ('POST', 0), 'retrieve': ('GET', 1), 'update': ('PUT', 1), 'partial_update': ('PATCH', 1),
         'destroy': ('DELETE', 1)}
DRFP = {'IsAuthenticated': ('required', ''), 'AllowAny': ('none', ''), 'IsAdminUser': ('required', 'staff'),
        'DjangoModelPermissions': ('required', '?'), 'DjangoObjectPermissions': ('required', '?')}


def _dj_view(h, ctx, name, depth=0):
    """(rel, block, kind 'class'|'def', methods {VERB: body block}, bases, decorators text) or None."""
    ix = _pyindex(h, ctx).get(name)
    if not ix:
        return None
    rel, b = ix
    c = _t(h, rel, 'py')[2]
    if b[0] == 'def':
        return rel, b, 'def', {}, [], _decos(c, c.rfind('\n', 0, b[2]) + 1)
    bases, meths = _bases(h, rel, b), {}
    for n, mb in _methods(h, rel, b[1]).items():
        if n in ('get', 'post', 'put', 'patch', 'delete', 'options', 'head') or n in VSACT:
            meths[n] = mb
    for base in bases:
        for L in GENERIC.get(base, ''):
            meths.setdefault({'G': 'get', 'P': 'post', 'U': 'put', 'A': 'patch', 'D': 'delete'}[L], None)
        for act in VSB.get(base, ()):
            meths.setdefault(act, None)
        sub = _dj_view(h, ctx, base, depth + 1) if depth < 3 and base not in GENERIC and base not in VSB else None
        if sub and sub[2] == 'class':
            for k, v in sub[3].items():
                meths.setdefault(k, v)
            bases = bases + sub[4]
    return rel, b, 'class', meths, bases, _decos(c, c.rfind('\n', 0, b[2]) + 1)


def _dj_authz(h, ctx, v, meth):
    S = _dj_settings(h, ctx)
    rel, b, kind, meths, bases, decos = v
    c = _t(h, rel, 'py')[2]
    body = c[b[3]:b[4]] if kind == 'class' else ''
    drf = kind == 'def' and '@api_view' in decos or any(re.search(r'APIView|ViewSet|Mixin$', x) for x in bases)
    pc = re.search(r'^\s+permission_classes\s*=\s*[\[(]([^\])]*)', body, re.M) or re.search(r'@permission_classes\(\s*[\[(]([^\])]*)', decos)
    if kind == 'class' and not pc:
        for base in bases:
            bv = _pyindex(h, ctx).get(base)
            if bv:
                pc = re.search(r'^\s+permission_classes\s*=\s*[\[(]([^\])]*)', _t(h, bv[0], 'py')[2][bv[1][3]:bv[1][4]], re.M) or pc
    names, src = [], ''
    if drf:
        dp = re.search(r'["\']DEFAULT_PERMISSION_CLASSES["\']\s*:\s*[\[(]([^\])]*)', S.get('REST_FRAMEWORK', ('', 0, ''))[2])
        src = pc.group(1) if pc else dp.group(1) if dp else 'AllowAny'
        names = [n.split('.')[-1] for n in re.findall(r'[\w.]+', src)] or ['AllowAny']
        authn, roles, ab, extra = 'none', set(), set(), False
        for n in names:
            if n == 'IsAuthenticatedOrReadOnly':
                authn = authn if meth in ('GET', 'HEAD', 'OPTIONS') else 'required'
            elif n in DRFP:
                authn = 'required' if DRFP[n][0] == 'required' else authn
                roles |= set([DRFP[n][1]]) if DRFP[n][1] == 'staff' else set()
                ab |= set(['?']) if DRFP[n][1] == '?' else set()
            else:
                extra = True
                authn = 'required' if authn == 'required' else '?'
        if '|' in src:
            authn = '?'
        return {'authn': authn, 'roles': ','.join(sorted(roles)), 'abilities': '?' if '?' in ab else '',
                'extra_guard': 'yes' if extra else 'no', 'mw': ','.join(names)}
    lrm = 'LoginRequiredMiddleware' in S.get('MIDDLEWARE', ('', 0, ''))[2] and '@login_not_required' not in decos
    perms = _lits(' '.join(re.findall(r'@permission_required\(([^)]*)\)', decos)))
    perms += _lits(' '.join(re.findall(r'^\s+permission_required\s*=\s*([^\n]+)', body, re.M))) if 'PermissionRequiredMixin' in bases else []
    req = lrm or '@login_required' in decos or 'LoginRequiredMixin' in bases or bool(perms) or '@staff_member_required' in decos
    extra = '@user_passes_test' in decos or 'UserPassesTestMixin' in bases
    return {'authn': 'required' if req else 'none', 'roles': 'staff' if '@staff_member_required' in decos else '',
            'abilities': ','.join(sorted(set(h.ability(p) for p in perms))), 'extra_guard': 'yes' if extra else 'no',
            'mw': ','.join(re.findall(r'@(\w+)', decos))}


def _scan_django(h, ctx):
    files, S, out = _py(h, ctx), _dj_settings(h, ctx), []

    def modrel(dotted):
        tail = (dotted or '').strip('.').replace('.', '/')
        for f in files:
            if f[:-3] == tail or f[:-3].endswith('/' + tail) or f.endswith(tail + '/__init__.py'):
                return f
        return None

    def view(raw, expr, rel, i, extra_meths=None):
        name = re.sub(r'\.as_view\(.*$', '', expr, flags=re.S).strip().split('.')[-1]
        v = _dj_view(h, ctx, name)
        if not v:
            h.unparse('I-ROUTES', rel, h.read(rel), i, 'view %s not found' % name)
            return
        vrel, b, kind, meths, bases, decos = v
        if kind == 'def':
            rm = re.search(r'@require_http_methods\(\s*\[([^\]]*)\]', decos)
            av = re.search(r'@api_view(?:\(\s*\[([^\]]*)\])?', decos)
            ms = ([l.upper() for l in _lits(rm.group(1))] if rm else ['POST'] if '@require_POST' in decos else ['GET'] if
                  re.search(r'@require_(?:GET|safe)\b', decos) else ([l.upper() for l in _lits(av.group(1) or '')] or ['GET']) if av else ['ANY'])
            pairs = [(mm, (b[3], b[4])) for mm in ms]
        else:
            pairs = [(VSACT[k][0] if k in VSACT else k.upper(), (mb[3], mb[4]) if mb else None) for k, mb in sorted(meths.items())
                     if ((k in VSACT and VSACT[k][1] == extra_meths) if extra_meths is not None else k not in VSACT)]
        for mm, bb in pairs:
            out.append(_R(mm, raw, rel, i, handler=re.sub(r'\.as_view\b.*', '', expr, flags=re.S).strip(), con=_constraint(raw), az=_dj_authz(h, ctx, v, mm),
                          body=(vrel, 'py', bb[0], bb[1]) if bb else None))

    def router(raw, regs, rel, i, default):
        if default:
            root = (rel, ['class', 'APIRootView', 0, 0, 0, 0, None], 'class', {}, ['APIView'], '')
            out.append(_R('GET', raw, rel, i, handler='DefaultRouter.api_root', az=_dj_authz(h, ctx, root, 'GET')))
        for p, vs, j in regs:
            v = _dj_view(h, ctx, vs.split('.')[-1])
            if not v:
                h.unparse('I-ROUTES', rel, h.read(rel), j, 'viewset %s not found' % vs)
                continue
            lv = re.search(r'lookup_value_regex\s*=\s*r?["\']([^"\']+)', _t(h, v[0], 'py')[2][v[1][3]:v[1][4]])
            for det, suf in ((0, '/'), (1, '/(?P<pk>%s)/' % (lv.group(1) if lv else '[^/.]+'))):
                view(raw + p + suf, vs, rel, j, extra_meths=det)
            for x in re.finditer(r'@action\(([^)]*)\)\s*\n\s*def\s+(\w+)', _t(h, v[0], 'py')[2][v[1][3]:v[1][4]]):
                up = re.search(r'url_path\s*=\s*r?["\']([^"\']+)', x.group(1))
                det = '/{pk}/' if re.search(r'detail\s*=\s*True', x.group(1)) else '/'
                for mm in [l.upper() for l in _lits((re.search(r'methods\s*=\s*\[([^\]]*)', x.group(1)) or re.match('', '')).group(0))] or ['GET']:
                    out.append(_R(mm, raw + p + det + (up.group(1) if up else x.group(2)), rel, j, handler='%s.%s' % (vs, x.group(2)),
                                  az=_dj_authz(h, ctx, v, mm)))

    def walk(rel, prefix, depth):
        if not rel or depth > 6:
            return
        t, m, c = _t(h, rel, 'py')
        regs, kinds = {}, {}
        for x in re.finditer(r'^(\w+)\s*=\s*(?:routers\.)?(DefaultRouter|SimpleRouter)\(', m, re.M):
            kinds[x.group(1)] = x.group(2) == 'DefaultRouter'
        for x in re.finditer(r'\b(\w+)\.register\(', m):
            sp = _args(h, m, x.end() - 1)
            if len(sp) >= 2:
                regs.setdefault(x.group(1), []).append((_lit(c[sp[0][0]:sp[0][1]]) or '', c[sp[1][0]:sp[1][1]].strip(), x.start()))
        for x in re.finditer(r'(?<![\w.])(path|re_path|url)\(', m):
            sp = _args(h, m, x.end() - 1)
            raw = _lit(c[sp[0][0]:sp[0][1]]) if sp else None
            if raw is None or len(sp) < 2:
                continue
            if x.group(1) != 'path':
                raw = raw.lstrip('^').rstrip('$').replace('/?', '/')
            tgt = c[sp[1][0]:sp[1][1]].strip()
            inc = re.match(r'include\(\s*(?:\(\s*)?(.*)', tgt, re.S)
            if inc:
                r = re.match(r'(\w+)\.urls', inc.group(1))
                if r and r.group(1) in regs:
                    router(prefix + raw, regs[r.group(1)], rel, x.start(), kinds.get(r.group(1)))
                elif _lit(inc.group(1).split(',')[0].rstrip(')')) is not None:
                    walk(modrel(_lit(inc.group(1).split(',')[0].rstrip(')'))), prefix + raw, depth + 1)
                else:
                    h.unparse('I-ROUTES', rel, t, x.start(), 'include() target not read')
            else:
                view(prefix + raw, tgt, rel, x.start())
        for x in re.finditer(r'(?<!include\()\b(\w+)\.urls\b', m):
            if x.group(1) in regs and not re.search(r'include\(\s*$', m[max(0, x.start() - 12):x.start()]):
                router(prefix, regs[x.group(1)], rel, x.start(), kinds.get(x.group(1)))
    root = modrel(_lit(S['ROOT_URLCONF'][2]) if 'ROOT_URLCONF' in S else None)
    if root:
        walk(root, '', 0)
    else:
        for f in files:
            if f.endswith('urls.py'):
                walk(f, '', 0)
        ctx.setdefault('notes', []).append('django: no ROOT_URLCONF read — every urls.py walked from /')
    return out


def dj_side(root, h, ctx):
    rows = []
    for rel in _py(h, ctx):
        t, m, c = _t(h, rel, 'py')
        for x in re.finditer(r'@receiver\(\s*([^)]*?)sender\s*=\s*([\w.]+)|\b(pre_save|post_save|pre_delete|post_delete)\.connect\(\s*(\w+)\s*,\s*sender\s*=\s*([\w.]+)', m):
            sigs = re.findall(r'(pre_save|post_save|pre_delete|post_delete)', x.group(1) or x.group(3))
            if x.group(4):
                fb = [f for f in _funcs(h, rel, 'py') if f[0] == x.group(4)]
            else:
                d = re.compile(r'def\s+(\w+)').search(m, x.end())
                fb = [f for f in _funcs(h, rel, 'py') if d and f[0] == d.group(1)]
            if not fb:
                continue
            ks = _kinds(m, fb[0][2], fb[0][3])
            for s in sigs:
                ev = {'pre_save': 'saving', 'pre_delete': 'deleting', 'post_delete': 'deleted'}.get(s) or (
                    'created' if re.search(r'\bif\s+created\b', m[fb[0][2]:fb[0][3]]) else 'saved')
                if ks:
                    rows.append(_row(h, '%s.%s' % (h.table(x.group(2) or x.group(5)), ev), {'kinds': ','.join(sorted(ks))}, rel, x.start()))
        for x in re.finditer(r'^\s+\w+\s*=\s*HistoricalRecords\(', m, re.M):
            cls = [b for b in _blocks(h, rel, 'py') if b[0] == 'class' and b[2] < x.start() < b[4]]
            for ev in ('created', 'updated', 'deleted') if cls else ():
                rows.append(_row(h, '%s.%s' % (h.table(cls[-1][1]), ev), {'kinds': 'activity'}, rel, x.start()))
    return _merged(rows) + _route_side(h, ctx)


def dj_scope(root, h, ctx):
    rows, ix = [], _pyindex(h, ctx)
    for rel in _py(h, ctx):
        if not re.search(r'(^|/)models(/|\.py$)', rel):
            continue
        t, m, c = _t(h, rel, 'py')
        for b in _blocks(h, rel, 'py'):
            bs = _bases(h, rel, b) if b[0] == 'class' and b[6] is None else []
            if not set(bs) & {'Model', 'SafeDeleteModel', 'SoftDeleteModel'} or re.search(r'abstract\s*=\s*True', c[b[3]:b[4]]):
                continue
            body = c[b[3]:b[4]]
            mg = re.findall(r'^\s+(\w+)\s*=\s*([\w.]*Manager)\(', body, re.M)
            mtxt = ' '.join(n for _, n in mg[:1])
            if mg and mg[0][1] in ix:
                mtxt += ' ' + _t(h, ix[mg[0][1]][0], 'py')[2][ix[mg[0][1]][1][3]:ix[mg[0][1]][1][4]]
            soft = bool(set(bs) & {'SafeDeleteModel', 'SoftDeleteModel'} or re.search(r'(?i)soft|deleted|alive|archiv', mtxt))
            dt = re.search(r'db_table\s*=\s*["\'](\w+)', body)
            rows.append(_row(h, 'table:' + (h.table(dt.group(1)) if dt else h.table(b[1])),
                             {'soft_delete': 'yes' if soft else 'no', 'tenant': 'yes' if TENANT.search(mtxt) else 'no',
                              'scopes': ','.join('%s=%s' % x for x in mg)}, rel, b[2]))
    return rows


def dj_conf(root, h, ctx):
    S, rows = _dj_settings(h, ctx), []
    for k, name in (('TIME_ZONE', 'timezone'), ('LANGUAGE_CODE', 'locale')):
        if k in S and _lit(S[k][2]) is not None:
            rows.append(_row(h, name, {'value': _lit(S[k][2])}, S[k][0], S[k][1]))
    ps = re.search(r'["\']PAGE_SIZE["\']\s*:\s*(\d+)', S.get('REST_FRAMEWORK', ('', 0, ''))[2])
    if ps:
        rows.append(_row(h, 'per_page', {'value': ps.group(1)}, S['REST_FRAMEWORK'][0], S['REST_FRAMEWORK'][1]))
    return rows + ([r for r in env_conf(root, h, ctx)] if 'TIME_ZONE' not in S else [])


# ---------------------------------------------------------------- python schedules (celery beat, apscheduler)
def _crontab(h, args):
    f = dict((k, v.strip().strip('"\'')) for k, v in re.findall(r'(\w+)\s*=\s*([^,)]+)', args))
    return h.cron(' '.join(f.get(k, '*') for k in ('minute', 'hour', 'day_of_month', 'month_of_year', 'day_of_week')))


def _apcron(h, args):
    f = dict((k, v.strip().strip('"\'')) for k, v in re.findall(r'\b(second|minute|hour|day|month|day_of_week|week|year)\s*=\s*([^,)]+)', args))
    if 'week' in f or 'year' in f or re.search(r'\d', f.get('day_of_week', '')):
        return '?'
    order = ['second', 'minute', 'hour', 'day', 'month']
    least = min(order.index(k) for k in f if k in order) if any(k in order for k in f) else 4
    mins = {'second': '0', 'minute': '0', 'hour': '0', 'day': '1', 'month': '1'}
    v = dict((k, f.get(k, mins[k] if order.index(k) < least else '*')) for k in order)
    return h.cron(('%s ' % v['second'] if v['second'] != '0' else '') + ' '.join([v['minute'], v['hour'], v['day'], v['month'],
                                                                                  f.get('day_of_week', '*')]))


def py_sched(root, h, ctx):
    rows, S = [], _dj_settings(h, ctx)
    ctz = S.get('CELERY_TIMEZONE') or S.get('CELERY_BEAT_TIMEZONE')
    gtz = []
    for rel in _py(h, ctx):
        t, m, c = _t(h, rel, 'py')
        gtz += re.findall(r'\w*Scheduler\([^)]*timezone\s*=\s*["\']([^"\']+)', c)
    for rel in _py(h, ctx):
        t, m, c = _t(h, rel, 'py')
        for x in re.finditer(r'(?:beat_schedule|CELERY_BEAT_SCHEDULE)\s*=\s*\{', m):
            a, b = x.end() - 1, h.close(m, x.end() - 1)
            for y in re.finditer(r'(["\'])([^"\']+)\1\s*:\s*\{', c[a + 1:b]):
                ea = a + 1 + y.end() - 1
                ent = c[ea:h.close(m, ea)]
                ct = re.search(r'crontab\(([^)]*)\)', ent)
                rows.append(_row(h, 'job:' + h.tokkey(y.group(2), SCHED_DROP), {'cron': _crontab(h, ct.group(1)) if ct else '?',
                                 'tz': _lit(ctz[2]) if ctz else '', 'overlap': 'no', 'target': 'celery beat'}, rel, ea))
        for x in re.finditer(r'\.add_job\(|@\w+\.scheduled_job\(', m):
            a = x.end() - 1
            sp = _args(h, m, a)
            args = c[a:h.close(m, a)]
            idm = _lit(_kw(c, m, sp, 'id') or '') or _lit(_kw(c, m, sp, 'name') or '')
            fn = c[sp[0][0]:sp[0][1]].strip() if sp and x.group(0).startswith('.') else (re.compile(r'def\s+(\w+)').search(m, a) or re.match('', '')).group(0)[4:]
            ft = re.search(r'from_crontab\(\s*["\']([^"\']+)', args)
            cr = h.cron(ft.group(1)) if ft else _apcron(h, args) if re.search(r"CronTrigger\(|['\"]cron['\"]", args) else '?'
            tz = re.search(r'timezone\s*=\s*["\']([^"\']+)', args)
            mi = re.search(r'max_instances\s*=\s*(\d+)', args)
            rows.append(_row(h, 'job:' + h.tokkey(idm or fn, SCHED_DROP), {'cron': cr, 'tz': tz.group(1) if tz else (gtz[0] if len(set(gtz)) == 1 else ''),
                             'overlap': 'no' if mi and int(mi.group(1)) > 1 else 'yes', 'target': 'apscheduler ' + fn}, rel, x.start()))
    return rows + _k8s(h, ctx)


# ---------------------------------------------------------------- registry
STACKS = ('django', 'fastapi')
C.SCAN['django'] = _scan_django
C.SCAN['fastapi'] = _scan_fastapi
LANES = C.drop_catchall({'django': dict(C.R3, **{'I-ENUM': py_enum, 'I-ERR': py_err, 'I-SIDE': dj_side, 'I-SCHED': py_sched, 'I-SCOPE': dj_scope, 'I-CONF': dj_conf}),
    'fastapi': dict(C.R3, **{'I-RULES': C.lane_rules, 'I-ENUM': py_enum, 'I-ERR': py_err, 'I-SIDE': C.lane_side, 'I-SCHED': py_sched,
                             'I-CONF': C.env_conf})})
PARTIAL = set((s, l) for s, ls in LANES.items() for l in ls)
GAPS = C.gaps(STACKS)


def detect(root, h):
    return C.detect_stacks(h, STACKS)


# ---------------------------------------------------------------- self-test: one tiny tree per stack, good rows + decoys
_L = C._L

SAMPLES = {
    'django': ({
        'requirements.txt': 'Django==5.0.1\ndjangorestframework==3.15.1\n',
        'proj/settings.py': _L('ROOT_URLCONF = "proj.urls"', 'INSTALLED_APPS = ["rest_framework", "shop"]', 'TIME_ZONE = "Asia/Riyadh"',
                               'REST_FRAMEWORK = {"DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"], "PAGE_SIZE": 25}',
                               'CELERY_BEAT_SCHEDULE = {"nightly-invoices": {"task": "shop.tasks.gen", "schedule": crontab(minute=0, hour=2)}}'),
        'proj/urls.py': _L('from django.urls import include, path', 'urlpatterns = [path("api/", include("shop.urls"))]'),
        'shop/urls.py': _L('router = DefaultRouter()', 'router.register("orders", views.OrderViewSet)',
                           'urlpatterns = [', '    path("", include(router.urls)),', '    path("health/", views.health),',
                           '    path("refunds/<int:pk>/", views.RefundView.as_view()),', '    # path("old/", views.health),', ']'),
        'shop/views.py': _L('class OrderViewSet(viewsets.ModelViewSet):', '    permission_classes = [IsAdminUser]', '',
                            'class RefundView(APIView):', '    permission_classes = [AllowAny]', '', '    def post(self, request, pk):',
                            '        send_mail("x", "y", "a@b.c", ["d@e.f"])', '', '', 'def health(request):', '    return JsonResponse({})'),
        'shop/models.py': _L('class Order(models.Model):', '    class Status(models.TextChoices):', '        PENDING = "pending", "Pending"',
                             '        PAID = "paid", "Paid"', '    objects = SoftDeleteManager()', '', '    class Meta:', '        db_table = "orders"', '',
                             '', '@receiver(post_save, sender=Order)', 'def order_saved(sender, instance, created, **kwargs):', '    if created:',
                             '        sync_order.delay(instance.pk)'),
        'shop/pricing.py': _L('def line_total(price, qty):', '    return round(price * qty, 2)', '', '', 'def page_count(n):', '    return round(n / 2)'),
        'shop/tests/test_enums.py': _L('class Ghost(models.TextChoices):', '    A = "a"')},
        [('I-ROUTES', 'GET /api', {'handler': 'DefaultRouter.api_root'}), ('I-ROUTES', 'POST /api/orders', {}), ('I-ROUTES', 'PATCH /api/orders/{}', {}),
         ('I-ROUTES', 'POST /api/refunds/{}', {'constraint': '1:int'}), ('I-ROUTES', 'ANY /api/health', {}),
         ('I-AUTHZ', 'GET /api/orders', {'authn': 'required', 'roles': 'staff'}), ('I-AUTHZ', 'POST /api/refunds/{}', {'authn': 'none'}),
         ('I-AUTHZ', 'ANY /api/health', {'authn': 'none'}), ('I-ENUM', 'type:orderstatus', {'values': 'paid,pending'}),
         ('I-ERR', 'unauthenticated', {'status': '403'}), ('I-ERR', 'validation', {'status': '400'}), ('I-SIDE', 'order.created', {'kinds': 'job'}),
         ('I-SIDE', 'POST /api/refunds/{}', {'kinds': 'mail'}), ('I-SCHED', 'job:invoice.nightly', {'cron': '0 2 * * *', 'overlap': 'no'}),
         ('I-SCOPE', 'table:order', {'soft_delete': 'yes'}), ('I-MONEY', 'area:pricing', {'modes': 'half-even'}),
         ('I-CONF', 'timezone', {'value': 'Asia/Riyadh'}), ('I-CONF', 'per_page', {'value': '25'})],
        [('I-ROUTES', 'ANY /api/old'), ('I-ENUM', 'type:ghost'), ('I-MONEY', 'area:page'), ('I-ROUTES', 'GET /api/health')]),
    'fastapi': ({
        'pyproject.toml': '[project]\ndependencies = ["fastapi>=0.110", "pydantic>=2.6"]\n',
        'Dockerfile': 'FROM python:3.12\nENV TZ=Asia/Riyadh\n',
        'app/main.py': _L('from fastapi import FastAPI, Depends', 'from app.routers import orders', 'app = FastAPI()',
                          'app.include_router(orders.router, prefix="/api", dependencies=[Depends(get_current_user)])', '',
                          '@app.exception_handler(OrderLocked)', 'async def locked(request, exc):', '    return JSONResponse({"m": 1}, status_code=409)'),
        'app/routers/orders.py': _L('router = APIRouter(prefix="/orders")', '', 'class OrderIn(BaseModel):', '    email: EmailStr',
                                    '    qty: int = Field(ge=1, le=10)', '    note: Optional[str] = None', '    status: Literal["new", "paid"]', '',
                                    '@router.post("", dependencies=[Depends(verify_tenant)])',
                                    'def create(body: OrderIn, user=Security(get_user, scopes=["orders:write"])):', '    send_receipt.delay(1)', '',
                                    '@router.get("/{order_id}")', 'def show(order_id: int):', '    return {}', '', '# @router.get("/ghost")'),
        'app/jobs.py': _L('scheduler.add_job(cleanup_carts, "cron", hour=3, id="cleanup-carts")')},
        [('I-ROUTES', 'GET /api/orders/{}', {'constraint': '1:int', 'handler': 'show'}),
         ('I-AUTHZ', 'POST /api/orders', {'authn': 'required', 'abilities': 'orders.write', 'extra_guard': 'yes'}),
         ('I-RULES', 'POST /api/orders email', {'format': 'email', 'presence': 'required'}),
         ('I-RULES', 'POST /api/orders qty', {'type': 'int', 'min': '1', 'max': '10'}),
         ('I-RULES', 'POST /api/orders note', {'nullable': 'yes', 'presence': 'optional'}), ('I-RULES', 'POST /api/orders status', {'in': 'new,paid'}),
         ('I-ERR', 'exc:orderlocked', {'status': '409'}), ('I-ERR', 'validation', {'status': '422'}), ('I-SIDE', 'POST /api/orders', {'kinds': 'job'}),
         ('I-SCHED', 'job:cart.cleanup', {'cron': '0 3 * * *', 'overlap': 'yes'}), ('I-CONF', 'timezone', {'value': 'Asia/Riyadh'})],
        [('I-ROUTES', 'GET /api/orders/ghost'), ('I-SIDE', 'GET /api/orders/{}')])}


def self_test(H, tmp):
    return C.run_samples(H, tmp, SAMPLES, detect, LANES)
