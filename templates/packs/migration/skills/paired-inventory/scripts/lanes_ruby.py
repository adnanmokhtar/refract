"""lanes_ruby.py — Rails lanes for pair-inventory.py.

Every lane in this module is `partial`: no paired fixture calibrates Rails yet, so each candidate it produces is
tagged `partial`. Reads are static (rg listing through the core's H, masked text); nothing is imported or executed.
Shared readers, the k8s CronJob reader and the I-MONEY lane come from lanes_common.py (loaded by path).

What it reads
  config/routes.rb: resources/resource (only/except/path/param), namespace/scope, member/collection, verb routes,
  match via: (via: :all is one `ANY` row), root, constraints {id: /\\d+/}, devise `authenticate` blocks; controllers'
  before_action/skip_before_action (only/except, superclass chain), Pundit `authorize`, CanCan
  load_and_authorize_resource; model `enum`; rescue_from + Rails rescue_responses defaults; model callbacks
  (bodies in the model) and has_paper_trail; whenever schedule.rb, sidekiq-cron YAML, k8s CronJobs; default_scope /
  acts_as_paranoid / acts_as_tenant; config.time_zone, i18n.default_locale, per_page; rounding on money paths.
What it cannot see: routes drawn through `draw` / `concerns` (unparsed, partial) or built dynamically, Rack
middleware, effects one call away from an action or callback, validation (I-RULES is a gap), DDL (I-SCHEMA is a
gap). What cannot be read is '?', never guessed.
"""
import importlib.util, os, re, sys

sys.dont_write_bytecode = True          # loading lanes_common must not drop __pycache__ into a repo
_spec = importlib.util.spec_from_file_location('lanes_common', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lanes_common.py'))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

AUTHN, SCHED_DROP, TENANT, _LN, _R, _blocks, _constraint, _errkey = C.AUTHN, C.SCHED_DROP, C.TENANT, C._LN, C._R, C._blocks, C._constraint, C._errkey
_funcs, _guard, _k8s, _kinds, _lit, _merged, _retype, _route_side = C._funcs, C._guard, C._k8s, C._kinds, C._lit, C._merged, C._retype, C._route_side
_row, _src, _status, _t = C._row, C._src, C._status, C._t


# ---------------------------------------------------------------- rails
RES7 = (('index', 'GET', ''), ('create', 'POST', ''), ('new', 'GET', '/new'), ('edit', 'GET', '/:id/edit'), ('show', 'GET', '/:id'),
        ('update', 'PATCH', '/:id'), ('update', 'PUT', '/:id'), ('destroy', 'DELETE', '/:id'))


def _rb(h, ctx, globs):
    return _src(h, ctx, globs)


def _rblist(rest, key):
    x = re.search(r'\b%s:\s*(\[[^\]]*\]|%%[iw]\[[^\]]*\]|:\w+[!?]?|["\'][^"\']*["\'])' % key, rest)
    return None if not x else set(re.findall(r'\w+[!?]?', x.group(1).replace('%i', '').replace('%w', '')))


def _rpath(raw):
    """Rails optional segments `(/:id)` -> plain, with the optional-param count."""
    opt = len([g for g in re.findall(r'\(([^()]*)\)', raw) if ':' in g and 'format' not in g])
    return re.sub(r'\(([^()]*:(?!format)[^()]*)\)', r'\1', raw), opt


def _scan_rails(h, ctx):
    out = []
    for rel in _rb(h, ctx, ['config/routes.rb', 'config/routes/*.rb']):
        t, m, c = _t(h, rel, 'rb')
        stack, pos = [], 0
        for ln in m.split('\n'):
            i, pos = pos, pos + len(ln) + 1
            s, cl = ln.strip(), c[i:i + len(ln)].strip()
            if re.match(r'end\b', s):
                stack and stack.pop()
                continue
            opens = bool(re.search(r'\bdo\b(\s*\|[^|]*\|)?\s*$', s))
            x = re.match(r'(\w+)\b\s*\(?\s*(.*)$', cl)
            pre, auth = '', any(f.get('auth') for f in stack)
            for k, f in enumerate(stack):
                nxt = stack[k + 1].get('kind') if k + 1 < len(stack) else None
                pre += f['res'][{'member': 'member', 'collection': 'coll'}.get(nxt, 'nest')] if f.get('res') else f.get('path', '')
            mod = '/'.join(f['mod'] for f in stack if f.get('mod'))
            res = next((f['res'] for f in reversed(stack) if f.get('res')), None)
            frame = {}
            verb, rest = (x.group(1), x.group(2)) if x else ('', '')
            cons = dict((n, _retype(r)) for n, r in re.findall(r'(\w+):\s*/((?:\\/|[^/\n])+)/', rest))
            az = {'authn': 'required', 'roles': '', 'abilities': '', 'extra_guard': 'no', 'mw': 'authenticate'} if auth else None

            def emit(meth, raw, handler):
                p, o = _rpath(raw)
                for mm in meth:
                    out.append(_R(mm, p, rel, i, handler=handler, con=_constraint(p, cons), opt=o, az=az))
            if verb in ('namespace', 'scope'):
                nm = re.match(r':(\w+)|["\']([^"\']*)["\']', rest)
                pth = _lit(re.search(r'path:\s*(["\'][^"\']*["\'])', rest).group(1)) if 'path:' in rest else None
                md = re.search(r'module:\s*[:"\']?([\w/]+)', rest)
                if verb == 'namespace' and nm:
                    frame = {'path': '/' + (pth if pth is not None else nm.group(1) or nm.group(2)), 'mod': nm.group(1) or nm.group(2)}
                else:
                    frame = {'path': ('/' + (nm.group(2) if nm and nm.group(2) is not None else pth or '')).rstrip('/'), 'mod': md.group(1) if md else ''}
            elif verb in ('resources', 'resource'):
                head = re.split(r'\b\w+:\s', rest)[0]
                names = re.findall(r'(?<![\w:]):(\w+)', head)
                only, exc = _rblist(rest, 'only'), _rblist(rest, 'except')
                pth = re.search(r'path:\s*["\']([^"\']*)', rest)
                prm = re.search(r'param:\s*:(\w+)', rest)
                ctl = re.search(r'controller:\s*[:"\']?([\w/]+)', rest)
                sing = verb == 'resource'
                for n in names:
                    base, idp = pre + '/' + (pth.group(1) if pth else n), prm.group(1) if prm else 'id'
                    ctrl = (mod + '/' if mod else '') + (ctl.group(1) if ctl else n + ('s' if sing else ''))
                    for act, meth, suf in RES7:
                        if (sing and act == 'index') or (only is not None and act not in only) or (exc and act in exc):
                            continue
                        suf = suf.replace('/:id', '' if sing else '/:' + idp)
                        emit([meth], base + suf, '%s#%s' % (ctrl, act))
                    frame = {'res': {'nest': base[len(pre):] + ('' if sing else '/:%s_id' % h.table(n)), 'member': base[len(pre):] + ('' if sing else '/:' + idp),
                                     'coll': base[len(pre):], 'ctrl': ctrl}}
            elif verb in ('member', 'collection'):
                frame = {'kind': verb}
            elif verb in ('get', 'post', 'put', 'patch', 'delete', 'match') and rest:
                lit, sym = _lit(re.split(r'\s*(?:,|=>)', rest)[0]), re.match(r':(\w+)', rest)
                to = re.search(r'(?:to:|=>)\s*["\']([\w/]+)#(\w+)', rest)
                on = re.search(r'on:\s*:(\w+)', rest)
                via = re.search(r'via:\s*(\[[^\]]*\]|:\w+)', rest)
                meths = [verb.upper()] if verb != 'match' else (['ANY'] if not via or ':all' in via.group(1) else
                                                                [w.upper() for w in re.findall(r'\w+', via.group(1))])
                if res and (sym or lit is not None):
                    rp = pre[:len(pre) - len(stack[-1]['res']['nest'])] + stack[-1]['res'][{'member': 'member', 'collection': 'coll'}[on.group(1)]] \
                        if on and on.group(1) in ('member', 'collection') and stack and stack[-1].get('res') else pre
                    seg = (sym.group(1) if sym else lit.strip('/'))
                    emit(meths, rp + '/' + seg, '%s#%s' % (to.group(1) if to else res['ctrl'], to.group(2) if to else seg))
                elif lit is not None:
                    hd = '%s#%s' % (to.group(1), to.group(2)) if to else (lit.strip('/').replace('/', '#', 1) if lit.count('/') == 1 else '')
                    emit(meths, pre + '/' + lit.lstrip('/'), (mod + '/' if mod and hd else '') + hd)
            elif verb == 'root':
                to = re.search(r'["\']([\w/]+)#(\w+)', rest)
                emit(['GET'], pre + '/', '%s#%s' % to.groups() if to else '')
            elif verb in ('authenticate', 'authenticated'):
                frame = {'auth': True}
            elif verb == 'draw' or verb == 'concerns':
                h.unparse('I-ROUTES', rel, t, i, '%s not followed (partial)' % verb)
            if opens:
                stack.append(frame)
    _rails_authz(h, ctx, out)
    return out


def _rbclass(h, ctx, name):
    p = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name).replace('::', '/').lower() + '.rb'
    for f in _rb(h, ctx, ['app/controllers/**/*.rb', 'app/models/**/*.rb']):
        if f.endswith('/' + p):
            return f
    return None


def _rb_filters(h, ctx, rel, depth=0):
    t, m, c = _t(h, rel, 'rb')
    x = re.search(r'^\s*class\s+[\w:]+\s*<\s*([\w:]+)', m, re.M)
    prel = _rbclass(h, ctx, x.group(1)) if x and depth < 4 else None
    out = _rb_filters(h, ctx, prel, depth + 1) if prel else []
    for y in re.finditer(r'^[ \t]*(prepend_before_action|before_action|skip_before_action|before_filter|skip_before_filter|'
                         r'load_and_authorize_resource|authorize_resource)\b([^\n]*)', m, re.M):
        rest = c[y.start(2):y.end(2)]
        names = re.findall(r'(?<![\w:]):(\w+[!?]?)', re.split(r'\b(?:only|except|if|unless):', rest)[0])
        out.append((y.group(1), names, _rblist(rest, 'only'), _rblist(rest, 'except')))
    return out


def _rails_authz(h, ctx, routes):
    for r in routes:
        if r['az'] or '#' not in r['handler']:
            continue
        ctrl, act = r['handler'].split('#')
        rel = next((f for f in _rb(h, ctx, ['app/controllers/**/*.rb']) if f.endswith('/%s_controller.rb' % ctrl)), None)
        if not rel:
            continue
        active, ab = [], set()
        for kind, names, only, exc in _rb_filters(h, ctx, rel):
            if (only is None or act in only) and (exc is None or act not in exc):
                if kind.startswith('skip'):
                    active = [n for n in active if n not in names]
                elif 'authorize' in kind:
                    ab.add('can.' + {'index': 'read', 'show': 'read', 'new': 'create', 'edit': 'update'}.get(act, act))
                else:
                    active += names
        fb = [f for f in _funcs(h, rel, 'rb') if f[0] == act]
        if fb:
            body = _t(h, rel, 'rb')[2][fb[0][2]:fb[0][3]]
            for y in re.finditer(r'(?<![\w.])authorize\b\s*\(?[^,\n)]*(?:,\s*:(\w+)\?)?', body):
                ab.add('policy.' + (y.group(1) or act))
            r['body'] = (rel, 'rb', fb[0][2], fb[0][3])
        mws = [(n, [], True) for n in active]
        r['az'] = _guard(h, mws, known_none=True)
        r['az']['abilities'] = ','.join(sorted(ab))
        r['az']['extra_guard'] = 'yes' if any(re.search(r'(?i)require|ensure|check|verify|authoriz|admin|guard|restrict', n)
                                              and not AUTHN.search(n) for n in active) else 'no'


def _models(h, ctx):
    out = []
    for rel in _rb(h, ctx, ['app/models/**/*.rb']):
        t, m, c = _t(h, rel, 'rb')
        for b in _blocks(h, rel, 'rb'):
            hd = re.match(r'class\s+([\w:]+)\s*<\s*([\w:]+)', m[b[2]:b[3]])
            if hd and hd.group(1) != 'ApplicationRecord' and 'concerns/' not in rel:
                out.append((rel, b, hd.group(1).split('::')[-1], c[b[3]:b[4]]))
    return out


def rails_enum(root, h, ctx):
    rows = []
    for rel, b, cls, body in _models(h, ctx):
        for x in re.finditer(r'\benum\s+(?:(\w+):\s*|:(\w+)\s*,\s*)(\{[^}]*\}|\[[^\]]*\]|%[wi]\[[^\]]*\])', body):
            v = x.group(3)
            if v.startswith('{'):
                pairs = re.findall(r'(\w+):\s*(-?\d+|["\'][^"\']*["\']|:\w+)', v)
                names, vals = [p[0] for p in pairs], [p[1].strip('"\':') for p in pairs]
            else:
                names = re.findall(r'\w+', v.replace('%i', '').replace('%w', ''))
                vals = [str(k) for k in range(len(names))]
            rows.append(_row(h, 'col:%s.%s' % (h.table(cls), x.group(1) or x.group(2)), {'values': ','.join(sorted(set(vals))),
                             'names': ','.join(names)}, rel, b[3] + x.start()))
    return rows


def rails_err(root, h, ctx):
    out = {}
    for rel in _rb(h, ctx, ['app/controllers/**/*.rb']):
        t, m, c = _t(h, rel, 'rb')
        for x in re.finditer(r'^[ \t]*rescue_from\s+([^\n]*)', m, re.M):
            rest = c[x.start(1):x.end(1)]
            w = re.search(r'with:\s*:(\w+)', rest)
            fb = [f for f in _funcs(h, rel, 'rb') if w and f[0] == w.group(1)]
            body = c[fb[0][2]:fb[0][3]] if fb else c[x.start():_blocks_end(m, x.start())] if re.search(r'\bdo\b|\{', rest) else rest
            st = _status(body)
            for cls in re.findall(r'[A-Z][\w:]*', re.split(r'with:', rest)[0]):
                k = _errkey(h, cls)
                out[k] = _row(h, k, {'status': ','.join(sorted(st)) or '?', 'envelope': w.group(1) if w else 'block'}, rel, x.start())
    for k, v, env in (('not_found', '404', 'ActiveRecord::RecordNotFound'), ('validation', '422', 'ActiveRecord::RecordInvalid'),
                      ('exc:parametermissing', '400', 'ActionController::ParameterMissing')):
        out.setdefault(k, {'key': k, 'attrs': {'status': v, 'envelope': env}, 'at': '-', 'excerpt': env + ' (Rails rescue_responses default)'})
    return list(out.values())


def _blocks_end(m, i):
    ls = m.rfind('\n', 0, i) + 1
    ind = len(m[ls:i]) - len(m[ls:i].lstrip())
    for y in _LN.finditer(m, i):
        if len(y.group(1)) <= ind and m.startswith('end', y.end()):
            return y.end() + 3
    return len(m)


RBEV = {'create': 'created', 'update': 'updated', 'destroy': 'deleted', 'save': 'saved', 'commit': 'committed'}


def rails_side(root, h, ctx):
    rows = []
    for rel, b, cls, body in _models(h, ctx):
        t, m, c = _t(h, rel, 'rb')
        ent = h.table(cls)
        for x in re.finditer(r'^[ \t]*(after|before)_(create|update|destroy|save|commit)(_commit)?\b([^\n]*)', m[b[3]:b[4]], re.M):
            rest, i = c[b[3] + x.start(4):b[3] + x.end(4)], b[3] + x.start()
            on = re.search(r'on:\s*(\[[^\]]*\]|:\w+)', rest)
            evs = [w for w in re.findall(r'\w+', on.group(1))] if on else [x.group(2)]
            names = re.findall(r'(?<![\w:]):(\w+[!?]?)', re.split(r'\b(?:on|if|unless):', rest)[0])
            ks = set()
            for f in _funcs(h, rel, 'rb'):
                if f[0] in names:
                    ks |= _kinds(m, f[2], f[3])
            if re.search(r'\bdo\b|\{', rest):
                ks |= _kinds(m, i, _blocks_end(m, i) if 'do' in rest else h.close(m, m.find('{', i)))
            for ev in evs:
                e = RBEV.get(ev, ev) if x.group(1) == 'after' else {'create': 'creating', 'update': 'updating', 'destroy': 'deleting', 'save': 'saving'}.get(ev)
                if ks and e:
                    rows.append(_row(h, '%s.%s' % (ent, e), {'kinds': ','.join(sorted(ks))}, rel, i))
        if re.search(r'^\s*has_paper_trail\b', body, re.M):
            rows += [_row(h, '%s.%s' % (ent, e), {'kinds': 'activity'}, rel, b[2]) for e in ('created', 'updated', 'deleted')]
    return _merged(rows) + _route_side(h, ctx)


def _ampm(s):
    x = re.match(r'\s*(\d{1,2})(?::(\d\d))?\s*([ap])?\.?m?', s or '', re.I)
    if not x:
        return None
    hh = int(x.group(1)) % 12 + (12 if (x.group(3) or '').lower() == 'p' else 0) if x.group(3) else int(x.group(1))
    return int(x.group(2) or 0), hh


def rails_sched(root, h, ctx):
    rows = []
    for rel in _rb(h, ctx, ['config/schedule.rb']):
        t, m, c = _t(h, rel, 'rb')
        for x in re.finditer(r'^[ \t]*every\s+([^\n]*?)\s+do\b', m, re.M):
            e = c[x.start(1):x.end(1)]
            at = re.search(r'at:\s*["\']([^"\']+)', e)
            unit = re.match(r'\s*(?:1\.(day|hour)|:(day|hour|daily|hourly|sunday|monday|tuesday|wednesday|thursday|friday|saturday))\b', e)
            u = unit and (unit.group(1) or unit.group(2))
            hm = _ampm(at.group(1)) if at else (0, 0)
            cr = (_lit(e.split(',')[0]) if _lit(e.split(',')[0]) and len(_lit(e.split(',')[0]).split()) >= 5 else
                  '%d %d * * *' % hm if u in ('day', 'daily') and hm else '%d * * * *' % (int(at.group(1)) if at and at.group(1).isdigit() else 0)
                  if u in ('hour', 'hourly') and not (at and not at.group(1).isdigit()) else
                  '%d %d * * %s' % (hm + (u[:3],)) if u and hm else '?')
            blk = c[x.end():_blocks_end(m, x.start())]
            for y in re.finditer(r'\b(runner|rake|command)\s+["\']([^"\']+)', blk):
                rows.append(_row(h, 'job:' + h.tokkey(y.group(2).split('(')[0], SCHED_DROP),
                                 {'cron': h.cron(cr) if cr != '?' else '?', 'tz': '', 'overlap': 'no', 'target': 'whenever'}, rel, x.start()))
    for rel in _rb(h, ctx, ['config/schedule.yml', 'config/sidekiq*.yml', 'config/*cron*.yml']):
        t = h.read(rel)
        for x in re.finditer(r'^([ \t]*)([\w:.\-]+):[ \t]*\n((?:\1[ \t]+[^\n]*\n?)+)', t, re.M):
            ind = re.match(r'[ \t]*', x.group(3)).group(0)
            cr = re.search(r'^%s(cron|every):\s*["\']?([^"\'\n#]+)' % ind, x.group(3), re.M)
            if cr:
                f = cr.group(2).split()
                tz = f.pop() if len(f) in (6, 7) and re.search(r'[A-Za-z]/|^UTC$', f[-1]) else ''
                rows.append(_row(h, 'job:' + h.tokkey(x.group(2), SCHED_DROP), {'cron': h.cron(' '.join(f)) if cr.group(1) == 'cron' else '?',
                                 'tz': tz, 'overlap': 'no', 'target': 'sidekiq-cron'}, rel, x.start(2)))
    return rows + _k8s(h, ctx)


def rails_scope(root, h, ctx):
    rows = []
    for rel, b, cls, body in _models(h, ctx):
        if 'abstract_class' in body:
            continue
        ds = ' '.join(re.findall(r'^\s*(default_scope\b[^\n]*|acts_as_\w+[^\n]*|include\s+Discard::Model)', body, re.M))
        soft = re.search(r'acts_as_paranoid|acts_as_archival|default_scope[^\n]*(?:deleted|discarded|kept|archived)', ds)
        tn = re.search(r'^\s*self\.table_name\s*=\s*["\'](\w+)', body, re.M)
        rows.append(_row(h, 'table:' + h.table(tn.group(1) if tn else cls), {'soft_delete': 'yes' if soft else 'no',
                         'tenant': 'yes' if re.search(r'acts_as_tenant', ds) or (TENANT.search(ds) and 'default_scope' in ds) else 'no',
                         'scopes': ds.strip()[:80]}, rel, b[2]))
    return rows


def rails_conf(root, h, ctx):
    rows = []
    for rel in _rb(h, ctx, ['config/application.rb', 'config/initializers/*.rb']):
        t, m, c = _t(h, rel, 'rb')
        for rx, k in ((r'config\.time_zone\s*=\s*["\']([^"\']+)', 'timezone'), (r'i18n\.default_locale\s*=\s*:?["\']?(\w+)', 'locale'),
                      (r'default_per_page\s*=?\s*(\d+)|WillPaginate\.per_page\s*=\s*(\d+)', 'per_page')):
            for x in re.finditer(rx, c):
                rows.append(_row(h, k, {'value': next(g for g in x.groups() if g)}, rel, x.start()))
    return rows


# ---------------------------------------------------------------- registry
STACKS = ('rails',)
C.SCAN['rails'] = _scan_rails
LANES = C.drop_catchall({'rails': dict(C.R3, **{'I-ENUM': rails_enum, 'I-ERR': rails_err, 'I-SIDE': rails_side, 'I-SCHED': rails_sched, 'I-SCOPE': rails_scope,
                        'I-CONF': rails_conf})})
PARTIAL = set((s, l) for s, ls in LANES.items() for l in ls)
GAPS = C.gaps(STACKS)


def detect(root, h):
    return C.detect_stacks(h, STACKS)


# ---------------------------------------------------------------- self-test: one tiny tree per stack, good rows + decoys
_L = C._L

SAMPLES = {
    'rails': ({
        'Gemfile.lock': '    rails (7.1.3)\n',
        'config/routes.rb': _L("Rails.application.routes.draw do", "  # get '/commented', to: 'x#y'", "  root 'home#index'", "  namespace :admin do",
                               "    resources :orders, only: [:index, :show], constraints: { id: /\\d+/ } do", "      member do", "        post :refund",
                               "      end", "    end", "  end", "  get 'health', to: 'health#show'", "  match 'legacy/*path', to: 'legacy#proxy', via: :all", "end"),
        'app/controllers/application_controller.rb': _L("class ApplicationController < ActionController::Base", "  before_action :authenticate_user!",
                                                        "  rescue_from Orders::Locked, with: :locked", "  def locked", "    head :conflict", "  end", "end"),
        'app/controllers/admin/orders_controller.rb': _L("class Admin::OrdersController < ApplicationController", "  before_action :require_admin!, except: [:index]",
                                                         "  def index", "    authorize Order", "    OrderMailer.summary.deliver_later", "  end", "  def show",
                                                         "    @order = Order.find(params[:id])", "  end", "end"),
        'app/models/order.rb': _L("class Order < ApplicationRecord", "  acts_as_paranoid", "  has_paper_trail", "  enum status: { pending: 0, paid: 1 }",
                                  "  # enum role: { a: 0 }", "  after_create_commit :notify_erp", "  def notify_erp", "    # OrderMailer.x.deliver_later",
                                  "    ErpSyncJob.perform_later(id)", "  end", "  def total_with_tax", "    (subtotal * 1.2).round(2)", "  end", "end"),
        'app/helpers/paging_helper.rb': _L("module PagingHelper", "  def page_count", "    (n / 2.0).round", "  end", "end"),
        'config/schedule.rb': _L("every 1.day, at: '2:30 am' do", "  runner 'InvoiceJob.perform_now'", "end", "# every 1.hour do", "#   rake 'ghost:run'", "# end"),
        'config/application.rb': _L("module App", "  class Application < Rails::Application", "    config.time_zone = 'Riyadh'", "  end", "end")},
        [('I-ROUTES', 'GET /', {'handler': 'home#index'}), ('I-ROUTES', 'GET /admin/orders', {'handler': 'admin/orders#index'}),
         ('I-ROUTES', 'GET /admin/orders/{}', {'constraint': '1:int'}), ('I-ROUTES', 'POST /admin/orders/{}/refund', {'handler': 'admin/orders#refund'}),
         ('I-ROUTES', 'ANY /legacy/{*}', {'handler': 'legacy#proxy'}),
         ('I-AUTHZ', 'GET /admin/orders', {'authn': 'required', 'abilities': 'policy.index', 'extra_guard': 'no'}),
         ('I-AUTHZ', 'GET /admin/orders/{}', {'authn': 'required', 'extra_guard': 'yes'}), ('I-ENUM', 'col:order.status', {'values': '0,1'}),
         ('I-ERR', 'exc:locked', {'status': '409'}), ('I-ERR', 'not_found', {'status': '404'}),
         ('I-SIDE', 'order.updated', {'kinds': 'activity'}), ('I-SIDE', 'order.created', {'kinds': 'activity,job'}), ('I-SIDE', 'GET /admin/orders', {'kinds': 'mail'}),
         ('I-SCHED', 'job:invoice.now.perform', {'cron': '30 2 * * *'}), ('I-SCOPE', 'table:order', {'soft_delete': 'yes', 'tenant': 'no'}),
         ('I-MONEY', 'area:order', {'modes': 'half-away'}), ('I-CONF', 'timezone', {'value': 'Riyadh'})],
        [('I-ROUTES', 'GET /commented'), ('I-ENUM', 'col:order.role'), ('I-MONEY', 'area:page'), ('I-SCHED', 'job:ghost')])}


def self_test(H, tmp):
    return C.run_samples(H, tmp, SAMPLES, detect, LANES)
